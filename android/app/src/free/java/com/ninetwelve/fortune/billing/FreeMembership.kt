package com.ninetwelve.fortune.billing

import android.app.Activity
import android.app.Application

/**
 * 完全解鎖版：沒有任何付費機制，命盤／運程／合盤直接開放。
 *
 * 這個版本不接 Google Play 帳單，也不做啟用碼驗證，
 * 是給作者自己試用與展示用的，不是拿去上架或發售的版本。
 * 要收費請用 `play`（Google Play 帳單）或 `direct`（微信／支付寶 + 啟用碼）。
 */
class FreeMembership(app: Application) : Membership(app) {

    override val isFree: Boolean get() = true

    init {
        isActive = true
        isLoading = false
    }

    override fun purchase(activity: Activity) = Unit

    override fun refresh() {
        isActive = true
        isLoading = false
    }
}

/** 由 flavor 提供的建構入口，見 `play` 與 `direct` flavor 的同名函式。 */
fun createMembership(app: Application): Membership = FreeMembership(app)
