package com.ninetwelve.fortune

import com.ninetwelve.fortune.engine.BirthDate
import com.ninetwelve.fortune.engine.ChartEngine
import com.ninetwelve.fortune.engine.Destiny
import com.ninetwelve.fortune.engine.Element
import com.ninetwelve.fortune.engine.Num
import com.ninetwelve.fortune.engine.Palace
import com.ninetwelve.fortune.engine.Lang
import com.ninetwelve.fortune.engine.PalaceRow
import com.ninetwelve.fortune.engine.Triple
import com.ninetwelve.fortune.engine.Verdict
import com.ninetwelve.fortune.engine.YearAnchor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 以原始文件（九型十二宮算命系統方法）中的每一個範例作為測試依據。
 * 與 iOS 版 `NineTwelveTests/EngineTests.swift` 是同一組案例，
 * 兩個平台算出來的結果必須一模一樣。
 */
class EngineTest {

    private fun line(row: PalaceRow): String =
        "${row.palace}宮 ${row.triple.year};${row.triple.month};${row.triple.day} ${row.reading.display}"

    private fun assertChart(rows: List<PalaceRow>, expected: List<String>) {
        assertEquals(expected.size, rows.size)
        rows.zip(expected).forEach { (row, want) -> assertEquals(want, line(row)) }
    }

    // ── 一、生命靈數化約 ──

    @Test
    fun lifeDigitReduction() {
        assertEquals(8, Num.lifeDigit(2006))   // 2+0+0+6
        assertEquals(1, Num.lifeDigit(1))
        assertEquals(5, Num.lifeDigit(14))     // 1+4
        assertEquals(7, Num.lifeDigit(1996))   // 1+9+9+6=25 → 7
        assertEquals(3, Num.lifeDigit(12))     // 1+2
        assertEquals(1, Num.lifeDigit(19))     // 1+9=10 → 1
        assertEquals(5, Num.lifeDigit(23))     // 2+3
    }

    @Test
    fun natalTripleAndLifeNumber() {
        val b = BirthDate(2006, 1, 14)
        assertEquals(Triple.of(8, 1, 5), b.triple)
        assertEquals(5, b.triple.lifeNumber)

        assertEquals(Triple.of(7, 3, 1), BirthDate(1996, 12, 19).triple)
        assertEquals(Triple.of(9, 1, 5), BirthDate(2007, 1, 23).triple)
    }

    @Test
    fun radixReduction() {
        assertEquals(1, Num.r12(13))
        assertEquals(3, Num.r12(15))
        assertEquals(12, Num.r12(12))
        assertEquals(12, Num.r12(24))
        assertEquals(8, Num.r12(20))
        assertEquals(3, Num.r9(21))
        assertEquals(5, Num.r9(14))
        assertEquals(9, Num.r9(18))
    }

    // ── 二、十二宮五行 ──

    @Test
    fun palaceElements() {
        assertEquals(listOf(Element.METAL, Element.METAL), listOf(2, 7).map { Element.of(it) })
        assertEquals(listOf(Element.WOOD, Element.WOOD), listOf(9, 12).map { Element.of(it) })
        assertEquals(
            listOf(Element.WATER, Element.WATER, Element.WATER),
            listOf(3, 4, 6).map { Element.of(it) },
        )
        assertEquals(
            listOf(Element.FIRE, Element.FIRE, Element.FIRE),
            listOf(1, 5, 8).map { Element.of(it) },
        )
        assertEquals(listOf(Element.EARTH, Element.EARTH), listOf(10, 11).map { Element.of(it) })
    }

    // ── 三、本命盤（文件第 1–2 頁） ──

    @Test
    fun natalChart() {
        val d = Destiny(BirthDate(2006, 1, 14))
        assertEquals(5, d.lifeNumber)
        assertChart(
            d.natalChart,
            listOf(
                "5宮 9;2;6 壞3因8",
                "4宮 10;3;7 壞10因5",
                "3宮 11;4;8 壞12因7",
                "2宮 12;5;9 好2因9",
                "1宮 1;6;10 壞11因4",
                "12宮 2;7;11 正11因7",
                "11宮 3;8;12 壞8因3",
                "10宮 4;9;1 好10因5",
                "9宮 5;10;2 好12因7",
                "8宮 6;11;3 壞9因2",
                "7宮 7;12;4 壞4因11",
                "6宮 8;1;5 正5因7",
            ),
        )
        // 末列必為本命三柱
        assertEquals(d.triple, d.natalChart.last().triple)
    }

    /** 文件中逐字說明的三個判讀例子。 */
    @Test
    fun workedReadings() {
        val r1 = ChartEngine.read(Triple.of(9, 2, 6))
        assertEquals(Verdict.BAD, r1.verdict)
        assertEquals(3, r1.result)
        assertEquals(8, r1.cause)

        val r2 = ChartEngine.read(Triple.of(4, 9, 1))
        assertEquals(Verdict.GOOD, r2.verdict)
        assertEquals(10, r2.result)
        assertEquals(5, r2.cause)

        val r3 = ChartEngine.read(Triple.of(2, 7, 11))
        assertEquals(Verdict.NEUTRAL, r3.verdict)
        assertEquals(11, r3.result)
        assertEquals(7, r3.cause)
    }

    // ── 四、流年（文件第 2 頁） ──

    @Test
    fun yearlyFortune() {
        val d = Destiny(BirthDate(2006, 1, 14))
        val expected = mapOf(
            2017 to 5, 2018 to 4, 2019 to 3, 2020 to 2, 2021 to 1, 2022 to 12,
            2023 to 11, 2024 to 10, 2025 to 9, 2026 to 8, 2027 to 7, 2028 to 6,
        )
        expected.forEach { (year, palace) ->
            assertEquals("${year}年", palace, d.year(year).palace)
        }
        // 出生年 2006 走 4宮 壞10因5
        assertEquals("4宮 10;3;7 壞10因5", line(d.year(2006)))
        // 12 年一循環
        assertEquals(d.year(2017), d.year(2029))
        assertEquals(d.year(2017), d.year(2005))
        assertEquals(d.year(2023), d.year(2035))
    }

    @Test
    fun fixedAnchorAlsoMatchesDocument() {
        val d = Destiny(BirthDate(2006, 1, 14), YearAnchor.FIXED_2017)
        assertEquals(5, d.year(2017).palace)
        assertEquals(8, d.year(2026).palace)
        assertEquals("4宮 10;3;7 壞10因5", line(d.year(2006)))
    }

    // ── 五、大運（文件第 2–3 頁） ──

    @Test
    fun luckPeriods() {
        val d = Destiny(BirthDate(2006, 1, 14))
        assertEquals(6, d.luckStartPosition)

        val periods = d.luckPeriods(4)
        assertEquals(
            listOf(listOf(2006, 2009), listOf(2010, 2018), listOf(2019, 2027), listOf(2028, 2036)),
            periods.map { listOf(it.startYear, it.endYear) },
        )
        assertEquals(
            listOf(
                "4宮 10;3;7 壞10因5",
                "12宮 2;7;11 正11因7",
                "3宮 11;4;8 壞12因7",
                "6宮 8;1;5 正5因7",
            ),
            periods.map { line(it.row) },
        )

        assertEquals(2019, d.luckPeriod(2026).startYear)
        assertEquals(2027, d.luckPeriod(2026).endYear)
        assertEquals(2006, d.luckPeriod(2008).startYear)
        assertEquals(2028, d.luckPeriod(2036).startYear)
    }

    /** 大運十二方面：以該段最後一年的年運為第一宮，往下接滿十二宮。 */
    @Test
    fun luckAspects() {
        val d = Destiny(BirthDate(2006, 1, 14))
        val aspects = d.luckAspects(2026)          // 2019–2027，末年 2027

        assertEquals((1..12).toList(), aspects.map { it.aspect })
        assertEquals(
            listOf(
                "7宮 7;12;4 壞4因11",
                "6宮 8;1;5 正5因7",
                "5宮 9;2;6 壞3因8",
                "4宮 10;3;7 壞10因5",
                "3宮 11;4;8 壞12因7",
                "2宮 12;5;9 好2因9",
                "1宮 1;6;10 壞11因4",
                "12宮 2;7;11 正11因7",
                "11宮 3;8;12 壞8因3",
                "10宮 4;9;1 好10因5",
                "9宮 5;10;2 好12因7",
                "8宮 6;11;3 壞9因2",
            ),
            aspects.map { line(it.row) },
        )

        // 第一宮就是該段最後一年的流年
        assertEquals(line(d.year(2027)), line(aspects[0].row))
        // 同一段大運裡，任一年問出來的結果都一樣
        assertEquals(aspects.map { line(it.row) }, d.luckAspects(2019).map { line(it.row) })
    }

    /**
     * 引動：流年走幾宮，引動所屬大運十二方面裡因落在那一宮的各項；
     * 大運走幾宮，引動本命盤裡因落在那一宮的各列。
     */
    @Test
    fun triggers() {
        val d = Destiny(BirthDate(2006, 1, 14))
        fun asp(y: Int) = d.triggeredAspects(y).map { "${it.aspect} ${it.row.reading.display}" }
        // 作者的例子：因或果落在流年所走那一宮
        assertEquals(listOf("6 好2因9", "12 壞9因2"), asp(2025))
        assertEquals(listOf("3 壞3因8", "9 壞8因3"), asp(2026))
        assertEquals(listOf("2 正5因7", "5 壞12因7", "8 正11因7", "11 好12因7"), asp(2027))
        assertEquals(listOf("1 好10因5", "5 正5因7", "7 壞10因5"), asp(2029))

        fun natal(y: Int) = d.triggeredNatalRows(d.luckPeriod(y)).map { "${it.palace} ${it.reading.display}" }
        // 作者的例子：大運 3宮 壞12因7 → 本命 5宮 壞3因8、11宮 壞8因3
        assertEquals(listOf("5 壞3因8", "11 壞8因3"), natal(2026))
        assertEquals(listOf("3 壞12因7", "9 好12因7"), natal(2012))
        assertEquals(emptyList<String>(), natal(2030))

        // 作者的例子：本命 9宮 → 本命 2宮 好2因9、8宮 壞9因2
        fun own(p: Int) = d.triggeredNatalRows(p).map { "${it.palace} ${it.reading.display}" }
        assertEquals(listOf("2 好2因9", "8 壞9因2"), own(9))
        assertEquals(emptyList<String>(), own(1))

        // 作者的例子：大運 2019–2027 引動本命 5宮、11宮，再各自影響這段大運的十二方面
        val p = d.luckPeriod(2026)
        fun affected(palace: Int): List<String> {
            val row = d.triggeredNatalRows(p).first { it.palace == palace }
            return d.affectedAspects(row, p).map { "${it.aspect} ${it.row.reading.display}" }
        }
        assertEquals(listOf("2 正5因7", "4 壞10因5", "10 好10因5"), affected(5))
        assertEquals(listOf("1 壞4因11", "7 壞11因4", "8 正11因7"), affected(11))
    }

    /** 摘要接在宮位簡稱底下顯示，不可以重複簡稱本身。 */
    @Test
    fun briefNeverRepeatsShortName() {
        for (lang in Lang.entries) {
            for (palace in 1..12) {
                val name = Palace.shortName(palace, lang)
                val items = Palace.keywords(palace, lang).filter { it != name }.take(4)
                assertEquals("$lang 第${palace}宮的摘要不是四個", 4, items.size)
                assertTrue("$lang 第${palace}宮的摘要重複了簡稱 $name", !items.contains(name))
                val sep = if (lang == Lang.ZH) "、" else ", "
                assertEquals(items.joinToString(sep), Palace.brief(palace, lang))
            }
        }
    }

    // ── 六、日運（文件第 3 頁） ──

    @Test
    fun dayFortune() {
        val d = Destiny(BirthDate(2006, 1, 14))   // 靈數 5
        val f = d.dayFortune(8, 17)
        assertEquals(10, f.dayPalace)
        assertEquals(3, f.nightPalace)
    }

    @Test
    fun dayFortuneLifeNumberSeven() {
        // 文件第二個例子：靈數 7、3月4日 → 白天 12宮、晚上 5宮
        val d = Destiny(BirthDate(2005, 1, 1))
        assertEquals(Triple.of(7, 1, 1), d.triple)

        // 直接驗算公式本身
        val life = 7
        val a = Num.r12(life + 3)
        val b = Num.r12(life + a)
        assertEquals(10, a)
        assertEquals(12, Num.r12(b + Num.digitSum(3) + Num.digitSum(4)))
        assertEquals(5, Num.r9(life + Num.digitSum(3) + Num.digitSum(4)))
    }

    // ── 七、月運（文件第 3 頁） ──

    @Test
    fun monthChart2026() {
        val d = Destiny(BirthDate(2006, 1, 14))
        val months = d.monthChart(2026)
        assertEquals(Triple.of(5, 3, 11), months.first().row.triple)
        assertEquals(7, months.first().row.palace)
        assertEquals((1..12).toList(), months.map { it.month })

        assertChart(
            months.map { it.row },
            listOf(
                "7宮 5;3;11 壞4因2",
                "6宮 6;4;12 正12因10",
                "5宮 7;5;1 壞8因6",
                "4宮 8;6;2 壞10因8",
                "3宮 9;7;3 壞12因10",
                "2宮 10;8;4 好2因12",
                "1宮 11;9;5 壞4因2",
                "12宮 12;10;6 壞4因6",
                "11宮 1;11;7 好6因8",
                "10宮 2;12;8 壞8因10",
                "9宮 3;1;9 壞10因12",
                "8宮 4;2;10 好2因12",
            ),
        )
    }

    // ── 八、合盤（文件第 4 頁） ──

    @Test
    fun synastry() {
        val a = Destiny(BirthDate(2006, 1, 14))
        val b = Destiny(BirthDate(2007, 1, 23))
        val s = a.synastry(b)

        assertEquals(Triple.of(5, 2, 10), s.triple)
        assertEquals(8, s.lifeNumber)

        assertChart(
            s.chart,
            listOf(
                "8宮 6;3;11 正11因7",
                "7宮 7;4;12 好4因7",
                "6宮 8;5;1 正1因3",
                "5宮 9;6;2 好11因8",
                "4宮 10;7;3 好10因1",
                "3宮 11;8;4 好3因12",
                "2宮 12;9;5 正5因7",
                "1宮 1;10;6 好4因7",
                "12宮 2;11;7 好9因6",
                "11宮 3;12;8 好8因11",
                "10宮 4;1;9 壞10因1",
                // 文件此列原寫「因7」，作者已確認為筆誤：火剋金，去剋的 5+10=15→3
                "9宮 5;2;10 壞12因3",
            ),
        )
    }

    // ── 一致性檢查 ──

    /** 任何盤的每一列，果與因都必須落在 1..12。 */
    @Test
    fun allReadingsInRange() {
        for (y in 1..12) for (m in 1..12) for (d in 1..12) {
            val r = ChartEngine.read(Triple.of(y, m, d))
            assertTrue("$y;$m;$d", r.result in 1..12)
            assertTrue("$y;$m;$d", r.cause in 1..12)
        }
    }

    /** 任何出生日期都能排出十二列不重複宮位的盤。 */
    @Test
    fun chartsAreWellFormedForManyBirthdays() {
        for (year in 1900..2100 step 7) {
            for (month in listOf(1, 2, 6, 9, 12)) {
                val d = Destiny(BirthDate(year, month, 28))
                assertEquals(12, d.natalChart.map { it.palace }.toSet().size)
                assertEquals(d.lifeNumber, d.natalChart.first().palace)
                assertEquals(d.triple, d.natalChart.last().triple)
                assertEquals(12, d.monthChart(year + 20).map { it.row.palace }.toSet().size)
            }
        }
    }

    /** 流年必為 12 年週期，大運必連續且不重疊。 */
    @Test
    fun periodicityAndContinuity() {
        val d = Destiny(BirthDate(1988, 7, 3))
        for (y in 1980..2060) {
            assertEquals(d.year(y), d.year(y + 12))
        }
        val ps = d.luckPeriods(12)
        ps.zipWithNext().forEach { (a, b) -> assertEquals(a.endYear + 1, b.startYear) }
        ps.forEach { p ->
            for (y in p.startYear..p.endYear) {
                assertEquals(p.startYear, d.luckPeriod(y).startYear)
            }
        }
    }
}
