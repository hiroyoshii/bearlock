package com.hiyozoo.bearlock

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/** Debug APK only. Adds bounded probe / example.com experiments using the production planner. No reset/unlock. */
class QAHarnessActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent.getStringExtra("language")?.takeIf { it in listOf("ja","en") }?.let {
            getSharedPreferences("appearance",0).edit().putString("language",it).commit()
            configureLanguage(this)
        }
        val store=Store(this)
        try {
            val now=System.currentTimeMillis()
            val action=intent.getStringExtra("action")
            if(action=="lock" || action=="reserve" || action=="webLock") {
                check(GuardService.instance!=null && (action != "reserve" || Scheduling.permitted(this)))
                val delay=if(action=="reserve") 120 else 0
                val start=now+delay*1000
                val r=Rule(title=if(action=="lock") "集中時間" else "読書の時間",targets=if(action=="webLock") Targets(domains=setOf("example.com")) else Targets(apps=setOf("com.hiyozoo.bearlock.probe")),schedule=LockSchedule.Single(start,start+60_000))
                store.change { Planner.save(it,r,now) }; store.event("qa_created:$start:${r.single!!.end}"); Scheduling.sync(this)
            }
            startActivity(Intent(this,MainActivity::class.java).putExtra("qaPage",intent.getStringExtra("page") ?: "home").putExtra("qaDraft",intent.getBooleanExtra("draft",false)))
        } catch(e: Exception) { store.event("qa_rejected:${e.message}") }
        finish()
    }
}
