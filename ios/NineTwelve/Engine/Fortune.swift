import Foundation

/// 出生年月日（西曆）。
public struct BirthDate: Equatable, Hashable, Codable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }

    public var display: String {
        String(format: "%04d年%d月%d日", year, month, day)
    }

    /// 由年、月、日分別以生命靈數化約，得出本命三柱。
    /// 例：2006年1月14日 → 2+0+0+6=8；1；1+4=5 → 8；1；5
    public var triple: Triple {
        Triple(Num.lifeDigit(year), Num.lifeDigit(month), Num.lifeDigit(day))
    }
}

/// 流年在盤上的錨定方式。
///
/// 文件的範例（2006年1月14日生、靈數5）中，2017年落在首列的命宮 5宮，
/// 而出生年 2006 落在第二列 4宮。以下兩種解讀都能重現該範例，
/// 但推廣到其他出生年時結果不同，故開放切換。
public enum YearAnchor: String, CaseIterable, Codable, Sendable {
    /// 出生年落在盤的第二列（即命宮的下一個位置）；等同於命宮列 = 出生年 + 11。
    /// 這與大運「出生年落在靈數的下一個位置」的規則一致，為預設。
    case birthDerived
    /// 命宮列固定對應 2017 年，所有人共用同一條年份刻度。
    case fixed2017

    public func title(_ lang: Lang) -> String {
        let t = T(lang)
        switch self {
        case .birthDerived: return t("依出生年（預設）", "From birth year (default)",
    "Según el año de nacimiento (predeterminado)",
    "Dall'anno di nascita (predefinito)")
        case .fixed2017:    return t("固定 2017 年錨點", "Fixed 2017 anchor",
    "Anclaje fijo en 2017",
    "Ancoraggio fisso al 2017")
        }
    }

    public func detail(_ lang: Lang) -> String {
        let t = T(lang)
        switch self {
        case .birthDerived:
            return t("出生年落在命宮的下一個位置，與大運的排法一致。", "The birth year sits in the position right after the Life Palace, matching how the Luck Pillars are laid out.",
    "El año de nacimiento ocupa la posición justo después del Palacio de Vida, igual que en la disposición de los Pilares de Suerte.",
    "L'anno di nascita occupa la posizione subito dopo il Palazzo della Vita, come nella disposizione dei Pilastri della Sorte.")
        case .fixed2017:
            return t("不論出生年為何，命宮一律對應 2017 年。", "Regardless of birth year, the Life Palace always corresponds to 2017.",
    "Sea cual sea el año de nacimiento, el Palacio de Vida siempre corresponde a 2017.",
    "Qualunque sia l'anno di nascita, il Palazzo della Vita corrisponde sempre al 2017.")
        }
    }
}

/// 一段大運。
public struct LuckPeriod: Identifiable, Equatable, Hashable, Sendable {
    public let startYear: Int
    public let endYear: Int
    /// 該大運取「起始年」的流年為其運勢。
    public let row: PalaceRow

    public var id: Int { startYear }
    public var span: String { "\(startYear) – \(endYear)" }
    public var length: Int { endYear - startYear + 1 }

    public func contains(_ year: Int) -> Bool {
        year >= startYear && year <= endYear
    }
}

/// 大運十二方面中的一項。`aspect` 是第幾宮（1...12），也就是要用哪一宮的含義去讀。
public struct LuckAspect: Identifiable, Equatable, Hashable, Sendable {
    public let aspect: Int
    public let row: PalaceRow

    public var id: Int { aspect }
}

/// 月運中的一列。
public struct MonthRow: Identifiable, Equatable, Hashable, Sendable {
    public let month: Int          // 1...12
    public let row: PalaceRow
    public var id: Int { month }
}

/// 日運（白天／晚上）。
public struct DayFortune: Equatable, Hashable, Sendable {
    /// 白天所走的宮位（1...12）。
    public let dayPalace: Int
    /// 晚上所走的宮位（1...9）。
    public let nightPalace: Int
}

/// 一個人的完整命盤與各種運勢推算。
public struct Destiny: Equatable, Sendable {

    public let birth: BirthDate
    public let anchor: YearAnchor

    /// 本命三柱。
    public let triple: Triple
    /// 命主靈數（1...9），也是本命盤首列的宮位。
    public let lifeNumber: Int
    /// 本命十二宮盤。首列為命宮，宮位逆序，末列即本命三柱。
    public let natalChart: [PalaceRow]

    public init(birth: BirthDate, anchor: YearAnchor = .birthDerived) {
        self.birth = birth
        self.anchor = anchor
        let t = birth.triple
        self.triple = t
        self.lifeNumber = t.lifeNumber
        self.natalChart = ChartEngine.natalStyleChart(for: t)
    }

    // MARK: - 流年

    /// 某一年落在本命盤的第幾列（0...11）。年份以 12 年為週期循環。
    public func rowIndex(forYear year: Int) -> Int {
        let offset: Int
        switch anchor {
        case .birthDerived:
            // 出生年 → 第 1 列（索引 1），亦即命宮列對應出生年 + 11
            offset = year - birth.year + 1
        case .fixed2017:
            // 2017 → 第 0 列
            offset = year - 2017
        }
        let m = offset % 12
        return m < 0 ? m + 12 : m
    }

    /// 某一年的流年。
    public func year(_ year: Int) -> PalaceRow {
        natalChart[rowIndex(forYear: year)]
    }

    /// 連續數年的流年列表。
    public func years(from start: Int, count: Int) -> [(year: Int, row: PalaceRow)] {
        (0..<count).map { (start + $0, year(start + $0)) }
    }

    // MARK: - 大運

    /// 出生年在九宮循環中的位置（1...9）：靈數的下一個位置。
    public var luckStartPosition: Int {
        Num.r9(lifeNumber + 1)
    }

    /// 第一段大運自出生年起，走到九宮循環的第 9 位為止；其後每段固定九年。
    public func luckPeriods(count: Int = 10) -> [LuckPeriod] {
        var result: [LuckPeriod] = []
        let firstEnd = birth.year + (9 - luckStartPosition)
        result.append(LuckPeriod(startYear: birth.year,
                                 endYear: firstEnd,
                                 row: year(birth.year)))
        var start = firstEnd + 1
        while result.count < count {
            result.append(LuckPeriod(startYear: start,
                                     endYear: start + 8,
                                     row: year(start)))
            start += 9
        }
        return result
    }

    /// 涵蓋指定年份的大運。
    public func luckPeriod(containing year: Int) -> LuckPeriod {
        if year < birth.year {
            // 出生前：往前推同樣的九年節奏
            var end = birth.year - 1
            var start = end - 8
            while year < start {
                end = start - 1
                start = end - 8
            }
            return LuckPeriod(startYear: start, endYear: end, row: self.year(start))
        }
        let firstEnd = birth.year + (9 - luckStartPosition)
        if year <= firstEnd {
            return LuckPeriod(startYear: birth.year, endYear: firstEnd, row: self.year(birth.year))
        }
        let n = (year - firstEnd - 1) / 9
        let start = firstEnd + 1 + n * 9
        return LuckPeriod(startYear: start, endYear: start + 8, row: self.year(start))
    }

    // MARK: - 大運的十二個方面

    /// 某個大運裡的十二個方面。
    ///
    /// 以該大運「最後一年」的年運為第一宮，往下接滿十二宮；
    /// 第 N 宮即以第 N 宮的含義去讀。
    public func luckAspects(containing year: Int) -> [LuckAspect] {
        let period = luckPeriod(containing: year)
        let start = rowIndex(forYear: period.endYear)
        return (0..<12).map { i in
            LuckAspect(aspect: i + 1, row: natalChart[(start + i) % 12])
        }
    }

    // MARK: - 引動

    /// 某一年的流年所引動的大運方面（該年所屬大運的十二方面中，因或果落在流年所走那一宮的各項）。
    public func triggeredAspects(forYear y: Int) -> [LuckAspect] {
        let palace = year(y).palace
        return luckAspects(containing: y).filter {
            $0.row.reading.cause == palace || $0.row.reading.result == palace
        }
    }

    /// 某一段大運所引動的本命盤宮位（本命盤中，因或果落在大運所走那一宮的各列）。
    public func triggeredNatalRows(for period: LuckPeriod) -> [PalaceRow] {
        triggeredNatalRows(forPalace: period.row.palace)
    }

    /// 本命盤某一宮所引動的本命盤宮位（本命盤中，因或果落在那一宮的各列）。
    public func triggeredNatalRows(forPalace palace: Int) -> [PalaceRow] {
        natalChart.filter { $0.reading.cause == palace || $0.reading.result == palace }
    }

    /// 被影響：大運所引動的某一本命宮位，再影響到那段大運十二方面裡的哪幾項
    /// （十二方面中，因或果落在那一本命宮位的各項）。
    public func affectedAspects(by natalRow: PalaceRow, in period: LuckPeriod) -> [LuckAspect] {
        let palace = natalRow.palace
        return luckAspects(containing: period.startYear).filter {
            $0.row.reading.cause == palace || $0.row.reading.result == palace
        }
    }

    // MARK: - 月運

    /// 某年的月運盤。
    ///
    /// 取該年所屬大運的三柱與該年流年的三柱，年加年、月加月、日加日（十二進制）
    /// 組成新的三柱，即為該年一月的盤；一月的宮位為流年宮位減一，其後宮位逆序、
    /// 三柱每月加一。
    public func monthChart(year y: Int) -> [MonthRow] {
        let luck = luckPeriod(containing: y).row
        let flow = year(y)
        let base = luck.triple + flow.triple
        let firstPalace = Num.r12(flow.palace - 1)
        let rows = ChartEngine.chart(startPalace: firstPalace, firstTriple: base)
        return rows.enumerated().map { MonthRow(month: $0.offset + 1, row: $0.element) }
    }

    public func month(_ m: Int, year y: Int) -> MonthRow {
        let chart = monthChart(year: y)
        return chart[(Num.r12(m) - 1)]
    }

    // MARK: - 日運

    /// 某月某日的白天與晚上日運。
    ///
    /// 白天（十二進制）：靈數加月份得 a；靈數再加 a 得 b；
    /// b 再加上月份與日期的各位數字，化約至 1...12。
    /// 晚上（九進制）：靈數直接加上月份與日期的各位數字，化約至 1...9。
    public func dayFortune(month m: Int, day d: Int) -> DayFortune {
        let a = Num.r12(lifeNumber + m)
        let b = Num.r12(lifeNumber + a)
        let digits = String(m).compactMap { $0.wholeNumberValue }
            + String(d).compactMap { $0.wholeNumberValue }
        let sum = digits.reduce(0, +)

        return DayFortune(dayPalace: Num.r12(b + sum),
                          nightPalace: Num.r9(lifeNumber + sum))
    }

    public func dayFortune(on date: Date, calendar: Calendar = .current) -> DayFortune {
        let c = calendar.dateComponents([.month, .day], from: date)
        return dayFortune(month: c.month ?? 1, day: c.day ?? 1)
    }

    // MARK: - 合盤

    /// 與另一個人合盤：兩盤三柱相加（十二進制），再依本命盤方式排出十二宮。
    public func synastry(with other: Destiny) -> Synastry {
        Synastry(a: self, b: other)
    }
}

/// 合盤結果。
public struct Synastry: Equatable, Sendable {
    public let a: Destiny
    public let b: Destiny
    public let triple: Triple
    public let lifeNumber: Int
    public let chart: [PalaceRow]

    public init(a: Destiny, b: Destiny) {
        self.a = a
        self.b = b
        let t = a.triple + b.triple
        self.triple = t
        self.lifeNumber = t.lifeNumber
        self.chart = ChartEngine.natalStyleChart(for: t)
    }
}
