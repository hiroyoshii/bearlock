package com.hiyozoo.bearlock

import android.view.Gravity
import android.widget.*
import android.text.InputType

class TargetPicker(private val a: MainActivity) {
    private val u get()=a.ui
    private fun t(ja: String,en: String)=a.t(ja,en)
    fun show(parent: LinearLayout) {

        val count=u.label(t("${a.draft.count} 件を選択中","${a.draft.count} selected"),17f,true)
        u.add(parent,count,12)
        fun update() {
            count.text=t("${a.draft.count} 件を選択中","${a.draft.count} selected")
            a.pickerCount?.text=t("${a.draft.count}件を選択中","${a.draft.count} selected")
            a.pickerSave?.apply { isEnabled=!a.draft.empty; alpha=if(isEnabled) 1f else .5f }
        }
        val tabIds=List(3) { android.view.View.generateViewId() }
        val tabs=RadioGroup(a).apply { orientation=RadioGroup.HORIZONTAL }
        for((i,name) in listOf(t("アプリ","Apps"),t("Web","Web"),t("カテゴリ","Categories")).withIndex()) tabs.addView(RadioButton(a).apply { id=tabIds[i]; text=name; setTextColor(Palette.navy) },RadioGroup.LayoutParams(0,-2,1f))
        u.add(parent,tabs,16)
        val content=u.column(); u.add(parent,content)
        fun apps() {
            content.removeAllViews()
            val search=u.input(t("アプリを検索","Search apps")).apply { isSingleLine=true }
            u.add(content,search,12)
            val list=u.column(); u.add(content,list)
            val entries=a.catalog.apps()
            fun showApps(query: String) {
                list.removeAllViews()
                for(app in entries.filter { it.name.contains(query,true) || it.pkg.contains(query,true) }) {
                    val row=u.row().apply { setPadding(u.dp(8),u.dp(6),u.dp(8),u.dp(6)); background=u.bg(Palette.white,12) }
                    row.addView(ImageView(a).apply { setImageDrawable(app.icon); importantForAccessibility=android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO },LinearLayout.LayoutParams(u.dp(36),u.dp(36)).apply { rightMargin=u.dp(12) })
                    val check=CheckBox(a).apply { text=app.name; textSize=16f; setTextColor(Palette.navy); minHeight=u.dp(52); isChecked=app.pkg in a.draft.apps
                        setOnCheckedChangeListener { _,on -> a.draft=a.draft.copy(apps=if(on) a.draft.apps+app.pkg else a.draft.apps-app.pkg); update() }
                    }
                    row.addView(check,LinearLayout.LayoutParams(0,-2,1f)); u.add(list,row,8)
                }
                if(list.childCount==0) u.add(list,u.label(t("該当するアプリがありません。","No matching apps."),15f,muted=true))
            }
            showApps(""); search.onEdit(::showApps)
            val missing=a.draft.apps-entries.map { it.pkg }.toSet()
            for(pkg in missing) u.add(content,u.button(t("未インストールの対象を外す: ","Remove unavailable target: ")+pkg) { a.draft=a.draft.copy(apps=a.draft.apps-pkg); update(); apps() })
            u.add(content,u.label(t("ホーム・設定・電話など、端末の操作に必要なアプリは除外しています。","Home, Settings and dialer apps are excluded."),13f,muted=true),0)
        }
        fun web() {
            content.removeAllViews()
            u.add(content,u.label(t("ドメイン単位で指定します。サブドメインも含みます。","Enter domains. Subdomains are included."),15f),12)
            val input=u.input("example.com").apply { inputType=InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI; isSingleLine=true }
            u.add(content,input,8)
            u.add(content,u.button(t("Webサイトを追加","Add website")) {
                val domain=Domain.normalize(input.text.toString())
                if(domain==null) a.error("invalid_domain") else { a.draft=a.draft.copy(domains=a.draft.domains+domain); update(); web() }
            },16)
            for(domain in a.draft.domains) u.add(content,u.button("×  $domain") { a.draft=a.draft.copy(domains=a.draft.domains-domain); update(); web() },8)
            u.add(content,u.label(t("Chrome・Firefoxの通常タブ向け。アドレス欄が読めない画面、シークレット、他のブラウザは保証対象外です。ブラウザ版ごとの動作検証中です。","Adapters target regular Chrome and Firefox tabs; version testing is ongoing. Unreadable address bars, private tabs and other browsers are not guaranteed."),14f,muted=true),0)
        }
        fun categories() {
            content.removeAllViews(); val entries=a.catalog.apps()
            u.add(content,u.label(t("端末が分類したアプリに適用します。未分類のアプリは「アプリ」から個別に追加してください。新しく入れた同カテゴリのアプリにも適用します。","Uses device app categories, including newly installed apps. Add unclassified apps individually from Apps."),14f,muted=true),16)
            for(id in 0..7) {
                val apps=entries.filter { it.category==id }
                val c=u.card()
                u.add(c,CheckBox(a).apply { text=a.catalog.categoryName(id)+" (${apps.size})"; textSize=17f; setTextColor(Palette.navy); isChecked=id in a.draft.categories
                    setOnCheckedChangeListener { _,on -> a.draft=a.draft.copy(categories=if(on) a.draft.categories+id else a.draft.categories-id); update() }
                },4)
                u.add(c,u.label(apps.joinToString(", ") { it.name }.ifEmpty { t("この端末では該当なし","No matching apps on this device") },13f,muted=true),0); u.add(content,c,12)
            }
        }
        tabs.setOnCheckedChangeListener { _,id -> when(id) { tabIds[0]->apps(); tabIds[1]->web(); tabIds[2]->categories() } }
        tabs.check(tabIds[0])
    }
}
