import Foundation

/// 八字排盤與分析（逐行對應 ai/bazi.py）。時間視為 UTC+8 鐘錶時間。
public struct BaZi {
    public static let wuxing = ["木", "火", "土", "金", "水"]
    static let stemEl = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4]
    static let branchEl = [4, 2, 0, 0, 2, 1, 1, 2, 3, 3, 2, 4]
    static let hidden: [[Int]] = [[9], [5, 9, 7], [0, 2, 4], [1], [4, 1, 9], [2, 6, 4],
                                  [3, 5], [5, 3, 1], [6, 8, 4], [7], [4, 7, 3], [8, 0]]
    public static let tenGods = ["比肩", "劫財", "食神", "傷官", "偏財", "正財", "七殺", "正官", "偏印", "正印"]

    static func generates(_ a: Int) -> Int { (a + 1) % 5 }
    static func controls(_ a: Int) -> Int { (a + 2) % 5 }

    public static func tenGod(dayStem: Int, other: Int) -> String {
        let dm = stemEl[dayStem], ot = stemEl[other]
        let samePol = dayStem % 2 == other % 2
        let rel: Int
        if ot == dm { rel = 0 }
        else if ot == generates(dm) { rel = 1 }
        else if ot == controls(dm) { rel = 2 }
        else if dm == controls(ot) { rel = 3 }
        else { rel = 4 }
        return tenGods[rel * 2 + (samePol ? 0 : 1)]
    }

    static func jieIndex(_ jdUT: Double) -> Int {
        let lon = Astro.sunLongitude(jdUT + Astro.deltaTDays(2000))
        return Int(floor(Astro.pmod(lon - 315, 360) / 30))
    }

    public let male: Bool
    public let hasHour: Bool
    let jd: Double
    public let year: Int
    public let month: Int
    public let day: Int
    public let hour: Int?

    public init(_ y: Int, _ m: Int, _ d: Int, hour: Int? = nil, minute: Int = 0, male: Bool = true) {
        self.male = male
        hasHour = hour != nil
        let h = hour ?? 12
        let jdUT = Astro.jd(y, m, d, hour: Double(h) + Double(minute) / 60) - Astro.tz
        jd = jdUT
        let lichun = Astro.solarTermJD(y, 315)
        let yy = jdUT >= lichun ? y : y - 1
        year = Astro.pmod(yy - 4, 60)
        let mi = BaZi.jieIndex(jdUT)
        let mstem = ((year % 10) % 5 * 2 + 2 + mi) % 10
        month = GZ.index(stem: mstem, branch: (mi + 2) % 12)
        let dn = Astro.dayNumber(y, m, d) + (h >= 23 ? 1 : 0)
        day = Astro.pmod(dn + 49, 60)
        if hasHour {
            let hb = ((h + 1) / 2) % 12
            let hstem = ((day % 10) % 5 * 2 + hb) % 10
            self.hour = GZ.index(stem: hstem, branch: hb)
        } else {
            self.hour = nil
        }
    }

    public var pillars: [Int] { [year, month, day] + (hour.map { [$0] } ?? []) }
    public var text: String { pillars.map(GZ.name).joined() }
    public var dayMaster: Int { day % 10 }

    func elementCounts() -> [Double] {
        var c = [Double](repeating: 0, count: 5)
        for (i, p) in pillars.enumerated() {
            c[BaZi.stemEl[p % 10]] += 1.0
            let w = i == 1 ? 2.0 : 1.0
            for (j, hs) in BaZi.hidden[p % 12].enumerated() {
                c[BaZi.stemEl[hs]] += w * (j == 0 ? 1.0 : (j == 1 ? 0.5 : 0.3))
            }
        }
        return c
    }

    public func strength() -> (strong: Bool, ratio: Double) {
        let c = elementCounts()
        let dm = BaZi.stemEl[dayMaster]
        let support = c[dm] + c[(dm + 4) % 5]
        let total = c[0] + c[1] + c[2] + c[3] + c[4]
        let ratio = support / total
        return (ratio >= 0.45, ratio)
    }

    public func favorable() -> [Int] {
        let dm = BaZi.stemEl[dayMaster]
        let c = elementCounts()
        if strength().strong {
            let cands = [BaZi.generates(dm), BaZi.controls(dm), (dm + 3) % 5]
            // Python 的 sort 是穩定排序：同分時保持原順序
            let sorted = cands.enumerated().sorted { a, b in
                c[a.element] != c[b.element] ? c[a.element] < c[b.element] : a.offset < b.offset
            }.map(\.element)
            return Array(sorted.prefix(2))
        }
        return [(dm + 4) % 5, dm]
    }

    /// 大運：(起運歲數, 干支序列)
    public func luck(count: Int = 8) -> (startAge: Int, seq: [Int]) {
        let yangYear = (year % 10) % 2 == 0
        let forward = yangYear == male
        let mi = BaZi.jieIndex(jd)
        let lonStart = Double((315 + 30 * mi) % 360)
        let target = forward ? Astro.pmod(lonStart + 30, 360) : lonStart
        let y = Astro.date(fromJD: jd).0
        let cands = [y - 1, y, y + 1].map { Astro.solarTermJD($0, target) }
        let days: Double
        if forward {
            days = cands.filter { $0 > jd }.min()! - jd
        } else {
            days = jd - cands.filter { $0 <= jd }.max()!
        }
        let start = max(1, Int((days / 3).rounded(.toNearestOrEven)))
        let step = forward ? 1 : -1
        return (start, (0..<count).map { Astro.pmod(month + step * ($0 + 1), 60) })
    }

    public func yearGod(_ y: Int) -> (gz: Int, god: String) {
        let g = Astro.pmod(y - 4, 60)
        return (g, BaZi.tenGod(dayStem: dayMaster, other: g % 10))
    }
}
