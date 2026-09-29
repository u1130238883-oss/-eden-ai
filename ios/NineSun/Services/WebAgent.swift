import EchoCore
import Foundation

/// NineSun 自己上網找答案的思路：
///   ① 理解問題（是哪一類問題、重點是什麼）
///   ② 規劃要搜尋的關鍵字
///   ③ 搜尋（DuckDuckGo／Bing／維基百科，不需要金鑰）
///   ④ 打開網頁閱讀，挑出和問題最相關的句子
///   ⑤ 交叉比對：好幾個來源都提到的說法才可信
///   ⑥ 回答，附上思路、把握程度和來源
///   ⑦ 記住查到的答案，下次不用再查
enum WebAgent {
    enum Kind { case define, reason, method, compare, recommend, news, person, fortune, general }

    struct Plan { let kind: Kind; let keywords: String; let queries: [String] }
    struct Finding { let text: String; let host: String; let url: String }
    struct Result { let text: String; let card: FortuneCard? }

    static let kindName: [Kind: String] = [
        .define: "「是什麼」", .reason: "「為什麼」", .method: "「怎麼做」", .compare: "「比較」",
        .recommend: "「推薦」", .news: "「最新消息」", .person: "「人物」", .fortune: "命理", .general: "一般",
    ]

    // MARK: - ① 理解問題 ② 規劃搜尋

    static func understand(_ question: String, L: Lang, fortune: Bool) -> Plan {
        let q = question.lowercased()
        func has(_ ws: [String]) -> Bool { ws.contains { q.contains($0) } }
        let kind: Kind
        if fortune { kind = .fortune }
        else if has(["差別", "區別", "比較", "哪個好", "哪一個好", " vs", "difference", "better than", "diferencia", "differenza"]) { kind = .compare }
        else if has(["為什麼", "為何", "原因", "why", "por qué", "perché"]) { kind = .reason }
        else if has(["怎麼", "如何", "方法", "步驟", "教我", "how to", "how do", "how can", "cómo", "come si"]) { kind = .method }
        else if has(["推薦", "有哪些", "哪裡", "recommend", "best ", "recomienda", "consiglia"]) { kind = .recommend }
        else if has(["最新", "新聞", "今天", "最近", "現在", "天氣", "股價", "latest", "news", "today", "weather", "noticias", "notizie"]) { kind = .news }
        else if has(["是誰", "誰是", "who is", "quién es", "chi è"]) { kind = .person }
        else if has(["是什麼", "什麼是", "什麼意思", "定義", "what is", "what are", "meaning", "qué es", "cos'è"]) { kind = .define }
        else { kind = .general }

        let kw = keywords(question)
        var qs = [kw]
        let extra: [Kind: String] = L == .zh
            ? [.define: " 是什麼", .reason: " 原因", .method: " 方法 步驟", .compare: " 差別", .recommend: " 推薦", .news: " 最新", .person: " 簡介"]
            : [.define: " meaning", .reason: " reason", .method: " how to steps", .compare: " difference", .recommend: " best", .news: " latest", .person: " biography"]
        if let e = extra[kind], !kw.hasSuffix(e.trimmingCharacters(in: .whitespaces)) { qs.append(kw + e) }
        var seen = Set<String>()
        return Plan(kind: kind, keywords: kw, queries: qs.filter { seen.insert($0).inserted })
    }

    /// 把口語問句整理成關鍵字
    static func keywords(_ raw: String) -> String {
        var q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.hasPrefix("請") && !q.hasPrefix("請問") { q.removeFirst() }
        for w in ["請問", "請你", "請幫我", "幫我查一下", "幫我查", "幫我", "可以告訴我", "告訴我", "你知道", "我想知道", "一下",
                  "是什麼意思", "什麼意思", "是什麼", "什麼是", "為什麼", "怎麼樣", "怎麼", "如何", "有哪些", "是誰", "誰是",
                  "呀", "啊", "呢", "吧", "嗎", "？", "?", "！", "!", "。", "，"] {
            q = q.replacingOccurrences(of: w, with: " ")
        }
        let parts = q.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        let out = parts.joined(separator: " ")
        return out.isEmpty ? raw : out
    }

    // MARK: - 主流程

    static func run(_ question: String, facts: String?, lang L: Lang, memory: WebMemory) async -> Result {
        let fortune = facts != nil
        let plan = understand(question, L: L, fortune: fortune)

        // ⑦ 之前查過（新聞類不用舊答案）
        if plan.kind != .news, !fortune, let m = memory.recall(question) {
            let when = DateFormatter.localizedString(from: m.date, dateStyle: .short, timeStyle: .none)
            return Result(text: "這題我之前上網查過（\(when)），記得是這樣：\n\n" + m.answer + "\n\n（想要最新的資料，可以說「重新查\(plan.keywords)」。）", card: nil)
        }

        // ③ 搜尋
        var hits: [WebSearch.Hit] = []
        var lead: String?
        var seenURL = Set<String>()
        for q in plan.queries.prefix(2) {
            guard let a = await WebSearch.search(q, lang: L) else { continue }
            if lead == nil { lead = a.lead }
            for h in a.hits where seenURL.insert(h.url).inserted { hits.append(h) }
        }
        if hits.isEmpty && lead == nil {
            return Result(text: Loc.s("webFail", L, plan.keywords), card: nil)
        }

        // ④ 閱讀網頁：打開前兩個網頁，挑出最相關的句子
        let terms = Set(plan.keywords.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation })
        var findings: [Finding] = []
        var read = 0
        for h in hits.prefix(3) {
            guard read < 2, let page = await fetchText(h.url, L) else { continue }
            read += 1
            for s in best(sentences(page), terms: terms, n: 3) { findings.append(Finding(text: s, host: WebSearch.host(h.url), url: h.url)) }
        }
        for h in hits where !h.snippet.isEmpty { findings.append(Finding(text: h.snippet, host: WebSearch.host(h.url), url: h.url)) }

        // ⑤ 交叉比對
        let common = consensus(findings, exclude: plan.keywords)
        let sources = Set(findings.map(\.host))
        let confidence: String
        if sources.count >= 3 && common.count >= 2 { confidence = "高（\(sources.count) 個來源，說法大致一致）" }
        else if sources.count >= 2 { confidence = "中（\(sources.count) 個來源，可以參考）" }
        else { confidence = "低（來源少，建議再確認）" }

        // ⑥ 回答
        var t = "🔎 我的思路\n"
        t += "① 先弄清楚你問的：這是\(kindName[plan.kind] ?? "一般")的問題，重點是「\(plan.keywords)」。\n"
        t += "② 我上網搜尋了：" + plan.queries.prefix(2).map { "「\($0)」" }.joined(separator: "、") + "，找到 \(hits.count) 個結果。\n"
        t += "③ 打開其中 \(read) 個網頁讀內容，挑出跟問題最相關的句子。\n"
        t += "④ 交叉比對：" + (common.isEmpty ? "各來源說法比較分散，我挑最相關的整理。" : "好幾個來源都提到「" + common.joined(separator: "」「") + "」。") + "\n"
        if let facts { t += "⑤ 對照你的盤：\(facts)。網路上的說法當作補充，判斷還是以你盤上的喜忌和流年為準。\n" }

        var answer = ""
        let ranked = rank(findings, terms: terms, common: common)
        if let lead { answer += WebSearch.clip(lead, 240) }
        else if let first = ranked.first { answer += WebSearch.clip(first.text, 220) }
        var used = Set<String>([answer])
        var points: [String] = []
        for f in ranked where points.count < 4 {
            let s = WebSearch.clip(f.text, 130)
            if used.contains(where: { $0.contains(String(s.prefix(15))) }) { continue }
            used.insert(s)
            points.append(s + "（\(f.host)）")
        }
        t += "\n📌 " + (fortune ? "網路上的說法" : "回答") + "\n" + answer
        if !points.isEmpty {
            let label = plan.kind == .method ? "步驟／做法" : "重點"
            t += "\n\n\(label)：\n" + points.enumerated().map { plan.kind == .method ? "\($0.offset + 1). \($0.element)" : "• \($0.element)" }.joined(separator: "\n")
        }
        t += "\n\n把握程度：\(confidence)"

        if !fortune { memory.remember(question, answer: answer + (points.isEmpty ? "" : "\n" + points.map { "• " + $0 }.joined(separator: "\n"))) }
        let card = FortuneCard(title: fortune ? "網路資料對照" : "上網查到的資料", headline: plan.keywords,
                               details: Array(sources.prefix(5)), link: ranked.first?.url ?? hits.first?.url)
        return Result(text: t, card: card)
    }

    // MARK: - 讀網頁

    static func fetchText(_ url: String, _ L: Lang) async -> String? {
        guard let u = URL(string: url), u.scheme?.hasPrefix("http") == true,
              let d = await WebSearch.get(u, L), d.count < 3_000_000 else { return nil }
        guard var html = String(data: d, encoding: .utf8) ?? String(data: d, encoding: .isoLatin1) else { return nil }
        for tag in ["script", "style", "noscript", "header", "footer", "nav", "svg"] {
            html = html.replacingOccurrences(of: "(?s)<\(tag)[^>]*>.*?</\(tag)>", with: " ", options: [.regularExpression, .caseInsensitive])
        }
        html = html.replacingOccurrences(of: "<(br|p|div|li|h[1-6]|tr)[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        return WebSearch.clean(html.replacingOccurrences(of: "\n", with: "。"))
    }

    static func sentences(_ s: String) -> [String] {
        var out: [String] = [], cur = ""
        for ch in s {
            cur.append(ch)
            if "。！？!?；".contains(ch) || (ch == "." && cur.count > 40) {
                let t = cur.trimmingCharacters(in: .whitespaces)
                if t.count >= 12 && t.count <= 220 { out.append(t) }
                cur = ""
            }
        }
        return out
    }

    /// 和問題重疊最多的幾句
    static func best(_ ss: [String], terms: Set<Character>, n: Int) -> [String] {
        let scored = ss.map { s -> (String, Int) in (s, Set(s.lowercased()).intersection(terms).count) }
        return scored.filter { $0.1 >= max(2, terms.count / 3) }.sorted { $0.1 > $1.1 }.prefix(n).map { $0.0 }
    }

    static func rank(_ fs: [Finding], terms: Set<Character>, common: [String]) -> [Finding] {
        fs.map { f -> (Finding, Int) in
            let base = Set(f.text.lowercased()).intersection(terms).count * 2
            return (f, base + common.filter { f.text.contains($0) }.count * 3)
        }.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    // MARK: - 交叉比對：好幾個來源都出現的詞

    static func consensus(_ fs: [Finding], exclude: String) -> [String] {
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
            for w in f.text.lowercased().split(whereSeparator: { !$0.isLetter }) where w.count >= 5 && w.allSatisfy({ $0.isASCII }) {
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

/// 查過的答案記在手機裡（下次不用再查）
final class WebMemory {
    struct Entry: Codable { let q: String; let answer: String; let date: Date }
    private(set) var entries: [Entry] = []
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ninesun-webmemory.json")

    init() {
        if let d = try? Data(contentsOf: url), let e = try? JSONDecoder().decode([Entry].self, from: d) { entries = e }
    }

    func recall(_ q: String) -> Entry? {
        let g = WebMemory.grams(q)
        guard !g.isEmpty else { return nil }
        var best: (Entry, Double)?
        for e in entries {
            let h = WebMemory.grams(e.q)
            guard !h.isEmpty else { continue }
            let s = 2 * Double(g.intersection(h).count) / Double(g.count + h.count)
            if s > (best?.1 ?? 0) { best = (e, s) }
        }
        return (best?.1 ?? 0) >= 0.8 ? best?.0 : nil
    }

    func remember(_ q: String, answer: String) {
        entries.removeAll { $0.q == q }
        entries.append(Entry(q: q, answer: answer, date: Date()))
        if entries.count > 300 { entries.removeFirst(entries.count - 300) }
        if let d = try? JSONEncoder().encode(entries) { try? d.write(to: url, options: .atomic) }
    }

    func forget(_ q: String) { entries.removeAll { $0.q.contains(q) || q.contains($0.q) } }

    static func grams(_ s: String) -> Set<String> {
        let c = Array(s.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation })
        guard c.count > 1 else { return Set(c.map(String.init)) }
        return Set((0..<(c.count - 1)).map { String(c[$0]) + String(c[$0 + 1]) })
    }
}
