package com.ninetwelve.fortune

import android.app.Application
import com.ninetwelve.fortune.billing.Membership
import com.ninetwelve.fortune.billing.createMembership

/**
 * 會員狀態要活得比畫面久（轉螢幕、切到背景再回來都不該重連商店），
 * 所以掛在 Application 上，而不是 Activity。
 *
 * [createMembership] 由 product flavor 提供：`play` 版回傳走 Google Play 帳單的實作，
 * `direct` 版回傳微信／支付寶 + 啟用碼的實作。
 */
class NineTwelveApplication : Application() {
    val membership: Membership by lazy { createMembership(this) }
}
