package com.hiyozoo.bearlock.lab

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

object Schedules {
    fun register(c: Context) {
        val next = LabStore(c).read()?.nextBoundary(System.currentTimeMillis()) ?: return
        val alarm = c.getSystemService(AlarmManager::class.java)
        val pending = PendingIntent.getBroadcast(c, 1, Intent(c, ScheduleReceiver::class.java).setAction("com.hiyozoo.bearlock.lab.BOUNDARY"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        if (Permissions.alarms(c)) alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending)
        else { LabStore(c).event("exact_alarm_missing"); alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending) }
    }
    fun resume(c: Context) {
        val w = LabStore(c).read() ?: return
        if (!w.pending(System.currentTimeMillis())) { AccessMonitor.instance?.refresh(); return }
        try {
            if (w.method == Method.USAGE) c.startForegroundService(Intent(c, UsageMonitor::class.java))
            else AccessMonitor.instance?.refresh()
        } catch (e: RuntimeException) { LabStore(c).event("resume_failed", JSONObject().put("error", e.javaClass.simpleName)) }
        register(c)
    }
}

class ScheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        LabStore(context).event("schedule_receiver", JSONObject().put("action", intent.action))
        Schedules.resume(context)
    }
}
