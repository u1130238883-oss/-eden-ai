import XCTest
@testable import EchoCore

/// 除錯用：多輪對話，一行一段，用「|」分開每一句（# 開頭的行略過，第三欄以後當註解不送出）。
/// NINESUN_DIALOGS=檔案 …xctest EchoCoreTests.DialogProbeTests
final class DialogProbeTests: XCTestCase {
    func testDialogs() throws {
        guard let path = ProcessInfo.processInfo.environment["NINESUN_DIALOGS"] else { throw XCTSkip("") }
        let res = EchoCoreTests.resources
        Brain.shared = try? Brain(weights: Data(contentsOf: res.appendingPathComponent("reader.bin")), metaJSON: Data(contentsOf: res.appendingPathComponent("reader.json")))
        MeaningMatch.shared = try? MeaningMatch(weights: Data(contentsOf: res.appendingPathComponent("meaning.bin")), metaJSON: Data(contentsOf: res.appendingPathComponent("meaning.json")))
        let turns = Int(ProcessInfo.processInfo.environment["NINESUN_DIALOG_TURNS"] ?? "2") ?? 2
        for line in try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n") where !line.hasPrefix("#") {
            let qs = line.split(separator: "|").map(String.init).prefix(turns)
            let engine = try SimpleQuestionsProbeTests.engine()
            var h: [ChatTurn] = []
            print("-----")
            for q in qs {
                let r = engine.reply(to: q, history: h, context: EchoEngine.Context())
                h.append(ChatTurn(role: .user, text: q)); h.append(r.turn)
                print("U: \(q)\nA: \(r.turn.text.replacingOccurrences(of: "\n", with: " / "))" + (r.webQuery.map { " [web: \($0)]" } ?? ""))
            }
        }
    }
}
