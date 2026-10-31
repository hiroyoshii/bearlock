package com.hiyozoo.bearlock

import android.os.Build
import android.view.Gravity
import android.widget.LinearLayout
import org.json.JSONArray
import org.json.JSONObject

/** All license text is bundled; reading it never requires a browser or network. */
class LicensesScreen(private val a: MainActivity) {
    private val u get() = a.ui
    private fun read(path: String) = a.assets.open(path).bufferedReader().use { it.readText() }

    fun show(parent: LinearLayout, entry: Int?) {
        val libraries = JSONArray(read("open-source/libraries.json"))
        if (entry == null) {
            u.add(parent,u.label(a.t(
                "このアプリで使用しているライブラリと素材の著作権・ライセンス情報です。",
                "Copyright and license information for the libraries and artwork used in this app."
            ),16f),24)
            val list = u.section(parent)
            for (index in 0 until libraries.length()) {
                if (index > 0) u.divider(list)
                u.add(list,u.textButton(libraries.getJSONObject(index).getString("name")) {
                    a.navigate(Route.Licenses(index))
                }.apply {
                    tag="license-entry-$index"
                    gravity=Gravity.START or Gravity.CENTER_VERTICAL
                    setTextColor(Palette.textPrimary)
                    compoundDrawablePadding=u.dp(12)
                    setCompoundDrawables(null,null,u.icon("right",Palette.secondary).apply {
                        setBounds(0,0,u.dp(16),u.dp(16))
                    },null)
                },0)
            }
            return
        }
        val library = libraries.getJSONObject(entry)
        u.add(parent,u.label(library.getString("name"),22f,true).apply {
            if (Build.VERSION.SDK_INT >= 28) isAccessibilityHeading=true
        },16)
        val text = buildString {
            appendLine(library.getString("attribution"))
            appendLine()
            if (library.has("source")) {
                val source=JSONObject(read(library.getString("source")))
                appendLine(source.getString("repository"))
                appendLine(source.getString("revision"))
                appendLine(source.getString("note"))
                appendLine()
                append(read(source.getString("licenseFile")))
            } else {
                appendLine(library.getString("url"))
                val artifacts=library.getJSONArray("artifacts")
                for (index in 0 until artifacts.length()) appendLine(artifacts.getString(index))
                val texts=library.getJSONArray("texts")
                for (index in 0 until texts.length()) {
                    appendLine()
                    appendLine(read(texts.getString(index)))
                }
            }
        }
        u.add(parent,u.label(text,16f).apply {
            tag="license-text"
            setTextColor(Palette.textPrimary)
            setTextIsSelectable(true)
        },0)
    }
}
