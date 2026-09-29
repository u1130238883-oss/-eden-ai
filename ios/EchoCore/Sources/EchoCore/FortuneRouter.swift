import Foundation

/// 結果卡片（App 畫成電視螢幕卡；數值 100% 來自引擎）。
public struct FortuneCard: Codable, Equatable {
    public var title: String
    public var headline: String
    public var verdict: NTVerdict?
    public var details: [String]
    /// 八字四柱（年月日時）與對應十神
    public var pillars: [String]?
    public var pillarGods: [String]?
    /// 卦：六爻（由下而上）與動爻位置
    public var hexLines: [Int]?
    public var hexMoving: [Int]?
    /// 紫微十二宮
    public var ziwei: [ZiWeiCell]?
    /// 外部連結（維基百科）
    public var link: String?
    /// 程式碼／檔案內容
    public var code: String?

    public init(title: String, headline: String, verdict: NTVerdict? = nil, details: [String] = [],
                pillars: [String]? = nil, pillarGods: [String]? = nil, hexLines: [Int]? = nil, hexMoving: [Int]? = nil,
                ziwei: [ZiWeiCell]? = nil, link: String? = nil, code: String? = nil) {
        self.title = title
        self.headline = headline
        self.verdict = verdict
        self.details = details
        self.pillars = pillars
        self.pillarGods = pillarGods
        self.hexLines = hexLines
        self.hexMoving = hexMoving
        self.ziwei = ziwei
        self.link = link
        self.code = code
    }
}

/// 一次推算的結果：給 Transformer 的事實框 + 核對規則 + 保底文字 + 卡片。
public struct FortuneQuery {
    public let frame: String
    /// 模型輸出必須包含這些字串，否則視為「解讀錯誤」並改用保底文字
    public let mustContain: [String]
    public let fallback: String
    public var card: FortuneCard?
    public let newBirthday: BirthDay?
    /// true：不經過模型，直接用 fallback（例如缺少資料的提示）
    public var deterministic: Bool = false
    /// 解讀層寫好的完整說明（有值時直接當作回覆，不再用模型逐字生成）
    public var composed: String?
    /// 讓使用者可以接著問「為什麼」「怎麼辦」
    public var follow: Followup?
    /// 由引擎附加在模型解讀後面的確定性補充（流月／流年／大運大局、今天概況）
    public var tail: String = ""
}

/// 命理意圖路由：與 ai/fortune_corpus.py 的事實框格式逐字一致。
public enum FortuneRouter {
    static let knowledgeMarkers = ["是什麼", "什麼是", "什麼意思", "代表", "有哪些", "屬什麼", "的五行", "準嗎", "原理"]

    public static func route(_ raw: String, birthday: BirthDay?, now: Date = Date(), i18n: I18N? = nil) -> FortuneQuery? {
        let text = raw.replacingOccurrences(of: " ", with: "")
        let cal = Calendar(identifier: .gregorian)
        let today = cal.dateComponents([.year, .month, .day], from: now)
        let ty = today.year!
        let date = parseDate(text)

        // 設定生日
        if text.contains("生日") || text.contains("出生"), let b = date, !containsAny(text, ["合", "配"]) {
            let d = Destiny(b)
            let p = d.natal[0].palace, t = d.type
            var q = FortuneQuery(
                frame: "生日|命\(p)|型\(t)",
                mustContain: [NT.label(p), "第\(t)型"],
                fallback: "收到，生日已記錄！你的命宮在\(NT.label(p))，九型是第\(t)型「\(NT.typeName(t))」。",
                card: FortuneCard(title: "本命", headline: "命宮 \(NT.label(p))", verdict: d.natal[0].reading.verdict,
                                  details: ["第\(t)型「\(NT.typeName(t))」", NT.typeTagline(t)]),
                newBirthday: b)
            q.tail = todayTail(d, now: now)
            let R0 = Reader(.zh, i18n: i18n)
            let nat = R0.natal(d)
            q.composed = "收到，生日記為\(b.display)！先簡單看你的本命：\n" + nat.text + todayTail(d, now: now)
            q.card = nat.card
            q.follow = nat.follow
            return q
        }

        let isSyn = containsAny(text, ["合盤", "合不合", "配不配", "速配"])
        // 一次問好幾段：「今天和明天運勢」「這個月跟下個月」
        if !isSyn, let bd = birthday, containsAny(text, ["和", "跟", "還有", "以及", "、", "與"]), !containsAny(text, ["哪個", "比較", "還是"]) {
            let tokens = ["今天", "今晚", "明天", "後天", "這週", "下週", "這個月", "下個月", "今年", "明年", "後年", "大運"]
            let found = tokens.compactMap { t -> (String, String.Index)? in text.range(of: t).map { (t, $0.lowerBound) } }
                .sorted { $0.1 < $1.1 }.map(\.0)
            if found.count >= 2 {
                let parts = found.compactMap { route($0 + "運勢", birthday: bd, now: now, i18n: i18n) }
                if parts.count >= 2, var first = parts.first {
                    first.composed = parts.compactMap(\.composed).joined(separator: "\n\n━━━━━━\n\n")
                    return first
                }
            }
        }
        guard let kind = classify(text, now: now, date: date, isSyn: isSyn) else { return nil }

        guard let birthday else {
            return FortuneQuery(frame: "無生日", mustContain: ["生日"],
                                fallback: "我還不知道你的生日！直接告訴我，例如：我的生日是2000年1月1日，或到右上角「調頻台」選好日期（會自動儲存）。",
                                card: nil, newBirthday: nil)
        }
        let D = Destiny(birthday)
        let R = Reader(.zh, i18n: i18n)

        var result: FortuneQuery = { () -> FortuneQuery in
        switch kind {
        case .week(let off):
            return FortuneQuery(frame: "一週|\(off)", mustContain: [], fallback: "", card: nil, newBirthday: nil, deterministic: true)
        case .day(let y, let m, let d, let label, _):
            let (dp, np) = D.day(month: m, day: d)
            let title = label.map { "\($0) \(m)/\(d)" } ?? "今日 \(m)/\(d)"
            let card = FortuneCard(title: title, headline: "日 \(NT.label(dp))", verdict: nil,
                                   details: ["白天：\(NT.keywords(dp))", "夜 \(NT.label(np))：\(NT.keywords(np, 2))"] + contextLines(D, year: y, month: m))
            if let label {
                return FortuneQuery(
                    frame: "今日|日\(dp)|夜\(np)", mustContain: [],
                    fallback: "\(label)（\(m)月\(d)日）白天走\(NT.label(dp))，關鍵字：\(NT.keywords(dp))；晚上走到\(NT.label(np))，留意\(NT.keywords(np, 2))。"
                        + contextTail(D, year: y, month: m),
                    card: card, newBirthday: nil, deterministic: true)
            }
            var q = FortuneQuery(
                frame: "今日|日\(dp)|夜\(np)",
                mustContain: [NT.label(dp), NT.label(np)],
                fallback: "今天的日宮是\(NT.label(dp))，關鍵字：\(NT.keywords(dp))。晚上走到\(NT.label(np))，留意\(NT.keywords(np, 2))。",
                card: card, newBirthday: nil)
            q.tail = contextTail(D, year: y, month: m)
            return q
        case .month(let my, let m):
            let row = D.month(m, year: my)
            return rowQuery(frame: "流月|\(m)月|\(row.text)", label: "\(m)月", title: "流月 \(my)年\(m)月", row: row)
        case .year(let y):
            let row = D.year(y)
            var frame = "流年|\(y)|\(row.text)"
            var q = rowQuery(frame: frame, label: "\(y)年", title: "流年 \(y)", row: row)
            let trig = D.triggeredAspects(y).prefix(3).map(\.palace)
            if !trig.isEmpty {
                frame += "|引" + trig.map(String.init).joined(separator: ",")
                let extra = "今年會引動大運的" + trig.map { "\($0)宮" }.joined(separator: "、") + "。"
                q = FortuneQuery(frame: frame, mustContain: q.mustContain, fallback: q.fallback + extra,
                                 card: q.card.map { FortuneCard(title: $0.title, headline: $0.headline, verdict: $0.verdict,
                                                                details: $0.details + ["引動大運：" + trig.map { NT.label($0) }.joined(separator: "、")]) },
                                 newBirthday: nil)
            }
            return q
        case .luckAt, .allLuck, .years:
            return FortuneQuery(frame: "大運", mustContain: [], fallback: "", card: nil, newBirthday: nil, deterministic: true)
        case .luck:
            let (s, e, row) = D.luckPeriod(ty)
            return rowQuery(frame: "大運|\(s)-\(e)|\(row.text)", label: "\(s)到\(e)年的大運", title: "大運 \(s)–\(e)", row: row)
        case .natal:
            let r0 = D.natal[0], t = D.type
            return FortuneQuery(
                frame: "命盤|命\(r0.palace)|型\(t)|\(r0.text)",
                mustContain: [NT.label(r0.palace), r0.reading.text],
                fallback: "你的命宮在\(NT.label(r0.palace))，本命判讀\(r0.reading.text)。命宮關鍵字：\(NT.keywords(r0.palace))。九型是第\(t)型「\(NT.typeName(t))」。",
                card: FortuneCard(title: "本命盤", headline: "命宮 \(NT.label(r0.palace))", verdict: r0.reading.verdict,
                                  details: D.natal.map { "\(NT.label($0.palace)) \($0.reading.text)" }),
                newBirthday: nil)
        case .personality:
            let t = D.type
            return FortuneQuery(
                frame: "九型|\(t)",
                mustContain: ["第\(t)型「\(NT.typeName(t))」"],
                fallback: "你是第\(t)型「\(NT.typeName(t))」：\(NT.typeTagline(t))。",
                card: FortuneCard(title: "九型人格", headline: "第\(t)型 \(NT.typeName(t))", verdict: nil,
                                  details: [NT.typeTagline(t)]),
                newBirthday: nil)
        case .syn(let other):
            let ch = D.synastry(with: Destiny(other))
            let c = [NTVerdict.good, .neutral, .bad].map { v in ch.filter { $0.reading.verdict == v }.count }
            let mood = c[0] > c[2] ? "好的比壞的多，整體合拍！"
                : c[0] < c[2] ? "壞的比較多，相處需要多一點耐心和磨合。" : "好壞參半，看你們怎麼經營。"
            return FortuneQuery(
                frame: "合盤|命\(ch[0].palace)|好\(c[0])正\(c[1])壞\(c[2])",
                mustContain: [NT.label(ch[0].palace), "好\(c[0])"],
                fallback: "你們的合盤命宮在\(NT.label(ch[0].palace))，重點是\(NT.keywords(ch[0].palace))。十二宮裡好\(c[0])、正\(c[1])、壞\(c[2])，\(mood)",
                card: FortuneCard(title: "合盤 × \(other.display)", headline: "合盤命宮 \(NT.label(ch[0].palace))",
                                  verdict: c[0] > c[2] ? NTVerdict.good : (c[0] < c[2] ? NTVerdict.bad : NTVerdict.neutral),
                                  details: ["好 \(c[0])　正 \(c[1])　壞 \(c[2])"] + ch.map { "\(NT.label($0.palace)) \($0.reading.text)" }),
                newBirthday: nil)
        }
        }()

        let out = reading(kind, D: D, R: R, now: now, text: text)
        result.composed = out.text
        result.card = out.card
        result.follow = out.follow
        return result
    }

    /// 依意圖產生解讀層文字（自己或別人的命盤都用這個）
    static func reading(_ kind: Kind, D: Destiny, R: Reader, now: Date, text: String) -> ReaderOutput {
        let cal = Calendar(identifier: .gregorian)
        let ty = cal.component(.year, from: now)
        var out: ReaderOutput
        switch kind {
        case .day(let y, let m, let d, let label, let focus):
            out = R.day(D, y: y, m: m, d: d, label: label, focus: focus)
            out.text += R.contextTail(D, y: y, m: m)
        case .week(let off): out = R.week(D, from: cal.date(byAdding: .day, value: off, to: now)!, next: off > 0)
        case .month(let my, let m): out = R.month(D, y: my, m: m)
        case .year(let y): out = R.year(D, y: y)
        case .luck:
            out = R.luck(D, y: ty, aspects: containsAny(text, ["十二方面", "十二個方面", "各方面", "每個方面", "每一方面"]))
        case .luckAt(let step):
            let lp = D.luckPeriod(ty)
            let target = step > 0 ? lp.end + 1 : lp.start - 1
            out = R.luck(D, y: target, aspects: true)
            let t = D.luckPeriod(target)
            out.text = (step > 0 ? "你現在的大運到\(lp.end)年結束，\(t.start)年起換下一個大運（\(t.start)–\(t.end)）。\n換運前後一兩年，生活重心通常會開始轉向新的主題。\n\n"
                                 : "你上一個大運是\(t.start)–\(t.end)年。\n\n") + out.text
        case .years(let n):
            var lines: [String] = []
            var best: (Int, NTVerdict)?
            for y in ty..<(ty + n) {
                let r = D.year(y), lp = D.luckPeriod(y)
                let trig = D.triggeredAspects(y).prefix(2).map { "\($0.palace)宮" }.joined(separator: "、")
                lines.append("• \(y)年：流年\(NT.label(r.palace))「\(r.reading.text)」" + (trig.isEmpty ? "" : "，引動\(trig)") + (y == lp.start && y != ty ? "（換大運）" : ""))
                if r.reading.verdict == .good && best == nil { best = (y, .good) }
            }
            var text = "接下來\(n)年的流年：\n" + lines.joined(separator: "\n")
            text += best.map { "\n\n最順的一年是\($0.0)年，想做大事可以把它當目標。" } ?? "\n\n這幾年沒有判讀「好」的流年，是穩紮穩打、累積實力的時期。"
            text += "\n想細看哪一年，就問「\(ty + 1)年運勢」。"
            out = ReaderOutput(text: text, card: FortuneCard(title: "未來\(n)年", headline: "流年一覽", details: lines), follow: nil)
        case .allLuck:
            var lines: [String] = []
            var y0 = D.birth.year
            for _ in 0..<10 {
                let lp = D.luckPeriod(y0)
                let mark = (lp.start...lp.end).contains(ty) ? " ← 現在" : ""
                lines.append("• \(lp.start)–\(lp.end)（\(lp.start - D.birth.year)–\(lp.end - D.birth.year)歲）：\(NT.label(lp.row.palace))「\(lp.row.reading.text)」\(mark)")
                y0 = lp.end + 1
            }
            let text = "你這一生的大運（每段九年，第一段依靈數調整長度）：\n" + lines.joined(separator: "\n")
                + "\n\n判讀「好」的階段比較順風，「壞」的階段是磨練期。想細看某一段，可以問「下一個大運」或「2035年運勢」。"
            out = ReaderOutput(text: text, card: FortuneCard(title: "一生大運", headline: "10 段", details: lines), follow: nil)
        case .natal: out = R.natal(D)
        case .personality: out = R.personality(D)
        case .syn(let other): out = R.synastry(D, other: other)
        }
        return out
    }

    enum Kind {
        /// focus：0 白天夜裡都講，1 只問白天，2 只問晚上
        case day(y: Int, m: Int, d: Int, label: String?, focus: Int)
        case week(Int)
        case month(y: Int, m: Int)
        case luck, luckAt(Int), allLuck, years(Int), year(Int), natal, personality, syn(BirthDay)
    }

    /// 中文意圖判斷：先分出「問哪一段時間」，再分出「問什麼」。
    /// 「今年是什麼運勢」「這個月是什麼運勢」這種帶「是什麼」的問句，只要有時間詞或在問自己，就是算命，不是查資料。
    static func classify(_ text: String, now: Date, date: BirthDay?, isSyn: Bool) -> Kind? {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: now)
        let ty = c.year!, tm = c.month!, td = c.day!
        if isSyn { return date.map { .syn($0) } }

        let timeWords = ["今天", "今日", "今晚", "今夜", "晚上", "夜裡", "夜晚", "半夜", "白天", "早上", "上午", "中午", "下午",
                         "明天", "明日", "後天", "昨天", "前天", "這週", "這周", "本週", "本周", "下週", "下周", "這禮拜", "這星期", "下禮拜",
                         "這個月", "本月", "下個月", "上個月", "今年", "明年", "去年", "後年", "最近", "近期", "這陣子", "這幾天", "未來",
                         "這個禮拜", "這個星期", "下個星期", "下個禮拜", "月底", "月初", "年底", "年初", "下半年", "上半年"]
        let fortuneWords = ["運", "吉", "凶", "順", "好不好", "怎麼樣", "怎樣", "如何", "會怎", "怎麼走", "走勢", "日宮", "夜宮", "流日",
                            "流月", "流年", "大運", "命盤", "命宮", "九型", "幾型", "什麼型", "靈數", "本命", "十二宮", "宮位", "算算", "幫我算", "看看", "預測", "命格", "好嗎", "會好", "旺", "衰", "走什麼", "性格", "人格", "個性", "適合", "注意", "小心", "宜", "忌", "幾宮", "哪一宮", "哪宮", "哪個宮"]
        let hasTime = containsAny(text, timeWords) || firstMatch(text, #"(\d{4})年"#) != nil || firstMatch(text, #"(\d{1,2})月"#) != nil
        let personal = text.contains("我")
        let fortune = containsAny(text, fortuneWords)
        // 純概念問題（「流年是什麼」「5宮是什麼意思」）交給資料庫
        if containsAny(text, knowledgeMarkers) && !hasTime && !personal { return nil }
        // 只有時間詞、沒在問運勢（「今天好累」）是聊天；短的追問（「那明天呢」「今年呢」）算命
        let shortFollow = hasTime && text.count <= 8 && containsAny(text, ["呢", "那", "還有", "再看"])
        guard fortune || shortFollow else { return nil }
        let hasDigits = text.contains { $0.isNumber }

        let night = containsAny(text, ["晚上", "今晚", "今夜", "夜裡", "夜晚", "夜間", "半夜", "夜宮", "睡前"])
        let dayOnly = containsAny(text, ["白天", "早上", "上午", "中午", "下午", "日宮"])
        let focus = night && !dayOnly ? 2 : (dayOnly && !night ? 1 : 0)

        // 1) 指定某一天：明天、後天、昨天、12月25日
        if let t = targetDate(text, now: now) { return .day(y: t.y, m: t.m, d: t.d, label: t.label, focus: focus) }
        // 2) 一週
        if containsAny(text, ["下週", "下周", "下禮拜", "下星期", "下個星期", "下個禮拜"]) { return .week(7) }
        if containsAny(text, ["這週", "這周", "本週", "本周", "這禮拜", "這星期", "這個禮拜", "這個星期", "一週", "一周", "這幾天", "未來七天", "接下來幾天"]) { return .week(0) }
        // 3) 月
        if let m = firstMatch(text, #"(\d{1,2})月"#).flatMap({ Int($0) }), (1...12).contains(m) {
            let y = firstMatch(text, #"(\d{4})年"#).flatMap { Int($0) } ?? (text.contains("明年") ? ty + 1 : (text.contains("去年") ? ty - 1 : ty))
            return .month(y: y, m: m)
        }
        if text.contains("下個月") { return tm == 12 ? .month(y: ty + 1, m: 1) : .month(y: ty, m: tm + 1) }
        if text.contains("上個月") { return tm == 1 ? .month(y: ty - 1, m: 12) : .month(y: ty, m: tm - 1) }
        if containsAny(text, ["這個月", "本月", "流月", "月運", "這月", "最近", "近期", "這陣子", "月底", "月初"]) { return .month(y: ty, m: tm) }
        // 4) 今天／今晚
        if containsAny(text, ["今天", "今日", "今晚", "今夜", "晚上", "夜裡", "夜晚", "半夜", "白天", "早上", "上午", "中午", "下午", "日宮", "夜宮", "流日"]) {
            return .day(y: ty, m: tm, d: td, label: nil, focus: focus)
        }
        // 4.5) 未來幾年
        if containsAny(text, ["未來幾年", "接下來幾年", "往後幾年", "未來五年", "接下來五年", "未來三年", "接下來三年", "未來十年", "近幾年", "之後幾年"]) {
            let n = containsAny(text, ["十年"]) ? 10 : (containsAny(text, ["三年"]) ? 3 : 5)
            return .years(n)
        }
        // 5) 大運：下一個、上一個、這一生
        if containsAny(text, ["一生的大運", "這輩子的大運", "所有大運", "人生大運", "每個大運", "全部大運", "一生大運", "大運一覽"]) { return .allLuck }
        if containsAny(text, ["下一個大運", "下個大運", "下一步大運", "下一段大運", "換大運", "交運"]) { return .luckAt(1) }
        if containsAny(text, ["上一個大運", "上個大運", "之前的大運"]) { return .luckAt(-1) }
        if containsAny(text, ["大運", "十年", "這幾年", "人生階段", "十二方面", "十二個方面"]) { return .luck }
        // 6) 年
        if let y = firstMatch(text, #"(\d{4})年"#).flatMap({ Int($0) }), (1900...2200).contains(y) { return .year(y) }
        if text.contains("後年") { return .year(ty + 2) }
        if text.contains("明年") { return .year(ty + 1) }
        if text.contains("去年") { return .year(ty - 1) }
        if containsAny(text, ["今年", "流年", "年運", "這一年", "整年", "年底", "年初", "下半年", "上半年"]) { return .year(ty) }
        // 7) 命盤、九型
        if containsAny(text, ["幾型", "什麼型", "九型", "性格", "人格", "個性", "靈數"]) && !text.contains("命盤") { return .personality }
        if containsAny(text, ["命盤", "命宮", "本命", "我的命", "十二宮", "宮位", "命格", "我是什麼命"]) { return .natal }
        // 8) 只說「運勢」「運氣」「幫我算算」→ 今天
        if containsAny(text, ["運勢", "運氣", "運程", "預測"]) || (!hasDigits && containsAny(text, ["算算", "幫我算", "幫我看"])) { return .day(y: ty, m: tm, d: td, label: nil, focus: focus) }
        return nil
    }

    static func rowQuery(frame: String, label: String, title: String, row: NTRow) -> FortuneQuery {
        let r = row.reading
        let phrase = ["整體順勢，有助力", "持平穩定，照常發揮就好", "有阻力，要多留意"][r.verdict.rawValue]
        return FortuneQuery(
            frame: frame,
            mustContain: [NT.label(row.palace), r.text],
            fallback: "\(label)落在\(NT.label(row.palace))，判讀「\(r.text)」：\(phrase)。果在\(NT.label(r.result))：\(NT.keywords(r.result))；因在\(NT.label(r.cause))：\(NT.keywords(r.cause))。",
            card: FortuneCard(title: title, headline: NT.label(row.palace), verdict: r.verdict,
                              details: ["判讀 \(r.text)", "果 \(NT.label(r.result))：\(NT.keywords(r.result))",
                                        "因 \(NT.label(r.cause))：\(NT.keywords(r.cause))"]),
            newBirthday: nil)
    }

    // MARK: - 今天的大局（Hollow「今天」分頁：日宮、夜宮、流月、流年、大運）

    static func contextLines(_ D: Destiny, year y: Int, month m: Int) -> [String] {
        let mo = D.month(m, year: y), yr = D.year(y), lp = D.luckPeriod(y)
        return ["流月 \(m)月 \(NT.label(mo.palace)) \(mo.reading.text)",
                "流年 \(y) \(NT.label(yr.palace)) \(yr.reading.text)",
                "大運 \(lp.start)–\(lp.end) \(NT.label(lp.row.palace)) \(lp.row.reading.text)"]
    }

    static func contextTail(_ D: Destiny, year y: Int, month m: Int) -> String {
        let mo = D.month(m, year: y), yr = D.year(y), lp = D.luckPeriod(y)
        return "\n順帶看大局：這個月（流月）在\(NT.label(mo.palace))「\(mo.reading.text)」，今年（流年）在\(NT.label(yr.palace))「\(yr.reading.text)」，目前大運（\(lp.start)–\(lp.end)）在\(NT.label(lp.row.palace))「\(lp.row.reading.text)」。想細看可以問「這個月運勢」「今年運勢」「我的大運」。"
    }

    /// 剛設定好生日時，順帶給今天的日宮與夜宮
    static func todayTail(_ D: Destiny, now: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: now)
        let (dp, np) = D.day(month: c.month!, day: c.day!)
        return "\n順帶看今天：白天走\(NT.label(dp))（\(NT.keywords(dp, 2))），夜裡走\(NT.label(np))（\(NT.keywords(np, 2))）。想細看就說「今天運勢」。"
    }

    /// 「明天」「後天」「昨天」「3月5日」「2026年12月1日」→ 日期與說法
    static func targetDate(_ text: String, now: Date) -> (y: Int, m: Int, d: Int, label: String)? {
        let cal = Calendar(identifier: .gregorian)
        for (w, off) in [("大後天", 3), ("後天", 2), ("明天", 1), ("明日", 1), ("昨天", -1), ("昨日", -1), ("前天", -2)] where text.contains(w) {
            guard let t = cal.date(byAdding: .day, value: off, to: now) else { return nil }
            let c = cal.dateComponents([.year, .month, .day], from: t)
            return (c.year!, c.month!, c.day!, w)
        }
        if let re = try? NSRegularExpression(pattern: #"(?:(\d{4})年)?(\d{1,2})月(\d{1,2})[日號号]"#),
           let mt = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            func g(_ i: Int) -> Int? { Range(mt.range(at: i), in: text).flatMap { Int(text[$0]) } }
            let ty = cal.component(.year, from: now)
            if let m = g(2), let d = g(3), (1...12).contains(m), (1...31).contains(d) {
                return (g(1) ?? ty, m, d, "\(m)月\(d)日")
            }
        }
        return nil
    }

    // MARK: - 工具

    static func containsAny(_ s: String, _ keys: [String]) -> Bool { keys.contains { s.contains($0) } }

    public static func firstMatch(_ s: String, _ pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }

    /// 解析「2000年1月2日」「2000-1-2」「2000/01/02」「2000.1.2」
    public static func parseDate(_ s: String) -> BirthDay? {
        let pattern = #"(\d{4})\s*[年/\-.]\s*(\d{1,2})\s*[月/\-.]\s*(\d{1,2})"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        func g(_ i: Int) -> Int? { Range(m.range(at: i), in: s).flatMap { Int(s[$0]) } }
        guard let y = g(1), let mo = g(2), let d = g(3),
              (1900...2100).contains(y), (1...12).contains(mo), (1...31).contains(d) else { return nil }
        return BirthDay(year: y, month: mo, day: d)
    }
}
