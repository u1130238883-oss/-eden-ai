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

    /// 玉山有多高 → 答成「3869公尺」（那是玉山東峰）
    func testSubPeakHeightIsNotTheAnswer() {
        let ys = [Understanding.Evidence(text: "著名的台灣百岳高峰中，玉山東峰（3,869公尺）、玉山北峰（3,858公尺）都在附近。", host: "w"),
                  Understanding.Evidence(text: "玉山主峰海拔3,952公尺，是台灣最高峰。", host: "w")]
        XCTAssertEqual(Understanding.voteNumber(ys, units: ["公尺", "米"], subject: "玉山")?.shown, "3,952公尺")
    }

    /// 歐洲有多少個國家 → 答成「37個國家」（「歐洲有37個國家立法禁止…」是在數做某件事的國家）
    func testCountOfCountriesDoingSomethingIsNotTheTotal() {
        let ev = [Understanding.Evidence(text: "歐洲有37個國家立法禁止在公共場所吸菸。", host: "w"),
                  Understanding.Evidence(text: "歐洲共有46個國家。", host: "x")]
        XCTAssertEqual(Understanding.voteNumber(ev, units: ["個國家"], subject: "歐洲")?.shown, "46個國家")
        XCTAssertTrue(Think.looksLikeNoise("（中文） 梁慶標：三島由紀夫《假面自白》主要內容簡介及賞析。"))
    }

    /// 世界上最高的山 → 答成「唐古拉站」（世界上海拔最高的火車站）
    func testSuperlativeMustBeTheSameKindOfThing() {
        let q = "世界上最高的山是哪座"
        XCTAssertFalse(Think.superlativeFits(question: q, passage: "唐古拉站是世界上海拔最高的火車站。"))
        XCTAssertTrue(Think.superlativeFits(question: q, passage: "珠穆朗瑪峰是世界上最高的山峰，海拔8848公尺。"))
        XCTAssertTrue(Think.superlativeFits(question: q, passage: "聖母峰為世界第一高峰，位於中國與尼泊爾邊界。"))
        // 沒講到「最高」的段落不是在回答哪一座最高（之前答成「高山」）
        XCTAssertFalse(Think.superlativeFits(question: q, passage: "高山的通用定義是突起地形超過300公尺的山峰。"))
        XCTAssertTrue(Think.echoes("高山", question: q))
        XCTAssertFalse(Think.echoes("珠穆朗瑪峰", question: q))
        XCTAssertFalse(Think.echoes("101", question: "台北101有幾層"))
        XCTAssertTrue(Think.superlativeFits(question: "台北101有多高", passage: "唐古拉站是世界上海拔最高的火車站。"))
    }

    /// 網頁標題、導覽、食譜列表、小標題不是內容（實測時被當成答案引用過的句子）
    func testNoiseSentences() {
        for n in ["三島由紀夫 - 維基百科，自由的百科全書跳至內容維基百科，自由的百科全書三島由紀夫1955年",
                  "19 讚20 分免控火汽化瓦斯爐煮白飯Vodga食材：米、水18 讚10 分鮭魚高麗菜拌飯",
                  "主條目：豆芽綠豆湯中式綠豆糕綠豆餡印度油餅",
                  "5.3. 《金閣寺》的結局是在讚美毀滅嗎？",
                  "三島由紀夫《金閣寺》解析：故事、結局與美／毀滅主題..."] {
            XCTAssertTrue(Think.looksLikeNoise(n), n)
        }
        for ok in ["由於空氣中灰塵對日光的瑞利散射，晴天的天空是藍色的。", "月亮會發光是因為它反射了太陽光。",
                   "《金閣寺》以1950年的金閣寺縱火事件為題材，描寫一名年輕僧人對金閣之美的執迷。"] {
            XCTAssertFalse(Think.looksLikeNoise(ok), ok)
        }
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
        // 三島由紀夫的書都講了什麼 → 答成「紀念日本作家三島由紀夫」（三島由紀夫獎）
        let prize = "三島由紀夫獎簡稱為三島獎，是一個日本文學獎，由新潮社於1988年開辦，紀念日本作家三島由紀夫。"
        XCTAssertFalse(Think.onTopic(question: "三島由紀夫的書都講了什麼", sentence: prize, passage: prize))
        let works = "三島由紀夫的小說常探討美與死亡。《金閣寺》描寫一名年輕僧人對金閣之美的執迷。"
        XCTAssertTrue(Think.onTopic(question: "三島由紀夫的書都講了什麼", sentence: "《金閣寺》描寫一名年輕僧人對金閣之美的執迷。", passage: works))
        XCTAssertTrue(Think.cues("天空為什麼是藍色的").contains("因為"))
        XCTAssertTrue(Think.cues("甲減是什麼").contains("簡稱"))
        XCTAssertEqual(Think.chunks("甲減是什麼"), ["甲減"])
    }

    /// 「三島由紀夫的書都講了什麼」：先找代表作，再說每一部在講什麼（不是拿「三島由紀夫獎」那句）
    func testWorksQuestionIsSplitIntoSteps() {
        let fr = Understanding.frame("三島由紀夫的書都講了什麼")
        XCTAssertEqual(fr.subject, "三島由紀夫")
        XCTAssertTrue(fr.searches.contains("三島由紀夫 作品"), "\(fr.searches)")
        XCTAssertEqual(Understanding.frame("金閣寺在講什麼").subject, "金閣寺")
        XCTAssertEqual(Understanding.frame("感冒了怎麼辦").subject, "感冒")
        XCTAssertEqual(Understanding.frame("老闆不給我加薪怎麼辦").subject, "老闆不給我加薪")
        let page = """
        三島由紀夫是日本戰後的重要作家，作品常探討美、死亡與肉體。
        三島由紀夫的代表作有《假面的告白》、《金閣寺》、《潮騷》。
        《金閣寺》以1950年的金閣寺縱火事件為題材，描寫一名年輕僧人對金閣之美的執迷。
        《潮騷》講述漁村少年新治與少女初江的純愛故事。
        三島由紀夫獎是紀念三島由紀夫的文學獎，曾頒給《某某》。
        """
        let d = Think.worksDigest(question: "三島由紀夫的書都講了什麼", pages: [.init(text: page, host: "zh.wikipedia.org")]) ?? ""
        XCTAssertTrue(d.contains("《金閣寺》：") && d.contains("年輕僧人"), d)
        XCTAssertTrue(d.contains("《潮騷》："), d)
        XCTAssertTrue(d.contains("美、死亡"), d)
        XCTAssertFalse(d.contains("文學獎"), d)
        XCTAssertNil(Think.worksDigest(question: "台北101有多高", pages: [.init(text: page, host: "w")]))
    }

    /// 「金閣寺在講什麼」：講小說的內容，不是寺廟的介紹、不是改編的電影
    func testAboutTheWorkNotTheTemple() {
        let kp = "金閣寺是位於京都的寺廟，正式名稱是鹿苑寺。\n《金閣寺》是三島由紀夫的小說，描寫一名口吃的年輕僧人溝口對金閣之美的執迷，最後放火燒了金閣。\n電影《炎上》改編自《金閣寺》，由市川崑導演，講述同樣的故事。"
        let a = Think.aboutWork(question: "金閣寺在講什麼", pages: [.init(text: kp, host: "zh.wikipedia.org")]) ?? ""
        XCTAssertTrue(a.contains("溝口"), a)
        XCTAssertFalse(a.contains("炎上"), a)
        XCTAssertNil(Think.aboutWork(question: "台北101有多高", pages: [.init(text: kp, host: "w")]))
        // 作品清單：書名裡有作者名字的（傳記電影）不算他的作品
        let film = "三島由紀夫的代表作有《金閣寺》、《潮騷》。\n電影《三島由紀夫：人間四幕》講述三島由紀夫的一生，並穿插《金閣寺》的故事。\n《潮騷》講述漁村少年與少女的純愛故事。"
        let d = Think.worksDigest(question: "三島由紀夫的書都講了什麼", pages: [.init(text: film, host: "zh.wikipedia.org")]) ?? ""
        XCTAssertFalse(d.contains("人間四幕"), d)
        XCTAssertTrue(d.contains("《潮騷》："), d)
        // 做法：問答、文章預告不是步驟
        let steps = "白飯做法\n1. 米洗淨後泡水30分鐘。\n2. 加入1.1倍的水，大火煮滾。\n3. 轉小火煮15分鐘，關火燜10分鐘。\nA: 可能水太多或沒燜飯，調整水量並確保燜10分鐘。\n泡紅豆的水到底要不要倒掉？本文深入探討紅豆浸泡水的利弊…"
        XCTAssertEqual(Understanding.extractSteps([.init(text: steps, host: "r.tw")], target: "白飯")?.steps.count, 3)
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

    /// 歐洲國家名單的第一項變成「聯合國地理分區將歐洲分為」
    func testListItemsAreNamesNotClauses() {
        XCTAssertNil(Understanding.item("聯合國地理分區將歐洲分為"))
        XCTAssertEqual(Understanding.item("阿爾巴尼亞"), "阿爾巴尼亞")
    }

    /// 北歐有哪些國家 → 列出 80 個（政府首腦、議會議長、各省…）：手機版維基好幾張表疊在一起
    func testLongMixedColumnKeepsConfirmedItems() {
        var lines = ["北歐國家", "北歐理事會的成員國包括丹麥、芬蘭、冰島、挪威和瑞典。"]
        let rows = [("芬蘭", "赫爾辛基"), ("政府首腦", "總理"), ("冰島", "雷克雅維克"), ("議會議長", "議長"), ("挪威", "奧斯陸"),
                    ("獨立黨領袖", "主席"), ("瑞典", "斯德哥爾摩"), ("進步黨領袖", "主席"), ("丹麥", "哥本哈根"), ("社會黨領袖", "主席"),
                    ("格陵蘭", "努克"), ("中央黨領袖", "主席"), ("法羅群島", "托爾斯港"), ("綠黨領袖", "主席")]
        for (a, b) in rows { lines += [a, b, "550萬"] }
        let r = Understanding.extractList([.init(text: lines.joined(separator: "\n"), host: "zh.wikipedia.org")], noun: "國家", subject: "北歐")
        XCTAssertEqual(Set(r.items), ["丹麥", "芬蘭", "冰島", "挪威", "瑞典"], "\(r.items)")
    }

    /// 北歐有哪些國家：「北歐五國，指…」直接列名單；或從歐洲國家大表裡挑「地區」那一格是北歐的列
    func testNordicFromIntroOrRegionColumn() {
        let intro = "北歐五國，指丹麥、瑞典、挪威、芬蘭和冰島。"
        XCTAssertEqual(Set(Understanding.extractList([.init(text: intro, host: "w")], noun: "國家", subject: "北歐").items),
                       ["丹麥", "瑞典", "挪威", "芬蘭", "冰島"])
        var table = "歐洲國家列表\n以下是位於歐洲的國家。\n"
        for (c, cap, r) in [("丹麥", "哥本哈根", "北歐"), ("法國", "巴黎", "西歐"), ("芬蘭", "赫爾辛基", "北歐"), ("德國", "柏林", "西歐"),
                            ("挪威", "奧斯陸", "北歐"), ("義大利", "羅馬", "南歐"), ("瑞典", "斯德哥爾摩", "北歐"), ("冰島", "雷克雅維克", "北歐")] {
            table += "\(c)\n\(cap)\n\(r)\n5,800,000\n"
        }
        let r = Understanding.extractList([.init(text: table, host: "zh.wikipedia.org")], noun: "國家", subject: "北歐")
        XCTAssertEqual(r.items, ["丹麥", "芬蘭", "挪威", "瑞典", "冰島"], "\(r.items)")
        XCTAssertEqual(r.hosts, ["zh.wikipedia.org"])
    }

    /// 「我是說這些歐洲國家是哪些國家」→ 查成「列表 歐洲國家…」（上一次查詢加的「列表」被當成主題）
    func testFollowUpIgnoresSearchHelperWords() {
        let q = EchoEngine.resolveFollowUp("我是說這些歐洲國家是哪些國家？", query: "我是說這些歐洲國家是哪些國家",
                                           previous: "歐洲國家 哪些國家 列表", gap: 2)
        XCTAssertTrue(q.hasPrefix("歐洲國家"), q)
    }
}

/// 比較題：分開找兩邊的優缺點再並排（之前答成「增強功能、錯誤修正和安全性更新」）
final class CompareTests: XCTestCase {
    func testCompareDigest() {
        let page = """
        iPhone 的優點是系統流暢、更新快，而且隱私保護做得比較好。
        安卓手機的優勢是選擇多、價格範圍廣，也比較能自己客製。
        iOS 17 加入待機模式和其他錯誤修正。
        """
        let d = Think.compareDigest("iPhone", "安卓", pages: [.init(text: page, host: "tech.tw")]) ?? ""
        XCTAssertTrue(d.contains("• iPhone：") && d.contains("流暢"), d)
        XCTAssertTrue(d.contains("• 安卓：") && d.contains("選擇多"), d)
        XCTAssertFalse(d.contains("待機模式"), d)
        XCTAssertNil(Think.compareDigest("iPhone", "安卓", pages: [.init(text: "iOS 17 加入待機模式。", host: "w")]))
        // 資料寫「Android」也算在講安卓
        let wiki = "Android 是開放原始碼的系統，優點是可以自由客製、選擇多。\niPhone 的優勢在於系統穩定、隱私保護好。"
        let w = Think.compareDigest("iPhone", "安卓", pages: [.init(text: wiki, host: "zh.wikipedia.org")]) ?? ""
        XCTAssertTrue(w.contains("• 安卓：") && w.contains("客製"), w)
    }

    /// 歐洲有多少個國家 → 答成「8個國家」（「瑞士8個國家共同經營」是在數別的東西）
    func testCountRightAfterAnotherNameIsNotTheTotal() {
        let ev = [Understanding.Evidence(text: "由法國、德國、瑞士8個國家共同經營的歐洲核子研究組織。", host: "w"),
                  Understanding.Evidence(text: "歐洲目前共有44個國家。", host: "x")]
        XCTAssertEqual(Understanding.voteNumber(ev, units: ["個國家"], subject: "歐洲")?.shown, "44個國家")
        XCTAssertEqual(Understanding.voteNumber([.init(text: "加拿大由10個省和3個地區組成。", host: "w")], units: ["個省"], subject: "加拿大")?.shown, "10個省")
    }

    /// 誰畫了蒙娜麗莎 → 答成「文西」；世界最高的山 → 「珠穆朗瑪峰頂峰」
    func testBrainSpanIsWidenedToTheWholeName() {
        let texts = ["片名是指達文西的油畫《蒙娜麗莎》。", "《蒙娜麗莎》是達文西的作品。"]
        XCTAssertEqual(Think.wholeName("文西", in: texts), "達文西")
        XCTAssertEqual(Think.wholeName("達文西", in: texts), "達文西")
        // 「首都東京」「位於東京」：前面的字不一樣，不能亂加
        XCTAssertEqual(Think.wholeName("東京", in: ["日本首都東京", "位於東京的公司"]), "東京")
        XCTAssertEqual(Think.wholeName("珠穆朗瑪峰頂峰", in: []), "珠穆朗瑪峰")
    }

    /// 北歐有哪些國家 → 只拿到「芬蘭、冰島、丹麥、法羅群島」（表格不完整）；句子裡明說「這五個國家」的名單最可信
    func testCountedEnumerationIsTheList() {
        let page = """
        首都/首府 ｜ 語言
        芬蘭 ｜ 赫爾辛基
        冰島 ｜ 雷克雅維克
        通常斯堪地納維亞指的是丹麥、挪威與瑞典，而北歐五國則清楚說明為丹麥、芬蘭、冰島、挪威和瑞典這五個國家，再加上各自的海外屬地。
        """
        let r = Understanding.extractList([.init(text: page, host: "zh.wikipedia.org")], noun: "國家", subject: "北歐")
        XCTAssertEqual(r.items, ["丹麥", "芬蘭", "冰島", "挪威", "瑞典"])
        XCTAssertEqual(Understanding.smallNumber("十二"), 12)
        XCTAssertEqual(Understanding.cutVerbTail("芬蘭同意成立"), "芬蘭")
        XCTAssertEqual(Understanding.cutVerbTail("冰島"), "冰島")
        XCTAssertEqual(Understanding.cutVerbTail("東京都"), "東京都")
        XCTAssertEqual(Understanding.cutVerbTail("阿拉伯聯合大公國"), "阿拉伯聯合大公國")
        XCTAssertEqual(Understanding.smallNumber("五"), 5)
        // 數目對不上就不算
        XCTAssertNil(Understanding.countedList([.init(text: "北歐包括丹麥、芬蘭和瑞典這五個國家。", host: "w")], noun: "國家", subject: "北歐"))
    }
}
