import Foundation

/// 安慰：聽出你現在的心情 → 用你的生日看此刻走到哪裡（這幾年的大運、今年的流年、這個月的流月、今天的日宮／今晚的夜宮）
/// → 照九型十二宮的讀法（起因 → 場域 → 呈現出來的樣子）說出你的處境和情緒 → 這十年的那一方面、本命裡這件事是敏感處還是力量
/// → 西方星盤同一宮的角度，或你的九型在壓力下會怎樣、怎麼好起來 → 什麼時候會鬆開、今天可以做的一件小事 → 陪著你。
/// 跟 ai/solace.py 逐字一樣（Fixtures/solace.json 對照）；不講算法代號，只講含義。
public enum Solace {
    struct Feeling {
        let kind: String
        let palaces: [Int]
        let topic: Int?
        let lead: [String]
    }

    static func seed(_ text: String, _ y: Int, _ m: Int, _ d: Int) -> Int {
        text.unicodeScalars.reduce(0) { $0 + Int($1.value) } + y * 372 + m * 31 + d
    }

    static func pick(_ options: [String], _ s: Int) -> String { options[s % options.count] }

    static func detect(_ text: String) -> Feeling? {
        let t = text.replacingOccurrences(of: " ", with: "")
        if SolaceData.notFeeling.contains(where: { t.contains($0) }) { return nil }
        for f in SolaceData.feelings where f.keys.contains(where: { t.contains($0) }) {
            let topic = SolaceData.topicHints.first { h in h.words.contains { t.contains($0) } }?.palace
            return Feeling(kind: f.kind, palaces: f.palaces, topic: topic, lead: f.lead)
        }
        return nil
    }

    /// 這句話是在說心情（App 在「全部交給 AI」時，心情還是由 NineSun 用命盤來接）
    public static func isFeeling(_ text: String) -> Bool { detect(text) != nil }

    static func dom(_ p: Int) -> String { SolaceData.domainShort[p - 1] }

    static func emotion(_ r: NTReading) -> String {
        let e = SolaceData.emotion[r.result - 1]
        switch r.verdict {
        case .good: return e.good
        case .bad: return e.bad
        case .neutral:
            let g = e.good.components(separatedBy: "、")[0]
            let b = e.bad.components(separatedBy: "、")[0].components(separatedBy: "，")[0]
            return "在" + g + "和" + b + "之間擺盪"
        }
    }

    static func explains(_ row: NTRow, _ focus: [Int]) -> Bool {
        focus.contains(row.palace) || focus.contains(row.reading.result) || focus.contains(row.reading.cause)
    }

    /// 一層的一句話（起因 → 場域 →（呈現出來的樣子））
    static func clause(_ row: NTRow) -> String {
        let r = row.reading
        let tone = ["是順的", "平平", "比較重"][r.verdict.rawValue]
        if r.cause == row.palace { return "起因和場域都在\(dom(row.palace))（\(tone)）" }
        return "\(SolaceData.causeShort[r.cause - 1])，落在\(dom(row.palace))（\(tone)）"
    }

    static func detail(_ row: NTRow) -> String {
        "呈現出來是「\(dom(row.reading.result))」那一面，心裡容易\(emotion(row.reading))"
    }

    /// 四層一起看，再挑最貼近這個心情的那一層細說
    static func situation(_ D: Destiny, _ y: Int, _ m: Int, _ d: Int, _ hour: Int, _ focus: [Int]) -> (name: String, row: NTRow, text: String) {
        let (day, night) = D.day(month: m, day: d)
        let late = hour >= 18 || hour < 5
        let nowP = late ? night : day, when = late ? "今晚" : "今天白天"
        let mo = D.month(m, year: y), yr = D.year(y)
        let lp = D.luckPeriod(y)
        var lines = ["我看了你此刻走到的地方：",
                     "・這幾年（\(lp.start)–\(lp.end)）：\(clause(lp.row))",
                     "・今年：\(clause(yr))",
                     "・這個月：\(clause(mo))",
                     "・\(when)：走到「\(NT.palaceName(nowP))」這一宮，心思會在\(dom(nowP))上"]
        let layers: [(String, NTRow)] = [("month", mo), ("year", yr), ("luck", lp.row)]
        let chosen = layers.first { $0.1.reading.verdict == .bad && explains($0.1, focus) }
            ?? layers.first { explains($0.1, focus) } ?? ("month", mo)
        let (name, row) = chosen
        let span = ["month": "這個月", "year": "今年", "luck": "這幾年"][name]!
        let v = row.reading.verdict
        let extra = focus.contains(nowP) && v != .good ? "再加上\(when)剛好走到「\(NT.palaceName(nowP))」，" : ""
        switch v {
        case .bad:
            lines.append("最貼近你現在感受的是\(span)：\(detail(row))。\(extra)所以你會這樣，一點都不奇怪，這不是你想太多。")
        case .good:
            lines.append("\(span)其實是往好的方向走的，底子是\(emotion(row.reading))的。現在的難受，比較像路上的一顆小石頭，不會擋住你太久。")
        case .neutral:
            lines.append("\(span)不算特別順也不算特別卡：\(detail(row))。\(extra)心情起伏是正常的。")
        }
        return (name, row, lines.joined(separator: "\n"))
    }

    /// 本命盤裡，這件事是你天生比較敏感的地方，還是你的力量
    static func natalNote(_ D: Destiny, _ focus: [Int]) -> String? {
        for fp in focus.prefix(2) {
            guard let row = D.natal.first(where: { $0.palace == fp }) else { continue }
            if row.reading.verdict == .bad {
                return "從你的本命看，\(dom(fp))本來就是你比較敏感、柔軟的地方，所以這件事會特別碰到你的心。"
            }
            if row.reading.verdict == .good {
                return "不過從你的本命看，\(dom(fp))其實是你的力量所在，你有走出來的底子。"
            }
        }
        return nil
    }

    static func nextGoodMonth(_ D: Destiny, _ y: Int, _ m: Int, ahead: Int = 6) -> (k: Int, month: Int)? {
        for k in 1...ahead {
            let yy = y + (m + k - 1) / 12, mm = (m + k - 1) % 12 + 1
            if D.month(mm, year: yy).reading.verdict == .good { return (k, mm) }
        }
        return nil
    }

    /// 什麼時候會鬆開
    static func hope(_ D: Destiny, _ name: String, _ row: NTRow, _ y: Int, _ m: Int) -> String {
        let g = nextGoodMonth(D, y, m)
        if row.reading.verdict != .bad {
            if let g, g.k == 1 { return "下個月（\(g.month)月）會走到比較順的一段，心會慢慢鬆開。" }
            if let g { return "到\(g.month)月會走到比較順的時候。情緒會過去的。" }
            return "這段時間會慢慢過去，情緒像天氣，會換的。"
        }
        if name == "month" {
            if let g, g.k == 1 { return "好消息是，下個月（\(g.month)月）會換到比較順的一段，心會慢慢鬆開。" }
            if let g { return "這個月過完就會換一段，到\(g.month)月會走到比較順的時候。情緒不會一直停在這裡。" }
            return "這個月過完就會換到下一段。情緒像天氣，會過去的。"
        }
        if name == "year" {
            if D.year(y + 1).reading.verdict == .good { return "今年是比較重的一年，但明年（\(y + 1)）會往好的方向轉。" }
            if let g { return "今年雖然比較重，但\(g.month)月會是喘口氣的時候。" }
            return "今年比較重，但每一年都會換，你會一步一步走出來。"
        }
        let tail = g.map { "而且就算在這段裡，\($0.month)月也會是比較輕鬆的時候。" } ?? ""
        return "這一段會走到\(D.luckPeriod(y).end)年，它是一段長的功課，不是永遠。" + tail
    }

    /// 用現在的時間（手機的時區）
    public static func reply(_ text: String, birthday: BirthDay?, now: Date, again: Bool = false) -> String? {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour], from: now)
        return reply(text, birthday: birthday, y: c.year!, m: c.month!, d: c.day!, hour: c.hour!, again: again)
    }

    /// again：這段對話剛剛已經細看過時間點，這次簡短、換個角度陪
    public static func reply(_ text: String, birthday: BirthDay?, y: Int, m: Int, d: Int, hour: Int, again: Bool = false) -> String? {
        guard let f = detect(text) else { return nil }
        let s = seed(text, y, m, d)
        let focus = (f.topic.map { [$0] } ?? []) + f.palaces
        var out = [pick(f.lead, s)]
        let ending = SolaceData.ask[f.kind] ?? pick(SolaceData.closing, s / 3)
        let heavy = SolaceData.heavy.contains { text.contains($0) }
        if again, let b = birthday {
            let D = Destiny(b)
            out.append(SolaceData.again)
            if SolaceData.westernKinds.contains(f.kind) {
                let t = D.type
                let ts = SolaceData.typeStress[t - 1]
                out.append("你是第\(t)型「\(NT.typeName(t))」：\(ts.stress)。這不是缺點；往第\(ts.toward)型的方向走會好受一些：\(ts.grow)。")
            } else {
                let w = SolaceData.western[focus[0] - 1]
                out.append("在西方星盤裡，\(w.meaning)；\(w.comfort)")
            }
            out.append("現在先為自己做一件小事就好：\(SolaceData.smallStep[focus[0] - 1])。")
            out.append(ending)
            if heavy { out.append(SolaceData.care) }
            return out.joined(separator: "\n")
        }
        guard let b = birthday else {
            let p = focus[0]
            out.append("這種感覺在九型十二宮裡對應「\(NT.palaceName(p))」這一宮，它管的是\(dom(p))。")
            let w = SolaceData.western[p - 1]
            out.append("在西方星盤裡，\(w.meaning)；\(w.comfort)")
            out.append("今天可以先為自己做一件小事：\(SolaceData.smallStep[p - 1])。")
            out.append(ending)
            if heavy { out.append(SolaceData.care) }
            out.append(SolaceData.noBirthday)
            return out.joined(separator: "\n")
        }
        let D = Destiny(b)
        let sit = situation(D, y, m, d, hour, focus)
        out.append(sit.text)
        // 問的是某一方面（感情、工作、家、錢、朋友、身體）：再看這十年的大運十二方面裡的那一方面
        let area = SolaceData.aspect[f.kind] ?? f.topic.flatMap { SolaceData.areaName[$0] != nil ? $0 : nil }
        if let area {
            let a = D.luckAspects(y)[area - 1]
            let tone = ["這十年整體是順的，這次只是一時的卡", "這十年平平，起伏都還在可以走過的範圍", "這十年本來就比較需要用力"][a.reading.verdict.rawValue]
            let hit = D.triggeredAspects(y).contains { $0.palace == area } ? "而且今年的流年剛好引動這一方面，所以最近特別有感。" : ""
            out.append("再看你這十年的「\(SolaceData.areaName[area]!)」這一方面：\(tone)。\(hit)")
        }
        if let note = natalNote(D, focus) { out.append(note) }
        let key = sit.row.reading.verdict == .bad ? sit.row.reading.result : (f.topic ?? focus[0])
        // 心裡的痛（難過、失戀、孤單…）用西方星盤的角度；壓力、焦慮、自我懷疑這類，看你的九型在壓力下會怎樣
        if SolaceData.westernKinds.contains(f.kind) {
            let w = SolaceData.western[key - 1]
            out.append("在西方星盤裡，\(w.meaning)；\(w.comfort)")
        } else {
            let t = D.type
            let ts = SolaceData.typeStress[t - 1]
            out.append("你是第\(t)型「\(NT.typeName(t))」：\(ts.stress)。這不是缺點；往第\(ts.toward)型的方向走會好受一些：\(ts.grow)。")
        }
        out.append(hope(D, sit.name, sit.row, y, m) + "今天可以先為自己做一件小事：\(SolaceData.smallStep[sit.row.reading.cause - 1])。")
        out.append(ending)
        if heavy { out.append(SolaceData.care) }
        return out.joined(separator: "\n")
    }
}
