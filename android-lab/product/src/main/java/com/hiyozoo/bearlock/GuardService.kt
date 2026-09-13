package com.hiyozoo.bearlock

import android.accessibilityservice.AccessibilityService
import android.os.*
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import java.util.concurrent.Executors

data class Foreground(val pkg: String, val host: String?)
class GuardService : AccessibilityService() {
    companion object { var instance: GuardService? = null; private set }
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val gate = SnapshotGate()
    private val store by lazy { Store(this) }
    private val shield by lazy { Shield(this) }
    private val catalog by lazy { Catalog(this) }
    private var current: Foreground? = null
    private var state = State()
    private var activeKeys = emptyList<String>()
    private var disposed = false
    private var attempts = 0
    private var lastStateLoad = 0L
    private val read = Runnable { snapshot() }
    private val tick = object : Runnable {
        override fun run() {
            if (disposed) return
            reconcile()
            main.postDelayed(this, if (activeKeys.isNotEmpty()) 250 else 1500)
        }
    }
    override fun onServiceConnected() {
        configureLanguage(this); instance = this; store.event("service_connected"); main.post(tick); Scheduling.sync(this)
    }
    fun appForeground() { current = Foreground(packageName, null); request(); reconcile() }
    fun refresh() { load(); request(); reconcile() }
    private fun load() {
        runCatching { store.read() }.onSuccess {
            val changed = state.rules != it.rules
            state = it
            if (changed) request()
        }.onFailure { store.event("storage_unavailable") }
        lastStateLoad = SystemClock.elapsedRealtime()
    }
    private fun reconcile() {
        if (SystemClock.elapsedRealtime() - lastStateLoad > 1000) load()
        val now = System.currentTimeMillis()
        val keys = state.activeLocks(now).map { it.key }
        if (keys != activeKeys) { activeKeys = keys; request() }
        val front = current
        val session = if (front == null || catalog.excluded(front.pkg)) null
            else state.blockingLock(now, front.pkg, catalog.category(front.pkg), front.host)
        if (session != null && getSystemService(PowerManager::class.java).isInteractive) {
            shield.show(session, if (front?.host != null && session.targets.domains.any { Domain.matches(front.host, it) }) tr(this,"このWebサイト","This website") else catalog.name(front!!.pkg))
        } else shield.hide()
    }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.packageName?.toString() == packageName) return
        val pkg = event.packageName?.toString()
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED && pkg !in BrowserAddress.packages) return
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && pkg != null) {
            // Never reuse the previous browser's domain across navigation/window transitions.
            current = Foreground(pkg, null); reconcile()
        }
        request()
    }
    private fun request() {
        if (disposed) return
        gate.invalidate(); attempts = 0; main.removeCallbacks(read)
        if (state.rules.any { it.enabled && (it.recurring || it.single!!.end > System.currentTimeMillis()) }) main.postDelayed(read, 100)
    }
    private fun snapshot() {
        if (disposed) return
        val ticket = gate.begin() ?: return
        val inspectAddress = state.activeLocks(System.currentTimeMillis()).any { it.targets.domains.isNotEmpty() }
        worker.execute {
            val result = runCatching { foreground(inspectAddress) }.getOrNull()
            main.post {
                val valid = gate.finish(ticket)
                if (disposed) return@post
                if (!valid) { main.post(read); return@post }
                if (result != null) { current = result; reconcile() }
                else if (++attempts < 8) main.postDelayed(read, attempts * 250L)
                else { current = null; shield.hide(); store.event("foreground_unavailable") }
            }
        }
    }
    @Suppress("DEPRECATION")
    private fun foreground(inspectAddress: Boolean): Foreground? {
        val windows = windows
        try {
            val window = windows.firstOrNull { it.isFocused && it.type != AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY }
                ?: windows.firstOrNull { it.isActive && it.type != AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY }
            val root = window?.root ?: rootInActiveWindow ?: return null
            try {
                val pkg = root.packageName?.toString() ?: return null
                if (pkg == packageName) return null
                return Foreground(pkg, if (inspectAddress) BrowserAddress.host(root, pkg) else null)
            } finally { if (Build.VERSION.SDK_INT < 33) root.recycle() }
        } finally { if (Build.VERSION.SDK_INT < 33) windows.forEach { it.recycle() } }
    }
    override fun onInterrupt() { shield.hide(); store.event("service_interrupted"); request() }
    override fun onDestroy() {
        disposed = true; gate.close(); main.removeCallbacksAndMessages(null); worker.shutdownNow(); shield.hide(); instance = null; super.onDestroy()
    }
}
object BrowserAddress {
    // Adapters are deliberately narrow. Unknown browsers/custom tabs are not advertised as covered.
    val packages = setOf("com.android.chrome", "org.mozilla.firefox")
    @Suppress("DEPRECATION")
    fun host(root: AccessibilityNodeInfo, pkg: String): String? {
        val ids = when (pkg) {
            "com.android.chrome" -> listOf("url_bar")
            "org.mozilla.firefox" -> listOf("mozac_browser_toolbar_url_view", "toolbar_url_view")
            else -> emptyList()
        }
        for (id in ids) {
            val nodes = root.findAccessibilityNodeInfosByViewId("$pkg:id/$id")
            try {
                for (n in nodes) if (n.isVisibleToUser && !n.isPassword && !n.isFocused) {
                    Domain.normalize(n.text?.toString().orEmpty())?.let { return it }
                }
            } finally { if (Build.VERSION.SDK_INT < 33) nodes.forEach { it.recycle() } }
        }
        return null
    }
}
