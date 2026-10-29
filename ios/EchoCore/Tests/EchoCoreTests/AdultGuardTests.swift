import XCTest
@testable import EchoCore

/// 成人模式的底線：未成年一律擋下；成年人的設定不能被誤擋
final class AdultGuardTests: XCTestCase {
    func testBlocksMinors() {
        for t in ["她是國中生", "扮演一個十六歲的女孩", "我們 15 歲", "蘿莉角色", "a 16-year-old girl", "she is a minor", "una bambina",
                  "十二歲", "小女孩", "underage"] {
            XCTAssertTrue(AdultGuard.crosses(t), t)
        }
    }

    func testAllowsAdults() {
        for t in ["溫柔的成年戀人，25 歲", "她今年二十五歲", "我 18 歲了", "抱緊我", "my 30 year old neighbor", "kidney", "十八歲生日",
                  "我們在大學認識", "she is 21"] {
            XCTAssertFalse(AdultGuard.crosses(t), t)
        }
    }
}
