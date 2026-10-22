package com.ninetwelve.fortune.engine

import java.util.Locale

/**
 * 介面語言。
 *
 * 這份程式碼同時支援四種語言，但單一次建置只會開放其中兩種。
 * 開放哪兩種由 product flavor 決定：
 * `cjk` 版本為繁體中文與英文（`src/cjk/.../LangVariant.kt`），
 * `latin` 版本為西班牙文與義大利文（`src/latin/.../LangVariant.kt`）。
 */
enum class Lang(val code: String, val title: String) {
    ZH("zh", "繁體中文"),
    EN("en", "English"),
    ES("es", "Español"),
    IT("it", "Italiano");

    companion object {
        /** 這個版本開放的語言，由 flavor 的原始碼集提供。 */
        val available: List<Lang> get() = AVAILABLE_LANGS

        /** 找不到合適語言時的預設值。 */
        val fallback: Lang get() = available[0]

        fun fromCode(code: String?): Lang? = entries.firstOrNull { it.code == code }

        /** 依系統語言推測，推測結果不在這個版本內時退回預設。 */
        fun detect(): Lang {
            val code = Locale.getDefault().language.lowercase(Locale.ROOT)
            val guess = when {
                code.startsWith("zh") -> ZH
                code.startsWith("es") -> ES
                code.startsWith("it") -> IT
                else -> EN
            }
            return if (available.contains(guess)) guess else fallback
        }
    }
}

/**
 * 多語字串輔助。
 *
 * 用法：`t("今日", "Today", "Hoy", "Oggi")` —— 各語言的文字並排寫在一起，方便對照。
 * 西／義文可以省略，省略時退回英文。
 */
class Txt(val lang: Lang) {

    /** 依目前語言取字串。 */
    operator fun invoke(zh: String, en: String, es: String? = null, ita: String? = null): String =
        when (lang) {
            Lang.ZH -> zh
            Lang.EN -> en
            Lang.ES -> es ?: en
            Lang.IT -> ita ?: en
        }

    val isZH: Boolean get() = lang == Lang.ZH

    /** 中文用頓號，其餘語言用逗號。 */
    val listSeparator: String get() = if (isZH) "、" else ", "

    // ── 領域詞彙 ──

    /** 「5宮」／「Palace 5」／「Palacio 5」／「Palazzo 5」 */
    fun palace(n: Int): String = this("${n}宮", "Palace $n", "Palacio $n", "Palazzo $n")

    /** 「5宮・桃花」／「Palace 5 · Peach Blossom」 */
    fun palaceNamed(n: Int): String =
        palace(n) + this("・", " · ") + Palace.shortName(n, lang)

    /** 「金」／「Metal」／「Metal」／「Metallo」 */
    fun element(e: Element): String = e.name(lang)

    /** 「壞」／「Adverse」／「Adverso」／「Avverso」 */
    fun verdict(v: Verdict): String = v.name(lang)

    /** 「壞3因8」／「Adverse 3 from 8」 */
    fun reading(r: Reading): String = r.text(lang)

    /** 判讀中間那個小字：「因」／「from」／「de」／「da」 */
    val causeParticle: String get() = this("因", "from", "de", "da")

    /** 「果」／「Effect」／「Efecto」／「Effetto」 */
    val effectWord: String get() = this("果", "Effect", "Efecto", "Effetto")

    /** 「因」／「Cause」／「Causa」／「Causa」 */
    val causeWord: String get() = this("因", "Cause", "Causa", "Causa")

    val lifeNumber: String get() = this("靈數", "Life Number", "Número de Vida", "Numero di Vita")
    val lifePalace: String get() = this("命宮", "Life Palace", "Palacio de Vida", "Palazzo della Vita")

    val yearPillar: String get() = this("年柱", "Year Pillar", "Pilar del Año", "Pilastro dell'Anno")
    val monthPillar: String get() = this("月柱", "Month Pillar", "Pilar del Mes", "Pilastro del Mese")
    val dayPillar: String get() = this("日柱", "Day Pillar", "Pilar del Día", "Pilastro del Giorno")

    /** 三柱寫法：中文用全形分號，其餘用斜線 */
    fun triple(t: Triple): String =
        this("${t.year}；${t.month}；${t.day}", "${t.year} / ${t.month} / ${t.day}")

    /** 年份：「2026年」／「2026」 */
    fun year(y: Int): String = this("${y}年", "$y")

    /** 月份縮寫 */
    fun month(m: Int): String {
        val i = m.coerceIn(1, 12) - 1
        return when (lang) {
            Lang.ZH -> "${m}月"
            Lang.EN -> listOf(
                "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
            )[i]
            Lang.ES -> listOf(
                "ene", "feb", "mar", "abr", "may", "jun",
                "jul", "ago", "sep", "oct", "nov", "dic",
            )[i]
            Lang.IT -> listOf(
                "gen", "feb", "mar", "apr", "mag", "giu",
                "lug", "ago", "set", "ott", "nov", "dic",
            )[i]
        }
    }

    /** 日期：「2006年1月14日」／「14 Jan 2006」 */
    fun date(b: BirthDate): String =
        this("${b.year}年${b.month}月${b.day}日", "${b.day} ${month(b.month)} ${b.year}")

    /** 年月柱的五行關係說明 */
    fun relation(r: Reading): String {
        val ey = element(r.yearElement)
        val em = element(r.monthElement)
        val yearWord = this("年", "Year", "Año", "Anno")
        val monthWord = this("月", "Month", "Mes", "Mese")
        return when (r.relation) {
            PillarRelation.SAME ->
                this("同為$ey", "both $ey", "ambos $ey", "entrambi $ey")
            PillarRelation.YEAR_GENERATES_MONTH ->
                this(
                    "${ey}生${em}（年生月）",
                    "$ey generates $em ($yearWord → $monthWord)",
                    "$ey genera $em ($yearWord → $monthWord)",
                    "$ey genera $em ($yearWord → $monthWord)",
                )
            PillarRelation.MONTH_GENERATES_YEAR ->
                this(
                    "${em}生${ey}（月生年）",
                    "$em generates $ey ($monthWord → $yearWord)",
                    "$em genera $ey ($monthWord → $yearWord)",
                    "$em genera $ey ($monthWord → $yearWord)",
                )
            PillarRelation.YEAR_CONTROLS_MONTH ->
                this(
                    "${ey}剋${em}（年剋月）",
                    "$ey controls $em ($yearWord → $monthWord)",
                    "$ey domina $em ($yearWord → $monthWord)",
                    "$ey domina $em ($yearWord → $monthWord)",
                )
            PillarRelation.MONTH_CONTROLS_YEAR ->
                this(
                    "${em}剋${ey}（月剋年）",
                    "$em controls $ey ($monthWord → $yearWord)",
                    "$em domina $ey ($monthWord → $yearWord)",
                    "$em domina $ey ($monthWord → $yearWord)",
                )
        }
    }

    /** 好／正／壞的一句話解釋 */
    fun verdictHint(v: Verdict): String = when (v) {
        Verdict.GOOD -> this(
            "年月相生", "Year and Month generate",
            "el Año y el Mes se generan", "l'Anno e il Mese si generano",
        )
        Verdict.NEUTRAL -> this(
            "年月同五行", "Year and Month share an element",
            "el Año y el Mes comparten elemento",
            "l'Anno e il Mese condividono l'elemento",
        )
        Verdict.BAD -> this(
            "年月相剋", "Year and Month control",
            "el Año y el Mes se dominan", "l'Anno e il Mese si dominano",
        )
    }
}
