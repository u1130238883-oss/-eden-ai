import XCTest
@testable import EchoCore

/// 名字合盤：Nine & Twelve 原版作者的例子
final class NameSynastryTests: XCTestCase {
    func testNameRows() {
        let d = Destiny(BirthDay(year: 2006, month: 1, day: 14))   // 靈數 5
        func rows(_ s: String) -> [String] { d.nameRows(s).map { $0.text } }
        XCTAssertEqual(rows("china"), ["8宮壞9因2", "1宮壞11因4", "2宮好2因9", "7宮壞4因11", "6宮正5因7"])
        XCTAssertEqual(rows("Chi na"), rows("china"))
        XCTAssertEqual(rows(""), [])
        XCTAssertEqual(rows("小明"), [])
    }
}
