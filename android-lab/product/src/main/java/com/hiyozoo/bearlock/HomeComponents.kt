package com.hiyozoo.bearlock

import android.app.AlertDialog
import android.view.Gravity
import android.widget.*

class SelectionSummary(private val a: MainActivity) {
    private val u get()=a.ui
    fun show(parent: LinearLayout, locked: Boolean) {
        val c=u.card().apply { tag="target-summary" }
        val top=if(u.compact) u.column() else u.row()
        top.addView(u.label(a.t("選択済み対象","Selected targets"),17f,true),if(u.compact) LinearLayout.LayoutParams(-1,-2) else LinearLayout.LayoutParams(0,-2,1f))
        top.addView(u.label(if(a.editor.targets.empty) a.t("なし","None") else a.t("${a.editor.targets.count}件の対象","${a.editor.targets.count} targets"),15f,true,a.editor.targets.empty).apply {
            if(u.compact) setPadding(0,u.dp(4),0,0)
        })
        u.add(c,top,12)
        if(!a.editor.targets.empty) {
        val counts=u.column()
        val entries=listOf(a.t("対象アプリ","Apps") to a.editor.targets.apps.size,a.t("カテゴリ","Categories") to a.editor.targets.categories.size,a.t("Webサイト","Websites") to a.editor.targets.domains.size)
        u.choices(counts,entries.map { (label,count) ->
            u.column().apply {
                background=u.bg(Palette.ice); setPadding(u.dp(4),u.dp(8),u.dp(4),u.dp(8))
                u.add(this,u.label("$count",17f,true).apply { gravity=Gravity.CENTER },2)
                u.add(this,u.label(label,11f,true).apply { gravity=Gravity.CENTER },0)
                contentDescription=a.t("$label ${count}件","$count $label")
                importantForAccessibility=android.view.View.IMPORTANT_FOR_ACCESSIBILITY_YES
                for(i in 0 until childCount) getChildAt(i).importantForAccessibility=android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO
            }
        },if(a.resources.configuration.fontScale>1.2f) 1 else 3,if(a.resources.configuration.fontScale>1.2f) 8 else 0)
        u.add(c,counts,8)
        }
        if(a.editor.targets.empty) u.add(c,u.label(a.t("ロック対象が選択されていません。","No targets are selected."),15f,muted=true),12)
        val disclosure=u.row().apply { minimumHeight=u.dp(44); isClickable=true; isFocusable=true; background=u.touchBackground(android.graphics.Color.TRANSPARENT); contentDescription=a.t("対象一覧","Target list")
            accessibilityDelegate=object: android.view.View.AccessibilityDelegate() {
                override fun onInitializeAccessibilityNodeInfo(host: android.view.View, info: android.view.accessibility.AccessibilityNodeInfo) {
                    super.onInitializeAccessibilityNodeInfo(host,info); info.className="android.widget.Button"
                    if(android.os.Build.VERSION.SDK_INT>=30) info.stateDescription=if(a.expandedTargets) a.t("展開中","Expanded") else a.t("折りたたみ","Collapsed")
                }
            }
        }
        disclosure.addView(u.label(a.t("対象一覧","Target list"),15f,true,true).apply {
            importantForAccessibility=android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO
            setCompoundDrawables(u.icon("category",Palette.muted).apply { setBounds(0,0,u.dp(18),u.dp(18)) },null,null,null)
            compoundDrawablePadding=u.dp(8)
        },LinearLayout.LayoutParams(0,-2,1f))
        disclosure.addView(ImageView(a).apply { setImageDrawable(u.icon(if(a.expandedTargets) "up" else "down",Palette.muted)); importantForAccessibility=android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO },LinearLayout.LayoutParams(u.dp(18),u.dp(18)))
        u.add(c,disclosure,4)
        val details=u.column(); u.add(c,details,0)
        fun bindDetails() {
            details.removeAllViews()
            val c=details
            if(a.expandedTargets) {
            if(!a.editor.targets.empty) TargetRows(a).details(c,a.editor.targets)
            if(!locked && a.state.recent.isNotEmpty()) {
                u.add(c,android.view.View(a).apply { background=u.bg(Palette.line,0); layoutParams=LinearLayout.LayoutParams(-1,u.dp(1)).apply { topMargin=u.dp(12) } },12)
                u.add(c,u.label(a.t("最近使った対象","Recent targets"),12f,true,true),8)
                for(recent in Planner.displayedRecent(a.state.recent)) {
                    val r=u.row().apply { background=u.bg(if(recent.targets==a.editor.targets) Palette.ice else Palette.white,8,true).apply { setStroke(u.dp(if(recent.targets==a.editor.targets) 2 else 1),if(recent.targets==a.editor.targets) Palette.navy else Palette.line) }; setPadding(u.dp(4),u.dp(4),u.dp(2),u.dp(4)) }
                    r.addView(TargetRows(a).recent(recent) {
                        if(a.selectTargets(recent.targets)) a.render()
                    },LinearLayout.LayoutParams(0,-2,1f))
                    r.addView(u.iconButton("more",a.t("対象の操作","Target actions")) {
                        val menu=PopupMenu(a,r.getChildAt(1))
                        menu.menu.add(if(recent.pinned) a.t("対象の固定を解除","Unpin target") else a.t("対象を固定","Pin target")).setOnMenuItemClickListener {
                            a.setRecentPinned(recent,!recent.pinned); true
                        }
                        menu.menu.add(a.t("対象を削除","Remove target")).setOnMenuItemClickListener {
                            AlertDialog.Builder(a).setTitle(a.t("最近使った対象から削除しますか？","Remove from recent targets?"))
                                .setMessage(a.t("作成済みの予定と実行中のロックは変更されません。","Existing schedules and the active lock will not change."))
                                .setNegativeButton(a.t("キャンセル","Cancel"),null).setPositiveButton(a.t("削除","Remove")) { _,_-> a.deleteRecentTarget(recent) }.show(); true
                        }; menu.show()
                    }); u.add(c,r,8)
                }
            }
        }
        }
        bindDetails()
        disclosure.setOnClickListener {
            android.transition.TransitionManager.beginDelayedTransition(c,android.transition.AutoTransition().apply { duration=180 })
            a.expandedTargets=!a.expandedTargets
            (disclosure.getChildAt(1) as ImageView).setImageDrawable(u.icon(if(a.expandedTargets) "up" else "down",Palette.muted))
            bindDetails()
        }
        u.add(c,u.button(if(!a.savedDataAvailable) a.t("保存データを確認できません","Saved data is unavailable") else if(locked) a.t("ロック中は変更できません","Cannot change during lock") else a.t("ロック対象を選ぶ","Select targets"),radius=100) { a.pickTargets() }.apply {
            minHeight=u.dp(44); textSize=17f
            background=android.graphics.drawable.InsetDrawable(u.touchBackground(if(locked) Palette.disabled else Palette.subtle,radius=100),0,u.dp(3),0,u.dp(3)); setTextColor(if(locked) Palette.muted else Palette.link)
            text=android.text.SpannableString("  $text").apply {
                setSpan(android.text.style.ImageSpan(u.icon("select",if(locked) Palette.muted else Palette.link).apply { setBounds(0,0,u.dp(18),u.dp(18)) },android.text.style.ImageSpan.ALIGN_BASELINE),0,1,android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            isEnabled=!locked && a.savedDataAvailable
        },0)
        u.add(parent,c,20)
    }
}

class ActiveCard(private val u: Ui) {
    fun show(parent: LinearLayout, remaining: String, wakes: String, wakeRequest: WakeRequest?, canScheduleWake: Boolean = true, onWake: () -> Unit): TextView {
        val c=u.card().apply { background=u.bg(Palette.ice,8,true).apply { setStroke(u.dp(1),Palette.outline) }; setPadding(u.dp(28),u.dp(28),u.dp(28),u.dp(28)); gravity=Gravity.CENTER_HORIZONTAL }
        u.add(c,u.asset(R.drawable.bear_sleep,225).apply { background=u.bg(Palette.ice,8); clipToOutline=true },18)
        u.add(c,u.label(tr(u.c,"熊は眠っています。","Bear is sleeping."),28f,true).apply { gravity=Gravity.CENTER },18)
        u.add(c,u.label(tr(u.c,"熊を起こさないでください。","Do not wake the bear."),17f,muted=true).apply { gravity=Gravity.CENTER },18)
        val countdown=u.label(remaining,44f,true).apply { gravity=Gravity.CENTER; typeface=android.graphics.Typeface.create("sans-serif-rounded",android.graphics.Typeface.BOLD) }
        u.add(c,countdown,18)
        u.add(c,u.label(tr(u.c,"${wakes}に起床","Wakes at $wakes"),15f,muted=true).apply { gravity=Gravity.CENTER },0)
        if(wakeRequest!=null || canScheduleWake) u.add(c,u.button(tr(u.c,"熊を起こす","Wake the bear"),radius=100,action=onWake).apply {
            tag="open-wake-options"
            background=u.touchBackground(Palette.subtle,radius=100); setTextColor(Palette.link)
            minHeight=u.dp(44); textSize=15f; layoutParams=LinearLayout.LayoutParams(-2,-2).apply { gravity=Gravity.CENTER_HORIZONTAL }
        },0)
        u.add(parent,c,20); return countdown
    }
}

class ScheduleList(private val a: MainActivity) {
    fun show(parent: LinearLayout) {
        val u=a.ui; val now=System.currentTimeMillis()
        u.add(parent,u.label(a.t("ロック予定","Scheduled Locks"),17f,true),12)
        val rules=a.state.scheduledRules(now)
        if(rules.isEmpty()) { val c=u.card(); u.add(c,u.label(a.t("予定されたロックはありません。","No scheduled locks."),15f,muted=true),0); u.add(parent,c,12) }
        for(rule in rules) {
            val isActive=!Planner.editable(a.state,rule,now)
            val canEdit=Planner.scheduleEditable(a.state,rule,now)
            val r=u.row().apply { background=u.bg(Palette.white,8); setPadding(u.dp(14),u.dp(14),u.dp(8),u.dp(14)) }
            r.addView(ImageView(a).apply { setImageDrawable(u.icon(if(rule.recurring) "repeat" else "calendar",Palette.steel)) },LinearLayout.LayoutParams(u.dp(22),u.dp(22)).apply { rightMargin=u.dp(12) })
            val title=when(rule.title) {
                "あとで開始","Starts later" -> a.t("あとで開始","Starts later")
                "日時指定","Date & Time" -> a.t("日時指定","Date & Time")
                else -> rule.title
            }
            val info=u.column(); u.add(info,u.label(if(rule.recurring) a.t("繰り返し","Repeats") else title,15f,true),4)
            val next=rule.copy(enabled=true).nextOccurrence(now)
            val interval=next?.let { a.state.effective(it) }
            val intervalText=interval?.let { dateText(it.start,a,rule.weekly?.zone)+(if(u.compact) "\n→ " else " → ")+dateText(it.end,a,rule.weekly?.zone) }
            u.add(info,u.label(intervalText ?: a.t("今後の冬眠予定はありません","No upcoming hibernation"),12f,muted=true),0)
            if(isActive) u.add(info,u.label(if(rule.recurring) a.t("実行中です。予定を削除すると、このロックも終了します。","Active. You can delete this schedule to end its lock.") else a.t("実行中です。開始後は予定の編集・削除はできません。","Active. This schedule cannot be edited or deleted after it starts."),12f,muted=true),0)
            else if(!canEdit) u.add(info,u.label(a.t("起床済みです。開始後は予定の編集・削除はできません。","Woken. This schedule cannot be edited or deleted after it starts."),12f,muted=true),0)
            if(!rule.enabled) u.add(info,u.label(a.t("オフ","Off"),11f,true,true),0)
            r.addView(info,LinearLayout.LayoutParams(0,-2,1f))
            r.addView(u.iconButton("edit",a.t("予定ロックを編集","Edit scheduled lock")) { a.edit(rule) }.apply { isEnabled=canEdit; alpha=if(canEdit) 1f else .5f })
            r.addView(u.iconButton("trash",a.t("予定ロックを削除","Delete scheduled lock")) {
                AlertDialog.Builder(a).setTitle(a.t("この予約を削除しますか？","Delete this schedule?"))
                    .setMessage(listOf(title,a.t("対象: ","Targets: ")+a.catalog.summary(rule.targets),intervalText,if(rule.recurring) a.t("この予定による実行中のロックも終了します。他の予定によるロックは続きます。","Deleting this schedule also ends its active lock. Other schedules will keep blocking their targets.") else a.t("この予定を削除します。他の予定は変更しません。","This schedule will be deleted. Other schedules are unchanged.")).filterNotNull().joinToString("\n\n"))
                    .setNegativeButton(a.t("キャンセル","Cancel"),null).setPositiveButton(a.t("削除","Delete")) { _,_-> a.deleteSchedule(rule.id) }.show()
            }.apply { isEnabled=rule.recurring || canEdit; alpha=if(isEnabled) 1f else .5f; setTextColor(android.graphics.Color.rgb(255,59,48)) })
            u.add(parent,r,12)
        }
    }
}
