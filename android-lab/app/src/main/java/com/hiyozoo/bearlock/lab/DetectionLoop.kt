package com.hiyozoo.bearlock.lab

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import org.json.JSONObject

/** Shared time reconciliation; only A supplies a usage-poll function. */
class DetectionLoop(private val context: Context, val method: Method, overlayType: Int) {
    private val handler = Handler(Looper.getMainLooper())
    private val store = LabStore(context)
    private val overlay = BlockOverlay(context, overlayType)
    private var foreground: String? = null
    private var sourceWall: Long? = null
    private var lastPhase: String? = null
    private var running = false
    var poll: (() -> Unit)? = null
    var onFinished: (() -> Unit)? = null
    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            if (context.getSystemService(PowerManager::class.java).isInteractive) poll?.invoke()
            reconcile()
            if (running) handler.postDelayed(this, 250)
        }
    }
    fun start() { if (!running) { running = true; handler.post(tick) } }
    fun observed(pkg: String, sourceWallMs: Long) {
        if (foreground != pkg) {
            foreground = pkg; sourceWall = sourceWallMs
            // Do not log unrelated package identities or screen contents.
            val target = store.read()?.target
            store.event("foreground_changed", JSONObject().put("method", method).put("isTarget", pkg == target)
                .put("sourceWallMs", sourceWallMs))
        }
        reconcile()
    }
    fun reconcile() {
        val window = store.read()
        val now = System.currentTimeMillis()
        if (window == null || window.method != method) { overlay.hide("inactive_method"); return }
        val phase = when { now < window.start -> "scheduled"; window.active(now) -> "active"; else -> "ended" }
        if (phase != lastPhase) {
            lastPhase = phase
            store.event("phase", JSONObject().put("method", method).put("phase", phase).put("start", window.start).put("end", window.end))
        }
        if (window.active(now) && foreground == window.target && context.getSystemService(PowerManager::class.java).isInteractive) {
            overlay.show(window, sourceWall)
        } else overlay.hide(phase)
        if (!window.pending(now)) { stop(); onFinished?.invoke() }
    }
    fun stop() { running = false; handler.removeCallbacks(tick); overlay.hide("monitor_stopped") }
}
