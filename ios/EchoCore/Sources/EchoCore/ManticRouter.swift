import Foundation

/// 使用者檔案：生日、出生時間、性別。
public struct UserProfile: Codable, Equatable {
    public var birthday: BirthDay?
    public var hour: Int?
    public var minute: Int?
    public var male: Bool?

    public init(birthday: BirthDay? = nil, hour: Int? = nil, minute: Int? = nil, male: Bool? = nil) {
        self.birthday = birthday
        self.hour = hour
        self.minute = minute
        self.male = male
    }
}

/// 八字、紫微斗數、易經卦的意圖路由與事實框（逐字對應 ai/mantic_corpus.py）。
public enum ManticRouter {
    static let palaceWords = ["兄弟宮", "夫妻宮", "子女宮", "財帛宮", "疾厄宮", "遷移宮", "交友宮", "官祿宮", "田宅宮", "福德宮", "父母宮"]
    static let guaWords = ["算一卦", "卜卦", "起卦", "占卜", "搖卦", "占一卦", "卜一卦", "一卦", "梅花易數"]

    // MARK: - 事實框（與 Python 逐字一致）

    public static func baziFrame(_ b: BaZi) -> (frame: String, reply: String, must: [String]) {
        let ps = b.pillars.map(GZ.name)
        let dmChar = String(ps[2].prefix(1))
        let el = BaZi.wuxing[BaZi.stemEl[b.dayMaster]]
        let strong = b.strength().strong
        let fav = b.favorable()
        let frame = "八字|\(ps.joined())|日主\(dmChar)\(el)|\(strong ? "身強" : "身弱")|喜\(BaZi.wuxing[fav[0]])\(BaZi.wuxing[fav[1]])"
        var parts = ["\(ps[0])年", "\(ps[1])月", "\(ps[2])日"]
        if ps.count == 4 { parts.append("\(ps[3])時") }
        let reply = "你的八字是\(parts.joined(separator: "、"))。日主\(dmChar)\(el)：\(ManticData.stemText[dmChar]!)"
            + "整體\(strong ? "身強" : "身弱")，喜用傾向\(BaZi.wuxing[fav[0]])、\(BaZi.wuxing[fav[1]])。"
        return (frame, reply, ["\(ps[2])日", "日主\(dmChar)\(el)"])
    }

    public static func baziLuckFrame(_ b: BaZi, birthYear: Int, nowYear: Int) -> (frame: String, reply: String, must: [String]) {
        let (start, seq) = b.luck(count: 10)
        let age = nowYear - birthYear
        if age < start {
            return ("八字大運|起\(start)歲|未起運",
                    "你\(start)歲起運，目前還在童限，大運尚未開始。第一步大運是\(GZ.name(seq[0]))。", ["\(start)歲"])
        }
        let gz = seq[min(9, (age - start) / 10)]
        let god = BaZi.tenGod(dayStem: b.dayMaster, other: gz % 10)
        let g = GZ.name(gz)
        return ("八字大運|起\(start)歲|現\(g)|\(god)",
                "你\(start)歲起運，現在走\(g)大運，\(g.prefix(1))對日主是\(god)：\(ManticData.tenGodText[god]!)", ["\(start)歲", g])
    }

    public static func baziYearFrame(_ b: BaZi, year: Int) -> (frame: String, reply: String, must: [String]) {
        let (gz, god) = b.yearGod(year)
        let g = GZ.name(gz)
        return ("八字流年|\(year)\(g)|\(god)", "\(year)年是\(g)年，\(g.prefix(1))對你的日主是\(god)：\(ManticData.tenGodText[god]!)", [g, god])
    }

    static func starsPhrase(_ zw: ZiWei, _ b: Int) -> (String, Bool) {
        let s = zw.starsText(b)
        if !s.isEmpty { return (s.joined(separator: "、"), false) }
        return (zw.starsText(Astro.pmod(b + 6, 12)).joined(separator: "、"), true)
    }

    static func firstStar(_ text: String) -> String {
        var s = text.components(separatedBy: "、")[0]
        for t in ["化祿", "化權", "化科", "化忌"] { s = s.replacingOccurrences(of: t, with: "") }
        return s
    }

    public static func ziweiFrame(_ zw: ZiWei) -> (frame: String, reply: String, must: [String]) {
        let B = GZ.branches[zw.ming], B2 = GZ.branches[zw.shen]
        let (stars, borrowed) = starsPhrase(zw, zw.ming)
        let ju = ZiWei.juNames[zw.ju]!
        let first = firstStar(stars)
        let head = borrowed ? "宮內無主星，借對宮\(stars)。" : "主星是\(stars)。"
        return ("紫微|命宮\(B)|\(borrowed ? "借" : "")\(stars)|身宮\(B2)|\(ju)",
                "你的紫微命宮在\(B)宮，\(head)\(first)：\(ManticData.starText[first] ?? "")身宮在\(B2)，\(ju)。",
                ["命宮在\(B)宮", first])
    }

    public static func ziweiPalaceFrame(_ zw: ZiWei, name: String) -> (frame: String, reply: String, must: [String]) {
        let b = zw.palaceOf(name)
        let B = GZ.branches[b]
        let pn = name.hasSuffix("宮") ? name : name + "宮"
        let (stars, borrowed) = starsPhrase(zw, b)
        let first = firstStar(stars)
        let head = borrowed ? "宮內無主星，借對宮\(stars)。" : "主星是\(stars)。"
        return ("紫微宮|\(pn)|\(B)|\(borrowed ? "借" : "")\(stars)",
                "你的\(pn)在\(B)宮，\(head)\(pn)看\(ManticData.ziweiPalaceText[name]!)\(first)：\(ManticData.starText[first] ?? "")",
                ["\(pn)在\(B)宮", first])
    }

    public static func ziweiDecadeFrame(_ zw: ZiWei, age: Int) -> (frame: String, reply: String, must: [String])? {
        guard let d = zw.decade(atAge: age) else { return nil }
        let B = GZ.branches[d.branch]
        let raw = zw.palaceAt[d.branch]!
        let pn = raw.hasSuffix("宮") ? raw : raw + "宮"
        let (stars, borrowed) = starsPhrase(zw, d.branch)
        return ("紫微大限|\(d.from)-\(d.to)|\(B)|\(pn)|\(borrowed ? "借" : "")\(stars)",
                "你\(d.from)到\(d.to)歲的大限走\(B)宮（本命\(pn)），"
                    + (borrowed ? "借對宮\(stars)。" : "主星是\(stars)。") + "這十年的重點落在\(ManticData.ziweiPalaceText[raw]!)",
                ["\(d.from)到\(d.to)歲", "\(B)宮"])
    }

    public static func guaFrame(_ r: IChing.Reading) -> (frame: String, reply: String, must: [String]) {
        let p = r.primary
        let fp = IChing.fullName(p)
        let meaning = ManticData.hexMeaning[p - 1]
        var reply = "你得到\(fp)（第\(p)卦）"
        if let c = r.changed {
            let lines = r.moving.map { IChing.lineNames[$0] }.joined(separator: "、")
            reply += "，動在\(lines)爻，變為\(IChing.fullName(c))。\(IChing.name(p))：\(meaning)"
            reply += "變卦\(IChing.name(c))：\(ManticData.hexMeaning[c - 1])"
        } else {
            reply += "，沒有動爻。\(IChing.name(p))：\(meaning)"
        }
        return (r.frame, reply, [fp, String(meaning.prefix(8))])
    }

    // MARK: - 路由

    static func has(_ s: String, _ keys: [String]) -> Bool { keys.contains { s.contains($0) } }

    static func numbers(_ s: String) -> [Int] {
        guard let re = try? NSRegularExpression(pattern: #"\d+"#) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap {
            Range($0.range, in: s).flatMap { Int(s[$0]) }
        }
    }

    public static func route<R: RandomNumberGenerator>(_ raw: String, profile: UserProfile, now: Date,
                                                       rng: inout R) -> FortuneQuery? {
        let text = raw.replacingOccurrences(of: " ", with: "")
        if has(text, FortuneRouter.knowledgeMarkers) && !has(text, guaWords) { return nil }
        let nowYear = Calendar(identifier: .gregorian).component(.year, from: now)

        // 易經卦（不需要生日）
        if has(text, guaWords) {
            let nums = numbers(raw)
            let r = nums.count >= 2 ? IChing.plum(nums[0], nums[1]) : IChing.threeCoins(using: &rng)
            let f = guaFrame(r)
            var details = ["本卦 \(IChing.fullName(r.primary))：\(ManticData.hexMeaning[r.primary - 1])"]
            if let c = r.changed { details.append("變卦 \(IChing.fullName(c))：\(ManticData.hexMeaning[c - 1])") }
            details.append("互卦 \(IChing.fullName(r.mutual))")
            return FortuneQuery(frame: f.frame, mustContain: f.must, fallback: f.reply,
                                card: FortuneCard(title: nums.count >= 2 ? "梅花易數 \(nums[0])・\(nums[1])" : "三錢起卦",
                                                  headline: "第\(r.primary)卦 \(IChing.fullName(r.primary))", verdict: nil,
                                                  details: details, hexLines: r.lines, hexMoving: r.moving),
                                newBirthday: nil)
        }

        let wantsBazi = has(text, ["八字", "日主", "四柱", "走什麼運", "流年十神", "流年對我"])
        let wantsZiwei = has(text, ["紫微", "主星", "大限"]) || has(text, palaceWords)
        guard wantsBazi || wantsZiwei else { return nil }

        guard let bd = profile.birthday else {
            return FortuneQuery(frame: "無生日", mustContain: ["生日"],
                                fallback: "我還不知道你的生日！直接告訴我，例如：我的生日是2000年1月1日。", card: nil, newBirthday: nil)
        }

        if wantsBazi {
            let b = BaZi(bd.year, bd.month, bd.day, hour: profile.hour, minute: profile.minute ?? 0, male: profile.male ?? true)
            let ps = b.pillars.map(GZ.name)
            let pillarCard = FortuneCard(title: "八字 · 四柱", headline: "日主 \(ps[2].prefix(1))\(BaZi.wuxing[BaZi.stemEl[b.dayMaster]])",
                                         verdict: nil, details: [], pillars: ps,
                                         pillarGods: b.pillars.enumerated().map { $0.offset == 2 ? "日主" : BaZi.tenGod(dayStem: b.dayMaster, other: $0.element % 10) })
            if has(text, ["大運", "走什麼運"]) {
                guard profile.male != nil else { return needGender() }
                let f = baziLuckFrame(b, birthYear: bd.year, nowYear: nowYear)
                let (start, seq) = b.luck(count: 8)
                return FortuneQuery(frame: f.frame, mustContain: f.must, fallback: f.reply,
                                    card: FortuneCard(title: "八字大運（\(start)歲起）", headline: f.must.last ?? "",
                                                      verdict: nil, details: seq.enumerated().map { "\(start + 10 * $0.offset)歲 \(GZ.name($0.element))" }),
                                    newBirthday: nil)
            }
            if has(text, ["流年"]) {
                let f = baziYearFrame(b, year: nowYear)
                return FortuneQuery(frame: f.frame, mustContain: f.must, fallback: f.reply,
                                    card: FortuneCard(title: "八字流年 \(nowYear)", headline: f.must[0] + " · " + f.must[1],
                                                      verdict: nil, details: [ManticData.tenGodText[f.must[1]]!]),
                                    newBirthday: nil)
            }
            let f = baziFrame(b)
            var card = pillarCard
            let (strong, ratio) = b.strength()
            let fav = b.favorable()
            let c = b.elementCounts()
            card.details = ["五行 " + (0..<5).map { "\(BaZi.wuxing[$0])\(String(format: "%.1f", c[$0]))" }.joined(separator: " "),
                            "\(strong ? "身強" : "身弱")（生扶 \(Int(ratio * 100))%）· 喜用 \(BaZi.wuxing[fav[0]])\(BaZi.wuxing[fav[1]])"]
            if profile.hour == nil { card.details.append("未設定出生時辰，只排三柱") }
            return FortuneQuery(frame: f.frame, mustContain: f.must, fallback: f.reply, card: card, newBirthday: nil)
        }

        // 紫微斗數
        guard let hour = profile.hour else {
            return FortuneQuery(frame: "無時辰", mustContain: ["時辰"],
                                fallback: "紫微斗數需要出生時辰。告訴我，例如：我是早上8點出生的。", card: nil, newBirthday: nil)
        }
        let zw = ZiWei(bd.year, bd.month, bd.day, hour: hour, male: profile.male ?? true)
        let grid = (0..<12).map { b in
            ZiWeiCell(branch: b, stem: GZ.stems[zw.stemAt[b]!], palace: zw.palaceAt[b]!,
                      stars: zw.starsText(b, withAux: true), isMing: b == zw.ming, isShen: b == zw.shen)
        }
        let title = "紫微斗數 · \(zw.lunar.text)\(GZ.branches[zw.hourBranch])時"
        if text.contains("大限") {
            guard profile.male != nil else { return needGender() }
            guard let f = ziweiDecadeFrame(zw, age: nowYear - bd.year) else { return nil }
            return FortuneQuery(frame: f.frame, mustContain: f.must, fallback: f.reply,
                                card: FortuneCard(title: title, headline: "大限 " + f.must[0], verdict: nil,
                                                  details: [], ziwei: grid), newBirthday: nil)
        }
        if let pw = palaceWords.first(where: { text.contains($0) }) {
            let f = ziweiPalaceFrame(zw, name: String(pw.dropLast()))
            return FortuneQuery(frame: f.frame, mustContain: f.must, fallback: f.reply,
                                card: FortuneCard(title: title, headline: f.must[0], verdict: nil, details: [], ziwei: grid),
                                newBirthday: nil)
        }
        let f = ziweiFrame(zw)
        return FortuneQuery(frame: f.frame, mustContain: f.must, fallback: f.reply,
                            card: FortuneCard(title: title, headline: "命宮 \(GZ.branches[zw.ming]) · \(ZiWei.juNames[zw.ju]!)",
                                              verdict: nil, details: [], ziwei: grid),
                            newBirthday: nil)
    }

    static func needGender() -> FortuneQuery {
        FortuneQuery(frame: "", mustContain: [], fallback: "大運的順逆要看性別。告訴我「我是男生」或「我是女生」就可以了。",
                     card: nil, newBirthday: nil, deterministic: true)
    }
}

/// 紫微命盤格子（卡片用）
public struct ZiWeiCell: Codable, Equatable {
    public let branch: Int
    public let stem: String
    public let palace: String
    public let stars: [String]
    public let isMing: Bool
    public let isShen: Bool
}
