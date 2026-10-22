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
        XCTAssertTrue(r.contains("繁體中文 → 阿拉伯文") && r.contains("شكرا") && r.contains("šukran"), r)
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
}
