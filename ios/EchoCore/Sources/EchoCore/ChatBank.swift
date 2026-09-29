import Foundation

/// 對話庫：手寫問答（人設、日常、生活）以字元雙字組相似度檢索。
/// 命中就直接用人寫好的答案回答；沒命中就交給下一層，不亂編。可以隨時擴充 chat_bank.json，不用重新訓練。
public final class ChatBank {
    struct Entry: Decodable { let q: [String]; let a: [String] }
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

    static func bigrams(_ s: String) -> Set<String> {
        let c = Array(s.replacingOccurrences(of: " ", with: ""))
        guard c.count > 1 else { return Set(c.map(String.init)) }
        return Set((0..<(c.count - 1)).map { String(c[$0]) + String(c[$0 + 1]) })
    }

    func match(_ text: String, _ L: Lang) -> Hit? {
        guard let list = index[L], let all = entries[L] else { return nil }
        let t = ChatBank.norm(text)
        guard !t.isEmpty else { return nil }
        let tg = ChatBank.bigrams(t)
        let minLen = L == .zh ? 2 : 4
        var best: (Int, Double)?
        for item in list {
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
            if s > (best?.1 ?? 0) { best = (item.entry, s) }
        }
        guard let (i, score) = best, score >= (L == .zh ? 0.65 : 0.7) else { return nil }
        return Hit(entry: all[i], score: score)
    }

    /// 回傳這題的候選答案（同一題有好幾種說法）；沒命中回傳 nil
    public func answers(_ text: String, _ L: Lang) -> [String]? { match(text, L)?.entry.a }
}
