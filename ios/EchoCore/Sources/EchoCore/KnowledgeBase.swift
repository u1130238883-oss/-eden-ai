import Foundation

/// 內建資料庫：六十四卦、天干地支、五行、十神、紫微星曜、四化、九型十二宮…（ai/knowledge_data.py 產生）
public final class KnowledgeBase {
    public struct Entry: Codable, Identifiable, Equatable {
        public var id: String { title }
        public let cat: String
        public let title: String
        public let aliases: [String]
        public let body: String
    }

    public let entries: [Entry]
    public let lang: Lang
    public var categories: [String] {
        var seen = Set<String>(), out: [String] = []
        for e in entries where seen.insert(e.cat).inserted { out.append(e.cat) }
        return out
    }

    public init(entries: [Entry], lang: Lang = .zh) {
        self.entries = entries
        self.lang = lang
    }

    public convenience init(json: Data, lang: Lang = .zh) throws {
        self.init(entries: try JSONDecoder().decode([Entry].self, from: json), lang: lang)
    }

    public convenience init(bundle: Bundle, lang: Lang = .zh) throws {
        let name = "knowledge_\(lang.rawValue)"
        guard let url = bundle.url(forResource: name, withExtension: "json") else { throw EchoError.missing(name) }
        try self.init(json: Data(contentsOf: url), lang: lang)
    }

    static let fillers = ["維基百科", "維基", "是誰", "是什麼意思", "什麼意思", "是什麼", "什麼是", "的意思", "代表什麼", "代表", "介紹一下", "介紹",
                          "請問", "查一下", "幫我查", "搜尋", "查詢", "查", "告訴我", "解釋", "？", "?", "。", "！", " ", "一下"]

    static let foreignFillers = ["what is", "what's", "what does", " mean", "tell me about", "meaning of", "look up", "search",
                                 "who is", "explain", "wikipedia", "qué es", "que es", "qué significa", "significa", "háblame de",
                                 "hablame de", "buscar", "busca", "quién es", "quien es", "explica", "cos'è", "cosa è",
                                 "cosa significa", "parlami di", "cerca", "chi è", "spiega", "?", "¿", "!", "¡", "."]

    static let articles: Set<String> = ["the", "a", "an", "el", "la", "los", "las", "lo", "un", "una", "uno", "il", "gli",
                                        "i", "le", "del", "della", "de"]

    /// 從問句中取出關鍵詞
    public static func keyword(_ q: String, lang: Lang = .zh) -> String {
        if lang == .zh {
            var s = q
            for f in fillers { s = s.replacingOccurrences(of: f, with: "") }
            return s
        }
        var s = q.lowercased()
        for f in foreignFillers { s = s.replacingOccurrences(of: f, with: " ") }
        var words = s.split(separator: " ").map(String.init)
        // 去掉開頭的冠詞（the / el / la / il / l'…）
        while words.count > 1, articles.contains(words[0]) { words.removeFirst() }
        if let w = words.first, w.hasPrefix("l'") || w.hasPrefix("un'") {
            words[0] = String(w[w.index(after: w.firstIndex(of: "'")!)...])
        }
        return words.joined(separator: " ")
    }

    static func bigrams(_ s: String) -> Set<String> {
        let c = Array(s)
        guard c.count > 1 else { return Set(c.map(String.init)) }
        var out = Set<String>()
        for i in 0..<(c.count - 1) { out.insert(String(c[i]) + String(c[i + 1])) }
        return out
    }

    /// 搜尋：別名完全相符 > 標題包含 > 雙字重疊
    public func search(_ query: String, limit: Int = 20) -> [(entry: Entry, score: Double)] {
        let low = lang != .zh
        let k = KnowledgeBase.keyword(query, lang: lang)
        guard !k.isEmpty else { return [] }
        let qb = KnowledgeBase.bigrams(k)
        var scored: [(Entry, Double)] = []
        for e in entries {
            var s = 0.0
            let title = low ? e.title.lowercased() : e.title
            let aliases = low ? e.aliases.map { $0.lowercased() } : e.aliases
            let body = low ? e.body.lowercased() : e.body
            if aliases.contains(k) || title == k { s += 10 }
            if title.contains(k) { s += 5 + Double(k.count) / Double(max(1, title.count)) }
            if aliases.contains(where: { $0.contains(k) }) { s += 3 }
            if k.count >= (low ? 4 : 2) && body.contains(k) { s += 1.5 }
            let tb = KnowledgeBase.bigrams(title + aliases.joined())
            if !qb.isEmpty { s += 2 * Double(qb.intersection(tb).count) / Double(qb.count) }
            if s > 0 { scored.append((e, s)) }
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { ($0.0, $0.1) }
    }

    /// 這句話提到的條目（標題或別名出現在句子裡）：交給大腦當參考資料。名字越長、越具體越優先；
    /// 被更長的名字蓋過的短名字不算（問「急性腸胃炎」就不要再給「腸胃炎」以外的「胃」）
    public func mentioned(in text: String, limit: Int = 2) -> [Entry] {
        let chem = ["元素", "化學", "符號", "原子"].contains { text.contains($0) }
        var hits: [(entry: Entry, name: String)] = []
        for e in entries {
            let names = ([e.title] + e.aliases).filter { $0.count >= 2 || (chem && e.cat == "化學元素") }
            if let best = names.filter({ text.contains($0) }).max(by: { $0.count < $1.count }) { hits.append((e, best)) }
        }
        hits = hits.filter { h in !hits.contains { $0.name.count > h.name.count && $0.name.contains(h.name) } }
        var out = hits.sorted { $0.name.count > $1.name.count }.prefix(limit).map(\.entry)
        // 「為什麼天空是藍的」這種整句的條目：用雙字重疊找
        if out.isEmpty, let best = search(text, limit: 1).first, best.score >= 1.2,
           ["為什麼", "急救衛教"].contains(best.entry.cat) {
            out = [best.entry]
        }
        return Array(out)
    }

    /// 對話用：只在很有把握時回答
    public func answer(_ query: String) -> Entry? {
        guard let best = search(query, limit: 1).first, best.score >= 5 else { return nil }
        return best.entry
    }
}
