import Foundation

/// 規劃型問題：「我什麼時候會結婚」「今年哪個月最好」「今年哪方面比較順」「我的5宮今年怎樣」。
/// 全部用九型十二宮的流年、流月、大運十二方面與引動掃描出答案。
public enum Planner {
    public enum Ask {
        case when(palace: Int, topic: String)
        case bestMonths(y: Int, palace: Int?)
        case areas(y: Int)
        case palace(Int, y: Int)
        case days(palace: Int, topic: String)
        case compareYears([Int])
        case compareMonths([(Int, Int)])
    }

    static func has(_ s: String, _ k: [String]) -> Bool { k.contains { s.contains($0) } }

    /// 事件 → 宮位
    static let events: [(Int, [String], String)] = [
        (5, ["告白", "約會", "表白", "相親", "見喜歡的人"], "戀愛・桃花"),
        (3, ["談判", "面試", "開會", "報告", "溝通", "簽約", "談生意", "考試"], "溝通・學習"),
        (2, ["買東西", "購物", "理財", "收錢", "花錢"], "錢財"),
        (9, ["旅行", "出遊", "出門", "遠行"], "好運・遠行"),
        (7, ["結婚", "嫁", "娶", "婚姻", "另一半", "對象", "伴侶", "正緣"], "結婚・伴侶"),
        (5, ["感情", "脫單", "戀愛", "談戀愛", "桃花", "交男朋友", "交女朋友", "遇到喜歡", "愛情"], "戀愛・桃花"),
        (10, ["升職", "升官", "加薪", "工作", "事業", "創業", "找到工作", "換工作", "成功"], "事業・地位"),
        (2, ["發財", "賺錢", "有錢", "財運", "存到錢", "買車"], "錢財"),
        (8, ["偏財", "中獎", "投資", "健康", "身體", "生病"], "偏財・身體"),
        (9, ["出國", "旅行", "搬到國外", "留學", "好運", "轉運"], "好運・遠行"),
        (4, ["買房", "搬家", "家庭", "成家"], "家庭・安全感"),
        (3, ["考試", "考上", "學業", "畢業", "讀書"], "溝通・學習"),
        (11, ["朋友", "貴人", "人脈"], "朋友・變動"),
    ]

    public static func parse(_ raw: String, now: Date) -> Ask? {
        let text = raw.replacingOccurrences(of: " ", with: "")
        if text.hasPrefix("你") && !has(text, ["你覺得", "你看"]) { return nil }
        let cal = Calendar(identifier: .gregorian)
        let ty = cal.component(.year, from: now)
        var y = ty
        if let m = FortuneRouter.firstMatch(text, #"(\d{4})年"#).flatMap({ Int($0) }) { y = m }
        else if text.contains("明年") { y = ty + 1 } else if text.contains("去年") { y = ty - 1 } else if text.contains("後年") { y = ty + 2 }

        // 比較：「今年和明年哪個好」「這個月跟下個月哪個比較順」
        if has(text, ["哪個", "哪一個", "比較好", "比較順", "還是", "比起", "差在哪", "誰比較"]) {
            var ys: [Int] = []
            for (w, v) in [("去年", ty - 1), ("今年", ty), ("明年", ty + 1), ("後年", ty + 2)] {
                if let r = text.range(of: w) { ys.append(v); _ = r }
            }
            if let re = try? NSRegularExpression(pattern: #"(\d{4})年"#) {
                for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    if let r = Range(m.range(at: 1), in: text), let v = Int(text[r]) { ys.append(v) }
                }
            }
            let uy = Array(Set(ys)).sorted()
            if uy.count >= 2 { return .compareYears(uy) }
            let tm = cal.component(.month, from: now)
            var ms: [(Int, Int)] = []
            if text.contains("上個月") { ms.append(tm == 1 ? (ty - 1, 12) : (ty, tm - 1)) }
            if text.contains("這個月") || text.contains("本月") { ms.append((ty, tm)) }
            if text.contains("下個月") { ms.append(tm == 12 ? (ty + 1, 1) : (ty, tm + 1)) }
            if let re = try? NSRegularExpression(pattern: #"(?<!\d)(\d{1,2})月"#) {
                for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    if let r = Range(m.range(at: 1), in: text), let v = Int(text[r]), (1...12).contains(v) { ms.append((ty, v)) }
                }
            }
            if ms.count >= 2 { return .compareMonths(ms) }
        }

        // 哪幾天：「這個月哪天適合告白」「最近哪天適合面試」→ 掃未來 30 天的日宮／夜宮
        if has(text, ["哪天", "哪幾天", "哪一天", "什麼日子", "哪個日子", "幾號"]) {
            for (p, words, name) in events where has(text, words) { return .days(palace: p, topic: name) }
            if let p = palaceNumber(text) { return .days(palace: p, topic: "\(p)宮") }
            return .days(palace: 9, topic: "好運・順心")
        }

        let whenAsk = has(text, ["什麼時候", "哪一年", "哪年", "幾時", "何時", "幾歲", "要等多久", "多久才"])
        if whenAsk {
            for (p, words, name) in events where has(text, words) { return .when(palace: p, topic: name) }
            if let p = palaceNumber(text) { return .when(palace: p, topic: "\(p)宮") }
            return nil
        }
        if has(text, ["哪個月", "哪幾個月", "哪些月", "幾月"]) && has(text, ["好", "順", "適合", "旺", "注意", "小心", "差", "不好"]) {
            var p: Int?
            for (pp, words, _) in events where has(text, words) { p = pp; break }
            return .bestMonths(y: y, palace: p ?? palaceNumber(text))
        }
        if has(text, ["哪方面", "哪些方面", "什麼方面", "哪個方面", "哪一方面", "哪些事", "要注意什麼", "該注意什麼", "哪裡比較"])
            && (text.contains("我") || has(text, ["今年", "明年", "年"])) {
            return .areas(y: y)
        }
        if let p = palaceNumber(text), text.contains("我") || has(text, ["今年", "明年", "這個月", "運", "怎樣", "如何"]),
           !has(text, FortuneRouter.knowledgeMarkers) || text.contains("我") {
            return .palace(p, y: y)
        }
        return nil
    }

    static func palaceNumber(_ text: String) -> Int? {
        guard let s = FortuneRouter.firstMatch(text, #"(?<![\d年月日號])(\d{1,2})宮"#), let p = Int(s), (1...12).contains(p) else { return nil }
        return p
    }

    // MARK: - 回答

    public static func answer(_ ask: Ask, D: Destiny, now: Date, reader R: Reader) -> ReaderOutput {
        let ty = Calendar(identifier: .gregorian).component(.year, from: now)
        switch ask {
        case .palace(let p, let y):
            let cal = Calendar(identifier: .gregorian)
            return R.topicReading(D, palace: p, y: y, m: y == ty ? cal.component(.month, from: now) : nil)
        case .when(let p, let topic):
            return when(D, palace: p, topic: topic, from: ty, R)
        case .bestMonths(let y, let p):
            return bestMonths(D, y: y, palace: p, R)
        case .areas(let y):
            return areas(D, y: y, R)
        case .days(let p, let topic):
            return days(D, palace: p, topic: topic, now: now, R)
        case .compareYears(let ys):
            return compareYears(D, ys, R)
        case .compareMonths(let ms):
            return compare(ms.map { (y, m) in (label: "\(y)年\(m)月", row: D.month(m, year: y), extra: D.year(y)) }, kind: "流月", R)
        }
    }

    static func days(_ D: Destiny, palace p: Int, topic: String, now: Date, _ R: Reader) -> ReaderOutput {
        let cal = Calendar(identifier: .gregorian)
        let wd = ["日", "一", "二", "三", "四", "五", "六"]
        var dayHits: [String] = [], nightHits: [String] = []
        for i in 0..<30 {
            let d = cal.date(byAdding: .day, value: i, to: now)!
            let c = cal.dateComponents([.month, .day, .weekday], from: d)
            let (dp, np) = D.day(month: c.month!, day: c.day!)
            let label = "\(c.month!)/\(c.day!)（\(wd[c.weekday! - 1])）"
            if dp == p { dayHits.append(label) }
            if np == p { nightHits.append(label) }
        }
        var text = "以\(topic)來看，這件事對應\(NT.label(p))。我掃了接下來 30 天的流日：\n"
        text += "• 白天走到\(p)宮的日子：" + (dayHits.isEmpty ? "沒有" : dayHits.joined(separator: "、")) + "\n"
        text += "• 晚上走到\(p)宮的日子：" + (nightHits.isEmpty ? "沒有" : nightHits.joined(separator: "、")) + "\n"
        if let first = (dayHits + nightHits).first {
            text += "這些天\(p)宮的主題（\(NT.keywords(p, 3))）會特別明顯，最近的是\(first)。\(R.tip(p))"
        } else {
            text += "接下來一個月流日都沒有直接走到\(p)宮；可以挑日宮在9宮「愉悅」的日子，心情和運氣會比較順。"
        }
        let card = FortuneCard(title: "挑日子 · \(topic)", headline: NT.label(p),
                               details: dayHits.map { "白天 \($0)" } + nightHits.map { "晚上 \($0)" })
        return ReaderOutput(text: R.polish(text), card: card, follow: nil)
    }

    static func compare(_ items: [(label: String, row: NTRow, extra: NTRow)], kind: String, _ R: Reader) -> ReaderOutput {
        func score(_ r: NTRow, _ e: NTRow) -> Double { Double([2, 1, 0][r.reading.verdict.rawValue]) + 0.4 * Double([2, 1, 0][e.reading.verdict.rawValue]) }
        var text = "比較看看：\n"
        for it in items {
            text += "• \(it.label)：\(kind)在\(NT.label(it.row.palace))，判讀「\(it.row.reading.text)」——\(R.verdictLine(it.row.reading.verdict, it.row.palace))\n"
        }
        let ranked = items.sorted { score($0.row, $0.extra) > score($1.row, $1.extra) }
        if let a = ranked.first, let b = ranked.dropFirst().first, score(a.row, a.extra) > score(b.row, b.extra) {
            text += "整體來說，\(a.label)比較順。"
            if a.row.reading.verdict == b.row.reading.verdict { text += "（兩者判讀一樣，差在背景的大環境。）" }
        } else {
            text += "兩段時間的判讀差不多，重點在你想做的事落在哪一宮：問我「\(items[0].label)感情運」之類的，我可以分主題比較。"
        }
        let card = FortuneCard(title: "比較 · \(kind)", headline: items.map(\.label).joined(separator: " vs "),
                               details: items.map { "\($0.label) \(NT.label($0.row.palace)) \($0.row.reading.text)" })
        return ReaderOutput(text: R.polish(text), card: card, follow: nil)
    }

    /// 比較流年：不只看流年本身，還要看每一年引動了大運的哪些方面（幾個、好壞、各代表什麼），再從含義下結論
    static func compareYears(_ D: Destiny, _ ys: [Int], _ R: Reader) -> ReaderOutput {
        struct Y { let y: Int; let row: NTRow; let trig: [NTRow]; let good: Int; let bad: Int; let score: Double }
        let items: [Y] = ys.map { y in
            let row = D.year(y), trig = D.triggeredAspects(y)
            let g = trig.filter { $0.reading.verdict == .good }.count, b = trig.filter { $0.reading.verdict == .bad }.count
            // 流年本身的好壞佔一部分；被引動的方面越多好的、越少壞的越順
            let base = Double([2, 1, 0][row.reading.verdict.rawValue])
            return Y(y: y, row: row, trig: trig, good: g, bad: b, score: base + 1.2 * Double(g) - 1.0 * Double(b) + 0.3 * Double(trig.count - g - b))
        }
        var text = "比較看看（先看流年本身，再看它引動了大運的哪些方面）：\n"
        for it in items {
            text += "\n【\(it.y)年】流年在\(NT.label(it.row.palace))，判讀「\(it.row.reading.text)」——\(R.verdictLine(it.row.reading.verdict, it.row.palace))\n"
            if it.trig.isEmpty {
                text += "這一年沒有引動大運的任何方面，比較平淡，變化主要來自流年本身。\n"
            } else {
                let neutral = it.trig.count - it.good - it.bad
                text += "引動大運 \(it.trig.count) 個方面（好 \(it.good)、壞 \(it.bad)" + (neutral > 0 ? "、平 \(neutral)" : "") + "）：\n"
                for a in it.trig {
                    text += "• 第\(a.palace)方面 \(NT.label(a.palace))「\(a.reading.text)」：" + FlowReading.interpret(a) + "\n"
                }
            }
        }
        let ranked = items.sorted { $0.score > $1.score }
        if let a = ranked.first, let b = ranked.dropFirst().first {
            text += "\n🧭 結論："
            if a.score - b.score < 0.5 {
                text += "兩年差不多，差別在哪些方面被引動——"
            } else {
                text += "\(a.y)年比較好。"
            }
            // 從被引動的方面的含義說明為什麼
            func themes(_ rows: [NTRow], _ v: NTVerdict) -> String {
                rows.filter { $0.reading.verdict == v }.map { NT.palaceName($0.palace) }.joined(separator: "、")
            }
            for it in [a, b] {
                let good = themes(it.trig, .good), bad = themes(it.trig, .bad)
                var line = "\(it.y)年"
                if it.trig.isEmpty { line += "沒有引動，看流年本身" }
                else {
                    if !good.isEmpty { line += "可以把握「\(good)」" }
                    if !bad.isEmpty { line += (good.isEmpty ? "" : "，") + "要小心「\(bad)」" }
                    if good.isEmpty && bad.isEmpty { line += "引動的方面都是平的，不好不壞" }
                }
                text += line + "；"
            }
            text.removeLast()
            text += "。"
            // 被引動的方面如果起因都在同一宮，那一宮就是這一年的關鍵
            for it in items where it.trig.count >= 2 {
                let causes = Dictionary(grouping: it.trig, by: { $0.reading.cause })
                if let (c, rows) = causes.max(by: { $0.value.count < $1.value.count }), rows.count * 2 > it.trig.count {
                    text += "\n\(it.y)年被引動的方面，起因\(rows.count == it.trig.count ? "全部" : "大多")在\(NT.label(c))（\(NT.keywords(c, 3))），"
                        + "所以這一年的起伏關鍵在「\(NT.palaceName(c))」這件事上，處理好了，其他方面也會跟著順。"
                }
            }
            if a.good > 0 && a.row.reading.verdict == .bad {
                text += "雖然\(a.y)年流年本身判讀是壞，但引動的方面裡有好的，代表有機會可以把握，不是一路不順。"
            }
        }
        let card = FortuneCard(title: "比較 · 流年", headline: ys.map { "\($0)年" }.joined(separator: " vs "),
                               details: items.map { "\($0.y)年 \(NT.label($0.row.palace)) \($0.row.reading.text)・引動\($0.trig.count)（好\($0.good) 壞\($0.bad)）" })
        return ReaderOutput(text: R.polish(text), card: card, follow: nil)
    }

    static func vname(_ v: NTVerdict) -> String { ["好", "正", "壞"][v.rawValue] }

    static func when(_ D: Destiny, palace p: Int, topic: String, from: Int, _ R: Reader) -> ReaderOutput {
        struct Hit { let y: Int; let score: Int; let why: String; let verdict: NTVerdict }
        var hits: [Hit] = []
        for y in from..<(from + 12) {
            let row = D.year(y)
            let aspect = D.luckAspects(y)[p - 1]
            var reasons: [String] = []
            var score = 0
            if row.palace == p { reasons.append("流年正好走到\(NT.label(p))"); score += 3 }
            else if row.reading.result == p { reasons.append("流年的果落在\(p)宮"); score += 2 }
            else if row.reading.cause == p { reasons.append("流年的因來自\(p)宮"); score += 1 }
            if D.triggeredAspects(y).contains(where: { $0.palace == p }) { reasons.append("流年引動大運的第\(p)方面"); score += 2 }
            guard score > 0 else { continue }
            let v = row.palace == p ? row.reading.verdict : aspect.reading.verdict
            score += [2, 0, -2][v.rawValue]
            hits.append(Hit(y: y, score: score, why: reasons.joined(separator: "，") + "（判讀\(vname(v))）", verdict: v))
        }
        var text = "以\(topic)（\(NT.label(p))）來看，我掃了\(from)到\(from + 11)年的流年、大運方面和引動：\n"
        if hits.isEmpty {
            text += "這十二年裡流年都沒有直接碰到\(p)宮，代表這件事比較不是被「時機」推著走，而是看你自己的主動。\n"
            let a = D.luckAspects(from)[p - 1]
            text += "目前大運的第\(p)方面判讀是「\(a.reading.text)」。" + R.verdictLine(a.reading.verdict, from)
        } else {
            for h in hits.prefix(5) { text += "• \(h.y)年：\(h.why)\n" }
            let best = hits.max { $0.score != $1.score ? $0.score < $1.score : $0.y > $1.y }!
            text += "最值得把握的是\(best.y)年" + (best.verdict == .bad ? "，雖然判讀偏辛苦，但這一宮在那年最被觸動，事情比較會有動靜。" : "，那一年這個主題最有機會往前走。")
        }
        text += "\n提醒：九型十二宮看的是走勢和時機，不是保證，真正的結果還是看你怎麼做。"
        let card = FortuneCard(title: "時機 · \(topic)", headline: NT.label(p), details: hits.map { "\($0.y) \($0.why)" })
        return ReaderOutput(text: R.polish(text), card: card, follow: nil)
    }

    static func bestMonths(_ D: Destiny, y: Int, palace p: Int?, _ R: Reader) -> ReaderOutput {
        let rows = (1...12).map { ($0, D.month($0, year: y)) }
        var text: String
        var det: [String] = rows.map { "\($0.0)月 \(NT.label($0.1.palace)) \($0.1.reading.text)" }
        if let p {
            let rel = rows.filter { $0.1.palace == p || $0.1.reading.result == p || $0.1.reading.cause == p }
            text = "\(y)年跟\(NT.label(p))有關的月份：\n"
            if rel.isEmpty { text += "今年沒有哪個月特別碰到\(p)宮。" }
            for (m, r) in rel {
                let how = r.palace == p ? "流月正好在\(p)宮" : (r.reading.result == p ? "果落在\(p)宮" : "因來自\(p)宮")
                text += "• \(m)月：\(how)，判讀\(r.reading.text)\n"
            }
            if let best = rel.first(where: { $0.1.reading.verdict == .good }) { text += "其中最順的是\(best.0)月。" }
            det = rel.map { "\($0.0)月 \(NT.label($0.1.palace)) \($0.1.reading.text)" }
        } else {
            let good = rows.filter { $0.1.reading.verdict == .good }, bad = rows.filter { $0.1.reading.verdict == .bad }
            text = "\(y)年的十二個流月：\n"
            text += "比較順的月份：" + (good.isEmpty ? "沒有特別順的月份" : good.map { "\($0.0)月（\(NT.palaceName($0.1.palace))）" }.joined(separator: "、")) + "\n"
            text += "要多留意的月份：" + (bad.isEmpty ? "沒有" : bad.map { "\($0.0)月（\(NT.palaceName($0.1.palace))）" }.joined(separator: "、")) + "\n"
            text += "想細看哪個月，就問「\(good.first?.0 ?? 1)月運勢」。"
        }
        let card = FortuneCard(title: "\(y) 流月一覽", headline: p.map { NT.label($0) } ?? "十二個月", details: det)
        return ReaderOutput(text: R.polish(text), card: card, follow: nil)
    }

    static func areas(_ D: Destiny, y: Int, _ R: Reader) -> ReaderOutput {
        let aspects = D.luckAspects(y)
        let lp = D.luckPeriod(y), yr = D.year(y)
        let trig = Set(D.triggeredAspects(y).map(\.palace))
        func item(_ a: NTRow) -> String { "\(R.topicShort(a.palace))（\(a.palace)宮\(a.reading.text)）" + (trig.contains(a.palace) ? "★" : "") }
        let good = aspects.filter { $0.reading.verdict == .good }, bad = aspects.filter { $0.reading.verdict == .bad }
        var text = "\(y)年你在大運（\(lp.start)–\(lp.end)）的十二個方面：\n"
        text += "比較順的：" + (good.isEmpty ? "沒有" : good.map(item).joined(separator: "、")) + "\n"
        text += "要多注意的：" + (bad.isEmpty ? "沒有" : bad.map(item).joined(separator: "、")) + "\n"
        text += "今年的流年在\(NT.label(yr.palace))（\(yr.reading.text)）"
        text += trig.isEmpty ? "。" : "，標★的是今年被流年引動、特別有感的方面。"
        text += "\n想細看某一方面，可以問「我今年感情運如何」「今年事業順不順」。"
        let card = FortuneCard(title: "\(y) 十二方面", headline: "大運 \(lp.start)–\(lp.end)",
                               details: aspects.map { "\($0.palace)宮 \(R.topicShort($0.palace)) \($0.reading.text)" + (trig.contains($0.palace) ? " ★" : "") })
        return ReaderOutput(text: R.polish(text), card: card, follow: nil)
    }
}
