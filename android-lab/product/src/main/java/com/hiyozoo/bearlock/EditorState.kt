package com.hiyozoo.bearlock

import java.io.Serializable
import java.time.ZoneId

sealed interface DraftTiming : Serializable {
    data class Now(val duration: Int = 120) : DraftTiming
    data class Later(val delay: Int = 30, val duration: Int = 120) : DraftTiming
    data class Fixed(val start: Long, val duration: Int = 120) : DraftTiming
    data class Weekly(val days: Set<Int> = setOf(1,2,3,4,5), val start: Int = 1380,
                      val end: Int = 420, val zone: String = ZoneId.systemDefault().id) : DraftTiming
}

private val DraftTiming.singleDuration: Int? get() = when(this) {
    is DraftTiming.Now -> duration
    is DraftTiming.Later -> duration
    is DraftTiming.Fixed -> duration
    is DraftTiming.Weekly -> null
}

enum class ComposerMode { NOW, LATER, FIXED, WEEKLY }

/** Saved-rule identity and the editable draft have separate roles. No saved Rule snapshot. */
data class EditorDraft(val originalID: String? = null, var targets: Targets = Targets(),
                       var timing: DraftTiming = DraftTiming.Now(), var enabled: Boolean = true) : Serializable {
    // Unselected tabs retain input only for this editing session. The active timing is never duplicated.
    private val inactiveTimings = mutableMapOf<ComposerMode, DraftTiming>()
    val mode get() = when(timing) {
        is DraftTiming.Now -> ComposerMode.NOW
        is DraftTiming.Later -> ComposerMode.LATER
        is DraftTiming.Fixed -> ComposerMode.FIXED
        is DraftTiming.Weekly -> ComposerMode.WEEKLY
    }
    fun chooseMode(mode: ComposerMode, now: Long) {
        check(originalID == null) { "Cannot change an existing schedule's type" }
        if(mode == this.mode) return
        val minutes = timing.singleDuration ?: inactiveTimings.values.lastOrNull { it.singleDuration != null }?.singleDuration ?: 120
        inactiveTimings[this.mode] = timing
        timing = inactiveTimings.remove(mode) ?: when(mode) {
            ComposerMode.NOW -> DraftTiming.Now(minutes)
            ComposerMode.LATER -> DraftTiming.Later(duration=minutes)
            ComposerMode.FIXED -> DraftTiming.Fixed(now+30*60_000L,minutes)
            ComposerMode.WEEKLY -> DraftTiming.Weekly()
        }
        if(timing !is DraftTiming.Weekly) duration = minutes
    }
    var duration: Int
        get() = when(val t=timing) {
            is DraftTiming.Now -> t.duration
            is DraftTiming.Later -> t.duration
            is DraftTiming.Fixed -> t.duration
            is DraftTiming.Weekly -> (t.end-t.start+1439)%1440+1
        }
        set(value) { timing=when(val t=timing) {
            is DraftTiming.Now -> t.copy(duration=value)
            is DraftTiming.Later -> t.copy(duration=value)
            is DraftTiming.Fixed -> t.copy(duration=value)
            is DraftTiming.Weekly -> error("Weekly schedules use wall times")
        } }
    var delay: Int
        get() = (timing as DraftTiming.Later).delay
        set(value) { timing=(timing as DraftTiming.Later).copy(delay=value) }
    var at: Long
        get() = (timing as DraftTiming.Fixed).start
        set(value) { timing=(timing as DraftTiming.Fixed).copy(start=value) }
    var days: Set<Int>
        get() = (timing as DraftTiming.Weekly).days
        set(value) { timing=(timing as DraftTiming.Weekly).copy(days=value) }
    var repeatStart: Int
        get() = (timing as DraftTiming.Weekly).start
        set(value) { timing=(timing as DraftTiming.Weekly).copy(start=value) }
    var repeatEnd: Int
        get() = (timing as DraftTiming.Weekly).end
        set(value) { timing=(timing as DraftTiming.Weekly).copy(end=value) }

    fun canSubmit(now: Long) = !targets.empty && runCatching { makeRule(now,"") }.isSuccess
    fun makeRule(now: Long, title: String): Rule {
        val schedule = when(val t=timing) {
            is DraftTiming.Now -> LockSchedule.Single(now,now+t.duration*60_000L,immediate=true)
            is DraftTiming.Later -> {
                require(t.delay in 5..240) { "invalid_time" }
                val start=now+t.delay*60_000L
                LockSchedule.Single(start,start+t.duration*60_000L)
            }
            is DraftTiming.Fixed -> {
                require(t.start>now) { "past_time" }
                LockSchedule.Single(t.start,t.start+t.duration*60_000L)
            }
            is DraftTiming.Weekly -> LockSchedule.Weekly(t.days,t.start,t.end,t.zone)
        }
        require(if(schedule is LockSchedule.Single) duration in 15..720 else days.isNotEmpty()) { "invalid_time" }
        return Rule(id=originalID ?: java.util.UUID.randomUUID().toString(),title=title,targets=targets,schedule=schedule,enabled=enabled)
    }
    companion object {
        fun editing(rule: Rule) = EditorDraft(rule.id,rule.targets,when(val t=rule.schedule) {
            is LockSchedule.Single -> DraftTiming.Fixed(t.start,rule.durationMinutes)
            is LockSchedule.Weekly -> DraftTiming.Weekly(t.days,t.startMinute,t.endMinute,t.zone)
        },rule.enabled)
    }
}

/** A return destination exists only while the corresponding flow is open. */
sealed class Route : Serializable {
    data object Home : Route()
    data object Setup : Route()
    data object Editor : Route()
    data object Settings : Route()
    data class Licenses(val entry: Int? = null) : Route()
    data object Diagnostics : Route()
    data object Support : Route()
    data object Schedules : Route()
    data object Fixture : Route()
    data class Picker(val returnTo: Route, val original: Targets) : Route()
    data class Permissions(val returnTo: Route, val action: PermissionReturn) : Route()
    val page: String get() = when(this) {
        Home -> "home"; Setup -> "setup"; Editor -> "compose"; Settings -> "settings"
        Support -> "support"; Diagnostics -> "diagnostics"; Schedules -> "schedules"; Fixture -> "fixture"
        is Picker -> "targets"; is Permissions -> "permissions"
        is Licenses -> "licenses"
    }
}
enum class PermissionReturn { BACK, CONFIRM }
