package com.hiyozoo.bearlock

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.ScrollView

class Shield(private val context: Context, private val manager: WindowManager = context.getSystemService(WindowManager::class.java)) {
    private var view: ScrollView? = null
    private var identity: String? = null
    fun show(session: ActiveLock, name: String) {
        val id = "${session.key}:$name:${session.end}"
        if (view != null && identity == id) return
        if (!hide()) return
        val ui = Ui(context)
        val body = ui.column().apply { gravity = Gravity.CENTER; setPadding(ui.dp(28),ui.dp(48),ui.dp(28),ui.dp(36)) }
        ui.add(body,ui.asset(R.drawable.bear_locked,220),24)
        ui.add(body,ui.label(tr(context,"${name}は眠っています。","$name is sleeping."),24f,true).apply { gravity=Gravity.CENTER },16)
        val sameDay=java.time.Instant.ofEpochMilli(session.end).atZone(java.time.ZoneId.systemDefault()).toLocalDate()==java.time.LocalDate.now()
        val unlocks=(if(sameDay) "" else java.text.DateFormat.getDateInstance(java.text.DateFormat.SHORT).format(java.util.Date(session.end))+" ")+timeText(session.end,context)
        ui.add(body,ui.label(tr(context,"解除予定 $unlocks","Unlocks at $unlocks"),16f).apply { gravity=Gravity.CENTER },12)
        val navigationError=ui.label(tr(context,"Bear Lockを開けません。ホームに戻ってアプリを開いてください。","Could not open Bear Lock. Return home and open the app."),14f).apply { visibility=android.view.View.GONE }
        ui.add(body,navigationError,12)
        ui.add(body,ui.button(tr(context,"熊を起こす","Wake the bear"),true) {
            try {
                context.startActivity(Intent(context,MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    .putExtra("wakeRuleId",session.ruleId).putExtra("wakeOccurrenceStart",session.start))
                hide()
            } catch (_: RuntimeException) { navigationError.visibility=android.view.View.VISIBLE }
        },12)
        ui.add(body,ui.button(tr(context,"そのまま眠らせる","Keep sleeping")) {
            context.startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); hide()
        })
        val scroll = ScrollView(context).apply { isFillViewport=true; setBackgroundColor(Palette.ice); addView(body) }
        try {
            manager.addView(scroll,WindowManager.LayoutParams(-1,-1,WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,PixelFormat.OPAQUE))
            view=scroll; identity=id; Store(context).event("shield_shown")
        } catch (e: RuntimeException) { Store(context).event("shield_failure:${e.javaClass.simpleName}") }
    }
    fun hide(): Boolean {
        val current = view ?: return true
        try {
            manager.removeView(current)
        } catch (e: RuntimeException) {
            // Already detached is harmless. Otherwise retain the handle for the next tick.
            if (current.parent != null) {
                Store(context).event("shield_hide_failure:${e.javaClass.simpleName}")
                return false
            }
        }
        view = null; identity = null
        Store(context).event("shield_hide_requested")
        return true
    }
}
