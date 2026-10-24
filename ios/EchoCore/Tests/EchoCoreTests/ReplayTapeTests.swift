import XCTest
@testable import EchoCore

/// 用錄下來的真實網頁重播幾題，看回答（訓練作品題、搜尋整理用）：
/// NINESUN_TAPES=錄音帶1:錄音帶2 NINESUN_QS="題目1|題目2" …xctest EchoCoreTests.ReplayTapeTests
/// 被擋住、沒查到的題目不印
final class ReplayTapeTests: XCTestCase {
    func testReplay() async throws {
        guard let paths = ProcessInfo.processInfo.environment["NINESUN_TAPES"] else { throw XCTSkip("") }
        Brain.shared = try? Brain(weights: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("reader.bin")),
                                  metaJSON: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("reader.json")))
        Intent.shared = try? Intent(weights: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("intent.bin")),
                                    metaJSON: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("intent.json")))
        let qs = (ProcessInfo.processInfo.environment["NINESUN_QS"] ?? "").split(separator: "|").map(String.init)
        for path in paths.split(separator: ":").map(String.init) {
            WebTape.shared = try WebTape(contentsOf: URL(fileURLWithPath: path))
            for q in qs {
                let w = await WebAgent.run(q, lang: .zh)
                if w.text.contains("擋住") || !w.found { continue }
                print("=== \(q)\n\(w.text)\n")
            }
        }
        WebTape.shared = nil
    }
}
