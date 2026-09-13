package com.hiyozoo.bearlock

import android.view.View
import android.view.ViewGroup
import android.widget.*

/** Uses the platform's expandable list for the same category-to-app flow as iOS. */
internal class AppCategoryAdapter(
    private val a: MainActivity,
    entries: List<AppEntry>,
    private val onSelectionChanged: () -> Unit
) : BaseExpandableListAdapter() {
    private val ids=(0..7).toList()+listOf(-1)
    private val groups=ids.map { id -> entries.filter { if(id==-1) it.category !in 0..7 else it.category==id } }
    private val children=groups.map { AppPickerAdapter(a,it,onSelectionChanged) }
    override fun getGroupCount()=ids.size
    override fun getChildrenCount(groupPosition: Int)=groups[groupPosition].size
    override fun getGroup(groupPosition: Int)=ids[groupPosition]
    override fun getChild(groupPosition: Int,childPosition: Int)=groups[groupPosition][childPosition]
    override fun getGroupId(groupPosition: Int)=groupPosition.toLong()
    override fun getChildId(groupPosition: Int,childPosition: Int)=childPosition.toLong()
    override fun hasStableIds()=false
    override fun isChildSelectable(groupPosition: Int,childPosition: Int)=true
    override fun getGroupView(position: Int,expanded: Boolean,convertView: View?,parent: ViewGroup): View {
        val u=a.ui
        val row=convertView as? LinearLayout ?: u.row().apply {
            setPadding(u.dp(8),u.dp(4),u.dp(8),u.dp(4))
            background=u.touchBackground(Palette.white)
            addView(CheckBox(a).apply { minHeight=u.dp(48) })
            addView(u.label("",16f,true),LinearLayout.LayoutParams(0,-2,1f))
            addView(u.label("",18f).apply { importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_NO })
        }
        row.setOnClickListener {
            (parent as? ExpandableListView)?.let { list ->
                if(list.isGroupExpanded(position)) list.collapseGroup(position) else list.expandGroup(position)
            }
        }
        val id=ids[position]
        val check=row.getChildAt(0) as CheckBox
        check.setOnCheckedChangeListener(null)
        check.visibility=if(id<0) View.INVISIBLE else View.VISIBLE
        check.contentDescription=a.t("カテゴリ全体を選択: ","Select entire category: ")+a.catalog.categoryName(id)
        check.isChecked=id in a.editor.targets.categories
        check.setOnCheckedChangeListener { _,on ->
            a.editor.targets=a.editor.targets.copy(categories=if(on) a.editor.targets.categories+id else a.editor.targets.categories-id)
            onSelectionChanged(); notifyDataSetChanged()
        }
        (row.getChildAt(1) as TextView).text="${a.catalog.categoryName(id)} (${groups[position].size})"
        (row.getChildAt(2) as TextView).text=if(expanded) "⌄" else "›"
        return row
    }
    override fun getChildView(groupPosition: Int,childPosition: Int,isLast: Boolean,convertView: View?,parent: ViewGroup): View =
        children[groupPosition].getView(childPosition,convertView,parent).apply {
            setPadding(a.ui.dp(24),a.ui.dp(2),a.ui.dp(8),a.ui.dp(2))
        }
}
