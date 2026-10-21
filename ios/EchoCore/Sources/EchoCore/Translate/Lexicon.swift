import Foundation

/// 離線字典（lexicon.tsv）：英文、中文、西班牙文、義大利文、阿拉伯文的常用詞。
/// 英文的意思是繁體中文；其他語言的意思是英文，要翻成第三種語言時用英文當橋樑。
/// 資料：ECDICT（MIT）、維基詞典（CC BY-SA 3.0），由 ai/build_lexicon.py 產生。
public final class Lexicon {
    public struct Entry: Equatable {
        public let lang: String
        public let word: String
        /// 讀音：英文音標、中文拼音、阿拉伯文拉丁拼音
        public let pron: String
        public let pos: String
        /// 意思，用「；」分開
        public let gloss: String
        /// 常用排名，越小越常用
        public let rank: Int

        public var senses: [String] { gloss.components(separatedBy: "；").filter { !$0.isEmpty } }
    }

    private let lines: [Substring]
    /// 語言 → 小寫的詞 → 第幾行
    private var index: [String: [String: Int32]] = [:]
    /// 英文 → 這個語言裡第一個意思就是它的詞（反查用，第一次用到才建）
    private var reverse: [String: [String: [Int32]]] = [:]
    private let lock = NSLock()

    nonisolated(unsafe) public static var shared: Lexicon?

    public init(text: String) {
        lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        for (i, l) in lines.enumerated() where !l.hasPrefix("#") {
            guard let t1 = l.firstIndex(of: "\t") else { continue }
            let lang = String(l[..<t1])
            let rest = l[l.index(after: t1)...]
            let word = rest.prefix { $0 != "\t" }
            let key = Lexicon.key(String(word))
            if index[lang]?[key] == nil { index[lang, default: [:]][key] = Int32(i) }
        }
    }

    public convenience init(bundle: Bundle, name: String = "lexicon") throws {
        guard let url = bundle.url(forResource: name, withExtension: "tsv") else { throw EchoError.missing("\(name).tsv") }
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    public var count: Int { index.values.reduce(0) { $0 + $1.count } }

    static func key(_ w: String) -> String {
        w.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "¿¡?!.,，。？！「」\"'“”")))
    }

    private func entry(_ i: Int32) -> Entry? {
        let f = lines[Int(i)].split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard f.count >= 5 else { return nil }
        return Entry(lang: f[0], word: f[1], pron: f[2], pos: f[3], gloss: f[4], rank: f.count > 5 ? Int(f[5]) ?? 99999 : 99999)
    }

    /// 查一個詞（變化形「comiendo → comer」會自動換成原形）
    public func lookup(_ word: String, lang: String) -> Entry? {
        let k = Lexicon.key(word)
        guard let i = index[lang]?[k], let e = entry(i) else {
            // 英文複數、過去式：試試看原形
            if lang == "en", k.count > 3 {
                for (suf, rep) in [("ies", "y"), ("es", ""), ("s", ""), ("ed", ""), ("ed", "e"), ("ing", ""), ("ing", "e")] where k.hasSuffix(suf) {
                    if let i = index["en"]?[String(k.dropLast(suf.count)) + rep], let e = entry(i) { return e }
                }
            }
            return nil
        }
        if e.pos == "→", let j = index[lang]?[Lexicon.key(e.gloss)], let base = entry(j) { return base }
        return e
    }

    /// 這個詞在不在字典裡
    public func has(_ word: String, lang: String) -> Bool { index[lang]?[Lexicon.key(word)] != nil }

    /// 英文意思的關鍵字：「(transitive) to eat [auxiliary avere]」→「eat」
    public static func head(_ sense: String) -> String {
        var s = sense.replacingOccurrences(of: #"\([^)]*\)|\[[^\]]*\]|“[^”]*”"#, with: "", options: .regularExpression)
        s = s.components(separatedBy: CharacterSet(charactersIn: ",;:")).first ?? s
        s = s.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "!.?")))
        if s.lowercased().hasPrefix("to ") { s = String(s.dropFirst(3)) }
        for a in ["a ", "an ", "the "] where s.lowercased().hasPrefix(a) { s = String(s.dropFirst(a.count)) }
        return s.lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// 英文意思裡的幾個說法：「hello, hi」→ [hello, hi]
    public static func heads(_ sense: String) -> [String] {
        let s = sense.replacingOccurrences(of: #"\([^)]*\)|\[[^\]]*\]"#, with: "", options: .regularExpression)
        return s.components(separatedBy: CharacterSet(charactersIn: ",;")).map { head($0) }.filter { !$0.isEmpty }
    }

    /// 反查：英文 → 這個語言的詞。cands 是同一個意思的幾種英文說法（thanks、thank you），越前面越重要。
    /// 對方的第一個意思、第一個說法就是它的最好；詞性一樣、比較常用的優先。
    public func find(english cands: [String], in lang: String, pos: String = "") -> [Entry] {
        lock.lock()
        if reverse[lang] == nil {
            var r: [String: [Int32]] = [:]
            for i in (index[lang] ?? [:]).values {
                guard let e = entry(i), e.pos != "→" else { continue }
                for sense in e.senses.prefix(2) {
                    for h in Lexicon.heads(sense).prefix(3) where h.count <= 30 {
                        r[h, default: []].append(i)
                    }
                }
            }
            reverse[lang] = r
        }
        let table = reverse[lang] ?? [:]
        lock.unlock()
        let firstPos = pos.split(separator: ",").first.map(String.init) ?? ""
        var best: [String: (score: Int, entry: Entry)] = [:]
        for (ci, c) in cands.prefix(3).enumerated() {
            let t = Lexicon.head(c)
            for i in table[t] ?? [] {
                guard let e = entry(i) else { continue }
                let ss = e.senses
                var pen = 1_000_000
                for (n, sense) in ss.prefix(2).enumerated() {
                    if let j = Lexicon.heads(sense).prefix(3).firstIndex(of: t) { pen = min(pen, n * 400 + j * 100) }
                }
                var s = pen + ci * 80 + e.rank / 50
                if e.pos.hasPrefix("name") { s += 300 }
                if !firstPos.isEmpty, e.pos.split(separator: ",").first.map(String.init) == firstPos { s -= 150 }
                if ss.count == 1 { s -= 30 }
                if best[e.word] == nil || s < best[e.word]!.score { best[e.word] = (s, e) }
            }
        }
        return best.values.sorted { $0.score < $1.score }.map(\.entry)
    }

    public func find(english w: String, in lang: String) -> [Entry] { find(english: [w], in: lang) }
}
