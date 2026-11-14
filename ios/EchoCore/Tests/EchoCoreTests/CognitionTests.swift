import XCTest
@testable import EchoCore

/// 認知判斷：給一個問題和一句網頁上的話，判斷能不能當答案、不能的話是哪一種錯（ai/cognition/gen.py 產生）。
/// 平常跑 20,000 題的樣本＋20,000 題沒看過的；NINESUN_COG=檔案 跑全部 500,000 題。錯的題目分組印出來（NINESUN_COG_OUT）。
final class CognitionTests: XCTestCase {
    struct Q: Decodable { let q: String; let want: String; let subject: String; let s: String; let ctx: Bool; let label: String }

    static func want(_ w: String, _ subject: String) -> Understanding.Want {
        switch w {
        case "steps": return .steps(target: subject)
        case "number": return .number(attr: "", units: [])
        case "time": return .time
        case "place": return .place
        case "reason": return .reason(pred: subject)
        case "definition": return .definition
        case "person": return .person
        default: return .open
        }
    }

    func run(_ name: String, path: String?, min: Double) throws {
        let url = try path.map { URL(fileURLWithPath: $0) }
            ?? XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let qs = try JSONDecoder().decode([Q].self, from: Data(contentsOf: url))
        var wrong = 0
        var confusion: [String: Int] = [:]
        var examples: [String: [String]] = [:]
        for x in qs {
            let v = Judge.check(x.s, want: Self.want(x.want, x.subject), subject: x.subject, question: x.q, inContext: x.ctx).rawValue
            if v != x.label {
                wrong += 1
                let k = "應該是 \(x.label)，判成 \(v)"
                confusion[k, default: 0] += 1
                if (examples[k]?.count ?? 0) < 8 { examples[k, default: []].append("「\(x.q)」｜「\(x.s)」\(x.ctx ? "（主題網頁裡）" : "")") }
            }
        }
        let n = qs.count
        var out = "COGNITION[\(name)] 共 \(n) 題，判斷對 \(n - wrong)（\(String(format: "%.2f", Double(n - wrong) * 100 / Double(n)))%）\n"
        for (k, c) in confusion.sorted(by: { $0.value > $1.value }) {
            out += "\n【\(k)】\(c) 題\n" + (examples[k] ?? []).map { "  " + $0 }.joined(separator: "\n") + "\n"
        }
        if let p = ProcessInfo.processInfo.environment["NINESUN_COG_OUT"] { try out.write(toFile: p + "." + name + ".txt", atomically: true, encoding: .utf8) }
        print(out.prefix(5000))
        XCTAssertGreaterThanOrEqual(Double(n - wrong) / Double(n), min, String(out.prefix(2000)))
    }

    func testTrain() throws {
        try run("cognition_sample", path: ProcessInfo.processInfo.environment["NINESUN_COG"], min: Double(ProcessInfo.processInfo.environment["NINESUN_COG_MIN"] ?? "0.99") ?? 0.99)
    }

    /// 沒看過的句型和主題
    func testHoldout() throws {
        try run("cognition_holdout", path: nil, min: Double(ProcessInfo.processInfo.environment["NINESUN_COG_HOLD_MIN"] ?? "0.97") ?? 0.97)
    }

    /// 使用者截圖的黃燜雞：網站廣告不是步驟、名字由來放到「小知識」
    func testRecipeStepsAndFacts() throws {
        let page = """
        黃燜雞
        1. 雞腿肉切成適當大小，用醬油醃10分鐘。
        2. 鍋中加入1大匙油燒熱，加入冰糖炒出糖色。
        3. 加入雞肉翻炒上色，然後下蒜頭及薑片拌炒。
        4. 加入香菇水，中火煮至沸騰收汁剩約一半。
        5. 加入青椒煮至喜歡的熟度，酌量加鹽調味，即可盛盤。
        6. 設定後，在Google搜尋食譜時，愛料理的食譜會優先出現！
        7. 煮出來的醬色，深一點會叫紅燒，這道菜顏色不那麼深，可能因此取名「黃燜」。
        看起來好好吃！感謝分享。
        """
        let r = try XCTUnwrap(Understanding.extractSteps([.init(text: page, host: "icook.tw")], target: "黃燜雞"))
        XCTAssertEqual(r.steps.count, 5, r.steps.joined(separator: "\n"))
        XCTAssertFalse(r.steps.contains { $0.contains("Google") || $0.contains("取名") }, r.steps.joined(separator: "\n"))
        XCTAssertTrue(r.facts.contains { $0.contains("取名") }, r.facts.joined(separator: "\n"))
    }
}
