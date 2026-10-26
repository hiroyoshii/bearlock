package com.hiyozoo.bearlock

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.widget.LinearLayout

class SupportScreen(private val a: MainActivity) {
    fun show(parent: LinearLayout) {
        val u=a.ui
        val intro=u.card()
        u.add(intro,u.label(a.t("Bear Lockは無料で使えます。良ければ開発を応援してください。","Bear Lock is free to use. Please consider supporting its development."),16f),14)
        u.add(intro,u.label(a.t("開発の応援については、公式サイトをご覧ください。応援の有無で機能は変わりません。","Visit our website to learn about supporting development. Bear Lock works the same either way."),15f,muted=true),0)
        u.add(parent,intro,20)
        u.add(parent,u.button(a.t("公式サイトを開く","Open website"),true) {
            val url="https://bearlock.hiyozoo.com/"+a.t("","en/")+"support/development/"
            try {
                a.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse(url)))
            } catch (_: ActivityNotFoundException) {
                a.error("browser_unavailable")
            }
        },12)
        u.add(parent,u.label(a.t("ブラウザで開きます。アプリ内での購入はありません。","Opens in your browser. There are no in-app purchases."),14f,muted=true),0)
    }
}
