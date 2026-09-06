package com.hiyozoo.bearlock

import org.junit.Assert.*
import org.junit.Test
import java.time.Instant

class PlannerTest {
    private val now=Instant.parse("2026-09-07T09:00:00Z").toEpochMilli() // Monday
    private val target=Targets(apps=setOf("app.a","app.b"))
    private fun rule(start: Long=now,end: Long=start+60_000)=Rule(title="Focus",targets=target,start=start,end=end,zone="UTC")
    @Test fun exactEndAndMultipleTargets() {
        val s=Planner.save(State(),rule(),now)
        assertEquals(2,s.sessions.single().targets.apps.size)
        assertTrue(s.sessions.single().active(now))
        assertFalse(s.sessions.single().active(now+60_000))
        assertTrue(Planner.reconcile(s,now+60_000).sessions.isEmpty())
    }
    @Test fun adjacentAllowedOverlappingRejectedWithoutMutation() {
        val s=Planner.save(State(),rule(now+60_000,now+120_000),now)
        assertEquals(2,Planner.save(s,rule(now+120_000,now+180_000),now).rules.size)
        assertThrows(IllegalArgumentException::class.java) { Planner.save(s,rule(now+90_000,now+150_000),now) }
        assertEquals(1,s.rules.size)
    }
    @Test fun activeCannotBeEditedOrDeleted() {
        val r=rule(); val s=Planner.save(State(),r,now)
        assertThrows(IllegalArgumentException::class.java) { Planner.delete(s,r.id,now+1) }
        assertThrows(IllegalArgumentException::class.java) { Planner.save(s,r.copy(end=now+120_000),now+1) }
    }
    @Test fun pendingCanBeEditedAndDeleted() {
        val r=rule(now+60_000); val s=Planner.save(State(),r,now)
        val edited=Planner.save(s,r.copy(start=now+120_000,end=now+180_000),now)
        assertEquals(now+120_000,edited.rules.single().start)
        assertTrue(Planner.delete(edited,r.id,now).rules.isEmpty())
    }
    @Test fun editingRecurringParentPreservesActiveSnapshot() {
        val r=rule().copy(days=setOf(1),minute=9*60,durationMinutes=30)
        val s=Planner.save(State(),r,now)
        val changed=Planner.save(s,r.copy(targets=Targets(apps=setOf("new")),durationMinutes=60),now+1)
        assertEquals(target,changed.sessions.single().targets)
        assertEquals(now+30*60_000,changed.sessions.single().end)
        assertEquals(setOf("new"),changed.rules.single().targets.apps)
        assertEquals(s.sessions,Planner.delete(changed,r.id,now+1).sessions)
    }
    @Test fun dailyCrossMidnightAndDstUseSavedZone() {
        val r=rule().copy(days=setOf(1),minute=23*60+30,durationMinutes=90)
        val s=r.occurrences(now,now+Planner.DAY).single()
        assertEquals(Instant.parse("2026-09-08T01:00:00Z").toEpochMilli(),s.end)
        val spring=Instant.parse("2026-03-08T00:00:00Z").toEpochMilli()
        val dst=r.copy(start=spring,end=spring+60_000,days=setOf(7),minute=150,zone="America/New_York")
        assertEquals(Instant.parse("2026-03-08T07:30:00Z").toEpochMilli(),dst.occurrences(spring,spring+Planner.DAY).single().start)
    }
    @Test fun futureRecurringConflictRejected() {
        val r=rule().copy(days=setOf(2),minute=540,durationMinutes=30)
        val s=Planner.save(State(),r,now)
        assertThrows(IllegalArgumentException::class.java) { Planner.save(s,rule(now+Planner.DAY,now+Planner.DAY+60_000),now) }
    }
    @Test fun missedExpiredOccurrenceDoesNotCreateLock() {
        val r=rule().copy(days=setOf(1),minute=540,durationMinutes=30)
        assertTrue(Planner.reconcile(State(rules=listOf(r)),now+31*60_000).sessions.isEmpty())
    }
    @Test fun endedSessionDoesNotReplayOnClockRollback() {
        val s=Planner.save(State(),rule(),now)
        val ended=Planner.reconcile(s,now+60_000)
        assertTrue(Planner.reconcile(ended,now+10_000).sessions.isEmpty())
    }
    @Test fun recentKeepsThreePlusPins() {
        val recent=(0..6).map { Recent(Targets(apps=setOf("app.$it")),now-it,it==6) }
        val trimmed=Planner.trimRecent(recent)
        assertEquals(4,trimmed.size); assertTrue(trimmed.first().pinned)
    }
    @Test fun invalidEmptyOrLongLockRejected() {
        assertThrows(IllegalArgumentException::class.java) { Planner.save(State(),rule().copy(targets=Targets()),now) }
        assertThrows(IllegalArgumentException::class.java) { Planner.save(State(),rule(end=now+Planner.DAY+1),now) }
    }
    @Test fun disablingRecurringPreservesActiveAndSkipsFutureBoundaries() {
        val r=rule().copy(days=setOf(1),minute=540,durationMinutes=30)
        val active=Planner.save(State(),r,now)
        val off=Planner.save(active,r.copy(enabled=false),now+1)
        assertEquals(active.sessions,off.sessions)
        assertEquals(now+30*60_000,Planner.nextBoundary(off,now+1))
        val ended=Planner.reconcile(off,now+31*60_000)
        assertNull(Planner.nextBoundary(ended,now+31*60_000))
        assertTrue(Planner.reconcile(ended,now+7*Planner.DAY).sessions.isEmpty())
    }
    @Test fun reenableRecurringRechecksConflicts() {
        val r=rule().copy(days=setOf(2),minute=540,durationMinutes=30,enabled=false)
        val disabled=Planner.save(State(),r,now)
        val occupied=Planner.save(disabled,rule(now+Planner.DAY),now)
        assertThrows(IllegalArgumentException::class.java) { Planner.save(occupied,r.copy(enabled=true),now) }
        val enabled=Planner.save(disabled,r.copy(enabled=true),now)
        assertEquals(now+Planner.DAY,Planner.nextBoundary(enabled,now))
    }
    @Test fun domainMatchingIsBoundaryAware() {
        assertEquals("example.com",Domain.normalize("https://Example.com/path?q=test"))
        assertTrue(Domain.matches("a.example.com","example.com"))
        assertFalse(Domain.matches("notexample.com","example.com"))
        assertFalse(Domain.matches("example.com.evil.test","example.com"))
        assertNull(Domain.normalize("https://user@example.com"))
        assertNull(Domain.normalize("not a domain"))
        assertNull(Domain.normalize("https://example.com:444"))
        assertEquals("xn--r8jz45g.xn--zckzah",Domain.normalize("例え.テスト"))
    }
}
