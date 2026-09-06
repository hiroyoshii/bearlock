package com.hiyozoo.bearlock.lab

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import org.json.JSONObject
import java.util.concurrent.Executors

/** Event-triggered snapshots, not UsageStats polling. Only root package metadata is inspected. */
class ForegroundRecovery(
    private val service: AccessibilityService,
    private val needed: () -> Boolean,
    private val apply: (String, Long) -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val gate = SnapshotGate()
    private val store = LabStore(service)
    private var closed = false
    private var attempts = 0
    private var reason = "connect"
    private val read = Runnable { snapshot() }

    fun request(why: String) {
        if (closed) return
        gate.invalidate()
        reason = why
        attempts = 0
        handler.removeCallbacks(read)
        if (needed()) handler.postDelayed(read, 100)
    }

    private fun snapshot() {
        if (closed || !needed()) return
        val ticket = gate.begin() ?: return // In-flight completion will schedule the newest request.
        val requestReason = reason
        val capturedAt = System.currentTimeMillis()
        worker.execute {
            // Accessibility calls can wait on another process; never block the service/UI thread.
            val result = runCatching { currentPackage() }
            handler.post {
                val current = gate.finish(ticket)
                if (closed || !needed()) return@post
                if (!current) {
                    handler.post(read)
                    return@post
                }
                val pkg = result.getOrNull()
                if (pkg != null) {
                    store.event("foreground_snapshot", JSONObject().put("reason", requestReason)
                        .put("isTarget", pkg == store.read()?.target).put("sourceWallMs", capturedAt))
                    apply(pkg, capturedAt)
                } else if (++attempts < 8) {
                    store.event("snapshot_retry", JSONObject().put("attempt", attempts)
                        .put("reason", requestReason).put("error", result.exceptionOrNull()?.javaClass?.simpleName))
                    handler.postDelayed(read, (attempts * 250L).coerceAtMost(2000))
                } else {
                    store.event("snapshot_unavailable", JSONObject().put("reason", requestReason))
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun packageOf(root: AccessibilityNodeInfo?): String? {
        if (root == null) return null
        return try { root.packageName?.toString() }
        finally { if (Build.VERSION.SDK_INT < 33) root.recycle() }
    }

    @Suppress("DEPRECATION")
    private fun currentPackage(): String? {
        val windows = service.windows
        try {
            // Ignore our unfocusable overlay: its window events must not erase the underlying app.
            val focused = windows.firstOrNull {
                it.isFocused && it.type != AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY
            }
            if (focused != null) return packageOf(focused.root)
            val active = windows.firstOrNull {
                it.isActive && it.type != AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY
            }
            if (active != null) return packageOf(active.root)
            return packageOf(service.rootInActiveWindow)?.takeUnless { it == service.packageName }
        } finally {
            if (Build.VERSION.SDK_INT < 33) windows.forEach { it.recycle() }
        }
    }

    fun close() {
        closed = true
        gate.close()
        handler.removeCallbacksAndMessages(null)
        worker.shutdownNow()
    }
}
