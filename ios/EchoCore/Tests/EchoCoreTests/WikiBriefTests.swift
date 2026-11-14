import XCTest
@testable import EchoCore

/// 維基百科只讀開頭摘要和作品的「劇情」那一節（整頁、頁尾不讀）
final class WikiBriefTests: XCTestCase {
    static let werther = """
    《少年維特的煩惱》（德語：Die Leiden des jungen Werthers）是第一部讓歌德在德國幾乎一夜成名的小說。1774年秋天在萊比錫書籍展覽會上面世，並在那裡成了暢銷書。

    == 內容 ==
    維特是一個能詩善畫、熱愛自然的青年。他來到一個小鎮，在一次舞會上認識了法官的女兒綠蒂，並愛上了她，可是綠蒂已經與阿爾伯特訂婚。
    === 第二部 ===
    維特離開小鎮去公使館任職，受不了官僚習氣而辭職。回到綠蒂身邊時她已經結婚，維特在絕望中用阿爾伯特的手槍自殺。

    == 創作背景 ==
    歌德在韋茨拉爾愛上了夏綠蒂·布夫。

    == 參見 ==
    維特效應
    == 外部連結 ==
    維基共享資源上的相關多媒體資源
    """

    func testOnlyIntroAndPlot() {
        let t = WebSearch.wikiBriefText(Self.werther, work: true)
        XCTAssertTrue(t.hasPrefix("《少年維特的煩惱》"), t)
        XCTAssertTrue(t.contains("劇情：維特是一個"), t)
        XCTAssertTrue(t.contains("綠蒂") && t.contains("自殺"), t)
        for junk in ["參見", "外部連結", "維基共享", "創作背景", "韋茨拉爾", "=="] { XCTAssertFalse(t.contains(junk), junk + "\n" + t) }
        // 不是作品：只要開頭
        let d = WebSearch.wikiBriefText(Self.werther, work: false)
        XCTAssertFalse(d.contains("綠蒂"), d)
    }

    func testLongIntroCutAtSentence() {
        let long = String(repeating: "五行是中國古代哲學的一種系統觀。", count: 60)
        let t = WebSearch.wikiBriefText(long, work: false)
        XCTAssertLessThanOrEqual(t.count, 500)
        XCTAssertTrue(t.hasSuffix("。"), t)
    }

    func testCandidates() {
        XCTAssertEqual(WebSearch.wikiCandidates("活著", titles: ["活著", "活著 (電影)", "活著 (小說)"], work: true, prefer: ["小說", "書"]).first, "活著 (小說)")
        // 沒講明是哪一種：名字一樣的條目先試（小王子是書，不是 2015 年的電影；你的名字不是原聲帶）
        XCTAssertEqual(WebSearch.wikiCandidates("小王子", titles: ["小王子 (2015年電影)", "小王子"], work: true).first, "小王子")
        XCTAssertEqual(WebSearch.wikiCandidates("你的名字", titles: ["你的名字。 (專輯)", "你的名字。"], work: true).first, "你的名字。")
        XCTAssertEqual(WebSearch.wikiCandidates("活著", titles: ["活着 (電影)", "活着 (小说)", "活著 (專輯)"], work: true).prefix(2).map { $0 }, ["活着 (小说)", "活着 (電影)"])
        XCTAssertEqual(WebSearch.wikiCandidates("夏洛特的煩惱", titles: ["夏洛特煩惱", "夏洛特"], work: true).first, "夏洛特煩惱")
        XCTAssertEqual(WebSearch.wikiCandidates("五行", titles: ["五行山", "五行"], work: false).first, "五行")
        // 定義題：名字對不上的不要（問「時間」不能拿「時間簡史」）
        XCTAssertEqual(WebSearch.wikiCandidates("通貨膨脹", titles: ["惡性通貨膨脹的歷史"], work: false), [])
        // 作品的別名：第一筆也試，但要開頭有提到這個名字才算
        XCTAssertEqual(WebSearch.wikiCandidates("刺激1995", titles: ["肖申克的救贖"], work: true), ["肖申克的救贖"])
        XCTAssertTrue(WebSearch.wikiFits("刺激1995", title: "肖申克的救贖", text: "《肖申克的救贖》（香港譯《月黑高飛》，台灣譯《刺激1995》）是1994年的美國電影。"))
        XCTAssertFalse(WebSearch.wikiFits("刺激1995", title: "佛羅里達馬林魚", text: "邁阿密馬林魚是一支職業棒球隊，1993年成立。"))
        XCTAssertTrue(WebSearch.wikiFits("夏洛特的煩惱", title: "夏洛特煩惱", text: "《夏洛特煩惱》是2015年的中國喜劇電影。"))
    }

    static func brief(_ name: String) throws -> WikiAnswer.Brief {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "wiki_briefs", withExtension: "json", subdirectory: "Fixtures"))
        let all = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
        let parts = try XCTUnwrap(all[name]).split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        return (parts[0], parts[2], parts[1])
    }

    /// 真的從維基錄下來的摘要：第一句是定義，外文原名、注音拿掉，句子完整
    func testDefineFromRealBriefs() throws {
        for (name, must) in [("五行", "哲學概念"), ("時間", "尺度"), ("愛", "情感"), ("民主", "政體"), ("通貨膨脹", "物價"), ("陰陽", "哲學觀念"), ("幸福", "心靈滿足")] {
            let a = try XCTUnwrap(WikiAnswer.define(subject: name, brief: Self.brief(name)), name)
            let lead = try XCTUnwrap(a.text.components(separatedBy: "\n").first { $0.hasPrefix("簡單說：") })
            print("DEF", name, "→", a.text.replacingOccurrences(of: "\n", with: " ⏎ "))
            XCTAssertTrue(lead.contains(name) && lead.contains(must), lead)
            XCTAssertTrue(lead.hasSuffix("。"), lead)
            XCTAssertLessThanOrEqual(lead.count, 135, lead)
            for junk in ["英語", "ㄒ", "δ", "羅馬化", "…", "（）", "，，", "instant", "；"] { XCTAssertFalse(a.text.contains(junk), junk + " | " + a.text) }
        }
    }

    func testWorkFromRealBriefs() throws {
        let w = try XCTUnwrap(WikiAnswer.work(title: "少年維特的煩惱", brief: Self.brief("少年維特的煩惱")))
        print("WORK", w.text)
        XCTAssertTrue(w.text.contains("歌德") && w.text.contains("📖 故事：") && w.text.contains("綠蒂"), w.text)
        XCTAssertFalse(w.text.contains("德語"), w.text)
        XCTAssertTrue(w.text.contains("🔚 結局：") && w.text.contains("自殺"), w.text)
        // 書名裡有句號：不能從那裡斷句
        let y = try XCTUnwrap(WikiAnswer.work(title: "你的名字", brief: ("你的名字。", "《你的名字。》（日語：君の名は。）是一部2016年日本動畫愛情奇幻片，由新海誠編劇兼執導。\n劇情：住在東京的高中生立花瀧和住在鄉下糸守町的宮水三葉，有一天醒來發現兩人交換了身體。", "u")))
        XCTAssertTrue(y.text.contains("新海誠") && y.text.contains("交換了身體"), y.text)
        // 只有一句介紹也比亂抓好
        let z = try XCTUnwrap(WikiAnswer.work(title: "活著", brief: ("活着", "《活著》是一部中國小說，作者余華，於1993年出版。", "u")))
        XCTAssertTrue(z.text.contains("余華"), z.text)
        let x = try XCTUnwrap(WikiAnswer.work(title: "夏洛特的煩惱", brief: Self.brief("夏洛特的煩惱")))
        print("WORK", x.text)
        XCTAssertTrue(x.text.contains("喜劇電影") && x.text.contains("夏洛") && x.text.contains("重回校園"), x.text)
        XCTAssertFalse(x.text.contains("飾）"), x.text)
        let b = try XCTUnwrap(WikiAnswer.work(title: "百年孤寂", brief: Self.brief("百年孤寂")))
        print("WORK", b.text)
        XCTAssertTrue(b.text.contains("馬奎斯") && b.text.contains("波恩地亞家族"), b.text)
        let s = try XCTUnwrap(WikiAnswer.work(title: "刺激1995", brief: Self.brief("刺激1995")))
        print("WORK", s.text)
        XCTAssertTrue(s.text.contains("安迪") && s.text.contains("監獄"), s.text)
    }
}
