package com.hiyozoo.bearlock

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.ScrollView

class Shield(private val context: Context) {
    private val manager = context.getSystemService(WindowManager::class.java)
    private var view: ScrollView? = null
    private var identity: String? = null
    fun show(session: Session, name: String) {
        val id = "${session.key}:$name:${session.end}"
        if (view != null && identity == id) return
        hide()
        val ui = Ui(context)
        val body = ui.column().apply { gravity = Gravity.CENTER; setPadding(ui.dp(28),ui.dp(48),ui.dp(28),ui.dp(36)) }
        ui.add(body,ui.asset(R.drawable.bear_locked,220),24)
        ui.add(body,ui.label(name+"\n"+tr(context,"は眠っています。","is sleeping."),24f,true).apply { gravity=Gravity.CENTER },16)
        ui.add(body,ui.label(tr(context,"${timeText(session.end)} に解除","Wakes at ${timeText(session.end)}"),16f).apply { gravity=Gravity.CENTER },12)
        ui.add(body,ui.button("OK",true) {
            context.startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); hide()
        })
        val scroll = ScrollView(context).apply { isFillViewport=true; setBackgroundColor(Palette.ice); addView(body) }
        try {
            manager.addView(scroll,WindowManager.LayoutParams(-1,-1,WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,PixelFormat.OPAQUE))
            view=scroll; identity=id; Store(context).event("shield_shown")
        } catch (e: RuntimeException) { Store(context).event("shield_failure:${e.javaClass.simpleName}") }
    }
    fun hide() { view?.let { runCatching { manager.removeView(it) }; Store(context).event("shield_hidden") }; view=null; identity=null }
}
