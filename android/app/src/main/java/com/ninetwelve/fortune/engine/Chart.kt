package com.ninetwelve.fortune.engine

/** 三柱：年柱、月柱、日柱，每柱為 1..12。 */
data class Triple(val year: Int, val month: Int, val day: Int) {

    /** 三柱同步加上同一個數（十二進制）。 */
    fun advancedBy(n: Int): Triple = of(year + n, month + n, day + n)

    /** 兩盤相加：年加年、月加月、日加日（十二進制）。用於合盤與月運。 */
    operator fun plus(other: Triple): Triple =
        of(year + other.year, month + other.month, day + other.day)

    /** 此三柱的靈數：三柱相加後以九進制化約。 */
    val lifeNumber: Int get() = Num.lifeDigit(year + month + day)

    val display: String get() = "${year}；${month}；$day"

    companion object {
        /** 建構時一律先做十二進制化約，與 iOS 版的 init 行為相同。 */
        fun of(year: Int, month: Int, day: Int) =
            Triple(Num.r12(year), Num.r12(month), Num.r12(day))
    }
}

/** 年柱與月柱的五行關係所定出的吉凶。 */
enum class Verdict(val zh: String) {
    GOOD("好"),      // 年月相生
    NEUTRAL("正"),   // 年月同五行
    BAD("壞");       // 年月相剋

    /** 各語言採用能對應「相生／同／相剋」語感的譯法。 */
    fun name(lang: Lang): String = when (lang) {
        Lang.ZH -> zh
        Lang.EN -> when (this) {
            GOOD -> "Favorable"; NEUTRAL -> "Aligned"; BAD -> "Adverse"
        }
        Lang.ES -> when (this) {
            GOOD -> "Favorable"; NEUTRAL -> "Alineado"; BAD -> "Adverso"
        }
        Lang.IT -> when (this) {
            GOOD -> "Favorevole"; NEUTRAL -> "Allineato"; BAD -> "Avverso"
        }
    }

    /** 空間很小時用的符號，不分語言。 */
    val mark: String
        get() = when (this) {
            GOOD -> "+"
            NEUTRAL -> "="
            BAD -> "−"
        }
}

/** 年柱與月柱之間的五行關係。 */
enum class PillarRelation {
    SAME,
    YEAR_GENERATES_MONTH,
    MONTH_GENERATES_YEAR,
    YEAR_CONTROLS_MONTH,
    MONTH_CONTROLS_YEAR,
}

/** 一組三柱的判讀結果：`好 / 正 / 壞` + 果宮 + 因宮。 */
data class Reading(
    val verdict: Verdict,
    /** 「果」的宮位數（好X／正X／壞X 的 X）。 */
    val result: Int,
    /** 「因」的宮位數（因Y 的 Y）。 */
    val cause: Int,
    /** 年柱五行 */
    val yearElement: Element,
    /** 月柱五行 */
    val monthElement: Element,
    /** 年月柱的五行關係 */
    val relation: PillarRelation,
) {
    fun text(lang: Lang): String = when (lang) {
        Lang.ZH -> "${verdict.zh}${result}因$cause"
        Lang.EN -> "${verdict.name(Lang.EN)} $result from $cause"
        Lang.ES -> "${verdict.name(Lang.ES)} $result de $cause"
        Lang.IT -> "${verdict.name(Lang.IT)} $result da $cause"
    }

    /** 中文的標準寫法，也是測試比對的依據。 */
    val display: String get() = text(Lang.ZH)
}

/** 命盤中的一列：宮位 + 三柱 + 判讀。 */
data class PalaceRow(
    /** 在盤中的列序（0 為首列）。 */
    val index: Int,
    /** 宮位 1..12。 */
    val palace: Int,
    val triple: Triple,
    val reading: Reading,
) {
    val display: String get() = "${palace}宮 ${triple.display} ${reading.display}"
}

object ChartEngine {

    /**
     * 判讀一組三柱。
     *
     * 規則（取自命盤方法）：
     * 1. 看年柱與月柱的五行關係。
     * 2. 相剋 →「壞」：被剋的一柱加日柱得「果」，去剋的一柱加日柱得「因」。
     * 3. 相生 →「好」：受生的一柱加日柱得「果」，去生的一柱加日柱得「因」。
     * 4. 相同 →「正」：年月同五行會強化日柱，果即日柱本身；
     *    年柱加日柱、月柱加日柱，兩者再相加得「因」。
     * 全部加法皆為十二進制。
     */
    fun read(t: Triple): Reading {
        val ey = Element.of(t.year)
        val em = Element.of(t.month)

        val yearPlusDay = Num.r12(t.year + t.day)
        val monthPlusDay = Num.r12(t.month + t.day)

        if (ey == em) {
            return Reading(
                verdict = Verdict.NEUTRAL,
                result = t.day,
                cause = Num.r12(yearPlusDay + monthPlusDay),
                yearElement = ey,
                monthElement = em,
                relation = PillarRelation.SAME,
            )
        }
        if (ey.generates == em) {
            // 年生月：月柱受生
            return Reading(
                verdict = Verdict.GOOD,
                result = monthPlusDay,
                cause = yearPlusDay,
                yearElement = ey,
                monthElement = em,
                relation = PillarRelation.YEAR_GENERATES_MONTH,
            )
        }
        if (em.generates == ey) {
            // 月生年：年柱受生
            return Reading(
                verdict = Verdict.GOOD,
                result = yearPlusDay,
                cause = monthPlusDay,
                yearElement = ey,
                monthElement = em,
                relation = PillarRelation.MONTH_GENERATES_YEAR,
            )
        }
        if (ey.overcomes == em) {
            // 年剋月：月柱被剋
            return Reading(
                verdict = Verdict.BAD,
                result = monthPlusDay,
                cause = yearPlusDay,
                yearElement = ey,
                monthElement = em,
                relation = PillarRelation.YEAR_CONTROLS_MONTH,
            )
        }
        // 月剋年：年柱被剋
        return Reading(
            verdict = Verdict.BAD,
            result = yearPlusDay,
            cause = monthPlusDay,
            yearElement = ey,
            monthElement = em,
            relation = PillarRelation.MONTH_CONTROLS_YEAR,
        )
    }

    /**
     * 以 [startPalace] 為首列、宮位逆序排列的十二列盤，
     * 三柱由 [firstTriple] 起每列加一（十二進制）。
     */
    fun chart(startPalace: Int, firstTriple: Triple): List<PalaceRow> =
        (0 until 12).map { k ->
            val palace = Num.r12(startPalace - k)
            val t = firstTriple.advancedBy(k)
            PalaceRow(index = k, palace = palace, triple = t, reading = read(t))
        }

    /**
     * 本命／合盤型的盤：首列落在靈數宮，三柱由「本命三柱 + 1」起算，
     * 因此末列會剛好回到本命三柱本身。
     */
    fun natalStyleChart(triple: Triple): List<PalaceRow> =
        chart(startPalace = triple.lifeNumber, firstTriple = triple.advancedBy(1))
}
