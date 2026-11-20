import XCTest
@testable import EchoCore

/// Round 28（2026-11-20）：本地剛回答了一件事，下一句沒有主語的短追問要上網查時，帶著那個主題查
final class Round28Tests: XCTestCase {
    func run(_ qs: [String]) throws -> [EchoEngine.Reply] {
        let engine = try SimpleQuestionsProbeTests.engine()
        var h: [ChatTurn] = [], out: [EchoEngine.Reply] = []
        for q in qs {
            let r = engine.reply(to: q, history: h, context: EchoEngine.Context())
            h.append(ChatTurn(role: .user, text: q)); h.append(r.turn); out.append(r)
        }
        return out
    }

    func testFollowUpSearchKeepsTopic() throws {
        let a = try run(["手機一直自己重開機", "要送修嗎"])
        XCTAssertEqual(a[1].webQuery, "手機一直自己重開機 要送修")
        let b = try run(["信用卡忘記繳會怎樣", "會影響信用嗎"])
        XCTAssertTrue(b[1].webQuery?.hasPrefix("信用卡忘記繳") == true, b[1].webQuery ?? b[1].turn.text)
        // 「多少錢」要找到真的價錢；「免費的道路救援」不是電瓶的價錢
        let c = try run(["汽車電瓶沒電怎麼辦", "換一顆要多少錢"])
        XCTAssertFalse(c[1].turn.text.contains("道路救援"), c[1].turn.text)
    }

    /// 模型對到的條目，用名稱查不到回答的（「誰提出的」「作品」類）也要回答得出來
    func testEntryAnswerCoversWhoAndWorks() throws {
        _ = try SimpleQuestionsProbeTests.engine()
        XCTAssertTrue(MeaningMatch.entryAnswer("精神分析", now: Date())?.contains("佛洛伊德") == true)
        XCTAssertTrue(MeaningMatch.entryAnswer("基督教", now: Date())?.contains("耶穌") == true)
        XCTAssertTrue(MeaningMatch.entryAnswer("中國四大古都", now: Date())?.contains("西安") == true)
        XCTAssertNotNil(MeaningMatch.entryAnswer("一九八四", now: Date()))
        // 查到的要真的是在講這個條目：「老人與海」不能變成「海水是…」
        XCTAssertFalse(MeaningMatch.entryAnswer("老人與海", now: Date())?.contains("海水是") == true)
    }

    /// 開發題找到的：抱怨累（「一直羨慕別人的生活好累」）不是想輕生；「不快樂」不是開心；用日期說星座個性
    func testDevFixes() throws {
        let engine = try SimpleQuestionsProbeTests.engine()
        let res = EchoCoreTests.resources
        let (oldBrain, oldMM) = (Brain.shared, MeaningMatch.shared)
        defer { Brain.shared = oldBrain; MeaningMatch.shared = oldMM }
        Brain.shared = try Brain(weights: Data(contentsOf: res.appendingPathComponent("reader.bin")), metaJSON: Data(contentsOf: res.appendingPathComponent("reader.json")))
        MeaningMatch.shared = try MeaningMatch(weights: Data(contentsOf: res.appendingPathComponent("meaning.bin")), metaJSON: Data(contentsOf: res.appendingPathComponent("meaning.json")))
        XCTAssertFalse(MeaningMatch.shared!.looksLikeCrisis("一直羨慕別人的生活好累"))
        XCTAssertTrue(MeaningMatch.shared!.looksLikeCrisis("我真的覺得活著好累喔"))
        let a = engine.reply(to: "現在工作很穩定但是不快樂要不要走", history: [], context: EchoEngine.Context()).turn.text
        XCTAssertFalse(a.contains("開心"), a)
        XCTAssertTrue(EchoEngine.personalityForDateQuestion("三月底生日的人個性如何")?.contains("牡羊座") == true)
        XCTAssertTrue(EchoEngine.personalityForDateQuestion("7月5號出生的人是什麼個性")?.contains("巨蟹座") == true)
        XCTAssertNil(EchoEngine.personalityForDateQuestion("我的個性怎麼樣"))
    }

    /// 「出國可以帶泡麵嗎」「旅行要買旅平險嗎」是實際的問題，不是出國運勢（以前回「我還不知道你的生日」）
    func testPracticalTravelIsNotFortune() throws {
        let engine = try SimpleQuestionsProbeTests.engine()
        for q in ["出國可以帶泡麵嗎", "出國手機要開漫遊嗎", "旅行要買旅平險嗎"] {
            let a = engine.reply(to: q, history: [], context: EchoEngine.Context()).turn.text
            XCTAssertFalse(a.contains("生日"), q + " → " + a)
        }
        XCTAssertFalse(EchoEngine.knowledgeNotFortune("我出國順不順"))
    }
}
