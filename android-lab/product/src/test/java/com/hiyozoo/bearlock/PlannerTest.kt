package com.hiyozoo.bearlock

import org.junit.Assert.*
import org.junit.Test
import java.time.Instant

class PlannerTest {
    private val now=Instant.parse("2026-09-07T09:00:00Z").toEpochMilli() // Monday
    private val target=Targets(apps=setOf("app.a","app.b"))
    private fun rule(start: Long=now,end: Long=start+60_000)=Rule(title="Focus",targets=target,schedule=LockSchedule.Single(start,end))
    private fun weekly(days: Set<Int>,minute: Int,durationMinutes: Int,enabled: Boolean=true) =
        Rule(title="Focus",targets=target,schedule=LockSchedule.Weekly(days,minute,(minute+durationMinutes)%1440,"UTC"),enabled=enabled)
    @Test fun immediateExpiryDoesNotRequireScheduledWakeup() {
        val state = Planner.save(State(), rule(), now)
        assertFalse(Planner.needsScheduledAlarm(state, now))
        assertEquals(now + 60_000, Planner.nextBoundary(state, now))
        assertFalse(state.activeLocks(now).single().active(now + 60_000))
        assertTrue(state.activeLocks(now + 60_000).isEmpty())
    }
    @Test fun onlyEnabledFutureOrRecurringRulesNeedScheduledWakeup() {
        val future = rule(now + 60_000)
        assertTrue(Planner.needsScheduledAlarm(State(rules=listOf(future)), now))
        assertFalse(Planner.needsScheduledAlarm(State(rules=listOf(future.copy(enabled=false))), now))
        val repeating = weekly(days=setOf(1), minute=540, durationMinutes=1)
        assertTrue(Planner.needsScheduledAlarm(State(rules=listOf(repeating)), now))
        assertFalse(Planner.needsScheduledAlarm(State(rules=listOf(repeating.copy(enabled=false))), now))
    }
    @Test fun exactEndAndMultipleTargets() {
        val s=Planner.save(State(),rule(),now)
        assertEquals(2,s.activeLocks(now).single().targets.apps.size)
        assertTrue(s.activeLocks(now).single().active(now))
        assertFalse(s.activeLocks(now).single().active(now+60_000))
        assertTrue(s.activeLocks(now+60_000).isEmpty())
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
        assertThrows(IllegalArgumentException::class.java) { Planner.save(s,r.copy(schedule=r.single!!.copy(end=now+120_000)),now+1) }
    }
    @Test fun pendingCanBeEditedAndDeleted() {
        val r=rule(now+60_000); val s=Planner.save(State(),r,now)
        val edited=Planner.save(s,r.copy(schedule=LockSchedule.Single(now+120_000,now+180_000)),now)
        assertEquals(now+120_000,edited.rules.single().single!!.start)
        assertTrue(Planner.delete(edited,r.id,now).rules.isEmpty())
    }
    @Test fun activeRecurringCannotBeEditedOrDisabledButCanBeDeleted() {
        val r=weekly(days=setOf(1),minute=9*60,durationMinutes=30)
        val s=Planner.save(State(),r,now)
        for (draft in listOf(r.copy(targets=Targets(apps=setOf("new"))),r.copy(enabled=false))) {
            assertThrows(IllegalArgumentException::class.java) { Planner.replace(s,draft,now+1) }
        }
        assertTrue(Planner.delete(s,r.id,now+1).rules.isEmpty())
        assertEquals(target,s.activeLocks(now+1).single().targets)
        assertTrue(Planner.delete(s,r.id,now+30*60_000).rules.isEmpty())
    }
    @Test fun deletingAllDayRepeatPreservesOtherRuleThenReleases() {
        val a=weekly(days=(1..7).toSet(),minute=540,durationMinutes=1440)
        val b=a.copy(id="other")
        val both=Planner.save(Planner.save(State(),a,now),b,now)
        val one=Planner.delete(both,a.id,now)
        assertEquals(listOf(b),one.rules)
        assertNotNull(one.blockingLock(now,"app.a"))
        val none=Planner.delete(one,b.id,now)
        assertTrue(none.rules.isEmpty())
        assertNull(none.blockingLock(now,"app.a"))
        assertNull(Planner.nextBoundary(none,now))
        assertTrue(none.activeLocks(now+Planner.DAY).isEmpty())
    }
    @Test fun dailyCrossMidnightAndDstUseSavedZone() {
        val r=weekly(days=setOf(1),minute=23*60+30,durationMinutes=90)
        val s=r.occurrences(now,now+Planner.DAY).single()
        assertEquals(Instant.parse("2026-09-08T01:00:00Z").toEpochMilli(),s.end)
        val spring=Instant.parse("2026-03-08T00:00:00Z").toEpochMilli()
        val dst=r.copy(schedule=LockSchedule.Weekly(setOf(7),150,240,"America/New_York"))
        assertEquals(Instant.parse("2026-03-08T07:30:00Z").toEpochMilli(),dst.occurrences(spring,spring+Planner.DAY).single().start)
    }
    @Test fun distantSingleHasBoundaryWithoutArtificialYearLimit() {
        val future=rule(now+400*Planner.DAY)
        val state=Planner.save(State(),future,now)
        assertEquals(future.single!!.start,Planner.nextBoundary(state,now))
        assertEquals(future.single!!.end,Planner.nextBoundary(state,future.single!!.start))
        assertNull(Planner.nextBoundary(state,future.single!!.end))
    }
    @Test fun futureRecurringConflictRejected() {
        val r=weekly(days=setOf(2),minute=540,durationMinutes=30)
        val s=Planner.save(State(),r,now)
        assertThrows(IllegalArgumentException::class.java) { Planner.save(s,rule(now+Planner.DAY,now+Planner.DAY+60_000),now) }
    }
    @Test fun missedExpiredOccurrenceDoesNotCreateLock() {
        val r=weekly(days=setOf(1),minute=540,durationMinutes=30)
        assertTrue(State(rules=listOf(r)).activeLocks(now+31*60_000).isEmpty())
    }
    @Test fun clockRollbackReevaluatesRulesWithoutCompletionHistory() {
        val s=Planner.save(State(),rule(),now)
        assertTrue(s.activeLocks(now+60_000).isEmpty())
        assertEquals(1,s.activeLocks(now+10_000).size)
    }
    @Test fun recentRecordsConfirmedCreationButNotEditing() {
        val r=rule(now+60_000)
        val s=Planner.save(State(),r,now)
        assertEquals(listOf(Recent(target,now)),s.recent)
        val edited=Planner.save(s,r.copy(schedule=r.single!!.copy(end=r.single!!.end+60_000)),now+1)
        assertEquals(s.recent,edited.recent)
        val next=Planner.save(edited,rule(now+180_000),now+2)
        assertEquals(listOf(Recent(target,now+2)),next.recent)
    }
    @Test fun repeatedUsePreservesPinAndRejectedLockPreservesHistory() {
        val original=State(recent=listOf(Recent(target,now-1,true)))
        val s=Planner.save(original,rule(),now)
        assertEquals(listOf(Recent(target,now,true,now-1)),s.recent)
        assertThrows(IllegalArgumentException::class.java) { Planner.save(s,rule().copy(targets=Targets(apps=setOf("other"))),now) }
        assertEquals(listOf(Recent(target,now,true,now-1)),s.recent)
    }
    @Test fun recentDisplaysThreeIncludingPinsWithoutDeletingHistory() {
        val recent=(0..6).map { Recent(Targets(apps=setOf("app.$it")),now-it,it==6) }
        val saved=Planner.trimRecent(recent)
        assertEquals(7,saved.size)
        val displayed=Planner.displayedRecent(saved)
        assertEquals(3,displayed.size); assertTrue(displayed.first().pinned)
        assertEquals(listOf("app.6","app.0","app.1"),displayed.map { it.targets.apps.single() })
    }
    @Test fun pinLimitAndOrderSurviveReuse() {
        val items=(0..3).map { Recent(Targets(apps=setOf("app.$it")),now-it) }
        var pinned=items
        for(i in 0..2) pinned=Planner.pinRecent(pinned,items[i].targets,true,now+i)
        val full=pinned
        assertThrows(IllegalArgumentException::class.java) { Planner.pinRecent(full,items[3].targets,true,now+3) }
        val reused=full.map { if(it.targets==items[2].targets) it.copy(usedAt=now+99) else it }
        assertEquals(listOf(items[0].targets,items[1].targets,items[2].targets),Planner.displayedRecent(reused).map { it.targets })
        val unpinned=Planner.pinRecent(full,items[0].targets,false,now+4)
        assertEquals(3,Planner.pinRecent(unpinned,items[3].targets,true,now+5).count { it.pinned })
    }
    @Test fun legacyExcessPinsMigrateWithoutLosingSelections() {
        val items=(0..5).map { Recent(Targets(apps=setOf("app.$it")),now-it,true) }
        val normalized=Planner.trimRecent(items)
        assertEquals(6,normalized.size); assertEquals(3,normalized.count { it.pinned })
        assertEquals(items.map { it.targets },normalized.map { it.targets })
        assertEquals(normalized,Planner.trimRecent(normalized))
    }
    @Test fun invalidEmptyOrLongLockRejected() {
        assertThrows(IllegalArgumentException::class.java) { Planner.save(State(),rule().copy(targets=Targets()),now) }
        assertThrows(IllegalArgumentException::class.java) { Planner.save(State(),rule(end=now+Planner.DAY+1),now) }
    }
    @Test fun disabledRecurringHasNoActiveLockOrFutureBoundary() {
        val r=weekly(days=setOf(1),minute=540,durationMinutes=30,enabled=false)
        val off=Planner.save(State(),r,now)
        assertTrue(off.activeLocks(now).isEmpty())
        assertNull(Planner.nextBoundary(off,now))
        assertTrue(off.activeLocks(now+7*Planner.DAY).isEmpty())
    }
    @Test fun overlappingRepeatsRemainBlockedUntilLatestMatchingDeadline() {
        val a=weekly(days=setOf(1),minute=540,durationMinutes=30)
        val b=a.copy(id="other",schedule=a.weekly!!.copy(endMinute=600))
        val state=Planner.save(Planner.save(State(),a,now),b,now)
        assertEquals(now+60*60_000,state.blockingLock(now,"app.a")!!.end)
        assertEquals(now+60*60_000,state.blockingLock(now+30*60_000,"app.a")!!.end)
        assertNull(state.blockingLock(now+60*60_000,"app.a"))
    }
    @Test fun onlyMatchingAppCategoryOrDomainContributesToDeadline() {
        val app=rule(end=now+60_000)
        val category=rule(end=now+120_000).copy(targets=Targets(categories=setOf(3)))
        val domain=rule(end=now+180_000).copy(targets=Targets(domains=setOf("example.com")))
        val unrelated=rule(end=now+240_000).copy(targets=Targets(apps=setOf("other")))
        val state=State(rules=listOf(app,category,domain,unrelated))
        assertEquals(app.single!!.end,state.blockingLock(now,"app.a")!!.end)
        assertEquals(category.single!!.end,state.blockingLock(now,"app.a",3)!!.end)
        assertEquals(domain.single!!.end,state.blockingLock(now,"browser",3,"sub.example.com")!!.end)
        assertNull(state.blockingLock(now,"browser",-1,"notexample.com"))
        assertNull(state.blockingLock(domain.single!!.end,"browser",3,"example.com"))
    }
    @Test fun staleEditorCannotResurrectDeletedRule() {
        val r=rule(now+60_000)
        val state=Planner.delete(Planner.save(State(),r,now),r.id,now)
        assertThrows(IllegalArgumentException::class.java) { Planner.replace(state,r,now) }
    }
    @Test fun expiredSingleDoesNotConflictWithFutureRepeat() {
        val old=rule(now-7*Planner.DAY)
        val r=weekly(days=setOf(1),minute=540,durationMinutes=30)
        assertEquals(2,Planner.save(State(rules=listOf(old)),r,now).rules.size)
    }
    @Test fun reenableRecurringRechecksConflicts() {
        val r=weekly(days=setOf(2),minute=540,durationMinutes=30,enabled=false)
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
