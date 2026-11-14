import XCTest
@testable import EchoCore

/// 使用者 2026-11-11 的截圖裡答得不好的，照原樣寫成測試（每一張截圖都要變成一題，永遠留著）
final class ScreenshotTests: XCTestCase {
    static let questions = ["時間是什麼", "愛是什麼", "夏洛特的煩惱", "夏洛特的煩惱講的是什麼", "少年維特的煩惱講的是什麼",
                            "如果有一個按鈕讓你按下其中一個按鈕按下了就能拯救你自己，然後其他人都會死掉另一個按鈕按下去別人都能活，但是你會死掉，你怎麼選擇？",
                            "五行是什麼東西？", "紅樓夢的作者是誰", "八大行星有哪些"]

    func engine() throws -> EchoEngine {
        Intent.shared = try? Intent(weights: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("intent.bin")),
                                    metaJSON: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("intent.json")))
        return try SimpleQuestionsProbeTests.engine()
    }

    var me: EchoEngine.Context {
        var c = EchoEngine.Context()
        c.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14))
        return c
    }

    /// 「夏洛特的煩惱」是片名，不是在說心情（截圖：被答成 1 宮「自我」、慢慢來我在）
    func testTitleIsNotAFeeling() throws {
        let e = try engine()
        for q in ["夏洛特的煩惱", "少年維特的煩惱", "夏洛特的煩惱講的是什麼", "少年維特的煩惱講的是什麼", "蘇菲的抉擇在講什麼"] {
            let r = e.reply(to: q, history: [], context: me)
            XCTAssertNotNil(r.webQuery, "\(q) → \(r.turn.text.prefix(40))")
            XCTAssertNil(r.turn.palace, q)
            XCTAssertTrue(BrainRoute.namedWork(q), q)
        }
        // 主題不能把「講的」算進去；搜尋的字也不能有
        XCTAssertEqual(Understanding.frame("夏洛特的煩惱講的是什麼").subject, "夏洛特的煩惱")
        XCTAssertFalse(e.reply(to: "夏洛特的煩惱講的是什麼", history: [], context: me).webQuery?.contains("講的") ?? true)
        // 真的在說心情的照舊（不能把人的煩惱當成片名）
        for q in ["我好煩惱", "最近好煩", "媽媽的煩惱好多", "我的煩惱", "朋友的焦慮", "我很難過"] {
            XCTAssertFalse(EchoEngine.bareTitle(q), q)
            XCTAssertFalse(BrainRoute.namedWork(q), q)
        }
        XCTAssertNil(e.reply(to: "我好煩惱", history: [], context: me).webQuery)
    }

    /// 假設題問的是 NineSun 自己會怎麼選（截圖：按鈕題被答成 7 宮婚姻運）
    func testDilemmaGetsAStance() throws {
        let e = try engine()
        let q = Self.questions[5]
        XCTAssertTrue(Dilemma.looks(q))
        XCTAssertEqual(Dilemma.kind(q), .selfOrOthers)
        let r = e.reply(to: q, history: [], context: me)
        XCTAssertNil(r.turn.palace)
        XCTAssertNil(r.webQuery)
        XCTAssertTrue(r.turn.text.hasPrefix("我會按讓別人活下來的那個"), String(r.turn.text.prefix(60)))
        for bad in ["宮", "婚姻", "命盤", "運"] { XCTAssertFalse(r.turn.text.contains(bad), bad) }
        // 大腦開著：這種回答（.knowledge）會交給大腦推理
        XCTAssertEqual(r.turn.source, .knowledge)
        XCTAssertEqual(Dilemma.kind("如果電車前面有五個人，拉下拉桿會撞死另一個人，你會怎麼做"), .fewOrMany)
        XCTAssertEqual(Dilemma.kind("假如你媽媽和你女朋友同時掉到水裡，你先救誰"), .whoToSave)
        XCTAssertTrue(Dilemma.looks("如果只能選一個超能力你會選什麼"))
        // 不是假設題的不能被攔走：算命、心情、一般的問題
        for no in ["如果我今年換工作運勢會好嗎，你怎麼看", "你怎麼了", "我今天心情不好", "如果下雨怎麼辦", "台北101有多高", "你會選擇原諒他嗎", "你喜歡貓還是狗"] {
            XCTAssertFalse(Dilemma.looks(no), no)
        }
    }

    /// 「五行是什麼東西」的「東西」是口語，不是主題（截圖：搜到「什麼東西五行屬土」）
    func testFillerWords() throws {
        XCTAssertEqual(Understanding.frame("五行是什麼東西？").subject, "五行")
        XCTAssertEqual(try engine().reply(to: "五行是什麼東西？", history: [], context: me).webQuery, "五行是什麼")
        XCTAssertEqual(Understanding.clean("區塊鏈是個什麼玩意"), "區塊鏈是什麼")
        // 「東西」是問題本身的不動
        XCTAssertEqual(Understanding.clean("五行屬土的東西有哪些"), "五行屬土的東西有哪些")
    }

    /// 「X 是什麼」：開頭要是真的在說「X 是…」的那句——
    /// 不是講誤解的（很多人以為…）、不是主語是別人的（最後他提出…、它指的是…）、不是半句話
    func testDefinitionLeadsWithTheDefinition() {
        let wuxing = [(host: "leeren.com.tw", text: "很多人第一次聽到五行，以為是講木頭、火焰、泥土、金屬、水這五樣東西。\n其實五行講的是五種「性質」，古人拿這五樣東西當代表，用來把世界上的事物分類。\n木代表生長，火代表向上發熱，土代表承載，金代表收斂，水代表向下滋潤。"),
                      (host: "uptogo.com.tw", text: "對於許多希望透過風水佈局或命理調整來平衡自身磁場的人來說，瞭解什麼東西五行屬土至關重要。\n五行屬土的東西包括陶瓷、玉石和黃色的物品。"),
                      (host: "inzense.com.tw", text: "五行包括木、火、土、金、水，彼此之間有相生和相剋的關係。\n相生是木生火、火生土、土生金、金生水、水生木。")]
        let a = Synthesize.compose(question: "五行是什麼", subject: "五行", want: .definition, pages: wuxing, lead: "「很多人第一次聽到五行」（leeren.com.tw）") ?? ""
        XCTAssertTrue(a.hasPrefix("簡單說：五行講的是五種「性質」"), a)
        XCTAssertTrue(a.contains("木、火、土、金、水"), a)
        XCTAssertFalse(a.contains("以為"), a)
        XCTAssertFalse(a.contains("屬土至關重要"), a)

        let time = [(host: "pedia.cloud.edu.tw", text: "古希臘哲學家多用「運動」(motion)來界定時間。\n奧古斯丁對時間有深入的討論。\n最後他提出一個對時間的界說是：時間是呈現在靈魂中，並由靈魂來衡量的。"),
                    (host: "cosmo.wordpress.com", text: "時間是相對的 (Time is relative)，不同速度的觀察者量到的時間不一樣。\n其實在主流物理學中，時間是用來描述事件先後順序的一個維度。"),
                    (host: "sci.tw", text: "時間是用來描述事件發生先後和持續多久的物理量，基本單位是秒。")]
        let b = Synthesize.compose(question: "時間是什麼", subject: "時間", want: .definition, pages: time, lead: "「最後他提出一個對時間的界…」（pedia.cloud.edu.tw）") ?? ""
        XCTAssertTrue(b.hasPrefix("簡單說：時間是"), b)
        XCTAssertFalse(b.contains("最後他提出"), b)

        let love = [(host: "hketw.com", text: "古希臘人把愛分成好幾種。\n菲莉亞。它指的是友愛，是兄弟般的，以信任和陪伴為基礎的。\n另一方面，對佛教來說，愛是心靈解脫的道路。\n愛是一種發自內心、希望對方過得好的情感，會讓人願意付出和陪伴。"),
                    (host: "uptogo.com.tw", text: "心理學家佛洛姆在其暢銷經典《愛的藝術》中提到，愛是一種需要學習的能力，包含照顧、責任、尊重和了解。"),
                    (host: "gtan.com.tw", text: "今天將分享愛是什麼、愛一個人的表現。\n愛是指願意為對方付出、接納對方缺點的一種深厚感情。")]
        let c = Synthesize.compose(question: "愛是什麼", subject: "愛", want: .definition, pages: love, lead: "「菲莉亞.它指的是友愛」（hketw.com）") ?? ""
        XCTAssertTrue(c.hasPrefix("簡單說：愛是"), c)
        XCTAssertFalse(c.contains("它指的是"), c)
        XCTAssertFalse(c.contains("今天將分享"), c)
    }

    /// 維基的摘要寫「作者向來沒有定論」：那不是人名（上一輪引進維基摘要當佐證時多出來的錯）
    func testAuthorNotAPhrase() {
        typealias E = Understanding.Evidence
        let pages = [E(text: "《紅樓夢》，中國古典長篇章回小說。關於紅樓夢的作者向來沒有定論，一般認為前八十回為曹雪芹所著。", host: "zh.wikipedia.org"),
                     E(text: "紅樓夢的作者不詳的說法並不普遍。\n《紅樓夢》作者曹雪芹出身江寧織造曹家。", host: "a.com"),
                     E(text: "紅樓夢作者曹雪芹，名霑，字夢阮。", host: "b.com")]
        let a = Think.whoDid(question: "紅樓夢的作者是誰", pages: pages, subject: "紅樓夢") ?? ""
        XCTAssertTrue(a.hasPrefix("答案：曹雪芹"), a)
        XCTAssertFalse(a.contains("答案：向來"), a)
        // 只有「沒有定論」那一句時：寧可不答，也不把那句話當成名字
        XCTAssertNil(Think.whoDid(question: "紅樓夢的作者是誰", pages: [pages[0]], subject: "紅樓夢"))
    }

    /// 用中文問「八大行星」：數目對得上的有英文一串、中文一串，要用中文的
    func testChineseListPreferred() {
        typealias E = Understanding.Evidence
        let pages = [E(text: "太陽系八大行星依序為 Mercury、Venus、Earth、Mars、Jupiter、Saturn、Uranus、Neptune。", host: "en.site"),
                     E(text: "太陽系的八大行星由內到外是水星、金星、地球、火星、木星、土星、天王星、海王星。", host: "zh.site"),
                     E(text: "八大行星包括水星、金星、地球、火星、木星、土星、天王星和海王星。", host: "b.tw")]
        let a = Think.plainList(question: "八大行星有哪些", pages: pages, subject: "八大行星", noun: "") ?? ""
        XCTAssertTrue(a.contains("水星") && a.contains("海王星"), a)
        XCTAssertFalse(a.contains("Mercury"), a)
    }
}
