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
    fun occurrences(from: Long, until: Long): List<Session> {
        if (!enabled) return emptyList()
        if (!recurring) return if (end > from && start < until) listOf(Session(id, id, title, targets, start, end)) else emptyList()
        val tz = ZoneId.of(zone)
        var date = Instant.ofEpochMilli(from).atZone(tz).toLocalDate().minusDays(1)
        val last = Instant.ofEpochMilli(until).atZone(tz).toLocalDate()
        val result = mutableListOf<Session>()
        while (!date.isAfter(last)) {
            if (date.dayOfWeek.value in days) {
                val s = date.atStartOfDay().plusMinutes(minute.toLong()).atZone(tz).toInstant().toEpochMilli()
                val e = s + durationMinutes * 60_000L
                if (e > from && s < until && s >= start) result.add(Session("$id:$s", id, title, targets, s, e))
            }
            date = date.plusDays(1)
        }
        return result
    }
}
data class Session(val key: String, val ruleId: String, val title: String, val targets: Targets, val start: Long, val end: Long) {
    fun active(now: Long) = start <= now && now < end
}
data class Recent(val targets: Targets, val usedAt: Long, val pinned: Boolean = false)
data class State(val rules: List<Rule> = emptyList(), val sessions: List<Session> = emptyList(), val completed: Set<String> = emptySet(), val recent: List<Recent> = emptyList())

object Planner {
    const val DAY = 86_400_000L
    fun reconcile(state: State, now: Long): State {
        val ended = state.sessions.filter { it.end <= now }.map { it.key }
        val completed = state.completed + ended
        // Sessions are independent snapshots: editing a recurring parent cannot change an active child.
        val running = state.sessions.filter { it.end > now }.toMutableList()
        for (rule in state.rules) for (session in rule.occurrences(now, now + 1)) {
            if (session.active(now) && session.key !in completed && running.none { it.key == session.key }) running.add(session)
        }
        return state.copy(rules = state.rules.filter { it.recurring || it.end > now }, sessions = running, completed = completed)
    }
    fun save(state: State, rule: Rule, now: Long): State {
        require(!rule.targets.empty) { "empty_targets" }
        require(rule.durationMinutes in 1..1440 && rule.minute in 0..1439 && rule.days.all { it in 1..7 }) { "invalid_time" }
        require(rule.end - rule.start in 60_000..DAY) { "invalid_time" }
        ZoneId.of(rule.zone)
        require(rule.targets.domains.all { Domain.normalize(it) == it }) { "invalid_domain" }
        val current = reconcile(state, now)
        val previous = current.rules.find { it.id == rule.id }
        require(previous == null || previous.recurring || current.sessions.none { it.ruleId == rule.id }) { "active_immutable" }
        require(rule.recurring || rule.start >= now) { "past_time" }
        require(rule.start <= now + 366 * DAY) { "invalid_time" }
        val others = current.rules.filter { it.id != rule.id }
        // Weekly recurrences repeat forever. Check all seasonal timezone offsets plus one full year.
        val horizon = maxOf(now + 400 * DAY, rule.start + 400 * DAY, others.maxOfOrNull { it.start + 8 * DAY } ?: 0L)
        val candidates = rule.occurrences(now, horizon)
        val occupied = others.flatMap { it.occurrences(now, horizon) } + current.sessions
        require(candidates.none { a -> occupied.any { b ->
            // A persisted active occurrence supersedes the same occurrence of its edited parent.
            !(b.ruleId == rule.id && a.start == b.start) && a.start < b.end && b.start < a.end
        } }) { "overlap" }
        val recent = if(previous != null) current.recent else
            listOf(Recent(rule.targets, now, current.recent.any { it.targets == rule.targets && it.pinned })) + current.recent.filter { it.targets != rule.targets }
        return reconcile(current.copy(rules = others + rule, recent = trimRecent(recent)), now)
    }
    fun delete(state: State, id: String, now: Long): State {
        val current = reconcile(state, now)
        val rule = current.rules.find { it.id == id } ?: return current
        require(rule.recurring || current.sessions.none { it.ruleId == id }) { "active_immutable" }
        return current.copy(rules = current.rules.filter { it.id != id })
    }
    fun trimRecent(items: List<Recent>) = items.filter { it.pinned } + items.filterNot { it.pinned }.take(3)
    fun nextBoundary(state: State, now: Long): Long? = (state.sessions.map { it.end } + state.rules.flatMap {
        it.occurrences(now, now + 8 * DAY).flatMap { s -> listOf(s.start, s.end) }
    }).filter { it > now }.minOrNull()
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
