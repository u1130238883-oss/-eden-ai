import Foundation

/// 九型人格的深度問答（Hollow 每一型的七個段落）與「幫別人看」。
public enum Persona {
    /// 七個段落：0 形成背景、1 外在表現、2 安定成長時、3 壓力防衛時、4 健康、5 一般、6 不健康
    public enum Ask: Equatable {
        case sections([Int], title: String)
        case career
        case relationship
    }

    static func has(_ s: String, _ k: [String]) -> Bool { k.contains { s.contains($0) } }

    static let zhRules: [([String], [Int], String)] = [
        (["壓力大", "壓力很大", "有壓力", "壓力下", "焦慮的時候", "低潮", "崩潰", "防衛", "狀態不好", "心情不好的時候", "受挫"], [3, 6], "壓力和自我防衛時"),
        (["成長", "進步", "提升", "變更好", "安定的時候", "最好的狀態", "發揮潛力", "怎麼變好"], [2, 4], "安定和人格提升時"),
        (["優點", "長處", "強項", "天賦", "厲害的地方", "好的地方"], [4], "健康的特點（優點）"),
        (["缺點", "弱點", "短處", "壞習慣", "陰暗面", "不好的地方", "要改的", "盲點"], [5, 6], "需要留意的特點"),
        (["小時候", "童年", "成長背景", "為什麼會這樣", "形成", "原生"], [0], "形成性格的背景"),
        (["別人眼中", "給人的感覺", "給人什麼感覺", "外在", "表現", "別人怎麼看我", "第一印象"], [1], "外在表現"),
        (["平常", "一般的時候", "日常的我"], [5], "一般的特點"),
    ]

    public static func parse(_ raw: String, L: Lang) -> Ask? {
        let text = L == .zh ? raw.replacingOccurrences(of: " ", with: "") : raw.lowercased()
        if L == .zh {
            guard text.contains("我") || has(text, ["型", "九型"]) else { return nil }
            if text.hasPrefix("你") && !has(text, ["你覺得", "你看"]) { return nil }
            if has(text, ["適合什麼工作", "適合做什麼工作", "適合的工作", "適合什麼職業", "適合什麼行業", "職業方向", "適合做什麼", "適合走什麼路"]) && !has(text, ["今天", "明天", "今晚"]) { return .career }
            if has(text, ["適合什麼樣的人", "適合怎樣的人", "適合什麼對象", "理想型", "跟什麼人合", "談戀愛的樣子", "戀愛中的我", "感情中的我", "在感情裡"]) { return .relationship }
            // 需要是在問自己的性格

            if has(text, ["運", "今年", "明年", "這個月", "今天", "明天", "大運", "流年", "八字", "紫微", "最近", "工作表現"]) { return nil }
            for (keys, secs, title) in zhRules where has(text, keys) { return .sections(secs, title: title) }
            return nil
        }
        let rules: [([String], [Int], String)] = [
            (["under stress", "stressed", "when i'm stressed", "bajo estrés", "estresado", "estresada", "sotto stress", "stressato", "stressata"], [3, 6], "stress"),
            (["grow", "at my best", "improve myself", "crecer", "mejorar", "mi mejor versión", "crescere", "migliorare", "al meglio"], [2, 4], "growth"),
            (["strength", "strong points", "good at", "fortalezas", "virtudes", "puntos fuertes", "punti di forza", "pregi"], [4], "strengths"),
            (["weakness", "flaws", "blind spot", "debilidades", "defectos", "debolezze", "difetti"], [5, 6], "weaknesses"),
            (["childhood", "why am i like", "infancia", "por qué soy así", "infanzia", "perché sono così"], [0], "background"),
            (["how do others see me", "first impression", "cómo me ven", "come mi vedono", "prima impressione"], [1], "outside"),
        ]
        guard has(text, ["my ", " me", "i ", "mis ", "mi ", "soy", "sono", " me "]) || text.hasPrefix("i") else { return nil }
        if has(text, ["what job", "which job", "career suits", "suited for", "qué trabajo", "que trabajo", "trabajo ideal", "che lavoro", "lavoro adatto"]) { return .career }
        for (keys, secs, t) in rules where has(text, keys) { return .sections(secs, title: t) }
        return nil
    }

    public static func answer(_ ask: Ask, D: Destiny, i18n: I18N?, R: Reader) -> ReaderOutput {
        let L = R.L, ty = D.type
        let data = i18n?.d.types[L.rawValue]
        let name = L == .zh ? NT.typeName(ty) : (i18n?.typeName(ty, L) ?? "")
        let secs = data?.sections?[ty - 1] ?? []
        let titles = data?.sectionTitles ?? []
        func block(_ i: Int) -> String {
            guard i < secs.count else { return "" }
            let head = i < titles.count ? titles[i] : ""
            return "【\(head)】\n" + secs[i].map { "• " + $0 }.joined(separator: "\n")
        }
        var text: String
        var card: FortuneCard
        switch ask {
        case .sections(let idx, let title):
            text = R.fmt(R.t("你是第%@型「%@」。依九型的%@來看：", "You're type %@, “%@”. Here's what your type says:", "Eres el tipo %@, «%@». Esto dice tu tipo:",
                             "Sei il tipo %@, «%@». Ecco cosa dice il tuo tipo:"), "\(ty)", name, title)
            if L != .zh { text = R.fmt(R.t("", "You're type %@, “%@”. Here's what your type says:", "Eres el tipo %@, «%@». Esto dice tu tipo:", "Sei il tipo %@, «%@». Ecco cosa dice il tuo tipo:"), "\(ty)", name) }
            text += "\n" + idx.map(block).filter { !$0.isEmpty }.joined(separator: "\n")
            if idx.contains(3) {
                text += "\n" + R.t("好消息是，壓力時的反應是可以被看見、被調整的：先停下來、照顧好身體，再回到自己擅長的事。",
                                   "The good news: stress reactions can be noticed and adjusted — pause, look after your body, then return to what you do well.",
                                   "La buena noticia: las reacciones al estrés se pueden notar y ajustar; para, cuida tu cuerpo y vuelve a lo que haces bien.",
                                   "La buona notizia: le reazioni allo stress si possono notare e correggere; fermati, cura il corpo e torna a ciò che sai fare.")
            }
            card = FortuneCard(title: R.t("九型人格", "Enneagram", "Eneagrama", "Enneagramma"), headline: "\(ty) · \(name)",
                               details: idx.compactMap { $0 < titles.count ? titles[$0] : nil })
        case .career:
            let r10 = D.natal.first { $0.palace == 10 }!
            text = R.fmt(R.t("你是第%@型「%@」，", "You're type %@, “%@”. ", "Eres el tipo %@, «%@». ", "Sei il tipo %@, «%@». "), "\(ty)", name)
            text += R.t("從九型的健康特點看，你的強項是：", "From your type's healthy traits, your strengths are:", "Por los rasgos sanos de tu tipo, tus puntos fuertes son:", "Dai tratti sani del tuo tipo, i tuoi punti di forza sono:")
            if secs.count > 4 { text += "\n" + secs[4].map { "• " + $0 }.joined(separator: "\n") }
            if secs.count > 2 { text += "\n" + R.t("在最好的狀態時：", "At your best: ", "En tu mejor momento: ", "Al tuo meglio: ") + secs[2].joined(separator: " ") }
            text += "\n" + R.fmt(R.t("命盤上，事業看10宮：你本命的10宮判讀「%@」，%@",
                                    "In your chart, career is palace 10: natal reading “%@”. %@",
                                    "En tu carta, la carrera es el palacio 10: lectura natal «%@». %@",
                                    "Nel tuo tema, la carriera è il palazzo 10: lettura natale «%@». %@"),
                                 R.rt(r10.reading), R.verdictLine(r10.reading.verdict, ty))
            text += "\n" + R.t("適合找能發揮上面這些強項的環境；想看時機可以問「我什麼時候會升職」。",
                               "Look for places that use these strengths; for timing, ask “when will I get promoted”.",
                               "Busca entornos que aprovechen estas fortalezas.", "Cerca ambienti che valorizzino questi punti di forza.")
            card = FortuneCard(title: R.t("適合的方向", "Career fit", "Orientación", "Orientamento"), headline: "\(ty) · \(name)", verdict: r10.reading.verdict,
                               details: secs.count > 4 ? secs[4] : [])
        case .relationship:
            let r7 = D.natal.first { $0.palace == 7 }!, r5 = D.natal.first { $0.palace == 5 }!
            text = R.fmt(R.t("你是第%@型「%@」。", "You're type %@, “%@”. ", "Eres el tipo %@, «%@». ", "Sei il tipo %@, «%@». "), "\(ty)", name)
            if secs.count > 1 { text += "\n" + R.t("在關係裡，別人看到的你：", "In relationships, others see:", "En pareja, los demás ven:", "Nelle relazioni, gli altri vedono:") + "\n" + secs[1].prefix(3).map { "• " + $0 }.joined(separator: "\n") }
            text += "\n" + R.fmt(R.t("命盤上，戀愛看5宮（本命「%@」），伴侶看7宮（本命「%@」）。", "Romance is palace 5 (natal “%@”), partner is palace 7 (natal “%@”).",
                                    "El amor es el palacio 5 (natal «%@»), la pareja el 7 (natal «%@»).", "L'amore è il palazzo 5 (natale «%@»), il partner il 7 (natale «%@»)."),
                                 R.rt(r5.reading), R.rt(r7.reading))
            text += "\n" + R.t("想看跟某個人合不合，告訴我對方生日，例如「我跟1999年8月8日的人合不合」。",
                               "To check a match, tell me their birthday.", "Para ver la compatibilidad, dime su cumpleaños.", "Per la compatibilità, dimmi il suo compleanno.")
            card = FortuneCard(title: R.t("感情中的你", "You in love", "Tú en el amor", "Tu in amore"), headline: "\(ty) · \(name)")
        }
        return ReaderOutput(text: R.polish(text), card: card, follow: nil)
    }

    // MARK: - 幫別人看

    static let others: [(String, String)] = [
        ("老公", "你老公"), ("老婆", "你老婆"), ("先生", "你先生"), ("太太", "你太太"), ("男朋友", "你男朋友"), ("女朋友", "你女朋友"),
        ("男友", "你男友"), ("女友", "你女友"), ("另一半", "你的另一半"), ("對象", "你的對象"), ("媽媽", "你媽媽"), ("爸爸", "你爸爸"),
        ("母親", "你母親"), ("父親", "你父親"), ("我媽", "你媽媽"), ("我爸", "你爸爸"), ("兒子", "你兒子"), ("女兒", "你女兒"),
        ("小孩", "你的小孩"), ("孩子", "你的孩子"), ("哥哥", "你哥哥"), ("姐姐", "你姐姐"), ("弟弟", "你弟弟"), ("妹妹", "你妹妹"),
        ("朋友", "你朋友"), ("同事", "你同事"), ("老闆", "你老闆"), ("主管", "你主管"), ("同學", "你同學"), ("暗戀", "你暗戀的人"),
        ("喜歡的人", "你喜歡的人"), ("前任", "你的前任"), ("他", "他"), ("她", "她"),
    ]

    /// 句子裡有別人（老公、媽媽、朋友、他／她）且有日期 → 回傳稱呼
    public static func otherPerson(_ text: String) -> String? {
        guard FortuneRouter.parseDate(text) != nil else { return nil }
        if ["合盤", "合不合", "配不配", "速配"].contains(where: { text.contains($0) }) { return nil }
        for (k, label) in others where text.contains(k) { return label }
        if text.contains("這個人") || text.contains("那個人") { return "這個人" }
        return nil
    }
}
