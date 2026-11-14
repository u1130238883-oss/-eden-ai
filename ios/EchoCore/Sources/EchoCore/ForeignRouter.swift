import Foundation

/// 英文／西班牙文／義大利文的命理意圖路由（九型十二宮、八字、紫微、易經）。
/// 事實框與保底回覆由 I18N（與 ai/i18n.py 逐字一致）產生。
public enum ForeignRouter {
    static let knowMarkers: [String] = ["what is", "what's", "what does", "tell me about", "meaning of", "search", "explain",
                                        "qué es", "que es", "qué significa", "háblame de", "busca", "explica",
                                        "cos'è", "cosa è", "cosa significa", "parlami di", "cerca", "spiega"]
    static let gua = ["hexagram", "i ching", "iching", "hexagrama", "esagramma"]
    static let bazi = ["bazi", "four pillars", "day master", "cuatro pilares", "maestro del día", "maestro del dia",
                       "quattro pilastri", "maestro del giorno"]
    static let ziwei = ["zi wei", "ziwei", "purple star", "estrella púrpura", "stella viola"]
    static let decade = ["decade", "década", "decennio"]
    static let palaceWord = ["palace", "palacio", "palazzo"]
    static let luck = ["luck pillar", "luck period", "decade of luck", "pilar de suerte", "década de suerte",
                       "pilastro della sorte", "decennio di fortuna"]
    static let natal = ["my chart", "life palace", "show my chart", "mi carta", "palacio de vida", "muestra mi carta",
                        "il mio tema", "palazzo della vita", "mostra il mio tema"]
    static let type = ["what type", "enneagram", "personality type", "qué tipo", "eneagrama", "tipo de personalidad",
                       "che tipo", "enneagramma", "tipo di personalità"]
    static let month = ["this month", "month", "monthly", "este mes", "mes", "mensual", "questo mese", "mese", "mensile"]
    static let year = ["this year", "year", "annual", "este año", "año", "anual", "quest'anno", "anno", "annuale"]
    static let day = ["today", "daily", "hoy", "oggi", "tonight", "this evening", "esta noche", "stasera", "stanotte", "questa sera",
                      "this morning", "esta mañana", "stamattina"]
    static let nightWords = ["tonight", "this evening", "night", "esta noche", "noche", "stasera", "stanotte", "questa sera", "notte"]
    static let dayOnlyWords = ["this morning", "daytime", "afternoon", "esta mañana", "tarde", "stamattina", "pomeriggio"]
    static let weekWords = ["this week", "next week", "week", "esta semana", "próxima semana", "semana", "questa settimana",
                            "prossima settimana", "settimana"]
    static let syn = ["compatib", "match me"]
    static let born = ["birthday", "born", "cumpleaños", "nací", "naci", "nacido", "nacida", "compleanno", "nato", "nata"]
    static let luckWord = ["luck", "suerte", "sorte"]
    static let annualWord = ["this year", "annual", "este año", "anual", "quest'anno", "annuale"]

    /// 片語用子字串比對；單一字詞用完整單字比對（避免 "mes" 誤中 "mesa"）
    static func hit(_ text: String, _ words: Set<String>, _ keys: [String]) -> Bool {
        keys.contains { k in k.contains(" ") || k.contains("'") || k == "compatib" ? text.contains(k) : words.contains(k) }
    }

    enum Kind { case day(y: Int, m: Int, d: Int, label: String?), week(Int), month, year(Int), luck, natal, personality, syn(BirthDay) }

    static let dayOffsets: [(String, Int)] = [
        ("day after tomorrow", 2), ("pasado mañana", 2), ("dopodomani", 2), ("tomorrow", 1), ("mañana", 1), ("domani", 1),
        ("yesterday", -1), ("ayer", -1), ("ieri", -1)]
    static let fortuneWords = ["fortune", "luck", "reading", "horoscope", "suerte", "lectura", "horóscopo", "fortuna", "lettura",
                               "oroscopo", "va", "how", "day palace", "night palace", "palacio de día", "palazzo del giorno"]

    public static func route<R: RandomNumberGenerator>(_ raw: String, L: Lang, i18n: I18N, profile: UserProfile,
                                                       now: Date, rng: inout R) -> FortuneQuery? {
        let text = raw.lowercased()
        let words = Set(text.split { !($0.isLetter || $0 == "'") }.map(String.init))
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: now)
        let ty = c.year!, tm = c.month!, td = c.day!
        let date = FortuneRouter.parseDate(raw)
        let isGua = hit(text, words, gua)
        // 「what's tomorrow's fortune」這類問句是在問運勢，不是查資料
        let fortuneHit = ["fortune", "horoscope", "luck", "suerte", "fortuna", "oroscopo", "lectura"].contains { text.contains($0) }
        let timeHit = hit(text, words, day) || hit(text, words, month) || hit(text, words, year) || hit(text, words, weekWords)
            || dayOffsets.contains { text.contains($0.0) }
        if !isGua && !(fortuneHit && timeHit) && knowMarkers.contains(where: { text.contains($0) }) { return nil }

        // 生日
        if let b = date, hit(text, words, born), !hit(text, words, syn) {
            let s = i18n.birthday(Destiny(b), L)
            var q = FortuneQuery(frame: s.frame, mustContain: s.must, fallback: s.reply,
                                 card: FortuneCard(title: Loc.s("card.natal", L), headline: i18n.pn(Destiny(b).natal[0].palace, L),
                                                   verdict: Destiny(b).natal[0].reading.verdict,
                                                   details: [i18n.typeName(Destiny(b).type, L), i18n.tagline(Destiny(b).type, L)]),
                                 newBirthday: b)
            q.tail = i18n.todayTail(Destiny(b), now: now, L)
            let R0 = Reader(L, i18n: i18n)
            let nat = R0.natal(Destiny(b))
            q.composed = R0.cap(Loc.s("profile.birthday", L, "\(b.year)-\(b.month)-\(b.day)")) + ".\n" + nat.text + i18n.todayTail(Destiny(b), now: now, L)
            q.card = nat.card
            q.follow = nat.follow
            return q
        }

        // 易經（不需要生日）
        if isGua {
            let nums = ManticRouter.numbers(raw)
            let r = nums.count >= 2 ? IChing.plum(nums[0], nums[1]) : IChing.threeCoins(using: &rng)
            let s = i18n.gua(r, L)
            var details = ["\(Loc.s("card.gua.primary", L)) \(i18n.hexName(r.primary, L)) (\(IChing.fullName(r.primary))): \(i18n.hexMeaning(r.primary, L))"]
            if let ch = r.changed {
                details.append("\(Loc.s("card.gua.changed", L)) \(i18n.hexName(ch, L)) (\(IChing.fullName(ch))): \(i18n.hexMeaning(ch, L))")
            }
            details.append("\(Loc.s("card.gua.mutual", L)) \(i18n.hexName(r.mutual, L)) (\(IChing.fullName(r.mutual)))")
            return FortuneQuery(frame: s.frame, mustContain: s.must, fallback: s.reply,
                                card: FortuneCard(title: nums.count >= 2 ? Loc.s("card.gua.plum", L, "\(nums[0])·\(nums[1])") : Loc.s("card.gua.coins", L),
                                                  headline: "\(Loc.s("card.hexagram", L, "\(r.primary)")) \(i18n.hexName(r.primary, L))",
                                                  details: details, hexLines: r.lines, hexMoving: r.moving),
                                newBirthday: nil)
        }

        let wantsBazi = hit(text, words, bazi)
        let zwNames = i18n.d.zwPalaces[L.rawValue]!.map { $0.lowercased() }
        let zwPalaceIdx = zwNames.indices.dropFirst().first { i in
            hit(text, words, palaceWord) && text.contains(zwNames[i])
        }
        let wantsZiwei = hit(text, words, ziwei) || zwPalaceIdx != nil
        let isSyn = hit(text, words, syn)

        var kind: Kind?
        if !wantsBazi && !wantsZiwei {
            if isSyn, let o = date { kind = .syn(o) }
            else if hit(text, words, luck) { kind = .luck }
            else if hit(text, words, natal) { kind = .natal }
            else if hit(text, words, type) { kind = .personality }
            else if hit(text, words, weekWords) {
                kind = .week(["next week", "próxima semana", "prossima settimana"].contains(where: { text.contains($0) }) ? 7 : 0)
            }
            else if hit(text, words, month) { kind = .month }
            else if hit(text, words, year) {
                let y = ManticRouter.numbers(raw).first { (1900...2100).contains($0) } ?? ty
                kind = .year(y)
            } else if (hit(text, words, day) || dayOffsets.contains(where: { text.contains($0.0) }))
                        && fortuneWords.contains(where: { words.contains($0) || text.contains($0) }) {
                kind = .day(y: ty, m: tm, d: td, label: nil)
                for (w, off) in dayOffsets where text.contains(w) {
                    if let t = cal.date(byAdding: .day, value: off, to: now) {
                        let cc = cal.dateComponents([.year, .month, .day], from: t)
                        kind = .day(y: cc.year!, m: cc.month!, d: cc.day!, label: w)
                    }
                    break
                }
            }
            if kind == nil { return nil }
        }

        guard let bd = profile.birthday else {
            return FortuneQuery(frame: "\(L.rawValue)|無生日", mustContain: [], fallback: Loc.s("noBirthday", L), card: nil,
                                newBirthday: nil)
        }
        let D = Destiny(bd)

        if wantsBazi {
            let b = BaZi(bd.year, bd.month, bd.day, hour: profile.hour, minute: profile.minute ?? 0, male: profile.male ?? true)
            let ps = b.pillars.map(GZ.name)
            if hit(text, words, luckWord) {
                guard profile.male != nil else { return deterministic(Loc.s("needGender", L)) }
                let s = i18n.baziLuck(b, birthYear: bd.year, nowYear: ty, L)
                let (start, seq) = b.luck(count: 8)
                return FortuneQuery(frame: s.frame, mustContain: s.must, fallback: s.reply,
                                    card: FortuneCard(title: Loc.s("card.luck", L, "\(start)"), headline: s.must.last ?? "",
                                                      details: seq.enumerated().map { "\(Loc.s("card.age", L, "\(start + 10 * $0.offset)")) \(GZ.name($0.element))" }),
                                    newBirthday: nil)
            }
            if hit(text, words, annualWord) {
                let s = i18n.baziYear(b, year: ty, L)
                return FortuneQuery(frame: s.frame, mustContain: s.must, fallback: s.reply,
                                    card: FortuneCard(title: Loc.s("card.baziYear", L, "\(ty)"), headline: s.must.joined(separator: " · ")),
                                    newBirthday: nil)
            }
            let s = i18n.bazi(b, L)
            let gods = b.pillars.enumerated().map { $0.offset == 2 ? Loc.s("card.dayMaster", L)
                : i18n.godL(BaZi.tenGod(dayStem: b.dayMaster, other: $0.element % 10), L) }
            var details: [String] = []
            if profile.hour == nil { details.append(Loc.s("noHourCard", L)) }
            return FortuneQuery(frame: s.frame, mustContain: s.must, fallback: s.reply,
                                card: FortuneCard(title: Loc.s("card.bazi", L),
                                                  headline: "\(Loc.s("card.dayMaster", L)) \(ps[2].prefix(1)) \(i18n.d.wuxing[L.rawValue]![BaZi.stemEl[b.dayMaster]])",
                                                  details: details, pillars: ps, pillarGods: gods),
                                newBirthday: nil)
        }

        if wantsZiwei {
            guard let hour = profile.hour else {
                return FortuneQuery(frame: "\(L.rawValue)|無時辰", mustContain: [], fallback: i18n.t("nohour", L), card: nil,
                                    newBirthday: nil)
            }
            let zw = ZiWei(bd.year, bd.month, bd.day, hour: hour, male: profile.male ?? true)
            let grid = (0..<12).map { b in
                ZiWeiCell(branch: b, stem: GZ.stems[zw.stemAt[b]!], palace: zw.palaceAt[b]!,
                          stars: zw.starsText(b, withAux: true), isMing: b == zw.ming, isShen: b == zw.shen)
            }
            let title = Loc.s("card.ziwei", L)
            if hit(text, words, decade) {
                guard profile.male != nil else { return deterministic(Loc.s("needGender", L)) }
                guard let s = i18n.ziweiDecade(zw, age: ty - bd.year, L) else { return nil }
                return FortuneQuery(frame: s.frame, mustContain: s.must, fallback: s.reply,
                                    card: FortuneCard(title: title, headline: s.must[0], ziwei: grid), newBirthday: nil)
            }
            if let i = zwPalaceIdx {
                let s = i18n.ziweiPalace(zw, name: ZiWei.palaces[i], L)
                return FortuneQuery(frame: s.frame, mustContain: s.must, fallback: s.reply,
                                    card: FortuneCard(title: title, headline: s.must[0], ziwei: grid), newBirthday: nil)
            }
            let s = i18n.ziwei(zw, L)
            return FortuneQuery(frame: s.frame, mustContain: s.must, fallback: s.reply,
                                card: FortuneCard(title: title, headline: "\(Loc.s("card.lifePalace", L)) \(GZ.branches[zw.ming])",
                                                  ziwei: grid),
                                newBirthday: nil)
        }

        let s: I18N.Sample
        var card: FortuneCard?
        switch kind! {
        case .week:
            s = i18n.day(D, month: tm, day: td, L)
            card = nil
        case .day(_, let m, let d, _):
            s = i18n.day(D, month: m, day: d, L)
            card = FortuneCard(title: "\(Loc.s("card.today", L)) \(m)/\(d)", headline: s.must[0], details: [s.must[1]])
        case .month:
            s = i18n.month(D, year: ty, month: tm, L)
            card = FortuneCard(title: "\(Loc.s("card.month", L)) \(ty)/\(tm)", headline: s.must[0],
                               verdict: D.month(tm, year: ty).reading.verdict, details: [s.must[1]])
        case .year(let y):
            s = i18n.year(D, year: y, L)
            card = FortuneCard(title: "\(Loc.s("card.year", L)) \(y)", headline: s.must[0], verdict: D.year(y).reading.verdict,
                               details: [s.must[1]])
        case .luck:
            s = i18n.luck(D, year: ty, L)
            let lp = D.luckPeriod(ty)
            card = FortuneCard(title: "\(Loc.s("card.luckPillar", L)) \(lp.start)–\(lp.end)", headline: s.must[0],
                               verdict: lp.row.reading.verdict, details: [s.must[1]])
        case .natal:
            s = i18n.natal(D, L)
            card = FortuneCard(title: Loc.s("card.natal", L), headline: s.must[0], verdict: D.natal[0].reading.verdict,
                               details: D.natal.map { "\(i18n.pn($0.palace, L)) \(i18n.rt($0.reading, L))" })
        case .personality:
            s = i18n.type(D, L)
            card = FortuneCard(title: Loc.s("card.type", L), headline: "\(D.type) · \(i18n.typeName(D.type, L))",
                               details: [i18n.tagline(D.type, L)])
        case .syn(let o):
            s = i18n.synastry(D, Destiny(o), L)
            card = FortuneCard(title: "\(Loc.s("card.syn", L)) × \(o.year)-\(o.month)-\(o.day)", headline: s.must[0])
        }
        var q = FortuneQuery(frame: s.frame, mustContain: s.must, fallback: s.reply, card: card, newBirthday: nil)

        // 解讀層：用人話把引擎算出的結果講出來
        let R = Reader(L, i18n: i18n)
        var out: ReaderOutput
        switch kind! {
        case .week(let off):
            out = R.week(D, from: cal.date(byAdding: .day, value: off, to: now)!, next: off > 0)
        case .day(let y, let m, let d, let label):
            let night = hit(text, words, nightWords), dayOnly = hit(text, words, dayOnlyWords)
            out = R.day(D, y: y, m: m, d: d, label: label, focus: night && !dayOnly ? 2 : (dayOnly && !night ? 1 : 0))
            out.text += R.contextTail(D, y: y, m: m)
        case .month: out = R.month(D, y: ty, m: tm)
        case .year(let y): out = R.year(D, y: y)
        case .luck: out = R.luck(D, y: ty, aspects: hit(text, words, ["aspects", "aspectos", "aspetti"]))
        case .natal: out = R.natal(D)
        case .personality: out = R.personality(D)
        case .syn(let o): out = R.synastry(D, other: o)
        }
        q.composed = out.text
        q.card = out.card
        q.follow = out.follow
        return q
    }

    static func deterministic(_ text: String) -> FortuneQuery {
        FortuneQuery(frame: "", mustContain: [], fallback: text, card: nil, newBirthday: nil, deterministic: true)
    }
}
