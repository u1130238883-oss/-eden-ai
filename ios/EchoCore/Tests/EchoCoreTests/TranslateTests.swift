import XCTest
@testable import EchoCore

/// 翻譯：聽懂要翻什麼、翻成哪種語言；單字用手機裡的字典
final class TranslateTests: XCTestCase {
    static let lexicon: Lexicon? = try? Lexicon(text: String(contentsOf: EchoCoreTests.resources.appendingPathComponent("lexicon.tsv"), encoding: .utf8))

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

    func testDictionaryTranslatesWordsBetweenFiveLanguages() throws {
        let lex = try XCTUnwrap(Self.lexicon)
        XCTAssertGreaterThan(lex.count, 100_000)
        func t(_ s: String, _ to: Translate.Code) -> Translate.Result? {
            Translate.dictionary(.init(text: s, source: nil, target: to), lexicon: lex)
        }
        XCTAssertEqual(t("蘋果", .es)?.text, "manzana")
        XCTAssertEqual(t("蘋果", .it)?.text, "mela")
        XCTAssertEqual(t("蘋果", .en)?.text, "apple")
        XCTAssertEqual(t("蘋果", .en)?.pron, "píngguǒ")
        XCTAssertEqual(t("謝謝", .es)?.text, "gracias")
        XCTAssertEqual(t("謝謝", .it)?.text, "grazie")
        XCTAssertEqual(t("謝謝", .ar)?.text, "شكرا")
        XCTAssertEqual(t("謝謝", .ar)?.pron, "šukran")
        XCTAssertEqual(t("早安", .es)?.text.hasPrefix("buen"), true)
        XCTAssertEqual(t("apple", .zh)?.text, "蘋果")
        XCTAssertEqual(t("computer", .zh)?.text, "電腦")
        XCTAssertEqual(t("book", .ar)?.text, "كتاب")
        XCTAssertEqual(t("manzana", .zh)?.text, "蘋果")
        XCTAssertEqual(t("gracias", .en)?.text.contains("thank"), true)
        // 動詞變化形：comiendo → comer → eat → 吃
        XCTAssertEqual(t("comiendo", .en)?.text, "eat")
        XCTAssertEqual(t("mangiare", .zh)?.text, "吃")
        XCTAssertNotNil(t("ciao", .zh))
        // 整句不查字典（交給整句翻譯）
        XCTAssertNil(t("今天天氣很好，我們去公園。", .en))
        let r = Translate.reply(.init(text: "謝謝", source: nil, target: .ar), try XCTUnwrap(t("謝謝", .ar)))
        XCTAssertTrue(r.contains("繁體中文 → 阿拉伯文") && r.contains("شكرا"), r)
    }
}
