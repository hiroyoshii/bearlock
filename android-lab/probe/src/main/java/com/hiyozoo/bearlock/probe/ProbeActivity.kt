package com.hiyozoo.bearlock.probe

import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView

class ProbeActivity : Activity() {
    private var taps = 0
    private fun record(name: String) = Log.i("BearLockProbe", "$name wallMs=${System.currentTimeMillis()} uptimeMs=${SystemClock.uptimeMillis()} taps=$taps")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val body = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER; setPadding(48, 48, 48, 48) }
        body.addView(TextView(this).apply { text = "Bear Lock Probe\nブロック対象の比較用アプリ"; textSize = 24f; gravity = Gravity.CENTER })
        body.addView(Button(this).apply {
            text = "タップ試験: 0"; minHeight = 160
            setOnClickListener { taps++; text = "タップ試験: $taps"; record("tap") }
        })
        body.addView(Switch(this).apply {
            text = "通常の重ね表示を拒否（Android 12+）"; minHeight = 160
            setOnCheckedChangeListener { _, enabled -> if (Build.VERSION.SDK_INT >= 31) window.setHideOverlayWindows(enabled) }
        })
        setContentView(body)
    }
    override fun onResume() { super.onResume(); record("resume") }
    override fun onPause() { record("pause"); super.onPause() }
}
