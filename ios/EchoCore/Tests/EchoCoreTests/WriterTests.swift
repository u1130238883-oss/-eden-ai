import XCTest
@testable import EchoCore

/// 寫作訓練（ai/writing/gen.py，500,000 題）：擴寫（中英西義）、詳寫、修改。每一題都要：
///   字數至少是原句的 9 倍（中文算字，英西義算單字）、有環境、感受、觀點、比喻、成語／諺語、提到主角、
///   不混其他語言、不重複；詳寫和修改還要有至少三個高級詞、不能有衝突的情緒；
///   第一稿寫得不好（檢查出問題）→ 至少修改一次 → 最後一稿沒有問題。
/// 平常跑 20,000 題樣本＋20,000 題沒看過的主角、動作、問法；NINESUN_WR=檔案 跑全部 500,000 題。
final class WriterTests: XCTestCase {
    struct Q: Decodable {
        let q: String; let kind: String; let lang: String; let original: String; let subject: String; let cat: String; let min: Int
        let elevated: [String]; let avoid: [String]
    }

    func check(_ x: Q, hold: Bool) -> String? {
        let a = Writer.parse(x.q)
        if x.kind == "none" { return a.map { "不是要寫作，卻當成 \($0.kind.rawValue)「\($0.original)」" } }
        guard let a else { return "沒聽懂是要寫作" }
        if x.kind == "polish" { guard a.kind == .polish else { return "應該是修改，聽成 \(a.kind.rawValue)" } }
        else if a.kind == .polish { return "應該是 \(x.kind)，聽成修改" }
        guard a.lang == x.lang else { return "語言應該是 \(x.lang)，聽成 \(a.lang)" }
        let r = Writer.write(a)
        guard r.text == Writer.write(a).text else { return "同一題寫兩次不一樣" }
        let problems = Writer.review(r.text, a)
        if let p = problems.first { return "最後一稿還有問題：\(p)：\(r.text.prefix(40))" }
        let u = Writer.units(r.text, lang: x.lang)
        if u < x.min { return "字數不夠：\(u)／至少 \(x.min)" }
        if !x.subject.isEmpty, r.text.range(of: x.subject, options: .caseInsensitive) == nil { return "沒有寫到主角「\(x.subject)」" }
        if x.lang != "zh", Writer.units(r.text, lang: "zh") > 0 { return "混進了中文" }
        // 詳寫、修改（用人物情緒的寫法）才檢查高級詞和情緒衝突；同一句話用擴寫的寫法也可以
        if a.kind != .expand {
            if !x.elevated.isEmpty, x.elevated.filter({ r.text.contains($0) }).count < 3 { return "高級詞太少" }
            if let w = x.avoid.first(where: { r.text.contains($0) }) { return "情緒不對：「\(w)」" }
        }
        guard r.drafts.count >= 2, !Writer.review(r.drafts[0], a).isEmpty else { return "沒有經過修改" }
        return nil
    }

    func run(_ name: String, path: String?, min: Double, hold: Bool) throws {
        let url = try path.map { URL(fileURLWithPath: $0) }
            ?? XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url))
        var wrong = 0, ex: [String: [String]] = [:], cnt: [String: Int] = [:]
        for x in qs {
            if let why = check(x, hold: hold) {
                wrong += 1
                let k = x.kind + "/" + x.lang + " · " + String(why.prefix(while: { $0 != "：" && $0 != "（" && $0 != "「" }))
                cnt[k, default: 0] += 1
                if (ex[k]?.count ?? 0) < 8 { ex[k, default: []].append("「\(x.q)」→ \(why)") }
            }
        }
        let n = qs.count
        var out = "WRITER[\(name)] 共 \(n) 題，答對 \(n - wrong)（\(String(format: "%.2f", Double(n - wrong) * 100 / Double(n)))%）\n"
        for (k, c) in cnt.sorted(by: { $0.value > $1.value }) { out += "\n【\(k)】\(c) 題\n" + (ex[k] ?? []).map { "  " + $0 }.joined(separator: "\n") + "\n" }
        if let p = ProcessInfo.processInfo.environment["NINESUN_WR_OUT"] { try out.write(toFile: p + "." + name + ".txt", atomically: true, encoding: .utf8) }
        print(out.prefix(4000))
        XCTAssertGreaterThanOrEqual(Double(n - wrong) / Double(n), min, String(out.prefix(2000)))
    }

    func testTrain() throws { try run("writer_sample", path: ProcessInfo.processInfo.environment["NINESUN_WR"], min: 0.99, hold: false) }
    func testHoldout() throws { try run("writer_holdout", path: nil, min: 0.97, hold: true) }

    /// 整個引擎：寫作的題目由寫作模組回答
    func testEngineRouting() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "writer_sample", withExtension: "json", subdirectory: "Fixtures"))
        let qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url)).prefix(1500)
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 5)
        var ctx = EchoEngine.Context(now: t.date(2026, 10, 23, 15))
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 8, minute: 0, male: true)
        ctx.autoDetect = true
        var bad: [String] = []
        for x in qs {
            let text = engine.reply(to: x.q, context: ctx).turn.text
            if (x.kind == "none") == text.hasPrefix("✍️") { bad.append("「\(x.q)」（\(x.kind)）→ \(text.prefix(30))") }
        }
        if let p = ProcessInfo.processInfo.environment["NINESUN_WR_OUT"] { try bad.joined(separator: "\n").write(toFile: p + ".engine.txt", atomically: true, encoding: .utf8) }
        XCTAssertLessThanOrEqual(bad.count, qs.count / 100, bad.prefix(15).joined(separator: "\n"))
    }

    /// 例子：印出來看寫得好不好
    func testShowExamples() {
        for q in ["擴寫：樹在成長", "小明哭了，請詳寫", "Expand: The tree is growing.", "Amplía: El río fluye en silencio.", "Espandi: Il sole sta sorgendo.",
                  "幫我修改這段：小美笑了。小美很開心。", "描寫下雨天"] {
            guard let a = Writer.parse(q) else { print("WRITER-EXAMPLE 沒聽懂：\(q)"); continue }
            print("WRITER-EXAMPLE 「\(q)」\n" + Writer.reply(a) + "\n")
        }
    }
}
