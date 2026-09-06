package com.hiyozoo.bearlock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.*
import android.os.Build

object Scheduling {
    fun permitted(c: Context) = Build.VERSION.SDK_INT < 31 || c.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    fun sync(c: Context) {
        val store = Store(c)
        try {
            val state = store.reconcile()
            val alarm = c.getSystemService(AlarmManager::class.java)
            val pi = PendingIntent.getBroadcast(c, 1, Intent(c, BoundaryReceiver::class.java).setAction("com.hiyozoo.bearlock.BOUNDARY"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarm.cancel(pi)
            Planner.nextBoundary(state, System.currentTimeMillis())?.let {
                if (permitted(c)) alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, it, pi)
                else { alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, it, pi); store.event("alarm_permission_missing") }
            }
            GuardService.instance?.refresh()
        } catch (e: Exception) { store.event("schedule_failure:${e.javaClass.simpleName}") }
    }
}
class BoundaryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) { Store(context).event("boundary:${intent.action}"); Scheduling.sync(context) }
}
