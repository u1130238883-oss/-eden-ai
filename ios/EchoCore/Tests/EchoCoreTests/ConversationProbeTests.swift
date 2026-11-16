import XCTest
@testable import EchoCore

/// 除錯用：一段一段的對話（空行分開），同一個引擎、帶著前面的對話回答，像 App 一樣。
/// NINESUN_DIALOGS=檔案 [NINESUN_BIRTH=2006-01-14-8] …xctest EchoCoreTests.ConversationProbeTests
final class ConversationProbeTests: XCTestCase {
    func testDialogs() throws {
        guard let path = ProcessInfo.processInfo.environment["NINESUN_DIALOGS"] else { throw XCTSkip("") }
        let text = try String(contentsOfFile: path, encoding: .utf8)
        var ctx = EchoEngine.Context()
        if let b = ProcessInfo.processInfo.environment["NINESUN_BIRTH"]?.split(separator: "-").compactMap({ Int($0) }), b.count >= 3 {
            ctx.profile = UserProfile(birthday: BirthDay(year: b[0], month: b[1], day: b[2]), hour: b.count > 3 ? b[3] : nil)
        }
        for dialog in text.components(separatedBy: "\n\n") where !dialog.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let engine = try SimpleQuestionsProbeTests.engine()
            var history: [ChatTurn] = []
            print("######")
            for q in dialog.split(separator: "\n").map(String.init) where !q.hasPrefix("#") {
                let r = engine.reply(to: q, history: history, context: ctx)
                history.append(ChatTurn(role: .user, text: q))
                history.append(r.turn)
                print(">> \(q)\n[\(r.turn.source)] \(r.turn.text)" + (r.webQuery.map { "\n[web: \($0)]" } ?? ""))
            }
        }
    }
}
