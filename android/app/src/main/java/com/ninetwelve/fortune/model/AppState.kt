package com.ninetwelve.fortune.model

import android.app.Application
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import com.ninetwelve.fortune.engine.Destiny
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.Txt
import com.ninetwelve.fortune.engine.YearAnchor
import org.json.JSONArray
import org.json.JSONObject

/**
 * 全域狀態：主命盤、已存的其他人、以及顯示設定。全部存在 SharedPreferences，
 * 只留在這台裝置上，不會上傳。
 */
class AppState(private val app: Application) : AndroidViewModel(app) {

    private object Key {
        const val PREFS = "nt.prefs"
        const val OWNER = "nt.owner"
        const val OTHERS = "nt.others"
        const val LANG = "nt.lang"
        const val ANCHOR = "nt.yearAnchor"
    }

    private val prefs = app.getSharedPreferences(Key.PREFS, Context.MODE_PRIVATE)

    // 每個設定都是「改了就存」。用 private 的 state 當底層、外面再包一層有
    // 自訂 setter 的屬性 —— 委派屬性沒辦法自己寫 setter，而另外開 setXxx()
    // 函式會和編譯器產生的 setter 在 JVM 上撞名。

    private var ownerState by mutableStateOf<Profile?>(null)
    private var langState by mutableStateOf(Lang.fallback)
    private var anchorState by mutableStateOf(YearAnchor.BIRTH_DERIVED)

    /** 本人的命盤資料。為 null 時顯示輸入畫面。 */
    var owner: Profile?
        get() = ownerState
        set(value) {
            ownerState = value
            if (value == null) prefs.edit().remove(Key.OWNER).apply()
            else prefs.edit().putString(Key.OWNER, value.toJson().toString()).apply()
        }

    /** 合盤用的其他人。 */
    val others = mutableStateListOf<Profile>()

    /** 介面語言。首次啟動時依系統語言判斷。 */
    var lang: Lang
        get() = langState
        set(value) {
            langState = value
            prefs.edit().putString(Key.LANG, value.code).apply()
            // 主畫面上的名稱也跟著換
            AppLocale.apply(app, value)
        }

    /** 流年錨定方式。 */
    var yearAnchor: YearAnchor
        get() = anchorState
        set(value) {
            anchorState = value
            prefs.edit().putString(Key.ANCHOR, value.name).apply()
        }

    /** 目前語言的字串輔助。 */
    val t: Txt get() = Txt(lang)

    init {
        prefs.getString(Key.OWNER, null)?.let {
            runCatching { ownerState = Profile.fromJson(JSONObject(it)) }
        }
        prefs.getString(Key.OTHERS, null)?.let { raw ->
            runCatching {
                val arr = JSONArray(raw)
                for (i in 0 until arr.length()) {
                    others.add(Profile.fromJson(arr.getJSONObject(i)))
                }
            }
        }
        // 舊設定若不屬於這個版本開放的語言（例如換裝了另一個語言版本），退回預設
        val saved = Lang.fromCode(prefs.getString(Key.LANG, null))
        if (saved != null && Lang.available.contains(saved)) {
            langState = saved
            // 選過語言的話，補確認一次主畫面名稱用的是同一個語言
            AppLocale.apply(app, saved)
        } else {
            langState = Lang.detect()
        }

        prefs.getString(Key.ANCHOR, null)?.let { raw ->
            runCatching { anchorState = YearAnchor.valueOf(raw) }
        }
    }

    /** 本人的推算引擎。 */
    val destiny: Destiny?
        get() = owner?.destiny(yearAnchor)

    fun addOther(p: Profile) {
        others.removeAll { it.id == p.id }
        others.add(0, p)
        while (others.size > 30) others.removeAt(others.size - 1)
        saveOthers()
    }

    fun reset() {
        owner = null
        others.clear()
        saveOthers()
    }

    private fun saveOthers() {
        val arr = JSONArray()
        others.forEach { arr.put(it.toJson()) }
        prefs.edit().putString(Key.OTHERS, arr.toString()).apply()
    }
}
