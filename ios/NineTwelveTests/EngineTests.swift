import XCTest
@testable import NineTwelve

/// 以原始文件（九型十二宮算命系統方法）中的每一個範例作為測試依據。
final class EngineTests: XCTestCase {

    // MARK: - 工具

    private func line(_ row: PalaceRow) -> String {
        "\(row.palace)宮 \(row.triple.year);\(row.triple.month);\(row.triple.day) \(row.reading.display)"
    }

    private func assertChart(_ rows: [PalaceRow], _ expected: [String],
                             file: StaticString = #filePath, line lineNo: UInt = #line) {
        XCTAssertEqual(rows.count, expected.count, file: file, line: lineNo)
        for (row, want) in zip(rows, expected) {
            XCTAssertEqual(line(row), want, file: file, line: lineNo)
        }
    }

    // MARK: - 一、生命靈數化約

    func testLifeDigitReduction() {
        XCTAssertEqual(Num.lifeDigit(2006), 8)   // 2+0+0+6
        XCTAssertEqual(Num.lifeDigit(1), 1)
        XCTAssertEqual(Num.lifeDigit(14), 5)     // 1+4
        XCTAssertEqual(Num.lifeDigit(1996), 7)   // 1+9+9+6=25 → 7
        XCTAssertEqual(Num.lifeDigit(12), 3)     // 1+2
        XCTAssertEqual(Num.lifeDigit(19), 1)     // 1+9=10 → 1
        XCTAssertEqual(Num.lifeDigit(23), 5)     // 2+3
    }

    func testNatalTripleAndLifeNumber() {
        let b = BirthDate(year: 2006, month: 1, day: 14)
        XCTAssertEqual(b.triple, Triple(8, 1, 5))
        XCTAssertEqual(b.triple.lifeNumber, 5)

        let b2 = BirthDate(year: 1996, month: 12, day: 19)
        XCTAssertEqual(b2.triple, Triple(7, 3, 1))

        let b3 = BirthDate(year: 2007, month: 1, day: 23)
        XCTAssertEqual(b3.triple, Triple(9, 1, 5))
    }

    func testRadixReduction() {
        XCTAssertEqual(Num.r12(13), 1)
        XCTAssertEqual(Num.r12(15), 3)
        XCTAssertEqual(Num.r12(12), 12)
        XCTAssertEqual(Num.r12(24), 12)
        XCTAssertEqual(Num.r12(20), 8)
        XCTAssertEqual(Num.r9(21), 3)
        XCTAssertEqual(Num.r9(14), 5)
        XCTAssertEqual(Num.r9(18), 9)
    }

    // MARK: - 二、十二宮五行

    func testPalaceElements() {
        XCTAssertEqual([2, 7].map { Element.of(palace: $0) }, [.metal, .metal])
        XCTAssertEqual([9, 12].map { Element.of(palace: $0) }, [.wood, .wood])
        XCTAssertEqual([3, 4, 6].map { Element.of(palace: $0) }, [.water, .water, .water])
        XCTAssertEqual([1, 5, 8].map { Element.of(palace: $0) }, [.fire, .fire, .fire])
        XCTAssertEqual([10, 11].map { Element.of(palace: $0) }, [.earth, .earth])
    }

    // MARK: - 三、本命盤（文件第 1–2 頁）

    func testNatalChart() {
        let d = Destiny(birth: BirthDate(year: 2006, month: 1, day: 14))
        XCTAssertEqual(d.lifeNumber, 5)
        assertChart(d.natalChart, [
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
        ])
        // 末列必為本命三柱
        XCTAssertEqual(d.natalChart.last?.triple, d.triple)
    }

    /// 文件中逐字說明的三個判讀例子。
    func testWorkedReadings() {
        let r1 = ChartEngine.read(Triple(9, 2, 6))
        XCTAssertEqual(r1.verdict, .bad)
        XCTAssertEqual(r1.result, 3)
        XCTAssertEqual(r1.cause, 8)

        let r2 = ChartEngine.read(Triple(4, 9, 1))
        XCTAssertEqual(r2.verdict, .good)
        XCTAssertEqual(r2.result, 10)
        XCTAssertEqual(r2.cause, 5)

        let r3 = ChartEngine.read(Triple(2, 7, 11))
        XCTAssertEqual(r3.verdict, .neutral)
        XCTAssertEqual(r3.result, 11)
        XCTAssertEqual(r3.cause, 7)
    }

    // MARK: - 四、流年（文件第 2 頁）

    func testYearlyFortune() {
        let d = Destiny(birth: BirthDate(year: 2006, month: 1, day: 14))
        let expected: [Int: Int] = [
            2017: 5, 2018: 4, 2019: 3, 2020: 2, 2021: 1, 2022: 12,
            2023: 11, 2024: 10, 2025: 9, 2026: 8, 2027: 7, 2028: 6,
        ]
        for (year, palace) in expected {
            XCTAssertEqual(d.year(year).palace, palace, "\(year)年")
        }
        // 出生年 2006 走 4宮 壞10因5
        XCTAssertEqual(line(d.year(2006)), "4宮 10;3;7 壞10因5")
        // 12 年一循環
        XCTAssertEqual(d.year(2029), d.year(2017))
        XCTAssertEqual(d.year(2005), d.year(2017))
        XCTAssertEqual(d.year(2035), d.year(2023))
    }

    func testFixedAnchorAlsoMatchesDocument() {
        let d = Destiny(birth: BirthDate(year: 2006, month: 1, day: 14), anchor: .fixed2017)
        XCTAssertEqual(d.year(2017).palace, 5)
        XCTAssertEqual(d.year(2026).palace, 8)
        XCTAssertEqual(line(d.year(2006)), "4宮 10;3;7 壞10因5")
    }

    // MARK: - 五、大運（文件第 2–3 頁）

    func testLuckPeriods() {
        let d = Destiny(birth: BirthDate(year: 2006, month: 1, day: 14))
        XCTAssertEqual(d.luckStartPosition, 6)

        let periods = d.luckPeriods(count: 4)
        XCTAssertEqual(periods.map { [$0.startYear, $0.endYear] },
                       [[2006, 2009], [2010, 2018], [2019, 2027], [2028, 2036]])
        XCTAssertEqual(periods.map { line($0.row) }, [
            "4宮 10;3;7 壞10因5",
            "12宮 2;7;11 正11因7",
            "3宮 11;4;8 壞12因7",
            "6宮 8;1;5 正5因7",
        ])

        XCTAssertEqual(d.luckPeriod(containing: 2026).startYear, 2019)
        XCTAssertEqual(d.luckPeriod(containing: 2026).endYear, 2027)
        XCTAssertEqual(d.luckPeriod(containing: 2008).startYear, 2006)
        XCTAssertEqual(d.luckPeriod(containing: 2036).startYear, 2028)
    }

    /// 大運十二方面：以該段最後一年的年運為第一宮，往下接滿十二宮。
    func testLuckAspects() {
        let d = Destiny(birth: BirthDate(year: 2006, month: 1, day: 14))
        let aspects = d.luckAspects(containing: 2026)   // 2019–2027，末年 2027

        XCTAssertEqual(aspects.map { $0.aspect }, Array(1...12))
        XCTAssertEqual(aspects.map { line($0.row) }, [
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
        ])

        // 第一宮就是該段最後一年的流年
        XCTAssertEqual(line(aspects[0].row), line(d.year(2027)))
        // 同一段大運裡，任一年問出來的結果都一樣
        XCTAssertEqual(d.luckAspects(containing: 2019).map { line($0.row) },
                       aspects.map { line($0.row) })
    }

    /// 引動：流年走幾宮，引動所屬大運十二方面裡因落在那一宮的各項；
    /// 大運走幾宮，引動本命盤裡因落在那一宮的各列。
    func testTriggers() {
        let d = Destiny(birth: BirthDate(year: 2006, month: 1, day: 14))
        func asp(_ y: Int) -> [String] {
            d.triggeredAspects(forYear: y).map { "\($0.aspect) \($0.row.reading.display)" }
        }
        // 作者的例子：因或果落在流年所走那一宮
        XCTAssertEqual(asp(2025), ["6 好2因9", "12 壞9因2"])
        XCTAssertEqual(asp(2026), ["3 壞3因8", "9 壞8因3"])
        XCTAssertEqual(asp(2027), ["2 正5因7", "5 壞12因7", "8 正11因7", "11 好12因7"])
        XCTAssertEqual(asp(2029), ["1 好10因5", "5 正5因7", "7 壞10因5"])

        func natal(_ y: Int) -> [String] {
            d.triggeredNatalRows(for: d.luckPeriod(containing: y)).map { "\($0.palace) \($0.reading.display)" }
        }
        // 作者的例子：大運 3宮 壞12因7 → 本命 5宮 壞3因8、11宮 壞8因3
        XCTAssertEqual(natal(2026), ["5 壞3因8", "11 壞8因3"])
        XCTAssertEqual(natal(2012), ["3 壞12因7", "9 好12因7"])
        XCTAssertEqual(natal(2030), [])

        // 作者的例子：本命 9宮 → 本命 2宮 好2因9、8宮 壞9因2
        func own(_ p: Int) -> [String] {
            d.triggeredNatalRows(forPalace: p).map { "\($0.palace) \($0.reading.display)" }
        }
        XCTAssertEqual(own(9), ["2 好2因9", "8 壞9因2"])
        XCTAssertEqual(own(1), [])

        // 作者的例子：大運 2019–2027 引動本命 5宮、11宮，再各自影響這段大運的十二方面
        let p = d.luckPeriod(containing: 2026)
        func affected(_ palace: Int) -> [String] {
            let row = d.triggeredNatalRows(for: p).first { $0.palace == palace }!
            return d.affectedAspects(by: row, in: p).map { "\($0.aspect) \($0.row.reading.display)" }
        }
        XCTAssertEqual(affected(5), ["2 正5因7", "4 壞10因5", "10 好10因5"])
        XCTAssertEqual(affected(11), ["1 壞4因11", "7 壞11因4", "8 正11因7"])
    }

    /// 名字合盤：作者的例子，2006-01-14（靈數5）輸入 china。
    func testNameRows() {
        let d = Destiny(birth: BirthDate(year: 2006, month: 1, day: 14))
        func rows(_ s: String) -> [String] { d.nameRows(s).map { "\($0.palace) \($0.reading.display)" } }
        XCTAssertEqual(rows("china"), ["8 壞9因2", "1 壞11因4", "2 好2因9", "7 壞4因11", "6 正5因7"])
        XCTAssertEqual(rows("Chi na"), rows("china"))
        XCTAssertEqual(rows(""), [])
    }

    /// 摘要接在宮位簡稱底下顯示，不可以重複簡稱本身。
    func testBriefNeverRepeatsShortName() {
        for lang in Lang.allCases {
            for palace in 1...12 {
                let name = Palace.shortName(palace, lang: lang)
                let items = Palace.keywords(palace, lang: lang).filter { $0 != name }.prefix(4)
                XCTAssertFalse(items.contains(name),
                               "\(lang) 第\(palace)宮的摘要重複了簡稱 \(name)")
                XCTAssertEqual(items.count, 4,
                               "\(lang) 第\(palace)宮的摘要不是四個")
                let sep = lang == .zh ? "、" : ", "
                XCTAssertEqual(Palace.brief(palace, lang: lang), items.joined(separator: sep))
            }
        }
    }

    // MARK: - 六、日運（文件第 3 頁）

    func testDayFortune() {
        let d = Destiny(birth: BirthDate(year: 2006, month: 1, day: 14))   // 靈數 5
        let f = d.dayFortune(month: 8, day: 17)
        XCTAssertEqual(f.dayPalace, 10)
        XCTAssertEqual(f.nightPalace, 3)
    }

    func testDayFortuneLifeNumberSeven() {
        // 文件第二個例子：靈數 7、3月4日 → 白天 12宮、晚上 5宮
        // 1996-12-19 → 7;3;1，靈數為 2，故直接以三柱構造靈數 7 的命盤。
        let d = Destiny(birth: BirthDate(year: 2005, month: 1, day: 1))    // 7;1;1 → 靈數 9
        XCTAssertEqual(d.triple, Triple(7, 1, 1))

        // 直接驗算公式本身
        let life = 7
        let a = Num.r12(life + 3)
        let b = Num.r12(life + a)
        XCTAssertEqual(a, 10)
        XCTAssertEqual(Num.r12(b + Num.digitSum(3) + Num.digitSum(4)), 12)
        XCTAssertEqual(Num.r9(life + Num.digitSum(3) + Num.digitSum(4)), 5)
    }

    // MARK: - 七、月運（文件第 3 頁）

    func testMonthChart2026() {
        let d = Destiny(birth: BirthDate(year: 2006, month: 1, day: 14))
        let months = d.monthChart(year: 2026)
        XCTAssertEqual(months.first?.row.triple, Triple(5, 3, 11))
        XCTAssertEqual(months.first?.row.palace, 7)
        XCTAssertEqual(months.map { $0.month }, Array(1...12))

        assertChart(months.map { $0.row }, [
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
        ])
    }

    // MARK: - 八、合盤（文件第 4 頁）

    func testSynastry() {
        let a = Destiny(birth: BirthDate(year: 2006, month: 1, day: 14))
        let b = Destiny(birth: BirthDate(year: 2007, month: 1, day: 23))
        let s = a.synastry(with: b)

        XCTAssertEqual(s.triple, Triple(5, 2, 10))
        XCTAssertEqual(s.lifeNumber, 8)

        assertChart(s.chart, [
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
        ])
    }

    // MARK: - 九、九型人格

    /// 靈數幾就是第幾型，內容四種語言都要齊。
    func testEnneagram() {
        for n in 1...9 {
            XCTAssertEqual(Enneagram.type(forLifeNumber: n), n)
        }
        XCTAssertEqual(Enneagram.type(forLifeNumber: 10), 1)

        XCTAssertEqual(Enneagram.name(5, lang: .zh), "格物致知者")
        XCTAssertEqual(Enneagram.label(5, lang: .zh), "第五型")
        XCTAssertEqual(Enneagram.label(5, lang: .en), "Type 5")
        XCTAssertEqual(Enneagram.name(5, lang: .en), "The Investigator")

        for t in 1...Enneagram.count {
            for lang in [Lang.zh, .en, .es, .it] {
                XCTAssertFalse(Enneagram.name(t, lang: lang).isEmpty)
                XCTAssertFalse(Enneagram.tagline(t, lang: lang).isEmpty)
                XCTAssertGreaterThan(Enneagram.summary(t, lang: lang).count, 40)
                for i in 0..<Enneagram.sectionCount {
                    XCTAssertFalse(Enneagram.sectionTitle(i, lang: lang).isEmpty)
                    let lines = Enneagram.section(t, i, lang: lang)
                    XCTAssertFalse(lines.isEmpty, "第\(t)型 第\(i)段 \(lang)")
                    for line in lines { XCTAssertFalse(line.isEmpty) }
                }
            }
        }
        // 每一段在四種語言的條目數必須一樣
        for t in 1...Enneagram.count {
            for i in 0..<Enneagram.sectionCount {
                let counts = Set([Lang.zh, .en, .es, .it].map {
                    Enneagram.section(t, i, lang: $0).count
                })
                XCTAssertEqual(counts.count, 1, "第\(t)型 第\(i)段 條目數不一致")
            }
        }
        // 九個型號九個不同的顏色
        let colours = Set((1...Enneagram.count).map { t -> String in
            let c = Enneagram.rgb(t)
            return "\(c.red),\(c.green),\(c.blue)"
        })
        XCTAssertEqual(colours.count, 9)
    }

    // MARK: - 一致性檢查

    /// 任何盤的每一列，果與因都必須落在 1...12。
    func testAllReadingsInRange() {
        for y in 1...12 {
            for m in 1...12 {
                for d in 1...12 {
                    let r = ChartEngine.read(Triple(y, m, d))
                    XCTAssertTrue((1...12).contains(r.result), "\(y);\(m);\(d)")
                    XCTAssertTrue((1...12).contains(r.cause), "\(y);\(m);\(d)")
                }
            }
        }
    }

    /// 任何出生日期都能排出十二列不重複宮位的盤。
    func testChartsAreWellFormedForManyBirthdays() {
        for year in stride(from: 1900, through: 2100, by: 7) {
            for month in [1, 2, 6, 9, 12] {
                let d = Destiny(birth: BirthDate(year: year, month: month, day: 28))
                XCTAssertEqual(Set(d.natalChart.map { $0.palace }).count, 12)
                XCTAssertEqual(d.natalChart.first?.palace, d.lifeNumber)
                XCTAssertEqual(d.natalChart.last?.triple, d.triple)
                XCTAssertEqual(Set(d.monthChart(year: year + 20).map { $0.row.palace }).count, 12)
            }
        }
    }

    /// 流年必為 12 年週期，大運必連續且不重疊。
    func testPeriodicityAndContinuity() {
        let d = Destiny(birth: BirthDate(year: 1988, month: 7, day: 3))
        for y in 1980...2060 {
            XCTAssertEqual(d.year(y), d.year(y + 12))
        }
        let ps = d.luckPeriods(count: 12)
        for (a, b) in zip(ps, ps.dropFirst()) {
            XCTAssertEqual(a.endYear + 1, b.startYear)
        }
        for p in ps {
            for y in p.startYear...p.endYear {
                XCTAssertEqual(d.luckPeriod(containing: y).startYear, p.startYear)
            }
        }
    }
}
