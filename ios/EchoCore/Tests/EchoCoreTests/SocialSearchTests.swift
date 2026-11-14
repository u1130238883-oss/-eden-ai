import XCTest
@testable import EchoCore

/// 社群平台：最新的事查 X，看法、經驗查知乎，英文名字的主題也查 Reddit（都經過搜尋引擎，不登入平台）
final class SocialSearchTests: XCTestCase {
    func testPlatforms() {
        let fresh = WebAgent.socialQueries("現在ai都有什麼最新模型", kind: .general, core: "ai 模型", zh: true)
        XCTAssertEqual(fresh, ["site:x.com ai 模型", "site:threads.com ai 模型", "site:reddit.com ai 模型"])
        let opinion = WebAgent.socialQueries("學吉他推薦哪一本書", kind: .recommend, core: "學吉他 書", zh: true)
        XCTAssertEqual(opinion, ["site:threads.com 學吉他 書", "site:zhihu.com 學吉他 書"])
        let news = WebAgent.socialQueries("最近台灣有什麼新聞", kind: .news, core: "台灣 新聞", zh: true)
        XCTAssertEqual(news, ["site:x.com 台灣 新聞", "site:threads.com 台灣 新聞", "site:zhihu.com 台灣 新聞"])
        XCTAssertEqual(WebAgent.socialQueries("台北101有多高", kind: .general, core: "台北101", zh: true), [])
    }
}
