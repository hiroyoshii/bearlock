package com.hiyozoo.bearlock

import java.net.IDN
import java.net.URI
import java.time.*
import java.util.UUID

data class Targets(val apps: Set<String> = emptySet(), val domains: Set<String> = emptySet(), val categories: Set<Int> = emptySet()) {
    val empty get() = apps.isEmpty() && domains.isEmpty() && categories.isEmpty()
    val count get() = apps.size + domains.size + categories.size
}
data class Rule(
    val id: String = UUID.randomUUID().toString(), val title: String, val targets: Targets,
    val start: Long, val end: Long, val days: Set<Int> = emptySet(),
    val minute: Int = 0, val durationMinutes: Int = 30, val zone: String = ZoneId.systemDefault().id, val enabled: Boolean = true,
) {
    val recurring get() = days.isNotEmpty()
    fun occurrences(from: Long, until: Long): List<ActiveLock> {
        if (!enabled) return emptyList()
        if (!recurring) return if (end > from && start < until) listOf(ActiveLock(id, title, targets, start, end)) else emptyList()
        val tz = ZoneId.of(zone)
        var date = Instant.ofEpochMilli(from).atZone(tz).toLocalDate().minusDays(1)
        val last = Instant.ofEpochMilli(until).atZone(tz).toLocalDate()
        val result = mutableListOf<ActiveLock>()
        while (!date.isAfter(last)) {
            if (date.dayOfWeek.value in days) {
                val s = date.atStartOfDay().plusMinutes(minute.toLong()).atZone(tz).toInstant().toEpochMilli()
                val endMinute = minute + durationMinutes
                val localEnd = date.plusDays((endMinute / 1440).toLong())
                    .atTime(LocalTime.of((endMinute % 1440) / 60, endMinute % 60))
                // Calendar's end-time policy on iOS is nextTime: a missing 02:30 ends at 03:00.
                val resolvedEnd = if (tz.rules.getValidOffsets(localEnd).isEmpty())
                    tz.rules.getTransition(localEnd).dateTimeAfter else localEnd
                val e = resolvedEnd.atZone(tz).toInstant().toEpochMilli()
                if (e > s && e > from && s < until) result.add(ActiveLock(id, title, targets, s, e))
            }
            date = date.plusDays(1)
        }
        return result
    }
}
/** A display/enforcement value derived from a rule, never persisted. */
data class ActiveLock(val ruleId: String, val title: String, val targets: Targets, val start: Long, val end: Long) {
    val key get() = "$ruleId:$start"
    fun active(now: Long) = start <= now && now < end
}
data class Recent(val targets: Targets, val usedAt: Long, val pinned: Boolean = false, val pinnedAt: Long? = null)
data class State(val rules: List<Rule> = emptyList(), val recent: List<Recent> = emptyList()) {
    fun activeLocks(now: Long): List<ActiveLock> = rules.flatMap { it.occurrences(now, now + 1) }.sortedBy { it.start }
    fun blockingLock(now: Long, app: String, category: Int = -1, host: String? = null): ActiveLock? =
        activeLocks(now).filter {
            app in it.targets.apps || (category >= 0 && category in it.targets.categories) ||
                (host != null && it.targets.domains.any { domain -> Domain.matches(host, domain) })
        }.maxByOrNull { it.end }
}

object Planner {
    const val DAY = 86_400_000L
    fun editable(rule: Rule, now: Long) = rule.occurrences(now, now + 1).isEmpty()
    fun save(state: State, rule: Rule, now: Long): State {
        require(!rule.targets.empty) { "empty_targets" }
        require(rule.durationMinutes in 1..1440 && rule.minute in 0..1439 && rule.days.all { it in 1..7 }) { "invalid_time" }
        require(rule.end - rule.start in 60_000..DAY) { "invalid_time" }
        ZoneId.of(rule.zone)
        require(rule.targets.domains.all { Domain.normalize(it) == it }) { "invalid_domain" }
        val current = state.copy(recent = trimRecent(state.recent))
        val previous = current.rules.find { it.id == rule.id }
        require(previous == null || editable(previous, now)) { "active_immutable" }
        require(previous == null || previous.recurring || previous.start > now) { "past_time" }
        require(rule.recurring || if (previous == null) rule.start >= now else rule.start > now) { "past_time" }
        val others = current.rules.filter { it.id != rule.id }
        require(!rule.enabled || others.filter { it.enabled && (it.recurring || it.end > now) }.none { other ->
            if (rule.recurring && other.recurring) false else {
                val fixed = if (rule.recurring) other else rule
                val candidate = if (rule.recurring) rule else other
                candidate.occurrences(fixed.start, fixed.end).isNotEmpty()
            }
        }) { "overlap" }
        val recent = if(previous != null) current.recent else
            listOf(Recent(rule.targets, now, current.recent.any { it.targets == rule.targets && it.pinned }, current.recent.find { it.targets == rule.targets }?.pinnedAt)) + current.recent.filter { it.targets != rule.targets }
        return current.copy(rules = others + rule, recent = trimRecent(recent))
    }
    fun replace(state: State, rule: Rule, now: Long): State {
        require(state.rules.any { it.id == rule.id }) { "rule_not_found" }
        return save(state, rule, now)
    }
    fun delete(state: State, id: String, now: Long): State {
        val rule = state.rules.find { it.id == id } ?: return state
        require(editable(rule, now)) { "active_immutable" }
        return state.copy(rules = state.rules.filter { it.id != id })
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
    /** Only future starts need an exact wakeup; active locks use wall-clock expiry. */
    fun needsScheduledAlarm(state: State, now: Long): Boolean =
        state.rules.any { it.enabled && (it.recurring || it.start > now) }

    fun nextBoundary(state: State, now: Long): Long? = state.rules.flatMap {
        if (!it.enabled) emptyList() else if (!it.recurring) listOf(it.start, it.end)
        else it.occurrences(now, now + 8 * DAY).flatMap { s -> listOf(s.start, s.end) }
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
