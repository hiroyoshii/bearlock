package com.hiyozoo.bearlock

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.Bundle

/** Actual Activity recreation while a picker/permission flow holds an unsaved draft. */
class EditorInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        var activity: MainActivity? = null
        try {
            val original = Targets(apps=setOf("fixture.original"))
            val changed = Targets(apps=setOf("fixture.changed"))
            val start = System.currentTimeMillis()+30*Planner.DAY
            RecoveryTestActivity.failMonitoring=false
            activity=startActivitySync(Intent(targetContext,RecoveryTestActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK).putExtra("qaPage","home")) as MainActivity
            waitForIdleSync()
            val first=activity
            runOnMainSync {
                val icons=org.json.JSONObject(targetContext.assets.open("material-icons/source.json")
                    .bufferedReader().use { it.readText() }).getJSONArray("icons")
                for (index in 0 until icons.length()) {
                    val alias=icons.getJSONObject(index).getString("alias")
                    val drawable=first.ui.icon(alias,Palette.navy)
                    check(drawable is android.graphics.drawable.VectorDrawable) { alias }
                    val bitmap=android.graphics.Bitmap.createBitmap(48,48,android.graphics.Bitmap.Config.ARGB_8888)
                    drawable.setBounds(0,0,48,48)
                    drawable.draw(android.graphics.Canvas(bitmap))
                    val pixels=IntArray(48*48)
                    bitmap.getPixels(pixels,0,48,0,0,48,48)
                    check(pixels.any { android.graphics.Color.alpha(it)>0 }) { "Empty icon: $alias" }
                    check(pixels.filter { android.graphics.Color.alpha(it)==255 }.all { it==Palette.navy }) { "Wrong tint: $alias" }
                    bitmap.recycle()
                }
                first.store.change { State(selection=original) }
                first.editor=EditorDraft(targets=original,timing=DraftTiming.Fixed(start,90))
                first.navigate(Route.Settings)
                first.goBack()
                check(first.editor.at==start && first.editor.duration==90) { "Settings discarded the draft" }
                first.pickTargets()
                first.editor.targets=changed
                first.requestPermissions()
            }
            val monitor=addMonitor(RecoveryTestActivity::class.java.name,null,false)
            runOnMainSync { first.recreate() }
            activity=waitForMonitorWithTimeout(monitor,10_000) as? MainActivity ?: error("Activity did not recreate")
            removeMonitor(monitor)
            waitForIdleSync()
            val restored=activity
            runOnMainSync {
                check(restored.route is Route.Permissions)
                check(restored.editor.at==start && restored.editor.duration==90)
                check(restored.editor.targets==changed)
                check(restored.store.read().selection==original) { "Recreation saved an unconfirmed draft" }
                restored.goBack()
                check(restored.route is Route.Picker && restored.editor.targets==changed)
                restored.goBack()
                check(restored.route==Route.Home && restored.editor.targets==original)
                check(restored.editor.at==start && restored.editor.duration==90)
                val now=System.currentTimeMillis()
                val rule=Composer(restored).make(now)
                check(rule.nextOccurrence(now)?.start==start)
                check(Planner.save(State(),rule,now).rules.single()==rule)
                restored.editor=EditorDraft(targets=original)
                restored.navigate(Route.Home)
                val root=restored.findViewById<android.view.View>(android.R.id.content)
                check(root.findViewWithTag<android.widget.Button>("composer-mode-0").isSelected)
                fun checkSegments(selected: Int) {
                    val group=root.findViewWithTag<com.google.android.material.button.MaterialButtonToggleGroup>("composer-mode-picker")
                    check(group.isSingleSelection && group.isSelectionRequired)
                    check(group.checkedButtonIds.size==1)
                    check(root.findViewWithTag<com.google.android.material.button.MaterialButton>("composer-mode-$selected").isChecked)
                }
                checkSegments(0)
                val preset=root.findViewWithTag<android.widget.Button>("duration-preset-120")
                check(preset.isSelected && preset.currentTextColor==Palette.white)
                root.findViewWithTag<android.widget.Button>("duration-preset-30").performClick()
                check(restored.editor.duration==30)
                check(root.findViewWithTag<android.widget.Button>("duration-preset-30").currentTextColor==Palette.white)
                check(!preset.isSelected && preset.currentTextColor==Palette.navy)
                root.findViewWithTag<android.widget.Button>("composer-mode-2").performClick()
                checkSegments(2)
                check(root.findViewWithTag<android.widget.Button>("start-date")!=null)
                check(root.findViewWithTag<android.widget.Button>("start-time")!=null)
                fun inputStyle(tag: String): List<Any> {
                    val button=root.findViewWithTag<android.widget.Button>(tag)
                    val shape=(button.background as android.graphics.drawable.RippleDrawable).getDrawable(0) as android.graphics.drawable.GradientDrawable
                    return listOf(button.textSize,button.minHeight,button.minWidth,button.paddingLeft,button.paddingTop,button.paddingRight,button.paddingBottom,shape.cornerRadius)
                }
                val style=inputStyle("start-time")
                check(inputStyle("start-date")==style)
                val draft=restored.editor.at
                root.findViewWithTag<android.widget.Button>("composer-mode-3").performClick()
                checkSegments(3)
                check(inputStyle("start-time")==style && inputStyle("end-time")==style)
                root.findViewWithTag<android.widget.Button>("composer-mode-2").performClick()
                check(restored.editor.at==draft && restored.editor.duration==30)
                restored.navigate(Route.Settings)
                restored.navigate(Route.Diagnostics)
                restored.goBack()
                check(restored.route==Route.Settings && restored.editor.at==draft)
                restored.goBack()
                check(restored.route==Route.Home && restored.editor.at==draft)
                val fixed=Composer(restored).make(System.currentTimeMillis())
                restored.store.change { it.copy(rules=listOf(fixed)) }
                restored.edit(fixed)
                check(restored.route==Route.Editor && inputStyle("start-date")==style && inputStyle("start-time")==style)
                restored.goBack()
                restored.editor=EditorDraft(targets=original,timing=DraftTiming.Weekly())
                val weekly=Composer(restored).make(System.currentTimeMillis())
                restored.store.change { it.copy(rules=listOf(weekly)) }
                restored.edit(weekly)
                check(restored.route==Route.Editor && inputStyle("start-time")==style && inputStyle("end-time")==style)
            }
            finish(Activity.RESULT_OK,Bundle().apply {
                putString("stream","PASS: editor recreation; nested permission/picker cancellation, 30-day reservation, input retained; library segments single selection, common date/time shape, selected presets, split date/time, diagnostics return\n")
            })
        } catch(t: Throwable) {
            finish(Activity.RESULT_CANCELED,Bundle().apply { putString("stream",android.util.Log.getStackTraceString(t)) })
        } finally {
            activity?.let { a -> runOnMainSync { a.finish() }; a.filesDir.deleteRecursively() }
            Scheduling.sync(targetContext)
        }
    }
}
