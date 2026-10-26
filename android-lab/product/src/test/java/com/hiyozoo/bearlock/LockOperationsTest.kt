package com.hiyozoo.bearlock

import org.junit.Assert.*
import org.junit.Test

class LockOperationsTest {
    private val original=Targets(apps=setOf("app.a"))
    private val changed=Targets(apps=setOf("app.b"))
    private val rule=Rule(id="a",title="A",targets=original,schedule=LockSchedule.Single(0,7_200_000))

    @Test fun historyOperationsNeverReflectAndPreserveRulesWakesAndSelection() {
        val initial=State(rules=listOf(rule),selection=original,recent=listOf(Recent(original,0)),
            wakes=listOf(WakeRequest(rule.id,0,1_800_000)))
        var state=initial
        val operations=LockOperations(change={ command -> command(state).also { state=it } },
            reflect={ throw AssertionError("History must not touch monitoring") },clock={ 1_000 })
        assertTrue(operations.setRecentPinned(original,true) is OperationOutcome.Saved)
        assertEquals(1_000L,state.recent.single().pinnedAt)
        assertTrue(operations.setRecentPinned(original,false) is OperationOutcome.Saved)
        assertFalse(state.recent.single().pinned)
        assertTrue(operations.deleteRecentTarget(original) is OperationOutcome.Saved)
        assertTrue(state.recent.isEmpty())
        assertEquals(initial.rules,state.rules)
        assertEquals(initial.wakes,state.wakes)
        assertEquals(initial.selection,state.selection)
    }

    @Test fun historyReadAndWriteFailuresNeverPublishOrReflect() {
        for(message in listOf("storage_error","write_failed")) for(action in listOf("pin","unpin","delete")) {
            val initial=State(rules=listOf(rule),selection=original,recent=listOf(Recent(original,0,
                pinned=action=="unpin",pinnedAt=if(action=="unpin") 0 else null)),wakes=listOf(WakeRequest(rule.id,0,1_800_000)))
            var state=initial
            val operations=LockOperations(change={ command ->
                if(message=="storage_error") error(message)
                command(state)
                error(message) // Refuse the write before publishing.
            },reflect={ throw AssertionError("History must not touch monitoring") },clock={ 1_000 })
            val outcome=if(action=="delete") operations.deleteRecentTarget(original) else operations.setRecentPinned(original,action=="pin")
            assertEquals(message,(outcome as OperationOutcome.Rejected).cause.message)
            assertEquals(initial,state)
        }
    }

    @Test fun historyPinLimitAndClockUseTheFreshCommitState() {
        var state=State(recent=listOf(Recent(original,0)))
        var now=0L
        val newPins=(1..3).map { Recent(Targets(apps=setOf("pinned.$it")),0,true,it.toLong()) }
        val operations=LockOperations(change={ command ->
            now=1_000
            state=state.copy(recent=state.recent+newPins)
            command(state).also { state=it }
        },reflect={ throw AssertionError("History must not touch monitoring") },clock={ now })
        val outcome=operations.setRecentPinned(original,true) as OperationOutcome.Rejected
        assertEquals("pin_limit",outcome.cause.message)
        assertFalse(state.recent.first().pinned)
        assertEquals(3,state.recent.count { it.pinned })
        var committed=State(recent=listOf(Recent(original,0)))
        now=0
        val delayed=LockOperations(change={ command -> now=2_000; command(committed).also { committed=it } },
            reflect={ throw AssertionError("History must not touch monitoring") },clock={ now })
        assertTrue(delayed.setRecentPinned(original,true) is OperationOutcome.Saved)
        assertEquals(2_000L,committed.recent.single().pinnedAt)
    }

    @Test fun scheduleCreateEditDeleteCommitBeforeReflectionAndRetryNeverReplays() {
        var state=State(selection=original)
        var commits=0
        var fail=true
        val operations=LockOperations(change={ command -> command(state).also { state=it; commits++ } },
            reflect={ if(fail) Result.failure(IllegalStateException("OS unavailable")) else Result.success(Unit) },clock={ 0 })
        val future=rule.copy(schedule=LockSchedule.Single(3_600_000,7_200_000))
        val replacement=future.copy(schedule=LockSchedule.Single(4_000_000,7_600_000))
        val commands=listOf<()->OperationOutcome>(
            { operations.createSchedule { future } },
            { operations.updateSchedule { replacement } },
            { operations.deleteSchedule(future.id) })
        for((index,command) in commands.withIndex()) {
            fail=true
            val outcome=command() as OperationOutcome.Saved
            assertTrue(outcome.reflection.isFailure)
            assertEquals(listOf(listOf(future),listOf(replacement),emptyList<Rule>())[index],state.rules)
            val saved=state
            fail=false
            assertTrue(operations.retryReflection().isSuccess)
            assertEquals(saved,state)
            assertEquals(index+1,commits)
            assertEquals(original,state.selection)
        }
    }

    @Test fun allScheduleStorageFailuresPreserveStateAndDoNotReflect() {
        val future=rule.copy(schedule=LockSchedule.Single(3_600_000,7_200_000))
        val originalState=State(rules=listOf(future),selection=original)
        for(message in listOf("storage_error","write_failed")) {
            var reflected=false
            val operations=LockOperations(change={ command ->
                if(message=="storage_error") error(message)
                command(originalState)
                error(message)
            },reflect={ reflected=true; Result.success(Unit) },clock={ 0 })
            val outcomes=listOf(
                operations.createSchedule { rule.copy(id="b",schedule=LockSchedule.Single(8_000_000,9_000_000)) },
                operations.updateSchedule { future.copy(title="changed") },
                operations.deleteSchedule(future.id))
            outcomes.forEach { assertEquals(message,(it as OperationOutcome.Rejected).cause.message) }
            assertFalse(reflected)
        }
    }

    @Test fun relativeCreateUsesCommitTimeAndChecksNewlyStoredConflict() {
        var now=0L
        var state=State(selection=original)
        var reflected=0
        val draft=EditorDraft(targets=changed,timing=DraftTiming.Later(delay=30,duration=60))
        val operations=LockOperations(change={ command ->
            now=60_000
            command(state).also { state=it }
        },reflect={ reflected++; Result.success(Unit) },clock={ now })
        val saved=operations.createSchedule { draft.makeRule(it,"Later") } as OperationOutcome.Saved
        assertEquals(1_860_000L,saved.state.rules.single().single!!.start)
        val originalState=state
        val rejected=operations.createSchedule { draft.makeRule(it,"Later") } as OperationOutcome.Rejected
        assertEquals("overlap",rejected.cause.message)
        assertEquals(originalState,state)
        assertEquals(1,reflected)
    }

    @Test fun staleScheduleEditorCannotEditOrDeleteAfterStartOrResurrectDeletedRule() {
        val future=rule.copy(schedule=LockSchedule.Single(1_000,7_200_000))
        var state=State(rules=listOf(future))
        var now=0L
        var reflected=false
        val operations=LockOperations(change={ command ->
            now=1_000
            command(state).also { state=it }
        },reflect={ reflected=true; Result.success(Unit) },clock={ now })
        assertEquals("active_immutable",(operations.updateSchedule { future } as OperationOutcome.Rejected).cause.message)
        assertEquals("active_immutable",(operations.deleteSchedule(future.id) as OperationOutcome.Rejected).cause.message)
        assertEquals(listOf(future),state.rules)
        state=State()
        assertEquals("rule_not_found",(operations.updateSchedule { future } as OperationOutcome.Rejected).cause.message)
        assertTrue(state.rules.isEmpty())
        assertFalse(reflected)
    }

    @Test fun activeRecurringDeletionKeepsAndroidImmediateRemovalAndOtherOccurrences() {
        val recurring=rule.copy(schedule=LockSchedule.Weekly(setOf(4),0,120,"UTC"))
        val other=rule.copy(id="other")
        var state=State(rules=listOf(recurring,other),wakes=listOf(
            WakeRequest(recurring.id,0,1_800_000),WakeRequest(other.id,0,1_800_000)))
        val operations=LockOperations(change={ command -> command(state).also { state=it } },
            reflect={ Result.success(Unit) },clock={ 0 })
        assertTrue(state.activeLocks(0).any { it.ruleId==recurring.id })
        assertTrue(operations.deleteSchedule(recurring.id) is OperationOutcome.Saved)
        assertEquals(listOf(other),state.rules)
        assertEquals(listOf(WakeRequest(other.id,0,1_800_000)),state.wakes)
    }

    @Test fun selectionRevalidatesClockAndFreshStateInsideCommit() {
        var now=0L
        var state=State(selection=original)
        var reflected=false
        val operations=LockOperations(change={ command ->
            now=1_000
            state=state.copy(rules=listOf(rule)) // A schedule started after the picker opened.
            command(state).also { state=it }
        },reflect={ reflected=true; Result.success(Unit) },clock={ now })
        val outcome=operations.selectTargets(changed) as OperationOutcome.Rejected
        assertEquals("active_immutable",outcome.cause.message)
        assertEquals(original,state.selection)
        assertFalse(reflected)
    }

    @Test fun selectionCommitsBeforeReflectionAndReflectionFailureIsNotARejectedSave() {
        var state=State(selection=original)
        var commits=0
        var fail=true
        val operations=LockOperations(change={ command -> command(state).also { state=it; commits++ } },
            reflect={ assertEquals(changed,state.selection); if(fail) error("OS unavailable") else Result.success(Unit) })
        val outcome=operations.selectTargets(changed) as OperationOutcome.Saved
        assertEquals(changed,outcome.state.selection)
        assertTrue(outcome.reflection.isFailure)
        fail=false
        assertTrue(operations.retryReflection().isSuccess)
        assertEquals(1,commits)
    }

    @Test fun storageFailureDoesNotReflectOrChangeSelection() {
        for(message in listOf("storage_error","write_failed")) {
            var state=State(selection=original)
            var reflected=false
            val operations=LockOperations(change={ command ->
                if(message=="storage_error") error(message)
                command(state) // A repository write fails before publishing the next state.
                error(message)
            },reflect={ reflected=true; Result.success(Unit) })
            assertEquals(message,(operations.selectTargets(changed) as OperationOutcome.Rejected).cause.message)
            assertEquals(original,state.selection)
            assertFalse(reflected)
        }
    }

    @Test fun freeWakeCommitCancelAndRetryPreserveTheSavedOccurrence() {
        var state=State(rules=listOf(rule))
        var now=0L
        var commits=0
        var fail=true
        val operations=LockOperations(change={ command -> command(state).also { state=it; commits++ } },
            reflect={ if(fail) Result.failure(IllegalStateException("OS unavailable")) else Result.success(Unit) },clock={ now })
        val lock=rule.nextOccurrence(now)!!
        assertTrue((operations.scheduleWake(lock) as OperationOutcome.Saved).reflection.isFailure)
        val saved=state
        now=60_000; fail=false
        assertTrue(operations.retryReflection().isSuccess)
        assertEquals(saved,state)
        assertEquals(1,commits)
        assertTrue((operations.cancelWake(lock) as OperationOutcome.Saved).reflection.isSuccess)
        assertTrue(state.wakes.isEmpty())
        assertEquals(rule,state.rules.single())
    }

    @Test fun staleWakeDialogNeverTransfersToTheCurrentRepresentative() {
        val old=rule.nextOccurrence(0)!!
        val current=rule.copy(id="b")
        var state=State(rules=listOf(current))
        var reflected=false
        val operations=LockOperations(change={ command -> command(state).also { state=it } },
            reflect={ reflected=true; Result.success(Unit) },clock={ 1_000 })
        for(outcome in listOf(operations.scheduleWake(old),operations.cancelWake(old))) {
            assertEquals("wake_ended",(outcome as OperationOutcome.Rejected).cause.message)
        }
        assertEquals(State(rules=listOf(current)),state)
        assertFalse(reflected)
    }
}
