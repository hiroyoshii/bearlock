package com.hiyozoo.bearlock

import android.app.AlertDialog
import android.view.Gravity
import android.widget.*

class SelectionSummary(private val a: MainActivity) {
    private val u get()=a.ui
    fun show(parent: LinearLayout, locked: Boolean) {
        val c=u.card(); val top=u.row()
        top.addView(u.label(a.t("選択済み対象","Selected targets"),17f,true),LinearLayout.LayoutParams(0,-2,1f))
        top.addView(u.label(if(a.draft.empty) a.t("未選択","None") else a.t("保存済み","Saved"),13f,false,true))
        u.add(c,top,8)
        if(a.draft.empty) u.add(c,u.label(a.t("ロックする対象を選んでください。","Choose the targets you want to lock."),15f,muted=true),12)
        else {
            val total=u.label(a.t("${a.draft.count}件の対象","${a.draft.count} targets"),14f,muted=true)
            val counts=u.column()
            val entries=listOf(a.t("アプリ","Apps") to a.draft.apps.size,a.t("カテゴリ","Categories") to a.draft.categories.size,a.t("Web","Web") to a.draft.domains.size).filter { it.second>0 }
            u.choices(counts,entries.map { (label,count) -> u.label("$label $count",12f,false,true).apply { gravity=Gravity.CENTER; setPadding(u.dp(8),u.dp(5),u.dp(8),u.dp(5)); background=u.bg(Palette.background) } },if(u.compact) 1 else entries.size.coerceAtLeast(1),4)
            if(u.compact) { u.add(c,total,8); u.add(c,counts,0) }
            else {
                val summary=u.row(); summary.addView(total,LinearLayout.LayoutParams(-2,-2).apply { rightMargin=u.dp(12) }); summary.addView(counts,LinearLayout.LayoutParams(0,-2,1f)); u.add(c,summary,0)
            }
        }
        val disclosure=u.row().apply { minimumHeight=u.dp(44); isClickable=true; isFocusable=true; background=u.touchBackground(android.graphics.Color.TRANSPARENT); contentDescription=a.t("対象一覧","Target list"); setOnClickListener { a.expandedTargets=!a.expandedTargets; a.render() } }
        disclosure.addView(u.label(a.t("対象一覧","Target list"),14f,false,true),LinearLayout.LayoutParams(0,-2,1f))
        disclosure.addView(ImageView(a).apply { setImageDrawable(LineIcon(if(a.expandedTargets) "up" else "down",Palette.muted)); importantForAccessibility=android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO },LinearLayout.LayoutParams(u.dp(18),u.dp(18)))
        u.add(c,disclosure,4)
        val details=u.column(); u.add(c,details,0)
        fun bindDetails() {
            details.removeAllViews()
            val c=details
            if(a.expandedTargets) {
            if(!a.draft.empty) TargetRows(a).details(c,a.draft)
            if(!locked && a.state.recent.isNotEmpty()) {
                u.add(c,u.label(a.t("最近使った対象","Recent selections"),14f,true),8)
                for(recent in Planner.displayedRecent(a.state.recent)) {
                    val r=u.row().apply { background=u.bg(if(recent.targets==a.draft) Palette.ice else Palette.white,8,true).apply { setStroke(u.dp(if(recent.targets==a.draft) 2 else 1),if(recent.targets==a.draft) Palette.navy else Palette.line) }; setPadding(u.dp(4),u.dp(4),u.dp(2),u.dp(4)) }
                    r.addView(TargetRows(a).recent(recent) {
                        a.load()
                        if(a.state.activeLocks(System.currentTimeMillis()).isNotEmpty()) a.error("active_immutable")
                        else { a.draft=recent.targets; a.persistSelection(); a.render() }
                    },LinearLayout.LayoutParams(0,-2,1f))
                    r.addView(u.iconButton("⋯",a.t("対象のメニュー","Selection menu")) {
                        val menu=PopupMenu(a,r.getChildAt(1))
                        menu.menu.add(if(recent.pinned) a.t("ピン解除","Unpin") else a.t("ピン留め","Pin")).setOnMenuItemClickListener {
                            a.mutate { it.copy(recent=Planner.pinRecent(it.recent,recent.targets,!recent.pinned,System.currentTimeMillis())) }; true
                        }
                        menu.menu.add(a.t("削除","Delete")).setOnMenuItemClickListener {
                            AlertDialog.Builder(a).setTitle(a.t("履歴から削除しますか？","Remove from recent selections?"))
                                .setMessage(a.t("予約や実行中のロックには影響しません。","Scheduled and active locks are unchanged."))
                                .setNegativeButton(a.t("キャンセル","Cancel"),null).setPositiveButton(a.t("削除","Delete")) { _,_-> a.mutate { it.copy(recent=it.recent.filterNot { x -> x.targets==recent.targets }) } }.show(); true
                        }; menu.show()
                    }); u.add(c,r,6)
                }
            }
        }
        }
        bindDetails()
        disclosure.setOnClickListener {
            android.transition.TransitionManager.beginDelayedTransition(c,android.transition.AutoTransition().apply { duration=180 })
            a.expandedTargets=!a.expandedTargets
            (disclosure.getChildAt(1) as ImageView).setImageDrawable(LineIcon(if(a.expandedTargets) "up" else "down",Palette.muted))
            bindDetails()
        }
        u.add(c,u.button(if(locked) a.t("ロック中は変更できません","Cannot change during lock") else a.t("ロック対象を選ぶ","Select lock targets")) { a.pickTargets() }.apply { minHeight=u.dp(50); background=android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x33142E4F),u.bg(Palette.ice).apply { setStroke(u.dp(1),Palette.steel) },null); setTextColor(Palette.navy); setTypeface(typeface,android.graphics.Typeface.BOLD); isEnabled=!locked; alpha=if(locked) .55f else 1f },0)
        u.add(parent,c,20)
    }
}

class ActiveCard(private val u: Ui) {
    fun show(parent: LinearLayout, remaining: String, wakes: String): TextView {
        val c=u.card().apply { background=u.bg(Palette.ice,8,true); setPadding(u.dp(28),u.dp(28),u.dp(28),u.dp(28)); gravity=Gravity.CENTER_HORIZONTAL }
        u.add(c,u.asset(R.drawable.bear_sleep,220),18)
        u.add(c,u.label(tr(u.c,"熊は眠っています。","Bear is sleeping."),26f,true).apply { gravity=Gravity.CENTER },16)
        u.add(c,u.label(tr(u.c,"熊を起こさないでください。","Please do not wake the bear."),15f,muted=true).apply { gravity=Gravity.CENTER },24)
        val countdown=u.label(remaining,44f,true).apply { gravity=Gravity.CENTER; typeface=android.graphics.Typeface.create("sans-serif-rounded",android.graphics.Typeface.BOLD) }
        u.add(c,countdown,20)
        u.add(c,u.label(tr(u.c,"${wakes}に起床","Wakes at $wakes"),15f,muted=true).apply { gravity=Gravity.CENTER },0)
        u.add(parent,c,20); return countdown
    }
}

class ScheduleList(private val a: MainActivity) {
    fun show(parent: LinearLayout) {
        val u=a.ui; val now=System.currentTimeMillis()
        u.add(parent,u.label(a.t("ロック予定","Scheduled Locks"),17f,true),12)
        val rules=a.state.rules.filter { rule -> rule.recurring || rule.start>now }
            .sortedBy { it.copy(enabled=true).occurrences(now,now+8*Planner.DAY).firstOrNull()?.start ?: it.start }
        if(rules.isEmpty()) { val c=u.card(); u.add(c,u.label(a.t("ロック予定はありません。","No scheduled locks."),15f,muted=true),0); u.add(parent,c,12) }
        for(rule in rules) {
            val isActive=!Planner.editable(rule,now)
            val r=u.row().apply { background=u.bg(Palette.white,8); setPadding(u.dp(14),u.dp(14),u.dp(8),u.dp(14)) }
            r.addView(ImageView(a).apply { setImageDrawable(LineIcon(if(rule.recurring) "repeat" else "calendar",Palette.steel)) },LinearLayout.LayoutParams(u.dp(22),u.dp(22)).apply { rightMargin=u.dp(12) })
            val info=u.column(); u.add(info,u.label(if(rule.recurring) a.t("繰り返し","Repeats") else rule.title,15f,true),4)
            val next=rule.copy(enabled=true).occurrences(now,now+8*Planner.DAY).firstOrNull()
            u.add(info,u.label(next?.let { dateText(it.start)+"\n→ "+dateText(it.end) } ?: a.t("次の予定はありません","No upcoming lock"),12f,muted=true),0)
            if(isActive) u.add(info,u.label(a.t("実行中です。終了後に変更できます。","This lock is active. Changes are available after it ends."),12f,muted=true),0)
            if(!rule.enabled) u.add(info,u.label(a.t("オフ","Off"),11f,true,true),0)
            r.addView(info,LinearLayout.LayoutParams(0,-2,1f))
            r.addView(u.iconButton("✎",a.t("予約を編集","Edit scheduled lock")) { a.edit(rule) }.apply { isEnabled=!isActive; alpha=if(isActive) .5f else 1f })
            r.addView(u.iconButton("♜",a.t("予約を削除","Delete scheduled lock")) {
                AlertDialog.Builder(a).setTitle(a.t("予約を削除しますか？","Delete this schedule?"))
                    .setNegativeButton(a.t("キャンセル","Cancel"),null).setPositiveButton(a.t("削除","Delete")) { _,_-> a.mutate { Planner.delete(it,rule.id,System.currentTimeMillis()) } }.show()
            }.apply { isEnabled=!isActive; alpha=if(isActive) .5f else 1f; setTextColor(android.graphics.Color.rgb(255,59,48)) })
            u.add(parent,r,12)
        }
    }
}
