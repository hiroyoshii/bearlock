package com.hiyozoo.bearlock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.*
import android.os.Build

object Scheduling {
    @Volatile var updateFailed = false
        private set
    fun permitted(c: Context) = Build.VERSION.SDK_INT < 31 || c.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    fun sync(c: Context, refresh: () -> Unit = { GuardService.instance?.refresh() }): Result<Unit> {
        val store = Store(c)
        val result = runCatching {
            val state = store.read()
            val alarm = c.getSystemService(AlarmManager::class.java)
            val pi = PendingIntent.getBroadcast(c, 1, Intent(c, BoundaryReceiver::class.java).setAction("com.hiyozoo.bearlock.BOUNDARY"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val next = Planner.nextBoundary(state, System.currentTimeMillis())
            if (next == null) alarm.cancel(pi) else next.let {
                if (permitted(c)) alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, it, pi)
                else {
                    // GuardService also evaluates wall time; a delayed alarm must not extend a lock.
                    alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, it, pi)
                    if (Planner.needsScheduledAlarm(state, System.currentTimeMillis())) store.event("alarm_permission_missing")
                }
            }
        }.onFailure { store.event("schedule_failure:${it.javaClass.simpleName}") }
        updateFailed = result.isFailure
        // Expiry enforcement is independent of alarm registration success.
        refresh()
        return result
    }
}
class BoundaryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) { Store(context).event("boundary:${intent.action}"); Scheduling.sync(context) }
}
