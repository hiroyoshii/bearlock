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
        row(platform,t("権限・動作状態を確認","Permissions and status")) { a.requestPermissions() }
        row(platform,t("対応する制限","Supported blocking")) {
            AlertDialog.Builder(a).setTitle(t("対応する制限","Supported blocking")).setMessage(t("アプリ、端末のカテゴリ、Webサイトをロックできます。WebサイトはChromeとFirefoxの通常タブに対応しています。シークレットタブ、カスタムタブ、その他のブラウザには対応していません。\n\nカテゴリに含まれないアプリは個別に選択してください。通知や通信は停止しません。", "Bear Lock can block apps, device categories, and websites. Website blocking supports regular tabs in Chrome and Firefox. Private tabs, custom tabs, and other browsers are not supported.\n\nSelect apps individually when they are not included in a category. Notifications and network traffic are not blocked.")).setPositiveButton("OK",null).show()
        }
        u.add(parent,platform,24)
        run {
            u.add(parent,u.label(t("診断","Diagnostics"),13f,true,true),8)
            val diagnostics=u.card()
            row(diagnostics,t("端末内の診断","On-device diagnostics")) {
                val connected=if(GuardService.instance!=null) t("接続済み","Connected") else t("未接続","Not connected")
                val alarm=if(Scheduling.permitted(a)) t("許可済み","Allowed") else t("未許可","Not allowed")
                val storage=a.store.error?.let { t("エラー","Error") } ?: t("正常","OK")
                val records=runCatching { a.store.logs().takeLast(6000) }.getOrDefault(t("診断ログを読み込めません","Cannot read diagnostic logs"))
                val text="${t("OS","OS")}: Android ${Build.VERSION.RELEASE}\n${t("端末","Device")}: ${Build.MANUFACTURER} ${Build.MODEL}\n${t("制限サービス","Blocking service")}: $connected\n${t("予約権限","Scheduling permission")}: $alarm\n${t("保存状態","Storage")}: $storage\n${t("予定","Schedules")}: ${a.state.rules.size}\n${t("実行中","Active locks")}: ${a.state.activeLocks(System.currentTimeMillis()).size}\n\n${t("診断記録","Diagnostic records")}\n$records"
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
