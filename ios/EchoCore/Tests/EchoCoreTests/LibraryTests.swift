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

final class EverydaySafetyTests: XCTestCase {
    func testPetFood() {
        XCTAssertTrue(Commonsense.answer("狗可以吃葡萄嗎")?.hasPrefix("不可以") == true)
        XCTAssertTrue(Commonsense.answer("貓可以喝牛奶嗎")?.hasPrefix("不可以") == true, "以前答「可以」")
        XCTAssertTrue(Commonsense.answer("狗可以吃巧克力嗎")?.hasPrefix("不可以") == true)
        XCTAssertTrue(Commonsense.answer("狗可以吃肉嗎")?.hasPrefix("可以") == true)
    }

    func testPrizeTransferIsAScam() {
        XCTAssertTrue(ScamCheck.looks("有人叫我匯款說中獎了"))
        XCTAssertTrue(ScamCheck.looks("對方說我中獎了要我先轉帳"))
        XCTAssertFalse(ScamCheck.looks("我中獎了"))
        XCTAssertFalse(ScamCheck.looks("怎麼匯款給家人"))
    }

    func testHowtoHeadings() {
        XCTAssertTrue(Commonsense.answer("被霸凌怎麼辦")?.hasPrefix("被霸凌不是你的錯") == true)
        XCTAssertTrue(Commonsense.answer("一天要喝多少水")?.contains("30 毫升") == true)
        XCTAssertNil(Translate.parse("怎麼學好英文"))
        XCTAssertNotNil(Translate.parse("蘋果的英文怎麼說"))
    }

    func testGoodNewsFollowUp() throws {
        let e = try SimpleQuestionsProbeTests.engine()
        let r = e.reply(to: "我考上大學了", context: EchoEngine.Context())
        XCTAssertTrue(r.turn.text.contains("科系"), r.turn.text)
        XCTAssertFalse(r.turn.text.contains("發生了什麼事"), r.turn.text)
    }
}

final class MyTopicTests: XCTestCase {
    func testMyTopicGoesToTheReading() throws {
        XCTAssertEqual(EchoEngine.myTopic("我的健康要注意什麼？"), "我的健康怎麼樣")
        XCTAssertEqual(EchoEngine.myTopic("我的身體要注意什麼"), "我的健康怎麼樣")
        XCTAssertNil(EchoEngine.myTopic("我的身體一直發燒怎麼辦"))
        var ctx = EchoEngine.Context()
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 8)
        let e = try SimpleQuestionsProbeTests.engine()
        let r = e.reply(to: "我的錢財要注意什麼", context: ctx)
        XCTAssertNil(r.webQuery)
        XCTAssertTrue(r.turn.text.contains("2宮"), r.turn.text)
    }
}

final class ConversationTests: XCTestCase {
    func run(_ lines: [String]) throws -> [EchoEngine.Reply] {
        let e = try SimpleQuestionsProbeTests.engine()
        var ctx = EchoEngine.Context()
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 8)
        var history: [ChatTurn] = [], out: [EchoEngine.Reply] = []
        for q in lines {
            let r = e.reply(to: q, history: history, context: ctx)
            history += [ChatTurn(role: .user, text: q), r.turn]
            out.append(r)
        }
        return out
    }

    func testFillersAreNotSearches() throws {
        for q in ["好", "嗯", "😂", "？", "不知道", "隨便", "算了", "123", "你答錯了"] {
            let r = try run([q]).last!
            XCTAssertNil(r.webQuery, q)
        }
    }

    func testFollowUps() throws {
        XCTAssertTrue(try run(["八大行星有哪些", "最大的是哪一個"]).last!.turn.text.contains("木星"))
        XCTAssertEqual(try run(["哈姆雷特在講什麼", "結局呢"]).last!.webQuery, "哈姆雷特的結局")
        XCTAssertEqual(try run(["紅樓夢的作者是誰", "他還寫了什麼"]).last!.webQuery, "曹雪芹還寫了什麼")
        let joke = try run(["給我講個笑話", "再一個"])
        XCTAssertNil(joke.last!.webQuery)
        XCTAssertNotEqual(joke[0].turn.text, joke[1].turn.text)
        XCTAssertTrue(try run(["早安", "好"]).last!.turn.text.contains("今天"))
        XCTAssertTrue(try run(["什麼是通貨膨脹", "可以說簡單一點嗎"]).last!.turn.text.hasPrefix("簡單說"))
    }
}

final class WritingHelpTests: XCTestCase {
    func testWritingRequests() {
        XCTAssertTrue(Talk.answer("幫我寫一段生日祝福")?.contains("生日快樂") == true)
        XCTAssertTrue(Talk.answer("幫我寫一封請假信")?.contains("請假") == true)
        XCTAssertTrue(Talk.answer("寫一首關於月亮的詩")?.contains("〈月亮〉") == true)
        XCTAssertTrue(Talk.answer("幫我取一個貓的名字")?.contains("布丁") == true)
        XCTAssertTrue(Talk.answer("我和我男朋友合不合")?.contains("生日") == true)
        // 有生日的合盤交給引擎算，不攔
        XCTAssertNil(Talk.answer("我男朋友1998年5月5日生，我們合不合"))
        XCTAssertTrue(Commonsense.answer("今年過年是幾號")?.contains("春節") == true)
    }
}

final class SmallTalkTests: XCTestCase {
    func testStatementsGetARealReply() {
        for (q, must) in [("我今天去看電影了", "好看嗎"), ("我今天吃了拉麵", "好吃嗎"), ("我剛下班", "辛苦了"), ("我在家", "在家"),
                          ("我朋友要結婚了", "替你朋友開心"), ("我明天要去日本", "日本有什麼好玩的"), ("剛剛下大雨", "帶傘")] {
            let a = Talk.chat(q)
            XCTAssertTrue(a?.contains(must) == true, q + "：" + (a ?? "nil"))
        }
        // 問題、喜歡一個人、想死這些不是閒聊
        for q in ["我今天去看電影好嗎", "我喜歡你", "我喜歡一個人", "我想死", "我在想什麼"] { XCTAssertNil(Talk.chat(q), q) }
        XCTAssertEqual(Affect.detect("我朋友要結婚了"), .happy)
    }
}
