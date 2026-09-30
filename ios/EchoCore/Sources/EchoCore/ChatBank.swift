import Foundation

/// 對話庫：手寫問答（人設、日常、生活）以字元雙字組相似度檢索。
/// 命中就直接用人寫好的答案回答；沒命中就交給下一層，不亂編。可以隨時擴充 chat_bank.json，不用重新訓練。
public final class ChatBank {
    /// k：思路庫的關鍵詞（換句話說時，命中關鍵詞也算同一題）
    struct Entry: Decodable { let q: [String]; let a: [String]; let k: [String]?; let w: Bool? }
    struct Hit { let entry: Entry; let score: Double }

    let entries: [Lang: [Entry]]
    /// 預先算好的（正規化後問句、雙字組）
    private let index: [Lang: [(entry: Int, norm: String, grams: Set<String>)]]

    public init(json: Data) throws {
        let raw = try JSONDecoder().decode([String: [Entry]].self, from: json)
        var all: [Lang: [Entry]] = [:]
        var idx: [Lang: [(entry: Int, norm: String, grams: Set<String>)]] = [:]
        for (k, v) in raw {
            guard let L = Lang(rawValue: k) else { continue }
            all[L] = v
            var list: [(entry: Int, norm: String, grams: Set<String>)] = []
            for (i, e) in v.enumerated() {
                for q in e.q {
                    let n = ChatBank.norm(q)
                    list.append((i, n, ChatBank.bigrams(n)))
                }
            }
            idx[L] = list
        }
        entries = all
        index = idx
    }

    public convenience init(bundle: Bundle) throws {
        guard let url = bundle.url(forResource: "chat_bank", withExtension: "json") else { throw EchoError.missing("chat_bank.json") }
        try self.init(json: Data(contentsOf: url))
    }

    /// 小寫、去標點與空白（中文不需要空白；外語保留單一空白）
    static func norm(_ s: String) -> String {
        var out = ""
        var lastSpace = true
        for ch in s.lowercased() {
            if ch.isLetter || ch.isNumber {
                out.append(ch); lastSpace = false
            } else if ch.isWhitespace || ch == "'" {
                if ch == "'" { out.append(ch) } else if !lastSpace { out.append(" "); lastSpace = true }
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    static let askMarkers = ["怎麼", "怎樣", "如何", "要不要", "該不該", "嗎", "什麼", "為什麼", "哪", "辦", "可不可以", "能不能", "有沒有",
                             "多少", "有幾", "幾個", "幾種", "幾步", "多遠", "多高", "多久", "多重", "多大", "多長", "是不是", "應該", "不了", "不到", "一直", "好難", "不知道", "緊張", "不行"]

    static func bigrams(_ s: String) -> Set<String> {
        let c = Array(s.replacingOccurrences(of: " ", with: ""))
        guard c.count > 1 else { return Set(c.map(String.init)) }
        var out = Set<String>()
        for i in 0..<(c.count - 1) { out.insert(String(c[i]) + String(c[i + 1])) }
        return out
    }

    func match(_ text: String, _ L: Lang, useKeywords: Bool = true, onlyPlaybook: Bool = false) -> Hit? {
        guard let list = index[L], let all = entries[L] else { return nil }
        let t = ChatBank.norm(text)
        guard !t.isEmpty else { return nil }
        let tg = ChatBank.bigrams(t)
        let minLen = L == .zh ? 2 : 4
        var best: (Int, Double)?
        for item in list {
            if onlyPlaybook && all[item.entry].k == nil { continue }
            var s = 0.0
            if t == item.norm { s = 1 }
            else {
                if item.norm.count >= minLen, t.contains(item.norm) { s = max(s, Double(item.norm.count) / Double(t.count)) }
                if t.count >= minLen, item.norm.contains(t) { s = max(s, Double(t.count) / Double(item.norm.count)) }
                if !tg.isEmpty, !item.grams.isEmpty {
                    let inter = tg.intersection(item.grams).count
                    s = max(s, 2 * Double(inter) / Double(tg.count + item.grams.count))
                }
            }
            // 思路庫的題目只差一個主題詞（「歐洲」→「亞洲」、「歐洲」→「歐盟」）時字面很像，答案卻完全不對：
            // 不是幾乎一模一樣的話，至少要命中一個關鍵詞
            if s < 0.9, let ks = all[item.entry].k, !ks.isEmpty, !ks.contains(where: { t.contains($0.lowercased()) }) { continue }
            if s > (best?.1 ?? 0) { best = (item.entry, s) }
        }
        // 關鍵詞比對：命中 2 個以上，或是問句／在講困擾時命中 1 個（和 ai/ 的 Python 版一致）
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let ask = ChatBank.askMarkers.contains { t.contains($0) } || raw.hasSuffix("?") || raw.hasSuffix("？")
        for (i, e) in all.enumerated() where useKeywords {
            let ks = (e.k ?? []).filter { $0.count >= 2 }
            if ks.isEmpty { continue }
            let m = ks.filter { t.contains($0.lowercased()) }.count
            if !(m >= 2 || (m == 1 && ask)) { continue }
            let s = min(0.9, 0.66 + 0.04 * Double(m - 1))
            if s > (best?.1 ?? 0) { best = (i, s) }
        }
        guard let (i, score) = best, score >= (L == .zh ? 0.65 : 0.7) else { return nil }
        return Hit(entry: all[i], score: score)
    }

    /// 回傳這題的候選答案（同一題有好幾種說法）；沒命中回傳 nil
    public func answers(_ text: String, _ L: Lang, useKeywords: Bool = true) -> [String]? { match(text, L, useKeywords: useKeywords)?.entry.a }

    /// 只看思路庫（有關鍵詞的那些）：實用型問題的寫好答案
    public func playbook(_ text: String, _ L: Lang) -> [String]? { match(text, L, onlyPlaybook: true)?.entry.a }

    /// 思路庫答案＋要不要再上網補充（腦筋急轉彎、常識題本地就答完了，不用上網）
    public func playbookEntry(_ text: String, _ L: Lang) -> (answers: [String], web: Bool)? {
        guard let e = match(text, L, onlyPlaybook: true)?.entry else { return nil }
        return (e.a, e.w ?? true)
    }
}
