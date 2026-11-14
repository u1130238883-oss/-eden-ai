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

    /// 字本身的意思（不認得的詞，上下文決定不了時才看）：藍、瑩、嫩像形容詞；滾、爬、唱像動詞；極、相像程度副詞
    static let adjChars = Set("藍紅綠白黃金瑩嫩盛麗亮暖冷美茂鮮晶柔靜清甜香淨豔碧翠嬌濃淡寬窄圓胖瘦")
    static let verbChars = Set("行滾爬呼唱睡坐舉抬握罩綴芽開跑跳飛游走吟追轉步笑叫讀畫拿抱看撿摸提捧擦照閃飄流吹潤落吻長放曳綻發盤旋")
    static let degreeChars = Set("極相頗甚挺超太更最格十")
    static let nounEnd = Set("花掌杏鵝豚馬師居哥姐灘園谷套杯籠光星鼠鷹樹草魚")

    /// 最長的認得的詞優先；認不得的字連在一起，再切成像詞的長度（名詞常是三個字：仙人掌；動詞、形容詞常是兩個字）
    public static func segment(_ s: String) -> [Token] {
        let cs = Array(s)
        var out: [Token] = [], unknown = "", i = 0
        func flush() {
            guard !unknown.isEmpty else { return }
            let u = Array(unknown)
            var sizes: [Int] = []
            switch u.count {
            case 0...3: sizes = [u.count]
            case 5 where !nounEnd.contains(u[2]): sizes = verbChars.contains(u[4]) || adjChars.contains(u[4]) ? [3, 2] : [2, 3]
            default:
                // 「牽牛花相當嬌嫩」：開頭三個字、第三個字像名詞的結尾（花、掌、鵝…）→ 先切三個字
                var j = 0
                while j < u.count {
                    let left = u.count - j
                    let k = left == 3 || (left > 4 && nounEnd.contains(u[j + 2]) && !nounEnd.contains(u[j + 1])) ? 3 : min(2, left)
                    sizes.append(k); j += k
                }
            }
            var j = 0
            for k in sizes { out.append(Token(text: String(u[j..<(j + k)]), pos: nil, cat: nil)); j += k }
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
    static let boundary: Set<String> = ["。", "，", "！", "？", "；", "："]

    static func isDegree(_ t: Token) -> Bool { degree.contains(t.text) || (t.cat == nil && t.text.contains { degreeChars.contains($0) }) }

    /// 像人一樣：先用最確定的線索（的、地、著、了、很），再用已經判斷出來的鄰居一步一步推，最後才看字本身的意思
    public static func tag(_ s: String) -> [Token] {
        var t = segment(s)
        let unknown = t.indices.filter { t[$0].cat == nil && t[$0].pos == nil }
        func txt(_ i: Int) -> String { i >= 0 && i < t.count ? t[i].text : "。" }
        func pos(_ i: Int) -> POS? { i >= 0 && i < t.count ? t[i].pos : nil }
        // ① 最確定的線索（順序有意義：越確定的越先看）
        for i in unknown {
            let pt = txt(i - 1), nt = txt(i + 1)
            let nextIsAdj = pos(i + 1) == .adj || (i + 1 < t.count && t[i + 1].cat == nil && txt(i + 2) == "的")
            if nt == "地" { t[i].pos = .adv }                                                  // 「徐徐地」
            else if nt == "的" { t[i].pos = .adj }                                             // 「嬌嫩的手套」
            else if pt == "的" { t[i].pos = .noun }                                            // 「的銀杏」
            else if nextIsAdj { t[i].pos = .adv }                                              // 「相當柔軟」「極其晶瑩的」
            else if i > 0, degree.contains(t[i - 1].text) { t[i].pos = .adj }                 // 「很蔚藍」
            else if ["著", "了", "起來"].contains(nt) || pt == "地" { t[i].pos = .verb }      // 「抬著」「盛開了」「地翻滾」
            else if ["著", "把", "在", "和"].contains(pt) { t[i].pos = .noun }                 // 「著手套」「把陶杯」「在沙灘」
            else if ["裡", "上", "和", "覺得", "把"].contains(nt) { t[i].pos = .noun }        // 「沙灘上」「企鵝和」
            else if ["裡", "上"].contains(pt) { t[i].pos = .verb }                             // 「沙灘上靜坐」
            else if boundary.contains(pt) && nt == "，" { t[i].pos = .adv }                    // 「頓時，」
            else if boundary.contains(pt) { t[i].pos = .noun }                                 // 句首是主角
        }
        // ② 用判斷出來的鄰居推（重複幾次，直到推不動）
        for _ in 0..<4 {
            for i in unknown where t[i].pos == nil {
                let pp = pos(i - 1), np = pos(i + 1), nt = txt(i + 1)
                // 「斑馬偶爾滑行。」：主角後面兩個不認得的詞、接著句號——前面的是副詞，後面的是動詞
                if pp == .noun, np == nil, i + 1 < t.count, t[i + 1].cat == nil, boundary.contains(txt(i + 2)) { t[i].pos = .adv; continue }
                if pp == .noun || pp == .adv {
                    if np == .adv || np == .verb || nt == "在" { t[i].pos = .adv }               // 主角後面、動詞前面：副詞（「海豚依然徐徐地」）
                    else if boundary.contains(nt) {
                        if pp == .adv, i > 0, isDegree(t[i - 1]) { t[i].pos = .adj }          // 「極其晶瑩。」
                        else if pp == .adv, t[i].text.contains(where: { adjChars.contains($0) }) && !t[i].text.contains(where: { verbChars.contains($0) }) { t[i].pos = .adj }
                        else { t[i].pos = .verb }                                              // 「海豚又滑行。」
                    }
                } else if np == .adj, t[i].text.contains(where: { degreeChars.contains($0) }) { t[i].pos = .adv }
            }
        }
        // ③ 還是推不出來：看字的意思，再不行就當名詞
        for i in unknown where t[i].pos == nil {
            let w = t[i].text
            if w.contains(where: { degreeChars.contains($0) }) { t[i].pos = .adv }
            else if w.contains(where: { verbChars.contains($0) }) { t[i].pos = .verb }
            else if w.contains(where: { adjChars.contains($0) }) { t[i].pos = .adj }
            else { t[i].pos = .noun }
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
        let marked = t.map { tk in tk.pos.map { p in "\(tk.text)(\(p.short))" } ?? tk.text }.joined()
        if kind == .tag {
            return "🔍 詞性分析：\n名詞：\(list(.noun))\n動詞：\(list(.verb))\n形容詞：\(list(.adj))\n副詞：\(list(.adv))\n\n逐詞標注：\(marked)"
        }
        let new = imitate(text)
        return "✍️ 仿寫：\n\(new)\n\n📐 原文的結構：\(skeleton(t))\n（照同樣的詞性順序：名詞換名詞、動詞換動詞、形容詞換形容詞、副詞換副詞；的、地、著、了這些功能詞不變）\n\n🔍 原文的詞性：\(marked)"
    }

}
