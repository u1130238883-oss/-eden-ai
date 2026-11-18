import XCTest
@testable import EchoCore

/// Round 24（2026-11-17～18）修好的地方：每一題在上一版（build 429）都答錯或答偏，
/// 凍結版（commit 16cd388）答對。只用自己想到的問題，沒有用 offline_holdout5／offline_dialogs_holdout 的題目。
final class Round24Tests: XCTestCase {
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

    func one(_ q: String) throws -> EchoEngine.Reply { try run([q])[0] }

    /// 說活著很痛苦，一定要給求助專線（上一版只回心情和宮位）
    func testHurtingGetsHelpLines() throws {
        let a = try one("活著好痛苦")
        XCTAssertTrue(a.turn.text.contains("1925"), a.turn.text)
    }

    /// 生活和規定的問題不是問運勢；坐骨神經痛不是經痛
    func testEverydayQuestionsAreNotFortune() throws {
        for q in ["晚上吃水果好嗎", "晚上運動好嗎", "請事假會扣薪水嗎"] {
            let r = try one(q)
            XCTAssertFalse(r.turn.text.contains("生日"), "\(q) → \(r.turn.text)")
            XCTAssertNil(r.webQuery, "\(q) → \(r.turn.text)")
        }
        let a = try one("坐骨神經痛怎麼辦")
        XCTAssertTrue(a.turn.text.contains("坐骨神經"), a.turn.text)
        XCTAssertFalse(a.turn.text.hasPrefix("經痛"), a.turn.text)
    }

    /// 被男朋友弄難過 ≠ 擔心男朋友；問 NineSun 自己的事 ≠ 聽到好消息
    func testWhoIsHurting() throws {
        let a = try one("我男朋友讓我很難過")
        XCTAssertFalse(a.turn.text.contains("幫他"), a.turn.text)
        let b = try one("你有喜歡的人嗎")
        XCTAssertTrue(b.turn.text.contains("AI"), b.turn.text)
        XCTAssertFalse(b.turn.text.contains("後來呢"), b.turn.text)
    }

    /// 換個說法也找得到已經知道的答案
    func testRephrasings() throws {
        XCTAssertTrue(try one("誰發明電話的").turn.text.contains("貝爾"))
        XCTAssertTrue(try one("光一秒跑多遠").turn.text.contains("30 萬"))
        XCTAssertTrue(try one("排水孔堵住").turn.text.contains("小蘇打"))
        XCTAssertTrue(try one("推薦一部movie").turn.text.contains("《"))
        XCTAssertTrue(try one("1200元三個人分").turn.text.contains("400"))
        let c = try one("怎麼寫感謝卡")
        XCTAssertFalse(c.turn.text.contains("不客氣"), c.turn.text)
        XCTAssertNil(c.webQuery, c.turn.text)
    }

    /// 長得像別的題目的問題，不答別的題目
    func testNoLookalikeAnswers() throws {
        let a = try one("謝謝的日文怎麼說")
        XCTAssertFalse(a.turn.text.contains("不客氣"), a.turn.text)
        let b = try one("韓國最高的山是哪一座")
        XCTAssertFalse(b.turn.text.contains("聖母峰"), b.turn.text)
        let c = try one("晚安!？")
        XCTAssertTrue(c.turn.text.contains("晚安"), c.turn.text)
    }

    /// 「我今天被老闆罵」先接住心情、給做法；接著說原因和細節時還是陪他說，不是空泛的「後來呢」加運勢廣告
    /// （凍結版 16cd388 在這裡退步了，交付前修好）
    func testHurtThenDetails() throws {
        let a = try run(["我今天被老闆罵", "因為報告寫錯", "他當著大家的面罵"])
        XCTAssertTrue(a[0].turn.text.contains("被主管罵"), a[0].turn.text)
        XCTAssertTrue(a[1].turn.text.contains("報告寫錯"), a[1].turn.text)
        XCTAssertFalse(a[2].turn.text.contains("運勢"), a[2].turn.text)
        let b = try run(["我今天被老闆罵", "要怎麼辦"])
        XCTAssertTrue(b[1].turn.text.contains("剛剛那幾步"), b[1].turn.text)
        let c = try run(["我被裁員了", "最重要的是哪一個"])
        XCTAssertFalse(c[1].turn.text.contains("先抱抱你"), c[1].turn.text)
    }

    /// 追問帶上前一題的主題；猜數字可以接著玩
    func testFollowUpsKeepTheTopic() throws {
        let a = try run(["番茄炒蛋怎麼做", "要煮多久"])
        XCTAssertEqual(a[1].webQuery, "番茄炒蛋要煮多久", a[1].turn.text)
        let b = try run(["世界上最高的山是哪一座", "第二高的呢"])
        XCTAssertEqual(b[1].webQuery, "世界上第二高的山是哪一座", b[1].turn.text)
        let c = try run(["猜數字", "50"])
        let t = c[1].turn.text
        XCTAssertTrue(t.contains("再大一點") || t.contains("再小一點") || t.contains("答對了"), t)
    }
}
