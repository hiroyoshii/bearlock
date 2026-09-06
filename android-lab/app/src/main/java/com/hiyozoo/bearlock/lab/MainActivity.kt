package com.hiyozoo.bearlock.lab

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.InputType
import android.widget.*

class MainActivity : Activity() {
    private lateinit var body: LinearLayout
    private lateinit var status: TextView
    private lateinit var methods: Spinner
    private lateinit var targets: Spinner
    private lateinit var delay: EditText
    private lateinit var duration: EditText
    private lateinit var start: Button
    private var packages = listOf<String>()
    private val handler = Handler(Looper.getMainLooper())
    private val update = object : Runnable {
        override fun run() { refresh(); handler.postDelayed(this, 1000) }
    }
    private fun text(value: String, size: Float = 16f) = TextView(this).apply {
        text = value; textSize = size; setTextColor(Color.rgb(27, 49, 67)); setPadding(0, dp(8), 0, dp(8))
    }.also { body.addView(it) }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun button(title: String, action: () -> Unit) = Button(this).apply {
        text = title; isAllCaps = false; minHeight = dp(48)
        setOnClickListener { runCatching(action).onFailure { error(it.message ?: "操作できませんでした。") } }
    }.also { body.addView(it) }
    private fun spinner(label: String, values: List<String>): Spinner {
        val caption = text(label)
        return Spinner(this).apply {
            id = android.view.View.generateViewId(); caption.labelFor = id; minimumHeight = dp(48)
            adapter = ArrayAdapter(this@MainActivity, android.R.layout.simple_spinner_dropdown_item, values)
        }.also { body.addView(it) }
    }
    private fun seconds(label: String, value: String): EditText {
        val caption = text(label)
        return EditText(this).apply {
            id = android.view.View.generateViewId(); caption.labelFor = id
            inputType = InputType.TYPE_CLASS_NUMBER; setText(value); minHeight = dp(48)
        }.also { body.addView(it) }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        body = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(24), dp(24), dp(24), dp(24)) }
        val scroll = ScrollView(this).apply { addView(body) }
        setContentView(scroll)
        scroll.setOnApplyWindowInsetsListener { v, insets ->
            v.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom); insets
        }
        text("Bear Lock Lab", 28f)
        text("Android ブロック比較\nロックは最大5分。終了まで方式・対象を変更できません。OSの設定から無効化できます。")
        status = text("状態を確認しています。")
        methods = spinner("検知方式", listOf("A · 使用状況＋通常の重ね表示", "B · Accessibility＋専用の重ね表示"))
        @Suppress("DEPRECATION")
        val apps = packageManager.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
            .filter { it.activityInfo.packageName != packageName && it.activityInfo.packageName != "com.android.settings" }
            .distinctBy { it.activityInfo.packageName }.sortedBy { it.loadLabel(packageManager).toString() }
        packages = apps.map { it.activityInfo.packageName }
        targets = spinner("対象アプリ（1つ）", apps.map { "${it.loadLabel(packageManager)} · ${it.activityInfo.packageName}" })
        packages.indexOf("com.hiyozoo.bearlock.probe").takeIf { it >= 0 }?.let { targets.setSelection(it) }
        delay = seconds("開始まで（0〜300秒）", "0")
        duration = seconds("ロック時間（5〜300秒）", "30")
        text("必要な権限", 20f)
        button("A: 使用状況へのアクセス") { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)) }
        button("A: 他のアプリの上に表示") { startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))) }
        button("B: Accessibility の説明と設定") {
            AlertDialog.Builder(this).setTitle("検知する情報について")
                .setMessage("選んだアプリの表示イベントに加え、再起動後も制限を戻すため、現在のウィンドウのアプリ識別情報を取得します。その取得にはウィンドウ内容へのアクセス権限が必要ですが、本文・入力内容・子要素は参照しません。対象名と比較ログは端末内だけに保存し、送信しません。")
                .setNegativeButton("今は許可しない", null)
                .setPositiveButton("同意して設定を開く") { _, _ -> startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }.show()
        }
        button("共通: 正確なアラーム") {
            if (Build.VERSION.SDK_INT >= 31) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
        }
        button("通知を許可") { if (Build.VERSION.SDK_INT >= 33) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1) }
        start = button("比較を予約・開始") { confirm() }
        button("対象アプリを開く") {
            val target = LabStore(this).read()?.target ?: packages.getOrNull(targets.selectedItemPosition)
            val launch = target?.let { packageManager.getLaunchIntentForPackage(it) }
            if (launch == null) error("対象アプリを選択してください。") else startActivity(launch)
        }
        button("比較ログを表示") {
            val output = TextView(this).apply { text = LabStore(this@MainActivity).logs().takeLast(24000); setTextIsSelectable(true); setPadding(24, 24, 24, 24) }
            AlertDialog.Builder(this).setTitle("端末内の比較ログ").setView(ScrollView(this).apply { addView(output) }).setPositiveButton("閉じる", null).show()
        }
    }
    private fun confirm() {
        val method = Method.entries[methods.selectedItemPosition]
        val missing = Permissions.missing(this, method)
        if (missing.isNotEmpty()) { error("設定が必要です: ${missing.joinToString()} "); return }
        val target = packages.getOrNull(targets.selectedItemPosition) ?: return error("対象アプリがありません。")
        val d = delay.text.toString().toIntOrNull() ?: return error("開始までの秒数を入力してください。")
        val length = duration.text.toString().toIntOrNull() ?: return error("ロック時間を入力してください。")
        LockWindow.create(method, target, System.currentTimeMillis(), d, length, LabStore(this).read())
        AlertDialog.Builder(this).setTitle("この条件で比較しますか？")
            .setMessage("${method.name}\n$target\n${d}秒後から${length}秒間\n開始後は途中解除できません。")
            .setNegativeButton("戻る", null).setPositiveButton("開始") { _, _ ->
                runCatching {
                    check(Permissions.missing(this, method).isEmpty()) { "権限を再確認してください。" }
                    LabStore(this).save(LockWindow.create(method, target, System.currentTimeMillis(), d, length, LabStore(this).read()))
                    Schedules.resume(this); refresh()
                }.onFailure { error(it.message ?: "開始できません。") }
            }.show()
    }
    private fun error(message: String) { AlertDialog.Builder(this).setMessage(message).setPositiveButton("OK", null).show() }
    private fun refresh() {
        val w = LabStore(this).read()
        val now = System.currentTimeMillis()
        val pending = w?.pending(now) == true
        if (pending && w != null) {
            methods.setSelection(w.method.ordinal)
            packages.indexOf(w.target).takeIf { it >= 0 }?.let { targets.setSelection(it) }
        }
        listOf(methods, targets, delay, duration, start).forEach { it.isEnabled = !pending }
        val state = when { w == null -> "比較なし"; now < w.start -> "予約中 · 開始まで ${(w.start - now) / 1000}秒"; w.active(now) -> "ロック期間中 · 残り ${(w.end - now) / 1000}秒"; else -> "比較終了" }
        val method = w?.takeIf { pending }?.method ?: Method.entries[methods.selectedItemPosition]
        val missing = Permissions.missing(this, method)
        status.text = "$state\n${if (missing.isEmpty()) "必要な権限: 接続済み（制限の成功は別途確認）" else "未設定・停止: ${missing.joinToString()}"}"
    }
    override fun onResume() { super.onResume(); AccessMonitor.instance?.appForeground(); handler.post(update) }
    override fun onPause() { handler.removeCallbacks(update); super.onPause() }
}
