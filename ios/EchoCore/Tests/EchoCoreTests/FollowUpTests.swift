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

    /// 多輪對話：答案在剛剛的回答裡、換一個地方、謎語的答案、回答「吃了嗎」、要建議時照前面說的事
    func testMultiTurnFromContext() throws {
        let a = try run(["台北到高雄多遠", "搭高鐵要多久", "那台中呢"])
        XCTAssertTrue(a[1].turn.text.contains("高鐵") && a[1].webQuery == nil, a[1].turn.text)
        XCTAssertTrue(a[2].turn.text.contains("台中") && a[2].webQuery == nil, a[2].turn.text)
        let b = try run(["番茄炒蛋怎麼做", "要放糖嗎", "可以加洋蔥嗎"])
        XCTAssertTrue(b[1].turn.text.contains("糖") && b[1].webQuery == nil, b[1].turn.text)
        XCTAssertNil(b[2].webQuery, b[2].turn.text)
        let c = try run(["猜謎語", "答案是什麼", "再一題"])
        XCTAssertTrue(c[1].turn.text.hasPrefix("答案是"), c[1].turn.text)
        XCTAssertTrue(c[2].turn.text.contains("謎語") || c[2].turn.text.contains("腦筋急轉彎"), c[2].turn.text)
        let d = try run(["我剛下班", "還沒"])
        XCTAssertTrue(d[1].turn.text.contains("吃") && d[1].webQuery == nil, d[1].turn.text)
        let e = try run(["我想去日本玩", "要帶多少錢", "要簽證嗎"])
        XCTAssertTrue(e[2].turn.text.contains("日本") && e[2].webQuery == nil, e[2].turn.text)
        let f = try run(["工作做不完", "主管一直催", "我該怎麼辦"])
        XCTAssertNil(f[2].webQuery, f[2].turn.text)
        let g = try run(["天空是什麼顏色", "為什麼"])
        XCTAssertTrue(g[1].turn.text.contains("散射") && g[1].webQuery == nil, g[1].turn.text)
        let h = try run(["我考試考砸了", "數學"])
        XCTAssertTrue(h[1].turn.text.contains("數學") && h[1].webQuery == nil, h[1].turn.text)
    }

    /// 多輪對話：比較、推薦換一種、更正、幾句前的主題、寵物代名詞、就醫時機
    func testMultiTurnRefinements() throws {
        let a = try run(["台灣和日本哪個大", "人口呢"])
        XCTAssertTrue(a[0].turn.text.contains("日本比較大"), a[0].turn.text)
        XCTAssertNil(a[1].webQuery, a[1].turn.text)
        let b = try run(["推薦一部電影", "要溫馨一點的", "適合跟家人看的"])
        XCTAssertTrue(b[1].turn.text.contains("可可夜總會") && b[1].webQuery == nil, b[1].turn.text)
        XCTAssertFalse(b[2].turn.text.contains("生日"), b[2].turn.text)
        let c = try run(["台灣最高的山", "不是，我是問第二高的"])
        XCTAssertTrue(c[1].turn.text.contains("雪山"), c[1].turn.text)
        let d = try run(["我想學游泳", "要多久才會", "要買什麼"])
        XCTAssertTrue(d[2].turn.text.contains("泳帽") && d[2].webQuery == nil, d[2].turn.text)
        let e = try run(["我養了一隻狗", "叫Lucky", "牠很愛叫"])
        XCTAssertTrue(e[2].turn.text.contains("叫") && e[2].webQuery == nil, e[2].turn.text)
        let f = try run(["我的貓不吃飯", "已經兩天了"])
        XCTAssertTrue(f[1].turn.text.contains("獸醫") && f[1].webQuery == nil, f[1].turn.text)
        let g = try run(["富士山有多高", "什麼時候去最好"])
        XCTAssertTrue(g[1].turn.text.contains("月") && g[1].webQuery == nil, g[1].turn.text)
        let h = try run(["我想喝咖啡", "可是已經晚上了"])
        XCTAssertTrue(h[1].turn.text.contains("咖啡因"), h[1].turn.text)
        let i = try run(["跑步好還是游泳好", "一天要走幾步"])
        XCTAssertTrue(i[1].turn.text.contains("步"), i[1].turn.text)
    }

    /// 心情的長對話：不能回「做不到」、不知道怎麼辦要給方法、「如果…怎麼辦」照一般問題答
    func testEmotionalConversation() throws {
        let a = try run(["我好焦慮", "明天要報告", "我準備好了但還是很怕", "如果講不好怎麼辦", "你可以給我一點鼓勵嗎"])
        XCTAssertTrue(a[2].turn.text.contains("緊張") || a[2].turn.text.contains("在乎"), a[2].turn.text)
        XCTAssertNil(a[3].webQuery, a[3].turn.text)
        XCTAssertFalse(a[4].turn.text.contains("做不到"), a[4].turn.text)
        let b = try run(["我最近心情很差", "工作很不順", "同事也不幫我", "我不知道該怎麼辦"])
        XCTAssertNil(b[3].webQuery, b[3].turn.text)
        XCTAssertFalse(b[2].turn.text.contains("運勢"), b[2].turn.text)
    }

    /// 不同的打法：簡體字、異體字、開場白、句尾的 XD、大小寫、多打的字
    func testInputVariants() throws {
        let cases: [(String, String)] = [("猫可以吃巧克力吗", "不"), ("怎么煮白饭", "米"), ("番茄炒蛋怎麽做", "蛋"), ("台湾最高的山是哪座", "玉山"),
                                          ("我問你喔，台北101有多高", "508"), ("台北101有多高XD", "508"), ("iphone怎麼截圖", "截圖"),
                                          ("WiFi一直斷線", "Wi-Fi"), ("每天應該喝多少水", "毫升"), ("狗吃巧克力會怎樣", "不"),
                                          ("颱風形成的原因", "海水"), ("富士山在那裡", "日本"), ("可以告訴我牙齒痛怎麼辦嗎", "牙"), ("長頸鹿要如何睡覺", "睡")]
        for (q, must) in cases {
            let r = try run([q])[0]
            XCTAssertTrue(r.webQuery == nil && r.turn.text.contains(must), "\(q) → \(r.turn.text.prefix(60))")
        }
        // 口氣詞開頭、全形數字、「你知不知道…」、英文公司名的大小寫
        for (q, must) in [("嘿嘿 日本的首都是哪裡", "東京"), ("喂喂 貓可以吃巧克力嗎", "不"), ("好 那月亮離地球多遠", "38.4"), ("台北１０１多高", "508"),
                          ("你知不知道日本首都在哪", "東京"), ("google是誰創立的", "佩吉"), ("Google是哪一年成立的", "1998"), ("youtube是誰創的", "陳士駿"),
                          ("哪個國家人最多", "印度"), ("水滾是幾度", "100"), ("我想學python要怎麼開始", "Python")] {
            let r = try run([q])[0]
            XCTAssertTrue(r.webQuery == nil && r.turn.text.contains(must), "\(q) → \(r.turn.text.prefix(60))")
        }
        // 「google 台北101」還是叫我上網查
        XCTAssertNotNil(try run(["google 台北101"])[0].webQuery)
        // 繁體的「公里」「皇后」「只有」不能被改掉
        XCTAssertEqual(Hanzi.toTraditional("台北到高雄幾公里"), "台北到高雄幾公里")
        XCTAssertEqual(Hanzi.toTraditional("我只有一個皇后"), "我只有一個皇后")
        XCTAssertEqual(Hanzi.toTraditional("我的头发好干"), "我的頭髮好干")
    }

    /// 一次問兩個、打招呼接問題、「拜拜」不是再見、地名加「有什麼好玩的」
    /// 一大段在說自己的事、最後問「怎麼辦／要不要」：回答真正問的那件事，不是整段拿去上網查
    func testLongPersonalMessages() throws {
        let cases: [(String, String)] = [
            ("我家的貓從昨天開始就一直吐，也不太吃東西，精神看起來也不好，我很擔心，要不要帶去看醫生", "獸醫"),
            ("我男朋友最近都很晚回我訊息，問他在幹嘛他也只說在忙，我覺得他是不是不愛我了，我該怎麼辦", "不安"),
            ("最近工作壓力很大，每天都加班到很晚，回家只想躺著，週末也提不起勁出門，我是不是生病了", "倦怠"),
            ("我跟最好的朋友吵架了，因為她把我的秘密說出去，現在我們都不講話，我該怎麼辦", "和好"),
            ("我今天在公司被主管當著大家的面罵，因為我報告裡有一個數字寫錯，我覺得很丟臉，回家之後一直想這件事，晚上也睡不著，不知道明天要怎麼面對大家", "主管"),
            ("我媽最近一直咳嗽，已經咳了兩個禮拜了，她都說沒事不想去看醫生，我很擔心", "陪你去"),
            ("我想要換工作，可是現在的工作很穩定，新的工作薪水比較高但是要常常加班，不知道該不該換", "加班"),
        ]
        for (q, must) in cases {
            let r = try run([q])[0]
            XCTAssertTrue(r.webQuery == nil && r.turn.text.contains(must) && r.turn.text.contains("\n1. "), "\(q.prefix(20)) → \(r.turn.text.prefix(80))")
        }
        // 很長但在問事情的，照常回答或上網查，不給心靈建議
        let fact = try run(["我想知道為什麼天空是藍色的，還有晚上為什麼是黑的呢"])[0]
        XCTAssertFalse(fact.turn.text.contains("抱抱你") || fact.turn.text.contains("我陪你一起想"), fact.turn.text)
        let trip = try run(["我下個月要去日本東京玩五天，請問那邊現在天氣冷嗎"])[0]
        XCTAssertNotNil(trip.webQuery, trip.turn.text)
        // 「吉他」的「吉」不是在問運勢
        let guitar = try run(["我最近在學吉他，這樣正常嗎"])[0]
        XCTAssertNotEqual(guitar.turn.source, .grounded, guitar.turn.text)
        XCTAssertFalse(guitar.turn.text.contains("生日"), guitar.turn.text)
    }

    /// 換句話說也認得：本來要上網查或只會回客套話的，對到自己知道的事；不像的不能硬套
    func testParaphrasesFindKnownAnswers() throws {
        let cases: [(String, String)] = [("手機被人偷走了", "尋找"), ("家裡好多蚊子", "積水"), ("告白被打槍了", "拒絕"), ("馬桶堵住了要怎麼通", "吸盤"),
                                          ("騎摩托車要小心什麼", "安全帽"), ("我的電腦好卡", "電腦"), ("退租押金沒拿回來", "存證信函"), ("同事老是把他的工作丟給我", "拒絕"),
                                          ("孩子都不好好吃飯", "零食"), ("健保卡弄丟了要去哪裡補", "工本費")]
        for (q, must) in cases {
            let r = try run([q])[0]
            XCTAssertTrue(r.webQuery == nil && r.turn.text.contains(must), "\(q) → \(r.turn.text.prefix(60))")
        }
        // 長得有點像、但問的是別的事
        for q in ["老闆不給加班費違法嗎", "iPhone 17 多少錢", "信用卡年費多少", "世界上第二高的山是哪一座"] {
            XCTAssertNil(Fuzzy.match(q), q)
        }
        // 「被偷走了」不是有人過世
        XCTAssertNotEqual(Affect.detect("手機被人偷走了"), .grief)
        XCTAssertEqual(Affect.detect("我阿公上個月走了"), .grief)
    }

    func testCompoundGreetingAndWorship() throws {
        let a = try run(["台北101多高，富士山多高"])[0]
        XCTAssertTrue(a.turn.text.contains("508") && a.turn.text.contains("3776"), a.turn.text)
        let b = try run(["日本首都是哪裡？韓國呢？"])[0]
        XCTAssertTrue(b.turn.text.contains("東京") && b.turn.text.contains("首爾"), b.turn.text)
        let c = try run(["早安，今天幾號"])[0]
        XCTAssertTrue(c.turn.text.contains("今天是"), c.turn.text)
        let d = try run(["拜拜要準備什麼"])[0]
        XCTAssertFalse(d.turn.text.contains("下次聊") || d.turn.text.contains("掰掰"), d.turn.text)
        let e = try run(["宜蘭有什麼好玩的"])[0]
        XCTAssertFalse(e.turn.text.contains("學一道新菜"), e.turn.text)
    }
}
