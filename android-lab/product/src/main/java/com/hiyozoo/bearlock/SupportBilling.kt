package com.hiyozoo.bearlock

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.android.billingclient.api.*

/** One connection per process; pending purchases also recover when the app resumes. */
class SupportBilling private constructor(context: Context) : PurchasesUpdatedListener {
    companion object {
        val products=listOf("coffee","lunch","dinner").map { "com.hiyozoo.bearlock.support.$it" }
        @Volatile private var instance: SupportBilling?=null
        fun get(context: Context): SupportBilling = instance ?: synchronized(this) {
            instance ?: SupportBilling(context.applicationContext).also { instance=it }
        }
    }
    private val main=Handler(Looper.getMainLooper())
    var changed: (() -> Unit)?=null
    var details: Map<String,ProductDetails> = emptyMap(); private set
    var loading=false; private set
    var busy: String?=null; private set
    var message=""; private set
    private var connecting=false
    private val consuming=mutableSetOf<String>()
    private val finished=mutableSetOf<String>()
    private val client=BillingClient.newBuilder(context).setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection().build()
    private fun update(block: () -> Unit) { main.post { block(); changed?.invoke() } }
    val configured get()=BuildConfig.PLAY_LICENSE_KEY.isNotBlank()
    fun refresh() {
        if(loading || connecting) return
        loading=true; message=""; changed?.invoke()
        if(client.isReady) query() else {
            connecting=true
            client.startConnection(object: BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) { update {
                    connecting=false
                    if(result.responseCode==BillingClient.BillingResponseCode.OK) query()
                    else { loading=false; message="unavailable" }
                } }
                override fun onBillingServiceDisconnected() { update { loading=false; connecting=false; message="connection" } }
            })
        }
    }
    private fun query() {
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()) { result,purchases ->
            update { if(result.responseCode==BillingClient.BillingResponseCode.OK) purchases.forEach(::process) else message="connection" }
        }
        val params=QueryProductDetailsParams.newBuilder().setProductList(products.map {
            QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(BillingClient.ProductType.INAPP).build()
        }).build()
        client.queryProductDetailsAsync(params) { result,response -> update {
            loading=false
            details=if(result.responseCode==BillingClient.BillingResponseCode.OK) response.productDetailsList.associateBy { it.productId } else emptyMap()
            if(details.size<products.size || !configured) message="unavailable"
        } }
    }
    fun buy(activity: Activity, id: String) {
        if(busy!=null || loading || !configured) return
        val product=details[id] ?: return
        if(!client.isReady) { message="connection"; changed?.invoke(); refresh(); return }
        busy=id; message=""; changed?.invoke()
        val item=BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product)
        product.oneTimePurchaseOfferDetails?.offerToken?.let { item.setOfferToken(it) }
        val result=client.launchBillingFlow(activity,BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(item.build())).build())
        if(result.responseCode!=BillingClient.BillingResponseCode.OK) {
            busy=null; message=if(result.responseCode==BillingClient.BillingResponseCode.USER_CANCELED) "cancelled" else "failed"; changed?.invoke()
        }
    }
    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) { update {
        busy=null
        when(result.responseCode) {
            BillingClient.BillingResponseCode.OK -> purchases.orEmpty().forEach(::process)
            BillingClient.BillingResponseCode.USER_CANCELED -> message="cancelled"
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> refresh()
            else -> message="failed"
        }
    } }
    private fun process(purchase: Purchase) {
        if(purchase.products.isEmpty() || purchase.products.any { it !in products }) return
        if(purchase.purchaseState==Purchase.PurchaseState.PENDING) { message="pending"; return }
        if(purchase.purchaseState!=Purchase.PurchaseState.PURCHASED) return
        if(!PurchaseVerifier.verify(BuildConfig.PLAY_LICENSE_KEY,purchase.originalJson,purchase.signature)) { message="verification"; return }
        val token=purchase.purchaseToken
        if(token in finished || !consuming.add(token)) return
        client.consumeAsync(ConsumeParams.newBuilder().setPurchaseToken(token).build()) { result,_ -> update {
            consuming.remove(token)
            if(result.responseCode==BillingClient.BillingResponseCode.OK) { finished.add(token); message="thanks" }
            else message="retry_purchase"
        } }
    }
}
