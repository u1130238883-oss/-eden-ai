import XCTest
@testable import EchoCore

/// 實測時答錯過的題目：用當時讀到的真實句子當題目，確定不會再犯（不用連網）
final class AnswerQualityTests: XCTestCase {
    /// 日本的首都 → 答成「認為」（「一般也認為東京是日本的首都」）
    func testCapitalVoteSkipsVerbs() {
        let jp = ["一般也認為東京是日本的首都。", "日本的法律沒有明定首都，但通常認為東京是日本的首都。", "東京是日本的首都", "東京都是日本的首都"]
        let v = Understanding.capitalVotes(jp, subject: "日本")
        XCTAssertEqual(v.max { ($0.value, $0.key.count) < ($1.value, $1.key.count) }?.key, "東京", "\(v)")
        XCTAssertNil(v["認為"])
        XCTAssertNil(v["京都"], "東京都不能變成京都")
        let fr = Understanding.capitalVotes(["法國首都巴黎舉辦了奧運。", "巴黎是法國的首都"], subject: "法國")
        XCTAssertEqual(fr.max { ($0.value, $0.key.count) < ($1.value, $1.key.count) }?.key, "巴黎", "\(fr)")
        XCTAssertNil(Understanding.capitalVotes(["日本的首都是哪裡？"], subject: "日本")["哪裡"])
    }

    /// 太陽到地球 → 答成「5000萬km」（原文「1億5000萬km」）
    func testCompoundChineseNumbers() {
        let n = Understanding.numbers("離 太陽～1億5000萬km", units: ["km", "公里"])
        XCTAssertEqual(n.first?.value, 1.5e8)
        XCTAssertEqual(n.first?.shown, "1億5000萬km")
        XCTAssertEqual(Understanding.numbers("約1.5億公里", units: ["公里"]).first?.value, 1.5e8)
        XCTAssertEqual(Understanding.numbers("平均距離38萬公里", units: ["公里"]).first?.value, 3.8e5)
        XCTAssertEqual(Understanding.numbers("1億4960萬公里", units: ["公里"]).first?.value, 1.496e8)
    }

    /// 世界上最高的山 → 答成「唐古拉站」（世界上海拔最高的火車站）
    func testSuperlativeMustBeTheSameKindOfThing() {
        let q = "世界上最高的山是哪座"
        XCTAssertFalse(Think.superlativeFits(question: q, passage: "唐古拉站是世界上海拔最高的火車站。"))
        XCTAssertTrue(Think.superlativeFits(question: q, passage: "珠穆朗瑪峰是世界上最高的山峰，海拔8848公尺。"))
        XCTAssertTrue(Think.superlativeFits(question: q, passage: "聖母峰位於中國與尼泊爾邊界。"))
        XCTAssertTrue(Think.superlativeFits(question: "台北101有多高", passage: "唐古拉站是世界上海拔最高的火車站。"))
    }

    /// 網頁標題、動詞、單一個字不是答案（「維基百科」「認為」「圈」）
    func testJunkSpans() {
        for j in ["維基百科", "認為", "圈", "列表", "自由的百科全書"] { XCTAssertTrue(Think.junk(j), j) }
        for ok in ["東京", "508公尺", "唐朝", "5"] { XCTAssertFalse(Think.junk(ok), ok) }
    }

    /// 說明題（在講什麼、怎麼辦、為什麼）要整句、而且真的在講問的那件事
    func testExplanationQuestionsStayOnTopic() {
        XCTAssertTrue(Think.wantsSentences("三島由紀夫的書都講了什麼"))
        XCTAssertTrue(Think.wantsSentences("感冒了怎麼辦"))
        XCTAssertFalse(Think.wantsSentences("台北101有多高"))
        XCTAssertEqual(Think.chunks("老闆不給我加薪怎麼辦"), ["老闆不給", "加薪"])
        XCTAssertEqual(Think.chunks("感冒為什麼會發燒"), ["感冒", "發燒"])
        XCTAssertEqual(Think.chunks("三島由紀夫的書都講了什麼"), ["三島由紀夫"])
        // 「老闆不給我加薪」不能拿「老闆欠薪」的句子回答
        let law = "老闆欠薪不給怎麼辦？若老闆不給，可向勞工局申訴。"
        XCTAssertFalse(Think.onTopic(question: "老闆不給我加薪怎麼辦", sentence: "若老闆不給，可向勞工局申訴。", passage: law))
        let raise = "老闆不肯加薪時，可以先整理自己這一年的成果，再約時間談。"
        XCTAssertTrue(Think.onTopic(question: "老闆不給我加薪怎麼辦", sentence: raise, passage: raise))
        // 「怎麼煮綠豆湯」不能拿「扁豆湯」的句子回答
        let dal = "在印度，綠豆仁作為一種Dal可燉煮為咖喱和扁豆湯。"
        XCTAssertFalse(Think.onTopic(question: "怎麼煮綠豆湯", sentence: dal, passage: dal))
        XCTAssertTrue(Think.cues("金閣寺在講什麼").contains("講述"))
        XCTAssertTrue(Think.cues("天空為什麼是藍色的").contains("因為"))
    }

    /// 原因：表格的一列不是說明；有講到主題（感冒）的句子優先；引整句、不切成看不懂的幾個字
    func testReasonPicksAnExplainingSentence() {
        let ev: [Understanding.Evidence] = [
            .init(text: "治療 ｜ 治療導致發燒的疾病", host: "w"),
            .init(text: "發燒的原因有很多種。", host: "x"),
            .init(text: "感冒會發燒，是因為身體為了對抗病毒而提高體溫。", host: "y"),
        ]
        let r = Understanding.extractReason(ev, pred: "發燒", subject: "感冒")
        XCTAssertEqual(r.first?.host, "y")
        XCTAssertFalse(r.contains { $0.host == "w" })
        XCTAssertEqual(Cite.whole("天空呈現藍色是由於瑞利散射[3]。", host: "zh.wikipedia.org"), "「天空呈現藍色是由於瑞利散射。」（zh.wikipedia.org）")
        XCTAssertTrue(Cite.whole(String(repeating: "很長的句子", count: 30), host: "a").contains("…"))
    }

    /// 怎麼煮白飯 → 拿了食譜列表上別道菜的食材（「去骨雞腿肉切塊、高麗菜切塊」）
    func testStepsIgnoreIngredientListings() {
        let listing = """
        白飯食譜
        簡單做「手切滷肉飯」白飯煮多
        去骨雞腿肉切塊、高麗菜切塊
        乾香菇泡水切粗絲、蔥花、即食
        蒜頭切末、鴻喜菇、鹽巴、櫛瓜
        高麗菜切塊、蔥切末、煮好的白飯
        """
        XCTAssertNil(Understanding.extractSteps([.init(text: listing, host: "icook.tw")], target: "白飯"))
        XCTAssertEqual(Cite.step("綠豆洗淨，泡水 2 小時。"), "綠豆洗淨，泡水 2 小時。")
        let long = "把洗好的米放進內鍋，加入米量一點二倍的水，蓋上鍋蓋按下煮飯鍵，跳起來之後再燜十分鐘，用飯匙翻鬆"
        let st = Cite.step(long)
        XCTAssertTrue(st.hasSuffix("…") && st.count <= 41, st)
    }

    /// 反過來想：不同網頁抄同一句話只列一次
    func testOtherSideDeduplicates() {
        let dup: [(text: String, host: String)] = [("但其實天空是無色的，我們看到的藍色來自散射。", "a"), ("但其實天空是無色的。", "b")]
        XCTAssertEqual(Mind.otherSide(dup, topic: ["天空"], exclude: []).count, 1)
    }

    /// 「我是說這些歐洲國家是哪些國家」→ 查成「列表 歐洲國家…」（上一次查詢加的「列表」被當成主題）
    func testFollowUpIgnoresSearchHelperWords() {
        let q = EchoEngine.resolveFollowUp("我是說這些歐洲國家是哪些國家？", query: "我是說這些歐洲國家是哪些國家",
                                           previous: "歐洲國家 哪些國家 列表", gap: 2)
        XCTAssertTrue(q.hasPrefix("歐洲國家"), q)
    }
}
