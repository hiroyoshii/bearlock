package com.hiyozoo.bearlock.lab

import android.accessibilityservice.AccessibilityService
import android.os.SystemClock
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent

class AccessMonitor : AccessibilityService() {
    companion object { var instance: AccessMonitor? = null; private set }
    private lateinit var loop: DetectionLoop
    private lateinit var recovery: ForegroundRecovery
    override fun onServiceConnected() {
        if (::recovery.isInitialized) recovery.close()
        if (::loop.isInitialized) loop.stop()
        instance = this
        loop = DetectionLoop(this, Method.ACCESSIBILITY, WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
        recovery = ForegroundRecovery(this, ::hasPendingWindow) { pkg, time -> loop.observed(pkg, time) }
        LabStore(this).event("access_service_connected")
        refresh()
    }
    private fun hasPendingWindow(): Boolean = LabStore(this).read()?.let {
        it.method == Method.ACCESSIBILITY && it.pending(System.currentTimeMillis())
    } == true
    fun refresh() { loop.start(); loop.reconcile(); recovery.request("connect_or_schedule") }
    fun appForeground() {
        loop.observed(packageName, System.currentTimeMillis())
        recovery.request("lab_foreground")
    }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!::recovery.isInitialized || event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED) return
        val pkg = event.packageName?.toString()
        // Own overlay events must not dismiss that same overlay. MainActivity reports itself explicitly.
        if (pkg == packageName) return
        if (!hasPendingWindow()) return
        if (pkg != null && event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            loop.observed(pkg, System.currentTimeMillis() - (SystemClock.uptimeMillis() - event.eventTime))
        }
        loop.start()
        recovery.request("window_changed")
    }
    override fun onInterrupt() { loop.stop(); LabStore(this).event("access_interrupted") }
    override fun onDestroy() {
        if (::recovery.isInitialized) recovery.close()
        if (::loop.isInitialized) loop.stop()
        instance = null
        super.onDestroy()
    }
}
