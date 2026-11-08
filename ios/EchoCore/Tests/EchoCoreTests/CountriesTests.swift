import XCTest
@testable import EchoCore

/// 使用者回報：「中國護照免簽現在哪些國家」的名單混進「3天前」「請選擇護照」「電子旅行授權·6」，中英文擠成一大串
final class CountriesTests: XCTestCase {
    func testVisaListFromScreenshot() {
        let items = ["3天前", "請選擇護照", "電子旅行授權·6", "免簽", "亞美尼亞 Armenia", "伊朗 Iran", "卡塔爾 Qatar", "土耳其 Turkey",
                     "文萊 Brunei", "新加坡 Singapore", "格魯吉亞 Georgia", "泰國 Thailand", "落地簽", "尼泊爾 Nepal", "巴林 Bahrain",
                     "柬埔寨 Cambodia", "電子旅行授權", "不丹 Bhutan", "也門 Yemen", "電子簽", "巴基斯坦 Pakistan", "蒙古 Mongolia", "越南"]
        let t = Countries.tidy(items)
        XCTAssertEqual(t.groups.map(\.label), ["免簽", "落地簽", "電子旅行授權", "電子簽"])
        XCTAssertEqual(t.groups[0].names, ["亞美尼亞", "伊朗", "卡達", "土耳其", "汶萊", "新加坡", "喬治亞", "泰國"])
        XCTAssertEqual(t.groups[3].names, ["巴基斯坦", "蒙古", "越南"])
        XCTAssertEqual(t.dropped, 2)   // 3天前、請選擇護照
    }

    func testCanonical() {
        XCTAssertEqual(Countries.canonical("新西蘭"), "紐西蘭")
        XCTAssertEqual(Countries.canonical("Thailand"), "泰國")
        XCTAssertEqual(Countries.canonical("意大利共和國"), "義大利")
        XCTAssertNil(Countries.canonical("希臘神話"))
        XCTAssertNil(Countries.canonical("3天前"))
    }

    func testListSubjectDropsNow() {
        XCTAssertEqual(Understanding.itemsAsk("發達國家現在有哪些")?.subject, "發達國家")
    }
}
