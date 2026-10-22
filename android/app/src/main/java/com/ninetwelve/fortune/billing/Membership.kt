package com.ninetwelve.fortune.billing

import android.app.Activity
import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * 會員狀態。
 *
 * 三種發行管道各有一份實作，由 product flavor 決定編進哪一份：
 *
 * - `play`   → [com.ninetwelve.fortune.billing.PlayMembership]，走 Google Play 帳單。
 *              上架 Google Play 的版本一律要用這個，這是 Play 付款政策的規定。
 * - `direct` → [com.ninetwelve.fortune.billing.DirectMembership]，走微信／支付寶
 *              收款 + 啟用碼。只用於不經由 Google Play 發行的 APK。
 * - `free`   → [com.ninetwelve.fortune.billing.FreeMembership]，完全解鎖、
 *              沒有付費機制。給作者自己試用與展示用，不是發售版本。
 */
abstract class Membership(protected val app: Application) {

    /** 目前是否為會員。 */
    var isActive by mutableStateOf(false)
        protected set

    /** 是否正在向後端（Play 或本機）查詢。 */
    var isLoading by mutableStateOf(true)
        protected set

    /** 是否正在進行付款／驗證流程。 */
    var isBusy by mutableStateOf(false)
        protected set

    /** 要顯示的價格文字；Play 版由商店回傳當地價格，直連版為固定價。 */
    var priceText by mutableStateOf<String?>(null)
        protected set

    /** 最近一次錯誤，供介面顯示。 */
    var errorMessage by mutableStateOf<String?>(null)

    /** 會員到期日（yyyy-MM-dd），只有直連版知道；Play 版由商店管理，回傳 null。 */
    open val expiryText: String? get() = null

    /** 這個版本有沒有付費機制。解鎖版為 true，介面上就不必提會員。 */
    open val isFree: Boolean get() = false

    /** 開始購買流程。 */
    abstract fun purchase(activity: Activity)

    /** 重新確認權益（換手機、重裝、或付款後手動刷新）。 */
    abstract fun refresh()

    /** 「管理訂閱」要開的網址；直連版沒有，回傳 null。 */
    open val manageUrl: String? get() = null
}
