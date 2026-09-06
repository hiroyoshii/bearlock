package com.hiyozoo.bearlock.lab

import android.app.Activity
import android.os.Bundle
import org.json.JSONObject

/** Debug-only ADB harness. Restricted to the bundled probe and the same bounded, immutable window. */
class ExperimentActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val method = Method.valueOf(intent.getStringExtra("method") ?: "USAGE")
            check(Permissions.missing(this, method).isEmpty()) { "Required permissions are missing" }
            val store = LabStore(this)
            store.save(LockWindow.create(method, "com.hiyozoo.bearlock.probe", System.currentTimeMillis(),
                intent.getIntExtra("delay", 0), intent.getIntExtra("duration", 10), store.read()))
            Schedules.resume(this)
        } catch (e: RuntimeException) {
            LabStore(this).event("experiment_rejected", JSONObject().put("error", e.message))
        }
        finish()
    }
}
