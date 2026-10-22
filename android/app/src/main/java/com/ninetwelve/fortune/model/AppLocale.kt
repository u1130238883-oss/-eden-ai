package com.ninetwelve.fortune.model

import android.app.LocaleManager
import android.content.Context
import android.os.Build
import android.os.LocaleList
import com.ninetwelve.fortune.engine.Lang

/**
 * 讓主畫面上的名稱跟著 App 裡選的語言走。
 *
 * 主畫面的名稱是啟動器讀 AndroidManifest 的 android:label 來的，系統依
 * 「這個 App 的語言」去挑對應的 values-xx/strings.xml。Android 13（API 33）
 * 起 App 可以自己指定這個語言；更早的版本沒有這個機制，名稱只能跟著整支
 * 手機的系統語言，這是系統的限制，不是 App 能決定的。
 */
object AppLocale {

    /** 對應到 res 底下的語言資料夾。 */
    private fun tag(lang: Lang): String = when (lang) {
        Lang.ZH -> "zh-Hant"
        Lang.EN -> "en"
        Lang.ES -> "es"
        Lang.IT -> "it"
    }

    fun apply(context: Context, lang: Lang) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val manager = context.getSystemService(LocaleManager::class.java) ?: return
        val wanted = tag(lang)
        val current = manager.applicationLocales
        // 已經是這個語言就不要再設一次 —— 設定會讓畫面重建
        if (!current.isEmpty && current[0].toLanguageTag().equals(wanted, ignoreCase = true)) return
        manager.applicationLocales = LocaleList.forLanguageTags(wanted)
    }
}
