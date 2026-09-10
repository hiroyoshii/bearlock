package com.hiyozoo.bearlock

import android.os.Bundle
import android.view.Gravity
import android.widget.*

/** Visual fixtures only, like iOS ScreenshotSupport. Never writes rules or grants permissions. */
class ScreenshotActivity: MainActivity() {
    private var screen="home"
    private val fixtureNow=System.currentTimeMillis()
    override fun onCreate(savedInstanceState: Bundle?) {
        screen=intent.getStringExtra("screen") ?: "home"
        intent.getStringExtra("language")?.takeIf { it in listOf("ja","en") }?.let {
            getSharedPreferences("appearance",0).edit().putString("language",it).commit()
            configureLanguage(this)
        }
        visualPreview=true
        super.onCreate(savedInstanceState)
        page=when(screen) { "home","setup","settings" -> screen; else->"fixture" }
        draft=Targets(apps=setOf("com.hiyozoo.bearlock.probe","com.android.chrome"),domains=setOf("example.com"))
        mode=when(screen) { "composeRepeat"->3; "composeDelayed"->1; "composeDate"->2;else->0 }
        render()
    }
    override fun dispatchTouchEvent(event: android.view.MotionEvent) = true
    override fun load() {
        val targets=Targets(apps=setOf("com.hiyozoo.bearlock.probe","com.android.chrome"),domains=setOf("example.com"))
        val delayed=Rule(id="visual-delayed",title=t("あとで開始","Starts later"),targets=targets,start=fixtureNow+30*60_000,end=fixtureNow+150*60_000,durationMinutes=120)
        val fixed=delayed.copy(id="visual-fixed",title=t("日時指定","Date & Time"),start=fixtureNow+7*3_600_000,end=fixtureNow+9*3_600_000)
        val repeat=delayed.copy(id="visual-repeat",title=t("繰り返し","Repeats"),days=setOf(1,2,3,4,5),minute=1380,durationMinutes=480)
        state=State(rules=listOf(delayed,fixed,repeat,repeat.copy(id="visual-off",enabled=false)))
    }
    override fun render() {
        if(screen in listOf("home","setup","settings")) { super.render(); return }
        val root=ui.column().apply { setBackgroundColor(Palette.background) }
        root.setOnApplyWindowInsetsListener { v,i -> v.setPadding(i.systemWindowInsetLeft,i.systemWindowInsetTop,i.systemWindowInsetRight,i.systemWindowInsetBottom); i }
        val scroll=ScrollView(this).apply { isFillViewport=true }
        val body=ui.column().apply { setPadding(ui.dp(20),ui.dp(20),ui.dp(20),ui.dp(20)) }
        when(screen) {
            "confirmation" -> {
                root.setBackgroundColor(Palette.white); body.setPadding(0,0,0,0); body.gravity=Gravity.CENTER
                ui.add(body,ConfirmationContent(ui).build(t("3件の対象","3 targets"),dateText(fixtureNow+30*60_000),dateText(fixtureNow+150*60_000),false,{},{}),0)
            }
            "activeLock" -> {
                ui.add(body,ui.label(t("熊は眠っています","Bear is sleeping"),34f,true),24)
                ActiveCard(ui).show(body,"1:33:57",timeText(fixtureNow+94*60_000))
                ui.add(body,ui.label(t("ロック中は短縮、削除、対象アプリの削減はできません。","During a lock, you cannot shorten it, delete it, or reduce blocked apps."),13f,muted=true).apply { gravity=Gravity.CENTER },0)
            }
            else -> {
                val name=when(screen) { "composeRepeat"->t("繰り返し","Repeat");"composeDelayed"->t("あとで開始","Start later");"composeDate"->t("日時指定","Date & Time");else->t("今すぐ開始","Start now") }
                ui.add(body,ui.label(name,34f,true),24); ui.add(body,ui.label(name,17f,true),16)
                Composer(this).show(body)
            }
        }
        scroll.addView(body); root.addView(scroll,LinearLayout.LayoutParams(-1,-1)); setContentView(root); root.requestApplyInsets()
    }
}
