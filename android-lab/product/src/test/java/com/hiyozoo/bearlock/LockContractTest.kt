package com.hiyozoo.bearlock

import org.junit.Assert.*
import org.junit.Test
import java.time.Instant

/** Both platforms consume the same hand-specified expectations, including DST edge cases. */
class LockContractTest {
    @Test fun sharedContract() {
        val rows = javaClass.getResourceAsStream("/lock-contract.tsv")!!.bufferedReader().readLines()
            .filter { it.isNotBlank() && !it.startsWith("#") }.map { it.split(' ') }
        assertEquals(22, rows.size)
        for ((name, group) in rows.groupBy { it[0] }) {
            fun time(s: String) = Instant.parse(s).toEpochMilli()
            val now = time(group.first()[9])
            val rules = group.mapIndexed { index, c ->
                val minute = c[3].toInt(); val endMinute = c[4].toInt()
                Rule(id="$name-$index", title=name, targets=Targets(apps=setOf(c[1])),
                    start=time(c[7]), end=time(c[8]),
                    days=if(c[2]=="-") emptySet() else c[2].split(',').map(String::toInt).toSet(),
                    minute=minute, durationMinutes=if(c[2]=="-") 60 else (endMinute-minute+1439)%1440+1,
                    zone=c[5], enabled=c[6].toBoolean())
            }
            val state = State(rules=rules)
            group.forEachIndexed { index, c ->
                val active = state.activeLocks(now).find { it.ruleId==rules[index].id }
                assertEquals(name, c[10]=="-", Planner.editable(rules[index], now))
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
