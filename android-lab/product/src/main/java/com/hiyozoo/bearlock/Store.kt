package com.hiyozoo.bearlock

import android.content.Context
import android.util.AtomicFile
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class Store(private val context: Context) {
    companion object { private val guard = Any() }
    private val file get() = AtomicFile(File(context.filesDir, "locks-v1.json"))
    var error: String? = null; private set
    fun read(): State = synchronized(guard) {
        error = null
        if (!file.baseFile.exists() && !File(file.baseFile.path + ".bak").exists()) return@synchronized State()
        try { Codec.decode(String(file.readFully())) } catch (e: Exception) { error = "storage_error"; throw IllegalStateException("storage_error", e) }
    }
    fun change(block: (State) -> State): State = synchronized(guard) {
        val old = read()
        val next = block(old)
        if (next != old) {
            val stream = file.startWrite()
            try { stream.write(Codec.encode(next).toByteArray()); file.finishWrite(stream) }
            catch (e: Exception) { file.failWrite(stream); throw e }
        }
        next
    }
    fun event(name: String) = synchronized(guard) {
        Log.i("BearLock", name)
        // Logging failure must not stop expiry checks or turn a successful save into a failure.
        runCatching {
            val f = File(context.filesDir, "diagnostics.log")
            if (f.length() > 128_000) f.writeText(f.readLines().takeLast(300).joinToString("\n") + "\n")
            f.appendText("${System.currentTimeMillis()} $name\n")
        }.onFailure { Log.w("BearLock", "diagnostics_unavailable", it) }
        Unit
    }
    fun clearLogs() = synchronized(guard) { File(context.filesDir,"diagnostics.log").delete() }
    fun logs() = File(context.filesDir, "diagnostics.log").takeIf { it.exists() }?.readText().orEmpty()
}
object Codec {
    private fun JSONArray.strings() = (0 until length()).map { getString(it) }.toSet()
    private fun JSONArray.ints() = (0 until length()).map { getInt(it) }.toSet()
    private fun <T> JSONArray.mapObjects(f: (JSONObject) -> T) = (0 until length()).map { f(getJSONObject(it)) }
    fun targets(t: Targets) = JSONObject().put("apps", JSONArray(t.apps.toList())).put("domains", JSONArray(t.domains.toList())).put("categories", JSONArray(t.categories.toList()))
    fun targets(j: JSONObject) = Targets(j.getJSONArray("apps").strings(), j.getJSONArray("domains").strings(), j.getJSONArray("categories").ints())
    fun encode(s: State): String = JSONObject().put("schema", 2).put("rules", JSONArray(s.rules.map {
        JSONObject().put("id", it.id).put("title", it.title).put("targets", targets(it.targets)).put("start", it.start).put("end", it.end)
            .put("days", JSONArray(it.days.toList())).put("minute", it.minute).put("duration", it.durationMinutes).put("zone", it.zone).put("enabled", it.enabled)
    }))
        .put("recent", JSONArray(s.recent.map { JSONObject().put("targets", targets(it.targets)).put("used", it.usedAt).put("pinned", it.pinned).put("pinnedAt", it.pinnedAt ?: JSONObject.NULL) })).toString()
    fun decode(text: String): State {
        val j = JSONObject(text); require(j.getInt("schema") == 2)
        return State(j.getJSONArray("rules").mapObjects {
            Rule(it.getString("id"), it.getString("title"), targets(it.getJSONObject("targets")), it.getLong("start"), it.getLong("end"),
                it.getJSONArray("days").ints(), it.getInt("minute"), it.getInt("duration"), it.getString("zone"), it.optBoolean("enabled", true))
        }, Planner.trimRecent(j.getJSONArray("recent").mapObjects { Recent(targets(it.getJSONObject("targets")), it.getLong("used"), it.getBoolean("pinned"), if(it.isNull("pinnedAt")) null else it.getLong("pinnedAt")) }))
    }
}
