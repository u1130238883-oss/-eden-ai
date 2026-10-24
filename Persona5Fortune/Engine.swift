import Foundation

// 九型十二宮推算引擎。
// 演算法依原版 NineTwelve 逐函式還原：Num / Triple / Element / ChartEngine / Destiny / Synastry。

// MARK: - 數字化約

enum Num {
    static func mod(_ a: Int, _ n: Int) -> Int {
        let r = a % n
        return r < 0 ? r + n : r
    }

    /// 化為 1...9
    static func r9(_ n: Int) -> Int { mod(n - 1, 9) + 1 }

    /// 化為 1...12
    static func r12(_ n: Int) -> Int { mod(n - 1, 12) + 1 }

    /// 各位數相加
    static func digitSum(_ n: Int) -> Int {
        var v = abs(n), s = 0
        while v > 0 { s += v % 10; v /= 10 }
        return s
    }

    /// 反覆相加各位數直到剩一位；0 視為 9
    static func lifeDigit(_ n: Int) -> Int {
        var v = abs(n)
        while v > 9 { v = digitSum(v) }
        return v == 0 ? 9 : v
    }
}

// MARK: - 三柱

struct Triple: Hashable, Codable {
    let year: Int
    let month: Int
    let day: Int

    init(_ y: Int, _ m: Int, _ d: Int) {
        year = Num.r12(y)
        month = Num.r12(m)
        day = Num.r12(d)
    }

    static func + (a: Triple, b: Triple) -> Triple {
        Triple(a.year + b.year, a.month + b.month, a.day + b.day)
    }

    func advanced(by n: Int) -> Triple { Triple(year + n, month + n, day + n) }

    /// 三柱相加（九進制）
    var lifeNumber: Int { Num.lifeDigit(year + month + day) }

    var display: String { "\(year)・\(month)・\(day)" }
}

// MARK: - 五行

enum Element: Int, CaseIterable, Codable {
    case metal, wood, water, fire, earth

    var name: String {
        switch self {
        case .metal: return L("金", "Metal", "Metal", "Metallo")
        case .wood: return L("木", "Wood", "Madera", "Legno")
        case .water: return L("水", "Water", "Agua", "Acqua")
        case .fire: return L("火", "Fire", "Fuego", "Fuoco")
        case .earth: return L("土", "Earth", "Tierra", "Terra")
        }
    }

    /// 我生者
    var generates: Element {
        switch self {
        case .metal: return .water
        case .wood: return .fire
        case .water: return .wood
        case .fire: return .earth
        case .earth: return .metal
        }
    }

    /// 我剋者
    var overcomes: Element {
        switch self {
        case .metal: return .wood
        case .wood: return .earth
        case .water: return .fire
        case .fire: return .metal
        case .earth: return .water
        }
    }

    private static let palaceTable: [Element] = [
        .fire, .metal, .water, .water, .fire, .water, .metal, .fire, .wood, .earth, .earth, .wood
    ]

    /// 宮位（1...12）所屬五行
    static func of(palace: Int) -> Element { palaceTable[Num.r12(palace) - 1] }

    var palaces: [Int] { (1...12).filter { Element.of(palace: $0) == self } }
}

// MARK: - 判讀

enum Verdict: Int, Codable {
    case good, neutral, bad

    var name: String {
        switch self {
        case .good: return L("好", "Favorable", "Favorable", "Favorevole")
        case .neutral: return L("正", "Aligned", "Alineado", "Allineato")
        case .bad: return L("壞", "Adverse", "Adverso", "Avverso")
        }
    }

    var mark: String {
        switch self {
        case .good: return "+"
        case .neutral: return "="
        case .bad: return "−"
        }
    }
}

enum PillarRelation: Int, Codable {
    case same, yearGeneratesMonth, monthGeneratesYear, yearControlsMonth, monthControlsYear
}

struct Reading: Hashable, Codable {
    let verdict: Verdict
    /// 因（宮位 1...12）
    let cause: Int
    /// 果（宮位 1...12）
    let result: Int
    let yearElement: Element
    let monthElement: Element
    let relation: PillarRelation

    /// 例如「好7因3」
    var text: String {
        Lang.current == .zh
            ? "\(verdict.name)\(result)因\(cause)"
            : "\(verdict.name) \(result) \(L("因", "from", "de", "da")) \(cause)"
    }
}

struct PalaceRow: Identifiable, Hashable, Codable {
    let index: Int
    let palace: Int
    let triple: Triple
    let reading: Reading
    var id: Int { index }
}

enum ChartEngine {
    static func read(_ t: Triple) -> Reading {
        let ye = Element.of(palace: t.year)
        let me = Element.of(palace: t.month)
        let a = Num.r12(t.year + t.day)
        let b = Num.r12(t.month + t.day)

        // 欄位順序依原版 Reading(verdict, result, cause)
        if ye == me {
            return Reading(verdict: .neutral, cause: Num.r12(a + b), result: t.day,
                           yearElement: ye, monthElement: me, relation: .same)
        }
        if ye.generates == me {
            return Reading(verdict: .good, cause: a, result: b,
                           yearElement: ye, monthElement: me, relation: .yearGeneratesMonth)
        }
        if me.generates == ye {
            return Reading(verdict: .good, cause: b, result: a,
                           yearElement: ye, monthElement: me, relation: .monthGeneratesYear)
        }
        if ye.overcomes == me {
            return Reading(verdict: .bad, cause: a, result: b,
                           yearElement: ye, monthElement: me, relation: .yearControlsMonth)
        }
        return Reading(verdict: .bad, cause: b, result: a,
                       yearElement: ye, monthElement: me, relation: .monthControlsYear)
    }

    /// 由起始宮位逆排十二宮，三柱每列加一。
    static func chart(startPalace: Int, firstTriple: Triple) -> [PalaceRow] {
        (0..<12).map { i in
            let t = firstTriple.advanced(by: i)
            return PalaceRow(index: i, palace: Num.r12(startPalace - i), triple: t, reading: read(t))
        }
    }

    /// 本命式排盤：命宮 = 靈數，第一列三柱 = 本命三柱 + 1。
    static func natalStyleChart(for t: Triple) -> [PalaceRow] {
        chart(startPalace: t.lifeNumber, firstTriple: t.advanced(by: 1))
    }
}

// MARK: - 出生資料與年錨

struct BirthDate: Hashable, Codable {
    var year: Int
    var month: Int
    var day: Int

    var triple: Triple { Triple(Num.lifeDigit(year), Num.lifeDigit(month), Num.lifeDigit(day)) }
    var display: String { String(format: "%04d年%d月%d日", year, month, day) }
}

enum YearAnchor: String, CaseIterable, Codable {
    case birthDerived
    case fixed2017

    var title: String {
        switch self {
        case .birthDerived: return L("依出生年（預設）", "From birth year (default)",
                                     "Según el año de nacimiento (predeterminado)", "Dall'anno di nascita (predefinito)")
        case .fixed2017: return L("固定 2017 年錨點", "Fixed 2017 anchor", "Anclaje fijo en 2017", "Ancoraggio fisso al 2017")
        }
    }

    var detail: String {
        switch self {
        case .birthDerived:
            return L("出生年落在命宮的下一個位置，與大運的排法一致。",
                     "The birth year sits in the position right after the Life Palace, matching how the Luck Pillars are laid out.",
                     "El año de nacimiento ocupa la posición justo después del Palacio de Vida, igual que en la disposición de los Pilares de Suerte.",
                     "L'anno di nascita occupa la posizione subito dopo il Palazzo della Vita, come nella disposizione dei Pilastri della Sorte.")
        case .fixed2017:
            return L("不論出生年為何，命宮一律對應 2017 年。",
                     "Regardless of birth year, the Life Palace always corresponds to 2017.",
                     "Sea cual sea el año de nacimiento, el Palacio de Vida siempre corresponde a 2017.",
                     "Qualunque sia l'anno di nascita, il Palazzo della Vita corrisponde sempre al 2017.")
        }
    }
}

// MARK: - 大運 / 流年 / 月運 / 日運

struct LuckPeriod: Identifiable, Hashable {
    let startYear: Int
    let endYear: Int
    let row: PalaceRow
    var id: Int { startYear }
    var length: Int { endYear - startYear + 1 }
    var span: String { "\(startYear)–\(endYear)" }
    func contains(_ y: Int) -> Bool { (startYear...endYear).contains(y) }
}

struct LuckAspect: Identifiable, Hashable {
    /// 1...12
    let aspect: Int
    let row: PalaceRow
    var id: Int { aspect }
}

struct MonthRow: Identifiable, Hashable {
    let month: Int
    let row: PalaceRow
    var id: Int { month }
}

struct DayFortune: Hashable {
    /// 日宮（1...12）
    let dayPalace: Int
    /// 夜數（1...9）
    let nightPalace: Int
}

struct Destiny: Hashable {
    let birth: BirthDate
    let anchor: YearAnchor
    let triple: Triple
    let lifeNumber: Int
    let natalChart: [PalaceRow]

    init(birth: BirthDate, anchor: YearAnchor = .birthDerived) {
        self.birth = birth
        self.anchor = anchor
        let t = birth.triple
        triple = t
        lifeNumber = t.lifeNumber
        natalChart = ChartEngine.natalStyleChart(for: t)
    }

    func rowIndex(forYear y: Int) -> Int {
        switch anchor {
        case .fixed2017: return Num.mod(y - 2017, 12)
        case .birthDerived: return Num.mod(y - birth.year + 1, 12)
        }
    }

    /// 流年
    func year(_ y: Int) -> PalaceRow { natalChart[rowIndex(forYear: y)] }

    var luckStartPosition: Int { Num.r9(lifeNumber + 1) }

    private var firstLuckEnd: Int { birth.year + (8 - Num.mod(lifeNumber, 9)) }

    /// 大運：第一段由出生年起，之後每段九年。
    func luckPeriods(count: Int) -> [LuckPeriod] {
        var out = [LuckPeriod(startYear: birth.year, endYear: firstLuckEnd, row: year(birth.year))]
        var start = firstLuckEnd + 1
        while out.count < count {
            out.append(LuckPeriod(startYear: start, endYear: start + 8, row: year(start)))
            start += 9
        }
        return out
    }

    func luckPeriod(containing y: Int) -> LuckPeriod {
        var start: Int
        var end: Int
        if y < birth.year {
            var upper = birth.year
            while y < upper - 9 { upper -= 9 }
            start = upper - 9
            end = upper - 1
        } else {
            start = birth.year
            end = firstLuckEnd
            if y > end {
                start = end + 1 + ((y - end - 1) / 9) * 9
                end = start + 8
            }
        }
        return LuckPeriod(startYear: start, endYear: end, row: year(start))
    }

    /// 這一段大運的十二個方面
    /// 大運十二方面：由大運「結束年」所在的本命列起排，第 N 方面即 N 宮。
    func luckAspects(containing y: Int) -> [LuckAspect] {
        let p = luckPeriod(containing: y)
        let k0 = rowIndex(forYear: p.endYear)
        return (1...12).map { i in
            let r = natalChart[(k0 + i - 1) % 12]
            return LuckAspect(aspect: i, row: PalaceRow(index: r.index, palace: i, triple: r.triple, reading: r.reading))
        }
    }

    /// 流年引動的大運方面：果或因等於流年宮位
    func triggeredAspects(forYear y: Int) -> [LuckAspect] {
        let p = year(y).palace
        return luckAspects(containing: y).filter { $0.row.reading.result == p || $0.row.reading.cause == p }
    }

    /// 大運引動的本命宮：果或因等於大運宮位
    func triggeredNatalRows(for period: LuckPeriod) -> [PalaceRow] {
        let p = period.row.palace
        return natalChart.filter { $0.reading.result == p || $0.reading.cause == p }
    }

    /// 本命宮引動的其他本命宮：果或因等於該宮位者（不含本宮）
    func triggeredNatalRows(forPalace p: Int) -> [PalaceRow] {
        natalChart.filter { $0.palace != p && ($0.reading.result == p || $0.reading.cause == p) }
    }

    /// 月運：大運三柱 + 流年三柱，由流年宮位前一宮起排。
    func monthChart(year y: Int) -> [MonthRow] {
        let p = luckPeriod(containing: y)
        let yr = year(y)
        let rows = ChartEngine.chart(startPalace: Num.r12(yr.palace - 1), firstTriple: p.row.triple + yr.triple)
        return rows.enumerated().map { MonthRow(month: $0.offset + 1, row: $0.element) }
    }

    func month(_ m: Int, year y: Int) -> MonthRow { monthChart(year: y)[Num.r12(m) - 1] }

    /// 日運
    func dayFortune(month m: Int, day d: Int) -> DayFortune {
        let s = Num.digitSum(m) + Num.digitSum(d)
        let base = Num.r12(lifeNumber + Num.r12(lifeNumber + m))
        return DayFortune(dayPalace: Num.r12(base + s), nightPalace: Num.r9(lifeNumber + s))
    }

    func dayFortune(on date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> DayFortune {
        let c = calendar.dateComponents([.month, .day], from: date)
        return dayFortune(month: c.month ?? 1, day: c.day ?? 1)
    }

    func synastry(with other: Destiny) -> Synastry { Synastry(a: self, b: other) }
}

// MARK: - 合盤

struct Synastry {
    let a: Destiny
    let b: Destiny
    let triple: Triple
    let lifeNumber: Int
    let chart: [PalaceRow]

    init(a: Destiny, b: Destiny) {
        self.a = a
        self.b = b
        let t = a.triple + b.triple
        triple = t
        lifeNumber = t.lifeNumber
        chart = ChartEngine.natalStyleChart(for: t)
    }
}

// MARK: - 宮位與九型

// MARK: - 語言

enum Lang: String, CaseIterable, Codable {
    case zh, en, es, it

    /// 目前介面語言（由 Store 設定）
    static var current: Lang = .zh

    var index: Int {
        switch self {
        case .zh: return 0
        case .en: return 1
        case .es: return 2
        case .it: return 3
        }
    }

    var title: String {
        switch self {
        case .zh: return "繁體中文"
        case .en: return "English"
        case .es: return "Español"
        case .it: return "Italiano"
        }
    }

    var locale: Locale {
        switch self {
        case .zh: return Locale(identifier: "zh_Hant")
        case .en: return Locale(identifier: "en")
        case .es: return Locale(identifier: "es")
        case .it: return Locale(identifier: "it")
        }
    }

    /// 清單分隔符
    var separator: String { self == .zh ? "、" : ", " }

    static var systemDefault: Lang {
        let code = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "zh"
        return Lang(rawValue: String(code)) ?? .zh
    }
}

/// 依目前語言挑選字串
func L(_ zh: String, _ en: String, _ es: String, _ it: String) -> String {
    switch Lang.current {
    case .zh: return zh
    case .en: return en
    case .es: return es
    case .it: return it
    }
}

// MARK: - 宮位與九型

enum Palace {
    static func name(_ p: Int) -> String { PalaceData.shortNames[Lang.current.index][Num.r12(p) - 1] }
    static func keywords(_ p: Int) -> [String] { PalaceData.keywords[Lang.current.index][Num.r12(p) - 1] }

    /// 前四個關鍵詞（排除簡稱本身）
    static func brief(_ p: Int) -> String {
        let n = name(p)
        return keywords(p).filter { $0 != n }.prefix(4).joined(separator: Lang.current.separator)
    }

    static func text(_ p: Int) -> String { keywords(p).joined(separator: Lang.current.separator) }
}

enum Enneagram {
    private static var i: Int { Lang.current.index }
    static func type(forLifeNumber n: Int) -> Int { Num.r9(n) }
    static func name(_ t: Int) -> String { EnneagramData.names[i][Num.r9(t) - 1] }
    static func tagline(_ t: Int) -> String { EnneagramData.taglines[i][Num.r9(t) - 1] }
    static func summary(_ t: Int) -> String { EnneagramData.summaries[i][Num.r9(t) - 1] }
    static func sections(_ t: Int) -> [[String]] { EnneagramData.sections[i][Num.r9(t) - 1] }
    static var sectionTitles: [String] { EnneagramData.sectionTitles[i] }
}
