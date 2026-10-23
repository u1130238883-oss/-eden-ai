import XCTest
@testable import EchoCore

/// 個性訓練（ai/idioms/gen.py voice，500,000 題）：每個生日對應 405 種命盤之一，
/// 同一句話不同的人用不同的語氣回應，配一句合適的成語——語氣要對（難過時心疼、好消息時恭喜），
/// 成語的語氣要對（難過時不說笑、不說教；生氣時勸冷靜），而且同一個人每次都一樣。
/// NINESUN_VOICE=檔案 跑全部 500,000 題。
final class VoiceTests: XCTestCase {
    struct Q: Decodable { let y: Int; let m: Int; let d: Int; let q: String; let mood: String; let allow: [String]; let ban: [String] }

    func check(_ x: Q) -> String? {
        let v = Voice(BirthDay(year: x.y, month: x.m, day: x.d))
        let mood = Affect.detect(x.q)
        guard mood.rawValue == x.mood else { return "心情應該是 \(x.mood)，聽成 \(mood.rawValue)" }
        let out = Affect.color("（回答）", for: x.q, seed: x.q.count, voice: v)
        guard out == Affect.color("（回答）", for: x.q, seed: x.q.count + 7, voice: v) else { return "同一個人回答不一樣" }
        guard Affect.hasTone(String(out.prefix(80)), mood) else { return "語氣不對：\(out.prefix(30))" }
        if Affect.clashes(out, mood) { return "語氣衝突：\(out.prefix(30))" }
        guard let e = v.idiom(for: mood, message: x.q) else { return "沒有配成語" }
        guard out.contains("「\(e.idiom)」") else { return "回答裡沒有成語" }
        if !e.tones.contains(where: { x.allow.contains($0) }) { return "成語「\(e.idiom)」語氣（\(e.tones.joined(separator: ","))）不適合" }
        if let b = e.tones.first(where: { x.ban.contains($0) }) { return "成語「\(e.idiom)」帶著「\(b)」的語氣，不能用在這裡" }
        return nil
    }

    func run(_ name: String, path: String?, min: Double) throws {
        let url = try path.map { URL(fileURLWithPath: $0) }
            ?? XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url))
        var wrong = 0, ex: [String: [String]] = [:], cnt: [String: Int] = [:]
        for x in qs {
            if let why = check(x) {
                wrong += 1
                let k = x.mood + " · " + String(why.prefix(while: { $0 != "：" && $0 != "（" && $0 != "「" }))
                cnt[k, default: 0] += 1
                if (ex[k]?.count ?? 0) < 8 { ex[k, default: []].append("「\(x.q)」\(x.y)/\(x.m)/\(x.d) → \(why)") }
            }
        }
        let n = qs.count
        var out = "VOICE[\(name)] 共 \(n) 題，答對 \(n - wrong)（\(String(format: "%.2f", Double(n - wrong) * 100 / Double(n)))%）\n"
        for (k, c) in cnt.sorted(by: { $0.value > $1.value }) { out += "\n【\(k)】\(c) 題\n" + (ex[k] ?? []).map { "  " + $0 }.joined(separator: "\n") + "\n" }
        if let p = ProcessInfo.processInfo.environment["NINESUN_VOICE_OUT"] { try out.write(toFile: p + "." + name + ".txt", atomically: true, encoding: .utf8) }
        print(out.prefix(4000))
        XCTAssertGreaterThanOrEqual(Double(n - wrong) / Double(n), min, String(out.prefix(2000)))
    }

    func testTrain() throws { try run("voice_sample", path: ProcessInfo.processInfo.environment["NINESUN_VOICE"], min: 0.99) }
    func testHoldout() throws { try run("voice_holdout", path: nil, min: 0.97) }

    /// 405 種不同的人：年月互換是同一張盤；同一句話，不同的人說法不一樣
    func testFourHundredFiveVoices() throws {
        XCTAssertEqual(Voice.all.count, 405)
        // 本命盤也剛好 405 種：不同的 key ⇔ 不同的盤
        var charts = Set<String>()
        for v in Voice.all {
            let p = v.key.split(separator: "-").map { Int($0)! }
            charts.insert(NTChart.natalStyle(NTTriple(p[0], p[1], p[2])).map(\.text).joined(separator: ","))
        }
        XCTAssertEqual(charts.count, 405)
        // 年月互換：同一個人
        XCTAssertEqual(Voice(BirthDay(year: 1983, month: 7, day: 12)).key, Voice(BirthDay(year: 1987, month: 3, day: 12)).key)
        for msg in ["我考上大學了", "我好難過", "明天要面試好緊張", "謝謝你", "我的狗過世了", "好無聊", "氣死我了"] {
            let outs = Set(Voice.all.map { Affect.color("", for: msg, voice: $0) })
            print("「\(msg)」：405 個人有 \(outs.count) 種不同的回應")
            XCTAssertGreaterThanOrEqual(outs.count, 30, msg)
        }
    }

    /// 整個引擎：有生日的人，回答帶著他的個性和成語
    func testEngineVoice() throws {
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 5)
        var ctx = EchoEngine.Context(now: t.date(2026, 10, 23, 15))
        ctx.profile = UserProfile(birthday: BirthDay(year: 1990, month: 5, day: 20), hour: 8, minute: 0, male: false)
        for msg in ["我考上研究所了！", "我好難過", "謝謝你"] {
            let text = engine.reply(to: msg, context: ctx).turn.text
            XCTAssertTrue(text.contains("💬"), "\(msg) → \(text.prefix(80))")
        }
    }
}
