import Foundation

/// 三柱：年柱、月柱、日柱，每柱為 1...12。
public struct Triple: Equatable, Hashable, Codable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = Num.r12(year)
        self.month = Num.r12(month)
        self.day = Num.r12(day)
    }

    /// 三柱同步加上同一個數（十二進制）。
    public func advanced(by n: Int) -> Triple {
        Triple(year + n, month + n, day + n)
    }

    /// 兩盤相加：年加年、月加月、日加日（十二進制）。用於合盤與月運。
    public static func + (lhs: Triple, rhs: Triple) -> Triple {
        Triple(lhs.year + rhs.year, lhs.month + rhs.month, lhs.day + rhs.day)
    }

    /// 此三柱的靈數：三柱相加後以九進制化約。
    public var lifeNumber: Int {
        Num.lifeDigit(year + month + day)
    }

    public var display: String { "\(year)；\(month)；\(day)" }
}

/// 年柱與月柱的五行關係所定出的吉凶。
public enum Verdict: String, Codable, Sendable {
    case good = "好"     // 年月相生
    case neutral = "正"  // 年月同五行
    case bad = "壞"      // 年月相剋

    /// 各語言採用能對應「相生／同／相剋」語感的譯法。
    public func name(_ lang: Lang) -> String {
        switch lang {
        case .zh: return rawValue
        case .en:
            switch self {
            case .good: return "Favorable"; case .neutral: return "Aligned"; case .bad: return "Adverse"
            }
        case .es:
            switch self {
            case .good: return "Favorable"; case .neutral: return "Alineado"; case .bad: return "Adverso"
            }
        case .it:
            switch self {
            case .good: return "Favorevole"; case .neutral: return "Allineato"; case .bad: return "Avverso"
            }
        }
    }

    /// 空間很小時用的符號，不分語言。
    public var mark: String {
        switch self {
        case .good:    return "+"
        case .neutral: return "="
        case .bad:     return "−"
        }
    }
}

/// 年柱與月柱之間的五行關係。
public enum PillarRelation: String, Codable, Sendable {
    case same
    case yearGeneratesMonth
    case monthGeneratesYear
    case yearControlsMonth
    case monthControlsYear
}

/// 一組三柱的判讀結果：`好 / 正 / 壞` + 果宮 + 因宮。
public struct Reading: Equatable, Hashable, Codable, Sendable {
    public let verdict: Verdict
    /// 「果」的宮位數（好X／正X／壞X 的 X）。
    public let result: Int
    /// 「因」的宮位數（因Y 的 Y）。
    public let cause: Int
    /// 年柱五行
    public let yearElement: Element
    /// 月柱五行
    public let monthElement: Element
    /// 年月柱的五行關係
    public let relation: PillarRelation

    public func text(_ lang: Lang) -> String {
        switch lang {
        case .zh: return "\(verdict.rawValue)\(result)因\(cause)"
        case .en: return "\(verdict.name(.en)) \(result) from \(cause)"
        case .es: return "\(verdict.name(.es)) \(result) de \(cause)"
        case .it: return "\(verdict.name(.it)) \(result) da \(cause)"
        }
    }

    /// 中文的標準寫法，也是測試比對的依據。
    public var display: String { text(.zh) }
}

public enum ChartEngine {

    /// 判讀一組三柱。
    ///
    /// 規則（取自命盤方法）：
    /// 1. 看年柱與月柱的五行關係。
    /// 2. 相剋 →「壞」：被剋的一柱加日柱得「果」，去剋的一柱加日柱得「因」。
    /// 3. 相生 →「好」：受生的一柱加日柱得「果」，去生的一柱加日柱得「因」。
    /// 4. 相同 →「正」：年月同五行會強化日柱，果即日柱本身；
    ///    年柱加日柱、月柱加日柱，兩者再相加得「因」。
    /// 全部加法皆為十二進制。
    public static func read(_ t: Triple) -> Reading {
        let ey = Element.of(palace: t.year)
        let em = Element.of(palace: t.month)

        let yearPlusDay = Num.r12(t.year + t.day)
        let monthPlusDay = Num.r12(t.month + t.day)

        if ey == em {
            return Reading(verdict: .neutral,
                           result: t.day,
                           cause: Num.r12(yearPlusDay + monthPlusDay),
                           yearElement: ey,
                           monthElement: em,
                           relation: .same)
        }
        if ey.generates == em {
            // 年生月：月柱受生
            return Reading(verdict: .good,
                           result: monthPlusDay,
                           cause: yearPlusDay,
                           yearElement: ey,
                           monthElement: em,
                           relation: .yearGeneratesMonth)
        }
        if em.generates == ey {
            // 月生年：年柱受生
            return Reading(verdict: .good,
                           result: yearPlusDay,
                           cause: monthPlusDay,
                           yearElement: ey,
                           monthElement: em,
                           relation: .monthGeneratesYear)
        }
        if ey.overcomes == em {
            // 年剋月：月柱被剋
            return Reading(verdict: .bad,
                           result: monthPlusDay,
                           cause: yearPlusDay,
                           yearElement: ey,
                           monthElement: em,
                           relation: .yearControlsMonth)
        }
        // 月剋年：年柱被剋
        return Reading(verdict: .bad,
                       result: yearPlusDay,
                       cause: monthPlusDay,
                       yearElement: ey,
                       monthElement: em,
                       relation: .monthControlsYear)
    }
}

/// 命盤中的一列：宮位 + 三柱 + 判讀。
public struct PalaceRow: Identifiable, Equatable, Hashable, Codable, Sendable {
    /// 在盤中的列序（0 為首列）。
    public let index: Int
    /// 宮位 1...12。
    public let palace: Int
    public let triple: Triple
    public let reading: Reading

    public var id: Int { index }

    public var display: String {
        "\(palace)宮 \(triple.display) \(reading.display)"
    }
}

public extension ChartEngine {

    /// 以 `startPalace` 為首列、宮位逆序排列的十二列盤，
    /// 三柱由 `firstTriple` 起每列加一（十二進制）。
    static func chart(startPalace: Int, firstTriple: Triple) -> [PalaceRow] {
        (0..<12).map { k in
            let palace = Num.r12(startPalace - k)
            let t = firstTriple.advanced(by: k)
            return PalaceRow(index: k, palace: palace, triple: t, reading: read(t))
        }
    }

    /// 本命／合盤型的盤：首列落在靈數宮，三柱由「本命三柱 + 1」起算，
    /// 因此末列會剛好回到本命三柱本身。
    static func natalStyleChart(for triple: Triple) -> [PalaceRow] {
        chart(startPalace: triple.lifeNumber, firstTriple: triple.advanced(by: 1))
    }
}
