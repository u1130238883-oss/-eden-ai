import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 翻譯：聽懂「蘋果用西班牙文怎麼說」「把這句翻成英文：…」「gracias 是什麼意思」，
/// 交給手機內建的翻譯（App 那邊）、AI 或線上翻譯（日常的東西不在 App 裡存固定答案）。
public enum Translate {
    public enum Code: String, CaseIterable, Sendable {
        case zh = "zh-Hant", zhHans = "zh-Hans", en, es, it, ar, ja, ko, fr, de, ru, pt

        /// 中文名字
        public var name: String {
            switch self {
            case .zh: return "繁體中文"
            case .zhHans: return "簡體中文"
            case .en: return "英文"
            case .es: return "西班牙文"
            case .it: return "義大利文"
            case .ar: return "阿拉伯文"
            case .ja: return "日文"
            case .ko: return "韓文"
            case .fr: return "法文"
            case .de: return "德文"
            case .ru: return "俄文"
            case .pt: return "葡萄牙文"
            }
        }

        /// 同一種語言（繁中、簡中都算中文）
        var lex: String? {
            switch self {
            case .zh, .zhHans: return "zh"
            case .en: return "en"
            case .es: return "es"
            case .it: return "it"
            case .ar: return "ar"
            default: return nil
            }
        }

        /// MyMemory 線上翻譯用的代號
        var memory: String {
            switch self {
            case .zh: return "zh-TW"
            case .zhHans: return "zh-CN"
            default: return rawValue
            }
        }
    }

    public struct Request: Equatable, Sendable {
        public let text: String
        /// nil：自己看是什麼語言
        public let source: Code?
        public let target: Code
        public init(text: String, source: Code?, target: Code) {
            self.text = text; self.source = source; self.target = target
        }
    }

    // MARK: - 聽懂要翻譯什麼

    /// 各種語言名稱的說法（長的放前面，才不會「中文」先吃掉「繁體中文」）
    static let names: [(String, Code)] = [
        ("繁體中文", .zh), ("正體中文", .zh), ("簡體中文", .zhHans), ("簡體字", .zhHans), ("繁體字", .zh), ("繁體", .zh), ("簡體", .zhHans),
        ("中文", .zh), ("國語", .zh), ("華語", .zh), ("漢語", .zh), ("普通話", .zh),
        ("英文", .en), ("英語", .en), ("西班牙文", .es), ("西班牙語", .es), ("西文", .es), ("西語", .es),
        ("義大利文", .it), ("義大利語", .it), ("意大利文", .it), ("意大利語", .it), ("義文", .it), ("義語", .it),
        ("阿拉伯文", .ar), ("阿拉伯語", .ar), ("阿文", .ar), ("阿語", .ar),
        ("日文", .ja), ("日語", .ja), ("韓文", .ko), ("韓語", .ko), ("法文", .fr), ("法語", .fr),
        ("德文", .de), ("德語", .de), ("俄文", .ru), ("俄語", .ru), ("葡萄牙文", .pt), ("葡萄牙語", .pt), ("葡文", .pt),
        ("traditional chinese", .zh), ("simplified chinese", .zhHans), ("chinese", .zh), ("mandarin", .zh), ("english", .en),
        ("spanish", .es), ("italian", .it), ("arabic", .ar), ("japanese", .ja), ("korean", .ko), ("french", .fr),
        ("german", .de), ("russian", .ru), ("portuguese", .pt),
        ("inglés", .en), ("ingles", .en), ("chino", .zh), ("español", .es), ("italiano", .it), ("árabe", .ar), ("arabe", .ar),
        ("inglese", .en), ("cinese", .zh), ("spagnolo", .es), ("arabo", .ar),
    ]

    static var langPattern: String {
        names.map { NSRegularExpression.escapedPattern(for: $0.0) }.joined(separator: "|")
    }

    static func code(_ name: String) -> Code? {
        let n = name.lowercased().trimmingCharacters(in: .whitespaces)
        return names.first { $0.0 == n }?.1
    }

    /// 去掉引號、頭尾的標點
    static func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        for _ in 0..<2 {
            for (a, b) in [("「", "」"), ("『", "』"), ("“", "”"), ("\"", "\""), ("'", "'"), ("《", "》"), ("‘", "’")]
                where t.hasPrefix(a) && t.hasSuffix(b) && t.count > 2 {
                t = String(t.dropFirst().dropLast())
            }
            t = t.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "：:，,")))
        }
        return t
    }

    /// 這段話是不是要翻譯；是的話要翻什麼、翻成哪種語言
    public static func parse(_ raw: String) -> Request? {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, q.count <= 600 else { return nil }
        let L = "(" + langPattern + ")"
        // 中文句型只認中文的語言名稱（「translate good morning to italian」不要被中文句型吃掉）
        let Z = "(" + names.filter { $0.0.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) } }
            .map { NSRegularExpression.escapedPattern(for: $0.0) }.joined(separator: "|") + ")"
        let ask = "[？?。！!]*$"
        let pol = "^(?:請|請你|幫我|麻煩|可以|能不能|你可以)?(?:幫我)?"
        // (樣式, 文字在第幾組, 語言在第幾組)
        let patterns: [(String, Int, Int)] = [
            // 把 X 翻譯成英文
            (pol + "把(.+?)(?:翻譯|翻|譯)(?:成|為|到)" + Z + "(?:是什麼|怎麼說)?" + ask, 1, 2),
            // X 翻譯成英文 / X 翻成英文
            (pol + "(.+?)(?:翻譯|翻|譯)(?:成|為|到)" + Z + "(?:是什麼|怎麼說)?" + ask, 1, 2),
            // 翻譯成英文：X / 英文翻譯：X
            (pol + "(?:把)?(?:這句話|這句|這段話|這段|下面這句話|下面這句|下面這段|以下)?(?:翻譯|翻|譯)(?:成|為|到)?" + Z + "[：:，,\\s]+(.+)$", 2, 1),
            (pol + Z + "翻譯[：:，,\\s]+(.+)$", 2, 1),
            // X 用英文怎麼說 / X 英文怎麼講
            ("^(.+?)(?:用|的)?" + Z + "(?:要|該)?怎麼(?:說|講|寫|唸|念|拼)" + ask, 1, 2),
            // 用英文怎麼說 X
            ("^(?:用)?" + Z + "(?:要|該)?怎麼(?:說|講|寫)[：:，,\\s]*(.+?)" + ask, 2, 1),
            // X 的英文是什麼 / X 英文是什麼 / X 的英文
            ("^(.+?)(?:的|在)?" + Z + "(?:是什麼|是啥|叫什麼|叫做什麼|怎麼寫|是)?" + ask, 1, 2),
            // 英文的 X 怎麼說
            ("^" + Z + "(?:的|裡的)(.+?)(?:怎麼說|是什麼|怎麼寫)" + ask, 2, 1),
            // English
            ("(?i)^(?:please\\s+)?translate\\s+(?:this\\s+)?(?:into|to)\\s+" + L + "[:：,\\s]+(.+)$", 2, 1),
            ("(?i)^(?:please\\s+)?translate\\s+(.+?)\\s+(?:into|to)\\s+" + L + "[.?!]*$", 1, 2),
            ("(?i)^how\\s+(?:do\\s+(?:you|i)\\s+|to\\s+)say\\s+(.+?)\\s+in\\s+" + L + "[.?!]*$", 1, 2),
            ("(?i)^what\\s+is\\s+(.+?)\\s+in\\s+" + L + "[.?!]*$", 1, 2),
            // Español / Italiano
            ("(?i)^¿?\\s*c[oó]mo\\s+se\\s+dice\\s+(.+?)\\s+en\\s+" + L + "[?¿.!]*$", 1, 2),
            ("(?i)^traduc(?:e|ir)\\s+(.+?)\\s+(?:al|a|en)\\s+" + L + "[.!?]*$", 1, 2),
            ("(?i)^come\\s+si\\s+dice\\s+(.+?)\\s+in\\s+" + L + "[?.!]*$", 1, 2),
            ("(?i)^traduci\\s+(.+?)\\s+in\\s+" + L + "[.!?]*$", 1, 2),
        ]
        for (p, ti, li) in patterns {
            guard let m = match(q, p) else { continue }
            let text = clean(m[ti]), lang = code(m[li])
            guard let target = lang, !text.isEmpty, text.count <= 500 else { continue }
            // 「中文是什麼」「英文怎麼說」這種沒有要翻的東西
            if code(text) != nil { continue }
            // 本來就是這個語言（「什麼是中文」「台灣的中文」）：不是要翻譯
            let d = detect(text)
            if d == target || (d.lex != nil && d.lex == target.lex) { continue }
            // 「X 的英文」：X 太長、像在問別的事（「學英文的方法」）就不算
            if p.hasPrefix("^(.+?)(?:的|在)?") {
                if text.count > 30 || ["學", "考", "讀", "方法", "怎麼學", "老師", "課", "程度", "成績", "補習"].contains(where: { text.contains($0) }) { continue }
                // 「蘋果英文」可以；「我想學英文」不行
                if ["我", "你", "他", "想", "要", "會", "能"].contains(where: { text.hasPrefix($0) }) && text.count > 4 { continue }
                // 「你會說英文」「他懂英文」：在問會不會這個語言
                if ["說", "講", "會", "懂", "用", "是", "學", "有", "看", "聽", "寫", "讀", "教"].contains(where: { text.hasSuffix($0) }) { continue }
            }
            return Request(text: text, source: nil, target: target)
        }
        // 翻譯：X / 幫我翻譯 X / translate X（沒說翻成什麼：外文翻成中文，中文翻成英文）
        if let m = match(q, pol + "(?:翻譯一下|翻譯|翻一下)[：:，,\\s]*(.+)$") ?? match(q, "(?i)^(?:please\\s+)?translate[:：,\\s]+(.+)$")
            ?? match(q, "^(.+?)[\\s，,]*(?:翻譯一下|翻譯|翻一下)" + ask) {
            let text = clean(m[1])
            guard !text.isEmpty else { return nil }
            return Request(text: text, source: nil, target: detect(text) == .zh || detect(text) == .zhHans ? .en : .zh)
        }
        // gracias 是什麼意思 / what does gracias mean（外文才算；中文的「XX是什麼意思」是在問解釋）
        if let m = match(q, "^(.+?)[\\s]*(?:是什麼意思|什麼意思|是啥意思|的意思是什麼|的意思|意思是什麼|中文意思)" + ask)
            ?? match(q, "(?i)^what\\s+does\\s+(.+?)\\s+mean[.?!]*$") ?? match(q, "(?i)^(.+?)\\s+meaning[.?!]*$") {
            let text = clean(m[1])
            let d = detect(text)
            guard !text.isEmpty, d != .zh, d != .zhHans, text.contains(where: { $0.isLetter }) else { return nil }
            // 英文問「what does X mean」又是英文單字：翻成中文
            return Request(text: text, source: d, target: .zh)
        }
        return nil
    }

    static func match(_ s: String, _ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            Range(m.range(at: i), in: s).map { String(s[$0]) } ?? ""
        }
    }

    // MARK: - 是哪種語言

    static let esHints: Set<String> = ["el", "la", "los", "las", "que", "es", "está", "estoy", "por", "para", "gracias", "hola", "como", "cómo",
                                       "muy", "yo", "tú", "usted", "buenos", "buenas", "días", "noches", "qué", "dónde", "quiero", "tengo", "y", "una", "un", "del", "al", "pero", "mucho", "bien"]
    static let itHints: Set<String> = ["il", "lo", "gli", "le", "che", "è", "sono", "per", "grazie", "ciao", "come", "molto", "io", "tu", "lei",
                                       "buongiorno", "buonasera", "della", "del", "di", "non", "voglio", "ho", "una", "un", "dove", "perché", "bene", "anche"]
    static let enHints: Set<String> = ["the", "a", "an", "is", "are", "i", "you", "he", "she", "it", "we", "they", "what", "how", "where", "thank",
                                       "thanks", "hello", "good", "morning", "please", "love", "my", "your", "and", "of", "to", "in", "do", "does", "this", "that"]

    public static func detect(_ text: String) -> Code {
        var cjk = 0, kana = 0, hangul = 0, arabic = 0, cyr = 0
        for s in text.unicodeScalars {
            switch s.value {
            case 0x3040...0x30FF: kana += 1
            case 0xAC00...0xD7AF, 0x1100...0x11FF: hangul += 1
            case 0x0600...0x06FF, 0x0750...0x077F, 0xFB50...0xFDFF, 0xFE70...0xFEFF: arabic += 1
            case 0x0400...0x04FF: cyr += 1
            case 0x4E00...0x9FFF, 0x3400...0x4DBF: cjk += 1
            default: break
            }
        }
        if kana > 0 { return .ja }
        if hangul > 0 { return .ko }
        if arabic > 0 { return .ar }
        if cyr > 0 { return .ru }
        if cjk > 0 { return .zh }
        let lower = text.lowercased()
        let words = lower.split { !($0.isLetter || $0 == "'") }.map(String.init)
        var es = 0, it = 0, en = 0
        for w in words {
            if esHints.contains(w) { es += 2 }
            if itHints.contains(w) { it += 2 }
            if enHints.contains(w) { en += 2 }
        }
        for c in lower {
            if "ñ¿¡áíóú".contains(c) { es += 2 }
            if "èìòù".contains(c) { it += 2 }
        }
        if es > it && es > en { return .es }
        if it > es && it > en { return .it }
        return .en
    }

    public struct Result: Equatable, Sendable {
        /// 翻出來的那一句（字典的最佳答案或整句翻譯）
        public var text: String
        /// 讀音（拼音、音標、阿拉伯文拼音）
        public var pron: String = ""
        /// 字典的詳細說明（每一行一個）
        public var notes: [String] = []
        /// 其他說法
        public var alternatives: [String] = []
        public var source: Code
        public var via: String

        public init(text: String, pron: String = "", notes: [String] = [], alternatives: [String] = [], source: Code, via: String) {
            self.text = text; self.pron = pron; self.notes = notes; self.alternatives = alternatives; self.source = source; self.via = via
        }
    }

    // MARK: - 寫成回答

    public static func reply(_ r: Request, _ res: Result) -> String {
        var lines = ["🌐 \(res.source.name) → \(r.target.name)", res.text + (res.pron.isEmpty ? "" : "　〔\(res.pron)〕")]
        if !res.alternatives.isEmpty { lines.append("也可以說：" + res.alternatives.joined(separator: "、")) }
        if !res.notes.isEmpty { lines.append("📖 " + res.notes.prefix(4).joined(separator: "\n")) }
        lines.append("（\(res.via)）")
        return lines.joined(separator: "\n")
    }

    // MARK: - 線上翻譯（沒有內建翻譯、也沒有 AI 金鑰時）

    /// MyMemory 的免費翻譯服務（不需要金鑰）
    public static func online(_ r: Request) async -> Result? {
        let src = r.source ?? detect(r.text)
        guard src != r.target else { return nil }
        var c = URLComponents(string: "https://api.mymemory.translated.net/get")!
        c.queryItems = [.init(name: "q", value: r.text), .init(name: "langpair", value: "\(src.memory)|\(r.target.memory)")]
        guard let url = c.url else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("NineSun/1.0", forHTTPHeaderField: "User-Agent")
        guard let (d, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let rd = j["responseData"] as? [String: Any], let t = rd["translatedText"] as? String,
              !t.isEmpty, !t.uppercased().contains("MYMEMORY WARNING"), !t.uppercased().contains("INVALID") else { return nil }
        return Result(text: t, source: src, via: "MyMemory 線上翻譯")
    }

    /// 請 AI 翻譯時的指示
    public static func aiPrompt(_ r: Request) -> String {
        "把下面這段翻譯成\(r.target.name)。只回譯文本身，不要解釋、不要加引號；如果是單字，譯文後面可以用括號補一個讀音或最常見的另一種說法。\n\n\(r.text)"
    }
}
