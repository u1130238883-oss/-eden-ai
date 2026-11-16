import XCTest
@testable import EchoCore

/// 除錯用：一批日常的簡單問題，印出 NineSun 怎麼回答（要上網的題目，NINESUN_LIVE=1 時真的上網查）：
/// NINESUN_SIMPLE=題目檔（一行一題） [NINESUN_LIVE=1] …xctest EchoCoreTests.SimpleQuestionsProbeTests
final class SimpleQuestionsProbeTests: XCTestCase {
    func testProbe() async throws {
        guard let path = ProcessInfo.processInfo.environment["NINESUN_SIMPLE"] else { throw XCTSkip("") }
        let live = ProcessInfo.processInfo.environment["NINESUN_LIVE"] == "1"
        Brain.shared = try? Brain(weights: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("reader.bin")),
                                  metaJSON: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("reader.json")))
        Intent.shared = try? Intent(weights: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("intent.bin")),
                                    metaJSON: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("intent.json")))
        let qs = try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n").map(String.init).filter { !$0.isEmpty && !$0.hasPrefix("#") }
        for q in qs {
            // App 先看是不是翻譯（「謝謝的英文怎麼說」），是的話不會進到引擎
            if Translate.parse(q) != nil { print("=== \(q)\n[翻譯]\n"); continue }
            let engine = try Self.engine()
            // NINESUN_BIRTH=2006-01-14-8：用這個生日（和時辰）回答
            var ctx = EchoEngine.Context()
            if let b = ProcessInfo.processInfo.environment["NINESUN_BIRTH"]?.split(separator: "-").compactMap({ Int($0) }), b.count >= 3 {
                ctx.profile = UserProfile(birthday: BirthDay(year: b[0], month: b[1], day: b[2]), hour: b.count > 3 ? b[3] : nil)
            }
            let r = engine.reply(to: q, context: ctx)
            var out = "=== \(q)\n[\(r.turn.source)] \(r.turn.text)"
            if let w = r.webQuery {
                out += "\n[web: \(w)]"
                if live {
                    let a = await WebAgent.run(w, lang: r.lang)
                    out += "\n" + a.text
                }
            }
            print(out + "\n")
        }
    }

    static func engine() throws -> EchoEngine {
        func res(_ n: String) throws -> Data { try Data(contentsOf: EchoCoreTests.resources.appendingPathComponent(n)) }
        let e = EchoEngine(model: try EchoModel(weights: res("ninesun.bin"), metaJSON: res("ninesun.json")), seed: 1)
        for L in Lang.allCases { e.knowledge[L] = try KnowledgeBase(json: res("knowledge_\(L.rawValue).json"), lang: L) }
        e.core = try PalaceCore(json: res("palace_lexicon.json"))
        e.i18n = try I18N(json: res("i18n.json"))
        return e
    }
}
