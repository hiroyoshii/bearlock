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
    fun schedule(value: LockSchedule): JSONObject = when(value) {
        is LockSchedule.Single -> JSONObject().put("type", "single").put("start",value.start).put("end",value.end).put("immediate",value.immediate)
        is LockSchedule.Weekly -> JSONObject().put("type", "weekly").put("days",JSONArray(value.days.toList()))
            .put("startMinute",value.startMinute).put("endMinute",value.endMinute).put("zone",value.zone)
    }
    fun schedule(value: JSONObject): LockSchedule = when(value.getString("type")) {
        "single" -> LockSchedule.Single(value.getLong("start"),value.getLong("end"),value.optBoolean("immediate",false))
        "weekly" -> LockSchedule.Weekly(value.getJSONArray("days").ints(),value.getInt("startMinute"),value.getInt("endMinute"),value.getString("zone"))
        else -> error("invalid_schedule")
    }
    fun encode(s: State): String = JSONObject().put("schema", 4).put("rules", JSONArray(s.rules.map {
        JSONObject().put("id", it.id).put("title", it.title).put("targets", targets(it.targets))
            .put("schedule", schedule(it.schedule)).put("enabled", it.enabled)
    }))
        .put("recent", JSONArray(s.recent.map { JSONObject().put("targets", targets(it.targets)).put("used", it.usedAt).put("pinned", it.pinned).put("pinnedAt", it.pinnedAt ?: JSONObject.NULL) }))
        .put("wakes", JSONArray(s.wakes.map { JSONObject().put("ruleId", it.ruleId).put("start", it.occurrenceStart).put("wakesAt", it.wakesAt) }))
        .put("selection",s.selection?.let(::targets) ?: JSONObject.NULL).toString()
    fun decode(text: String): State {
        val j = JSONObject(text); val schema = j.getInt("schema"); require(schema in 3..4)
        return State(j.getJSONArray("rules").mapObjects {
            val savedSchedule=it.getJSONObject("schedule")
            val decoded=schedule(savedSchedule)
            // Older files did not store the creation mode. Recognize only shipped immediate titles;
            // ambiguous custom titles stay visible rather than hiding a possibly scheduled lock.
            val migrated=if(decoded is LockSchedule.Single && !savedSchedule.has("immediate"))
                decoded.copy(immediate=it.getString("title") in setOf("今すぐ","Now")) else decoded
            Rule(it.getString("id"), it.getString("title"), targets(it.getJSONObject("targets")),
                migrated, it.getBoolean("enabled"))
        }, Planner.trimRecent(j.getJSONArray("recent").mapObjects { Recent(targets(it.getJSONObject("targets")), it.getLong("used"), it.getBoolean("pinned"), if(it.isNull("pinnedAt")) null else it.getLong("pinnedAt")) }),
            if (schema == 3) emptyList() else j.getJSONArray("wakes").mapObjects { WakeRequest(it.getString("ruleId"), it.getLong("start"), it.getLong("wakesAt")) },
            if(!j.has("selection") || j.isNull("selection")) null else targets(j.getJSONObject("selection")))
    }
}
