package com.hiyozoo.bearlock

import android.view.Gravity
import android.widget.*
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher

private fun EditText.onEdit(action: (String)->Unit) { addTextChangedListener(object: TextWatcher {
    override fun beforeTextChanged(s: CharSequence?,start: Int,count: Int,after: Int) {}
    override fun onTextChanged(s: CharSequence?,start: Int,before: Int,count: Int) { action(s.toString()) }
    override fun afterTextChanged(s: Editable?) {}
}) }

class TargetPicker(private val a: MainActivity) {
    companion object { private val loader = java.util.concurrent.Executors.newSingleThreadExecutor() }
    private val u get()=a.ui
    private fun t(ja: String,en: String)=a.t(ja,en)
    fun show(parent: LinearLayout) {
        val openedAt=android.os.SystemClock.elapsedRealtime()

        // Selection count is shown once in the fixed footer.
        fun update() {
            a.pickerCount?.text=if(a.editor.targets.empty) t("ロック対象が選択されていません。","No targets are selected.") else t("${a.editor.targets.count}件の対象","${a.editor.targets.count} targets")
            a.pickerSave?.apply { isEnabled=!a.editor.targets.empty; alpha=if(isEnabled) 1f else .5f }
        }
        val tabIds=List(3) { android.view.View.generateViewId() }
        val tabs=RadioGroup(a).apply { orientation=if(u.compact) RadioGroup.VERTICAL else RadioGroup.HORIZONTAL }
        for((i,name) in listOf(t("対象アプリ","Apps"),t("Webサイト","Websites"),t("カテゴリ","Categories")).withIndex()) tabs.addView(RadioButton(a).apply { id=tabIds[i]; text=name; setTextColor(Palette.navy) },if(u.compact) RadioGroup.LayoutParams(-1,-2) else RadioGroup.LayoutParams(0,-2,1f))
        u.add(parent,tabs,16)
        val viewport=FrameLayout(a)
        parent.addView(viewport,LinearLayout.LayoutParams(-1,0,1f))
        val content=u.column()
        fun resetContent(scrollable: Boolean) {
            (content.parent as? android.view.ViewGroup)?.removeView(content)
            content.removeAllViews(); viewport.removeAllViews()
            if(scrollable) {
                val scroll=ScrollView(a).apply { isFillViewport=true }
                scroll.addView(content); viewport.addView(scroll,FrameLayout.LayoutParams(-1,-1))
            } else viewport.addView(content,FrameLayout.LayoutParams(-1,-1))
        }
        var entries: List<AppEntry>? = null
        var loadFailed = false
        var query = ""
        fun loading(): Boolean {
            if(entries != null) return false
            u.add(content,u.label(if(loadFailed) t("アプリを取得できませんでした。画面を開き直してください。","Could not load apps. Please reopen this screen.") else t("アプリを読み込み中…","Loading apps…"),15f,muted=true))
            return true
        }
        fun apps() {
            resetContent(false)
            val search=u.input(t("アプリを検索","Search apps")).apply { isSingleLine=true; isEnabled=entries != null }
            u.add(content,search,12)
            if(loading()) return
            val available=entries.orEmpty()
            val list=ListView(a).apply {
                divider=android.graphics.drawable.ColorDrawable(Palette.line); dividerHeight=u.dp(1)
                background=u.bg(Palette.white); clipToOutline=true
            }
            val empty=u.label(t("該当するアプリがありません。","No matching apps."),15f,muted=true)
            val container=FrameLayout(a)
            container.addView(list,FrameLayout.LayoutParams(-1,-1))
            container.addView(empty,FrameLayout.LayoutParams(-1,-2))
            content.addView(container,LinearLayout.LayoutParams(-1,0,1f))
            val adapter=AppPickerAdapter(a,available,::update)
            val notes=u.column()
            u.add(notes,u.label(t("ホーム・設定・電話など、端末の操作に必要なアプリは除外しています。","Home, Settings and dialer apps are excluded."),13f,muted=true),8)
            val missing=a.editor.targets.apps-available.map { it.pkg }.toSet()
            for(pkg in missing) u.add(notes,u.button(t("未インストールの対象を外す: ","Remove unavailable target: ")+pkg) {
                a.editor.targets=a.editor.targets.copy(apps=a.editor.targets.apps-pkg); update(); apps()
            })
            list.addFooterView(notes,null,false)
            list.adapter=adapter
            fun filter(value: String) {
                adapter.filter(value)
                empty.visibility=if(adapter.count==0) android.view.View.VISIBLE else android.view.View.GONE
                list.visibility=if(adapter.count==0) android.view.View.GONE else android.view.View.VISIBLE
                list.setSelection(0)
            }
            search.setText(query); filter(query)
            search.onEdit { query=it; filter(it) }
            if(BuildConfig.DEBUG) list.viewTreeObserver.addOnPreDrawListener(object: android.view.ViewTreeObserver.OnPreDrawListener {
                override fun onPreDraw(): Boolean {
                    list.viewTreeObserver.removeOnPreDrawListener(this)
                    android.util.Log.d("BearLockPicker","first_rows_ms=${android.os.SystemClock.elapsedRealtime()-openedAt} apps=${available.size} attached_rows=${list.childCount}")
                    return true
                }
            })
        }
        fun web() {
            resetContent(true)
            u.add(content,u.label(t("ドメイン単位で指定します。サブドメインも含みます。","Enter domains. Subdomains are included."),15f),12)
            val input=u.input("example.com").apply { inputType=InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI; isSingleLine=true }
            u.add(content,input,8)
            u.add(content,u.button(t("Webサイトを追加","Add website")) {
                val domain=Domain.normalize(input.text.toString())
                if(domain==null) a.error("invalid_domain") else { a.editor.targets=a.editor.targets.copy(domains=a.editor.targets.domains+domain); update(); web() }
            },16)
            for(domain in a.editor.targets.domains) u.add(content,u.button(domain) {
                a.editor.targets=a.editor.targets.copy(domains=a.editor.targets.domains-domain); update(); web()
            }.apply {
                contentDescription=t("$domain を削除","Remove $domain")
                setCompoundDrawables(u.icon("close").apply { setBounds(0,0,u.dp(20),u.dp(20)) },null,null,null)
                compoundDrawablePadding=u.dp(8)
            },8)
            u.add(content,u.label(t("ChromeとFirefoxの通常タブに対応しています。シークレットタブ、カスタムタブ、その他のブラウザには対応していません。","Supports regular tabs in Chrome and Firefox. Private tabs, custom tabs, and other browsers are not supported."),14f,muted=true),0)
        }
        fun categories() {
            resetContent(false)
            if(loading()) return
            u.add(content,u.label(t("カテゴリを開いてアプリを選べます。カテゴリ全体を選ぶと、新しく入れた同カテゴリのアプリにも適用します。","Expand a category to choose apps. Selecting a whole category also includes newly installed apps in that category."),14f,muted=true),12)
            val list=ExpandableListView(a).apply {
                setGroupIndicator(null)
                divider=android.graphics.drawable.ColorDrawable(Palette.line); dividerHeight=u.dp(1)
                background=u.bg(Palette.white); clipToOutline=true
            }
            list.setAdapter(AppCategoryAdapter(a,entries.orEmpty(),::update))
            content.addView(list,LinearLayout.LayoutParams(-1,0,1f))
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
