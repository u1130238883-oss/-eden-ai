import XCTest
@testable import EchoCore

/// 除錯用：印出寫作每一稿和檢查結果
final class ProbeTests: XCTestCase {
    func testProbe() {
        for q in ["Write a paragraph about this: The season has changed.", "老師出的題目：小明被嚇到了，請詳寫", "擴寫：小狗靜靜地等待", "改寫：小明氣炸了，小明很生氣。"] {
            guard let a = Writer.parse(q) else { print("PROBE 沒聽懂 \(q)"); continue }
            let r = Writer.write(a)
            print("PROBE 「\(q)」 kind=\(a.kind) cat=\(a.category) subj=\(a.subject) min=\(a.minUnits)")
            for (i, d) in r.drafts.enumerated() { print("  稿\(i)：\(Writer.review(d, a))\n    \(d)") }
            print("  notes=\(r.notes)")
        }
    }
}
