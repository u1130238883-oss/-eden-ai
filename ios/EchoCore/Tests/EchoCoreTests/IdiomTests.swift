import XCTest
@testable import EchoCore

/// 成語訓練（ai/idioms/gen.py 產生，每組 500,000 題；平常跑 20,000 題樣本＋20,000 題沒看過的問法）：
///   understand：看懂在問意思、用法、出處、找某一類的成語、用成語說心情、用成語說毛病、近義、反義
///   near／anti：近義、反義成語，兩個成語意思一不一樣、是不是相反
///   translate：成語 ↔ 英西義的對應說法，外文 → 另一種外文
/// NINESUN_IDIOM_DIR=資料夾（裡面有 id_<組>_train.json）跑全部 500,000 題。
final class IdiomTests: XCTestCase {
    struct Q: Decodable {
        let q: String; let intent: String?; let idiom: String; let extra: String?; let expect: [String]
        let src: String?; let target: String?; let text: String?
    }

    func check(_ set: String, _ x: Q) -> String? {
        if set == "translate" { return checkTranslate(x) }
        let u = Idioms.understand(x.q)
        let intent = x.intent ?? ""
        if intent == "none" { return u == nil ? nil : "不是成語的問題，卻認成 \(u!.intent)「\(u!.idiom)」" }
        guard let u else { return "沒看懂（應該是 \(intent)）" }
        guard u.intent == intent else { return "應該是 \(intent)，看成 \(u.intent)「\(u.idiom)」" }
        if !x.idiom.isEmpty, u.idiom != x.idiom { return "成語抓成「\(u.idiom)」" }
        switch intent {
        case "feeling":
            let m = Affect.detect(x.q)
            return m.rawValue == x.extra ? nil : "心情應該是 \(x.extra ?? "")，聽成 \(m.rawValue)"
        case "problem":
            guard let q = Idioms.problemQuery(u.idiom) else { return "沒有改善的查詢" }
            let core = (x.extra ?? "").split(whereSeparator: { "，、；".contains($0) }).first.map(String.init) ?? ""
            return q.contains(core) ? nil : "查詢沒用成語的意思：\(q)"
        case "origin":
            return Idioms.answer(u) == nil ? nil : "出處要上網查"
        case "meaning" where x.extra == "unknown":
            return Idioms.answer(u) == nil ? nil : "成語庫沒有這個成語，卻回答了"
        case "theme":
            guard u.extra == x.extra else { return "主題抓成「\(u.extra)」" }
            guard let a = Idioms.answer(u) else { return "沒有回答" }
            return x.expect.contains(where: { a.contains($0) }) ? nil : "回答裡沒有這類成語：\(a.prefix(40))"
        case "pairNear", "pairAnti":
            guard u.extra == x.extra else { return "第二個成語抓成「\(u.extra)」" }
            guard let a = Idioms.answer(u) else { return "沒有回答" }
            return a.hasPrefix(x.expect[0]) ? nil : "應該說「\(x.expect[0])」：\(a.prefix(40))"
        default:
            guard let a = Idioms.answer(u) else { return "沒有回答" }
            if x.expect.isEmpty { return nil }
            return x.expect.contains(where: { a.contains($0) }) ? nil : "回答不對：\(a.prefix(50))"
        }
    }

    func checkTranslate(_ x: Q) -> String? {
        var got: String?
        if let r = Translate.parse(x.q) {
            guard r.target.rawValue == x.target else { return "翻成的語言應該是 \(x.target ?? "")，聽成 \(r.target.rawValue)（「\(r.text)」）" }
            guard let res = Native.lookup(r) else { return "沒有用成語對照（內容「\(r.text)」）" }
            got = res.text
        } else if let u = Idioms.understand(x.q), u.intent == "reverse" {
            guard x.target == "zh-Hant" else { return "應該翻成 \(x.target ?? "")，卻找成語" }
            got = u.idiom
        } else {
            return "沒聽懂是要翻譯"
        }
        return x.expect.contains(got ?? "") ? nil : "翻成「\(got ?? "")」，應該是「\(x.expect.joined(separator: "／"))」"
    }

    func run(_ set: String, hold: Bool, min: Double) throws {
        let name = "idiom_\(set)_" + (hold ? "holdout" : "sample")
        let url: URL
        if !hold, let dir = ProcessInfo.processInfo.environment["NINESUN_IDIOM_DIR"] {
            url = URL(fileURLWithPath: dir + "/id_\(set)_train.json")
        } else {
            url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        }
        let qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url))
        var wrong = 0, ex: [String: [String]] = [:], cnt: [String: Int] = [:]
        for x in qs {
            if let why = check(set, x) {
                wrong += 1
                let k = (x.intent ?? x.target ?? "") + " · " + String(why.prefix(while: { $0 != "：" && $0 != "（" && $0 != "「" }))
                cnt[k, default: 0] += 1
                if (ex[k]?.count ?? 0) < 8 { ex[k, default: []].append("「\(x.q)」→ \(why)") }
            }
        }
        let n = qs.count
        var out = "IDIOM[\(name)] 共 \(n) 題，答對 \(n - wrong)（\(String(format: "%.2f", Double(n - wrong) * 100 / Double(n)))%）\n"
        for (k, c) in cnt.sorted(by: { $0.value > $1.value }) { out += "\n【\(k)】\(c) 題\n" + (ex[k] ?? []).map { "  " + $0 }.joined(separator: "\n") + "\n" }
        if let p = ProcessInfo.processInfo.environment["NINESUN_IDIOM_OUT"] { try out.write(toFile: p + "." + name + ".txt", atomically: true, encoding: .utf8) }
        print(out.prefix(4000))
        XCTAssertGreaterThanOrEqual(Double(n - wrong) / Double(n), min, String(out.prefix(2000)))
    }

    func testUnderstand() throws { try run("understand", hold: false, min: 0.99) }
    func testUnderstandHoldout() throws { try run("understand", hold: true, min: 0.97) }
    func testNear() throws { try run("near", hold: false, min: 0.99) }
    func testNearHoldout() throws { try run("near", hold: true, min: 0.97) }
    func testAnti() throws { try run("anti", hold: false, min: 0.99) }
    func testAntiHoldout() throws { try run("anti", hold: true, min: 0.97) }
    func testTranslate() throws { try run("translate", hold: false, min: 0.99) }
    func testTranslateHoldout() throws { try run("translate", hold: true, min: 0.97) }

    /// 整個引擎：成語的問題在本地回答；出處、詞庫沒有的成語、用成語說的毛病上網查
    func testEngineRouting() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "idiom_understand_sample", withExtension: "json", subdirectory: "Fixtures"))
        let qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url)).prefix(2000)
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 5)
        var ctx = EchoEngine.Context(now: t.date(2026, 10, 23, 15))
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 8, minute: 0, male: true)
        var bad: [String] = []
        for x in qs where !["none", "feeling"].contains(x.intent ?? "") {
            let r = engine.reply(to: x.q, context: ctx)
            let wantWeb = ["origin", "problem"].contains(x.intent ?? "") || x.extra == "unknown"
            let web = r.webQuery != nil
            if wantWeb != web || (!wantWeb && r.turn.source != .knowledge) { bad.append("「\(x.q)」（\(x.intent ?? "")）→ web=\(web) \(r.turn.source.rawValue)：\(r.turn.text.prefix(30))") }
        }
        if let p = ProcessInfo.processInfo.environment["NINESUN_IDIOM_OUT"] { try bad.joined(separator: "\n").write(toFile: p + ".engine.txt", atomically: true, encoding: .utf8) }
        print("IDIOM-ENGINE 不對 \(bad.count) 題\n" + bad.prefix(20).joined(separator: "\n"))
        XCTAssertLessThanOrEqual(bad.count, qs.count / 100, bad.prefix(15).joined(separator: "\n"))
    }
}
