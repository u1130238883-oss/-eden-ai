import XCTest
@testable import EchoCore

/// 簡單的問題自己回答（不用上網）：算的、日期、換算、常識、怎麼做、推薦。
/// 問法刻意寫得跟資料不一樣，確定是讀懂問題再從事實推出答案，不是背題目。
final class CommonsenseTests: XCTestCase {
    let now: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 28; c.hour = 16; c.minute = 5
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    func ask(_ q: String) -> String { Everyday.answer(q, now: now) ?? Commonsense.answer(q, now: now) ?? "（上網）" }

    func expect(_ q: String, _ must: [String], file: StaticString = #filePath, line: UInt = #line) {
        let a = ask(q)
        for m in must { XCTAssertTrue(a.contains(m), "「\(q)」→ \(a)\n應該有「\(m)」", file: file, line: line) }
    }

    func testArithmeticAndNumbers() {
        expect("1加1等於多少", ["等於 2"])
        expect("二十加三十五是多少", ["55"])
        expect("九十九乘九十九", ["9,801"])
        expect("兩千五加一千五", ["4,000"])
        expect("5的平方是多少", ["25"])
        expect("根號144", ["12"])
        expect("500的20%是多少", ["100"])
        expect("1000元打八折多少", ["800"])
        XCTAssertEqual(Everyday.number("一百零五"), 105)
        XCTAssertEqual(Everyday.number("三萬五"), 35000)
        XCTAssertEqual(Everyday.number("一點五"), 1.5)
    }

    func testDatesAndHolidays() {
        expect("今天星期幾", ["星期三"])
        expect("明天星期幾", ["星期四"])
        expect("今年是什麼生肖", ["馬"])
        expect("今年是民國幾年", ["115"])
        expect("2028年是閏年嗎", ["是"])
        expect("2100年是閏年嗎", ["不是"])
        expect("12月25日是星期幾", ["星期五"])
        expect("離聖誕節還有幾天", ["58 天"])
        expect("距離過年還有多久", ["2027 年 2 月 6 日"])
        expect("母親節是幾月幾號", ["第二個星期日", "2027 年 5 月 9 日"])
        expect("中秋節是哪一天", ["農曆八月十五", "9 月 25 日"])
    }

    func testUnits() {
        expect("一公斤等於幾公克", ["1,000 公克"])
        expect("一年有幾天", ["365", "366"])
        expect("半小時是幾分鐘", ["30 分鐘"])
        expect("3英寸等於幾公分", ["7.62"])
        expect("100華氏是攝氏幾度", ["37.78"])
        expect("一斤是幾公克", ["600"])
    }

    func testFacts() {
        expect("法國的首都在哪", ["巴黎"])
        expect("東京是哪個國家的首都", ["日本"])
        expect("美國有幾個州", ["50"])
        expect("熊貓吃什麼", ["竹子"])
        expect("火星有幾顆衛星", ["2 顆"])
        expect("人的體溫正常是幾度", ["36.5"])
        expect("人一天要睡幾個小時", ["7 到 9"])
        expect("月亮離地球多遠", ["38.4 萬"])
        expect("台灣最高的山是哪座", ["玉山"])
        expect("人體最大的器官是什麼", ["皮膚"])
        expect("杜甫是哪個朝代的人", ["唐朝"])
        expect("電話是誰發明的", ["貝爾"])
        expect("誰寫了少年維特的煩惱", ["歌德"])
        expect("蒙娜麗莎是誰畫的", ["達文西"])
    }

    func testYesNoReasoning() {
        expect("鯨魚是魚嗎", ["不是", "哺乳類"])
        expect("海豚是哺乳類嗎", ["是的"])
        expect("無尾熊是熊嗎", ["不是"])
        expect("蜘蛛是昆蟲嗎", ["不是", "8 隻腳"])
        expect("冥王星是行星嗎", ["不是", "矮行星"])
        expect("企鵝會飛嗎", ["不會"])
        expect("貓會游泳嗎", ["會"])
        expect("狗可以吃巧克力嗎", ["不可以", "可可鹼"])
        expect("蛇有腳嗎", ["沒有"])
        expect("月亮會發光嗎", ["不會"])
        expect("地球是圓的嗎", ["是的"])
        expect("番茄是水果還是蔬菜", ["兩個都對"])
    }

    func testWhy() {
        expect("天空為什麼是藍色的", ["瑞利散射"])
        expect("夕陽為什麼是紅色的", ["紅光"])
        expect("為什麼會打哈欠", ["降溫"])
        expect("為什麼會打雷", ["閃電"])
        expect("月亮為什麼會發光", ["反射"])
        expect("冰為什麼會浮在水上", ["密度"])
        expect("太陽從哪邊升起", ["東邊"])
    }

    func testHowtoAndRecommend() {
        expect("白飯怎麼煮", ["洗米", "燜"])
        expect("頭痛怎麼辦", ["休息", "看醫生"])
        expect("怎麼存錢", ["先存再花"])
        expect("推薦一部電影", ["我推薦", "如果只能選一個"])
        expect("貓和狗哪個比較好養", ["貓"])
        expect("我好無聊", ["試試"])
    }

    /// 不是常識題的不要攔下來：算命、心情、聊天、作品內容、時事
    func testLeavesOtherQuestionsAlone() {
        for q in ["我今年財運如何", "屬蛇的人今年運勢", "我今天心情不好", "少年維特的煩惱講了什麼", "格林童話有什麼故事",
                  "太陽星座是什麼", "貓咪好可愛", "我的狗今天生病了", "你好", "我叫小明", "台積電股價多少", "今天天氣如何", "東京晴空塔有多高"] {
            XCTAssertNil(Everyday.answer(q, now: now), q)
            XCTAssertNil(Commonsense.answer(q, now: now), q)
        }
    }

    /// 每一筆資料都讀得進來，名字不重複
    func testDataLoads() {
        XCTAssertGreaterThan(Commonsense.facts.count, 300)
        XCTAssertGreaterThan(Commonsense.howtos.count, 15)
        XCTAssertGreaterThan(Commonsense.recommends.count, 8)
        for e in Commonsense.all { XCTAssertFalse(e.attrs.isEmpty, e.name) }
    }
}
