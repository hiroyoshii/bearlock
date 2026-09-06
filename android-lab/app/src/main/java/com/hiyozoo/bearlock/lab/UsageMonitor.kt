package com.hiyozoo.bearlock.lab

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Intent
import android.os.IBinder
import android.view.WindowManager

class UsageMonitor : Service() {
    private lateinit var loop: DetectionLoop
    private var cursor = 0L
    private var lastEventTime = 0L
    override fun onCreate() {
        super.onCreate()
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel("comparison", "ブロック比較", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        startForeground(1, Notification.Builder(this, "comparison").setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Bear Lock 比較中").setContentText("方式 A · 保存した終了時刻まで検知します")
            .setContentIntent(open).setOngoing(true).build())
        loop = DetectionLoop(this, Method.USAGE, WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        loop.poll = ::poll
        loop.onFinished = { stopSelf() }
        LabStore(this).event("usage_service_started")
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val w = LabStore(this).read()
        if (w == null || w.method != Method.USAGE || !w.pending(System.currentTimeMillis())) stopSelf()
        else loop.start()
        return START_STICKY
    }
    @Suppress("DEPRECATION")
    private fun poll() {
        if (!Permissions.usage(this)) { loop.stop(); LabStore(this).event("usage_permission_lost"); stopSelf(); return }
        val now = System.currentTimeMillis()
        if (now < cursor) { cursor = 0; lastEventTime = 0 }
        // Usage events can become visible after their timestamp. Overlap queries instead of
        // advancing an exclusive cursor to "now", which can permanently skip late arrivals.
        val begin = now - if (cursor == 0L) 60_000 else 5_000
        val events = getSystemService(UsageStatsManager::class.java).queryEvents(begin, now) ?: return
        val event = UsageEvents.Event()
        var latestPackage: String? = null
        var latestTime = 0L
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND && event.timeStamp >= latestTime) {
                latestPackage = event.packageName
                latestTime = event.timeStamp
            }
        }
        // Replaying historical transitions can briefly block the wrong foreground app at startup.
        latestPackage?.takeIf { latestTime > lastEventTime }?.let {
            lastEventTime = latestTime
            loop.observed(it, latestTime)
        }
        cursor = now
    }
    override fun onDestroy() { loop.stop(); LabStore(this).event("usage_service_stopped"); super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null
}
