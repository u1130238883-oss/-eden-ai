import XCTest
@testable import EchoCore

/// 追問要接得上前一題的主題（「日本的首都」→「人口多少」→ 日本的人口）
final class FollowUpTests: XCTestCase {
    func run(_ qs: [String]) throws -> [EchoEngine.Reply] {
        let engine = try SimpleQuestionsProbeTests.engine()
        var history: [ChatTurn] = []
        var out: [EchoEngine.Reply] = []
        for q in qs {
            let r = engine.reply(to: q, history: history, context: EchoEngine.Context())
            history.append(ChatTurn(role: .user, text: q))
            history.append(r.turn)
            out.append(r)
        }
        return out
    }

    func testCarriesSubject() throws {
        let a = try run(["法國的首都", "說什麼語言", "用什麼貨幣"])
        XCTAssertTrue(a[1].turn.text.contains("法語"), a[1].turn.text)
        XCTAssertTrue(a[2].turn.text.contains("歐元"), a[2].turn.text)
        let b = try run(["日本的首都是哪裡", "人口多少"])
        XCTAssertTrue(b[1].turn.text.contains("億"), b[1].turn.text)
        let c = try run(["貓可以吃巧克力嗎", "那葡萄呢", "狗呢"])
        XCTAssertTrue(c[1].turn.text.contains("葡萄") && c[1].turn.text.contains("不"), c[1].turn.text)
        XCTAssertTrue(c[2].turn.text.contains("狗"), c[2].turn.text)
        let d = try run(["義大利的首都", "那德國呢"])
        XCTAssertTrue(d[1].turn.text.contains("柏林"), d[1].turn.text)
    }

    func testPersonYearsAndNoGrief() throws {
        let a = try run(["愛因斯坦是誰", "他哪一年過世"])
        XCTAssertTrue(a[1].turn.text.contains("1955"), a[1].turn.text)
        XCTAssertFalse(a[1].turn.text.contains("難過"), a[1].turn.text)
    }

    func testDoesNotHijackOtherTopics() throws {
        let a = try run(["日本的首都是哪裡", "你喜歡什麼", "謝謝"])
        XCTAssertFalse(a[1].turn.text.contains("日本"), a[1].turn.text)
        XCTAssertNil(a[2].webQuery)
    }
}
