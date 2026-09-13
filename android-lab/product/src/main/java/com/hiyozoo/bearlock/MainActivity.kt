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
    var route: Route = Route.Home
    val page get() = route.page
    var editor = EditorDraft()
    val mode get() = editor.mode.ordinal
    var expandedTargets = false
    var visualPreview = false
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
    private var renderedActiveKeys = emptyList<String>()
    private var renderedEditable = true
    private fun editingAllowed(): Boolean {
        val id = editor.originalID ?: return true
        val saved = state.rules.find { it.id == id } ?: return false
        val now = System.currentTimeMillis()
        return Planner.editable(saved, now) && (saved.recurring || saved.single!!.start > now)
    }
    private fun statusKey() = "${GuardService.instance != null}:${Scheduling.permitted(this)}:${store.error}"
    private val heartbeat = object : Runnable {
        override fun run() {
            if (page in listOf("home", "schedules")) {
                load()
                if (renderedActiveKeys != state.activeLocks(System.currentTimeMillis()).map { it.key }) render()
                else countdown?.text = remaining(countdownEnd)
            }
            if (page == "compose") {
                load()
                if (renderedEditable != editingAllowed()) render()
            }
            if(page in listOf("home","setup","settings") && lastStatus != statusKey()) render()
            handler.postDelayed(this,1000)
        }
    }
    fun t(ja: String,en: String) = tr(this,ja,en)
    override fun attachBaseContext(base: android.content.Context) {
        configureLanguage(base)
        val language=if(BuildConfig.DEBUG) base.getSharedPreferences("appearance",0).getString("language","").orEmpty() else ""
        if(language.isEmpty()) super.attachBaseContext(base) else {
            val config=android.content.res.Configuration(base.resources.configuration)
            config.setLocale(java.util.Locale.forLanguageTag(language))
            super.attachBaseContext(base.createConfigurationContext(config))
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33) onBackInvokedDispatcher.registerOnBackInvokedCallback(android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT) { goBack() }
        editor.targets=runCatching { Codec.targets(org.json.JSONObject(getPreferences(0).getString("selection","")!!)) }.getOrDefault(Targets())
        if (savedInstanceState != null) restore(savedInstanceState)
        else if (!getPreferences(0).getBoolean("onboarded",false)) route=Route.Setup
        if(savedInstanceState == null && BuildConfig.DEBUG && intent.hasExtra("qaPage")) {
            route=routeForPage(intent.getStringExtra("qaPage")!!)
            if(intent.getBooleanExtra("qaDraft",false)) editor.targets=Targets(apps=setOf("com.hiyozoo.bearlock.probe"))
        }
        render()
    }
    override fun onResume() { super.onResume(); GuardService.instance?.appForeground(); load(); render(); syncSchedules(); handler.post(heartbeat) }
    override fun onPause() { handler.removeCallbacks(heartbeat); super.onPause() }
    override fun onSaveInstanceState(out: Bundle) {
        out.putSerializable("route",route)
        out.putSerializable("editor",editor)
        out.putBoolean("expandedTargets",expandedTargets)
        super.onSaveInstanceState(out)
    }
    @Suppress("DEPRECATION")
    private fun restore(b: Bundle) {
        route=b.getSerializable("route") as? Route ?: Route.Home
        editor=b.getSerializable("editor") as? EditorDraft ?: EditorDraft()
        expandedTargets=b.getBoolean("expandedTargets")
        if(editor.originalID != null && runCatching { store.read().rules.none { it.id==editor.originalID } }.getOrDefault(true)) {
            route=Route.Home; editor=EditorDraft(); restoreSelection()
        }
    }
    @android.annotation.SuppressLint("GestureBackNavigation") // API 33+ uses the registered OnBackInvokedCallback above.
    @Deprecated("Used only by Android 8–12")
    override fun onBackPressed() { goBack() }
    fun goBack() {
        when(val current=route) {
            is Route.Permissions -> navigate(current.returnTo)
            is Route.Picker -> { editor.targets=current.original; navigate(current.returnTo) }
            Route.Support -> navigate(Route.Settings)
            Route.Home -> finish()
            Route.Editor -> { editor=EditorDraft(); restoreSelection(); navigate(Route.Home) }
            else -> navigate(Route.Home)
        }
    }
    fun restoreSelection() { editor.targets=runCatching { Codec.targets(org.json.JSONObject(getPreferences(0).getString("selection","")!!)) }.getOrDefault(Targets()) }
    fun persistSelection() { getPreferences(0).edit().putString("selection",Codec.targets(editor.targets).toString()).apply() }
    fun pickTargets() {
        if(state.activeLocks(System.currentTimeMillis()).isNotEmpty()) { error("active_immutable"); return }
        navigate(Route.Picker(route,editor.targets))
    }
    fun saveSelection() {
        load()
        if(state.activeLocks(System.currentTimeMillis()).isNotEmpty()) { error("active_immutable"); return }
        if(editor.targets.empty) { error("empty_targets"); return }
        persistSelection()
        getPreferences(0).edit().putBoolean("onboarded",true).apply()
        val destination=(route as? Route.Picker)?.returnTo ?: Route.Home
        navigate(if(destination == Route.Setup) Route.Home else destination)
    }
    open fun load() { runCatching { store.read() }.onSuccess { state=it } }
    fun requestPermissions(forConfirmation: Boolean = false) {
        navigate(Route.Permissions(route,if(forConfirmation) PermissionReturn.CONFIRM else PermissionReturn.BACK))
    }
    fun navigate(next: Route) { route=next; render() }
    // String entry points are limited to existing QA page names and simple navigation links.
    fun routeForPage(name: String): Route = when(name) {
        "setup" -> Route.Setup; "compose" -> Route.Editor; "settings" -> Route.Settings
        "support" -> Route.Support; "schedules" -> Route.Schedules; "fixture" -> Route.Fixture
        "targets" -> Route.Picker(route,editor.targets)
        else -> Route.Home
    }
    fun navigate(next: String) = navigate(routeForPage(next))
    fun edit(rule: Rule) {
        load()
        if (!Planner.editable(rule, System.currentTimeMillis())) { error("active_immutable"); return }
        editor=EditorDraft.editing(rule)
        navigate(Route.Editor)
    }
    open fun render() {
        val previousY=if(renderedPage==page) contentScroll?.scrollY ?: 0 else 0
        renderedPage=page
        countdown=null; pickerCount=null; pickerSave=null; load(); lastStatus=statusKey()
        renderedActiveKeys=state.activeLocks(System.currentTimeMillis()).map { it.key }
        renderedEditable=editingAllowed()
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
                val isEditingPage=page=="targets" || page=="compose"
                val cancel=ui.textButton(if(isEditingPage) t("キャンセル","Cancel") else t("戻る","Back")) { goBack() }.apply { id=View.generateViewId(); textSize=14f }
                val save=ui.textButton(if(page=="compose") t("保存","Save") else "") { if(page=="compose") Composer(this).saveEdit() }.apply { id=View.generateViewId(); textSize=14f; visibility=if(page=="compose") View.VISIBLE else View.INVISIBLE; isEnabled=renderedEditable }
                val side=ui.dp(if(ui.compact) 132 else 96)
                toolbar.addView(cancel,android.widget.RelativeLayout.LayoutParams(side,-2).apply { addRule(android.widget.RelativeLayout.ALIGN_PARENT_START) })
                toolbar.addView(save,android.widget.RelativeLayout.LayoutParams(side,-2).apply { addRule(android.widget.RelativeLayout.ALIGN_PARENT_END) })
                val name=when(page) { "targets"->t("ロック対象","Lock targets"); "compose"->if(mode==3) t("繰り返し","Repeat") else t("ロックを編集","Edit Lock"); "permissions"->t("アクセス許可","Permissions"); "support"->t("Bear Lockを応援","Support Bear Lock"); else->t("設定","Settings") }
                toolbar.addView(ui.label(name,17f,true).apply { gravity=Gravity.CENTER; minHeight=ui.dp(50) },android.widget.RelativeLayout.LayoutParams(-1,-2).apply { if(ui.compact) addRule(android.widget.RelativeLayout.BELOW,cancel.id) else { addRule(android.widget.RelativeLayout.END_OF,cancel.id); addRule(android.widget.RelativeLayout.START_OF,save.id) } })
                bar.addView(toolbar,LinearLayout.LayoutParams(-1,-2))
            }
            root.addView(bar)
        }
        val scroll=ScrollView(this).apply { isFillViewport=true; clipToPadding=false }; contentScroll=scroll
        body=ui.column().apply { setPadding(ui.dp(20),ui.dp(12),ui.dp(20),ui.dp(24)) }
        if(page=="targets") {
            // The picker owns its scrolling viewport; nesting a list in ScrollView defeats recycling.
            contentScroll=null
            root.addView(body,LinearLayout.LayoutParams(-1,0,1f))
        } else {
            scroll.addView(body); root.addView(scroll,LinearLayout.LayoutParams(-1,0,1f))
        }
        when(page) {
            "setup" -> setup(body); "home" -> home(body); "compose" -> { Composer(this).showEditor(body); if (!renderedEditable) disableEditor(body) }
            "targets" -> TargetPicker(this).show(body); "schedules" -> schedules(body); "settings" -> settings(body); "support" -> SupportScreen(this).show(body)
            "permissions" -> permissions(body)
        }
        if(page=="targets") {
            val footer=ui.column().apply { setPadding(ui.dp(20),ui.dp(12),ui.dp(20),ui.dp(12)); background=ui.bg(Palette.white,0) }
            pickerCount=ui.label(t("${editor.targets.count}件を選択中","${editor.targets.count} selected"),13f,muted=true)
            ui.add(footer,pickerCount!!,8)
            pickerSave=ui.button(t("保存","Save"),true) { saveSelection() }.apply { isEnabled=!editor.targets.empty; alpha=if(isEnabled) 1f else .5f }
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
        try { state=store.change(block); render(); syncSchedules() } catch(e: Exception) { error(e.message) }
    }
    private fun disableEditor(view: View) {
        view.isEnabled=false
        if(view is ViewGroup) for(i in 0 until view.childCount) disableEditor(view.getChildAt(i))
    }
    fun syncSchedules() {
        Scheduling.sync(this).onFailure {
            AlertDialog.Builder(this).setTitle(t("ロックの監視を更新できません", "Monitoring could not be updated"))
                .setMessage(t("予約した時刻にロックが動作しない可能性があります。再試行するか、Bear Lockを開き直してください。", "Scheduled blocking may not work. Retry or reopen Bear Lock."))
                .setNegativeButton(t("閉じる", "Close"),null)
                .setPositiveButton(t("再試行", "Retry")) { _,_ -> syncSchedules() }.show()
        }
    }
    fun error(key: String?) {
        val message=when(key) {
            "pin_limit" -> t("ピン留めできる対象は3件までです。","You can pin up to three targets.")
            "empty_targets" -> t("対象を1つ以上選んでください。","Choose at least one target.")
            "overlap" -> t("予約時間と重なっています。重ならない時間を選んでください。","This overlaps another lock. Choose a different time.")
            "rule_not_found" -> t("この予定は削除されています。", "This schedule is no longer available.")
            "active_immutable" -> t("開始したロックは変更・削除できません。","An active lock cannot be changed or deleted.")
            "storage_error" -> t("保存データを読み込めません。上書きせず保持しています。設定の診断をご確認ください。","Saved data cannot be read. It has been preserved. Check diagnostics in Settings.")
            "invalid_domain" -> t("有効なドメインを入力してください。","Enter a valid domain.")
            else -> t("日時・曜日とロック時間を確認してください。","Check the date, weekdays and lock duration.")
        }
        AlertDialog.Builder(this).setTitle(t("保存できません","Cannot save")).setMessage(message).setPositiveButton("OK",null).show()
    }
    fun home(parent: LinearLayout) {
        val now=System.currentTimeMillis()
        val active=state.activeLocks(now)
        val hasLocksToMonitor=state.rules.any { it.enabled && (it.recurring || it.single!!.end>now) }
        val missingScheduledAlarm = Planner.needsScheduledAlarm(state, System.currentTimeMillis()) && !Scheduling.permitted(this)
        SelectionSummary(this).show(parent,active.isNotEmpty())
        if(!visualPreview && store.error != null) {
            ui.add(parent,ui.label(t("保存データを読み込めません。予定の状態を確認できません。","Cannot read saved data. Schedule status is unknown."),17f,true),12)
            ui.add(parent,ui.button(t("再読み込み","Retry")) { load(); render() },12)
            ui.add(parent,ui.button(t("診断と問い合わせ","Diagnostics and support")) { navigate("settings") },16)
        } else if(!visualPreview && hasLocksToMonitor && GuardService.instance==null) {
            ui.add(parent,ui.label(t("アプリの制限は停止中です。ユーザー補助を接続してください。","App blocking is unavailable. Connect the accessibility service."),17f,true),16)
        } else if(!visualPreview && missingScheduledAlarm) {
            ui.add(parent,ui.label(t("予約時刻の動作に必要な権限がありません。設定を確認してください。","Scheduled timing permission is missing. Review permissions."),17f,true),16)
        }
        if(active.isNotEmpty() && (visualPreview || (store.error == null && GuardService.instance != null))) {
            countdownEnd=active.maxOf { it.end }
            countdown=ActiveCard(ui).show(parent,remaining(countdownEnd),timeText(countdownEnd))
            ui.add(parent,ui.label(t("ロック中は短縮、削除、対象アプリの削減はできません。","During a lock, you cannot shorten it, delete it, or reduce blocked apps."),13f,muted=true),20)
            if(mode==0) editor.chooseMode(ComposerMode.LATER,System.currentTimeMillis())
        }
        if(active.isNotEmpty() && mode==0) editor.chooseMode(ComposerMode.LATER,System.currentTimeMillis())
        if(!visualPreview && hasLocksToMonitor && (GuardService.instance==null || missingScheduledAlarm || store.error!=null)) {
            ui.add(parent,ui.textButton(t("動作に必要な設定を確認","Review required permissions")) { requestPermissions() },16)
        }
        if(store.error == null) {
            Composer(this).show(parent)
            schedules(parent)
        }
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
        ui.add(group,ui.label(t("開始後は途中で解除できません。終了時刻になると、自動で解除されます。","Once started, the lock cannot be ended early. It ends automatically at the chosen time."),15f,muted=true).apply { gravity=Gravity.CENTER },24)
        ui.add(group,ui.button(t("はじめる","Get started"),true) {
            getPreferences(0).edit().putBoolean("onboarded",true).apply(); navigate("home")
        },0)
        ui.add(parent,group,0)
    }
    private fun permissions(parent: LinearLayout) {
        val flow=route as Route.Permissions
        val returnToConfirmation=flow.action == PermissionReturn.CONFIRM
        ui.heading(parent,t("ロックに必要な設定","Required settings"),t("ロックの開始と解除に必要な状態を確認します。","Check the settings used to start and end locks."))

        val c=ui.card()
        ui.add(c,ui.label(t("1. アプリの制限","1. App blocking"),19f,true),8)
        ui.add(c,ui.label(if(GuardService.instance!=null) t("接続済み","Connected") else t("未接続","Not connected"),15f),8)
        ui.add(c,ui.button(t("ユーザー補助を設定","Set up accessibility"),true) { disclose() },0); ui.add(parent,c,16)
        if(!returnToConfirmation || mode != 0) {
            val a=ui.card(); ui.add(a,ui.label(t("2. 予約を使う場合のみ","2. Only for scheduled locks"),19f,true),8)
            ui.add(a,ui.label(t("後で・日時指定・繰り返しの開始時刻を正確に処理するために使います。今すぐのロックには不要です。","Used to start Later, Date and Repeat locks at the scheduled time. Not needed for immediate locks."),14f,muted=true),12)
            ui.add(a,ui.label(if(Scheduling.permitted(this)) t("許可済み","Allowed") else t("アラームとリマインダーの許可が必要です。","Allow alarms and reminders."),15f),12)
            ui.add(a,ui.button(t("アラームとリマインダーを設定","Set up alarms")) {
                if(Build.VERSION.SDK_INT>=31) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,Uri.parse("package:$packageName")))
            },0); ui.add(parent,a,16)
        }
        ui.add(parent,ui.label(t("ユーザー補助を解除した場合や、Bear Lockを強制停止した場合はロックが動作しません。","Locks do not work while accessibility access is disabled or Bear Lock is force-stopped."),14f,muted=true),20)
        ui.add(parent,ui.button(if(returnToConfirmation) t("確認に戻る","Return to confirmation") else t("戻る","Back"),true) {
            val confirm=returnToConfirmation
            val destination=flow.returnTo
            navigate(destination)
            if(confirm && GuardService.instance!=null && (mode == 0 || Scheduling.permitted(this))) Composer(this).confirm()
        })
    }
    private fun disclose() {
        AlertDialog.Builder(this).setTitle(t("ユーザー補助の使用について","Accessibility access"))
            .setMessage(t("Bear Lockは前面アプリの識別情報を読み、指定時間にブロック画面を表示します。Web制限が実行中の場合だけ、対応ブラウザのアドレス欄も読みます。本文やパスワードは読みません。URLや閲覧履歴を保存・送信せず、判定は端末内で行います。", "Bear Lock reads the foreground app identity to display your scheduled block screen. Only while website locks are active, it also reads the address bar in supported browsers. It does not read page contents or passwords, or store or transmit URLs or browsing history. Processing stays on your device."))
            .setNegativeButton(t("同意しない","Not now"),null).setPositiveButton(t("同意して設定へ","Agree and open settings")) { _,_->getPreferences(0).edit().putBoolean("access_consent_v1",true).apply(); startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }.show()
    }
    private fun settings(parent: LinearLayout) = SettingsScreen(this).show(parent)
}
