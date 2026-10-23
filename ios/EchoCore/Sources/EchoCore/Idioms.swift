import Foundation

/// 成語：意思、用法、近義、反義、英西義的對應說法、語氣（資料在 ai/idioms/idioms.py）。
/// 看懂跟成語有關的話在問什麼——像人一樣先找出句子裡的成語，再看旁邊的字：
///   「意思、解釋、什麼叫」→ 問意思；「怎麼用、造句」→ 問用法；「出處、典故」→ 問由來（上網查）；
///   「近義、意思一樣」→ 近義；「反義、相反」→ 反義；「形容開心的成語」→ 找某一類的成語；
///   「我最近心灰意冷」→ 用成語說自己的心情；「我做事老是三天打魚兩天曬網，怎麼改」→ 用成語說自己的毛病，要找改善的方法。
public enum Idioms {
    public struct Entry {
        public let idiom: String
        public let meaning: String
        public let en: [String]
        public let es: [String]
        public let it: [String]
        public let tones: [String]
    }

    public static let all: [Entry] = IdiomData.table.split(separator: "\n").compactMap { line in
        let c = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard c.count == 6 else { return nil }
        func forms(_ s: String) -> [String] { s.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) } }
        return Entry(idiom: c[0], meaning: c[1], en: forms(c[2]), es: forms(c[3]), it: forms(c[4]), tones: c[5].split(separator: ",").map(String.init))
    }

    static let byName: [String: Entry] = Dictionary(all.map { ($0.idiom, $0) }, uniquingKeysWith: { a, _ in a })
    /// 長的先找（「失敗為成功之母」不要只找到「成功」）
    static let names: [String] = all.map(\.idiom).sorted { $0.count > $1.count }

    static let nearGroups: [[String]] = IdiomData.near.split(separator: "\n").map { $0.split(separator: " ").map(String.init) }
    static let antiMap: [String: [String]] = {
        var d: [String: [String]] = [:]
        for line in IdiomData.anti.split(separator: "\n") {
            let sides = line.split(separator: "|").map { $0.split(separator: " ").map(String.init) }
            guard sides.count == 2 else { continue }
            for a in sides[0] { for b in sides[1] {
                if !(d[a] ?? []).contains(b) { d[a, default: []].append(b) }
                if !(d[b] ?? []).contains(a) { d[b, default: []].append(a) }
            } }
        }
        return d
    }()

    public static func entry(_ w: String) -> Entry? { byName[w] }
    public static func near(_ w: String) -> [String] {
        var out: [String] = []
        for g in nearGroups where g.contains(w) { for x in g where x != w && !out.contains(x) { out.append(x) } }
        return out
    }
    public static func opposites(_ w: String) -> [String] { antiMap[w] ?? [] }
    public static func isNear(_ a: String, _ b: String) -> Bool { near(a).contains(b) }
    public static func isOpposite(_ a: String, _ b: String) -> Bool { opposites(a).contains(b) }

    /// 句子裡的成語（最長的優先）
    public static func find(_ t: String) -> String? { names.first { t.contains($0) } }

    // MARK: - 看懂問題

    public struct Understood: Equatable {
        public let intent: String   // meaning usage origin theme feeling problem near anti pairNear pairAnti reverse
        public let idiom: String
        public let extra: String    // pair 的另一個成語、theme 的主題、feeling 的心情、reverse 的外文說法
    }

    /// 情境開頭（「老師上課說到」「我兒子問我」「考考你」）、結尾的客套話：不是問題本身
    static func strip(_ raw: String) -> String { Understanding.bare(raw) }

    static func has(_ t: String, _ p: String) -> Bool { t.range(of: p, options: .regularExpression) != nil }

    /// 外文說法 → 成語（比對時不分大小寫、重音、標點）
    static func key(_ s: String) -> String {
        s.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: "’", with: "'")
            .filter { $0.isLetter || $0.isNumber || $0 == "'" || $0 == " " }
            .split(separator: " ").joined(separator: " ")
    }
    static let foreignIndex: [String: (Entry, String)] = {
        var d: [String: (Entry, String)] = [:]
        for e in all {
            for (l, fs) in [("en", e.en), ("es", e.es), ("it", e.it)] { for f in fs where d[key(f)] == nil { d[key(f)] = (e, l) } }
        }
        return d
    }()
    public static func fromForeign(_ s: String) -> (entry: Entry, lang: String)? {
        var k = key(s)
        // 「the Chinese idiom for X」「'X'」：拿掉引號、冠詞
        if let e = foreignIndex[k] { return (e.0, e.1) }
        for art in ["to ", "the ", "a "] where k.hasPrefix(art) {
            k = String(k.dropFirst(art.count))
            if let e = foreignIndex[k] { return (e.0, e.1) }
        }
        return nil
    }

    public static func understand(_ raw: String) -> Understood? {
        let t = strip(raw)
        guard !t.isEmpty else { return nil }
        // 外文說法 → 成語：「kill two birds with one stone 的成語是什麼」「what's the Chinese idiom for X」
        if let m = Understanding.match(t, #"^[「『"“]?(.+?)[」』"”]?\s*(?:用中文成語怎麼說|用成語怎麼說|的成語是什麼|的成語|在中文裡是什麼成語|在中文裡有什麼成語|可以用什麼成語|的中文成語|對應的成語|換成成語是哪一個|換成成語|是什麼成語)$"#)
            ?? Understanding.match(t, #"(?i)^(?:what'?s|what is)?\s*(?:the\s+)?chinese\s+idiom\s+for\s+[「"“']?(.+?)[」"”']?$"#),
           let f = fromForeign(m[1]) {
            return Understood(intent: "reverse", idiom: f.entry.idiom, extra: m[1])
        }
        // 找某一類的成語：「形容開心的成語」「有哪些成語是形容努力的」「關於時間的成語」
        for p in [#"^(?:形容|描述)(.{1,6}?)的成語(?:有哪些|有什麼|是什麼)?$"#, #"^(?:有)?(?:哪些|什麼)成語(?:是|可以)?(?:形容|描述|用來形容)(.{1,6}?)的?$"#,
                  #"^(?:關於|跟|和|與)(.{1,6}?)(?:有關)?的成語(?:有哪些|有什麼)?$"#, #"^(.{1,6}?)的成語(?:有哪些|有什麼)$"#, #"^哪些成語(?:跟|和|與)(.{1,6}?)有關$"#] {
            if let m = Understanding.match(t, p), byName[m[1]] == nil, !theme(m[1]).isEmpty {
                return Understood(intent: "theme", idiom: "", extra: m[1])
            }
        }
        // 兩個成語：「A和B是反義詞嗎」「A的反義詞是B嗎」「A跟B意思一樣嗎」
        if let m = Understanding.match(t, #"^(.+?)(?:和|跟|與|同)(.+?)(?:是)?(?:不是)?(?:反義詞|反義成語|相反詞|一對反義詞|相反的意思|意思相反|相反)(?:嗎)?$"#)
            ?? Understanding.match(t, #"^(.+?)的(?:反義詞|反義成語|相反詞)是(?:不是)?(.+?)$"#),
           byName[m[1]] != nil, byName[m[2]] != nil {
            return Understood(intent: "pairAnti", idiom: m[1], extra: m[2])
        }
        if let m = Understanding.match(t, #"^(.+?)(?:和|跟|與|同)(.+?)(?:的)?(?:意思)?(?:一樣|相同|差不多|相近|是近義詞|是同義成語|是同義詞|是近義成語|一樣意思)(?:嗎)?$"#)
            ?? Understanding.match(t, #"^(.+?)是不是就是(.+?)的意思$"#),
           byName[m[1]] != nil, byName[m[2]] != nil {
            return Understood(intent: "pairNear", idiom: m[1], extra: m[2])
        }
        if let x = find(t) {
            let rest = t.replacingOccurrences(of: x, with: "＿")
            if has(rest, "反義|相反|反面") { return Understood(intent: "anti", idiom: x, extra: "") }
            if has(rest, "近義|同義|相似|意思(一樣|差不多|相近)|相近") { return Understood(intent: "near", idiom: x, extra: "") }
            if has(rest, "出處|典故|出自|由來|成語故事|的故事") { return Understood(intent: "origin", idiom: x, extra: "") }
            if has(rest, "怎麼用|用法|造句|用在|適合用") { return Understood(intent: "usage", idiom: x, extra: "") }
            if has(rest, "意思|解釋|指的是|什麼叫|含義|涵義|代表什麼|是啥|^＿$|^成語＿$") { return Understood(intent: "meaning", idiom: x, extra: "") }
            // 用成語說自己的毛病，要找方法：「我老是三心二意怎麼辦」「怎麼改掉半途而廢的毛病」
            if IdiomData.problem.contains(x), has(rest, "怎麼|如何|改|避免|方法|辦法|不再|不會|才能") {
                return Understood(intent: "problem", idiom: x, extra: "")
            }
            // 用成語說自己的心情：「我最近心灰意冷」「今天心花怒放的」
            if let m = IdiomData.selfMood[x], !has(rest, "是什麼|什麼是|為什麼|嗎$") {
                return Understood(intent: "feeling", idiom: x, extra: m)
            }
            return nil
        }
        // 詞庫沒有的成語：「狐假虎威是什麼意思」——還是知道在問意思（交給上網查）
        if let m = Understanding.match(t, #"^(?:成語)?(\p{Han}{4})(?:這個成語|這句成語)?(?:是什麼意思|的意思是什麼|的意思|指的是什麼|怎麼解釋|什麼意思|是啥意思|的含義|代表什麼意思|的涵義是什麼)$"#)
            ?? Understanding.match(t, #"^(?:什麼叫|解釋一下|請解釋|可以解釋)(?:成語)?(\p{Han}{4})$"#) {
            return Understood(intent: "meaning", idiom: m[1], extra: "unknown")
        }
        return nil
    }

    /// 主題 → 成語（語氣相同，或意思裡有這個字）
    static let themeTone: [String: String] = ["開心": "開心", "高興": "開心", "快樂": "開心", "難過": "難過", "傷心": "難過", "生氣": "生氣", "憤怒": "生氣",
                                              "努力": "努力", "冷靜": "冷靜", "感謝": "感謝", "感恩": "感謝", "祝福": "祝福", "稱讚": "稱讚", "讚美": "稱讚",
                                              "驚訝": "驚訝", "擔心": "擔心", "謙虛": "謙虛", "鼓勵": "鼓勵", "安慰": "安慰"]
    static let themeMeaning: [String: String] = ["說話": "說", "團結": "一起", "很多人": "人非常多", "專心": "專"]
    public static func theme(_ t: String) -> [Entry] {
        if let tone = themeTone[t] { return all.filter { $0.tones.contains(tone) } }
        let w = themeMeaning[t] ?? t
        guard w.count >= 1, t.count >= 2 else { return [] }
        return all.filter { $0.meaning.contains(w) }
    }

    // MARK: - 回答

    static let toneUse: [String: String] = ["鼓勵": "鼓勵別人", "稱讚": "稱讚別人", "安慰": "安慰別人", "冷靜": "勸人冷靜", "提醒": "提醒別人",
                                            "開心": "形容很開心", "難過": "形容難過", "生氣": "形容很生氣", "幽默": "開玩笑、自嘲", "道理": "說明道理",
                                            "努力": "形容努力", "感謝": "表達感謝", "驚訝": "表達驚訝", "擔心": "形容擔心不安", "祝福": "祝福別人",
                                            "批評": "批評不好的行為", "謙虛": "謙虛地說自己"]

    /// 用詞庫回答；要上網查的（出處、詞庫沒有的成語、用成語說的毛病）回 nil
    public static func answer(_ u: Understood) -> String? {
        switch u.intent {
        case "meaning", "usage":
            guard let e = byName[u.idiom] else { return nil }
            var s = "「\(e.idiom)」的意思是：\(e.meaning)。"
            if u.intent == "usage" {
                let uses = e.tones.compactMap { toneUse[$0] }
                if !uses.isEmpty { s += "\n常用來" + uses.joined(separator: "、") + "。" }
            }
            let n = near(e.idiom), o = opposites(e.idiom)
            if !n.isEmpty { s += "\n近義：" + n.prefix(4).joined(separator: "、") }
            if !o.isEmpty { s += "\n反義：" + o.prefix(4).joined(separator: "、") }
            s += "\n英文可以說：\(e.en[0])"
            return s
        case "near":
            let n = near(u.idiom)
            guard !n.isEmpty else { return byName[u.idiom].map { "「\($0.idiom)」（\($0.meaning)）我的成語庫裡還沒有近義的成語。" } }
            return "「\(u.idiom)」的近義成語：" + n.prefix(6).map { w in "\(w)（\(byName[w]?.meaning ?? "")）" }.joined(separator: "、") + "。"
        case "anti":
            let o = opposites(u.idiom)
            guard !o.isEmpty else { return byName[u.idiom].map { "「\($0.idiom)」（\($0.meaning)）我的成語庫裡還沒有反義的成語。" } }
            return "「\(u.idiom)」的反義成語：" + o.prefix(6).map { w in "\(w)（\(byName[w]?.meaning ?? "")）" }.joined(separator: "、") + "。"
        case "pairNear":
            let a = u.idiom, b = u.extra
            if isNear(a, b) { return "對，「\(a)」和「\(b)」意思相近：\(byName[a]?.meaning ?? "")。" }
            if isOpposite(a, b) { return "不一樣，「\(a)」和「\(b)」的意思剛好相反。" }
            return "不一樣。「\(a)」是\(byName[a]?.meaning ?? "")；「\(b)」是\(byName[b]?.meaning ?? "")。"
        case "pairAnti":
            let a = u.idiom, b = u.extra
            if isOpposite(a, b) { return "對，「\(a)」和「\(b)」是反義成語：「\(a)」是\(byName[a]?.meaning ?? "")，「\(b)」是\(byName[b]?.meaning ?? "")。" }
            if isNear(a, b) { return "不是，「\(a)」和「\(b)」意思相近，是近義成語。" }
            let o = opposites(a).prefix(3).joined(separator: "、")
            return "不是，「\(a)」和「\(b)」不是反義成語。" + (o.isEmpty ? "" : "「\(a)」的反義成語是：\(o)。")
        case "theme":
            let es = theme(u.extra)
            guard !es.isEmpty else { return nil }
            return "形容「\(u.extra)」的成語：\n" + es.prefix(8).map { "・\($0.idiom)：\($0.meaning)" }.joined(separator: "\n")
        case "reverse":
            guard let e = byName[u.idiom] else { return nil }
            return "「\(u.extra)」對應的成語是「\(e.idiom)」：\(e.meaning)。"
        default:
            return nil
        }
    }

    /// 用成語說自己的毛病：上網找改善的方法，用意思去查（「三天打魚兩天曬網」→「怎麼改善做事沒有恆心」）
    public static func problemQuery(_ idiom: String) -> String? {
        guard let e = byName[idiom] else { return nil }
        let core = e.meaning.split(whereSeparator: { "，、；".contains($0) }).first.map(String.init) ?? e.meaning
        return "怎麼改善" + core
    }

    /// 翻譯：成語 → 英西義的對應說法；外文說法 → 成語；外文 → 另一種外文（透過成語對照）
    public static func translate(_ r: Translate.Request) -> Translate.Result? {
        guard let tl = r.target.lex, ["zh", "en", "es", "it"].contains(tl) else { return nil }
        var text = r.text.trimmingCharacters(in: CharacterSet(charactersIn: "「」『』\"“”'‘’ 。.!?！？"))
        if text.hasPrefix("成語") { text = String(text.dropFirst(2)) }
        if let e = byName[text] {
            let out: [String]
            switch tl {
            case "en": out = e.en
            case "es": out = e.es
            case "it": out = e.it
            default: return nil
            }
            return Translate.Result(text: out[0], alternatives: Array(out.dropFirst().prefix(2)), source: .zh, via: "成語對照：\(e.meaning)")
        }
        guard let f = fromForeign(text) else { return nil }
        let src: Translate.Code = Translate.Code(rawValue: f.lang) ?? .en
        switch tl {
        case "zh": return Translate.Result(text: f.entry.idiom, alternatives: [], source: src, via: "成語對照：\(f.entry.meaning)")
        case f.lang: return nil
        case "en": return Translate.Result(text: f.entry.en[0], alternatives: Array(f.entry.en.dropFirst().prefix(2)), source: src, via: "成語「\(f.entry.idiom)」")
        case "es": return Translate.Result(text: f.entry.es[0], alternatives: Array(f.entry.es.dropFirst().prefix(2)), source: src, via: "成語「\(f.entry.idiom)」")
        default: return Translate.Result(text: f.entry.it[0], alternatives: Array(f.entry.it.dropFirst().prefix(2)), source: src, via: "成語「\(f.entry.idiom)」")
        }
    }
}
