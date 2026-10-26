package com.hiyozoo.bearlock

import java.net.IDN
import java.net.URI
import java.time.*
import java.util.UUID

data class Targets(val apps: Set<String> = emptySet(), val domains: Set<String> = emptySet(), val categories: Set<Int> = emptySet()) : java.io.Serializable {
    val empty get() = apps.isEmpty() && domains.isEmpty() && categories.isEmpty()
    val count get() = apps.size + domains.size + categories.size
}
sealed interface LockSchedule : java.io.Serializable {
    data class Single(val start: Long, val end: Long, val immediate: Boolean = false) : LockSchedule
    data class Weekly(val days: Set<Int>, val startMinute: Int, val endMinute: Int,
                      val zone: String = ZoneId.systemDefault().id) : LockSchedule {
        val durationMinutes get() = (endMinute - startMinute + 1439) % 1440 + 1
    }
}

data class Rule(
    val id: String = UUID.randomUUID().toString(), val title: String, val targets: Targets,
    val schedule: LockSchedule, val enabled: Boolean = true,
) {
    val single get() = schedule as? LockSchedule.Single
    val weekly get() = schedule as? LockSchedule.Weekly
    val recurring get() = schedule is LockSchedule.Weekly
    val durationMinutes get() = when(val value = schedule) {
        is LockSchedule.Single -> ((value.end - value.start) / 60_000).toInt()
        is LockSchedule.Weekly -> value.durationMinutes
    }
    fun nextOccurrence(now: Long): ActiveLock? = when(val value = schedule) {
        is LockSchedule.Single -> if(enabled && value.end > now) ActiveLock(id,title,targets,value.start,value.end) else null
        is LockSchedule.Weekly -> occurrences(now, now + 8 * Planner.DAY).firstOrNull()
    }
    fun occurrences(from: Long, until: Long): List<ActiveLock> {
        if (!enabled) return emptyList()
        when(val value = schedule) {
            is LockSchedule.Single -> return if (value.end > from && value.start < until)
                listOf(ActiveLock(id,title,targets,value.start,value.end)) else emptyList()
            is LockSchedule.Weekly -> {
                val tz = ZoneId.of(value.zone)
                var date = Instant.ofEpochMilli(from).atZone(tz).toLocalDate().minusDays(1)
                val last = Instant.ofEpochMilli(until).atZone(tz).toLocalDate()
                val result = mutableListOf<ActiveLock>()
                while (!date.isAfter(last)) {
                    if (date.dayOfWeek.value in value.days) {
                        val start = date.atStartOfDay().plusMinutes(value.startMinute.toLong()).atZone(tz).toInstant().toEpochMilli()
                        val endDay = date.plusDays(if(value.endMinute <= value.startMinute) 1 else 0)
                        val localEnd = endDay.atTime(value.endMinute / 60, value.endMinute % 60)
                        // Same nextTime policy as iOS for a missing end time during the DST gap.
                        val resolvedEnd = if(tz.rules.getValidOffsets(localEnd).isEmpty())
                            tz.rules.getTransition(localEnd).dateTimeAfter else localEnd
                        val end = resolvedEnd.atZone(tz).toInstant().toEpochMilli()
                        if(end > start && end > from && start < until) result.add(ActiveLock(id,title,targets,start,end))
                    }
                    date = date.plusDays(1)
                }
                return result
            }
        }
    }
}
/** A display/enforcement value derived from a rule, never persisted. */
data class ActiveLock(val ruleId: String, val title: String, val targets: Targets, val start: Long, val end: Long) {
    val key get() = "$ruleId:$start"
    fun active(now: Long) = start <= now && now < end
}
data class Recent(val targets: Targets, val usedAt: Long, val pinned: Boolean = false, val pinnedAt: Long? = null)
data class WakeRequest(val ruleId: String, val occurrenceStart: Long, val wakesAt: Long) {
    fun matches(lock: ActiveLock) = ruleId == lock.ruleId && occurrenceStart == lock.start
}
data class State(val rules: List<Rule> = emptyList(), val recent: List<Recent> = emptyList(), val wakes: List<WakeRequest> = emptyList(), val selection: Targets? = null) {
    fun scheduledRules(now: Long) = rules.filter { it.recurring || (!it.single!!.immediate && it.single!!.end > now) }
        .sortedBy { it.copy(enabled=true).nextOccurrence(now)?.start ?: Long.MAX_VALUE }
    fun wakeRequest(lock: ActiveLock) = wakes.firstOrNull { it.matches(lock) }
    fun effective(lock: ActiveLock): ActiveLock = lock.copy(end = wakeRequest(lock)?.wakesAt
        ?.takeIf { it >= lock.start && it < lock.end } ?: lock.end)
    fun activeLocks(now: Long): List<ActiveLock> = rules.flatMap { it.occurrences(now, now + 1) }
        .map { effective(it) }.filter { it.active(now) }.sortedBy { it.start }
    fun blockingLock(now: Long, app: String, category: Int = -1, host: String? = null): ActiveLock? =
        activeLocks(now).filter {
            app in it.targets.apps || (category >= 0 && category in it.targets.categories) ||
                (host != null && it.targets.domains.any { domain -> Domain.matches(host, domain) })
        }.maxByOrNull { it.end }
}

object Planner {
    fun selectTargets(state: State, targets: Targets, now: Long): State {
        require(!targets.empty) { "empty_targets" }
        require(state.activeLocks(now).isEmpty()) { "active_immutable" }
        return state.copy(selection=targets)
    }

    const val DAY = 86_400_000L
    const val WAKE_DELAY = 30 * 60_000L
    fun canScheduleFreeWake(lock: ActiveLock, now: Long) = lock.end-now>WAKE_DELAY
    fun scheduleWake(state: State, ruleId: String, occurrenceStart: Long, now: Long): State {
        val lock = state.rules.firstOrNull { it.id == ruleId }?.occurrences(now, now + 1)
            ?.firstOrNull { it.start == occurrenceStart } ?: error("wake_ended")
        require(state.effective(lock).active(now)) { "wake_ended" }
        if (state.wakeRequest(lock) != null) return state
        require(canScheduleFreeWake(lock,now)) { "wake_unavailable" }
        return state.copy(wakes = state.wakes + WakeRequest(ruleId, occurrenceStart, now + WAKE_DELAY))
    }
    fun cancelWake(state: State, ruleId: String, occurrenceStart: Long, now: Long): State {
        val lock = state.activeLocks(now).firstOrNull { it.ruleId == ruleId && it.start == occurrenceStart }
            ?: error("wake_ended")
        val request = state.wakeRequest(lock) ?: error("wake_missing")
        require(request.wakesAt > now) { "wake_ended" }
        return state.copy(wakes = state.wakes.filterNot { it == request })
    }
    fun editable(state: State, rule: Rule, now: Long) = rule.occurrences(now, now + 1)
        .none { state.effective(it).active(now) }
    fun scheduleEditable(state: State, rule: Rule, now: Long) = editable(state, rule, now) &&
        (rule.recurring || rule.single!!.start > now)
    fun save(state: State, rule: Rule, now: Long): State {
        require(!rule.targets.empty) { "empty_targets" }
        when(val schedule = rule.schedule) {
            is LockSchedule.Single -> require(schedule.end - schedule.start in 60_000..DAY) { "invalid_time" }
            is LockSchedule.Weekly -> {
                require(schedule.days.isNotEmpty() && schedule.days.all { it in 1..7 } &&
                    schedule.startMinute in 0..1439 && schedule.endMinute in 0..1439) { "invalid_time" }
                ZoneId.of(schedule.zone)
            }
        }
        require(rule.targets.domains.all { Domain.normalize(it) == it }) { "invalid_domain" }
        val current = state.copy(recent = trimRecent(state.recent))
        val previous = current.rules.find { it.id == rule.id }
        require(previous == null || editable(current, previous, now)) { "active_immutable" }
        require(previous == null || previous.recurring || previous.single!!.start > now) { "past_time" }
        require(rule.recurring || if (previous == null) rule.single!!.start >= now else rule.single!!.start > now) { "past_time" }
        val others = current.rules.filter { it.id != rule.id }
        require(overlappingRules(current,rule,now).isEmpty()) { "overlap" }
        val recent = if(previous != null) current.recent else
            listOf(Recent(rule.targets, now, current.recent.any { it.targets == rule.targets && it.pinned }, current.recent.find { it.targets == rule.targets }?.pinnedAt)) + current.recent.filter { it.targets != rule.targets }
        return current.copy(rules = others + rule, recent = trimRecent(recent))
    }
    fun overlappingRules(state: State, rule: Rule, now: Long): List<Rule> {
        if(!rule.enabled) return emptyList()
        return state.rules.filter { it.id != rule.id && it.enabled && (it.recurring || it.nextOccurrence(now)?.let { lock -> state.effective(lock).end > now } == true) }.filter { other ->
            if (rule.recurring && other.recurring) false else {
                val fixed = (if (rule.recurring) other else rule).single!!
                val candidate = if (rule.recurring) rule else other
                val fixedLock = if (rule.recurring) other.nextOccurrence(fixed.start) else rule.nextOccurrence(fixed.start)
                val effectiveFixed = fixedLock?.let { state.effective(it) }
                effectiveFixed != null && candidate.occurrences(fixed.start, fixed.end).map { state.effective(it) }
                    .any { it.start < effectiveFixed.end && effectiveFixed.start < it.end }
            }
        }
    }
    fun replace(state: State, rule: Rule, now: Long): State {
        val original = requireNotNull(state.rules.find { it.id == rule.id }) { "rule_not_found" }
        require(original.recurring == rule.recurring) { "invalid_time" }
        return save(state, rule, now)
    }
    fun delete(state: State, id: String, now: Long): State {
        val rule = state.rules.find { it.id == id } ?: return state
        require(rule.recurring || editable(state, rule, now)) { "active_immutable" }
        require(rule.recurring || rule.single!!.start > now) { "past_time" }
        return state.copy(rules = state.rules.filter { it.id != id }, wakes = state.wakes.filterNot { it.ruleId == id })
    }
    // Keep stored history; the three-item limit applies to display, as on iOS.
    fun trimRecent(items: List<Recent>): List<Recent> {
        var pins=0
        return items.distinctBy { it.targets }.map { item ->
            if(item.pinned && ++pins <= 3) item.copy(pinnedAt=item.pinnedAt ?: item.usedAt)
            else item.copy(pinned=false,pinnedAt=null)
        }
    }
    fun displayedRecent(items: List<Recent>): List<Recent> {
        val normalized=trimRecent(items)
        return (normalized.filter { it.pinned }.sortedBy { it.pinnedAt } + normalized.filterNot { it.pinned }.sortedByDescending { it.usedAt }).take(3)
    }
    fun pinRecent(items: List<Recent>, targets: Targets, pinned: Boolean, now: Long): List<Recent> {
        val normalized=trimRecent(items)
        require(!pinned || normalized.any { it.targets==targets && it.pinned } || normalized.count { it.pinned }<3) { "pin_limit" }
        return normalized.map { if(it.targets==targets) it.copy(pinned=pinned,pinnedAt=if(pinned) it.pinnedAt ?: now else null) else it }
    }
    fun deleteRecent(items: List<Recent>, targets: Targets): List<Recent> = items.filterNot { it.targets==targets }
    /** Future starts and requested wakes need an alarm; enforcement still checks wall time. */
    fun needsScheduledAlarm(state: State, now: Long): Boolean =
        state.rules.any { it.enabled && (it.recurring || it.single!!.start > now) } ||
            state.activeLocks(now).any { state.wakeRequest(it)?.wakesAt?.let { end -> end > now } == true }

    fun nextBoundary(state: State, now: Long): Long? = state.rules.flatMap {
        val occurrences = if(it.recurring) it.occurrences(now, now + 8 * DAY) else listOfNotNull(it.nextOccurrence(now))
        occurrences.flatMap { s -> listOf(s.start, state.effective(s).end) }
    }.filter { it > now }.minOrNull()
}
object Domain {
    fun normalize(input: String): String? = runCatching {
        val s = input.trim()
        require(s.isNotEmpty() && !s.any { it.isWhitespace() })
        val uri = URI(if (s.contains("://")) s else "https://$s")
        require(uri.scheme in listOf("http", "https") && uri.rawUserInfo == null && uri.port == -1)
        val host = (uri.host ?: uri.rawAuthority)?.trimEnd('.') ?: error("host")
        val ascii = IDN.toASCII(host, IDN.USE_STD3_ASCII_RULES).lowercase()
        require(ascii.length <= 253 && ascii.contains('.') && ascii.split('.').all { it.isNotEmpty() && it.length <= 63 })
        ascii
    }.getOrNull()
    fun matches(host: String, domain: String) = host == domain || host.endsWith(".$domain")
}
