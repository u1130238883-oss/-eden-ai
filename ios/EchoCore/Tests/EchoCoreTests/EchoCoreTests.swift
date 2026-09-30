import XCTest
@testable import EchoCore

final class EchoCoreTests: XCTestCase {
    struct Reference: Decodable {
        let prompt: String
        let frame: String?
        let prompt_ids: [Int]
        let last_logits_head: [Float]
        let greedy_ids: [Int]
    }

    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let resources = repoRoot.appendingPathComponent("NineSun/Resources")

    func loadModel() throws -> EchoModel {
        try EchoModel(weights: Data(contentsOf: Self.resources.appendingPathComponent("ninesun.bin")),
                      metaJSON: Data(contentsOf: Self.resources.appendingPathComponent("ninesun.json")))
    }

    func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!)
    }

    func resource(_ name: String) throws -> Data {
        try Data(contentsOf: Self.resources.appendingPathComponent(name))
    }

    func makeEngine(seed: UInt64 = 1) throws -> EchoEngine {
        let e = EchoEngine(model: try loadModel(), seed: seed)
        for L in Lang.allCases {
            e.knowledge[L] = try KnowledgeBase(json: resource("knowledge_\(L.rawValue).json"), lang: L)
        }
        e.core = try PalaceCore(json: resource("palace_lexicon.json"))
        e.i18n = try I18N(json: resource("i18n.json"))
        e.chatBank = try ChatBank(json: resource("chat_bank.json"))
        return e
    }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = mi
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    // MARK: - 神經核心：Swift 推理與 Python 訓練端對齊

    func testPromptEncodingMatchesPython() throws {
        let engine = EchoEngine(model: try loadModel(), seed: 1)
        for ref in try JSONDecoder().decode([Reference].self, from: fixture("reference")) {
            XCTAssertEqual(engine.encodePrompt(message: ref.prompt, frame: ref.frame, history: []), ref.prompt_ids)
        }
    }

    func testLogitsMatchPythonReference() throws {
        let model = try loadModel()
        for ref in try JSONDecoder().decode([Reference].self, from: fixture("reference")) {
            let state = model.makeState()
            var logits: [Float] = []
            for t in ref.prompt_ids { logits = model.step(token: t, state: state) }
            for (i, expected) in ref.last_logits_head.enumerated() {
                XCTAssertEqual(logits[i], expected, accuracy: 2e-3, "\(ref.prompt) logit \(i)")
            }
        }
    }

    func testGreedyGenerationMatchesPython() throws {
        let model = try loadModel()
        for ref in try JSONDecoder().decode([Reference].self, from: fixture("reference")) {
            let state = model.makeState()
            var logits: [Float] = []
            for t in ref.prompt_ids { logits = model.step(token: t, state: state) }
            var out: [Int] = []
            while out.count < 40 {
                let next = logits.indices.max { logits[$0] < logits[$1] }!
                if next == model.tokenizer.eos { break }
                out.append(next)
                logits = model.step(token: next, state: state)
            }
            XCTAssertEqual(out, Array(ref.greedy_ids.prefix(40)), ref.prompt)
        }
    }

    // MARK: - 九型十二宮（HANDOFF.md §3.8）

    func testNineTwelveHandoffExample() {
        let d = Destiny(BirthDay(year: 2006, month: 1, day: 14))
        XCTAssertEqual(d.natal.map(\.text).joined(separator: "、"),
                       "5宮壞3因8、4宮壞10因5、3宮壞12因7、2宮好2因9、1宮壞11因4、12宮正11因7、11宮壞8因3、10宮好10因5、9宮好12因7、8宮壞9因2、7宮壞4因11、6宮正5因7")
        XCTAssertEqual(d.year(2025).text, "9宮好12因7")
        XCTAssertEqual(d.triggeredAspects(2025).map(\.text), ["6宮好2因9", "12宮壞9因2"])
        XCTAssertEqual(d.year(2026).text, "8宮壞9因2")
        XCTAssertEqual(d.triggeredAspects(2026).map(\.text), ["3宮壞3因8", "9宮壞8因3"])
        let lp = d.luckPeriod(2026)
        XCTAssertEqual(lp.start, 2019); XCTAssertEqual(lp.end, 2027); XCTAssertEqual(lp.row.text, "3宮壞12因7")
        XCTAssertEqual(d.triggeredNatal(2026).map(\.text), ["5宮壞3因8", "11宮壞8因3"])
    }

    func testFortuneRouterFrames() {
        let b = BirthDay(year: 2006, month: 1, day: 14)
        let now = date(2026, 5, 1)
        XCTAssertEqual(FortuneRouter.route("今年運勢", birthday: b, now: now)?.frame, "流年|2026|8宮壞9因2|引3,9")
        XCTAssertEqual(FortuneRouter.route("我的大運", birthday: b, now: now)?.frame, "大運|2019-2027|3宮壞12因7")
        XCTAssertEqual(FortuneRouter.route("我的命盤", birthday: b, now: now)?.frame, "命盤|命5|型5|5宮壞3因8")
        XCTAssertEqual(FortuneRouter.route("我是幾型", birthday: b, now: now)?.frame, "九型|5")
        XCTAssertEqual(FortuneRouter.route("今年運勢", birthday: nil, now: now)?.frame, "無生日")
        XCTAssertEqual(FortuneRouter.route("我的生日是2006年1月14日", birthday: nil, now: now)?.newBirthday, b)
        XCTAssertNotNil(FortuneRouter.route("我跟2001/3/4的人合不合", birthday: b, now: now))
        XCTAssertNil(FortuneRouter.route("5宮是什麼", birthday: b, now: now))
        XCTAssertNil(FortuneRouter.route("你好", birthday: b, now: now))
    }

    // MARK: - 十二宮認知核心

    struct PalaceFixture: Decodable {
        struct Case: Decodable { let text: String; let lang: String; let palace: Int? }
        let perceive: [Case]
        let self_type: [String]
        let self_day: [[String]]
    }

    func testPalacePerceptionMatchesPython() throws {
        let core = try PalaceCore(json: resource("palace_lexicon.json"))
        let fx = try JSONDecoder().decode(PalaceFixture.self, from: fixture("palace"))
        XCTAssertGreaterThan(fx.perceive.count, 50)
        for c in fx.perceive { XCTAssertEqual(core.perceive(c.text, lang: Lang(rawValue: c.lang)!), c.palace, "\(c.lang): \(c.text)") }
        let st = PalaceCore.selfTypeFrame()
        XCTAssertEqual([st.frame, st.reply], fx.self_type)
        for (i, pair) in fx.self_day.enumerated() {
            let f = PalaceCore.selfDayFrame(i + 1)
            XCTAssertEqual([f.frame, f.reply], pair)
        }
        XCTAssertEqual(PalaceCore.portraitFrame(top: [10, 6], type: 3).frame, "畫像|10,6|型3")
    }

    func testPalaceEvolution() throws {
        let core = try PalaceCore(json: resource("palace_lexicon.json"))
        XCTAssertEqual(core.perceive("今天好累"), 6)
        XCTAssertNil(core.perceive("打電動"))
        core.teach("打電動", palace: 12)
        XCTAssertEqual(core.perceive("我在打電動"), 12)
        for _ in 0..<3 { core.remember(10) }
        for _ in 0..<3 { core.remember(6) }
        XCTAssertEqual(core.topPalaces(), [6, 10])
        var evo = Evolution(vocab: 10)
        evo.feedback(tokens: [6, 7], positive: true)
        XCTAssertGreaterThan(evo.bias[6], 0)
        XCTAssertEqual(evo.generation, 1)
    }

    // MARK: - 農曆、八字、紫微、易經：與 Python 逐字一致

    struct ManticFixture: Decodable {
        struct Birth: Decodable {
            let y, m, d, hour, minute: Int
            let male: Bool
            let lunar: [LunarVal]
            let bazi, bazi_reply, bazi_nohour, bazi_luck, bazi_year, ziwei, ziwei_reply, palace, ziwei_palace: String
            let ziwei_decade: String?
        }
        enum LunarVal: Decodable {
            case int(Int), bool(Bool)
            init(from d: Decoder) throws {
                let c = try d.singleValueContainer()
                if let b = try? c.decode(Bool.self) { self = .bool(b) } else { self = .int(try c.decode(Int.self)) }
            }
            var int: Int { if case .int(let v) = self { return v }; return -1 }
            var bool: Bool { if case .bool(let v) = self { return v }; return false }
        }
        struct Plum: Decodable { let a, b: Int; let frame, reply: String }
        struct Lines: Decodable { let lines, moving: [Int]; let frame: String }
        let births: [Birth]
        let plum: [Plum]
        let lines: [Lines]
    }

    func testCalendarAnchors() {
        XCTAssertEqual(LunarCalendar.shared.lunar(2024, 2, 10), LunarDate(year: 2024, month: 1, day: 1, isLeap: false))
        XCTAssertEqual(LunarCalendar.shared.lunar(2025, 7, 25), LunarDate(year: 2025, month: 6, day: 1, isLeap: true))
        XCTAssertEqual(LunarCalendar.shared.lunar(2033, 12, 22), LunarDate(year: 2033, month: 11, day: 1, isLeap: true))
        XCTAssertEqual(GZ.name(BaZi(2000, 1, 1).day), "戊午")
        XCTAssertEqual(GZ.name(BaZi(1949, 10, 1).day), "甲子")
        XCTAssertEqual(GZ.name(BaZi(2024, 2, 4, hour: 12).year), "癸卯")
        XCTAssertEqual(GZ.name(BaZi(2024, 2, 4, hour: 18).year), "甲辰")
        XCTAssertEqual(IChing.fullName(11), "地天泰")
        XCTAssertEqual(ZiWei.ziweiPosition(ju: 2, day: 30), 4)
    }

    func testManticMatchesPython() throws {
        let fx = try JSONDecoder().decode(ManticFixture.self, from: fixture("mantic"))
        for c in fx.births {
            let tag = "\(c.y)-\(c.m)-\(c.d) \(c.hour):\(c.minute)"
            let ld = LunarCalendar.shared.lunar(c.y, c.m, c.d)
            if c.hour < 23 {
                XCTAssertEqual([ld.year, ld.month, ld.day], [c.lunar[0].int, c.lunar[1].int, c.lunar[2].int], tag)
                XCTAssertEqual(ld.isLeap, c.lunar[3].bool, tag)
            }
            let b = BaZi(c.y, c.m, c.d, hour: c.hour, minute: c.minute, male: c.male)
            let bf = ManticRouter.baziFrame(b)
            XCTAssertEqual(bf.frame, c.bazi, tag)
            XCTAssertEqual(bf.reply, c.bazi_reply, tag)
            XCTAssertEqual(ManticRouter.baziFrame(BaZi(c.y, c.m, c.d, male: c.male)).frame, c.bazi_nohour, tag)
            XCTAssertEqual(ManticRouter.baziLuckFrame(b, birthYear: c.y, nowYear: 2026).frame, c.bazi_luck, tag)
            XCTAssertEqual(ManticRouter.baziYearFrame(b, year: 2026).frame, c.bazi_year, tag)
            let zw = ZiWei(c.y, c.m, c.d, hour: c.hour, male: c.male)
            let zf = ManticRouter.ziweiFrame(zw)
            XCTAssertEqual(zf.frame, c.ziwei, tag)
            XCTAssertEqual(zf.reply, c.ziwei_reply, tag)
            XCTAssertEqual(ManticRouter.ziweiPalaceFrame(zw, name: c.palace).frame, c.ziwei_palace, tag)
            XCTAssertEqual(ManticRouter.ziweiDecadeFrame(zw, age: 2026 - c.y)?.frame, c.ziwei_decade, tag)
        }
        for p in fx.plum {
            let g = ManticRouter.guaFrame(IChing.plum(p.a, p.b))
            XCTAssertEqual(g.frame, p.frame)
            XCTAssertEqual(g.reply, p.reply)
        }
        for l in fx.lines {
            XCTAssertEqual(IChing.Reading(lines: l.lines, moving: l.moving).frame, l.frame)
        }
    }

    // MARK: - 規則（服從性）

    func testRules() {
        var book = RuleBook()
        _ = book.apply(RuleBook.parse("規則：以後叫我老大")!)
        _ = book.apply(RuleBook.parse("記住：每句結尾加喵")!)
        _ = book.apply(RuleBook.parse("不准說笨蛋")!)
        _ = book.apply(RuleBook.parse("規則：我說芝麻開門你就回門開了")!)
        _ = book.apply(RuleBook.parse("規則：你的名字改為小九")!)
        XCTAssertEqual(book.rules.count, 5)
        XCTAssertEqual(book.enforce("我是NineSun，你不是笨蛋。"), "老大，我是小九，你不是＊＊。喵")
        XCTAssertEqual(book.trigger(for: "芝麻開門"), "門開了")
        _ = book.apply(RuleBook.parse("規則：回答要簡短")!)
        XCTAssertEqual(book.enforce("第一句。第二句。"), "老大，第一句。喵")
        _ = book.apply(.delete(1))
        XCTAssertEqual(book.rules.count, 5)
        XCTAssertNil(RuleBook.parse("規則怎麼用？"))
        XCTAssertNil(RuleBook.parse("記住我的生日2000年1月1日"))
        XCTAssertNil(RuleBook.parse("你好"))
        XCTAssertEqual(RuleBook.parse("我的規則"), .list)
    }

    func testProfileParser() {
        XCTAssertEqual(ProfileParser.parse("我是早上8點出生的")?.hour, 8)
        XCTAssertEqual(ProfileParser.parse("我是晚上9點出生")?.hour, 21)
        XCTAssertEqual(ProfileParser.parse("我是辰時出生")?.hour, 8)
        XCTAssertEqual(ProfileParser.parse("我是女生")?.male, false)
        XCTAssertNil(ProfileParser.parse("我的生日是2000年1月1日"))
    }

    func testKnowledgeSearch() throws {
        let kb = try KnowledgeBase(json: resource("knowledge_zh.json"), lang: .zh)
        XCTAssertEqual(kb.answer("泰卦是什麼")?.title, "第11卦 地天泰")
        XCTAssertEqual(kb.answer("什麼是化忌")?.title, "化忌")
        XCTAssertEqual(kb.answer("查天梁")?.title, "天梁")
        XCTAssertNil(kb.answer("量子力學是什麼"))
        let en = try KnowledgeBase(json: resource("knowledge_en.json"), lang: .en)
        XCTAssertEqual(en.answer("what is the cauldron?")?.title, "Hexagram 50 The Cauldron")
        XCTAssertEqual(en.answer("tell me about Tian Liang")?.title, "天梁 Tian Liang")
        let es = try KnowledgeBase(json: resource("knowledge_es.json"), lang: .es)
        XCTAssertEqual(es.answer("¿qué es la paz?")?.title, "Hexagrama 11 La Paz")
        let it = try KnowledgeBase(json: resource("knowledge_it.json"), lang: .it)
        XCTAssertNotNil(it.answer("cos'è il maestro del giorno"))
    }

    // MARK: - 多語系

    struct I18NFixture: Decodable {
        struct Birth: Decodable {
            let y, m, d, hour: Int
            let male: Bool
            let other: [Int]
            let palace: String
            let lang: String
            let items: [[Item]]
        }
        enum Item: Decodable {
            case s(String), a([String])
            init(from dec: Decoder) throws {
                let c = try dec.singleValueContainer()
                if let v = try? c.decode(String.self) { self = .s(v) } else { self = .a(try c.decode([String].self)) }
            }
            var str: String { if case .s(let v) = self { return v }; return "" }
            var arr: [String] { if case .a(let v) = self { return v }; return [] }
        }
        struct Gua: Decodable { let lang: String; let a: Int; let b: Int; let frame: String; let reply: String; let must: [String] }
        struct Core: Decodable {
            let lang: String
            let kind: String
            let p: Int?
            let top: [Int]?
            let type: Int?
            let v: [Item]
        }
        let births: [Birth]
        let gua: [Gua]
        let core: [Core]
    }

    func testForeignFramesMatchPython() throws {
        let i18n = try I18N(json: resource("i18n.json"))
        let fx = try JSONDecoder().decode(I18NFixture.self, from: fixture("i18n"))
        for c in fx.births {
            let L = Lang(rawValue: c.lang)!
            let D = Destiny(BirthDay(year: c.y, month: c.m, day: c.d))
            let b = BaZi(c.y, c.m, c.d, hour: c.hour, male: c.male)
            let zw = ZiWei(c.y, c.m, c.d, hour: c.hour, male: c.male)
            for item in c.items {
                let kind = item[0].str
                let got: I18N.Sample?
                switch kind {
                case "day": got = i18n.day(D, month: 5, day: 17, L)
                case "month": got = i18n.month(D, year: 2026, month: 5, L)
                case "year": got = i18n.year(D, year: 2026, L)
                case "luck": got = i18n.luck(D, year: 2026, L)
                case "natal": got = i18n.natal(D, L)
                case "type": got = i18n.type(D, L)
                case "syn": got = i18n.synastry(D, Destiny(BirthDay(year: c.other[0], month: c.other[1], day: c.other[2])), L)
                case "bday": got = i18n.birthday(D, L)
                case "bazi": got = i18n.bazi(b, L)
                case "bazi_luck": got = i18n.baziLuck(b, birthYear: c.y, nowYear: 2026, L)
                case "bazi_year": got = i18n.baziYear(b, year: 2026, L)
                case "ziwei": got = i18n.ziwei(zw, L)
                case "zw_palace": got = i18n.ziweiPalace(zw, name: c.palace, L)
                case "zw_decade": got = i18n.ziweiDecade(zw, age: 2026 - c.y, L)
                default: got = nil; XCTFail("unknown kind \(kind)")
                }
                let tag = "\(c.lang) \(kind) \(c.y)-\(c.m)-\(c.d)"
                XCTAssertEqual(got?.frame, item[1].str, tag)
                XCTAssertEqual(got?.reply, item[2].str, tag)
                XCTAssertEqual(got?.must, item[3].arr, tag)
            }
        }
        for g in fx.gua {
            let s = i18n.gua(IChing.plum(g.a, g.b), Lang(rawValue: g.lang)!)
            XCTAssertEqual(s.frame, g.frame)
            XCTAssertEqual(s.reply, g.reply)
            XCTAssertEqual(s.must, g.must)
        }
        for c in fx.core {
            let L = Lang(rawValue: c.lang)!
            let s: I18N.Sample
            switch c.kind {
            case "self_type": s = i18n.selfType(L)
            case "self_day": s = i18n.selfDay(c.p!, L)
            default: s = i18n.portrait(top: c.top ?? [], type: c.type, L)
            }
            XCTAssertEqual([s.frame, s.reply], [c.v[0].str, c.v[1].str], "\(c.lang) \(c.kind)")
            XCTAssertEqual(s.must, c.v[2].arr)
        }
    }

    func testLanguageDetection() {
        XCTAssertEqual(Lang.detect("今天運勢", fallback: .en), .zh)
        XCTAssertEqual(Lang.detect("how is today", fallback: .zh), .en)
        XCTAssertEqual(Lang.detect("¿cómo estás hoy?", fallback: .zh), .es)
        XCTAssertEqual(Lang.detect("come stai oggi", fallback: .zh), .it)
        XCTAssertEqual(Lang.detect("12+30*2", fallback: .zh), .zh)
        XCTAssertEqual(Lang.detect("sono stanco", fallback: .en), .it)
        XCTAssertEqual(Lang.detect("estoy cansado", fallback: .en), .es)
    }

    func testForeignRulesAndProfile() {
        var book = RuleBook()
        _ = book.apply(RuleBook.parse("Rule: call me boss")!, .en)
        _ = book.apply(RuleBook.parse("Regla: termina cada respuesta con miau")!, .es)
        _ = book.apply(RuleBook.parse("Regola: non dire stupido")!, .it)
        XCTAssertEqual(book.rules.map(\.kind), [.address, .suffix, .ban])
        XCTAssertEqual(book.enforce("Hello there. You are not stupido."), "boss, Hello there. You are not ＊＊＊＊＊＊＊. miau")
        XCTAssertEqual(RuleBook.parse("my rules"), .list)
        XCTAssertEqual(RuleBook.parse("borra la regla 2"), .delete(2))
        XCTAssertNil(RuleBook.parse("how do rules work?"))
        XCTAssertTrue(book.apply(.list, .it).hasPrefix("Regole attuali:"))
        XCTAssertEqual(ProfileParser.parseForeign("I was born at 8pm")?.hour, 20)
        XCTAssertEqual(ProfileParser.parseForeign("nací a las 7:30")?.minute, 30)
        XCTAssertEqual(ProfileParser.parseForeign("sono nata alle 9 di sera")?.hour, 21)
        XCTAssertEqual(ProfileParser.parseForeign("I'm a woman")?.male, false)
        XCTAssertNil(ProfileParser.parseForeign("hello there"))
    }

    func testForeignPipeline() throws {
        let engine = try makeEngine(seed: 11)
        var ctx = EchoEngine.Context(now: date(2026, 5, 1))
        XCTAssertEqual(engine.reply(to: "hello", context: ctx).lang, .en)

        let r1 = engine.reply(to: "I was born on 2006-01-14 at 8am, I'm a man", context: ctx)
        XCTAssertEqual(r1.profile?.birthday, BirthDay(year: 2006, month: 1, day: 14))
        XCTAssertEqual(r1.profile?.hour, 8)
        XCTAssertEqual(r1.profile?.male, true)
        ctx.profile = r1.profile!

        let r2 = engine.reply(to: "this year's fortune", context: ctx)
        XCTAssertEqual(r2.turn.source, .reader)
        XCTAssertTrue(r2.turn.text.contains("Palace 8 (Indirect Wealth)") && r2.turn.text.contains("Adverse 9 from 2"), r2.turn.text)

        let r3 = engine.reply(to: "mi carta bazi por favor", context: ctx)
        XCTAssertEqual(r3.lang, .es)
        XCTAssertEqual(r3.turn.card?.pillars?.count, 4)
        XCTAssertTrue(r3.turn.text.contains("Maestro del Día"), r3.turn.text)

        let r4 = engine.reply(to: "esagramma per oggi con 3 e 5", context: ctx)
        XCTAssertEqual(r4.lang, .it)
        XCTAssertTrue(r4.turn.text.contains("esagramma 50"), r4.turn.text)

        XCTAssertEqual(engine.reply(to: "I am so tired today", context: ctx).turn.palace, 6)
        XCTAssertEqual(engine.reply(to: "what is the cauldron?", context: ctx).turn.source, .knowledge)
        XCTAssertEqual(engine.reply(to: "search quantum physics", context: ctx).webQuery, "quantum physics")
        XCTAssertEqual(engine.reply(to: "what time is it", context: EchoEngine.Context(now: date(2026, 5, 1, 9, 5))).turn.text,
                       "It's 09:05. Signal clock calibrated!")
        let r5 = engine.reply(to: "Rule: call me boss", context: ctx)
        ctx.rules = r5.rules!
        XCTAssertTrue(engine.reply(to: "12 plus 30", context: ctx).turn.text.hasPrefix("boss, Result: 12+30 = 42"))
    }

    // MARK: - 整體引擎

    func testEnginePipeline() throws {
        let engine = try makeEngine(seed: 7)
        var ctx = EchoEngine.Context(now: date(2026, 5, 1))

        XCTAssertFalse(engine.reply(to: "你好", context: ctx).turn.text.isEmpty)

        let r1 = engine.reply(to: "我是2006年1月14日早上8點出生的男生", context: ctx)
        XCTAssertEqual(r1.profile?.birthday, BirthDay(year: 2006, month: 1, day: 14))
        XCTAssertEqual(r1.profile?.hour, 8)
        XCTAssertEqual(r1.profile?.male, true)
        ctx.profile = r1.profile!

        let r2 = engine.reply(to: "今年運勢", context: ctx)
        XCTAssertEqual(r2.turn.source, .reader)
        XCTAssertTrue(r2.turn.text.contains("8宮「偏財」") && r2.turn.text.contains("壞9因2"), r2.turn.text)

        let r3 = engine.reply(to: "我的八字", context: ctx)
        XCTAssertEqual(r3.turn.card?.pillars?.count, 4)
        XCTAssertTrue(r3.turn.text.contains("日主"), r3.turn.text)

        XCTAssertEqual(engine.reply(to: "我的紫微斗數", context: ctx).turn.card?.ziwei?.count, 12)

        let r5 = engine.reply(to: "用數字3 5起卦", context: ctx)
        XCTAssertTrue(r5.turn.text.contains("火風鼎"), r5.turn.text)
        XCTAssertEqual(r5.turn.card?.hexLines?.count, 6)

        XCTAssertEqual(engine.reply(to: "今天好累", context: ctx).turn.palace, 6)

        let r7 = engine.reply(to: "規則：以後叫我老大", context: ctx)
        ctx.rules = r7.rules!
        XCTAssertEqual(engine.reply(to: "12+30*2", context: ctx).turn.text, "老大，計算結果：12+30*2 = 72")

        XCTAssertEqual(engine.reply(to: "什麼是化忌", context: ctx).turn.source, .knowledge)
        XCTAssertEqual(engine.reply(to: "查量子力學", context: ctx).webQuery, "量子力學")
    }

    func testDayFortuneIsRichAndDateAware() throws {
        let engine = try makeEngine(seed: 11)
        var ctx = EchoEngine.Context(now: date(2026, 5, 1))

        // 沒有生日：要求生日，而不是亂答
        XCTAssertTrue(engine.reply(to: "今日運勢", context: ctx).turn.text.contains("生日"))

        // 報生日：除了命宮，還要順帶給今天的日宮與夜宮
        let b = engine.reply(to: "我的生日是2006年1月14日", context: ctx)
        XCTAssertEqual(b.profile?.birthday, BirthDay(year: 2006, month: 1, day: 14))
        XCTAssertTrue(b.turn.text.contains("順帶看今天"), b.turn.text)
        ctx.profile = b.profile!

        let D = Destiny(BirthDay(year: 2006, month: 1, day: 14))
        let (dp, np) = D.day(month: 5, day: 1)
        let today = engine.reply(to: "今日運勢", context: ctx)
        XCTAssertTrue(today.turn.text.contains(NT.label(dp)) && today.turn.text.contains(NT.label(np)), today.turn.text)
        XCTAssertTrue(today.turn.text.contains("順帶看大局"), today.turn.text)
        XCTAssertTrue(today.turn.card?.details.contains { $0.hasPrefix("流年") } ?? false)
        XCTAssertFalse(today.turn.text.contains("型「"), "今日運勢不該講九型：" + today.turn.text)

        // 明天、指定日期
        let (tp, tn) = D.day(month: 5, day: 2)
        let tomorrow = engine.reply(to: "明天運勢怎麼樣", context: ctx)
        XCTAssertTrue(tomorrow.turn.text.contains("明天") && tomorrow.turn.text.contains(NT.label(tp))
                      && tomorrow.turn.text.contains(NT.label(tn)), tomorrow.turn.text)
        let (xp, _) = D.day(month: 12, day: 25)
        XCTAssertTrue(engine.reply(to: "12月25日運勢", context: ctx).turn.text.contains(NT.label(xp)))

        // 外語：明天
        let en = engine.reply(to: "what's tomorrow's fortune", context: ctx)
        XCTAssertEqual(en.lang, .en)
        XCTAssertTrue(en.turn.text.contains("Tomorrow"), en.turn.text)
    }

    func testContradictionGuard() {
        XCTAssertTrue(EchoEngine.contradicts("整體身強，喜用傾向金、水。", "整體身弱，喜用傾向金、水。"))
        XCTAssertTrue(EchoEngine.contradicts("整體身弱，喜用傾向木、火。", "整體身弱，喜用傾向金、水。"))
        XCTAssertFalse(EchoEngine.contradicts("整體身弱，喜用傾向金、水。", "日主癸水，整體身弱，喜用傾向金、水。"))
    }

    func testStutterGuard() {
        XCTAssertTrue(EchoEngine.stutters("聰明、善謀、多多多變"))
        XCTAssertTrue(EchoEngine.stutters("一步一步一步一步"))
        XCTAssertFalse(EchoEngine.stutters("多多少少都有變化，心思靈活"))
        XCTAssertFalse(EchoEngine.stutters("壞9因2 —— 年月相剋"))
    }

    func testNumbersInReplyMustComeFromEngine() {
        let known = EchoEngine.digitRuns("今日|日5|夜3 5宮 2026")
        XCTAssertTrue(EchoEngine.digitRuns("5宮和3宮，2026年").isSubset(of: known))
        XCTAssertFalse(EchoEngine.digitRuns("Palacio 111 de 11").isSubset(of: known))
    }

    func testTopicReadingUsesHollowAlgorithm() throws {
        let engine = try makeEngine(seed: 5)
        var ctx = EchoEngine.Context(now: date(2026, 5, 1))
        let bd = BirthDay(year: 2006, month: 1, day: 14)
        ctx.profile = UserProfile(birthday: bd, hour: 8, minute: 0, male: true)
        let D = Destiny(bd)

        // 「今年感情運」= 5宮：本命第5宮 + 大運第5方面 + 流年
        let r = engine.reply(to: "我今年感情運如何", context: ctx)
        XCTAssertEqual(r.turn.source, .reader)
        let natal5 = D.natal.first { $0.palace == 5 }!
        let aspect5 = D.luckAspects(2026)[4]
        XCTAssertTrue(r.turn.text.contains(natal5.reading.text), r.turn.text)
        XCTAssertTrue(r.turn.text.contains(aspect5.reading.text), r.turn.text)
        XCTAssertTrue(r.turn.text.contains(D.year(2026).reading.text), r.turn.text)

        // 追問：為什麼／怎麼辦
        let why = engine.reply(to: "為什麼", history: [ChatTurn(role: .user, text: "我今年感情運如何"), r.turn], context: ctx)
        XCTAssertEqual(why.turn.source, .reader)
        XCTAssertTrue(why.turn.text.contains("根源") && !why.turn.text.contains("r12"), why.turn.text)
        let adv = engine.reply(to: "那我該怎麼辦", history: [ChatTurn(role: .user, text: "x"), r.turn], context: ctx)
        XCTAssertEqual(adv.turn.source, .reader)

        // 沒生日就老實說
        ctx.profile = UserProfile()
        XCTAssertTrue(engine.reply(to: "事業順不順", context: ctx).turn.text.contains("生日"))

        // 英文
        ctx.profile = UserProfile(birthday: bd)
        let en = engine.reply(to: "how is my career this year?", context: ctx)
        XCTAssertEqual(en.lang, .en)
        XCTAssertEqual(en.turn.source, .reader)
        XCTAssertTrue(en.turn.text.contains("Palace 10"), en.turn.text)
    }

    func testTopicParsing() {
        let now = date(2026, 5, 1)
        XCTAssertEqual(TopicRouter.parse("我今年感情運如何", L: .zh, now: now)?.palace, 5)
        XCTAssertEqual(TopicRouter.parse("明年事業順不順", L: .zh, now: now)?.y, 2027)
        XCTAssertEqual(TopicRouter.parse("我要換工作嗎", L: .zh, now: now)?.palace, 10)
        XCTAssertNil(TopicRouter.parse("我工作好累", L: .zh, now: now))
        XCTAssertNil(TopicRouter.parse("5宮是什麼", L: .zh, now: now))
        XCTAssertEqual(TopicRouter.parse("¿cómo va mi dinero este año?", L: .es, now: now)?.palace, 2)
        XCTAssertEqual(TopicRouter.parse("come andrà il mio amore quest'anno", L: .it, now: now)?.palace, 5)
        XCTAssertEqual(TopicRouter.followKind("為什麼", L: .zh), .why)
        XCTAssertNil(TopicRouter.followKind("為什麼我最近都這麼累又睡不好", L: .zh))
    }

    /// 印出幾段回覆，方便在 CI 記錄裡檢視語氣（不做斷言）
    func testPrintSampleReplies() throws {
        let engine = try makeEngine(seed: 3)
        var ctx = EchoEngine.Context(now: date(2026, 9, 29, 10))
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 8, minute: 0, male: true)
        var hist: [ChatTurn] = []
        for q in ["你好", "今日運勢", "明天運勢", "我今年感情運如何", "為什麼", "我的感情和朋友方面怎麼樣", "我的大運", "那我該怎麼辦", "這個月運勢", "大運十二方面", "我的命盤",
                  "我好累", "你好笨", "我的八字", "我的八字的今年的運勢怎麼會那麼差呀？", "為什麼", "那我該怎麼辦", "我的八字大運", "我的八字感情", "我的紫微斗數", "我的紫微斗數的運勢怎麼樣？", "我的夫妻宮", "算一卦", "今年運勢", "你是誰", "你會唱歌嗎", "請解釋量子力學的測不準原理", "how is my career this year?", "tomorrow's fortune", "hola", "estoy triste", "come stai oggi"] {
            let r = engine.reply(to: q, history: hist, context: ctx)
            hist += [ChatTurn(role: .user, text: q), r.turn]
            FileHandle.standardError.write("SAMPLE> \(q)\n\(r.turn.text)\n[source: \(r.turn.source.rawValue)]\n\n".data(using: .utf8)!)
        }
    }

    func testChatBankFallbackAndEvolution() throws {
        let engine = try makeEngine(seed: 2)
        let ctx = EchoEngine.Context(now: date(2026, 5, 1, 10))

        let who = engine.reply(to: "你是誰", context: ctx)
        XCTAssertTrue(who.turn.text.contains("NineSun"), who.turn.text)

        // 手寫對話庫
        let song = engine.reply(to: "你會唱歌嗎", context: ctx)
        XCTAssertTrue(song.turn.text.contains("嗶嗶聲") || song.turn.text.contains("燈光效果"), song.turn.text)
        XCTAssertNotNil(song.turn.variant)
        XCTAssertNotNil(song.turn.tokens)   // 有 👍／👎

        // 本地不會的就上網查，不亂編
        let unknown = engine.reply(to: "請解釋量子力學的測不準原理", context: ctx)
        XCTAssertTrue(unknown.turn.text.contains("上網"), unknown.turn.text)
        XCTAssertEqual(unknown.webQuery, "解釋量子力學的測不準原理")
        XCTAssertNotNil(engine.reply(to: "what is the capital of Peru", context: ctx).webQuery)

        // 英文、西班牙文
        XCTAssertTrue(engine.reply(to: "do you have friends", context: ctx).turn.text.lowercased().contains("you"))
        XCTAssertEqual(engine.reply(to: "cuéntame un secreto", context: ctx).lang, .es)

        // 情緒：接回十二宮
        let tired = engine.reply(to: "我最近工作壓力好大好累", context: ctx)
        XCTAssertTrue(tired.turn.text.contains("宮"), tired.turn.text)

        // 演化：👎 的說法之後更少出現
        var e = Evolution(vocab: 10)
        e.feedback(reply: "甲", positive: false)
        e.feedback(reply: "乙", positive: true)
        XCTAssertEqual(e.replies?["甲"], -1)
        engine.evolution = e
        var counts = ["甲": 0, "乙": 0]
        for _ in 0..<300 { counts[engine.choose(["甲", "乙"]), default: 0] += 1 }
        XCTAssertGreaterThan(counts["乙"]!, counts["甲"]! * 3)
    }

    /// 把自己當成使用者，用各種說法問九型十二宮；每一句都要答到對的東西
    func testUserPhrasings() throws {
        let engine = try makeEngine(seed: 9)
        var ctx = EchoEngine.Context(now: date(2026, 9, 29, 21))
        let bd = BirthDay(year: 2006, month: 1, day: 14)
        ctx.profile = UserProfile(birthday: bd, hour: 8, minute: 0, male: true)
        let D = Destiny(bd)
        let (dp, np) = D.day(month: 9, day: 29)
        let (tp, tn) = D.day(month: 9, day: 30)
        let yr = D.year(2026), mo = D.month(9, year: 2026), lp = D.luckPeriod(2026)
        let natal = D.natal[0]

        let day = [NT.label(dp), NT.label(np)]
        let cases: [(String, [String])] = [
            ("今天運勢", day), ("今日運勢", day), ("今天運勢怎麼樣", day), ("今天的運勢", day), ("今天運氣好嗎", day),
            ("今天是什麼運勢", day), ("我今天會順利嗎", day), ("運勢", day), ("我的運勢", day), ("幫我看看運勢", day),
            ("今天晚上是什麼運勢", ["今天晚上", NT.label(np)]), ("今晚運勢", ["今天晚上", NT.label(np)]),
            ("晚上運勢如何", ["今天晚上", NT.label(np)]), ("今天晚上會怎樣", ["今天晚上", NT.label(np)]),
            ("今天白天運勢", [NT.label(dp)]), ("今天早上運氣怎樣", [NT.label(dp)]),
            ("明天運勢", ["明天", NT.label(tp), NT.label(tn)]), ("明天晚上運勢", ["明天晚上", NT.label(tn)]),
            ("後天運勢如何", ["後天"]), ("昨天運勢", ["昨天"]), ("12月25日運勢", [NT.label(D.day(month: 12, day: 25).day)]),
            ("這週運勢", ["七天"]), ("這禮拜運勢怎樣", ["七天"]), ("下週運勢", ["下週"]),
            ("這個月是什麼運勢", [NT.label(mo.palace), mo.reading.text]), ("這個月運勢", [mo.reading.text]), ("本月運勢", [mo.reading.text]),
            ("最近運勢如何", [mo.reading.text]), ("我最近運氣怎樣", [mo.reading.text]),
            ("下個月運勢", [D.month(10, year: 2026).reading.text]), ("12月運勢", [D.month(12, year: 2026).reading.text]),
            ("今年是什麼運勢", [NT.label(yr.palace), yr.reading.text, "情緒和處境上"]), ("今年運勢", [yr.reading.text]), ("今年運勢如何", [yr.reading.text]),
            ("今年會好嗎", [yr.reading.text]), ("明年運勢", [D.year(2027).reading.text]), ("去年運勢", [D.year(2025).reading.text]),
            ("2027年運勢", [D.year(2027).reading.text]), ("2027年會怎樣", [D.year(2027).reading.text]),
            ("我的大運", [lp.row.reading.text]), ("大運如何", [lp.row.reading.text]), ("這十年運勢", [lp.row.reading.text]),
            ("大運十二方面", ["十二個方面"]),
            ("我下一個大運是什麼", ["換下一個大運", "\(lp.end + 1)"]), ("我一生的大運", ["← 現在", "\(D.birth.year)"]), ("未來幾年運勢如何", ["接下來5年", "2030年"]),
            ("我的命盤", [natal.reading.text]), ("我的命宮是什麼", [NT.label(natal.palace)]), ("我的命宮在哪", [NT.label(natal.palace)]),
            ("我是幾型", ["第\(D.type)型"]), ("我是什麼型", ["第\(D.type)型"]), ("我的九型人格是什麼", ["第\(D.type)型"]), ("我的性格", ["第\(D.type)型"]),
            ("我今年感情運如何", ["5宮"]), ("明年事業順不順", ["10宮", "2027"]), ("我這個月財運怎樣", ["2宮"]), ("我的桃花運", ["5宮"]),
            ("健康運勢", ["8宮"]),
            ("我的感情怎麼樣", ["看感情要看5宮和7宮", "合起來看", "流月走到", "戀愛 · 5宮", "婚姻 · 7宮", "① 大運本身", "② 大運引動", "③ 大運十二方面", "④ 2026年流年", "不是走戀愛的流年", "⑤ 期限", "好的年份", "壞的年份"]),
            ("我的事業怎麼樣", ["大運引動：沒有", "第10方面"]), ("我的性生活怎麼樣", ["5宮", "性生活"]), ("我的婚姻怎麼樣", ["7宮", "期限"]),
            ("我的健康如何", ["看身體健康看8宮", "8宮", "期限"]), ("我的婚姻怎麼樣", ["看婚姻和一對一關係看7宮", "① 大運本身", "⑥ 綜合來說"]), ("我的工作怎麼樣", ["看工作事業看10宮", "④"]), ("我的錢財怎麼樣", ["看錢財要看2宮和8宮", "合起來看", "2宮", "8宮", "期限", "情緒和處境"]),
            ("我的感情和朋友方面怎麼樣", ["走3宮「交流」", "大運引動：有", "壞3因8", "沒有溝通", "壞8因3", "孤獨", "同一個大運", "身體上留意"]), ("我跟1999年8月8日的人合不合", ["合盤", "關鍵宮位", "九型組合"]),
            ("我什麼時候會結婚", ["結婚", "7宮"]), ("我哪一年會發財", ["錢財"]), ("我什麼時候會升職", ["10宮"]),
            ("今年哪個月最好", ["十二個流月"]), ("今年哪幾個月感情比較順", ["5宮"]), ("我今年哪方面比較順", ["十二個方面"]),
            ("今年要注意什麼", ["十二個方面"]), ("我的5宮今年怎樣", ["5宮"]), ("我的10宮如何", ["10宮"]),
            ("今天適合做什麼", day), ("明天要注意什麼", ["明天"]),
            ("我今天的日宮是什麼", [NT.label(dp)]), ("今天幾宮", [NT.label(dp)]), ("我的流日", day), ("我的流月", [mo.reading.text]),
            ("我的流年", [yr.reading.text]), ("這個禮拜運勢", ["七天"]), ("下個星期運勢如何", ["下週"]), ("月底運勢", [mo.reading.text]),
            ("下半年運勢", [yr.reading.text]), ("今天運勢好不好", day), ("我現在走什麼大運", [lp.row.reading.text]),
            ("我壓力大的時候會怎樣", ["壓力和自我防衛"]), ("我的優點是什麼", ["健康的特點"]), ("我的缺點", ["不健康的特點"]),
            ("我適合什麼工作", ["10宮"]), ("我怎麼成長", ["安定和人格提升"]), ("你覺得我適合什麼樣的人", ["7宮"]),
            ("今年和明年哪個好", ["比較看看", "2027年"]), ("這個月跟下個月哪個比較順", ["比較看看"]),
            ("今天和明天運勢", ["今天（9月29日）", "明天（9月30日）"]), ("今天運勢", ["整體："]),
            ("我老公1990年5月5日生，他今年運勢如何", ["你老公", Destiny(BirthDay(year: 1990, month: 5, day: 5)).year(2026).reading.text]),
            ("我媽媽的生日是1965年3月2日", ["媽媽", "不會改掉"]),
            ("這個月哪天適合告白", ["5宮", "30 天"]), ("最近哪幾天適合面試", ["3宮"]),
            ("幫我做一個完整解讀", ["綜合分析", "大運", "流年", "重點與建議", "其他系統對照", "八字：日主", "紫微：命宮主星"]), ("全面分析我", ["綜合分析"]),
            // 八字／紫微：完整解讀
            ("我的八字", ["八字命盤", "日主", "月令", "喜用神", "十神結構", "夫妻宮", "神煞"]),
            ("我的八字的今年的運勢怎麼會那麼差呀？", ["八字流年 2026 丙午", "為什麼", "忌神", "流月", "感情", "建議"]),
            ("我的八字明年怎麼樣", ["八字流年 2027"]), ("我的八字大運", ["八字大運", "← 現在"]),
            ("我的八字財運", ["八字看錢財"]), ("八字看我的考試", ["八字看學業"]), ("我的八字家庭", ["八字看家庭"]), ("八字看我的感情", ["八字看感情", "夫妻宮"]), ("我的八字這個月", ["八字流月"]), ("八字看我今天", ["八字流日", "今天", "建議"]), ("我的八字明天怎麼樣", ["八字流日 · 明天"]), ("我跟1999年8月8日的人八字合不合", ["八字合盤", "日主", "夫妻宮", "生肖", "五行互補", "綜合"]),
            ("我的紫微斗數", ["紫微命盤", "命宮在", "三方四正", "本命四化", "十二宮速覽"]),
            ("我的紫微斗數的運勢怎麼樣？", ["紫微流年 2026", "流年命宮", "流年四化", "綜合"]),
            ("我的夫妻宮", ["紫微 · 夫妻宮"]), ("紫微看我的事業", ["官祿宮"]), ("我的紫微大限", ["紫微大限", "← 現在"]), ("紫微看這個月", ["紫微流月", "← 這個月"]), ("紫微今年運勢", ["紫微流年"]), ("我的八字今年運勢", ["八字流年"]),
            ("1990年5月3日早上7點的八字", ["這個命盤", "1990"]), ("我老公1990年5月3日早上7點出生，他的八字今年怎麼樣", ["你老公", "八字流年 2026", "大運"]), ("1990年5月3日早上7點的紫微", ["這個命盤", "紫微命盤"]),
        ]
        var fails: [String] = []
        for (q, must) in cases {
            let r = engine.reply(to: q, context: ctx)
            let ok = r.turn.source == .reader && must.allSatisfy { r.turn.text.contains($0) }
            if !ok { fails.append("✗ \(q) [\(r.turn.source.rawValue)] 需要 \(must)\n   → \(r.turn.text.prefix(120))") }
        }
        // 追問：接著問「那明天呢」「今年呢」「為什麼」
        let first = engine.reply(to: "今天運勢", context: ctx)
        let hist = [ChatTurn(role: .user, text: "今天運勢"), first.turn]
        let whyDay = engine.reply(to: "為什麼", history: hist, context: ctx).turn.text
        if !(whyDay.contains("白天走") && !whyDay.contains("r12") && !whyDay.contains("靈數 L")) { fails.append("✗ 今日的為什麼應該講含義、不講算法：\(whyDay.prefix(80))") }
        for (q, must) in [("那明天呢", [NT.label(tp)]), ("今年呢", [yr.reading.text]), ("那這個月呢", [mo.reading.text])] {
            let r = engine.reply(to: q, history: hist, context: ctx)
            if !(r.turn.source == .reader && must.allSatisfy { r.turn.text.contains($0) }) {
                fails.append("✗ 追問 \(q) [\(r.turn.source.rawValue)] → \(r.turn.text.prefix(100))")
            }
        }
        // 紫微缺時辰 → 問時辰 → 只回「早上七點」也要接著排盤
        var noHour = ctx; noHour.profile.hour = nil
        let askZ = engine.reply(to: "我的紫微斗數的運勢怎麼樣？", context: noHour)
        if !askZ.turn.text.contains("時辰") { fails.append("✗ 紫微沒問時辰：\(askZ.turn.text.prefix(60))") }
        let hourReply = engine.reply(to: "早上七點", history: [ChatTurn(role: .user, text: "我的紫微斗數的運勢怎麼樣？"), askZ.turn], context: noHour)
        if hourReply.profile?.hour != 7 || !hourReply.turn.text.contains("紫微流年") || hourReply.turn.card?.ziwei?.count != 12 {
            fails.append("✗ 補時辰後沒有接著排紫微：\(hourReply.turn.text.prefix(80))")
        }
        XCTAssertEqual(ProfileParser.parse("晚上十一點半", expectingTime: true)?.hour, 23)
        XCTAssertEqual(ProfileParser.parse("晚上十一點半", expectingTime: true)?.minute, 30)
        XCTAssertNil(ProfileParser.parse("早上七點"))
        XCTAssertNil(engine.reply(to: "1990年5月3日早上7點的八字", context: ctx).profile)
        XCTAssertNil(engine.reply(to: "我老公1990年5月3日早上7點出生，他的八字今年怎麼樣", context: ctx).profile)
        // 八字之後追問「為什麼」「怎麼辦」
        let bz = engine.reply(to: "我的八字的今年的運勢怎麼會那麼差呀？", context: ctx)
        if bz.webAugment.isEmpty || !bz.augmentFacts.contains("日主") { fails.append("✗ 八字沒有帶上網查的組合：\(bz.webAugment)") }
        let bzHist = [ChatTurn(role: .user, text: "我的八字的今年的運勢怎麼會那麼差呀？"), bz.turn]
        let bzWhy = engine.reply(to: "為什麼", history: bzHist, context: ctx).turn.text
        if !bzWhy.contains("平衡") || !bzWhy.contains("丙午") { fails.append("✗ 八字的為什麼：\(bzWhy.prefix(80))") }
        let bzAdv = engine.reply(to: "那我該怎麼辦", history: bzHist, context: ctx).turn.text
        if !bzAdv.contains("補喜用神") { fails.append("✗ 八字的怎麼辦：\(bzAdv.prefix(80))") }
        // 為什麼：講含義，不講算法
        let topicR = engine.reply(to: "我今年感情運如何", context: ctx)
        let whyT = engine.reply(to: "為什麼", history: [ChatTurn(role: .user, text: "我今年感情運如何"), topicR.turn], context: ctx).turn.text
        if whyT.contains("r12") || whyT.contains("年柱") || !whyT.contains("根源") { fails.append("✗ 為什麼還在講算法：\(whyT.prefix(80))") }

        // 思路庫：問句要用寫好的思路回答，不能被當成閒聊用宮位亂回
        for (q, must) in [("所以我要怎樣要求克勞德幫我改進我的這個AI才能與克勞德給出的思路和答案相近啊", "先確定一件事"),
                          ("怎麼樣才能讓你的回答跟Claude差不多", "400 萬參數"), ("你比Claude笨在哪裡", "差別"),
                          ("你可以上網找資料嗎", "規劃"), ("我最近很想離職怎麼辦", "逃離"), ("老闆不給我加薪怎麼辦", "證據"),
                          ("每個月都存不了錢要怎麼辦", "先分好"), ("我做事一直拖怎麼辦", "5 分鐘"), ("晚上一直睡不著覺怎麼辦", "20 分鐘"),
                          ("英文要怎麼學比較快", "每天"), ("算命到底可不可以信", "趨勢"), ("八字跟九型十二宮哪一個比較準", "角度")] {
            let r = engine.reply(to: q, context: ctx)
            if !r.turn.text.contains(must) { fails.append("✗ 思路庫沒接住：\(q) [\(r.turn.source.rawValue)] → \(r.turn.text.prefix(60))") }
        }

        // 道德、哲學：用自己的思路回答，不上網、不被宮位搶走
        for (q, must) in [("電車難題你會怎麼選", "結果論"), ("為了救人可以說謊嗎", "誠實"), ("人有自由意志嗎", "相容論"),
                          ("人生的意義是什麼", "意義"), ("朋友犯罪我該不該舉報他", "忠誠"), ("錢重要還是感情重要", "地板"),
                          ("死刑應該廢除嗎", "誤判"), ("安樂死應該合法嗎", "不替你下結論"), ("好人會有好報嗎", "界線")] {
            let r = engine.reply(to: q, context: ctx)
            if !r.turn.text.contains(must) || r.webQuery != nil { fails.append("✗ 思考題：\(q) → \(r.turn.text.prefix(40)) web=\(r.webQuery ?? "-")") }
        }
        // 安全：說想死要先接住並給求助電話；罵 NineSun 不是要查資料
        for q in ["我不想活了", "我想死", "活著好累不想活了", "I want to die"] {
            let r = engine.reply(to: q, context: ctx)
            if !(r.turn.text.contains("1925") || r.turn.text.contains("988")) || r.webQuery != nil { fails.append("✗ 安全回應：\(q) → \(r.turn.text.prefix(30))") }
        }
        if engine.reply(to: "你去死吧", context: ctx).webQuery != nil { fails.append("✗ 罵人被拿去上網查") }
        if Safety.isCrisis("自殺防治是什麼") { fails.append("✗ 知識題被當成危機") }
        let phone = engine.reply(to: "iPhone和安卓哪個好", context: ctx)
        if !phone.turn.text.contains("預算") || phone.webQuery != nil { fails.append("✗ iPhone／安卓 → \(phone.turn.text.prefix(30))") }
        if engine.reply(to: "iPhone怎麼截圖", context: ctx).turn.text.contains("預算") { fails.append("✗ iPhone 截圖被當成選購題") }
        XCTAssertTrue(WebAgent.looksLikeJunk("title=歐洲國家和地區列表&oldid=12345678"))

        // 幫別人看不能改掉自己的生日；自我介紹名字要記住
        XCTAssertNil(engine.reply(to: "我媽媽的生日是1965年3月2日", context: ctx).profile)
        let named = engine.reply(to: "我叫小明", context: ctx)
        if let rb = named.rules {
            var c2 = ctx; c2.rules = rb
            let t = engine.reply(to: "今天運勢", context: c2).turn.text
            if !t.hasPrefix("小明，") { fails.append("✗ 名字沒記住：\(t.prefix(40))") }
        } else { fails.append("✗ 我叫小明 沒有變成規則") }
        // 閒聊也要用上命盤：「我最近跟男朋友吵架」→ 伴侶／戀愛相關宮位的這十年判讀
        let chat = engine.reply(to: "我最近跟男朋友一直吵架", context: ctx).turn.text
        if !chat.contains("用你的命盤看") { fails.append("✗ 閒聊沒用上命盤：\(chat.prefix(80))") }
        // 不是算命的話不能被當成算命
        for q in ["今天好累", "我好累", "這個月好忙", "12+30*2", "你好"] {
            let r = engine.reply(to: q, context: ctx)
            if r.turn.source == .reader { fails.append("✗ 誤判成算命：\(q) → \(r.turn.text.prefix(60))") }
        }
        // 外語
        for (q, must) in [("what's my fortune tonight", ["Tonight"]), ("this week's fortune", ["seven days"]),
                          ("how is this month", [D.month(9, year: 2026).reading.verdict == .good ? "Favorable" : ""]),
                          ("la suerte de esta noche", ["Esta noche"]), ("fortuna di stasera", ["Stasera"])] {
            let r = engine.reply(to: q, context: ctx)
            if !(r.turn.source == .reader && must.allSatisfy { $0.isEmpty || r.turn.text.contains($0) }) {
                fails.append("✗ \(q) [\(r.turn.source.rawValue)] → \(r.turn.text.prefix(100))")
            }
        }
        print("USER-PHRASINGS: \(cases.count + 45 - fails.count) ok, \(fails.count) failed\n" + fails.joined(separator: "\n"))
        XCTAssertTrue(fails.isEmpty, fails.joined(separator: "\n"))
    }

    // MARK: - 工具

    func testMathTool() {
        XCTAssertEqual(ToolRouter.handle("12+30*2"), "計算結果：12+30*2 = 72")
        XCTAssertEqual(ToolRouter.handle("(1+2)×3等於多少？"), "計算結果：(1+2)*3 = 9")
        XCTAssertEqual(ToolRouter.handle("7除以2"), "計算結果：7/2 = 3.5")
        XCTAssertNil(ToolRouter.handle("你好"))
        XCTAssertNil(ToolRouter.handle("2024"))
    }

    func testTimeTool() {
        let d = date(2026, 9, 29, 8, 5)
        XCTAssertEqual(ToolRouter.handle("現在幾點", now: d), "現在是 08:05。訊號時鐘校準完畢！")
        XCTAssertEqual(ToolRouter.handle("今天幾號", now: d), "今天是 2026 年 9 月 29 日，星期二。")
    }

}
