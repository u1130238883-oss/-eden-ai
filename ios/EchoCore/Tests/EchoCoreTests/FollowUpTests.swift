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

    func testAnswersToMyQuestions() throws {
        let a = try run(["我養了一隻狗", "叫小白", "兩歲了"])
        XCTAssertTrue(a[1].turn.text.contains("小白") && a[1].webQuery == nil, a[1].turn.text)
        XCTAssertNil(a[2].webQuery, a[2].turn.text)
        let b = try run(["我考上研究所了", "台大", "準備了一年"])
        XCTAssertTrue(b[1].turn.text.contains("台大") && b[1].webQuery == nil, b[1].turn.text)
        XCTAssertNil(b[2].webQuery, b[2].turn.text)
        let c = try run(["我在煮飯", "咖哩"])
        XCTAssertTrue(c[1].turn.text.contains("咖哩") && c[1].webQuery == nil, c[1].turn.text)
        // 不是在回答：照一般問題處理
        let d = try run(["我在煮飯", "台灣最高的山是哪座"])
        XCTAssertTrue(d[1].turn.text.contains("玉山"), d[1].turn.text)
    }

    func testMoodThenAdvice() throws {
        let a = try run(["我失眠了", "要怎麼辦"])
        XCTAssertTrue(a[1].turn.text.contains("手機") || a[1].turn.text.contains("起床"), a[1].turn.text)
        let b = try run(["我最近在學日文", "好難", "有什麼方法"])
        XCTAssertTrue(b[2].turn.text.contains("五十音"), b[2].turn.text)
    }

    func testComparisonsTravelAndMood() throws {
        let a = try run(["台北101有多高", "比東京晴空塔高嗎"])
        XCTAssertTrue(a[1].turn.text.contains("634") && a[1].turn.text.contains("東京晴空塔比較高"), a[1].turn.text)
        let b = try run(["我想去日本玩", "要帶多少錢"])
        XCTAssertTrue(b[1].turn.text.contains("現金") || b[1].turn.text.contains("日圓"), b[1].turn.text)
        let c = try run(["我今天考試考砸了", "怎麼辦"])
        XCTAssertTrue(c[1].turn.text.contains("考試考不好"), c[1].turn.text)
        // 新的問題不能被接到上一題（「埃菲爾鐵塔高度多少」不是在問台北101）
        let d = try run(["台北101有多高", "埃菲爾鐵塔高度多少"])
        XCTAssertFalse(d[1].turn.text.contains("508"), d[1].turn.text)
        let f = try run(["日本有多大", "台灣呢", "誰比較大"])
        XCTAssertTrue(f[2].turn.text.hasPrefix("日本比較大"), f[2].turn.text)
        let g = try run(["周杰倫是誰", "他幾歲"])
        XCTAssertTrue(g[1].turn.text.contains("1979"), g[1].turn.text)
        let e = try run(["今天好累", "查量子力學"])
        XCTAssertEqual(e[1].webQuery, "量子力學")
    }

    /// 像 App 一樣：規則和生日會存起來，下一句用得到
    func testRemembersNameLikesAndSign() throws {
        let engine = try SimpleQuestionsProbeTests.engine()
        var ctx = EchoEngine.Context()
        var history: [ChatTurn] = []
        func say(_ q: String) -> EchoEngine.Reply {
            let r = engine.reply(to: q, history: history, context: ctx)
            if let b = r.rules { ctx.rules = b }
            if let p = r.profile { ctx.profile = p }
            history.append(ChatTurn(role: .user, text: q)); history.append(r.turn)
            return r
        }
        _ = say("我叫小明")
        _ = say("幫我記住我喜歡藍色")
        XCTAssertTrue(say("你記得我叫什麼嗎").turn.text.contains("小明"))
        XCTAssertTrue(say("我喜歡什麼顏色").turn.text.contains("藍色"))
        _ = say("我的生日是1995年3月8日")
        let s = say("我是什麼星座").turn.text
        XCTAssertTrue(s.contains("雙魚座") && s.contains("豬"), s)
    }
}
