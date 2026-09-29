import Foundation

// 九型十二宮推算引擎 —— ECHO-0 的符號認知層。
// 算法與 Hollow App（claude/hollow-ipa 分支 Engine.swift / HANDOFF.md §3）完全一致，
// 只保留繁體中文，並去掉 UI 相關的部分。

public enum NT {
    static func mod(_ a: Int, _ n: Int) -> Int { let r = a % n; return r < 0 ? r + n : r }
    public static func r9(_ n: Int) -> Int { mod(n - 1, 9) + 1 }
    public static func r12(_ n: Int) -> Int { mod(n - 1, 12) + 1 }

    public static func digitSum(_ n: Int) -> Int {
        var v = abs(n), s = 0
        while v > 0 { s += v % 10; v /= 10 }
        return s
    }

    public static func lifeDigit(_ n: Int) -> Int {
        var v = abs(n)
        while v > 9 { v = digitSum(v) }
        return v == 0 ? 9 : v
    }

    public static func palaceName(_ p: Int) -> String { NineTwelveData.palaceNames[r12(p) - 1] }

    /// 前 n 個關鍵詞（排除簡稱本身）——與訓練資料的取法一致。
    public static func keywords(_ p: Int, _ n: Int = 3) -> String {
        let name = palaceName(p)
        return NineTwelveData.palaceKeywords[r12(p) - 1].filter { $0 != name }.prefix(n).joined(separator: "、")
    }

    /// 例：5宮「桃花」
    public static func label(_ p: Int) -> String { "\(r12(p))宮「\(palaceName(p))」" }

    public static func typeName(_ t: Int) -> String { NineTwelveData.typeNames[r9(t) - 1] }
    public static func typeTagline(_ t: Int) -> String { NineTwelveData.typeTaglines[r9(t) - 1] }
}

public struct NTTriple: Hashable, Codable {
    public let y, m, d: Int
    public init(_ y: Int, _ m: Int, _ d: Int) { self.y = NT.r12(y); self.m = NT.r12(m); self.d = NT.r12(d) }
    static func + (a: NTTriple, b: NTTriple) -> NTTriple { NTTriple(a.y + b.y, a.m + b.m, a.d + b.d) }
    func advanced(by n: Int) -> NTTriple { NTTriple(y + n, m + n, d + n) }
    var life: Int { NT.lifeDigit(y + m + d) }
}

enum NTElement: Int { case metal, wood, water, fire, earth
    var generates: NTElement { [.water, .fire, .wood, .earth, .metal][rawValue] }
    var overcomes: NTElement { [.wood, .earth, .fire, .metal, .water][rawValue] }
    static let table: [NTElement] = [.fire, .metal, .water, .water, .fire, .water, .metal, .fire, .wood, .earth, .earth, .wood]
    static func of(_ p: Int) -> NTElement { table[NT.r12(p) - 1] }
}

public enum NTVerdict: Int, Codable {
    case good, neutral, bad
    public var name: String { ["好", "正", "壞"][rawValue] }
}

public struct NTReading: Hashable, Codable {
    public let verdict: NTVerdict
    public let result: Int  // 果
    public let cause: Int   // 因
    public var text: String { "\(verdict.name)\(result)因\(cause)" }
}

public struct NTRow: Hashable, Codable {
    public let index: Int
    public let palace: Int
    let triple: NTTriple
    public let reading: NTReading
    /// 例：8宮壞9因2
    public var text: String { "\(palace)宮\(reading.text)" }
}

enum NTChart {
    static func read(_ t: NTTriple) -> NTReading {
        let ye = NTElement.of(t.y), me = NTElement.of(t.m)
        let a = NT.r12(t.y + t.d), b = NT.r12(t.m + t.d)
        if ye == me { return NTReading(verdict: .neutral, result: t.d, cause: NT.r12(a + b)) }
        if ye.generates == me { return NTReading(verdict: .good, result: b, cause: a) }
        if me.generates == ye { return NTReading(verdict: .good, result: a, cause: b) }
        if ye.overcomes == me { return NTReading(verdict: .bad, result: b, cause: a) }
        return NTReading(verdict: .bad, result: a, cause: b)
    }

    static func chart(start: Int, first: NTTriple) -> [NTRow] {
        (0..<12).map { i in
            let t = first.advanced(by: i)
            return NTRow(index: i, palace: NT.r12(start - i), triple: t, reading: read(t))
        }
    }

    static func natalStyle(_ t: NTTriple) -> [NTRow] { chart(start: t.life, first: t.advanced(by: 1)) }
}

public struct BirthDay: Hashable, Codable {
    public var year, month, day: Int
    public init(year: Int, month: Int, day: Int) { self.year = year; self.month = month; self.day = day }
    public var display: String { "\(year)年\(month)月\(day)日" }
}

public struct Destiny {
    public let birth: BirthDay
    let triple: NTTriple
    public let lifeNumber: Int
    public let natal: [NTRow]

    public init(_ b: BirthDay) {
        birth = b
        triple = NTTriple(NT.lifeDigit(b.year), NT.lifeDigit(b.month), NT.lifeDigit(b.day))
        lifeNumber = triple.life
        natal = NTChart.natalStyle(triple)
    }

    public var type: Int { NT.r9(lifeNumber) }

    func rowIndex(_ y: Int) -> Int { NT.mod(y - birth.year + 1, 12) }

    /// 流年
    public func year(_ y: Int) -> NTRow { natal[rowIndex(y)] }

    var firstLuckEnd: Int { birth.year + (8 - NT.mod(lifeNumber, 9)) }

    /// 大運（起、迄、列）
    public func luckPeriod(_ y: Int) -> (start: Int, end: Int, row: NTRow) {
        var s: Int, e: Int
        if y < birth.year {
            var upper = birth.year
            while y < upper - 9 { upper -= 9 }
            s = upper - 9; e = upper - 1
        } else {
            s = birth.year; e = firstLuckEnd
            if y > e { s = e + 1 + ((y - e - 1) / 9) * 9; e = s + 8 }
        }
        return (s, e, year(s))
    }

    /// 大運十二方面：由大運結束年所在列起排，第 N 方面即 N 宮。
    public func luckAspects(_ y: Int) -> [NTRow] {
        let k0 = rowIndex(luckPeriod(y).end)
        return (1...12).map { i in
            let r = natal[(k0 + i - 1) % 12]
            return NTRow(index: r.index, palace: i, triple: r.triple, reading: r.reading)
        }
    }

    /// 流年引動的大運方面
    public func triggeredAspects(_ y: Int) -> [NTRow] {
        let p = year(y).palace
        return luckAspects(y).filter { $0.reading.result == p || $0.reading.cause == p }
    }

    /// 大運引動的本命宮
    public func triggeredNatal(_ y: Int) -> [NTRow] {
        let p = luckPeriod(y).row.palace
        return natal.filter { $0.reading.result == p || $0.reading.cause == p }
    }

    /// 流月
    public func month(_ m: Int, year y: Int) -> NTRow {
        let yr = year(y)
        let rows = NTChart.chart(start: NT.r12(yr.palace - 1), first: luckPeriod(y).row.triple + yr.triple)
        return rows[NT.r12(m) - 1]
    }

    /// 日宮、夜宮
    public func day(month m: Int, day d: Int) -> (day: Int, night: Int) {
        let s = NT.digitSum(m) + NT.digitSum(d)
        let base = NT.r12(lifeNumber + NT.r12(lifeNumber + m))
        return (NT.r12(base + s), NT.r9(lifeNumber + s))
    }

    /// 合盤
    public func synastry(with o: Destiny) -> [NTRow] { NTChart.natalStyle(triple + o.triple) }
}
