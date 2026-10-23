import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 翻譯：聽懂「蘋果用西班牙文怎麼說」「把這句翻成英文：…」「gracias 是什麼意思」，
/// 交給 Google 翻譯或手機內建的翻譯（App 那邊），翻好後念出來；App 裡不存字典。
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
        public var lex: String? {
            switch self {
            case .zh, .zhHans: return "zh"
            case .en: return "en"
            case .es: return "es"
            case .it: return "it"
            case .ar: return "ar"
            default: return nil
            }
        }

        /// 念出來用的語音（AVSpeechSynthesisVoice 的語言代號）
        public var voice: String {
            switch self {
            case .zh: return "zh-TW"
            case .zhHans: return "zh-CN"
            case .en: return "en-US"
            case .es: return "es-ES"
            case .it: return "it-IT"
            case .ar: return "ar-SA"
            case .ja: return "ja-JP"
            case .ko: return "ko-KR"
            case .fr: return "fr-FR"
            case .de: return "de-DE"
            case .ru: return "ru-RU"
            case .pt: return "pt-PT"
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
        // 開頭的客套話不是要翻的內容（「請問一下X翻成英文」「麻煩一下，X換成西文」「那X的義大利文」）
        var q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 「那」後面接外文才是口頭禪（「那short and sweet…」）；「那條毛巾」「那本書」的「那」是內容
        let lead = #"^(請問一下|麻煩一下|請教一下|麻煩你|請問|告訴我|欸|嗯|那(?=[A-Za-z¿¡「"]))[，,、\s]*(?=.)"#
        if let r = q.range(of: lead, options: .regularExpression), q[r.upperBound...].count >= 2 { q = String(q[r.upperBound...]) }
        // 同一個意思的不同說法，先換成認得的說法：「中譯英」＝「中翻英」、「X 的英語說法」＝「X 的英語」、
        // 「，請翻西」＝「，翻西」、「這個用國語怎麼表達」＝「用國語怎麼表達」、「… please」
        for (p, r) in [(#"([中英西義意日韓法德])譯([中英西義意日韓法德])"#, "$1翻$2"), (#"[，,]\s*請翻"#, "，翻"), (#"(?<=[^，,、：:\s])這個用"#, "用"),
                       (#"的(\S{2,5}?)說法$"#, "的$1"), (#"(?i)^([^：:]*?),?\s+please[.!]?$"#, "$1"), (#"(?i)^please\s+(?=(translate|how|what|say|tell)\b)"#, "")] {
            q = q.replacingOccurrences(of: p, with: r, options: .regularExpression)
        }
        // 結尾的「～」「~」只是口氣
        q = q.replacingOccurrences(of: #"[～~]+$"#, with: "", options: .regularExpression)
        guard !q.isEmpty, q.count <= 600 else { return nil }
        // 有中文的語言名稱：先拆開來想（固定句型容易把「請問」「告訴我」也當成內容）
        if let r = understand(q) { return r }
        // 簡稱：「中翻英：你好」「翻西 謝謝」「你好 翻英」「謝謝中翻義」「早安翻成英」
        if let r = abbreviated(q) { return r }
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
            ("^(.+?)(?:翻譯|翻|譯)(?:成|為|到)" + Z + "(?:是什麼|怎麼說)?" + ask, 1, 2),
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
            ("(?i)^what'?s\\s+(.+?)\\s+in\\s+" + L + "[.?!]*$", 1, 2),
            ("(?i)^(?:what'?s|what\\s+is)\\s+the\\s+" + L + "\\s+(?:word\\s+)?for\\s+(.+?)[.?!]*$", 2, 1),
            ("(?i)^(?:the\\s+)?" + L + "\\s+(?:word\\s+)?for\\s+(.+?)[.?!]*$", 2, 1),
            ("(?i)^how\\s+(?:do\\s+you|do\\s+i|to)\\s+translate\\s+(.+?)\\s+(?:into|to|in)\\s+" + L + "[.?!]*$", 1, 2),
            ("(?i)^¿?\\s*c[oó]mo\\s+(?:digo|puedo\\s+decir|se\\s+escribe)\\s+(.+?)\\s+en\\s+" + L + "[?¿.!]*$", 1, 2),
            ("(?i)^come\\s+(?:posso\\s+dire|dico|si\\s+scrive)\\s+(.+?)\\s+in\\s+" + L + "[?.!]*$", 1, 2),
            ("(?i)^(?:can|could|would)\\s+you\\s+(?:please\\s+)?translate\\s+(.+?)\\s+(?:into|to)\\s+" + L + "[.?!]*$", 1, 2),
            ("(?i)^how\\s+(?:would|should|can|could|do)\\s+(?:i|you|we|one)\\s+say\\s+(.+?)\\s+in\\s+" + L + "[.?!]*$", 1, 2),
            ("(?i)^(?:please\\s+)?say\\s+(.+?)\\s+in\\s+" + L + "[.?!]*$", 1, 2),
            // Español / Italiano
            ("(?i)^¿?\\s*c[oó]mo\\s+se\\s+dice\\s+(.+?)\\s+en\\s+" + L + "[?¿.!]*$", 1, 2),
            ("(?i)^traduc(?:e|ir)\\s+(.+?)\\s+(?:al|a|en)\\s+" + L + "[.!?]*$", 1, 2),
            ("(?i)^come\\s+si\\s+dice\\s+(.+?)\\s+in\\s+" + L + "[?.!]*$", 1, 2),
            ("(?i)^traduci\\s+(.+?)\\s+in\\s+" + L + "[.!?]*$", 1, 2),
            // 最寬的說法放最後：「X in Spanish (please)」——前面有「come si dice」「traduci」「how do you say」的要先比對
            ("(?i)^(.+?)\\s+in\\s+" + L + "(?:\\s*,?\\s*please)?[.?!]*$", 1, 2),
        ]
        for (p, ti, li) in patterns {
            guard let m = match(q, p) else { continue }
            let text = clean(m[ti]), lang = code(m[li])
            guard let target = lang, !text.isEmpty, text.count <= 500 else { continue }
            // 本來就是這個語言（「什麼是中文」「台灣的中文」）：不是要翻譯
            if code(text) == nil, let d = confidentLang(text), d == target || (d.lex != nil && d.lex == target.lex) { continue }
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
        if let m = match(q, pol + "(?:翻譯一下|翻一下|翻譯[：:，,\\s]+)[：:，,\\s]*(.+)$") ?? match(q, "(?i)^(?:please\\s+)?translate[:：,\\s]+(.+)$")
            ?? match(q, "^(.+?)[\\s，,]*(?:翻譯一下|翻譯|翻一下)" + ask) {
            let text = clean(m[1])
            // 「什麼叫翻譯」「你翻譯得不錯」不是要翻譯
            guard !text.isEmpty, text.range(of: "(?:什麼|叫|是|會|做|的|好|你|不錯|怎麼)$", options: .regularExpression) == nil else { return nil }
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

    /// 拆開來想（「你有沒有吃飯用英語說」「用英文跟他說謝謝」「教我用西班牙文說我愛你」「這句英文怎麼說：你吃飯了嗎」）：
    /// ① 句子裡只提到一種語言 → 那是要翻成的語言；不是在問學語言、會不會說
    /// ② 找出「語言那一段」（用英文說／翻成英文／的英文是什麼／在英文裡怎麼說），這一段要有翻譯的意思（「他說英文嗎」就沒有）
    /// ③ 那一段前面、後面哪一邊是內容：前面只有「請問、教我、這句」這類包裝 → 內容在後面；不然內容在前面
    /// ④ 內容去掉包裝（「請問」「告訴我」「跟他說」），不能是空的、不能明顯本來就是那個語言
    static func understand(_ raw: String) -> Request? {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "？?。！!～~")))
        let zhNames = names.filter { $0.0.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) } }
        let Z = "(?:" + zhNames.map { NSRegularExpression.escapedPattern(for: $0.0) }.joined(separator: "|") + ")"
        // ① 語言那一段（用英文說／翻成英文／的英文是什麼／在英文裡怎麼說）。句子裡可能有好幾個語言名稱
        //   （「義大利文用英文怎麼說」：要翻的是「義大利文」這個詞），挑最後一個真的有翻譯意思的那一段
        let seg = "[（(]?(?:(?:翻譯|翻|譯|換|轉)(?:成|為|到)?|用|以|拿|換成|的|在)?" + Z
            + "(?:裡|中)?(?:的話|的)?(?:要|該|來)?(?:怎麼|怎樣|怎么|咋|如何)?(?:來)?(?:說|講|寫|念|唸|表達|翻譯|拼)?(?:出來)?"
            + "(?:是什麼|叫什麼|叫做什麼|是啥|是)?(?:呢|啊|呀|嗎)?[）)]?"
        let cue = ["翻", "譯", "換", "轉", "用", "以", "拿", "說", "講", "寫", "念", "唸", "表達", "是什麼", "叫什麼", "是啥", "怎麼", "怎樣", "咋", "如何", "的話"]
        guard let segRe = try? NSRegularExpression(pattern: seg), let zRe = try? NSRegularExpression(pattern: Z) else { return nil }
        var chosen: (part: String, prefix: String, suffix: String, target: Code, hasCue: Bool)?
        var chosenBare: (part: String, prefix: String, suffix: String, target: Code, hasCue: Bool)?
        // 每個語言名稱都各自找一次「語言那一段」（可以重疊：「把日文翻成英文」的「日文」和「翻成英文」）
        let ns = q as NSString
        var segs: [Range<String.Index>] = []
        for zm in zRe.matches(in: q, range: NSRange(location: 0, length: ns.length)) {
            var best: NSRange?
            for back in stride(from: min(4, zm.range.location), through: 0, by: -1) {
                let start = zm.range.location - back
                if let m = segRe.firstMatch(in: q, options: .anchored, range: NSRange(location: start, length: ns.length - start)),
                   m.range.location + m.range.length >= zm.range.location + zm.range.length {
                    best = m.range
                    break
                }
            }
            if let b = best, let r = Range(b, in: q) { segs.append(r) }
        }
        for r in segs {
            let part = String(q[r]), prefix = String(q[..<r.lowerBound]), suffix = String(q[r.upperBound...])
            guard let zm = zRe.firstMatch(in: part, range: NSRange(part.startIndex..., in: part)), let zr = Range(zm.range, in: part),
                  let target = code(String(part[zr])) else { continue }
            let bare = part.replacingOccurrences(of: Z, with: "", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "（()）"))
            // 「英文：X」「X（英文）」「英文的話 X 怎麼說」：語言後面接冒號、括起來、或句尾還有「怎麼說」也算
            let colonAfter = suffix.hasPrefix("：") || suffix.hasPrefix(":")
            let bracketed = part.hasPrefix("（") || part.hasPrefix("(")
            let askAtEnd = suffix.range(of: "(?:怎麼|怎樣|咋)(?:說|講|寫)(?:呢)?$", options: .regularExpression) != nil
            // 「X的英文」「X 英文」放在最後也算；「他說英文嗎」不算
            let atEnd = suffix.trimmingCharacters(in: .whitespaces).isEmpty
            let hasCue = cue.contains(where: { bare.contains($0) })
            // 有翻譯意思的那一段優先（「翻譯成義大利文：西班牙文」要翻成義大利文）；只有「X的英文」「X 英文」這種沒動詞的才退而求其次
            if hasCue || colonAfter || bracketed || askAtEnd {
                chosen = (part, prefix, suffix, target, hasCue)
            } else if atEnd && (bare.hasPrefix("的") || bare.isEmpty) && !bare.hasSuffix("嗎") {
                chosenBare = (part, prefix, suffix, target, hasCue)
            }
        }
        guard let c = chosen ?? chosenBare else { return nil }
        let target = c.target, prefix = c.prefix, suffix = c.suffix
        // ② 在問學這個語言、會不會講、口音（要緊貼著這個語言才算：「學校用英文怎麼說」還是要翻）
        let T = "(?:" + zhNames.filter { $0.1 == target }.map { NSRegularExpression.escapedPattern(for: $0.0) }.joined(separator: "|") + ")"
        var about = "(?:學|學習|懂|會說|會講|會不會說|會不會講|能說|能講|考|讀|教|補習|練)" + T + "|" + T
            + "(?:課|老師|程度|考試|好難|難不難|文法|口音|流利|很好|很爛|不好|好不好|怎麼學|要學|好學|檢定|單字量|說得|講得|很強|進步)"
        if !c.hasCue { about += "|幾種語言|哪種語言|什麼語言" }
        guard q.range(of: about, options: .regularExpression) == nil else { return nil }
        // ③ 內容在哪一邊
        let wrap = "(?:請你|請問|請|麻煩你|麻煩|可以幫我|幫我|教我|可以|你可以|能不能|可不可以|告訴我|跟我說|欸|誒|那個|嗯|哈囉|嗨|嘿|如何|要怎麼|怎麼"
            + "|如果要|如果|那麼|那|還有|另外|我想知道|想知道|想問|我想問|請教|(?i:ninesun)"
            + "|這句話|這句|這段話|這段|這個字|這個詞|這個|下面這句|以下|句子|我想要|我想|我要|翻譯一下|翻一下|翻譯|把|[，,、：:\\s])"
        let suffixReal = !suffix.trimmingCharacters(in: CharacterSet(charactersIn: "，,、：:?？!！。～~ ")).isEmpty
        var content: String
        if suffixReal && prefix.range(of: "^" + wrap + "*$", options: .regularExpression) != nil {
            content = suffix
            for p in ["^[，,、：:\\s]+", "^(?:跟|對|和|向)(?:他|她|他們|她們|你|對方|朋友|老外|外國人|老闆|客人|別人|大家)(?:說|講)"] {
                content = content.replacingOccurrences(of: p, with: "", options: .regularExpression)
            }
            // 「需要怎麼說」：「要」可能是內容的一部分——拿掉「要怎麼說」只剩一個字時，只拿掉「怎麼說」
            let withYao = content.replacingOccurrences(of: "(?:要|該)?(?:怎麼|怎樣|咋)(?:說|講|寫)(?:呢)?$", with: "", options: .regularExpression)
            content = clean(withYao).count >= 2 || !content.hasSuffix("說") && !content.hasSuffix("講") && !content.hasSuffix("寫") && !content.hasSuffix("呢")
                ? withYao : content.replacingOccurrences(of: "(?:怎麼|怎樣|咋)(?:說|講|寫)(?:呢)?$", with: "", options: .regularExpression)
            // 「英文的話是的怎麼說」「義大利語的話說好怎麼說」：語言那一段吃掉了內容的第一個字（是、說）——只剩一個字時補回去
            if clean(content).count == 1, let last = c.part.last, "說講是寫".contains(last) { content = String(last) + content }
        } else {
            // 語言前後都有實際的內容（「我在翻英文書」）：是一般的句子，不是要翻譯
            let rest = suffix.replacingOccurrences(of: "^(?:[，,、：:?？!！。～~\\s]|呢|啊|呀|嗎|吧|才自然|比較自然|比較道地|才道地|才對|比較好|最自然|最道地|的話是什麼|的話|是什麼)+$", with: "", options: .regularExpression)
            guard rest.isEmpty else { return nil }
            let original = prefix
            content = prefix
            // 開頭的包裝；「請問」後面本身就是問句（「請問車站怎麼走」）就留著；「那輛車」的「那」是內容
            let mw = "個是裡邊些麼就天時輛本張隻件條家座顆杯枝支把台扇盞面份封副根球頭匹位列架艘頂所棵朵間塊"
            // 「那個」後面是整句話（「那個碗很重」）時是「那個」，不是口頭禪
            let fillerThat = "那個(?![^，,]*[很是了。有在會要想])"
            let lead = "^(?:欸|誒|" + fillerThat + "|嗯|哈囉|嗨|嘿|告訴我|跟我說|翻譯一下|翻一下|可以幫我把|幫我把|請把|麻煩把|把|如何"
                + "|可不可以告訴我|可以告訴我|我想知道|想知道|我想問|想問|請教|還有|另外|那麼|那(?=[，,\\s])|那(?![" + mw + "])|(?i:ninesun)"
                + "|請問(?=請問|你|妳|您|我|他|她|大家)|請問(?!.*(?:怎麼|哪|嗎|什麼|幾|多少|誰|呢)))[，,、：:\\s]*"
            for _ in 0..<3 { content = content.replacingOccurrences(of: lead, with: "", options: .regularExpression) }
            content = content.replacingOccurrences(of: "(?:要怎麼|該怎麼|怎麼|如何|這句話|這句|這個字|這個詞|[，,、：:?？\\s])+$", with: "", options: .regularExpression)
            // 拿掉包裝後什麼都不剩：那些字本身就是要翻的（「請問」「那個」「翻譯」）
            // 「我想知道怎麼用義大利語怎麼說」：拿掉客套話之後剩下的「怎麼」本身就是要翻的
            var kept = original
            for _ in 0..<3 { kept = kept.replacingOccurrences(of: lead, with: "", options: .regularExpression) }
            kept = kept.replacingOccurrences(of: "(?:這句話|這句|這個字|這個詞|[，,、：:?？\\s])+$", with: "", options: .regularExpression)
            if clean(content).isEmpty, !clean(kept).isEmpty, kept != original { content = kept }
            if clean(content).isEmpty {
                content = original.replacingOccurrences(of: "(?:這句話|這句|這個字|這個詞|[，,、：:?？\\s])+$", with: "", options: .regularExpression)
                content = content.replacingOccurrences(of: "^(?:請問(?=.)|把(?=.))", with: "", options: .regularExpression)
            }
        }
        // ④ 內容要像樣
        let text = clean(content)
        guard !text.isEmpty, text.count <= 300, !["嗎", "呢", "啊", "呀"].contains(text) else { return nil }
        // 本來就是那個語言的句子（語言名稱本身例外：「Italian 用義大利文怎麼說」）
        if code(text) == nil, let d = confidentLang(text), d == target || (d.lex != nil && d.lex == target.lex) { return nil }
        return Request(text: text, source: nil, target: target)
    }

    static let shortNames: [Character: Code] = ["中": .zh, "英": .en, "西": .es, "義": .it, "意": .it, "日": .ja, "韓": .ko, "法": .fr, "德": .de]

    static func abbreviated(_ raw: String) -> Request? {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "？?。！!～~")))
        let S = "[中英西義意日韓法德]"
        let pats: [(String, Int, Int)] = [
            ("^(?:請|請你|幫我|麻煩)?(?:" + S + ")?翻(" + S + ")(?:文)?[：:，,\\s]+(.+)$", 2, 1),
            ("^(.+?)[\\s，,：:]+(?:幫我)?(?:" + S + ")?翻(" + S + ")(?:文)?$", 1, 2),
            ("^(.+?)" + S + "翻(" + S + ")(?:文)?$", 1, 2),
            ("^(.+?)(?:翻譯|翻|譯)(?:成|為|到)(" + S + ")(?:文)?$", 1, 2),
        ]
        for (p, ti, li) in pats {
            guard let m = match(q, p), let c = m[li].first, let target = shortNames[c] else { continue }
            let text = clean(m[ti])
            guard !text.isEmpty, text.count <= 300 else { continue }
            if code(text) == nil, let d = confidentLang(text), d == target || (d.lex != nil && d.lex == target.lex) { continue }
            return Request(text: text, source: nil, target: target)
        }
        return nil
    }

    /// 有把握才說是哪種語言（中文、日文這些看字就知道；拉丁字母要有明顯的特徵字或重音），沒把握回 nil
    static func confidentLang(_ text: String) -> Code? {
        // 成語的外文說法：知道是哪一種語言（「la goccia scava la pietra」是義大利文，不是西班牙文）；兩種語言都有的字不確定
        if !Idioms.foreignHits(text).isEmpty { return Idioms.foreignLang(text).flatMap { Code(rawValue: $0) } }
        let d = detect(text)
        if ![Code.en, .es, .it].contains(d) { return d }
        let lower = text.lowercased()
        let words = lower.split { !($0.isLetter || $0 == "'") }.map(String.init)
        func score(_ hints: Set<String>, _ marks: String) -> Int {
            words.filter { hints.contains($0) }.count * 2 + lower.filter { marks.contains($0) }.count * 2
        }
        let sc: [(Code, Int)] = [(.en, score(enHints, "")), (.es, score(esHints, "ñ¿¡áíóú")), (.it, score(itHints, "èìòù"))]
        let sorted = sc.sorted { $0.1 > $1.1 }
        return sorted[0].1 >= 4 && sorted[0].1 >= sorted[1].1 + 4 ? sorted[0].0 : nil
    }

    /// 接著上一次翻譯問：「那西班牙文呢？」「義大利文呢」「in Italian?」「¿y en italiano?」→ 同一段話換一種語言
    public static func followUp(_ raw: String, last: Request?) -> Request? {
        guard let last else { return nil }
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let Z = "(" + langPattern + ")"
        let pats = ["^(?:那|那麼)?(?:換成|改成|用)?" + Z + "(?:呢|的呢|怎麼說|怎麼說呢|是什麼|是什麼呢)?[？?。！!]*$",
                    "(?i)^(?:and |what about |how about )?(?:in )?" + Z + "[?.!]*$",
                    "(?i)^¿?\\s*(?:y )?(?:en )?" + Z + "[?¿.!]*$",
                    "(?i)^(?:e )?(?:in )?" + Z + "[?.!]*$"]
        for p in pats {
            guard let m = match(q, p), let target = code(m[1]) else { continue }
            guard target != (last.source ?? detect(last.text)) else { return nil }
            return Request(text: last.text, source: last.source, target: target)
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
                                       "muy", "yo", "tú", "usted", "buenos", "buenas", "días", "noches", "qué", "dónde", "quiero", "tengo", "y", "una", "un", "del", "al", "pero", "mucho", "bien",
                                       "siento", "llamo", "hasta", "luego", "gusto", "favor", "hambre", "baño", "estás", "te", "adiós", "perdón"]
    static let itHints: Set<String> = ["il", "lo", "gli", "le", "che", "è", "sono", "per", "grazie", "ciao", "come", "molto", "io", "tu", "lei",
                                       "buongiorno", "buonasera", "della", "del", "di", "non", "voglio", "ho", "una", "un", "dove", "perché", "bene", "anche",
                                       "amo", "manchi", "arrivederci", "quanto", "costa", "fame", "buonanotte", "piacere", "conoscerti", "favore", "bagno", "stai", "dov'è", "scusi"]
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
        /// 翻回原文核對意思（「翻回中文：你吃飯了嗎？」）
        public var back = ""

        public init(text: String, pron: String = "", notes: [String] = [], alternatives: [String] = [], source: Code, via: String) {
            self.text = text; self.pron = pron; self.notes = notes; self.alternatives = alternatives; self.source = source; self.via = via
        }
    }

    // MARK: - 寫成回答

    /// 只給譯文（中文附拼音）；不加「也可以說」、說明、來源（字典的其他說法常常意思不一樣：今天 ≠ now）
    public static func reply(_ r: Request, _ res: Result) -> String {
        res.text + (res.pron.isEmpty ? "" : "　〔\(res.pron)〕")
    }

    /// 比對用：去掉標點、空白、大小寫
    static func norm(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// 短到算一個詞或片語（查字典、給其他說法）
    public static func isWordish(_ text: String) -> Bool {
        let t = clean(text)
        if t.contains(where: { "。！？.!?，,；;".contains($0) }) { return false }
        let cjk = t.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        if cjk > 0 { return t.count <= 6 }
        return t.split(separator: " ").count <= 3
    }

    /// 一個詞（中文三個字以內、外文一個字）
    public static func isSingleWord(_ text: String) -> Bool {
        let t = clean(text)
        let cjk = t.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        if cjk > 0 { return t.count <= 3 }
        return !t.contains(" ") && t.count <= 20
    }

    /// 去掉跟譯文一樣、或彼此一樣的說法（只差標點、大小寫的算一樣）
    public static func distinct(_ alts: [String], from main: String) -> [String] {
        var seen: Set<String> = [norm(main)]
        return alts.filter { !norm($0).isEmpty && seen.insert(norm($0)).inserted }
    }

    // MARK: - Google 翻譯

    /// Google 翻譯（translate.googleapis.com 的免費網頁介面，不需要金鑰）。原文語言交給 Google 自己判斷；
    /// 有讀音（拼音、羅馬拼音）的話一起帶回來
    public static func google(_ r: Request) async -> Result? {
        var c = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        c.queryItems = [.init(name: "client", value: "gtx"), .init(name: "sl", value: r.source?.memory ?? "auto"),
                        .init(name: "tl", value: r.target.memory), .init(name: "dt", value: "t"), .init(name: "dt", value: "rm"), .init(name: "dt", value: "bd"),
                        .init(name: "q", value: r.text)]
        guard let url = c.url else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        var parsed: (text: String, pron: String, source: Code?, alternatives: [String])?
        if let (d, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
           let j = try? JSONSerialization.jsonObject(with: d) {
            parsed = parseGoogle(j, target: r.target)
        }
        // 第一個介面被擋時，換 Chrome 擴充功能用的那個
        if parsed == nil {
            var c2 = URLComponents(string: "https://clients5.google.com/translate_a/t")!
            c2.queryItems = [.init(name: "client", value: "dict-chrome-ex"), .init(name: "sl", value: r.source?.memory ?? "auto"),
                             .init(name: "tl", value: r.target.memory), .init(name: "q", value: r.text)]
            if let u = c2.url {
                var req2 = URLRequest(url: u, timeoutInterval: 8)
                req2.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                if let (d, resp) = try? await URLSession.shared.data(for: req2), (resp as? HTTPURLResponse)?.statusCode == 200,
                   let j = try? JSONSerialization.jsonObject(with: d) {
                    parsed = parseGoogleSimple(j).map { ($0.text, $0.pron, $0.source, []) }
                }
            }
        }
        guard let parsed else { return nil }
        let src = parsed.source ?? r.source ?? detect(r.text)
        return Result(text: parsed.text, pron: parsed.pron, alternatives: parsed.alternatives, source: src, via: "Google 翻譯")
    }

    /// 第二個介面：["譯文"] 或 [["譯文","en"]]
    static func parseGoogleSimple(_ j: Any) -> (text: String, pron: String, source: Code?)? {
        guard let top = j as? [Any], let first = top.first else { return nil }
        if let t = first as? String, !t.isEmpty { return (t, "", nil) }
        if let a = first as? [Any], let t = a.first as? String, !t.isEmpty {
            let src = (a.count > 1 ? a[1] as? String : nil).flatMap { n -> Code? in
                n.hasPrefix("zh") ? (n == "zh-TW" ? .zh : .zhHans) : Code(rawValue: n)
            }
            return (t, "", src)
        }
        return nil
    }

    /// Google 回來的 JSON：[[["譯文","原文",…],…,[null,null,"讀音","原文讀音"]], null, "en", …]
    static func parseGoogle(_ j: Any, target: Code) -> (text: String, pron: String, source: Code?, alternatives: [String])? {
        guard let top = j as? [Any], let segs = top.first as? [Any] else { return nil }
        var text = "", pron = ""
        for seg in segs {
            guard let a = seg as? [Any] else { continue }
            if let t = a.first as? String { text += t }
            // 讀音那一段：前兩格是空的，第三格是譯文的讀音
            else if a.count > 2, let p = a[2] as? String { pron += p }
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let srcName = top.count > 2 ? top[2] as? String : nil
        let src: Code? = srcName.flatMap { n in
            switch n {
            case "zh-TW": return .zh
            case "zh-CN", "zh": return .zhHans
            default: return Code(rawValue: n)
            }
        }
        // 只有中文、日文、韓文、阿拉伯文、俄文的譯文需要讀音
        let needPron: Set<Code> = [.zh, .zhHans, .ja, .ko, .ar, .ru]
        // 單字的字典：[["noun",["apple","…"],…],["verb",[…]]] → 其他說法（每個詞性前兩個，跟譯文不同的）
        var alts: [String] = []
        if top.count > 1, let dict = top[1] as? [Any] {
            for entry in dict {
                guard let e = entry as? [Any], e.count > 1, let words = e[1] as? [String] else { continue }
                for w in words.prefix(2) where norm(w) != norm(text) && !alts.contains(w) { alts.append(w) }
            }
        }
        return (text, needPron.contains(target) ? pron.trimmingCharacters(in: .whitespaces) : "", src, Array(alts.prefix(4)))
    }

    // MARK: - 線上翻譯（Google 也連不上時）

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
        "把下面這段翻譯成\(r.target.name)，要像\(r.target.name)母語人士在日常生活裡真的會這樣說：用自然、口語、常用的講法，"
            + "不要逐字直譯（例如「加油」不要翻成 add oil，「辛苦了」不要翻成 you worked hard）；語氣、客氣程度跟原文一樣。"
            + "只回譯文本身，不要解釋、不要加引號、不要加讀音。\n\n\(r.text)"
    }
}
