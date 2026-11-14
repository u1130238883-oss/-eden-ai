import XCTest
@testable import EchoCore

/// 排盤、解盤、解運勢的語料：用 NineSun 自己的八字、紫微程式排盤，再用 App 裡的解讀（BaZiReading、ZiWeiReading）寫出解盤和運勢，
/// 連同排盤要用到的節氣資料一起輸出，由 ai/corpus/gen_fortune_read.py 寫成問答。
/// NINESUN_READ_OUT=輸出.jsonl NINESUN_READ_N=筆數 …xctest EchoCoreTests.FortuneReadingsExport
final class FortuneReadingsExport: XCTestCase {
    func testExport() throws {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["NINESUN_READ_OUT"] else { throw XCTSkip("") }
        let n = Int(env["NINESUN_READ_N"] ?? "") ?? 6000
        var rng = SplitMix(seed: 10_000_000)
        let topics = ["感情", "錢財", "事業", "學業", "家庭"]
        let zwPalaces = ["夫妻", "財帛", "官祿", "疾厄"]
        let jieNames = ["立春", "驚蟄", "清明", "立夏", "芒種", "小暑", "立秋", "白露", "寒露", "立冬", "大雪", "小寒"]
        var text = ""
        func date(_ jd: Double) -> [Int] { let d = Astro.date(fromJD: jd + Astro.tz); return [d.0, d.1, d.2, Int(d.3 * 24)] }
        for _ in 0..<n {
            let y = 1950 + Int(rng.next() % 61), m = 1 + Int(rng.next() % 12)
            let dim = [31, (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
            let d = 1 + Int(rng.next() % UInt64(dim)), h = Int(rng.next() % 24), mi = Int(rng.next() % 60)
            let male = rng.next() % 2 == 0
            let b = BaZi(y, m, d, hour: h, minute: mi, male: male)
            let zw = ZiWei(y, m, d, hour: h, male: male)
            let ny = 2025 + Int(rng.next() % 4)
            let age = ny - y
            let mi2 = BaZi.jieIndex(b.jd)
            let (start, seq) = b.luck(count: 8)
            var rec: [String: Any] = [
                "y": y, "m": m, "d": d, "h": h, "mi": mi, "male": male, "pillars": b.pillars, "dayMaster": b.dayMaster,
                "lichun": date(Astro.solarTermJD(y, 315)), "jie": jieNames[mi2], "jieIndex": mi2,
                "luckStart": start, "luck": seq, "strong": b.strength().strong, "favorable": b.favorable(),
                "lunar": zw.lunar.text, "lunarMonth": zw.lunar.month, "lunarDay": zw.lunar.day, "leap": zw.lunar.isLeap,
                "hourBranch": zw.hourBranch, "ming": zw.ming, "shen": zw.shen, "ju": zw.ju, "yearStem": zw.yearStem,
                "mingStem": zw.stemAt[zw.ming]!, "ziwei": zw.main.firstIndex { $0.contains("紫微") }!,
                "now": ny, "age": age,
                "bazi_natal": BaZiReading.natal(b, male: male, nowYear: ny, birthYear: y),
                "bazi_year": BaZiReading.year(b, male: male, y: ny, birthYear: y).text,
                "bazi_year_verdict": "\(BaZiReading.year(b, male: male, y: ny, birthYear: y).verdict)",
            ]
            let tp = topics[Int(rng.next() % UInt64(topics.count))]
            rec["topic"] = tp
            rec["bazi_topic"] = BaZiReading.topic(b, male: male, kind: tp, y: ny)
            let mm = 1 + Int(rng.next() % 12)
            rec["month"] = [ny, mm, 15]
            rec["bazi_month"] = BaZiReading.month(b, male: male, date: (ny, mm, 15))
            if age > 0 {
                rec["zw_natal"] = ZiWeiReading.natal(zw, male: male, age: age, year: ny)
                rec["zw_year"] = ZiWeiReading.year(zw, male: male, age: age, year: ny).text
            }
            let pz = zwPalaces[Int(rng.next() % UInt64(zwPalaces.count))]
            rec["zw_palace_name"] = pz
            rec["zw_palace"] = ZiWeiReading.palace(zw, name: pz, year: ny)
            let data = try JSONSerialization.data(withJSONObject: rec, options: [.sortedKeys])
            text += String(decoding: data, as: UTF8.self) + "\n"
        }
        try text.write(toFile: out, atomically: true, encoding: .utf8)
    }
}
