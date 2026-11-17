import XCTest
@testable import EchoCore

/// 除錯用：每一句印出知識庫的答案、寬鬆說法、換句話說對到的問法。
/// NINESUN_LOOKUP=檔案 …xctest EchoCoreTests.LookupDebugTests
final class LookupDebugTests: XCTestCase {
    func testLookup() throws {
        guard let path = ProcessInfo.processInfo.environment["NINESUN_LOOKUP"] else { throw XCTSkip("") }
        for q in try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n").map(String.init) where !q.isEmpty {
            let a = Commonsense.answer(q)
            let f = Fuzzy.match(q)
            print("=== \(q)\n  loosen: \(Commonsense.loosen(q))\n  fuzzyNorm: \(Fuzzy.normalize(q)) segs=\(Fuzzy.segments(Fuzzy.normalize(q)).map { String($0.text) }) focus=\(Fuzzy.focus(Fuzzy.normalize(q)).sorted())\n  answer: \((a ?? "nil").prefix(60).replacingOccurrences(of: "\n", with: " / "))\n  fuzzy: \(f.map { "\($0.entity.name) ← \($0.alias)" } ?? "nil")")
        }
    }
}
