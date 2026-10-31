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
    private val operations by lazy { LockOperations(store::change, ::updateMonitoring) }
    val catalog by lazy { Catalog(this) }
    var route: Route = Route.Home
    val page get() = route.page
    var editor = EditorDraft()
    val mode get() = editor.mode.ordinal
    var expandedTargets = false
    var visualPreview = false
    var state = State()
    private var selectionReadFailed = false
    val savedDataAvailable get() = store.error == null && !selectionReadFailed
    private lateinit var body: LinearLayout
    private var renderedPage: String? = null
    private var contentScroll: ScrollView? = null
    private val handler = Handler(Looper.getMainLooper())
    var pickerCount: TextView? = null
    var pickerSave: Button? = null
    var saveErrorLabel: TextView? = null
    private var countdown: TextView? = null
    private var countdownEnd = 0L
    private var lastStatus = ""
    private var renderedActiveKeys = emptyList<String>()
    private var renderedScheduleIDs = emptyList<String>()
    private var renderedEditable = true
    private var wakeDialog: AlertDialog? = null
    private fun editingAllowed(): Boolean {
        if(!savedDataAvailable) return false
        val id = editor.originalID ?: return true
        val saved = state.rules.find { it.id == id } ?: return false
        val now = System.currentTimeMillis()
        return Planner.scheduleEditable(state, saved, now)
    }
    private fun statusKey() = "${GuardService.instance != null}:${Scheduling.permitted(this)}:${store.error}:$selectionReadFailed:${Scheduling.updateFailed}"
    private fun activePresentationKeys(now: Long)=state.activeLocks(now).map { "${it.key}:${it.end}:${Planner.canScheduleFreeWake(it,now)}" }
    private val heartbeat = object : Runnable {
        override fun run() {
            if (page in listOf("home", "schedules")) {
                load()
                val now=System.currentTimeMillis()
                if (renderedActiveKeys != activePresentationKeys(now) ||
                    renderedScheduleIDs != state.scheduledRules(now).map { it.id }) render()
                else countdown?.text = remaining(countdownEnd)
                if(page=="home") updateEditorActions()
            }
            if (page == "compose") {
                load()
                if (renderedEditable != editingAllowed()) render()
                updateEditorActions()
            }
            if(page in listOf("home","setup","settings","schedules") && lastStatus != statusKey()) render()
            handler.postDelayed(this,1000)
        }
    }
    fun t(ja: String,en: String) = tr(this,ja,en)
    fun updateEditorActions() {
        val valid=editor.canSubmit(System.currentTimeMillis())
        findViewById<View>(android.R.id.content)?.findViewWithTag<Button>("editor-save")?.apply { isEnabled=editingAllowed() && valid; alpha=if(isEnabled) 1f else .5f }
        findViewById<View>(android.R.id.content)?.findViewWithTag<Button>("composer-primary")?.apply { isEnabled=savedDataAvailable && valid; alpha=if(isEnabled) 1f else .5f }
    }
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
        restoreSelection()
        if (savedInstanceState != null) restore(savedInstanceState)
        else if (!getPreferences(0).getBoolean("onboarded",false)) route=Route.Setup
        if(savedInstanceState == null && BuildConfig.DEBUG && intent.hasExtra("qaPage")) {
            route=routeForPage(intent.getStringExtra("qaPage")!!)
            if(intent.getBooleanExtra("qaDraft",false)) editor.targets=Targets(apps=setOf("com.hiyozoo.bearlock.probe"))
        }
        render()
    }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); setIntent(intent) }
    override fun onResume() {
        super.onResume(); GuardService.instance?.appForeground(); load()
        val wakeRuleId=intent.getStringExtra("wakeRuleId")
        val wakeStart=intent.getLongExtra("wakeOccurrenceStart",Long.MIN_VALUE)
        intent.removeExtra("wakeRuleId"); intent.removeExtra("wakeOccurrenceStart")
        if(wakeRuleId != null) route=Route.Home
        render(); syncSchedules(); handler.post(heartbeat)
        if(wakeRuleId != null) {
            val lock=state.activeLocks(System.currentTimeMillis()).find { it.ruleId==wakeRuleId && it.start==wakeStart }
            if(!savedDataAvailable) error("storage_error")
            else if(lock==null) error("wake_ended")
            else showWakeOptions(lock)
        }
    }
    override fun onPause() { handler.removeCallbacks(heartbeat); wakeDialog?.dismiss(); wakeDialog=null; super.onPause() }
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
            Route.Support, Route.Diagnostics -> navigate(Route.Settings)
            is Route.Licenses -> navigate(if(current.entry==null) Route.Settings else Route.Licenses())
            Route.Home -> finish()
            Route.Editor -> { editor=EditorDraft(); restoreSelection(); navigate(Route.Home) }
            else -> navigate(Route.Home)
        }
    }
    fun restoreSelection() {
        runCatching {
            val saved=store.read()
            val legacy=if(saved.selection==null) getPreferences(0).getString("selection",null) else null
            state=if(saved.selection==null && legacy!=null) {
                val targets=Codec.targets(org.json.JSONObject(legacy))
                // Restore an already-saved legacy value, not a user edit during an active lock.
                store.change { it.copy(selection=targets) }
            } else saved
            // Once the AtomicFile owns selection, never read a stale legacy value again.
            if(state.selection!=null && getPreferences(0).contains("selection")) getPreferences(0).edit().remove("selection").apply()
            state.selection ?: Targets()
        }.onSuccess { editor.targets=it; selectionReadFailed=false }
            .onFailure { selectionReadFailed=true }
    }
    fun selectTargets(targets: Targets): Boolean {
        if(selectionReadFailed) { error("storage_error"); return false }
        val outcome=operations.selectTargets(targets)
        if(outcome is OperationOutcome.Rejected) {
            error(if(outcome.cause.message in listOf("active_immutable","empty_targets","storage_error")) outcome.cause.message else "selection_save")
            return false
        }
        state=(outcome as OperationOutcome.Saved).state
        editor.targets=targets
        if(outcome.reflection.isFailure) showReflectionFailure()
        return true
    }
    fun pickTargets() {
        load()
        if(!savedDataAvailable) { error("storage_error"); return }
        if(state.activeLocks(System.currentTimeMillis()).isNotEmpty()) { error("active_immutable"); return }
        navigate(Route.Picker(route,editor.targets))
    }
    fun saveSelection() {
        if(!selectTargets(editor.targets)) return
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
        "licenses" -> Route.Licenses()
        "support" -> Route.Support; "diagnostics" -> Route.Diagnostics; "schedules" -> Route.Schedules; "fixture" -> Route.Fixture
        "targets" -> Route.Picker(route,editor.targets)
        else -> Route.Home
    }
    fun navigate(next: String) = navigate(routeForPage(next))
    fun edit(rule: Rule) {
        load()
        if(!savedDataAvailable) { error("storage_error"); return }
        val saved=state.rules.find { it.id==rule.id } ?: run { error("rule_not_found"); return }
        val now=System.currentTimeMillis()
        if (!Planner.scheduleEditable(state, saved, now)) {
            error(if(Planner.editable(state,saved,now)) "rule_started" else "active_immutable"); return
        }
        editor=EditorDraft.editing(saved)
        navigate(Route.Editor)
    }
    open fun render() {
        if(!BuildConfig.DEBUG && route==Route.Diagnostics) route=Route.Settings
        val scrollPage=when(val current=route) { is Route.Licenses -> "$page:${current.entry}"; else -> page }
        val previousY=if(renderedPage==scrollPage) contentScroll?.scrollY ?: 0 else 0
        renderedPage=scrollPage
        countdown=null; pickerCount=null; pickerSave=null; load(); lastStatus=statusKey()
        renderedActiveKeys=activePresentationKeys(System.currentTimeMillis())
        renderedScheduleIDs=state.scheduledRules(System.currentTimeMillis()).map { it.id }
        renderedEditable=editingAllowed()
        val grouped=page in listOf("compose","settings","diagnostics","licenses")
        val pageBackground=if(grouped) Palette.grouped else Palette.background
        val root=ui.column().apply { setBackgroundColor(pageBackground) }
        root.setOnApplyWindowInsetsListener { v,ins -> v.setPadding(ins.systemWindowInsetLeft,ins.systemWindowInsetTop,ins.systemWindowInsetRight,ins.systemWindowInsetBottom); ins }
        if(page!="setup") {
            val bar=ui.row().apply {
                setPadding(ui.dp(20),ui.dp(12),ui.dp(20),ui.dp(12))
                setBackgroundColor(pageBackground)
                elevation=ui.dp(1).toFloat(); outlineProvider=null // Keep scrolled content behind the fixed header, without a shadow.
            }
            if(page=="home") {
                bar.addView(ui.asset(R.drawable.brand_header,44).apply {
                    background=ui.bg(Palette.white,100); scaleType=ImageView.ScaleType.CENTER_CROP
                    elevation=ui.dp(2).toFloat()
                    setPadding(ui.dp(6),0,ui.dp(6),0)
                },LinearLayout.LayoutParams(ui.dp(150),ui.dp(44)))
                bar.addView(View(this),LinearLayout.LayoutParams(0,1,1f))
                bar.addView(ui.iconButton("gear",t("設定","Settings")) { navigate("settings") }.apply {
                    background=ui.touchBackground(Palette.white,radius=100)
                    setCompoundDrawables(ui.icon("gear",Palette.navy).apply { setBounds(0,0,ui.dp(24),ui.dp(24)) },null,null,null)
                    setPadding(ui.dp(10),ui.dp(10),ui.dp(10),ui.dp(10)); elevation=ui.dp(2).toFloat()
                    layoutParams=LinearLayout.LayoutParams(ui.dp(44),ui.dp(44))
                })
            } else {
                val toolbar=android.widget.RelativeLayout(this)
                val isEditingPage=page=="targets" || page=="compose"
                val cancel=ui.textButton(if(isEditingPage) t("キャンセル","Cancel") else t("戻る","Back")) { goBack() }.apply { id=View.generateViewId(); textSize=14f }
                val save=ui.textButton(if(page=="compose") t("保存","Save") else "") { if(page=="compose") Composer(this).saveEdit() }.apply { id=View.generateViewId(); tag="editor-save"; textSize=14f; visibility=if(page=="compose") View.VISIBLE else View.INVISIBLE; isEnabled=renderedEditable && editor.canSubmit(System.currentTimeMillis()) }
                if(grouped) for(control in listOf(cancel,save)) control.apply {
                    background=ui.touchBackground(Palette.white,radius=100); setTextColor(Palette.textPrimary); minHeight=ui.dp(44)
                }
                val side=ui.dp(if(ui.compact) 132 else 96)
                toolbar.addView(cancel,android.widget.RelativeLayout.LayoutParams(side,-2).apply { addRule(android.widget.RelativeLayout.ALIGN_PARENT_START) })
                toolbar.addView(save,android.widget.RelativeLayout.LayoutParams(side,-2).apply { addRule(android.widget.RelativeLayout.ALIGN_PARENT_END) })
                val name=when(page) { "targets"->t("ロック対象","Lock targets"); "compose"->if(mode==3) t("繰り返し","Repeat") else t("ロック予定を編集","Edit Lock"); "permissions"->t("アクセス許可","Permissions"); "support"->t("サポート","Support"); "diagnostics"->t("診断","Diagnostics"); else->t("設定","Settings") }
                if(!grouped) toolbar.addView(ui.label(name,17f,true).apply { gravity=Gravity.CENTER; minHeight=ui.dp(50) },android.widget.RelativeLayout.LayoutParams(-1,-2).apply { if(ui.compact) addRule(android.widget.RelativeLayout.BELOW,cancel.id) else { addRule(android.widget.RelativeLayout.END_OF,cancel.id); addRule(android.widget.RelativeLayout.START_OF,save.id) } })
                bar.addView(toolbar,LinearLayout.LayoutParams(-1,-2))
            }
            root.addView(bar)
        }
        val scroll=ScrollView(this).apply { isFillViewport=true; clipToPadding=false }; contentScroll=scroll
        body=ui.column().apply { setPadding(ui.dp(20),ui.dp(12),ui.dp(20),ui.dp(24)) }
        if(grouped) ui.add(body,ui.label(when(page) { "compose"->if(mode==3) t("繰り返し","Repeat") else t("ロック予定を編集","Edit Lock"); "diagnostics"->t("診断","Diagnostics"); "licenses"->t("オープンソースライセンス","Open source licenses"); else->t("設定","Settings") },32f,true).apply { setTextColor(Palette.textPrimary); if(android.os.Build.VERSION.SDK_INT>=28) isAccessibilityHeading=true },24)
        if(page=="targets") {
            // The picker owns its scrolling viewport; nesting a list in ScrollView defeats recycling.
            contentScroll=null
            root.addView(body,LinearLayout.LayoutParams(-1,0,1f))
        } else {
            scroll.addView(body); root.addView(scroll,LinearLayout.LayoutParams(-1,0,1f))
        }
        if (page in listOf("home", "schedules", "settings")) statusWarnings(body)
        when(page) {
            "setup" -> setup(body); "home" -> home(body); "compose" -> { Composer(this).showEditor(body); if (!renderedEditable) disableEditor(body) }
            "targets" -> TargetPicker(this).show(body); "schedules" -> schedules(body); "settings" -> settings(body); "support" -> SupportScreen(this).show(body)
            "diagnostics" -> SettingsScreen(this).diagnostics(body)
            "licenses" -> LicensesScreen(this).show(body,(route as Route.Licenses).entry)
            "permissions" -> permissions(body)
        }
        if(page=="targets") {
            val footer=ui.column().apply { setPadding(ui.dp(20),ui.dp(12),ui.dp(20),ui.dp(12)); background=ui.bg(Palette.white,0) }
            saveErrorLabel=ui.label("",14f).apply { tag="selection-save-error"; setTextColor(android.graphics.Color.RED); visibility=View.GONE }
            ui.add(footer,saveErrorLabel!!,0)
            pickerCount=ui.label(if(editor.targets.empty) t("ロック対象が選択されていません。","No targets are selected.") else t("${editor.targets.count}件の対象","${editor.targets.count} targets"),13f,muted=true)
            ui.add(footer,pickerCount!!,8)
            pickerSave=ui.button(t("保存","Save"),true) { saveSelection() }.apply { isEnabled=!editor.targets.empty; alpha=if(isEnabled) 1f else .5f }
            ui.add(footer,pickerSave!!,0); root.addView(footer)
        }
        window.statusBarColor=pageBackground
        setContentView(root); root.requestApplyInsets()
        scroll.post { scroll.scrollTo(0,previousY) }
        if(Build.VERSION.SDK_INT>=30) window.insetsController?.setSystemBarsAppearance(
            android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
            android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS)
        else window.decorView.systemUiVisibility=View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
    }
    fun setRecentPinned(recent: Recent, pinned: Boolean) = finishHistoryOperation(operations.setRecentPinned(recent.targets,pinned))
    fun deleteRecentTarget(recent: Recent) = finishHistoryOperation(operations.deleteRecentTarget(recent.targets))
    private fun finishHistoryOperation(outcome: OperationOutcome) {
        when(outcome) {
            is OperationOutcome.Rejected -> error(if(outcome.cause.message in listOf("pin_limit","storage_error")) outcome.cause.message else "history_storage")
            is OperationOutcome.Saved -> { state=outcome.state; render() }
        }
    }
    fun createSchedule(make: (Long)->Rule, onSaved: ()->Unit) = finishScheduleOperation(operations.createSchedule(make),onSaved)
    fun updateSchedule(make: (Long)->Rule, onSaved: ()->Unit) = finishScheduleOperation(operations.updateSchedule(make),onSaved)
    fun deleteSchedule(id: String) = finishScheduleOperation(operations.deleteSchedule(id)) { render() }
    private fun finishScheduleOperation(outcome: OperationOutcome, onSaved: ()->Unit) {
        when(outcome) {
            is OperationOutcome.Rejected -> error(if(outcome.cause.message in listOf(
                "empty_targets","invalid_time","invalid_domain","active_immutable","past_time","overlap","rule_not_found","storage_error"
            )) outcome.cause.message else "schedule_storage")
            is OperationOutcome.Saved -> {
                state=outcome.state
                onSaved()
                if(outcome.reflection.isFailure) showReflectionFailure()
            }
        }
    }
    private fun disableEditor(view: View) {
        view.isEnabled=false
        if(view is ViewGroup) for(i in 0 until view.childCount) disableEditor(view.getChildAt(i))
    }
    open fun updateMonitoring(): Result<Unit> = Scheduling.sync(this)
    fun syncSchedules() {
        operations.retryReflection()
        render()
    }
    fun error(key: String?) {
        val message=when(key) {
            "selection_save" -> t("対象を保存できませんでした。選択内容はこの画面に保持しています。再試行してください。","Could not save the selection. Your draft is kept on this screen. Please retry.")
            "schedule_storage" -> t("予定の変更を保存できませんでした。元の状態を保持しています。再試行してください。","Could not save the schedule change. The previous state is preserved. Please retry.")
            "history_storage" -> t("履歴の変更を保存できませんでした。元の状態を保持しています。再試行してください。","Could not save the history change. The previous state is preserved. Please retry.")
            "pin_limit" -> t("固定できる対象は3件までです。","You can pin up to three targets.")
            "empty_targets" -> t("ブロック対象アプリが選択されていません。","No blocked apps are selected.")
            "past_time" -> t("未来の開始時刻を選んでください。","Choose a start time in the future.")
            "invalid_time" -> if(mode==3 && editor.days.isEmpty()) t("曜日を1つ以上選んでください。","Choose at least one weekday.")
                else if(mode!=3 && editor.duration<=0) t("ロック時間を1分以上にしてください。","Choose a lock duration longer than zero.")
                else t("日時・曜日とロック時間を確認してください。","Check the date, weekdays and lock duration.")
            "overlap" -> t("予約時間と重なっています。重ならない時間を選んでください。","This overlaps a scheduled lock. Choose a time that does not overlap.")
            "rule_not_found" -> t("この予定は削除されています。", "This schedule is no longer available.")
            "active_immutable" -> t("このロックは実行中のため変更できません。","This lock is already active and cannot be changed.")
            "rule_started" -> t("このロックは開始済みのため変更できません。","This lock has already started and cannot be changed.")
            "storage_error" -> t("データは上書きしていません。再試行して、ロック対象と予定を読み込んでください。","Your data has not been replaced. Retry to load your targets and schedules.")
            "invalid_domain" -> t("有効なドメインを入力してください。","Enter a valid domain.")
            "wake_ended" -> t("このロックはすでに終了しています。","This lock has already ended.")
            "wake_missing" -> t("起床リクエストはすでに終了しています。","The wake-up request is no longer active.")
            "wake_unavailable" -> t("残り30分以下です。予定した起床時刻までお待ちください。","30 minutes or less remain. Wait for the scheduled wake time.")
            "wake_storage" -> t("起床予約の変更を保存できません。元の状態を保持しています。再試行してください。","Could not save the wake-up change. The previous state is preserved. Please retry.")
            "browser_unavailable" -> t("Webサイトを開くブラウザが見つかりませんでした。","No browser is available to open the website.")
            else -> t("日時・曜日とロック時間を確認してください。","Check the date, weekdays and lock duration.")
        }
        val inline=saveErrorLabel
        if(key in listOf("selection_save","schedule_storage") && inline?.isAttachedToWindow==true) {
            inline.text=message; inline.visibility=View.VISIBLE
            inline.announceForAccessibility(message)
            return
        }
        AlertDialog.Builder(this).setTitle("Bear Lock").setMessage(message).setPositiveButton("OK",null).show()
    }
    private fun statusWarnings(parent: LinearLayout) {
        val now=System.currentTimeMillis()
        val readFailed=!visualPreview && !savedDataAvailable
        val needsMonitoring=state.activeLocks(now).isNotEmpty() || Planner.needsScheduledAlarm(state,now)
        val missingAccess=!visualPreview && needsMonitoring && GuardService.instance==null
        val missingAlarm=!visualPreview && Planner.needsScheduledAlarm(state,now) && !Scheduling.permitted(this)
        if(!readFailed && !Scheduling.updateFailed && !missingAccess && !missingAlarm) return
        val warning=ui.card().apply { tag="home-status-warning" }
        if(readFailed) {
            ui.add(warning,ui.label(t("保存データを読み込めません","Saved data could not be read"),17f,true),12)
            ui.add(warning,ui.label(t("データは上書きしていません。再試行して、ロック対象と予定を読み込んでください。","Your data has not been replaced. Retry to load your targets and schedules."),15f),12)
            ui.add(warning,ui.button(t("再試行","Retry")) { restoreSelection(); load(); syncSchedules() }.apply { tag="storage-retry" },12)
            ui.add(warning,ui.textButton(t("設定を開く","Open Settings")) { navigate("settings") },12)
        }
        if(Scheduling.updateFailed) {
            ui.add(warning,ui.label(t("ロックの監視を更新できません", "Monitoring could not be updated"),17f,true).apply {
                setCompoundDrawables(ui.icon("warning",Palette.navy).apply { setBounds(0,0,ui.dp(20),ui.dp(20)) },null,null,null); compoundDrawablePadding=ui.dp(8)
            },12)
            ui.add(warning,ui.label(t("予定は保存されています。監視を更新するまで、予定時刻にロックが動作しない可能性があります。", "Your schedules are saved. Scheduled blocking may not work until monitoring is updated."),15f),12)
            if(!readFailed) ui.add(warning,ui.textButton(t("再試行","Retry")) { syncSchedules() }.apply {
                tag="monitoring-retry"; setTextColor(Palette.link); layoutParams=LinearLayout.LayoutParams(-2,-2); setPadding(0,ui.dp(4),ui.dp(8),ui.dp(4))
            },0)
        }
        if(missingAccess) ui.add(warning,ui.label(t("アプリの制限は停止中です。ユーザー補助を接続してください。","App blocking is unavailable. Connect the accessibility service."),17f,true),12)
        if(missingAlarm) ui.add(warning,ui.label(t("予約時刻の動作に必要な権限がありません。設定を確認してください。","Scheduled timing permission is missing. Review permissions."),17f,true),12)
        if(missingAccess || missingAlarm) ui.add(warning,ui.button(t("動作に必要な設定を確認","Review required permissions")) { requestPermissions() },0)
        ui.add(parent,warning,20)
    }
    fun home(parent: LinearLayout) {
        val now=System.currentTimeMillis()
        val active=state.activeLocks(now)
        if(!savedDataAvailable) return // Kept data is not a verified current selection or lock state.
        SelectionSummary(this).show(parent,active.isNotEmpty())
        if(active.isNotEmpty() && (visualPreview || (store.error == null && GuardService.instance != null))) {
            val lock=active.maxBy { it.end }
            countdownEnd=lock.end
            countdown=ActiveCard(ui).show(parent,remaining(countdownEnd),timeText(countdownEnd,this),state.wakeRequest(lock),Planner.canScheduleFreeWake(lock,now)) { showWakeOptions(lock) }
            if(mode==0) editor.chooseMode(ComposerMode.LATER,System.currentTimeMillis())
        }
        if(active.isNotEmpty() && mode==0) editor.chooseMode(ComposerMode.LATER,System.currentTimeMillis())
        if(savedDataAvailable) {
            Composer(this).show(parent)
            schedules(parent)
        }
    }
    private fun remaining(end: Long): String {
        val seconds=((end-System.currentTimeMillis()).coerceAtLeast(0)/1000)
        return if(seconds>=3600) "%d:%02d:%02d".format(seconds/3600,seconds/60%60,seconds%60) else "%02d:%02d".format(seconds/60,seconds%60)
    }
    private fun showWakeOptions(lock: ActiveLock) {
        load()
        if(store.error != null) { error("storage_error"); return }
        val now=System.currentTimeMillis()
        val active=state.activeLocks(now).firstOrNull { it.key==lock.key }
        if(active==null) { error("wake_ended"); return }
        val request=state.wakeRequest(active)
        val content=ui.column().apply { setPadding(ui.dp(24),ui.dp(12),ui.dp(24),ui.dp(12)) }
        ui.add(content,ui.label(if(request!=null) t("${timeText(request.wakesAt,this)}に起床","Wakes at ${timeText(request.wakesAt,this)}")
            else t("起床で終了するのは今回のロックだけです。今後の繰り返し予定は残ります。","A wake-up ends only the current lock. Future repeating locks stay scheduled."),16f),12)
        if(!Scheduling.permitted(this)) ui.add(content,ui.label(t("正確なアラームが許可されていません。起床の反映が遅れる可能性があります。","Exact alarms are not allowed. Wake-up may be delayed."),14f,muted=true),12)
        if(GuardService.instance==null) ui.add(content,ui.label(t("アプリの制限は停止中です。設定からユーザー補助を再接続してください。","App blocking is stopped. Reconnect accessibility in Settings."),14f,muted=true),12)
        val builder=AlertDialog.Builder(this).setTitle(t("熊を起こす","Wake the bear"))
            .setView(ScrollView(this).apply { addView(content) }).setNegativeButton(t("キャンセル","Cancel"),null)
        if(request!=null) builder.setPositiveButton(t("起床を取り消す","Cancel wake-up")) { _,_-> changeWake(active,true) }
        else if(Planner.canScheduleFreeWake(active,now)) builder.setPositiveButton(t("無料で30分後に起こす","Wake in 30 minutes for free")) { _,_-> changeWake(active,false) }
        else ui.add(content,ui.label(t("残り30分以下です。予定した起床時刻までお待ちください。","30 minutes or less remain. Wait for the scheduled wake time."),14f,muted=true),0)
        wakeDialog?.dismiss()
        wakeDialog=builder.show().apply { getButton(AlertDialog.BUTTON_POSITIVE)?.tag=if(request!=null) "cancel-free-wake" else "schedule-free-wake" }
    }
    private fun changeWake(lock: ActiveLock, cancel: Boolean) {
        when(val outcome=if(cancel) operations.cancelWake(lock) else operations.scheduleWake(lock)) {
            is OperationOutcome.Rejected -> {
                error(if(outcome.cause.message in listOf("wake_ended","wake_missing","wake_unavailable","overlap","storage_error")) outcome.cause.message else "wake_storage")
                render()
            }
            is OperationOutcome.Saved -> {
                state=outcome.state
                render()
                if(outcome.reflection.isFailure) showReflectionFailure()
            }
        }
    }
    private fun showReflectionFailure() {
        render()
    }
    fun schedules(parent: LinearLayout) { if(savedDataAvailable) ScheduleList(this).show(parent) }
    private fun setup(parent: LinearLayout) {
        parent.gravity=Gravity.CENTER
        val group=ui.column().apply { setPadding(ui.dp(4),0,ui.dp(4),0) }
        ui.add(group,ui.asset(R.drawable.brand_hero,175).apply { layoutParams=LinearLayout.LayoutParams(minOf(ui.dp(310),resources.displayMetrics.widthPixels-ui.dp(48)),ui.dp(175)).apply { gravity=Gravity.CENTER_HORIZONTAL } },18)
        ui.add(group,ui.label(t("アプリを選び、時間を決めて、ロックします。","Choose apps. Set a time. Keep the lock."),20f,true).apply { gravity=Gravity.CENTER; setTextColor(Palette.steel) },28)
        ui.add(group,ui.label(t("指定時刻になると自動で解除します。必要な場合は無料で30分後に起こせます。","Locks end automatically at the chosen time. If needed, you can request a free wake-up in 30 minutes."),15f,muted=true).apply { gravity=Gravity.CENTER },24)
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
            .setNegativeButton(t("同意しない","Do not agree"),null).setPositiveButton(t("同意して設定へ","Agree and open settings")) { _,_->getPreferences(0).edit().putBoolean("access_consent_v1",true).apply(); startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }.show()
    }
    private fun settings(parent: LinearLayout) = SettingsScreen(this).show(parent)
}
