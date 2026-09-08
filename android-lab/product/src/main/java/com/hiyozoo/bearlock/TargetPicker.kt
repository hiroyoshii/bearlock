package com.hiyozoo.bearlock

import android.view.Gravity
import android.widget.*
import android.text.InputType

class TargetPicker(private val a: MainActivity) {
    companion object { private val loader = java.util.concurrent.Executors.newSingleThreadExecutor() }
    private val u get()=a.ui
    private fun t(ja: String,en: String)=a.t(ja,en)
    fun show(parent: LinearLayout) {

        // Selection count is shown once in the fixed footer.
        fun update() {
            a.pickerCount?.text=t("${a.draft.count}件を選択中","${a.draft.count} selected")
            a.pickerSave?.apply { isEnabled=!a.draft.empty; alpha=if(isEnabled) 1f else .5f }
        }
        val tabIds=List(3) { android.view.View.generateViewId() }
        val tabs=RadioGroup(a).apply { orientation=if(u.compact) RadioGroup.VERTICAL else RadioGroup.HORIZONTAL }
        for((i,name) in listOf(t("アプリ","Apps"),t("Web","Web"),t("カテゴリ","Categories")).withIndex()) tabs.addView(RadioButton(a).apply { id=tabIds[i]; text=name; setTextColor(Palette.navy) },if(u.compact) RadioGroup.LayoutParams(-1,-2) else RadioGroup.LayoutParams(0,-2,1f))
        u.add(parent,tabs,16)
        val content=u.column(); u.add(parent,content)
        var entries: List<AppEntry>? = null
        var loadFailed = false
        var query = ""
        var generation = 0
        fun loading(): Boolean {
            if(entries != null) return false
            u.add(content,u.label(if(loadFailed) t("アプリを取得できませんでした。画面を開き直してください。","Could not load apps. Please reopen this screen.") else t("アプリを読み込み中…","Loading apps…"),15f,muted=true))
            return true
        }
        fun apps() {
            ++generation
            content.removeAllViews()
            val search=u.input(t("アプリを検索","Search apps")).apply { isSingleLine=true; isEnabled=entries != null }
            u.add(content,search,12)
            val list=u.column().apply { background=u.bg(Palette.white) }; u.add(content,list)
            if(loading()) return
            val available=entries.orEmpty()
            fun showApps(query: String) {
                list.removeAllViews()
                val searchGeneration = ++generation
                val matches=available.filter { it.name.contains(query,true) || it.pkg.contains(query,true) }
                var offset=0
                fun appendBatch() {
                    if(generation != searchGeneration || a.isDestroyed || !parent.isAttachedToWindow) return
                    val end=minOf(offset+12,matches.size)
                    for(app in matches.subList(offset,end)) {
                        val row=u.row().apply { setPadding(u.dp(8),u.dp(2),u.dp(8),u.dp(2)); background=u.bg(Palette.white,12) }
                        row.addView(ImageView(a).apply { setImageDrawable(app.icon); importantForAccessibility=android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO },LinearLayout.LayoutParams(u.dp(36),u.dp(36)).apply { rightMargin=u.dp(12) })
                        val check=CheckBox(a).apply { text=app.name; textSize=16f; setTextColor(Palette.navy); minHeight=u.dp(52); isChecked=app.pkg in a.draft.apps
                            setOnCheckedChangeListener { _,on -> a.draft=a.draft.copy(apps=if(on) a.draft.apps+app.pkg else a.draft.apps-app.pkg); update() }
                        }
                        row.addView(check,LinearLayout.LayoutParams(0,-2,1f)); u.add(list,row,0)
                    }
                    offset=end
                    if(offset<matches.size) list.postOnAnimation { appendBatch() }
                }
                list.post { appendBatch() }
                if(matches.isEmpty()) u.add(list,u.label(t("該当するアプリがありません。","No matching apps."),15f,muted=true))
            }
            search.setText(query); showApps(query); search.onEdit { query=it; showApps(it) }
            val missing=a.draft.apps-available.map { it.pkg }.toSet()
            for(pkg in missing) u.add(content,u.button(t("未インストールの対象を外す: ","Remove unavailable target: ")+pkg) { a.draft=a.draft.copy(apps=a.draft.apps-pkg); update(); apps() })
            u.add(content,u.label(t("ホーム・設定・電話など、端末の操作に必要なアプリは除外しています。","Home, Settings and dialer apps are excluded."),13f,muted=true),0)
        }
        fun web() {
            ++generation
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
            ++generation
            content.removeAllViews()
            if(loading()) return
            val available=entries.orEmpty()
            u.add(content,u.label(t("端末が分類したアプリに適用します。未分類のアプリは「アプリ」から個別に追加してください。新しく入れた同カテゴリのアプリにも適用します。","Uses device app categories, including newly installed apps. Add unclassified apps individually from Apps."),14f,muted=true),16)
            for(id in 0..7) {
                val apps=available.filter { it.category==id }
                val c=u.card()
                u.add(c,CheckBox(a).apply { text=a.catalog.categoryName(id)+" (${apps.size})"; textSize=17f; setTextColor(Palette.navy); isChecked=id in a.draft.categories
                    setOnCheckedChangeListener { _,on -> a.draft=a.draft.copy(categories=if(on) a.draft.categories+id else a.draft.categories-id); update() }
                },4)
                u.add(c,u.label(apps.joinToString(", ") { it.name }.ifEmpty { t("この端末では該当なし","No matching apps on this device") },13f,muted=true),0); u.add(content,c,12)
            }
        }
        tabs.setOnCheckedChangeListener { _,id -> when(id) { tabIds[0]->apps(); tabIds[1]->web(); tabIds[2]->categories() } }
        tabs.check(tabIds[0])
        // PackageManager and icon decoding must never block navigation or touch handling.
        val catalog=Catalog(a.applicationContext)
        loader.execute {
            val result=runCatching { catalog.apps() }
            a.runOnUiThread {
                if(!a.isDestroyed && parent.isAttachedToWindow) {
                    entries=result.getOrNull(); loadFailed=result.isFailure
                    when(tabs.checkedRadioButtonId) { tabIds[0]->apps(); tabIds[2]->categories() }
                }
            }
        }
    }
}
