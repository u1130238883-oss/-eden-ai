import XCTest
@testable import EchoCore

/// 10000 題翻譯問法（ai/translate_questions.py 產生）：每一題都要聽懂「要翻什麼、翻成哪種語言」，不是翻譯的不能硬翻
final class TranslateQuestionsTests: XCTestCase {
    struct Q: Decodable { let q: String; let text: String?; let target: String? }

    func testTenThousandQuestions() throws { try run("translate_questions") }
    /// 第二批：新的問法、簡稱（中翻英、翻西）、英西義的其他說法
    func testTenThousandMore() throws { try run("translate_questions2") }

    func run(_ name: String) throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url))
        var bad: [String] = []
        for x in qs {
            let r = Translate.parse(x.q)
            // 句尾的問號算不算進內容都一樣（翻譯結果相同）
            func n(_ s: String?) -> String? { s?.trimmingCharacters(in: CharacterSet(charactersIn: "?？")) }
            // 「請問」是客氣話（excuse me），翻進去或不翻進去意思都對
            func same(_ a: String?, _ b: String?) -> Bool {
                guard let a = n(a), let b = n(b) else { return a == nil && b == nil }
                // 「那個」可以是口頭禪，也可以是「那個（東西）」，兩種都對
                return a == b || a == "請問" + b || b == "請問" + a || a == "那個" + b || b == "那個" + a
            }
            if let text = x.text {
                if !same(r?.text, text) || r?.target.rawValue != x.target {
                    bad.append("✗ \(x.q)  →  \(r.map { "「\($0.text)」/\($0.target.rawValue)" } ?? "沒聽懂")　應該：「\(text)」/\(x.target ?? "")")
                }
            } else if let r {
                bad.append("✗ 不是翻譯：\(x.q)  →  「\(r.text)」/\(r.target.rawValue)")
            }
        }
        print("TRANSLATE-QUESTIONS \(name): \(qs.count - bad.count) ok, \(bad.count) failed")
        if let out = ProcessInfo.processInfo.environment["NINESUN_TQ_OUT"] {
            try? bad.joined(separator: "\n").write(toFile: out + "." + name, atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(bad.isEmpty, bad.prefix(40).joined(separator: "\n"))
    }
}
