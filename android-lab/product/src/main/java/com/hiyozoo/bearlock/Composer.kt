package com.hiyozoo.bearlock

import android.app.*
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.widget.*
import java.time.*

fun EditText.onEdit(action: (String)->Unit) { addTextChangedListener(object: TextWatcher {
    override fun beforeTextChanged(s: CharSequence?,start: Int,count: Int,after: Int) {}
    override fun onTextChanged(s: CharSequence?,start: Int,before: Int,count: Int) { action(s.toString()) }
    override fun afterTextChanged(s: Editable?) {}
}) }
class Composer(private val a: MainActivity) {
    private val u get()=a.ui
    private fun t(ja: String,en: String)=a.t(ja,en)
    private val compact get()=a.resources.configuration.screenWidthDp<360 || a.resources.configuration.fontScale>1.2f
    private fun horizontal(parent: LinearLayout, row: LinearLayout, gap: Int, selected: Int = 0) {
        if(!compact) { u.add(parent,row,gap); return }
        val scroll=HorizontalScrollView(a).apply { isHorizontalScrollBarEnabled=true; addView(row); clipToPadding=false }
        u.add(parent,scroll,gap)
        scroll.post { scroll.scrollTo(u.dp(selected*116),0) }
    }
    fun show(parent: LinearLayout) {
        val c=u.card(); val row=u.row()
        val modes=listOf(t("今すぐ","Now"),t("後で","Later"),t("日時指定","Date & time"),t("繰り返し","Repeat"))
        for(i in 0..3) {
            if(i==0 && a.state.sessions.any { it.active(System.currentTimeMillis()) }) continue
            row.addView(u.button(modes[i],a.mode==i) { a.mode=i; a.render() }.apply {
                setCompoundDrawables(LineIcon(listOf("bolt","timer","calendar","repeat")[i],if(a.mode==i) Palette.white else Palette.navy).apply { setBounds(0,0,u.dp(14),u.dp(14)) },null,null,null); compoundDrawablePadding=u.dp(3)
                textSize=12f; minWidth=0; minHeight=u.dp(38); setPadding(u.dp(2),u.dp(6),u.dp(2),u.dp(6)); isSelected=a.mode==i
                setTypeface(typeface,android.graphics.Typeface.BOLD)
            },(if(compact) LinearLayout.LayoutParams(u.dp(108),-2) else LinearLayout.LayoutParams(0,-2,1f)).apply { if(i<3) rightMargin=u.dp(8) })
        }
        horizontal(c,row,18,a.mode)
        fields(c)
        u.add(c,u.button(if(a.mode==0) t("ロック開始","Start lock") else t("ロックを予約","Schedule lock"),true) { confirm() }.apply { isEnabled=!a.draft.empty; alpha=if(isEnabled) 1f else .5f },0)
        u.add(parent,c,20)
    }
    fun showEditor(parent: LinearLayout) {
        val c=u.card()
        if(a.mode==3) u.add(c,Switch(a).apply {
            text=t("有効","Enabled"); textSize=17f; setTextColor(Palette.navy); isChecked=a.enabled; minHeight=u.dp(48)
            setOnCheckedChangeListener { _,on ->
                try {
                    val rule=a.editing ?: return@setOnCheckedChangeListener
                    val changed=rule.copy(enabled=on)
                    val now=System.currentTimeMillis(); a.state=a.store.change { Planner.save(it,changed,now) }
                    a.editing=changed; a.enabled=on; Scheduling.sync(a)
                } catch(e: Exception) { a.error(e.message); a.render() }
            }
        },16)
        fields(c); u.add(parent,c,20)
        u.add(parent,u.label(if(a.mode==3) t("繰り返しの変更は次回から適用されます。実行中のロックは短縮・解除できません。","Changes apply from the next interval. The current lock cannot be shortened or cleared.") else t("予約は開始前のみ編集できます。開始後は短縮、削除、対象の削減はできません。","Scheduled locks can only be edited before they start. Active locks cannot be shortened, deleted, or have targets reduced."),13f,muted=true),16)
        if(a.mode!=3) u.pair(parent,t("起床","Wakes"),dateText(a.at+a.duration*60_000L))
    }
    private fun fields(c: LinearLayout) {
        if(a.mode==1) {
            u.add(c,u.label(t("開始まで","Starts in"),17f,true),10)
            val r=u.row()
            r.addView(u.button("−") { a.delay=(a.delay-5).coerceAtLeast(5); a.render() }.apply {
                contentDescription=t("開始を5分早める","Decrease start delay"); isEnabled=a.delay>5; minWidth=0; background=u.bg(Palette.subtle)
            },LinearLayout.LayoutParams(u.dp(54),u.dp(54)))
            val value=u.column().apply { gravity=Gravity.CENTER }
            u.add(value,u.label("${a.delay}"+t("分"," min"),22f,true),2)
            u.add(value,u.label(t("開始までの時間","Start delay"),12f,true,true),0)
            r.addView(value,LinearLayout.LayoutParams(0,u.dp(54),1f))
            r.addView(u.button("＋") { a.delay=(a.delay+5).coerceAtMost(240); a.render() }.apply {
                contentDescription=t("開始を5分遅らせる","Increase start delay"); isEnabled=a.delay<240; minWidth=0; background=u.bg(Palette.subtle)
            },LinearLayout.LayoutParams(u.dp(54),u.dp(54)))
            u.add(c,r,18)
        }
        if(a.mode==2) {
            u.add(c,u.label(t("開始","Starts"),17f),8)
            u.add(c,u.button(dateText(a.at)) { chooseDate() },18)
        }
        if(a.mode==3) {
            u.add(c,u.label(t("曜日","Weekdays"),17f,true),10)
            val weekdays=u.row()
            for(day in listOf(7,1,2,3,4,5,6)) weekdays.addView(u.button(dayName(day)) {
                a.days=if(day in a.days) a.days-day else a.days+day; a.render()
            }.apply {
                minWidth=0; minHeight=u.dp(38); textSize=15f; setPadding(0,u.dp(4),0,u.dp(4)); isSelected=day in a.days
                setTextColor(if(isSelected) Palette.navy else Palette.steel); background=u.bg(if(isSelected) Palette.selected else Palette.subtle); contentDescription=java.time.DayOfWeek.of(day).getDisplayName(java.time.format.TextStyle.FULL,a.resources.configuration.locales[0])
            },LinearLayout.LayoutParams(0,-2,1f).apply { if(day!=6) rightMargin=u.dp(8) })
            u.add(c,weekdays,18)
            for(start in listOf(true,false)) {
                val minute=if(start) a.repeatStart else a.repeatEnd; val row=u.row()
                row.addView(u.label(if(start) t("開始","Starts") else t("終了","Ends"),17f),LinearLayout.LayoutParams(0,-2,1f))
                row.addView(u.button("%d:%02d".format(minute/60,minute%60)) {
                    TimePickerDialog(a,{ _,h,m -> if(start) a.repeatStart=h*60+m else a.repeatEnd=h*60+m; a.render() },minute/60,minute%60,true).show()
                }.apply { background=u.bg(0xFFEEEEEF.toInt()); textSize=18f; contentDescription=if(start) t("開始時刻","Start time") else t("終了時刻","End time") })
                u.add(c,row,18)
            }
            return
        }
        val row=u.row(); row.addView(u.label(t("ロック時間","Duration"),17f,true),LinearLayout.LayoutParams(0,-2,1f))
        val value=u.label("${a.duration}"+t("分"," min"),18f,true); row.addView(value); u.add(c,row,10)
        val slider=SeekBar(a).apply { max=141; progress=((a.duration-15)/5).coerceIn(0,141); minimumHeight=u.dp(38); contentDescription=t("ロック時間（分）","Duration in minutes")
            progressTintList=android.content.res.ColorStateList.valueOf(Palette.navy)
            thumb=android.graphics.drawable.GradientDrawable().apply { shape=android.graphics.drawable.GradientDrawable.OVAL; setColor(Palette.white); setStroke(u.dp(1),Palette.line); setSize(u.dp(28),u.dp(28)) }
        }
        val presets=u.row()
        fun markPresets() { for(i in 0 until presets.childCount) (presets.getChildAt(i) as Button).apply { isSelected=listOf(15,30,60,120)[i]==a.duration; background=u.bg(if(isSelected) Palette.selected else Palette.subtle); setTextColor(if(isSelected) Palette.navy else Palette.steel); setTypeface(typeface,android.graphics.Typeface.BOLD) } }
        slider.setOnSeekBarChangeListener(object: SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(s: SeekBar?,p: Int,user: Boolean) { if(user) { a.duration=15+p*5; value.text="${a.duration}"+t("分"," min"); markPresets() } }
            override fun onStartTrackingTouch(s: SeekBar?) {}
            override fun onStopTrackingTouch(s: SeekBar?) {}
        })
        u.add(c,slider,8)
        for(n in listOf(15,30,60,120)) presets.addView(u.button("$n"+t("分"," min")) { a.duration=n; a.render() }.apply { minWidth=0; minHeight=u.dp(30); textSize=13f; setPadding(u.dp(2),u.dp(4),u.dp(2),u.dp(4)) },(if(compact) LinearLayout.LayoutParams(u.dp(88),-2) else LinearLayout.LayoutParams(0,-2,1f)).apply { if(n!=120) rightMargin=u.dp(8) })
        markPresets(); horizontal(c,presets,10)
        u.add(c,u.label(t("ロック時間は15分以上から設定できます。","Locks can be set for 15 minutes or longer."),12f,muted=true),18)
        if(a.editing==null && a.mode in 1..2) {
            val start=if(a.mode==1) System.currentTimeMillis()+a.delay*60_000L else a.at
            u.add(c,u.label(t("開始 ","Starts ")+dateText(start),14f,muted=true),4)
            u.add(c,u.label(t("起床 ","Wakes ")+dateText(start+a.duration*60_000L),14f,muted=true),18)
        }
    }
    fun dayName(d: Int)=if(a.resources.configuration.locales[0].language=="ja") listOf("月","火","水","木","金","土","日")[d-1] else listOf("M","T","W","T","F","S","S")[d-1]
    fun daysText(days: Set<Int>)=days.sorted().joinToString(" ") { dayName(it) }
    private fun chooseDate() {
        val date=Instant.ofEpochMilli(a.at).atZone(ZoneId.systemDefault())
        DatePickerDialog(a,{ _,y,m,d ->
            val day=LocalDate.of(y,m+1,d)
            TimePickerDialog(a,{ _,h,min -> a.at=day.atTime(h,min).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(); a.render() },date.hour,date.minute,true).show()
        },date.year,date.monthValue-1,date.dayOfMonth).show()
    }
    fun make(now: Long): Rule {
        val duration=if(a.mode==3) ((a.repeatEnd-a.repeatStart+1440)%1440).takeIf { it>0 } ?: 1440 else a.duration
        require(if(a.mode==3) duration in 1..1440 else duration in 15..720) { "invalid_time" }
        require(a.mode!=1 || a.delay in 5..240) { "invalid_time" }
        require(a.mode!=3 || a.days.isNotEmpty()) { "invalid_time" }
        val start=when(a.mode) { 0->now; 1->now+a.delay*60_000L; 2->a.at; else->a.editing?.start ?: now }
        return Rule(id=a.editing?.id ?: java.util.UUID.randomUUID().toString(),title=a.editing?.title ?: when(a.mode) { 0->t("今すぐ","Now");1->t("あとで開始","Starts later");2->t("日時指定","Date & Time");else->t("繰り返し","Repeats") },targets=a.draft,start=start,end=start+duration*60_000L,
            days=if(a.mode==3) a.days else emptySet(),minute=a.repeatStart,durationMinutes=duration,zone=a.editing?.zone ?: ZoneId.systemDefault().id,enabled=a.enabled)
    }
    fun saveEdit() {
        if(a.editing==null) return
        try { val now=System.currentTimeMillis(); a.state=a.store.change { Planner.save(it,make(now),now) }; Scheduling.sync(a); a.editing=null; a.enabled=true; a.restoreSelection(); a.mode=0; a.navigate("home") } catch(e: Exception) { a.error(e.message) }
    }
    fun confirm() {
        try {
            val now=System.currentTimeMillis(); val rule=make(now); Planner.save(a.state,rule,now)
            if(GuardService.instance==null || !Scheduling.permitted(a)) {
                AlertDialog.Builder(a).setTitle(t("先に設定を完了してください","Complete setup first"))
                    .setMessage(t("ユーザー補助の接続と予約権限が必要です。","Accessibility and alarm permissions are required."))
                    .setNegativeButton(t("キャンセル","Cancel"),null).setPositiveButton(t("設定へ","Setup")) { _,_->a.navigate("permissions") }.show(); return
            }
            val first=rule.occurrences(now,now+8*Planner.DAY).first()
            val dialog=Dialog(a)
            val content=ConfirmationContent(u).build(a.catalog.summary(rule.targets),dateText(first.start),dateText(first.end),a.mode==0,{ dialog.dismiss() }) {
                try {
                    val savedAt=System.currentTimeMillis(); a.state=a.store.change { Planner.save(it,make(savedAt),savedAt) }
                    a.persistSelection(); a.store.event("lock_saved"); Scheduling.sync(a); dialog.dismiss(); a.navigate("home")
                } catch(e: Exception) { a.error(e.message) }
            }
            dialog.setContentView(ScrollView(a).apply { setBackgroundColor(Palette.background); addView(content) })
            dialog.window?.apply { setBackgroundDrawableResource(android.R.color.transparent); setGravity(Gravity.BOTTOM); addFlags(android.view.WindowManager.LayoutParams.FLAG_DIM_BEHIND) }
            dialog.show(); dialog.window?.setLayout(-1, minOf(u.dp(560),a.resources.displayMetrics.heightPixels-u.dp(48)))
        } catch(e: Exception) { a.error(e.message) }
    }
}

class ConfirmationContent(private val u: Ui) {
    fun build(targets: String, start: String, end: String, immediate: Boolean, cancel: ()->Unit, confirm: ()->Unit): LinearLayout {
        val c=u.column().apply { setPadding(u.dp(24),u.dp(28),u.dp(24),u.dp(24)); gravity=Gravity.CENTER_HORIZONTAL; setBackgroundColor(Palette.background) }
        u.add(c,u.asset(R.drawable.bear_arming,118),16)
        u.add(c,u.label(tr(u.c,if(immediate) "熊を眠らせます。" else "ロックを予約します。",if(immediate) "Put Bear to sleep." else "Schedule Bear’s sleep."),22f,true).apply { gravity=Gravity.CENTER },12)
        u.add(c,u.label(tr(u.c,"開始後は短縮・解除できません。","Once started, you cannot shorten or end it early."),15f,muted=true).apply { gravity=Gravity.CENTER },22)
        val summary=u.card().apply { background=u.bg(Palette.ice) }
        u.pair(summary,tr(u.c,"対象アプリ","Apps"),targets)
        u.pair(summary,tr(u.c,"開始","Starts"),start)
        u.pair(summary,tr(u.c,"起床","Wakes"),end,0); u.add(c,summary,22)
        u.add(c,u.button(tr(u.c,if(immediate) "ロック開始" else "ロックを予約",if(immediate) "Start lock" else "Schedule lock"),true,confirm),10)
        u.add(c,u.textButton(tr(u.c,"キャンセル","Cancel"),cancel),0)
        return c
    }
}
