import XCTest
@testable import EchoCore

/// 上網功能：問題要交給網路查，而不是用本地寫死的答案
final class WebRoutingTests: XCTestCase {
    func testQuestionsGoToTheWeb() throws {
        let t = EchoCoreTests()
        let engine = try t.makeEngine(seed: 3)
        var ctx = EchoEngine.Context(now: t.date(2026, 9, 29, 21))
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 8, minute: 0, male: true)

        let web: [String] = [
            "台北101有多高？", "上網查 iPhone 17 價格", "幫我查一下今天的新聞", "明天台北天氣如何", "美元對台幣匯率多少",
            "量子電腦是什麼", "日本首相是誰", "搜尋 珍珠奶茶的由來", "紅燒肉怎麼煮", "世界上最高的山是哪一座",
            "上網查偏財格", "who won the last world cup", "what is the capital of Peru", "search quantum physics",
            "高雄到台南要多久", "今天股市怎麼樣？",
        ]
        var fails: [String] = []
        for q in web {
            let r = engine.reply(to: q, context: ctx)
            if r.webQuery == nil { fails.append("✗ 沒上網：\(q) → \(r.turn.text.prefix(40))") }
        }
        // 這些還是要用本地的命理／陪伴（不能被上網搶走）
        let local: [String] = ["今天運勢", "我的八字", "我今年感情怎麼樣", "你會唱歌嗎", "我今天好累", "你好", "12+30", "我的紫微斗數"]
        for q in local {
            let r = engine.reply(to: q, context: ctx)
            if r.webQuery != nil { fails.append("✗ 不該上網：\(q)") }
        }
        print("WEB-ROUTING: \(web.count + local.count - fails.count) ok, \(fails.count) failed")
        fails.forEach { print($0) }
        XCTAssertTrue(fails.isEmpty, fails.joined(separator: "\n"))

        XCTAssertEqual(EchoEngine.explicitSearch("上網查 iPhone 17 價格"), "iPhone 17 價格")
        XCTAssertNil(EchoEngine.explicitSearch("幫我查今天運勢"))
    }

    func testParsers() {
        let xml = """
        <rss><channel><title>x</title><item><title>台北101 - 維基百科</title><link>https://zh.wikipedia.org/wiki/台北101</link>
        <description>台北101高度 508 公尺，&amp;曾是世界第一高樓。</description></item></channel></rss>
        """
        let items = WebSearch.rssItems(xml)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.desc, "台北101高度 508 公尺，&曾是世界第一高樓。")
        XCTAssertEqual(WebSearch.ddgRealURL("//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fa&rut=1"), "https://example.com/a")
        XCTAssertEqual(WebSearch.place("台北明天天氣如何"), "台北")
        XCTAssertEqual(WebAgent.keywords("請問台北101有多高？"), "台北101有多高")
        XCTAssertEqual(WebAgent.keywords("上網查 iPhone 17 價格"), "iPhone 17 價格")
    }
}

/// 真的連上網路測試（CI 用 NINESUN_LIVE=1 執行；平常跳過）
final class WebLiveTests: XCTestCase {
    func testLiveSearch() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NINESUN_LIVE"] == "1", "live test")
        let qs: [(String, Lang)] = [
            ("台北101有多高", .zh), ("量子電腦是什麼", .zh), ("台北明天天氣如何", .zh), ("今天台灣新聞", .zh),
            ("紅燒肉怎麼煮", .zh), ("偏財格", .zh), ("what is the capital of Peru", .en),
        ]
        var found = 0
        for (q, L) in qs {
            let r = await WebAgent.run(q, lang: L)
            if r.found { found += 1 }
            print("LIVE ===== \(q) found=\(r.found) engines=\(r.engines.sorted { $0.key < $1.key })")
            print(r.text.split(separator: "\n").map { "LIVE | " + $0 }.joined(separator: "\n"))
        }
        print("LIVE-SUMMARY: \(found)/\(qs.count) found")
        XCTAssertGreaterThanOrEqual(found, qs.count - 1)
    }
}
