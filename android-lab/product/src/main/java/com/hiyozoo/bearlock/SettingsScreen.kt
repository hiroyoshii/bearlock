package com.hiyozoo.bearlock

import android.app.AlertDialog
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.Gravity
import android.widget.*

class SettingsScreen(private val a: MainActivity) {
    private val u get()=a.ui
    private fun t(ja: String,en: String)=a.t(ja,en)
    private fun link(path: String) = a.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://bearlock.hiyozoo.com/"+t("","en/")+path+"/")))
    private fun row(parent: LinearLayout, label: String, symbol: String = "info", action: ()->Unit) = u.add(parent,u.textButton(label,action).apply {
        gravity=Gravity.START or Gravity.CENTER_VERTICAL; setTextColor(Palette.navy); compoundDrawablePadding=u.dp(12)
        setCompoundDrawables(LineIcon(symbol,Palette.steel).apply { setBounds(0,0,u.dp(22),u.dp(22)) },null,null,null)
    },0)
    fun show(parent: LinearLayout) {
        u.add(parent,u.asset(R.drawable.bear_ready,108),12)
        u.add(parent,u.label(t("指定時間が終わると、自動でロックを解除します。","Set app locks that end automatically at the chosen time."),15f,muted=true).apply { gravity=Gravity.CENTER; setTextColor(Palette.muted) },24)
        u.add(parent,u.label(t("データの扱い","Data handling"),13f,true,true),8)
        val data=u.card(); u.add(data,u.label(t("選択対象と予約はこの端末に保存されます。アカウント、クラウド同期、広告、分析、トラッキングはありません。","Selections and schedules stay on this device. No accounts, cloud sync, ads, analytics, or tracking."),15f),0); u.add(parent,data,24)
        u.add(parent,u.label(t("情報","Information"),13f,true,true),8)
        val info=u.card()
        row(info,t("プライバシーポリシー","Privacy Policy")) { link("privacy") }
        row(info,t("サポートとよくある質問","Support and FAQ")) { link("support") }
        u.pair(info,t("バージョン","Version"),BuildConfig.VERSION_NAME,8)
        row(info,t("Bear Lockを応援","Support Bear Lock"),"heart") { a.navigate("support") }
        u.add(parent,info,24)
        u.add(parent,u.label(t("Androidの設定","Android settings"),13f,true,true),8)
        val platform=u.card()
        row(platform,t("権限・動作状態を確認","Permissions and status")) { a.navigate("permissions") }
        row(platform,t("Androidの対応範囲","Android coverage")) {
            AlertDialog.Builder(a).setTitle(t("対応範囲","Coverage")).setMessage(t("Web制限はChrome・Firefoxの通常タブのアドレス欄を対象にしています。非表示のアドレス欄、シークレット、カスタムタブ、他ブラウザは保証対象外です。\n\nカテゴリは端末の分類を使います。未分類のアプリは個別に選択してください。\n\n権限の取消や強制停止中は制限できません。分割画面・PiP・通知返信・仕事用プロファイル・Android 17の高度な保護は未検証です。通信や通知そのものは停止しません。", "Website adapters target regular Chrome and Firefox tabs. Hidden address bars, private tabs, custom tabs and other browsers are not guaranteed.\n\nCategories use device classification. Select unclassified apps individually.\n\nBlocking cannot run while permission is revoked or the app is force-stopped. Split screen, PiP, notification replies, work profiles and Android 17 Advanced Protection are unverified. Network traffic and notifications are not stopped.")).setPositiveButton("OK",null).show()
        }
        row(platform,t("言語 / Language","Language / 言語")) {
            AlertDialog.Builder(a).setTitle("Language / 言語").setItems(arrayOf("システム / System","日本語","English")) { _,which ->
                a.getSharedPreferences("appearance",0).edit().putString("language",listOf("","ja","en")[which]).apply(); a.recreate()
            }.show()
        }
        u.add(parent,platform,24)
        run {
            u.add(parent,u.label(t("診断","Diagnostics"),13f,true,true),8)
            val diagnostics=u.card()
            row(diagnostics,t("端末内の診断","On-device diagnostics")) {
                val text="Android ${Build.VERSION.RELEASE} / ${Build.MANUFACTURER} ${Build.MODEL}\nService: ${GuardService.instance!=null}\nExact alarms: ${Scheduling.permitted(a)}\nStorage: ${a.store.error ?: "OK"}\nRules: ${a.state.rules.size}\nActive: ${a.state.sessions.size}\n\n"+runCatching { a.store.logs().takeLast(6000) }.getOrDefault(t("診断ログを読み込めません","Cannot read diagnostic logs"))
                val view=u.label(text,13f).apply { setTextIsSelectable(true); setPadding(u.dp(20),u.dp(12),u.dp(20),u.dp(12)) }
                AlertDialog.Builder(a).setTitle(t("診断","Diagnostics")).setView(ScrollView(a).apply { addView(view) }).setPositiveButton("OK",null)
                    .setNeutralButton(t("共有","Share")) { _,_ ->
                        a.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                            type="text/plain"; putExtra(Intent.EXTRA_TEXT,text)
                        },t("診断を共有","Share diagnostics")))
                    }.show()
            }
            row(diagnostics,t("診断ログを消去","Clear diagnostics")) { a.store.clearLogs(); Toast.makeText(a,t("診断ログを消去しました","Diagnostics cleared"),Toast.LENGTH_SHORT).show() }
            u.add(parent,diagnostics,0)
        }
    }
}
