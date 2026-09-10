package com.hiyozoo.bearlock

import android.view.Gravity
import android.view.View
import android.widget.LinearLayout

class SupportScreen(private val a: MainActivity) {
    fun show(parent: LinearLayout) {
        val u=a.ui; val billing=SupportBilling.get(a)
        val intro=u.card()
        u.add(intro,u.label(a.t("Bear Lockは無料です。広告、アカウント、サブスクリプションはありません。","Bear Lock is free. No ads, accounts, or subscriptions."),16f),14)
        u.add(intro,u.label(a.t("気に入っていただけたら、開発を応援できます。応援の有無で機能は変わりません。","If you like it, you can help development continue. Bear Lock works the same either way."),15f,muted=true),0)
        u.add(parent,intro,20)
        val items=u.card()
        SupportBilling.products.forEachIndexed { i,id ->
            val product=billing.details[id]
            val price=product?.oneTimePurchaseOfferDetails?.formattedPrice
            val name=listOf("Coffee","Lunch","Dinner")[i]
            val displayPrice=if(billing.busy==id) a.t("購入中…","Purchasing…") else price ?: "—"
            val row=u.row().apply {
                minimumHeight=u.dp(56); setPadding(u.dp(8),u.dp(10),u.dp(8),u.dp(10))
                background=u.touchBackground(Palette.white); isClickable=true; isFocusable=true
                isEnabled=billing.configured && price!=null && !billing.loading && billing.busy==null
                alpha=if(isEnabled) 1f else .6f
                contentDescription="$name · $displayPrice"
                accessibilityDelegate=object: View.AccessibilityDelegate() {
                    override fun onInitializeAccessibilityNodeInfo(host: View, info: android.view.accessibility.AccessibilityNodeInfo) {
                        super.onInitializeAccessibilityNodeInfo(host,info); info.className="android.widget.Button"; info.text=contentDescription
                    }
                }
                setOnClickListener { billing.buy(a,id) }
            }
            row.addView(android.widget.ImageView(a).apply {
                setImageDrawable(LineIcon(name.lowercase(),Palette.steel)); importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_NO
            },LinearLayout.LayoutParams(u.dp(24),u.dp(24)).apply { rightMargin=u.dp(12) })
            row.addView(u.label(name,16f,true).apply { importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_NO },LinearLayout.LayoutParams(0,-2,1f))
            row.addView(u.label(displayPrice,14f,true).apply { importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_NO; gravity=Gravity.END })
            u.add(items,row,4)
        }
        u.add(parent,items,16)
        val message=when(billing.message) {
            "thanks" -> a.t("応援ありがとうございます！","Thank you for supporting Bear Lock!")
            "pending" -> a.t("購入は保留中です。Google Playでのお支払い完了後に確認します。","Your purchase is pending. It will be checked after payment completes in Google Play.")
            "cancelled" -> a.t("購入をキャンセルしました。","Purchase cancelled.")
            "verification" -> a.t("購入を確認できませんでした。時間をおいて再度お試しください。","The purchase could not be verified. Please try again later.")
            "retry_purchase" -> a.t("購入の確認を完了できませんでした。再読み込みすると再確認します。再購入は不要です。","Could not finish confirming your purchase. Reload to retry; you do not need to buy again.")
            "connection" -> a.t("Google Playに接続できません。接続を確認して再読み込みしてください。","Cannot connect to Google Play. Check your connection and reload.")
            "failed" -> a.t("購入を完了できませんでした。","The purchase could not be completed.")
            "unavailable" -> a.t("現在、応援アイテムを購入できません。時間をおいて再読み込みしてください。","Support items are currently unavailable. Please reload later.")
            else -> if(billing.loading) a.t("応援アイテムを読み込み中…","Loading support items…") else ""
        }
        if(message.isNotEmpty()) u.add(parent,u.label(message,14f,muted=true).apply { accessibilityLiveRegion=View.ACCESSIBILITY_LIVE_REGION_POLITE },16)
        u.add(parent,u.button(a.t("応援アイテムを再読み込み","Reload support items")) { billing.refresh() }.apply { isEnabled=!billing.loading && billing.busy==null },0)
    }
}
