package com.hiyozoo.bearlock

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.widget.*
import java.text.DateFormat
import java.util.Date

fun tr(c: Context, ja: String, en: String): String {
    val testLanguage=if(BuildConfig.DEBUG) c.getSharedPreferences("appearance",0).getString("language","").orEmpty() else ""
    val language=testLanguage.ifEmpty { c.resources.configuration.locales[0].language }
    return if(language=="ja") ja else en
}
fun configureLanguage(c: Context) {
    val language=if(BuildConfig.DEBUG) c.getSharedPreferences("appearance",0).getString("language","").orEmpty() else ""
    java.util.Locale.setDefault(if(language.isEmpty()) c.resources.configuration.locales[0] else java.util.Locale.forLanguageTag(language))
}
fun timeText(ms: Long, context: Context, zone: String? = null): String = android.text.format.DateFormat.getTimeFormat(context)
    .apply { if(zone != null) timeZone=java.util.TimeZone.getTimeZone(zone) }.format(Date(ms))
fun dateText(ms: Long, context: Context, zone: String? = null): String {
    val date=if(java.util.Locale.getDefault().language=="ja") java.text.SimpleDateFormat("yyyy年M月d日",java.util.Locale.JAPAN)
        else DateFormat.getDateInstance(DateFormat.MEDIUM)
    if(zone != null) date.timeZone=java.util.TimeZone.getTimeZone(zone)
    return date.format(Date(ms))+" "+timeText(ms,context,zone)
}
object Palette {
    val grouped = Color.rgb(242,242,247)
    val control = Color.rgb(238,238,240)
    val textPrimary = Color.BLACK
    val background = Color.rgb(242,250,255); val ice = Color.rgb(212,230,247)
    val navy = Color.rgb(20,46,79); val muted = Color.rgb(78,102,129); val line = Color.rgb(218,229,239)
    val subtle = Color.rgb(227,236,245); val steel = Color.rgb(99,143,191)
    val link = Color.rgb(53,106,159)
    val navigation = Color.rgb(0,122,255)
    val disabled = Color.rgb(232,232,234)
    val outline = Color.argb(40,Color.red(navy),Color.green(navy),Color.blue(navy))
    val warning = Color.rgb(123,65,20); val white = Color.WHITE
}
class Ui(val c: Context) {
    val compact get() = c.resources.configuration.screenWidthDp < 360 || c.resources.configuration.fontScale > 1.2f
    fun dp(n: Int) = (n*c.resources.displayMetrics.density).toInt()
    /** Google Material Icons geometry; native theme tint only. See assets/material-icons/source.json. */
    fun icon(name: String, color: Int = Palette.navy): android.graphics.drawable.Drawable {
        val resource=when(name) {
            "warning" -> R.drawable.outline_warning_24
            "apps" -> R.drawable.outline_apps_24
            "select" -> R.drawable.outline_filter_none_24
            "category" -> R.drawable.outline_list_24
            "web" -> R.drawable.outline_language_24
            "heart" -> R.drawable.outline_favorite_border_24
            "info" -> R.drawable.outline_info_24
            "trash" -> R.drawable.outline_delete_24
            "edit" -> R.drawable.outline_edit_24
            "down" -> R.drawable.outline_expand_more_24
            "up" -> R.drawable.outline_expand_less_24
            "right" -> R.drawable.outline_chevron_right_24
            "gear" -> R.drawable.outline_settings_24
            "calendar" -> R.drawable.outline_event_24
            "repeat" -> R.drawable.outline_repeat_24
            "lock" -> R.drawable.outline_lock_24
            "more" -> R.drawable.outline_more_horiz_24
            "pin" -> R.drawable.outline_push_pin_24
            "close" -> R.drawable.outline_close_24
            else -> error("Unknown Material icon: $name")
        }
        return requireNotNull(c.getDrawable(resource)).mutate().apply { setTint(color) }
    }
    fun bg(color: Int, radius: Int = 8, border: Boolean = false) = GradientDrawable().apply {
        setColor(color); cornerRadius = dp(radius).toFloat(); if (border) setStroke(dp(1),Palette.line)
    }
    fun touchBackground(color: Int, border: Boolean = false, radius: Int = 8) = android.graphics.drawable.RippleDrawable(
        android.content.res.ColorStateList(arrayOf(intArrayOf(android.R.attr.state_focused),intArrayOf()),intArrayOf(0x33142E4F,0x22142E4F)),bg(color,radius,border),bg(Palette.white,radius))
    fun column() = LinearLayout(c).apply { orientation = LinearLayout.VERTICAL }
    fun row() = LinearLayout(c).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
    fun label(value: String, size: Float = 16f, bold: Boolean = false, muted: Boolean = false) = TextView(c).apply {
        text = value; textSize = size; setTextColor(if (muted) Palette.muted else Palette.navy)
        if (bold) setTypeface(typeface, Typeface.BOLD)
        includeFontPadding = false
        setLineSpacing(dp(2).toFloat(),1f)
    }
    fun button(value: String, primary: Boolean = false, radius: Int = 8, action: () -> Unit) = Button(c).apply {
        contentDescription=value
        text = if(value in listOf("ロック開始","ロックを予約","Start Lock","Schedule Lock")) android.text.SpannableString("  $value").apply {
            setSpan(android.text.style.ImageSpan(icon("lock",Palette.white).apply { setBounds(0,0,dp(16),dp(16)) },android.text.style.ImageSpan.ALIGN_CENTER),0,1,android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        } else value
        isAllCaps = false; textSize = 16f; minHeight = dp(50); minimumHeight=0; minimumWidth=0; includeFontPadding=false
        setPadding(dp(16),dp(8),dp(16),dp(8)); setTextColor(if (primary) Palette.white else Palette.navy)
        background = android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(if(primary) 0x33FFFFFF else 0x22142E4F),bg(if (primary) Palette.navy else Palette.ice,radius),null)
        stateListAnimator=null; elevation=0f
        setOnClickListener { action() }
    }
    fun dateTimeButton(value: String, description: String, action: () -> Unit) = button(value,action=action).apply {
        contentDescription=description
        background=touchBackground(Palette.control,radius=100)
        textSize=17f; minWidth=dp(76); minHeight=dp(44)
        setPadding(dp(12),dp(6),dp(12),dp(6))
    }
    fun input(hintText: String, value: String = "") = EditText(c).apply {
        hint = hintText; contentDescription = hintText; setText(value); textSize = 16f
        setTextColor(Palette.navy); setHintTextColor(Palette.muted); minHeight = dp(50)
        setPadding(dp(12),dp(8),dp(12),dp(8)); background = bg(Palette.white,12,true)
    }
    fun card() = column().apply { setPadding(dp(16),dp(16),dp(16),dp(16)); background = bg(Palette.white,8) }
    fun section(parent: LinearLayout, title: String? = null): LinearLayout {
        title?.let { add(parent,label(it,13f,muted=true).apply { setPadding(dp(16),0,0,0) },8) }
        return card().apply { background=bg(Palette.white,20); add(parent,this,24) }
    }
    fun divider(parent: LinearLayout) = add(parent,View(c).apply {
        setBackgroundColor(Palette.control); layoutParams=LinearLayout.LayoutParams(-1,dp(1))
    },0)
    fun asset(resource: Int, height: Int) = ImageView(c).apply {
        setImageResource(resource); scaleType=ImageView.ScaleType.FIT_CENTER
        importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_NO
        val ratio=drawable.intrinsicWidth.toFloat()/drawable.intrinsicHeight
        val width=minOf(dp((height*ratio).toInt()),(c.resources.displayMetrics.widthPixels-dp(96)).coerceAtLeast(dp(120)))
        layoutParams=LinearLayout.LayoutParams(width,(width/ratio).toInt()).apply { gravity=Gravity.CENTER_HORIZONTAL }
        background=bg(Palette.background,8); clipToOutline=true
    }
    fun textButton(value: String, action: () -> Unit) = button(value,action=action).apply {
        background=touchBackground(android.graphics.Color.TRANSPARENT); setPadding(dp(8),dp(4),dp(8),dp(4)); minWidth=0
    }
    fun iconButton(name: String, description: String, action: () -> Unit) = textButton("",action).apply {
        contentDescription=description
        text=""; setCompoundDrawables(icon(name,if(name=="trash") 0xFFFF3B30.toInt() else Palette.steel).apply { setBounds(0,0,dp(20),dp(20)) },null,null,null)
        setPadding(dp(12),dp(14),dp(12),dp(14)); layoutParams=LinearLayout.LayoutParams(dp(44),dp(48))
    }
    fun pair(parent: LinearLayout, name: String, value: String, gap: Int = 12, emphasized: Boolean = false) {
        if(compact) {
            val group=column(); add(group,label(name,14f,emphasized,true),4); add(group,label(value,15f,emphasized),0); add(parent,group,gap); return
        }
        val r=row(); r.addView(label(name,14f,emphasized,true),LinearLayout.LayoutParams(0,-2,1f))
        r.addView(label(value,15f,emphasized).apply { gravity=Gravity.END },LinearLayout.LayoutParams(0,-2,2f)); add(parent,r,gap)
    }
    fun art(sleep: Boolean = false, height: Int = 180) = ImageView(c).apply {
        setImageResource(if(sleep) R.drawable.bear_sleep else R.drawable.bear_ready)
        scaleType = ImageView.ScaleType.FIT_CENTER; importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        layoutParams = LinearLayout.LayoutParams(-1,dp(height))
    }
    fun add(parent: LinearLayout, child: View, gap: Int = 12) {
        val p = child.layoutParams as? LinearLayout.LayoutParams ?: LinearLayout.LayoutParams(-1,-2)
        p.bottomMargin = dp(gap); parent.addView(child,p)
    }
    fun choices(parent: LinearLayout, items: List<View>, columns: Int, gap: Int = 8) {
        for (chunk in items.chunked(columns)) {
            val row=row()
            chunk.forEachIndexed { index, view ->
                row.addView(view,LinearLayout.LayoutParams(0,-2,1f).apply { if(index<columns-1) rightMargin=dp(8) })
            }
            repeat(columns-chunk.size) { row.addView(View(c),LinearLayout.LayoutParams(0,1,1f)) }
            add(parent,row,gap)
        }
    }
    fun heading(parent: LinearLayout, title: String, sub: String? = null) {
        add(parent,label(title,28f,true),8); sub?.let { add(parent,label(it,15f,muted=true),24) }
    }
}
