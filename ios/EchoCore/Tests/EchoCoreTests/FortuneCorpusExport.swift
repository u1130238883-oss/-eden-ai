import XCTest
@testable import EchoCore

/// 命理語料：用 NineSun 自己的八字、紫微斗數、農曆、節氣程式真的排盤，把結果輸出成 JSON，
/// 再由 ai/corpus/gen_fortune.py 寫成問答（答案跟 App 算的一模一樣）。
/// NINESUN_FORTUNE_OUT=輸出.jsonl NINESUN_FORTUNE_N=筆數 …xctest EchoCoreTests.FortuneCorpusExport
final class FortuneCorpusExport: XCTestCase {
    func testExport() throws {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["NINESUN_FORTUNE_OUT"] else { throw XCTSkip("") }
        let n = Int(env["NINESUN_FORTUNE_N"] ?? "") ?? 4000
        var rng = SplitMix(seed: 20261106)
        var text = ""
        for _ in 0..<n {
            let y = 1940 + Int(rng.next() % 86), m = 1 + Int(rng.next() % 12)
            let dim = [31, (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
            let d = 1 + Int(rng.next() % UInt64(dim)), h = Int(rng.next() % 24), mi = Int(rng.next() % 60)
            let male = rng.next() % 2 == 0
            let b = BaZi(y, m, d, hour: h, minute: mi, male: male)
            let zw = ZiWei(y, m, d, hour: h, male: male)
            let lunar = LunarCalendar.shared.lunar(y, m, d)
            let (start, seq) = b.luck(count: 8)
            let st = b.strength()
            // 太陽黃經（中午），七政四餘「太陽過宮」用
            let sunLon = Astro.sunLongitude(Astro.jd(y, m, d, hour: 12) - Astro.tz + Astro.deltaTDays(2000))
            var rec: [String: Any] = [
                "y": y, "m": m, "d": d, "h": h, "mi": mi, "male": male,
                "pillars": b.pillars, "text": b.text, "dayMaster": b.dayMaster,
                "strong": st.strong, "ratio": (st.ratio * 1000).rounded() / 1000,
                "favorable": b.favorable(), "luckStart": start, "luck": seq,
                "elements": b.elementCounts().map { ($0 * 10).rounded() / 10 },
                "lunar": lunar.text, "lunarMonth": lunar.month, "lunarDay": lunar.day, "leap": lunar.isLeap,
                "sunLon": (sunLon * 100).rounded() / 100,
                "zw": [
                    "ming": zw.ming, "shen": zw.shen, "ju": zw.ju, "yearStem": zw.yearStem, "hourBranch": zw.hourBranch,
                    "main": zw.main, "aux": zw.aux, "sihua": zw.sihuaOf,
                    "palaceAt": Dictionary(uniqueKeysWithValues: zw.palaceAt.map { (String($0.key), $0.value) }),
                    "stemAt": Dictionary(uniqueKeysWithValues: zw.stemAt.map { (String($0.key), $0.value) }),
                    "decades": zw.decades().map { [$0.branch, $0.from, $0.to] },
                ] as [String: Any],
            ]
            // 流年十神（2020～2035）
            rec["yearGods"] = (2020...2035).map { yy -> [Any] in let g = b.yearGod(yy); return [yy, g.gz, g.god] }
            let data = try JSONSerialization.data(withJSONObject: rec, options: [.sortedKeys])
            text += String(decoding: data, as: UTF8.self) + "\n"
        }
        try text.write(toFile: out, atomically: true, encoding: .utf8)
    }
}

/// 固定種子的亂數（每次產生一樣的語料）
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
