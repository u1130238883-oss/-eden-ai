import Foundation

/// NineSun 自己上網找答案的思路（每次都即時上網，不存舊答案）：
///   ① 理解問題（是哪一類問題、重點是什麼）
///   ② 規劃要搜尋的關鍵字
///   ③ 同時問好幾個搜尋來源（Bing／DuckDuckGo／維基百科／新聞／天氣，不需要金鑰）
///   ④ 打開最相關的幾個網頁閱讀，挑出和問題最相關的句子
///   ⑤ 交叉比對：好幾個來源都提到的說法才可信
///   ⑥ 回答，附上思路、把握程度和來源連結
public enum WebAgent {
    public enum Kind { case define, reason, method, compare, recommend, news, weather, person, fortune, general }

    public struct Plan {
        public let kind: Kind
        public let keywords: String
        /// 去掉「多高」「怎麼煮」這類問法之後的主題（「台北101」「紅燒肉」）
        public let core: String
        public let queries: [String]
        /// 問的是數量（多高、多少、幾歲……），答案裡要有數字
        public let numeric: Bool
    }
    public struct Finding { public let text: String; public let host: String; public let url: String }
    public struct Result {
        public let text: String
        public let card: FortuneCard?
        /// 有沒有真的查到東西
        public let found: Bool
        /// 每個來源找到幾筆（診斷用）
        public let engines: [String: Int]
    }

    static let kindName: [Kind: String] = [
        .define: "「是什麼」", .reason: "「為什麼」", .method: "「怎麼做」", .compare: "「比較」", .recommend: "「推薦」",
        .news: "「最新消息」", .weather: "「天氣」", .person: "「人物」", .fortune: "命理", .general: "一般",
    ]

    // MARK: - ① 理解問題 ② 規劃搜尋

    public static func understand(_ question: String, L: Lang, fortune: Bool) -> Plan {
        let q = question.lowercased()
        func has(_ ws: [String]) -> Bool { ws.contains { q.contains($0) } }
        let kind: Kind
        if fortune { kind = .fortune }
        else if WebSearch.wantsWeather(q) { kind = .weather }
        else if has(["差別", "區別", "比較", "哪個好", "哪一個好", " vs", "difference", "better than", "diferencia", "differenza"]) { kind = .compare }
        else if has(["新聞", "最新", "最近發生", "今天發生", "消息", "股價", "匯率", "比分", "latest", "news", "noticias", "notizie"]) { kind = .news }
        else if has(["為什麼", "為何", "原因", "why", "por qué", "perché"]) { kind = .reason }
        else if has(["怎麼", "如何", "方法", "步驟", "教我", "how to", "how do", "how can", "cómo", "come si"]) { kind = .method }
        else if has(["推薦", "有哪些", "哪裡", "recommend", "best ", "recomienda", "consiglia"]) { kind = .recommend }
        else if has(["是誰", "誰是", "who is", "quién es", "chi è"]) { kind = .person }
        else if has(["是什麼", "什麼是", "什麼意思", "定義", "what is", "what are", "meaning", "qué es", "cos'è"]) { kind = .define }
        else { kind = .general }

        let kw = keywords(question)
        let core = coreTopic(kw)
        let numeric = has(["多高", "多大", "多遠", "多久", "多長", "多重", "多少", "幾歲", "幾年", "幾點", "幾個", "幾公", "匯率", "價格", "股價", "人口",
                           "how many", "how much", "how tall", "how far", "how long", "how old", "when did", "when was", "population", "price"])
        var qs = [kw]
        let extra: [Kind: String] = L == .zh
            ? [.define: " 是什麼", .reason: " 原因", .method: " 方法", .compare: " 差別", .recommend: " 推薦", .person: " 簡介"]
            : [.define: " meaning", .reason: " reason", .method: " how to", .compare: " difference", .recommend: " best", .person: " biography"]
        if let e = extra[kind], !kw.hasSuffix(e.trimmingCharacters(in: .whitespaces)) { qs.append(core + e) }
        if core != kw && kind != .weather && kind != .news { qs.append(core) }
        // 原句本身也是很好的搜尋詞（搜尋引擎看得懂自然語言）
        let raw = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.count <= 40 { qs.append(raw) }
        var seen = Set<String>()
        return Plan(kind: kind, keywords: kw, core: core, queries: qs.filter { !$0.isEmpty && seen.insert($0).inserted }, numeric: numeric)
    }

    /// 把口語問句整理成關鍵字
    public static func keywords(_ raw: String) -> String {
        var q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.hasPrefix("請") && !q.hasPrefix("請問") { q.removeFirst() }
        for w in ["請問", "請你", "請幫我", "幫我上網查", "上網查一下", "上網查", "上網搜尋", "上網找", "幫我查一下", "幫我查", "幫我搜尋", "搜尋一下", "搜尋",
                  "查一下", "幫我", "可以告訴我", "告訴我", "你知道", "我想知道", "想問", "一下",
                  "是什麼意思", "什麼意思", "是什麼", "什麼是", "為什麼", "怎麼樣", "如何", "有哪些", "是誰", "誰是",
                  "呀", "啊", "呢", "吧", "嗎", "？", "?", "！", "!", "。", "，", ","] {
            q = q.replacingOccurrences(of: w, with: " ")
        }
        for p in ["search for ", "search ", "look up ", "google ", "busca ", "cerca "] where q.lowercased().hasPrefix(p) {
            q = String(q.dropFirst(p.count))
        }
        if q.hasPrefix("查") { q.removeFirst() }
        let parts = q.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        let out = parts.joined(separator: " ")
        return out.isEmpty ? raw : out
    }

    /// 主題詞：去掉問法（「台北101有多高」→「台北101」、「紅燒肉怎麼煮」→「紅燒肉」）
    public static func coreTopic(_ kw: String) -> String {
        var t = kw
        for w in ["有多高", "多高", "有多大", "多大", "有多遠", "多遠", "要多久", "多久", "有多長", "多長", "有多重", "多重", "多少錢", "是多少", "有多少", "多少",
                  "幾歲", "幾點", "怎麼煮", "怎麼做", "怎麼去", "怎麼用", "怎麼樣", "怎樣", "是哪一座", "是哪一個", "是哪個", "是哪裡", "在哪裡", "哪一座", "哪一個",
                  "哪個", "哪裡", "的由來", "的原因", "的意思", "的差別", "的方法", "介紹", "的歷史", "的原理"] {
            t = t.replacingOccurrences(of: w, with: " ")
        }
        let out = t.split(separator: " ").map(String.init).filter { !$0.isEmpty }.joined(separator: " ")
        return out.count >= 2 ? out : kw
    }

    // MARK: - 主流程

    public static func run(_ question: String, facts: String? = nil, lang L: Lang) async -> Result {
        let fortune = facts != nil
        let plan = understand(question, L: L, fortune: fortune)
        let zh = L == .zh

        // ③ 搜尋：幾組關鍵字同時查
        let answers = await withTaskGroup(of: (Int, WebSearch.Answer).self) { g -> [WebSearch.Answer] in
            for (i, q) in plan.queries.prefix(3).enumerated() {
                g.addTask { (i, await WebSearch.search(q, lang: L, news: plan.kind == .news && i == 0)) }
            }
            var out: [(Int, WebSearch.Answer)] = []
            for await a in g { out.append(a) }
            return out.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
        var hits: [WebSearch.Hit] = []
        var lead: String?, leadSource: String?
        var engines: [String: Int] = [:]
        var seenURL = Set<String>()
        for a in answers {
            if lead == nil, let l = a.lead { lead = l; leadSource = a.leadSource }
            for (k, v) in a.engines { engines[k, default: 0] += v }
            for h in a.hits where seenURL.insert(WebSearch.normURL(h.url)).inserted { hits.append(h) }
        }
        if hits.isEmpty && lead == nil {
            return Result(text: Loc.s("webFail", L, plan.keywords), card: nil, found: false, engines: engines)
        }

        // ④ 閱讀網頁：挑最相關的三個網頁同時打開
        let terms = termSet(plan.core)
        let toRead = Array(hits.sorted { score($0.title + " " + $0.snippet, terms) > score($1.title + " " + $1.snippet, terms) }
            .filter { !$0.url.contains("news.google.com") }
            .prefix(3))
        let pages = await withTaskGroup(of: (WebSearch.Hit, String?).self) { g -> [(WebSearch.Hit, String)] in
            for h in toRead { g.addTask { (h, await WebSearch.pageText(h.url, L)) } }
            var out: [(WebSearch.Hit, String)] = []
            for await (h, t) in g { if let t { out.append((h, t)) } }
            return out
        }
        var findings: [Finding] = []
        for (h, page) in pages {
            for s in best(sentences(page), terms: terms, numeric: plan.numeric, core: plan.core, n: 3) {
                findings.append(Finding(text: s, host: WebSearch.host(h.url), url: h.url))
            }
        }
        for h in hits where !h.snippet.isEmpty {
            findings.append(Finding(text: h.snippet, host: WebSearch.host(h.url), url: h.url))
        }

        // ⑤ 交叉比對
        let common = consensus(findings.filter { score($0.text, terms) > 0 }, exclude: plan.keywords, cjkOnly: zh)
        let sources = orderedUnique(findings.map(\.host) + (leadSource.map { [$0] } ?? []))
        let confidence: String
        if sources.count >= 3 && common.count >= 2 {
            confidence = zh ? "高（\(sources.count) 個來源，說法大致一致）" : "high (\(sources.count) sources mostly agree)"
        } else if sources.count >= 2 {
            confidence = zh ? "中（\(sources.count) 個來源，可以參考）" : "medium (\(sources.count) sources)"
        } else {
            confidence = zh ? "低（來源少，建議再確認）" : "low (few sources, double-check)"
        }

        // ⑥ 回答
        let ranked = rank(findings, terms: terms, common: common, numeric: plan.numeric, core: plan.core)
        var answer = ""
        if let lead { answer = lead }
        else if let first = ranked.first { answer = WebSearch.clip(first.text, 240) }
        // 問數量：直接答案裡沒有數字，就改用有數字、最相關的那句
        if plan.numeric, plan.kind != .weather, !hasNumber(answer, besides: plan.core),
           let withNum = ranked.first(where: { hasNumber($0.text, besides: plan.core) && score($0.text, terms) > 0 }) {
            answer = WebSearch.clip(withNum.text, 240) + "（\(withNum.host)）" + (lead.map { "\n\n" + $0 } ?? "")
        }
        var used: [String] = [answer]
        var points: [String] = []
        for f in ranked where points.count < (plan.kind == .weather && lead != nil ? 0 : 4) {
            let s = WebSearch.clip(f.text, 140)
            let key = String(s.prefix(15))
            if used.contains(where: { $0.contains(key) }) { continue }
            used.append(s)
            points.append(s + "（\(f.host)）")
        }
        if plan.kind == .news {
            // 新聞：直接列出最新的標題
            points = hits.filter { $0.engine == "Google 新聞" }.prefix(5).map { $0.snippet } + points.prefix(2)
        }

        var t = ""
        if zh {
            t += "🔎 我的思路\n"
            t += "① 你問的是\(kindName[plan.kind] ?? "一般")的問題，重點是「\(plan.keywords)」。\n"
            t += "② 上網搜尋：" + plan.queries.prefix(3).map { "「\($0)」" }.joined(separator: "、")
            t += "，從 " + engines.filter { $0.value > 0 && $0.key != "instant" }.keys.sorted().joined(separator: "、") + " 找到 \(hits.count) 個結果。\n"
            t += "③ 打開 \(pages.count) 個網頁讀內容，挑出跟問題最相關的句子。\n"
            t += "④ 交叉比對：" + (common.isEmpty ? "各來源說法比較分散，我挑最相關的整理。" : "好幾個來源都提到「" + common.joined(separator: "」「") + "」。") + "\n"
            if let facts { t += "⑤ 對照你的盤：\(facts)。網路上的說法當作補充，判斷還是以你盤上的喜忌和流年為準。\n" }
            t += "\n📌 " + (fortune ? "網路上的說法" : "回答") + "\n" + answer
            if !points.isEmpty {
                let label = plan.kind == .method ? "步驟／做法" : plan.kind == .news ? "最新消息" : "重點"
                t += "\n\n\(label)：\n" + points.enumerated().map { plan.kind == .method ? "\($0.offset + 1). \($0.element)" : "• \($0.element)" }.joined(separator: "\n")
            }
            t += "\n\n把握程度：\(confidence)"
            t += "\n來源：" + sources.prefix(5).joined(separator: "、")
        } else {
            t += Loc.s("webResult", L, plan.keywords) + "\n\n" + answer
            if !points.isEmpty { t += "\n\n" + points.map { "• " + $0 }.joined(separator: "\n") }
            t += "\n\n" + Loc.s("webSources", L) + ": " + sources.prefix(5).joined(separator: ", ") + " · " + confidence
        }

        let links = orderedUnique((ranked.map(\.url) + hits.map(\.url)))
        let card = FortuneCard(title: fortune ? (zh ? "網路資料對照" : "Web check") : (zh ? "上網查到的資料" : "From the web"),
                               headline: plan.keywords,
                               details: Array(links.prefix(5)).map { WebSearch.host($0) + "  " + $0 },
                               link: links.first)
        return Result(text: t, card: card, found: true, engines: engines)
    }

    // MARK: - 挑句子

    static func sentences(_ s: String) -> [String] {
        var out: [String] = [], cur = ""
        for ch in s {
            if ch == "\n" {
                let t = cur.trimmingCharacters(in: .whitespaces)
                if t.count >= 12 && t.count <= 220 { out.append(t) }
                cur = ""
                continue
            }
            cur.append(ch)
            if "。！？!?；".contains(ch) || (ch == "." && cur.count > 40) {
                let t = cur.trimmingCharacters(in: .whitespaces)
                if t.count >= 12 && t.count <= 220 { out.append(t) }
                cur = ""
            }
        }
        return out.filter { !looksLikeJunk($0) }
    }

    /// 選單、版權、Cookie 提示之類的句子
    static func looksLikeJunk(_ s: String) -> Bool {
        let l = s.lowercased()
        let junk = ["cookie", "copyright", "版權所有", "all rights reserved", "登入", "註冊", "訂閱", "javascript", "隱私權", "privacy policy",
                    "點擊", "下載app", "分享到", "上一篇", "下一篇", "sign in", "subscribe", "廣告"]
        if junk.contains(where: { l.contains($0) }) { return true }
        let letters = s.filter { $0.isLetter }.count
        return Double(letters) / Double(max(1, s.count)) < 0.5
    }

    /// 問題的關鍵單位：中文用雙字組、外文用單字
    static func termSet(_ kw: String) -> Set<String> {
        var out = Set<String>()
        let l = kw.lowercased()
        for w in l.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            let c = Array(w)
            if c.contains(where: isCJK) {
                if c.count == 1 { out.insert(String(c)) }
                for i in 0..<max(0, c.count - 1) { out.insert(String(c[i...i + 1])) }
            } else if w.count >= 2 {
                out.insert(String(w))
            }
        }
        return out
    }

    static func score(_ s: String, _ terms: Set<String>) -> Int {
        let l = s.lowercased()
        return terms.filter { l.contains($0) }.count
    }

    /// 一句話適不適合當答案：跟主題的重疊、問數量時有沒有數字，扣掉列表、清單式的句子
    /// 除了主題本身（「台北101」的 101）以外，還有沒有數字
    static func hasNumber(_ s: String, besides core: String) -> Bool {
        s.replacingOccurrences(of: core, with: "").contains(where: \.isNumber)
    }

    static func quality(_ s: String, terms: Set<String>, numeric: Bool, core: String = "") -> Int {
        let hit = score(s, terms)
        guard hit > 0 else { return 0 }
        var q = hit * 4
        if hit * 2 >= terms.count { q += 4 }
        if numeric && hasNumber(s, besides: core) { q += 6 }
        let listy = s.components(separatedBy: "｜").count + s.components(separatedBy: "|").count - 2
            + (s.range(of: #"\d+\.\s*\D+\s*\d+\.\s"#, options: .regularExpression) != nil ? 3 : 0)
            + s.components(separatedBy: "、").count / 6
        q -= listy * 3
        if s.count > 160 { q -= 2 }
        if s.count < 20 { q -= 2 }
        return q
    }

    /// 和問題最相關的幾句
    static func best(_ ss: [String], terms: Set<String>, numeric: Bool, core: String, n: Int) -> [String] {
        let need = max(1, (terms.count + 1) / 3)
        var seen = Set<String>()
        return ss.filter { score($0, terms) >= need && seen.insert(String($0.prefix(20))).inserted }
            .map { ($0, quality($0, terms: terms, numeric: numeric, core: core)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }.prefix(n).map { $0.0 }
    }

    static func rank(_ fs: [Finding], terms: Set<String>, common: [String], numeric: Bool, core: String) -> [Finding] {
        fs.map { f -> (Finding, Int) in
            (f, quality(f.text, terms: terms, numeric: numeric, core: core) * 2 + common.filter { f.text.contains($0) }.count * 2)
        }.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    static func orderedUnique(_ xs: [String]) -> [String] {
        var seen = Set<String>()
        return xs.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    // MARK: - 交叉比對：好幾個來源都出現的詞

    static func consensus(_ fs: [Finding], exclude: String, cjkOnly: Bool) -> [String] {
        var bySource: [String: Set<String>] = [:]
        for f in fs {
            var grams = Set<String>()
            let chars = Array(f.text)
            for n in 2...4 where chars.count >= n {
                for i in 0...(chars.count - n) {
                    let g = chars[i..<(i + n)]
                    if g.allSatisfy(isCJK) { grams.insert(String(g)) }
                }
            }
            for w in f.text.lowercased().split(whereSeparator: { !$0.isLetter }) where !cjkOnly && w.count >= 5 && w.allSatisfy({ $0.isASCII }) {
                grams.insert(String(w))
            }
            bySource[f.host, default: []].formUnion(grams)
        }
        var count: [String: Int] = [:]
        for (_, g) in bySource { for x in g { count[x, default: 0] += 1 } }
        let stop: Set<String> = ["什麼", "一個", "可以", "我們", "你的", "自己", "這個", "就是", "因為", "所以", "如果", "還是", "沒有", "他們",
                                 "以及", "其實", "如何", "這些", "非常", "需要", "時候", "大家", "的人", "是一", "the", "which", "their",
                                 "about", "there", "these", "would", "other", "could", "should"]
        let ex = exclude.lowercased()
        let cands = count.filter { $0.value >= 2 && !stop.contains($0.key) && !ex.contains($0.key) }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.count > $1.key.count }
        var out: [String] = []
        for (g, _) in cands {
            if out.contains(where: { $0.contains(g) || g.contains($0) }) { continue }
            out.append(g)
            if out.count >= 5 { break }
        }
        return out
    }

    static func isCJK(_ c: Character) -> Bool {
        c.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
    }
}
