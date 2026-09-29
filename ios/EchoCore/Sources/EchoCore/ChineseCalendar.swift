import Foundation

/// 干支與農曆（逐行對應 ai/chinese_cal.py）。
public enum GZ {
    public static let stems = Array("甲乙丙丁戊己庚辛壬癸").map(String.init)
    public static let branches = Array("子丑寅卯辰巳午未申酉戌亥").map(String.init)
    public static let monthNames = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "臘"]

    /// 六十甲子序號 → 字串
    public static func name(_ i: Int) -> String { stems[Astro.pmod(i, 10)] + branches[Astro.pmod(i, 12)] }

    public static func index(stem: Int, branch: Int) -> Int {
        for i in 0..<60 where i % 10 == stem && i % 12 == branch { return i }
        fatalError("stem/branch parity mismatch")
    }

    public static func lunarDayName(_ d: Int) -> String {
        if d == 10 { return "初十" }
        if d == 20 { return "二十" }
        if d == 30 { return "三十" }
        let tens = ["初", "十", "廿", "三"][(d - 1) / 10]
        return tens + ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"][(d - 1) % 10]
    }
}

public struct LunarDate: Equatable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let isLeap: Bool

    public var text: String {
        "\(GZ.name(Astro.pmod(year - 4, 60)))年\(isLeap ? "閏" : "")\(GZ.monthNames[month - 1])月\(GZ.lunarDayName(day))"
    }
}

/// 農曆換算（含快取；執行緒安全）。
public final class LunarCalendar {
    public static let shared = LunarCalendar()
    private var cache: [Int: [(start: Int, num: Int, leap: Bool)]] = [:]
    private let lock = NSLock()

    private func winterSolsticeDay(_ y: Int) -> Int { Astro.localDay(Astro.solarTermJD(y, 270)) }

    func monthsOfSpan(_ y: Int) -> [(start: Int, num: Int, leap: Bool)] {
        lock.lock()
        if let c = cache[y] { lock.unlock(); return c }
        lock.unlock()

        let ws0 = winterSolsticeDay(y - 1), ws1 = winterSolsticeDay(y)
        let k0 = Astro.newMoon(onOrBefore: ws0)
        let k1 = Astro.newMoon(onOrBefore: ws1)
        let starts = (k0...(k1 + 1)).map { Astro.localDay(Astro.newMoonJD($0)) }
        let n = k1 - k0
        var leapIdx = -1
        if n == 13 {
            var zq: [Int] = []
            for yy in [y - 1, y] {
                for lon in stride(from: 0, to: 360, by: 30) {
                    zq.append(Astro.localDay(Astro.solarTermJD(yy, Double(lon))))
                }
            }
            for i in 0..<n {
                let a = starts[i], b = starts[i + 1]
                if !zq.contains(where: { a <= $0 && $0 < b }) { leapIdx = i; break }
            }
        }
        var out: [(start: Int, num: Int, leap: Bool)] = []
        var num = 11
        for i in 0..<(starts.count - 1) {
            if i == leapIdx {
                out.append((starts[i], Astro.pmod(num - 2, 12) + 1, true))
                continue
            }
            out.append((starts[i], num, false))
            num = num % 12 + 1
        }
        lock.lock(); cache[y] = out; lock.unlock()
        return out
    }

    /// 公曆 → 農曆（農曆年以正月初一為界）
    public func lunar(_ y: Int, _ m: Int, _ d: Int) -> LunarDate {
        let day = Astro.dayNumber(y, m, d)
        let spanYear = day >= monthsOfSpan(y + 1)[0].start ? y + 1 : y
        let months = monthsOfSpan(spanYear)
        for i in 0..<months.count {
            let mo = months[i]
            let next = i + 1 < months.count ? months[i + 1].start : monthsOfSpan(spanYear + 1)[1].start
            if mo.start <= day && day < next {
                let beforeNewYear = months[0...i].allSatisfy { !($0.num == 1 && !$0.leap) }
                let ly = beforeNewYear ? spanYear - 1 : spanYear
                return LunarDate(year: ly, month: mo.num, day: day - mo.start + 1, isLeap: mo.leap)
            }
        }
        fatalError("lunar conversion failed")
    }
}
