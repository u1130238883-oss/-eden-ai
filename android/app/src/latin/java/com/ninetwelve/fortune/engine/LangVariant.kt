package com.ninetwelve.fortune.engine

/**
 * 西班牙文／義大利文版本開放的語言。
 *
 * `cjk` flavor 有一份同名檔案，開放繁體中文與英文。
 * 兩者只會有一份被編進去，取決於建置的 product flavor。
 */
internal val AVAILABLE_LANGS: List<Lang> = listOf(Lang.ES, Lang.IT)
