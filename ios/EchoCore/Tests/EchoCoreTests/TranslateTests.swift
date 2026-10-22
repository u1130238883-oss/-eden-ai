import XCTest
@testable import EchoCore

/// 翻譯：聽懂要翻什麼、翻成哪種語言
final class TranslateTests: XCTestCase {
    func testUnderstandsTranslationRequests() {
        func p(_ s: String) -> Translate.Request? { Translate.parse(s) }
        XCTAssertEqual(p("蘋果用西班牙文怎麼說"), .init(text: "蘋果", source: nil, target: .es))
        XCTAssertEqual(p("謝謝的義大利文是什麼？"), .init(text: "謝謝", source: nil, target: .it))
        XCTAssertEqual(p("把「我愛你」翻譯成阿拉伯文"), .init(text: "我愛你", source: nil, target: .ar))
        XCTAssertEqual(p("幫我翻成英文：今天天氣很好"), .init(text: "今天天氣很好", source: nil, target: .en))
        XCTAssertEqual(p("早安英文"), .init(text: "早安", source: nil, target: .en))
        XCTAssertEqual(p("how do you say thank you in Spanish?"), .init(text: "thank you", source: nil, target: .es))
        XCTAssertEqual(p("translate good morning to italian"), .init(text: "good morning", source: nil, target: .it))
        XCTAssertEqual(p("¿Cómo se dice gracias en inglés?"), .init(text: "gracias", source: nil, target: .en))
        XCTAssertEqual(p("gracias是什麼意思")?.target, .zh)
        XCTAssertEqual(p("gracias是什麼意思")?.source, .es)
        XCTAssertEqual(p("翻譯：Where is the bathroom?")?.target, .zh)
        XCTAssertEqual(p("翻譯 我想喝咖啡")?.target, .en)
        XCTAssertEqual(p("這句話翻成日文：你好嗎"), .init(text: "你好嗎", source: nil, target: .ja))
        XCTAssertEqual(p("用英文怎麼說謝謝"), .init(text: "謝謝", source: nil, target: .en))
        XCTAssertEqual(p("مرحبا 是什麼意思")?.source, .ar)
        // 不是要翻譯
        for s in ["你會說英文嗎", "我想學英文", "英文怎麼學比較快", "什麼是中文", "量子力學是什麼意思", "iPhone是什麼", "今天天氣如何",
                  "中文是什麼", "英文", "學英文的方法"] {
            XCTAssertNil(p(s), s)
        }
    }

    func testDetectsLanguage() {
        XCTAssertEqual(Translate.detect("¿Dónde está el baño?"), .es)
        XCTAssertEqual(Translate.detect("Dove è il bagno? Grazie"), .it)
        XCTAssertEqual(Translate.detect("Where is the bathroom?"), .en)
        XCTAssertEqual(Translate.detect("شكرا جزيلا"), .ar)
        XCTAssertEqual(Translate.detect("謝謝你"), .zh)
        XCTAssertEqual(Translate.detect("ありがとう"), .ja)
    }

    func testReplyFormat() {
        let r = Translate.reply(.init(text: "謝謝", source: nil, target: .ar), .init(text: "شكرا", pron: "šukran", source: .zh, via: "AI"))
        XCTAssertEqual(r, "شكرا　〔šukran〕")
    }

    func testGoogleResponse() throws {
        let json = #"[[["浴室在哪裡？","¿Dónde está el baño?",null,null,10],[null,null,"Yùshì zài nǎlǐ?","¿Dónde está el baño?"]],null,"es",null,null,null,1]"#
        let j = try JSONSerialization.jsonObject(with: Data(json.utf8))
        let r = try XCTUnwrap(Translate.parseGoogle(j, target: .zh))
        XCTAssertEqual(r.text, "浴室在哪裡？")
        XCTAssertEqual(r.pron, "Yùshì zài nǎlǐ?")
        XCTAssertEqual(r.source, .es)
        // 西文譯文不需要讀音
        let it = #"[[["Voglio bere un caffè","我想喝咖啡",null,null,10],[null,null,null,"Wǒ xiǎng hē kāfēi"]],null,"zh-CN"]"#
        let r2 = try XCTUnwrap(Translate.parseGoogle(try JSONSerialization.jsonObject(with: Data(it.utf8)), target: .it))
        XCTAssertEqual(r2.text, "Voglio bere un caffè")
        XCTAssertEqual(r2.pron, "")
        XCTAssertEqual(Translate.parseGoogleSimple(try JSONSerialization.jsonObject(with: Data(#"[["Hello","it"]]"#.utf8)))?.text, "Hello")
        XCTAssertEqual(Translate.parseGoogleSimple(try JSONSerialization.jsonObject(with: Data(#"["Ciao"]"#.utf8)))?.text, "Ciao")
        XCTAssertNil(Translate.parseGoogle(try JSONSerialization.jsonObject(with: Data("[]".utf8)), target: .en))
    }

    func testFollowUpLanguage() {
        let last = Translate.Request(text: "謝謝", source: nil, target: .en)
        XCTAssertEqual(Translate.followUp("那西班牙文呢？", last: last), .init(text: "謝謝", source: nil, target: .es))
        XCTAssertEqual(Translate.followUp("義大利文呢", last: last)?.target, .it)
        XCTAssertEqual(Translate.followUp("what about Italian?", last: last)?.target, .it)
        XCTAssertEqual(Translate.followUp("¿y en italiano?", last: last)?.target, .it)
        XCTAssertNil(Translate.followUp("中文呢", last: last))          // 原文就是中文
        XCTAssertNil(Translate.followUp("今天天氣如何", last: last))
        XCTAssertNil(Translate.followUp("英文呢", last: nil))
        XCTAssertEqual(Translate.Code.it.voice, "it-IT")
    }

    /// 真實的問法（教它聽懂「什麼是要翻的內容、翻成什麼」）：每一句都要拆對
    func testManyPhrasings() {
        let cases: [(String, String, Translate.Code)] = [
            ("你有沒有吃飯用英語說", "你有沒有吃飯", .en),
            ("你有沒有吃飯用英文怎麼講", "你有沒有吃飯", .en),
            ("用英文跟他說謝謝", "謝謝", .en),
            ("教我用西班牙文說我愛你", "我愛你", .es),
            ("我想用義大利文說我很累", "我很累", .it),
            ("請用義大利文說早安", "早安", .it),
            ("這句英文怎麼說：你吃飯了嗎", "你吃飯了嗎", .en),
            ("學校用英文怎麼說", "學校", .en),
            ("我不懂用英文怎麼說", "我不懂", .en),
            ("你今天過得好嗎 西班牙文", "你今天過得好嗎", .es),
            ("好久不見用義大利語講", "好久不見", .it),
            ("「我想喝咖啡」英語怎麼說？", "我想喝咖啡", .en),
            ("幫我把明天見翻成西班牙語", "明天見", .es),
            ("麻煩用英文寫：我會晚一點到", "我會晚一點到", .en),
            ("跟我說生日快樂的義大利文", "生日快樂", .it),
            ("hasta luego 用中文怎麼說", "hasta luego", .zh),
            ("buongiorno翻成中文", "buongiorno", .zh),
            ("I miss you 中文是什麼", "I miss you", .zh),
        ]
        var bad: [String] = []
        for (q, text, target) in cases {
            let r = Translate.parse(q)
            if r?.text != text || r?.target != target { bad.append("\(q) → \(r.map { "\($0.text)/\($0.target.rawValue)" } ?? "nil")") }
        }
        // 不是要翻譯
        for q in ["你會說英文嗎", "我想學西班牙文", "英文好難", "義大利文怎麼學比較快", "你的英文很好", "西班牙文老師說我很棒",
                  "我的英文程度不好", "你會講幾種語言", "英文課好無聊", "今天運勢如何", "我愛你", "英文"] {
            if let r = Translate.parse(q) { bad.append("不該翻：\(q) → \(r.text)") }
        }
        XCTAssertTrue(bad.isEmpty, bad.joined(separator: "\n"))
    }

    func testGoogleDictionaryAlternatives() throws {
        let json = #"[[["apple","蘋果",null,null,1]],[["noun",["apple","Apple"],[]],["noun2",["pome"],[]]],"zh-TW"]"#
        let r = try XCTUnwrap(Translate.parseGoogle(try JSONSerialization.jsonObject(with: Data(json.utf8)), target: .en))
        XCTAssertEqual(r.text, "apple")
        XCTAssertEqual(r.alternatives, ["pome"])
        XCTAssertEqual(r.source, .zh)
        let res = Translate.Result(text: "Have you eaten?", alternatives: ["Did you eat?"], source: .zh, via: "test")
        XCTAssertEqual(Translate.reply(.init(text: "你吃飯了嗎", source: .zh, target: .en), res), "Have you eaten?\n也可以說：Did you eat?")
        XCTAssertEqual(Translate.parse("中翻英：我想喝咖啡"), .init(text: "我想喝咖啡", source: nil, target: .en))
        XCTAssertEqual(Translate.parse("謝謝 翻西"), .init(text: "謝謝", source: nil, target: .es))
    }

    /// 常用口語用母語人士真的會說的
    func testNativePhrases() {
        func t(_ text: String, _ to: Translate.Code) -> String? { Native.lookup(.init(text: text, source: nil, target: to))?.text }
        XCTAssertEqual(t("加油", .en), "You've got this!")
        XCTAssertEqual(t("辛苦了！", .it), "Grazie per tutto il lavoro.")
        XCTAssertEqual(t("吃飯了嗎？", .es), "¿Ya comiste?")
        XCTAssertEqual(t("妳好漂亮", .it), "Sei bellissima.")
        XCTAssertEqual(t("In bocca al lupo!", .zh), "加油")
        XCTAssertEqual(t("no worries", .zh), "沒關係")
        // 外文單字一字多義，不查道地說法表
        XCTAssertNil(t("ojo", .en))
        XCTAssertNil(t("tranquilo", .en))
        XCTAssertEqual(t("que rico", .zh), "好吃")
        XCTAssertNil(t("今天天氣很好", .en))
        XCTAssertEqual(t("我好累啊", .en), "I'm exhausted.")
        // 吃飯是一般的「吃」，不是晚餐（cena）
        XCTAssertEqual(t("我想去吃飯", .it), "Voglio andare a mangiare.")
        XCTAssertEqual(t("吃晚飯", .it), "cenare")
        XCTAssertEqual(Translate.distinct(["I'm so tired", "Hallo!", "hallo"], from: "I'm so tired."), ["Hallo!"])
        XCTAssertTrue(Translate.isSingleWord("蘋果") && !Translate.isSingleWord("吃飯了嗎") && !Translate.isSingleWord("good morning"))
        XCTAssertNil(t("加油", .zh))
        // 每一行四種語言都要有
        for e in Native.entries { XCTAssertTrue(!e.zh.isEmpty && !e.en.isEmpty && !e.es.isEmpty && !e.it.isEmpty, e.zh.first ?? "") }
    }
}
