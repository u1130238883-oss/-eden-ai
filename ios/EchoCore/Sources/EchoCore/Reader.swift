import Foundation

/// 追問用的記憶：上一則解讀的是什麼（「為什麼」「怎麼辦」「再多說一點」）。
public struct Followup {
    public var scope: String          // day / month / year / luck / natal / topic / syn
    public var label: String
    public var row: NTRow?
    public var y: Int
    public var m: Int
    public var d: Int
    public var palace: Int?           // 主題宮位（topic）或日宮（day）
    public var birthday: BirthDay?
}

/// 解讀層輸出：文字、卡片、追問記憶
public struct ReaderOutput {
    public var text: String
    public var card: FortuneCard?
    public var follow: Followup?
}

/// 解讀層：把九型十二宮引擎算出的事實，寫成像真人說的話（繁中／English／Español／Italiano）。
///
/// 全部依 Hollow 的算法取材：本命盤、流日（日宮夜宮）、流月、流年、大運、大運十二方面、引動、合盤。
/// 措辭會依日期與宮位輪替，同一天問同一件事答案一致，不同天說法會變。
public struct Reader {
    public let L: Lang
    let i18n: I18N?

    public init(_ L: Lang, i18n: I18N?) {
        self.L = (L != .zh && i18n == nil) ? .zh : L
        self.i18n = i18n
    }

    var idx: Int { [Lang.zh, .en, .es, .it].firstIndex(of: L)! }

    func t(_ zh: String, _ en: String, _ es: String, _ it: String) -> String { [zh, en, es, it][idx] }

    func pn(_ p: Int) -> String { L == .zh ? NT.label(p) : i18n!.pn(p, L) }
    func kw(_ p: Int, _ n: Int) -> String { L == .zh ? NT.keywords(p, n) : i18n!.kw(p, n, L) }
    func rt(_ r: NTReading) -> String { L == .zh ? r.text : i18n!.rt(r, L) }
    var sep: String { L == .zh ? "、" : ", " }
    func topic(_ p: Int) -> String { Reader.topics[idx][NT.r12(p) - 1] }
    func topicShort(_ p: Int) -> String {
        let s = topic(p)
        for d in ["・", " · "] { if let r = s.range(of: d) { return String(s[..<r.lowerBound]) } }
        return s
    }
    func tip(_ p: Int) -> String { Reader.tips[idx][NT.r12(p) - 1] }

    func cap(_ s: String) -> String { L == .zh ? s : s.prefix(1).uppercased() + s.dropFirst() }

    /// 收尾整理：去掉重複的括號、中文句間空白、外語的全形括號
    public func polish(_ input: String) -> String {
        var s = input
        func rx(_ pattern: String, _ tpl: String) {
            if let re = try? NSRegularExpression(pattern: pattern) {
                s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: tpl)
            }
        }
        if L == .zh {
            rx("「([^」]+)」（\\1）", "「$1」")
            rx("(?<=[\\u4e00-\\u9fff。！？，、；：」）』])[ \\t]+(?=[\\u4e00-\\u9fff「（『])", "")
        } else {
            s = s.replacingOccurrences(of: "（", with: " (").replacingOccurrences(of: "）", with: ")")
            rx("\\(([^()]+)\\) \\(\\1\\)", "($1)")
            rx("[ ]{2,}", " ")
            rx("[ ]+\\)", ")")
        }
        return s
    }

    func mk(text: String, card: FortuneCard?, follow: Followup?) -> ReaderOutput {
        ReaderOutput(text: polish(text), card: card, follow: follow)
    }

    /// 句子之間的空白（中文不需要）
    var sp: String { L == .zh ? "" : " " }

    /// 宮位 + 生活主題；主題和宮名一樣時不重複
    func pnt(_ p: Int) -> String {
        let name = L == .zh ? NT.palaceName(p) : i18n!.pname(p, L)
        let tp = topicShort(p)
        if tp == name || tp.isEmpty { return pn(p) }
        return L == .zh ? "\(pn(p))（\(tp)）" : "\(pn(p)) — \(tp)"
    }

    func pick(_ options: [String], _ seed: Int) -> String { options[((seed % options.count) + options.count) % options.count] }

    /// %@ 依序代入
    func fmt(_ tpl: String, _ args: String...) -> String {
        var out = tpl
        for a in args { if let r = out.range(of: "%@") { out.replaceSubrange(r, with: a) } }
        return out
    }

    func join(_ items: [String]) -> String { items.joined(separator: sep) }

    func verdictLine(_ v: NTVerdict, _ seed: Int) -> String { pick(Reader.verdictLines[idx][v.rawValue], seed) }
    func adviceLine(_ v: NTVerdict, _ seed: Int) -> String { pick(Reader.adviceLines[idx][v.rawValue], seed) }
    func basis(_ v: NTVerdict) -> String { Reader.basisText[idx][v.rawValue] }
    func vname(_ v: NTVerdict) -> String { L == .zh ? v.name : i18n!.d.verdict[L.rawValue]![v.rawValue] }
    func elementName(_ p: Int) -> String { Reader.elements[idx][NTElement.of(p).rawValue] }

    func lblMonth(_ m: Int) -> String { t("\(m)月", "Month \(m)", "Mes \(m)", "Mese \(m)") }
    func lblYear(_ y: Int) -> String { t("\(y)年", "\(y)", "\(y)", "\(y)") }
    func lblLuck(_ s: Int, _ e: Int) -> String {
        t("\(s)–\(e)年的大運", "the \(s)–\(e) luck pillar", "el pilar de suerte \(s)–\(e)", "il pilastro della sorte \(s)–\(e)")
    }

    // MARK: - 流日：白天與夜裡

    public func day(_ D: Destiny, y: Int, m: Int, d: Int, label: String?, focus: Int = 0) -> ReaderOutput {
        let (dp, np) = D.day(month: m, day: d)
        let seed = y * 372 + m * 31 + d
        let head: String
        if let label {
            head = t("\(label)（\(m)月\(d)日）", "\(label.capitalized) (\(m)/\(d))", "\(label.capitalized) (\(d)/\(m))", "\(label.capitalized) (\(d)/\(m))") + "\n"
        } else {
            head = t("今天（\(m)月\(d)日）", "Today (\(m)/\(d))", "Hoy (\(d)/\(m))", "Oggi (\(d)/\(m))") + "\n"
        }
        let dayIntro = pick([
            t("白天走%@——%@這塊比較明顯，關鍵字是%@。", "In the daytime you're in %@ — %@ stands out. Keywords: %@.",
              "De día estás en %@: destaca %@. Palabras clave: %@.", "Di giorno sei in %@: spicca %@. Parole chiave: %@."),
            t("白天的主題落在%@（%@），會特別感覺到：%@。", "Your daytime theme is %@ (%@) — you'll feel it in: %@.",
              "Tu tema de día es %@ (%@); lo notarás en: %@.", "Il tema del giorno è %@ (%@): lo sentirai in: %@."),
            t("日宮在%@，也就是%@的事會浮上檯面：%@。", "The day palace is %@, so %@ comes to the surface: %@.",
              "El palacio del día es %@, así que sale a la luz %@: %@.", "Il palazzo del giorno è %@, quindi emerge %@: %@."),
        ], seed)
        let nightIntro = pick([
            t("夜裡轉到%@——%@，關鍵字是%@。", "At night you move to %@ — %@. Keywords: %@.",
              "De noche pasas a %@: %@. Palabras clave: %@.", "Di notte passi a %@: %@. Parole chiave: %@."),
            t("到了晚上換成%@（%@），留意：%@。", "By evening it's %@ (%@) — watch for: %@.",
              "Al anochecer es %@ (%@); atento a: %@.", "Verso sera è %@ (%@): fai attenzione a: %@."),
            t("夜宮走%@，%@方面的心情會比較突出：%@。", "The night palace is %@; %@ feelings run stronger: %@.",
              "El palacio de la noche es %@; los sentimientos de %@ se notan más: %@.", "Il palazzo della notte è %@; i sentimenti di %@ si sentono di più: %@."),
        ], seed + 1)
        var text = head
        switch focus {
        case 2:   // 只問晚上：夜宮講詳細，白天一句帶過
            text = (label.map { t("\($0)晚上（\(m)月\(d)日）", "\($0.capitalized) night (\(m)/\(d))", "\($0.capitalized) por la noche (\(d)/\(m))", "\($0.capitalized) sera (\(d)/\(m))") }
                    ?? t("今天晚上（\(m)月\(d)日）", "Tonight (\(m)/\(d))", "Esta noche (\(d)/\(m))", "Stasera (\(d)/\(m))")) + "\n"
            text += fmt(t("晚上走的是夜宮%@（%@）。這一宮的關鍵字：%@。", "Tonight your night palace is %@ (%@). Its keywords: %@.",
                          "Esta noche tu palacio de la noche es %@ (%@). Sus palabras clave: %@.", "Stasera il tuo palazzo della notte è %@ (%@). Parole chiave: %@."),
                        pn(np), topicShort(np), kw(np, 6)) + "\n" + tip(np)
            text += "\n" + fmt(t("（白天走的是%@，到了晚上重心就轉到%@了。）", "(Your daytime palace was %@; at night the focus shifts to %@.)",
                                 "(De día era %@; de noche el foco pasa a %@.)", "(Di giorno era %@; di notte il centro passa a %@.)"), pn(dp), topicShort(np))
        case 1:   // 只問白天
            text += fmt(t("白天走的是日宮%@（%@）。這一宮的關鍵字：%@。", "Your daytime palace is %@ (%@). Its keywords: %@.",
                          "Tu palacio de día es %@ (%@). Sus palabras clave: %@.", "Il tuo palazzo di giorno è %@ (%@). Parole chiave: %@."),
                        pn(dp), topicShort(dp), kw(dp, 6)) + "\n" + tip(dp)
            text += "\n" + fmt(t("（晚上會轉到%@。）", "(At night it shifts to %@.)", "(De noche pasa a %@.)", "(Di notte passa a %@.)"), pn(np))
        default:
            text += fmt(dayIntro, pn(dp), topicShort(dp), kw(dp, 3)) + sp + tip(dp) + "\n"
            text += fmt(nightIntro, pn(np), topicShort(np), kw(np, 3)) + sp + tip(np)
        }
        // 日宮／夜宮和命宮、流月、流年、大運重疊時，特別點出來
        let life = D.natal[0].palace, yr = D.year(y).palace, mo = D.month(m, year: y).palace, lpp = D.luckPeriod(y).row.palace
        var echoes: [String] = []
        for (name, palace) in [(t("你的命宮", "your Life Palace", "tu Palacio de Vida", "il tuo Palazzo della Vita"), life),
                               (t("今年的流年", "this year's annual palace", "el palacio anual de este año", "il palazzo annuale di quest'anno"), yr),
                               (t("這個月的流月", "this month's monthly palace", "el palacio mensual de este mes", "il palazzo mensile di questo mese"), mo),
                               (t("目前的大運", "your current luck pillar", "tu pilar de suerte actual", "il tuo pilastro attuale"), lpp)] where palace == dp || palace == np {
            echoes.append(fmt(t("今天的%@和%@落在同一宮，這個主題會特別明顯。", "Today's %@ falls on the same palace as %@, so this theme stands out even more.",
                                "El palacio de %@ de hoy coincide con %@: este tema destaca aún más.", "Il palazzo di %@ di oggi coincide con %@: questo tema risalta ancora di più."),
                              palace == dp ? t("日宮", "day palace", "día", "giorno") : t("夜宮", "night palace", "noche", "notte"), name))
        }
        if !echoes.isEmpty { text += "\n" + echoes.prefix(2).joined(separator: sp) }
        // 總評：今天落在怎樣的月份和年份裡
        let mv = D.month(m, year: y).reading.verdict, yv = D.year(y).reading.verdict
        let mood: String
        switch (mv, yv) {
        case (.good, .good): mood = t("這個月和今年的判讀都順，大方向是助力，今天可以積極一點。", "Both this month and this year read favorably — the tide is with you, so you can be proactive today.", "Este mes y este año son favorables: la corriente te ayuda, hoy puedes ser proactivo.", "Questo mese e quest'anno sono favorevoli: la corrente ti aiuta, oggi puoi essere intraprendente.")
        case (.bad, .bad): mood = t("這個月和今年的判讀都偏辛苦，今天以穩為主，別硬碰硬。", "Both this month and this year read adverse — keep today steady and don't force things.", "Este mes y este año son adversos: hoy ve con calma y no fuerces.", "Questo mese e quest'anno sono avversi: oggi vai con calma e non forzare.")
        case (.good, _): mood = t("這個月的流月是順的，小事可以趁勢推進；大決定還是要看年的走勢。", "This month is favorable, so push small things forward; big decisions still depend on the year.", "Este mes es favorable: avanza en lo pequeño; las grandes decisiones dependen del año.", "Questo mese è favorevole: porta avanti le piccole cose; le grandi decisioni dipendono dall'anno.")
        case (.bad, _): mood = t("這個月的流月偏有阻力，今天的事情多留一點緩衝時間。", "This month has some resistance, so give today's plans a little extra buffer.", "Este mes hay algo de resistencia: deja margen en los planes de hoy.", "Questo mese c'è un po' di resistenza: lascia margine ai piani di oggi.")
        default: mood = t("這個月整體平穩，照自己的節奏走就好。", "This month is steady overall — just keep your own rhythm.", "Este mes es estable: sigue tu ritmo.", "Questo mese è stabile: segui il tuo ritmo.")
        }
        text += "\n" + t("整體：", "Overall: ", "En conjunto: ", "Nel complesso: ") + mood
        if dp == np && focus == 0 {
            text += "\n" + t("白天和夜裡是同一個主題，整天都會被它牽著走。", "Day and night share the same theme, so it colors the whole day.",
                             "Día y noche comparten el mismo tema: teñirá todo el día.", "Giorno e notte condividono lo stesso tema: colorerà l'intera giornata.")
        }
        var det: [String] = []
        det.append(t("白天：", "Day: ", "Día: ", "Giorno: ") + kw(dp, 4))
        det.append(t("夜 ", "Night ", "Noche ", "Notte ") + pn(np) + ": " + kw(np, 3))
        det += contextLines(D, y: y, m: m)
        let cardTitle: String = (label.map { L == .zh ? $0 : $0.capitalized } ?? t("今日", "Today", "Hoy", "Oggi")) + " \(m)/\(d)"
        let card = FortuneCard(title: cardTitle, headline: t("日 ", "Day ", "Día ", "Giorno ") + pn(dp), details: det)
        return mk(text: text, card: card,
                            follow: Followup(scope: "day", label: label ?? "", row: nil, y: y, m: m, d: d, palace: dp, birthday: D.birth))
    }

    // MARK: - 一週

    public func week(_ D: Destiny, from start: Date, next: Bool) -> ReaderOutput {
        let cal = Calendar(identifier: .gregorian)
        let wd = L == .zh ? ["日", "一", "二", "三", "四", "五", "六"] : (L == .en ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                 : (L == .es ? ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"] : ["dom", "lun", "mar", "mer", "gio", "ven", "sab"]))
        var lines: [String] = [], det: [String] = []
        var counts: [Int: Int] = [:]
        let life = D.natal[0].palace
        var lifeDays: [String] = []
        for i in 0..<7 {
            let day = cal.date(byAdding: .day, value: i, to: start)!
            let c = cal.dateComponents([.year, .month, .day, .weekday], from: day)
            let (dp, np) = D.day(month: c.month!, day: c.day!)
            counts[dp, default: 0] += 1
            let label = L == .zh ? "\(c.month!)/\(c.day!)（\(wd[c.weekday! - 1])）" : "\(wd[c.weekday! - 1]) \(c.month!)/\(c.day!)"
            lines.append("• \(label)" + t("：白天", ": day ", ": día ", ": giorno ") + "\(pnt(dp))" + t("，夜裡", "; night ", "; noche ", "; notte ") + "\(pn(np))")
            det.append("\(label) \(pn(dp)) / \(pn(np))")
            if dp == life || np == life { lifeDays.append(label) }
        }
        var text = (next ? t("下週的日宮與夜宮：", "Next week's day and night palaces:", "Palacios de día y de noche de la próxima semana:", "Palazzi di giorno e notte della prossima settimana:")
                         : t("接下來七天的日宮與夜宮：", "Day and night palaces for the next seven days:", "Palacios de día y de noche de los próximos siete días:", "Palazzi di giorno e notte dei prossimi sette giorni:"))
        text += "\n" + lines.joined(separator: "\n")
        let top = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.first
        if let top, top.value >= 2 {
            let p = top.key, n = top.value
            text += "\n" + fmt(t("這幾天白天最常走到%@（%@次），%@", "Your most frequent daytime palace is %@ (%@ times). %@",
                                 "Tu palacio de día más frecuente es %@ (%@ veces). %@", "Il tuo palazzo di giorno più frequente è %@ (%@ volte). %@"),
                               pnt(p), "\(n)", tip(p))
        }
        if !lifeDays.isEmpty {
            text += "\n" + fmt(t("%@會走到你的命宮%@，那幾天跟你本身的課題特別有關。", "On %@ you pass through your Life Palace %@ — those days touch your core themes.",
                                 "El %@ pasas por tu Palacio de Vida %@: esos días tocan tus temas centrales.", "Il %@ passi per il tuo Palazzo della Vita %@: quei giorni toccano i tuoi temi centrali."),
                               join(lifeDays), pn(life))
        }
        text += "\n" + t("想細看哪一天，就問我「明天運勢」或「10月3日運勢」。", "For any single day, ask “tomorrow's fortune” or give me a date.",
                         "Para un día concreto, pregunta «la suerte de mañana» o dime una fecha.", "Per un giorno preciso, chiedi «fortuna di domani» o dammi una data.")
        let card = FortuneCard(title: next ? t("下週", "Next week", "Próxima semana", "Prossima settimana") : t("七天", "7 days", "7 días", "7 giorni"),
                               headline: t("日宮 / 夜宮", "Day / night palace", "Día / noche", "Giorno / notte"), details: det)
        return mk(text: text, card: card, follow: nil)
    }

    // MARK: - 流月／流年／大運

    func rowText(_ label: String, _ row: NTRow, seed: Int, headKey: Int) -> String {
        let r = row.reading
        var s = fmt(pick([
            t("%@落在%@（%@），判讀「%@」——%@。", "%@ falls in %@ (%@), reading “%@” — %@.",
              "%@ cae en %@ (%@), lectura «%@» — %@.", "%@ cade in %@ (%@), lettura «%@» — %@."),
            t("%@走到%@，主題是%@，判讀「%@」（%@）。", "%@ lands on %@, theme: %@, reading “%@” (%@).",
              "%@ llega a %@, tema: %@, lectura «%@» (%@).", "%@ arriva a %@, tema: %@, lettura «%@» (%@)."),
        ], seed), label, pn(row.palace), topicShort(row.palace), rt(r), basis(r.verdict))
        s += "\n" + verdictLine(r.verdict, seed + headKey)
        if L == .zh {
            // 飛宮讀法：因宮的含義飛到本宮，得到果宮的好／正／壞
            s += "\n" + FlowReading.interpret(row)
            s += "\n情緒和處境上，你會感覺\(FlowReading.mood(r))。"
            let ex = FlowReading.extras(r)
            if !ex.isEmpty { s += "\n" + ex }
            s += "\n" + adviceLine(r.verdict, seed + 2 * headKey)
            return s
        }
        if r.result == r.cause {
            s += "\n" + fmt(t("果與因都在%@（%@：%@），力量很集中。", "Effect and cause both sit in %@ (%@: %@) — a very concentrated force.",
                              "Efecto y causa están en %@ (%@: %@): una fuerza muy concentrada.", "Effetto e causa sono in %@ (%@: %@): una forza molto concentrata."),
                            pn(r.result), topicShort(r.result), kw(r.result, 2))
        } else {
            s += "\n" + fmt(t("果落在%@（%@：%@），也就是結果會表現在這一塊；因來自%@（%@：%@），是背後推動的原因。",
                              "The effect lands in %@ (%@: %@) — that's where results show; the cause comes from %@ (%@: %@) — what's driving it.",
                              "El efecto cae en %@ (%@: %@): ahí se ven los resultados; la causa viene de %@ (%@: %@): lo que lo impulsa.",
                              "L'effetto cade in %@ (%@: %@): lì si vedono i risultati; la causa viene da %@ (%@: %@): ciò che lo muove."),
                            pn(r.result), topicShort(r.result), kw(r.result, 2), pn(r.cause), topicShort(r.cause), kw(r.cause, 2))
        }
        // 這一宮在這個判讀下的具體表現
        s += "\n" + fmt(t("在%@「%@」的時候：", "With %@ reading “%@”: ", "Con %@ en «%@»: ", "Con %@ in «%@»: "), pn(row.palace), vname(r.verdict))
            + PalaceLore.text(row.palace, r.verdict, L)
        s += "\n" + adviceLine(r.verdict, seed + 2 * headKey)
        return s
    }

    func rowCard(_ title: String, _ row: NTRow) -> FortuneCard {
        let r = row.reading
        var det: [String] = []
        det.append(t("判讀 ", "Reading ", "Lectura ", "Lettura ") + rt(r))
        det.append(t("果 ", "Effect ", "Efecto ", "Effetto ") + pn(r.result) + ": " + kw(r.result, 2))
        det.append(t("因 ", "Cause ", "Causa ", "Causa ") + pn(r.cause) + ": " + kw(r.cause, 2))
        return FortuneCard(title: title, headline: pn(row.palace), verdict: r.verdict, details: det)
    }

    public func month(_ D: Destiny, y: Int, m: Int) -> ReaderOutput {
        let row = D.month(m, year: y)
        let label = t("\(y)年\(m)月（流月）", "\(lblMonth(m)) \(y) (monthly)", "\(lblMonth(m)) de \(y) (mensual)", "\(lblMonth(m)) \(y) (mensile)")
        let text = rowText(label, row, seed: y * 13 + m, headKey: 3)
        return mk(text: text, card: rowCard(t("流月 ", "Monthly ", "Mensual ", "Mensile ") + "\(y)/\(m)", row),
                            follow: Followup(scope: "month", label: label, row: row, y: y, m: m, d: 1, palace: nil, birthday: D.birth))
    }

    public func year(_ D: Destiny, y: Int) -> ReaderOutput {
        let row = D.year(y)
        let label = t("\(y)年（流年）", "\(y) (annual)", "\(y) (anual)", "\(y) (annuale)")
        var text = rowText(label, row, seed: y * 7, headKey: 5)
        var card = rowCard(t("流年 ", "Annual ", "Anual ", "Annuale ") + "\(y)", row)
        let trig = D.triggeredAspects(y)
        if !trig.isEmpty && L == .zh {
            text += "\n\n今年流年在\(row.palace)宮，會引動大運裡果或因是\(row.palace)的方面："
            for a in trig {
                text += "\n• 第\(a.palace)方面 \(NT.label(a.palace))「\(a.reading.text)」：" + FlowReading.interpret(a)
            }
            text += "\n這些方面今年特別有感。"
            card.details.append("引動大運：" + trig.map { "\($0.palace)宮\($0.reading.text)" }.joined(separator: "、"))
        } else if !trig.isEmpty {
            let items = trig.prefix(3).map { "\(pnt($0.palace))" }
            text += "\n" + fmt(t("這一年還會引動大運的%@，這些方面今年特別有感。", "This year also triggers %@ of your luck pillar — you'll feel those areas more.",
                                 "Este año también activa %@ de tu pilar de suerte: notarás más esas áreas.",
                                 "Quest'anno attiva anche %@ del tuo pilastro della sorte: sentirai di più quelle aree."), join(items))
            card.details.append(t("引動大運：", "Triggers: ", "Activa: ", "Attiva: ") + join(trig.map { pn($0.palace) }))
        }
        return mk(text: text, card: card,
                            follow: Followup(scope: "year", label: label, row: row, y: y, m: 1, d: 1, palace: nil, birthday: D.birth))
    }

    public func luck(_ D: Destiny, y: Int, aspects: Bool = false) -> ReaderOutput {
        let lp = D.luckPeriod(y)
        let label = t("\(lp.start)–\(lp.end)年的大運", "the \(lp.start)–\(lp.end) luck pillar", "el pilar de suerte \(lp.start)–\(lp.end)",
                      "il pilastro della sorte \(lp.start)–\(lp.end)")
        var text = rowText(cap(label), lp.row, seed: lp.start * 3, headKey: 7)
        var card = rowCard(t("大運 ", "Luck Pillar ", "Pilar de Suerte ", "Pilastro della Sorte ") + "\(lp.start)–\(lp.end)", lp.row)
        let natal = D.triggeredNatal(y)
        if !natal.isEmpty && L == .zh {
            text += "\n\n大運在\(lp.row.palace)宮，會引動本命裡果或因是\(lp.row.palace)的宮位（這十年一直會感覺到）："
            for r in natal {
                text += "\n• \(NT.label(r.palace))「\(r.reading.text)」：" + FlowReading.interpret(r)
            }
            card.details.append("引動本命：" + natal.map { "\($0.palace)宮\($0.reading.text)" }.joined(separator: "、"))
        } else if !natal.isEmpty {
            text += "\n" + fmt(t("這一段大運會牽動你本命的%@。", "This pillar stirs your natal %@.", "Este pilar mueve tus %@ natales.",
                                 "Questo pilastro smuove i tuoi %@ natali."), join(natal.prefix(3).map { "\(pnt($0.palace))" }))
            card.details.append(t("引動本命宮：", "Triggers natal: ", "Activa natal: ", "Attiva natale: ") + join(natal.map { pn($0.palace) }))
        }
        if aspects {
            text += "\n\n" + t("這十年的十二個方面：", "The twelve aspects of this decade:", "Los doce aspectos de esta década:",
                              "I dodici aspetti di questo decennio:")
            for a in D.luckAspects(y) {
                text += "\n" + "• \(pnt(a.palace))\(sp)\(rt(a.reading))" + (L == .zh ? "：" + FlowReading.brief(palace: a.palace, reading: a.reading) : "")
            }
            card.details += D.luckAspects(y).map { "\(pn($0.palace)) \(rt($0.reading))" }
        }
        return mk(text: text, card: card,
                            follow: Followup(scope: "luck", label: label, row: lp.row, y: y, m: 1, d: 1, palace: nil, birthday: D.birth))
    }

    // MARK: - 本命

    public func natal(_ D: Destiny) -> ReaderOutput {
        let r0 = D.natal[0], ty = D.type
        let nameT = L == .zh ? NT.typeName(ty) : i18n!.typeName(ty, L)
        let tag = L == .zh ? NT.typeTagline(ty) : i18n!.tagline(ty, L)
        var text = fmt(t("你的命宮在%@（%@），本命判讀「%@」——%@。命宮關鍵字：%@。",
                         "Your Life Palace is %@ (%@), natal reading “%@” — %@. Life Palace keywords: %@.",
                         "Tu Palacio de Vida es %@ (%@), lectura natal «%@» — %@. Palabras clave: %@.",
                         "Il tuo Palazzo della Vita è %@ (%@), lettura natale «%@» — %@. Parole chiave: %@."),
                       pn(r0.palace), topicShort(r0.palace), rt(r0.reading), basis(r0.reading.verdict), kw(r0.palace, 4))
        text += "\n" + fmt(t("九型是第%@型「%@」：%@。", "Your type is %@, “%@”: %@.", "Tu tipo es el %@, «%@»: %@.", "Il tuo tipo è il %@, «%@»: %@."),
                           "\(ty)", nameT, tag)
        if let sum = i18n?.d.types[L.rawValue]?.summaries?[ty - 1] {
            let stops: [Character] = L == .zh ? ["。"] : ["."]
            var parts: [String] = [], cur = ""
            for ch in sum {
                cur.append(ch)
                if stops.contains(ch) { parts.append(cur); cur = "" }
                if parts.count == 2 { break }
            }
            if !parts.isEmpty { text += "\n" + parts.joined(separator: L == .zh ? "" : " ") }
        }
        let good = D.natal.filter { $0.reading.verdict == .good }.map { topicShort($0.palace) }
        let bad = D.natal.filter { $0.reading.verdict == .bad }.map { topicShort($0.palace) }
        if !good.isEmpty {
            text += "\n" + fmt(t("十二宮裡比較順的方面：%@。", "Areas that flow more easily in your chart: %@.", "Áreas que fluyen mejor en tu carta: %@.",
                                 "Aree che scorrono meglio nel tuo tema: %@."), join(good))
        }
        if !bad.isEmpty {
            text += "\n" + fmt(t("需要多留意的方面：%@。", "Areas that need extra care: %@.", "Áreas que piden más cuidado: %@.",
                                 "Aree che chiedono più cura: %@."), join(bad))
        }
        let cardHead = t("命宮 ", "Life Palace ", "Palacio de Vida ", "Palazzo della Vita ") + pn(r0.palace)
        let card = FortuneCard(title: t("本命盤", "Natal chart", "Carta natal", "Tema natale"), headline: cardHead,
                               verdict: r0.reading.verdict, details: D.natal.map { "\(pn($0.palace)) \(rt($0.reading))" })
        return mk(text: text, card: card,
                            follow: Followup(scope: "natal", label: "", row: r0, y: 0, m: 0, d: 0, palace: r0.palace, birthday: D.birth))
    }

    // MARK: - 九型

    public func personality(_ D: Destiny) -> ReaderOutput {
        let ty = D.type
        let nameT = L == .zh ? NT.typeName(ty) : i18n!.typeName(ty, L)
        let tag = L == .zh ? NT.typeTagline(ty) : i18n!.tagline(ty, L)
        var text = fmt(t("你是第%@型「%@」：%@。", "You're type %@, “%@”: %@.", "Eres el tipo %@, «%@»: %@.", "Sei il tipo %@, «%@»: %@."), "\(ty)", nameT, tag)
        if let sum = i18n?.d.types[L.rawValue]?.summaries?[ty - 1] { text += "\n" + sum }
        text += "\n" + fmt(t("你的靈數是%@，命宮在%@（%@）。", "Your life number is %@ and your Life Palace is %@ (%@).",
                              "Tu número de vida es %@ y tu Palacio de Vida es %@ (%@).", "Il tuo numero di vita è %@ e il tuo Palazzo della Vita è %@ (%@)."),
                            "\(D.lifeNumber)", pn(D.natal[0].palace), topicShort(D.natal[0].palace))
        let card = FortuneCard(title: t("九型人格", "Enneagram", "Eneagrama", "Enneagramma"), headline: "\(ty) · " + nameT, details: [tag])
        return mk(text: text, card: card,
                            follow: Followup(scope: "natal", label: "", row: D.natal[0], y: 0, m: 0, d: 0, palace: D.natal[0].palace, birthday: D.birth))
    }

    // MARK: - 合盤

    public func synastry(_ D: Destiny, other: BirthDay) -> ReaderOutput {
        let ch = D.synastry(with: Destiny(other))
        let g = ch.filter { $0.reading.verdict == .good }, n = ch.filter { $0.reading.verdict == .neutral }, b = ch.filter { $0.reading.verdict == .bad }
        let p = ch[0].palace
        var text = fmt(t("你們的合盤命宮在%@（%@），重點是%@。十二宮裡好%@、正%@、壞%@。",
                         "Your shared Life Palace is %@ (%@), centered on %@. Across the twelve palaces: %@ favorable, %@ aligned, %@ adverse.",
                         "Vuestro Palacio de Vida compartido es %@ (%@), centrado en %@. En los doce palacios: %@ favorables, %@ neutros, %@ adversos.",
                         "Il vostro Palazzo della Vita condiviso è %@ (%@), incentrato su %@. Nei dodici palazzi: %@ favorevoli, %@ neutri, %@ avversi."),
                       pn(p), topicShort(p), kw(p, 3), "\(g.count)", "\(n.count)", "\(b.count)")
        text += "\n" + (g.count > b.count
            ? t("好的比壞的多，整體合拍！", "More favorable than adverse — a good match!", "Más favorables que adversos: ¡buena compatibilidad!", "Più favorevoli che avversi: buona intesa!")
            : g.count < b.count
            ? t("壞的比較多，相處需要多一點耐心和磨合。", "More adverse than favorable — it takes patience.", "Más adversos que favorables: requiere paciencia.", "Più avversi che favorevoli: serve pazienza.")
            : t("好壞參半，看你們怎麼經營。", "Evenly balanced — it depends on you both.", "Equilibrado: depende de ambos.", "In equilibrio: dipende da entrambi."))
        if !g.isEmpty {
            text += "\n" + fmt(t("最合拍的面向：%@。", "Where you click most: %@.", "Donde mejor encajáis: %@.", "Dove siete più in sintonia: %@."),
                               join(g.prefix(3).map { topicShort($0.palace) }))
        }
        if !b.isEmpty {
            text += "\n" + fmt(t("需要磨合的面向：%@。", "Where you need to adjust: %@.", "Donde hay que ajustar: %@.", "Dove serve adattarsi: %@."),
                               join(b.prefix(3).map { topicShort($0.palace) }))
        }
        // 關係裡最重要的幾宮：戀愛 5、伴侶 7、家庭 4、錢 2、溝通 3
        if L == .zh {
            text += "\n\n關係裡的關鍵宮位："
            for key in [5, 7, 4, 2, 3] {
                if let r = ch.first(where: { $0.palace == key }) {
                    text += "\n• \(pnt(key))「\(r.reading.text)」：" + PalaceLore.text(key, r.reading.verdict, .zh)
                }
            }
            let D2 = Destiny(other)
            text += "\n\n九型組合：你是第\(D.type)型「\(NT.typeName(D.type))」（\(NT.typeTagline(D.type))），對方是第\(D2.type)型「\(NT.typeName(D2.type))」（\(NT.typeTagline(D2.type))）。"
            text += D.type == D2.type ? "同一型的人很懂彼此，但也容易放大同樣的缺點。" : "不同型的人能互補，關鍵是理解對方在意的東西和你不一樣。"
            let y = Calendar(identifier: .gregorian).component(.year, from: Date())
            let yr = D2.year(y)
            text += "\n對方今年的流年在\(NT.label(yr.palace))「\(yr.reading.text)」，相處時可以體諒他這一年的課題：\(tip(yr.palace))"
        }
        let v: NTVerdict = g.count > b.count ? .good : (g.count < b.count ? .bad : .neutral)
        var det: [String] = []
        var summary = t("好 ", "Good ", "Buenos ", "Buoni ") + "\(g.count)  "
        summary += t("正 ", "Even ", "Neutros ", "Neutri ") + "\(n.count)  "
        summary += t("壞 ", "Bad ", "Malos ", "Cattivi ") + "\(b.count)"
        det.append(summary)
        det += ch.map { "\(pn($0.palace)) \(rt($0.reading))" }
        let cardTitle = t("合盤 × ", "Synastry × ", "Sinastría × ", "Sinastria × ") + "\(other.year)-\(other.month)-\(other.day)"
        let cardHead = t("合盤命宮 ", "Shared Life Palace ", "Palacio de Vida compartido ", "Palazzo della Vita condiviso ") + pn(p)
        let card = FortuneCard(title: cardTitle, headline: cardHead, verdict: v, details: det)
        return mk(text: text, card: card, follow: nil)
    }

    // MARK: - 主題：感情、事業、財運……

    /// 依 Hollow 的算法回答「我今年感情運如何」：
    /// 本命第 p 宮 + 這十年的第 p 方面（大運十二方面）+ 流年是否引動 + 流月是否牽動。
    static func vword(_ v: NTVerdict) -> String { ["好", "中性", "壞"][v.rawValue] }

    /// 開頭先說清楚「這個問題看哪幾宮、各代表什麼」
    static func topicIntro(_ ps: [Int]) -> String {
        let set = Set(ps)
        var parts: [String] = []
        if set.isSuperset(of: [5, 7]) {
            parts.append("看感情要看5宮和7宮：5宮是戀愛、性生活、吸引力；7宮是負責任的一對一關係、談戀愛、結婚和婚姻。")
        }
        if set.isSuperset(of: [2, 8]) {
            parts.append("看錢財要看2宮和8宮：2宮是我的錢、小一點的錢（薪水、日常收支）；8宮是別人的錢、大一點的錢（投資、借貸、合夥、伴侶或家裡的錢）。")
        }
        for p in ps where !(set.isSuperset(of: [5, 7]) && (p == 5 || p == 7)) && !(set.isSuperset(of: [2, 8]) && (p == 2 || p == 8)) {
            parts.append(Reader.singleIntro[p] ?? "看\(p)宮：\(FlowReading.domain[FlowReading.i(p)])。")
        }
        return parts.joined(separator: "\n")
    }

    static let singleIntro: [Int: String] = [
        2: "看自己的錢看2宮：2宮是我的錢、小一點的錢，薪水、日常收支、吃喝和物質。",
        5: "看戀愛看5宮：5宮是戀愛、性生活、吸引力，也是享樂和被看見。",
        7: "看婚姻和一對一關係看7宮：7宮是負責任的關係、談戀愛、結婚、婚姻和伴侶。",
        8: "看身體健康看8宮：8宮管身體、體力精力和生存壓力，也管別人的錢、大一點的錢。",
        10: "看工作事業看10宮：10宮是工作、事業、名聲地位、成就，也代表長輩和上司。",
        11: "看朋友看11宮：11宮是朋友、群體、網路和變動。",
    ]

    /// 兩宮合看：5宮×7宮（戀愛×婚姻）、2宮×8宮（小錢×大錢）
    static func pairSynthesis(_ v: [Int: NTVerdict]) -> String? {
        var out: [String] = []
        if let a = v[5], let b = v[7] {
            switch (a, b) {
            case (.good, .good): out.append("戀愛和關係兩頭都順：有吸引力、有火花，也走得到穩定的一對一關係。")
            case (.good, .bad): out.append("5宮好7宮壞：容易有吸引力、有曖昧或短暫的戀愛，但要走到負責任的關係、婚姻比較難，關係裡容易拉扯。")
            case (.bad, .good): out.append("5宮壞7宮好：火花和新鮮感少一點，但穩定的一對一關係、承諾是有的，偏向細水長流。")
            case (.bad, .bad): out.append("5宮和7宮都壞：戀愛沒火花，一對一的關係也卡，這段時間先把自己顧好，不要勉強。")
            case (.good, _): out.append("戀愛那一面（5宮）比較好，關係和婚姻（7宮）平平，機會多但不一定定下來。")
            case (_, .good): out.append("關係和婚姻（7宮）比較好，戀愛的火花（5宮）平平，重在穩定。")
            case (.bad, _): out.append("戀愛和性這一面（5宮）比較弱，關係（7宮）平平，要主動創造交流和新鮮感。")
            case (_, .bad): out.append("關係和婚姻（7宮）比較辛苦，戀愛（5宮）平平，重點是別被對方牽著走。")
            default: out.append("戀愛和關係都平平，沒有大起大落。")
            }
        }
        if let a = v[2], let b = v[8] {
            switch (a, b) {
            case (.good, .good): out.append("小錢大錢都有：薪水日常有進帳，大一點的錢或別人的資源也會進來。")
            case (.good, .bad): out.append("2宮好8宮壞：小錢、薪水正常有進帳，但大筆的錢、投資、借貸、合夥要小心，容易損耗。")
            case (.bad, .good): out.append("2宮壞8宮好：日常開銷容易緊、錢留不住，但會有大一點的錢或別人的資源進來。")
            case (.bad, .bad): out.append("2宮和8宮都壞：小錢留不住，大錢也要防損耗，這段時間以守為主，不要冒險投資或借錢給人。")
            case (.good, _): out.append("自己賺的小錢（2宮）比較好，大錢（8宮）平平，穩穩存。")
            case (_, .good): out.append("大錢、別人的錢（8宮）比較有機會，自己的小錢（2宮）平平。")
            case (.bad, _): out.append("自己的小錢（2宮）比較緊，大錢（8宮）平平，先控制開銷。")
            case (_, .bad): out.append("大錢（8宮）要小心，投資借貸別衝動；小錢（2宮）平平。")
            default: out.append("錢財整體平平，收支持平。")
            }
        }
        return out.isEmpty ? nil : "合起來看：" + out.joined(separator: "")
    }

    /// 某一宮在某一年的狀態：流年本身走這宮、或流年引動大運的這一方面
    func yearStatus(_ D: Destiny, palace p: Int, year yy: Int) -> (text: String, verdict: NTVerdict)? {
        let r = D.year(yy)
        if r.palace == p { return ("流年走\(p)宮「\(r.reading.text)」", r.reading.verdict) }
        if D.triggeredAspects(yy).contains(where: { $0.palace == p }) {
            let a = D.luckAspects(yy)[p - 1]
            return ("流年\(r.palace)宮引動第\(p)方面「\(a.reading.text)」", a.reading.verdict)
        }
        return nil
    }

    /// 中文主題解讀——看盤節奏：
    ///   ① 大運本身是不是走這一宮（好／壞）
    ///   ② 大運有沒有引動本命這一宮（好／壞的引動）
    ///   ③ 大運十二方面的這一方面（好／壞）
    ///   ④ 流年：是不是走這一宮的流年？流年有沒有引動這一方面？
    ///   ⑤ 期限：哪幾年好、哪幾年壞；前後幾段大運的狀態
    ///   ⑥ 綜合
    public func topicZh(_ D: Destiny, palaces ps: [Int], y: Int, m: Int?) -> ReaderOutput {
        let lp = D.luckPeriod(y), yr = D.year(y)
        let luckP = lp.row.palace
        var text = ""
        var conclusions: [(Int, NTRow, Bool)] = []
        var goodSpans: [String] = [], badSpans: [String] = []
        text = Reader.topicIntro(ps)
        for p in ps {
            let name = topicShort(p)
            let natal = D.natal.first { $0.palace == p }!
            let aspect = D.luckAspects(y)[p - 1]
            let aspectRow = NTRow(index: aspect.index, palace: p, triple: aspect.triple, reading: aspect.reading)
            let byLuck = natal.reading.result == luckP || natal.reading.cause == luckP
            text += (text.isEmpty ? "" : "\n\n") + "【\(name) · \(NT.label(p))】"
            text += "\n本命\(p)宮「\(natal.reading.text)」：" + FlowReading.interpret(natal)

            // ① 大運本身
            text += "\n\n① 大運本身（\(lp.start)–\(lp.end)）：走\(NT.label(luckP))「\(lp.row.reading.text)」。"
            if luckP == p {
                text += "這部大運本身就是走\(name)的大運，是\(Reader.vword(lp.row.reading.verdict))的\(name)運：" + FlowReading.interpret(lp.row)
            } else {
                text += "這部大運本身不是走\(name)的大運。"
            }
            // ② 大運引動
            if byLuck {
                text += "\n② 大運引動：有。大運\(luckP)宮引動本命\(p)宮「\(natal.reading.text)」，是\(Reader.vword(natal.reading.verdict))的引動，這\(lp.end - lp.start + 1)年\(name)會一直被觸發。"
            } else {
                text += "\n② 大運引動：沒有（本命\(p)宮的果\(natal.reading.result)、因\(natal.reading.cause)都不是\(luckP)）。"
            }
            // ③ 大運十二方面
            text += "\n③ 大運十二方面的第\(p)方面「\(aspect.reading.text)」，這十年的\(name)是\(Reader.vword(aspect.reading.verdict))的：" + FlowReading.interpret(aspectRow)

            // ④ 流年
            text += "\n④ \(y)年流年在\(NT.label(yr.palace))「\(yr.reading.text)」。"
            if yr.palace == p {
                text += "這一年就是走\(name)的流年，是\(Reader.vword(yr.reading.verdict))的\(name)年：" + FlowReading.interpret(yr)
            } else {
                text += "這一年不是走\(name)的流年；"
                if D.triggeredAspects(y).contains(where: { $0.palace == p }) {
                    text += "但流年有引動大運的第\(p)方面「\(aspect.reading.text)」，是\(Reader.vword(aspect.reading.verdict))的引動，這一年\(name)特別有感。"
                } else {
                    text += "流年也沒有引動\(name)，這一年照大運的狀態走。"
                }
            }
            if let m {
                let mr = D.month(m, year: y)
                if mr.palace == p { text += "這個月（\(m)月）流月也走\(name)「\(mr.reading.text)」。" }
            }

            // ⑤ 期限
            var good: [String] = [], bad: [String] = [], mid: [String] = []
            for yy in y...(y + 11) {
                guard let st = yearStatus(D, palace: p, year: yy) else { continue }
                let item = "\(yy)年（\(st.text)）"
                switch st.verdict { case .good: good.append(item); case .bad: bad.append(item); case .neutral: mid.append(item) }
            }
            text += "\n⑤ 期限："
            var periods: [String] = []
            var yy0 = lp.start
            for _ in 0..<3 {
                let L = D.luckPeriod(yy0)
                let a = D.luckAspects(yy0)[p - 1]
                let trig = natal.reading.result == L.row.palace || natal.reading.cause == L.row.palace
                var desc = "\(L.start)–\(L.end)：\(Reader.vword(a.reading.verdict))（第\(p)方面「\(a.reading.text)」"
                if L.row.palace == p { desc += "，大運本身走\(p)宮" }
                if trig { desc += "，引動本命\(p)宮「\(natal.reading.text)」" }
                desc += "）"
                periods.append(desc)
                if a.reading.verdict == .good { goodSpans.append("\(name) \(L.start)–\(L.end)") }
                if a.reading.verdict == .bad { badSpans.append("\(name) \(L.start)–\(L.end)") }
                yy0 = L.end + 1
            }
            text += "\n• 以大運來看：" + periods.joined(separator: "；")
            text += "\n• 好的年份：" + (good.isEmpty ? "未來十二年流年沒有好的\(name)年" : good.prefix(4).joined(separator: "、"))
            text += "\n• 壞的年份：" + (bad.isEmpty ? "未來十二年流年沒有壞的\(name)年" : bad.prefix(4).joined(separator: "、"))
            if !mid.isEmpty { text += "\n• 中性的年份：" + mid.prefix(3).joined(separator: "、") }
            let months = (1...12).compactMap { mm -> String? in
                let mr = D.month(mm, year: y)
                return mr.palace == p ? "\(mm)月（\(Reader.vword(mr.reading.verdict))，「\(mr.reading.text)」）" : nil
            }
            if !months.isEmpty { text += "\n• \(y)年流月走到\(p)宮的月份：" + months.joined(separator: "、") }
            conclusions.append((p, byLuck ? natal : aspectRow, byLuck))
        }

        // ⑥ 綜合
        text += "\n\n⑥ 綜合來說"
        for (p, row, byLuck) in conclusions {
            let r = row.reading
            text += "\n• \(topicShort(p))：" + (byLuck ? "被大運引動，" : "以大運第\(p)方面來看，")
            text += "\(r.cause)宮的\(FlowReading.cause[FlowReading.i(r.cause)].components(separatedBy: "、").prefix(2).joined(separator: "、"))影響到這裡，結果是\(FlowReading.result[FlowReading.i(r.result)][r.verdict.rawValue])。"
            text += "情緒和處境上，你會感覺\(FlowReading.mood(r))。"
            text += FlowReading.extras(r)
        }
        let vs = Dictionary(conclusions.map { ($0.0, $0.1.reading.verdict) }, uniquingKeysWith: { a, _ in a })
        if let pair = Reader.pairSynthesis(vs) { text += "\n" + pair }
        let lucky = conclusions.filter { $0.2 }
        if lucky.count >= 2 {
            text += "\n這\(lucky.count)件事都是被同一個大運（\(NT.label(luckP))：\(FlowReading.cause[luckP - 1])）引動的，根源都跟「\(topicShort(luckP))」有關。"
        }
        let bad = conclusions.filter { $0.1.reading.verdict == .bad }
        if !bad.isEmpty {
            let fixP = bad[0].1.reading.result
            text += "\n建議：關鍵在\(fixP)宮（\(FlowReading.domain[fixP - 1])），\(tip(fixP))"
        } else {
            text += "\n整體是順的，可以主動一點。"
        }
        if !goodSpans.isEmpty { text += "\n比較好的時期：" + goodSpans.joined(separator: "、") + "。" }
        if !badSpans.isEmpty { text += "\n需要小心的時期：" + badSpans.joined(separator: "、") + "。" }
        text += "\n想知道原因可以問「為什麼」。"

        let card = FortuneCard(title: "主題 · " + ps.map { topicShort($0) }.joined(separator: "＋"),
                               headline: "大運 \(lp.start)–\(lp.end) \(NT.label(luckP))",
                               verdict: bad.isEmpty ? .good : .bad,
                               details: conclusions.map { "\($0.0)宮 \($0.1.reading.text)" + ($0.2 ? "（大運引動）" : "（大運第\($0.0)方面）") }
                                + ["流年 \(y) \(NT.label(yr.palace)) \(yr.reading.text)"])
        let first = conclusions.first!
        return mk(text: text, card: card,
                  follow: Followup(scope: "topic", label: topicShort(first.0), row: first.1, y: y, m: m ?? 1, d: 1, palace: first.0, birthday: D.birth))
    }

    public func topicReading(_ D: Destiny, palace p: Int, y: Int, m: Int?) -> ReaderOutput {
        if L == .zh { return topicZh(D, palaces: [p], y: y, m: m) }
        let natalRow = D.natal.first { $0.palace == p }!
        let aspect = D.luckAspects(y)[p - 1]
        let yearRow = D.year(y)
        let triggered = D.triggeredAspects(y).contains { $0.palace == p }
        let seed = y * 17 + p
        var lines: [String] = []
        lines.append(fmt(t("【%@ · %@】", "[%@ · %@]", "[%@ · %@]", "[%@ · %@]"), topicShort(p), pn(p)))
        lines.append(fmt(t("本命：%@判讀「%@」——%@。%@", "Natal: %@ reads “%@” — %@. %@", "Natal: %@ lee «%@» — %@. %@", "Natale: %@ legge «%@» — %@. %@"),
                         pn(p), rt(natalRow.reading), basis(natalRow.reading.verdict), PalaceLore.text(p, natalRow.reading.verdict, L)))
        let lp = D.luckPeriod(y)
        lines.append(fmt(t("這十年（%@–%@）：這方面是大運的第%@方面，判讀「%@」。%@",
                           "This decade (%@–%@): this is aspect %@ of your luck pillar, reading “%@”. %@",
                           "Esta década (%@–%@): es el aspecto %@ de tu pilar de suerte, lectura «%@». %@",
                           "Questo decennio (%@–%@): è l'aspetto %@ del tuo pilastro della sorte, lettura «%@». %@"),
                         "\(lp.start)", "\(lp.end)", "\(p)", rt(aspect.reading), aspect.reading.verdict == natalRow.reading.verdict
                             ? t("跟本命一樣的判讀，這個課題這十年會一直跟著你。", "Same as your natal reading — this theme stays with you all decade.", "Igual que tu lectura natal: este tema te acompaña toda la década.", "Uguale alla lettura natale: questo tema ti accompagna per tutto il decennio.")
                             : PalaceLore.text(p, aspect.reading.verdict, L)))
        // 流年
        var yearNote: String
        if yearRow.palace == p {
            yearNote = t("今年的流年正好落在這一宮，是這個主題的主場。", "This year's annual palace lands right here — this theme is center stage.",
                         "El palacio anual de este año cae justo aquí: este tema es el protagonista.", "Il palazzo annuale di quest'anno cade proprio qui: questo tema è protagonista.")
        } else if yearRow.reading.result == p || yearRow.reading.cause == p {
            yearNote = t("今年的流年判讀牽動到這一宮（\(yearRow.reading.result == p ? "果" : "因")在這裡）。",
                         "This year's reading touches this palace (\(yearRow.reading.result == p ? "effect" : "cause") is here).",
                         "La lectura de este año toca este palacio (\(yearRow.reading.result == p ? "el efecto" : "la causa") está aquí).",
                         "La lettura di quest'anno tocca questo palazzo (\(yearRow.reading.result == p ? "l'effetto" : "la causa") è qui).")
        } else {
            yearNote = t("今年沒有特別去碰這一宮，走勢以本命和大運為主。", "This year doesn't directly touch this palace, so your natal chart and luck pillar set the tone.",
                         "Este año no toca directamente este palacio; marcan el tono tu carta natal y tu pilar de suerte.",
                         "Quest'anno non tocca direttamente questo palazzo: danno il tono il tema natale e il pilastro della sorte.")
        }
        if triggered {
            yearNote += " " + t("而且流年引動了大運裡的這個方面，今年特別有感。", "Also, the annual palace triggers this aspect of your luck pillar — you'll feel it strongly this year.",
                                "Además, el palacio anual activa este aspecto de tu pilar: lo notarás mucho este año.",
                                "Inoltre il palazzo annuale attiva questo aspetto del pilastro: lo sentirai molto quest'anno.")
        }
        lines.append(fmt(t("%@年：流年在%@，判讀「%@」。", "%@: annual palace %@, reading “%@”.", "%@: palacio anual %@, lectura «%@».", "%@: palazzo annuale %@, lettura «%@»."),
                         "\(y)", pn(yearRow.palace), rt(yearRow.reading)) + " " + yearNote)
        // 流月
        var monthRow: NTRow?
        if let m {
            let mr = D.month(m, year: y)
            monthRow = mr
            var note = t("這個月沒有特別碰到這個主題。", "This month doesn't specifically touch the theme.", "Este mes no toca especialmente el tema.", "Questo mese non tocca in particolare il tema.")
            if mr.palace == p {
                note = t("這個月正好走到這一宮，會有感。", "This month lands right on this palace — you'll notice it.", "Este mes cae justo en este palacio: lo notarás.", "Questo mese cade proprio su questo palazzo: lo noterai.")
            } else if mr.reading.result == p || mr.reading.cause == p {
                note = t("這個月的果或因牽動這一宮，留意相關的事。", "This month's effect or cause involves this palace — watch related matters.",
                         "El efecto o la causa de este mes involucra este palacio: atento a lo relacionado.", "L'effetto o la causa di questo mese coinvolge questo palazzo: attenzione a ciò che ne deriva.")
            }
            lines.append(fmt(t("%@：流月在%@，判讀「%@」。", "%@: monthly palace %@, reading “%@”.", "%@: palacio mensual %@, lectura «%@».", "%@: palazzo mensile %@, lettura «%@»."),
                             lblMonth(m), pn(mr.palace), rt(mr.reading)) + " " + note)
        }
        // 綜合
        let score = [natalRow.reading.verdict, aspect.reading.verdict].map { [1, 0, -1][$0.rawValue] }.reduce(0, +)
            + (triggered ? [1, 0, -1][aspect.reading.verdict.rawValue] : 0)
        let overall: NTVerdict = score > 0 ? .good : (score < 0 ? .bad : .neutral)
        lines.append(fmt(t("綜合來看：%@", "Overall: %@", "En conjunto: %@", "Nel complesso: %@"), adviceLine(overall, seed + 3)))
        lines.append(tip(p))
        var det: [String] = []
        det.append(t("本命 ", "Natal ", "Natal ", "Natale ") + rt(natalRow.reading))
        det.append(t("大運方面 ", "Luck aspect ", "Aspecto de suerte ", "Aspetto di sorte ") + rt(aspect.reading))
        det.append(t("流年 ", "Annual ", "Anual ", "Annuale ") + "\(y) " + pn(yearRow.palace) + " " + rt(yearRow.reading))
        if let mr = monthRow, let mm = m { det.append(lblMonth(mm) + " " + pn(mr.palace) + " " + rt(mr.reading)) }
        let cardTitle = fmt(t("主題 · %@", "Topic · %@", "Tema · %@", "Tema · %@"), topic(p))
        let card = FortuneCard(title: cardTitle, headline: pn(p), verdict: overall, details: det)
        return mk(text: lines.joined(separator: "\n"), card: card,
                            follow: Followup(scope: "topic", label: topic(p), row: aspect, y: y, m: m ?? 1, d: 1, palace: p, birthday: D.birth))
    }

    // MARK: - 追問

    public enum FollowKind { case why, advice, more }

    public func followup(_ kind: FollowKind, _ f: Followup) -> String {
        polish(followupRaw(kind, f))
    }

    func followupRaw(_ kind: FollowKind, _ f: Followup) -> String {
        let seed = f.y * 31 + f.m
        switch kind {
        case .why:
            if L == .zh { return whyZh(f) }
            guard let row = f.row else {
                return t("這個是日宮／夜宮：日宮由你的靈數、月份和日期算出，夜宮則把靈數和當天的數字和化成 1 到 9 宮。",
                         "Day and night palaces come from your life number plus the digits of the month and day; the night palace reduces to palaces 1–9.",
                         "Los palacios de día y noche salen de tu número de vida más los dígitos del mes y el día; el de noche se reduce a los palacios 1–9.",
                         "I palazzi di giorno e notte nascono dal tuo numero di vita più le cifre di mese e giorno; quello notturno si riduce ai palazzi 1–9.")
            }
            let r = row.reading, t3 = row.triple
            var s = f.scope == "topic"
                ? t("以這十年在這個方面的判讀來說：", "For this decade's reading of this area: ", "Sobre la lectura de esta década en esta área: ", "Sulla lettura di questo decennio in quest'area: ") : ""
            s += fmt(t("這一列的年柱是%@（%@），月柱是%@（%@）。", "This row's year pillar is %@ (%@) and its month pillar is %@ (%@).",
                          "El pilar del año de esta fila es %@ (%@) y el del mes es %@ (%@).", "Il pilastro dell'anno di questa riga è %@ (%@) e quello del mese è %@ (%@)."),
                        pn(t3.y), elementName(t3.y), pn(t3.m), elementName(t3.m))
            s += " " + fmt(t("兩者%@，所以判讀是「%@」。", "They %@, so the reading is “%@”.", "Ellos %@, así que la lectura es «%@».", "Loro %@, quindi la lettura è «%@»."),
                           [t("五行同行", "share the same element", "comparten elemento", "condividono l'elemento"),
                            t("相生（有一方生另一方）", "generate each other", "se generan", "si generano"),
                            t("相剋", "control each other", "se dominan", "si dominano")][r.verdict.rawValue], vname(r.verdict))
            s += "\n" + t("果與因是用年柱、月柱各自加上日柱後算出來的兩個宮位：果是結果出現的地方，因是推動它的來源。",
                          "Effect and cause are two palaces computed by adding the day pillar to the year and month pillars: the effect is where it shows, the cause is what drives it.",
                          "Efecto y causa son dos palacios que salen de sumar el pilar del día a los del año y del mes: el efecto es dónde se ve, la causa qué lo impulsa.",
                          "Effetto e causa sono due palazzi ottenuti sommando il pilastro del giorno a quelli di anno e mese: l'effetto è dove si vede, la causa ciò che lo muove.")
            return s
        case .advice:
            if L == .zh, let row = f.row {
                let r = row.reading
                var s = "怎麼做比較好："
                if r.verdict == .bad {
                    s += "\n• 問題的根源在\(NT.label(r.cause))，先從這裡下手：\(FlowReading.remedy[FlowReading.i(r.cause)])。"
                    s += "\n• 結果卡在\(NT.label(r.result))，可以同時補一補：\(FlowReading.remedy[FlowReading.i(r.result)])。"
                } else if r.verdict == .good {
                    s += "\n• 這是順的，力量來自\(NT.label(r.cause))，多用它：\(FlowReading.remedy[FlowReading.i(r.cause)])。"
                    s += "\n• 好的結果會出現在\(NT.label(r.result))，把握住：\(FlowReading.remedy[FlowReading.i(r.result)])。"
                } else {
                    s += "\n• 這是中性的，看你怎麼用\(NT.label(r.cause))：\(FlowReading.remedy[FlowReading.i(r.cause)])。"
                }
                if let p = f.palace, p != r.result && p != r.cause {
                    s += "\n• \(NT.label(p))本身：\(FlowReading.remedy[FlowReading.i(p)])。"
                }
                s += "\n" + adviceLine(r.verdict, seed)
                return s
            }
            if let p = f.palace, f.scope == "day" {
                return tip(p) + sp + adviceLine(.neutral, seed)
            }
            if let p = f.palace, f.scope == "topic", let row = f.row {
                return adviceLine(row.reading.verdict, seed) + "\n" + tip(p)
            }
            guard let row = f.row else {
                return adviceLine(.neutral, seed)
            }
            let r = row.reading
            return adviceLine(r.verdict, seed) + "\n" + tip(r.result) + "\n" + tip(r.cause)
        case .more:
            var ps: [Int] = []
            if let row = f.row { ps = [row.reading.result, row.reading.cause, row.palace] }
            if let p = f.palace { ps.insert(p, at: 0) }
            var seen = Set<Int>(), out: [String] = []
            for p in ps where seen.insert(p).inserted {
                out.append("\(pn(p))（\(topic(p))）：\(kw(p, 8))")
            }
            return out.isEmpty ? adviceLine(.neutral, seed) : out.joined(separator: "\n")
        }
    }

    /// 「為什麼」：不講計算過程，講宮位的含義——因宮的什麼事，飛到哪個領域，得到什麼結果，心裡是什麼感覺
    func whyZh(_ f: Followup) -> String {
        guard let row = f.row else {
            guard let b = f.birthday else { return "因為今天的日宮和夜宮落在不同的宮位，所以白天和晚上關注的事情不一樣。" }
            let (dp, np) = Destiny(b).day(month: f.m, day: f.d)
            var s = "為什麼\(f.m)月\(f.d)日會這樣？\n"
            s += "白天走\(NT.label(dp))，所以白天比較容易碰到\(FlowReading.domain[FlowReading.i(dp)])這一類的事，關鍵字是\(kw(dp, 4))。"
            s += "\n晚上轉到\(NT.label(np))，心思會換到\(FlowReading.domain[FlowReading.i(np)])，關鍵字是\(kw(np, 4))。"
            if dp == np { s += "\n白天和晚上是同一宮，所以整天都被這件事牽著走。" }
            let D = Destiny(b)
            let mo = D.month(f.m, year: f.y), yr = D.year(f.y)
            if dp == mo.palace || np == mo.palace { s += "\n而且這個月的流月也在\(mo.palace)宮，所以這個主題被放大了。" }
            if dp == yr.palace || np == yr.palace { s += "\n今年的流年也在\(yr.palace)宮，這一天跟今年的大主題是連在一起的。" }
            s += "\n這個月整體是「\(mo.reading.text)」：" + FlowReading.interpret(mo)
            return s
        }
        let r = row.reading, p = row.palace
        var s = f.scope == "topic" ? "為什麼這十年的\(topicShort(p))會是「\(r.text)」？\n" : "為什麼是「\(r.text)」？\n"
        let causeWords = FlowReading.cause[FlowReading.i(r.cause)]
        let resultText = FlowReading.result[FlowReading.i(r.result)][r.verdict.rawValue]
        if r.cause == p {
            s += "根源就在\(p)宮自己：\(causeWords)。"
        } else {
            s += "根源在\(NT.label(r.cause))：\(causeWords)。"
            s += "這些東西飛進了\(NT.label(p))，也就是\(FlowReading.domain[FlowReading.i(p)])這一塊。"
        }
        s += "\n結果落在\(NT.label(r.result))，而且是「\(r.verdict.name)」的一面：\(resultText)。"
        s += "\n所以情緒和處境上，你會感覺\(FlowReading.mood(r))。"
        switch r.verdict {
        case .good: s += "\n這是順的：\(NT.palaceName(r.cause))的力量是在幫你，可以順勢用它。"
        case .bad: s += "\n這是卡的：問題不在表面，而是\(NT.palaceName(r.cause))那邊的狀態沒有處理好，先照顧\(r.cause)宮，\(p)宮才會鬆開。"
        case .neutral: s += "\n這是中性的：不會特別好也不會特別壞，看你怎麼用\(NT.palaceName(r.cause))的力量。"
        }
        s += "\n" + tip(r.cause)
        return s
    }

    // MARK: - 詞庫（四語）

    static let elements: [[String]] = [
        ["金", "木", "水", "火", "土"], ["Metal", "Wood", "Water", "Fire", "Earth"],
        ["Metal", "Madera", "Agua", "Fuego", "Tierra"], ["Metallo", "Legno", "Acqua", "Fuoco", "Terra"],
    ]

    static let basisText: [[String]] = [
        ["年月相生", "年月同行", "年月相剋"],
        ["Year and Month generate", "Year and Month share an element", "Year and Month control"],
        ["El Año y el Mes se generan", "El Año y el Mes comparten elemento", "El Año y el Mes se dominan"],
        ["L'Anno e il Mese si generano", "L'Anno e il Mese condividono l'elemento", "L'Anno e il Mese si dominano"],
    ]

    static let topics: [[String]] = [
        ["自己・情緒", "錢財・物質", "溝通・學習", "家庭・安全感", "戀愛・桃花", "忙碌・日常", "婚姻・伴侶", "身體・大錢", "好運・遠行", "事業・地位", "朋友・變動", "內心・隱藏"],
        ["Self · Emotions", "Money · Possessions", "Communication · Learning", "Home · Security", "Romance · Attraction", "Busyness · Routine",
         "Partner · Relationships", "Windfalls · Body", "Luck · Travel", "Career · Status", "Friends · Change", "Inner Self · Hidden"],
        ["Yo · Emociones", "Dinero · Bienes", "Comunicación · Estudio", "Hogar · Seguridad", "Amor · Atracción", "Ajetreo · Rutina",
         "Pareja · Relaciones", "Dinero extra · Cuerpo", "Suerte · Viajes", "Carrera · Estatus", "Amigos · Cambios", "Mundo interior · Oculto"],
        ["Io · Emozioni", "Denaro · Beni", "Comunicazione · Studio", "Casa · Sicurezza", "Amore · Attrazione", "Fatica · Routine",
         "Partner · Relazioni", "Denaro extra · Corpo", "Fortuna · Viaggi", "Carriera · Status", "Amici · Cambiamenti", "Interiorità · Nascosto"],
    ]

    static let tips: [[String]] = [
        ["情緒容易被放大，先照顧好自己。", "跟吃、錢、價值觀有關，花錢前多想一下。", "適合聊天、學習、和身邊的人交換想法。",
         "安全感的議題會浮現，待在熟悉的地方會比較安心。", "容易被注意、也容易心動，適合表現自己。", "事情多、想得多，別把自己耗盡。",
         "心思會放在別人身上，人際與伴侶互動是重點。", "可能有孤獨或煎熬感，也留意身體狀況與意外之財。", "心情偏樂觀，運氣、遠行、文件類的事比較順手。",
         "工作與挑戰擺在眼前，壓力也在，別一個人硬扛。", "朋友與變動多，計畫可能被打亂。", "容易想太多或沉溺，留意情緒與界線。"],
        ["Feelings can get amplified — look after yourself first.", "Food, money and values are in focus — think before you spend.",
         "Great for chatting, learning and swapping ideas with people around you.", "Security issues surface; being somewhere familiar will calm you.",
         "You're likely to be noticed and to feel sparks — good for showing yourself.", "Lots to do and lots on your mind — don't burn yourself out.",
         "Your attention goes to other people; partners and relationships are the focus.", "Loneliness or restlessness may creep in; also watch your body and unexpected money.",
         "Mood leans optimistic; luck, travel and paperwork go smoothly.", "Work and challenges are front and center, with pressure — don't tough it out alone.",
         "Friends and changes abound; plans may get shuffled.", "You may overthink or drift into escapism — mind your emotions and boundaries."],
        ["Las emociones pueden amplificarse: cuídate primero.", "Comida, dinero y valores están en foco: piensa antes de gastar.",
         "Ideal para charlar, aprender e intercambiar ideas con quienes te rodean.", "Salen temas de seguridad; estar en un lugar familiar te calmará.",
         "Es probable que te noten y sientas chispa: bueno para mostrarte.", "Mucho por hacer y mucho en la cabeza: no te agotes.",
         "Tu atención va hacia los demás; pareja y relaciones son el foco.", "Pueden aparecer soledad o inquietud; cuida también el cuerpo y el dinero inesperado.",
         "El ánimo tiende al optimismo; suerte, viajes y papeles fluyen.", "Trabajo y retos en primer plano, con presión: no lo aguantes solo.",
         "Muchos amigos y cambios; los planes pueden reordenarse.", "Puedes darle demasiadas vueltas o evadirte: cuida tus emociones y límites."],
        ["Le emozioni possono amplificarsi: prenditi cura di te per primo.", "Cibo, denaro e valori sono in primo piano: pensa prima di spendere.",
         "Ottimo per chiacchierare, studiare e scambiare idee con chi ti sta intorno.", "Emergono temi di sicurezza; stare in un posto familiare ti calmerà.",
         "È probabile che ti notino e che tu senta scintille: bene per mostrarti.", "Molte cose da fare e molti pensieri: non consumarti.",
         "L'attenzione va agli altri; partner e relazioni sono al centro.", "Possono affiorare solitudine o inquietudine; attenzione anche al corpo e ai soldi inattesi.",
         "L'umore tende all'ottimismo; fortuna, viaggi e documenti scorrono.", "Lavoro e sfide in primo piano, con pressione: non sopportarlo da solo.",
         "Molti amici e cambiamenti; i piani possono rimescolarsi.", "Puoi rimuginare o evadere: cura le emozioni e i tuoi confini."],
    ]

    /// [語言][好/正/壞][說法]
    static let verdictLines: [[[String]]] = [
        [["整體順勢，有助力，可以放心往前推。", "氣是順的，做事容易得到回應。", "有種被推著走的順風感，適合主動一點。"],
         ["持平穩定，照常發揮就好。", "不好不壞，穩紮穩打最適合。", "沒有大起大落，照自己的節奏走。"],
         ["有些阻力，這方面要放慢、多留意。", "容易卡關或耗神，先顧好基本盤。", "會有點拉扯，別硬碰硬，留點餘地。"]],
        [["Things are flowing your way — you can push forward with confidence.", "The tide is with you; efforts tend to get a response.", "It feels like a tailwind — a good time to take the initiative."],
         ["Steady and even — just keep doing what you do.", "Neither good nor bad; steady steps work best.", "No big swings, so stay in your own rhythm."],
         ["There's some resistance here, so slow down and watch this area.", "Things may snag or drain you — cover the basics first.", "Expect a bit of friction; don't push head-on, leave some room."]],
        [["Todo fluye a tu favor: puedes avanzar con confianza.", "La marea está de tu lado; el esfuerzo suele tener respuesta.", "Se siente como viento a favor: buen momento para tomar la iniciativa."],
         ["Estable y parejo: sigue con tu ritmo.", "Ni bueno ni malo; los pasos firmes funcionan mejor.", "Sin grandes altibajos, así que mantén tu propio ritmo."],
         ["Hay algo de resistencia: ve más despacio y presta atención a esta área.", "Puede haber bloqueos o desgaste: cuida primero lo básico.", "Habrá algo de fricción; no choques de frente y deja margen."]],
        [["Tutto scorre a tuo favore: puoi andare avanti con fiducia.", "La marea è dalla tua parte; gli sforzi trovano risposta.", "Sembra un vento a favore: buon momento per prendere l'iniziativa."],
         ["Stabile e regolare: continua col tuo ritmo.", "Né bene né male; i passi costanti funzionano meglio.", "Nessun grande sbalzo: segui il tuo ritmo."],
         ["C'è un po' di resistenza: rallenta e presta attenzione a quest'area.", "Possibili intoppi o stanchezza: cura prima le basi.", "Ci sarà un po' di attrito; non scontrarti, lascia margine."]],
    ]

    static let adviceLines: [[[String]]] = [
        [["想爭取的、想說的話，這時候不妨主動一點。", "有想推進的事，就趁順風時多走一步。", "把握機會，但仍要留意細節。"],
         ["維持日常節奏，把手上的事做完就很好。", "適合整理與累積，不必急著改變什麼。", "保持穩定，觀察就好。"],
         ["重要決定先緩一緩，多確認一次再行動。", "情緒上來時先深呼吸，別把小事放大。", "遇到卡住的地方先退一步，別急著下結論。"]],
        [["If there's something you've wanted to say or go after, make the first move.", "If you've been meaning to push something forward, take one more step while the wind is behind you.", "Seize the chance, but keep an eye on the details."],
         ["Keep your routine and finish what's on your plate — that's plenty.", "It's a good time to tidy up and build up; no need to change anything.", "Stay steady and simply observe."],
         ["Put big decisions on hold and double-check before acting.", "When emotions run high, breathe first and don't blow small things up.", "If something jams, step back before you draw conclusions."]],
        [["Si hay algo que quieras decir o conseguir, da el primer paso.", "Si tenías algo pendiente por impulsar, da un paso más mientras el viento sopla a favor.", "Aprovecha la oportunidad, pero cuida los detalles."],
         ["Mantén tu rutina y termina lo que tienes entre manos; ya es mucho.", "Buen momento para ordenar y acumular; no hace falta cambiar nada.", "Mantente estable y observa."],
         ["Pospón las decisiones importantes y comprueba dos veces antes de actuar.", "Cuando suban las emociones, respira primero y no agrandes las cosas pequeñas.", "Si algo se atasca, da un paso atrás antes de sacar conclusiones."]],
        [["Se c'è qualcosa che vuoi dire o ottenere, fai il primo passo.", "Se avevi qualcosa da portare avanti, fai un passo in più finché il vento è a favore.", "Cogli l'occasione, ma cura i dettagli."],
         ["Mantieni la tua routine e porta a termine ciò che hai: basta così.", "È un buon momento per riordinare e accumulare; non serve cambiare nulla.", "Resta stabile e osserva."],
         ["Rimanda le decisioni importanti e ricontrolla prima di agire.", "Quando le emozioni salgono, respira prima e non ingigantire le piccole cose.", "Se qualcosa si blocca, fai un passo indietro prima di trarre conclusioni."]],
    ]

    // MARK: - 今天的大局

    func contextLines(_ D: Destiny, y: Int, m: Int) -> [String] {
        let mo = D.month(m, year: y), yr = D.year(y), lp = D.luckPeriod(y)
        var out: [String] = []
        out.append(t("流月 ", "Monthly ", "Mensual ", "Mensile ") + "\(m): " + pn(mo.palace) + " " + rt(mo.reading))
        out.append(t("流年 ", "Annual ", "Anual ", "Annuale ") + "\(y): " + pn(yr.palace) + " " + rt(yr.reading))
        out.append(t("大運 ", "Luck Pillar ", "Pilar de Suerte ", "Pilastro della Sorte ") + "\(lp.start)–\(lp.end): " + pn(lp.row.palace) + " " + rt(lp.row.reading))
        return out
    }

    public func contextTail(_ D: Destiny, y: Int, m: Int) -> String {
        let mo = D.month(m, year: y), yr = D.year(y), lp = D.luckPeriod(y)
        func item(_ r: NTRow) -> String { L == .zh ? "\(pnt(r.palace))（\(rt(r.reading))）" : "\(pnt(r.palace)) (\(rt(r.reading)))" }
        return polish("\n\n" + fmt(t("順帶看大局：這個月（流月）在%@；今年（流年）在%@；目前大運在%@。想細看可以問「這個月運勢」「今年感情運」「我的大運」。",
                              "The bigger picture: this month is %@; this year is %@; your current luck pillar is %@. Ask “this month”, “my career this year” or “my luck pillar” for details.",
                              "El panorama: este mes es %@; este año es %@; tu pilar de suerte actual es %@. Pregunta «este mes», «mi trabajo este año» o «mi pilar de suerte».",
                              "Il quadro generale: questo mese è %@; quest'anno è %@; il tuo pilastro attuale è %@. Chiedi «questo mese», «il mio lavoro quest'anno» o «il mio pilastro»."),
                           item(mo), item(yr), item(lp.row)))
    }
}
