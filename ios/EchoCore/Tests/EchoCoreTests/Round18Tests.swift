import XCTest
@testable import EchoCore

/// 第 18 輪：上網考題和大腦考試裡答錯的，照原樣寫成測試
final class Round18Tests: XCTestCase {
    typealias E = Understanding.Evidence

    /// 大腦把「張忠謀」框成「張忠」：後面每次都接同一個字，那個字也是名字
    func testWholeNameTail() {
        let texts = ["今天是台積電創辦人張忠謀94歲大壽", "張忠謀博士表示看好半導體", "1987年張忠謀創辦台積電"]
        XCTAssertEqual(Think.wholeName("張忠", in: texts), "張忠謀")
        // 後面接的是動詞、虛字就不動
        XCTAssertEqual(Think.wholeName("愛因斯坦", in: ["愛因斯坦提出相對論", "由愛因斯坦提出的理論", "愛因斯坦提出了狹義相對論"]), "愛因斯坦")
        XCTAssertEqual(Think.wholeName("玉山", in: ["玉山是台灣最高的山", "玉山是東北亞第一高峰", "玉山是百岳之首"]), "玉山")
    }

    /// 「X 的創辦人是誰」和「X 是誰創辦的」是同一題
    func testFounderByRoleNoun() {
        let pages = [E(text: "編按：今天是台積電創辦人張忠謀94歲大壽。\n台積電創辦人張忠謀博士表示，半導體是關鍵產業。", host: "a.com"),
                     E(text: "張忠謀在1987年創辦台積電，開創晶圓代工模式。", host: "b.com")]
        let a = Think.whoDid(question: "台積電的創辦人是誰", pages: pages, subject: "台積電")
        XCTAssertTrue(a?.hasPrefix("答案：張忠謀") ?? false, a ?? "nil")
    }

    /// 「作者是誰」只認「作者 XXX」：「前後共寫了五年」的「前後共」不是人
    func testAuthorNotVerbPrefix() {
        let junk = [E(text: "她的第一本書《哈利波特—神秘的魔法石》前後共寫了5年。\n哈利波特這套書前後共寫了十七年。", host: "a.com")]
        XCTAssertNil(Think.whoDid(question: "哈利波特的作者是誰", pages: junk, subject: "哈利波特"))
        let good = [E(text: "《哈利波特》的作者J.K.羅琳出生於英國。", host: "a.com"), E(text: "哈利波特系列作者羅琳表示不會再寫續集。", host: "b.com")]
        let a = Think.whoDid(question: "哈利波特的作者是誰", pages: good, subject: "哈利波特")
        XCTAssertTrue(a?.contains("羅琳") ?? false, a ?? "nil")
    }

    /// 一個一個介紹的文章：編號的小標題連起來就是名單；每一項底下重複的小節、別篇文章的標題都不是
    func testNumberedHeadingsAsList() {
        var page = "常見的狗品種介紹\n貴賓狗品種全解析：大小、性格、飼養指南與常見問題\n2025年11月05日\n"
        for (i, n) in ["吉娃娃 (Chihuahua)", "博美犬 (Pomeranian)", "約克夏（Yorkshire Terrier）", "馬爾濟斯 ( Maltese )", "臘腸犬 ( Dachshund )", "柴犬 ( Shiba Inu )"].enumerated() {
            // 每一種底下都有一串毛色：這幾串互相重疊，但不是品種
            page += "\(i + 1).\(n)\n原產地：某地\n1. 外貌特徵\n牠們體型小巧，這種狗品種的常見色為白色、黑色、杏色、灰色\(i % 2 == 0 ? "" : "、米白色")。\n2. 個性\n牠們很活潑。\n"
        }
        let a = Think.plainList(question: "常見的狗品種有哪些", pages: [E(text: page, host: "pets.tw")], subject: "常見的狗品種", noun: "")
        XCTAssertNotNil(a)
        for n in ["吉娃娃", "博美犬", "約克夏", "柴犬"] { XCTAssertTrue(a?.contains(n) ?? false, "\(n)：\(a ?? "nil")") }
        for n in ["性格", "飼養指南", "外貌特徵", "個性", "白色", "杏色"] { XCTAssertFalse(a?.contains(n) ?? true, "\(n)：\(a ?? "nil")") }
    }

    /// 互相重疊的幾串是同一種名單；跟誰都不重疊的（用途）不是。上一句講主題、這句用「包括」接下去也算
    func testOverlappingRunsAndContinuation() {
        let pages = [E(text: "在程式設計世界中，有幾種流行的程式語言。最常見的一些包括 Java、C++、Python 和 JavaScript。\n常見的程式語言用於網路開發的有 HTML、CSS、JavaScript、PHP。\nPython 這種程式語言廣泛應用於網路開發、資料分析、人工智慧和機器學習。", host: "a.com"),
                     E(text: "C、Java 和 Python 都是程式設計領域常見的程式語言。\n初學者常見的程式語言有 Python、JavaScript、Java、C#。", host: "b.com")]
        let a = Think.plainList(question: "常見的程式語言有哪些", pages: pages, subject: "常見的程式語言", noun: "")
        XCTAssertNotNil(a)
        for n in ["Python", "Java", "JavaScript"] { XCTAssertTrue(a?.contains(n) ?? false, "\(n)：\(a ?? "nil")") }
        for n in ["人工智慧", "資料分析"] { XCTAssertFalse(a?.contains(n) ?? true, "\(n)：\(a ?? "nil")") }
    }

    /// 「X 代表什麼」：先講它代表什麼的那句；否定句不算
    func testMeaningSentence() {
        let pages = [(host: "wiki.org", text: "奧林匹克五環於1913年由顧拜旦設計。1979年，國際奧委會出版的《奧林匹克評論》中指出：五環象徵 五大洲 的團結，全世界的運動員在奧運會上相見。各大洲並非由特定色環所代表。"),
                     (host: "b.com", text: "奧運五環代表五大洲的團結與友誼。")]
        let m = Synthesize.meaning(question: "奧運的五環代表什麼", subject: "奧運的五環", pages: pages)
        XCTAssertTrue(m?.text.contains("五大洲") ?? false, m?.text ?? "nil")
        XCTAssertEqual(m?.hosts.count, 2)
        XCTAssertNil(Synthesize.meaning(question: "奧運的五環是誰設計的", subject: "奧運的五環", pages: pages))
    }

    /// 問「大城市」卻拿到八十個的表：只列前面十二個
    func testTopOfTable() {
        let names = (1...30).map { "城市\($0)市" }
        let text = "一共找到 30 個大城市：\n" + Countries.lines(names) + "\n（名單整理自 wiki.org；不同資料的算法可能略有差異）"
        let t = WebAgent.topOfTable(text, question: "日本有哪些大城市")
        XCTAssertTrue(t.contains("表上一共 30 個"), t)
        XCTAssertTrue(t.contains("城市12市") && !t.contains("城市13市"), t)
        XCTAssertTrue(t.contains("名單整理自 wiki.org"), t)
        // 沒有「大、主要」這種字的問題要完整的名單
        XCTAssertEqual(WebAgent.topOfTable(text, question: "日本有哪些城市"), text)
    }

    /// 一個網站把 GDP 寫成「國民生產毛額」，其他地方都寫「國內生產毛額」：用大家寫的那個
    func testAcronymNameByAgreement() {
        let pages = [(host: "a.com", text: "什麼是國內生產毛額（GDP）？一本國家的經濟成績單\n國內生產毛額（Gross Domestic Product），簡稱GDP，是衡量一個國家或地區經濟活動的指標。"),
                     (host: "b.com", text: "GDP（Gross Domestic Product，國民生產毛額）是用來衡量一個國家生產力的重要總經數據，也代表一個國家的經濟成長率。"),
                     (host: "c.com", text: "國內生產毛額(GDP)是一定時期內一個地區生產的所有最終商品和服務的市場價值。\n實質國內生產毛額（GDP）扣掉了物價的影響。")]
        XCTAssertEqual(Synthesize.acronymName("GDP", pages: pages), "國內生產毛額")
        XCTAssertNil(Synthesize.acronymName("玉山", pages: pages))
        let a = Synthesize.compose(question: "什麼是GDP", subject: "GDP", want: .definition, pages: pages)
        XCTAssertTrue(a?.components(separatedBy: "\n").first?.contains("國內生產毛額") ?? false, a ?? "nil")
    }

    /// 「推薦什麼方法」要的是做法，不是幾個字的答案
    func testRecommendMethodIsAdvice() {
        if case .steps = Understanding.frame("學日文推薦什麼方法").want {} else { XCTFail("\(Understanding.frame("學日文推薦什麼方法").want)") }
    }
}
