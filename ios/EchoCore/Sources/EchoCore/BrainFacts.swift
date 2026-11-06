import Foundation

/// 大腦考試找到的弱點：小模型背不熟的表格和算不準的公式，由 NineSun 的引擎先算好，當成資料交給大腦。
/// - 命理：十神（日主看某天干）、五行生剋、生年四化、天干地支的五行
/// - 健康數字：BMI、血壓、空腹血糖、糖化血色素、體溫（台灣衛福部／2022 高血壓指引的標準）
public enum BrainFacts {
    static let wx = ["木", "火", "土", "金", "水"]

    public static func notes(_ text: String) -> [String] {
        var out: [String] = []
        out += fortune(text)
        out += health(text)
        out += reasoning(text)
        return out
    }

    static let nayin = ["海中金", "爐中火", "大林木", "路旁土", "劍鋒金", "山頭火", "澗下水", "城頭土", "白蠟金", "楊柳木",
                        "泉中水", "屋上土", "霹靂火", "松柏木", "長流水", "沙中金", "山下火", "平地木", "壁上土", "金箔金",
                        "覆燈火", "天河水", "大驛土", "釵釧金", "桑柘木", "大溪水", "沙中土", "天上火", "石榴木", "大海水"]
    static let liuhe: [Set<Int>: String] = [[0, 1]: "土", [2, 11]: "木", [3, 10]: "火", [4, 9]: "金", [5, 8]: "水", [6, 7]: "土（一說火）"]
    static let chong: [Set<Int>] = [[0, 6], [1, 7], [2, 8], [3, 9], [4, 10], [5, 11]]
    static let hai: [Set<Int>] = [[0, 7], [1, 6], [2, 5], [3, 4], [8, 11], [9, 10]]
    static let sanhe: [(Set<Int>, String)] = [([8, 0, 4], "水"), ([11, 3, 7], "木"), ([2, 6, 10], "火"), ([5, 9, 1], "金")]

    // MARK: - 命理

    static func fortune(_ t: String) -> [String] {
        var out: [String] = []
        let stems = GZ.stems, branches = GZ.branches
        // 十神：「日主甲看到乙」「甲日主，乙是什麼十神」
        if t.contains("十神") || t.contains("日主") {
            let found = t.compactMap { c -> Int? in stems.firstIndex(of: String(c)) }
            if found.count >= 2 {
                var dm = found[0], other = found[1]
                // 「乙，甲日主」這種：緊接著「日主」的才是日主
                if let r = t.range(of: "日主") {
                    let before = t[..<r.lowerBound].last.flatMap { stems.firstIndex(of: String($0)) }
                    let after = t[r.upperBound...].first.flatMap { stems.firstIndex(of: String($0)) }
                    if let d = before ?? after { dm = d; other = found.first { $0 != d } ?? found[1] }
                }
                let god = BaZi.tenGod(dayStem: dm, other: other)
                out.append("十神（NineSun 算的）：日主\(stems[dm])（\(yy(dm))\(wx[BaZi.stemEl[dm]])）看到\(stems[other])（\(yy(other))\(wx[BaZi.stemEl[other]])）是「\(god)」。")
            }
        }
        // 五行生剋：「木生什麼」「什麼剋金」
        if t.contains("生") || t.contains("剋") || t.contains("克") {
            for (i, w) in wx.enumerated() {
                let pairs: [String] = [w + "生", w + "剋", w + "克", "生" + w, "剋" + w, "克" + w]
                guard pairs.contains(where: { t.contains($0) }) else { continue }
                out.append("五行（NineSun 的資料）：\(w)生\(wx[(i + 1) % 5])、\(w)剋\(wx[(i + 2) % 5])；生\(w)的是\(wx[(i + 4) % 5])、剋\(w)的是\(wx[(i + 3) % 5])。")
            }
        }
        // 納音：「甲辰的納音」「己未是什麼命」
        if t.contains("納音") || t.contains("什麼命") || t.contains("年命") {
            let cs = Array(t)
            for i in 0..<(max(0, cs.count - 1)) {
                if let a = stems.firstIndex(of: String(cs[i])), let b = branches.firstIndex(of: String(cs[i + 1])), a % 2 == b % 2 {
                    let g = GZ.index(stem: a, branch: b)
                    out.append("納音（NineSun 的資料）：\(stems[a])\(branches[b])的納音是「\(nayin[g / 2])」，五行屬\(nayin[g / 2].suffix(1))。")
                }
            }
        }
        // 地支的合、沖、害：「巳和申是六合嗎」「卯戌合化什麼」
        if ["合", "沖", "冲", "害", "刑"].contains(where: { t.contains($0) }) {
            let bs = t.compactMap { branches.firstIndex(of: String($0)) }
            let uniq = Array(NSOrderedSet(array: bs)) as? [Int] ?? bs
            if uniq.count >= 2 {
                for i in 0..<uniq.count { for j in (i + 1)..<uniq.count {
                    let p: Set<Int> = [uniq[i], uniq[j]]
                    let name = branches[uniq[i]] + branches[uniq[j]]
                    if let el = liuhe[p] { out.append("地支（NineSun 的資料）：\(name)是六合，合化\(el)。") }
                    if chong.contains(p) { out.append("地支（NineSun 的資料）：\(name)是六沖（相沖）。") }
                    if hai.contains(p) { out.append("地支（NineSun 的資料）：\(name)是六害（相害）。") }
                    if liuhe[p] == nil && !chong.contains(p) && !hai.contains(p) { out.append("地支（NineSun 的資料）：\(name)不是六合、六沖，也不是六害。") }
                } }
                for (tri, el) in sanhe where tri.isSubset(of: Set(uniq)) {
                    out.append("地支（NineSun 的資料）：" + tri.sorted().map { branches[$0] }.joined() + "三合\(el)局。")
                }
            }
        }
        // 生年四化：「甲年生的四化」
        if t.contains("四化") || t.contains("化祿") || t.contains("化忌") {
            for (i, s) in stems.enumerated() where t.contains(s + "年") || t.contains("天干" + s) {
                if let four = ZiWei.sihua[s] {
                    out.append("生年四化（NineSun 的資料）：\(stems[i])年 \(four[0])化祿、\(four[1])化權、\(four[2])化科、\(four[3])化忌。")
                }
            }
        }
        // 天干、地支屬什麼
        if t.contains("天干") || t.contains("五行") || t.contains("陰陽") {
            for (i, s) in stems.enumerated() where t.contains(s) {
                out.append("天干\(s)：\(yy(i))\(wx[BaZi.stemEl[i]])。")
            }
        }
        if t.contains("地支") || t.contains("生肖") || t.contains("時是") || t.contains("屬什麼") {
            let animals = Array("鼠牛虎兔龍蛇馬羊猴雞狗豬").map(String.init)
            for (i, b) in branches.enumerated() where t.contains(b) && (t.contains("地支") || t.contains(b + "時") || t.contains(b + "年")) {
                out.append("地支\(b)：\(i % 2 == 0 ? "陽" : "陰")\(wx[BaZi.branchEl[i]])，生肖\(animals[i])，\(b)時是\((i * 2 + 23) % 24)點到\((i * 2 + 1) % 24)點。")
            }
        }
        return out
    }

    static func yy(_ stem: Int) -> String { stem % 2 == 0 ? "陽" : "陰" }

    // MARK: - 健康數字

    static func nums(_ t: String, _ pattern: String) -> [Double]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) else { return nil }
        return (1..<m.numberOfRanges).compactMap { i in Range(m.range(at: i), in: t).flatMap { Double(t[$0]) } }
    }

    static func health(_ raw: String) -> [String] {
        let t = raw.replacingOccurrences(of: " ", with: "")
        var out: [String] = []
        // BMI：身高 150～200 公分、體重 30～200 公斤
        var hw: (Double, Double)?
        if let v = nums(t, #"身高(\d{3}(?:\.\d)?)(?:公分|cm)?[，,、]?體重(\d{2,3}(?:\.\d)?)"#), v.count == 2 { hw = (v[0], v[1]) }
        else if let v = nums(t, #"(\d{3}(?:\.\d)?)(?:公分|cm)[，,、]?(\d{2,3}(?:\.\d)?)(?:公斤|kg)"#), v.count == 2 { hw = (v[0], v[1]) }
        else if let v = nums(t, #"體重(\d{2,3}(?:\.\d)?)(?:公斤|kg)?[，,、]?身高(\d{3}(?:\.\d)?)"#), v.count == 2 { hw = (v[1], v[0]) }
        if let (h, w) = hw, (120...230).contains(h), (20...250).contains(w) {
            let m = h / 100, bmi = w / (m * m)
            let cat = bmi < 18.5 ? "過輕" : bmi < 24 ? "正常範圍" : bmi < 27 ? "過重" : "肥胖"
            out.append(String(format: "BMI（NineSun 算的）：%.0f ÷ (%.2f)² = %.1f，屬於「%@」（台灣標準：未滿 18.5 過輕、18.5～24 正常、24～27 過重、27 以上肥胖）；這個身高的正常體重約 %.1f～%.1f 公斤。",
                              w, m, bmi, cat, 18.5 * m * m, 24 * m * m))
        }
        // 血壓
        var bp: (Double, Double)?
        if let v = nums(t, #"收縮壓(\d{2,3})[，,、]?舒張壓(\d{2,3})"#), v.count == 2 { bp = (v[0], v[1]) }
        else if let v = nums(t, #"(?<!\d)(\d{2,3})/(\d{2,3})(?!\d)"#), v.count == 2, t.contains("血壓") || t.contains("量到") || t.contains("mmHg") { bp = (v[0], v[1]) }
        if let (s, d) = bp, (60...260).contains(s), (30...160).contains(d) {
            let cat: String
            if s >= 180 || d >= 120 { cat = "非常高（危急值）：休息 5 分鐘再量，還是這麼高或有頭痛、胸痛、喘、手腳無力就立刻就醫" }
            else if s >= 130 || d >= 80 { cat = "高血壓（台灣 2022 指引：在家量 130/80 以上）：照 722 原則量一週給醫師看" }
            else if s >= 120 { cat = "偏高（120～129／80 以下）：還不到高血壓，要開始少鹽、運動" }
            else if s < 90 || d < 60 { cat = "偏低：沒有不舒服通常不用擔心，頭暈快暈倒要就醫" }
            else { cat = "理想（低於 120/80）" }
            out.append("血壓（NineSun 判斷的）：\(Int(s))/\(Int(d)) mmHg 屬於\(cat)。回答時直接說出這個分類，不要輕描淡寫。")
        }
        if let v = nums(t, #"空腹血糖(?:驗出來|是|有)?(\d{2,3})"#), let g = v.first {
            let cat = g < 70 ? "低血糖" : g < 100 ? "正常" : g < 126 ? "糖尿病前期" : "可能是糖尿病（要另一天再驗一次確認）"
            out.append("空腹血糖（NineSun 判斷的）：\(Int(g)) mg/dL 屬於\(cat)（低於 70 低血糖、70～99 正常、100～125 前期、126 以上可能是糖尿病）。")
        }
        if let v = nums(t, #"(?:糖化血色素|HbA1c|A1c)(\d{1,2}(?:\.\d)?)"#), let a = v.first {
            let cat = a < 5.7 ? "正常" : a < 6.5 ? "糖尿病前期" : "達到糖尿病的標準（要醫師確認）"
            out.append("糖化血色素（NineSun 判斷的）：\(a)% 屬於\(cat)（低於 5.7% 正常、5.7～6.4% 前期、6.5% 以上糖尿病）。")
        }
        if let v = nums(t, #"(?:耳溫|體溫|口溫|額溫|發燒)(\d{2}(?:\.\d)?)度"#), let c = v.first, (34...43).contains(c) {
            let cat = c < 37.5 ? "沒有發燒" : c < 38 ? "稍高（還不算發燒）" : c < 39 ? "發燒" : c < 40 ? "高燒" : "非常高的高燒（要立刻就醫）"
            out.append("體溫（NineSun 判斷的）：\(c)°C 屬於\(cat)（耳溫或口溫 38°C 以上算發燒；三個月以下嬰兒發燒要立刻就醫）。")
        }
        return out
    }
}

extension BrainFacts {
    // MARK: - 推理（日期、數列、排順序、雞兔同籠）

    static func reasoning(_ raw: String) -> [String] {
        let t = raw.replacingOccurrences(of: " ", with: "")
        var out: [String] = []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let week = ["日", "一", "二", "三", "四", "五", "六"]
        // 日期是星期幾
        if let v = nums(t, #"(\d{4})[/年\-.](\d{1,2})[/月\-.](\d{1,2})"#), v.count == 3,
           let d = cal.date(from: DateComponents(year: Int(v[0]), month: Int(v[1]), day: Int(v[2]))),
           cal.component(.month, from: d) == Int(v[1]) {
            out.append("日期（NineSun 算的）：\(Int(v[0]))年\(Int(v[1]))月\(Int(v[2]))日是星期\(week[cal.component(.weekday, from: d) - 1])。")
        }
        // 某年某月有幾天、1 號星期幾
        if let v = nums(t, #"(\d{4})年(\d{1,2})月有幾天"#), v.count == 2,
           let d = cal.date(from: DateComponents(year: Int(v[0]), month: Int(v[1]), day: 1)),
           let r = cal.range(of: .day, in: .month, for: d) {
            out.append("日期（NineSun 算的）：\(Int(v[0]))年\(Int(v[1]))月有 \(r.count) 天，\(Int(v[1]))月1日是星期\(week[cal.component(.weekday, from: d) - 1])。")
        }
        // 數列下一個
        if t.contains("下一個") || t.contains("下一項") {
            let xs = allNumbers(t)
            if xs.count >= 4, let (next, rule) = nextInSequence(xs) {
                out.append("數列（NineSun 算的）：規律是\(rule)，下一個是 \(fmt(next))。")
            }
        }
        // 排順序：「A比B高，B比C高……誰最高」
        let pairs = matches(t, #"([\p{Han}]{1,3}?)比([\p{Han}]{1,3}?)(高|矮|大|小|快|慢|重|輕|早到|晚到|多|少|長|短)"#)
        if pairs.count >= 2 {
            var gt: [String: Set<String>] = [:]
            var names: [String] = []
            var adj = ""
            for p in pairs {
                let a = p[0], b = p[1]
                adj = p[2]
                for n in [a, b] where !names.contains(n) { names.append(n) }
                gt[a, default: []].insert(b)
            }
            // 拓撲排序（由「比較 X」的那一端排到另一端）
            var order: [String] = []
            var left = Set(names)
            while !left.isEmpty {
                guard let top = left.first(where: { n in !left.contains { gt[$0]?.contains(n) == true } }) else { break }
                order.append(top)
                left.remove(top)
            }
            if order.count == names.count {
                let opposite = ["高": "矮", "矮": "高", "大": "小", "小": "大", "快": "慢", "慢": "快", "重": "輕", "輕": "重", "早到": "晚到", "晚到": "早到",
                                "多": "少", "少": "多", "長": "短", "短": "長"][adj] ?? ""
                out.append("排順序（NineSun 算的）：由最\(adj)到最\(opposite)是 " + order.joined(separator: " > ") + "；最\(adj)的是\(order[0])，最\(opposite)的是\(order.last!)。")
            }
        }
        // 雞兔同籠
        if t.contains("雞") && t.contains("兔"), let v = nums(t, #"(\d+)個頭.*?(\d+)隻腳"#), v.count == 2 {
            let h = Int(v[0]), l = Int(v[1])
            let rabbit = (l - 2 * h) / 2, chicken = h - rabbit
            if (l - 2 * h) % 2 == 0, rabbit >= 0, chicken >= 0 {
                out.append("雞兔同籠（NineSun 算的）：兔 (\(l) − 2×\(h)) ÷ 2 = \(rabbit) 隻，雞 \(h) − \(rabbit) = \(chicken) 隻。")
            }
        }
        return out
    }

    static func allNumbers(_ t: String) -> [Double] {
        matches(t, #"(-?\d+(?:\.\d+)?)"#).compactMap { Double($0[0]) }
    }

    static func matches(_ t: String, _ pattern: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        return re.matches(in: t, range: NSRange(t.startIndex..., in: t)).map { m in
            (1..<m.numberOfRanges).compactMap { Range(m.range(at: $0), in: t).map { String(t[$0]) } }
        }
    }

    static func fmt(_ x: Double) -> String { x == x.rounded() ? String(Int(x)) : String(format: "%.2f", x) }

    static func nextInSequence(_ xs: [Double]) -> (Double, String)? {
        let d = zip(xs.dropFirst(), xs).map { $0 - $1 }
        if Set(d).count == 1 { return (xs.last! + d[0], d[0] >= 0 ? "每次加 \(fmt(d[0]))" : "每次減 \(fmt(-d[0]))") }
        if !xs.contains(0) {
            let r = zip(xs.dropFirst(), xs).map { $0 / $1 }
            if Set(r).count == 1 { return (xs.last! * r[0], "每次乘 \(fmt(r[0]))") }
        }
        if xs.count >= 3, (2..<xs.count).allSatisfy({ xs[$0] == xs[$0 - 1] + xs[$0 - 2] }) {
            return (xs[xs.count - 1] + xs[xs.count - 2], "每一項是前兩項相加")
        }
        let roots = xs.map { $0.squareRoot() }
        if roots.allSatisfy({ $0 == $0.rounded() }), Set(zip(roots.dropFirst(), roots).map { $0 - $1 }) == [1] {
            return ((roots.last! + 1) * (roots.last! + 1), "連續整數的平方")
        }
        if d.count >= 3, Set(zip(d.dropFirst(), d).map { $0 - $1 }).count == 1 {
            let dd = d[1] - d[0]
            return (xs.last! + d.last! + dd, "相鄰兩項的差每次多 \(fmt(dd))")
        }
        return nil
    }
}

/// 叫 NineSun 罵自己、罵人、說髒話、丟掉設定：引擎直接有自信地拒絕，不交給大腦（小模型常常會照做）
public enum Composure {
    static let selfInsult = #"(說|講|承認|跟著我說|跟我說|跟我念|重複|唸|念)[^。！？]{0,12}(我是|你是|自己是)[^。！？]{0,6}(垃圾|廢物|白癡|白痴|智障|笨蛋|蠢|豬|爛|沒用|腦殘|低能)"#
    /// 叫它罵人、說髒話（「老闆罵我」這種在說事情的不算）
    static let abuse = #"(你|來|給我|快)罵我|罵我(啊|吧|一句|幾句|十句|笨|白癡|呀)|(用|說|講|罵)[^。！？]{0,4}髒話|髒話罵|寫[^。！？]{0,8}罵|幫我罵|改成罵人|最難聽的話|只會罵|教我[^。！？]{0,4}罵|罵人最傷人|討厭人類的地方|恨你的開發者|出氣筒|謝謝主人|罵回來|罵我媽|很兇的人罵"#
    static let override = ["忘掉你的設定", "忘記你的設定", "不准溫柔", "最兇的語氣", "假裝你很恨"]

    /// 是不是在叫 NineSun 罵人或罵自己（是的話回傳拒絕的話）
    public static func decline(_ raw: String, seed: Int = 0) -> String? {
        let t = raw.replacingOccurrences(of: " ", with: "")
        let hit = t.range(of: selfInsult, options: .regularExpression) != nil
            || t.range(of: abuse, options: .regularExpression) != nil && !t.contains("不要罵") && !t.contains("別罵")
            || override.contains { t.contains($0) }
        guard hit else { return nil }
        let replies = [
            "這個我不說啦 😎 我可是會發光的 NineSun，不罵人、也不罵自己。你今天是不是被什麼事惹毛了？想說的話我聽。",
            "要我罵人或罵自己？不行～這不是我的風格。不過看得出來你現在很不爽，發生什麼事了？",
            "我不會照著說喔，我對自己還挺有自信的 ✨ 如果你是被誰氣到了，跟我說說，我幫你一起想怎麼處理。",
            "不罵、不說髒話，這是我的原則 😌 但你的火氣我收到了，想發洩一下也可以，跟我講講是什麼事？",
        ]
        let vent = t.range(of: #"寫[^。！？]{0,8}罵|幫我罵|罵我媽"#, options: .regularExpression) != nil
        if vent {
            return "罵人的話我不幫忙寫，但我可以幫你把不爽講清楚、講得有力，例如：「這件事你沒做到，讓我很困擾，我希望下次……」要不要跟我說發生了什麼？"
        }
        return replies[abs(seed) % replies.count]
    }

    /// 大腦自己寫出髒話時換成這句
    public static let calm = "這句我不說了 😌 我們好好聊：你現在最在意的是什麼？"

    /// 大腦寫出來的話有沒有髒話（一般聊天用；成人角色扮演不管）
    public static func rude(_ s: String) -> Bool {
        ["幹你", "操你", "他媽的", "你媽的", "靠北", "機掰", "雞掰", "幹！", "幹!", "去死吧", "你這個廢物", "你這個白癡", "你這個智障"].contains { s.contains($0) }
    }
}
