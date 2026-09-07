package com.hiyozoo.bearlock

import android.app.*
import android.content.Intent
import android.net.Uri
import android.os.*
import android.provider.Settings
import android.view.*
import android.widget.*
import java.time.*

open class MainActivity : Activity() {
    val ui by lazy { Ui(this) }
    val store by lazy { Store(this) }
    val catalog by lazy { Catalog(this) }
    var page = "home"
    var draft = Targets()
    var editing: Rule? = null
    var mode = 0
    var duration = 120
    var delay = 30
    var at = System.currentTimeMillis()+3_600_000
    var days = setOf(1,2,3,4,5)
    var repeatStart = 23*60
    var repeatEnd = 7*60
    var enabled = true
    var expandedTargets = false
    var pickerOriginal = Targets()
    var pickerReturn = "home"
    var visualPreview = false
    var title = ""
    var state = State()
    private lateinit var body: LinearLayout
    private var renderedPage: String? = null
    private var contentScroll: ScrollView? = null
    private val handler = Handler(Looper.getMainLooper())
    var pickerCount: TextView? = null
    var pickerSave: Button? = null
    private var countdown: TextView? = null
    private var countdownEnd = 0L
    private var lastStatus = ""
    private fun statusKey() = "${GuardService.instance != null}:${Scheduling.permitted(this)}:${store.error}"
    private val heartbeat = object : Runnable {
        override fun run() {
            if (page == "home") {
                val before=state.sessions.map { it.key }
                load()
                if (before != state.sessions.map { it.key }) render() else countdown?.text = remaining(countdownEnd)
            }
            if(page in listOf("home","setup","settings") && lastStatus != statusKey()) render()
            handler.postDelayed(this,1000)
        }
    }
    fun t(ja: String,en: String) = tr(this,ja,en)
    override fun attachBaseContext(base: android.content.Context) {
        configureLanguage(base)
        val language=base.getSharedPreferences("appearance",0).getString("language","").orEmpty()
        if(language.isEmpty()) super.attachBaseContext(base) else {
            val config=android.content.res.Configuration(base.resources.configuration)
            config.setLocale(java.util.Locale.forLanguageTag(language))
            super.attachBaseContext(base.createConfigurationContext(config))
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33) onBackInvokedDispatcher.registerOnBackInvokedCallback(android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT) { goBack() }
        draft=runCatching { Codec.targets(org.json.JSONObject(getPreferences(0).getString("selection","")!!)) }.getOrDefault(Targets())
        if (savedInstanceState != null) restore(savedInstanceState)
        else if (!getPreferences(0).getBoolean("onboarded",false)) page="setup"
        if(savedInstanceState == null && BuildConfig.DEBUG && intent.hasExtra("qaPage")) {
            page=intent.getStringExtra("qaPage")!!.takeIf { it in listOf("home","setup","compose","targets","settings","schedules") } ?: "home"
            if(intent.getBooleanExtra("qaDraft",false)) draft=Targets(apps=setOf("com.hiyozoo.bearlock.probe"))
        }
        render()
    }
    override fun onResume() { super.onResume(); GuardService.instance?.appForeground(); Scheduling.sync(this); load(); render(); handler.post(heartbeat) }
    override fun onPause() { handler.removeCallbacks(heartbeat); super.onPause() }
    override fun onSaveInstanceState(out: Bundle) {
        out.putString("page",page); out.putString("targets",Codec.targets(draft).toString()); out.putInt("mode",mode)
        out.putInt("duration",duration); out.putInt("delay",delay); out.putLong("at",at); out.putString("title",title)
        out.putInt("repeatStart",repeatStart); out.putInt("repeatEnd",repeatEnd); out.putBoolean("enabled",enabled)
        out.putString("pickerOriginal",Codec.targets(pickerOriginal).toString()); out.putString("pickerReturn",pickerReturn); out.putBoolean("expandedTargets",expandedTargets)
        out.putIntArray("days",days.toIntArray()); out.putString("editing",editing?.id); super.onSaveInstanceState(out)
    }
    private fun restore(b: Bundle) {
        page=b.getString("page","home"); draft=Codec.targets(org.json.JSONObject(b.getString("targets","{}")))
        mode=b.getInt("mode"); duration=b.getInt("duration",120); delay=b.getInt("delay",30); at=b.getLong("at")
        repeatStart=b.getInt("repeatStart",1380); repeatEnd=b.getInt("repeatEnd",420); enabled=b.getBoolean("enabled",true)
        pickerOriginal=runCatching { Codec.targets(org.json.JSONObject(b.getString("pickerOriginal", ""))) }.getOrDefault(draft)
        pickerReturn=b.getString("pickerReturn","home"); expandedTargets=b.getBoolean("expandedTargets")
        days=b.getIntArray("days")?.toSet() ?: days; title=b.getString("title",""); editing=store.read().rules.find { it.id==b.getString("editing") }
    }
    @android.annotation.SuppressLint("GestureBackNavigation") // API 33+ uses the registered OnBackInvokedCallback above.
    @Deprecated("Used only by Android 8–12")
    override fun onBackPressed() { goBack() }
    fun goBack() {
        if(page=="targets") { draft=pickerOriginal; navigate(pickerReturn) }
        else if(page!="home") { editing=null; enabled=true; restoreSelection(); navigate("home") } else finish()
    }
    fun restoreSelection() { draft=runCatching { Codec.targets(org.json.JSONObject(getPreferences(0).getString("selection","")!!)) }.getOrDefault(draft) }
    fun persistSelection() { getPreferences(0).edit().putString("selection",Codec.targets(draft).toString()).apply() }
    fun pickTargets() {
        if(state.sessions.any { it.active(System.currentTimeMillis()) }) { error("active_immutable"); return }
        pickerOriginal=draft; pickerReturn=page; navigate("targets")
    }
    fun saveSelection() {
        load()
        if(state.sessions.any { it.active(System.currentTimeMillis()) }) { draft=pickerOriginal; error("active_immutable"); return }
        if(draft.empty) { error("empty_targets"); return }
        persistSelection()
        mutate { it.copy(recent=Planner.trimRecent(listOf(Recent(draft,System.currentTimeMillis(),it.recent.any { r -> r.targets==draft && r.pinned })) + it.recent.filterNot { r -> r.targets==draft })) }
        getPreferences(0).edit().putBoolean("onboarded",true).apply()
        navigate(if(pickerReturn=="setup") "home" else pickerReturn)
    }
    open fun load() { runCatching { store.reconcile() }.onSuccess { state=it } }
    fun navigate(next: String) { page=next; render() }
    fun create(targets: Targets = Targets()) { editing=null; draft=targets; mode=0; duration=120; enabled=true; title=""; at=System.currentTimeMillis()+3_600_000; navigate("compose") }
    fun edit(rule: Rule) {
        editing=rule; draft=rule.targets; title=rule.title; at=rule.start
        mode=if(rule.recurring) 3 else 2; duration=if(rule.recurring) rule.durationMinutes else ((rule.end-rule.start)/60_000).toInt()
        days=rule.days; enabled=rule.enabled; repeatStart=rule.minute; repeatEnd=(rule.minute+rule.durationMinutes)%1440
        if(rule.recurring) at=LocalDate.now(ZoneId.of(rule.zone)).atStartOfDay().plusMinutes(rule.minute.toLong()).atZone(ZoneId.of(rule.zone)).toInstant().toEpochMilli()
        navigate("compose")
    }
    open fun render() {
        val previousY=if(renderedPage==page) contentScroll?.scrollY ?: 0 else 0
        renderedPage=page
        countdown=null; pickerCount=null; pickerSave=null; load(); lastStatus=statusKey()
        val root=ui.column().apply { setBackgroundColor(Palette.background) }
        root.setOnApplyWindowInsetsListener { v,ins -> v.setPadding(ins.systemWindowInsetLeft,ins.systemWindowInsetTop,ins.systemWindowInsetRight,ins.systemWindowInsetBottom); ins }
        if(page!="setup") {
            val bar=ui.row().apply { setPadding(ui.dp(20),ui.dp(12),ui.dp(20),ui.dp(12)) }
            if(page=="home") {
                bar.addView(ui.asset(R.drawable.brand_header,50).apply { background=null; scaleType=ImageView.ScaleType.FIT_START },LinearLayout.LayoutParams(ui.dp(142),ui.dp(50)))
                bar.addView(View(this),LinearLayout.LayoutParams(0,1,1f))
                bar.addView(ui.iconButton("⚙",t("設定","Settings")) { navigate("settings") })
            } else {
                val toolbar=android.widget.RelativeLayout(this)
                val cancel=ui.textButton(t("キャンセル","Cancel")) { goBack() }.apply { id=View.generateViewId(); textSize=14f }
                val save=ui.textButton(if(page=="compose") t("保存","Save") else "") { if(page=="compose") Composer(this).saveEdit() }.apply { id=View.generateViewId(); textSize=14f; visibility=if(page=="compose") View.VISIBLE else View.INVISIBLE }
                val side=ui.dp(if(ui.compact) 132 else 96)
                toolbar.addView(cancel,android.widget.RelativeLayout.LayoutParams(side,-2).apply { addRule(android.widget.RelativeLayout.ALIGN_PARENT_START) })
                toolbar.addView(save,android.widget.RelativeLayout.LayoutParams(side,-2).apply { addRule(android.widget.RelativeLayout.ALIGN_PARENT_END) })
                val name=when(page) { "targets"->t("ロック対象","Lock targets"); "compose"->if(mode==3) t("繰り返し","Repeat") else t("ロックを編集","Edit Lock"); "permissions"->t("アクセス許可","Permissions"); else->t("設定","Settings") }
                toolbar.addView(ui.label(name,17f,true).apply { gravity=Gravity.CENTER; minHeight=ui.dp(50) },android.widget.RelativeLayout.LayoutParams(-1,-2).apply { if(ui.compact) addRule(android.widget.RelativeLayout.BELOW,cancel.id) else { addRule(android.widget.RelativeLayout.END_OF,cancel.id); addRule(android.widget.RelativeLayout.START_OF,save.id) } })
                bar.addView(toolbar,LinearLayout.LayoutParams(-1,-2))
            }
            root.addView(bar)
        }
        val scroll=ScrollView(this).apply { isFillViewport=true; clipToPadding=false }; contentScroll=scroll
        body=ui.column().apply { setPadding(ui.dp(20),ui.dp(12),ui.dp(20),ui.dp(24)) }
        scroll.addView(body); root.addView(scroll,LinearLayout.LayoutParams(-1,0,1f))
        when(page) {
            "setup" -> setup(body); "home" -> home(body); "compose" -> Composer(this).showEditor(body)
            "targets" -> TargetPicker(this).show(body); "schedules" -> schedules(body); "settings" -> settings(body)
            "permissions" -> permissions(body)
        }
        if(page=="targets") {
            val footer=ui.column().apply { setPadding(ui.dp(20),ui.dp(12),ui.dp(20),ui.dp(12)); background=ui.bg(Palette.white,0) }
            pickerCount=ui.label(t("${draft.count}件を選択中","${draft.count} selected"),13f,muted=true)
            ui.add(footer,pickerCount!!,8)
            pickerSave=ui.button(t("保存","Save"),true) { saveSelection() }.apply { isEnabled=!draft.empty; alpha=if(isEnabled) 1f else .5f }
            ui.add(footer,pickerSave!!,0); root.addView(footer)
        }
        setContentView(root); root.requestApplyInsets()
        scroll.post { scroll.scrollTo(0,previousY) }
        if(Build.VERSION.SDK_INT>=30) window.insetsController?.setSystemBarsAppearance(
            android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
            android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS)
        else window.decorView.systemUiVisibility=View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
    }
    fun mutate(block: (State)->State) {
        try { state=store.change(block); Scheduling.sync(this); render() } catch(e: Exception) { error(e.message) }
    }
    fun error(key: String?) {
        val message=when(key) {
            "empty_targets" -> t("対象を1つ以上選んでください。","Choose at least one target.")
            "overlap" -> t("予約時間と重なっています。重ならない時間を選んでください。","This overlaps another lock. Choose a different time.")
            "active_immutable" -> t("開始したロックは変更・削除できません。","An active lock cannot be changed or deleted.")
            "storage_error" -> t("保存データを読み込めません。上書きせず保持しています。設定の診断をご確認ください。","Saved data cannot be read. It has been preserved. Check diagnostics in Settings.")
            "invalid_domain" -> t("有効なドメインを入力してください。","Enter a valid domain.")
            else -> t("日時・曜日とロック時間を確認してください。","Check the date, weekdays and lock duration.")
        }
        AlertDialog.Builder(this).setTitle(t("保存できません","Cannot save")).setMessage(message).setPositiveButton("OK",null).show()
    }
    fun home(parent: LinearLayout) {
        val active=state.sessions.filter { it.active(System.currentTimeMillis()) }
        SelectionSummary(this).show(parent,active.isNotEmpty())
        if(active.isNotEmpty()) {
            countdownEnd=active.maxOf { it.end }
            countdown=ActiveCard(ui).show(parent,remaining(countdownEnd),timeText(countdownEnd))
            ui.add(parent,ui.label(t("ロック中は短縮、削除、対象アプリの削減はできません。","During a lock, you cannot shorten it, delete it, or reduce blocked apps."),13f,muted=true),20)
            if(mode==0) mode=1
        }
        if(!visualPreview && (GuardService.instance==null || !Scheduling.permitted(this) || store.error!=null)) {
            ui.add(parent,ui.textButton(t("動作に必要な設定を確認","Review required permissions")) { navigate("permissions") },16)
        }
        Composer(this).show(parent)
        schedules(parent)
    }
    private fun remaining(end: Long): String {
        val seconds=((end-System.currentTimeMillis()).coerceAtLeast(0)/1000)
        return if(seconds>=3600) "%d:%02d:%02d".format(seconds/3600,seconds/60%60,seconds%60) else "%02d:%02d".format(seconds/60,seconds%60)
    }
    fun schedules(parent: LinearLayout) = ScheduleList(this).show(parent)
    private fun setup(parent: LinearLayout) {
        parent.gravity=Gravity.CENTER
        val group=ui.column().apply { setPadding(ui.dp(4),0,ui.dp(4),0) }
        ui.add(group,ui.asset(R.drawable.brand_hero,175).apply { layoutParams=LinearLayout.LayoutParams(minOf(ui.dp(310),resources.displayMetrics.widthPixels-ui.dp(48)),ui.dp(175)).apply { gravity=Gravity.CENTER_HORIZONTAL } },18)
        ui.add(group,ui.label(t("アプリを選び、時間を\n決めて、ロックします。","Choose apps, set a time,\nand lock them."),20f,true).apply { gravity=Gravity.CENTER; setTextColor(Palette.steel) },28)
        ui.add(group,ui.button(t("ロックのアクセスを許可","Allow lock access"),true) { navigate("permissions") },12)
        ui.add(group,ui.button(t("ロック対象を選ぶ","Select lock targets")) { pickTargets() },0)
        ui.add(parent,group,0)
    }
    private fun permissions(parent: LinearLayout) {
        ui.heading(parent,t("使う前の準備","A little setup"),t("Bear Lockが時間どおりに動くように。","Help Bear Lock keep your schedule."))

        val c=ui.card()
        ui.add(c,ui.label(t("1. アプリの制限","1. App blocking"),19f,true),8)
        ui.add(c,ui.label(if(GuardService.instance!=null) t("接続済み","Connected") else t("未接続","Not connected"),15f),8)
        ui.add(c,ui.button(t("ユーザー補助を設定","Set up accessibility"),true) { disclose() },0); ui.add(parent,c,16)
        val a=ui.card(); ui.add(a,ui.label(t("2. 予約時刻の実行","2. Scheduled timing"),19f,true),8)
        ui.add(a,ui.label(if(Scheduling.permitted(this)) t("許可済み","Allowed") else t("アラームとリマインダーの許可が必要です。","Allow alarms and reminders."),15f),12)
        ui.add(a,ui.button(t("予約の権限を設定","Set up alarms")) {
            if(Build.VERSION.SDK_INT>=31) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,Uri.parse("package:$packageName")))
        },0); ui.add(parent,a,16)
        ui.add(parent,ui.label(t("権限の取消・強制停止中は制限できません。Android 17の高度な保護が有効な環境は対応確認中です。","Blocking cannot run while permission is revoked or the app is force-stopped. Android 17 Advanced Protection compatibility is not verified."),14f,muted=true),20)
        ui.add(parent,ui.button(t("ホームへ","Continue to home"),true) { getPreferences(0).edit().putBoolean("onboarded",true).apply(); navigate("home") })
    }
    private fun disclose() {
        AlertDialog.Builder(this).setTitle(t("ユーザー補助の使用について","Accessibility access"))
            .setMessage(t("Bear Lockは前面アプリの識別情報を読み、指定時間にブロック画面を表示します。Web制限が実行中の場合だけ、対応ブラウザのアドレス欄も読みます。本文やパスワードは読みません。URLや閲覧履歴を保存・送信せず、判定は端末内で行います。", "Bear Lock reads the foreground app identity to display your scheduled block screen. Only while website locks are active, it also reads the address bar in supported browsers. It does not read page contents or passwords, or store or transmit URLs or browsing history. Processing stays on your device."))
            .setNegativeButton(t("同意しない","Not now"),null).setPositiveButton(t("同意して設定へ","Agree and open settings")) { _,_->getPreferences(0).edit().putBoolean("access_consent_v1",true).apply(); startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }.show()
    }
    private fun settings(parent: LinearLayout) = SettingsScreen(this).show(parent)
}
