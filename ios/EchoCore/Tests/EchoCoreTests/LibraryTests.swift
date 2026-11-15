import XCTest
@testable import EchoCore

/// 自己知道的作品和清單（ai/commonsense/data/works.txt、lists.txt）：不用上網就能回答
final class LibraryTests: XCTestCase {
    func testAuthor() {
        XCTAssertTrue(Library.answer("紅樓夢的作者是誰")?.contains("曹雪芹") == true)
        XCTAssertTrue(Library.answer("誰寫了老人與海？")?.contains("海明威") == true)
        XCTAssertTrue(Library.answer("三國演義是誰寫的")?.contains("羅貫中") == true)
        XCTAssertTrue(Library.answer("《百年孤寂》的作者")?.contains("馬奎斯") == true)
        XCTAssertTrue(Library.answer("鐵達尼號是誰導演的")?.contains("卡麥隆") == true)
        XCTAssertTrue(Library.answer("論語的作者是誰")?.contains("孔子") == true)
        // 不認識的作品：交給上網查
        XCTAssertNil(Library.answer("某某某的奇幻冒險的作者是誰"))
    }

    func testLists() {
        XCTAssertTrue(Library.answer("八大行星有哪些")?.contains("海王星") == true)
        XCTAssertTrue(Library.answer("四大名著是哪些")?.contains("水滸傳") == true)
        XCTAssertTrue(Library.answer("七大洲是什麼")?.contains("南極洲") == true)
        XCTAssertTrue(Library.answer("十二生肖有哪些？")?.contains("豬") == true)
        XCTAssertTrue(Library.answer("莎士比亞四大悲劇是哪些")?.contains("馬克白") == true)
        // 問意思的交給原本的方法（會解釋，不是只列出來）
        XCTAssertNil(Library.answer("五行是什麼"))
    }

    func testCategory() throws {
        // 使用者截圖的問題
        let a = try XCTUnwrap(Library.answer("出名的西方作品講的是什麼"))
        XCTAssertTrue(a.contains("《哈姆雷特》") && a.contains("共同點"))
        // 不要全部都是莎士比亞
        XCTAssertLessThanOrEqual(a.components(separatedBy: "莎士比亞）").count - 1, 1)
        let novels = try XCTUnwrap(Library.answer("推薦幾本西方經典小說"))
        XCTAssertFalse(novels.contains("《哈姆雷特》"), "劇本不是小說")
        let cn = try XCTUnwrap(Library.answer("中國有名的古典小說有哪些"))
        XCTAssertTrue(cn.contains("《紅樓夢》") && !cn.contains("《活著》"))
        // 有具體作品名、或不是在問作品：不攔
        XCTAssertNil(Library.answer("哈姆雷特為什麼有名"))
        XCTAssertNil(Library.answer("有名的西方節日有哪些"))
    }

    func testWorkAnswer() throws {
        let a = try XCTUnwrap(Library.workAnswer("鐵達尼號講的是什麼"))
        XCTAssertTrue(a.contains("傑克") && a.contains("蘿絲"), "是電影，不是船")
        let b = try XCTUnwrap(Library.workAnswer("活著這本書在講什麼"))
        XCTAssertTrue(b.contains("福貴") && b.contains("📖"))
        let c = try XCTUnwrap(Library.workAnswer("哈姆雷特的結局"))
        XCTAssertTrue(c.contains("🔚") && !c.contains("📖"))
        XCTAssertNil(Library.workAnswer("今天天氣好嗎"))
    }

    func testEngineAnswersOffline() throws {
        let e = try SimpleQuestionsProbeTests.engine()
        for (q, must) in [("紅樓夢的作者是誰", "曹雪芹"), ("八大行星有哪些", "木星"), ("非常出名的西方文學作品講的都是什麼", "哈姆雷特")] {
            let r = e.reply(to: q, context: EchoEngine.Context())
            XCTAssertNil(r.webQuery, q)
            XCTAssertTrue(r.turn.text.contains(must), q + "：" + r.turn.text)
        }
        // 問「五行是什麼」不能先答「五行局」
        let r = e.reply(to: "五行是什麼", context: EchoEngine.Context())
        XCTAssertFalse(r.turn.text.contains("五行局"), r.turn.text)
    }
}
