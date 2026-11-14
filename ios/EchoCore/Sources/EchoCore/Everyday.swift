import Foundation

/// 生活裡的簡單問題，用算的就知道，不用上網：現在幾點、今天幾號、明天星期幾、今年是什麼年、
/// 母親節是哪天、離過年還有幾天、一公斤幾公克、華氏 100 度是攝氏幾度、一加一、三的平方、一百塊打八折……
/// 數字可以用阿拉伯數字或中文（「一百二十」「兩千五」「三萬五」）。
public enum Everyday {
    public static func answer(_ raw: String, now: Date = Date()) -> String? {
        let t = clean(raw)
        guard !t.isEmpty, t.count <= 40 else { return nil }
        if let a = clock(t, now) { return a }
        if let a = dayQuestion(t, now) { return a }
        if let a = yearQuestion(t, now) { return a }
        if let a = dateWeekday(t) { return a }
        if let a = leapYear(t, now) { return a }
        if let a = countdown(t, now) { return a }
        if let a = convert(t) { return a }
        if let a = arithmetic(t) { return a }
        return nil
    }

    /// 去掉客套話、標點、語氣詞
    static func clean(_ raw: String) -> String {
        var t = raw.filter { !$0.isWhitespace && !"？?！!。，,~～、：:「」\"'".contains($0) }
        let polite = ["可以告訴我", "能不能告訴我", "請問一下", "請問", "想請問", "想問一下", "想問", "我想問", "問一下", "我想知道", "你知道", "請告訴我",
                      "告訴我", "跟我說", "幫我算一下", "幫我算", "算一下", "請計算", "計算", "好奇", "欸", "所以", "那麼", "那", "對了", "話說"]
        var changed = true
        while changed {
            changed = false
            for p in polite where t.hasPrefix(p) && t.count > p.count { t.removeFirst(p.count); changed = true; break }
        }
        while let l = t.last, "呀啊啦喔哦耶唷".contains(l) { t.removeLast() }
        return t
    }

    static let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    static let zodiac = ["鼠", "牛", "虎", "兔", "龍", "蛇", "馬", "羊", "猴", "雞", "狗", "豬"]
    static var cal: Calendar { Calendar(identifier: .gregorian) }

    static func ymd(_ d: Date) -> (y: Int, m: Int, d: Int, w: Int) {
        let c = cal.dateComponents([.year, .month, .day, .weekday], from: d)
        return (c.year!, c.month!, c.day!, c.weekday!)
    }

    static func make(_ y: Int, _ m: Int, _ d: Int) -> Date? {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        guard let date = cal.date(from: c), ymd(date).m == m, ymd(date).d == d else { return nil }
        return date
    }

    static func show(_ d: Date, year: Bool = false) -> String {
        let c = ymd(d)
        return (year ? "\(c.y) 年 " : "") + "\(c.m) 月 \(c.d) 日（星期\(weekdays[c.w - 1])）"
    }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0
    }

    // MARK: - 現在幾點

    static func clock(_ t: String, _ now: Date) -> String? {
        let forms = ["幾點", "幾點了", "幾點鐘", "幾點幾分", "現在幾點", "現在幾點了", "現在幾點鐘", "現在是幾點", "現在幾點幾分", "現在時間", "現在的時間",
                     "現在時間是", "時間", "現在是什麼時間", "現在什麼時間", "目前幾點", "目前時間", "那現在幾點"]
        guard forms.contains(t) || forms.contains(where: { t == $0 + "呢" || t == $0 + "嗎" }) else { return nil }
        let c = cal.dateComponents([.hour, .minute], from: now)
        let h = c.hour!, mi = c.minute!
        let part = h < 5 ? "凌晨" : h < 11 ? "早上" : h < 13 ? "中午" : h < 18 ? "下午" : "晚上"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "現在是 %02d:%02d，", h, mi) + "\(part) \(h12) 點" + (mi == 0 ? "整" : " \(mi) 分") + "。"
    }

    // MARK: - 今天幾號、明天星期幾、今天農曆幾號

    static let relDays: [(String, Int)] = [("大後天", 3), ("大前天", -3), ("今天", 0), ("今日", 0), ("明天", 1), ("明日", 1),
                                           ("後天", 2), ("昨天", -1), ("昨日", -1), ("前天", -2)]

    static func dayQuestion(_ t: String, _ now: Date) -> String? {
        guard let (word, off) = relDays.first(where: { t.hasPrefix($0.0) }) else { return nil }
        var rest = String(t.dropFirst(word.count))
        if rest.hasPrefix("是") { rest.removeFirst() }
        for s in ["呢", "嗎"] where rest.hasSuffix(s) { rest.removeLast() }
        guard let day = cal.date(byAdding: .day, value: off, to: now) else { return nil }
        let c = ymd(day)
        let lunarAsk = rest.contains("農曆") || rest.contains("陰曆") || rest.contains("舊曆")
        let asks = ["幾月幾號", "幾月幾日", "幾號", "幾日", "星期幾", "禮拜幾", "週幾", "周幾", "什麼日子", "幾月", "日期", "什麼日期", "哪一天"]
        guard lunarAsk || asks.contains(where: { rest == $0 }) else { return nil }
        if lunarAsk {
            let l = LunarCalendar.shared.lunar(c.y, c.m, c.d)
            return "\(word)是農曆\(l.text.dropFirst(3))（\(l.text.prefix(3))，\(zodiac[Astro.pmod(l.year - 4, 12)])年），國曆 \(c.m) 月 \(c.d) 日。"
        }
        if rest == "星期幾" || rest == "禮拜幾" || rest == "週幾" || rest == "周幾" {
            return "\(word)是星期\(weekdays[c.w - 1])（\(c.m) 月 \(c.d) 日）。"
        }
        var s = "\(word)是 \(c.y) 年 \(c.m) 月 \(c.d) 日，星期\(weekdays[c.w - 1])。"
        if rest == "什麼日子", let f = Commonsense.festival(on: day) { s += "也是\(f)！" }
        let l = LunarCalendar.shared.lunar(c.y, c.m, c.d)
        s += "農曆是\(GZ.monthNames[l.month - 1])月\(GZ.lunarDayName(l.day))。"
        return s
    }

    // MARK: - 今年是什麼年

    static func yearQuestion(_ t: String, _ now: Date) -> String? {
        let words: [(String, Int)] = [("今年", 0), ("明年", 1), ("去年", -1), ("後年", 2), ("前年", -2)]
        guard let (w, off) = words.first(where: { t.hasPrefix($0.0) }) else { return nil }
        var rest = String(t.dropFirst(w.count))
        if rest.hasPrefix("是") { rest.removeFirst() }
        for s in ["呢", "嗎"] where rest.hasSuffix(s) { rest.removeLast() }
        let y = ymd(now).y + off
        let animal = zodiac[Astro.pmod(y - 4, 12)]
        let gz = GZ.name(Astro.pmod(y - 4, 60))
        switch rest {
        case "哪一年", "哪年", "幾年", "西元幾年", "公元幾年", "什麼年", "幾幾年":
            return "\(w)是西元 \(y) 年，民國 \(y - 1911) 年，農曆是\(gz)年（\(animal)年）。"
        case "民國幾年":
            return "\(w)是民國 \(y - 1911) 年（西元 \(y) 年）。"
        case "什麼生肖", "生肖", "屬什麼", "是什麼生肖", "什麼年生肖", "哪個生肖", "生肖是什麼", "屬什麼生肖":
            return "\(w)（\(y) 年）是\(gz)年，生肖屬\(animal)。注意生肖是從農曆過年（春節）開始算，過年前出生的還是屬前一年的生肖。"
        default:
            return nil
        }
    }

    // MARK: - 某一天是星期幾

    static func dateWeekday(_ t: String) -> String? {
        guard let g = RuleBook.match(t, #"^(?:(\d{4})年)?(\d{1,2})月(\d{1,2})[日號](?:是)?(?:星期幾|禮拜幾|週幾|周幾)"#) else { return nil }
        let y = Int(g[0]) ?? ymd(Date()).y
        guard let m = Int(g[1]), let d = Int(g[2]), let date = make(y, m, d) else { return nil }
        return "\(y) 年 \(m) 月 \(d) 日是星期\(weekdays[ymd(date).w - 1])。"
    }

    // MARK: - 閏年

    static func leapYear(_ t: String, _ now: Date) -> String? {
        guard t.contains("閏年") else { return nil }
        var y: Int?
        if let g = RuleBook.match(t, #"(\d{4})年?"#) { y = Int(g[0]) }
        else if t.hasPrefix("今年") { y = ymd(now).y }
        else if t.hasPrefix("明年") { y = ymd(now).y + 1 }
        else if t.hasPrefix("去年") { y = ymd(now).y - 1 }
        if let y {
            let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
            let next = (y + 1...y + 8).first { ($0 % 4 == 0 && $0 % 100 != 0) || $0 % 400 == 0 }!
            return leap ? "是，\(y) 年是閏年，2 月有 29 天，一年 366 天。"
                        : "不是，\(y) 年不是閏年，2 月只有 28 天。下一個閏年是 \(next) 年。"
        }
        if t.contains("怎麼算") || t.contains("什麼是") || t.contains("是什麼") || t.contains("規則") {
            return "閏年的規則：能被 4 整除的年是閏年，但能被 100 整除的不是，除非也能被 400 整除。所以 2024、2028 是閏年，1900 不是，2000 是。閏年的 2 月有 29 天。\n為什麼要閏年？地球繞太陽一圈大約是 365.2422 天，每年多出將近 6 小時，每 4 年補一天，日曆才不會和季節越差越遠。"
        }
        return nil
    }

    // MARK: - 離某一天還有幾天

    static func countdown(_ t: String, _ now: Date) -> String? {
        guard let g = RuleBook.match(t, #"^(?:距離|離|到)?(.+?)(?:還有|剩下|剩|還剩)(?:幾天|多少天|多久|幾個月|幾週)"#) else { return nil }
        var target = g[0]
        for s in ["只", "大概"] where target.hasSuffix(s) { target.removeLast(s.count) }
        let today = cal.startOfDay(for: now)
        var when: Date?, name = target
        if let g2 = RuleBook.match(target, #"^(?:(\d{4})年)?(\d{1,2})月(\d{1,2})[日號]?$"#), let m = Int(g2[1]), let d = Int(g2[2]) {
            if let y = Int(g2[0]) { when = make(y, m, d) }
            else if let a = make(ymd(now).y, m, d) { when = a < today ? make(ymd(now).y + 1, m, d) : a }
        } else if ["週末", "周末", "星期六", "禮拜六"].contains(target) {
            let w = ymd(now).w
            when = cal.date(byAdding: .day, value: (7 - w) % 7, to: now)
            name = "星期六"
        } else if ["月底"].contains(target) {
            let c = ymd(now)
            when = cal.date(byAdding: DateComponents(month: 1, day: -1), to: make(c.y, c.m, 1)!)
        } else if ["年底", "跨年", "今年結束"].contains(target) {
            when = make(ymd(now).y, 12, 31); name = "今年的最後一天"
        } else if let f = Commonsense.festivalNamed(target), let d = Commonsense.nextDate(of: f, from: now) {
            when = d; name = f.name
        }
        guard let date = when else { return nil }
        let n = daysBetween(today, date)
        if n == 0 { return "就是今天！今天是\(name)（\(show(date))）。" }
        guard n > 0 else { return nil }
        let weeks = n >= 14 ? "，大約 \(n / 7) 週" + (n % 7 > 0 ? "又 \(n % 7) 天" : "") : ""
        return "離\(name)還有 \(n) 天\(weeks)。\(name)是 \(show(date, year: true))。"
    }

    // MARK: - 中文數字

    static let digit: [Character: Int] = ["零": 0, "〇": 0, "一": 1, "二": 2, "兩": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
    static let smallUnit: [Character: Int] = ["十": 10, "百": 100, "千": 1000]
    static let numeralChars = Set("0123456789.,零〇一二兩两三四五六七八九十百千萬万億亿點半")

    /// 「一百二十」「兩千五」「三萬五千」「1.5」「12萬」「一點五」「半」→ 數字
    static func number(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: ",", with: "")
        if t.isEmpty { return nil }
        if let v = Double(t) { return v }
        if t == "半" { return 0.5 }
        if t.hasSuffix("半"), let v = number(String(t.dropLast())) { return v + 0.5 }
        if let r = t.range(of: "點") ?? t.range(of: ".") {
            guard let a = number(String(t[..<r.lowerBound])) ?? (r.lowerBound == t.startIndex ? 0 : nil) else { return nil }
            let frac = t[r.upperBound...]
            var f = ""
            for ch in frac {
                if let d = digit[ch] { f += String(d) } else if ch.isNumber { f.append(ch) } else { return nil }
            }
            return Double("\(Int(a)).\(f)")
        }
        for (big, mul) in [("億", 1e8), ("亿", 1e8), ("萬", 1e4), ("万", 1e4)] {
            if let r = t.range(of: big) {
                let hi = number(String(t[..<r.lowerBound])) ?? 1
                let tail = String(t[r.upperBound...])
                var lo = tail.isEmpty ? 0 : (number(tail) ?? -1)
                if lo < 0 { return nil }
                // 「三萬五」＝三萬五千
                if tail.count == 1, let d = tail.first.flatMap({ digit[$0] }) { lo = Double(d) * mul / 10 }
                return hi * mul + lo
            }
        }
        // 小於一萬：一千二百三十四、兩千五（＝2500）、十五、二十
        var total = 0, cur = -1, lastUnit = 10000
        var digitsOnly = ""
        for ch in t {
            if let d = digit[ch] { cur = d; digitsOnly += String(d) }
            else if ch.isNumber, let d = Int(String(ch)) { cur = d; digitsOnly += String(d) }
            else if let u = smallUnit[ch] {
                total += (cur < 0 ? 1 : cur) * u
                cur = -1; lastUnit = u; digitsOnly = "x"
            } else { return nil }
        }
        if cur >= 0 {
            // 「兩千五」的五是五百；「一百零五」的五是五
            let prevZero = t.dropLast().last.map { $0 == "零" || $0 == "〇" } ?? false
            total += (lastUnit >= 100 && lastUnit < 10000 && !prevZero && t.count >= 3) ? cur * lastUnit / 10 : cur
        }
        if digitsOnly.count > 1, !digitsOnly.contains("x"), let v = Double(digitsOnly) { return v }   // 「一二三」→ 123
        return Double(total)
    }

    /// 把句子裡的中文數字換成阿拉伯數字（「一加一」→「1加1」），避開「一下」「一起」這種不是數字的字
    static func digitize(_ s: String) -> String {
        var out = "", run = ""
        func flush() {
            if !run.isEmpty {
                if let v = number(run), run != "點", run != "半" { out += fmt(v, comma: false) } else { out += run }
                run = ""
            }
        }
        for ch in s {
            if numeralChars.contains(ch) && !(ch == "點" && run.isEmpty) { run.append(ch) } else { flush(); out.append(ch) }
        }
        flush()
        return out
    }

    static func fmt(_ v: Double, comma: Bool = true) -> String {
        if v.isNaN || v.isInfinite { return "\(v)" }
        if abs(v - v.rounded()) < 1e-9 && abs(v) < 1e15 {
            let i = Int64(v.rounded())
            if !comma { return String(i) }
            let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier: "en_US")
            return f.string(from: NSNumber(value: i)) ?? String(i)
        }
        let a = abs(v)
        let s = a >= 1000 ? String(format: "%.2f", v) : a >= 1 ? String(format: "%.4g", v) : String(format: "%.4g", v)
        var r = s
        if r.contains(".") && !r.contains("e") { while r.hasSuffix("0") { r.removeLast() }; if r.hasSuffix(".") { r.removeLast() } }
        return r
    }

    // MARK: - 計算

    static func arithmetic(_ t0: String) -> String? {
        var t = t0
        for f in ["等於多少", "等於幾", "等於什麼", "是多少", "是幾", "等於", "多少", "是什麼", "呢", "嗎", "="] where t.hasSuffix(f) {
            t.removeLast(f.count)
        }
        guard !t.isEmpty else { return nil }
        let d = digitize(t)
        func num(_ s: String) -> Double? { Double(s.replacingOccurrences(of: ",", with: "")) }
        // 平方、立方、根號、次方
        if let g = RuleBook.match(d, #"^([\d.]+)的平方根$"#) ?? RuleBook.match(d, #"^根號([\d.]+)$"#) ?? RuleBook.match(d, #"^([\d.]+)開根號$"#),
           let a = num(g[0]) {
            return "√\(fmt(a)) = \(fmt(a.squareRoot()))。"
        }
        if let g = RuleBook.match(d, #"^([\d.]+)的平方$"#), let a = num(g[0]) { return "\(fmt(a)) 的平方是 \(fmt(a * a))（\(fmt(a)) × \(fmt(a))）。" }
        if let g = RuleBook.match(d, #"^([\d.]+)的立方$"#), let a = num(g[0]) { return "\(fmt(a)) 的立方是 \(fmt(a * a * a))。" }
        if let g = RuleBook.match(d, #"^([\d.]+)的([\d.]+)次方$"#), let a = num(g[0]), let b = num(g[1]), b <= 64 {
            return "\(fmt(a)) 的 \(fmt(b)) 次方是 \(fmt(pow(a, b)))。"
        }
        if let g = RuleBook.match(d, #"^([\d.]+)的一?半$"#), let a = num(g[0]) { return "\(fmt(a)) 的一半是 \(fmt(a / 2))。" }
        if let g = RuleBook.match(d, #"^([\d.]+)的([\d.]+)倍$"#), let a = num(g[0]), let b = num(g[1]) {
            return "\(fmt(a)) 的 \(fmt(b)) 倍是 \(fmt(a * b))。"
        }
        // 百分比：百分之二十的五百、五百的百分之二十、500的20%、20%的500
        if let g = RuleBook.match(d, #"^百分之([\d.]+)的([\d.]+)$"#) ?? RuleBook.match(d, #"^([\d.]+)[%％]的([\d.]+)$"#),
           let p = num(g[0]), let a = num(g[1]) {
            return "\(fmt(a)) 的 \(fmt(p))% 是 \(fmt(a * p / 100))。"
        }
        if let g = RuleBook.match(d, #"^([\d.]+)的百分之([\d.]+)$"#) ?? RuleBook.match(d, #"^([\d.]+)的([\d.]+)[%％]$"#),
           let a = num(g[0]), let p = num(g[1]) {
            return "\(fmt(a)) 的 \(fmt(p))% 是 \(fmt(a * p / 100))。"
        }
        // 打折：一百塊打八折、500元打75折
        if let g = RuleBook.match(d, #"^([\d.]+)(?:塊|元|塊錢|歐元|美元)?打([\d.]+)折(?:後|以後)?$"#), let a = num(g[0]), let z = num(g[1]) {
            let rate = z >= 10 ? z / 100 : z / 10
            return "\(fmt(a)) 打 \(g[1]) 折是 \(fmt(a * rate))（\(fmt(a)) × \(fmt(rate))），省了 \(fmt(a - a * rate))。"
        }
        // 四則運算
        var e = d
        for (a, b) in [("加上", "+"), ("減去", "-"), ("減掉", "-"), ("乘以", "*"), ("乘上", "*"), ("除以", "/"),
                       ("加", "+"), ("減", "-"), ("乘", "*"), ("×", "*"), ("÷", "/"), ("＋", "+"), ("－", "-"), ("＊", "*"),
                       ("／", "/"), ("（", "("), ("）", ")"), ("x", "*"), ("X", "*")] {
            e = e.replacingOccurrences(of: a, with: b)
        }
        e = e.replacingOccurrences(of: ",", with: "")
        let allowed = Set("0123456789.+-*/()")
        guard e.allSatisfy({ allowed.contains($0) }), e.contains(where: { "+-*/".contains($0) }), e.first.map({ $0 != "+" && $0 != "*" && $0 != "/" }) ?? false
        else { return nil }
        var p = ExprParser(Array(e))
        guard let v = p.parse() else { return nil }
        guard v.isFinite else { return "不能除以 0 喔：任何數除以 0 都沒有意義。" }
        let shown = e.replacingOccurrences(of: "*", with: " × ").replacingOccurrences(of: "/", with: " ÷ ")
            .replacingOccurrences(of: "+", with: " + ").replacingOccurrences(of: "-", with: " - ")
        return "\(shown) 等於 \(fmt(v))。"
    }

    // MARK: - 單位換算

    struct Unit { let names: [String]; let dim: String; let factor: Double; let show: String }
    static let units: [Unit] = [
        Unit(names: ["公里", "千米", "km"], dim: "長", factor: 1000, show: "公里"),
        Unit(names: ["公尺", "米", "m"], dim: "長", factor: 1, show: "公尺"),
        Unit(names: ["公分", "釐米", "厘米", "cm"], dim: "長", factor: 0.01, show: "公分"),
        Unit(names: ["毫米", "公釐", "mm"], dim: "長", factor: 0.001, show: "公釐"),
        Unit(names: ["英里", "哩", "mile"], dim: "長", factor: 1609.344, show: "英里"),
        Unit(names: ["英尺", "英呎", "呎", "ft"], dim: "長", factor: 0.3048, show: "英尺"),
        Unit(names: ["英寸", "英吋", "吋", "inch"], dim: "長", factor: 0.0254, show: "英寸"),
        Unit(names: ["碼"], dim: "長", factor: 0.9144, show: "碼"),
        Unit(names: ["公噸", "噸"], dim: "重", factor: 1_000_000, show: "公噸"),
        Unit(names: ["公斤", "千克", "kg"], dim: "重", factor: 1000, show: "公斤"),
        Unit(names: ["台斤", "臺斤"], dim: "重", factor: 600, show: "台斤"),
        Unit(names: ["斤"], dim: "重", factor: 600, show: "台斤"),
        Unit(names: ["公克", "克", "g"], dim: "重", factor: 1, show: "公克"),
        Unit(names: ["毫克", "mg"], dim: "重", factor: 0.001, show: "毫克"),
        Unit(names: ["磅", "lb"], dim: "重", factor: 453.59237, show: "磅"),
        Unit(names: ["盎司", "oz"], dim: "重", factor: 28.349523125, show: "盎司"),
        Unit(names: ["公升", "升", "L"], dim: "容", factor: 1, show: "公升"),
        Unit(names: ["毫升", "西西", "cc", "ml"], dim: "容", factor: 0.001, show: "毫升"),
        Unit(names: ["加侖"], dim: "容", factor: 3.785411784, show: "加侖"),
        Unit(names: ["世紀"], dim: "時", factor: 3_155_695_200, show: "世紀"),
        Unit(names: ["年"], dim: "時", factor: 31_536_000, show: "年"),
        Unit(names: ["個月", "月"], dim: "時", factor: 2_629_746, show: "個月"),
        Unit(names: ["星期", "禮拜", "週", "周"], dim: "時", factor: 604_800, show: "星期"),
        Unit(names: ["天", "日"], dim: "時", factor: 86400, show: "天"),
        Unit(names: ["小時", "鐘頭"], dim: "時", factor: 3600, show: "小時"),
        Unit(names: ["分鐘", "分"], dim: "時", factor: 60, show: "分鐘"),
        Unit(names: ["秒鐘", "秒"], dim: "時", factor: 1, show: "秒"),
        Unit(names: ["平方公里"], dim: "面", factor: 1_000_000, show: "平方公里"),
        Unit(names: ["平方公尺", "平方米"], dim: "面", factor: 1, show: "平方公尺"),
        Unit(names: ["平方公分"], dim: "面", factor: 0.0001, show: "平方公分"),
        Unit(names: ["公頃"], dim: "面", factor: 10_000, show: "公頃"),
        Unit(names: ["坪"], dim: "面", factor: 3.305785, show: "坪"),
        Unit(names: ["英畝"], dim: "面", factor: 4046.8564224, show: "英畝"),
        Unit(names: ["TB"], dim: "資", factor: 1_099_511_627_776, show: "TB"),
        Unit(names: ["GB"], dim: "資", factor: 1_073_741_824, show: "GB"),
        Unit(names: ["MB"], dim: "資", factor: 1_048_576, show: "MB"),
        Unit(names: ["KB"], dim: "資", factor: 1024, show: "KB"),
        Unit(names: ["華氏", "°F", "℉"], dim: "溫", factor: 0, show: "華氏"),
        Unit(names: ["攝氏", "°C", "℃"], dim: "溫", factor: 0, show: "攝氏"),
    ]

    /// 句子裡提到的單位（長的先比對：「平方公里」不會變成「公里」，「公斤」不會變成「斤」）
    static func unitMentions(_ t: String) -> [(unit: Unit, range: Range<String.Index>)] {
        var found: [(Unit, Range<String.Index>)] = []
        let all = units.flatMap { u in u.names.map { (u, $0) } }.sorted { $0.1.count > $1.1.count }
        for (u, n) in all {
            var from = t.startIndex
            while let r = t.range(of: n, range: from..<t.endIndex) {
                if !found.contains(where: { $0.1.overlaps(r) }) { found.append((u, r)) }
                from = r.upperBound
            }
        }
        return found.sorted { $0.1.lowerBound < $1.1.lowerBound }
    }

    static func convert(_ t0: String) -> String? {
        var t1 = t0.replacingOccurrences(of: "個", with: "").replacingOccurrences(of: "度", with: "")
        if t1.hasPrefix("半") { t1 = "0.5" + t1.dropFirst() }
        let t = digitize(t1)
        guard ["幾", "多少", "換算", "換成", "等於", "轉成", "折合"].contains(where: { t.contains($0) }) else { return nil }
        let ms = unitMentions(t)
        // 溫度：「華氏100是攝氏幾」「37是華氏幾」
        if ms.contains(where: { $0.unit.dim == "溫" }) {
            let temps = ms.filter { $0.unit.dim == "溫" }
            guard let g = RuleBook.match(t, #"(-?[\d.]+)"#), let v = Double(g[0]) else { return nil }
            let numPos = t.range(of: g[0])!.lowerBound
            let fromF: Bool
            if temps.count >= 2 { fromF = temps[0].unit.show == "華氏" }
            else { fromF = temps[0].unit.show == "華氏" ? temps[0].range.lowerBound <= numPos || t.hasPrefix("華氏") : false }
            if fromF { return "華氏 \(fmt(v)) 度 = 攝氏 \(fmt((v - 32) * 5 / 9)) 度。（攝氏 = (華氏 − 32) × 5 ÷ 9）" }
            return "攝氏 \(fmt(v)) 度 = 華氏 \(fmt(v * 9 / 5 + 32)) 度。（華氏 = 攝氏 × 9 ÷ 5 + 32）"
        }
        guard ms.count == 2, ms[0].unit.dim == ms[1].unit.dim, ms[0].unit.show != ms[1].unit.show else { return nil }
        let (a, b) = (ms[0], ms[1])
        // 第二個單位前面要是「幾／多少」（問的是它）
        let before = t[t.startIndex..<b.range.lowerBound]
        guard before.hasSuffix("幾") || before.hasSuffix("多少") || before.hasSuffix("成") || before.hasSuffix("於") || before.hasSuffix("算") else { return nil }
        // 第一個單位前面的數字（沒有就是 1）
        var numStr = ""
        var i = a.range.lowerBound
        while i > t.startIndex {
            let j = t.index(before: i)
            if "0123456789.".contains(t[j]) { numStr.insert(t[j], at: numStr.startIndex); i = j } else { break }
        }
        guard t[t.startIndex..<i].allSatisfy({ "一有".contains($0) }) else { return nil }
        let v = Double(numStr) ?? 1
        // 跟日曆有關的：一年幾天、一個月幾天
        if a.unit.show == "年" && b.unit.show == "天" && v == 1 {
            return "一年有 365 天；閏年有 366 天（2 月多一天，每 4 年一次，像 2028 年）。"
        }
        if a.unit.show == "個月" && b.unit.show == "天" && v == 1 {
            return "一個月有 28 到 31 天：1、3、5、7、8、10、12 月是 31 天，4、6、9、11 月是 30 天，2 月是 28 天（閏年 29 天）。"
        }
        if a.unit.show == "年" && b.unit.show == "個月" && v == 1 { return "一年有 12 個月。" }
        if a.unit.show == "年" && (b.unit.show == "星期") && v == 1 { return "一年大約有 52 個星期又 1 天（閏年多 2 天）。" }
        let r = v * a.unit.factor / b.unit.factor
        // 「一天有幾個小時」→「一天有 24 小時」；其他「3 公里 = 1.864 英里」
        var s = v == 1 && t.contains("有") ? "一\(a.unit.show)有 \(fmt(r)) \(b.unit.show)。" : "\(fmt(v)) \(a.unit.show) = \(fmt(r)) \(b.unit.show)。"
        if a.unit.names.contains("斤") && t.contains("斤") && !t.contains("台斤") || b.unit.names.contains("斤") && !t.contains("台斤") {
            s += "（這裡的斤是台灣的台斤，1 台斤 = 600 公克；中國大陸的市斤是 500 公克）"
        }
        if a.unit.dim == "時" && (a.unit.show == "個月" || b.unit.show == "個月") { s += "（一個月用平均 30.4 天算）" }
        return s
    }
}
