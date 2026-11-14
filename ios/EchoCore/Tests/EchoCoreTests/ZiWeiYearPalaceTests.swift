import XCTest
@testable import EchoCore

/// 流年四化看流年盤：2006/1/14 8 點（乙酉年臘月十五辰時，命宮酉）2026 丙午年，
/// 流年命宮在午，廉貞在子 → 流年遷移宮（本命田宅宮），化忌沖流年命宮
final class ZiWeiYearPalaceTests: XCTestCase {
    func testYearSihuaUsesYearPalaces() {
        let zw = ZiWei(2006, 1, 14, hour: 8, male: true)
        XCTAssertEqual(GZ.branches[zw.ming], "酉")
        let t = ZiWeiReading.year(zw, male: true, age: 20, year: 2026).text
        print(t)
        XCTAssertTrue(t.contains("廉貞化忌落在流年遷移宮（子宮，本命田宅宮）"))
        XCTAssertTrue(t.contains("天同化祿落在流年子女宮（卯宮，本命遷移宮）"))
        XCTAssertTrue(t.contains("文昌化科落在流年命宮"))
        XCTAssertTrue(t.contains("天機化權落在流年父母宮"))
        XCTAssertTrue(t.contains("會沖到對面的流年命宮"))
        let h = ZiWeiReading.yearHua(zw, year: 2026)
        XCTAssertEqual(h.last?.label, "流年遷移宮（本命田宅宮）")
        print(ZiWeiReading.palace(zw, name: "田宅", year: 2026))
    }
}
