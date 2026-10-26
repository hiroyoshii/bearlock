package com.hiyozoo.bearlock

import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
import org.json.JSONObject

/** Both platforms consume the same hand-specified expectations, including DST edge cases. */
class LockContractTest {
    @Test fun sharedOverlapOperations() {
        val fixture=JSONObject(javaClass.getResourceAsStream("/lock-operations.json")!!.bufferedReader().use { it.readText() })
        val cases=fixture.getJSONArray("overlapCases")
        assertTrue(cases.length()>0)
        val ids=mutableSetOf<String>()
        fun time(value: String)=Instant.parse(value).toEpochMilli()
        fun rule(value: JSONObject): Rule {
            val schedule=if(value.has("days")) {
                val days=value.getJSONArray("days")
                LockSchedule.Weekly((0 until days.length()).map { days.getInt(it) }.toSet(),
                    value.getInt("startMinute"),value.getInt("endMinute"),value.getString("zone"))
            } else LockSchedule.Single(time(value.getString("start")),time(value.getString("end")))
            return Rule(id=value.getString("key"),title="Contract",targets=Targets(apps=setOf(value.getString("key"))),
                schedule=schedule,enabled=value.optBoolean("enabled",true))
        }
        for(i in 0 until cases.length()) {
            val scenario=cases.getJSONObject(i)
            val id=scenario.getString("id")
            assertTrue(id,ids.add(id))
            val saved=scenario.getJSONArray("existing")
            val wakes=(0 until saved.length()).map { saved.getJSONObject(it) }.filter { it.has("wakeAt") }.map {
                WakeRequest(it.getString("key"),time(it.getString("wakeStart")),time(it.getString("wakeAt")))
            }
            val original=State(rules=(0 until saved.length()).map { rule(saved.getJSONObject(it)) },wakes=wakes)
            var state=original
            var reflected=0
            val operations=LockOperations(change={ command -> command(state).also { state=it } },
                reflect={ reflected++; Result.success(Unit) },clock={ time(scenario.getString("now")) })
            val proposed=rule(scenario.getJSONObject("proposed"))
            val action=scenario.optString("action")
            val outcome=when(action) {
                "replace" -> operations.updateSchedule { proposed }
                "cancel" -> operations.cancelWake(state.activeLocks(time(scenario.getString("now"))).single { it.ruleId==proposed.id })
                else -> operations.createSchedule { proposed }
            }
            val result=if(outcome is OperationOutcome.Rejected) {
                assertEquals(id,original,state)
                assertEquals(id,0,reflected)
                if(outcome.cause.message=="overlap") "overlap" else "unexpected:${outcome.cause}"
            } else "ok"
            assertEquals(id,scenario.getString("result"),result)
            if(result=="ok") {
                assertEquals(id,original.rules.size+(if(action.isEmpty()) 1 else 0),state.rules.size)
                assertEquals(id,1,reflected)
                if(action=="cancel") {
                    assertEquals(id,original.rules,state.rules)
                    assertTrue(id,state.wakes.isEmpty())
                }
            }
        }
    }

    @Test fun sharedHistoryOperations() {
        val fixture=JSONObject(javaClass.getResourceAsStream("/lock-operations.json")!!.bufferedReader().use { it.readText() })
        assertEquals(1,fixture.getInt("version"))
        val cases=fixture.getJSONArray("historyCases")
        assertTrue(cases.length()>0)
        val ids=mutableSetOf<String>()
        val lockCases=fixture.getJSONArray("cases")
        for(i in 0 until lockCases.length()) assertTrue(ids.add(lockCases.getJSONObject(i).getString("id")))
        val overlapCases=fixture.getJSONArray("overlapCases")
        for(i in 0 until overlapCases.length()) assertTrue(ids.add(overlapCases.getJSONObject(i).getString("id")))
        val epoch=1_800_000_000_000L
        fun time(seconds: Double)=epoch+(seconds*1000).toLong()
        fun strings(array: org.json.JSONArray)=(0 until array.length()).map { array.getString(it) }
        for(i in 0 until cases.length()) {
            val scenario=cases.getJSONObject(i)
            val id=scenario.getString("id")
            assertTrue(ids.add(id))
            val entries=scenario.getJSONArray("recent")
            val targets=(0 until entries.length()).associate { index ->
                val entry=entries.getJSONObject(index)
                entry.getString("target") to Targets(apps=setOf("app.${entry.getString("target")}"))
            }
            val recent=(0 until entries.length()).map { index ->
                val entry=entries.getJSONObject(index)
                val pinnedAt=if(entry.has("pinnedAt")) time(entry.getDouble("pinnedAt")) else null
                Recent(targets.getValue(entry.getString("target")),time(entry.getDouble("usedAt")),pinnedAt!=null,pinnedAt)
            }
            val rule=Rule(id="current",title=id,targets=targets.getValue("A"),schedule=LockSchedule.Single(epoch,epoch+7_200_000))
            val initial=State(rules=listOf(rule),recent=recent,wakes=listOf(WakeRequest(rule.id,epoch,epoch+1_800_000)),selection=rule.targets)
            var state=initial
            var now=epoch
            var reflections=0
            val operations=LockOperations(change={ command -> command(state).also { state=it } },
                reflect={ reflections++; Result.success(Unit) },clock={ now })
            fun label(item: Recent)=targets.entries.single { it.value==item.targets }.key
            val steps=scenario.getJSONArray("steps")
            assertTrue(steps.length()>0)
            for(index in 0 until steps.length()) {
                val step=steps.getJSONObject(index)
                val name="$id/$index:${step.getString("action")}"
                val original=state
                now=time(step.getDouble("at"))
                val outcome=when(step.getString("action")) {
                    "evaluate" -> null
                    "pin","unpin" -> operations.setRecentPinned(targets.getValue(step.getString("target")),step.getString("action")=="pin")
                    "delete" -> operations.deleteRecentTarget(targets.getValue(step.getString("target")))
                    else -> throw AssertionError("Unknown history operation")
                }
                val result=if(outcome is OperationOutcome.Rejected) {
                    assertEquals(name,original,state)
                    if(outcome.cause.message=="pin_limit") "pinLimit" else "unexpected:${outcome.cause}"
                } else "ok"
                assertEquals(name,step.getString("result"),result)
                assertEquals(name,step.getJSONArray("stored").length(),state.recent.size)
                assertEquals(name,strings(step.getJSONArray("stored")).toSet(),state.recent.map(::label).toSet())
                assertEquals(name,strings(step.getJSONArray("pinned")).toSet(),state.recent.filter { it.pinned }.map(::label).toSet())
                assertEquals(name,strings(step.getJSONArray("displayed")),Planner.displayedRecent(state.recent).map(::label))
                assertEquals(name,initial.rules,state.rules)
                assertEquals(name,initial.wakes,state.wakes)
                assertEquals(name,initial.selection,state.selection)
                assertEquals("$name: history must not update OS monitoring",0,reflections)
            }
        }
    }

    @Test fun sharedOperations() {
        val fixture = JSONObject(javaClass.getResourceAsStream("/lock-operations.json")!!.bufferedReader().use { it.readText() })
        assertEquals(1, fixture.getInt("version"))
        val cases = fixture.getJSONArray("cases")
        assertTrue(cases.length()>0)
        val ids = mutableSetOf<String>()
        val epoch = 1_800_000_000_000L
        fun time(seconds: Double) = epoch + (seconds * 1000).toLong()
        for (i in 0 until cases.length()) {
            val scenario = cases.getJSONObject(i)
            val id = scenario.getString("id")
            assertTrue("duplicate scenario: $id", ids.add(id))
            val start = scenario.optDouble("start", 0.0)
            val rule = Rule(id="current", title=id, targets=Targets(apps=setOf("app.a")),
                schedule=LockSchedule.Single(time(start), time(start+scenario.getDouble("duration"))))
            var state = State(rules=listOf(rule),selection=rule.targets)
            var operationTime = epoch
            val operations = LockOperations(change={ command -> command(state).also { state=it } },
                reflect={ Result.success(Unit) },clock={ operationTime })
            val steps = scenario.getJSONArray("steps")
            assertTrue(id, steps.length()>0)
            for (index in 0 until steps.length()) {
                val step = steps.getJSONObject(index)
                val action = step.getString("action")
                val name = "$id/$index:$action"
                val now = time(step.getDouble("at"))
                operationTime = now
                val requestedId = step.optString("rule", rule.id)
                val occurrenceStart = time(step.optDouble("occurrenceStart", start))
                val original = state
                var result = "ok"
                try {
                    val requestedLock = ActiveLock(requestedId,rule.title,rule.targets,occurrenceStart,rule.single!!.end)
                    val outcome = when(action) {
                        "wake" -> operations.scheduleWake(requestedLock)
                        "cancel" -> operations.cancelWake(requestedLock)
                        "evaluate" -> null
                        "select" -> operations.selectTargets(Targets(apps=setOf("app.b")))
                        "create" -> operations.createSchedule { Rule(title="B", targets=Targets(apps=setOf("app.b")),
                            schedule=LockSchedule.Single(time(step.getDouble("start")),
                                time(step.getDouble("start")+step.getDouble("duration")))) }
                        "replace" -> operations.updateSchedule { rule.copy(schedule=LockSchedule.Single(
                            time(step.getDouble("start")), time(step.getDouble("start")+step.getDouble("duration")))) }
                        "delete" -> operations.deleteSchedule(rule.id)
                        else -> throw AssertionError("Unknown operation: $action")
                    }
                    if(outcome is OperationOutcome.Rejected) throw outcome.cause
                } catch (e: Exception) {
                    result = when(e.message) {
                        "wake_unavailable" -> "wakeUnavailable"
                        "wake_ended" -> "inactiveOccurrence"
                        "wake_missing" -> "noWakeRequest"
                        "overlap" -> "overlap"
                        "active_immutable" -> "activeImmutable"
                        "rule_not_found" -> "missingRule"
                        else -> "unexpected:$e"
                    }
                    assertEquals("$name: rejection must not mutate state", original, state)
                }
                assertEquals(name, step.getString("result"), result)
                assertEquals(name, step.getInt("ruleCount"), state.rules.size)
                if(step.has("selection")) assertEquals(name,
                    if(step.getString("selection")=="A") setOf("app.a") else setOf("app.b"), state.selection?.apps)
                if(action in listOf("wake", "cancel", "evaluate"))
                    assertEquals("$name: wake must not rewrite schedules", original.rules, state.rules)
                if(step.getString("result")=="ok" && action in listOf("replace", "create")) {
                    val saved = state.rules.single { if(action=="replace") it.id==rule.id else it.id!=rule.id }
                    assertEquals(name, time(step.getDouble("start")), saved.single!!.start)
                    assertEquals(name, time(step.getDouble("start")+step.getDouble("duration")), saved.single!!.end)
                    if(action=="create") assertEquals(name, setOf("app.b"), saved.targets.apps)
                }
                assertEquals(name, if(step.isNull("wakeAt")) null else time(step.getDouble("wakeAt")),
                    state.wakes.firstOrNull { it.ruleId==rule.id }?.wakesAt)
                assertEquals(name, step.getBoolean("active"), state.activeLocks(now).any { it.ruleId==rule.id })
            }
        }
    }

    @Test fun sharedWakeContract() {
        val rows = javaClass.getResourceAsStream("/wake-contract.tsv")!!.bufferedReader().readLines()
            .filter { it.isNotBlank() && !it.startsWith("#") }.map { it.split(' ') }
        assertTrue(rows.isNotEmpty())
        val start = 1_800_000_000_000L
        fun time(value: String) = start + value.toLong() * 1000
        for (c in rows) {
            val rule = Rule(id="current", title=c[0], targets=Targets(apps=setOf("app.a")),
                schedule=LockSchedule.Single(start, start + 7_200_000))
            val lock = ActiveLock(rule.id, rule.title, rule.targets, start, start + 7_200_000)
            val requests = if (c[2]=="-") emptyList() else
                listOf(WakeRequest(c[2], time(c[3]), time(c[4])))
            val state = State(rules=listOf(rule), wakes=requests)
            assertEquals(c[0], time(c[5]), state.effective(lock).end)
            assertEquals(c[0], c[6].toBoolean(), state.activeLocks(time(c[1])).any { it.ruleId==rule.id })
        }
    }

    @Test fun sharedContract() {
        val rows = javaClass.getResourceAsStream("/lock-contract.tsv")!!.bufferedReader().readLines()
            .filter { it.isNotBlank() && !it.startsWith("#") }.map { it.split(' ') }
        assertTrue(rows.isNotEmpty())
        for ((name, group) in rows.groupBy { it[0] }) {
            fun time(s: String) = Instant.parse(s).toEpochMilli()
            val now = time(group.first()[9])
            val rules = group.mapIndexed { index, c ->
                val minute = c[3].toInt(); val endMinute = c[4].toInt()
                Rule(id="$name-$index", title=name, targets=Targets(apps=setOf(c[1])),
                    schedule=if(c[2]=="-") LockSchedule.Single(time(c[7]),time(c[8])) else
                        LockSchedule.Weekly(c[2].split(',').map(String::toInt).toSet(),minute,endMinute,c[5]),
                    enabled=c[6].toBoolean())
            }
            val state = State(rules=rules)
            group.forEachIndexed { index, c ->
                val active = state.activeLocks(now).find { it.ruleId==rules[index].id }
                assertEquals(name, c[10]=="-", Planner.editable(state, rules[index], now))
                assertEquals(name, c[10].takeUnless { it=="-" }?.let(::time), active?.start)
                assertEquals(name, c[11].takeUnless { it=="-" }?.let(::time), active?.end)
            }
            for (target in group.map { it[1] }.toSet()+"unselected") {
                val end = group.filter { it[1]==target && it[11]!="-" }.maxOfOrNull { time(it[11]) }
                assertEquals("$name/$target", end, state.blockingLock(now,target)?.end)
            }
        }
    }
}
