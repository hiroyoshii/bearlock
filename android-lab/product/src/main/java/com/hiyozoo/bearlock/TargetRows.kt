package com.hiyozoo.bearlock

import android.view.Gravity
import android.view.View
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.*

/** Shared target summaries for selection details and recent targets. */
class TargetRows(private val a: MainActivity) {
    private val u get()=a.ui
    companion object { private val icons=java.util.concurrent.Executors.newSingleThreadExecutor() }
    private fun icon(pkg: String?, symbol: String): ImageView = ImageView(a).apply {
        setImageDrawable(u.icon(symbol,Palette.steel)); importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_NO
        layoutParams=LinearLayout.LayoutParams(u.dp(20),u.dp(20)).apply { rightMargin=u.dp(10) }
        if(pkg != null) {
            val pm=a.applicationContext.packageManager
            val target=this
            icons.execute {
                val drawable=runCatching { pm.getApplicationIcon(pkg) }.getOrNull()
                target.post { if(target.isAttachedToWindow && drawable != null) target.setImageDrawable(drawable) }
            }
        }
    }
    fun details(parent: LinearLayout, targets: Targets) {
        fun group(title: String, entries: List<Pair<String,String?>>, symbol: String) {
            if(entries.isEmpty()) return
            if(listOf(targets.apps,targets.categories,targets.domains).count { it.isNotEmpty() }>1) u.add(parent,u.label(title,12f,true,true),4)
            for((name,pkg) in entries.take(5)) {
                val row=u.row().apply { setPadding(0,u.dp(4),0,u.dp(4)) }
                row.addView(icon(pkg,symbol))
                row.addView(u.label(name,17f).apply { setTextColor(Palette.textPrimary); maxLines=2; ellipsize=android.text.TextUtils.TruncateAt.END },LinearLayout.LayoutParams(0,-2,1f))
                row.contentDescription=name; u.add(parent,row,0)
            }
        }
        group(a.t("アプリ","Apps"),targets.apps.sorted().map { a.catalog.name(it) to it },"apps")
        group(a.t("カテゴリ","Categories"),targets.categories.sorted().map { a.catalog.categoryName(it) to null },"category")
        group(a.t("Webサイト","Websites"),targets.domains.sorted().map { it to null },"web")
        val overflow=listOf(targets.apps.size,targets.categories.size,targets.domains.size).sumOf { (it-5).coerceAtLeast(0) }
        if(overflow>0) u.add(parent,u.label(a.t("ほか${overflow}件","+$overflow more"),13f,true,true),12)
    }
    fun recent(recent: Recent, select: ()->Unit): LinearLayout {
        val t=recent.targets; val selected=t==a.editor.targets
        val pkg=t.apps.sorted().firstOrNull()
        val name=pkg?.let(a.catalog::name) ?: t.categories.sorted().firstOrNull()?.let(a.catalog::categoryName) ?: t.domains.sorted().firstOrNull().orEmpty()
        val row=u.row().apply {
            minimumHeight=u.dp(52); setPadding(u.dp(8),u.dp(8),u.dp(8),u.dp(8))
            isClickable=true; isFocusable=true; background=u.touchBackground(android.graphics.Color.TRANSPARENT)
            contentDescription=listOf(if(recent.pinned) a.t("ピン留め","Pinned") else "",name,a.t("${t.count}件の対象","${t.count} targets"),if(selected) a.t("選択中","Selected") else a.t("未選択","Not selected")).filter { it.isNotEmpty() }.joinToString("、")
            accessibilityDelegate=object: View.AccessibilityDelegate() {
                override fun onInitializeAccessibilityNodeInfo(host: View, info: AccessibilityNodeInfo) { super.onInitializeAccessibilityNodeInfo(host,info); info.className="android.widget.Button"; info.isSelected=selected }
            }
            setOnClickListener { select() }
        }
        val text=u.column().apply { importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS }
        u.add(text,u.label(a.t("${t.count}件の対象","${t.count} targets"),15f,true).apply {
            if(recent.pinned) {
                setCompoundDrawables(u.icon("pin").apply { setBounds(0,0,u.dp(16),u.dp(16)) },null,null,null)
                compoundDrawablePadding=u.dp(4)
            }
        },3)
        u.add(text,u.label(a.t("保存済み対象","Saved target"),12f,muted=true),0)
        val badge=u.label(a.t("選択中","Selected"),12f,true).apply { importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_NO; setTextColor(Palette.white); background=u.bg(Palette.navy,20); setPadding(u.dp(8),u.dp(5),u.dp(8),u.dp(5)) }
        if(selected && u.compact) u.add(text,badge,0)
        row.addView(text,LinearLayout.LayoutParams(0,-2,1f))
        if(selected && !u.compact) row.addView(badge)
        return row
    }
}
