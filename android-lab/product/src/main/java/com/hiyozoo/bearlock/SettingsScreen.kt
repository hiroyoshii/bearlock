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
    private fun link(path: String) {
        try { a.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://bearlock.hiyozoo.com/"+t("","en/")+path+"/"))) }
        catch (_: android.content.ActivityNotFoundException) { a.error("browser_unavailable") }
    }
    private fun row(parent: LinearLayout, label: String, symbol: String = "info", navigation: Boolean = false, action: ()->Unit) {
        if(parent.childCount>0) u.divider(parent)
        u.add(parent,u.textButton(label,action).apply {
            gravity=Gravity.START or Gravity.CENTER_VERTICAL; textSize=17f; setTextColor(if(navigation) Palette.textPrimary else Palette.navigation); compoundDrawablePadding=u.dp(12)
            setCompoundDrawables(u.icon(symbol,Palette.navigation).apply { setBounds(0,0,u.dp(22),u.dp(22)) },null,
                if(navigation) u.icon("right",Palette.secondary).apply { setBounds(0,0,u.dp(16),u.dp(16)) } else null,null)
        },0)
    }
    fun show(parent: LinearLayout) {
        val hero=u.section(parent).apply { background=u.bg(Palette.background,20) }
        u.add(hero,u.asset(R.drawable.bear_ready,108),12)
        u.add(hero,u.label(t("選んだ時刻に自動で終わるアプリロックを設定します。","Set app locks that end automatically at the chosen time."),15f,muted=true).apply { gravity=Gravity.CENTER; setTextColor(Palette.steel) },0)
        val data=u.section(parent,t("データの扱い","Data handling"))
        u.add(data,u.label(t("選択と予定はこの端末内に保存されます。アカウント、クラウド同期、広告、分析、トラッキングは使いません。","Selections and schedules stay on this device. No accounts, cloud sync, ads, analytics, or tracking."),17f).apply { setTextColor(Palette.textPrimary) },0)
        val info=u.section(parent,t("情報","Information"))
        row(info,t("プライバシーポリシー","Privacy Policy")) { link("privacy") }
        row(info,t("サポート・よくある質問","Support and FAQ")) { link("support") }
        u.divider(info); u.pair(info,t("バージョン","Version"),BuildConfig.VERSION_NAME,12)
        row(info,t("サポート","Support"),"heart",true) { a.navigate("support") }
        if(BuildConfig.DEBUG) {
            val diagnostics=u.section(parent,t("診断","Diagnostics"))
            row(diagnostics,t("診断","Diagnostics"),navigation=true) { a.navigate("diagnostics") }
        }
        val platform=u.section(parent,t("Androidの設定","Android settings"))
        row(platform,t("権限・動作状態を確認","Permissions and status")) { a.requestPermissions() }
        row(platform,t("対応する制限","Supported blocking")) {
            AlertDialog.Builder(a).setTitle(t("対応する制限","Supported blocking")).setMessage(t("アプリ、端末のカテゴリ、Webサイトをロックできます。WebサイトはChromeとFirefoxの通常タブで、アドレス欄から現在のドメインを取得できる場合に対応します。アドレス欄の非表示・編集中、シークレットタブ、カスタムタブ、その他のブラウザの遮断は保証できません。\n\nカテゴリに含まれないアプリは個別に選択してください。通知や通信は停止しません。", "Bear Lock can block apps, device categories, and websites. Website blocking supports regular Chrome and Firefox tabs when the current domain can be read from the address bar. Blocking is not guaranteed while the address bar is hidden or being edited, or in private tabs, custom tabs, or other browsers.\n\nSelect apps individually when they are not included in a category. Notifications and network traffic are not blocked.")).setPositiveButton("OK",null).show()
        }
    }
    fun diagnostics(parent: LinearLayout) {
        if(!BuildConfig.DEBUG) return
        val now=System.currentTimeMillis()
        val connected=if(GuardService.instance!=null) t("接続済み","Connected") else t("未接続","Not connected")
        val alarm=if(Scheduling.permitted(a)) t("許可済み","Allowed") else t("未許可","Not allowed")
        val storage=a.store.error ?: t("正常","OK")
        val records=runCatching { a.store.logs().takeLast(6000) }.getOrDefault(t("診断ログを読み込めません","Cannot read diagnostic logs"))
        val summary=listOf(
            t("制限サービス","Blocking service") to connected,
            t("予約権限","Scheduling permission") to alarm,
            t("保存状態","Storage") to storage,
            t("対象選択","Target selections") to (a.state.selection?.count ?: 0).toString(),
            t("予定数","Scheduled rules") to a.state.rules.size.toString(),
            t("繰り返し予定","Recurring rules") to a.state.rules.count { it.recurring }.toString(),
            t("実行中","Active locks") to a.state.activeLocks(now).size.toString(),
            t("最後の警告","Last warning") to if(Scheduling.updateFailed) t("ロックの監視を更新できません","Monitoring could not be updated") else t("なし","None")
        )
        val status=u.section(parent,t("状態","Status"))
        summary.forEachIndexed { i,(name,value) -> if(i>0) u.divider(status); u.pair(status,name,value,12) }
        val text=("Bear Lock "+BuildConfig.VERSION_NAME+"\n"+summary.joinToString("\n") { it.first+": "+it.second }+"\nAndroid "+Build.VERSION.RELEASE+" / "+Build.MANUFACTURER+" "+Build.MODEL+"\n\n"+records)
        val sharing=u.section(parent)
        row(sharing,t("診断を共有","Share diagnostics")) {
            a.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply { type="text/plain"; putExtra(Intent.EXTRA_TEXT,text) },t("診断を共有","Share diagnostics")))
        }
        u.add(sharing,u.label(t("共有前に診断内容を確認してください。対象や予約時刻が含まれる場合があります。","Review diagnostics before sharing. They may include your selections and schedule times."),13f,muted=true),0)
        val device=u.section(parent,t("アプリ・端末","App and device"))
        u.pair(device,t("バージョン","Version"),BuildConfig.VERSION_NAME)
        u.pair(device,"OS","Android "+Build.VERSION.RELEASE)
        u.pair(device,t("端末","Device"),Build.MANUFACTURER+" "+Build.MODEL,0)
        val events=u.section(parent,t("最近のイベント","Recent Events"))
        u.add(events,u.label(records.ifBlank { t("まだイベントはありません。","No events yet.") },13f,muted=true).apply { setTextIsSelectable(true) },0)
        val actions=u.section(parent)
        row(actions,t("診断ログを消去","Clear Diagnostics"),"trash") { a.store.clearLogs(); a.render() }
    }
}
