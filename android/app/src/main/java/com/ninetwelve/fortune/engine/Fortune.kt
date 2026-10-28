package com.ninetwelve.fortune.engine

/** 出生年月日（西曆）。 */
data class BirthDate(val year: Int, val month: Int, val day: Int) {

    val display: String get() = "${year}年${month}月${day}日"

    /**
     * 由年、月、日分別以生命靈數化約，得出本命三柱。
     * 例：2006年1月14日 → 2+0+0+6=8；1；1+4=5 → 8；1；5
     */
    val triple: Triple
        get() = Triple.of(Num.lifeDigit(year), Num.lifeDigit(month), Num.lifeDigit(day))
}

/**
 * 流年在盤上的錨定方式。
 *
 * 文件的範例（2006年1月14日生、靈數5）中，2017年落在首列的命宮 5宮，
 * 而出生年 2006 落在第二列 4宮。以下兩種解讀都能重現該範例，
 * 但推廣到其他出生年時結果不同，故開放切換。
 */
enum class YearAnchor {
    /**
     * 出生年落在盤的第二列（即命宮的下一個位置）；等同於命宮列 = 出生年 + 11。
     * 這與大運「出生年落在靈數的下一個位置」的規則一致，為預設。
     */
    BIRTH_DERIVED,

    /** 命宮列固定對應 2017 年，所有人共用同一條年份刻度。 */
    FIXED_2017;

    fun title(lang: Lang): String {
        val t = Txt(lang)
        return when (this) {
            BIRTH_DERIVED -> t(
                "依出生年（預設）", "From birth year (default)",
                "Según el año de nacimiento (predeterminado)",
                "Dall'anno di nascita (predefinito)",
            )
            FIXED_2017 -> t(
                "固定 2017 年錨點", "Fixed 2017 anchor",
                "Anclaje fijo en 2017",
                "Ancoraggio fisso al 2017",
            )
        }
    }

    fun detail(lang: Lang): String {
        val t = Txt(lang)
        return when (this) {
            BIRTH_DERIVED -> t(
                "出生年落在命宮的下一個位置，與大運的排法一致。",
                "The birth year sits in the position right after the Life Palace, matching how the Luck Pillars are laid out.",
                "El año de nacimiento ocupa la posición justo después del Palacio de Vida, igual que en la disposición de los Pilares de Suerte.",
                "L'anno di nascita occupa la posizione subito dopo il Palazzo della Vita, come nella disposizione dei Pilastri della Sorte.",
            )
            FIXED_2017 -> t(
                "不論出生年為何，命宮一律對應 2017 年。",
                "Regardless of birth year, the Life Palace always corresponds to 2017.",
                "Sea cual sea el año de nacimiento, el Palacio de Vida siempre corresponde a 2017.",
                "Qualunque sia l'anno di nascita, il Palazzo della Vita corrisponde sempre al 2017.",
            )
        }
    }
}

/** 一段大運。 */
data class LuckPeriod(
    val startYear: Int,
    val endYear: Int,
    /** 該大運取「起始年」的流年為其運勢。 */
    val row: PalaceRow,
) {
    val span: String get() = "$startYear – $endYear"
    val length: Int get() = endYear - startYear + 1

    fun contains(year: Int): Boolean = year in startYear..endYear
}

/** 大運十二方面中的一項。aspect 是第幾宮（1..12），也就是要用哪一宮的含義去讀。 */
data class LuckAspect(val aspect: Int, val row: PalaceRow)

/** 月運中的一列。 */
data class MonthRow(val month: Int, val row: PalaceRow)

/** 日運（白天／晚上）。 */
data class DayFortune(
    /** 白天所走的宮位（1..12）。 */
    val dayPalace: Int,
    /** 晚上所走的宮位（1..9）。 */
    val nightPalace: Int,
)

/** 一個人的完整命盤與各種運勢推算。 */
class Destiny(
    val birth: BirthDate,
    val anchor: YearAnchor = YearAnchor.BIRTH_DERIVED,
) {
    /** 本命三柱。 */
    val triple: Triple = birth.triple

    /** 命主靈數（1..9），也是本命盤首列的宮位。 */
    val lifeNumber: Int = triple.lifeNumber

    /** 本命十二宮盤。首列為命宮，宮位逆序，末列即本命三柱。 */
    val natalChart: List<PalaceRow> = ChartEngine.natalStyleChart(triple)

    // ── 流年 ──

    /** 某一年落在本命盤的第幾列（0..11）。年份以 12 年為週期循環。 */
    fun rowIndex(year: Int): Int {
        val offset = when (anchor) {
            // 出生年 → 第 1 列（索引 1），亦即命宮列對應出生年 + 11
            YearAnchor.BIRTH_DERIVED -> year - birth.year + 1
            // 2017 → 第 0 列
            YearAnchor.FIXED_2017 -> year - 2017
        }
        val m = offset % 12
        return if (m < 0) m + 12 else m
    }

    /** 某一年的流年。 */
    fun year(year: Int): PalaceRow = natalChart[rowIndex(year)]

    /** 連續數年的流年列表。 */
    fun years(from: Int, count: Int): List<Pair<Int, PalaceRow>> =
        (0 until count).map { (from + it) to year(from + it) }

    // ── 大運 ──

    /** 出生年在九宮循環中的位置（1..9）：靈數的下一個位置。 */
    val luckStartPosition: Int get() = Num.r9(lifeNumber + 1)

    /** 第一段大運自出生年起，走到九宮循環的第 9 位為止；其後每段固定九年。 */
    fun luckPeriods(count: Int = 10): List<LuckPeriod> {
        val result = mutableListOf<LuckPeriod>()
        val firstEnd = birth.year + (9 - luckStartPosition)
        result.add(
            LuckPeriod(
                startYear = birth.year,
                endYear = firstEnd,
                row = year(birth.year),
            )
        )
        var start = firstEnd + 1
        while (result.size < count) {
            result.add(LuckPeriod(startYear = start, endYear = start + 8, row = year(start)))
            start += 9
        }
        return result
    }

    /** 涵蓋指定年份的大運。 */
    fun luckPeriod(containingYear: Int): LuckPeriod {
        if (containingYear < birth.year) {
            // 出生前：往前推同樣的九年節奏
            var end = birth.year - 1
            var start = end - 8
            while (containingYear < start) {
                end = start - 1
                start = end - 8
            }
            return LuckPeriod(startYear = start, endYear = end, row = year(start))
        }
        val firstEnd = birth.year + (9 - luckStartPosition)
        if (containingYear <= firstEnd) {
            return LuckPeriod(startYear = birth.year, endYear = firstEnd, row = year(birth.year))
        }
        val n = (containingYear - firstEnd - 1) / 9
        val start = firstEnd + 1 + n * 9
        return LuckPeriod(startYear = start, endYear = start + 8, row = year(start))
    }

    // ── 月運 ──

    /**
     * 某年的月運盤。
     *
     * 取該年所屬大運的三柱與該年流年的三柱，年加年、月加月、日加日（十二進制）
     * 組成新的三柱，即為該年一月的盤；一月的宮位為流年宮位減一，其後宮位逆序、
     * 三柱每月加一。
     */
    /**
     * 某個大運裡的十二個方面。
     *
     * 以該大運「最後一年」的年運為第一宮，往下接滿十二宮；
     * 第 N 宮即以第 N 宮的含義去讀。
     */
    fun luckAspects(containingYear: Int): List<LuckAspect> {
        val period = luckPeriod(containingYear)
        val start = rowIndex(period.endYear)
        return (0 until 12).map { i ->
            LuckAspect(i + 1, natalChart[(start + i) % 12])
        }
    }

    /** 某一年的流年所引動的大運方面（該年所屬大運的十二方面中，因或果落在流年所走那一宮的各項）。 */
    fun triggeredAspects(y: Int): List<LuckAspect> {
        val palace = year(y).palace
        return luckAspects(y).filter {
            it.row.reading.cause == palace || it.row.reading.result == palace
        }
    }

    /** 某一段大運所引動的本命盤宮位（本命盤中，因或果落在大運所走那一宮的各列）。 */
    fun triggeredNatalRows(period: LuckPeriod): List<PalaceRow> =
        triggeredNatalRows(period.row.palace)

    /** 本命盤某一宮所引動的本命盤宮位（本命盤中，因或果落在那一宮的各列）。 */
    fun triggeredNatalRows(palace: Int): List<PalaceRow> =
        natalChart.filter { it.reading.cause == palace || it.reading.result == palace }

    /**
     * 被影響：大運所引動的某一本命宮位，再影響到那段大運十二方面裡的哪幾項
     * （十二方面中，因或果落在那一本命宮位的各項）。
     */
    fun affectedAspects(natalRow: PalaceRow, period: LuckPeriod): List<LuckAspect> {
        val palace = natalRow.palace
        return luckAspects(period.startYear).filter {
            it.row.reading.cause == palace || it.row.reading.result == palace
        }
    }

    /** 名字合盤：名字裡的每一個英文字母，依序對應到本命盤的一宮（不是英文字母的略過）。 */
    fun nameRows(name: String): List<PalaceRow> =
        name.lowercase().mapNotNull { c ->
            if (c !in 'a'..'z') {
                null
            } else {
                val palace = Num.r12(lifeNumber + (c - 'a' + 1))
                natalChart.first { it.palace == palace }
            }
        }

    fun monthChart(y: Int): List<MonthRow> {
        val luck = luckPeriod(y).row
        val flow = year(y)
        val base = luck.triple + flow.triple
        val firstPalace = Num.r12(flow.palace - 1)
        return ChartEngine.chart(startPalace = firstPalace, firstTriple = base)
            .mapIndexed { i, row -> MonthRow(month = i + 1, row = row) }
    }

    fun month(m: Int, y: Int): MonthRow = monthChart(y)[Num.r12(m) - 1]

    // ── 日運 ──

    /**
     * 某月某日的白天與晚上日運。
     *
     * 白天（十二進制）：靈數加月份得 a；靈數再加 a 得 b；
     * b 再加上月份與日期的各位數字，化約至 1..12。
     * 晚上（九進制）：靈數直接加上月份與日期的各位數字，化約至 1..9。
     */
    fun dayFortune(m: Int, d: Int): DayFortune {
        val a = Num.r12(lifeNumber + m)
        val b = Num.r12(lifeNumber + a)
        val sum = Num.digitSum(m) + Num.digitSum(d)
        return DayFortune(
            dayPalace = Num.r12(b + sum),
            nightPalace = Num.r9(lifeNumber + sum),
        )
    }

    // ── 合盤 ──

    /** 與另一個人合盤：兩盤三柱相加（十二進制），再依本命盤方式排出十二宮。 */
    fun synastry(other: Destiny): Synastry = Synastry(this, other)
}

/** 合盤結果。 */
class Synastry(val a: Destiny, val b: Destiny) {
    val triple: Triple = a.triple + b.triple
    val lifeNumber: Int = triple.lifeNumber
    val chart: List<PalaceRow> = ChartEngine.natalStyleChart(triple)
}
