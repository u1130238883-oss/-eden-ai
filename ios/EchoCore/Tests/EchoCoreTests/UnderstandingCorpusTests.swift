import XCTest
@testable import EchoCore

/// 中文理解訓練：50,000 題（ai/understanding/gen.py 產生），每題有標準答案——
/// 該去哪裡回答（上網／用命盤算／安慰／聊天）、上網要什麼樣的答案、要查的主題。
/// 平常跑前 6,000 題；NINESUN_UNDERSTAND_ALL=1 跑全部。錯的題目依類型分組印出來（NINESUN_UNDERSTAND_OUT 寫到檔案）。
final class UnderstandingCorpusTests: XCTestCase {
    struct Q: Decodable { let q: String; let route: String; let want: String; let subject: String; let kind: String }

    static func wantName(_ w: Understanding.Want) -> String {
        switch w {
        case .number: return "number"
        case .list: return "list"
        case .reason: return "reason"
        case .steps: return "steps"
        case .person: return "person"
        case .place: return "place"
        case .time: return "time"
        case .definition: return "definition"
        case .compare: return "compare"
        case .open: return "open"
        }
    }

    static func norm(_ s: String) -> String {
        s.replacingOccurrences(of: #"[《》〈〉「」\s，,]"#, with: "", options: .regularExpression)
    }

    func testUnderstanding() throws {
        try run("understanding_questions", limit: ProcessInfo.processInfo.environment["NINESUN_UNDERSTAND_ALL"] == "1" || ProcessInfo.processInfo.environment["NINESUN_UNDERSTAND_FILE"] != nil ? nil : 6000, min: 0.995)
    }

    /// 沒看過的問法和名稱（不在訓練題裡）：檢查是真的理解，不是背題目
    func testHoldout() throws {
        try run("understanding_holdout", limit: nil, min: Double(ProcessInfo.processInfo.environment["NINESUN_HOLDOUT_MIN"] ?? "0.99") ?? 0)
    }

    func run(_ name: String, limit: Int?, min: Double) throws {
        // NINESUN_UNDERSTAND_FILE=檔案：跑 500,000 題（ai/understanding/gen.py --n 500000）
        let file = name == "understanding_questions" ? ProcessInfo.processInfo.environment["NINESUN_UNDERSTAND_FILE"] : nil
        let url = try file.map { URL(fileURLWithPath: $0) } ?? XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        var qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url))
        if let limit { qs = Array(qs.prefix(limit)) }
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 5)
        var ctx = EchoEngine.Context(now: t.date(2026, 10, 23, 15))
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 8, minute: 0, male: true)

        var errors: [String: [String]] = [:]
        var total: [String: Int] = [:], wrong: [String: Int] = [:]
        for x in qs {
            total[x.kind, default: 0] += 1
            let r = engine.reply(to: x.q, context: ctx)
            var why: String?
            let web = r.webQuery != nil
            switch x.route {
            case "web":
                // NineSun 自己的常識答得出來就不用上網（Commonsense／Everyday）——但答的要是問題問的那個東西，
                // 不能把「挪威的森林」當成挪威、「老人與海」當成人
                if !web {
                    let sub = Self.norm(x.subject)
                    let names = Commonsense.subjects(x.q)
                    let local = r.turn.source == .knowledge || r.turn.source == .tool
                    // 為什麼題的 subject 是「藍色的」「閃爍」這種說法：認得出問題裡的主角（天空、星星）就算懂
                    let same = (!sub.isEmpty && (Self.norm(r.turn.text).contains(sub) || names.contains { sub.contains($0) || $0.contains(sub) }))
                        || (x.want == "reason" && !names.isEmpty)
                    if !(local && same) { why = "route 應該上網，卻在本地回答（\(r.turn.source.rawValue)）：\(r.turn.text.prefix(30))" }
                }
            case "fortune":
                if web { why = "route 應該用命盤算，卻上網查「\(r.webQuery!)」" }
                else if r.turn.source != .reader && r.turn.source != .tool { why = "route 應該用命盤算，卻是 \(r.turn.source.rawValue)：\(r.turn.text.prefix(30))" }
            case "feeling":
                if web { why = "route 是在說心情，卻上網查「\(r.webQuery!)」" }
                else if r.turn.source != .neural { why = "route 是在說心情，卻是 \(r.turn.source.rawValue)：\(r.turn.text.prefix(30))" }
            default:
                if web { why = "route 是聊天，卻上網查「\(r.webQuery!)」" }
            }
            if why == nil, x.route == "web", let wq = r.webQuery {
                let f = Understanding.frame(wq)
                let w = Self.wantName(f.want)
                if w != x.want {
                    why = "want 應該是 \(x.want)，理解成 \(w)（主題「\(f.subject)」）"
                } else if !x.subject.isEmpty, !Self.norm(f.subject).contains(Self.norm(x.subject)) && !f.searches.contains(where: { Self.norm($0).contains(Self.norm(x.subject)) }) {
                    why = "subject 應該包含「\(x.subject)」，理解成「\(f.subject)」"
                }
            }
            if let why {
                wrong[x.kind, default: 0] += 1
                let key = x.kind + " · " + String(why.prefix(while: { $0 != " " }))
                if (errors[key]?.count ?? 0) < 12 { errors[key, default: []].append("「\(x.q)」→ \(why)") }
            }
        }
        let n = qs.count, bad = wrong.values.reduce(0, +)
        var out = "UNDERSTAND[\(name)] 共 \(n) 題，答對 \(n - bad)（\(String(format: "%.2f", Double(n - bad) * 100 / Double(n)))%）\n"
        for k in total.keys.sorted() where (wrong[k] ?? 0) > 0 {
            out += "UNDERSTAND \(k)：錯 \(wrong[k]!)/\(total[k]!)\n"
        }
        for (k, v) in errors.sorted(by: { $0.key < $1.key }) {
            out += "\n【\(k)】\n" + v.map { "  " + $0 }.joined(separator: "\n") + "\n"
        }
        if let p = ProcessInfo.processInfo.environment["NINESUN_UNDERSTAND_OUT"] { try out.write(toFile: p + "." + name + ".txt", atomically: true, encoding: .utf8) }
        print(out.prefix(6000))
        XCTAssertGreaterThanOrEqual(Double(n - bad) / Double(n), min, out.prefix(3000).description)
    }
}
