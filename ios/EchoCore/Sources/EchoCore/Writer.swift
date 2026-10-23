import Foundation

/// 寫作：把一句很短的話寫成一段有畫面、有情緒、有觀點的文字。
///   詳寫：「小明哭了，請詳寫」→ 環境烘托、動作神態、比喻、內心感受、成語、觀點、收尾（WritingData）
///   擴寫：「擴寫：樹在成長」「Expand: The tree is growing.」「Amplía: El río fluye.」「Espandi: Il sole sta sorgendo.」
///         → 字數至少是原句的 9 倍（中文算字，英西義算單字）（ExpandData）
///   修改：「幫我修改這段：小明哭了。他很傷心。」→ 找出寫得不好的地方，一項一項改好
/// 像學寫作文一樣：先寫第一稿 → 自己檢查（字數、環境、感受、觀點、比喻、成語／諺語、平淡的詞、重複、語言）
/// → 照檢查出來的問題修改 → 再檢查，直到沒有問題為止。
public enum Writer {
    public enum Kind: String { case detail, expand, polish }

    public struct Ask {
        public let kind: Kind
        public let lang: String        // zh en es it
        public let original: String    // 原句（不含句末標點）
        public let subject: String     // 主角（找不到是空的）
        public let category: String    // 詳寫：WritingData 的類別；擴寫：「主角類/動作類」或「general」
        public let minUnits: Int       // 至少要寫多少（中文字／英西義單字）
    }

    public struct Result {
        public let text: String
        public let drafts: [String]    // 每一稿
        public let notes: [String]     // 每一次改了什麼
        public let units: Int
    }

    // MARK: - 材料

    struct Expand {
        var subjects: [String: [[String]]] = [:]                 // 主角類 → [[中, 英, 西, 義]]
        var preds: [String: [([String], Set<String>)]] = [:]      // 動作類 → [([中, 英, 西, 義], 可以配的主角類)]
        var combos: [String: [String]] = [:]
        var scene: [String: [String: [String]]] = [:]             // 主角類 → 語言 → 句子
        var detail: [String: [String: [String]]] = [:]
        var act: [String: [String: [String: [String]]]] = [:]     // 動作類 → 段落 → 語言 → 句子
        var idioms: [String: [String]] = [:]
        var proverb: [String: [String: String]] = [:]
        var extra: [String: [String]] = [:]
        var mark: [String: [String: [String]]] = [:]              // 記號 → 語言 → 詞
    }

    static let X: Expand = {
        var x = Expand()
        for line in ExpandData.table.split(separator: "\n") {
            let c = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard c.count == 4 else { continue }
            let (kind, key, lang, text) = (c[0], c[1], c[2], c[3])
            switch kind {
            case "SUBJ": x.subjects[key, default: []].append(text.components(separatedBy: "¦"))
            case "PRED":
                let f = text.components(separatedBy: "¦")
                x.preds[key, default: []].append((Array(f.prefix(4)), Set(f[4].split(separator: ",").map(String.init))))
            case "COMBO": x.combos[key] = text.split(separator: ",").map(String.init)
            case "SCENE": x.scene[key, default: [:]][lang, default: []].append(text)
            case "DETAIL": x.detail[key, default: [:]][lang, default: []].append(text)
            case "IDIOM": x.idioms[key] = text.split(separator: ",").map(String.init)
            case "PROVERB": x.proverb[key, default: [:]][lang] = text
            case "EXTRA": x.extra[lang, default: []].append(text)
            default:
                if kind.hasPrefix("ACT.") { x.act[key, default: [:]][String(kind.dropFirst(4)), default: [:]][lang, default: []].append(text) }
                if kind.hasPrefix("MARK.") { x.mark[String(kind.dropFirst(5)), default: [:]][lang] = text.components(separatedBy: "¦") }
            }
        }
        return x
    }()

    static let langIndex = ["zh": 0, "en": 1, "es": 2, "it": 3]

    /// 穩定的雜湊（Swift 內建的 hashValue 每次執行都不一樣）
    static func stable(_ s: String) -> Int {
        var h: UInt64 = 1469598103934665603
        for u in s.unicodeScalars { h = (h ^ UInt64(u.value)) &* 1099511628211 }
        return Int(h % 1_000_003)
    }

    static func pick(_ xs: [String], _ seed: Int, _ slot: Int) -> String? {
        xs.isEmpty ? nil : xs[(seed + slot * 7 + slot * slot) % xs.count]
    }

    // MARK: - 字數

    /// 中文算漢字；英西義算單字
    public static func units(_ s: String, lang: String) -> Int {
        if lang == "zh" { return s.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) }.count }
        return s.split(whereSeparator: { $0.isWhitespace }).filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }.count
    }

    // MARK: - 聽懂要寫什麼

    static func match(_ s: String, _ p: String) -> [String]? { Understanding.match(s, p) }

    static func cleanContent(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        for (a, b) in [("「", "」"), ("『", "』"), ("\"", "\""), ("“", "”")] where t.hasPrefix(a) && t.hasSuffix(b) && t.count > 2 {
            t = String(t.dropFirst().dropLast())
        }
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: "「」『』\"“” 。.！!？?，,：:"))
        return t
    }

    static let zhAsks = [
        #"^(?:請)?(?:幫我)?(?:擴寫|詳寫)(?:這句話|這句|一下)?[：:，,\s]+(.+)$"#,
        #"^(?:請)?(?:幫我)?(?:擴寫|詳寫)[「『](.+?)[」』]$"#,
        #"^(.+?)[。，,\s]*(?:請)?(?:幫我)?(?:詳寫|擴寫)(?:成一段)?$"#,
        #"^(.+?)[。，,\s]*請(?:詳細描寫|擴寫成一段|詳細地寫)$"#,
        #"^(?:請)?(?:幫我)?把[「『]?(.+?)[」』]?寫(?:成|得)(?:一段話|一段優美的文字|一段有畫面的文字|一段|更生動|更有感情|生動一點|感人一點|更好)(?:一點)?$"#,
        #"^(?:請)?用(?:優美|生動|高級)的(?:文字|句子|筆觸|詞)(?:描寫|擴寫|寫)[：:]?(.+)$"#,
        #"^(.+?)[，,]\s*(?:寫得|寫一段)(?:生動一點|有畫面一點|有畫面的文字|富有感情|優美一點|感人一點)$"#,
        #"^(.+?)[，,]\s*(?:請寫得富有感情|用高級的詞寫一段|寫一段有畫面的文字)$"#,
        #"^(?:請)?(?:描寫|描述)(?:一下)?[：:]?(.+)$"#,
    ]
    static let zhPolish = [
        #"^(?:請)?(?:幫我)?(?:修改|潤飾|潤色|改寫|修飾)(?:一下)?(?:這段|這句|這篇)?(?:話|文字)?[：:，,\s]+(.+)$"#,
        #"^(?:請)?(?:幫我)?把這段(?:話|文字)?寫得更好[：:，,\s]+(.+)$"#,
        #"^這段寫得不好[，,]?(?:幫我)?修改[：:，,\s]+(.+)$"#,
        #"^(.+?)[，,\s]*(?:這段)?(?:幫我)?(?:改得更好|修改一下|潤飾一下|可以怎麼改|寫得更好)$"#,
    ]
    static let foreignAsks: [(String, String)] = [
        ("en", #"(?i)^(?:please\s+)?(?:expand|develop|elaborate on)(?:\s+this)?(?:\s+sentence)?(?:\s+into\s+a\s+[a-z ]*paragraph)?(?:,?\s*please)?\s*[:：]\s*(.+)$"#),
        ("en", #"(?i)^write\s+a\s+paragraph\s+about\s+this\s*[:：]\s*(.+)$"#),
        ("en", #"(?i)^turn\s+this\s+into\s+a\s+[a-z ]*paragraph\s*[:：]\s*(.+)$"#),
        ("en", #"(?i)^(.+?)[.!]?\s+please\s+expand\s+it[.!]?$"#),
        ("es", #"(?i)^(?:por\s+favor,?\s*)?(?:amplía|amplia|desarrolla)(?:\s+esta\s+frase)?(?:,?\s*por\s+favor)?\s*[:：]\s*(.+)$"#),
        ("es", #"(?i)^escribe\s+un\s+párrafo\s+sobre\s+esto\s*[:：]\s*(.+)$"#),
        ("es", #"(?i)^convierte\s+esto\s+en\s+un\s+párrafo\s*[:：]\s*(.+)$"#),
        ("es", #"(?i)^(.+?)[.!]?\s+ampl[ií]ala,?\s+por\s+favor[.!]?$"#),
        ("it", #"(?i)^(?:per\s+favore,?\s*)?(?:espandi|sviluppa)(?:\s+questa\s+frase)?(?:,?\s*per\s+favore)?\s*[:：]\s*(.+)$"#),
        ("it", #"(?i)^scrivi\s+un\s+paragrafo\s+su\s+questo\s*[:：]\s*(.+)$"#),
        ("it", #"(?i)^trasforma\s+questo\s+in\s+un\s+paragrafo\s*[:：]\s*(.+)$"#),
        ("it", #"(?i)^(.+?)[.!]?\s+espandila,?\s+per\s+favore[.!]?$"#),
    ]

    /// 主角：人名、稱呼
    static let namePattern = #"^(小\p{Han}|阿\p{Han}|老師|同學們?|媽媽|爸爸|奶奶|爺爺|外婆|外公|哥哥|姊姊|姐姐|弟弟|妹妹|阿姨|叔叔|我們|我|他們|他|她|你|[王李張陳林黃吳劉蔡楊許鄭謝郭洪曾邱廖賴周徐蘇葉莊呂江何蕭羅高潘簡朱鍾彭游詹胡施沈余趙盧梁顏柯孫魏翁戴范宋方]\p{Han}{2})"#

    public static func parse(_ raw: String) -> Ask? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: #"^(作業|老師出的題目|題目|考考你|老師要我)[：:，,\s]*"#, with: "", options: .regularExpression)
        // 英西義
        for (lang, p) in foreignAsks {
            if let m = match(t, p) {
                let o = cleanContent(m[1])
                guard units(o, lang: lang) >= 2, units(o, lang: "zh") == 0 else { continue }
                return expandAsk(o, lang: lang)
            }
        }
        // 修改
        for p in zhPolish {
            if let m = match(t, p) {
                let o = m[1].trimmingCharacters(in: .whitespacesAndNewlines)
                guard units(o, lang: "zh") >= 4, !questionish(o) else { continue }
                let cat = category(o)
                return Ask(kind: .polish, lang: "zh", original: o, subject: subjectOf(o) ?? "", category: cat ?? "general",
                           minUnits: max(9 * units(o, lang: "zh"), 80))
            }
        }
        // 詳寫、擴寫
        for p in zhAsks {
            if let m = match(t, p) {
                let o = cleanContent(m[1])
                guard units(o, lang: "zh") >= 2, !questionish(o) else { continue }
                if let a = expandAsk(o, lang: "zh"), a.category != "general" { return a }
                if let cat = category(o) {
                    return Ask(kind: .detail, lang: "zh", original: o, subject: subjectOf(o) ?? "", category: cat, minUnits: 9 * units(o, lang: "zh"))
                }
                return expandAsk(o, lang: "zh")
            }
        }
        return nil
    }

    /// 「描寫是什麼意思」「擴寫和縮寫有什麼不同」：在問問題，不是要寫
    static func questionish(_ s: String) -> Bool {
        s.range(of: "什麼|怎麼|如何|嗎$|為什麼|哪裡|多少|差別|不同", options: .regularExpression) != nil
    }

    static func subjectOf(_ s: String) -> String? {
        let t = s.replacingOccurrences(of: #"^[^，,]{1,6}[，,]"#, with: "", options: .regularExpression)
        return match(t, namePattern)?[1] ?? match(s, namePattern)?[1]
    }

    /// 詳寫的類別（情緒、動作、景物）
    static func category(_ s: String) -> String? {
        for k in WritingData.order {
            guard let c = WritingData.cats[k] else { continue }
            if c.keys.contains(where: { s.contains($0) }) { return k }
        }
        return nil
    }

    static func expandAsk(_ o: String, lang: String) -> Ask? {
        let li = langIndex[lang] ?? 0
        let low = o.lowercased()
        var subject = "", sc = "", pc = ""
        var best = 0
        for (c, xs) in X.subjects {
            for x in xs {
                let w = x[li], k = w.lowercased()
                let hit = lang == "zh" ? o.contains(w) : (" " + low + " ").contains(" " + k + " ") || low.hasPrefix(k + " ")
                if hit, k.count > best { best = k.count; subject = lang == "zh" ? w : String(o[o.range(of: w, options: .caseInsensitive)!]); sc = c }
            }
        }
        best = 0
        for (c, xs) in X.preds {
            for (x, _) in xs where low.contains(x[li].lowercased()) && x[li].count > best { best = x[li].count; pc = c }
        }
        let cat = (!sc.isEmpty && !pc.isEmpty) ? sc + "/" + pc : "general"
        return Ask(kind: .expand, lang: lang, original: o, subject: subject, category: cat, minUnits: 9 * units(o, lang: lang))
    }

    // MARK: - 檢查

    static let sceneWords: [String: [String]] = [
        "zh": WritingData.scene + ["相簿", "季節", "夜深", "照片"],
        "en": ["album", "photo", "outside", "light", "sun", "air", "wind", "rain", "morning", "night", "sky", "breeze", "window", "street", "garden", "hill", "water", "dusk", "afternoon", "room", "woods", "park", "seasons", "clouds", "mist"],
        "es": ["álbum", "fotos", "luz", "sol", "aire", "viento", "lluvia", "mañana", "noche", "cielo", "brisa", "ventana", "calle", "jardín", "colina", "agua", "tarde", "habitación", "bosque", "parque", "estaciones", "nubes", "niebla"],
        "it": ["album", "fotografie", "luce", "sole", "aria", "vento", "pioggia", "mattino", "notte", "cielo", "brezza", "finestra", "strada", "giardino", "collina", "acqua", "pomeriggio", "stanza", "bosco", "parco", "stagioni", "nuvole", "nebbia"],
    ]
    static let plainWords: [String: [String]] = [
        "zh": ["我覺得很好", "很好。", "很棒。"], "en": ["It is nice", "very nice"], "es": ["Es bonito", "muy bonito"], "it": ["È bello", "molto bello"],
    ]
    static let proverbMarks = ["As the old saying goes", "As the saying goes", "As they say", "Como dice el refrán", "Come dice il proverbio", "Come si dice"]

    static func sentences(_ s: String, lang: String) -> [String] {
        let sep: Set<Character> = lang == "zh" ? ["。", "！", "？", "…"] : [".", "!", "?"]
        var out: [String] = [], cur = ""
        for ch in s {
            cur.append(ch)
            if sep.contains(ch) { let x = cur.trimmingCharacters(in: .whitespaces); if x.count > 1 { out.append(x) }; cur = "" }
        }
        let x = cur.trimmingCharacters(in: .whitespaces); if !x.isEmpty { out.append(x) }
        return out
    }

    /// 自己檢查：回傳寫得不好的地方（空的＝合格）
    public static func review(_ text: String, _ a: Ask) -> [String] {
        var p: [String] = []
        let L = a.lang
        let u = units(text, lang: L)
        let has: (String) -> Bool = { text.range(of: $0, options: .caseInsensitive) != nil }
        if u < a.minUnits { p.append("字數不夠：\(u)／至少 \(a.minUnits)") }
        if !(sceneWords[L] ?? []).contains(where: has) { p.append("沒有環境描寫") }
        if (X.mark["emotion"]?[L] ?? []).filter(has).count < 2 { p.append("沒有寫出感受") }
        if !(X.mark["view"]?[L] ?? []).contains(where: has) { p.append("沒有自己的觀點") }
        if !(X.mark["simile"]?[L] ?? []).contains(where: has) { p.append("沒有比喻") }
        if L == "zh" {
            let quoted = text.components(separatedBy: "「").dropFirst().compactMap { $0.components(separatedBy: "」").first }
            if !quoted.contains(where: { Idioms.entry($0) != nil }) { p.append("沒有用成語點題") }
        } else if !proverbMarks.contains(where: { text.contains($0) }) { p.append("沒有諺語點題") }
        if (plainWords[L] ?? []).contains(where: { text.contains($0) }) { p.append("用詞太平淡") }
        if a.kind != .expand, let c = WritingData.cats[a.category] {
            if c.elevated.filter({ text.contains($0) }).count < 3 { p.append("高級詞太少") }
            if let w = c.avoid.first(where: { text.contains($0) }) { p.append("情緒不對：「\(w)」") }
            if text.contains("很" + c.plain) { p.append("用詞太平淡：「很\(c.plain)」") }
        }
        if !a.subject.isEmpty, !has(a.subject) { p.append("沒有寫到主角") }
        let ss = sentences(text, lang: L)
        if Set(ss).count < ss.count { p.append("句子重複") }
        // 一段好文章要有層次：環境、主角、動作、比喻、感受、觀點、點題、收尾——寫作至少八句，修改至少六句
        let need = a.kind == .polish ? 6 : 8
        if ss.count < need { p.append("內容太單薄：只有 \(ss.count) 句") }
        if L != "zh", units(text, lang: "zh") > 0 { p.append("混進了中文") }
        return p
    }

    // MARK: - 寫、改

    /// 把句子裡的 {S}、{s}、{O}、{n} 換成這一題的內容；西班牙文、義大利文的冠詞要跟介系詞合起來（a el → al、di il → del）
    static func fill(_ t: String, _ a: Ask, n: String) -> String {
        var s = t.replacingOccurrences(of: "{O}", with: a.original)
            .replacingOccurrences(of: "{S}", with: a.subject.isEmpty ? n : a.subject)
            .replacingOccurrences(of: "{s}", with: a.subject.isEmpty ? n : (a.lang == "zh" ? a.subject : lowerArticle(a.subject)))
            .replacingOccurrences(of: "{n}", with: n)
        if a.lang == "es" { for (x, y) in [(" a el ", " al "), (" de el ", " del ")] { s = s.replacingOccurrences(of: x, with: y) } }
        if a.lang == "it" {
            for (x, y) in [(" di il ", " del "), (" di lo ", " dello "), (" di l'", " dell'"), (" a il ", " al "), (" su il ", " sul "), (" in il ", " nel "), (" da il ", " dal ")] {
                s = s.replacingOccurrences(of: x, with: y)
            }
        }
        if let f = s.first, f.isLowercase { s = f.uppercased() + s.dropFirst() }
        return s
    }

    /// 句中的冠詞小寫（「The tree」→「the tree」；人名不變）
    static func lowerArticle(_ s: String) -> String {
        for art in ["The ", "El ", "La ", "Il ", "Lo ", "L'"] where s.hasPrefix(art) { return art.lowercased() + s.dropFirst(art.count) }
        return s
    }

    /// 一段文字由這些段落組成（順序固定）；修改＝補上缺的段落、拿掉平淡的句子
    enum Part: Int, CaseIterable { case draft, scene, opening, detail, vivid, simile, feel, idiom, view, end, extra1, extra2, extra3, extra4, extra5, extra6, extra7, extra8, extra9, extra10 }

    static func render(_ parts: Set<Part>, _ a: Ask, seed: Int, userText: String?) -> String {
        let L = a.lang
        let joiner = L == "zh" ? "" : " "
        var out: [String] = []
        if a.kind == .expand {
            let sp = a.category.split(separator: "/").map(String.init)
            let sc = sp.count == 2 ? sp[0] : "abstract", pc = sp.count == 2 ? sp[1] : "general"
            let n = a.subject.isEmpty ? (L == "zh" ? "它" : "it") : a.subject
            let act = X.act[pc] ?? X.act["general"] ?? [:]
            for part in Part.allCases where parts.contains(part) {
                var s: String?
                switch part {
                case .draft: s = a.original + (L == "zh" ? "。" : ".") + (L == "zh" ? "我覺得很好。" : L == "en" ? " It is nice." : L == "es" ? " Es bonito." : " È bello.")
                case .scene: s = pick(X.scene[sc]?[L] ?? [], seed, 1)
                case .detail: s = sp.count == 2 ? pick(X.detail[sc]?[L] ?? [], seed, 2) : nil
                case .vivid: s = pick(act["vivid"]?[L] ?? [], seed, 3)
                case .simile: s = pick(act["simile"]?[L] ?? [], seed, 4)
                case .feel: s = pick(act["feel"]?[L] ?? [], seed, 5)
                case .idiom:
                    if L == "zh" {
                        if let i = pick(X.idioms[pc] ?? X.idioms["general"] ?? [], seed, 6), let e = Idioms.entry(i) { s = "正如一句成語所說：「\(i)」——\(e.meaning)。" }
                    } else { s = X.proverb[pc]?[L] ?? X.proverb["general"]?[L] }
                case .view: s = pick(act["view"]?[L] ?? [], seed, 7)
                case .end: s = pick(act["end"]?[L] ?? [], seed, 8)
                case .opening: s = nil
                default:
                    let i = part.rawValue - Part.extra1.rawValue
                    let ex = X.extra[L] ?? []
                    let filled = Set(out)
                    s = (0..<ex.count).lazy.map { ex[(seed + i + $0) % ex.count] }.first { !filled.contains(fill($0, a, n: n)) }
                }
                if let s { out.append(fill(s, a, n: n)) }
            }
        } else {
            guard let c0 = WritingData.cats[a.category] ?? WritingData.cats["general"] else { return a.original }
            // 好的寫法要用到高級詞：每一段優先挑有高級詞的句子
            func rich(_ xs: [String]) -> [String] { let r = xs.filter { s in c0.elevated.contains { s.contains($0) } }; return r.isEmpty ? xs : r }
            let c = WritingData.Cat(keys: c0.keys, idioms: c0.idioms, elevated: c0.elevated, avoid: c0.avoid, idiomTones: c0.idiomTones,
                                    setting: rich(c0.setting), body: rich(c0.body), simile: rich(c0.simile), inner: rich(c0.inner), end: rich(c0.end),
                                    view: c0.view, feel: c0.feel, plain: c0.plain, idiomLine: c0.idiomLine)
            let scene = WritingData.scenes.contains(a.category)
            let n = a.subject.isEmpty ? "我" : a.subject
            let startsWithSubject = !a.subject.isEmpty && a.original.hasPrefix(a.subject)
            let event = startsWithSubject ? upgrade(String(a.original.dropFirst(a.subject.count))) : upgrade(a.original)
            for part in Part.allCases where parts.contains(part) {
                var s: String?
                switch part {
                case .draft:
                    if let u = userText { s = upgrade(u) } else {
                        s = scene ? "\(a.original)。天氣很\(c.plain)。" : startsWithSubject ? "\(a.original)。\(n)很\(c.plain)。" : "\(a.original)。很\(c.plain)。"
                    }
                case .scene: s = pick(c.setting, seed, 1)
                case .opening:
                    if userText != nil { s = nil }
                    else if scene { s = c.keys.contains(a.original) || ["下雨天", "雪景", "夕陽", "月亮", "晚霞"].contains(a.original) ? nil : upgrade(a.original) + "。" }
                    else if startsWithSubject { s = pick(["那一刻，\(n)\(event)。", "就在這時，\(n)\(event)。", "誰也沒想到，\(n)\(event)。"], seed, 9) }
                    else { s = event + "。" }
                case .detail: s = pick(c.body, seed, 2)
                case .vivid: s = pick(c.inner, seed, 3)
                case .simile: s = pick(c.simile, seed, 4)
                case .feel: s = pick(c.feel, seed, 5)
                case .idiom: if let i = pick(c.idioms, seed, 6) { s = c.idiomLine.replacingOccurrences(of: "{i}", with: i) }
                case .view: s = pick(c.view, seed, 7)
                case .end: s = pick(c.end, seed, 8)
                default:
                    let i = part.rawValue - Part.extra1.rawValue
                    // 多寫的句子：從還沒用過的句子裡挑（重複的句子會被刪掉，等於沒多寫）
                    let ex = c.inner + c.simile + c.body + c.end + c.feel
                    let filled = Set(out)
                    s = (0..<ex.count).lazy.map { ex[(seed + i * 3 + 1 + $0) % ex.count] }.first { !filled.contains(fill($0, a, n: n)) }
                }
                if let s { out.append(fill(s, a, n: n)) }
            }
        }
        // 同一句不要出現兩次
        var seen = Set<String>(), uniq: [String] = []
        for s in out where seen.insert(s).inserted { uniq.append(s) }
        return uniq.joined(separator: joiner)
    }

    /// 平淡的說法換成高級的說法（「很傷心」→「黯然神傷」）
    static func upgrade(_ s: String) -> String {
        var t = s
        for (a, b) in WritingData.upgrade { t = t.replacingOccurrences(of: a, with: b) }
        return t
    }

    /// 檢查出來的問題 → 要補上哪些段落、怎麼說明
    static func fix(_ problem: String, _ parts: inout Set<Part>, _ a: Ask, lang: String) -> String? {
        let zh = lang == "zh"
        func add(_ p: Part, _ why: String) -> String? { parts.insert(p).inserted ? why : nil }
        switch true {
        case problem.hasPrefix("沒有環境"): return add(.scene, zh ? "補上環境描寫，用天氣、光線和聲音烘托氣氛" : "added a setting (light, weather, sounds)")
        case problem.hasPrefix("沒有寫出感受"):
            // 先寫感受那一句；已經有了還不夠，就再多寫幾句心裡的話
            for p in [Part.feel, .vivid, .extra1, .extra2, .extra3, .extra4] where !parts.contains(p) {
                parts.insert(p)
                return zh ? "寫出心裡的感受" : "added my feelings"
            }
            return nil
        case problem.hasPrefix("沒有自己的觀點"): return add(.view, zh ? "加上自己的觀點，讓文章有想法" : "added my own point of view")
        case problem.hasPrefix("沒有比喻"): return add(.simile, zh ? "加上比喻，讓畫面更生動" : "added a simile")
        case problem.hasPrefix("沒有用成語"), problem.hasPrefix("沒有諺語"): return add(.idiom, zh ? "用成語點題" : "added a proverb")
        case problem.hasPrefix("高級詞太少"):
            // 多用帶著高級詞的描寫：動作神態、比喻、收尾
            for p in [Part.detail, .simile, .vivid, .end, .scene, .extra1, .extra2, .extra3, .extra4] where !parts.contains(p) {
                parts.insert(p)
                return "多用高級的詞來描寫（動作神態、比喻、收尾）"
            }
            return nil
        case problem.hasPrefix("用詞太平淡"):
            if a.kind == .polish {
                return add(.detail, "把平淡的詞換成高級的詞，加上動作神態的描寫")
            }
            parts.remove(.draft)
            parts.insert(.opening); parts.insert(.vivid); parts.insert(.detail)
            return zh ? "把平淡的句子改寫成生動的描寫（動作、神態、感官）" : "rewrote the flat sentence into a vivid description"
        case problem.hasPrefix("沒有寫到主角"): return add(.detail, zh ? "多寫主角的樣子" : "described the subject more closely")
        case problem.hasPrefix("句子重複"):
            parts.remove(.draft)
            return zh ? "刪掉重複的句子" : "removed a repeated sentence"
        case problem.hasPrefix("內容太單薄"):
            for p in [Part.scene, .detail, .vivid, .simile, .feel, .view, .idiom, .end, .extra1, .extra2, .extra3, .extra4, .extra5, .extra6] where !parts.contains(p) {
                parts.insert(p)
                return zh ? "補上層次：環境、主角、比喻、感受、觀點、收尾" : "added more layers (setting, feelings, view, ending)"
            }
            return nil
        case problem.hasPrefix("字數不夠"):
            for p in [Part.detail, .vivid, .feel, .end, .extra1, .extra2, .extra3, .extra4, .extra5, .extra6, .extra7, .extra8, .extra9, .extra10] where !parts.contains(p) {
                parts.insert(p)
                return zh ? "多寫一些細節和感想，讓字數夠" : "added more detail to reach the length"
            }
            return nil
        default: return nil
        }
    }

    /// 寫：第一稿 → 檢查 → 修改 → 再檢查……直到沒有問題（最多 10 次）
    public static func write(_ a: Ask) -> Result {
        let seed = stable(a.original)
        var parts: Set<Part> = [.draft]
        let user = a.kind == .polish ? a.original : nil
        var text = render(parts, a, seed: seed, userText: user)
        var drafts = [text], notes: [String] = []
        for _ in 0..<16 {
            let problems = review(text, a)
            if problems.isEmpty { break }
            let before = parts
            // 一次改兩個問題，像老師批改一樣一項一項來；改不動的問題換下一個
            var fixed = 0
            for pr in problems where fixed < 2 {
                let was = parts
                if let why = fix(pr, &parts, a, lang: a.lang), !why.isEmpty { notes.append(why) }
                if parts != was { fixed += 1 }
            }
            if parts == before { break }
            text = render(parts, a, seed: seed, userText: user)
            drafts.append(text)
        }
        // 第一稿是給自己看的：修改到後來，平淡的那句已經被生動的描寫取代
        return Result(text: text, drafts: drafts, notes: notes, units: units(text, lang: a.lang))
    }

    /// 回覆給使用者的文字
    public static func reply(_ a: Ask) -> String {
        let r = write(a)
        let n0 = units(a.original, lang: a.lang)
        let times = String(format: "%.1f", Double(r.units) / Double(max(1, n0)))
        var notes: [String] = []
        for x in r.notes where !notes.contains(x) { notes.append(x) }
        switch a.lang {
        case "en": return "✍️ Expanded:\n\n\(r.text)\n\n📝 My first draft was too plain, so I revised it \(r.drafts.count - 1) times: \(notes.joined(separator: "; ")). It is now \(r.units) words (\(times)× the original)."
        case "es": return "✍️ Ampliado:\n\n\(r.text)\n\n📝 El primer borrador era demasiado simple, así que lo corregí \(r.drafts.count - 1) veces. Ahora tiene \(r.units) palabras (\(times) veces la frase original)."
        case "it": return "✍️ Espanso:\n\n\(r.text)\n\n📝 La prima bozza era troppo semplice, quindi l'ho corretta \(r.drafts.count - 1) volte. Ora sono \(r.units) parole (\(times) volte la frase originale)."
        default:
            let head = a.kind == .polish ? "✍️ 修改後：" : a.kind == .detail ? "✍️ 詳寫「\(a.original)」：" : "✍️ 擴寫「\(a.original)」："
            return "\(head)\n\n\(r.text)\n\n📝 第一稿太平淡，改了 \(r.drafts.count - 1) 次：" + notes.joined(separator: "；") + "。現在 \(r.units) 字（原句的 \(times) 倍）。"
        }
    }
}
