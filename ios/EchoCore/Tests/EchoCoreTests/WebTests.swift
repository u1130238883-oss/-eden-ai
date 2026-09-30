import XCTest
@testable import EchoCore

/// 上網功能：問題要交給網路查，而不是用本地寫死的答案
final class WebRoutingTests: XCTestCase {
    func testQuestionsGoToTheWeb() throws {
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 3)
        var ctx = EchoEngine.Context(now: t.date(2026, 9, 29, 21))
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 8, minute: 0, male: true)

        let web: [String] = [
            "台北101有多高？", "上網查 iPhone 17 價格", "幫我查一下今天的新聞", "明天台北天氣如何", "美元對台幣匯率多少",
            "量子電腦是什麼", "日本首相是誰", "搜尋 珍珠奶茶的由來", "紅燒肉怎麼煮", "世界上最高的山是哪一座",
            "上網查偏財格", "who won the last world cup", "what is the capital of Peru", "search quantum physics",
            "高雄到台南要多久", "今天股市怎麼樣？", "甲減是什麼", "甲狀腺疾病有哪些", "我有甲減要注意什麼", "甲亢的症狀",
            "橋本氏甲狀腺炎怎麼治療", "糖尿病可以吃什麼", "房東不還押金怎麼辦", "車禍對方不賠償怎麼辦", "老闆不給加班費違法嗎",
            "離婚要準備什麼", "被詐騙了怎麼辦", "遺產怎麼分",
        ]
        var fails: [String] = []
        for q in web {
            let r = engine.reply(to: q, context: ctx)
            if r.webQuery == nil { fails.append("✗ 沒上網：\(q) → \(r.turn.text.prefix(40))") }
        }
        // 這些還是要用本地的命理／陪伴（不能被上網搶走）
        let local: [String] = ["今天運勢", "我的八字", "我今年感情怎麼樣", "你會唱歌嗎", "我今天好累", "你好", "12+30", "我的紫微斗數",
                               "我今年會不會離婚", "我的健康運", "我今年身體怎麼樣"]
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
        XCTAssertEqual(WebAgent.coreTopic("台北101有多高"), "台北101")
        XCTAssertEqual(WebAgent.coreTopic("紅燒肉怎麼煮"), "紅燒肉")
        XCTAssertEqual(WebAgent.understand("甲減是什麼", L: .zh, fortune: false).kind, .health)
        XCTAssertEqual(WebAgent.understand("房東不還押金怎麼辦", L: .zh, fortune: false).kind, .legal)
        XCTAssertEqual(WebAgent.understand("今天股市怎麼樣", L: .zh, fortune: false).kind, .news)
        XCTAssertEqual(WebStrategy.canonical("甲減"), "甲狀腺機能低下症")

        // 命理：網路說法對照自己的盤
        let c = WebFortune.parse("你的日主是癸水，身弱，喜金、水，忌土、火、木；2026年丙午對你是壞的")
        XCTAssertEqual(c.dayMaster, "癸水")
        XCTAssertEqual(c.strong, false)
        XCTAssertEqual(c.fav, ["金", "水"])
        XCTAssertEqual(c.avoid, ["木", "火", "土"])
        XCTAssertEqual(WebFortune.judge("癸水日主身弱，喜金水相生", c).0, .fits)
        XCTAssertEqual(WebFortune.judge("癸水生於冬月，喜火調候", c).0, .conflicts)
        XCTAssertEqual(WebFortune.judge("身強的癸水喜木火洩秀", c).0, .conflicts)
        XCTAssertEqual(WebStrategy.toTraditional("甲状腺功能减退的症状"), "甲狀腺功能減退的症狀")
    }
}

/// 追問、反問句過濾、數字多數決、腦筋急轉彎（不用連網）
final class WebThinkingTests: XCTestCase {
    func testFollowUpAndFiltering() throws {
        XCTAssertEqual(EchoEngine.resolveFollowUp("那這些國家都是哪些國家", query: "那這些國家都是哪些國家", previous: "歐洲有多少個國家", gap: 2),
                       "歐洲 國家 哪些國家 列表")
        XCTAssertTrue(EchoEngine.resolveFollowUp("我是說這些歐洲國家是哪些國家？", query: "我是說這些歐洲國家是哪些國家", previous: "歐洲有多少個國家", gap: 2)
            .hasPrefix("歐洲國家"))
        XCTAssertEqual(EchoEngine.resolveFollowUp("台北101有多高", query: "台北101有多高", previous: "歐洲有多少個國家", gap: 2), "台北101有多高")
        XCTAssertTrue(WebAgent.isQuestionOrFluff("知道歐洲有多少個國家嗎？"))
        XCTAssertTrue(WebAgent.isQuestionOrFluff("大家都知道，在我們認知的世界上，有個地方叫歐洲"))
        XCTAssertFalse(WebAgent.isQuestionOrFluff("歐洲共有46個國家，按地理位置通常分為五個地區。"))
        let fs = [WebAgent.Finding(text: "歐洲共有46個國家", host: "a.com", url: "https://a.com"),
                  WebAgent.Finding(text: "目前歐洲有46個國家和地區", host: "b.com", url: "https://b.com"),
                  WebAgent.Finding(text: "歐洲約有50個國家", host: "c.com", url: "https://c.com")]
        let v = WebAgent.numberVote(fs, core: "歐洲")
        XCTAssertEqual(v?.best, "46個")
        XCTAssertEqual(v?.others, ["50個"])
        XCTAssertEqual(WebSearch.wikiTerm("誰發明了電話"), "發明 電話")
        XCTAssertEqual(WebSearch.wikiTerm("地球到月亮有多遠"), "地球 月亮")
        XCTAssertEqual(WebSearch.wikiTerm("日本的首都是哪裡"), "日本 首都")
        XCTAssertEqual(WebAgent.readablePath("https://zh.wikipedia.org/zh-tw/%E6%AD%90%E6%B4%B2"), "zh-tw/歐洲")

        // 腦筋急轉彎：本地直接答，不用上網
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 3)
        let ctx = EchoEngine.Context(now: t.date(2026, 9, 30, 11))
        for (q, must) in [("把冰箱放進大象裡需要多少步", "打開大象"), ("把大象放進冰箱需要幾步", "三步"), ("一公斤的鐵和一公斤的棉花哪個重", "一樣重")] {
            let r = engine.reply(to: q, context: ctx)
            XCTAssertTrue(r.turn.text.contains(must), "\(q) → \(r.turn.text.prefix(40))")
            XCTAssertNil(r.webQuery, q)
        }
        // 上網的回覆不帶宮位標籤；追問要補主題
        let a = engine.reply(to: "日本有多少個縣？", context: ctx)
        XCTAssertNotNil(a.webQuery)
        XCTAssertNil(a.turn.palace)
        let b = engine.reply(to: "那這些縣都是哪些縣", history: [ChatTurn(role: .user, text: "日本有多少個縣？"), a.turn], context: ctx)
        XCTAssertTrue(b.webQuery?.contains("日本") == true, b.webQuery ?? "nil")
    }
}

/// 模擬真人提問：整段對話走 EchoEngine → 需要時 WebAgent 上網（CI 用 NINESUN_LIVE=1 執行）
final class WebConversationLiveTests: XCTestCase {
    /// 直接寫到 stderr（不經過緩衝，測試結束時才不會掉字）
    func say(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }

    func testLiveConversation() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NINESUN_LIVE"] == "1", "live test")
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 5)
        var ctx = EchoEngine.Context(now: t.date(2026, 9, 30, 11))
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 7, minute: 0, male: true)
        let conversation = [
            "把冰箱放進大象裡需要多少步", "把大象放進冰箱裡需要幾步",
            "歐洲有多少個國家？", "那這些國家都是哪些國家", "我是說這些歐洲國家是哪些國家？",
            "台北101有多高", "天空為什麼是藍色的", "感冒了怎麼辦", "誰發明了電話", "地球到月亮有多遠",
            "iPhone和安卓哪個好", "日本的首都是哪裡", "怎麼煮白飯", "老闆不給我加薪怎麼辦",
        ]
        var history: [ChatTurn] = []
        var slow = 0
        for q in conversation {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let t0 = Date()
            let r = engine.reply(to: q, history: history, context: ctx)
            history += [ChatTurn(role: .user, text: q), r.turn]
            say("LIVE ===== 問：\(q)")
            say(r.turn.text.split(separator: "\n").prefix(8).map { "LIVE | " + $0 }.joined(separator: "\n"))
            if let wq = r.webQuery {
                let w = await WebAgent.run(wq, lang: .zh)
                let secs = Date().timeIntervalSince(t0)
                if secs > 15 { slow += 1 }
                say("LIVE --- 上網查「\(wq)」 用了 \(String(format: "%.1f", secs)) 秒 found=\(w.found)")
                if !w.debug.isEmpty { say("LIVE DEBUG " + w.debug) }
                // 只印回答和判斷，思路那段略過
                let lines = w.text.split(separator: "\n").map(String.init)
                let from = lines.firstIndex { $0.hasPrefix("📌") } ?? 0
                say(lines[from...].prefix(14).map { "LIVE | " + $0 }.joined(separator: "\n"))
            }
        }
        say("LIVE-CONVERSATION: \(conversation.count) questions, \(slow) slower than 15s")
    }
}

/// 真的連上網路測試（CI 用 NINESUN_LIVE=1 執行；平常跳過）
final class WebLiveTests: XCTestCase {
    func testLiveSearch() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NINESUN_LIVE"] == "1", "live test")
        let qs: [(String, Lang)] = [
            ("甲減是什麼", .zh), ("房東不還押金怎麼辦", .zh), ("甲狀腺疾病有哪些", .zh), ("老闆不給加班費違法嗎", .zh),
            ("台北101有多高", .zh), ("紅燒肉怎麼煮", .zh), ("美元對台幣匯率多少", .zh), ("今天股市怎麼樣", .zh),
            ("what is the capital of Peru", .en),
        ]
        var found = 0
        for (q, L) in qs {
            try? await Task.sleep(nanoseconds: 3_000_000_000)   // 像真人一樣一題一題問
            let r = await WebAgent.run(q, lang: L)
            if r.found { found += 1 }
            print("LIVE ===== \(q) found=\(r.found) engines=\(r.engines.sorted { $0.key < $1.key })")
            if !r.debug.isEmpty { print("LIVE DEBUG " + r.debug) }
            print(r.text.split(separator: "\n").map { "LIVE | " + $0 }.joined(separator: "\n"))
        }
        let f = await WebAgent.run("八字 癸水日主 感情", facts: "你的日主是癸水，身弱，喜金、水，忌土、火、木；2026年丙午對你是壞的",
                                   also: ["癸水日主 身弱 感情"], lang: .zh)
        print("LIVE ===== 命理對照 found=\(f.found) engines=\(f.engines.sorted { $0.key < $1.key })")
        print(f.text.split(separator: "\n").map { "LIVE | " + $0 }.joined(separator: "\n"))
        print("LIVE-SUMMARY: \(found)/\(qs.count) found")
        XCTAssertGreaterThanOrEqual(found, qs.count - 2)
    }
}
