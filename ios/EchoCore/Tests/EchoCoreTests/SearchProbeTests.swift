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
        // 有 cookie 的連線：先開首頁拿 cookie，再查（Bing 可能把沒有 cookie 的當成機器人，給別的查詢的結果）
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage()
        cfg.httpShouldSetCookies = true
        cfg.timeoutIntervalForRequest = 8
        let cookied = URLSession(configuration: cfg)
        func get(_ u: String, ua: String = WebSearch.desktopUA, warm: String? = nil) async -> String? {
            if let w = warm, let wu = URL(string: w) {
                var r = URLRequest(url: wu); r.setValue(ua, forHTTPHeaderField: "User-Agent")
                r.setValue("zh-TW,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
                _ = try? await cookied.data(for: r)
            }
            guard let url = URL(string: u) else { return nil }
            var r = URLRequest(url: url); r.setValue(ua, forHTTPHeaderField: "User-Agent")
            r.setValue("zh-TW,zh;q=0.9,en;q=0.6", forHTTPHeaderField: "Accept-Language")
            r.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            guard let (d, _) = try? await cookied.data(for: r) else { return nil }
            return String(decoding: d, as: UTF8.self)
        }
        /// 不認識的搜尋引擎：把結果頁裡連到別的網站的連結文字當成結果
        func anchors(_ html: String?, own: String) -> [WebSearch.Hit] {
            guard let html, let re = try? NSRegularExpression(pattern: #"<a[^>]+href="(https?://[^"]+)"[^>]*>(.*?)</a>"#, options: [.dotMatchesLineSeparators]) else { return [] }
            var out: [WebSearch.Hit] = []
            for m in re.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
                guard let u = Range(m.range(at: 1), in: html), let t = Range(m.range(at: 2), in: html) else { continue }
                let url = String(html[u]), title = WebSearch.clean(String(html[t]))
                if url.contains(own) || title.count < 6 { continue }
                out.append(.init(title: title, snippet: "", url: url, engine: own))
            }
            return out
        }
        let s = Self.strict
        let engines: [Engine] = [
            ("bing-rss 有 cookie", { await get("https://www.bing.com/search?format=rss&count=10&q=\(s($0))&mkt=zh-TW&setlang=zh-TW", warm: "https://www.bing.com/").map { WebSearch.rssItems($0).map { .init(title: $0.title, snippet: $0.desc, url: $0.link, engine: "rss") } } ?? [] }),
            ("bing-html 有 cookie", { anchors(await get("https://www.bing.com/search?q=\(s($0))&mkt=zh-TW&setlang=zh-TW", warm: "https://www.bing.com/"), own: "bing.") }),
            ("bing-html 手機版有 cookie", { anchors(await get("https://www.bing.com/search?q=\(s($0))&mkt=zh-TW", ua: WebSearch.mobileUA, warm: "https://www.bing.com/"), own: "bing.") }),
            ("sogou", { anchors(await get("https://www.sogou.com/web?query=\(s($0))"), own: "sogou.") }),
            ("360", { anchors(await get("https://www.so.com/s?q=\(s($0))"), own: "so.com") }),
            ("startpage", { anchors(await get("https://www.startpage.com/do/search?q=\(s($0))&language=zh-TW"), own: "startpage.") }),
            ("qwant", { anchors(await get("https://lite.qwant.com/?q=\(s($0))&locale=zh_TW"), own: "qwant.") }),
            ("yandex", { anchors(await get("https://yandex.com/search/?text=\(s($0))"), own: "yandex.") }),
            ("ecosia", { anchors(await get("https://www.ecosia.org/search?q=\(s($0))"), own: "ecosia.") }),
            ("duckduckgo-html 有 cookie", { anchors(await get("https://html.duckduckgo.com/html/?q=\(s($0))&kl=tw-tzh", warm: "https://duckduckgo.com/"), own: "duckduckgo.") }),
            ("yahoo-tw 有 cookie", { anchors(await get("https://tw.search.yahoo.com/search?p=\(s($0))", warm: "https://tw.yahoo.com/"), own: "yahoo.") }),
            ("google 有 cookie", { anchors(await get("https://www.google.com/search?q=\(s($0))&hl=zh-TW&gbv=1", ua: "Lynx/2.9.0 libwww-FM/2.14 SSL-MM/1.4.1", warm: "https://www.google.com/"), own: "google.") }),
            ("bing-rss 現在的寫法", { await WebSearch.bingRSS($0, .zh) }),
            ("baidu", { await WebSearch.baidu($0, .zh) }),
        ]
        var report = "搜尋探針：每一格是「前 8 筆裡跟問題有關的筆數／拿到的筆數」\n\n"
        var total: [String: (Int, Int)] = [:]
        for e in engines {
            report += "== \(e.name)\n"
            for (q, key) in Self.queries {
                let hits = Array(await e.run(q).prefix(8))
                let rel = hits.filter { h in key.contains { WebStrategy.toTraditional(h.title + h.snippet).contains($0) } }.count
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
