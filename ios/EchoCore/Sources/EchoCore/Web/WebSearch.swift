import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 上網查資料（全部免費、不需要任何金鑰）。
/// 同時問好幾個來源，誰有結果就用誰：
///   Bing（RSS 與網頁）、DuckDuckGo（網頁與即時答案）、維基百科、Google 新聞 RSS、Open-Meteo 天氣。
/// 每一次都是即時上網查，不在手機裡存舊答案。
public enum WebSearch {
    public struct Hit: Equatable {
        public let title: String
        public let snippet: String
        public let url: String
        /// 哪個搜尋來源找到的
        public let engine: String
        public init(title: String, snippet: String, url: String, engine: String) {
            self.title = title; self.snippet = snippet; self.url = url; self.engine = engine
        }
    }

    public struct Answer {
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
        c.timeoutIntervalForRequest = 10
        c.timeoutIntervalForResource = 15
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.urlCache = nil
        c.httpShouldSetCookies = false
        return URLSession(configuration: c)
    }()

    /// 同時問所有來源，合併去重
    /// light：只問 Bing（拆成好幾個方面分開查的時候用，比較快）
    public static func search(_ q: String, lang L: Lang, news: Bool = false, light: Bool = false) async -> Answer {
        if light {
            async let rss = bingRSS(q, L)
            async let bh = bingHTML(q, L)
            let a = await rss, b = await bh
            var seen = Set<String>()
            let hits = (a + b).filter { seen.insert(normURL($0.url)).inserted }
            return Answer(lead: nil, leadSource: nil, hits: Array(hits.prefix(10)), engines: ["bing": a.count, "bing-web": b.count])
        }
        async let rss = bingRSS(q, L)
        async let bh = bingHTML(q, L)
        async let dh = ddgHTML(q, L)
        async let ws = wikiSearch(q, L)
        async let inst = ddgInstant(q, L)
        async let wk = wikiSummary(q, L)
        async let nw = newsIf(news, q, L)
        async let wx = weatherIf(q, L)
        async let fx = exchangeIf(q, L)
        async let mk = marketIf(q, L)

        let lists: [(String, [Hit])] = [("news", await nw), ("bing", await rss), ("bing-web", await bh), ("duckduckgo", await dh), ("wikipedia", await ws)]
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
        if lead == nil, let w = await wk, related(w.title, q) { lead = w.extract; leadSource = host(w.url) }
        engines["instant"] = lead == nil ? 0 : 1
        if wantsWeather(q) { engines["weather"] = leadSource == "open-meteo.com" ? 1 : 0 }
        return Answer(lead: lead.map { clip($0, 320) }, leadSource: leadSource, hits: Array(hits.prefix(10)), engines: engines)
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

    // MARK: - DuckDuckGo

    static func ddgHTML(_ q: String, _ L: Lang) async -> [Hit] {
        let region = ["zh": "tw-tzh", "en": "us-en", "es": "es-es", "it": "it-it"][L.rawValue] ?? "wt-wt"
        guard let url = URL(string: "https://html.duckduckgo.com/html/") else { return [] }
        var req = request(url, L, ua: desktopUA)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("https://html.duckduckgo.com/", forHTTPHeaderField: "Referer")
        req.httpBody = "q=\(enc(q))&kl=\(region)&b=".data(using: .utf8)
        guard let html = await text(req) else { return [] }
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

    static func exchangeIf(_ q: String, _ L: Lang) async -> String? {
        let l = q.lowercased()
        guard ["匯率", "換多少", "兌", "exchange rate", "tipo de cambio", "cambio"].contains(where: { l.contains($0) }) else { return nil }
        // 依照在句子裡出現的先後決定「誰換誰」
        var found: [(pos: Int, code: String, zh: String)] = []
        for c in currencies {
            if let r = c.words.compactMap({ l.range(of: $0) }).min(by: { $0.lowerBound < $1.lowerBound }) {
                found.append((l.distance(from: l.startIndex, to: r.lowerBound), c.code, c.zh))
            }
        }
        found.sort { $0.pos < $1.pos }
        let from = found.first ?? (0, "USD", "美元")
        var to = found.count > 1 ? found[1] : (0, "TWD", "新台幣")
        if to.code == from.code { to = from.code == "TWD" ? (0, "USD", "美元") : (0, "TWD", "新台幣") }
        guard let url = URL(string: "https://open.er-api.com/v6/latest/\(from.code)"),
              let d = await data(request(url, L, ua: desktopUA)),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let rates = o["rates"] as? [String: Double], let r = rates[to.code] else { return nil }
        let when = (o["time_last_update_utc"] as? String).map { " （更新：\(shortDate($0.replacingOccurrences(of: "+0000", with: "GMT"))）" } ?? ""
        let v = r >= 100 ? String(format: "%.2f", r) : String(format: "%.4f", r)
        let inv = 1 / r >= 100 ? String(format: "%.2f", 1 / r) : String(format: "%.4f", 1 / r)
        if L == .zh { return "1 \(from.zh) ≈ \(v) \(to.zh)；1 \(to.zh) ≈ \(inv) \(from.zh)\(when)。這是市場參考匯率，銀行實際買賣價會有價差。" }
        return "1 \(from.code) ≈ \(v) \(to.code); 1 \(to.code) ≈ \(inv) \(from.code). Market reference rate; bank rates differ."
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
        guard let idx = indices.first(where: { $0.words.contains(where: { l.contains($0) }) }) else { return nil }
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(enc(idx.symbol))?range=1d&interval=1d"),
              let d = await data(request(url, L, ua: desktopUA)),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let res = ((o["chart"] as? [String: Any])?["result"] as? [[String: Any]])?.first,
              let meta = res["meta"] as? [String: Any], let price = meta["regularMarketPrice"] as? Double else { return nil }
        let prev = meta["chartPreviousClose"] as? Double ?? meta["previousClose"] as? Double
        let t = (meta["regularMarketTime"] as? Double).map { Date(timeIntervalSince1970: $0) }
        let f = DateFormatter(); f.dateFormat = "M/d HH:mm"
        var s = "\(idx.zh) \(String(format: "%.2f", price))"
        if let p = prev, p > 0 {
            let ch = price - p
            s += "，漲跌 \(ch >= 0 ? "+" : "")\(String(format: "%.2f", ch))（\(ch >= 0 ? "+" : "")\(String(format: "%.2f", ch / p * 100))%）"
        }
        if let t { s += "，時間 \(f.string(from: t))" }
        return s + "。"
    }

    // MARK: - 讀網頁

    /// 打開網頁，去掉選單、腳本，回傳正文文字
    public static func pageText(_ url: String, _ L: Lang) async -> String? {
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
        let lines = html.components(separatedBy: "\n").map { clean($0) }.filter { $0.count >= 8 }
        return lines.joined(separator: "\n")
    }

    /// 依照 Content-Type 或 <meta charset> 解碼（支援 Big5、GBK）
    static func decode(_ d: Data, contentType: String) -> String? {
        var cs = first(#"charset=["']?([a-zA-Z0-9_-]+)"#, contentType, group: 1)?.lowercased()
        if cs == nil, let head = String(data: d.prefix(3000), encoding: .isoLatin1) {
            cs = first(#"charset=["']?([a-zA-Z0-9_-]+)"#, head, group: 1)?.lowercased()
        }
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

    static func request(_ url: URL, _ L: Lang, ua: String) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.setValue(L == .zh ? "zh-TW,zh;q=0.9,en;q=0.6" : "\(L.rawValue),en;q=0.6", forHTTPHeaderField: "Accept-Language")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7", forHTTPHeaderField: "Accept")
        return req
    }

    static func data(_ req: URLRequest) async -> Data? {
        guard let res = try? await session.data(for: req) else { return nil }
        let (d, resp) = res
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 200
        return code < 400 ? d : nil
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
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
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
