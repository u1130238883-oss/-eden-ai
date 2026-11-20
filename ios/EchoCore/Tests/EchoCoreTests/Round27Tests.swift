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
        for q in ["謝謝的英文怎麼說", "蘋果翻成英文", "早安的日文怎麼講", "文法的西班牙文是什麼"] {
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
        XCTAssertFalse(ask("我想知道出國需要注意哪些？").turn.text.contains("韓國"))
        for q in ["哭泣的駱駝好看嗎", "房價會跌嗎"] {
            let r = ask(q)
            XCTAssertFalse(r.turn.text.contains("駝峰") || r.turn.text.contains("房貸是"), q + " → " + r.turn.text)
        }
    }

    /// 探測找到的：吃藥不是推薦美食；「吃完飯就想睡」不是在說吃了什麼；擔心的好消息不先恭喜；新加的生活知識
    func testProbeFixes() throws {
        let engine = try SimpleQuestionsProbeTests.engine()
        func ask(_ q: String) -> String { engine.reply(to: q, history: [], context: EchoEngine.Context()).turn.text }
        XCTAssertFalse(ask("頭痛要吃什麼藥").contains("我推薦這幾個"))
        XCTAssertFalse(ask("吃完飯就想睡").contains("好吃嗎"))
        XCTAssertEqual(Talk.chat("我吃完拉麵了")?.hasPrefix("拉麵好吃嗎"), true)
        XCTAssertFalse(ask("畢業了不知道要做什麼").contains("恭喜"))
        let expect = ["衣服沾到原子筆": "原子筆", "被狗咬到要打針嗎": "肥皂", "網路一直斷線": "路由器", "耳機一邊沒聲音": "平衡",
                      "信用卡忘記繳會怎樣": "最低應繳", "手機掉到馬桶": "關機", "起床脖子好痛": "落枕", "兔子不吃東西": "12 小時",
                      "汽車電瓶沒電怎麼辦": "道路救援", "照片不小心刪掉了": "最近刪除", "菜太鹹了怎麼救": "稀釋",
                      "那個我家冰箱好像不冷了耶": "膠條", "欸我那個機車發不動了": "側柱", "我想要存錢但是每個月都花光光": "記帳",
                      "就是我想減肥但是晚上都會很餓": "減肥", "那個我朋友生日要送什麼比較好": "送禮", "早上都爬不起來": "早起",
                      "手機一直自己重開機": "更新", "健保卡怎麼註冊": "快易通", "瓦斯桶沒瓦斯了": "瓦斯行", "水龍頭一直滴水": "墊片",
                      "前天我錄取醫學系了，真的，怎麼辦！": "恭喜"]
        for (q, w) in expect { XCTAssertTrue(ask(q).contains(w), q + " → " + ask(q)) }
    }

    /// 語音輸入的「睡不好然後早上都爬不起來」是起床困難，不是不想醒來
    func testNotCrisis() {
        XCTAssertNil(Safety.level("就是說我最近一直睡不好然後早上都爬不起來"))
        XCTAssertEqual(Safety.level("好想就這樣睡著不要醒來"), .crisis)
        XCTAssertEqual(EchoEngine.dropFillers("所以就是說貓為什麼會一直舔自己"), "貓為什麼會一直舔自己")
    }
}
