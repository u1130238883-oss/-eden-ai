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

final class LibraryWhoTests: XCTestCase {
    func testWhoDid() {
        XCTAssertTrue(Library.answer("相對論是誰提出的")?.contains("愛因斯坦") == true)
        XCTAssertTrue(Library.answer("蘋果公司是誰創立的")?.contains("賈伯斯") == true)
        XCTAssertTrue(Library.answer("蘋果是誰創立的")?.contains("賈伯斯") == true)
        XCTAssertTrue(Library.answer("微軟的創辦人是誰")?.contains("蓋茲") == true)
        XCTAssertTrue(Library.answer("誰發現了萬有引力")?.contains("牛頓") == true)
        XCTAssertTrue(Library.answer("台積電的創辦人是誰")?.contains("張忠謀") == true)
        XCTAssertNil(Library.answer("我家的狗是誰發現的"))
    }

    func testDefineFallback() {
        XCTAssertTrue(Library.defineAnswer("DeepSeek是什麼")?.contains("人工智慧") == true)
        XCTAssertNil(Library.defineAnswer("蘋果是什麼"), "蘋果是水果")
    }
}

final class TalkTests: XCTestCase {
    func testTalk() {
        for (q, must) in [("你有感情嗎", "感情"), ("你喜歡什麼？", "喜歡"), ("給我講個笑話", ""), ("你覺得AI會取代人類嗎", "取代"),
                          ("我該不該換工作", "存款"), ("怎麼交到女朋友", "生活圈"), ("你覺得我很笨嗎", "不覺得"), ("世界上有外星人嗎", "證據"),
                          ("算命準嗎", "鏡子"), ("人生的意義是什麼", "意義")] {
            let a = Talk.answer(q)
            XCTAssertNotNil(a, q)
            if !must.isEmpty { XCTAssertTrue(a?.contains(must) == true, q + "：" + (a ?? "nil")) }
        }
        // 不能攔下來的：自己的事、命理問題、知識題
        for q in ["我今年感情運如何", "你喜歡的人是誰的生日", "我喜歡你", "外星人電影推薦", "換工作要注意什麼", "交到女朋友了"] {
            XCTAssertNil(Talk.answer(q), q)
        }
    }

    func testGoodNewsIsNotAQuestion() {
        XCTAssertEqual(Affect.detect("怎麼交到女朋友"), .info)
        XCTAssertEqual(Affect.detect("我交到女朋友了"), .goodNews)
    }
}
