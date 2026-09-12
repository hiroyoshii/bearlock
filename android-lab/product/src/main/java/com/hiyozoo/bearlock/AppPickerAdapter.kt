package com.hiyozoo.bearlock

import android.view.View
import android.view.ViewGroup
import android.widget.*

/** A bounded viewport: Android recycles rows instead of constructing every installed app. */
internal class AppPickerAdapter(
    private val a: MainActivity,
    private val entries: List<AppEntry>,
    private val onSelectionChanged: () -> Unit
) : BaseAdapter() {
    private val u=a.ui
    private var matches=entries
    fun filter(query: String) {
        matches=entries.filter { it.name.contains(query,true) || it.pkg.contains(query,true) }
        notifyDataSetChanged()
    }
    override fun getCount()=matches.size
    override fun getItem(position: Int)=matches[position]
    override fun getItemId(position: Int)=position.toLong()
    override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
        val row=convertView as? LinearLayout ?: u.row().apply {
            setPadding(u.dp(8),u.dp(2),u.dp(8),u.dp(2))
            background=u.touchBackground(Palette.white)
            addView(ImageView(a).apply {
                importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_NO
            },LinearLayout.LayoutParams(u.dp(36),u.dp(36)).apply { rightMargin=u.dp(12) })
            addView(CheckBox(a).apply {
                textSize=16f; setTextColor(Palette.navy); minHeight=u.dp(52)
            },LinearLayout.LayoutParams(0,-2,1f))
        }
        val app=getItem(position)
        val check=row.getChildAt(1) as CheckBox
        // Rebinding must not turn a recycled row's previous selection into a user action.
        check.setOnCheckedChangeListener(null)
        check.text=app.name
        check.isChecked=app.pkg in a.draft.apps || app.category in a.draft.categories
        check.isEnabled=app.category !in a.draft.categories
        check.setOnCheckedChangeListener { _,on ->
            a.draft=a.draft.copy(apps=if(on) a.draft.apps+app.pkg else a.draft.apps-app.pkg)
            onSelectionChanged()
        }
        row.setOnClickListener { if(check.isEnabled) check.toggle() }
        AppIcons.bind(row.getChildAt(0) as ImageView,app)
        return row
    }
}
