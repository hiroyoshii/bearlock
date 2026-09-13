package com.hiyozoo.bearlock

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.Bundle

/** Actual Activity recreation while a picker/permission flow holds an unsaved draft. */
class EditorInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        var activity: MainActivity? = null
        try {
            val original = Targets(apps=setOf("fixture.original"))
            val changed = Targets(apps=setOf("fixture.changed"))
            val start = System.currentTimeMillis()+30*Planner.DAY
            activity=startActivitySync(Intent(targetContext,MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK).putExtra("qaPage","home")) as MainActivity
            waitForIdleSync()
            val first=activity
            runOnMainSync {
                first.editor=EditorDraft(targets=original,timing=DraftTiming.Fixed(start,90))
                first.navigate(Route.Settings)
                first.goBack()
                check(first.editor.at==start && first.editor.duration==90) { "Settings discarded the draft" }
                first.pickTargets()
                first.editor.targets=changed
                first.requestPermissions()
            }
            val monitor=addMonitor(MainActivity::class.java.name,null,false)
            runOnMainSync { first.recreate() }
            activity=waitForMonitorWithTimeout(monitor,10_000) as? MainActivity ?: error("Activity did not recreate")
            removeMonitor(monitor)
            waitForIdleSync()
            val restored=activity
            runOnMainSync {
                check(restored.route is Route.Permissions)
                check(restored.editor.at==start && restored.editor.duration==90)
                check(restored.editor.targets==changed)
                restored.goBack()
                check(restored.route is Route.Picker && restored.editor.targets==changed)
                restored.goBack()
                check(restored.route==Route.Home && restored.editor.targets==original)
                check(restored.editor.at==start && restored.editor.duration==90)
                val now=System.currentTimeMillis()
                val rule=Composer(restored).make(now)
                check(rule.nextOccurrence(now)?.start==start)
                check(Planner.save(State(),rule,now).rules.single()==rule)
            }
            finish(Activity.RESULT_OK,Bundle().apply {
                putString("stream","PASS: editor recreation; nested permission/picker cancellation, 30-day reservation, input retained\n")
            })
        } catch(t: Throwable) {
            finish(Activity.RESULT_CANCELED,Bundle().apply { putString("stream",android.util.Log.getStackTraceString(t)) })
        } finally { activity?.let { runOnMainSync { it.finish() } } }
    }
}
