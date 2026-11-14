import XCTest
@testable import EchoCore

/// 八字（500 萬字）、紫微（1000 萬字）深入語料用的盤：每張盤輸出多年的流年、整年的流月、五個主題、
/// 紫微十二宮、每個大限、每顆星的位置，由 ai/corpus/gen_bazi_deep.py、gen_ziwei_deep.py 寫成問答和考題。
/// NINESUN_DEEP_OUT=輸出.jsonl NINESUN_DEEP_N=筆數 …xctest EchoCoreTests.FortuneDeepExport
final class FortuneDeepExport: XCTestCase {
    func testExport() throws {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["NINESUN_DEEP_OUT"] else { throw XCTSkip("") }
        let n = Int(env["NINESUN_DEEP_N"] ?? "") ?? 3000
        var rng = SplitMix(seed: 20_261_107)
        let topics = ["感情", "錢財", "事業", "學業", "家庭"]
        var lines: [String] = []
        for _ in 0..<n {
            let y = 1950 + Int(rng.next() % 61), m = 1 + Int(rng.next() % 12)
            let dim = [31, (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
            let d = 1 + Int(rng.next() % UInt64(dim)), h = Int(rng.next() % 24), mi = Int(rng.next() % 60)
            let male = rng.next() % 2 == 0
            let b = BaZi(y, m, d, hour: h, minute: mi, male: male)
            let zw = ZiWei(y, m, d, hour: h, male: male)
            let ny = 2025 + Int(rng.next() % 3)
            let years = Array((ny - 1)...(ny + 3)).filter { $0 > y }
            let (start, seq) = b.luck(count: 8)
            var rec: [String: Any] = [
                "y": y, "m": m, "d": d, "h": h, "mi": mi, "male": male, "pillars": b.pillars, "dayMaster": b.dayMaster,
                "luckStart": start, "luck": seq, "strong": b.strength().strong, "favorable": b.favorable(),
                "lunar": zw.lunar.text, "hourBranch": zw.hourBranch, "ming": zw.ming, "shen": zw.shen, "ju": zw.ju,
                "yearStem": zw.yearStem, "now": ny,
                "bazi_natal": BaZiReading.natal(b, male: male, nowYear: ny, birthYear: y),
            ]
            var by: [String: String] = [:], bv: [String: String] = [:]
            for yy in years {
                let r = BaZiReading.year(b, male: male, y: yy, birthYear: y)
                by["\(yy)"] = r.text; bv["\(yy)"] = "\(r.verdict)"
            }
            rec["bazi_years"] = by; rec["bazi_verdicts"] = bv
            var bt: [String: String] = [:]
            for t in topics { bt[t] = BaZiReading.topic(b, male: male, kind: t, y: ny) }
            rec["bazi_topics"] = bt
            var bm: [String] = []
            for mm in 1...12 { bm.append(BaZiReading.month(b, male: male, date: (ny, mm, 15))) }
            rec["bazi_months"] = bm

            // 紫微
            var stars: [String: Int] = [:]
            for br in 0..<12 { for s in zw.main[br] + zw.aux[br] { stars[s] = br } }
            rec["zw_stars"] = stars
            rec["zw_main"] = zw.main; rec["zw_aux"] = zw.aux
            rec["zw_palaceAt"] = (0..<12).map { zw.palaceAt[$0]! }
            rec["zw_stemAt"] = (0..<12).map { zw.stemAt[$0]! }
            rec["zw_sihua"] = zw.sihuaOf
            rec["zw_decades"] = zw.decades().map { [$0.branch, $0.from, $0.to] }
            if ny > y { rec["zw_natal"] = ZiWeiReading.natal(zw, male: male, age: ny - y, year: ny) }
            var zy: [String: String] = [:], zh: [String: [[String]]] = [:]
            for yy in years {
                zy["\(yy)"] = ZiWeiReading.year(zw, male: male, age: yy - y, year: yy).text
                zh["\(yy)"] = ZiWeiReading.yearHua(zw, year: yy).map { [$0.tag, $0.star, $0.year ?? "", $0.natal ?? ""] }
            }
            rec["zw_years"] = zy; rec["zw_yearhua"] = zh
            var zp: [String: String] = [:]
            for p in ZiWei.palaces { zp[p] = ZiWeiReading.palace(zw, name: p, year: ny) }
            rec["zw_palaces"] = zp
            let mm = 1 + Int(rng.next() % 12)
            var comps = DateComponents(); comps.year = ny; comps.month = mm; comps.day = 20
            rec["zw_month_date"] = [ny, mm, 20]
            rec["zw_month"] = ZiWeiReading.month(zw, now: Calendar(identifier: .gregorian).date(from: comps)!)
            let data = try JSONSerialization.data(withJSONObject: rec, options: [.sortedKeys])
            lines.append(String(decoding: data, as: UTF8.self))
        }
        try (lines.joined(separator: "\n") + "\n").write(toFile: out, atomically: true, encoding: .utf8)
    }
}
