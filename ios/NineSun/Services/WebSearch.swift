import EchoCore
import Foundation

/// 上網查資料（免費、不需要任何金鑰）：
/// DuckDuckGo 即時答案 → DuckDuckGo 網頁搜尋 → Bing → 維基百科全文搜尋，整理成一段回答和來源。
enum WebSearch {
    struct Hit { let title: String; let snippet: String; let url: String }
    struct Answer { let lead: String?; let hits: [Hit] }

    static let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    static func search(_ q: String, lang L: Lang) async -> Answer? {
        async let instant = ddgInstant(q, L)
        async let wiki = WikiLookup.fetch(q, lang: L)
        var hits = await ddgHTML(q, L)
        if hits.count < 2 { hits += await bing(q, L) }
        if hits.count < 2 { hits += await wikiSearch(q, L) }
        var seen = Set<String>()
        hits = hits.filter { !$0.snippet.isEmpty && seen.insert($0.url).inserted }
        var lead = await instant
        if lead == nil, let w = await wiki, related(w.title, q) { lead = w.extract }
        if lead == nil && hits.isEmpty { return nil }
        return Answer(lead: lead.map { clip($0, 260) }, hits: Array(hits.prefix(4)))
    }

    /// 回答文字（NineSun 的語氣）：先給一段重點，再列出幾個來源的補充
    static func compose(_ a: Answer, query q: String, L: Lang) -> String {
        var s = Loc.s("webResult", L, q)
        var rest = a.hits
        let lead: String
        if let l = a.lead {
            lead = l
        } else if let best = bestHit(a.hits, query: q) {
            lead = sentences(best.snippet).prefix(2).joined()
            rest.removeAll { $0.url == best.url }
        } else {
            lead = ""
        }
        if !lead.isEmpty { s += "\n\n" + clip(lead, 260) }
        let extra = rest.filter { !$0.snippet.isEmpty && !lead.contains(String($0.snippet.prefix(20))) }.prefix(3)
        if !extra.isEmpty {
            s += "\n"
            for h in extra { s += "\n• " + clip(h.snippet, 140) + "（" + host(h.url) + "）" }
        }
        return s
    }

    /// 片段裡最多跟問題重疊的字的那一筆
    static func bestHit(_ hits: [Hit], query q: String) -> Hit? {
        let qs = Set(q.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation })
        return hits.filter { !$0.snippet.isEmpty }.max { a, b in
            overlap(a.title + a.snippet, qs) < overlap(b.title + b.snippet, qs)
        }
    }

    static func overlap(_ s: String, _ qs: Set<Character>) -> Int { Set(s.lowercased()).intersection(qs).count }

    static func sentences(_ s: String) -> [String] {
        var out: [String] = [], cur = ""
        for ch in s {
            cur.append(ch)
            if "。！？.!?".contains(ch) { out.append(cur); cur = "" }
        }
        if !cur.trimmingCharacters(in: .whitespaces).isEmpty { out.append(cur) }
        return out
    }

    // MARK: - 來源

    static func ddgInstant(_ q: String, _ L: Lang) async -> String? {
        guard let url = URL(string: "https://api.duckduckgo.com/?format=json&no_html=1&skip_disambig=1&q=\(enc(q))"),
              let d = await get(url, L), let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        if let a = obj["AbstractText"] as? String, a.count > 20 { return a }
        if let a = obj["Answer"] as? String, !a.isEmpty { return a }
        return nil
    }

    static func ddgHTML(_ q: String, _ L: Lang) async -> [Hit] {
        let region = ["zh": "tw-tzh", "en": "us-en", "es": "es-es", "it": "it-it"][L.rawValue] ?? "wt-wt"
        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=\(enc(q))&kl=\(region)"),
              let d = await get(url, L), let html = String(data: d, encoding: .utf8) else { return [] }
        var out: [Hit] = []
        for block in html.components(separatedBy: "class=\"result__body").dropFirst() {
            if block.contains("result--ad") || block.contains("badge--ad") { continue }
            guard let tag = first(#"<a[^>]*class="result__a"[^>]*>"#, block),
                  let href = first(#"href="([^"]+)""#, tag, group: 1),
                  let title = first(#"class="result__a"[^>]*>(.*?)</a>"#, block, group: 1) else { continue }
            let snip = first(#"class="result__snippet"[^>]*>(.*?)</a>"#, block, group: 1) ?? ""
            out.append(Hit(title: clean(title), snippet: clean(snip), url: realURL(href)))
            if out.count >= 6 { break }
        }
        return out
    }

    static func bing(_ q: String, _ L: Lang) async -> [Hit] {
        let mkt = ["zh": "zh-TW", "en": "en-US", "es": "es-ES", "it": "it-IT"][L.rawValue] ?? "en-US"
        guard let url = URL(string: "https://www.bing.com/search?q=\(enc(q))&mkt=\(mkt)&setlang=\(mkt)"),
              let d = await get(url, L), let html = String(data: d, encoding: .utf8) else { return [] }
        var out: [Hit] = []
        for block in html.components(separatedBy: "<li class=\"b_algo\"").dropFirst() {
            guard let href = first(#"<h2[^>]*>\s*<a[^>]*href="([^"]+)""#, block, group: 1),
                  let title = first(#"<h2[^>]*>\s*<a[^>]*>(.*?)</a>"#, block, group: 1) else { continue }
            let snip = first(#"<p[^>]*>(.*?)</p>"#, block, group: 1) ?? ""
            out.append(Hit(title: clean(title), snippet: clean(snip), url: href.replacingOccurrences(of: "&amp;", with: "&")))
            if out.count >= 6 { break }
        }
        return out
    }

    static func wikiSearch(_ q: String, _ L: Lang) async -> [Hit] {
        let host = "\(L.rawValue).wikipedia.org"
        guard let url = URL(string: "https://\(host)/w/api.php?action=query&list=search&format=json&utf8=1&srlimit=3&srsearch=\(enc(q))"),
              let d = await get(url, L), let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let items = (obj["query"] as? [String: Any])?["search"] as? [[String: Any]] else { return [] }
        return items.compactMap { it in
            guard let t = it["title"] as? String else { return nil }
            let path = t.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? t
            return Hit(title: t, snippet: clean(it["snippet"] as? String ?? ""), url: "https://\(host)/wiki/\(path)")
        }
    }

    // MARK: - 工具

    static func get(_ url: URL, _ L: Lang) async -> Data? {
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.setValue(L == .zh ? "zh-TW,zh;q=0.9,en;q=0.5" : "\(L.rawValue),en;q=0.5", forHTTPHeaderField: "Accept-Language")
        guard let res = try? await URLSession.shared.data(for: req) else { return nil }
        let code = (res.1 as? HTTPURLResponse)?.statusCode ?? 200
        return code < 400 ? res.0 : nil
    }

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
    static func clean(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (k, v) in ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&ensp;": " ", "&#183;": "·"] {
            t = t.replacingOccurrences(of: k, with: v)
        }
        if let re = try? NSRegularExpression(pattern: "&#(\\d+);") {
            for m in re.matches(in: t, range: NSRange(t.startIndex..., in: t)).reversed() {
                guard let r = Range(m.range, in: t), let nr = Range(m.range(at: 1), in: t),
                      let n = UInt32(t[nr]), let u = UnicodeScalar(n) else { continue }
                t.replaceSubrange(r, with: String(Character(u)))
            }
        }
        return t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    /// DuckDuckGo 的轉址連結 → 原網址
    static func realURL(_ href: String) -> String {
        let h = href.replacingOccurrences(of: "&amp;", with: "&")
        if let c = URLComponents(string: h.hasPrefix("//") ? "https:" + h : h),
           let u = c.queryItems?.first(where: { $0.name == "uddg" })?.value { return u }
        return h.hasPrefix("//") ? "https:" + h : h
    }

    static func host(_ url: String) -> String {
        (URL(string: url)?.host ?? url).replacingOccurrences(of: "www.", with: "")
    }

    static func clip(_ s: String, _ n: Int) -> String {
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
