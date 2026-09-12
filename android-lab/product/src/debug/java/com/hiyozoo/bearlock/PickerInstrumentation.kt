package com.hiyozoo.bearlock

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.Bundle
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.ExpandableListView

/** Run with adb shell am instrument -w com.hiyozoo.bearlock/.PickerInstrumentation. */
class PickerInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        var activity: MainActivity?=null
        try {
            activity=startActivitySync(Intent(targetContext,MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK).putExtra("qaPage","targets")) as MainActivity
            val a=activity
            waitForIdleSync()
            lateinit var list: ListView
            lateinit var adapter: AppPickerAdapter
            val entries=(0 until 1000).map { AppEntry("fixture.app.$it","App %04d".format(it),it%8,"fixture-$it") }
            runOnMainSync {
                a.draft=Targets()
                adapter=AppPickerAdapter(a,entries) {}
                list=ListView(a).apply { this.adapter=adapter }
                a.setContentView(list)
            }
            waitForIdleSync()
            var initialRows=0
            runOnMainSync {
                initialRows=list.childCount
                check(initialRows in 1..40) { "List inflated $initialRows rows for 1000 apps" }
                val row=adapter.getView(0,null,list) as LinearLayout
                (row.getChildAt(1) as CheckBox).performClick()
                check(a.draft.apps==setOf("fixture.app.0"))
                val recycled=adapter.getView(1,row,list) as LinearLayout
                check(recycled===row)
                check(!(recycled.getChildAt(1) as CheckBox).isChecked) { "Recycled checkbox leaked" }
                check(a.draft.apps==setOf("fixture.app.0")) { "Rebinding changed selection" }
                adapter.filter("App 0999")
                check(adapter.count==1 && adapter.getItem(0).pkg=="fixture.app.999")
                adapter.filter("no-such-app")
                check(adapter.count==0)
                adapter.filter("")
                check(a.draft.apps==setOf("fixture.app.0"))
                a.draft=a.draft.copy(categories=setOf(1))
                val inherited=adapter.getView(1,recycled,list) as LinearLayout
                check((inherited.getChildAt(1) as CheckBox).isChecked)
                check(!(inherited.getChildAt(1) as CheckBox).isEnabled)
                a.draft=a.draft.copy(categories=emptySet())
                adapter.getView(1,inherited,list)
                check(!(inherited.getChildAt(1) as CheckBox).isChecked)
                check((inherited.getChildAt(1) as CheckBox).isEnabled)
                list.setSelection(999)
            }
            waitForIdleSync()
            runOnMainSync {
                check(list.lastVisiblePosition==999)
                check(list.childCount in 1..40)
                val groups=AppCategoryAdapter(a,entries) {}
                check(groups.getChildrenCount(0)==125)
                val group=groups.getGroupView(0,false,null,list) as LinearLayout
                (group.getChildAt(0) as CheckBox).performClick()
                check(0 in a.draft.categories)
                (group.getChildAt(0) as CheckBox).performClick()
                check(0 !in a.draft.categories)
                a.draft=Targets(apps=setOf("fixture.app.0")); a.page="home"
                a.pickTargets()
                a.draft=Targets(apps=setOf("fixture.app.1")); a.goBack()
                check(a.draft.apps==setOf("fixture.app.0")) { "Cancel did not restore selection" }
            }
            lateinit var categories: ExpandableListView
            runOnMainSync {
                categories=ExpandableListView(a).apply { setAdapter(AppCategoryAdapter(a,entries) {}) }
                a.setContentView(categories)
            }
            waitForIdleSync()
            runOnMainSync { categories.getChildAt(0).performClick() }
            waitForIdleSync()
            runOnMainSync {
                check(categories.isGroupExpanded(0)) { "Category row did not expand" }
                check(categories.childCount in 1..40) { "Expanded group inflated every child" }
                categories.getChildAt(0).performClick()
                check(!categories.isGroupExpanded(0)) { "Category row did not collapse" }
            }
            finish(Activity.RESULT_OK,Bundle().apply {
                putString("stream","PASS: 1000 apps, $initialRows visible rows; recycling, search, category selection, scroll and cancel\n")
            })
        } catch(t: Throwable) {
            finish(Activity.RESULT_CANCELED,Bundle().apply { putString("stream",android.util.Log.getStackTraceString(t)) })
        } finally { activity?.let { runOnMainSync { it.finish() } } }
    }
}
