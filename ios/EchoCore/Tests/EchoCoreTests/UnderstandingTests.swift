import XCTest
@testable import EchoCore

/// 先理解問題、再照要的答案去找證據：不靠寫死的答案
final class UnderstandingTests: XCTestCase {
    func testFrames() {
        func want(_ q: String) -> Understanding.Want { Understanding.frame(q).want }
        XCTAssertEqual(want("歐洲有哪些國家"), .list(noun: "國家"))
        XCTAssertEqual(Understanding.frame("歐洲國家都是哪些國家").subject, "歐洲")
        XCTAssertEqual(Understanding.frame("日本有哪些縣？").subject, "日本")
        XCTAssertEqual(want("加拿大有多少個省"), .number(attr: "省", units: ["個", "座", "種", "名", "省"]))
        XCTAssertEqual(Understanding.frame("加拿大有多少個省").subject, "加拿大")
        if case let .number(attr, units) = want("太陽到地球有多遠") { XCTAssertEqual(attr, "距離"); XCTAssertTrue(units.contains("公里")) } else { XCTFail() }
        XCTAssertTrue(Understanding.frame("太陽到地球有多遠").searches.contains("太陽 地球 距離"))
        if case .number = want("玉山有多高") {} else { XCTFail() }
        XCTAssertEqual(want("感冒為什麼會發燒"), .reason(pred: "發燒"))
        XCTAssertEqual(want("貓為什麼會發出呼嚕聲"), .reason(pred: "發出呼嚕聲"))
        XCTAssertEqual(want("怎麼煮綠豆湯"), .steps(target: "綠豆湯"))
        XCTAssertEqual(want("綠豆湯怎麼煮"), .steps(target: "綠豆湯"))
        XCTAssertTrue(Understanding.frame("怎麼煮綠豆湯").searches.contains("綠豆湯 做法"))
        XCTAssertEqual(want("誰發明了電話"), .person)
        XCTAssertEqual(want("日本的首都是哪裡"), .place)
        XCTAssertEqual(want("iPhone和安卓哪個好"), .compare("iPhone", "安卓"))
        XCTAssertEqual(want("量子力學是什麼"), .definition)
        XCTAssertEqual(want("老闆不給我加薪怎麼辦"), .open)
    }

    func testNumberVote() {
        let ev: [Understanding.Evidence] = [
            .init(text: "地球與太陽的平均距離約為1.496億公里，也就是一個天文單位。", host: "a.com"),
            .init(text: "日地平均距離大約是 149,600,000 公里。", host: "b.com"),
            .init(text: "近日點時距離約1.47億公里。", host: "c.com"),
        ]
        let v = Understanding.voteNumber(ev, units: ["公里", "km"], subject: "太陽 地球")
        XCTAssertEqual(v?.votes, 2)
        XCTAssertEqual(v?.others.first, "1.47億公里")
        XCTAssertTrue(v?.shown.contains("1.496億公里") == true, v?.shown ?? "nil")
        // 主題本身的數字不算（台北101 的 101）
        let t = Understanding.voteNumber([.init(text: "台北101高508公尺，地上101層。", host: "x")], units: ["公尺"], subject: "台北101")
        XCTAssertEqual(t?.shown, "508公尺")
    }

    func testListFromTableAndEnumeration() {
        let table = """
        加拿大省份列表
        省份 ｜ 首府 ｜ 人口
        安大略省 ｜ 多倫多 ｜ 14,223,942
        魁北克省 ｜ 魁北克市 ｜ 8,501,833
        卑詩省 ｜ 維多利亞 ｜ 5,000,879
        亞伯達省 ｜ 愛德蒙頓 ｜ 4,262,635
        曼尼托巴省 ｜ 溫尼伯 ｜ 1,342,153
        薩斯喀徹溫省 ｜ 里賈納 ｜ 1,132,505
        """
        let r = Understanding.extractList([.init(text: table, host: "zh.wikipedia.org")], noun: "省", subject: "加拿大")
        XCTAssertEqual(r.items.first, "安大略省")
        XCTAssertEqual(r.items.count, 6, "\(r.items)")
        XCTAssertFalse(r.items.contains("省份"))
        let en = "北歐國家包括挪威、瑞典、芬蘭、丹麥、冰島等五國。"
        let e = Understanding.extractList([.init(text: en, host: "x.com")], noun: "國家", subject: "北歐")
        XCTAssertEqual(e.items.count, 5, "\(e.items)")
        // 不是名單的一串（介紹文）不能當成名單
        let intro = "本文將透過地理分區、政治實體等不同角度，帶你詳細瞭解。"
        XCTAssertTrue(Understanding.extractList([.init(text: intro, host: "y")], noun: "國家", subject: "歐洲").items.isEmpty)
    }

    func testReasonAndSteps() {
        let ev: [Understanding.Evidence] = [
            .init(text: "感冒時會發燒，是因為免疫系統為了對抗病毒，把體溫調節的設定點調高。", host: "a"),
            .init(text: "風熱感冒會流黃鼻涕、口乾。", host: "b"),
        ]
        let r = Understanding.extractReason(ev, pred: "發燒")
        XCTAssertEqual(r.count, 1)
        XCTAssertTrue(r[0].text.contains("免疫系統"))
        let page = """
        綠豆湯做法
        1. 綠豆洗淨，泡水 2 小時。
        2. 鍋中加水，放入綠豆，大火煮滾。
        3. 轉小火煮 30 分鐘，至綠豆開花。
        4. 關火後加入冰糖攪拌均勻。
        """
        let s = Understanding.extractSteps([.init(text: page, host: "recipe.tw")], target: "綠豆湯")
        XCTAssertEqual(s?.steps.count, 4)
        XCTAssertEqual(s?.steps.first, "綠豆洗淨，泡水 2 小時。")
    }

    func testSolveSaysWhenNotAnswered() {
        let fr = Understanding.frame("月亮為什麼會發光")
        let off = [Understanding.Evidence(text: "雙聖樹後來被毀壞，最後一朵花被創造成月亮和太陽。", host: "w")]
        XCTAssertFalse(WebAgent.solve(fr, pages: off, snippets: off).ok)
        let on = [Understanding.Evidence(text: "月亮本身不會發光，我們看到的月光是因為它反射了太陽光。", host: "w")]
        XCTAssertTrue(WebAgent.solve(fr, pages: on, snippets: on).ok)
    }
}
