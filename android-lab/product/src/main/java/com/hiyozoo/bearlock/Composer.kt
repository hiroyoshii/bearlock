package com.hiyozoo.bearlock

import android.app.*
import android.view.Gravity
import android.widget.*
import java.time.*
import android.text.format.DateFormat

class Composer(private val a: MainActivity) {
    private val u get()=a.ui
    private fun t(ja: String,en: String)=a.t(ja,en)
    private var updateSummary: (() -> Unit)? = null
    private val compact get()=u.compact
    fun show(parent: LinearLayout) {
        val c=u.card()
        fun bind() {
            c.removeAllViews()
            val modes=listOf(t("今すぐ","Now"),t("後で","In"),t("日時指定",if(a.resources.configuration.screenWidthDp>=440) "Date & Time" else "Date"),t("繰り返し","Repeat"))
            val context=android.view.ContextThemeWrapper(a,R.style.BearSegmentTheme)
            val segments=com.google.android.material.button.MaterialButtonToggleGroup(context).apply {
                isSingleSelection=true; isSelectionRequired=true; tag="composer-mode-picker"
            }
            for(i in (0..3).filterNot { it==0 && a.state.activeLocks(System.currentTimeMillis()).isNotEmpty() }) {
                val button=com.google.android.material.button.MaterialButton(context,null,
                    com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
                    id=android.view.View.generateViewId(); tag="composer-mode-$i"
                    text=modes[i]; contentDescription=modes[i]; isAllCaps=false
                    textSize=12f; setTypeface(typeface,android.graphics.Typeface.BOLD)
                    minWidth=0; minimumWidth=0; minHeight=u.dp(44)
                    insetTop=0; insetBottom=0; setPadding(u.dp(8),u.dp(8),u.dp(8),u.dp(8))
                    setTextColor(android.content.res.ColorStateList(arrayOf(intArrayOf(android.R.attr.state_checked),intArrayOf()),intArrayOf(Palette.white,Palette.navy)))
                    backgroundTintList=android.content.res.ColorStateList(arrayOf(intArrayOf(android.R.attr.state_checked),intArrayOf()),intArrayOf(Palette.navy,Palette.ice))
                    if(!compact) { maxLines=1; androidx.core.widget.TextViewCompat.setAutoSizeTextTypeUniformWithConfiguration(this,10,12,1,android.util.TypedValue.COMPLEX_UNIT_SP) }
                    isSelected=a.mode==i
                }
                segments.addView(button,LinearLayout.LayoutParams(if(compact) -2 else 0,-2,if(compact) 0f else 1f))
                if(a.mode==i) segments.check(button.id)
                button.setOnClickListener { a.editor.chooseMode(ComposerMode.entries[i],System.currentTimeMillis()); bind() }
            }
            if(compact) u.add(c,HorizontalScrollView(a).apply {
                isHorizontalScrollBarEnabled=true; addView(segments); isFillViewport=true
            },18) else u.add(c,segments,18)
            fields(c) { bind() }
            u.add(c,u.button(if(a.mode==0) t("ロック開始","Start Lock") else t("ロックを予約","Schedule Lock"),true,radius=100) { confirm() }.apply { textSize=17f; tag="composer-primary"; isEnabled=a.editor.canSubmit(System.currentTimeMillis()); alpha=if(isEnabled) 1f else .5f },0)
        }
        bind(); u.add(parent,c,20)
    }
    fun showEditor(parent: LinearLayout) {
        if(a.mode==3) u.add(u.section(parent,t("状態","Status")),Switch(a).apply {
            text=t("有効","Enabled"); textSize=17f; setTextColor(Palette.navy); isChecked=a.editor.enabled; minHeight=u.dp(48)
            setOnCheckedChangeListener { _,on -> a.editor.enabled=on }
        },0)
        fields(if(a.mode==3) parent else u.section(parent,t("予定","Schedule")),grouped=a.mode==3)
        val confirmation=u.section(parent,if(a.mode==3) null else t("確認","Confirmation"))
        u.add(confirmation,u.label(if(a.mode==3) t("実行中は時刻・曜日を変更できません。予定はいつでも削除できます。","Times and weekdays cannot be changed during a lock. You can delete the schedule at any time.") else t("予約は開始前のみ編集できます。開始後は無料で30分後の起床を予約できますが、予定の編集・削除はできません。","Scheduled locks can only be edited before they start. During a lock you can schedule a free wake-up in 30 minutes, but cannot edit or delete the schedule."),13f,muted=true),0)
        if(a.mode!=3) {
            val row=u.row(); val wake=u.label(dateText(a.editor.at+a.editor.duration*60_000L,a),15f).apply { gravity=Gravity.END }
            row.addView(u.label(t("起床","Wakes"),14f,false,true),LinearLayout.LayoutParams(0,-2,1f)); row.addView(wake,LinearLayout.LayoutParams(0,-2,2f)); confirmation.addView(row,0); (row.layoutParams as LinearLayout.LayoutParams).bottomMargin=u.dp(12)
            updateSummary={ wake.text=dateText(a.editor.at+a.editor.duration*60_000L,a) }
        }
    }
    private fun fields(parent: LinearLayout, grouped: Boolean = false, refresh: () -> Unit = { a.render() }) {
        var c=parent
        updateSummary=null
        if(a.mode==1) {
            u.add(c,u.label(t("開始まで","Starts in"),17f,true),10)
            val r=u.row()
            r.addView(u.button("−") { a.editor.delay=(a.editor.delay-5).coerceAtLeast(5); refresh() }.apply {
                contentDescription=t("開始を5分早める","Decrease start delay"); isEnabled=a.editor.delay>5; minWidth=0
                background=u.touchBackground(Palette.subtle,radius=100); setTextColor(Palette.link)
            },LinearLayout.LayoutParams(u.dp(54),u.dp(54)))
            val value=u.column().apply { gravity=Gravity.CENTER }
            u.add(value,u.label("${a.editor.delay}"+t("分"," min"),22f,true).apply { gravity=Gravity.CENTER },2)
            u.add(value,u.label(t("開始までの時間","Start delay"),12f,true,true).apply { gravity=Gravity.CENTER },0)
            value.minimumHeight=u.dp(54)
            r.addView(value,LinearLayout.LayoutParams(0,-2,1f).apply { leftMargin=u.dp(12); rightMargin=u.dp(12) })
            r.addView(u.button("＋") { a.editor.delay=(a.editor.delay+5).coerceAtMost(240); refresh() }.apply {
                contentDescription=t("開始を5分遅らせる","Increase start delay"); isEnabled=a.editor.delay<240; minWidth=0
                background=u.touchBackground(Palette.subtle,radius=100); setTextColor(Palette.link)
            },LinearLayout.LayoutParams(u.dp(54),u.dp(54)))
            u.add(c,r,18)
        }
        if(a.mode==2) {
            if(a.editor.originalID==null) u.add(c,u.label(t("日時指定","Date & Time"),17f,true).apply { setTextColor(Palette.textPrimary) },12)
            val date=Instant.ofEpochMilli(a.editor.at).atZone(ZoneId.systemDefault())
            val row=u.row()
            row.addView(u.label(t("開始","Starts"),17f),LinearLayout.LayoutParams(0,-2,1f))
            val formatter=java.text.DateFormat.getDateInstance(java.text.DateFormat.SHORT)
            row.addView(u.dateTimeButton(formatter.format(java.util.Date(a.editor.at)),t("開始日","Start date")) { chooseDate() }.apply {
                tag="start-date"
            })
            row.addView(u.dateTimeButton(timeText(a.editor.at,a),t("開始時刻","Start time")) {
                TimePickerDialog(a,{ _,h,m -> a.editor.at=date.withHour(h).withMinute(m).toInstant().toEpochMilli(); a.render() },date.hour,date.minute,DateFormat.is24HourFormat(a)).show()
            }.apply { tag="start-time"; layoutParams=LinearLayout.LayoutParams(-2,-2).apply { leftMargin=u.dp(8) } })
            if(compact) { row.orientation=LinearLayout.VERTICAL; for(i in 0 until row.childCount) row.getChildAt(i).layoutParams=LinearLayout.LayoutParams(-1,-2) }
            u.add(c,row,18)
        }
        if(a.mode==3) {
            if(grouped) c=u.section(parent,t("曜日","Weekdays"))
            else u.add(c,u.label(t("曜日","Weekdays"),17f,true),10)
            val largeWeekdays=a.resources.configuration.fontScale>=1.5f
            val weekdays=listOf(7,1,2,3,4,5,6).map { day ->
                lateinit var button: Button
                val fullName=java.time.DayOfWeek.of(day).getDisplayName(java.time.format.TextStyle.FULL,a.resources.configuration.locales[0])
                fun mark() {
                    button.isSelected=day in a.editor.days
                    val foreground=if(button.isSelected) Palette.white else Palette.navy
                    button.setTextColor(foreground)
                    val background=u.bg(if(button.isSelected) Palette.navy else 0xFFF2F2F4.toInt()).apply {
                        if(!largeWeekdays) shape=android.graphics.drawable.GradientDrawable.OVAL
                        else cornerRadius=u.dp(24).toFloat()
                    }
                    background.setStroke(u.dp(1),if(button.isSelected) Palette.navy else 0xFFDDDEE1.toInt())
                    button.background=android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(if(button.isSelected) 0x33FFFFFF else 0x22142E4F),background,null)
                }
                button=u.button(dayName(day)) {
                a.editor.days=if(day in a.editor.days) a.editor.days-day else a.editor.days+day
                mark()
                updateSummary?.invoke()
                a.updateEditorActions()
            }.apply {
                text=if(largeWeekdays) fullName else dayName(day)
                minWidth=u.dp(44); minHeight=u.dp(44); textSize=if(largeWeekdays) 16f else 15f
                setPadding(if(largeWeekdays) u.dp(8) else 0,u.dp(6),if(largeWeekdays) u.dp(8) else 0,u.dp(6))
                contentDescription=fullName
                }
                mark()
                button
            }
            val availableWidth=a.resources.displayMetrics.widthPixels-u.dp(40+32)
            if(largeWeekdays) u.choices(c,weekdays,1,8)
            else {
                val columns=if(availableWidth>=u.dp(7*44+6*4)) 7 else 4
                val cells=weekdays.map { button -> FrameLayout(a).apply {
                    addView(button,FrameLayout.LayoutParams(u.dp(44),u.dp(44),Gravity.CENTER))
                } }
                for(chunk in cells.chunked(columns)) {
                    val row=u.row()
                    chunk.forEach { row.addView(it,LinearLayout.LayoutParams(0,u.dp(44),1f)) }
                    repeat(columns-chunk.size) { row.addView(android.view.View(a),LinearLayout.LayoutParams(0,1,1f)) }
                    u.add(c,row,8)
                }
            }
            if(grouped) c=u.section(parent,t("時刻","Time"))
            for(start in listOf(true,false)) {
                val minute=if(start) a.editor.repeatStart else a.editor.repeatEnd; val row=u.row()
                row.addView(u.label(if(start) t("開始","Starts") else t("終了","Ends"),17f),LinearLayout.LayoutParams(0,-2,1f))
                val display=LocalDate.now().atTime(minute/60,minute%60).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
                row.addView(u.dateTimeButton(timeText(display,a),if(start) t("開始時刻","Start time") else t("終了時刻","End time")) {
                    TimePickerDialog(a,{ _,h,m -> if(start) a.editor.repeatStart=h*60+m else a.editor.repeatEnd=h*60+m; refresh() },minute/60,minute%60,DateFormat.is24HourFormat(a)).show()
                }.apply { tag=if(start) "start-time" else "end-time" })
                u.add(c,row,18)
                if(grouped) u.divider(c)
            }
            val preview=u.label("",14f,muted=true).apply { tag="recurring-next-preview" }
            updateSummary={
                val now=System.currentTimeMillis()
                val next=runCatching { make(now).copy(enabled=true).nextOccurrence(now) }.getOrNull()
                val zone=(a.editor.timing as DraftTiming.Weekly).zone
                preview.text=next?.let { t("次回の開始 ","Next start ")+dateText(it.start,a,zone)+"\n"+t("次回の起床 ","Next wake-up ")+dateText(it.end,a,zone) } ?: t("次の予定はありません","No upcoming lock")
            }
            updateSummary?.invoke(); u.add(c,preview,0)
            return
        }
        val row=u.row(); row.addView(u.label(t("ロック時間","Duration"),17f,true).apply { setTextColor(Palette.textPrimary) },LinearLayout.LayoutParams(0,-2,1f))
        val value=u.label("${a.editor.duration}"+t("分"," min"),17f,true); row.addView(value); u.add(c,row,10)
        val slider=SeekBar(a).apply { max=141; progress=((a.editor.duration-15)/5).coerceIn(0,141); minimumHeight=u.dp(44); setPadding(u.dp(14),0,u.dp(14),0); contentDescription=t("ロック時間（分）","Duration in minutes")
            progressTintList=android.content.res.ColorStateList.valueOf(Palette.navy)
            thumb=android.graphics.drawable.GradientDrawable().apply { shape=android.graphics.drawable.GradientDrawable.OVAL; setColor(Palette.white); setStroke(u.dp(1),Palette.line); setSize(u.dp(28),u.dp(28)) }
        }
        val presets=u.column()
        val presetButtons=mutableListOf<Button>()
        fun markPresets() { presetButtons.forEachIndexed { i, button -> button.apply {
            isSelected=listOf(15,30,60,120)[i]==a.editor.duration
            // A low visual capsule inside the unchanged 44dp touch target.
            background=android.graphics.drawable.InsetDrawable(u.touchBackground(if(isSelected) Palette.navy else Palette.subtle,radius=100),0,u.dp(6),0,u.dp(6))
            setTextColor(if(isSelected) Palette.white else Palette.navy)
        } } }

        slider.setOnSeekBarChangeListener(object: SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(s: SeekBar?,p: Int,user: Boolean) { if(user) { a.editor.duration=15+p*5; value.text="${a.editor.duration}"+t("分"," min"); markPresets(); updateSummary?.invoke() } }
            override fun onStartTrackingTouch(s: SeekBar?) {}
            override fun onStopTrackingTouch(s: SeekBar?) {}
        })
        u.add(c,slider,4)
        for(n in listOf(15,30,60,120)) presetButtons.add(u.button("$n"+t("分"," min")) {
            a.editor.duration=n; slider.progress=(n-15)/5; value.text="$n"+t("分"," min"); markPresets(); updateSummary?.invoke()
        }.apply { tag="duration-preset-$n"; minWidth=0; minHeight=u.dp(56); textSize=13f; setTypeface(typeface,android.graphics.Typeface.BOLD); setPadding(u.dp(4),u.dp(8),u.dp(4),u.dp(8)) })
        markPresets(); u.choices(presets,presetButtons,if(compact) 2 else 4,0); u.add(c,presets,4)
        u.add(c,u.label(t("ロック時間は15分以上から設定できます。","Locks start at 15 minutes or longer."),12f,muted=true),18)
        if(a.editor.originalID==null && a.mode in 1..2) {
            val startLabel=u.label("",14f,muted=true); val wakeLabel=u.label("",14f,muted=true)
            updateSummary={ val start=if(a.mode==1) System.currentTimeMillis()+a.editor.delay*60_000L else a.editor.at
                startLabel.text=t("開始 ","Starts ")+dateText(start,a); wakeLabel.text=t("起床 ","Wakes ")+dateText(start+a.editor.duration*60_000L,a) }
            updateSummary?.invoke(); u.add(c,startLabel,4); u.add(c,wakeLabel,18)
        }
    }
    fun dayName(d: Int)=if(a.resources.configuration.locales[0].language=="ja") listOf("月","火","水","木","金","土","日")[d-1] else listOf("M","T","W","T","F","S","S")[d-1]
    fun daysText(days: Set<Int>)=days.sorted().joinToString(" ") {
        java.time.DayOfWeek.of(it).getDisplayName(java.time.format.TextStyle.SHORT,a.resources.configuration.locales[0])
    }
    private fun chooseDate() {
        val date=Instant.ofEpochMilli(a.editor.at).atZone(ZoneId.systemDefault())
        DatePickerDialog(a,{ _,y,m,d ->
            val day=LocalDate.of(y,m+1,d)
            a.editor.at=day.atTime(date.toLocalTime()).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(); a.render()
        },date.year,date.monthValue-1,date.dayOfMonth).show()
    }
    fun make(now: Long): Rule {
        val title=a.state.rules.find { it.id==a.editor.originalID }?.title ?: when(a.editor.mode) {
            ComposerMode.NOW -> t("今すぐ","Now"); ComposerMode.LATER -> t("あとで開始","Starts later")
            ComposerMode.FIXED -> t("日時指定","Date & Time"); ComposerMode.WEEKLY -> t("繰り返し","Repeats")
        }
        return a.editor.makeRule(now,title)
    }
    private fun permissionsReady(scheduled: Boolean, forConfirmation: Boolean): Boolean {
        val missingAccess = GuardService.instance == null
        val missingAlarm = scheduled && !Scheduling.permitted(a)
        if(missingAccess || missingAlarm) {
            AlertDialog.Builder(a).setTitle(t("先に設定を完了してください","Complete setup first"))
                .setMessage(listOfNotNull(
                    if(missingAccess) t("選んだアプリを制限するため、ユーザー補助を許可してください。","Allow accessibility access to block your selected apps.") else null,
                    if(missingAlarm) t("予約した時刻にロックを開始するため、「アラームとリマインダー」を許可してください。今すぐのロックには不要です。","Allow alarms and reminders to start locks at scheduled times. Immediate locks do not need this permission.") else null
                ).joinToString("\n\n"))
                .setNegativeButton(t("キャンセル","Cancel"),null).setPositiveButton(t("設定へ","Setup")) { _,_->a.requestPermissions(forConfirmation=forConfirmation) }.show(); return false
        }
        return true
    }
    fun saveEdit() {
        if(a.editor.originalID==null) return
        a.load()
        if(!a.savedDataAvailable) { a.error("storage_error"); return }
        if(a.editor.enabled && !permissionsReady(true, false)) return
        a.updateSchedule(::make) { a.editor=EditorDraft(); a.restoreSelection(); a.navigate("home") }
    }
    fun confirm() {
        a.load()
        if(!a.savedDataAvailable) { a.error("storage_error"); return }
        try {
            val now=System.currentTimeMillis(); val rule=make(now); Planner.save(a.state,rule,now)
            if(!permissionsReady(a.mode != 0, true)) return
            val first=rule.nextOccurrence(now) ?: error("invalid_time")
            val dialog=Dialog(a)
            val content=ConfirmationContent(u).build(rule.targets,when(a.mode) { 0 -> t("確定後に開始","After confirmation"); 1 -> t("確定から${a.editor.delay}分後","${a.editor.delay} min after confirmation"); 3 -> daysText(a.editor.days)+"\n"+dateText(first.start,a,rule.weekly!!.zone); else -> dateText(first.start,a) },
                if(a.mode in listOf(0,1)) t("開始から${a.editor.duration}分後","${a.editor.duration} min after start") else dateText(first.end,a,rule.weekly?.zone),a.mode==0,a.mode==3,{ dialog.dismiss() }) {
                a.createSchedule(::make) {
                    a.store.event("lock_saved"); dialog.dismiss(); a.navigate("home")
                }
            }
            dialog.setContentView(ScrollView(a).apply {
                background=u.bg(Palette.background,24); clipToOutline=true; addView(content)
            })
            dialog.window?.apply { setBackgroundDrawableResource(android.R.color.transparent); setGravity(Gravity.BOTTOM); addFlags(android.view.WindowManager.LayoutParams.FLAG_DIM_BEHIND) }
            dialog.show()
            content.measure(android.view.View.MeasureSpec.makeMeasureSpec(a.resources.displayMetrics.widthPixels,android.view.View.MeasureSpec.EXACTLY),android.view.View.MeasureSpec.makeMeasureSpec(0,android.view.View.MeasureSpec.UNSPECIFIED))
            dialog.window?.setLayout(-1, minOf(content.measuredHeight,(a.resources.displayMetrics.heightPixels * 0.9).toInt()))
        } catch(e: Exception) { a.error(e.message) }
    }
}

class ConfirmationContent(private val u: Ui) {
    fun build(targets: Targets, start: String, end: String, immediate: Boolean, recurring: Boolean, cancel: ()->Unit, confirm: ()->Unit): LinearLayout {
        val c=u.column().apply { setPadding(u.dp(24),u.dp(24),u.dp(24),u.dp(24)); gravity=Gravity.CENTER_HORIZONTAL }
        u.add(c,u.asset(R.drawable.bear_arming,118),10)
        u.add(c,u.label(tr(u.c,if(immediate) "このロックを開始しますか？" else "このロックを予約しますか？",if(immediate) "Start this lock?" else "Schedule this lock?"),22f,true).apply { gravity=Gravity.CENTER },10)
        u.add(c,u.label(if(recurring) tr(u.c,"予定はいつでも削除できます。削除すると、実行中のロックも終了します。","You can delete this schedule at any time. Deleting it also ends its active lock.") else tr(u.c,"開始後は編集・削除できません。無料で30分後の起床を予約できます。","Once started, you cannot edit or delete it. You can schedule a free wake-up in 30 minutes."),15f,muted=true).apply { gravity=Gravity.CENTER },22)
        val summary=u.card().apply { background=u.bg(Palette.ice) }
        val kinds=listOf(Triple("アプリ","Apps",targets.apps.size),Triple("カテゴリ","Categories",targets.categories.size),Triple("Webサイト","Websites",targets.domains.size))
        kinds.filter { it.third>0 }.forEach { (ja,en,count) -> u.pair(summary,tr(u.c,ja,en),tr(u.c,"${count}件の対象","$count targets"),12,emphasized=true) }
        u.pair(summary,tr(u.c,"開始","Starts"),start,12,emphasized=true)
        u.pair(summary,tr(u.c,"起床","Wakes"),end,0,emphasized=true); u.add(c,summary,22)
        u.add(c,u.button(tr(u.c,if(immediate) "ロック開始" else "ロックを予約",if(immediate) "Start Lock" else "Schedule Lock"),true,radius=100,action=confirm).apply { textSize=17f },10)
        u.add(c,u.button(tr(u.c,"キャンセル","Cancel"),radius=100,action=cancel).apply {
            textSize=17f; background=u.touchBackground(Palette.white,radius=100); setTextColor(Palette.link)
            layoutParams=LinearLayout.LayoutParams(-2,-2).apply { gravity=Gravity.CENTER_HORIZONTAL }
        },0)
        return c
    }
}
