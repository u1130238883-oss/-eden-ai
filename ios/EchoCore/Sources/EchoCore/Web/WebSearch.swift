import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 上網查資料（全部免費、不需要任何金鑰）。
/// 同時問好幾個來源，誰有結果就用誰：
///   Bing（RSS 與網頁）、DuckDuckGo（網頁、輕量版與即時答案）、Brave、Mojeek、百度、Yahoo、Google（基本版網頁）、維基百科、Google 新聞 RSS、Open-Meteo 天氣。
/// 每一次都是即時上網查，不在手機裡存舊答案。
public enum WebSearch {
    public struct Hit: Equatable, Sendable, Codable {
        public let title: String
        public let snippet: String
        public let url: String
        /// 哪個搜尋來源找到的
        public let engine: String
        public init(title: String, snippet: String, url: String, engine: String) {
            self.title = title; self.snippet = snippet; self.url = url; self.engine = engine
        }
    }

    public struct Answer: Codable {
        /// 直接的答案（即時答案、維基百科摘要、天氣）
        public var lead: String?
        public var leadSource: String?
        public var hits: [Hit]
        /// 每個來源找到幾筆（診斷用）
        public var engines: [String: Int]
    }

    static let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
    static let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

    static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 6
        c.timeoutIntervalForResource = 9
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.urlCache = nil
        c.httpShouldSetCookies = false
        c.httpMaximumConnectionsPerHost = 3
        return URLSession(configuration: c)
    }()

    /// 維基百科（和它的鏡像站）：不讀。條目太長、什麼都講，NineSun 在裡面抓不到重點
    /// （問「少年維特的煩惱講了什麼」，抓到的是頁尾的「參見…外部連結」和翻譯版本）；改讀書評、影評、專門介紹的網站
    public static func isWiki(_ url: String) -> Bool {
        let h = (URL(string: url)?.host ?? url).lowercased()
        return ["wikipedia.org", "wikiwand.com", "wiki.kfd.me", "wikimedia.org", "wikiwiki.jp", "wikisource.org"].contains { h.contains($0) }
    }

    static func withoutWiki(_ a: Answer) -> Answer {
        let wikiLead = a.leadSource.map(isWiki) ?? false
        var engines = a.engines
        engines["wikipedia"] = nil
        return Answer(lead: wikiLead ? nil : a.lead, leadSource: wikiLead ? nil : a.leadSource, hits: a.hits.filter { !isWiki($0.url) }, engines: engines)
    }

    /// 同時問所有來源，合併去重
    /// light：只問 Bing（拆成好幾個方面分開查的時候用，比較快）
    public static func search(_ q: String, lang L: Lang, news: Bool = false, light: Bool = false) async -> Answer {
        // 錄音帶：重播時直接用錄下來的結果；錄音時照常上網，再把結果記下來
        if let tape = WebTape.shared {
            if tape.replaying { return withoutWiki(tape.search(q, L, news: news, light: light) ?? Answer(lead: nil, leadSource: nil, hits: [], engines: [:])) }
            let a = await liveSearch(q, lang: L, news: news, light: light)
            tape.record(q, L, news: news, light: light, a)
            return withoutWiki(a)
        }
        return withoutWiki(await liveSearch(q, lang: L, news: news, light: light))
    }

    /// 這批結果有幾筆跟查詢有關（標題、摘要裡有查詢的雙字詞；簡體先轉繁體）
    static func relevant(_ hits: [Hit], _ q: String) -> Int {
        let g = Think.grams(q.components(separatedBy: " (site:").first ?? q).filter { !$0.contains(where: { $0.isASCII && !$0.isLetter && !$0.isNumber }) }
        guard !g.isEmpty else { return hits.count }
        return hits.filter { h in
            let t = Think.canonText(WebStrategy.toTraditional(h.title + " " + h.snippet)).lowercased()
            return g.contains { t.contains($0.lowercased()) }
        }.count
    }

    /// 搜尋引擎給了一整批跟查詢無關的結果（Bing 常把別人查的東西給機器人：問小說給股價、問失眠給披薩），整批不要
    static func poisoned(_ hits: [Hit], _ q: String) -> Bool { hits.count >= 4 && relevant(hits, q) == 0 }

    static func liveSearch(_ q: String, lang L: Lang, news: Bool, light: Bool) async -> Answer {
        if light {
            // 小問題：先問 DuckDuckGo（有 cookie）和百度——在 GitHub 的機器上試過，只有這兩個給的結果跟問題有關；
            // Bing 常給別人查的東西（問小說給股價），放到最後、而且整批無關就不要
            async let dd = soon(4, [], { await ddgHTML(q, L) })
            let d: [Hit] = await soon(4, [], { await baidu(q, L) })
            var a = await dd
            if relevant(a + d, q) < 3 {
                let bing = await soon(4, [], { await bingRSS(q, L) })
                if !poisoned(bing, q) { a += bing }
            }
            let b: [Hit] = a.count + d.count < 3 ? await soon(3, [], { await yahoo(q, L) }) : []
            let c: [Hit] = a.count + b.count + d.count < 3 ? await soon(3, [], { await ddgLite(q, L) }) : []
            // 都給不出什麼：不放棄，再問 Google
            let g: [Hit] = a.count + b.count + d.count < 3 ? await soon(3, [], { await google(q, L) }) : []
            var seen = Set<String>()
            var hits: [Hit] = []
            for i in 0..<max(a.count, b.count, c.count, d.count, g.count) {
                for l in [a, d, c, b, g] where i < l.count && seen.insert(normURL(l[i].url)).inserted { hits.append(l[i]) }
            }
            return Answer(lead: nil, leadSource: nil, hits: Array(hits.prefix(10)),
                          engines: ["bing": a.filter { $0.engine == "Bing" }.count, "yahoo": b.count, "ddg-lite": c.count, "google": g.count, "baidu": d.count, "duckduckgo": a.filter { $0.engine == "DuckDuckGo" }.count])
        }
        async let inst = soon(3, nil, { await ddgInstant(q, L) })
        async let wx = weatherIf(q, L)
        async let fx = exchangeIf(q, L)
        async let mk = marketIf(q, L)

        // 各來源一起問；結果夠用了就不再等慢吞吞的來源（以前常常為了一個來源卡 6 秒）
        var got: [String: [Hit]] = [:]
        await withTaskGroup(of: (String, [Hit]).self) { g in
            g.addTask { ("news", await newsIf(news, q, L)) }
            g.addTask { ("bing", await bingRSS(q, L)) }
            g.addTask { ("bing-web", await bingHTML(q, L)) }
            g.addTask { ("duckduckgo", await ddgHTML(q, L)) }
            g.addTask { ("yahoo", await yahoo(q, L)) }
            g.addTask { ("google", await google(q, L)) }
            g.addTask { ("ddg-lite", await ddgLite(q, L)) }
            g.addTask { ("mojeek", await mojeek(q, L)) }
            g.addTask { ("brave", await brave(q, L)) }
            g.addTask { ("baidu", await baidu(q, L)) }
            g.addTask { try? await Task.sleep(nanoseconds: 2_500_000_000); return ("_soft", []) }
            g.addTask { try? await Task.sleep(nanoseconds: 4_000_000_000); return ("_late", []) }
            var waiting = 10
            while waiting > 0, let r = await g.next() {
                let (name, l) = r
                if name.hasPrefix("_") {
                    let have = got.values.reduce(0) { $0 + $1.count }
                    // 2.5 秒時已經有 6 筆以上、4 秒時有任何結果，就先用手上的
                    if have >= (name == "_soft" ? 6 : 1) { break }
                    continue
                }
                got[name] = l
                waiting -= 1
            }
            g.cancelAll()
        }
        // 跟查詢無關的整批結果不要（新聞不算：標題常常不重複查詢的字）
        let lists: [(String, [Hit])] = ["news", "duckduckgo", "baidu", "ddg-lite", "brave", "mojeek", "yahoo", "google", "bing", "bing-web"]
            .map { ($0, got[$0] ?? []) }.map { ($0.0, $0.0 != "news" && poisoned($0.1, q) ? [] : $0.1) }
        var engines: [String: Int] = [:]
        var hits: [Hit] = []
        var seen = Set<String>()
        // 交錯合併：每個來源輪流拿一筆，避免被單一來源洗版
        let maxLen = lists.map { $0.1.count }.max() ?? 0
        for (name, l) in lists { engines[name] = l.count }
        for i in 0..<maxLen {
            for (_, l) in lists where i < l.count {
                let h = l[i]
                let key = normURL(h.url)
                guard !h.snippet.isEmpty || !h.title.isEmpty, seen.insert(key).inserted else { continue }
                hits.append(h)
            }
        }

        var lead: String?, leadSource: String?
        if let w = await wx { lead = w; leadSource = "open-meteo.com" }
        if lead == nil, let f = await fx { lead = f; leadSource = "open.er-api.com" }
        if lead == nil, let m = await mk { lead = m; leadSource = "finance.yahoo.com" }
        if lead == nil, let a = await inst { lead = a.text; leadSource = a.source }
        engines["instant"] = lead == nil ? 0 : 1
        if wantsWeather(q) { engines["weather"] = leadSource == "open-meteo.com" ? 1 : 0 }
        return Answer(lead: lead.map { clip($0, 320) }, leadSource: leadSource, hits: Array(hits.prefix(10)), engines: engines)
    }

    /// 最多等 seconds 秒；來不及就用 fallback（慢的來源不要拖住整個回答）
    static func soon<T: Sendable>(_ seconds: Double, _ fallback: T, _ op: @escaping @Sendable () async -> T) async -> T {
        await withTaskGroup(of: T?.self) { g in
            g.addTask { await op() }
            g.addTask { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)); return nil }
            let first = await g.next() ?? nil
            g.cancelAll()
            return first ?? fallback
        }
    }

    // MARK: - Bing

    /// Bing 的 RSS 格式最穩定（純 XML，不會因為改版而抓不到）
    static func bingRSS(_ q: String, _ L: Lang) async -> [Hit] {
        let mkt = market(L)
        guard let url = URL(string: "https://www.bing.com/search?format=rss&count=10&q=\(enc(q))&mkt=\(mkt)&setlang=\(mkt)&cc=\(mkt.suffix(2))"),
              let xml = await text(url, L, ua: desktopUA) else { return [] }
        return rssItems(xml).map { Hit(title: $0.title, snippet: $0.desc, url: $0.link, engine: "Bing") }
            .filter { !$0.url.contains("bing.com/") }
            .prefix(8).map { $0 }
    }

    static func bingHTML(_ q: String, _ L: Lang) async -> [Hit] {
        let mkt = market(L)
        guard let url = URL(string: "https://www.bing.com/search?q=\(enc(q))&mkt=\(mkt)&setlang=\(mkt)"),
              let html = await text(url, L, ua: desktopUA) else { return [] }
        var out: [Hit] = []
        for block in html.components(separatedBy: "class=\"b_algo\"").dropFirst() {
            guard let href = first(#"<h2[^>]*>\s*<a[^>]*href="([^"]+)""#, block, group: 1),
                  let title = first(#"<h2[^>]*>\s*<a[^>]*>(.*?)</a>"#, block, group: 1) else { continue }
            let snip = first(#"<p[^>]*>(.*?)</p>"#, block, group: 1)
                ?? first(#"class="b_caption"[^>]*>(.*?)</div>"#, block, group: 1) ?? ""
            let link = bingRealURL(href.replacingOccurrences(of: "&amp;", with: "&"))
            out.append(Hit(title: clean(title), snippet: clean(snip), url: link, engine: "Bing"))
            if out.count >= 8 { break }
        }
        return out
    }

    /// Bing 的追蹤連結（bing.com/ck/a?...&u=a1<base64>）→ 原網址
    static func bingRealURL(_ href: String) -> String {
        guard href.contains("bing.com/ck/"), let c = URLComponents(string: href),
              var u = c.queryItems?.first(where: { $0.name == "u" })?.value, u.hasPrefix("a1") else { return href }
        u.removeFirst(2)
        u = u.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while u.count % 4 != 0 { u += "=" }
        if let d = Data(base64Encoded: u), let s = String(data: d, encoding: .utf8), s.hasPrefix("http") { return s }
        return href
    }

    // MARK: - Google（基本版網頁，結果連結是 /url?q=原網址；Google 擋自動查詢時就沒有結果，其他來源照常）

    static func google(_ q: String, _ L: Lang) async -> [Hit] {
        let hl = L == .zh ? "zh-TW" : L.rawValue
        guard let url = URL(string: "https://www.google.com/search?q=\(enc(q))&hl=\(hl)&gbv=1&num=10&ie=UTF-8"),
              let html = await text(url, L, ua: "Lynx/2.9.0 libwww-FM/2.14 SSL-MM/1.4.1") else { return [] }
        return googleResults(html)
    }

    /// 從 Google 基本版網頁抓出結果（標題、摘要、原網址）
    static func googleResults(_ html: String) -> [Hit] {
        var out: [Hit] = []
        var seen = Set<String>()
        for block in html.components(separatedBy: "href=\"/url?q=").dropFirst() {
            guard let end = block.firstIndex(where: { $0 == "&" || $0 == "\"" }) else { continue }
            let raw = String(block[..<end])
            let link = raw.removingPercentEncoding ?? raw
            guard link.hasPrefix("http"), !host(link).hasSuffix("google.com"), seen.insert(link).inserted else { continue }
            guard let title = first(#"<h3[^>]*>(.*?)</h3>"#, block, group: 1).map(clean), !title.isEmpty else { continue }
            var snip = ""
            if let a = block.range(of: "</a>") { snip = clean(String(block[a.upperBound...])) }
            if snip.hasSuffix("<a") { snip = String(snip.dropLast(2)).trimmingCharacters(in: .whitespaces) }  // 下一個結果的開頭
            out.append(Hit(title: title, snippet: clip(snip, 300), url: link, engine: "Google"))
            if out.count >= 8 { break }
        }
        return out
    }

    // MARK: - Yahoo（台灣用 tw.search.yahoo.com）

    static func yahoo(_ q: String, _ L: Lang) async -> [Hit] {
        let host = L == .zh ? "tw.search.yahoo.com" : "search.yahoo.com"
        guard let url = URL(string: "https://\(host)/search?p=\(enc(q))&ei=UTF-8"),
              let html = await text(url, L, ua: desktopUA) else { return [] }
        var out: [Hit] = []
        for block in html.components(separatedBy: "class=\"compTitle").dropFirst() {
            guard let href = first(#"<a[^>]*href="([^"]+)""#, block, group: 1),
                  let title = first(#"<a[^>]*>(.*?)</a>"#, block, group: 1) else { continue }
            let snip = first(#"class="compText[^"]*"[^>]*>(.*?)</div>"#, block, group: 1) ?? ""
            let link = yahooRealURL(href.replacingOccurrences(of: "&amp;", with: "&"))
            if link.contains("yahoo.com") && !link.contains("tw.news.yahoo") && !link.contains("tw.stock.yahoo") { continue }
            let t = clean(title)
            if t.isEmpty { continue }
            out.append(Hit(title: t, snippet: clean(snip), url: link, engine: "Yahoo"))
            if out.count >= 8 { break }
        }
        return out
    }

    /// Yahoo 的轉址連結（.../RU=<網址>/RK=...）→ 原網址
    static func yahooRealURL(_ href: String) -> String {
        guard let r = href.range(of: "/RU=") else { return href }
        var rest = String(href[r.upperBound...])
        if let e = rest.range(of: "/RK=") { rest = String(rest[..<e.lowerBound]) }
        return rest.removingPercentEncoding ?? rest
    }

    // MARK: - DuckDuckGo

    /// 有 cookie 的連線（只在記憶體裡、App 關掉就沒了）：DuckDuckGo 要先開過首頁拿到 cookie，查詢才會給結果
    static let cookieSession: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 6
        c.timeoutIntervalForResource = 9
        c.httpShouldSetCookies = true
        c.httpCookieAcceptPolicy = .always
        c.urlCache = nil
        return URLSession(configuration: c)
    }()
    /// 像人一樣慢慢查：每個搜尋引擎短時間內只問幾次（一題常常同時有 6～10 組查詢，一起丟過去會被當成機器人擋掉）；
    /// 被擋（驗證頁、429）就先停一陣子，不要一直問、越擋越久
    final class Pace: @unchecked Sendable {
        let capacity: Double, refill: Double, rest: TimeInterval
        private var tokens: Double, last = Date(), blockedUntil = Date.distantPast
        private let lock = NSLock()
        init(capacity: Double, perSecond refill: Double, rest: TimeInterval) {
            self.capacity = capacity; self.refill = refill; self.rest = rest; tokens = capacity
        }
        /// 現在可以問嗎（可以就用掉一次）
        func take(now: Date = Date()) -> Bool {
            lock.lock(); defer { lock.unlock() }
            if now < blockedUntil { return false }
            tokens = min(capacity, tokens + now.timeIntervalSince(last) * refill)
            last = now
            guard tokens >= 1 else { return false }
            tokens -= 1
            return true
        }
        func blocked(now: Date = Date()) { lock.lock(); blockedUntil = now.addingTimeInterval(rest); tokens = 0; lock.unlock() }
        var resting: Bool { lock.lock(); defer { lock.unlock() }; return Date() < blockedUntil }
    }
    static let ddgPace = Pace(capacity: 4, perSecond: 1.0 / 4, rest: 120)
    /// 有用的搜尋引擎（DuckDuckGo、百度）都在休息：剛剛查太多次被擋了
    public static var resting: Bool { ddgPace.resting && baiduPace.resting }
    static let baiduPace = Pace(capacity: 3, perSecond: 1.0 / 4, rest: 180)

    /// 搜尋引擎回的是「你是機器人嗎」的驗證頁
    static func isBlockPage(_ html: String) -> Bool {
        ["anomaly-modal", "anomaly.js", "captcha", "Unfortunately, bots use DuckDuckGo", "wappass.baidu.com", "安全验证", "百度安全验证", "verify you are human"]
            .contains { html.contains($0) }
    }

    private static let warmLock = NSLock()
    nonisolated(unsafe) private static var warmed = false

    /// DuckDuckGo：先開首頁拿 cookie，再用一般的網址查。
    /// 在 GitHub 的機器上試過：這樣 80 筆裡有 67 筆跟問題有關（以前沒有 cookie、用 POST 查，一筆都拿不到；Bing 給的是別人查的東西）
    static func ddgHTML(_ q: String, _ L: Lang) async -> [Hit] {
        let region = ["zh": "tw-tzh", "en": "us-en", "es": "es-es", "it": "it-it"][L.rawValue] ?? "wt-wt"
        guard ddgPace.take() else { return [] }
        func get(_ u: String) async -> String? {
            guard let url = URL(string: u) else { return nil }
            var req = request(url, L, ua: desktopUA)
            req.setValue("https://duckduckgo.com/", forHTTPHeaderField: "Referer")
            guard let (d, resp) = try? await cookieSession.data(for: req) else { return nil }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 200
            let html = String(data: d, encoding: .utf8) ?? String(decoding: d, as: UTF8.self)
            // 被擋了：先休息，不要一直問
            if code == 429 || code == 403 || (code == 202 && !html.contains("result__")) || isBlockPage(html) { ddgPace.blocked(); return nil }
            return code < 400 ? html : nil
        }
        let needWarm: Bool = { warmLock.lock(); defer { warmLock.unlock() }; return !warmed }()
        if needWarm {
            _ = await get("https://duckduckgo.com/")
            warmLock.lock(); warmed = true; warmLock.unlock()
        }
        guard let html = await get("https://html.duckduckgo.com/html/?q=\(enc(q))&kl=\(region)") else {
            warmLock.lock(); warmed = false; warmLock.unlock()
            return []
        }
        var out: [Hit] = []
        for block in html.components(separatedBy: "result__body").dropFirst() {
            if block.contains("result--ad") || block.contains("badge--ad") { continue }
            guard let tag = first(#"<a[^>]*class="result__a"[^>]*>"#, block),
                  let href = first(#"href="([^"]+)""#, tag, group: 1),
                  let title = first(#"class="result__a"[^>]*>(.*?)</a>"#, block, group: 1) else { continue }
            let snip = first(#"class="result__snippet"[^>]*>(.*?)</(?:a|div|td)>"#, block, group: 1) ?? ""
            let link = ddgRealURL(href)
            if link.contains("duckduckgo.com/y.js") { continue }
            out.append(Hit(title: clean(title), snippet: clean(snip), url: link, engine: "DuckDuckGo"))
            if out.count >= 8 { break }
        }
        // 版面改了、抓不到結果的區塊：改用通用的解析（連到別的網站的連結）
        if out.isEmpty {
            let fixed = html.replacingOccurrences(of: "href=\"//duckduckgo.com/l/?", with: "href=\"https://duckduckgo.com/l/?")
            out = genericResults(fixed, engine: "duckduckgo.com", name: "DuckDuckGo").map {
                Hit(title: $0.title, snippet: $0.snippet, url: ddgRealURL($0.url), engine: $0.engine)
            }
        }
        // 沒有結果：下次重新拿 cookie
        if out.isEmpty { warmLock.lock(); warmed = false; warmLock.unlock() }
        return out
    }

    // MARK: - 更多來源（多看幾個網站才能比對；某些來源被擋時，其他的還能用）

    /// 通用的結果解析：不靠網站的 CSS 名稱（常常改版），找「連到別的網站、文字夠長的連結」當標題，
    /// 它後面一小段文字當摘要。engine：搜尋引擎自己的網域（自己的連結不算結果）
    static func genericResults(_ html: String, engine: String, skip: [String] = [], name: String) -> [Hit] {
        guard let re = try? NSRegularExpression(pattern: #"<a\b[^>]*href="(https?://[^"]+)"[^>]*>(.*?)</a>"#, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let ns = html as NSString
        let ms = re.matches(in: html, range: NSRange(location: 0, length: ns.length))
        var out: [Hit] = [], seen = Set<String>()
        let bad = [engine, "google.", "bing.", "microsoft.", "apple.com", "facebook.", "twitter.", "x.com", "instagram.", "youtube.com/@", "javascript:"] + skip
        for (k, m) in ms.enumerated() {
            let url = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: "&amp;", with: "&")
            let title = clean(ns.substring(with: m.range(at: 2)))
            let h = host(url)
            guard title.count >= 6, !bad.contains(where: { h.contains($0) || url.hasPrefix($0) }),
                  seen.insert(normURL(url)).inserted else { continue }
            // 摘要：這個連結後面、到下一個結果之前的文字
            let from = m.range.location + m.range.length
            let to = k + 1 < ms.count ? ms[k + 1].range.location : min(ns.length, from + 1500)
            var snip = to > from ? clean(ns.substring(with: NSRange(location: from, length: min(to - from, 1500)))) : ""
            if snip.count > 200 { snip = String(snip.prefix(200)) }
            // 網址本身、麵包屑當摘要沒意義
            if snip.hasPrefix(h) || snip.hasPrefix("http") { snip = "" }
            out.append(Hit(title: title, snippet: snip, url: url, engine: name))
            if out.count >= 8 { break }
        }
        return out
    }

    /// DuckDuckGo 輕量版（一般版被擋時這個常常還能用）
    static func ddgLite(_ q: String, _ L: Lang) async -> [Hit] {
        let region = ["zh": "tw-tzh", "en": "us-en", "es": "es-es", "it": "it-it"][L.rawValue] ?? "wt-wt"
        // 跟一般版是同一家：一起算次數，不然一題就問了 DuckDuckGo 兩倍
        guard ddgPace.take(), let url = URL(string: "https://lite.duckduckgo.com/lite/?q=\(enc(q))&kl=\(region)"),
              let html = await text(url, L, ua: desktopUA) else { return [] }
        if isBlockPage(html) { ddgPace.blocked(); return [] }
        let fixed = html.replacingOccurrences(of: "href=\"//duckduckgo.com/l/?", with: "href=\"https://duckduckgo.com/l/?")
        return genericResults(fixed, engine: "duckduckgo.com", name: "DuckDuckGo").map {
            Hit(title: $0.title, snippet: $0.snippet, url: ddgRealURL($0.url), engine: $0.engine)
        }
    }

    /// Mojeek（獨立的搜尋引擎，不太擋程式）
    static func mojeek(_ q: String, _ L: Lang) async -> [Hit] {
        let lang = ["zh": "zh", "en": "en", "es": "es", "it": "it"][L.rawValue] ?? "en"
        guard let url = URL(string: "https://www.mojeek.com/search?q=\(enc(q))&lb=\(lang)"),
              let html = await text(url, L, ua: desktopUA) else { return [] }
        return genericResults(html, engine: "mojeek.com", name: "Mojeek")
    }

    /// Brave 搜尋
    static func brave(_ q: String, _ L: Lang) async -> [Hit] {
        guard let url = URL(string: "https://search.brave.com/search?q=\(enc(q))&source=web"),
              let html = await text(url, L, ua: desktopUA) else { return [] }
        return genericResults(html, engine: "brave.com", skip: ["imgs.search.brave"], name: "Brave")
    }

    /// 百度：中文的生活、做法類網站多（知乎、百度經驗、各種教學）；簡體會再轉成繁體
    static func baidu(_ q: String, _ L: Lang) async -> [Hit] {
        guard L == .zh, baiduPace.take(), let url = URL(string: "https://www.baidu.com/s?wd=\(enc(q))&rn=10"),
              let html = await text(url, L, ua: desktopUA) else { return [] }
        if isBlockPage(html) { baiduPace.blocked(); return [] }
        var out: [Hit] = []
        // 每一筆結果的容器上有 mu="原網址"
        for block in html.components(separatedBy: "class=\"result c-container").dropFirst() {
            guard let real = first(#"mu="(https?://[^"]+)""#, block, group: 1) ?? first(#"<h3[^>]*>\s*<a[^>]*href="(https?://[^"]+)""#, block, group: 1),
                  let title = first(#"<h3[^>]*>(.*?)</h3>"#, block, group: 1) else { continue }
            let snip = first(#"class="[^"]*content-right[^"]*"[^>]*>(.*?)</span>"#, block, group: 1)
                ?? first(#"class="c-abstract[^"]*"[^>]*>(.*?)</div>"#, block, group: 1) ?? ""
            out.append(Hit(title: clean(title), snippet: clean(snip), url: real, engine: "Baidu"))
            if out.count >= 8 { break }
        }
        return out
    }

    static func ddgInstant(_ q: String, _ L: Lang) async -> (text: String, source: String)? {
        guard let url = URL(string: "https://api.duckduckgo.com/?format=json&no_html=1&skip_disambig=1&no_redirect=1&q=\(enc(q))"),
              let d = await data(request(url, L, ua: desktopUA)),
              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        if let a = obj["Answer"] as? String, !a.isEmpty { return (clean(a), "duckduckgo.com") }
        if let a = obj["AbstractText"] as? String, a.count > 20 {
            return (a, host(obj["AbstractURL"] as? String ?? "duckduckgo.com"))
        }
        return nil
    }

    /// DuckDuckGo 的轉址連結 → 原網址
    static func ddgRealURL(_ href: String) -> String {
        let h = href.replacingOccurrences(of: "&amp;", with: "&")
        let full = h.hasPrefix("//") ? "https:" + h : h
        if let c = URLComponents(string: full), let u = c.queryItems?.first(where: { $0.name == "uddg" })?.value { return u }
        return full
    }

    // MARK: - 維基百科（中文用台灣正體）

    /// 維基百科要用關鍵詞查，整句問題查不到（「誰發明了電話」→「發明 電話」、「地球到月亮有多遠」→「地球 月亮」）
    public static func wikiTerm(_ q: String) -> String {
        var t = q
        // 問多遠、多高：百科裡寫的是「距離」「高度」，把這個詞補上才找得到對的條目（不然「地球 月亮」會找到超級月亮）
        let hint = [("多遠", "距離"), ("多高", "高度"), ("多重", "質量"), ("多深", "深度"), ("多長", "長度")].first { q.contains($0.0) }?.1
        for w in ["是哪裡", "在哪裡", "是哪一個", "是哪個", "有多遠", "有多高", "有多大", "有多少", "有多長", "有多久", "是多少", "是什麼", "是誰",
                  "為什麼", "怎麼樣", "怎麼", "如何", "哪些", "哪裡", "哪個", "什麼", "多少", "多遠", "多高", "多大", "多久",
                  "誰", "嗎", "呢", "了", "的", "是", "要", "會", "有"] {
            t = t.replacingOccurrences(of: w, with: " ")
        }
        for w in ["到", "和", "跟", "與", "及"] { t = t.replacingOccurrences(of: w, with: " ") }
        var out = t.split(separator: " ").map(String.init).filter { !$0.isEmpty }.joined(separator: " ")
        if let hint, out.count >= 2, !out.contains(hint) { out += " " + hint }
        return out.count >= 2 ? out : q
    }

    static func wikiHost(_ L: Lang) -> String { "\(L.rawValue).wikipedia.org" }

    static func wikiSearch(_ q: String, _ L: Lang) async -> [Hit] {
        let host = wikiHost(L)
        let variant = L == .zh ? "&variant=zh-tw&uselang=zh-tw" : ""
        guard let url = URL(string: "https://\(host)/w/api.php?action=query&generator=search&gsrlimit=4&gsrsearch=\(enc(q))&prop=extracts&exintro=1&explaintext=1&exsentences=3&exlimit=4&format=json&utf8=1\(variant)"),
              let d = await data(request(url, L, ua: desktopUA)),
              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let pages = (obj["query"] as? [String: Any])?["pages"] as? [String: [String: Any]] else { return [] }
        return pages.values
            .sorted { ($0["index"] as? Int ?? 99) < ($1["index"] as? Int ?? 99) }
            .compactMap { p in
                guard let t = p["title"] as? String else { return nil }
                let ex = (p["extract"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let path = t.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? t
                let zh = L == .zh ? "zh-tw/" : "wiki/"
                return Hit(title: t, snippet: clip(ex, 300), url: "https://\(host)/\(zh)\(path)", engine: "Wikipedia")
            }
    }

    static func wikiSummary(_ q: String, _ L: Lang) async -> (title: String, extract: String, url: String)? {
        let host = wikiHost(L)
        guard let s = URL(string: "https://\(host)/w/api.php?action=opensearch&limit=1&format=json&search=\(enc(q))"),
              let d = await data(request(s, L, ua: desktopUA)),
              let arr = try? JSONSerialization.jsonObject(with: d) as? [Any], arr.count > 1,
              let title = (arr[1] as? [String])?.first,
              let path = title.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let u = URL(string: "https://\(host)/api/rest_v1/page/summary/\(path)") else { return nil }
        var req = request(u, L, ua: desktopUA)
        req.setValue(L == .zh ? "zh-tw" : L.rawValue, forHTTPHeaderField: "Accept-Language")
        guard let sd = await data(req), let obj = try? JSONSerialization.jsonObject(with: sd) as? [String: Any],
              let ex = obj["extract"] as? String, !ex.isEmpty else { return nil }
        let page = ((obj["content_urls"] as? [String: Any])?["mobile"] as? [String: Any])?["page"] as? String
        return (obj["title"] as? String ?? title, ex, page ?? "https://\(host)/wiki/\(path)")
    }

    // MARK: - 新聞

    static func googleNews(_ q: String, _ L: Lang) async -> [Hit] {
        let p: (String, String, String) = [
            Lang.zh: ("zh-TW", "TW", "TW:zh-Hant"), .en: ("en-US", "US", "US:en"),
            .es: ("es-419", "US", "US:es-419"), .it: ("it", "IT", "IT:it"),
        ][L]!
        guard let url = URL(string: "https://news.google.com/rss/search?q=\(enc(q))&hl=\(p.0)&gl=\(p.1)&ceid=\(enc(p.2))"),
              let xml = await text(url, L, ua: desktopUA) else { return [] }
        return rssItems(xml).prefix(6).map { item in
            let date = item.date.map { " · " + shortDate($0) } ?? ""
            return Hit(title: item.title, snippet: item.title + date, url: item.link, engine: "Google 新聞")
        }
    }

    static func newsIf(_ on: Bool, _ q: String, _ L: Lang) async -> [Hit] {
        on ? await googleNews(q, L) : []
    }

    static func shortDate(_ rfc: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let d = f.date(from: rfc) else { return rfc }
        let o = DateFormatter()
        o.dateFormat = "M/d HH:mm"
        return o.string(from: d)
    }

    // MARK: - 天氣（Open-Meteo，免費、不需要金鑰）

    static let weatherWords = ["天氣", "氣溫", "溫度", "下雨", "會不會下雨", "weather", "temperature", "clima", "tiempo en", "meteo", "tempo a"]

    public static func wantsWeather(_ q: String) -> Bool {
        let l = q.lowercased()
        return weatherWords.contains { l.contains($0) }
    }

    /// 從問句挑出地名（「台北明天天氣」→「台北」）
    static func place(_ q: String) -> String? {
        var t = q
        for w in weatherWords + ["今天", "明天", "後天", "現在", "這週", "本週", "如何", "怎麼樣", "怎樣", "多少", "度", "的", "嗎", "呢", "會", "查", "幫我", "請問",
                                  "?", "？", "today", "tomorrow", "now", "in ", " the ", "what's", "what is", "how is", "hoy", "mañana", "oggi", "domani", "com'è", "qué", "el ", "a "] {
            t = t.replacingOccurrences(of: w, with: " ", options: .caseInsensitive)
        }
        let p = t.split(separator: " ").map(String.init).filter { !$0.isEmpty }.joined(separator: " ")
        return p.isEmpty ? nil : p
    }

    static let wmo: [Int: String] = [0: "晴", 1: "大致晴朗", 2: "局部多雲", 3: "陰天", 45: "有霧", 48: "有霧", 51: "毛毛雨", 53: "毛毛雨", 55: "毛毛雨",
                                     61: "小雨", 63: "中雨", 65: "大雨", 66: "凍雨", 67: "凍雨", 71: "小雪", 73: "中雪", 75: "大雪", 77: "雪粒",
                                     80: "陣雨", 81: "較強陣雨", 82: "豪大陣雨", 85: "陣雪", 86: "陣雪", 95: "雷雨", 96: "雷雨夾冰雹", 99: "強雷雨夾冰雹"]

    static func weatherIf(_ q: String, _ L: Lang) async -> String? {
        wantsWeather(q) ? await weather(q, L) : nil
    }

    /// 常見城市的英文名（地理編碼用英文最準）
    static let cityEN: [String: String] = [
        "台北": "Taipei", "臺北": "Taipei", "新北": "New Taipei", "板橋": "Banqiao", "桃園": "Taoyuan", "新竹": "Hsinchu", "苗栗": "Miaoli",
        "台中": "Taichung", "臺中": "Taichung", "彰化": "Changhua", "南投": "Nantou", "雲林": "Douliu", "嘉義": "Chiayi", "台南": "Tainan",
        "臺南": "Tainan", "高雄": "Kaohsiung", "屏東": "Pingtung", "宜蘭": "Yilan", "花蓮": "Hualien", "台東": "Taitung", "臺東": "Taitung",
        "基隆": "Keelung", "澎湖": "Magong", "金門": "Kinmen", "馬祖": "Nangan", "香港": "Hong Kong", "澳門": "Macau", "北京": "Beijing",
        "上海": "Shanghai", "廣州": "Guangzhou", "深圳": "Shenzhen", "東京": "Tokyo", "大阪": "Osaka", "京都": "Kyoto", "首爾": "Seoul",
        "新加坡": "Singapore", "曼谷": "Bangkok", "紐約": "New York", "洛杉磯": "Los Angeles", "倫敦": "London", "巴黎": "Paris",
        "雪梨": "Sydney", "溫哥華": "Vancouver", "多倫多": "Toronto", "羅馬": "Rome", "馬德里": "Madrid",
    ]

    static func geocode(_ name: String, _ L: Lang) async -> (lat: Double, lon: Double, name: String)? {
        var tries: [(String, String)] = []
        let trimmed = name.replacingOccurrences(of: "市", with: "").replacingOccurrences(of: "縣", with: "")
        if let en = cityEN[trimmed] ?? cityEN.first(where: { trimmed.contains($0.key) })?.value { tries.append((en, "en")) }
        tries.append((name, L == .zh ? "zh" : L.rawValue))
        if trimmed != name { tries.append((trimmed, "zh")) }
        for (n, lang) in tries {
            guard let g = URL(string: "https://geocoding-api.open-meteo.com/v1/search?count=1&language=\(lang)&name=\(enc(n))"),
                  let gd = await data(request(g, L, ua: desktopUA)),
                  let gobj = try? JSONSerialization.jsonObject(with: gd) as? [String: Any],
                  let r = (gobj["results"] as? [[String: Any]])?.first,
                  let lat = r["latitude"] as? Double, let lon = r["longitude"] as? Double else { continue }
            return (lat, lon, L == .zh ? name : (r["name"] as? String ?? n))
        }
        return nil
    }

    static func weather(_ q: String, _ L: Lang) async -> String? {
        let name = place(q) ?? (L == .zh ? "台北" : "London")
        guard let g = await geocode(name, L) else { return nil }
        let (lat, lon, city) = g
        guard let f = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code,relative_humidity_2m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&forecast_days=3&timezone=auto"),
              let fd = await data(request(f, L, ua: desktopUA)),
              let o = try? JSONSerialization.jsonObject(with: fd) as? [String: Any],
              let cur = o["current"] as? [String: Any], let daily = o["daily"] as? [String: Any] else { return nil }
        let t = cur["temperature_2m"] as? Double ?? 0
        let code = cur["weather_code"] as? Int ?? -1
        let hum = cur["relative_humidity_2m"] as? Double
        let maxs = daily["temperature_2m_max"] as? [Double] ?? [], mins = daily["temperature_2m_min"] as? [Double] ?? []
        let codes = daily["weather_code"] as? [Int] ?? [], rain = daily["precipitation_probability_max"] as? [Double] ?? []
        guard L == .zh else {
            var s = "\(city): now \(Int(t.rounded()))°C"
            for (i, day) in ["today", "tomorrow", "day after"].enumerated() where i < maxs.count && i < mins.count {
                s += "; \(day) \(Int(mins[i].rounded()))–\(Int(maxs[i].rounded()))°C" + (i < rain.count ? ", rain \(Int(rain[i]))%" : "")
            }
            return s
        }
        var s = "\(city)現在 \(Int(t.rounded()))°C，\(wmo[code] ?? "")" + (hum.map { "，濕度 \(Int($0))%" } ?? "") + "。"
        for (i, day) in ["今天", "明天", "後天"].enumerated() where i < maxs.count && i < mins.count {
            s += "\(day)\(i < codes.count ? wmo[codes[i]] ?? "" : "")，\(Int(mins[i].rounded()))～\(Int(maxs[i].rounded()))°C"
            if i < rain.count { s += "，降雨機率 \(Int(rain[i]))%" }
            s += "。"
        }
        return s
    }

    // MARK: - 匯率（open.er-api.com，免費、不需要金鑰）

    static let currencies: [(words: [String], code: String, zh: String)] = [
        (["美元", "美金", "usd", "dollar"], "USD", "美元"), (["台幣", "臺幣", "新台幣", "twd", "ntd"], "TWD", "新台幣"),
        (["日圓", "日元", "日幣", "jpy", "yen"], "JPY", "日圓"), (["人民幣", "rmb", "cny"], "CNY", "人民幣"),
        (["歐元", "eur", "euro"], "EUR", "歐元"), (["港幣", "港元", "hkd"], "HKD", "港幣"), (["韓元", "韓幣", "krw", "won"], "KRW", "韓元"),
        (["英鎊", "gbp", "pound"], "GBP", "英鎊"), (["澳幣", "澳元", "aud"], "AUD", "澳幣"), (["泰銖", "thb", "baht"], "THB", "泰銖"),
        (["新加坡幣", "新幣", "sgd"], "SGD", "新加坡幣"), (["加幣", "cad"], "CAD", "加幣"),
    ]

    struct Currency { let code: String; let zh: String }

    static func exchangeIf(_ q: String, _ L: Lang) async -> String? {
        let l = q.lowercased()
        let asks = ["匯率", "換多少", "兌", "exchange rate", "tipo de cambio", "cambio"]
        if !asks.contains(where: { l.contains($0) }) { return nil }
        // 依照在句子裡出現的先後決定「誰換誰」
        var found: [(Int, Currency)] = []
        for c in currencies {
            var pos: Int? = nil
            for w in c.words {
                if let r = l.range(of: w) {
                    let p = l.distance(from: l.startIndex, to: r.lowerBound)
                    if pos == nil || p < pos! { pos = p }
                }
            }
            if let p = pos { found.append((p, Currency(code: c.code, zh: c.zh))) }
        }
        found.sort { $0.0 < $1.0 }
        let usd = Currency(code: "USD", zh: "美元"), twd = Currency(code: "TWD", zh: "新台幣")
        let from: Currency = found.first?.1 ?? usd
        var to: Currency = found.count > 1 ? found[1].1 : twd
        if to.code == from.code { to = from.code == "TWD" ? usd : twd }
        guard let url = URL(string: "https://open.er-api.com/v6/latest/" + from.code) else { return nil }
        guard let d = await data(request(url, L, ua: desktopUA)) else { return nil }
        guard let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        guard let rates = o["rates"] as? [String: Double], let r = rates[to.code], r > 0 else { return nil }
        let v = fmtNum(r)
        let inv = fmtNum(1.0 / r)
        if L == .zh {
            return "1 " + from.zh + " ≈ " + v + " " + to.zh + "；1 " + to.zh + " ≈ " + inv + " " + from.zh + "。這是市場參考匯率，銀行實際買賣價會有價差。"
        }
        return "1 " + from.code + " ≈ " + v + " " + to.code + "; 1 " + to.code + " ≈ " + inv + " " + from.code + ". Market reference rate; bank rates differ."
    }

    static func fmtNum(_ x: Double) -> String {
        x >= 100 ? String(format: "%.2f", x) : String(format: "%.4f", x)
    }

    // MARK: - 股市指數（Yahoo Finance 公開報價）

    static let indices: [(words: [String], symbol: String, zh: String)] = [
        (["台股", "臺股", "加權指數", "大盤", "台灣股市", "台灣股票", "股市"], "^TWII", "台股加權指數"),
        (["櫃買", "上櫃"], "^TWOII", "櫃買指數"), (["道瓊", "dow"], "^DJI", "道瓊工業指數"), (["那斯達克", "納斯達克", "nasdaq"], "^IXIC", "那斯達克指數"),
        (["標普", "s&p"], "^GSPC", "標普500指數"), (["費半", "費城半導體"], "^SOX", "費城半導體指數"), (["日經", "nikkei"], "^N225", "日經225指數"),
        (["恆生", "港股"], "^HSI", "恆生指數"), (["美股"], "^GSPC", "標普500指數"),
    ]

    static func marketIf(_ q: String, _ L: Lang) async -> String? {
        let l = q.lowercased()
        guard let idx = indices.first(where: { item in item.words.contains(where: { l.contains($0) }) }) else { return nil }
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/" + enc(idx.symbol) + "?range=1d&interval=1d") else { return nil }
        guard let d = await data(request(url, L, ua: desktopUA)) else { return nil }
        guard let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        guard let chart = o["chart"] as? [String: Any], let results = chart["result"] as? [[String: Any]],
              let res = results.first, let meta = res["meta"] as? [String: Any],
              let price = meta["regularMarketPrice"] as? Double else { return nil }
        var s = idx.zh + " " + String(format: "%.2f", price)
        let prev = (meta["chartPreviousClose"] as? Double) ?? (meta["previousClose"] as? Double) ?? 0
        if prev > 0 {
            let ch = price - prev
            let pct = ch / prev * 100
            let sign = ch >= 0 ? "+" : ""
            s += "，漲跌 " + sign + String(format: "%.2f", ch) + "（" + sign + String(format: "%.2f", pct) + "%）"
        }
        if let ts = meta["regularMarketTime"] as? Double {
            let f = DateFormatter()
            f.dateFormat = "M/d HH:mm"
            s += "，時間 " + f.string(from: Date(timeIntervalSince1970: ts))
        }
        return s + "。"
    }

    // MARK: - 讀網頁

    /// 打開網頁，去掉選單、腳本，回傳正文文字
    public static func pageText(_ url: String, _ L: Lang) async -> String? {
        if isWiki(url) { return nil }
        if let tape = WebTape.shared {
            if tape.replaying { return tape.page(url) }
            let t = await livePageText(url, L)
            tape.record(page: url, t)
            return t
        }
        return await livePageText(url, L)
    }

    static func livePageText(_ url: String, _ L: Lang) async -> String? {
        guard let u = URL(string: url), u.scheme?.hasPrefix("http") == true else { return nil }
        let req = request(u, L, ua: mobileUA)
        guard let res = try? await session.data(for: req) else { return nil }
        let (d, resp) = res
        guard ((resp as? HTTPURLResponse)?.statusCode ?? 200) < 400, d.count < 4_000_000 else { return nil }
        let ctype = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if !ctype.isEmpty && !ctype.contains("html") && !ctype.contains("text") { return nil }
        guard var html = decode(d, contentType: ctype) else { return nil }
        for tag in ["script", "style", "noscript", "header", "footer", "nav", "svg", "form", "aside", "iframe", "button", "select"] {
            html = html.replacingOccurrences(of: "(?is)<\(tag)\\b[^>]*>.*?</\(tag)>", with: " ", options: .regularExpression)
        }
        html = html.replacingOccurrences(of: "(?is)<!--.*?-->", with: " ", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?i)<(br|p|div|li|h[1-6]|tr|section|article)\\b[^>]*>", with: "\n", options: .regularExpression)
        // 表格每一格用「｜」隔開，才看得出第一欄是名單（國家、縣市……）
        html = html.replacingOccurrences(of: "(?i)<(td|th)\\b[^>]*>", with: " ｜ ", options: .regularExpression)
        // 短行（清單的一項，例如「青森縣」）也要留著，挑句子時會再過濾
        let lines = html.components(separatedBy: "\n").map { clean($0).trimmingCharacters(in: .whitespaces) }
            .map { $0.hasPrefix("｜") ? String($0.dropFirst()).trimmingCharacters(in: .whitespaces) : $0 }
            .filter { $0.count >= 2 }
        return lines.joined(separator: "\n")
    }

    /// 依照 Content-Type 或 <meta charset> 解碼（支援 Big5、GBK）
    static func decode(_ d: Data, contentType: String) -> String? {
        var cs = first(#"charset=["']?([a-zA-Z0-9_-]+)"#, contentType, group: 1)?.lowercased()
        if cs == nil, let head = String(data: d.prefix(3000), encoding: .isoLatin1) {
            cs = first(#"charset=["']?([a-zA-Z0-9_-]+)"#, head, group: 1)?.lowercased()
        }
        #if canImport(Darwin)
        switch cs ?? "utf-8" {
        case "big5", "big5-hkscs", "x-big5":
            return String(data: d, encoding: String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5_HKSCS_1999.rawValue))))
                ?? String(decoding: d, as: UTF8.self)
        case "gbk", "gb2312", "gb18030", "x-gbk":
            return String(data: d, encoding: String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))))
                ?? String(decoding: d, as: UTF8.self)
        default:
            return String(data: d, encoding: .utf8) ?? String(decoding: d, as: UTF8.self)
        }
        #else
        // Linux／網頁版沒有 CoreFoundation 的 big5、gbk 轉碼（只用來跑測試）
        _ = cs
        return String(data: d, encoding: .utf8) ?? String(decoding: d, as: UTF8.self)
        #endif
    }

    // MARK: - RSS

    struct RSSItem { let title: String; let link: String; let desc: String; let date: String? }

    static func rssItems(_ xml: String) -> [RSSItem] {
        xml.components(separatedBy: "<item>").dropFirst().compactMap { block in
            guard let t = first(#"<title>(.*?)</title>"#, block, group: 1),
                  let l = first(#"<link>(.*?)</link>"#, block, group: 1) else { return nil }
            let desc = first(#"<description>(.*?)</description>"#, block, group: 1) ?? ""
            let date = first(#"<pubDate>(.*?)</pubDate>"#, block, group: 1)
            return RSSItem(title: clean(unCDATA(t)), link: unCDATA(l).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "&amp;", with: "&"),
                           desc: clean(unCDATA(desc)), date: date)
        }
    }

    static func unCDATA(_ s: String) -> String {
        s.replacingOccurrences(of: "<![CDATA[", with: "").replacingOccurrences(of: "]]>", with: "")
    }

    // MARK: - 網路工具

    static func market(_ L: Lang) -> String {
        ["zh": "zh-TW", "en": "en-US", "es": "es-ES", "it": "it-IT"][L.rawValue] ?? "en-US"
    }

    /// 維基百科要求程式用自己的名字當 User-Agent，用瀏覽器的名字反而容易被擋
    static let wikiUA = "NineSun/1.0 (iOS companion app; https://github.com/u1130238883-oss/-eden-ai) URLSession"

    static func request(_ url: URL, _ L: Lang, ua: String) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: 6)
        let isWiki = url.host?.hasSuffix("wikipedia.org") == true
        req.setValue(isWiki ? wikiUA : ua, forHTTPHeaderField: "User-Agent")
        req.setValue(L == .zh ? "zh-TW,zh;q=0.9,en;q=0.6" : "\(L.rawValue),en;q=0.6", forHTTPHeaderField: "Accept-Language")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7", forHTTPHeaderField: "Accept")
        return req
    }

    static func data(_ req: URLRequest) async -> Data? {
        // 維基百科偶爾回 429（太頻繁），等一下再試一次
        for attempt in 0..<2 {
            guard let res = try? await session.data(for: req) else { return nil }
            let (d, resp) = res
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 200
            if code < 400 { return d }
            guard attempt == 0, code == 429 || code == 503, req.url?.host?.hasSuffix("wikipedia.org") == true else { return nil }
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
        return nil
    }

    static func text(_ req: URLRequest) async -> String? {
        guard let d = await data(req) else { return nil }
        return String(data: d, encoding: .utf8) ?? String(decoding: d, as: UTF8.self)
    }

    static func text(_ url: URL, _ L: Lang, ua: String) async -> String? {
        await text(request(url, L, ua: ua))
    }

    // MARK: - 文字工具

    static func enc(_ s: String) -> String {
        // 只留 ASCII 的英數字（CharacterSet.alphanumerics 連中文都算，中文就沒有編碼）
        var allowed = CharacterSet()
        allowed.insert(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    static func first(_ pattern: String, _ s: String, group: Int = 0) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r = Range(m.range(at: group), in: s) else { return nil }
        return String(s[r])
    }

    /// 去掉 HTML 標籤與實體
    public static func clean(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (k, v) in ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " ",
                       "&ensp;": " ", "&emsp;": " ", "&#183;": "·", "&middot;": "·", "&hellip;": "…", "&mdash;": "—", "&ndash;": "–",
                       "&ldquo;": "“", "&rdquo;": "”", "&lsquo;": "‘", "&rsquo;": "’"] {
            t = t.replacingOccurrences(of: k, with: v)
        }
        if let re = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);") {
            for m in re.matches(in: t, range: NSRange(t.startIndex..., in: t)).reversed() {
                guard let r = Range(m.range, in: t), let xr = Range(m.range(at: 1), in: t), let nr = Range(m.range(at: 2), in: t),
                      let n = UInt32(t[nr], radix: t[xr].isEmpty ? 10 : 16), let u = UnicodeScalar(n) else { continue }
                t.replaceSubrange(r, with: String(Character(u)))
            }
        }
        return t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    public static func host(_ url: String) -> String {
        (URL(string: url)?.host ?? url).replacingOccurrences(of: "www.", with: "")
    }

    static func normURL(_ url: String) -> String {
        var u = url.lowercased()
        for p in ["https://", "http://", "www.", "m."] where u.hasPrefix(p) { u.removeFirst(p.count) }
        u = u.replacingOccurrences(of: "zh.wikipedia.org/zh-tw/", with: "zh.wikipedia.org/wiki/")
        while u.hasSuffix("/") { u.removeLast() }
        return u
    }

    public static func clip(_ s: String, _ n: Int) -> String {
        s.count <= n ? s : String(s.prefix(n)) + "…"
    }

    /// 維基百科的標題跟問題有沒有關係（避免答非所問）
    static func related(_ title: String, _ q: String) -> Bool {
        let t = title.lowercased(), ql = q.lowercased()
        if ql.contains(t) || t.contains(ql) { return true }
        let chars = Set(t.filter { !$0.isWhitespace })
        let hit = chars.filter { ql.contains($0) }.count
        return !chars.isEmpty && Double(hit) / Double(chars.count) >= 0.6
    }
}
