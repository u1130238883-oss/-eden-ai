import Foundation

/// 介面／回覆語言
public enum Lang: String, Codable, CaseIterable, Identifiable {
    case zh, en, es, it
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .zh: return "繁體中文"
        case .en: return "English"
        case .es: return "Español"
        case .it: return "Italiano"
        }
    }

    static let enWords: Set<String> = ["the", "is", "are", "am", "i", "you", "my", "your", "what", "how", "hello", "hi", "hey",
                                       "thanks", "today", "do", "can", "please", "and", "of", "to", "it", "this", "who", "why",
                                       "fortune", "chart", "tired", "sad", "happy", "good", "morning", "night", "me", "cast",
                                       "tell", "give", "make", "show", "have", "with", "for", "will", "would", "could", "should", "yes",
                                       "tomorrow", "career", "love", "work", "friends", "secret", "sleep"]
    static let esWords: Set<String> = ["el", "los", "las", "es", "está", "estoy", "soy", "tu", "qué", "que", "cómo", "como",
                                       "hola", "gracias", "por", "para", "y", "hoy", "muy", "te", "carta", "suerte", "quién",
                                       "buenos", "buenas", "días", "noches", "cansado", "cansada", "triste", "mis", "tengo",
                                       "cuéntame", "cuentame", "secreto", "dime", "hazme", "tienes", "puedes", "eres", "quiero", "mañana",
                                       "trabajo", "amor", "amigos", "dormir"]
    static let itWords: Set<String> = ["il", "lo", "gli", "è", "sono", "sei", "mio", "mia", "tuo", "che", "come", "ciao",
                                       "grazie", "per", "di", "oggi", "molto", "ti", "tema", "fortuna", "chi", "cosa", "cos",
                                       "buongiorno", "buonanotte", "stanco", "stanca", "mie", "ho", "anno", "mese",
                                       "dimmi", "fammi", "hai", "puoi", "voglio", "domani", "lavoro", "amore", "amici", "segreto", "dormi"]

    /// 偵測訊息語言：含漢字 → 中文；否則以常用詞與重音字母計分，無法判斷時用 fallback
    public static func detect(_ text: String, fallback: Lang) -> Lang {
        for s in text.unicodeScalars where (0x4E00...0x9FFF).contains(s.value) || (0x3400...0x4DBF).contains(s.value) {
            return .zh
        }
        let lower = text.lowercased()
        if !lower.contains(where: { $0.isLetter }) { return fallback }
        var score: [Lang: Int] = [.en: 0, .es: 0, .it: 0]
        let words = lower.split { !($0.isLetter || $0 == "'") }.map(String.init)
        for w in words {
            let parts = w.split(separator: "'").map(String.init)
            for p in parts + [w] {
                if enWords.contains(p) { score[.en]! += 1 }
                if esWords.contains(p) { score[.es]! += 1 }
                if itWords.contains(p) { score[.it]! += 1 }
            }
        }
        for c in lower {
            if "ñ¿¡".contains(c) { score[.es]! += 2 }
            if "èòù".contains(c) { score[.it]! += 2 }
        }
        let best = score.max { a, b in a.value != b.value ? a.value < b.value : a.key.rawValue > b.key.rawValue }!
        if best.value == 0 { return fallback == .zh ? .en : fallback }
        let tied = score.filter { $0.value == best.value }
        if tied.count > 1, tied[fallback] != nil { return fallback }
        return best.key
    }
}

/// 多語系資料與模板（i18n.json，由 ai/i18n.py 產生）。與 Python 的 fill() 與各 *_sample 函式逐字一致。
public final class I18N {
    public struct Data: Decodable {
        struct Palace: Decodable { let names: [String]; let keywords: [[String]] }
        struct Types: Decodable { let names: [String]; let taglines: [String]; let summaries: [String]?; let sectionTitles: [String]?; let sections: [[[String]]]? }
        let templates: [String: [String: [String]]]
        let palace: [String: Palace]
        let types: [String: Types]
        let verdict: [String: [String]]
        let from: [String: String]
        let hexNames: [String: [String]]
        let hexMeanings: [String: [String]]
        let stemText: [String: [String]]
        let stemPinyin: [String: String]
        let branchPinyin: [String: String]
        let starPinyin: [String: String]
        let starText: [String: [String: String]]
        let tenGods: [String: [String]]
        let tenGodText: [String: [String]]
        let wuxing: [String: [String]]
        let sihua: [String: [String]]
        let zwPalaces: [String: [String]]
        let zwPalaceText: [String: [String]]
        let ju: [String: [String: String]]
    }

    public let d: Data

    public init(json: Foundation.Data) throws { d = try JSONDecoder().decode(Data.self, from: json) }

    public convenience init(bundle: Bundle) throws {
        guard let url = bundle.url(forResource: "i18n", withExtension: "json") else { throw EchoError.missing("i18n.json") }
        try self.init(json: Foundation.Data(contentsOf: url))
    }

    // MARK: - 基本工具

    public static func fill(_ tpl: String, _ v: [String: String]) -> String {
        var s = tpl
        for k in v.keys.sorted() { s = s.replacingOccurrences(of: "{" + k + "}", with: v[k]!) }
        return s
    }

    public func t(_ key: String, _ L: Lang) -> String { d.templates[key]![L.rawValue]![0] }

    public func pname(_ p: Int, _ L: Lang) -> String { d.palace[L.rawValue]!.names[p - 1] }

    public func pn(_ p: Int, _ L: Lang) -> String {
        switch L {
        case .en: return "Palace \(p) (\(pname(p, L)))"
        case .es: return "Palacio \(p) (\(pname(p, L)))"
        case .it: return "Palazzo \(p) (\(pname(p, L)))"
        case .zh: return NT.label(p)
        }
    }

    public func kw(_ p: Int, _ n: Int, _ L: Lang) -> String {
        let name = pname(p, L)
        return d.palace[L.rawValue]!.keywords[p - 1].filter { $0 != name }.prefix(n).joined(separator: ", ")
    }

    public func rt(_ r: NTReading, _ L: Lang) -> String {
        "\(d.verdict[L.rawValue]![r.verdict.rawValue]) \(r.result) \(d.from[L.rawValue]!) \(r.cause)"
    }

    public func typeName(_ t: Int, _ L: Lang) -> String { d.types[L.rawValue]!.names[t - 1] }
    public func tagline(_ t: Int, _ L: Lang) -> String { d.types[L.rawValue]!.taglines[t - 1] }

    func starLabel(_ s: String, _ L: Lang) -> String {
        for (zh, tag) in zip(d.sihua["zh"]!, d.sihua[L.rawValue]!) where s.hasSuffix(zh) {
            return "\(s.dropLast(2)) (\(tag))"
        }
        return s
    }

    func starsL(_ stars: [String], _ L: Lang) -> String { stars.map { starLabel($0, L) }.joined(separator: ", ") }

    public typealias Sample = (frame: String, reply: String, must: [String])

    // MARK: - 九型十二宮

    func rowReply(_ row: NTRow, label: String, _ L: Lang) -> String {
        let r = row.reading
        return I18N.fill(t("row", L), ["label": label, "p": pn(row.palace, L), "rt": rt(r, L),
                                        "phrase": t("phrase\(r.verdict.rawValue)", L), "rp": pn(r.result, L),
                                        "rkw": kw(r.result, 2, L), "cp": pn(r.cause, L), "ckw": kw(r.cause, 2, L)])
    }

    func rowMust(_ row: NTRow, _ L: Lang) -> [String] { [pn(row.palace, L), rt(row.reading, L)] }

    public func day(_ D: Destiny, month m: Int, day dd: Int, _ L: Lang) -> Sample {
        let (dp, np) = D.day(month: m, day: dd)
        return ("\(L.rawValue)|今日|日\(dp)|夜\(np)",
                I18N.fill(t("day", L), ["dp": pn(dp, L), "dkw": kw(dp, 2, L), "np": pn(np, L), "nkw": kw(np, 2, L)]),
                [pn(dp, L), pn(np, L)])
    }

    public func month(_ D: Destiny, year y: Int, month m: Int, _ L: Lang) -> Sample {
        let row = D.month(m, year: y)
        return ("\(L.rawValue)|流月|\(m)月|\(row.text)", rowReply(row, label: I18N.fill(t("label_month", L), ["m": "\(m)"]), L),
                rowMust(row, L))
    }

    public func year(_ D: Destiny, year y: Int, _ L: Lang) -> Sample {
        let row = D.year(y)
        let trig = D.triggeredAspects(y).prefix(3).map(\.palace)
        var frame = "\(L.rawValue)|流年|\(y)|\(row.text)"
        var rep = rowReply(row, label: I18N.fill(t("label_year", L), ["y": "\(y)"]), L)
        if !trig.isEmpty {
            frame += "|引" + trig.map(String.init).joined(separator: ",")
            rep += " " + I18N.fill(t("trig", L), ["list": trig.map(String.init).joined(separator: ", ")])
        }
        return (frame, rep, rowMust(row, L))
    }

    public func luck(_ D: Destiny, year y: Int, _ L: Lang) -> Sample {
        let (s, e, row) = D.luckPeriod(y)
        return ("\(L.rawValue)|大運|\(s)-\(e)|\(row.text)",
                rowReply(row, label: I18N.fill(t("label_luck", L), ["s": "\(s)", "e": "\(e)"]), L), rowMust(row, L))
    }

    public func natal(_ D: Destiny, _ L: Lang) -> Sample {
        let r0 = D.natal[0], ty = D.type
        return ("\(L.rawValue)|命盤|命\(r0.palace)|型\(ty)|\(r0.text)",
                I18N.fill(t("natal", L), ["p": pn(r0.palace, L), "rt": rt(r0.reading, L), "kw": kw(r0.palace, 3, L),
                                          "t": "\(ty)", "tn": typeName(ty, L)]),
                [pn(r0.palace, L), rt(r0.reading, L)])
    }

    public func type(_ D: Destiny, _ L: Lang) -> Sample {
        let ty = D.type
        return ("\(L.rawValue)|九型|\(ty)", I18N.fill(t("type", L), ["t": "\(ty)", "tn": typeName(ty, L), "tag": tagline(ty, L)]),
                [typeName(ty, L)])
    }

    public func synastry(_ D: Destiny, _ other: Destiny, _ L: Lang) -> Sample {
        let ch = D.synastry(with: other)
        var c = [0, 0, 0]
        for r in ch { c[r.reading.verdict.rawValue] += 1 }
        let mood = t(c[0] > c[2] ? "mood_good" : (c[0] < c[2] ? "mood_bad" : "mood_even"), L)
        let p = ch[0].palace
        return ("\(L.rawValue)|合盤|命\(p)|好\(c[0])正\(c[1])壞\(c[2])",
                I18N.fill(t("syn", L), ["p": pn(p, L), "kw": kw(p, 3, L), "g": "\(c[0])", "n": "\(c[1])", "b": "\(c[2])", "mood": mood]),
                [pn(p, L)])
    }

    public func birthday(_ D: Destiny, _ L: Lang) -> Sample {
        let p = D.natal[0].palace, ty = D.type
        return ("\(L.rawValue)|生日|命\(p)|型\(ty)", I18N.fill(t("bday", L), ["p": pn(p, L), "t": "\(ty)", "tn": typeName(ty, L)]),
                [pn(p, L)])
    }

    // MARK: - 今天的大局（與中文版相同的補充）

    public func todayTail(_ D: Destiny, now: Date, _ L: Lang) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: now)
        let (dp, np) = D.day(month: c.month!, day: c.day!)
        return "\n" + Loc.s("tail.bday", L, "\(pn(dp, L)) — \(kw(dp, 2, L))", "\(pn(np, L)) — \(kw(np, 2, L))")
    }

    public func contextTail(_ D: Destiny, year y: Int, month m: Int, _ L: Lang) -> String {
        let mo = D.month(m, year: y), yr = D.year(y), lp = D.luckPeriod(y)
        return "\n" + Loc.s("tail.ctx", L, "\(pn(mo.palace, L)) \(rt(mo.reading, L))", "\(pn(yr.palace, L)) \(rt(yr.reading, L))",
                            "\(pn(lp.row.palace, L)) \(rt(lp.row.reading, L))")
    }

    public func contextLines(_ D: Destiny, year y: Int, month m: Int, _ L: Lang) -> [String] {
        let mo = D.month(m, year: y), yr = D.year(y), lp = D.luckPeriod(y)
        return ["\(Loc.s("card.month", L)) \(m): \(pn(mo.palace, L)) \(rt(mo.reading, L))",
                "\(Loc.s("card.year", L)) \(y): \(pn(yr.palace, L)) \(rt(yr.reading, L))",
                "\(Loc.s("card.luckPillar", L)) \(lp.start)–\(lp.end): \(pn(lp.row.palace, L)) \(rt(lp.row.reading, L))"]
    }

    // MARK: - 八字

    func godL(_ zh: String, _ L: Lang) -> String { d.tenGods[L.rawValue]![BaZi.tenGods.firstIndex(of: zh)!] }
    func godText(_ zh: String, _ L: Lang) -> String { d.tenGodText[L.rawValue]![BaZi.tenGods.firstIndex(of: zh)!] }

    public func bazi(_ b: BaZi, _ L: Lang) -> Sample {
        let ps = b.pillars.map(GZ.name)
        let dm = String(ps[2].prefix(1))
        let elIdx = BaZi.stemEl[b.dayMaster]
        let strong = b.strength().strong
        let fav = b.favorable()
        let zhW = BaZi.wuxing
        let frame = "\(L.rawValue)|八字|\(ps.joined())|日主\(dm)\(zhW[elIdx])|\(strong ? "身強" : "身弱")|喜\(zhW[fav[0]])\(zhW[fav[1]])"
        let v: [String: String] = [
            "y": ps[0], "m": ps[1], "d": ps[2],
            "h": ps.count == 4 ? I18N.fill(t("bazi_hour", L), ["h": ps[3]]) : "",
            "dm": dm, "py": d.stemPinyin[dm]!, "el": d.wuxing[L.rawValue]![elIdx],
            "text": d.stemText[L.rawValue]![GZ.stems.firstIndex(of: dm)!],
            "str": t(strong ? "strong" : "weak", L), "f1": d.wuxing[L.rawValue]![fav[0]], "f2": d.wuxing[L.rawValue]![fav[1]],
        ]
        let mustD = ["en": "\(ps[2]) day", "es": "día \(ps[2])", "it": "giorno \(ps[2])"][L.rawValue]!
        let mustM = ["en": "Day Master \(dm)", "es": "Maestro del Día \(dm)", "it": "Maestro del Giorno \(dm)"][L.rawValue]!
        return (frame, I18N.fill(t("bazi", L), v), [mustD, mustM])
    }

    public func baziLuck(_ b: BaZi, birthYear: Int, nowYear: Int, _ L: Lang) -> Sample {
        let (start, seq) = b.luck(count: 10)
        let age = nowYear - birthYear
        let mustA = ["en": "age \(start)", "es": "\(start) años", "it": "\(start) anni"][L.rawValue]!
        if age < start {
            return ("\(L.rawValue)|八字大運|起\(start)歲|未起運",
                    I18N.fill(t("bazi_luck0", L), ["a": "\(start)", "gz": GZ.name(seq[0])]), [mustA])
        }
        let gz = seq[min(9, (age - start) / 10)]
        let god = BaZi.tenGod(dayStem: b.dayMaster, other: gz % 10)
        let g = GZ.name(gz)
        return ("\(L.rawValue)|八字大運|起\(start)歲|現\(g)|\(god)",
                I18N.fill(t("bazi_luck", L), ["a": "\(start)", "gz": g, "st": String(g.prefix(1)), "god": godL(god, L),
                                              "text": godText(god, L)]), [mustA, g])
    }

    public func baziYear(_ b: BaZi, year: Int, _ L: Lang) -> Sample {
        let (gz, god) = b.yearGod(year)
        let g = GZ.name(gz)
        return ("\(L.rawValue)|八字流年|\(year)\(g)|\(god)",
                I18N.fill(t("bazi_year", L), ["y": "\(year)", "gz": g, "st": String(g.prefix(1)), "god": godL(god, L),
                                              "text": godText(god, L)]), [g, godL(god, L)])
    }

    // MARK: - 紫微

    func zwHead(_ zw: ZiWei, _ b: Int, _ L: Lang) -> (head: String, stars: [String], borrowed: Bool) {
        let s = zw.starsText(b)
        if !s.isEmpty { return (I18N.fill(t("zw_main", L), ["stars": starsL(s, L)]), s, false) }
        let o = zw.starsText(Astro.pmod(b + 6, 12))
        return (I18N.fill(t("zw_borrow", L), ["stars": starsL(o, L)]), o, true)
    }

    func firstStar(_ s: [String]) -> String {
        var x = s[0]
        for tag in ["化祿", "化權", "化科", "化忌"] { x = x.replacingOccurrences(of: tag, with: "") }
        return x
    }

    public func ziwei(_ zw: ZiWei, _ L: Lang) -> Sample {
        let B = GZ.branches[zw.ming], B2 = GZ.branches[zw.shen]
        let (head, s, borrowed) = zwHead(zw, zw.ming, L)
        let first = firstStar(s)
        let frame = "\(L.rawValue)|紫微|命宮\(B)|\(borrowed ? "借" : "")\(s.joined(separator: "、"))|身宮\(B2)|\(ZiWei.juNames[zw.ju]!)"
        let reply = I18N.fill(t("ziwei", L), ["b": B, "py": d.branchPinyin[B]!, "head": head, "first": first,
                                              "fpy": d.starPinyin[first]!, "text": d.starText[L.rawValue]![first]!,
                                              "b2": B2, "ju": d.ju[L.rawValue]!["\(zw.ju)"]!])
        let must = ["en": "Life Palace is in \(B)", "es": "Palacio de Vida Zi Wei está en \(B)",
                    "it": "Palazzo della Vita Zi Wei è in \(B)"][L.rawValue]!
        return (frame, reply, [must, first])
    }

    public func ziweiPalace(_ zw: ZiWei, name: String, _ L: Lang) -> Sample {
        let b = zw.palaceOf(name)
        let B = GZ.branches[b]
        let idx = ZiWei.palaces.firstIndex(of: name)!
        let (head, s, borrowed) = zwHead(zw, b, L)
        let first = firstStar(s)
        let pnz = name.hasSuffix("宮") ? name : name + "宮"
        let pal = d.zwPalaces[L.rawValue]![idx]
        let frame = "\(L.rawValue)|紫微宮|\(pnz)|\(B)|\(borrowed ? "借" : "")\(s.joined(separator: "、"))"
        let reply = I18N.fill(t("zw_palace", L), ["pal": pal, "b": B, "head": head, "ptext": d.zwPalaceText[L.rawValue]![idx],
                                                  "first": first, "fpy": d.starPinyin[first]!, "text": d.starText[L.rawValue]![first]!])
        let must = ["en": "\(pal) palace is in \(B)", "es": "palacio \(pal) está en \(B)", "it": "palazzo \(pal) è in \(B)"][L.rawValue]!
        return (frame, reply, [must, first])
    }

    public func ziweiDecade(_ zw: ZiWei, age: Int, _ L: Lang) -> Sample? {
        guard let dec = zw.decade(atAge: age) else { return nil }
        let B = GZ.branches[dec.branch]
        let raw = zw.palaceAt[dec.branch]!
        let idx = ZiWei.palaces.firstIndex(of: raw)!
        let (head, s, borrowed) = zwHead(zw, dec.branch, L)
        let pnz = raw.hasSuffix("宮") ? raw : raw + "宮"
        let frame = "\(L.rawValue)|紫微大限|\(dec.from)-\(dec.to)|\(B)|\(pnz)|\(borrowed ? "借" : "")\(s.joined(separator: "、"))"
        let reply = I18N.fill(t("zw_decade", L), ["a0": "\(dec.from)", "a1": "\(dec.to)", "b": B, "pal": d.zwPalaces[L.rawValue]![idx],
                                                  "head": head, "ptext": d.zwPalaceText[L.rawValue]![idx]])
        let must = ["en": "\(dec.from) to \(dec.to)", "es": "\(dec.from) a los \(dec.to)", "it": "\(dec.from) ai \(dec.to)"][L.rawValue]!
        return (frame, reply, [must, B])
    }

    // MARK: - 易經

    public func hexName(_ n: Int, _ L: Lang) -> String { L == .zh ? IChing.fullName(n) : d.hexNames[L.rawValue]![n - 1] }
    public func hexMeaning(_ n: Int, _ L: Lang) -> String {
        L == .zh ? ManticData.hexMeaning[n - 1] : d.hexMeanings[L.rawValue]![n - 1]
    }

    public func gua(_ r: IChing.Reading, _ L: Lang) -> Sample {
        let p = r.primary
        var v: [String: String] = ["p": "\(p)", "name": "\(hexName(p, L)) (\(IChing.fullName(p)))", "short": hexName(p, L),
                                   "meaning": hexMeaning(p, L)]
        let reply: String
        if let c = r.changed {
            v["lines"] = r.moving.map { String($0 + 1) }.joined(separator: ", ")
            v["c"] = "\(c)"
            v["cname"] = "\(hexName(c, L)) (\(IChing.fullName(c)))"
            v["cshort"] = hexName(c, L)
            v["cmeaning"] = hexMeaning(c, L)
            reply = I18N.fill(t("gua_move", L), v)
        } else {
            reply = I18N.fill(t("gua_still", L), v)
        }
        let word = ["en": "hexagram", "es": "hexagrama", "it": "esagramma"][L.rawValue]!
        return ("\(L.rawValue)|\(r.frame)", reply, ["\(word) \(p)", String(hexMeaning(p, L).prefix(12))])
    }

    // MARK: - 十二宮認知核心

    public func selfType(_ L: Lang) -> Sample {
        let D = Destiny(PalaceCore.selfBirth)
        let ty = D.type
        return ("\(L.rawValue)|我|型\(ty)",
                I18N.fill(t("self_type", L), ["life": "\(D.lifeNumber)", "p": pn(D.natal[0].palace, L), "t": "\(ty)",
                                              "tn": typeName(ty, L), "tag": tagline(ty, L)]), [typeName(ty, L)])
    }

    public func selfDay(_ p: Int, _ L: Lang) -> Sample {
        ("\(L.rawValue)|我|日\(p)", I18N.fill(t("self_day", L), ["p": pn(p, L), "kw": kw(p, 2, L)]), [pn(p, L)])
    }

    public func portrait(top: [Int], type ty: Int?, _ L: Lang) -> Sample {
        guard let p1 = top.first else { return ("\(L.rawValue)|畫像|無", t("portrait_none", L), []) }
        let more = top.count > 1 ? I18N.fill(t("portrait_more", L), ["p2": pn(top[1], L), "k2": kw(top[1], 2, L)]) : ""
        let typ = ty.map { I18N.fill(t("portrait_type", L), ["t": "\($0)", "tn": typeName($0, L), "tag": tagline($0, L)]) } ?? ""
        var reply = I18N.fill(t("portrait", L), ["p1": pn(p1, L), "k1": kw(p1, 2, L), "more": more, "typ": typ])
        while let last = reply.unicodeScalars.last, CharacterSet.whitespacesAndNewlines.contains(last) { reply.removeLast() }
        return ("\(L.rawValue)|畫像|\(top.map(String.init).joined(separator: ","))|型\(ty.map(String.init) ?? "無")", reply, [pn(p1, L)])
    }
}
