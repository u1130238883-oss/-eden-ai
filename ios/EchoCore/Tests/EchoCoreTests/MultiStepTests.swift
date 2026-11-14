import XCTest
@testable import EchoCore

/// 分兩步想：先分別查兩個數字，換成同一個單位，再相減、比大小、算倍數
final class MultiStepTests: XCTestCase {
    func testSplitsIntoTwoQuestions() throws {
        let p = try XCTUnwrap(MultiStep.parse("台北101比玉山高多少？"))
        XCTAssertEqual([p.a, p.b, p.subA, p.subB], ["台北101", "玉山", "台北101有多高", "玉山有多高"])
        XCTAssertEqual(p.op, .diff)
        let w = try XCTUnwrap(MultiStep.parse("玉山和富士山哪個高"))
        XCTAssertEqual(w.op, .which)
        let r = try XCTUnwrap(MultiStep.parse("太陽的質量是地球的幾倍"))
        XCTAssertEqual([r.subA, r.subB], ["太陽的質量是多少", "地球的質量是多少"])
        XCTAssertEqual(r.op, .ratio)
        let pop = try XCTUnwrap(MultiStep.parse("台灣人口比日本多多少"))
        XCTAssertEqual([pop.subA, pop.subB], ["台灣人口有多少", "日本的人口有多少"])
        // 不是在比兩個東西的數量
        for q in ["我比你高多少", "iPhone和安卓哪個好", "台北101有多高", "今天比昨天冷嗎"] { XCTAssertNil(MultiStep.parse(q), q) }
    }

    func testComputesWithUnits() throws {
        let p = try XCTUnwrap(MultiStep.parse("台北101比玉山高多少"))
        // 台北101 其實比較矮：照實講
        let c = try XCTUnwrap(MultiStep.compute(p, "508公尺", "3,952公尺"))
        XCTAssertTrue(c.answer.contains("其實台北101比玉山矮 3,444公尺"), c.answer)
        XCTAssertEqual(c.math, "3,952公尺 − 508公尺 = 3,444公尺")
        let w = try XCTUnwrap(MultiStep.parse("玉山和台北101哪個高"))
        let cw = try XCTUnwrap(MultiStep.compute(w, "3952公尺", "0.508公里"))
        XCTAssertTrue(cw.answer.hasPrefix("玉山比較高：比台北101高 3,444公尺"), cw.answer)
        let r = try XCTUnwrap(MultiStep.parse("太陽到地球的距離是地球到月亮的幾倍"))
        let cr = try XCTUnwrap(MultiStep.compute(r, "1.496億公里", "384,400公里"))
        XCTAssertTrue(cr.answer.contains("389 倍"), cr.answer)
        // 「１億2321萬9千人」（全形數字、好幾段）
        XCTAssertEqual(MultiStep.quantity("１億2321萬9千人")?.base, 123_219_000)
        let pop = try XCTUnwrap(MultiStep.parse("台灣人口比日本多多少"))
        let cp = try XCTUnwrap(MultiStep.compute(pop, "23,213,251人", "１億2321萬9千人"))
        XCTAssertTrue(cp.answer.hasPrefix("其實台灣人口比日本的人口少 1億"), cp.answer)
        // 單位對不起來（公尺 vs 公斤）就不算
        XCTAssertNil(MultiStep.compute(p, "508公尺", "70公斤"))
        XCTAssertEqual(MultiStep.short("答案：508公尺（3 個網站都這樣說）。\n依據：「主體建築的塔樓高508公尺」（zh.wikipedia.org）")?.host, "zh.wikipedia.org")
    }
}
