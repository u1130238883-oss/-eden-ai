import XCTest
@testable import EchoCore

/// 情感訓練（ai/affect/gen.py 產生）：對方說不同的話，NineSun 要聽出心情、有對應的感受，回答帶著對的語氣、不衝突。
/// 平常跑 20,000 題樣本＋20,000 題沒看過的；NINESUN_AFF=檔案 跑全部 500,000 題。
final class AffectTests: XCTestCase {
    struct Q: Decodable { let q: String; let label: String }

    func run(_ name: String, path: String?, min: Double) throws {
        let url = try path.map { URL(fileURLWithPath: $0) }
            ?? XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url))
        var wrong = 0, cnt: [String: Int] = [:], ex: [String: [String]] = [:]
        for x in qs {
            let m = Affect.detect(x.q).rawValue
            if m != x.label {
                wrong += 1
                let k = "應該是 \(x.label)，聽成 \(m)"
                cnt[k, default: 0] += 1
                if (ex[k]?.count ?? 0) < 6 { ex[k, default: []].append("「\(x.q)」") }
            }
        }
        let n = qs.count
        var out = "AFFECT[\(name)] 共 \(n) 題，聽對 \(n - wrong)（\(String(format: "%.2f", Double(n - wrong) * 100 / Double(n)))%）\n"
        for (k, c) in cnt.sorted(by: { $0.value > $1.value }).prefix(30) { out += "\n【\(k)】\(c) 題\n" + (ex[k] ?? []).map { "  " + $0 }.joined(separator: "\n") + "\n" }
        if let p = ProcessInfo.processInfo.environment["NINESUN_AFF_OUT"] { try out.write(toFile: p + "." + name + ".txt", atomically: true, encoding: .utf8) }
        print(out.prefix(5000))
        XCTAssertGreaterThanOrEqual(Double(n - wrong) / Double(n), min, String(out.prefix(2000)))
    }

    func testTrain() throws { try run("affect_sample", path: ProcessInfo.processInfo.environment["NINESUN_AFF"], min: 0.99) }
    func testHoldout() throws { try run("affect_holdout", path: nil, min: Double(ProcessInfo.processInfo.environment["NINESUN_AFF_HOLD_MIN"] ?? "0.97") ?? 0.97) }

    /// 整個引擎：回答要帶著對的語氣（替你開心、心疼、道歉……），而且不能衝突（難過時不能說恭喜）；一般問題不加情緒
    func testEngineTone() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "affect_sample", withExtension: "json", subdirectory: "Fixtures"))
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
        for x in qs {
            guard let m = Affect.Mood(rawValue: x.label), m != .crisis else { continue }
            let text = engine.reply(to: x.q, context: ctx).turn.text
            if m == .info {
                if Affect.openers.values.flatMap({ $0 }).contains(where: { text.hasPrefix($0) }) { bad.append("「\(x.q)」一般問題卻加了情緒：\(text.prefix(30))") }
            } else if !Affect.hasTone(String(text.prefix(80)), m) && !(m == .greeting || m == .farewell) {
                bad.append("「\(x.q)」（\(m.rawValue)）語氣不對：\(text.prefix(40))")
            } else if Affect.clashes(text, m) {
                bad.append("「\(x.q)」（\(m.rawValue)）語氣衝突：\(text.prefix(40))")
            }
        }
        XCTAssertLessThanOrEqual(bad.count, qs.count / 100, bad.prefix(20).joined(separator: "\n"))
    }
}
