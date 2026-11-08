import Foundation

/// 有標準答案、用算的就知道的題目：大腦（小模型）很常算錯或亂猜，引擎直接算給它。
/// 某年生肖、某年干支、日期加幾天、兩個日期差幾天、地支沖合、按比例分錢、長方形面積周長、單利利息、原子序、
/// 轉向後面向哪、時針分針夾角、幾點再過幾小時、親戚稱謂、繩子對折剪一刀。
/// 前後的口頭禪（「認真問：」「考考你：」「不要騙我」「拜託」「快」）先拿掉再看。
public enum QuickCalc {
    public static func answer(_ raw: String) -> String? {
        let t = strip(raw)
        guard !t.isEmpty, t.count <= 60 else { return nil }
        for f in [zodiacYear, ganzhiYear, dateAdd, dateDiff, branchClash, branchHarmony, share, rectangle, interest, element, facing, clockAngle, timeAdd, kinship, ropeCut, zhuyinFill, polyphone, weekday, chickenRabbit, rate] {
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
        guard let g = groups(t, #"^原子序(?:是|為)?(\d{1,3})(?:號)?(?:的)?(?:是)?(?:什麼|哪個|哪一個|哪種)(?:元素)?$"#)
                ?? groups(t, #"^(?:週期表上?的?)?第(\d{1,3})號(?:化學)?元素(?:是)?(?:什麼|哪個|哪一個|哪種)?(?:元素)?$"#), let n = Int(g[0]),
              let e = elements.first(where: { $0.0 == n }) else { return nil }
        return "原子序 \(n) 是\(e.2)，化學符號 \(e.1)。"
    }

    // MARK: - 小邏輯題

    static let weekNames = ["一", "二", "三", "四", "五", "六", "日"]

    /// 今天星期一，三天前／五天後是星期幾
    static func weekday(_ t: String) -> String? {
        guard let g = groups(t, #"^(?:如果)?(今天|明天|昨天)(?:是)?(?:星期|禮拜|週)([一二三四五六日天])[,，]?(?:那)?(?:再過)?([0-9一二三四五六七八九十百兩]+)天(前|後|之前|之後|以前|以後)?(?:是|會是)?(?:星期|禮拜|週)幾$"#),
              var d = weekNames.firstIndex(of: g[1] == "天" ? "日" : g[1]), let k = n(g[2]) else { return nil }
        if g[0] == "明天" { d -= 1 } else if g[0] == "昨天" { d += 1 }
        let back = g[3].hasSuffix("前")
        let w = ((d + (back ? -k : k)) % 7 + 7) % 7
        let w0 = weekNames[(d % 7 + 7) % 7]
        let given = g[0] == "今天" ? "" : "\(g[0])是星期\(g[1] == "天" ? "日" : g[1])，"
        return given + "今天是星期\(w0)，\(k) 天\(back ? "前" : "後")是星期\(weekNames[w])。"
    }

    /// 雞兔同籠：共有 H 個頭、F 隻腳，雞和兔各幾隻
    static func chickenRabbit(_ t: String) -> String? {
        guard t.contains("雞"), t.contains("兔"), let g = groups(t, #"([0-9]+)(?:個|顆)頭.*?([0-9]+)(?:隻|條)腳"#),
              let h = Int(g[0]), let f = Int(g[1]) else { return nil }
        let rabbits = (f - 2 * h) / 2, chickens = h - rabbits
        guard (f - 2 * h) % 2 == 0, rabbits >= 0, chickens >= 0 else { return "這組數字湊不出來：\(h) 個頭最少 \(2 * h) 隻腳、最多 \(4 * h) 隻腳，而且腳數要是雙數。" }
        return "雞 \(chickens) 隻、兔 \(rabbits) 隻。\n假設全部是雞：\(h) × 2 = \(2 * h) 隻腳，比實際少 \(f - 2 * h) 隻；每把一隻雞換成兔多 2 隻腳，所以兔 = \(f - 2 * h) ÷ 2 = \(rabbits) 隻，雞 = \(h) − \(rabbits) = \(chickens) 隻。"
    }

    /// 三個人三天吃三個蘋果，九個人九天吃幾個（工作量 ∝ 人數 × 天數）
    static func rate(_ t: String) -> String? {
        let nn = "([0-9一二三四五六七八九十百兩]+)"
        guard let g = groups(t, "^" + nn + "(?:個|位|名)?(人|隻貓|隻雞|隻|台機器|台)" + nn + "(天|小時|分鐘)(?:能|可以|會)?(吃|做|喝|生|印|蓋|挖|搬|寫|摺)(?:完|了)?" + nn + "(個|顆|條|件|瓶|杯|頁|隻|張|塊|間|袋|箱|顆蛋)([^,，]{0,3})[,，]?(?:那|照這樣)?(?:麼)?" + nn + "(?:個|位|名)?\\2?" + nn + "\\4(?:能|可以|會)?\\5?(?:完|了)?(?:幾|多少)"),
              let a = n(g[0]), let d = n(g[2]), let c = n(g[5]), let a2 = n(g[8]), let d2 = n(g[9]), a > 0, d > 0 else { return nil }
        let x = Double(c) * Double(a2) * Double(d2) / (Double(a) * Double(d))
        let what = g[6] + g[7]
        return "\(num(x)) \(what)。\n\(g[4])的量跟數量和時間成正比：\(c) × (\(a2) × \(d2)) ÷ (\(a) × \(d)) = \(num(x)) \(what)。"
    }

    /// 「一」「十二」或「3」→ 數字
    static func n(_ w: String) -> Int? { Int(w) ?? ProfileParser.cnNumber(w) }

    static let dirs = ["北", "東", "南", "西"]

    /// 面向東，向後轉／向左轉再向右轉 → 面向哪裡
    static func facing(_ t: String) -> String? {
        guard let g = groups(t, #"^(?:一個人|我|他|她|小明)?(?:面向|面朝|面對|朝)([東南西北])(?:方)?[,，]?(.+?)(?:之?後)?(?:會)?(?:面向|面朝|朝|面對)(?:哪裡|哪邊|哪個方向|哪一個方向|什麼方向|哪方)$"#),
              var i = dirs.firstIndex(of: g[0]) else { return nil }
        guard let re = try? NSRegularExpression(pattern: #"(?:向|往)?(左|右|後)轉"#) else { return nil }
        let ms = re.matches(in: g[1], range: NSRange(g[1].startIndex..., in: g[1]))
        guard !ms.isEmpty else { return nil }
        for m in ms {
            guard let r = Range(m.range(at: 1), in: g[1]) else { return nil }
            switch g[1][r] { case "右": i += 1; case "左": i += 3; default: i += 2 }
        }
        return "原本面向\(g[0])，轉完之後面向\(dirs[i % 4])。"
    }

    /// 鐘面上 6 點整（3 點半、9 點 15 分），時針和分針的夾角
    static func clockAngle(_ t: String) -> String? {
        guard t.contains("夾角") || t.contains("角度"), t.contains("針"),
              let g = groups(t, #"(\d{1,2}|[一二兩三四五六七八九十]{1,3})(?:點|時)(整|半|(\d{1,2})分)?"#),
              let h0 = n(g[0]), h0 <= 24 else { return nil }
        let m = g[1] == "半" ? 30 : (Int(g[2]) ?? 0)
        guard m < 60 else { return nil }
        let h = h0 % 12
        var a = abs(Double(h * 30) - 5.5 * Double(m))
        if a > 180 { a = 360 - a }
        let when = m == 0 ? "\(h0) 點整" : "\(h0) 點 \(m) 分"
        return "\(when)：時針在 \(num(Double(h * 30) + 0.5 * Double(m))) 度、分針在 \(m * 6) 度，夾角是 \(num(a)) 度。"
    }

    static func clock(_ h: Int) -> String {
        let p = h < 5 ? "凌晨" : h < 12 ? "早上" : h == 12 ? "中午" : h < 18 ? "下午" : "晚上"
        let d = h % 12 == 0 ? 12 : h % 12
        return "\(p)\(d)點"
    }

    /// 現在下午 3 點，再過 10 個小時是幾點
    static func timeAdd(_ t: String) -> String? {
        guard let g = groups(t, #"(凌晨|半夜|早上|上午|中午|下午|傍晚|晚上)?(\d{1,2}|[一二兩三四五六七八九十]{1,3})點(?:整)?[,，]?(?:再)?(?:過|經過|加)(\d{1,3}|[一二兩三四五六七八九十]{1,3})(?:個)?(?:小時|鐘頭)(?:後|之後|以後)?(?:是|會是)?(?:幾點|什麼時候|幾點鐘)$"#),
              var h = n(g[1]), h <= 24, let d = n(g[2]) else { return nil }
        if ["下午", "傍晚", "晚上"].contains(g[0]) && h < 12 { h += 12 }
        if g[0] == "中午" && h < 11 { h += 12 }
        if ["凌晨", "半夜"].contains(g[0]) && h == 12 { h = 0 }
        let e = h + d, days = e / 24
        let next = days == 0 ? "" : days == 1 ? "隔天" : "\(days) 天後的"
        return "\(clock(h % 24))再過 \(d) 小時，是\(next)\(clock(e % 24))（\(e % 24):00）。"
    }

    static let kin: [String: String] = [
        "爸爸的爸爸": "爺爺（祖父）", "爸爸的媽媽": "奶奶（祖母）", "媽媽的爸爸": "外公（外祖父）", "媽媽的媽媽": "外婆（外祖母）",
        "爸爸的哥哥": "伯伯（伯父）", "爸爸的弟弟": "叔叔（叔父）", "爸爸的姊姊": "姑姑（姑媽）", "爸爸的姐姐": "姑姑（姑媽）", "爸爸的妹妹": "姑姑（姑姑）",
        "媽媽的哥哥": "舅舅", "媽媽的弟弟": "舅舅", "媽媽的姊姊": "阿姨（姨媽）", "媽媽的姐姐": "阿姨（姨媽）", "媽媽的妹妹": "阿姨",
        "爸爸的爸爸的爸爸": "曾祖父（阿祖）", "哥哥的兒子": "姪子", "弟弟的兒子": "姪子", "哥哥的女兒": "姪女", "弟弟的女兒": "姪女",
        "姊姊的兒子": "外甥", "姐姐的兒子": "外甥", "妹妹的兒子": "外甥", "姊姊的女兒": "外甥女", "姐姐的女兒": "外甥女", "妹妹的女兒": "外甥女",
        "爸爸的哥哥的兒子": "堂哥或堂弟（看年紀）", "爸爸的弟弟的兒子": "堂哥或堂弟（看年紀）", "媽媽的哥哥的兒子": "表哥或表弟（看年紀）",
        "媽媽的姊姊的女兒": "表姊或表妹（看年紀）", "老婆的爸爸": "岳父", "老婆的媽媽": "岳母", "老公的爸爸": "公公", "老公的媽媽": "婆婆",
        "兒子的兒子": "孫子", "兒子的女兒": "孫女", "女兒的兒子": "外孫", "女兒的女兒": "外孫女", "哥哥的老婆": "大嫂（嫂嫂）", "弟弟的老婆": "弟媳",
        "姊姊的老公": "姊夫", "姐姐的老公": "姊夫", "妹妹的老公": "妹夫",
    ]

    /// 爸爸的爸爸叫什麼；哥哥的兒子叫我什麼（我是男生）
    static func kinship(_ t: String) -> String? {
        let u = t.replacingOccurrences(of: "父親", with: "爸爸").replacingOccurrences(of: "母親", with: "媽媽")
            .replacingOccurrences(of: "我的", with: "").replacingOccurrences(of: "你的", with: "")
        if let g = groups(u, #"^((?:(?:爸爸|媽媽|哥哥|弟弟|姊姊|姐姐|妹妹|兒子|女兒|老婆|老公)的)+(?:爸爸|媽媽|哥哥|弟弟|姊姊|姐姐|妹妹|兒子|女兒|老婆|老公))(?:要)?(?:叫|稱呼|是)(?:什麼|做什麼|我的什麼|誰)$"#),
           let k = kin[g[0]] {
            return "\(g[0])叫\(k)。"
        }
        // 反過來：他們叫我什麼
        guard let g = groups(u, #"^(哥哥|弟弟|姊姊|姐姐|妹妹)的(兒子|女兒|小孩)(?:要)?(?:叫|稱呼)我(?:什麼)[（(]?(?:我是)?(男生|女生|男的|女的)?[）)]?$"#) else { return nil }
        let mySide = g[0].hasSuffix("哥") || g[0].hasSuffix("弟")   // 兄弟的小孩：我是叔叔／伯伯或姑姑
        let male: Bool? = g[2].isEmpty ? nil : g[2].hasPrefix("男")
        let older = !(g[0] == "哥哥" || g[0] == "姊姊" || g[0] == "姐姐")   // 我比對方大
        let title: String
        switch (mySide, male) {
        case (true, true?): title = older ? "伯伯（伯父）" : "叔叔"
        case (true, false?): title = "姑姑"
        case (false, true?): title = "舅舅"
        case (false, false?): title = "阿姨"
        case (true, nil): title = older ? "伯伯（男生）或姑姑（女生）" : "叔叔（男生）或姑姑（女生）"
        case (false, nil): title = "舅舅（男生）或阿姨（女生）"
        }
        return "\(g[0])的\(g[1])叫你\(title)。"
    }

    /// 一根繩子對折再對折，從中間剪一刀，變成幾段：對折 k 次是 2^k 層，一刀切 2^k 個口 → 2^k＋1 段
    static func ropeCut(_ t: String) -> String? {
        guard t.contains("繩") || t.contains("線"), t.contains("剪一刀") || t.contains("剪1刀") || t.contains("切一刀"),
              t.contains("幾段") || t.contains("多少段") else { return nil }
        var k = t.components(separatedBy: "對折").count - 1
        if let g = groups(t, #"對折(\d|[一二兩三四五六])次"#), let c = n(g[0]) { k = c }
        guard (1...6).contains(k) else { return nil }
        let layers = 1 << k
        return "對折 \(k) 次是 \(layers) 層，剪一刀會剪斷 \(layers) 個地方，所以變成 \(layers)＋1＝\(layers + 1) 段。"
    }

    // MARK: - 國字：注音填字、多音字

    /// 常用但不在成語表裡的詞（注音填字用）
    static let commonWords = ["迫不及待", "再接再厲", "一帆風順", "按部就班", "一鼓作氣", "名列前茅", "義不容辭", "走投無路", "一籌莫展",
                              "迫在眉睫", "既往不咎", "不可思議", "莫名其妙", "罄竹難書", "首當其衝", "如火如荼", "炙手可熱", "差強人意",
                              "美輪美奐", "七嘴八舌", "一臂之力", "語重心長", "專心致志", "興高采烈", "金榜題名", "鴉雀無聲"]

    /// 「再接再ㄌㄧˋ」的ㄌㄧˋ是哪個字：把注音當成一個字，到成語表裡找唯一對得上的
    static func zhuyinFill(_ t: String) -> String? {
        guard let g = groups(t, #"^(.+?)的([ㄅ-ㄩ˙ˊˇˋ]+)是(?:哪個|哪一個|什麼)字$"#), g[0].contains(g[1]) else { return nil }
        let parts = g[0].components(separatedBy: g[1])
        guard parts.count == 2, parts.joined().count >= 2 else { return nil }
        let n = parts[0].count + parts[1].count + 1
        let pool = Set(Idioms.names + commonWords)
        let hits = pool.filter { $0.count == n && $0.hasPrefix(parts[0]) && $0.hasSuffix(parts[1]) }
        guard hits.count == 1, let w = hits.first else { return nil }
        let c = w[w.index(w.startIndex, offsetBy: parts[0].count)]
        return "「\(w)」，\(g[1])是「\(c)」。"
    }

    /// 多音字：(字, 詞, 注音, 拼音)
    static let readings: [(String, String, String, String)] = [
        ("長", "校長", "ㄓㄤˇ", "zhǎng"), ("長", "長大", "ㄓㄤˇ", "zhǎng"), ("長", "長度", "ㄔㄤˊ", "cháng"), ("長", "長短", "ㄔㄤˊ", "cháng"),
        ("樂", "音樂", "ㄩㄝˋ", "yuè"), ("樂", "樂器", "ㄩㄝˋ", "yuè"), ("樂", "快樂", "ㄌㄜˋ", "lè"), ("樂", "樂觀", "ㄌㄜˋ", "lè"),
        ("行", "銀行", "ㄏㄤˊ", "háng"), ("行", "行業", "ㄏㄤˊ", "háng"), ("行", "行走", "ㄒㄧㄥˊ", "xíng"), ("行", "旅行", "ㄒㄧㄥˊ", "xíng"),
        ("重", "重要", "ㄓㄨㄥˋ", "zhòng"), ("重", "重新", "ㄔㄨㄥˊ", "chóng"), ("重", "重複", "ㄔㄨㄥˊ", "chóng"),
        ("好", "好人", "ㄏㄠˇ", "hǎo"), ("好", "愛好", "ㄏㄠˋ", "hào"), ("好", "好奇", "ㄏㄠˋ", "hào"),
        ("還", "還錢", "ㄏㄨㄢˊ", "huán"), ("還", "還有", "ㄏㄞˊ", "hái"),
        ("覺", "睡覺", "ㄐㄧㄠˋ", "jiào"), ("覺", "覺得", "ㄐㄩㄝˊ", "jué"), ("覺", "感覺", "ㄐㄩㄝˊ", "jué"),
        ("都", "首都", "ㄉㄨ", "dū"), ("都", "都市", "ㄉㄨ", "dū"), ("都", "都是", "ㄉㄡ", "dōu"),
        ("便", "便宜", "ㄆㄧㄢˊ", "pián"), ("便", "方便", "ㄅㄧㄢˋ", "biàn"),
        ("數", "數學", "ㄕㄨˋ", "shù"), ("數", "數一數", "ㄕㄨˇ", "shǔ"),
        ("了", "了解", "ㄌㄧㄠˇ", "liǎo"), ("了", "走了", "˙ㄌㄜ", "le"), ("了", "吃飯了", "˙ㄌㄜ", "le"),
        ("得", "得到", "ㄉㄜˊ", "dé"), ("得", "跑得快", "˙ㄉㄜ", "de"), ("得", "覺得", "˙ㄉㄜ", "de"),
        ("地", "慢慢地", "˙ㄉㄜ", "de"), ("地", "地方", "ㄉㄧˋ", "dì"), ("地", "土地", "ㄉㄧˋ", "dì"),
        ("的", "我的", "˙ㄉㄜ", "de"), ("的", "目的", "ㄉㄧˋ", "dì"), ("的", "的確", "ㄉㄧˊ", "dí"),
        ("會", "會計", "ㄎㄨㄞˋ", "kuài"), ("會", "開會", "ㄏㄨㄟˋ", "huì"),
        ("藏", "西藏", "ㄗㄤˋ", "zàng"), ("藏", "寶藏", "ㄗㄤˋ", "zàng"), ("藏", "收藏", "ㄘㄤˊ", "cáng"), ("藏", "躲藏", "ㄘㄤˊ", "cáng"),
        ("傳", "傳說", "ㄔㄨㄢˊ", "chuán"), ("傳", "自傳", "ㄓㄨㄢˋ", "zhuàn"),
        ("差", "差不多", "ㄔㄚˋ", "chà"), ("差", "出差", "ㄔㄞ", "chāi"), ("差", "差別", "ㄔㄚ", "chā"),
        ("調", "調查", "ㄉㄧㄠˋ", "diào"), ("調", "調整", "ㄊㄧㄠˊ", "tiáo"),
        ("朝", "朝代", "ㄔㄠˊ", "cháo"), ("朝", "朝陽", "ㄓㄠ", "zhāo"),
        ("角", "角色", "ㄐㄩㄝˊ", "jué"), ("角", "角落", "ㄐㄧㄠˇ", "jiǎo"),
        ("乾", "乾淨", "ㄍㄢ", "gān"), ("乾", "乾坤", "ㄑㄧㄢˊ", "qián"),
        ("率", "效率", "ㄌㄩˋ", "lǜ"), ("率", "率領", "ㄕㄨㄞˋ", "shuài"),
        ("種", "種類", "ㄓㄨㄥˇ", "zhǒng"), ("種", "種田", "ㄓㄨㄥˋ", "zhòng"),
        ("為", "為什麼", "ㄨㄟˋ", "wèi"), ("為", "作為", "ㄨㄟˊ", "wéi"), ("為", "認為", "ㄨㄟˊ", "wéi"),
        ("空", "天空", "ㄎㄨㄥ", "kōng"), ("空", "空閒", "ㄎㄨㄥˋ", "kòng"),
        ("興", "高興", "ㄒㄧㄥˋ", "xìng"), ("興", "興奮", "ㄒㄧㄥ", "xīng"),
        ("降", "投降", "ㄒㄧㄤˊ", "xiáng"), ("降", "下降", "ㄐㄧㄤˋ", "jiàng"),
        ("處", "處理", "ㄔㄨˇ", "chǔ"), ("處", "到處", "ㄔㄨˋ", "chù"),
        ("給", "給你", "ㄍㄟˇ", "gěi"), ("給", "供給", "ㄐㄧˇ", "jǐ"),
        ("看", "看守", "ㄎㄢ", "kān"), ("看", "看書", "ㄎㄢˋ", "kàn"),
        ("教", "教書", "ㄐㄧㄠ", "jiāo"), ("教", "教育", "ㄐㄧㄠˋ", "jiào"),
        ("背", "背包", "ㄅㄟ", "bēi"), ("背", "背後", "ㄅㄟˋ", "bèi"),
        ("發", "頭髮", "ㄈㄚˇ", "fǎ"), ("曲", "歌曲", "ㄑㄩˇ", "qǔ"), ("曲", "彎曲", "ㄑㄩ", "qū"),
    ]

    /// 「長」在「校長」裡念什麼；「慢慢地」的「地」怎麼念
    static func polyphone(_ t: String) -> String? {
        var ch = "", word = ""
        if let g = groups(t, #"^(.)在(.{2,5}?)(?:這個詞)?(?:裡|中|裡面|裡頭)?(?:要|應該)?(?:念|讀|唸|發音)(?:什麼|作什麼|成什麼|哪個音|幾聲)?$"#) { ch = g[0]; word = g[1] }
        else if let g = groups(t, #"^(.{2,5}?)的(.)(?:要|應該)?(?:怎麼|如何)(?:念|讀|唸|發音)$|^(.{2,5}?)的(.)(?:念|讀|唸)(?:什麼|幾聲)$"#) {
            word = g[0].isEmpty ? g[2] : g[0]; ch = g[0].isEmpty ? g[3] : g[1]
        }
        guard !ch.isEmpty, word.contains(ch), let r = readings.first(where: { $0.0 == ch && $0.1 == word }) else { return nil }
        let others = readings.filter { $0.0 == ch && $0.2 != r.2 }.map { "\($0.1)的\($0.0)念\($0.2)" }
        let extra = others.isEmpty ? "" : "（多音字：" + Array(Set(others)).sorted().prefix(2).joined(separator: "、") + "。）"
        return "「\(word)」的「\(ch)」念 \(r.2)（\(r.3)）。" + extra
    }
}
