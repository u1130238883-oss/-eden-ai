import XCTest
@testable import EchoCore

/// 近義詞訓練（ai/lexicon/gen_tests.py 產生）：
///   near：「開心的近義詞是什麼」→ 回答要有同一組的詞；詞庫沒有的詞要上網查
///   pair：「開心和快樂意思一樣嗎」→ 同一組說「相近」、不同組說「不一樣」
///   para：同一個問題換個說法（「羅浮宮位在何處」＝「羅浮宮在哪裡」）→ 題型、主題要一樣
/// 平常跑 20,000 題樣本＋20,000 題沒看過的；NINESUN_SYN=檔案 跑全部 500,000 題。
final class SynonymTests: XCTestCase {
    struct Q: Decodable { let type: String; let q: String; let a: String; let b: String; let expect: [String]; let web: Bool }

    func check(_ x: Q) -> String? {
        switch x.type {
        case "near":
            guard case let .near(w)? = Synonyms.parse(x.q) else { return "沒認出是在問近義詞" }
            guard w == x.a else { return "詞抓成「\(w)」" }
            let ans = Synonyms.answer(.near(w))
            if x.web { return ans == nil ? nil : "詞庫沒有這個詞，卻回答了" }
            guard let a = ans else { return "詞庫有這個詞，卻沒回答" }
            return x.expect.contains(where: { a.contains($0) }) ? nil : "回答裡沒有近義詞：\(a.prefix(40))"
        case "pair":
            guard case let .pair(a, b)? = Synonyms.parse(x.q) else { return "沒認出是在比較兩個詞" }
            guard a == x.a, b == x.b else { return "詞抓成「\(a)」「\(b)」" }
            guard let ans = Synonyms.answer(.pair(a, b)) else { return "沒有回答" }
            return ans.contains(x.expect[0]) ? nil : "應該說「\(x.expect[0])」：\(ans.prefix(30))"
        default:
            let f = Understanding.frame(x.q)
            let w = UnderstandingCorpusTests.wantName(f.want)
            if w != x.b { return "題型應該是 \(x.b)，理解成 \(w)（主題「\(f.subject)」）" }
            let n = UnderstandingCorpusTests.norm
            return n(f.subject).contains(n(x.a)) || f.searches.contains(where: { n($0).contains(n(x.a)) }) ? nil : "主題應該包含「\(x.a)」，理解成「\(f.subject)」"
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
        var out = "SYNONYM[\(name)] 共 \(n) 題，答對 \(n - wrong)（\(String(format: "%.2f", Double(n - wrong) * 100 / Double(n)))%）\n"
        for (k, c) in cnt.sorted(by: { $0.value > $1.value }) { out += "\n【\(k)】\(c) 題\n" + (ex[k] ?? []).map { "  " + $0 }.joined(separator: "\n") + "\n" }
        if let p = ProcessInfo.processInfo.environment["NINESUN_SYN_OUT"] { try out.write(toFile: p + "." + name + ".txt", atomically: true, encoding: .utf8) }
        print(out.prefix(5000))
        XCTAssertGreaterThanOrEqual(Double(n - wrong) / Double(n), min, String(out.prefix(2000)))
    }

    func testTrain() throws { try run("synonym_sample", path: ProcessInfo.processInfo.environment["NINESUN_SYN"], min: 0.99) }
    func testHoldout() throws { try run("synonym_holdout", path: nil, min: Double(ProcessInfo.processInfo.environment["NINESUN_SYN_HOLD_MIN"] ?? "0.97") ?? 0.97) }

    /// 整個引擎：近義詞的問題在本地回答（資料庫），詞庫沒有的上網查；換個說法的問題要上網
    func testEngineRouting() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "synonym_sample", withExtension: "json", subdirectory: "Fixtures"))
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
        for x in qs {
            let r = engine.reply(to: x.q, context: ctx)
            let web = r.webQuery != nil
            if x.web != web || (!x.web && r.turn.source != .knowledge) { bad.append("「\(x.q)」→ web=\(web) \(r.turn.source.rawValue)：\(r.turn.text.prefix(30))") }
        }
        XCTAssertLessThanOrEqual(bad.count, qs.count / 100, bad.prefix(15).joined(separator: "\n"))
    }
}
