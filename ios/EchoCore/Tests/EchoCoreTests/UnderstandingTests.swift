import XCTest
@testable import EchoCore

/// 先理解問題、再照要的答案去找證據：不靠寫死的答案
final class UnderstandingTests: XCTestCase {
    func testFrames() {
        func want(_ q: String) -> Understanding.Want { Understanding.frame(q).want }
        XCTAssertEqual(want("歐洲有哪些國家"), .list(noun: "國家"))
        XCTAssertEqual(Understanding.frame("歐洲國家都是哪些國家").subject, "歐洲")
        XCTAssertEqual(Understanding.frame("日本有哪些縣？").subject, "日本")
        XCTAssertEqual(want("加拿大有多少個省"), .number(attr: "省", units: ["個省", "座省", "種省", "名省", "省"]))
        XCTAssertEqual(want("加拿大 省 哪些省 列表"), .list(noun: "省"))
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
            .init(text: "近日點時距離約1.47億公里。", host: "nasa.gov"),
        ]
        let v = Understanding.voteNumber(ev, units: ["公里", "km"], subject: "太陽 地球")
        XCTAssertEqual(v?.votes, 2)
        XCTAssertTrue(v?.others.isEmpty == true, "只有一個網站說的數字不算另一種說法")
        XCTAssertTrue(v?.shown.contains("1.496億公里") == true, v?.shown ?? "nil")
        // 主題本身的數字不算（台北101 的 101）
        let t = Understanding.voteNumber([.init(text: "台北101高508公尺，地上101層。", host: "x")], units: ["公尺"], subject: "台北101")
        XCTAssertEqual(t?.shown, "508公尺")
        let pop: [Understanding.Evidence] = [.init(text: "該里人口密度約是每平方公里113,703人。", host: "zh.wikipedia.org"),
                                             .init(text: "臺灣總人口約2,334萬人。", host: "www.ris.gov.tw")]
        XCTAssertEqual(Understanding.voteNumber(pop, units: ["人", "萬", "億"], subject: "台灣人口")?.shown, "2,334萬人")
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
        // 日本：表格混了導覽字（「都道府縣列表」「按地區」「島嶼」），只留真的是縣、都、道、府的
        let jp = "都道府縣列表、按地區、青森縣、北海道、岩手縣、東京都、京都府、島嶼、都道府縣"
        XCTAssertEqual(Understanding.extractList([.init(text: jp, host: "w")], noun: "縣", subject: "日本").items,
                       ["青森縣", "北海道", "岩手縣", "東京都", "京都府"])
        // 同一頁的側欄（經濟學導覽）沒有提到北歐，不能當成北歐的國家
        let side = "北歐\n北歐位於歐洲北部。\n資本主義\n市場經濟\n自由市場\n混合經濟\n國家資本主義\n福利資本主義"
        XCTAssertTrue(Understanding.extractList([.init(text: side, host: "w")], noun: "國家", subject: "北歐").items.isEmpty)
        XCTAssertEqual(Understanding.frame("台灣現在人口有多少").subject, "台灣人口")
        let clauses = "松德海峽大橋開通後，故海關檢查亦隨之鬆綁，瑞典及挪威之間，海關或護照檢查則更加寬鬆，不過北歐公民除護照外，並配合機票，通常亦可放行。"
        XCTAssertTrue(Understanding.extractList([.init(text: clauses, host: "w")], noun: "國家", subject: "北歐").items.isEmpty)
        let desc = "歐洲全稱歐羅巴洲、是世界人口第三多的洲、僅次於亞洲和非洲、最北端是挪威的北角、其與亞洲合稱為歐亞大陸"
        XCTAssertTrue(Understanding.extractList([.init(text: desc, host: "w")], noun: "國家", subject: "歐洲").items.isEmpty)
        // 國家名單：表頭有「國家」的表格才算；導覽框表格（沒有表頭）不算
        let wiki = "歐洲國家列表\n國家 ｜ 首都 ｜ 人口\n阿爾巴尼亞 ｜ 地拉那 ｜ 280萬\n安道爾 ｜ 安道爾城 ｜ 8萬\n奧地利 ｜ 維也納 ｜ 900萬\n比利時 ｜ 布魯塞爾 ｜ 1100萬\n保加利亞 ｜ 索菲亞 ｜ 650萬\n相關條目\n聯賽A ｜ 葡萄牙 ｜ 決賽\n聯賽B ｜ 賽季 ｜ 成立\n聯賽C ｜ 附加賽 ｜ 賽事\n聯賽D ｜ 足球 ｜ 俱樂部"
        let eu = Understanding.extractList([.init(text: wiki, host: "zh.wikipedia.org")], noun: "國家", subject: "歐洲")
        XCTAssertEqual(eu.items, ["阿爾巴尼亞", "安道爾", "奧地利", "比利時", "保加利亞"])
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
        let nutrition = "綠豆\n打開的成熟綠豆豆莢\n綠豆芽可以炒、煮、涼拌、醃製等做法。\n鈣 ｜ 95毫克\n鐵 ｜ 18毫克\n綠豆湯是常見甜品"
        XCTAssertNil(Understanding.extractSteps([.init(text: nutrition, host: "w")], target: "綠豆湯"))
    }

    func testSolveSaysWhenNotAnswered() {
        let fr = Understanding.frame("月亮為什麼會發光")
        let off = [Understanding.Evidence(text: "雙聖樹後來被毀壞，最後一朵花被創造成月亮和太陽。", host: "w")]
        XCTAssertFalse(WebAgent.solve(fr, pages: off, snippets: off).ok)
        let on = [Understanding.Evidence(text: "月亮本身不會發光，我們看到的月光是因為它反射了太陽光。", host: "w")]
        XCTAssertTrue(WebAgent.solve(fr, pages: on, snippets: on).ok)
    }
}

final class ThinkingHabitsTests: XCTestCase {
    func testRecencyAndSources() {
        let f = Understanding.withRecency(Understanding.frame("台灣現在人口有多少"), question: "台灣現在人口有多少", now: Date(timeIntervalSince1970: 1_790_000_000))
        XCTAssertTrue(f.recent)
        XCTAssertTrue(f.searches.first?.hasSuffix("2026") == true, "\(f.searches)")
        XCTAssertFalse(Understanding.withRecency(Understanding.frame("玉山有多高"), question: "玉山有多高").recent)
        XCTAssertEqual(Understanding.latestYear("根據2023年與2025年的統計"), 2025)
        // 一個官方來源勝過一個普通網站
        let ev: [Understanding.Evidence] = [.init(text: "總人口約2,340萬人。", host: "www.ris.gov.tw"), .init(text: "總人口約2,100萬人。", host: "blog.example.com")]
        XCTAssertEqual(Understanding.voteNumber(ev, units: ["人"], subject: "台灣")?.shown, "2,340萬人")
    }

    func testMissingSubject() throws {
        XCTAssertEqual(Understanding.missingSubject("名字叫什麼"), .personal)
        XCTAssertEqual(Understanding.missingSubject("幾歲"), .personal)
        XCTAssertEqual(Understanding.missingSubject("多少錢"), .generic)
        XCTAssertEqual(Understanding.missingSubject("是什麼顏色"), .generic)
        XCTAssertNil(Understanding.missingSubject("台北101有多高"))
        XCTAssertNil(Understanding.missingSubject("歐洲有哪些國家"))
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 2)
        let ctx = EchoEngine.Context(now: t.date(2026, 9, 30, 11))
        let name = engine.reply(to: "名字叫什麼", context: ctx)
        XCTAssertNil(name.webQuery)
        XCTAssertTrue(name.turn.text.contains("NineSun"), name.turn.text)
        let price = engine.reply(to: "多少錢", context: ctx)
        XCTAssertNil(price.webQuery)
        XCTAssertTrue(price.turn.text.contains("告訴我名稱"), price.turn.text)
    }

    func testClarifyVaguePronoun() throws {
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 2)
        let ctx = EchoEngine.Context(now: t.date(2026, 9, 30, 11))
        let r = engine.reply(to: "它有多高", context: ctx)
        XCTAssertNil(r.webQuery)
        XCTAssertTrue(r.turn.text.contains("是指什麼"), r.turn.text)
    }
}
