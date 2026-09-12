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
fun timeText(ms: Long): String = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(ms))
fun dateText(ms: Long): String = if(java.util.Locale.getDefault().language=="ja") java.text.SimpleDateFormat("yyyy年M月d日 H:mm",java.util.Locale.JAPAN).format(Date(ms)) else DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(ms))
object Palette {
    val background = Color.rgb(242,250,255); val ice = Color.rgb(212,230,247)
    val navy = Color.rgb(20,46,79); val muted = Color.rgb(78,102,129); val line = Color.rgb(218,229,239)
    val subtle = Color.rgb(227,236,245); val steel = Color.rgb(99,143,191); val selected = Color.rgb(214,219,225)
    val warning = Color.rgb(123,65,20); val white = Color.WHITE
}
class Ui(val c: Context) {
    val compact get() = c.resources.configuration.screenWidthDp < 360 || c.resources.configuration.fontScale > 1.2f
    fun dp(n: Int) = (n*c.resources.displayMetrics.density).toInt()
    fun bg(color: Int, radius: Int = 8, border: Boolean = false) = GradientDrawable().apply {
        setColor(color); cornerRadius = dp(radius).toFloat(); if (border) setStroke(dp(1),Palette.line)
    }
    fun touchBackground(color: Int, border: Boolean = false) = android.graphics.drawable.RippleDrawable(
        android.content.res.ColorStateList(arrayOf(intArrayOf(android.R.attr.state_focused),intArrayOf()),intArrayOf(0x33142E4F,0x22142E4F)),bg(color,8,border),bg(Palette.white))
    fun column() = LinearLayout(c).apply { orientation = LinearLayout.VERTICAL }
    fun row() = LinearLayout(c).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
    fun label(value: String, size: Float = 16f, bold: Boolean = false, muted: Boolean = false) = TextView(c).apply {
        text = value; textSize = size; setTextColor(if (muted) Palette.muted else Palette.navy)
        if (bold) setTypeface(typeface, Typeface.BOLD)
        includeFontPadding = false
        setLineSpacing(dp(2).toFloat(),1f)
    }
    fun button(value: String, primary: Boolean = false, action: () -> Unit) = Button(c).apply {
        contentDescription=value
        text = if(value in listOf("ロック開始","ロックを予約","Start lock","Schedule lock")) android.text.SpannableString("  $value").apply {
            setSpan(android.text.style.ImageSpan(LineIcon("lock",Palette.white).apply { setBounds(0,0,dp(16),dp(16)) },android.text.style.ImageSpan.ALIGN_CENTER),0,1,android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        } else value
        isAllCaps = false; textSize = 16f; minHeight = dp(50); minimumHeight=0; minimumWidth=0; includeFontPadding=false
        setPadding(dp(16),dp(8),dp(16),dp(8)); setTextColor(if (primary) Palette.white else Palette.navy)
        background = android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(if(primary) 0x33FFFFFF else 0x22142E4F),bg(if (primary) Palette.navy else Palette.ice,8),null)
        stateListAnimator=null; elevation=0f
        setOnClickListener { action() }
    }
    fun input(hintText: String, value: String = "") = EditText(c).apply {
        hint = hintText; contentDescription = hintText; setText(value); textSize = 16f
        setTextColor(Palette.navy); setHintTextColor(Palette.muted); minHeight = dp(50)
        setPadding(dp(12),dp(8),dp(12),dp(8)); background = bg(Palette.white,12,true)
    }
    fun card() = column().apply { setPadding(dp(16),dp(16),dp(16),dp(16)); background = bg(Palette.white,8) }
    fun asset(resource: Int, height: Int) = ImageView(c).apply {
        setImageResource(resource); scaleType=ImageView.ScaleType.FIT_CENTER
        importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_NO
        val ratio=drawable.intrinsicWidth.toFloat()/drawable.intrinsicHeight
        val width=minOf(dp((height*ratio).toInt()),(c.resources.displayMetrics.widthPixels-dp(96)).coerceAtLeast(dp(120)))
        layoutParams=LinearLayout.LayoutParams(width,(width/ratio).toInt()).apply { gravity=Gravity.CENTER_HORIZONTAL }
        background=bg(Palette.background,8); clipToOutline=true
    }
    fun textButton(value: String, action: () -> Unit) = button(value,false,action).apply {
        background=touchBackground(android.graphics.Color.TRANSPARENT); setPadding(dp(8),dp(4),dp(8),dp(4)); minWidth=0
    }
    fun iconButton(symbol: String, description: String, action: () -> Unit) = textButton(symbol,action).apply {
        contentDescription=description
        val name=when(symbol) { "⚙"->"gear"; "✎"->"edit"; "♜"->"trash"; else->"more" }
        text=""; setCompoundDrawables(LineIcon(name,if(name=="trash") 0xFFFF3B30.toInt() else Palette.steel).apply { setBounds(0,0,dp(20),dp(20)) },null,null,null)
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
