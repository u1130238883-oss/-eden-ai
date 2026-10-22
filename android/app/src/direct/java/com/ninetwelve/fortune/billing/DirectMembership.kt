package com.ninetwelve.fortune.billing

import android.app.Activity
import android.app.Application
import android.content.Context
import com.ninetwelve.fortune.BuildConfig
import java.util.Calendar
import java.util.Locale
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.random.Random

/**
 * 直連版（不經 Google Play 發行）的會員機制：微信／支付寶收款 + 啟用碼。
 *
 * 為什麼只有這個版本能這樣做：Google Play 的付款政策只管在 Play 上架的 App。
 * 從自己的網站、二維碼或其他管道直接發 APK 給用戶安裝，不受該政策約束，
 * 可以用任何方式收款。Play 版請見 `src/play` 的 [PlayMembership]。
 *
 * 流程：
 * 1. App 為每台裝置產生一組「裝置碼」（隨機產生，不讀取任何硬體識別碼）。
 * 2. 用戶掃微信／支付寶付款，把裝置碼傳給你。
 * 3. 你用 `tools/make_activation_code.py` 產生啟用碼給他。
 * 4. 他輸入啟用碼，App 在本機驗證，不需要連網。
 *
 * 啟用碼綁定裝置碼，換一台手機就失效，所以不能互相轉傳。
 *
 * 誠實說明其限度：驗證金鑰是編進 APK 裡的，會反編譯的人可以把它挖出來自己發碼。
 * 這對這個規模的軟體足夠了，但它不是防不破的；真的要防，得改成連自己的伺服器驗證。
 */
class DirectMembership(app: Application) : Membership(app) {

    private val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** 這台裝置的識別碼，給用戶抄給你用。隨機產生，與硬體無關。 */
    val deviceCode: String = prefs.getString(KEY_DEVICE, null) ?: newDeviceCode().also {
        prefs.edit().putString(KEY_DEVICE, it).apply()
    }

    /** 目前生效的啟用碼到期日，格式 yyyyMMdd；沒有會員時為 0。 */
    private var expiry: Int = 0

    override val expiryText: String?
        get() = if (expiry <= 0) null else String.format(
            Locale.ROOT, "%04d-%02d-%02d", expiry / 10000, expiry / 100 % 100, expiry % 100
        )

    init {
        priceText = PRICE_TEXT
        refresh()
    }

    /** 直連版沒有商店可跳轉；付款畫面自己就是購買流程。 */
    override fun purchase(activity: Activity) = Unit

    override fun refresh() {
        val saved = prefs.getString(KEY_CODE, null)
        expiry = 0
        isActive = false
        if (saved != null && verify(saved)) {
            expiry = saved.substringBefore('-').toIntOrNull() ?: 0
            isActive = expiry >= today()
            if (!isActive) expiry = 0
        }
        isLoading = false
    }

    /**
     * 輸入啟用碼。成功會存起來，之後開 App 不必再輸入。
     * 回傳 null 表示成功，否則回傳該顯示的錯誤原因代碼。
     */
    fun activate(raw: String): ActivationError? {
        val code = normalise(raw)
        if (code.isEmpty()) return ActivationError.EMPTY
        if (!verify(code)) return ActivationError.INVALID
        val exp = code.substringBefore('-').toIntOrNull() ?: return ActivationError.INVALID
        if (exp < today()) return ActivationError.EXPIRED
        prefs.edit().putString(KEY_CODE, code).apply()
        refresh()
        return null
    }

    enum class ActivationError { EMPTY, INVALID, EXPIRED }

    // ── 驗證 ──

    /** 統一成 `yyyyMMdd-XXXXXXXX` 的大寫形式。 */
    private fun normalise(raw: String): String {
        val cleaned = raw.uppercase(Locale.ROOT).filter { it.isLetterOrDigit() }
        if (cleaned.length < 9) return ""
        return cleaned.substring(0, 8) + "-" + cleaned.substring(8)
    }

    private fun verify(code: String): Boolean {
        val parts = code.split("-")
        if (parts.size != 2) return false
        val (exp, mac) = parts
        if (exp.length != 8 || exp.toIntOrNull() == null) return false
        return constantTimeEquals(mac, sign(deviceCode, exp))
    }

    private fun sign(device: String, expiry: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(BuildConfig.ACTIVATION_SECRET.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        val digest = mac.doFinal("$device|$expiry".toByteArray(Charsets.UTF_8))
        val sb = StringBuilder(MAC_LENGTH)
        for (i in 0 until MAC_LENGTH) {
            sb.append(ALPHABET[digest[i].toInt() and 0x1F])
        }
        return sb.toString()
    }

    private fun constantTimeEquals(a: String, b: String): Boolean {
        if (a.length != b.length) return false
        var diff = 0
        for (i in a.indices) diff = diff or (a[i].code xor b[i].code)
        return diff == 0
    }

    private fun today(): Int {
        val c = Calendar.getInstance()
        return c.get(Calendar.YEAR) * 10000 +
            (c.get(Calendar.MONTH) + 1) * 100 +
            c.get(Calendar.DAY_OF_MONTH)
    }

    private fun newDeviceCode(): String =
        (1..DEVICE_LENGTH).map { ALPHABET[Random.nextInt(ALPHABET.length)] }.joinToString("")

    companion object {
        private const val PREFS = "nt.direct"
        private const val KEY_DEVICE = "deviceCode"
        private const val KEY_CODE = "activationCode"

        /** 去掉容易看錯的 I O 0 1，方便用戶用手抄或念給你聽。 */
        const val ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        const val DEVICE_LENGTH = 8
        const val MAC_LENGTH = 8

        /** 直連版不受商店價格級距限制，就是你定的那個價。 */
        const val PRICE_TEXT = "€10 / US\$10 / £10 / ¥80"
    }
}

/** 由 flavor 提供的建構入口，見 `play` flavor 的同名函式。 */
fun createMembership(app: Application): Membership = DirectMembership(app)
