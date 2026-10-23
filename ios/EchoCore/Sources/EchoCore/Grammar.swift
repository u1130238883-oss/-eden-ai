import Foundation

/// 詞性和仿寫：分辨一段話裡哪些是名詞、動詞、形容詞、副詞，再照同樣的結構（同樣的詞性順序、同樣的功能詞）寫一段不同的短文。
///   「美麗的蝴蝶輕輕地飛翔。」→ 形容詞＋的＋名詞＋副詞＋地＋動詞 → 仿寫「可愛的小鹿悄悄地奔跑。」
/// 認得的詞查詞庫（ai/grammar/lexicon.py）；不認得的詞像人一樣看上下文：
///   後面是「地」→ 副詞；前面是「很、非常」→ 形容詞；後面是「的」→ 形容詞；後面是「著、了」或前面是「地」→ 動詞；
///   在「在…裡／上」中間、在「的、著、把、和」後面 → 名詞。
public enum Grammar {
    public enum POS: String {
        case noun = "N", verb = "V", adj = "A", adv = "D"
        public var name: String { ["N": "名詞", "V": "動詞", "A": "形容詞", "D": "副詞"][rawValue]! }
        var short: String { ["N": "名", "V": "動", "A": "形", "D": "副"][rawValue]! }
    }

    public struct Token: Equatable {
        public let text: String
        public var pos: POS?       // nil＝功能詞、標點
        public var cat: String?    // 語意的小類（animal、vmove…）；不認得的詞是 nil
    }

    static let lexicon: [String: (cat: String, pos: POS)] = {
        var d: [String: (String, POS)] = [:]
        for (c, p, ws) in GrammarData.words { for w in ws { d[w] = (c, POS(rawValue: p)!) } }
        return d
    }()
    static let byCat: [String: [String]] = Dictionary(GrammarData.words.map { ($0.0, $0.2) }, uniquingKeysWith: { a, _ in a })
    static let catPOS: [String: POS] = Dictionary(GrammarData.words.map { ($0.0, POS(rawValue: $0.1)!) }, uniquingKeysWith: { a, _ in a })
    static let function = Set(GrammarData.function)
    static let maxLen = max(lexicon.keys.map(\.count).max() ?? 4, GrammarData.function.map(\.count).max() ?? 2)

    static func isPunct(_ c: Character) -> Bool { !(c.isLetter || c.isNumber) }

    // MARK: - 斷詞

    /// 最長的認得的詞優先；認不得的字連在一起當一個詞（太長的兩個字一組）
    public static func segment(_ s: String) -> [Token] {
        let cs = Array(s)
        var out: [Token] = [], unknown = "", i = 0
        func flush() {
            guard !unknown.isEmpty else { return }
            let u = Array(unknown)
            if u.count >= 4 {
                // 「偶爾徐徐」「極其晶瑩」：兩個不認得的詞連在一起，兩個字一組
                var j = 0
                while j < u.count { let n = (u.count - j == 3) ? 3 : 2; out.append(Token(text: String(u[j..<min(u.count, j + n)]), pos: nil, cat: nil)); j += n }
            } else { out.append(Token(text: unknown, pos: nil, cat: nil)) }
            unknown = ""
        }
        while i < cs.count {
            if isPunct(cs[i]) { flush(); out.append(Token(text: String(cs[i]), pos: nil, cat: "punct")); i += 1; continue }
            var hit: String?
            for n in stride(from: min(maxLen, cs.count - i), through: 1, by: -1) {
                let w = String(cs[i..<(i + n)])
                if lexicon[w] != nil || function.contains(w) { hit = w; break }
            }
            if let w = hit {
                flush()
                if let e = lexicon[w] { out.append(Token(text: w, pos: e.pos, cat: e.cat)) } else { out.append(Token(text: w, pos: nil, cat: "function")) }
                i += w.count
            } else { unknown.append(cs[i]); i += 1 }
        }
        flush()
        return out
    }

    // MARK: - 標詞性

    static let degree: Set<String> = Set(byCat["advd"] ?? [])

    public static func tag(_ s: String) -> [Token] {
        var t = segment(s)
        // 連在一起的不認得的詞（兩個字一組切開的）：句首的是主角（名詞），其他的是修飾後面的（副詞）
        for i in t.indices where t[i].cat == nil && t[i].pos == nil && i + 1 < t.count && t[i + 1].cat == nil && t[i + 1].pos == nil {
            let pt = i > 0 ? t[i - 1].text : "。"
            t[i].pos = ["。", "，", "！", "？", "和"].contains(pt) ? .noun : .adv
        }
        for i in t.indices where t[i].cat == nil && t[i].pos == nil {
            let prev = i > 0 ? t[i - 1] : nil, next = i + 1 < t.count ? t[i + 1] : nil
            let pt = prev?.text ?? "", nt = next?.text ?? ""
            let p: POS
            if nt == "地" { p = .adv }
            else if let pv = prev, pv.pos == .adv, degree.contains(pv.text) { p = .adj }
            else if nt == "的" { p = .adj }
            else if ["裡", "上"].contains(pt) { p = .verb }
            else if ["著", "了", "起來"].contains(nt) || pt == "地" { p = .verb }
            else if ["裡", "上"].contains(nt) || ["的", "著", "把", "和", "在"].contains(pt) { p = .noun }
            else if ["和", "在", "覺得", "把"].contains(nt) { p = .noun }
            else if nt == "，", prev == nil || ["。", "，"].contains(pt) { p = .adv }
            else if let nx = next, nx.pos == .adv || nx.pos == .verb { p = .noun }
            else if let pv = prev, pv.pos == .adv, ["。", "，", ""].contains(nt) { p = .verb }
            else if let pv = prev, pv.pos == .noun { p = .verb }
            else { p = .noun }
            t[i].pos = p
        }
        return t
    }

    /// 只留內容詞（名動形副）
    public static func content(_ tokens: [Token]) -> [Token] { tokens.filter { $0.pos != nil } }

    /// 結構：內容詞換成詞性，功能詞照寫（「[形]的[名][副]地[動]。」）
    public static func skeleton(_ tokens: [Token]) -> String {
        tokens.map { $0.pos.map { "[\($0.short)]" } ?? $0.text }.joined()
    }

    // MARK: - 仿寫

    /// 不認得的詞猜它是哪一小類（才知道換成什麼詞句子會通順）
    static func guessCat(_ t: [Token], _ i: Int) -> String {
        let tk = t[i]
        let prev = i > 0 ? t[i - 1].text : "", next = i + 1 < t.count ? t[i + 1].text : ""
        switch tk.pos {
        case .noun?:
            if prev == "在" || ["裡", "上"].contains(next) { return "place" }
            if ["著", "把"].contains(prev) { return "thing" }
            let nextVerb = t[(i + 1)...].first { $0.pos == .verb }?.cat
            switch nextVerb {
            case "vplant"?: return "plant"
            case "vnature"?: return "nature"
            case "vtrans"?: return "person"
            default: return prev == "的" && ["。", "，"].contains(next) ? "thing" : "animal"
            }
        case .verb?:
            let subj = t[..<i].last { $0.pos == .noun }.map { $0.cat ?? "animal" } ?? "animal"
            if next == "著" || next == "起來" { return subj == "nature" ? "vnature" : "vtrans" }
            return ["plant": "vplant", "nature": "vnature", "person": "vsound"][subj] ?? "vmove"
        case .adj?: return "adj"
        default:
            if next == "地" { return "advm" }
            if i + 1 < t.count, t[i + 1].pos == .adj { return "advd" }
            if next == "，" { return "advs" }
            return "advt"
        }
    }

    /// 同樣的結構、不同的詞：每個內容詞換成同一小類裡的另一個詞，功能詞不變
    public static func imitate(_ s: String) -> String {
        let t = tag(s)
        var seed = Writer.stable(s)
        var used: [String: Set<String>] = [:]   // 同一句裡同一小類不要重複（「小貓和小貓」）
        var out = ""
        for (i, tk) in t.enumerated() {
            guard tk.pos != nil else {
                out += tk.text
                if tk.text == "。" || tk.text == "！" || tk.text == "？" { used = [:] }
                continue
            }
            let cat = tk.cat ?? guessCat(t, i)
            let pool = (byCat[cat] ?? []).filter { $0 != tk.text && !(used[cat] ?? []).contains($0) }
            guard !pool.isEmpty else { out += tk.text; continue }
            seed = (seed &* 31 &+ i &* 7 &+ 13) % 1_000_003
            let w = pool[abs(seed) % pool.count]
            used[cat, default: []].insert(w)
            out += w
        }
        return out
    }

    // MARK: - 聽懂要做什麼

    public enum Kind: String { case tag, imitate }

    static let imitateCue = "仿寫|模仿這段|照樣造句|同樣的結構|同樣的句型|照著這個句型|一樣的結構"
    static let tagCue = "詞性|名詞|動詞|形容詞|副詞"

    public static func parse(_ raw: String) -> (kind: Kind, text: String)? {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let isImitate = q.range(of: imitateCue, options: .regularExpression) != nil
        guard isImitate || q.range(of: tagCue, options: .regularExpression) != nil else { return nil }
        var passage: String?
        let lines = q.split(separator: "\n").map(String.init)
        if lines.count >= 2 {
            // 第一行是要求、後面是短文；或短文在前、最後一行是要求
            if lines[0].range(of: imitateCue + "|" + tagCue, options: .regularExpression) != nil { passage = lines.dropFirst().joined() }
            else { passage = lines.dropLast().joined() }
        } else if let r = q.range(of: "[：:]", options: .regularExpression) {
            let head = String(q[..<r.lowerBound])
            if head.range(of: imitateCue + "|" + tagCue, options: .regularExpression) != nil { passage = String(q[r.upperBound...]) }
        } else if let r = q.range(of: "[？?]", options: .regularExpression) {
            passage = String(q[r.upperBound...])
        }
        guard var p = passage?.trimmingCharacters(in: .whitespaces), Writer.units(p, lang: "zh") >= 4 else { return nil }
        p = p.replacingOccurrences(of: "\n", with: "")
        // 「名詞和動詞有什麼不同」這種是在問文法知識，不是給一段話
        guard p.range(of: "[。！？，]", options: .regularExpression) != nil || Writer.units(p, lang: "zh") >= 6 else { return nil }
        return (isImitate ? .imitate : .tag, p)
    }

    public static func reply(_ kind: Kind, _ text: String) -> String {
        let t = tag(text)
        let words = content(t)
        func list(_ p: POS) -> String {
            var seen: [String] = []
            for w in words where w.pos == p && !seen.contains(w.text) { seen.append(w.text) }
            return seen.isEmpty ? "（沒有）" : seen.joined(separator: "、")
        }
        let marked = t.map { $0.pos.map { p in "\(tkText($0))(\(p.short))" } ?? $0.text }.joined()
        if kind == .tag {
            return "🔍 詞性分析：\n名詞：\(list(.noun))\n動詞：\(list(.verb))\n形容詞：\(list(.adj))\n副詞：\(list(.adv))\n\n逐詞標注：\(marked)"
        }
        let new = imitate(text)
        return "✍️ 仿寫：\n\(new)\n\n📐 原文的結構：\(skeleton(t))\n（照同樣的詞性順序：名詞換名詞、動詞換動詞、形容詞換形容詞、副詞換副詞；的、地、著、了這些功能詞不變）\n\n🔍 原文的詞性：\(marked)"
    }

    static func tkText(_ t: Token) -> String { t.text }
}
