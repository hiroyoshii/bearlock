package com.hiyozoo.bearlock

import android.app.Activity
import android.app.Instrumentation
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import java.io.File
import java.lang.reflect.Proxy

/** Real write refusal for both older and current AtomicFile implementations. */
internal fun refuseStoreWrites(context: Context): () -> Unit {
    val directory=context.filesDir
    val file=File(directory,"locks-v1.json")
    check(file.setWritable(false)); check(directory.setWritable(false))
    return { check(directory.setWritable(true)); check(file.setWritable(true)) }
}

/** Native AtomicFile and view-removal failure tests, without touching the user's saved rules. */
class LockInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        val directory = File(targetContext.cacheDir, "lock-contract-${System.nanoTime()}").apply { mkdirs() }
        val context = object : ContextWrapper(targetContext) { override fun getFilesDir() = directory }
        try {
            val store = Store(context)
            val now = System.currentTimeMillis()
            val rule = Rule(title="Fixture", targets=Targets(apps=setOf("fixture.app")), schedule=LockSchedule.Single(now,now+60_000))
            val saved = store.change { Planner.save(it, rule, now) }
            val file = File(directory, "locks-v1.json")
            val original = file.readText()
            check(!original.contains("sessions") && !original.contains("completed"))
            val weekly = rule.copy(schedule=LockSchedule.Weekly(setOf(1,5),1380,420,"UTC"))
            val weeklyJSON = Codec.encode(State(rules=listOf(weekly)))
            check(!weeklyJSON.contains("\"start\"") && !weeklyJSON.contains("\"duration\""))
            check(Codec.decode(weeklyJSON).rules.single() == weekly)
            check(store.read() == saved)
            check(store.read().activeLocks(now+60_000).isEmpty())
            check(file.readText() == original) { "Expiry wrote execution state" }

            file.writeText("corrupt")
            check(runCatching { store.read() }.isFailure)
            check(runCatching { store.change { State() } }.isFailure)
            check(file.readText() == "corrupt") { "Read failure overwrote data" }
            file.writeText(original)
            check(store.read() == saved && store.error == null)

            val unblock=refuseStoreWrites(context)
            try {
                check(runCatching { store.change { it.copy(rules=emptyList()) } }.isFailure)
                check(file.readText() == original) { "Failed write lost the old rules" }
            } finally { unblock() }
            check(store.change { it.copy(rules=emptyList()) }.rules.isEmpty())

            File(directory,"diagnostics.log").mkdirs() // Logging fails; save/expiry must continue.
            store.event("expected_log_failure")
            store.change { saved }
            check(store.read().activeLocks(now+60_000).isEmpty())

            var refreshed = 0
            val badAlarmContext = object : ContextWrapper(context) {
                override fun getSystemService(name: String): Any? {
                    if (name == Context.ALARM_SERVICE) throw SecurityException("fixture alarm failure")
                    return super.getSystemService(name)
                }
            }
            check(Scheduling.sync(badAlarmContext) { refreshed++ }.isFailure)
            check(refreshed == 1) { "Alarm failure suppressed expiry refresh" }
            check(Scheduling.sync(context) { refreshed++ }.isSuccess)
            check(refreshed == 2)

            var failure: Throwable? = null
            runOnMainSync {
                try {
                    val host = LinearLayout(context)
                    var rejectRemoval = true
                    var additions = 0
                    val manager = Proxy.newProxyInstance(WindowManager::class.java.classLoader,
                        arrayOf(WindowManager::class.java)) { _, method, args ->
                        when(method.name) {
                            "addView" -> { additions++; host.addView(args!![0] as View); null }
                            "removeView" -> {
                                if(rejectRemoval) throw IllegalStateException("fixture removal failure")
                                host.removeView(args!![0] as View); null
                            }
                            else -> null
                        }
                    } as WindowManager
                    val shield = Shield(context,manager)
                    val active = saved.activeLocks(now).single()
                    shield.show(active,"Fixture")
                    check(host.childCount==1)
                    check(!shield.hide() && host.childCount==1)
                    shield.show(active.copy(end=active.end+60_000),"Fixture")
                    check(additions==1) { "Failed removal added a second shield" }
                    rejectRemoval=false
                    check(shield.hide() && host.childCount==0)
                    check(shield.hide())
                    var rejectNavigation=true
                    var opened: Intent?=null
                    val navigationContext=object : ContextWrapper(context) {
                        override fun startActivity(intent: Intent) {
                            if(rejectNavigation) throw android.content.ActivityNotFoundException("fixture")
                            opened=intent
                        }
                    }
                    val navigable=Shield(navigationContext,manager)
                    navigable.show(active,"Fixture")
                    val wakeButtons=arrayListOf<View>()
                    host.findViewsWithText(wakeButtons,tr(context,"熊を起こす","Wake the bear"),View.FIND_VIEWS_WITH_CONTENT_DESCRIPTION)
                    wakeButtons.single().performClick()
                    check(host.childCount==1 && opened==null)
                    val errors=arrayListOf<View>()
                    host.findViewsWithText(errors,tr(context,"Bear Lockを開けません。ホームに戻ってアプリを開いてください。","Could not open Bear Lock. Return home and open the app."),View.FIND_VIEWS_WITH_TEXT)
                    check(errors.single().visibility==View.VISIBLE)
                    rejectNavigation=false
                    wakeButtons.single().performClick()
                    check(opened!!.getStringExtra("wakeRuleId")==active.ruleId)
                    check(opened!!.getLongExtra("wakeOccurrenceStart",-1)==active.start)
                    check(host.childCount==0 && store.read()==saved)
                } catch(t: Throwable) { failure=t }
            }
            failure?.let { throw it }
            finish(Activity.RESULT_OK,Bundle().apply {
                putString("stream","PASS: lock failure recovery; corrupt read, atomic write, logging, alarm refresh/retry, shield removal/retry\n")
            })
        } catch(t: Throwable) {
            finish(Activity.RESULT_CANCELED,Bundle().apply { putString("stream",android.util.Log.getStackTraceString(t)) })
        } finally {
            directory.deleteRecursively()
            Scheduling.sync(targetContext) // The isolated fixture shares the OS PendingIntent.
        }
    }
}
