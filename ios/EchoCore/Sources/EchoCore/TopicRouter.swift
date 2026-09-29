import Foundation

/// 主題問句：「我今年感情運如何」「明年事業順不順」「will I have luck with money this year」。
/// 解析出要看的宮位與時間範圍，再交給 Reader.topicReading（本命 + 大運方面 + 流年引動 + 流月）。
public enum TopicRouter {
    public struct Parsed {
        public var palace: Int
        public var y: Int
        public var m: Int?
        /// 一次問好幾個主題（「感情和朋友」）
        public var palaces: [Int] = []
    }

    /// (宮位, 詞)。中文用子字串比對；外語用「單字開頭」比對（amor→amore、trabaj→trabajo）。
    static let zhTopics: [(Int, [String])] = [
        // 感情看 5宮（戀愛、性生活、吸引力）＋ 7宮（負責任的一對一關係、交往、結婚、婚姻）
        (5, ["感情", "戀愛", "愛情", "桃花", "脫單", "暗戀", "曖昧", "談戀愛", "性方面", "性生活", "吸引力", "魅力", "性慾"]),
        (7, ["感情", "談戀愛", "婚姻", "伴侶", "結婚", "配偶", "夫妻", "老公", "老婆", "另一半", "對象", "交往", "一對一", "正緣"]),
        (10, ["事業", "工作", "職場", "升職", "加薪", "創業", "跳槽", "換工作", "老闆", "考核", "上司", "名聲"]),
        // 錢財看 2宮（我的錢、小錢）＋ 8宮（別人的錢、大錢）
        (2, ["財運", "錢財", "金錢", "賺錢", "收入", "薪水", "存錢", "理財", "正財", "花錢", "經濟", "小錢", "我的錢"]),
        (8, ["財運", "錢財", "金錢", "經濟", "偏財", "投資", "股票", "彩券", "橫財", "意外之財", "大錢", "別人的錢", "借錢",
             "健康", "身體", "生病", "養生", "體力", "精力"]),
        (3, ["學習", "考試", "讀書", "學業", "溝通", "兄弟姐妹", "同事"]),
        (4, ["家庭", "家人", "父母", "媽媽", "母親", "房子", "搬家", "買房", "原生家庭"]),
        (9, ["旅行", "旅遊", "出國", "遠行", "留學", "簽證", "幸運", "機會"]),
        (11, ["朋友", "人脈", "社交", "人際", "貴人", "群體"]),
        (1, ["情緒", "脾氣"]),
        (12, ["緣分", "迷茫", "內心"]),
        (6, ["忙碌", "勞碌", "工作量"]),
    ]

    static let foreignTopics: [Lang: [(Int, [String])]] = [
        .en: [(5, ["love", "romanc", "dating", "crush", "boyfriend", "girlfriend"]),
              (7, ["marriage", "marry", "partner", "spouse", "relationship", "husband", "wife"]),
              (10, ["career", "job", "work", "promotion", "boss", "business", "employ"]),
              (2, ["money", "financ", "income", "salary", "saving", "wealth"]),
              (8, ["invest", "stock", "lotter", "windfall", "health", "body", "illness"]),
              (3, ["study", "studies", "exam", "school", "learning"]),
              (4, ["family", "parents", "house", "home"]),
              (9, ["travel", "trip", "abroad", "visa"]),
              (11, ["friend", "social"]),
              (1, ["mood", "feeling", "emotion"])],
        .es: [(5, ["amor", "romanc", "ligar", "novio", "novia"]),
              (7, ["pareja", "matrimonio", "casarme", "casar", "espos", "relaci"]),
              (10, ["carrera", "trabaj", "emple", "jefe", "negocio", "ascenso", "profesi"]),
              (2, ["dinero", "finanz", "ingres", "sueldo", "salario", "ahorr"]),
              (8, ["inver", "lotería", "loteria", "salud", "cuerpo", "enferm"]),
              (3, ["estud", "examen", "aprend", "escuela"]),
              (4, ["famil", "casa", "padres", "mudanza"]),
              (9, ["viaj", "extranjero", "visa"]),
              (11, ["amig", "social"]),
              (1, ["emocion", "ánimo", "animo", "sentimiento"])],
        .it: [(5, ["amor", "romanticismo", "flirt", "fidanzat"]),
              (7, ["coppia", "matrimonio", "spos", "partner", "relazion", "marito", "moglie"]),
              (10, ["carriera", "lavor", "capo", "promozion", "business", "attività"]),
              (2, ["denaro", "sold", "finanz", "stipendio", "risparm", "guadagn"]),
              (8, ["invest", "lotteria", "salute", "corpo", "malatt"]),
              (3, ["stud", "esame", "impar", "scuola"]),
              (4, ["famigli", "casa", "genitori", "trasloc"]),
              (9, ["viagg", "estero", "visto"]),
              (11, ["amic", "social"]),
              (1, ["emozion", "umore", "sentiment"])],
    ]

    static func has(_ s: String, _ keys: [String]) -> Bool { keys.contains { s.contains($0) } }

    static func years(_ s: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: #"(?<!\d)(19|20)\d{2}(?!\d)"#),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r = Range(m.range, in: s) else { return nil }
        return Int(s[r])
    }

    public static func parse(_ raw: String, L: Lang, now: Date) -> Parsed? {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month], from: now)
        let ty = c.year!, tm = c.month!
        var palace: Int?
        var y = ty
        var m: Int? = tm

        if L == .zh {
            let text = raw.replacingOccurrences(of: " ", with: "")
            // 「你的工作是什麼」問的是 AI 自己；「你覺得我適合什麼工作」問的是使用者
            if text.hasPrefix("你") && !["你覺得", "你認為", "你看"].contains(where: { text.hasPrefix($0) }) { return nil }
            let personalOrTime = has(text, ["我", "今", "明", "這", "本月", "下個", "去年", "後年", "最近"])
            if (has(text, FortuneRouter.knowledgeMarkers) && !personalOrTime) || has(text, ["八字", "紫微", "合盤", "合不合", "配不配"]) { return nil }
            let ask = has(text, ["運", "如何", "怎麼樣", "怎樣", "好不好", "順不順", "順利", "會不會", "有沒有", "能不能", "適合",
                                 "機會", "走向", "趨勢", "看看", "看一下", "幫我看", "算算", "嗎", "？", "?", "怎麼"])
            guard ask else { return nil }
            // 依出現順序收集所有主題
            var found: [(Int, String.Index)] = []
            for (p, words) in zhTopics {
                let idx = words.compactMap { text.range(of: $0)?.lowerBound }.min()
                if let idx, !found.contains(where: { $0.0 == p }) { found.append((p, idx)) }
            }
            found.sort { $0.1 < $1.1 }
            palace = found.first?.0
            guard let p = palace else { return nil }
            let all = found.map(\.0)
            if let yy = years(text), text.contains("年") { y = yy; m = nil }
            else if text.contains("後年") { y = ty + 2; m = nil }
            else if text.contains("明年") { y = ty + 1; m = nil }
            else if text.contains("去年") { y = ty - 1; m = nil }
            else if text.contains("下個月") { m = tm % 12 + 1; if tm == 12 { y = ty + 1 } }
            else if text.contains("上個月") { m = (tm + 10) % 12 + 1; if tm == 1 { y = ty - 1 } }
            var r = Parsed(palace: p, y: y, m: m)
            r.palaces = all
            return r
        }

        let text = raw.lowercased()
        let words = text.split { !($0.isLetter || $0 == "'") }.map(String.init)
        guard let table = foreignTopics[L] else { return nil }
        let know = ["what is", "what's", "qué es", "que es", "cos'è", "cosa è", "meaning of", "significa"]
        let fortuneish = ["luck", "fortune", "outlook", "forecast", "prospect", "reading", "suerte", "perspectiv", "lectura", "panorama",
                          "fortuna", "prospettiv", "lettura", "andrà", "sarà", "será", "how", "cómo", "como", "come", "will", "should",
                          "this year", "next year", "this month", "este año", "este mes", "quest'anno", "questo mese"]
        if has(text, know) && !has(text, ["luck", "fortune", "suerte", "fortuna"]) { return nil }
        let ask = text.contains("?") || text.contains("¿") || has(text, fortuneish)
        guard ask else { return nil }
        for (p, stems) in table where stems.contains(where: { st in words.contains { $0.hasPrefix(st) } }) { palace = p; break }
        guard let p = palace else { return nil }
        if let yy = years(text) { y = yy; m = nil }
        else if has(text, ["next year", "el año que viene", "próximo año", "proximo año", "año próximo", "l'anno prossimo", "prossimo anno"]) { y = ty + 1; m = nil }
        else if has(text, ["last year", "año pasado", "anno scorso"]) { y = ty - 1; m = nil }
        else if has(text, ["next month", "mes que viene", "próximo mes", "proximo mes", "prossimo mese"]) { m = tm % 12 + 1; if tm == 12 { y = ty + 1 } }
        return Parsed(palace: p, y: y, m: m)
    }

    // MARK: - 追問（為什麼／怎麼辦／再多說）

    public static func followKind(_ raw: String, L: Lang) -> Reader.FollowKind? {
        let text = raw.lowercased().replacingOccurrences(of: " ", with: L == .zh ? "" : " ")
        // 追問都很短；長句多半是在講自己的事，不是在問上一則解讀
        guard L == .zh ? text.count <= 12 : text.split(separator: " ").count <= 6 else { return nil }
        // 帶了新的時間（「明天要注意什麼」「今年呢」）就是新問題，不是追問上一則
        let timeWords = ["今天", "今日", "今晚", "晚上", "明天", "後天", "昨天", "這週", "下週", "這個月", "下個月", "今年", "明年", "去年",
                         "大運", "月", "年", "today", "tonight", "tomorrow", "week", "month", "year", "hoy", "mañana", "semana", "mes", "año",
                         "oggi", "domani", "stasera", "settimana", "mese", "anno"]
        if timeWords.contains(where: { text.contains($0) }) { return nil }
        let why: [String], advice: [String], more: [String]
        switch L {
        case .zh:
            why = ["為什麼", "怎麼判", "依據", "怎麼算", "怎麼來的", "為何"]
            advice = ["怎麼辦", "建議", "該怎麼做", "要注意什麼", "怎麼做", "怎麼應對", "要怎麼"]
            more = ["詳細", "再多說", "多說一點", "細節", "展開", "然後呢", "還有呢", "再說"]
        case .en:
            why = ["why", "how did you", "how is that", "basis", "how do you calculate", "explain that"]
            advice = ["what should i do", "advice", "any tips", "suggest", "what do i do", "how should i"]
            more = ["tell me more", "more detail", "details", "go on", "elaborate", "and then", "anything else"]
        case .es:
            why = ["por qué", "por que", "cómo lo calculas", "como lo calculas", "explica eso"]
            advice = ["qué debo hacer", "que debo hacer", "consejo", "qué hago", "que hago", "sugieres"]
            more = ["dime más", "dime mas", "más detalles", "mas detalles", "cuéntame más", "sigue", "algo más"]
        case .it:
            why = ["perché", "perche", "come lo calcoli", "spiega questo"]
            advice = ["cosa devo fare", "consiglio", "che faccio", "suggerisci", "cosa faccio"]
            more = ["dimmi di più", "dimmi di piu", "più dettagli", "piu dettagli", "raccontami di più", "vai avanti", "altro"]
        }
        if has(text, why) { return .why }
        if has(text, advice) { return .advice }
        if has(text, more) { return .more }
        return nil
    }
}
