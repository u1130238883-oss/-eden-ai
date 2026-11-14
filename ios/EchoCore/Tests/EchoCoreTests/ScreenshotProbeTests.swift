import XCTest
@testable import EchoCore

/// 除錯用：把使用者截圖裡的問題照 App 的流程丟給引擎，印出每一題走到哪裡（NINESUN_SHOTS=1 才跑）
final class ScreenshotProbeTests: XCTestCase {
    func testProbe() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["NINESUN_SHOTS"] != nil else { throw XCTSkip("") }
        Intent.shared = try? Intent(weights: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("intent.bin")),
                                    metaJSON: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("intent.json")))
        let engine = try SimpleQuestionsProbeTests.engine()
        var ctx = EchoEngine.Context()
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14))
        let qs = (env["NINESUN_SHOTS_Q"].map { $0.components(separatedBy: "|") }) ?? ScreenshotTests.questions
        for q in qs {
            let r = engine.reply(to: q, history: [], context: ctx)
            let fr = Understanding.frame(q)
            print("SHOT 「\(q)」\n  source=\(r.turn.source) palace=\(String(describing: r.turn.palace)) web=\(r.webQuery ?? "-")"
                  + "\n  want=\(fr.want) subject=\(fr.subject) lookup=\(BrainRoute.needsLookup(q)) feeling=\(Solace.isFeeling(q)) low=\(BrainRoute.feelingLow(q))"
                  + "\n  text=\(r.turn.text.prefix(90).replacingOccurrences(of: "\n", with: "⏎"))")
        }
    }
}

