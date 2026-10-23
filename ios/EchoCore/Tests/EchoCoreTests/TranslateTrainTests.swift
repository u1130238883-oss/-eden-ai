import XCTest
@testable import EchoCore

/// 中英西義互相翻譯（ai/translate/gen.py，500,000 題）：單字、短語、句子 × 四種語言互翻 × 各種問法，
/// 每一題都要聽懂「要翻什麼、翻成哪種語言」；不是翻譯的不能硬翻。
/// 平常跑 20,000 題樣本＋20,000 題沒看過的內容和問法；NINESUN_TR=檔案 跑全部 500,000 題。
final class TranslateTrainTests: XCTestCase {
    struct Q: Decodable { let q: String; let text: String?; let target: String?; let kind: String }

    static func norm(_ s: String?) -> String? {
        s?.trimmingCharacters(in: CharacterSet(charactersIn: "?？。.!！ ")).lowercased()
    }

    func check(_ x: Q) -> String? {
        let r = Translate.parse(x.q)
        guard let text = x.text else { return r.map { "不是翻譯，卻翻「\($0.text)」" } }
        guard let r else { return "沒聽懂是要翻譯" }
        guard r.target.rawValue == x.target else { return "語言應該是 \(x.target ?? "")，聽成 \(r.target.rawValue)" }
        let a = Self.norm(r.text), b = Self.norm(text)
        // 「請問」「那個」可以是內容也可以是客氣話
        if a == b || a == "請問" + (b ?? "") || a == "那個" + (b ?? "") { return nil }
        return "內容抓成「\(r.text)」，應該是「\(text)」"
    }

    func run(_ name: String, path: String?, min: Double) throws {
        let url = try path.map { URL(fileURLWithPath: $0) }
            ?? XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url))
        var wrong = 0, ex: [String: [String]] = [:], cnt: [String: Int] = [:]
        for x in qs {
            if let why = check(x) {
                wrong += 1
                let k = x.kind + " · " + String(why.prefix(while: { $0 != "：" && $0 != "（" && $0 != "「" && $0 != "，" }))
                cnt[k, default: 0] += 1
                if (ex[k]?.count ?? 0) < 10 { ex[k, default: []].append("「\(x.q)」→ \(why)") }
            }
        }
        let n = qs.count
        var out = "TRANSLATE[\(name)] 共 \(n) 題，答對 \(n - wrong)（\(String(format: "%.2f", Double(n - wrong) * 100 / Double(n)))%）\n"
        for (k, c) in cnt.sorted(by: { $0.value > $1.value }) { out += "\n【\(k)】\(c) 題\n" + (ex[k] ?? []).map { "  " + $0 }.joined(separator: "\n") + "\n" }
        if let p = ProcessInfo.processInfo.environment["NINESUN_TR_OUT"] { try out.write(toFile: p + "." + name + ".txt", atomically: true, encoding: .utf8) }
        print(out.prefix(4000))
        XCTAssertGreaterThanOrEqual(Double(n - wrong) / Double(n), min, String(out.prefix(2000)))
    }

    func testTrain() throws { try run("translate_train_sample", path: ProcessInfo.processInfo.environment["NINESUN_TR"], min: 0.99) }
    func testHoldout() throws { try run("translate_train_holdout", path: nil, min: 0.97) }
}
