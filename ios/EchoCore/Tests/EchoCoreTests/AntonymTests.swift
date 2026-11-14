import XCTest
@testable import EchoCore

/// 反義詞訓練（ai/lexicon/gen_antonym_tests.py 產生）：
///   of：「開心的反義詞是什麼」→ 回答要有相反的詞；詞庫沒有的詞要上網查
///   pair：「大和小是反義詞嗎」→ 是一對說「對」、不是說「不是」
///   trap：「什麼是反義詞」「相反數怎麼算」→ 不是在問某個詞的反義詞
/// 平常跑 20,000 題樣本＋20,000 題沒看過的；NINESUN_ANT=檔案 跑全部 500,000 題。
final class AntonymTests: XCTestCase {
    struct Q: Decodable { let type: String; let q: String; let a: String; let b: String; let expect: [String]; let web: Bool }

    func check(_ x: Q) -> String? {
        switch x.type {
        case "of":
            guard case let .of(w)? = Antonyms.parse(x.q) else { return "沒認出是在問反義詞" }
            guard w == x.a else { return "詞抓成「\(w)」" }
            let ans = Antonyms.answer(.of(w))
            if x.web { return ans == nil ? nil : "詞庫沒有這個詞，卻回答了" }
            guard let a = ans else { return "詞庫有這個詞，卻沒回答" }
            return x.expect.contains(where: { a.contains($0) }) ? nil : "回答裡沒有反義詞：\(a.prefix(40))"
        case "pair":
            guard case let .pair(a, b)? = Antonyms.parse(x.q) else { return "沒認出是在問兩個詞是不是相反" }
            guard a == x.a, b == x.b else { return "詞抓成「\(a)」「\(b)」" }
            guard let ans = Antonyms.answer(.pair(a, b)) else { return "沒有回答" }
            return ans.hasPrefix(x.expect[0]) ? nil : "應該說「\(x.expect[0])」：\(ans.prefix(40))"
        default:
            if let a = Antonyms.parse(x.q) { return "不是在問某個詞的反義詞，卻當成 \(a)" }
            return nil
        }
    }

    func run(_ name: String, path: String?, min: Double) throws {
        let url = try path.map { URL(fileURLWithPath: $0) }
            ?? XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url))
        var wrong = 0, ex: [String: [String]] = [:], cnt: [String: Int] = [:]
        for x in qs {
            if let why = check(x) {
                wrong += 1
                let k = x.type + " · " + String(why.prefix(while: { $0 != "：" && $0 != "（" && $0 != "「" }))
                cnt[k, default: 0] += 1
                if (ex[k]?.count ?? 0) < 8 { ex[k, default: []].append("「\(x.q)」→ \(why)") }
            }
        }
        let n = qs.count
        var out = "ANTONYM[\(name)] 共 \(n) 題，答對 \(n - wrong)（\(String(format: "%.2f", Double(n - wrong) * 100 / Double(n)))%）\n"
        for (k, c) in cnt.sorted(by: { $0.value > $1.value }) { out += "\n【\(k)】\(c) 題\n" + (ex[k] ?? []).map { "  " + $0 }.joined(separator: "\n") + "\n" }
        if let p = ProcessInfo.processInfo.environment["NINESUN_ANT_OUT"] { try out.write(toFile: p + "." + name + ".txt", atomically: true, encoding: .utf8) }
        print(out.prefix(5000))
        XCTAssertGreaterThanOrEqual(Double(n - wrong) / Double(n), min, String(out.prefix(2000)))
    }

    func testTrain() throws { try run("antonym_sample", path: ProcessInfo.processInfo.environment["NINESUN_ANT"], min: 0.99) }
    func testHoldout() throws { try run("antonym_holdout", path: nil, min: Double(ProcessInfo.processInfo.environment["NINESUN_ANT_HOLD_MIN"] ?? "0.97") ?? 0.97) }

    /// 整個引擎：反義詞在本地回答，詞庫沒有的、問反義詞概念的上網查
    func testEngineRouting() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "antonym_sample", withExtension: "json", subdirectory: "Fixtures"))
        let qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url)).prefix(1500)
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 5)
        var ctx = EchoEngine.Context(now: t.date(2026, 10, 23, 15))
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 8, minute: 0, male: true)
        var bad: [String] = []
        for x in qs where x.type != "trap" {
            let r = engine.reply(to: x.q, context: ctx)
            let web = r.webQuery != nil
            if x.web != web || (!x.web && r.turn.source != .knowledge) { bad.append("「\(x.q)」→ web=\(web) \(r.turn.source.rawValue)：\(r.turn.text.prefix(30))") }
        }
        XCTAssertLessThanOrEqual(bad.count, qs.count / 100, bad.prefix(15).joined(separator: "\n"))
    }
}
