package com.ninetwelve.fortune.engine

/**
 * 繁體中文／英文版本開放的語言。
 *
 * `latin` flavor 有一份同名檔案，開放西班牙文與義大利文。
 * 兩者只會有一份被編進去，取決於建置的 product flavor。
 */
internal val AVAILABLE_LANGS: List<Lang> = listOf(Lang.ZH, Lang.EN)
