import Foundation

/// 有標準答案、用算的就知道的題目：大腦（小模型）很常算錯或亂猜，引擎直接算給它。
/// 某年生肖、某年干支、日期加幾天、兩個日期差幾天、地支沖合、按比例分錢、長方形面積周長、單利利息、原子序。
/// 前後的口頭禪（「認真問：」「考考你：」「不要騙我」「拜託」「快」）先拿掉再看。
public enum QuickCalc {
    public static func answer(_ raw: String) -> String? {
        let t = strip(raw)
        guard !t.isEmpty, t.count <= 60 else { return nil }
        for f in [zodiacYear, ganzhiYear, dateAdd, dateDiff, branchClash, branchHarmony, share, rectangle, interest, element] {
            if let a = f(t) { return a }
        }
        return nil
    }

    static let prefixes = ["我朋友說我錯了", "快點告訴我", "認真問", "考考你", "小問題", "問一下", "請問一下", "請問", "想問一下", "想問", "哈囉", "欸", "急",
                           "你知道", "告訴我", "幫我算一下", "幫我算", "算一下"]
    static let suffixes = ["你算得出來嗎", "不要騙我", "謝謝你", "謝謝", "謝啦", "拜託", "快", "只回答答案不要解釋", "只回答答案", "不要解釋", "呢", "嗎"]

    static func strip(_ raw: String) -> String {
        var t = raw.filter { !$0.isWhitespace && !"？?！!。~～「」\"'".contains($0) }
        t = t.replacingOccurrences(of: "：", with: ":")
        var changed = true
        while changed {
            changed = false
            while let f = t.first, ":,，".contains(f) { t.removeFirst(); changed = true }
            while let l = t.last, ":,，".contains(l) { t.removeLast(); changed = true }
            for p in prefixes where t.hasPrefix(p) && t.count > p.count + 3 { t.removeFirst(p.count); changed = true; break }
            for s in suffixes where t.hasSuffix(s) && t.count > s.count + 3 { t.removeLast(s.count); changed = true; break }
        }
        return t
    }

    static func groups(_ t: String, _ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) else { return nil }
        return (1..<m.numberOfRanges).map { i in Range(m.range(at: i), in: t).map { String(t[$0]) } ?? "" }
    }

    static func num(_ x: Double) -> String {
        abs(x - x.rounded()) < 1e-9 ? String(Int(x.rounded())) : String(format: "%.2f", x).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }

    // MARK: - 年份：生肖、干支

    static func zodiacYear(_ t: String) -> String? {
        guard let g = groups(t, #"^(?:西元)?(\d{4})年(?:出生|生)?(?:的人?)?(?:是)?(?:屬什麼|屬啥|什麼)(?:生肖)?$"#), let y = Int(g[0]), y > 0 else { return nil }
        let i = Astro.pmod(y - 4, 60)
        return "\(y) 年是\(GZ.name(i))年，生肖屬\(Everyday.zodiac[Astro.pmod(y - 4, 12)])。（生肖從農曆過年算起：1 月到春節前出生的，屬前一年的\(Everyday.zodiac[Astro.pmod(y - 5, 12)])。）"
    }

    static func ganzhiYear(_ t: String) -> String? {
        guard t.contains("干支") || t.contains("甲子") || t.hasSuffix("農曆什麼年")
                || t.range(of: #"^(?:西元)?\d{4}年(?:是)?(?:什麼|哪一|哪個)年$"#, options: .regularExpression) != nil else { return nil }
        guard let g = groups(t, #"^(?:西元)?(\d{4})年"#), let y = Int(g[0]), y > 0 else { return nil }
        let i = Astro.pmod(y - 4, 60)
        return "\(y) 年是\(GZ.name(i))年（生肖\(Everyday.zodiac[Astro.pmod(y - 4, 12)])）。"
    }

    // MARK: - 日期

    static func date(_ y: String, _ m: String, _ d: String) -> Date? {
        guard let y = Int(y), let m = Int(m), let d = Int(d) else { return nil }
        return Everyday.make(y, m, d)
    }

    static func dateAdd(_ t: String) -> String? {
        guard let g = groups(t, #"^(\d{4})年(\d{1,2})月(\d{1,2})[日號](?:再|往後|之後)?(?:過|加|後)(\d{1,4})天(?:後|之後)?(?:是)?(?:幾月幾[日號]|哪一天|哪天|什麼時候|幾號)$"#),
              let a = date(g[0], g[1], g[2]), let n = Int(g[3]),
              let b = Everyday.cal.date(byAdding: .day, value: n, to: a) else { return nil }
        let c = Everyday.ymd(b)
        return "\(g[0]) 年 \(g[1]) 月 \(g[2]) 日再過 \(n) 天，是 \(c.y) 年 \(c.m)月\(c.d)日（星期\(Everyday.weekdays[c.w - 1])）。"
    }

    static func dateDiff(_ t: String) -> String? {
        guard let g = groups(t, #"^(\d{4})年(\d{1,2})月(\d{1,2})[日號](?:到|至|和|跟)(\d{4})年(\d{1,2})月(\d{1,2})[日號](?:相差|差|隔|相隔|之間)?(?:有)?幾天$"#),
              let a = date(g[0], g[1], g[2]), let b = date(g[3], g[4], g[5]) else { return nil }
        let n = abs(Everyday.daysBetween(a, b))
        return "從 \(g[0])/\(g[1])/\(g[2]) 到 \(g[3])/\(g[4])/\(g[5])，相差 \(n) 天。"
    }

    // MARK: - 地支

    static let branches = "子丑寅卯辰巳午未申酉戌亥".map(String.init)
    static let harmony: [String: (String, String)] = ["子": ("丑", "土"), "丑": ("子", "土"), "寅": ("亥", "木"), "亥": ("寅", "木"), "卯": ("戌", "火"),
                                                       "戌": ("卯", "火"), "辰": ("酉", "金"), "酉": ("辰", "金"), "巳": ("申", "水"), "申": ("巳", "水"),
                                                       "午": ("未", "土"), "未": ("午", "土")]

    static func branchClash(_ t: String) -> String? {
        guard let g = groups(t, #"^(?:地支)?([子丑寅卯辰巳午未申酉戌亥])(?:會)?(?:沖|衝|相沖)(?:什麼|哪個|哪一個|誰)(?:地支)?$"#),
              let i = branches.firstIndex(of: g[0]) else { return nil }
        let o = branches[(i + 6) % 12]
        return "\(g[0])沖\(o)（\(g[0])\(o)六沖，生肖\(Everyday.zodiac[i])和\(Everyday.zodiac[(i + 6) % 12])相沖），代表衝突、變動。"
    }

    static func branchHarmony(_ t: String) -> String? {
        guard let g = groups(t, #"^(?:地支)?([子丑寅卯辰巳午未申酉戌亥])(?:和|跟|與)?(?:哪個|哪一個|什麼|誰)(?:地支)?(?:六合|合|相合)$|^(?:地支)?([子丑寅卯辰巳午未申酉戌亥])(?:的)?六合(?:是)?(?:什麼|哪個|誰)$"#)
        else { return nil }
        let b = g[0].isEmpty ? g[1] : g[0]
        guard let (o, el) = harmony[b] else { return nil }
        return "\(b)和\(o)六合（\(b)\(o)合化\(el)），代表互相吸引、合作。"
    }

    // MARK: - 應用題

    static func share(_ t: String) -> String? {
        guard let g = groups(t, #"^(\d+)元(?:按|依|照)([\d:]+)(?:的比例)?分給(.+?)(?:可以)?(?:拿|分到|得到)(?:多少|幾元|幾塊)(?:錢|元)?$"#),
              let total = Double(g[0]) else { return nil }
        let ks = g[1].split(separator: ":").compactMap { Double($0) }
        // 「家豪、怡君、小明，家豪」或沒有逗號的「家豪、怡君、小明家豪」：最後一段拆成「最後一個人＋問的人」
        var names = g[2].replacingOccurrences(of: ",", with: "，").split(separator: "、").map(String.init)
        guard ks.count >= 2, names.count == ks.count, var last = names.popLast() else { return nil }
        var asked = ""
        if let r = last.range(of: "，") { asked = String(last[r.upperBound...]); last = String(last[..<r.lowerBound]) } else {
            for n in names + [String(last.prefix(last.count / 2))] where last.count > n.count && last.hasSuffix(n) {
                asked = n; last = String(last.dropLast(n.count)); break
            }
        }
        names.append(last)
        guard let i = names.firstIndex(of: asked) else { return nil }
        let sum = ks.reduce(0, +), unit = total / sum
        return "總共 \(num(sum)) 份，一份 \(num(total))÷\(num(sum))＝\(num(unit)) 元；\(asked)拿 \(num(ks[i])) 份，\(num(ks[i]))×\(num(unit))＝\(num(ks[i] * unit)) 元。"
    }

    static func rectangle(_ t: String) -> String? {
        guard let g = groups(t, #"^長([\d.]+)(公分|公尺|公里|cm|m)[,，]?[,，、]?寬([\d.]+)(?:公分|公尺|公里|cm|m)的長方形[,，]?(?:的)?(周長|面積)(?:是)?(?:多少|幾)"#),
              let a = Double(g[0]), let b = Double(g[2]) else { return nil }
        if g[3] == "周長" { return "周長＝(長＋寬)×2＝(\(num(a))＋\(num(b)))×2＝\(num(2 * (a + b)))\(g[1])。" }
        return "面積＝長×寬＝\(num(a))×\(num(b))＝\(num(a * b))平方\(g[1])。"
    }

    static func interest(_ t: String) -> String? {
        guard let g = groups(t, #"^本金([\d.]+)元[,，]?年利率([\d.]+)%[,，]?單利(?:存)?(\d+)年[,，]?(?:的)?利息(?:是)?(?:多少|幾元)"#),
              let p = Double(g[0]), let r = Double(g[1]), let y = Double(g[2]) else { return nil }
        return "單利利息＝本金×年利率×年數＝\(num(p))×\(num(r))%×\(num(y))＝\(num(p * r / 100 * y)) 元。"
    }

    // MARK: - 原子序

    static let elements: [(Int, String, String)] = [
        (1, "H", "氫"), (2, "He", "氦"), (3, "Li", "鋰"), (4, "Be", "鈹"), (5, "B", "硼"), (6, "C", "碳"), (7, "N", "氮"), (8, "O", "氧"), (9, "F", "氟"),
        (10, "Ne", "氖"), (11, "Na", "鈉"), (12, "Mg", "鎂"), (13, "Al", "鋁"), (14, "Si", "矽"), (15, "P", "磷"), (16, "S", "硫"), (17, "Cl", "氯"),
        (18, "Ar", "氬"), (19, "K", "鉀"), (20, "Ca", "鈣"), (21, "Sc", "鈧"), (22, "Ti", "鈦"), (23, "V", "釩"), (24, "Cr", "鉻"), (25, "Mn", "錳"),
        (26, "Fe", "鐵"), (27, "Co", "鈷"), (28, "Ni", "鎳"), (29, "Cu", "銅"), (30, "Zn", "鋅"), (31, "Ga", "鎵"), (32, "Ge", "鍺"), (33, "As", "砷"),
        (34, "Se", "硒"), (35, "Br", "溴"), (36, "Kr", "氪"), (37, "Rb", "銣"), (38, "Sr", "鍶"), (39, "Y", "釔"), (40, "Zr", "鋯"), (41, "Nb", "鈮"),
        (42, "Mo", "鉬"), (43, "Tc", "鎝"), (44, "Ru", "釕"), (45, "Rh", "銠"), (46, "Pd", "鈀"), (47, "Ag", "銀"), (48, "Cd", "鎘"), (49, "In", "銦"),
        (50, "Sn", "錫"), (51, "Sb", "銻"), (52, "Te", "碲"), (53, "I", "碘"), (54, "Xe", "氙"), (55, "Cs", "銫"), (56, "Ba", "鋇"), (78, "Pt", "鉑（白金）"),
        (79, "Au", "金"), (80, "Hg", "汞（水銀）"), (82, "Pb", "鉛"), (86, "Rn", "氡"), (92, "U", "鈾"),
    ]

    static func element(_ t: String) -> String? {
        guard let g = groups(t, #"^原子序(?:是|為)?(\d{1,3})(?:號)?(?:的)?(?:是)?(?:什麼|哪個|哪一個|哪種)(?:元素)?$"#), let n = Int(g[0]),
              let e = elements.first(where: { $0.0 == n }) else { return nil }
        return "原子序 \(n) 是\(e.2)，化學符號 \(e.1)。"
    }
}
