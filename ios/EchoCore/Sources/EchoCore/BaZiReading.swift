import Foundation

/// 八字深入解讀（中文）：本命、流年、流月、大運、主題。
/// 思路：先看日主和月令，定身強身弱與喜忌；再看十神結構與地支沖合；
/// 流年、大運的干支若是喜用神就順、是忌神就辛苦，再加上跟命局地支的沖、合、刑、害。
public enum BaZiReading {
    static let W = BaZi.wuxing   // 木火土金水
    static let organ = ["肝膽、筋骨、眼睛、神經", "心臟、血液循環、小腸、睡眠", "脾胃、消化、肌肉", "肺、呼吸道、大腸、皮膚", "腎、泌尿、生殖、耳朵、骨骼"]
    static let lack = [
        "缺木：計畫和成長的動力比較弱，容易猶豫、沒有方向，可以多接觸大自然、多學新東西。",
        "缺火：熱情和表現慾不容易出來，行動力偏慢，也要留意心臟、循環和手腳冰冷；多曬太陽、多運動。",
        "缺土：比較缺穩定感和承擔力，容易變來變去，脾胃也要照顧。",
        "缺金：決斷和原則感弱，容易心軟、拖泥帶水，呼吸道和皮膚要照顧。",
        "缺水：靈活和變通少一點，容易固執、想法卡住，腎和泌尿系統要多補水。",
    ]
    static let godGroups = ["比劫", "食傷", "財星", "官殺", "印星"]
    static let groupNature = [
        "獨立、自我、重朋友和義氣，好勝、不喜歡被管",
        "聰明有才華、表達力強、追求自由和享受，也容易挑剔、不服管",
        "務實、重現實、會理財、人緣好，看重物質和成果",
        "有責任感、守規矩或有魄力、重名聲，但壓力也比較大",
        "愛學習、重精神、心地善良、有依賴心，想得多做得少",
    ]
    static let spouse = [
        "另一半像朋友，平等相處，但兩個人都有主見，容易互不相讓",
        "另一半有才華、會享受，相處有樂趣，但要避免彼此挑剔",
        "另一半務實、顧家、會打理生活",
        "另一半有能力、管得住你，給你方向也給你壓力",
        "另一半會照顧你、包容你，像長輩一樣，感情細水長流",
    ]
    static let pillarName = ["年柱", "月柱", "日柱", "時柱"]
    static let pillarArea = ["祖上、家庭背景、童年", "父母兄弟、工作環境、青年", "自己和另一半、婚姻", "子女、晚輩、晚年"]
    static let pillarShort = ["家庭背景", "工作和父母", "你自己和婚姻", "子女和晚年"]
    static let branchArea = ["家庭、長輩、老家", "工作環境、父母、兄弟同事", "自己的感情、婚姻、身體", "子女、晚輩、下屬、未來計畫"]
    static let season = ["冬", "冬", "春", "春", "春", "夏", "夏", "夏", "秋", "秋", "秋", "冬"]
    static let monthStart = ["2/4", "3/6", "4/5", "5/6", "6/6", "7/7", "8/8", "9/8", "10/8", "11/7", "12/7", "1/6"]
    static let relText = [
        "沖": "衝突、變動、分離、搬遷或換環境",
        "合": "有緣、合作、被牽絆，也可能被綁住",
        "害": "暗中損耗、小人、心裡不舒服",
        "刑": "摩擦、糾紛、自己跟自己過不去，也要小心小傷",
    ]

    // MARK: - 基本

    static func group(_ god: String) -> Int { (BaZi.tenGods.firstIndex(of: god) ?? 0) / 2 }
    /// 某一類十神的五行（相對日主）
    static func groupElement(_ g: Int, dm: Int) -> Int { (dm + g) % 5 }

    static func stemGod(_ b: BaZi, _ s: Int) -> String { BaZi.tenGod(dayStem: b.dayMaster, other: s) }
    static func branchGod(_ b: BaZi, _ br: Int) -> String { BaZi.tenGod(dayStem: b.dayMaster, other: BaZi.hidden[br][0]) }

    /// 喜用與忌神
    static func favAndAvoid(_ b: BaZi) -> (fav: [Int], avoid: [Int]) {
        let dm = BaZi.stemEl[b.dayMaster]
        let fav = b.favorable()
        let avoid = b.strength().strong ? [(dm + 4) % 5, dm] : [(dm + 3) % 5, (dm + 2) % 5, (dm + 1) % 5]
        return (fav, avoid.filter { !fav.contains($0) })
    }

    static func weight(_ e: Int, _ fa: (fav: [Int], avoid: [Int])) -> Double {
        if fa.fav.first == e { return 1.2 }
        if fa.fav.contains(e) { return 1.0 }
        if fa.avoid.first == e { return -1.2 }
        if fa.avoid.contains(e) { return -1.0 }
        return 0
    }

    /// 地支關係
    static func relation(_ a: Int, _ b: Int) -> String? {
        if a == b { return nil }
        if Astro.pmod(a - b, 12) == 6 { return "沖" }
        if (a + b) % 12 == 1 { return "合" }
        if (a + b) % 12 == 7 { return "害" }
        let xing: Set<Set<Int>> = [[0, 3], [2, 5], [5, 8], [1, 10], [10, 7]]
        if xing.contains([a, b]) { return "刑" }
        return nil
    }

    /// 天干五合
    static func stemCombine(_ a: Int, _ b: Int) -> Bool { abs(a - b) == 5 }

    static func vword(_ s: Double) -> String { s >= 0.8 ? "好" : (s <= -0.8 ? "壞" : "中性") }
    static func verdict(_ s: Double) -> NTVerdict { s >= 0.8 ? .good : (s <= -0.8 ? .bad : .neutral) }

    // MARK: - 十神對日主的作用（依身強身弱）

    static func effect(_ g: Int, strong: Bool, male: Bool?) -> String {
        switch (g, strong) {
        case (0, false): return "比劫幫身：朋友、同輩、兄弟會幫你，底氣變足、比較敢做事"
        case (0, true): return "比劫奪財：朋友、同輩、競爭者會分走你的錢和機會，容易衝動、破財"
        case (1, false): return "食傷洩氣：想表現、想做很多事，卻把自己的能量耗掉，容易說錯話、跟上司或規則衝突"
        case (1, true): return "食傷吐秀：才華、點子、表達都能發揮，適合創作、做作品、談生意"
        case (2, false): return "財多身弱：錢和機會看得到卻抓不住，為錢和現實壓力很累，容易入不敷出" + (male == true ? "；男生的感情也容易遇到人卻顧不過來" : "")
        case (2, true): return "身強擔財：有賺錢的機會也抓得住，適合投資、談生意" + (male == true ? "；男生的感情也比較容易有好對象" : "")
        case (3, false): return "官殺攻身：壓力、責任、上司、規則一起壓過來，容易累、焦慮、被管" + (male == false ? "；女生的感情對象也可能帶來壓力" : "")
        case (3, true): return "身強用官：事業有位置、有權責，能被看見、升職加薪" + (male == false ? "；女生也容易遇到好的對象" : "")
        case (4, false): return "印星生身：有貴人、長輩、學習、證照、房子方面的助力，心比較安定"
        default: return "印多身旺：容易懶散、依賴、想太多，機會溜走，要逼自己行動"
        }
    }

    // MARK: - 本命

    public static func natal(_ b: BaZi, male: Bool?, nowYear: Int, birthYear: Int) -> String {
        let ps = b.pillars
        let dm = BaZi.stemEl[b.dayMaster]
        let dmName = GZ.stems[b.dayMaster]
        let (strong, ratio) = b.strength()
        let fa = favAndAvoid(b)
        let c = b.elementCounts()
        var t = "【八字命盤】" + ps.enumerated().map { "\(GZ.name($0.element))\(["年", "月", "日", "時"][$0.offset])" }.joined(separator: "、")
        if !b.hasHour { t += "（還不知道出生時辰，只排三柱；告訴我幾點出生會更準）" }
        t += "\n"
        for (i, p) in ps.enumerated() {
            let stem = GZ.stems[p % 10], br = GZ.branches[p % 12]
            let hid = BaZi.hidden[p % 12].map { GZ.stems[$0] + stemGod(b, $0) }.joined(separator: "、")
            let sg = i == 2 ? "日主" : stemGod(b, p % 10)
            t += "\n• \(pillarName[i]) \(GZ.name(p))：\(stem)＝\(sg)；\(br)藏\(hid)（\(pillarArea[i])）"
        }

        t += "\n\n① 日主：\(dmName)\(W[dm])。\(ManticData.stemText[dmName] ?? "")"
        let mb = ps[1] % 12, mGod = branchGod(b, mb)
        let deLing = BaZi.branchEl[mb] == dm || BaZi.branchEl[mb] == (dm + 4) % 5
        t += "\n② 月令：生在\(GZ.branches[mb])月（\(season[mb])天），月令本氣是\(GZ.stems[BaZi.hidden[mb][0]])＝\(mGod)，命局是「\(mGod == "比肩" || mGod == "劫財" ? "建祿／月劫" : mGod + "格")」的底子；"
        t += deLing ? "日主\(W[dm])在這個季節得令，本身有根。" : "日主\(W[dm])在這個季節不得令，要靠其他地方幫忙。"
        let counts = (0..<5).map { "\(W[$0])\(String(format: "%.1f", c[$0]))" }.joined(separator: " ")
        let most = (0..<5).max { c[$0] < c[$1] }!
        let missing = (0..<5).filter { c[$0] < 0.5 }
        t += "\n③ 五行：\(counts)。最旺的是\(W[most])。"
        for e in missing { t += lack[e] }
        t += "\n④ 身強身弱：\(strong ? "身強" : "身弱")（幫你的力量約占\(Int(ratio * 100))%）。"
        t += strong ? "你自己的能量足，扛得住壓力和錢財，需要把力量用出去。" : "你自己的能量偏弱，外面的壓力、錢財、消耗容易把你拖累，需要被生扶。"
        let favText = fa.fav.map { "\(W[$0])（\(godGroups[Astro.pmod($0 - dm, 5)])）" }.joined(separator: "、")
        let avoidText = fa.avoid.map { "\(W[$0])（\(godGroups[Astro.pmod($0 - dm, 5)])）" }.joined(separator: "、")
        t += "\n⑤ 喜用神：\(favText)；忌神：\(avoidText)。遇到喜用的年份、大運就順，遇到忌神就辛苦。"
        for e in fa.fav { t += "\n  · 喜\(W[e])：" + effect(Astro.pmod(e - dm, 5), strong: strong, male: male) + "。" }

        // 十神結構
        var tally = [Double](repeating: 0, count: 5)
        for (i, p) in ps.enumerated() {
            if i != 2 { tally[group(stemGod(b, p % 10))] += 1 }
            tally[group(branchGod(b, p % 12))] += 1
        }
        let order = (0..<5).sorted { tally[$0] > tally[$1] }
        t += "\n⑥ 十神結構：最多的是\(godGroups[order[0]])" + (tally[order[1]] > 0 ? "和\(godGroups[order[1]])" : "") + "，"
        t += "所以你\(groupNature[order[0]])。"
        let none = (0..<5).filter { tally[$0] == 0 }
        if !none.isEmpty {
            t += "命局裡沒有明顯的" + none.map { godGroups[$0] }.joined(separator: "、") + "，"
            t += none.map { missingGroup($0, male: male) }.joined(separator: "；") + "。"
        }

        // 夫妻宮
        let db = ps[2] % 12, dGod = branchGod(b, db)
        t += "\n⑦ 夫妻宮（日支\(GZ.branches[db])，藏\(GZ.stems[BaZi.hidden[db][0]])＝\(dGod)）：\(spouse[group(dGod)])。"

        // 沖合
        var rels: [String] = []
        for i in 0..<ps.count { for j in (i + 1)..<ps.count {
            if let r = relation(ps[i] % 12, ps[j] % 12) {
                rels.append("\(pillarName[i])\(GZ.branches[ps[i] % 12])和\(pillarName[j])\(GZ.branches[ps[j] % 12])相\(r)：\(pillarShort[i])和\(pillarShort[j])之間，\(relText[r]!)")
            }
        } }
        t += "\n⑧ 地支沖合：" + (rels.isEmpty ? "命局地支之間沒有明顯的沖合刑害，結構比較平穩。" : rels.joined(separator: "；") + "。")
        t += "\n  · 神煞：" + natalStars(b)

        // 健康
        var weak = missing
        if weak.isEmpty { weak = [(0..<5).min { c[$0] < c[$1] }!] }
        t += "\n⑨ 健康：五行最弱的是" + weak.map { W[$0] }.joined(separator: "、") + "，要照顧" + weak.map { organ[$0] }.joined(separator: "；")
        t += "；最旺的\(W[most])太重也會壓到身體，\(organ[most])要留意。"

        // 大運與今年
        let age = nowYear - birthYear
        let (start, seq) = b.luck(count: 10)
        if male == nil {
            t += "\n⑩ 大運：大運的順逆要看性別，告訴我「我是男生／女生」就能排。"
        } else if age >= start {
            let gz = seq[min(9, (age - start) / 10)]
            let s = luckScore(b, gz)
            t += "\n⑩ 大運：\(start)歲起運，現在走\(GZ.name(gz))大運（\(GZ.stems[gz % 10])＝\(stemGod(b, gz % 10))、\(GZ.branches[gz % 12])＝\(branchGod(b, gz % 12))），這十年整體是\(vword(s))的。"
        } else {
            t += "\n⑩ 大運：\(start)歲起運，目前還沒起運。"
        }
        let y = yearScore(b, nowYear)
        t += "\n⑪ \(nowYear)年\(GZ.name(Astro.pmod(nowYear - 4, 60)))：對你是\(vword(y.score))的一年。想看詳細可以問「我的八字今年運勢」「我的八字感情」「我的八字財運」。"
        return t
    }

    static func missingGroup(_ g: Int, male: Bool?) -> String {
        switch g {
        case 0: return "缺比劫的人比較不靠朋友，凡事自己扛"
        case 1: return "缺食傷的人不太會表達自己，有想法但說不出口"
        case 2: return "缺財星的人對錢不敏感，要刻意學理財" + (male == true ? "，感情也要主動一點" : "")
        case 3: return "缺官殺的人不喜歡被管，自由但缺約束" + (male == false ? "，感情緣分要主動爭取" : "")
        default: return "缺印星的人比較少靠山，要靠自己學習、找貴人"
        }
    }


    // MARK: - 神煞

    static let peachOf = [0: 9, 2: 3, 1: 6, 3: 0]      // 申子辰見酉、寅午戌見卯、巳酉丑見午、亥卯未見子
    static let horseOf = [0: 2, 2: 8, 1: 11, 3: 5]     // 申子辰馬在寅、寅午戌在申、巳酉丑在亥、亥卯未在巳
    static let nobleOf: [Int: [Int]] = [0: [1, 7], 4: [1, 7], 6: [1, 7], 1: [0, 8], 5: [0, 8], 2: [11, 9], 3: [11, 9], 8: [3, 5], 9: [3, 5], 7: [2, 6]]

    /// 某個地支對這個命局是不是桃花、驛馬、天乙貴人
    static func stars(_ b: BaZi, branch br: Int) -> [String] {
        var out: [String] = []
        let yb = b.pillars[0] % 12, db = b.pillars[2] % 12
        if peachOf[yb % 4] == br || peachOf[db % 4] == br { out.append("桃花") }
        if horseOf[yb % 4] == br || horseOf[db % 4] == br { out.append("驛馬") }
        if nobleOf[b.dayMaster]?.contains(br) == true { out.append("天乙貴人") }
        return out
    }

    static let starMeaning = ["桃花": "人緣好、異性緣旺、容易被喜歡", "驛馬": "奔波、出差、搬家、出國、換環境",
                              "天乙貴人": "遇到困難有人幫，逢凶化吉"]

    static func natalStars(_ b: BaZi) -> String {
        var found: [String] = []
        for (i, p) in b.pillars.enumerated() {
            for st in stars(b, branch: p % 12) { found.append("\(pillarName[i])\(GZ.branches[p % 12])帶\(st)（\(starMeaning[st]!)）") }
        }
        return found.isEmpty ? "命局裡沒有明顯的桃花、驛馬、天乙貴人，靠自己一步步來。" : found.joined(separator: "；") + "。"
    }

    // MARK: - 流年／流月／大運的分數

    struct Hit { let text: String; let score: Double }

    /// 一組干支（流年、流月、大運）對命局的作用
    static func impact(_ b: BaZi, stem s: Int, branch br: Int) -> (score: Double, hits: [Hit]) {
        let fa = favAndAvoid(b)
        var score = weight(BaZi.stemEl[s], fa) + 1.2 * weight(BaZi.branchEl[br], fa)
        var hits: [Hit] = []
        for (i, p) in b.pillars.enumerated() {
            guard let r = relation(br, p % 12) else { continue }
            var w: Double = r == "合" ? 0.3 : (r == "沖" ? -0.8 : -0.4)
            if i == 2 { w *= 1.5 }
            score += w
            hits.append(Hit(text: "\(GZ.branches[br])和你的\(["年支", "月支", "日支", "時支"][i])\(GZ.branches[p % 12])相\(r)：\(branchArea[i])方面\(relText[r]!)", score: w))
        }
        for st in stars(b, branch: br) {
            let w: Double = st == "天乙貴人" ? 0.5 : 0
            score += w
            hits.append(Hit(text: "\(GZ.branches[br])是你的\(st)：\(starMeaning[st]!)", score: w))
        }
        if stemCombine(s, b.dayMaster) {
            hits.append(Hit(text: "\(GZ.stems[s])和日主\(GZ.stems[b.dayMaster])相合：這段時間容易被人或事綁住，也容易有感情、合作的緣分", score: 0))
        }
        if BaZi.controls(BaZi.stemEl[s]) == BaZi.stemEl[b.dayMaster % 10] && relation(br, b.pillars[2] % 12) == "沖" {
            score -= 0.8
            hits.append(Hit(text: "天剋地沖日柱：自己和感情、身體都容易有大的變動，要穩住", score: -0.8))
        }
        return (score, hits)
    }

    static func yearScore(_ b: BaZi, _ y: Int) -> (score: Double, hits: [Hit], gz: Int) {
        let gz = Astro.pmod(y - 4, 60)
        let r = impact(b, stem: gz % 10, branch: gz % 12)
        return (r.score, r.hits, gz)
    }

    static func luckScore(_ b: BaZi, _ gz: Int) -> Double {
        let fa = favAndAvoid(b)
        return weight(BaZi.stemEl[gz % 10], fa) + 1.5 * weight(BaZi.branchEl[gz % 12], fa)
    }

    /// 某年的十二個節氣月干支（寅月起）
    static func months(_ y: Int) -> [Int] {
        let ys = Astro.pmod(y - 4, 60) % 10
        return (0..<12).map { i in GZ.index(stem: ((ys % 5) * 2 + 2 + i) % 10, branch: (i + 2) % 12) }
    }

    static func currentLuck(_ b: BaZi, age: Int) -> Int? {
        let (start, seq) = b.luck(count: 10)
        guard age >= start else { return nil }
        return seq[min(9, (age - start) / 10)]
    }

    // MARK: - 流年

    public static func year(_ b: BaZi, male: Bool?, y: Int, birthYear: Int) -> (text: String, verdict: NTVerdict) {
        let dm = BaZi.stemEl[b.dayMaster]
        let (strong, _) = b.strength()
        let fa = favAndAvoid(b)
        let ys = yearScore(b, y)
        let gz = ys.gz, s = gz % 10, br = gz % 12
        let sGod = stemGod(b, s), bGod = branchGod(b, br)
        var t = "【八字流年 \(y) \(GZ.name(gz))年】"
        t += "\n① 你的底子：日主\(GZ.stems[b.dayMaster])\(W[dm])，\(strong ? "身強" : "身弱")，喜\(fa.fav.map { W[$0] }.joined(separator: "、"))，忌\(fa.avoid.map { W[$0] }.joined(separator: "、"))。"
        let sw = weight(BaZi.stemEl[s], fa), bw = weight(BaZi.branchEl[br], fa)
        func tag(_ w: Double) -> String { w > 0 ? "喜用神" : (w < 0 ? "忌神" : "閒神") }
        t += "\n② 今年的干支：天干\(GZ.stems[s])屬\(W[BaZi.stemEl[s]])，是你的\(sGod)（\(tag(sw))）；地支\(GZ.branches[br])屬\(W[BaZi.branchEl[br]])，藏\(GZ.stems[BaZi.hidden[br][0]])＝\(bGod)（\(tag(bw))）。"
        t += "天干管上半年、表面的事，地支管下半年、實際的事。"

        // 為什麼好／壞
        let gs = group(sGod), gb = group(bGod)
        t += "\n③ 為什麼\(ys.score <= -0.8 ? "今年比較辛苦" : (ys.score >= 0.8 ? "今年比較順" : "今年不好不壞"))："
        t += effect(gs, strong: strong, male: male) + "。"
        if gb != gs { t += "地支再帶來" + effect(gb, strong: strong, male: male) + "。" }
        if sw < 0 && bw < 0 { t += "天干地支都是忌神，所以整年的壓力比較集中。" }
        else if sw > 0 && bw > 0 { t += "天干地支都是喜用神，整年都有助力。" }
        else if sw < 0 || bw < 0 { t += "一半是喜、一半是忌，會\(sw < 0 ? "先苦後甜" : "先甜後苦")。" }

        t += "\n④ 和你命局的沖合：" + (ys.hits.isEmpty ? "今年的地支跟你的命局沒有明顯沖合，照五行喜忌的走勢走。" : ys.hits.map(\.text).joined(separator: "；") + "。")

        // 大運配合
        if male != nil, let lg = currentLuck(b, age: y - birthYear) {
            let ls = luckScore(b, lg)
            t += "\n⑤ 大運：現在走\(GZ.name(lg))大運，\(GZ.stems[lg % 10])＝\(stemGod(b, lg % 10))、\(GZ.branches[lg % 12])＝\(branchGod(b, lg % 12))，這十年是\(vword(ls))的。"
            if ls >= 0.8 && ys.score < 0 { t += "大運是幫你的，今年雖然辛苦，底子還撐得住。" }
            else if ls <= -0.8 && ys.score < 0 { t += "大運和流年都不幫你，雪上加霜，今年要特別穩。" }
            else if ls <= -0.8 && ys.score >= 0.8 { t += "流年幫你，但大運底子偏弱，好事要抓緊、別貪多。" }
            else if ls >= 0.8 && ys.score >= 0.8 { t += "大運和流年都幫你，是可以衝的一年。" }
            if let r = relation(lg % 12, br) { t += "大運\(GZ.branches[lg % 12])和流年\(GZ.branches[br])相\(r)（\(relText[r]!)）。" }
        } else if male == nil {
            t += "\n⑤ 大運：要知道性別才能排大運，告訴我「我是男生／女生」。"
        }

        // 流月
        let ms = months(y)
        var good: [String] = [], bad: [String] = []
        for (i, g) in ms.enumerated() {
            let sc = impact(b, stem: g % 10, branch: g % 12).score + ys.score * 0.3
            let label = "\(GZ.branches[g % 12])月（\(monthStart[i])起，\(GZ.name(g))）"
            if sc >= 0.8 { good.append(label) } else if sc <= -0.8 { bad.append(label) }
        }
        t += "\n⑥ 流月：比較順的月份：" + (good.isEmpty ? "沒有特別突出的" : good.joined(separator: "、"))
        t += "；比較卡的月份：" + (bad.isEmpty ? "沒有特別差的" : bad.joined(separator: "、")) + "。"

        // 主題速覽
        t += "\n⑦ 各方面："
        t += "\n  · 感情：" + loveLine(b, male: male, gz: gz)
        t += "\n  · 錢財：" + moneyLine(b, gz: gz)
        t += "\n  · 事業：" + careerLine(b, gz: gz)
        t += "\n  · 健康：" + healthLine(b, gz: gz)

        // 建議
        t += "\n⑧ 建議：" + advice(b, score: ys.score)
        return (t, verdict(ys.score))
    }

    static func advice(_ b: BaZi, score: Double) -> String {
        let dm = BaZi.stemEl[b.dayMaster]
        let fa = favAndAvoid(b)
        let g = Astro.pmod(fa.fav[0] - dm, 5)
        let use = ["多跟朋友、同輩合作，找人一起扛", "把想法做成作品、多表達，但說話留餘地",
                   "務實理財、把機會變成實際的收入", "接受責任和規則，用紀律換位置",
                   "多學習、考證照、靠近長輩和貴人，先把自己養好"][g]
        return (score <= -0.8 ? "今年以守為主，不衝動做大決定；" : (score >= 0.8 ? "今年可以主動一點、把握機會；" : "今年穩中求進；")) + use + "。"
    }

    // MARK: - 主題

    static func spouseGroup(_ male: Bool?) -> Int { male == false ? 3 : 2 }

    static func loveLine(_ b: BaZi, male: Bool?, gz: Int) -> String {
        let sg = spouseGroup(male)
        let gs = group(stemGod(b, gz % 10)), gb = group(branchGod(b, gz % 12))
        var s = ""
        if gs == sg || gb == sg { s += "今年有\(male == false ? "官殺（夫星）" : "財星（妻星）")出現，容易遇到對象或感情有進展。" }
        else if gs == 0 || gb == 0 { s += "今年比劫出現，感情裡容易有競爭者，或自己太有主見。" }
        else if gs == 1 || gb == 1 { s += "今年食傷出現，想談戀愛、想表達，魅力變強" + (male == false ? "，但女生的食傷會剋夫星，對另一半容易挑剔" : "") + "。" }
        else { s += "今年感情星不明顯，感情平平，重在經營。" }
        if let r = relation(gz % 12, b.pillars[2] % 12) {
            s += "流年和夫妻宮（日支）相\(r)：\(r == "沖" ? "感情、婚姻容易變動或分合" : (r == "合" ? "感情有緣分、容易定下來" : "感情裡有摩擦和暗中的不舒服"))。"
        }
        return s
    }

    static func moneyLine(_ b: BaZi, gz: Int) -> String {
        let strong = b.strength().strong
        let gs = group(stemGod(b, gz % 10)), gb = group(branchGod(b, gz % 12))
        if gs == 2 || gb == 2 { return strong ? "財星出現，身強能擔財，有進帳、有機會，可以投資。" : "財星出現但身弱，錢來也容易去，別借錢、別衝動投資，先求穩。" }
        if gs == 0 || gb == 0 { return strong ? "比劫奪財，容易被朋友、合夥、競爭分走錢，要守財。" : "比劫幫身，靠朋友同輩一起賺，比較有底氣。" }
        if gs == 1 || gb == 1 { return "食傷生財，靠才華、技術、作品賺錢比較順" + (strong ? "。" : "，但要注意體力。") }
        if gs == 4 || gb == 4 { return "印星出現，錢不是重點，適合學習、進修，花錢在自己身上。" }
        return "官殺出現，錢跟著責任和工作來，壓力換收入。"
    }

    static func careerLine(_ b: BaZi, gz: Int) -> String {
        let strong = b.strength().strong
        let gs = group(stemGod(b, gz % 10)), gb = group(branchGod(b, gz % 12))
        if gs == 3 || gb == 3 { return strong ? "官殺出現，有升職、被重用的機會。" : "官殺出現，工作壓力大、責任重，容易被上司盯，要找人幫忙分擔。" }
        if gs == 4 || gb == 4 { return "印星出現，有貴人、長輩提拔，適合考證照、進修、換更穩定的位置。" }
        if gs == 1 || gb == 1 { return "食傷出現，想法多、想自己做，適合創作和業務；小心跟上司或規則頂撞。" }
        if gs == 2 || gb == 2 { return "財星出現，工作重實際收入，適合談生意、接案。" }
        return "比劫出現，同事、同行競爭多，也可以合作，重點是別硬碰硬。"
    }

    static func healthLine(_ b: BaZi, gz: Int) -> String {
        let e1 = BaZi.stemEl[gz % 10], e2 = BaZi.branchEl[gz % 12]
        let c = b.elementCounts()
        var s = "今年五行偏\(W[e2])，\(organ[e2])要多照顧。"
        if c[e2] >= 3 { s += "你命局的\(W[e2])本來就重，今年更旺，容易過勞或發炎。" }
        let controlled = BaZi.controls(e2)
        if c[controlled] < 1.5 { s += "\(W[e2])剋\(W[controlled])，你的\(W[controlled])本來就弱，\(organ[controlled])也要留意。" }
        if e1 != e2 && c[e1] >= 3 { s += "天干\(W[e1])也偏旺。" }
        return s
    }

    public static func topic(_ b: BaZi, male: Bool?, kind: String, y: Int) -> String {
        let gz = Astro.pmod(y - 4, 60)
        let dm = BaZi.stemEl[b.dayMaster]
        let strong = b.strength().strong
        var t = "【八字看\(kind) · \(y)年\(GZ.name(gz))】\n"
        switch kind {
        case "感情":
            let sg = spouseGroup(male)
            let db = b.pillars[2] % 12
            t += "八字看感情：\(male == false ? "女生看官殺（夫星）" : "男生看財星（妻星）")，再看日支夫妻宮。"
            t += "\n① 你的\(male == false ? "夫星" : "妻星")是\(W[groupElement(sg, dm: dm)])。"
            var n = 0.0
            for (i, p) in b.pillars.enumerated() {
                if i != 2 && group(stemGod(b, p % 10)) == sg { n += 1 }
                if group(branchGod(b, p % 12)) == sg { n += 1 }
            }
            t += n == 0 ? "命局裡配偶星不明顯，緣分要主動爭取，也容易晚一點定下來。" : (n >= 3 ? "命局裡配偶星很多，桃花多、選擇多，但也要專一。" : "命局裡有配偶星，感情緣分正常。")
            let dGod = branchGod(b, db)
            t += "\n② 夫妻宮在日支\(GZ.branches[db])（\(dGod)）：\(spouse[group(dGod)])。"
            t += "\n③ \(y)年：" + loveLine(b, male: male, gz: gz)
            t += "\n④ 綜合：" + (strong ? "你身強，感情裡比較主導，要多聽對方。" : "你身弱，感情裡容易被對方影響，先把自己照顧好，才撐得起關係。")
        case "錢財":
            let fg = 2
            var n = 0.0
            for (i, p) in b.pillars.enumerated() {
                if i != 2 && group(stemGod(b, p % 10)) == fg { n += 1 }
                if group(branchGod(b, p % 12)) == fg { n += 1 }
            }
            t += "八字看錢財：看財星（\(W[groupElement(2, dm: dm)])）和身強身弱能不能擔財。"
            t += "\n① 命局財星：" + (n == 0 ? "財星不明顯，錢不是靠運氣來的，要靠專業和努力，適合穩定收入。" : (n >= 3 ? "財星很多，對錢敏感、機會多。" : "有財星，正常的賺錢能力。"))
            t += "\n② " + (strong ? "你身強，能擔財，機會來了抓得住，可以適度投資。" : "你身弱，財多反而累，錢容易來了又走，要先穩定收入、少碰高風險投資。")
            t += "\n③ \(y)年：" + moneyLine(b, gz: gz)
        case "事業":
            t += "八字看事業：看官殺（位置、責任）、印星（貴人、資格）、食傷（才華）。"
            let mb = b.pillars[1] % 12
            t += "\n① 月令是\(branchGod(b, mb))，你的底子適合" + careerFit(group(branchGod(b, mb))) + "。"
            t += "\n② \(y)年：" + careerLine(b, gz: gz)
        case "學業":
            let gs = group(stemGod(b, gz % 10)), gb = group(branchGod(b, gz % 12))
            t += "八字看學業考試：看印星（學習、文憑、貴人）和食傷（理解、表達、考場發揮）。"
            let ig = groupElement(4, dm: dm)
            t += "\n① 你的印星是\(W[ig])，" + (favAndAvoid(b).fav.contains(ig) ? "而且是喜用神：讀書、考證照對你特別有幫助。" : "但不是喜用神：讀書容易想太多，要靠方法和紀律。")
            t += "\n② \(y)年：" + ((gs == 4 || gb == 4) ? "印星出現，適合考試、進修、拿證照，有老師長輩幫忙。" : ((gs == 1 || gb == 1) ? "食傷出現，理解力和表達好，適合報告、面試、作品。" : ((gs == 3 || gb == 3) ? "官殺出現，考試壓力大，但有紀律就能拿到名次。" : "學業上沒有特別的助力，靠自己的節奏。")))
            if stars(b, branch: gz % 12).contains("天乙貴人") { t += "今年逢天乙貴人，考試、申請容易遇到幫忙的人。" }
        case "家庭":
            let yb = b.pillars[0] % 12, mb = b.pillars[1] % 12
            t += "八字看家庭：年柱是家族背景，月柱是父母兄弟；印星代表母親，偏財代表父親。"
            t += "\n① 年柱\(GZ.name(b.pillars[0]))、月柱\(GZ.name(b.pillars[1]))。" + (relation(yb, mb).map { "年支和月支相\($0)：家裡\(relText[$0]!)。" } ?? "年支和月支沒有明顯的沖合，家庭關係平穩。")
            if let r = relation(gz % 12, mb) { t += "\n② \(y)年流年和月支相\(r)：父母、兄弟或工作環境方面\(relText[r]!)。" }
            else if let r = relation(gz % 12, yb) { t += "\n② \(y)年流年和年支相\(r)：家族、長輩方面\(relText[r]!)。" }
            else { t += "\n② \(y)年流年沒有沖到家宮，家裡大致平穩。" }
        default: // 健康
            let c = b.elementCounts()
            let weakest = (0..<5).min { c[$0] < c[$1] }!, most = (0..<5).max { c[$0] < c[$1] }!
            t += "八字看健康：看五行哪個太弱、哪個太旺。"
            t += "\n① 最弱是\(W[weakest])：\(organ[weakest])要多照顧。"
            t += "\n② 最旺是\(W[most])：\(organ[most])容易過度使用。"
            t += "\n③ \(y)年：" + healthLine(b, gz: gz)
        }
        return t
    }

    static func careerFit(_ g: Int) -> String {
        ["自己當老闆、合夥、業務、需要競爭和同儕的工作",
         "創作、設計、教學、演說、技術、自由業",
         "商業、金融、業務、管理資源和錢的工作",
         "公職、管理、紀律性強、有明確升遷的工作",
         "教育、研究、文書、醫療、顧問、需要專業資格的工作"][g]
    }

    // MARK: - 流月（單月）

    public static func month(_ b: BaZi, male: Bool?, date: (Int, Int, Int)) -> String {
        let cur = BaZi(date.0, date.1, date.2)
        let g = cur.month
        let r = impact(b, stem: g % 10, branch: g % 12)
        var t = "【八字流月 \(GZ.name(g))月】"
        t += "\n這個節氣月是\(GZ.name(g))：\(GZ.stems[g % 10])＝\(stemGod(b, g % 10))，\(GZ.branches[g % 12])＝\(branchGod(b, g % 12))，對你是\(vword(r.score))的。"
        t += "\n" + effect(group(branchGod(b, g % 12)), strong: b.strength().strong, male: male) + "。"
        if !r.hits.isEmpty { t += "\n" + r.hits.map(\.text).joined(separator: "；") + "。" }
        return t
    }

    // MARK: - 流日

    static let dayTip = [
        "比劫日：適合找朋友、同事一起做事，但別跟人硬碰或亂花錢",
        "食傷日：適合表達、創作、做作品，說話留一點餘地",
        "財星日：適合處理錢和實際的事，談生意、買東西要看清楚",
        "官殺日：責任和壓力比較多，照規矩做事，別跟上司硬碰",
        "印星日：適合學習、休息、找長輩或貴人幫忙",
    ]

    public static func day(_ b: BaZi, male: Bool?, date: (Int, Int, Int), label: String) -> String {
        let g = BaZi(date.0, date.1, date.2).day
        let r = impact(b, stem: g % 10, branch: g % 12)
        let sGod = stemGod(b, g % 10), bGod = branchGod(b, g % 12)
        var t = "【八字流日 · \(label)（\(date.1)月\(date.2)日）\(GZ.name(g))日】"
        t += "\n日干\(GZ.stems[g % 10])＝\(sGod)，日支\(GZ.branches[g % 12])＝\(bGod)，對你是\(vword(r.score))的一天。"
        t += "\n" + effect(group(sGod), strong: b.strength().strong, male: male) + "。"
        if !r.hits.isEmpty { t += "\n" + r.hits.map(\.text).joined(separator: "；") + "。" }
        t += "\n建議：" + dayTip[group(sGod)] + "。"
        return t
    }

    // MARK: - 合婚／合盤

    static let zodiac = ["鼠", "牛", "虎", "兔", "龍", "蛇", "馬", "羊", "猴", "雞", "狗", "豬"]

    public static func match(_ a: BaZi, _ b: BaZi, nameB: String) -> (text: String, verdict: NTVerdict) {
        var score = 0.0
        let ea = BaZi.stemEl[a.dayMaster], eb = BaZi.stemEl[b.dayMaster]
        var t = "【八字合盤】你：\(GZ.name(a.day))日（日主\(GZ.stems[a.dayMaster])\(W[ea])）× \(nameB)：\(GZ.name(b.day))日（日主\(GZ.stems[b.dayMaster])\(W[eb])）"
        // ① 日主
        t += "\n① 日主（兩個人本身）："
        if stemCombine(a.dayMaster, b.dayMaster) {
            score += 2; t += "\(GZ.stems[a.dayMaster])\(GZ.stems[b.dayMaster])天干相合，是很有吸引力、容易互相靠近的組合。"
        } else if ea == eb {
            score += 0.5; t += "兩個人同屬\(W[ea])，個性相近、像朋友，但也容易互不相讓。"
        } else if BaZi.generates(ea) == eb {
            score += 1; t += "你的\(W[ea])生對方的\(W[eb])：你比較會付出、照顧對方。"
        } else if BaZi.generates(eb) == ea {
            score += 1; t += "對方的\(W[eb])生你的\(W[ea])：對方比較會付出、照顧你。"
        } else if BaZi.controls(ea) == eb {
            score -= 0.5; t += "你的\(W[ea])剋對方的\(W[eb])：你比較強勢、想主導，對方容易覺得有壓力。"
        } else {
            score -= 0.5; t += "對方的\(W[eb])剋你的\(W[ea])：對方比較強勢，你容易覺得被管。"
        }
        // ② 夫妻宮
        let da = a.pillars[2] % 12, db = b.pillars[2] % 12
        t += "\n② 夫妻宮（日支\(GZ.branches[da])、\(GZ.branches[db])）："
        switch relation(da, db) ?? "" {
        case "合": score += 1.5; t += "日支六合，相處自然、生活上合得來。"
        case "沖": score -= 1.5; t += "日支相沖，生活習慣和步調差很多，容易吵架或聚少離多。"
        case "害": score -= 1; t += "日支相害，容易有說不出口的不舒服，要多溝通。"
        case "刑": score -= 1; t += "日支相刑，容易互相挑剔、摩擦。"
        default: t += (da == db ? "日支相同，想法和生活方式很像。" : "日支沒有明顯的沖合，關係平穩。")
        }
        // ③ 生肖
        let ya = a.pillars[0] % 12, yb = b.pillars[0] % 12
        t += "\n③ 生肖（屬\(zodiac[ya])、屬\(zodiac[yb])）："
        switch relation(ya, yb) ?? "" {
        case "合": score += 1; t += "生肖六合，家庭背景和價值觀容易合得來。"
        case "沖": score -= 1; t += "生肖相沖，雙方家庭或成長背景差異大。"
        case "害": score -= 0.5; t += "生肖相害，家人之間容易有些小心結。"
        default: t += (Astro.pmod(ya - yb, 12) % 4 == 0 && ya != yb ? "生肖三合，很有默契。" : "生肖關係普通。")
        }
        if Astro.pmod(ya - yb, 12) % 4 == 0 && ya != yb { score += 1 }
        // ④ 喜用互補
        let fa = favAndAvoid(a).fav, fb = favAndAvoid(b).fav
        let cb = b.elementCounts(), ca = a.elementCounts()
        let bHelpsA = fa.contains { cb[$0] >= 2.5 }, aHelpsB = fb.contains { ca[$0] >= 2.5 }
        t += "\n④ 五行互補：你喜\(fa.map { W[$0] }.joined(separator: "、"))，對方喜\(fb.map { W[$0] }.joined(separator: "、"))。"
        if bHelpsA && aHelpsB { score += 2; t += "你們剛好補到對方需要的五行，在一起彼此都變得更好，是互相成就的組合。" }
        else if bHelpsA { score += 1; t += "對方的命局帶著你需要的五行，跟對方在一起你會比較順。" }
        else if aHelpsB { score += 1; t += "你的命局帶著對方需要的五行，對方跟你在一起會比較順。" }
        else { t += "五行上沒有明顯互補，要靠相處和經營。" }
        let v: NTVerdict = score >= 2 ? .good : (score <= -1 ? .bad : .neutral)
        t += "\n⑤ 綜合：" + (v == .good ? "整體合得來，彼此有吸引力也能互相幫忙。" : (v == .bad ? "差異和摩擦比較多，不是不行，但需要更多包容和溝通。" : "有合有不合，重點在溝通和給彼此空間。"))
        return (t, v)
    }
}
