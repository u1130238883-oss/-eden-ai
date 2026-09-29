import Foundation

/// 中文的八字／紫微問句：判斷要看本命、流年、流月、大運還是主題，交給 BaZiReading／ZiWeiReading 寫成完整解讀。
/// 句子裡直接帶生日和時間（「1990年5月3日早上7點的八字」）就用那個生日排，不會改掉使用者自己的生日。
public enum ManticReader {
    public struct Output {
        public let text: String
        public let card: FortuneCard?
        /// 還缺什麼資料（"hour"、"birthday"），App 下一句會等使用者補上
        public let needs: String?
        /// 要上網查的關鍵組合（例如「太陰化忌 命宮」），App 會查完再對照盤面分析
        public var search: [String] = []
        /// 盤面重點（和網路資料對照用）
        public var summary: String = ""
    }

    static let baziWords = ["八字", "日主", "四柱", "十神", "喜用", "五行缺", "我缺什麼", "缺什麼五行", "五行"]
    static let ziweiWords = ["紫微", "主星", "大限", "斗數", "命盤星"]
    static let topicWords: [(String, [String])] = [
        ("感情", ["感情", "婚姻", "桃花", "另一半", "戀愛", "姻緣", "老公", "老婆", "對象", "結婚", "配偶"]),
        ("錢財", ["財運", "錢財", "賺錢", "錢", "財富", "收入", "投資"]),
        ("事業", ["事業", "工作", "職業", "升職", "創業"]),
        ("健康", ["健康", "身體", "疾病", "生病"]),
        ("學業", ["學業", "考試", "讀書", "升學", "證照", "成績"]),
        ("家庭", ["家庭", "父母", "爸媽", "媽媽", "爸爸", "家人"]),
    ]
    static let ziweiTopicPalace = ["感情": "夫妻", "錢財": "財帛", "事業": "官祿", "健康": "疾厄", "學業": "父母", "家庭": "田宅"]

    static func has(_ s: String, _ keys: [String]) -> Bool { keys.contains { s.contains($0) } }

    public static func wants(_ raw: String) -> Bool {
        let t = raw.replacingOccurrences(of: " ", with: "")
        return has(t, baziWords) || has(t, ziweiWords) || has(t, ManticRouter.palaceWords)
    }

    static func dayAsk(_ t: String) -> (String, Int)? {
        if t.contains("後天") { return ("後天", 2) }
        if t.contains("明天") || t.contains("明日") { return ("明天", 1) }
        if t.contains("今天") || t.contains("今日") { return ("今天", 0) }
        return nil
    }

    static func targetYear(_ t: String, now: Int) -> Int {
        if t.contains("明年") { return now + 1 }
        if t.contains("去年") { return now - 1 }
        if t.contains("後年") { return now + 2 }
        if let g = RuleBook.match(t, #"((?:19|20)\d{2})年(?!\d{1,2}月)"#), let y = Int(g[0]) { return y }
        return now
    }

    public static func route(_ raw: String, profile: UserProfile, now: Date) -> Output? {
        let text = raw.replacingOccurrences(of: " ", with: "")
        let isBazi = has(text, baziWords)
        let isZiwei = has(text, ziweiWords) || has(text, ManticRouter.palaceWords)
        guard isBazi || isZiwei else { return nil }
        // 「八字是什麼」「紫微斗數準嗎」是知識題，交給資料庫
        if has(text, FortuneRouter.knowledgeMarkers) && !text.contains("我") && FortuneRouter.parseDate(raw) == nil { return nil }
        if text.contains("五行") && !isZiwei && !has(text, ["八字", "我", "缺"]) { return nil }

        let cal = Calendar(identifier: .gregorian)
        let nowC = cal.dateComponents([.year, .month, .day], from: now)
        let nowYear = nowC.year!

        // 八字合婚：「我跟1999年8月8日的人八字合不合」
        if isBazi, has(text, ["合不合", "合婚", "配不配", "合盤", "速配", "適不適合在一起"]), let other = FortuneRouter.parseDate(raw) {
            guard let mine = profile.birthday else {
                return Output(text: "我需要你自己的生日才能合八字。先告訴我，例如：我是2000年1月1日早上8點出生的女生。", card: nil, needs: "birthday")
            }
            let a = BaZi(mine.year, mine.month, mine.day, hour: profile.hour, minute: profile.minute ?? 0, male: profile.male ?? true)
            let upd = ProfileParser.parse(raw, expectingTime: true)
            let b = BaZi(other.year, other.month, other.day, hour: upd?.hour, minute: upd?.minute ?? 0, male: guessGender(raw) ?? !(profile.male ?? true))
            let name = Persona.otherPerson(raw) ?? "對方"
            let r = BaZiReading.match(a, b, nameB: name == "他" || name == "她" ? "對方" : name)
            return Output(text: r.text, card: FortuneCard(title: "八字合盤", headline: "\(GZ.name(a.day))日 × \(GZ.name(b.day))日", verdict: r.verdict,
                                                          details: [], pillars: nil), needs: nil)
        }

        // 句子裡帶生日：用那個生日排（不改使用者的生日）
        var prof = profile
        var who = "你"
        if let d = FortuneRouter.parseDate(raw) {
            let aboutMe = has(text, ["我的生日", "我是", "我生"])
            prof.birthday = d
            let upd = ProfileParser.parse(raw, expectingTime: true)
            prof.hour = upd?.hour; prof.minute = upd?.minute
            if let m = upd?.male { prof.male = m } else if !aboutMe { prof.male = nil }
            if !aboutMe {
                let time = prof.hour.map { String(format: " %02d:%02d", $0, prof.minute ?? 0) } ?? ""
                if let rel = Persona.otherPerson(raw) {
                    who = "\(rel)（\(d.display)\(time)）"
                    if prof.male == nil { prof.male = guessGender(raw) }
                } else {
                    who = "這個命盤（\(d.display)\(time)）"
                }
            }
        }
        guard let bd = prof.birthday else {
            return Output(text: "我還不知道你的生日，沒辦法排盤。直接告訴我，例如：我是2000年1月1日早上8點出生的女生。", card: nil, needs: "birthday")
        }
        let y = targetYear(text, now: nowYear)
        let age = y - bd.year
        // 幫別人看時，「老公」「媽媽」是在說誰，不是在問感情、家庭
        var topicText = text
        if who != "你" { for (k, _) in Persona.others { topicText = topicText.replacingOccurrences(of: k, with: "") } }
        let topic = topicWords.first { has(topicText, $0.1) }?.0
        let yearAsk = has(text, ["今年", "明年", "去年", "後年", "流年", "運勢", "運氣", "這一年", "順不順"]) || targetYear(text, now: nowYear) != nowYear
        let monthAsk = has(text, ["這個月", "本月", "流月", "每個月"])

        if isBazi && !(isZiwei && !text.contains("八字")) {
            let b = BaZi(bd.year, bd.month, bd.day, hour: prof.hour, minute: prof.minute ?? 0, male: prof.male ?? true)
            let card = baziCard(b)
            var body: String
            if text.contains("大運") && prof.male == nil {
                return Output(text: "大運的順逆要看性別。告訴我「我是男生」或「我是女生」就可以了。", card: nil, needs: "gender")
            }
            if let topic {
                body = BaZiReading.topic(b, male: prof.male, kind: topic, y: y)
            } else if let da = dayAsk(text) {
                let d = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: da.1, to: now)!)
                body = BaZiReading.day(b, male: prof.male, date: (d.year!, d.month!, d.day!), label: da.0)
            } else if monthAsk {
                body = BaZiReading.month(b, male: prof.male, date: (nowC.year!, nowC.month!, nowC.day!))
            } else if text.contains("大運") {
                body = baziLuck(b, birthYear: bd.year, nowYear: nowYear)
            } else if yearAsk && !has(text, ["命盤", "分析我的八字", "排八字", "排盤"]) {
                body = BaZiReading.year(b, male: prof.male, y: y, birthYear: bd.year).text
            } else {
                body = BaZiReading.natal(b, male: prof.male, nowYear: nowYear, birthYear: bd.year)
            }
            if who != "你" { body = "以\(who)來看：\n" + personalize(body, raw) }
            var out = Output(text: body, card: card, needs: nil)
            let sr = baziSearch(b, topic: topic, y: y, yearAsk: yearAsk)
            out.search = sr.terms; out.summary = sr.summary
            return out
        }

        // 紫微斗數需要時辰
        guard let hour = prof.hour else {
            return Output(text: "紫微斗數要用出生時辰才能排盤（命宮、身宮都跟時辰有關）。告訴我你幾點出生，例如「早上7點」「晚上11點半」或「辰時」，我馬上幫你排。",
                          card: nil, needs: "hour")
        }
        let zw = ZiWei(bd.year, bd.month, bd.day, hour: hour, male: prof.male ?? true)
        let card = ziweiCard(zw)
        var body: String
        if let pw = ManticRouter.palaceWords.first(where: { text.contains($0) }) {
            body = ZiWeiReading.palace(zw, name: String(pw.dropLast()), year: y)
        } else if text.contains("命宮") && !yearAsk {
            body = ZiWeiReading.natal(zw, male: prof.male, age: age, year: y)
        } else if let topic, let p = ziweiTopicPalace[topic] {
            body = ZiWeiReading.palace(zw, name: p, year: y)
        } else if text.contains("大限") {
            if prof.male == nil {
                return Output(text: "大限的順逆要看性別。告訴我「我是男生」或「我是女生」就可以了。", card: nil, needs: "gender")
            }
            body = ziweiDecades(zw, age: nowYear - bd.year)
        } else if monthAsk {
            body = ZiWeiReading.month(zw, now: now)
        } else if yearAsk && !has(text, ["命盤", "排盤"]) {
            body = ZiWeiReading.year(zw, male: prof.male, age: age, year: y).text
        } else {
            body = ZiWeiReading.natal(zw, male: prof.male, age: nowYear - bd.year, year: nowYear)
        }
        if who != "你" { body = "以\(who)來看：\n" + personalize(body, raw) }
        var out = Output(text: body, card: card, needs: nil)
        let focusPalace = ManticRouter.palaceWords.first(where: { text.contains($0) }).map { String($0.dropLast()) } ?? topic.flatMap { ziweiTopicPalace[$0] }
        let sr = ziweiSearch(zw, palace: focusPalace, y: y, yearAsk: yearAsk)
        out.search = sr.terms; out.summary = sr.summary
        return out
    }

    /// 八字要上網查的組合與盤面重點
    static func baziSearch(_ b: BaZi, topic: String?, y: Int, yearAsk: Bool) -> (terms: [String], summary: String) {
        let dm = GZ.stems[b.dayMaster] + BaZi.wuxing[BaZi.stemEl[b.dayMaster]]
        let strong = b.strength().strong
        let fa = BaZiReading.favAndAvoid(b)
        let gz = Astro.pmod(y - 4, 60)
        var terms: [String]
        if let topic {
            terms = ["八字 \(dm)日主 \(topic)", "\(dm)日主 \(strong ? "身強" : "身弱") \(topic)"]
        } else if yearAsk {
            let key = BaZiReading.effect(BaZiReading.group(BaZiReading.stemGod(b, gz % 10)), strong: strong, male: nil)
                .components(separatedBy: "：").first ?? ""
            terms = ["\(dm)日主 \(GZ.name(gz))年 運勢", "八字 \(key)"]
        } else {
            let mGod = BaZiReading.branchGod(b, b.pillars[1] % 12)
            terms = ["\(dm)日主 生於\(GZ.branches[b.pillars[1] % 12])月", "八字 \(mGod)格 性格"]
        }
        var summary = "你的日主是\(dm)，\(strong ? "身強" : "身弱")，喜\(fa.fav.map { BaZi.wuxing[$0] }.joined(separator: "、"))，忌\(fa.avoid.map { BaZi.wuxing[$0] }.joined(separator: "、"))"
        if yearAsk { summary += "；\(y)年\(GZ.name(gz))對你是\(BaZiReading.vword(BaZiReading.yearScore(b, y).score))的" }
        return (terms, summary)
    }

    /// 紫微要上網查的組合與盤面重點
    static func ziweiSearch(_ zw: ZiWei, palace: String?, y: Int, yearAsk: Bool) -> (terms: [String], summary: String) {
        let ming = ZiWeiReading.mainStars(zw, zw.ming).stars.joined(separator: "")
        var terms: [String] = []
        if let p = palace {
            let st = ZiWeiReading.mainStars(zw, zw.palaceOf(p)).stars.joined(separator: "")
            terms = ["紫微斗數 \(st)在\(ZiWeiReading.pname(p))"]
        } else if yearAsk {
            let hs = ZiWeiReading.yearSihua(zw, year: y)
            if let ji = hs.last, let p = ji.palace { terms.append("紫微斗數 流年\(ji.star)化忌 \(ZiWeiReading.pname(p))") }
            if let lu = hs.first, let p = lu.palace { terms.append("紫微斗數 流年\(lu.star)化祿 \(ZiWeiReading.pname(p))") }
        } else {
            terms = ["紫微斗數 \(ming)坐命宮"]
            if let nj = ZiWeiReading.natalSihua(zw).last, let p = nj.palace { terms.append("紫微斗數 \(nj.star)化忌在\(ZiWeiReading.pname(p))") }
        }
        var summary = "你的命宮主星是\(ming.isEmpty ? "空宮" : ming)"
        if yearAsk, let ji = ZiWeiReading.yearSihua(zw, year: y).last, let p = ji.palace {
            summary += "；\(y)年流年化忌在\(ZiWeiReading.pname(p))"
        }
        return (terms, summary)
    }

    /// 幫別人看：「你的」換成「你老公的」
    static func personalize(_ body: String, _ raw: String) -> String {
        guard let rel = Persona.otherPerson(raw), rel != "他", rel != "她" else { return body }
        return body.replacingOccurrences(of: "你的", with: "\(rel)的").replacingOccurrences(of: "對你是", with: "對\(rel)是")
    }

    /// 從稱呼猜性別（老公、爸爸、他 → 男；老婆、媽媽、她 → 女）
    static func guessGender(_ t: String) -> Bool? {
        let m = ["老公", "先生", "男朋友", "男友", "爸爸", "父親", "我爸", "兒子", "哥哥", "弟弟", "他", "男生", "男的"]
        let f = ["老婆", "太太", "女朋友", "女友", "媽媽", "母親", "我媽", "女兒", "姐姐", "妹妹", "她", "女生", "女的"]
        if f.contains(where: { t.contains($0) }) { return false }
        if m.contains(where: { t.contains($0) }) { return true }
        return nil
    }

    static func baziLuck(_ b: BaZi, birthYear: Int, nowYear: Int) -> String {
        let (start, seq) = b.luck(count: 8)
        let age = nowYear - birthYear
        var t = "【八字大運】\(start)歲起運，每十年換一步："
        for (i, gz) in seq.enumerated() {
            let from = start + 10 * i
            let s = BaZiReading.luckScore(b, gz)
            let mark = (age >= from && age < from + 10) ? " ← 現在" : ""
            t += "\n• \(from)–\(from + 9)歲 \(GZ.name(gz))（\(GZ.stems[gz % 10])＝\(BaZiReading.stemGod(b, gz % 10))、\(GZ.branches[gz % 12])＝\(BaZiReading.branchGod(b, gz % 12))）：\(BaZiReading.vword(s))\(mark)"
        }
        let fa = BaZiReading.favAndAvoid(b)
        t += "\n大運的地支管得比較久、比較重。你喜\(fa.fav.map { BaZi.wuxing[$0] }.joined(separator: "、"))，走到這些五行的大運就順，走到\(fa.avoid.map { BaZi.wuxing[$0] }.joined(separator: "、"))的大運就比較辛苦。"
        return t
    }

    static func ziweiDecades(_ zw: ZiWei, age: Int) -> String {
        var t = "【紫微大限】\(ZiWei.juNames[zw.ju]!)，\(zw.ju)歲起限，每十年走一個宮："
        for d in zw.decades().prefix(9) {
            let p = zw.palaceAt[d.branch]!
            let mark = (age >= d.from && age <= d.to) ? " ← 現在" : ""
            t += "\n• \(d.from)–\(d.to)歲 \(GZ.branches[d.branch])宮（本命\(ZiWeiReading.pname(p))）：\(ZiWeiReading.starsLine(zw, d.branch))\(mark)"
        }
        if let d = zw.decade(atAge: age) {
            let p = zw.palaceAt[d.branch]!
            t += "\n現在這十年走本命\(ZiWeiReading.pname(p))，重點在\(ManticData.ziweiPalaceText[p] ?? "")"
        }
        return t
    }

    static func baziCard(_ b: BaZi) -> FortuneCard {
        let ps = b.pillars.map(GZ.name)
        let (strong, ratio) = b.strength()
        let fav = b.favorable()
        let c = b.elementCounts()
        var card = FortuneCard(title: "八字 · 四柱", headline: "日主 \(ps[2].prefix(1))\(BaZi.wuxing[BaZi.stemEl[b.dayMaster]])",
                               verdict: nil, details: [], pillars: ps,
                               pillarGods: b.pillars.enumerated().map { $0.offset == 2 ? "日主" : BaZi.tenGod(dayStem: b.dayMaster, other: $0.element % 10) })
        card.details = ["五行 " + (0..<5).map { "\(BaZi.wuxing[$0])\(String(format: "%.1f", c[$0]))" }.joined(separator: " "),
                        "\(strong ? "身強" : "身弱")（生扶 \(Int(ratio * 100))%）· 喜用 \(BaZi.wuxing[fav[0]])\(BaZi.wuxing[fav[1]])"]
        if !b.hasHour { card.details.append("未設定出生時辰，只排三柱") }
        return card
    }

    static func ziweiCard(_ zw: ZiWei) -> FortuneCard {
        let grid = (0..<12).map { b in
            ZiWeiCell(branch: b, stem: GZ.stems[zw.stemAt[b]!], palace: zw.palaceAt[b]!,
                      stars: zw.starsText(b, withAux: true), isMing: b == zw.ming, isShen: b == zw.shen)
        }
        return FortuneCard(title: "紫微斗數 · \(zw.lunar.text)\(GZ.branches[zw.hourBranch])時",
                           headline: "命宮 \(GZ.branches[zw.ming]) · \(ZiWei.juNames[zw.ju]!)", verdict: nil, details: [], ziwei: grid)
    }
}

extension ManticReader {
    static let elementAdvice = [
        "木：多接觸大自然、閱讀、學新東西、訂成長計畫，早睡早起",
        "火：多曬太陽、運動流汗、主動社交、把自己表現出來",
        "土：規律作息、存錢、把生活穩定下來，做事一步一步來",
        "金：整理環境、斷捨離、訂規則和紀律、做重量訓練",
        "水：多喝水、游泳、旅行、多讀書思考，讓自己流動起來",
    ]

    /// 八字／紫微之後的追問：為什麼、怎麼辦、再多說一點
    public static func followup(_ kind: Reader.FollowKind, query raw: String, profile: UserProfile, now: Date) -> String? {
        let text = raw.replacingOccurrences(of: " ", with: "")
        guard let bd = FortuneRouter.parseDate(raw) ?? profile.birthday else { return nil }
        let nowYear = Calendar(identifier: .gregorian).component(.year, from: now)
        let y = targetYear(text, now: nowYear)
        let isZiwei = has(text, ziweiWords) || has(text, ManticRouter.palaceWords)
        if isZiwei && !text.contains("八字"), let hour = profile.hour {
            let zw = ZiWei(bd.year, bd.month, bd.day, hour: hour, male: profile.male ?? true)
            let hs = ZiWeiReading.yearSihua(zw, year: y)
            let gz = Astro.pmod(y - 4, 60)
            switch kind {
            case .why:
                var s = "紫微看一年的好壞，主要看兩件事：流年命宮走到哪一宮、流年四化落在哪裡。"
                s += "\n\(y)年是\(GZ.stems[gz % 10])年，\(GZ.stems[gz % 10])干的四化是" + hs.map { "\($0.star)\($0.tag)" }.joined(separator: "、") + "。"
                for h in hs { if let p = h.palace { s += "\n• \(h.star)\(h.tag)在你的\(ZiWeiReading.pname(p))，所以\(ZiWeiReading.ptext(p))這方面\(h.tag == "化忌" ? "會卡、會煩" : (h.tag == "化祿" ? "會有好處" : (h.tag == "化權" ? "你會很用力" : "有貴人")))。" } }
                s += "\n化祿是資源，化忌是執著和阻礙；忌落在的宮位就是今年最費心的地方。"
                return s
            case .advice:
                var s = "怎麼做比較好："
                if let ji = hs.last?.palace { s += "\n• 化忌在\(ZiWeiReading.pname(ji))：這方面放慢、不要硬碰，\(jiAdvice[ji] ?? "多留後路")。" }
                if let lu = hs.first?.palace { s += "\n• 化祿在\(ZiWeiReading.pname(lu))：把力氣放在這裡，\(ZiWeiReading.luGood[lu] ?? "")。" }
                if let k = hs.dropFirst(2).first?.palace { s += "\n• 化科在\(ZiWeiReading.pname(k))：有事可以找這方面的貴人幫忙。" }
                return s
            case .more:
                return ZiWeiReading.natal(zw, male: profile.male, age: nowYear - bd.year, year: nowYear)
            }
        }
        let b = BaZi(bd.year, bd.month, bd.day, hour: profile.hour, minute: profile.minute ?? 0, male: profile.male ?? true)
        let dm = BaZi.stemEl[b.dayMaster]
        let fa = BaZiReading.favAndAvoid(b)
        let strong = b.strength().strong
        let gz = Astro.pmod(y - 4, 60)
        switch kind {
        case .why:
            var s = "八字看好壞的道理是「平衡」：你的日主是\(GZ.stems[b.dayMaster])\(BaZi.wuxing[dm])，\(strong ? "身強，能量太多，需要洩出去、用出去" : "身弱，能量不夠，需要被生、被幫")。"
            s += "\n所以對你有幫助的是\(fa.fav.map { BaZi.wuxing[$0] }.joined(separator: "、"))（喜用神），會加重負擔的是\(fa.avoid.map { BaZi.wuxing[$0] }.joined(separator: "、"))（忌神）。"
            let se = BaZi.stemEl[gz % 10], be = BaZi.branchEl[gz % 12]
            s += "\n\(y)年是\(GZ.name(gz))：天干\(GZ.stems[gz % 10])是\(BaZi.wuxing[se])、地支\(GZ.branches[gz % 12])是\(BaZi.wuxing[be])。"
            func tag(_ e: Int) -> String { fa.fav.contains(e) ? "喜用神，會幫你" : (fa.avoid.contains(e) ? "忌神，會壓你" : "不太相關") }
            s += "\(BaZi.wuxing[se])對你是\(tag(se))；\(BaZi.wuxing[be])對你是\(tag(be))。"
            s += "\n用十神來說：" + BaZiReading.effect(BaZiReading.group(BaZiReading.stemGod(b, gz % 10)), strong: strong, male: profile.male) + "。"
            let hits = BaZiReading.impact(b, stem: gz % 10, branch: gz % 12).hits
            if !hits.isEmpty { s += "\n再加上：" + hits.map(\.text).joined(separator: "；") + "。" }
            return s
        case .advice:
            var s = "怎麼做比較好（補喜用神）："
            for e in fa.fav { s += "\n• " + elementAdvice[e] + "。" }
            s += "\n• 少碰忌神的事：" + fa.avoid.prefix(2).map { avoidAdvice[$0] }.joined(separator: "；") + "。"
            s += "\n" + BaZiReading.advice(b, score: BaZiReading.yearScore(b, y).score)
            return s
        case .more:
            return BaZiReading.natal(b, male: profile.male, nowYear: nowYear, birthYear: bd.year)
        }
    }

    static let avoidAdvice = [
        "木太多時少一點衝動開新計畫", "火太多時少熬夜、少發脾氣、不要急", "土太多時別太固執、別什麼都扛",
        "金太多時少批評、別太硬", "水太多時少想太多、少熬夜、別逃避",
    ]
    static let jiAdvice: [String: String] = [
        "命宮": "多休息、別鑽牛角尖", "兄弟": "不要借錢、合夥先說清楚", "夫妻": "多溝通、少猜疑",
        "子女": "對孩子和桃花多一點耐心", "財帛": "守財、不投機、不借錢", "疾厄": "定期檢查、不要硬撐",
        "遷移": "出門小心、少做冒險的行程", "交友": "慎選朋友、少作保", "官祿": "低調做事、別跟上司硬碰",
        "田宅": "家裡的事多關心，買房搬家慢慢來", "福德": "讓自己放鬆、找興趣紓壓", "父母": "文書合約看仔細、多關心長輩",
    ]
}
