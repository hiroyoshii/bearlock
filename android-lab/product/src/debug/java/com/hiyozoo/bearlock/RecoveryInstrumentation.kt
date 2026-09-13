package com.hiyozoo.bearlock

import android.app.Activity
import android.app.Instrumentation
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Button
import java.io.File

/** Isolated storage and a failing alarm service; the real retry button calls Scheduling.sync. */
class RecoveryTestActivity : MainActivity() {
    companion object { var failMonitoring = true }
    override fun getFilesDir() = File(cacheDir, "recovery-test").apply { mkdirs() }
    override fun updateMonitoring(): Result<Unit> {
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
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        var activity: RecoveryTestActivity? = null
        try {
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
            finish(Activity.RESULT_OK, Bundle().apply {
                putString("stream", "PASS: monitoring recovery UI; repeated failure, navigation, recreation, successful retry, saved rule preserved\n")
            })
        } catch(t: Throwable) {
            finish(Activity.RESULT_CANCELED, Bundle().apply { putString("stream", android.util.Log.getStackTraceString(t)) })
        } finally {
            activity?.let { a -> runOnMainSync { a.store.change { State() }; a.updateMonitoring(); a.finish() }; a.filesDir.deleteRecursively() }
        }
    }
    private fun capture(name: String) {
        val directory = File(targetContext.filesDir, "recovery-evidence").apply { mkdirs() }
        val bitmap = uiAutomation.takeScreenshot() ?: error("No screenshot")
        File(directory,"$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,it) }
        bitmap.recycle()
    }
}
