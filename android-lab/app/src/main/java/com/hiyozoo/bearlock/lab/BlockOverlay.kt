package com.hiyozoo.bearlock.lab

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import java.text.DateFormat
import java.util.Date

/** A uses application overlay, B uses accessibility overlay; this difference is measured explicitly. */
class BlockOverlay(private val context: Context, private val type: Int) {
    private val manager = context.getSystemService(WindowManager::class.java)
    private var view: LinearLayout? = null
    private val store = LabStore(context)
    fun show(window: LockWindow, sourceWallMs: Long?) {
        if (view != null) return
        val body = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(32, 32, 32, 32)
            setBackgroundColor(Color.rgb(235, 245, 249))
        }
        body.addView(TextView(context).apply {
            text = "このアプリは眠っています。\n\n${DateFormat.getTimeInstance().format(Date(window.end))} に解除\nBear Lock Lab · ${window.method}"
            textSize = 24f; gravity = Gravity.CENTER; setTextColor(Color.rgb(27, 49, 67))
        })
        body.addView(Button(context).apply {
            text = "ホームに戻る"
            setOnClickListener {
                context.startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                hide("home")
            }
        })
        val params = WindowManager.LayoutParams(-1, -1, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.OPAQUE)
        try {
            manager.addView(body, params)
            view = body
            store.event("overlay_added", JSONObject().put("method", window.method).put("target", window.target)
                .put("sourceWallMs", sourceWallMs).put("eventToAddMs", sourceWallMs?.let { System.currentTimeMillis() - it }))
            // The first posted frame is diagnostic, not proof that the display compositor showed it.
            body.postOnAnimation { if (view === body) store.event("overlay_frame", JSONObject().put("method", window.method)) }
        } catch (e: RuntimeException) {
            store.event("overlay_error", JSONObject().put("error", e.javaClass.simpleName))
        }
    }
    fun hide(reason: String) {
        view?.let {
            manager.removeView(it)
            view = null
            store.event("overlay_removed", JSONObject().put("reason", reason))
        }
    }
}
