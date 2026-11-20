import XCTest
@testable import EchoCore

/// Round 27（2026-11-20）：意思比對模型第二輪訓練時，順便修掉的兩個引擎問題。
final class Round27Tests: XCTestCase {
    /// 「三月底出生是什麼星座」：用日期算，不讓模型猜（以前會被當成「三月是什麼星座」或上網查）
    func testSignForDate() {
        XCTAssertEqual(EchoEngine.sunSign(month: 3, day: 28), "牡羊座")
        XCTAssertEqual(EchoEngine.sunSign(month: 1, day: 19), "摩羯座")
        XCTAssertEqual(EchoEngine.sunSign(month: 1, day: 20), "水瓶座")
        XCTAssertEqual(EchoEngine.sunSign(month: 12, day: 25), "摩羯座")
        XCTAssertEqual(EchoEngine.signForDateQuestion("12月25日生的是什麼星座"), "12 月 25 日出生是摩羯座。")
        XCTAssertEqual(EchoEngine.signForDateQuestion("10月5號是什麼星座"), "10 月 5 日出生是天秤座。")
        XCTAssertTrue(EchoEngine.signForDateQuestion("三月底出生的是什麼星座")?.contains("牡羊座") == true)
        XCTAssertTrue(EchoEngine.signForDateQuestion("七月初出生是什麼星座")?.contains("巨蟹座") == true)
        XCTAssertNil(EchoEngine.signForDateQuestion("我是什麼星座"))
        XCTAssertNil(EchoEngine.signForDateQuestion("13月5號是什麼星座"))
    }

    /// 問怎麼練一種語言，不是要翻譯
    func testLanguagePracticeIsNotTranslation() {
        for q in ["英文講不出口要怎麼練", "日文聽力很差怎麼辦", "韓文單字背不起來"] {
            XCTAssertNil(Translate.parse(q), q)
        }
        for q in ["謝謝的英文怎麼說", "蘋果翻成英文", "早安的日文怎麼講"] {
            XCTAssertNotNil(Translate.parse(q), q)
        }
    }

    /// 規則的換句話說對錯條目、模型非常有把握是另一個條目：用模型的；問好不好看、會不會跌，不用模型硬配
    func testModelOverridesAndGuards() throws {
        let res = EchoCoreTests.resources
        guard FileManager.default.fileExists(atPath: res.appendingPathComponent("meaning.bin").path) else { throw XCTSkip("沒有 meaning.bin") }
        let (oldBrain, oldMM) = (Brain.shared, MeaningMatch.shared)
        defer { Brain.shared = oldBrain; MeaningMatch.shared = oldMM }
        Brain.shared = try Brain(weights: Data(contentsOf: res.appendingPathComponent("reader.bin")),
                                 metaJSON: Data(contentsOf: res.appendingPathComponent("reader.json")))
        MeaningMatch.shared = try MeaningMatch(weights: Data(contentsOf: res.appendingPathComponent("meaning.bin")),
                                               metaJSON: Data(contentsOf: res.appendingPathComponent("meaning.json")))
        let engine = try SimpleQuestionsProbeTests.engine()
        func ask(_ q: String) -> EchoEngine.Reply { engine.reply(to: q, history: [], context: EchoEngine.Context()) }
        let a = ask("下雨天衣服都乾不了")
        XCTAssertTrue(a.turn.text.contains("衣服快點乾"), a.turn.text)
        for q in ["哭泣的駱駝好看嗎", "房價會跌嗎"] {
            let r = ask(q)
            XCTAssertFalse(r.turn.text.contains("駝峰") || r.turn.text.contains("房貸是"), q + " → " + r.turn.text)
        }
    }
}
