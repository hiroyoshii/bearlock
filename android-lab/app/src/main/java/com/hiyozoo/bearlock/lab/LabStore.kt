package com.hiyozoo.bearlock.lab

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.util.Log
import org.json.JSONObject
import java.io.File

class LabStore(private val context: Context) {
    private val prefs get() = context.getSharedPreferences("experiment", Context.MODE_PRIVATE)
    fun read(): LockWindow? = prefs.getString("window", null)?.let {
        val j = JSONObject(it)
        LockWindow(Method.valueOf(j.getString("method")), j.getString("target"), j.getLong("start"), j.getLong("end"))
    }
    fun save(window: LockWindow) {
        check(read()?.pending(System.currentTimeMillis()) != true) { "実行中・予約中の比較は変更できません。" }
        val j = JSONObject().put("method", window.method.name).put("target", window.target).put("start", window.start).put("end", window.end)
        check(prefs.edit().putString("window", j.toString()).commit())
        event("created", j)
    }
    fun event(name: String, details: JSONObject = JSONObject()) {
        val line = details.put("event", name).put("wallMs", System.currentTimeMillis())
            .put("elapsedMs", SystemClock.elapsedRealtime()).put("uptimeMs", SystemClock.uptimeMillis())
            .put("sdk", Build.VERSION.SDK_INT).put("device", "${Build.MANUFACTURER} ${Build.MODEL}").toString()
        Log.i("BearLockLab", line)
        synchronized(LabStore::class.java) {
            val file = File(context.filesDir, "events.jsonl")
            if (file.length() > 1_000_000) file.writeText(file.readLines().takeLast(1000).joinToString("\n", postfix = "\n"))
            file.appendText(line + "\n")
        }
    }
    fun logs(): String = File(context.filesDir, "events.jsonl").takeIf { it.exists() }?.readText() ?: "まだ記録がありません。"
}
