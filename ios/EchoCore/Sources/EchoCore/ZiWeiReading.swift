import Foundation

/// 紫微斗數深入解讀（中文）：命宮、身宮、本命四化、十二宮、大限、流年命宮與流年四化、主題宮位。
public enum ZiWeiReading {
    static let starKey: [String: String] = [
        "紫微": "尊貴、領導、自尊心強", "天機": "聰明、善變、想得多", "太陽": "熱情、付出、好面子",
        "武曲": "剛毅、務實、重錢財", "天同": "溫和、享福、孩子氣", "廉貞": "個性鮮明、愛恨分明",
        "天府": "穩重、守成、會存錢", "太陰": "溫柔、細膩、重家庭", "貪狼": "慾望、桃花、多才多藝",
        "巨門": "口才、懷疑、是非", "天相": "公正、協調、重形象", "天梁": "照顧人、老成、逢凶化吉",
        "七殺": "衝勁、獨立、敢冒險", "破軍": "破舊立新、變動、消耗大",
        "文昌": "文書、考試", "文曲": "才藝、口才", "左輔": "貴人、平輩幫忙", "右弼": "暗中相助、人緣",
        "祿存": "穩定收入、守財", "擎羊": "衝動、競爭、刀傷", "陀羅": "拖延、糾纏", "地空": "落空、想法脫俗", "地劫": "波折、破耗",
    ]
    static let spouseStar: [String: String] = [
        "紫微": "另一半有主見、有氣質，你對感情要求高，要找讓你尊重的人；相處要給彼此面子",
        "天機": "另一半聰明、心思多，感情容易多變或聚少離多，適合聊得來、年紀有差距的人",
        "太陽": "另一半熱情大方、愛付出，也可能事業心強、很忙",
        "武曲": "另一半剛直務實、能幹，感情表達直接不浪漫，晚一點結婚比較穩",
        "天同": "另一半溫和、會享受、像小孩，感情甜，但兩個人都容易太被動",
        "廉貞": "感情愛恨分明、吸引力強，容易有波折或糾纏，需要界線",
        "天府": "另一半穩重、顧家、有經濟能力，婚姻重實際、比較穩",
        "太陰": "另一半溫柔細膩、重家庭，感情浪漫",
        "貪狼": "桃花多、感情豐富，另一半多才又愛玩，婚前容易有好幾段感情",
        "巨門": "溝通容易有誤會和口角，感情裡猜疑多，要多把話說清楚",
        "天相": "另一半公正體貼、重承諾，婚姻講規矩，你容易被照顧",
        "天梁": "另一半成熟、像長輩會照顧人，年紀差多一點比較好，但對方可能愛管你",
        "七殺": "另一半個性強、獨立，感情變動大，晚婚或各自保留空間比較好",
        "破軍": "感情起伏大、敢愛敢恨，容易分分合合，婚姻要用心經營",
    ]
    static let moneyStar: [String: String] = [
        "紫微": "賺錢靠地位和格局，適合主導、管理，花錢也大方",
        "天機": "靠頭腦、點子、資訊賺錢，收入起伏多變",
        "太陽": "靠名聲和付出賺錢，錢來得公開也花得快",
        "武曲": "正財星，賺錢能力強、有理財頭腦，越努力越有錢",
        "天同": "先苦後甜、白手起家，不太為錢拼命，量入為出就好",
        "廉貞": "錢來得快去得快，靠專業和人脈賺錢，避免投機",
        "天府": "財庫星，會存錢、守得住，收入穩定",
        "太陰": "適合慢慢累積、存錢置產，跟房地產有緣",
        "貪狼": "偏財運好、會交際賺錢，但慾望大、容易亂花",
        "巨門": "靠嘴巴、專業、競爭賺錢，錢財容易有是非",
        "天相": "收入穩定，適合在制度裡領薪水，靠信用賺錢",
        "天梁": "錢財常有人幫，但不宜投機，適合專業服務",
        "七殺": "錢財大起大落，敢衝敢拼，適合創業或業務，要留後路",
        "破軍": "花錢大方、先破後立，避免借錢和衝動投資",
    ]
    static let careerStar: [String: String] = [
        "紫微": "適合當主管、做決策、管理", "天機": "適合企劃、研究、技術、顧問",
        "太陽": "適合公職、教育、傳播、服務大眾", "武曲": "適合金融、財務、工程、軍警，執行力強",
        "天同": "適合服務、設計、休閒產業，工作要有樂趣", "廉貞": "適合公關、法律、科技，競爭力強",
        "天府": "適合管理、行政、財務，穩紮穩打", "太陰": "適合文職、設計、房地產，細膩有耐心",
        "貪狼": "適合業務、娛樂、藝術、交際", "巨門": "適合老師、律師、主播、業務，靠口才吃飯",
        "天相": "適合幕僚、秘書、公務、協調", "天梁": "適合醫療、教育、社工、監察，愛照顧人",
        "七殺": "適合開創、業務、創業，喜歡挑戰、變動多", "破軍": "適合改革、開創、跑外務，常換跑道",
    ]
    static let healthStar: [String: String] = [
        "紫微": "脾胃、消化，壓力大時腸胃不適", "天機": "肝膽、神經、四肢，想太多容易失眠",
        "太陽": "心臟、血壓、眼睛、頭部，注意過勞", "武曲": "肺、呼吸道、牙齒、骨骼",
        "天同": "泌尿、腎、膀胱，也容易水腫發胖", "廉貞": "血液、循環、生殖泌尿",
        "天府": "脾胃，體質大致穩定", "太陰": "腎、內分泌、眼睛",
        "貪狼": "肝腎、生殖，小心菸酒熬夜", "巨門": "口腔、腸胃、呼吸道，病從口入",
        "天相": "皮膚、泌尿", "天梁": "脾胃、心臟，多半能逢凶化吉",
        "七殺": "呼吸道、意外傷、開刀，小心運動傷害", "破軍": "腎、泌尿、生殖，容易透支",
    ]
    static let luGood: [String: String] = [
        "命宮": "自己運氣好、心情開朗、機會多", "兄弟": "兄弟朋友、合夥有助力，現金流順",
        "夫妻": "感情甜、有桃花或好的互動", "子女": "子女、桃花、合夥、創作有好消息",
        "財帛": "進財順、收入增加", "疾厄": "身體狀況好、生活享受",
        "遷移": "出門在外有機會，貴人在外地", "交友": "朋友人脈帶來好處",
        "官祿": "工作順、有升遷或好案子", "田宅": "家庭和樂，有置產或搬家的好消息",
        "福德": "心情愉快、享福，興趣有收穫", "父母": "長輩上司照顧，文書考試順",
    ]
    static let jiBad: [String: String] = [
        "命宮": "自己想不開、壓力大、容易鑽牛角尖", "兄弟": "兄弟朋友、合夥有摩擦，現金週轉緊",
        "夫妻": "感情摩擦、誤會，另一半讓你操心", "子女": "子女、桃花、合夥的事讓你煩心",
        "財帛": "錢財緊、容易破財、為錢煩惱", "疾厄": "身體容易出狀況、疲勞累積",
        "遷移": "出門不順，在外容易有意外或是非", "交友": "被朋友拖累、人際是非",
        "官祿": "工作壓力大、不順或變動", "田宅": "家裡有事、房子相關的麻煩",
        "福德": "心情煩悶、睡不好、想太多", "父母": "跟長輩上司不合，文書手續出狀況",
    ]
    static let sihuaMeaning = ["化祿": "資源、順利、緣分", "化權": "掌控、主導、用力", "化科": "名聲、貴人、體面", "化忌": "執著、阻礙、虧欠"]
    static let sha: Set<String> = ["擎羊", "陀羅", "地空", "地劫"]

    static func pname(_ raw: String) -> String { raw.hasSuffix("宮") ? raw : raw + "宮" }
    /// 宮位含義（不帶句號，方便接在句子中間）
    static func ptext(_ p: String) -> String {
        var s = ManticData.ziweiPalaceText[p] ?? ""
        if s.hasSuffix("。") { s.removeLast() }
        return s
    }
    static func branchOf(_ zw: ZiWei, star: String) -> Int? {
        (0..<12).first { zw.main[$0].contains(star) || zw.aux[$0].contains(star) }
    }
    static func mainStars(_ zw: ZiWei, _ b: Int) -> (stars: [String], borrowed: Bool) {
        if !zw.main[b].isEmpty { return (zw.main[b], false) }
        return (zw.main[Astro.pmod(b + 6, 12)], true)
    }
    static func starsLine(_ zw: ZiWei, _ b: Int) -> String {
        let (ms, borrowed) = mainStars(zw, b)
        let main = ms.map { $0 + (zw.sihuaOf[$0] ?? "") }.joined(separator: "、")
        var s = borrowed ? "空宮，借對宮\(main)" : main
        let ax = zw.aux[b].map { $0 + (zw.sihuaOf[$0] ?? "") }
        if !ax.isEmpty { s += "，輔星" + ax.joined(separator: "、") }
        return s
    }

    /// 某一年的流年四化落在哪些本命宮位
    static func yearSihua(_ zw: ZiWei, year y: Int) -> [(tag: String, star: String, palace: String?)] {
        let stem = GZ.stems[Astro.pmod(y - 4, 60) % 10]
        return hua(zw, stem: stem)
    }

    static func natalSihua(_ zw: ZiWei) -> [(tag: String, star: String, palace: String?)] {
        hua(zw, stem: GZ.stems[zw.yearStem])
    }

    static func hua(_ zw: ZiWei, stem: String) -> [(tag: String, star: String, palace: String?)] {
        var out: [(tag: String, star: String, palace: String?)] = []
        let stars = ZiWei.sihua[stem]!
        for i in 0..<4 {
            let b = branchOf(zw, star: stars[i])
            out.append((tag: ZiWei.sihuaNames[i], star: stars[i], palace: b.flatMap { zw.palaceAt[$0] }))
        }
        return out
    }


    // MARK: - 三方四正與格局

    static func sanfang(_ zw: ZiWei) -> [Int] {
        [zw.ming, zw.palaceOf("財帛"), zw.palaceOf("官祿"), zw.palaceOf("遷移")]
    }

    static func patterns(_ zw: ZiWei) -> [String] {
        let sf = sanfang(zw)
        let mains = Set(sf.flatMap { zw.main[$0] })
        let all = mains.union(sf.flatMap { zw.aux[$0] })
        let ming = Set(zw.main[zw.ming])
        var out: [String] = []
        if !ming.isDisjoint(with: ["七殺", "破軍", "貪狼"]) {
            out.append("殺破狼：一生變動大、敢衝敢闖，適合開創、業務、創業；要學會收，別一直換")
        }
        if ming.isSuperset(of: ["紫微", "天府"]) { out.append("紫府同宮：穩重有領導力、格局大，但容易自視太高") }
        if mains.intersection(["天機", "太陰", "天同", "天梁"]).count >= 3 {
            out.append("機月同梁：適合穩定的上班、公職、文職、專業技術，重安定")
        }
        if all.isSuperset(of: ["太陽", "天梁", "文昌", "祿存"]) { out.append("陽梁昌祿：利考試、學歷、證照，讀書和專業能出頭") }
        if mains.isSuperset(of: ["天府", "天相"]) && ming.isDisjoint(with: ["天府", "天相"]) {
            out.append("府相朝垣：有貴人、做事穩當，適合管理和守成")
        }
        if zw.main[zw.ming].isEmpty { out.append("命無正曜：可塑性大，容易受環境和身邊的人影響，遷移宮（在外）特別重要") }
        return out
    }

    // MARK: - 本命

    public static func natal(_ zw: ZiWei, male: Bool?, age: Int, year: Int) -> String {
        var t = "【紫微命盤】農曆\(zw.lunar.text)\(GZ.branches[zw.hourBranch])時生，\(ZiWei.juNames[zw.ju]!)。"
        let (ms, borrowed) = mainStars(zw, zw.ming)
        t += "\n\n① 命宮在\(GZ.branches[zw.ming])宮：\(starsLine(zw, zw.ming))。"
        if borrowed { t += "命宮沒有主星，性格比較受環境和身邊的人影響，可塑性大。" }
        for s in ms { t += "\n  · \(s)：\(ManticData.starText[s] ?? "")" }
        for s in zw.aux[zw.ming] where sha.contains(s) { t += "\n  · 命宮有\(s)：\(ManticData.starText[s] ?? "")" }
        let sf = sanfang(zw)
        t += "\n  · 三方四正（財帛、官祿、遷移）：" + sf.dropFirst().map { "\(pname(zw.palaceAt[$0]!))\(mainStars(zw, $0).stars.joined(separator: "、"))" }.joined(separator: "；") + "。"
        let pats = patterns(zw)
        if !pats.isEmpty { t += "\n  · 格局：" + pats.joined(separator: "；") + "。" }
        let shenPalace = zw.palaceAt[zw.shen]!
        t += "\n② 身宮在\(GZ.branches[zw.shen])，落在\(pname(shenPalace))：後天的重心會放在\(ManticData.ziweiPalaceText[shenPalace] ?? "")"
        t += "\n③ 本命四化（\(GZ.stems[zw.yearStem])年生）："
        for h in natalSihua(zw) {
            guard let p = h.palace else { continue }
            t += "\n  · \(h.star)\(h.tag)在\(pname(p))：" + sihuaLine(h.tag, palace: p, natal: true)
        }
        t += "\n④ 十二宮速覽："
        for i in 0..<12 {
            let b = Astro.pmod(zw.ming - i, 12)
            let name = zw.palaceAt[b]!
            let (m, _) = mainStars(zw, b)
            let key = m.first.flatMap { starKey[$0] } ?? ""
            t += "\n  · \(pname(name))（\(GZ.branches[b])）：\(starsLine(zw, b))" + (key.isEmpty ? "" : "——\(key)")
        }
        t += "\n⑤ 幾個重點："
        t += "\n  · 感情（夫妻宮）：" + palaceStarText(zw, "夫妻", table: spouseStar)
        t += "\n  · 錢財（財帛宮）：" + palaceStarText(zw, "財帛", table: moneyStar)
        t += "\n  · 事業（官祿宮）：" + palaceStarText(zw, "官祿", table: careerStar)
        t += "\n  · 健康（疾厄宮）：" + palaceStarText(zw, "疾厄", table: healthStar)
        if male == nil {
            t += "\n⑥ 大限：大限的順逆要看性別，告訴我「我是男生／女生」就能排。"
        } else if let d = zw.decade(atAge: age) {
            let p = zw.palaceAt[d.branch]!
            t += "\n⑥ 大限：\(d.from)–\(d.to)歲走\(GZ.branches[d.branch])宮（本命\(pname(p))，\(starsLine(zw, d.branch))），這十年的重點在\(ManticData.ziweiPalaceText[p] ?? "")"
        }
        let ly = GZ.branches[Astro.pmod(year - 4, 60) % 12]
        t += "\n⑦ \(year)年：流年命宮走到\(ly)宮。想看詳細可以問「我的紫微今年運勢」「紫微看感情」「我的財帛宮」。"
        return t
    }

    static func palaceStarText(_ zw: ZiWei, _ palace: String, table: [String: String]) -> String {
        let b = zw.palaceOf(palace)
        let (ms, borrowed) = mainStars(zw, b)
        var parts = ms.compactMap { s in table[s].map { "\(s)——\($0)" } }
        if parts.isEmpty { parts = ["宮內沒有主星，看對宮"] }
        var s = (borrowed ? "空宮借對宮，" : "") + parts.joined(separator: "；")
        let hua = ms.compactMap { st in zw.sihuaOf[st].map { st + $0 } } + zw.aux[b].compactMap { st in zw.sihuaOf[st].map { st + $0 } }
        if !hua.isEmpty { s += "；有" + hua.joined(separator: "、") }
        let bad = zw.aux[b].filter { sha.contains($0) }
        if !bad.isEmpty { s += "；有" + bad.joined(separator: "、") + "，多一點波折" }
        return s + "。"
    }

    static func sihuaLine(_ tag: String, palace p: String, natal: Bool) -> String {
        switch tag {
        case "化祿": return (natal ? "天生在這裡有資源、有福氣：" : "今年這方面有好處：") + (luGood[p] ?? "") + "。"
        case "化權": return (natal ? "你在這方面想掌控、會用力，也比較有主導權。" : "今年這方面你會比較用力、想掌控，有權也有壓力。")
        case "化科": return (natal ? "這方面有好名聲、有貴人，事情能體面解決。" : "今年這方面有貴人、有好名聲，事情能順利化解。")
        default: return (natal ? "一生在這方面比較執著、容易有缺憾，是要修的課題：" : "今年這方面最容易卡、煩心，要小心：") + (jiBad[p] ?? "") + "。"
        }
    }

    // MARK: - 流年

    public static func year(_ zw: ZiWei, male: Bool?, age: Int, year y: Int) -> (text: String, verdict: NTVerdict) {
        let gz = Astro.pmod(y - 4, 60)
        let lb = gz % 12
        let lp = zw.palaceAt[lb]!
        var t = "【紫微流年 \(y) \(GZ.name(gz))年】"
        t += "\n① 流年命宮：今年走到\(GZ.branches[lb])宮，也就是你本命的\(pname(lp))（\(starsLine(zw, lb))）。"
        t += "今年的重心會放在\(ManticData.ziweiPalaceText[lp] ?? "")"
        let (ms, _) = mainStars(zw, lb)
        if let s = ms.first, let k = starKey[s] { t += "\(s)坐流年命宮，今年的你比較\(k)。" }
        let bad = zw.aux[lb].filter { sha.contains($0) }
        if !bad.isEmpty { t += "流年命宮有\(bad.joined(separator: "、"))，今年容易有波折和情緒起伏。" }

        t += "\n② 流年四化（\(GZ.stems[gz % 10])干）："
        var score = 0.0
        let hs = yearSihua(zw, year: y)
        for h in hs {
            guard let p = h.palace else { t += "\n  · \(h.star)\(h.tag)：不在你的盤上。"; continue }
            t += "\n  · \(h.star)\(h.tag)落在\(pname(p))：" + sihuaLine(h.tag, palace: p, natal: false)
            let key = ["命宮", "財帛", "官祿", "夫妻", "疾厄", "福德"].contains(p)
            if h.tag == "化祿" { score += key ? 1.2 : 0.6 }
            if h.tag == "化科" { score += 0.3 }
            if h.tag == "化忌" { score -= key ? 1.5 : 0.8 }
        }
        // 流年忌沖：化忌所在宮的對宮受沖
        if let ji = hs.last, let p = ji.palace {
            let b = zw.palaceOf(p)
            let opp = zw.palaceAt[Astro.pmod(b + 6, 12)]!
            t += "\n  · 化忌在\(pname(p))，會沖到對面的\(pname(opp))，\(ptext(opp))這方面也會被牽動。"
            if opp == "命宮" { score -= 0.8 }
        }
        // 本命化忌被流年引動
        if let nj = natalSihua(zw).last, let np = nj.palace, hs.contains(where: { $0.palace == np && $0.tag == "化忌" }) {
            t += "\n  · 本命化忌和流年化忌都在\(pname(np))，雙忌疊在一起，這一年\(jiBad[np] ?? "")會特別明顯。"
            score -= 1.0
        }

        if male == nil {
            t += "\n③ 大限：要知道性別才能排大限，告訴我「我是男生／女生」。"
        } else if let d = zw.decade(atAge: age) {
            let dp = zw.palaceAt[d.branch]!
            t += "\n③ 大限：\(d.from)–\(d.to)歲走本命\(pname(dp))（\(starsLine(zw, d.branch))），這十年的主軸是\(ManticData.ziweiPalaceText[dp] ?? "")"
            if hs.last?.palace == dp { t += "今年的化忌正好落在大限命宮，是這十年裡比較辛苦的一年。"; score -= 0.8 }
            if hs.first?.palace == dp { t += "今年的化祿落在大限命宮，是這十年裡比較順的一年。"; score += 0.8 }
        }
        let v: NTVerdict = score >= 0.8 ? .good : (score <= -0.8 ? .bad : .neutral)
        t += "\n④ 綜合：今年整體是" + ["好", "中性", "壞"][v.rawValue] + "的。"
        if let lu = hs.first?.palace { t += "最順的是\(pname(lu))（\(luGood[lu] ?? "")），可以多往這裡用力；" }
        if let ji = hs.last?.palace { t += "最要小心的是\(pname(ji))（\(jiBad[ji] ?? "")）。" }
        return (t, v)
    }


    // MARK: - 流月（斗君起正月）

    /// 流年的正月從「斗君」起：由流年命宮逆數到生月、再順數到生時；之後每月順行一宮
    static func douJun(_ zw: ZiWei, year y: Int) -> Int {
        var lm = zw.lunar.month
        if zw.lunar.isLeap && zw.lunar.day > 15 { lm = lm % 12 + 1 }
        return Astro.pmod(Astro.pmod(y - 4, 60) % 12 - (lm - 1) + zw.hourBranch, 12)
    }

    static func monthInfo(_ zw: ZiWei, year y: Int, lunarMonth m: Int) -> (branch: Int, palace: String, ji: String?, lu: String?) {
        let b = Astro.pmod(douJun(zw, year: y) + m - 1, 12)
        let ys = Astro.pmod(y - 4, 60) % 10
        let stem = GZ.stems[((ys % 5) * 2 + 2 + m - 1) % 10]
        let h = hua(zw, stem: stem)
        return (b, zw.palaceAt[b]!, h.last?.palace, h.first?.palace)
    }

    public static func month(_ zw: ZiWei, now: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: now)
        let ld = LunarCalendar.shared.lunar(c.year!, c.month!, c.day!)
        let y = ld.year
        let info = monthInfo(zw, year: y, lunarMonth: ld.month)
        var t = "【紫微流月 · 農曆\(GZ.monthNames[ld.month - 1])月】"
        t += "\n這個月的流月命宮走到\(GZ.branches[info.branch])宮，也就是你本命的\(pname(info.palace))（\(starsLine(zw, info.branch))）：這個月的重心在\(ManticData.ziweiPalaceText[info.palace] ?? "")"
        if let lu = info.lu { t += "\n流月化祿在\(pname(lu))：\(luGood[lu] ?? "")。" }
        if let ji = info.ji { t += "\n流月化忌在\(pname(ji))：\(jiBad[ji] ?? "")，這個月這方面要小心。" }
        t += "\n\n今年每個月的重點："
        for m in 1...12 {
            let i = monthInfo(zw, year: y, lunarMonth: m)
            t += "\n• 農曆\(GZ.monthNames[m - 1])月：走\(pname(i.palace))" + (i.ji.map { "，化忌在\(pname($0))" } ?? "") + (m == ld.month ? " ← 這個月" : "")
        }
        return t
    }

    // MARK: - 主題宮位

    public static func palace(_ zw: ZiWei, name: String, year y: Int) -> String {
        let b = zw.palaceOf(name)
        let table: [String: String]? = ["夫妻": spouseStar, "財帛": moneyStar, "官祿": careerStar, "疾厄": healthStar][name]
        var t = "【紫微 · \(pname(name))】\(pname(name))管\(ManticData.ziweiPalaceText[name] ?? "")"
        t += "\n① 在\(GZ.branches[b])宮：\(starsLine(zw, b))。"
        let (ms, borrowed) = mainStars(zw, b)
        if borrowed { t += "空宮借對宮的星，這方面比較受外在環境影響。" }
        for s in ms { t += "\n  · \(s)：" + (table?[s] ?? ManticData.starText[s] ?? "") }
        for s in zw.aux[b] { t += "\n  · \(s)：\(starKey[s] ?? "")" }
        let hua = natalSihua(zw).filter { $0.palace == name }
        for h in hua { t += "\n② 本命\(h.star)\(h.tag)在這裡：" + sihuaLine(h.tag, palace: name, natal: true) }
        let opp = Astro.pmod(b + 6, 12)
        t += "\n③ 對宮是\(pname(zw.palaceAt[opp]!))（\(starsLine(zw, opp))），也會影響這一宮。"
        let gz = Astro.pmod(y - 4, 60)
        let ys = yearSihua(zw, year: y).filter { $0.palace == name }
        t += "\n④ \(y)年："
        if gz % 12 == b { t += "流年命宮正好走到這一宮，今年這方面就是主題。" }
        if ys.isEmpty { t += "流年四化沒有落在這裡，照本命的樣子走。" }
        for h in ys { t += "流年\(h.star)\(h.tag)落在這裡：" + sihuaLine(h.tag, palace: name, natal: false) }
        if let ji = yearSihua(zw, year: y).last?.palace, zw.palaceAt[Astro.pmod(zw.palaceOf(ji) + 6, 12)] == name {
            t += "流年化忌從對宮\(pname(ji))沖過來，這方面今年會被干擾。"
        }
        return t
    }
}
