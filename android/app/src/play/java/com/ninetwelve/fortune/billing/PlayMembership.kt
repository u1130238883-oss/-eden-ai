package com.ninetwelve.fortune.billing

import android.app.Activity
import android.app.Application
import android.util.Log
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.ninetwelve.fortune.BuildConfig

/**
 * Google Play 帳單（Play Billing Library 7）。
 *
 * Google Play 的付款政策規定：在 Play 上架的 App，只要在 App 內解鎖數位內容或功能，
 * 就必須使用 Google Play 帳單，不能改接微信支付、支付寶或其他第三方收款。
 * 因此上架 Play 的版本一律走這條路。
 *
 * 商品必須先在 Play Console 建立，商品編號要與 [PRODUCT_ID] 一致。
 */
class PlayMembership(app: Application) : Membership(app) {

    private var productDetails: ProductDetails? = null
    private var offerToken: String? = null

    private val purchasesUpdated = PurchasesUpdatedListener { result, purchases ->
        isBusy = false
        when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                purchases?.forEach { settle(it) }
                queryEntitlement()
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> Unit
            else -> errorMessage = result.debugMessage.ifBlank { "Billing error ${result.responseCode}" }
        }
    }

    private val client: BillingClient = BillingClient.newBuilder(app)
        .setListener(purchasesUpdated)
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
        )
        .build()

    init {
        connect()
    }

    private fun connect() {
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    queryProduct()
                    queryEntitlement()
                } else {
                    isLoading = false
                    Log.w(TAG, "billing setup failed: ${result.debugMessage}")
                }
            }

            override fun onBillingServiceDisconnected() {
                // 下次需要時再連；不在這裡無限重試，避免耗電
                isLoading = false
            }
        })
    }

    private fun queryProduct() {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(PRODUCT_ID)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                )
            )
            .build()
        client.queryProductDetailsAsync(params) { result, details ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                val pd = details.firstOrNull()
                productDetails = pd
                val offer = pd?.subscriptionOfferDetails?.firstOrNull()
                offerToken = offer?.offerToken
                priceText = offer?.pricingPhases?.pricingPhaseList
                    ?.firstOrNull()?.formattedPrice
            }
            isLoading = false
        }
    }

    private fun queryEntitlement() {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS)
            .build()
        client.queryPurchasesAsync(params) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                val active = purchases.any { p ->
                    p.products.contains(PRODUCT_ID) &&
                        p.purchaseState == Purchase.PurchaseState.PURCHASED
                }
                purchases.forEach { settle(it) }
                isActive = active
            }
            isLoading = false
        }
    }

    /** Play 要求購買後三天內確認，否則會自動退款。 */
    private fun settle(purchase: Purchase) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return
        if (purchase.isAcknowledged) return
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        client.acknowledgePurchase(params) { }
    }

    override fun purchase(activity: Activity) {
        val pd = productDetails
        val token = offerToken
        if (pd == null || token == null) {
            errorMessage = null
            queryProduct()
            return
        }
        isBusy = true
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(pd)
                        .setOfferToken(token)
                        .build()
                )
            )
            .build()
        val result = client.launchBillingFlow(activity, params)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            isBusy = false
            errorMessage = result.debugMessage.ifBlank { "Billing error ${result.responseCode}" }
        }
    }

    override fun refresh() {
        errorMessage = null
        if (client.isReady) {
            queryProduct()
            queryEntitlement()
        } else {
            connect()
        }
    }

    override val manageUrl: String
        get() = "https://play.google.com/store/account/subscriptions" +
            "?sku=$PRODUCT_ID&package=${BuildConfig.APPLICATION_ID}"

    companion object {
        private const val TAG = "PlayMembership"

        /** 要與 Play Console 裡建立的訂閱商品編號完全一致。 */
        const val PRODUCT_ID = "pro_monthly"
    }
}

/** 由 flavor 提供的建構入口，見 `direct` flavor 的同名函式。 */
fun createMembership(app: Application): Membership = PlayMembership(app)
