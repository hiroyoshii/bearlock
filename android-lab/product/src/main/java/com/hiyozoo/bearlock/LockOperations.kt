package com.hiyozoo.bearlock

/** A commit and its OS reflection are distinct outcomes. A failed reflection never replays a command. */
sealed interface OperationOutcome {
    data class Saved(val state: State, val reflection: Result<Unit>) : OperationOutcome
    data class Rejected(val cause: Exception) : OperationOutcome
}

/** Application entry for lock mutations. The repository owns the fresh-read/write lock. */
class LockOperations(
    private val change: ((State) -> State) -> State,
    private val reflect: () -> Result<Unit>,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    fun selectTargets(targets: Targets) = commit { state, now -> Planner.selectTargets(state, targets, now) }
    fun scheduleWake(lock: ActiveLock) = commit { state, now -> Planner.scheduleWake(state, lock.ruleId, lock.start, now) }
    fun cancelWake(lock: ActiveLock) = commit { state, now -> Planner.cancelWake(state, lock.ruleId, lock.start, now) }
    // Build relative starts inside the repository boundary, not when confirmation opens.
    fun createSchedule(make: (Long) -> Rule) = commit { state, now -> Planner.save(state, make(now), now) }
    fun updateSchedule(make: (Long) -> Rule) = commit { state, now -> Planner.replace(state, make(now), now) }
    fun deleteSchedule(id: String) = commit { state, now -> Planner.delete(state, id, now) }
    fun setRecentPinned(targets: Targets, pinned: Boolean) = commit(updateMonitoring=false) { state, now ->
        state.copy(recent=Planner.pinRecent(state.recent,targets,pinned,now))
    }
    fun deleteRecentTarget(targets: Targets) = commit(updateMonitoring=false) { state, _ ->
        state.copy(recent=Planner.deleteRecent(state.recent,targets))
    }
    fun retryReflection(): Result<Unit> = runCatching { reflect().getOrThrow() }

    private fun commit(updateMonitoring: Boolean = true, command: (State, Long) -> State): OperationOutcome {
        val saved = try { change { command(it, clock()) } }
            catch (e: Exception) { return OperationOutcome.Rejected(e) }
        return OperationOutcome.Saved(saved, if(updateMonitoring) retryReflection() else Result.success(Unit))
    }
}
