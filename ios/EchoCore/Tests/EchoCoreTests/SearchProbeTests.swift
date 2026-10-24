import XCTest
@testable import EchoCore

/// 搜尋探針（CI 有網路時跑）：同一批問題，用不同的搜尋引擎、不同的寫法（編碼、參數）查，
/// 看哪一種拿到的結果真的跟問題有關。結果寫到 NINESUN_PROBE_OUT。
final class SearchProbeTests: XCTestCase {
    static let queries: [(q: String, key: [String])] = [
        ("少年維特的煩惱 劇情", ["維特"]), ("老人與海 內容簡介", ["老人與海"]), ("台北101 高度", ["101"]),
        ("誰寫了哈利波特", ["哈利"]), ("失眠 怎麼辦", ["失眠"]), ("天空為什麼是藍色的", ["天空", "藍"]),
        ("怎麼煮白飯", ["飯"]), ("神隱少女 劇情", ["神隱"]), ("通貨膨脹是什麼", ["通膨", "通貨膨脹"]), ("三體 小說 內容", ["三體"]),
    ]

    /// 嚴格的網址編碼：只留 ASCII 的英數字（中文一定編碼）
    static func strict(_ s: String) -> String {
        var a = CharacterSet()
        a.insert(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return s.addingPercentEncoding(withAllowedCharacters: a) ?? s
    }

    func testProbe() async throws {
        guard let out = ProcessInfo.processInfo.environment["NINESUN_PROBE_OUT"] else { throw XCTSkip("只在 CI 跑") }
        WebTape.shared = nil
        typealias Engine = (name: String, run: (String) async -> [WebSearch.Hit])
        func rss(_ u: String) async -> [WebSearch.Hit] {
            guard let url = URL(string: u), let x = await WebSearch.text(url, .zh, ua: WebSearch.desktopUA) else { return [] }
            return WebSearch.rssItems(x).map { .init(title: $0.title, snippet: $0.desc, url: $0.link, engine: "rss") }
        }
        let engines: [Engine] = [
            ("bing-rss 現在的寫法", { await WebSearch.bingRSS($0, .zh) }),
            ("bing-rss 嚴格編碼", { await rss("https://www.bing.com/search?format=rss&count=10&q=\(Self.strict($0))&mkt=zh-TW&setlang=zh-TW&cc=TW") }),
            ("bing-rss 嚴格編碼、不帶 mkt", { await rss("https://www.bing.com/search?format=rss&count=10&q=\(Self.strict($0))") }),
            ("bing-rss cn.bing", { await rss("https://cn.bing.com/search?format=rss&count=10&q=\(Self.strict($0))") }),
            ("bing-html 現在的寫法", { await WebSearch.bingHTML($0, .zh) }),
            ("duckduckgo-html", { await WebSearch.ddgHTML($0, .zh) }),
            ("ddg-lite", { await WebSearch.ddgLite($0, .zh) }),
            ("yahoo", { await WebSearch.yahoo($0, .zh) }),
            ("google", { await WebSearch.google($0, .zh) }),
            ("brave", { await WebSearch.brave($0, .zh) }),
            ("mojeek", { await WebSearch.mojeek($0, .zh) }),
            ("baidu", { await WebSearch.baidu($0, .zh) }),
        ]
        var report = "搜尋探針：每一格是「前 8 筆裡跟問題有關的筆數／拿到的筆數」\n\n"
        var total: [String: (Int, Int)] = [:]
        for e in engines {
            report += "== \(e.name)\n"
            for (q, key) in Self.queries {
                let hits = Array(await e.run(q).prefix(8))
                let rel = hits.filter { h in key.contains { (h.title + h.snippet).contains($0) } }.count
                total[e.name, default: (0, 0)].0 += rel
                total[e.name, default: (0, 0)].1 += hits.count
                report += "  \(q)：\(rel)/\(hits.count)  " + hits.prefix(3).map { "〔\($0.title.prefix(18))〕" }.joined() + "\n"
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
        }
        report += "\n總計（有關／拿到）：\n"
        for e in engines { let t = total[e.name] ?? (0, 0); report += "  \(e.name)：\(t.0)/\(t.1)\n" }
        try report.write(toFile: out, atomically: true, encoding: .utf8)
    }
}
