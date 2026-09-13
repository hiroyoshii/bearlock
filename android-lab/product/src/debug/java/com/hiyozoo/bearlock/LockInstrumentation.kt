package com.hiyozoo.bearlock

import android.app.Activity
import android.app.Instrumentation
import android.content.Context
import android.content.ContextWrapper
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import java.io.File
import java.lang.reflect.Proxy

/** Native AtomicFile and view-removal failure tests, without touching the user's saved rules. */
class LockInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        val directory = File(targetContext.cacheDir, "lock-contract-${System.nanoTime()}").apply { mkdirs() }
        val context = object : ContextWrapper(targetContext) { override fun getFilesDir() = directory }
        try {
            val store = Store(context)
            val now = System.currentTimeMillis()
            val rule = Rule(title="Fixture", targets=Targets(apps=setOf("fixture.app")), start=now, end=now+60_000)
            val saved = store.change { Planner.save(it, rule, now) }
            val file = File(directory, "locks-v1.json")
            val original = file.readText()
            check(!original.contains("sessions") && !original.contains("completed"))
            check(store.read() == saved)
            check(store.read().activeLocks(now+60_000).isEmpty())
            check(file.readText() == original) { "Expiry wrote execution state" }

            file.writeText("corrupt")
            check(runCatching { store.read() }.isFailure)
            check(runCatching { store.change { State() } }.isFailure)
            check(file.readText() == "corrupt") { "Read failure overwrote data" }
            file.writeText(original)
            check(store.read() == saved && store.error == null)

            // AtomicFile cannot create its output when .new is a nonempty directory.
            val blockedWrite = File(directory, "locks-v1.json.new").apply { mkdirs() }
            File(blockedWrite, "blocker").writeText("fixture")
            check(runCatching { store.change { it.copy(rules=emptyList()) } }.isFailure)
            check(file.readText() == original) { "Failed write lost the old rules" }
            blockedWrite.deleteRecursively()
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
                } catch(t: Throwable) { failure=t }
            }
            failure?.let { throw it }
            finish(Activity.RESULT_OK,Bundle().apply {
                putString("stream","PASS: lock failure recovery; corrupt read, atomic write, logging, alarm refresh/retry, shield removal/retry\n")
            })
        } catch(t: Throwable) {
            finish(Activity.RESULT_CANCELED,Bundle().apply { putString("stream",android.util.Log.getStackTraceString(t)) })
        } finally { directory.deleteRecursively() }
    }
}
