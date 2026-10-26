package com.hiyozoo.bearlock

import android.app.Activity
import android.app.Instrumentation
import android.app.UiAutomation
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.view.accessibility.AccessibilityNodeInfo
import java.io.File

/** Isolated storage and a failing alarm service; the real retry button calls Scheduling.sync. */
class RecoveryTestActivity : MainActivity() {
    companion object { var failMonitoring = true; var monitoringCalls = 0 }
    override fun onCreate(savedInstanceState: Bundle?) {
        visualPreview = true // Failure UI is isolated from the OS service; probe E2E verifies enforcement.
        super.onCreate(savedInstanceState)
    }
    override fun getFilesDir() = File(cacheDir, "recovery-test").apply { mkdirs() }
    override fun updateMonitoring(): Result<Unit> {
        monitoringCalls++
        val context = if (!failMonitoring) this else object : ContextWrapper(this) {
            override fun getSystemService(name: String): Any? {
                if (name == Context.ALARM_SERVICE) throw SecurityException("Test alarm unavailable")
                return super.getSystemService(name)
            }
        }
        return Scheduling.sync(context)
    }
}

class RecoveryInstrumentation : Instrumentation() {
    private lateinit var automation: UiAutomation
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        var activity: RecoveryTestActivity? = null
        try {
            automation = getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
            targetContext.getSharedPreferences("appearance",0).edit().putString("language","en").commit()
            RecoveryTestActivity.failMonitoring = true
            activity = startActivitySync(Intent(targetContext, RecoveryTestActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK).putExtra("qaPage", "home")) as RecoveryTestActivity
            waitForIdleSync()
            val first = activity
            val rule = Rule(title="Saved schedule", targets=Targets(apps=setOf("fixture.app")),
                schedule=LockSchedule.Single(System.currentTimeMillis()+3_600_000, System.currentTimeMillis()+7_200_000))
            runOnMainSync {
                first.store.change { State(rules=listOf(rule)) }
                first.syncSchedules()
                check(Scheduling.updateFailed)
                first.findViewById<View>(android.R.id.content).findViewWithTag<Button>("monitoring-retry").performClick()
                check(Scheduling.updateFailed) { "Failed retry cleared the warning" }
                first.navigate(Route.Settings)
                first.goBack()
                check(first.findViewById<View>(android.R.id.content).findViewWithTag<Button>("monitoring-retry") != null)
            }
            capture("monitoring-error")
            val monitor = addMonitor(RecoveryTestActivity::class.java.name, null, false)
            runOnMainSync { first.recreate() }
            activity = waitForMonitorWithTimeout(monitor,10_000) as? RecoveryTestActivity ?: error("Activity did not recreate")
            removeMonitor(monitor)
            waitForIdleSync()
            val restored = activity
            runOnMainSync {
                val retry = restored.findViewById<View>(android.R.id.content).findViewWithTag<Button>("monitoring-retry")
                check(retry != null) { "Recreation hid the failed update" }
                check(restored.store.read().rules == listOf(rule))
                RecoveryTestActivity.failMonitoring = false
                retry.performClick()
                check(!Scheduling.updateFailed)
                check(restored.findViewById<View>(android.R.id.content).findViewWithTag<Button>("monitoring-retry") == null)
                check(restored.store.read().rules == listOf(rule)) { "Retry changed saved schedules" }
            }
            waitForIdleSync()
            capture("monitoring-restored")
            verifyWakeFailures(restored)
            verifyScheduleAndComposer(restored)
            verifySelectionPersistence(restored)
            verifyScheduleOperations(restored)
            verifyHistoryOperations(restored)
            verifyHomeSummary(restored)
            finish(Activity.RESULT_OK, Bundle().apply {
                putString("stream", "PASS: monitoring recovery UI; free-wake recovery; selection migration, write failure/retry/cancel/recreation; schedule create/edit/delete failure and reflection-only retry; history pin/unpin/delete failure/retry without monitoring; unavailable data hides stale summaries; home empty/mixed/locked summary\n")
            })
        } catch(t: Throwable) {
            runCatching { capture("failure") }
            finish(Activity.RESULT_CANCELED, Bundle().apply { putString("stream", android.util.Log.getStackTraceString(t)) })
        } finally {
            activity?.let { a -> runOnMainSync { a.getPreferences(0).edit().clear().commit(); a.finish() }; a.filesDir.deleteRecursively() }
            Scheduling.sync(targetContext) // Restore real alarms after the isolated fixture.
        }
    }
    private fun verifyHomeSummary(a: RecoveryTestActivity) {
        fun root()=a.findViewById<View>(android.R.id.content)
        fun controls(description: String): List<View> = arrayListOf<View>().also {
            root().findViewsWithText(it,description,View.FIND_VIEWS_WITH_CONTENT_DESCRIPTION)
        }
        runOnMainSync {
            a.editor.chooseMode(ComposerMode.NOW,System.currentTimeMillis())
            a.store.change { State(selection=Targets()) }; a.restoreSelection(); a.navigate(Route.Home)
            check(listOf("0 Apps","0 Categories","0 Websites").all { controls(it).isEmpty() })
            check(controls("Select targets").single().isEnabled)
            check(!root().findViewWithTag<Button>("composer-primary").isEnabled)
        }
        capture("home-empty")
        val targets=Targets(apps=setOf("com.hiyozoo.bearlock.probe","com.android.chrome"),categories=setOf(1),domains=setOf("example.com"))
        runOnMainSync {
            a.store.change { State(selection=targets) }; a.restoreSelection(); a.expandedTargets=true; a.render()
            check(listOf("2 Apps","1 Categories","1 Websites").all { controls(it).size==1 })
            check(root().findViewWithTag<Button>("composer-primary").isEnabled)
            for(n in listOf(15,30,60,120)) {
                val preset=root().findViewWithTag<Button>("duration-preset-$n")
                check(preset.minHeight>=a.ui.dp(44))
                check(preset.background is android.graphics.drawable.InsetDrawable)
                check(preset.isSelected==(n==a.editor.duration))
            }
            val mode=root().findViewWithTag<Button>("composer-mode-0")
            check(mode.typeface.isBold && mode.minHeight>=a.ui.dp(44))
            if(a.ui.compact) {
                check(mode.autoSizeTextType==TextView.AUTO_SIZE_TEXT_TYPE_NONE) { "Large text must not be shrunk" }
                check(kotlin.math.abs(mode.textSize-android.util.TypedValue.applyDimension(android.util.TypedValue.COMPLEX_UNIT_SP,12f,a.resources.displayMetrics))<=1f)
            } else check(kotlin.math.abs(mode.autoSizeMaxTextSize-android.util.TypedValue.applyDimension(android.util.TypedValue.COMPLEX_UNIT_SP,12f,a.resources.displayMetrics))<=1f)
            val group=mode.parent as com.google.android.material.button.MaterialButtonToggleGroup
            val container=if(a.ui.compact) (group.parent as android.widget.HorizontalScrollView).apply {
                check(isFillViewport)
            } else group
            check((container.layoutParams as android.widget.LinearLayout.LayoutParams).bottomMargin==a.ui.dp(18))
            for(text in listOf("Duration",a.catalog.name("com.android.chrome"))) {
                val labels=arrayListOf<View>()
                root().findViewsWithText(labels,text,View.FIND_VIEWS_WITH_TEXT)
                check(labels.filterIsInstance<TextView>().filter { it.text.toString()==text }.any { it.currentTextColor==Palette.textPrimary }) { "Primary text color differs: $text" }
            }
            val disclosure=controls("Target list").single()
            check(disclosure.isFocusable)
            disclosure.performClick(); check(!a.expandedTargets)
            disclosure.performClick(); check(a.expandedTargets)
            check(a.store.read()==State(selection=targets)) { "Disclosure wrote saved state" }
        }
        capture("home-mixed-expanded")
        runOnMainSync {
            val now=System.currentTimeMillis()
            a.store.change { State(selection=targets,rules=listOf(Rule(title="Home locked",targets=targets,schedule=LockSchedule.Single(now-60_000,now+3_600_000)))) }
            a.render()
            check(!controls("Cannot change during lock").single().isEnabled)
            check(a.editor.targets==targets)
        }
        capture("home-locked")
    }
    private fun verifyWakeFailures(a: RecoveryTestActivity) {
        val now = System.currentTimeMillis()
        val rule = Rule(title="Wake failure test", targets=Targets(apps=setOf("fixture.app")),
            schedule=LockSchedule.Single(now, now+7_200_000))
        runOnMainSync { a.store.change { State(rules=listOf(rule)) }; a.syncSchedules() }
        fun open() {
            runOnMainSync {
                check(a.findViewById<View>(android.R.id.content).findViewWithTag<Button>("open-wake-options").performClick())
            }
            waitForIdleSync()
        }
        val unblock=refuseStoreWrites(a)
        try {
            open(); click("Wake in 30 minutes for free")
            check(a.store.read() == State(rules=listOf(rule))) { "Failed save changed booking" }
            check(windowText().contains("Could not save the wake-up change"))
            capture("wake-save-error"); click("OK")
        } finally { unblock() }

        RecoveryTestActivity.failMonitoring = true
        open(); click("Wake in 30 minutes for free")
        val booked = a.store.read()
        check(booked.wakes.size == 1 && booked.rules == listOf(rule))
        check(Scheduling.updateFailed && windowText().contains("Your change is saved"))
        capture("wake-registration-error"); click("Close")
        runOnMainSync { a.load(); a.render() }
        RecoveryTestActivity.failMonitoring = false
        runOnMainSync { a.findViewById<View>(android.R.id.content).findViewWithTag<Button>("monitoring-retry").performClick() }
        check(!Scheduling.updateFailed && a.store.read() == booked) { "Retry replaced the saved deadline" }

        val unblockCancel=refuseStoreWrites(a)
        try {
            open(); click("Cancel wake-up")
            check(a.store.read() == booked) { "Failed cancellation lost the booking" }
            check(windowText().contains("Could not save the wake-up change")); click("OK")
        } finally { unblockCancel() }

        RecoveryTestActivity.failMonitoring = true
        open(); click("Cancel wake-up")
        check(a.store.read() == State(rules=listOf(rule))) { "Registration failure reverted cancellation" }
        check(Scheduling.updateFailed && windowText().contains("Your change is saved"))
        capture("wake-cancel-registration-error"); click("Close")
        RecoveryTestActivity.failMonitoring = false
        runOnMainSync { a.syncSchedules() }
        check(!Scheduling.updateFailed && a.store.read().activeLocks(System.currentTimeMillis()).single().end == rule.single!!.end)

        val nextStart=booked.wakes.single().wakesAt
        val next=rule.copy(id="after-free-wake",schedule=LockSchedule.Single(nextStart,nextStart+60_000))
        val conflict=booked.copy(rules=listOf(rule,next))
        runOnMainSync { a.store.change { conflict }; a.syncSchedules() }
        val calls=RecoveryTestActivity.monitoringCalls
        open(); click("Cancel wake-up")
        check(windowText().contains("This overlaps another lock"))
        check(a.store.read()==conflict && RecoveryTestActivity.monitoringCalls==calls)
        capture("wake-cancel-overlap-rejected"); click("OK")
        runOnMainSync { a.store.change { State(rules=listOf(rule)) }; a.syncSchedules() }

        // A dialog must keep its original rule/occurrence, not redirect to a new representative.
        open()
        val other = rule.copy(id="another-rule")
        runOnMainSync { a.store.change { State(rules=listOf(other)) } }
        click("Wake in 30 minutes for free")
        check(a.store.read() == State(rules=listOf(other)))
        check(windowText().contains("This lock has already ended")); click("OK")

        val short = other.copy(schedule=LockSchedule.Single(now,System.currentTimeMillis()+Planner.WAKE_DELAY))
        runOnMainSync { a.store.change { State(rules=listOf(short)) }; a.syncSchedules() }
        runOnMainSync {
            check(a.findViewById<View>(android.R.id.content).findViewWithTag<Button>("open-wake-options")==null)
            val explanations=arrayListOf<View>()
            a.findViewById<View>(android.R.id.content).findViewsWithText(explanations,"The bear will wake naturally within 30 minutes.",View.FIND_VIEWS_WITH_TEXT)
            check(explanations.size==1)
        }
        check(a.store.read() == State(rules=listOf(short)))

        val crossing=other.copy(schedule=LockSchedule.Single(now,System.currentTimeMillis()+Planner.WAKE_DELAY+3_000))
        runOnMainSync {
            a.store.change { State(rules=listOf(crossing)) }; a.syncSchedules()
            check(a.findViewById<View>(android.R.id.content).findViewWithTag<Button>("open-wake-options")!=null)
        }
        Thread.sleep(4_500) // The real heartbeat must change the UI without a tap or navigation.
        waitForIdleSync()
        runOnMainSync { check(a.findViewById<View>(android.R.id.content).findViewWithTag<Button>("open-wake-options")==null) }
        check(a.store.read()==State(rules=listOf(crossing))) { "Boundary rendering changed the saved rule" }

        runOnMainSync { a.store.change { State(rules=listOf(other)) }; a.syncSchedules() }
        open()
        val shortened = other.copy(schedule=LockSchedule.Single(now,System.currentTimeMillis()+20*60_000))
        runOnMainSync { a.store.change { State(rules=listOf(shortened)) } }
        click("Wake in 30 minutes for free")
        check(a.store.read() == State(rules=listOf(shortened)))
        check(windowText().contains("30 minutes or less remain")); click("OK")

        val started = java.time.Instant.ofEpochMilli(now).atZone(java.time.ZoneOffset.UTC).minusHours(1)
        val minute = started.hour*60+started.minute
        val weekly = rule.copy(schedule=LockSchedule.Weekly(setOf(started.dayOfWeek.value),minute,(minute+180)%1440,"UTC"))
        val occurrence = weekly.occurrences(now,now+1).single()
        val woken = Planner.scheduleWake(State(rules=listOf(weekly)),weekly.id,occurrence.start,occurrence.start)
        runOnMainSync { a.store.change { woken }; a.navigate(Route.Schedules) }
        waitForIdleSync()
        check(!windowText().contains("Active. You can delete this schedule")) { "Woken weekly rule still shown as active" }
        runOnMainSync {
            val buttons = arrayListOf<View>()
            a.findViewById<View>(android.R.id.content).findViewsWithText(buttons,"Edit scheduled lock",View.FIND_VIEWS_WITH_CONTENT_DESCRIPTION)
            check(buttons.single().isEnabled) { "Woken weekly rule remained uneditable" }
            buttons.single().performClick()
            check(a.page == "compose" && a.editor.originalID == weekly.id)
        }
        capture("wake-weekly-editable")
    }
    private fun verifyScheduleAndComposer(a: RecoveryTestActivity) {
        fun root()=a.findViewById<View>(android.R.id.content)
        fun controls(description: String): List<View> = arrayListOf<View>().also {
            root().findViewsWithText(it,description,View.FIND_VIEWS_WITH_CONTENT_DESCRIPTION)
        }
        val now=System.currentTimeMillis()
        val scheduled=Rule(title="Date & Time",targets=Targets(apps=setOf("fixture.app")),schedule=LockSchedule.Single(now-60_000,now+60*60_000))
        val immediate=scheduled.copy(id="immediate",title="Now",schedule=scheduled.single!!.copy(immediate=true))
        runOnMainSync {
            a.store.change { State(rules=listOf(scheduled,immediate)) }; a.editor=EditorDraft(targets=scheduled.targets); a.navigate(Route.Schedules)
            check(controls("Edit scheduled lock").single().isEnabled.not())
            check(controls("Delete scheduled lock").single().isEnabled.not())
        }
        capture("started-reservation")
        val woken=Planner.scheduleWake(State(rules=listOf(scheduled)),scheduled.id,scheduled.single!!.start,scheduled.single!!.start)
        runOnMainSync {
            a.store.change { woken }; a.render()
            check(controls("Edit scheduled lock").single().isEnabled.not())
            // The stored wake is still future here; move it into the past without altering the rule.
            a.store.change { it.copy(wakes=listOf(it.wakes.single().copy(wakesAt=now-1))) }; a.render()
            check(controls("Edit scheduled lock").single().isEnabled.not())
            check(controls("Delete scheduled lock").single().isEnabled.not())
            a.store.change { State(rules=listOf(scheduled.copy(schedule=scheduled.single!!.copy(end=now-1)))) }; a.render()
            check(controls("Edit scheduled lock").isEmpty())
            a.store.change { State() }; a.editor=EditorDraft(targets=scheduled.targets)
            a.editor.chooseMode(ComposerMode.FIXED,now)
            check(a.editor.at==now+30*60_000L)
            a.editor.chooseMode(ComposerMode.WEEKLY,now); a.navigate(Route.Editor)
        }
        waitForIdleSync()
        runOnMainSync {
            val preview=root().findViewWithTag<TextView>("recurring-next-preview")
            val occurrence=Composer(a).make(now).copy(enabled=true).nextOccurrence(now)!!
            check(preview.text.contains(dateText(occurrence.start,a)))
            check(preview.text.contains(dateText(occurrence.end,a)))
            for(day in java.time.DayOfWeek.values()) {
                val button=controls(day.getDisplayName(java.time.format.TextStyle.FULL,java.util.Locale.ENGLISH)).single() as Button
                check(button.measuredWidth>=a.ui.dp(44) && button.measuredHeight>=a.ui.dp(44)) { "Weekday touch target too small" }
                val selected=day.value in a.editor.days
                check(button.isSelected==selected)
                check(button.currentTextColor==if(selected) Palette.white else Palette.navy)
                val large=a.resources.configuration.fontScale>=1.5f
                check(button.compoundDrawables.all { it==null }) { "Weekdays must not show check icons" }
                if(!large) check(button.measuredWidth==button.measuredHeight) { "Weekday must be circular" }
                if(large) check(button.text==button.contentDescription) { "Large weekday label must use the full name" }
                button.performClick()
                check(button.isSelected!=selected)
                check(button.currentTextColor==if(selected) Palette.navy else Palette.white)
            }
            check(a.editor.days==setOf(6,7))
            val changed=Composer(a).make(now).nextOccurrence(now)!!
            check(preview.text.contains(dateText(changed.start,a)))
            for(day in listOf(java.time.DayOfWeek.SATURDAY,java.time.DayOfWeek.SUNDAY)) {
                controls(day.getDisplayName(java.time.format.TextStyle.FULL,java.util.Locale.ENGLISH)).single().performClick()
            }
            check(preview.text.toString()=="No upcoming lock")
            check(!root().findViewWithTag<Button>("editor-save").isEnabled)
            controls("Sunday").single().performClick()
            check(root().findViewWithTag<Button>("editor-save").isEnabled)
        }
        capture("recurring-next-preview")
        runOnMainSync {
            a.navigate(Route.Home)
            a.store.change { State(rules=listOf(scheduled.copy(schedule=LockSchedule.Single(now+60_000,now+3_600_000)))) }
            RecoveryTestActivity.failMonitoring=true; a.syncSchedules()
            val warning=root().findViewWithTag<LinearLayout>("home-status-warning")
            val summary=root().findViewWithTag<LinearLayout>("target-summary")
            check(warning.parent===summary.parent && (warning.parent as LinearLayout).indexOfChild(warning)<(summary.parent as LinearLayout).indexOfChild(summary))
        }
        // Actual AtomicFile corruption must block creation and retain the original bytes.
        val file=File(a.filesDir,"locks-v1.json")
        val original=file.readText()
        try {
            file.writeText("corrupt")
            runOnMainSync { a.visualPreview=false; a.render(); check(!a.savedDataAvailable) }
            check(windowText().contains("Schedule status is unknown"))
            check(!windowText().contains("Start Lock") && !windowText().contains("Schedule Lock"))
            runOnMainSync { check(root().findViewWithTag<LinearLayout>("target-summary")==null) { "Unavailable data showed a stale selection" } }
            check(file.readText()=="corrupt")
            capture("saved-data-unavailable")
            file.writeText(original)
            RecoveryTestActivity.failMonitoring=false
            click("Reload saved data")
            check(a.savedDataAvailable && a.store.read().rules.size==1 && !Scheduling.updateFailed)
        } finally { a.visualPreview=true; file.writeText(original); RecoveryTestActivity.failMonitoring=false }
    }
    private fun verifySelectionPersistence(a: RecoveryTestActivity) {
        val original=Targets(apps=setOf("fixture.original"),domains=setOf("example.com"),categories=setOf(2))
        val changed=Targets(apps=setOf("fixture.changed"))
        val scheduled=Rule(id="selection-reservation",title="Selection reservation",targets=original,schedule=LockSchedule.Single(System.currentTimeMillis()+3_600_000,System.currentTimeMillis()+7_200_000))
        runOnMainSync {
            a.visualPreview=false
            a.store.change { State(rules=listOf(scheduled)) }
            a.getPreferences(0).edit().putString("selection",Codec.targets(original).toString()).commit()
            a.restoreSelection(); a.render()
            check(a.savedDataAvailable && a.editor.targets==original)
            check(a.store.read().selection==original && a.store.read().rules==listOf(scheduled))
            check(!a.getPreferences(0).contains("selection")) { "Legacy selection still has an active owner" }
            a.getPreferences(0).edit().putString("selection","corrupt obsolete data").commit()
            a.restoreSelection()
            check(a.savedDataAvailable && a.editor.targets==original) { "Stale legacy data overrode the AtomicFile" }
            a.pickTargets(); a.editor.targets=changed
        }
        val bytes=File(a.filesDir,"locks-v1.json").readText()
        val unblock=refuseStoreWrites(a)
        try {
            runOnMainSync { a.saveSelection() }
            check(windowText().contains("Could not save the selection"))
            check(a.route is Route.Picker && a.editor.targets==changed) { "Failed save discarded the picker draft" }
            check(File(a.filesDir,"locks-v1.json").readText()==bytes) { "Failed selection save changed reservations" }
            capture("selection-save-failed"); click("OK")
            runOnMainSync { a.goBack(); check(a.editor.targets==original && a.route==Route.Home) }
            runOnMainSync { a.pickTargets(); a.editor.targets=changed; a.saveSelection() }
            check(windowText().contains("Could not save the selection")); click("OK")
        } finally { unblock() }
        runOnMainSync { a.saveSelection() }
        check(a.route==Route.Home && a.store.read().selection==changed && a.store.read().rules==listOf(scheduled))
        // Explicitly restore as a fresh launch does, without reading a cached SharedPreferences selection.
        runOnMainSync { a.editor.targets=Targets(); a.restoreSelection(); a.render() }
        check(a.editor.targets==changed)
        capture("selection-save-restored")
        val stored=File(a.filesDir,"locks-v1.json").readText()
        try {
            File(a.filesDir,"locks-v1.json").writeText("corrupt")
            runOnMainSync { a.render() }
            check(!a.savedDataAvailable && windowText().contains("Schedule status is unknown"))
            check(windowText().lineSequence().none { it=="Saved" } && !windowText().contains("fixture.changed"))
            capture("selection-read-failed")
        } finally {
            // Restore and press retry in one UI turn: the heartbeat must not replace the button between them.
            runOnMainSync {
                File(a.filesDir,"locks-v1.json").writeText(stored)
                check(a.findViewById<View>(android.R.id.content).findViewWithTag<Button>("storage-retry").performClick())
            }
        }
        check(a.savedDataAvailable && a.editor.targets==changed)
        runOnMainSync {
            a.store.change { State(rules=listOf(scheduled)) }
            a.getPreferences(0).edit().putString("selection","malformed legacy selection").commit()
            a.restoreSelection(); a.render()
        }
        check(!a.savedDataAvailable)
        check(a.getPreferences(0).getString("selection",null)=="malformed legacy selection")
        runOnMainSync { a.getPreferences(0).edit().putString("selection",Codec.targets(original).toString()).commit() }
        click("Reload saved data")
        check(a.savedDataAvailable && a.store.read().selection==original)
        // A picker opened while idle must not save a new selection after a schedule starts.
        val active=scheduled.copy(schedule=LockSchedule.Single(System.currentTimeMillis()-1_000,System.currentTimeMillis()+3_600_000))
        runOnMainSync {
            a.store.change { State(selection=original) }; a.restoreSelection(); a.navigate(Route.Home)
            a.pickTargets(); a.editor.targets=changed
            a.store.change { it.copy(rules=listOf(active)) }
            a.saveSelection()
        }
        check(windowText().contains("An active lock cannot be changed"))
        check(a.route is Route.Picker && a.editor.targets==changed)
        check(a.store.read()==State(selection=original,rules=listOf(active)))
        capture("selection-started-before-commit"); click("OK")
        runOnMainSync { a.goBack(); check(a.editor.targets==original) }
        // A committed selection closes the picker even when OS reflection fails. Retry is reflection-only.
        runOnMainSync {
            a.store.change { State(selection=original,rules=listOf(scheduled)) }; a.restoreSelection(); a.navigate(Route.Home)
            a.pickTargets(); a.editor.targets=changed
            RecoveryTestActivity.failMonitoring=true
            a.saveSelection()
        }
        check(windowText().contains("Your change is saved"))
        check(a.route==Route.Home && a.store.read().selection==changed)
        val committed=File(a.filesDir,"locks-v1.json").readText()
        capture("selection-saved-reflection-failed"); click("Close")
        runOnMainSync {
            RecoveryTestActivity.failMonitoring=false
            a.findViewById<View>(android.R.id.content).findViewWithTag<Button>("monitoring-retry").performClick()
        }
        check(!Scheduling.updateFailed)
        check(File(a.filesDir,"locks-v1.json").readText()==committed)
        a.visualPreview=true
    }
    private fun verifyScheduleOperations(a: RecoveryTestActivity) {
        val targets=Targets(apps=setOf("fixture.schedule"))
        val file=File(a.filesDir,"locks-v1.json")
        val future=System.currentTimeMillis()+3_600_000
        fun submit() {
            // Exercise the application entry used by confirmation, without requiring accessibility permission.
            a.createSchedule(Composer(a)::make) { a.navigate(Route.Home) }
        }
        fun retryWithoutSaving() {
            val bytes=file.readText()
            runOnMainSync { RecoveryTestActivity.failMonitoring=false; a.syncSchedules() }
            check(!Scheduling.updateFailed && file.readText()==bytes) { "Reflection retry replayed a schedule command" }
        }
        runOnMainSync {
            a.store.change { State(selection=targets) }; a.restoreSelection()
            a.editor=EditorDraft(targets=targets,timing=DraftTiming.Fixed(future,30))
            a.navigate(Route.Editor)
            RecoveryTestActivity.failMonitoring=false
        }
        val original=file.readText()
        val unblockCreate=refuseStoreWrites(a)
        try {
            runOnMainSync { submit() }
            check(windowText().contains("Could not save the schedule change"))
            check(a.route==Route.Editor && a.editor.at==future && file.readText()==original)
            capture("schedule-create-save-failed"); click("OK")
        } finally { unblockCreate() }
        runOnMainSync { RecoveryTestActivity.failMonitoring=true; submit() }
        check(a.route==Route.Home && a.store.read().rules.size==1)
        check(windowText().contains("Your change is saved"))
        capture("schedule-create-reflection-failed"); click("Close"); retryWithoutSaving()

        // A disabled weekly rule needs no permission preflight, but uses the real editor save button.
        val rule=a.store.read().rules.single().copy(enabled=false,schedule=LockSchedule.Weekly(setOf(1,2,3,4,5),1380,420,"UTC"))
        runOnMainSync {
            a.store.change { it.copy(rules=listOf(rule)) }; a.load(); a.edit(rule)
            a.editor.repeatEnd=480
            a.render()
        }
        val beforeEdit=file.readText()
        fun saveEditor() = runOnMainSync {
            check(a.findViewById<View>(android.R.id.content).findViewWithTag<Button>("editor-save").performClick())
        }
        val unblockEdit=refuseStoreWrites(a)
        try {
            saveEditor()
            check(windowText().contains("Could not save the schedule change"))
            check(a.route==Route.Editor && a.editor.repeatEnd==480 && file.readText()==beforeEdit)
            capture("schedule-edit-save-failed"); click("OK")
        } finally { unblockEdit() }
        RecoveryTestActivity.failMonitoring=true
        saveEditor()
        check(a.route==Route.Home && a.store.read().rules.single().weekly!!.endMinute==480)
        check(windowText().contains("Your change is saved"))
        capture("schedule-edit-reflection-failed"); click("Close"); retryWithoutSaving()

        fun openDelete() {
            runOnMainSync {
                a.navigate(Route.Schedules)
                val buttons=arrayListOf<View>()
                a.findViewById<View>(android.R.id.content).findViewsWithText(buttons,"Delete scheduled lock",View.FIND_VIEWS_WITH_CONTENT_DESCRIPTION)
                check(buttons.single().performClick())
            }
        }
        val beforeDelete=file.readText()
        val unblockDelete=refuseStoreWrites(a)
        try {
            openDelete(); click("Delete")
            check(windowText().contains("Could not save the schedule change"))
            check(file.readText()==beforeDelete)
            capture("schedule-delete-save-failed"); click("OK")
        } finally { unblockDelete() }
        RecoveryTestActivity.failMonitoring=true
        openDelete(); click("Delete")
        check(a.store.read().rules.isEmpty() && windowText().contains("Your change is saved"))
        capture("schedule-delete-reflection-failed"); click("Close"); retryWithoutSaving()
    }
    private fun verifyHistoryOperations(a: RecoveryTestActivity) {
        val targets=Targets(domains=setOf("history.example.com"))
        val now=System.currentTimeMillis()
        val expired=Rule(id="history-expired",title="Expired",targets=targets,schedule=LockSchedule.Single(now-7_200_000,now-3_600_000))
        val future=expired.copy(id="history-future",title="Date & Time",schedule=LockSchedule.Single(now+3_600_000,now+7_200_000))
        val recent=Recent(targets,now)
        val initial=State(rules=listOf(expired,future),recent=listOf(recent),
            wakes=listOf(WakeRequest(expired.id,expired.single!!.start,now-5_400_000)),selection=targets)
        runOnMainSync {
            a.store.change { initial }; a.restoreSelection(); a.expandedTargets=true
            a.navigate(Route.Home)
            RecoveryTestActivity.failMonitoring=true
        }
        val calls=RecoveryTestActivity.monitoringCalls
        val file=File(a.filesDir,"locks-v1.json")
        fun openMenu() {
            runOnMainSync {
                val buttons=arrayListOf<View>()
                a.findViewById<View>(android.R.id.content).findViewsWithText(buttons,"Selection menu",View.FIND_VIEWS_WITH_CONTENT_DESCRIPTION)
                check(buttons.single().performClick())
            }
        }
        fun request(action: String) {
            openMenu(); click(action)
            if(action=="Delete") click("Delete") // Confirm the native destructive dialog.
        }
        fun unchangedLockState() {
            val state=a.store.read()
            check(state.rules==initial.rules && state.wakes==initial.wakes && state.selection==initial.selection)
            check(a.editor.targets==targets)
            check(RecoveryTestActivity.monitoringCalls==calls) { "History operation updated OS monitoring" }
            check(!Scheduling.updateFailed) { "History operation introduced a monitoring failure" }
        }
        for(action in listOf("Pin","Unpin","Delete")) {
            val original=file.readText()
            val unblock=refuseStoreWrites(a)
            try {
                request(action)
                check(windowText().contains("Could not save the history change"))
                check(file.readText()==original)
                unchangedLockState()
                capture("history-${action.lowercase()}-save-failed"); click("OK")
            } finally { unblock() }
            request(action)
            val state=a.store.read()
            when(action) {
                "Pin" -> check(state.recent.single().pinned)
                "Unpin" -> check(!state.recent.single().pinned)
                "Delete" -> check(state.recent.isEmpty())
            }
            unchangedLockState()
            capture("history-${action.lowercase()}-saved")
        }
        // A menu opened before another update must validate the latest pin count.
        runOnMainSync { a.store.change { initial }; a.render() }
        openMenu()
        val pins=(1..3).map { Recent(Targets(domains=setOf("pinned$it.example.com")),now,true,now-it) }
        runOnMainSync { a.store.change { it.copy(recent=it.recent+pins) } }
        val beforeLimit=file.readText()
        click("Pin")
        check(windowText().contains("You can pin up to three targets"))
        check(file.readText()==beforeLimit)
        unchangedLockState()
        capture("history-pin-limit"); click("OK")
        RecoveryTestActivity.failMonitoring=false
    }
    private fun windowText(): String {
        waitForIdleSync()
        automation.waitForIdle(100,5_000)
        val texts = mutableListOf<String>()
        fun visit(node: AccessibilityNodeInfo) {
            node.text?.toString()?.let(texts::add)
            for(i in 0 until node.childCount) node.getChild(i)?.let(::visit)
        }
        visit(automation.rootInActiveWindow ?: error("No active UI"))
        return texts.joinToString("\n")
    }
    private fun click(text: String) {
        waitForIdleSync()
        automation.waitForIdle(100,5_000)
        fun find(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
            if(node.text?.toString().equals(text,ignoreCase=true)) return node
            for(i in 0 until node.childCount) node.getChild(i)?.let { find(it)?.let { found -> return found } }
            return null
        }
        val node = find(automation.rootInActiveWindow ?: error("No active UI")) ?: error("Missing button: $text; window=${windowText()}")
        // Popup-menu text is a child of the actionable menu item, unlike a dialog button.
        val actionable=generateSequence(node) { it.parent }.firstOrNull { it.isClickable && it.isEnabled }
            ?: error("No clickable item for $text (${node.className})")
        check(actionable.performAction(AccessibilityNodeInfo.ACTION_CLICK)) { "Click rejected: $text (${actionable.className})" }
        waitForIdleSync()
    }
    private fun capture(name: String) {
        waitForIdleSync()
        android.os.SystemClock.sleep(250) // Wait for the next presented frame, not only view mutation.
        val directory = File(targetContext.filesDir, "recovery-evidence").apply { mkdirs() }
        val bitmap = automation.takeScreenshot() ?: error("No screenshot")
        File(directory,"$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,it) }
        bitmap.recycle()
    }
}
