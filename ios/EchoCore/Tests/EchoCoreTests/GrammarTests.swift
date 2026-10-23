import XCTest
@testable import EchoCore

/// 詞性＋仿寫（ai/grammar/gen.py，500,000 篇小短文）：
///   分析詞性：每個內容詞（名詞、動詞、形容詞、副詞）都要切對、標對
///   仿寫：詞性的順序一樣、功能詞一樣（結構相同），每個內容詞都換成別的詞，而且仿寫出來的短文也要標得出同樣的詞性
/// 平常跑 20,000 篇樣本＋20,000 篇沒看過的詞和句型；NINESUN_GR=檔案 跑全部 500,000 篇。
final class GrammarTests: XCTestCase {
    struct Q: Decodable { let q: String; let text: String; let kind: String; let tokens: [[String]] }

    func check(_ x: Q) -> String? {
        guard let a = Grammar.parse(x.q) else { return "沒聽懂要做什麼" }
        guard a.kind.rawValue == x.kind else { return "應該是 \(x.kind)，聽成 \(a.kind.rawValue)" }
        guard a.text == x.text else { return "短文抓成「\(a.text.prefix(20))」" }
        let t = Grammar.tag(x.text)
        let got = Grammar.content(t).map { [$0.text, $0.pos!.rawValue] }
        if x.kind == "tag" {
            if got != x.tokens {
                let i = zip(got, x.tokens).firstIndex { $0 != $1 } ?? min(got.count, x.tokens.count)
                let g = i < got.count ? got[i].joined(separator: "/") : "（沒有）", w = i < x.tokens.count ? x.tokens[i].joined(separator: "/") : "（沒有）"
                return "詞性標錯：\(g)，應該是 \(w)"
            }
            return nil
        }
        // 仿寫
        let new = Grammar.imitate(x.text)
        guard new == Grammar.imitate(x.text) else { return "同一篇仿寫兩次不一樣" }
        guard new != x.text else { return "仿寫跟原文一樣" }
        let nt = Grammar.tag(new)
        let gold = x.tokens.map { $0[1] }
        let newPOS = Grammar.content(nt).map { $0.pos!.rawValue }
        guard newPOS == gold else { return "仿寫的詞性順序不一樣：\(newPOS.joined()) ≠ \(gold.joined())：\(new.prefix(30))" }
        // 結構：功能詞一樣（用標準答案的詞性換掉原文的內容詞）
        var sk = x.text
        for tk in x.tokens { if let r = sk.range(of: tk[0]) { sk.replaceSubrange(r, with: "\u{1}") } }
        let goldSkeleton = sk.split(separator: "\u{1}", omittingEmptySubsequences: false).joined(separator: "_")
        var nk = new
        for tk in Grammar.content(nt) { if let r = nk.range(of: tk.text) { nk.replaceSubrange(r, with: "\u{1}") } }
        let newSkeleton = nk.split(separator: "\u{1}", omittingEmptySubsequences: false).joined(separator: "_")
        guard newSkeleton == goldSkeleton else { return "功能詞不一樣：\(new.prefix(30))" }
        for (o, n) in zip(x.tokens.map { $0[0] }, Grammar.content(nt).map(\.text)) where o == n { return "「\(o)」沒有換：\(new.prefix(30))" }
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
                let k = x.kind + " · " + String(why.prefix(while: { $0 != "：" && $0 != "「" }))
                cnt[k, default: 0] += 1
                if (ex[k]?.count ?? 0) < 10 { ex[k, default: []].append("「\(x.text.prefix(40))」→ \(why)") }
            }
        }
        let n = qs.count
        var out = "GRAMMAR[\(name)] 共 \(n) 篇，答對 \(n - wrong)（\(String(format: "%.2f", Double(n - wrong) * 100 / Double(n)))%）\n"
        for (k, c) in cnt.sorted(by: { $0.value > $1.value }) { out += "\n【\(k)】\(c) 篇\n" + (ex[k] ?? []).map { "  " + $0 }.joined(separator: "\n") + "\n" }
        if let p = ProcessInfo.processInfo.environment["NINESUN_GR_OUT"] { try out.write(toFile: p + "." + name + ".txt", atomically: true, encoding: .utf8) }
        print(out.prefix(4000))
        XCTAssertGreaterThanOrEqual(Double(n - wrong) / Double(n), min, String(out.prefix(2000)))
    }

    func testTrain() throws { try run("grammar_sample", path: ProcessInfo.processInfo.environment["NINESUN_GR"], min: 0.99) }
    func testHoldout() throws { try run("grammar_holdout", path: nil, min: 0.97) }

    func testEngine() throws {
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 5)
        let ctx = EchoEngine.Context(now: t.date(2026, 10, 23, 15))
        let a = engine.reply(to: "分析詞性：美麗的蝴蝶輕輕地飛翔。", context: ctx).turn.text
        XCTAssertTrue(a.hasPrefix("🔍"), a)
        XCTAssertTrue(a.contains("蝴蝶") && a.contains("美麗") && a.contains("輕輕") && a.contains("飛翔"), a)
        let b = engine.reply(to: "仿寫：美麗的蝴蝶輕輕地飛翔。", context: ctx).turn.text
        print("GRAMMAR-EXAMPLE\n\(a)\n\n\(b)")
        XCTAssertTrue(b.hasPrefix("✍️ 仿寫"), b)
    }
}
