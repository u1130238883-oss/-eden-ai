import XCTest
@testable import EchoCore

/// Round 29（2026-11-20 晚上）：口語說「我想要…」「我的…壞了」的探測找到的問題
final class Round29Tests: XCTestCase {
    // 每一題用新的引擎（同一個引擎會帶著上一題的狀態）
    private func ask(_ q: String) -> String {
        (try? SimpleQuestionsProbeTests.engine())?.reply(to: q, history: [], context: EchoEngine.Context()).turn.text ?? ""
    }

    /// 只說想做什麼，也給那件事的做法；想去做某件事不是去旅行
    func testWantsToDo() {
        XCTAssertTrue(ask("我想要學做麵包").contains("酵母"))
        XCTAssertTrue(ask("我想要寫小說").contains("短篇"))
        XCTAssertFalse(ask("我想去看電影").contains("去幾天"))
        XCTAssertTrue(ask("我想去日本玩").contains("去幾天"))
    }

    /// 「我吃到魚刺卡住」不是在說要吃什麼
    func testEatingTroubleIsNotAMealChoice() {
        XCTAssertNil(Talk.chat("我吃到魚刺卡住")?.range(of: "也很好"))
        XCTAssertNil(Talk.chat("我吃壞肚子")?.range(of: "也很好"))
        XCTAssertEqual(Talk.chat("我要喝珍奶")?.hasPrefix("珍奶也很好"), true)
    }

    /// 模型沒學過的新條目，規則對到了就用規則的（模型不知道它存在，說「是別的」不算數）
    func testRulesWinForEntriesTheModelNeverSaw() {
        XCTAssertTrue(ask("我炒青菜都會變黃").contains("翠綠"))
        XCTAssertTrue(ask("我買的酪梨太硬").contains("催熟"))
    }

    /// 探測補上的生活知識（各挑一個關鍵字）
    func testProbeEntries() {
        let expect = ["我的包包發霉了": "皮件", "我家的鳥不吃東西": "獸醫", "我的機車一直熄火": "怠速",
                      "我的耳機有雜音": "配對", "我家的門很吵會叫": "鉸鏈", "我切洋蔥一直流眼淚": "冰箱",
                      "我的冰箱一直在叫": "壓縮機", "我的電鍋跳起來飯還沒熟": "外鍋", "我的咖啡太苦": "水溫",
                      "我一直冒冷汗": "119", "我的牙齒很敏感": "抗敏感", "欸我車子的胎壓燈亮了": "打氣"]
        for (q, w) in expect { let a = ask(q); XCTAssertTrue(a.contains(w), q + " → " + a) }
    }
}
