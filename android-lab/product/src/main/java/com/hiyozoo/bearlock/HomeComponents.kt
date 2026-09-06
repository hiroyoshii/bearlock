package com.hiyozoo.bearlock

import android.app.AlertDialog
import android.view.Gravity
import android.widget.*

class SelectionSummary(private val a: MainActivity) {
    private val u get()=a.ui
    fun show(parent: LinearLayout, locked: Boolean) {
        val c=u.card(); val top=u.row()
        top.addView(u.label(a.t("選択済み対象","Selected targets"),17f,true),LinearLayout.LayoutParams(0,-2,1f))
        top.addView(u.label(if(a.draft.empty) a.t("未選択","None") else a.t("保存済み","Saved"),14f,true,true))
        u.add(c,top,12)
        if(a.draft.empty) u.add(c,u.label(a.t("ロックする対象を選んでください。","Choose the targets you want to lock."),15f,muted=true),12)
        else {
            u.add(c,u.label(a.t("${a.draft.count}件の対象","${a.draft.count} targets"),15f,muted=true),10)
            val counts=u.row()
            for((label,count) in listOf(a.t("アプリ","Apps") to a.draft.apps.size,a.t("カテゴリ","Categories") to a.draft.categories.size,a.t("Web","Web") to a.draft.domains.size)) {
                counts.addView(u.label("$label $count",12f,true,true).apply { gravity=Gravity.CENTER; setPadding(u.dp(4),u.dp(6),u.dp(4),u.dp(6)); background=u.bg(Palette.background) },LinearLayout.LayoutParams(0,-2,1f).apply { rightMargin=u.dp(4) })
            }
            u.add(c,counts,6)
        }
        u.add(c,u.textButton(a.t("☷  対象一覧","☷  Target list")+if(a.expandedTargets) "  ⌃" else "  ⌄") { a.expandedTargets=!a.expandedTargets; a.render() }.apply { minHeight=u.dp(32); gravity=Gravity.START or Gravity.CENTER_VERTICAL; contentDescription=a.t("対象一覧","Target list"); setTypeface(typeface,android.graphics.Typeface.BOLD) },8)
        if(a.expandedTargets) {
            if(!a.draft.empty) u.add(c,u.label(a.catalog.summary(a.draft),14f,muted=true),12)
            if(!locked && a.state.recent.isNotEmpty()) {
                u.add(c,u.label(a.t("最近使った対象","Recent selections"),14f,true),8)
                for(recent in a.state.recent) {
                    val r=u.row().apply { background=u.bg(if(recent.targets==a.draft) Palette.ice else Palette.background); setPadding(u.dp(6),0,u.dp(2),0) }
                    r.addView(u.textButton((if(recent.pinned) "⌖ " else "")+a.catalog.summary(recent.targets)) {
                        a.load()
                        if(a.state.sessions.any { it.active(System.currentTimeMillis()) }) a.error("active_immutable")
                        else { a.draft=recent.targets; a.persistSelection(); a.render() }
                    }.apply { textSize=13f; gravity=Gravity.START or Gravity.CENTER_VERTICAL },LinearLayout.LayoutParams(0,-2,1f))
                    r.addView(u.iconButton("⋯",a.t("対象のメニュー","Selection menu")) {
                        val menu=PopupMenu(a,r.getChildAt(1))
                        menu.menu.add(if(recent.pinned) a.t("ピン解除","Unpin") else a.t("ピン留め","Pin")).setOnMenuItemClickListener {
                            a.mutate { it.copy(recent=Planner.trimRecent(it.recent.map { x -> if(x.targets==recent.targets) x.copy(pinned=!x.pinned) else x })) }; true
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
        u.add(c,u.button(if(locked) a.t("ロック中は変更できません","Cannot change during lock") else a.t("ロック対象を選ぶ","Select lock targets")) { a.pickTargets() }.apply { minHeight=u.dp(36); background=u.bg(Palette.subtle); setTextColor(Palette.steel); isEnabled=!locked; alpha=if(locked) .55f else 1f },0)
        u.add(parent,c,20)
    }
}

class ActiveCard(private val u: Ui) {
    fun show(parent: LinearLayout, remaining: String, wakes: String): TextView {
        val c=u.card().apply { background=u.bg(Palette.ice,8,true); setPadding(u.dp(28),u.dp(28),u.dp(28),u.dp(28)); gravity=Gravity.CENTER_HORIZONTAL }
        u.add(c,u.asset(R.drawable.bear_sleep,220),18)
        u.add(c,u.label(tr(u.c,"熊は眠っています。","Bear is sleeping."),28f,true).apply { gravity=Gravity.CENTER },10)
        u.add(c,u.label(tr(u.c,"熊を起こさないでください。","Please do not wake the bear."),15f,muted=true).apply { gravity=Gravity.CENTER },16)
        val countdown=u.label(remaining,44f,true).apply { gravity=Gravity.CENTER; typeface=android.graphics.Typeface.create("sans-serif-rounded",android.graphics.Typeface.BOLD) }
        u.add(c,countdown,10)
        u.add(c,u.label(tr(u.c,"${wakes}に起床","Wakes at $wakes"),16f).apply { gravity=Gravity.CENTER },0)
        u.add(parent,c,20); return countdown
    }
}

class ScheduleList(private val a: MainActivity) {
    fun show(parent: LinearLayout) {
        val u=a.ui; val now=System.currentTimeMillis()
        u.add(parent,u.label(a.t("ロック予定","Scheduled Locks"),17f,true),12)
        val rules=a.state.rules.filter { rule -> (rule.recurring || rule.start>now) && a.state.sessions.none { it.ruleId==rule.id && it.active(now) } }
            .sortedBy { it.copy(enabled=true).occurrences(now,now+8*Planner.DAY).firstOrNull()?.start ?: it.start }
        if(rules.isEmpty()) { val c=u.card(); u.add(c,u.label(a.t("ロック予定はありません。","No scheduled locks."),15f,muted=true),0); u.add(parent,c,12) }
        for(rule in rules) {
            val r=u.row().apply { background=u.bg(Palette.white,8); setPadding(u.dp(14),u.dp(14),u.dp(8),u.dp(14)) }
            r.addView(ImageView(a).apply { setImageDrawable(LineIcon(if(rule.recurring) "repeat" else "calendar",Palette.steel)) },LinearLayout.LayoutParams(u.dp(22),u.dp(22)).apply { rightMargin=u.dp(12) })
            val info=u.column(); u.add(info,u.label(if(rule.recurring) a.t("繰り返し","Repeats") else rule.title,15f,true),4)
            val next=rule.copy(enabled=true).occurrences(now,now+8*Planner.DAY).firstOrNull()
            u.add(info,u.label(next?.let { dateText(it.start)+" → "+dateText(it.end) } ?: a.t("次の予定はありません","No upcoming lock"),12f,muted=true),0)
            if(!rule.enabled) u.add(info,u.label(a.t("オフ","Off"),11f,true,true),0)
            r.addView(info,LinearLayout.LayoutParams(0,-2,1f))
            r.addView(u.iconButton("✎",a.t("予約を編集","Edit scheduled lock")) { a.edit(rule) })
            r.addView(u.iconButton("♜",a.t("予約を削除","Delete scheduled lock")) {
                AlertDialog.Builder(a).setTitle(a.t("予約を削除しますか？","Delete this schedule?"))
                    .setMessage(a.t("実行中のロックは終了時刻まで続きます。","An active lock continues until its end time."))
                    .setNegativeButton(a.t("キャンセル","Cancel"),null).setPositiveButton(a.t("削除","Delete")) { _,_-> a.mutate { Planner.delete(it,rule.id,System.currentTimeMillis()) } }.show()
            }.apply { setTextColor(android.graphics.Color.rgb(255,59,48)) })
            u.add(parent,r,12)
        }
    }
}
