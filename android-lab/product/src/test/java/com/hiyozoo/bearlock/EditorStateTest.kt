package com.hiyozoo.bearlock

import org.junit.Assert.*
import org.junit.Test
import java.io.*

class EditorStateTest {
    private val now = 1_800_000_000_000L
    private val targets = Targets(apps=setOf("fixture.app"))
    private fun <T> restored(value: T): T {
        val bytes=ByteArrayOutputStream().also { ObjectOutputStream(it).use { out -> out.writeObject(value) } }.toByteArray()
        @Suppress("UNCHECKED_CAST")
        return ObjectInputStream(ByteArrayInputStream(bytes)).use { it.readObject() as T }
    }
    @Test fun distantFixedReservationHasConfirmationAndBoundary() {
        val start=now+30*Planner.DAY
        val draft=EditorDraft(targets=targets,timing=DraftTiming.Fixed(start,90))
        val rule=draft.makeRule(now,"Later this month")
        val state=Planner.save(State(),rule,now)
        assertEquals(start,rule.nextOccurrence(now)!!.start)
        assertEquals(start+90*60_000,rule.nextOccurrence(now)!!.end)
        assertEquals(start,Planner.nextBoundary(state,now))
    }
    @Test fun tabsRetainInputsAcrossRestoration() {
        var draft=EditorDraft(targets=targets)
        draft.chooseMode(ComposerMode.LATER,now); draft.delay=55; draft.duration=90
        draft.chooseMode(ComposerMode.FIXED,now); draft.at=now+30*Planner.DAY
        draft.chooseMode(ComposerMode.WEEKLY,now); draft.days=setOf(2,6); draft.repeatEnd=480
        draft=restored(draft)
        draft.chooseMode(ComposerMode.LATER,now)
        assertEquals(55,draft.delay); assertEquals(90,draft.duration)
        draft.chooseMode(ComposerMode.FIXED,now); assertEquals(now+30*Planner.DAY,draft.at)
        draft.chooseMode(ComposerMode.WEEKLY,now)
        assertEquals(setOf(2,6),draft.days); assertEquals(480,draft.repeatEnd)
        assertEquals(targets,draft.targets)
        val newTab=EditorDraft(timing=DraftTiming.Now(60))
        newTab.chooseMode(ComposerMode.WEEKLY,now)
        newTab.chooseMode(ComposerMode.FIXED,now)
        assertEquals(60,newTab.duration) // A first visit through Repeat keeps the common single duration.
    }
    @Test fun editingUsesIDAndDraftWithoutMutatingSavedRule() {
        val rule=Rule(title="Weekly",targets=targets,schedule=LockSchedule.Weekly(setOf(1),1380,420,"America/New_York"))
        val draft=EditorDraft.editing(rule)
        draft.enabled=false; draft.repeatEnd=480
        assertTrue(rule.enabled); assertEquals(420,rule.weekly!!.endMinute)
        val edited=draft.makeRule(now,rule.title)
        assertEquals(rule.id,edited.id); assertFalse(edited.enabled)
        assertEquals("America/New_York",edited.weekly!!.zone)
        assertEquals(480,edited.weekly!!.endMinute)
        assertThrows(IllegalStateException::class.java) { draft.chooseMode(ComposerMode.NOW,now) }
    }
    @Test fun nestedReturnFlowRestoresWithItsCancellationTarget() {
        val flow=Route.Permissions(Route.Picker(Route.Home,targets),PermissionReturn.CONFIRM)
        val restored=restored(flow)
        assertEquals(flow,restored)
        assertEquals(Route.Home,(restored.returnTo as Route.Picker).returnTo)
        assertEquals(targets,(restored.returnTo as Route.Picker).original)
        assertEquals(PermissionReturn.CONFIRM,restored.action)
    }
}
