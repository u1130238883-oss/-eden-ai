import XCTest
@testable import EchoCore

/// 臨時：看引擎怎麼接這些問題（只在本機跑）
final class ProbeTests: XCTestCase {
    func testProbe() throws {
        guard let qs = ProcessInfo.processInfo.environment["PROBE"] else { throw XCTSkip("probe") }
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 5)
        var ctx = EchoEngine.Context(now: t.date(2026, 9, 30, 11))
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 7, minute: 0, male: true)
        var history: [ChatTurn] = []
        let keep = ProcessInfo.processInfo.environment["PROBE_HIST"] != nil
        for q in qs.split(separator: "|").map(String.init) {
            let r = engine.reply(to: q, history: keep ? history : [], context: ctx)
            history += [ChatTurn(role: .user, text: q), r.turn]
            FileHandle.standardError.write("PROBE> \(q)\n[\(r.turn.source.rawValue)] web=\(r.webQuery ?? "-")\n\(r.turn.text.prefix(ProcessInfo.processInfo.environment["PROBE_FULL"] != nil ? 3000 : 160))\n\n".data(using: .utf8)!)
        }
    }
}
