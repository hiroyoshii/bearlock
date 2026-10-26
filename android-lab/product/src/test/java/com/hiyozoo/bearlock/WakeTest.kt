package com.hiyozoo.bearlock

import org.junit.Assert.*
import org.junit.Test
import java.time.Instant

class WakeTest {
    @Test fun scheduleListRetainsStartedAndWokenReservationsButNotImmediateLocks() {
        val start=1_800_000_000_000L
        val scheduled=Rule(id="scheduled",title="Date & Time",targets=Targets(apps=setOf("app")),schedule=LockSchedule.Single(start,start+2*60*60_000L))
        val immediate=scheduled.copy(id="immediate",schedule=scheduled.single!!.copy(immediate=true))
        val state=Planner.scheduleWake(State(listOf(scheduled,immediate)),scheduled.id,start,start)
        assertEquals(listOf(scheduled),state.scheduledRules(start-1))
        assertEquals(listOf(scheduled),state.scheduledRules(start+1))
        assertFalse(Planner.scheduleEditable(state,scheduled,start+1))
        val deadline=start+Planner.WAKE_DELAY
        assertTrue(Planner.editable(state,scheduled,deadline))
        assertFalse(Planner.scheduleEditable(state,scheduled,deadline))
        assertThrows(IllegalArgumentException::class.java) { Planner.delete(state,scheduled.id,deadline) }
        assertEquals(listOf(scheduled),state.scheduledRules(deadline))
        assertTrue(state.scheduledRules(scheduled.single!!.end).isEmpty())
    }
    private val now = Instant.parse("2026-09-07T09:00:00Z").toEpochMilli()
    private val targets = Targets(apps = setOf("app.a"))
    private fun single(minutes: Int = 120) = Rule(title="Focus", targets=targets,
        schedule=LockSchedule.Single(now, now + minutes * 60_000L))
    private fun wake(state: State, rule: Rule, at: Long = now) = Planner.scheduleWake(state, rule.id, now, at)

    @Test fun thirtyMinuteBoundary() {
        for(minutes in listOf(1, 29, 30)) {
            val rule = single(minutes)
            assertThrows(IllegalArgumentException::class.java) { wake(State(listOf(rule)), rule) }
        }
        val rule=single(31)
        val state=wake(State(listOf(rule)),rule)
        assertEquals(now + Planner.WAKE_DELAY,state.activeLocks(now).single().end)
        assertTrue(state.activeLocks(now + Planner.WAKE_DELAY).isEmpty())
    }
    @Test fun resendingDoesNotExtendEvenWithLessThanThirtyMinutesRemaining() {
        val rule=single(31); val state=wake(State(listOf(rule)),rule)
        assertEquals(state,wake(state,rule,now+2*60_000))
    }
    @Test fun cancellationRestoresOriginalEndAndReschedulingUsesNewTime() {
        val rule=single(); val state=wake(State(listOf(rule)),rule)
        val cancelled=Planner.cancelWake(state,rule.id,now,now+60_000)
        assertEquals(rule.single!!.end,cancelled.activeLocks(now+60_000).single().end)
        assertEquals(now+60_000+Planner.WAKE_DELAY,wake(cancelled,rule,now+60_000).wakes.single().wakesAt)
        assertThrows(IllegalStateException::class.java) { Planner.cancelWake(state,rule.id,now,now+Planner.WAKE_DELAY) }
        assertTrue(state.activeLocks(now+Planner.WAKE_DELAY).isEmpty())
    }
    @Test fun originalEndAndExpiredRequestCannotRelockTheOccurrence() {
        val rule=single(); val state=wake(State(listOf(rule)),rule)
        assertTrue(state.activeLocks(now+Planner.WAKE_DELAY+1).isEmpty())
        assertTrue(state.activeLocks(rule.single!!.end).isEmpty())
        assertThrows(IllegalArgumentException::class.java) { wake(state,rule,now+Planner.WAKE_DELAY) }
    }
    @Test fun weeklyOnlyWakesThisOccurrenceAndOtherLockStillBlocks() {
        val first=Rule(title="A",targets=targets,schedule=LockSchedule.Weekly(setOf(1),540,720,"UTC"))
        val other=first.copy(id="other",title="B")
        val state=wake(State(listOf(first,other)),first)
        assertEquals(other.id,state.blockingLock(now+Planner.WAKE_DELAY,"app.a")!!.ruleId)
        assertEquals(2,state.activeLocks(now+7*Planner.DAY).size)
        assertEquals(now+7*Planner.DAY+3*60*60_000L,state.activeLocks(now+7*Planner.DAY).first().end)
    }
    @Test fun nextBoundaryUsesWakeAndCancelledWakeUsesOriginalEnd() {
        val rule=single(); val state=wake(State(listOf(rule)),rule)
        assertTrue(Planner.needsScheduledAlarm(state,now))
        assertEquals(now+Planner.WAKE_DELAY,Planner.nextBoundary(state,now))
        val cancelled=Planner.cancelWake(state,rule.id,now,now)
        assertFalse(Planner.needsScheduledAlarm(cancelled,now))
        assertEquals(rule.single!!.end,Planner.nextBoundary(cancelled,now))
        assertNull(Planner.nextBoundary(state,now+Planner.WAKE_DELAY))
    }
    @Test fun distantSingleStartStillRegistersAnAlarm() {
        val start=now+30*Planner.DAY
        val rule=single().copy(schedule=LockSchedule.Single(start,start+60_000))
        assertEquals(start,Planner.nextBoundary(State(listOf(rule)),now))
    }
    @Test fun relockAfterWakeDoesNotConflictWithOriginalInterval() {
        val rule=single(); val state=wake(State(listOf(rule)),rule)
        val start=now+Planner.WAKE_DELAY
        val next=single().copy(id="next",schedule=LockSchedule.Single(start,start+60_000))
        assertEquals(2,Planner.save(state,next,start).rules.size)
        assertThrows(IllegalArgumentException::class.java) {
            Planner.save(state,next.copy(schedule=LockSchedule.Single(start-1,start+60_000)),now)
        }
    }
    @Test fun relockAfterWeeklyWakeIsAllowedButNextWeekStillConflicts() {
        val rule=Rule(title="A",targets=targets,schedule=LockSchedule.Weekly(setOf(1),540,720,"UTC"))
        val state=wake(State(listOf(rule)),rule)
        val start=now+Planner.WAKE_DELAY
        assertEquals(2,Planner.save(state,single().copy(schedule=LockSchedule.Single(start,start+60_000)),start).rules.size)
        assertThrows(IllegalArgumentException::class.java) {
            Planner.save(state,single().copy(schedule=LockSchedule.Single(now+7*Planner.DAY,now+7*Planner.DAY+60_000)),now)
        }
    }
    @Test fun newWeeklyRuleDoesNotConflictWithAnAlreadyWokenSingle() {
        val rule=single(); val state=wake(State(listOf(rule)),rule)
        val repeating=Rule(title="New",targets=targets,schedule=LockSchedule.Weekly(setOf(1),540,720,"UTC"))
        assertEquals(2,Planner.save(state,repeating,now+Planner.WAKE_DELAY).rules.size)
    }
    @Test fun staleDialogCannotWakeAnotherRuleOrOccurrence() {
        val rule=single(); val state=State(listOf(rule))
        assertThrows(IllegalStateException::class.java) { Planner.scheduleWake(state,"gone",now,now) }
        assertThrows(IllegalStateException::class.java) { Planner.scheduleWake(state,rule.id,now-1,now) }
        assertThrows(IllegalStateException::class.java) { wake(state,rule,rule.single!!.end) }
    }
    @Test fun deletingRecurringRuleRemovesItsRequestOnly() {
        val a=Rule(title="A",targets=targets,schedule=LockSchedule.Weekly(setOf(1),540,720,"UTC"))
        val b=a.copy(id="b")
        val state=wake(wake(State(listOf(a,b)),a),b)
        val deleted=Planner.delete(state,a.id,now)
        assertEquals(listOf(b.id),deleted.wakes.map { it.ruleId })
        assertEquals(b.id,deleted.blockingLock(now,"app.a")!!.ruleId)
    }
    @Test fun weeklyBecomesEditableAtWakeWithoutRelockingOrChangingNextWeek() {
        val rule=Rule(title="A",targets=targets,schedule=LockSchedule.Weekly(setOf(1),540,720,"UTC"))
        val state=wake(State(listOf(rule)),rule)
        assertFalse(Planner.editable(state,rule,now+Planner.WAKE_DELAY-1))
        assertThrows(IllegalArgumentException::class.java) { Planner.replace(state,rule,now+Planner.WAKE_DELAY-1) }
        assertTrue(Planner.editable(state,rule,now+Planner.WAKE_DELAY))
        val edited=Planner.replace(state,rule.copy(schedule=rule.weekly!!.copy(endMinute=780)),now+Planner.WAKE_DELAY)
        assertEquals(state.wakes,edited.wakes)
        assertTrue(edited.activeLocks(now+Planner.WAKE_DELAY).isEmpty())
        assertEquals(now+7*Planner.DAY+4*60*60_000L,edited.activeLocks(now+7*Planner.DAY).single().end)
    }
    @Test fun wallClockAndTimezoneSemanticsPreserveSavedDeadline() {
        val rule=single(); val state=wake(State(listOf(rule)),rule)
        assertEquals(now+Planner.WAKE_DELAY,state.activeLocks(now+60_000).single().end)
        assertTrue(state.activeLocks(now+Planner.WAKE_DELAY).isEmpty())
        assertEquals(now+Planner.WAKE_DELAY,state.activeLocks(now).single().end)
        val previous=java.util.TimeZone.getDefault()
        try {
            java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("Asia/Tokyo"))
            assertEquals(now+Planner.WAKE_DELAY,state.activeLocks(now).single().end)
        } finally { java.util.TimeZone.setDefault(previous) }
    }
}
