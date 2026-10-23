import XCTest
@testable import EchoCore

/// 整理：好幾個網站 → 拆重點、比對、用自己的話寫；不能貼文章簡介、hashtag 標題
final class SynthesizeTests: XCTestCase {
    func testAdviceFromSeveralSites() {
        let a = """
        ⭐ 免費算命看運勢#喜歡一個人# 戀愛心理# 戀愛技巧# 約會建議
        這篇文章旨在幫助你瞭解當你喜歡一個人時，應該如何應對、行動以及如何增強自己的自信。
        1. 先觀察對方
        看看對方對你的態度是不是跟對別人不一樣，有沒有主動找你聊天。
        2. 製造相處的機會
        可以約對方一起參加活動，讓彼此有更多自然相處的時間。
        3. 做好自己
        保持自己的生活和興趣，有自信的人最有吸引力。
        延伸閱讀：暗戀一個人的10個表現
        """
        let b = """
        喜歡一個人該怎麼辦？5招教你脫單｜戀愛學
        很多人都有過喜歡一個人卻不敢說的經驗。
        第一招：多創造和對方相處的機會，例如一起吃飯、一起參加社團活動。
        第二招：觀察對方的反應，如果對方也會主動找你，代表有機會。
        第三招：不要一下子就告白，先成為朋友，讓對方認識真正的你。
        第四招：把自己打理好，保持自信和自己的生活圈。
        """
        let c = """
        當你喜歡一個人時，最重要的是先讓自己變得更好，保持自信。
        建議先跟對方當朋友，慢慢了解彼此的興趣和價值觀。
        如果被拒絕也不要灰心，這不代表你不好，只是不適合。
        """
        let t = Synthesize.compose(question: "喜歡一個人該怎麼辦", subject: "喜歡一個人", want: .steps(target: "喜歡一個人"),
                                   pages: [("ai.shareba.com", a), ("love.example.tw", b), ("psy.example.com", c)])
        let out = try! XCTUnwrap(t)
        XCTAssertTrue(out.hasPrefix("我讀了 3 個網站"), out)
        XCTAssertFalse(out.contains("這篇文章"), out)
        XCTAssertFalse(out.contains("#"), out)
        XCTAssertFalse(out.contains("延伸閱讀"), out)
        XCTAssertFalse(out.contains("當你喜歡一個人時"), out)
        XCTAssertTrue(out.contains("先觀察對方"), out)
        XCTAssertTrue(out.contains("2 個網站都提到"), out)
        XCTAssertFalse(out.contains("第一招"), out)
    }

    /// 新的搜尋來源用同一個通用解析：找連到別的網站、文字夠長的連結當結果
    func testGenericResults() {
        let html = """
        <html><a href="https://www.mojeek.com/about">About Mojeek</a>
        <ul class="results-standard"><li><a class="ob" href="https://www.example.tw/love/how-to">喜歡一個人怎麼辦？5個方法</a>
        <p class="s">先觀察對方的反應，再慢慢製造相處的機會。</p></li>
        <li><a href="https://psy.example.com/a?x=1&amp;y=2">暗戀的心理學：從朋友開始</a><p>先成為朋友，讓對方認識你。</p></li>
        <li><a href="https://www.google.com/search?q=x">Google 搜尋這個問題</a></li></ul></html>
        """
        let hits = WebSearch.genericResults(html, engine: "mojeek.com", name: "Mojeek")
        XCTAssertEqual(hits.map(\.url), ["https://www.example.tw/love/how-to", "https://psy.example.com/a?x=1&y=2"])
        XCTAssertEqual(hits.first?.title, "喜歡一個人怎麼辦？5個方法")
        XCTAssertTrue(hits.first?.snippet.contains("先觀察對方") == true, hits.first?.snippet ?? "")
    }
}
