import Foundation

/// 一則對話訊息。
public struct ChatTurn: Codable, Equatable, Identifiable {
    public enum Role: String, Codable { case user, echo }
    /// 這則回覆是怎麼來的
    public enum Source: String, Codable {
        case neural      // Transformer 生成（一般對話，經十二宮感知）
        case grounded    // Transformer 解讀引擎事實框，並通過核對
        case corrected   // Transformer 解讀有誤，已改用引擎結果
        case tool        // 系統／計算機／時鐘
        case knowledge   // 資料庫
        case rule        // 使用者規則
        case reader      // 解讀層：引擎結果寫成的完整說明
    }

    public var id = UUID()
    public let role: Role
    public var text: String
    public var source: Source = .neural
    public var card: FortuneCard?
    /// 感知到的宮位（一般對話）
    public var palace: Int?
    /// 生成的 token（供演化回饋使用）
    public var tokens: [Int]?
    /// 使用者回饋：true 👍、false 👎
    public var liked: Bool?
    /// 對話庫／陪伴層的原始回覆（回饋時用來記住「這種說法」好不好）
    public var variant: String?

    public init(role: Role, text: String, source: Source = .neural, card: FortuneCard? = nil,
                palace: Int? = nil, tokens: [Int]? = nil) {
        self.role = role
        self.text = text
        self.source = source
        self.card = card
        self.palace = palace
        self.tokens = tokens
    }
}

/// 取樣參數。
public struct SamplingOptions: Codable, Equatable {
    public var temperature: Float = 0.6
    public var topK: Int = 10
    public var repetitionPenalty: Float = 1.1
    public var maxNewTokens: Int = 120
    public var useTools: Bool = true
    public var evolutionStrength: Float = 1.0

    public init() {}
}

/// NineSun 的認知迴路（底層 = 九型十二宮）：
///
///   規則（使用者的話就是法律）
///     → 十二宮感知：每句話先找出被觸動的宮位，累積成命主畫像
///     → 符號推理：九型十二宮／八字／紫微／易經引擎算出事實，寫成事實框 <f>
///     → 神經生成：Transformer 讀入「對話 + 事實框」逐字生成，並套用演化權重
///     → 自我核對：解讀必須包含引擎算出的事實，不符就改用引擎結果
///     → 規則強制：每一則回覆都套用使用者規則
public final class EchoEngine {
    public let model: EchoModel
    public var options = SamplingOptions()
    /// 各語言的資料庫
    public var knowledge: [Lang: KnowledgeBase] = [:]
    /// 多語系模板與資料（英文／西班牙文／義大利文）
    public var i18n: I18N?
    /// 手寫對話庫（人設、日常、生活）
    public var chatBank: ChatBank?
    public var core: PalaceCore?
    public var evolution: Evolution
    /// 上一則命理解讀（可追問「為什麼」「怎麼辦」）與當時的對話長度
    public var last: Followup?
    var lastTurn = 0
    /// 上一則八字／紫微的問題（追問「為什麼」「怎麼辦」時用）
    var lastMantic: String?
    var lastManticTurn = -1
    var rng: SplitMix64

    public init(model: EchoModel, seed: UInt64? = nil) {
        self.model = model
        evolution = Evolution(vocab: model.config.vocab_size)
        rng = SplitMix64(seed: seed ?? UInt64.random(in: 0...UInt64.max))
    }

    public struct Context {
        public var profile: UserProfile
        public var rules: RuleBook
        public var now: Date
        /// 使用者偏好語言（自動偵測失敗時使用）
        public var language: Lang
        /// true：依每則訊息自動判斷語言
        public var autoDetect: Bool
        public init(profile: UserProfile = UserProfile(), rules: RuleBook = RuleBook(), now: Date = Date(),
                    language: Lang = .zh, autoDetect: Bool = true) {
            self.profile = profile
            self.rules = rules
            self.now = now
            self.language = language
            self.autoDetect = autoDetect
        }
    }

    public struct Reply {
        public var turn: ChatTurn
        /// 有變動時才非 nil（App 需保存）
        public var profile: UserProfile?
        public var rules: RuleBook?
        /// 資料庫查不到時，App 可改查維基百科
        public var webQuery: String?
        /// 引擎算出的事實（保底文字）與必含字串：交給超腦時用來約束與核對
        public var facts: String? = nil
        public var must: [String] = []
        /// 這則回覆使用的語言
        public var lang: Lang = .zh
        /// 回答完之後還要上網查、再對照分析的關鍵組合（八字／紫微）
        public var webAugment: [String] = []
        /// 對照用的盤面重點
        public var augmentFacts: String = ""
    }

    static let selfTypeQ = ["你是幾型", "你的九型", "你是什麼型", "你的命宮", "你的生日", "你的命盤", "你的靈數"]
    static let selfDayQ = ["你今天心情", "你今天好嗎", "你今天怎麼樣", "你心情如何", "你今天運勢", "你今天的日宮"]
    static let portraitQ = ["你了解我", "我的畫像", "你覺得我是怎樣的人", "分析我", "你對我的印象", "你懂我"]

    /// 上一次上網查的問題（追問「那這些國家是哪些」時補上主題）
    var lastWebQuery: String?
    var lastWebTurn = -100
    /// 上一個問題（不論是上網查還是本地回答），追問時用來補上主題
    var lastQuestion: String?
    var lastQuestionTurn = -100

    /// 逐字產生回覆。`onToken` 每產生一個字就回呼一次。
    public func reply(to message: String, history: [ChatTurn] = [], context: Context,
                      onToken: ((String) -> Void)? = nil) -> Reply {
        // 追問（「那這些國家都是哪些國家」）：先把代名詞換回上一題的主題，再照一般問題處理
        var text = message
        if let prev = lastQuestion, history.count - lastQuestionTurn <= 8,
           let t = EchoEngine.substituteAnaphor(message, previous: prev) { text = t }
        var r = replyCore(to: text, history: history, context: context, onToken: onToken)
        if r.webQuery != nil || (EchoEngine.isQuestion(text) && !EchoEngine.fortuneIntent(text) && r.turn.card == nil) {
            lastQuestion = text
            lastQuestionTurn = history.count
        }
        if let q = r.webQuery {
            // 上網查的回覆不帶宮位感知標籤；追問的代名詞補上前一題的主題
            r.turn.palace = nil
            let resolved = EchoEngine.resolveFollowUp(message, query: q, previous: lastWebQuery, gap: history.count - lastWebTurn)
            r.webQuery = resolved
            lastWebQuery = resolved
            lastWebTurn = history.count
        }
        return r
    }

    static let anaphora = ["這些", "那些", "這個", "那個", "它們", "他們", "牠們", "其中", "剛剛說的", "剛才說的", "上面說的"]

    /// 追問換成完整的問題：「那這些國家都是哪些國家」（上一題「歐洲有多少個國家」）→「歐洲國家都是哪些國家」
    static func substituteAnaphor(_ text: String, previous prev: String) -> String? {
        let t0 = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 「這個月」「那個時候」是時間，不是在指上一題；要算運勢的也不接
        let timeWords = ["這個月", "那個月", "這個禮拜", "這個星期", "這個時候", "那個時候", "這個年", "這個週末"]
        if timeWords.contains(where: { t0.contains($0) }) || fortuneIntent(t0) { return nil }
        guard let a = anaphora.first(where: { t0.contains($0) }) else { return nil }
        let topic = WebAgent.coreTopic(prev).replacingOccurrences(of: "個", with: "")
        let main = topic.split(separator: " ").map { String($0.filter { $0.isLetter || $0.isNumber }) }.filter { $0.count >= 2 }
        guard !main.isEmpty else { return nil }
        let missing = main.filter { !t0.contains($0) }
        // 跟上一題有共同的詞（「這些國家」的國家），或是很短的追問（「那些是哪些」），才當成在指上一題
        guard missing.count < main.count || t0.count <= 6 else { return nil }
        var t = t0
        for w in ["我是說", "我的意思是", "我是問", "那麼", "那"] where t.hasPrefix(w) { t.removeFirst(w.count); break }
        if let r = t.range(of: a) { t.replaceSubrange(r, with: missing.joined()) }
        return t.isEmpty ? nil : t
    }

    /// 追問：「那這些國家都是哪些國家」→「歐洲 國家 哪些國家 列表」
    static func resolveFollowUp(_ text: String, query q: String, previous: String?, gap: Int) -> String {
        var cur = q
        let refers = anaphora.contains { text.contains($0) }
        if refers {
            for w in anaphora + ["我是說", "我的意思是", "都是", "那"] { cur = cur.replacingOccurrences(of: w, with: " ") }
        }
        var tokens = cur.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if refers, let prev = previous, gap <= 8 {
            let topic = WebAgent.coreTopic(prev).replacingOccurrences(of: "個", with: "")
            let main = topic.split(separator: " ").map(String.init).filter { $0.count >= 2 }
            // 只補這一句還沒講到的主題詞（「這些歐洲國家」已經有歐洲，就不用補）
            let missing = main.filter { m in !tokens.contains { $0.contains(m) } }
            tokens = missing + tokens
        }
        var out = tokens.joined(separator: " ")
        if refers && text.contains("哪些") && !out.contains("列表") { out += " 列表" }
        return out.isEmpty ? q : out
    }

    func replyCore(to message: String, history: [ChatTurn] = [], context: Context,
                   onToken: ((String) -> Void)? = nil) -> Reply {
        var ctx = context
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let L = ctx.autoDetect ? Lang.detect(text, fallback: ctx.language) : ctx.language
        func done(_ t: String, _ src: ChatTurn.Source, card: FortuneCard? = nil, palace: Int? = nil,
                  tokens: [Int]? = nil, profile: UserProfile? = nil, rules: RuleBook? = nil, web: String? = nil) -> Reply {
            let enforced = (rules ?? ctx.rules).enforce(t)
            var r = Reply(turn: ChatTurn(role: .echo, text: enforced, source: src, card: card, palace: palace, tokens: tokens),
                          profile: profile, rules: rules, webQuery: web)
            r.lang = L
            return r
        }

        // 0) 安全：說想死、不想活的時候，先好好接住，不算命、不上網、不套規則
        if let care = Safety.crisisReply(text, L) {
            var r = Reply(turn: ChatTurn(role: .echo, text: care, source: .tool), profile: nil, rules: nil, webQuery: nil)
            r.lang = L
            return r
        }

        // 1) 規則指令（四語）
        if let cmd = RuleBook.parse(text) {
            var book = ctx.rules
            let ack = book.apply(cmd, L)
            var r = Reply(turn: ChatTurn(role: .echo, text: ack, source: .rule), profile: nil, rules: book, webQuery: nil)
            r.lang = L
            return r
        }
        // 2) 觸發規則
        if let t = ctx.rules.trigger(for: text) { return done(t, .rule) }

        // 2.5) 明確叫它上網查（「上網查…」「搜尋…」「幫我查…」「search …」）：直接上網，不用本地存的答案
        if let q = EchoEngine.explicitSearch(text) {
            return done(Loc.s("webAsk", L), .tool, web: q)
        }

        // 外語走多語系流程
        if L != .zh, let i18n {
            return replyForeign(text, L, i18n, history: history, ctx: ctx, onToken: onToken, done: done)
        }

        // 3) 教十二宮新詞（演化）
        if let core, let g = RuleBook.match(text, #"(?:記住[：:]?)?(.+?)屬於(\d{1,2})宮"#), let p = Int(g[1]), (1...12).contains(p) {
            let word = RuleBook.strip(g[0])
            core.teach(word, palace: p)
            return done("學會了！以後「\(word)」會觸動\(NT.label(p))。我的十二宮感知又進化了一點。", .tool)
        }

        // 3.5) 幫別人看：「我老公1990年5月5日生，他今年運勢如何」——不能覆蓋使用者自己的生日
        if !ManticReader.wants(text), let who = Persona.otherPerson(text), let b = FortuneRouter.parseDate(text) {
            return done(otherReading(text, who: who, birth: b, now: ctx.now), .reader)
        }
        // 3.6) 九型人格深度問答：壓力、成長、優缺點、適合的工作、感情中的自己
        if !ManticReader.wants(text), let ask = Persona.parse(text, L: .zh) {
            guard let bd = ctx.profile.birthday else {
                return done("我需要你的生日才能知道你是第幾型。直接告訴我，例如：我的生日是2000年1月1日。", .tool)
            }
            let out = Persona.answer(ask, D: Destiny(bd), i18n: i18n, R: Reader(.zh, i18n: i18n))
            return done(out.text, .reader, card: out.card)
        }

        // 3.55) 八字／紫微（本命、流年、流月、大運、主題；句中帶生日就用那個生日排）
        let lastEcho = history.last(where: { $0.role == .echo })?.text ?? ""
        let expectingTime = lastEcho.contains("幾點出生") || lastEcho.contains("出生時辰")
        let expectingGender = lastEcho.contains("看性別")
        let profUpdate = ProfileParser.parse(text, expectingTime: expectingTime, expectingGender: expectingGender)
        let aboutOther = FortuneRouter.parseDate(text) != nil && (Persona.otherPerson(text) != nil || !text.contains("我"))
        if ManticReader.wants(text), profUpdate == nil || aboutOther,
           let out = ManticReader.route(text, profile: ctx.profile, now: ctx.now) {
            if out.needs == nil { lastMantic = text; lastManticTurn = history.count }
            var r = done(out.text, .reader, card: out.card)
            r.webAugment = out.search; r.augmentFacts = out.summary
            return r
        }
        if let q = lastMantic, history.count - lastManticTurn <= 6,
           let k = TopicRouter.followKind(text, L: .zh), let s = ManticReader.followup(k, query: q, profile: ctx.profile, now: ctx.now) {
            return done(s, .reader)
        }

        // 4) 出生時間、性別
        if let upd = profUpdate {
            var prof = ctx.profile
            var msgs: [String] = []
            if text.contains("生日") || text.contains("出生"), let b = FortuneRouter.parseDate(text) {
                prof.birthday = b
                msgs.append("生日記為\(b.display)")
            }
            if let h = upd.hour {
                prof.hour = h; prof.minute = upd.minute
                msgs.append("出生時間記為 \(String(format: "%02d:%02d", h, upd.minute ?? 0))（\(GZ.branches[((h + 1) / 2) % 12])時）")
            }
            if let m = upd.male { prof.male = m; msgs.append("性別記為\(m ? "男" : "女")") }
            // 同一句話要排盤，或上一句 NineSun 在等時辰／性別：記好之後直接接著回答
            var pending: String? = ManticReader.wants(text) ? text : nil
            if pending == nil && (expectingTime || expectingGender), history.count >= 2,
               let q = history.dropLast().last(where: { $0.role == .user })?.text, ManticReader.wants(q) {
                pending = q
            }
            if let q = pending, let out = ManticReader.route(q, profile: prof, now: ctx.now), out.needs == nil {
                lastMantic = q; lastManticTurn = history.count
                var r = done("收到，" + msgs.joined(separator: "，") + "。\n\n" + out.text, .reader, card: out.card, profile: prof)
                r.webAugment = out.search; r.augmentFacts = out.summary
                return r
            }
            let tail = prof.birthday.map { FortuneRouter.todayTail(Destiny($0), now: ctx.now) } ?? ""
            return done("收到，" + msgs.joined(separator: "，") + "。現在可以排八字和紫微斗數了！" + tail, .tool, profile: prof)
        }

        // 5) NineSun 自己的命盤、命主畫像
        if EchoEngine.selfTypeQ.contains(where: { text.contains($0) }) {
            let f = PalaceCore.selfTypeFrame()
            let t = Destiny(PalaceCore.selfBirth).type
            return grounded(text, frame: f.frame, must: ["第\(t)型"], fallback: f.reply, card: nil, ctx: ctx, onToken: onToken, done: done)
        }
        if EchoEngine.selfDayQ.contains(where: { text.contains($0) }) {
            let p = todayPalace(PalaceCore.selfBirth, ctx.now)
            let f = PalaceCore.selfDayFrame(p)
            return grounded(text, frame: f.frame, must: [NT.label(p)], fallback: f.reply, card: nil, ctx: ctx, onToken: onToken, done: done)
        }
        if EchoEngine.portraitQ.contains(where: { text.contains($0) }) && !FullReading.matches(text) {
            let top = core?.topPalaces() ?? []
            let t = ctx.profile.birthday.map { Destiny($0).type }
            let f = PalaceCore.portraitFrame(top: top, type: t)
            let card = top.isEmpty ? nil : FortuneCard(title: "命主畫像", headline: top.map { NT.label($0) }.joined(separator: " · "),
                                                       details: (1...12).filter { (core?.memory[$0] ?? 0) >= 0.5 }
                                                           .map { "\(NT.label($0))  \(String(format: "%.1f", core!.memory[$0]))" })
            return grounded(text, frame: f.frame, must: top.first.map { [NT.label($0)] } ?? [], fallback: f.reply,
                            card: card, ctx: ctx, onToken: onToken, done: done)
        }

        // 5.5) 實用型問題（沒有要算運勢）：用思路庫寫好的答案，不要被主題、宮位搶走
        // 不是問句的（「我感冒了好難受」）只接常識型、不用上網的答案；心情、感情這類還是交給命盤陪伴
        if !EchoEngine.fortuneIntent(text), let pb = chatBank?.playbookEntry(text, .zh), EchoEngine.isQuestion(text) || !pb.web {
            let raw = choose(pb.answers)
            var r = done(raw, .neural)
            r.turn.tokens = []
            r.turn.variant = raw
            if pb.web && !EchoEngine.addressedToMe(text) { r.webQuery = EchoEngine.searchQuery(text) }
            return r
        }

        // 6) 八字、紫微、易經卦
        if let q = ManticRouter.route(text, profile: ctx.profile, now: ctx.now, rng: &rng) {
            if q.deterministic { return done(q.fallback + q.tail, .tool, card: q.card) }
            return grounded(text, frame: q.frame, must: q.mustContain, fallback: q.fallback, card: q.card, tail: q.tail,
                            ctx: ctx, onToken: onToken, done: done)
        }

        // 6.5) 追問上一則解讀：為什麼、怎麼辦、再多說一點
        if let f = last, history.count - lastTurn <= 6, let k = TopicRouter.followKind(text, L: .zh) {
            return done(Reader(.zh, i18n: i18n).followup(k, f), .reader)
        }
        // 6.5x) 綜合分析：本命＋九型＋大運＋流年＋流月＋流日＋引動，找出重點
        if FullReading.matches(text) {
            guard let bd = ctx.profile.birthday else {
                return done("我需要你的生日才能做綜合分析。直接告訴我，例如：我的生日是2000年1月1日，或到右上角「調頻台」選好日期。", .tool)
            }
            let out = FullReading.build(Destiny(bd), now: ctx.now, R: Reader(.zh, i18n: i18n), profile: ctx.profile)
            last = out.follow; lastTurn = history.count; lastMantic = nil
            return done(out.text, .reader, card: out.card)
        }
        // 6.54) 明顯是在問知識、新聞、天氣、疾病、法律……（不是在問自己的命）：上網查
        if EchoEngine.strongInfo(text) || EchoEngine.healthOrLegal(text) {
            if let kb = knowledge[.zh], let e = kb.answer(text) {
                return done("\(e.title)：\(e.body)", .knowledge,
                            card: FortuneCard(title: "資料庫 · \(e.cat)", headline: e.title, details: [e.body]), web: EchoEngine.searchQuery(text))
            }
            return done(Loc.s("webAsk", .zh), .tool, web: EchoEngine.searchQuery(text))
        }
        // 6.55) 規劃型：什麼時候、哪個月最好、哪方面比較順、N宮
        if let ask = Planner.parse(text, now: ctx.now) {
            guard let bd = ctx.profile.birthday else {
                return done("我需要你的生日才能推算。直接告訴我，例如：我的生日是2000年1月1日，或到右上角「調頻台」選好日期。", .tool)
            }
            let out = Planner.answer(ask, D: Destiny(bd), now: ctx.now, reader: Reader(.zh, i18n: i18n))
            if out.follow != nil { last = out.follow; lastTurn = history.count; lastMantic = nil }
            return done(out.text, .reader, card: out.card)
        }
        // 6.6) 主題問句：感情、事業、財運、健康……（本命 + 大運方面 + 流年引動 + 流月）
        if let tp = TopicRouter.parse(text, L: .zh, now: ctx.now) {
            guard let bd = ctx.profile.birthday else {
                return done("我還不知道你的生日，沒辦法看這個主題。直接告訴我，例如：我的生日是2000年1月1日，或到右上角「調頻台」選好日期（會自動儲存）。", .tool)
            }
            let out = Reader(.zh, i18n: i18n).topicZh(Destiny(bd), palaces: tp.palaces.isEmpty ? [tp.palace] : tp.palaces, y: tp.y, m: tp.m)
            last = out.follow; lastTurn = history.count; lastMantic = nil
            return done(out.text, .reader, card: out.card)
        }

        // 7) 九型十二宮（含設定生日）
        if let q = FortuneRouter.route(text, birthday: ctx.profile.birthday, now: ctx.now, i18n: i18n) {
            var prof: UserProfile?
            if let b = q.newBirthday { var p = ctx.profile; p.birthday = b; prof = p; ctx.profile = p }
            if let c = q.composed {
                last = q.follow; lastTurn = history.count; lastMantic = nil
                return done(c, .reader, card: q.card, profile: prof)
            }
            if q.deterministic {
                var r = done(q.fallback + q.tail, .tool, card: q.card)
                r.profile = prof
                return r
            }
            var r = grounded(text, frame: q.frame, must: q.mustContain, fallback: q.fallback, card: q.card, tail: q.tail,
                             ctx: ctx, onToken: onToken, done: done)
            r.profile = prof
            return r
        }

        // 8) 資料庫
        let askSearch = text.hasPrefix("查") || text.hasPrefix("搜尋") || text.contains("幫我查")
            || text.contains("是誰") || text.contains("維基")
        let askKnow = askSearch || FortuneRouter.knowledgeMarkers.contains { text.contains($0) }
        if askKnow, !askSearch, let kb = knowledge[.zh], let e = kb.answer(text) {
            // 本地資料庫先回答，接著上網查更多說法
            return done("\(e.title)：\(e.body)", .knowledge,
                        card: FortuneCard(title: "資料庫 · \(e.cat)", headline: e.title, details: [e.body]), web: EchoEngine.searchQuery(text))
        }
        if askSearch {
            let k = KnowledgeBase.keyword(text)
            // 「你是誰」「我是誰」問的是對話，不是要查維基百科
            if k.count >= 2 && !["你", "我", "妳", "他", "她", "誰"].contains(k) {
                return done(Loc.s("web", .zh, k), .tool, web: EchoEngine.searchQuery(text))
            }
        }

        // 9) 工具
        if options.useTools, let answer = ToolRouter.handle(text, now: ctx.now, lang: .zh) { return done(answer, .tool) }

        // 10) 一般對話：先經十二宮感知，再依序：陪伴層 → 手寫對話庫 → 宮位感知回覆 → 老實說不會
        let palace = core?.perceive(text)
        if let p = palace { core?.remember(p) }
        return chatReply(text, .zh, ctx: ctx, palace: palace, turns: history.count) { t, src, pal in done(t, src, palace: pal) }
    }

    /// 一般對話的回答流程（中文與外語共用）
    func chatReply(_ text: String, _ L: Lang, ctx: Context, palace: Int?, turns: Int = 0, done: (String, ChatTurn.Source, Int?) -> Reply) -> Reply {
        let raw: String
        let asksMe = EchoEngine.addressedToMe(text)
        let asking = EchoEngine.isQuestion(text)
        if asking, let pb = chatBank?.playbookEntry(text, L) {
            // 思路庫：先用寫好的思路回答（前提 → 原因 → 做法 → 下一步），需要的話再上網查最新資料補充
            let a = choose(pb.answers)
            var r = done(a, .neural, nil)
            r.turn.tokens = []
            r.turn.variant = a
            if pb.web && !asksMe { r.webQuery = EchoEngine.searchQuery(text) }
            return r
        }
        if let c = companionReply(text, L, ctx: ctx, palace: palace) {
            raw = c
        } else if !asksMe, EchoEngine.infoQuestion(text) || EchoEngine.looksLikeQuestion(text) {
            // 在問問題（不是問 NineSun 自己）：上網查，不用本地寫死的答案
            var r = done(Loc.s("webAsk", L), .tool, palace)
            r.webQuery = EchoEngine.searchQuery(text)
            return r
        } else if let opts = chatBank?.answers(text, L, useKeywords: asking) {
            raw = choose(opts)
        } else if EchoEngine.infoQuestion(text) || (asking && !text.contains("我")) {
            // 知識題、跟自己無關的問題：上網查
            var r = done(Loc.s("webAsk", L), .tool, palace)
            r.webQuery = EchoEngine.searchQuery(text)
            return r
        } else if let p = palace {
            let cal = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: ctx.now)
            let dn = ctx.profile.birthday.map { Destiny($0).day(month: cal.month!, day: cal.day!) }
            raw = Companion.life(L: L, reader: Reader(L, i18n: i18n), perceived: p, day: dn?.day, night: dn?.night, choose: choose,
                                 destiny: ctx.profile.birthday.map { Destiny($0) }, now: ctx.now)
            if let bd = ctx.profile.birthday, L == .zh {
                let y = Calendar(identifier: .gregorian).component(.year, from: ctx.now)
                let D = Destiny(bd)
                last = Followup(scope: "topic", label: "", row: D.luckAspects(y)[p - 1], y: y, m: 1, d: 1, palace: p, birthday: bd)
                lastTurn = turns
                lastMantic = nil
            }
        } else {
            if asksMe {
                // 對 NineSun 說的話（「你去死吧」「你好爛」）不是要查資料：老實回應
                raw = Companion.fallback(L: L, choose: choose)
            } else if !EchoEngine.isQuestion(text) && !EchoEngine.infoQuestion(text) && (text.contains("我") || text.lowercased().contains(" i ") || text.lowercased().hasPrefix("i ")) {
                // 講自己的事（「我今天不想煮飯」）不是在問問題：先聽，不拿去上網查
                raw = choose(EchoEngine.listenReplies[[Lang.zh, .en, .es, .it].firstIndex(of: L) ?? 0])
            } else {
                // 本地不會：上網查（App 收到 webQuery 就去搜尋並整理答案）
                var r = done(Loc.s("webAsk", L), .tool, palace)
                r.webQuery = EchoEngine.searchQuery(text)
                return r
            }
        }
        var r = done(raw, .neural, palace)
        r.turn.tokens = []          // 讓對話泡泡出現 👍／👎
        r.turn.variant = raw
        return r
    }

    static let listenReplies: [[String]] = [
        ["嗯，我在聽。想多說一點嗎？", "了解。是發生了什麼事，還是只是想找人聊聊？", "聽起來今天有點累。想聊聊，還是要我幫你想想辦法？"],
        ["I'm listening. Want to tell me more?", "Got it. Did something happen, or do you just want to talk?"],
        ["Te escucho. ¿Quieres contarme más?", "Entiendo. ¿Pasó algo o solo quieres hablar?"],
        ["Ti ascolto. Vuoi raccontarmi di più?", "Capito. È successo qualcosa o vuoi solo parlare?"],
    ]

    static let infoMarkers = ["請解釋", "解釋一下", "是什麼", "什麼是", "什麼意思", "怎麼做", "怎麼用", "怎麼煮", "如何", "為什麼會", "為什麼要",
                              "多少", "哪裡", "哪個", "誰是", "是誰", "介紹", "教我", "推薦", "意思", "歷史", "原理", "區別", "差別", "方法",
                              "步驟", "新聞", "天氣", "價格", "幾歲", "有什麼", "怎麼去", "定義", "公式", "多高", "多大", "多遠", "多久", "多長",
                              "幾點", "幾號", "哪一", "哪些", "最新", "匯率", "股價", "比分", "氣溫", "上網", "搜尋", "google",
                              "where is", "when is", "when did", "how many", "how much", "latest", "news", "weather",
                              "what is", "what are", "who is", "how to", "how do", "how does", "why do", "why is", "explain", "tell me about",
                              "qué es", "quién es", "cómo se", "por qué", "explica", "cos'è", "chi è", "come si", "perché", "spiega"]
    /// 是不是問句（問句不該被當成閒聊，用宮位感知亂回）
    static func isQuestion(_ raw: String) -> Bool {
        let t = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = ["怎麼", "怎樣", "如何", "要不要", "該不該", "什麼", "為什麼", "哪", "可不可以", "能不能", "有沒有", "多少", "是不是",
                     "才能", "誰", "幾", "多遠", "多高", "多久", "多重", "多大", "多長", "多深", "how", "what", "why", "which", "who", "cómo", "qué", "por qué", "come", "cosa", "perché"]
        return words.contains { t.contains($0) } || t.hasSuffix("?") || t.hasSuffix("？") || t.hasSuffix("嗎") || t.hasSuffix("呢")
    }

    /// 有沒有要算運勢的意思（有的話交給命理；沒有的話是一般的實用問題）
    static func fortuneIntent(_ text: String) -> Bool {
        let meta = ["哪個準", "哪一個準", "比較準", "可以信", "可不可以信", "準不準", "準嗎"]
        if meta.contains(where: { text.contains($0) }) { return false }
        let words = ["運", "命", "宮", "今年", "明年", "流年", "大運", "流月", "這個月", "下個月", "今天", "明天", "今晚", "順不順", "好不好",
                     "會不會", "什麼時候", "哪個月", "哪一年", "哪天", "哪幾天", "哪一天", "適合", "八字", "紫微", "卦", "怎麼樣", "如何",
                     "九型", "第幾型"]
        return words.contains { text.contains($0) }
    }

    /// 是在問知識／資訊（可以上網查），不是在聊心情或算命
    static func infoQuestion(_ raw: String) -> Bool {
        let t = raw.lowercased()
        guard infoMarkers.contains(where: { t.contains($0) }) else { return false }
        let personal = ["我覺得", "我好", "我很", "我最近", "我心情", "我是不是", "我該", "我要不要"]
        return !personal.contains { t.contains($0) }
    }

    /// 明確要求上網查：回傳要搜尋的關鍵字（問自己的運勢、命盤不算）
    static func explicitSearch(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = t.lowercased()
        let prefixes = ["上網", "搜尋", "搜索", "查一下", "幫我查", "幫我搜", "幫我上網", "請上網", "請幫我查", "請幫我上網", "去網上", "網上查", "google",
                        "search ", "search for ", "look up ", "busca ", "buscar ", "cerca "]
        let inside = ["上網查", "上網搜", "上網找", "網路上查", "網上查", "上網看看"]
        guard prefixes.contains(where: { l.hasPrefix($0) }) || inside.contains(where: { t.contains($0) }) else { return nil }
        if t.contains("我的") || t.contains("運勢") || (t.contains("我") && ManticReader.wants(t)) { return nil }
        // 「你可以上網找資料嗎」「你會上網嗎」是在問 NineSun 的能力，不是要它去查
        if ["你可以", "你會", "你能", "你有辦法"].contains(where: { t.hasPrefix($0) }) && (t.hasSuffix("嗎") || t.hasSuffix("？") || t.hasSuffix("?")) { return nil }
        let q = WebAgent.keywords(t)
        return q.isEmpty || q == t ? nil : q
    }

    /// 明顯是知識、時事類問題（而且不是在問自己的命）
    static let strongMarkers = ["是什麼", "什麼是", "什麼意思", "是誰", "誰是", "新聞", "天氣", "氣溫", "匯率", "股價", "股市", "台股", "美股", "比分", "油價", "颱風", "地震", "怎麼做", "怎麼煮",
                                "怎麼去", "怎麼用", "教我", "介紹一下", "歷史", "原理", "定義", "公式", "多高", "多遠", "多大", "多久", "多長"]
    static let selfMarkers = ["我", "運", "命", "宮", "八字", "紫微", "卦", "大限", "流年", "流月", "流日", "九型", "星盤", "合婚", "桃花", "時辰", "生肖", "你"]
    static func strongInfo(_ raw: String) -> Bool {
        strongMarkers.contains { raw.contains($0) } && !selfMarkers.contains { raw.contains($0) }
    }

    /// 疾病、法律問題（就算句子裡有「我」也要上網查），但「我今年會不會離婚」這種是在問命
    static func healthOrLegal(_ raw: String) -> Bool {
        guard WebStrategy.isHealth(raw) || WebStrategy.isLegal(raw) else { return false }
        let fortune = ["運", "命", "宮", "八字", "紫微", "卦", "大限", "流年", "流月", "流日", "九型", "桃花", "時辰", "生肖"]
        if fortune.contains(where: { raw.contains($0) }) { return false }
        let when = ["會不會", "會嗎", "今年", "明年", "什麼時候", "哪年", "哪一年", "幾歲", "這個月", "下個月"]
        if raw.contains("我") && when.contains(where: { raw.contains($0) }) { return false }
        return raw.count >= 2
    }

    /// 在問 NineSun 自己（「你會唱歌嗎」「你幾歲」），不是要查資料
    static func addressedToMe(_ raw: String) -> Bool {
        var t = raw.lowercased()
        for w in ["你知道", "你可以告訴我", "你能告訴我", "你能不能告訴我", "你幫我", "請你", "你查", "你上網", "can you tell me", "do you know", "could you tell me"] {
            t = t.replacingOccurrences(of: w, with: "")
        }
        if ["你", "妳", "您"].contains(where: { t.contains($0) }) { return true }
        let words = t.split(whereSeparator: { !$0.isLetter })
        return words.contains { ["you", "your", "tú", "tu", "te", "ti"].contains(String($0)) }
    }

    /// 句子的形式是問句（「台北101有多高？」「明天會下雨嗎」），而且不是在說自己的心情
    static func looksLikeQuestion(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard t.count >= 4 else { return false }
        let personal = ["我覺得", "我好", "我很", "我最近", "我心情", "我是不是", "我該", "我要不要", "我想", "我今天", "我會不會", "我的"]
        if personal.contains(where: { t.contains($0) }) { return false }
        let mark = t.contains("?") || t.contains("？") || ["嗎", "呢", "麼"].contains(where: { t.hasSuffix($0) })
        let words = ["多少", "幾", "哪", "誰", "什麼", "怎麼", "為何", "為什麼", "是否", "有沒有", "是不是", "可不可以", "能不能", "要不要"]
        let en = ["what", "who", "where", "when", "why", "how", "which", "is there", "are there", "qué", "quién", "dónde", "cuándo", "cómo",
                  "cosa", "chi ", "dove", "quando", "come "]
        return (mark && (words.contains(where: { t.contains($0) }) || t.count >= 6)) || words.contains(where: { t.hasPrefix($0) })
            || en.contains(where: { t.hasPrefix($0) })
    }

    /// 把口語問句整理成搜尋關鍵字
    static func searchQuery(_ raw: String) -> String {
        var q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.hasPrefix("請") && !q.hasPrefix("請問") { q.removeFirst() }
        for w in ["請問", "請你", "請幫我", "幫我查一下", "幫我查", "幫我", "可以告訴我", "告訴我", "你知道", "我想知道", "一下", "呀", "啊", "呢", "吧", "嗎", "？", "?", "！", "!", "。"] {
            q = q.replacingOccurrences(of: w, with: " ")
        }
        q = q.replacingOccurrences(of: "查", with: " ", options: .anchored)
        let parts = q.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        let out = parts.joined(separator: " ")
        return out.isEmpty ? raw : out
    }

    /// 從幾種說法裡挑一句；使用者按過 👍 的說法更常出現，按過 👎 的少出現
    func choose(_ options: [String]) -> String {
        guard options.count > 1 else { return options[0] }
        let scores = evolution.replies ?? [:]
        let w = options.map { max(0.15, 1.0 + 1.5 * Double(scores[$0, default: 0])) }
        var r = Double(rng.next() >> 11) / Double(1 << 53) * w.reduce(0, +)
        for (i, x) in w.enumerated() {
            r -= x
            if r <= 0 { return options[i] }
        }
        return options[options.count - 1]
    }

    static let selfTypeQF = ["what type are you", "your enneagram", "your life palace", "your birthday", "qué tipo eres",
                             "tu eneagrama", "tu palacio de vida", "tu cumpleaños", "che tipo sei", "il tuo enneagramma",
                             "il tuo palazzo della vita", "il tuo compleanno"]
    static let selfDayQF = ["how are you today", "how do you feel today", "your mood today", "cómo estás hoy",
                            "cómo te sientes hoy", "tu ánimo hoy", "come stai oggi", "come ti senti oggi", "il tuo umore oggi"]
    static let portraitQF = ["do you understand me", "my portrait", "what kind of person am i", "analyze me", "me entiendes",
                             "mi retrato", "qué clase de persona soy", "analízame", "mi capisci", "il mio ritratto",
                             "che tipo di persona sono", "analizzami"]

    /// 英文／西班牙文／義大利文的認知迴路（與中文相同的階段）
    func replyForeign(_ text: String, _ L: Lang, _ i18n: I18N, history: [ChatTurn], ctx inCtx: Context,
                      onToken: ((String) -> Void)?,
                      done: (String, ChatTurn.Source, FortuneCard?, Int?, [Int]?, UserProfile?, RuleBook?, String?) -> Reply) -> Reply {
        var ctx = inCtx
        let lower = text.lowercased()

        // 教十二宮新詞
        if let core, let g = RuleBook.match(text, #"^(?:remember|recuerda|ricorda)?[:：]?\s*(.+?)\s+(?:is|belongs to|es|pertenece al|è|appartiene al)\s+(?:palace|palacio|palazzo)\s+(\d{1,2})"#),
           let p = Int(g[1]), (1...12).contains(p) {
            let word = RuleBook.strip(g[0]).lowercased()
            core.teach(word, palace: p)
            return done(Loc.s("teach", L, word, i18n.pn(p, L)), .tool, nil, nil, nil, nil, nil, nil)
        }

        // 出生時間、性別、生日
        if let upd = ProfileParser.parseForeign(text) {
            var prof = ctx.profile
            var msgs: [String] = []
            if let b = FortuneRouter.parseDate(text) {
                prof.birthday = b
                msgs.append(Loc.s("profile.birthday", L, "\(b.year)-\(b.month)-\(b.day)"))
            }
            if let h = upd.hour {
                prof.hour = h; prof.minute = upd.minute
                msgs.append(Loc.s("profile.time", L, String(format: "%02d:%02d", h, upd.minute ?? 0), GZ.branches[((h + 1) / 2) % 12]))
            }
            if let m = upd.male { prof.male = m; msgs.append(Loc.s(m ? "profile.male" : "profile.female", L)) }
            let tail = prof.birthday.map { i18n.todayTail(Destiny($0), now: ctx.now, L) } ?? ""
            return done(Loc.s("profile.ack", L, msgs.joined(separator: ", ")) + tail, .tool, nil, nil, nil, prof, nil, nil)
        }

        // NineSun 自己的命盤、命主畫像
        if EchoEngine.selfTypeQF.contains(where: { lower.contains($0) }) {
            let s = i18n.selfType(L)
            return grounded(text, frame: s.frame, must: s.must, fallback: s.reply, card: nil, ctx: ctx, onToken: onToken, done: done)
        }
        if EchoEngine.selfDayQF.contains(where: { lower.contains($0) }) {
            let s = i18n.selfDay(todayPalace(PalaceCore.selfBirth, ctx.now), L)
            return grounded(text, frame: s.frame, must: s.must, fallback: s.reply, card: nil, ctx: ctx, onToken: onToken, done: done)
        }
        if EchoEngine.portraitQF.contains(where: { lower.contains($0) }) {
            let top = core?.topPalaces() ?? []
            let s = i18n.portrait(top: top, type: ctx.profile.birthday.map { Destiny($0).type }, L)
            let card = top.isEmpty ? nil : FortuneCard(title: Loc.s("card.portrait", L), headline: top.map { i18n.pn($0, L) }.joined(separator: " · "))
            return grounded(text, frame: s.frame, must: s.must, fallback: s.reply, card: card, ctx: ctx, onToken: onToken, done: done)
        }

        // 追問上一則解讀
        if let f = last, history.count - lastTurn <= 6, let k = TopicRouter.followKind(text, L: L) {
            return done(Reader(L, i18n: i18n).followup(k, f), .reader, nil, nil, nil, nil, nil, nil)
        }
        // 主題問句：love / career / money / health …
        if let tp = TopicRouter.parse(text, L: L, now: ctx.now) {
            guard let bd = ctx.profile.birthday else {
                return done(Loc.s("noBirthday", L), .tool, nil, nil, nil, nil, nil, nil)
            }
            let out = Reader(L, i18n: i18n).topicReading(Destiny(bd), palace: tp.palace, y: tp.y, m: tp.m)
            last = out.follow; lastTurn = history.count; lastMantic = nil
            return done(out.text, .reader, out.card, nil, nil, nil, nil, nil)
        }

        // 九型十二宮、八字、紫微、易經
        if let q = ForeignRouter.route(text, L: L, i18n: i18n, profile: ctx.profile, now: ctx.now, rng: &rng) {
            var prof: UserProfile?
            if let b = q.newBirthday { var p = ctx.profile; p.birthday = b; prof = p; ctx.profile = p }
            if let c = q.composed {
                last = q.follow; lastTurn = history.count; lastMantic = nil
                return done(c, .reader, q.card, nil, nil, prof, nil, nil)
            }
            if q.deterministic {
                return done(q.fallback + q.tail, .tool, q.card, nil, nil, prof, nil, nil)
            }
            var r = grounded(text, frame: q.frame, must: q.mustContain, fallback: q.fallback, card: q.card, tail: q.tail,
                             ctx: ctx, onToken: onToken, done: done)
            r.profile = prof
            return r
        }

        // 資料庫／維基百科
        let searchWords = ["search", "look up", "who is", "wikipedia", "busca", "buscar", "quién es", "quien es", "cerca", "chi è", "chi e"]
        let askSearch = searchWords.contains { lower.hasPrefix($0) || lower.contains(" " + $0) }
        let askKnow = askSearch || ForeignRouter.knowMarkers.contains { lower.contains($0) }
        let key = KnowledgeBase.keyword(lower, lang: L)
        if askKnow, let kb = knowledge[L], let e = kb.answer(key) {
            return done("\(e.title): \(e.body)", .knowledge,
                        FortuneCard(title: "\(Loc.s("card.library", L)) · \(e.cat)", headline: e.title, details: [e.body]),
                        nil, nil, nil, nil, nil)
        }
        if askSearch, !key.isEmpty {
            return done(Loc.s("web", L, key), .tool, nil, nil, nil, nil, nil, key)
        }

        // 工具
        if options.useTools, let answer = ToolRouter.handle(text, now: ctx.now, lang: L) {
            return done(answer, .tool, nil, nil, nil, nil, nil, nil)
        }

        // 一般對話：十二宮感知 → 陪伴層 → 手寫對話庫 → 宮位感知回覆 → 老實說不會
        let palace = core?.perceive(text, lang: L)
        if let p = palace { core?.remember(p) }
        return chatReply(text, L, ctx: ctx, palace: palace, turns: history.count) { t, src, pal in done(t, src, nil, pal, nil, nil, nil, nil) }
    }

    /// 用別人的生日推算，稱呼換成「你老公」「你媽媽」……
    func otherReading(_ text: String, who: String, birth b: BirthDay, now: Date) -> String {
        let D = Destiny(b)
        let R = Reader(.zh, i18n: i18n)
        // 把生日日期拿掉，免得「5月5日」被當成在問 5 月
        var q = text
        if let re = try? NSRegularExpression(pattern: #"\d{4}\s*[年/\-.]\s*\d{1,2}\s*[月/\-.]\s*\d{1,2}\s*[日號]?"#) {
            q = re.stringByReplacingMatches(in: q, range: NSRange(q.startIndex..., in: q), withTemplate: "")
        }
        // 「老公」「媽媽」是在說誰，不是在問伴侶宮、家庭宮
        for (k, _) in Persona.others { q = q.replacingOccurrences(of: k, with: "") }
        var body: String
        if let tp = TopicRouter.parse(q.replacingOccurrences(of: "他", with: "我").replacingOccurrences(of: "她", with: "我"), L: .zh, now: now) {
            body = R.topicReading(D, palace: tp.palace, y: tp.y, m: tp.m).text
        } else if let ask = Planner.parse(q.replacingOccurrences(of: "他", with: "我").replacingOccurrences(of: "她", with: "我"), now: now) {
            body = Planner.answer(ask, D: D, now: now, reader: R).text
        } else if let kind = FortuneRouter.classify(q, now: now, date: nil, isSyn: false) {
            body = FortuneRouter.reading(kind, D: D, R: R, now: now, text: q).text
        } else {
            body = R.natal(D).text + "\n\n" + R.year(D, y: Calendar(identifier: .gregorian).component(.year, from: now)).text
        }
        let name = who.hasPrefix("你") ? String(who.dropFirst()) : who
        body = body.replacingOccurrences(of: "你的", with: "\(who)的").replacingOccurrences(of: "你是第", with: "\(who)是第")
            .replacingOccurrences(of: "你今天", with: "\(who)今天").replacingOccurrences(of: "你在大運", with: "\(who)在大運")
        return "以\(who)（\(b.display)）的九型十二宮來看：\n" + body
            + "\n\n（這是幫\(name)算的，不會改掉你自己的生日。）"
    }

    /// 陪伴層：寒暄與情緒陪伴（把感受接回今天的日宮／夜宮）
    func companionReply(_ text: String, _ L: Lang, ctx: Context, palace: Int?) -> String? {
        let cal = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: ctx.now)
        let dn = ctx.profile.birthday.map { Destiny($0).day(month: cal.month!, day: cal.day!) }
        return Companion.reply(text, L: L, reader: Reader(L, i18n: i18n), now: ctx.now, hasBirthday: ctx.profile.birthday != nil,
                               perceived: palace, day: dn?.day, night: dn?.night, choose: choose)
    }

    func todayPalace(_ b: BirthDay, _ now: Date) -> Int {
        let c = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: now)
        return Destiny(b).day(month: c.month!, day: c.day!).day
    }

    /// 事實框 → 模型生成 → 核對 → 保底。
    /// 核對 = 必含字串都在，而且輸出裡的每一串數字都必須出現在事實框或保底文字裡（防止模型亂編數字）。
    func grounded(_ text: String, frame: String, must: [String], fallback: String, card: FortuneCard?,
                  tail: String = "", ctx: Context, onToken: ((String) -> Void)?,
                  done: (String, ChatTurn.Source, FortuneCard?, Int?, [Int]?, UserProfile?, RuleBook?, String?) -> Reply) -> Reply {
        let prompt = encodePrompt(message: text, frame: frame, history: [])
        var toks: [Int] = []
        let out = generate(prompt: prompt, tokens: &toks, onToken: onToken)
        let known = EchoEngine.digitRuns(frame + " " + fallback + " " + must.joined(separator: " "))
        let faithful = must.allSatisfy({ out.contains($0) }) && EchoEngine.digitRuns(out).isSubset(of: known) && !EchoEngine.stutters(out)
            && !EchoEngine.contradicts(out, fallback)
        var r = faithful
            ? done(out + tail, .grounded, card, nil, toks, nil, nil, nil)
            : done(fallback + tail, .corrected, card, nil, nil, nil, nil, nil)
        r.facts = fallback
        r.must = must
        return r
    }

    /// 模型口吃：同一字連續 3 次以上（「多多多變」），或同一段 2–4 字連續重複 3 次以上
    static func stutters(_ s: String) -> Bool {
        let c = Array(s)
        guard c.count >= 3 else { return false }
        for i in 0..<(c.count - 2) where c[i] == c[i + 1] && c[i] == c[i + 2] && !c[i].isNumber && !"—-…. ".contains(c[i]) { return true }
        for len in 2...4 where c.count >= len * 3 {
            for i in 0...(c.count - len * 3) {
                let a = c[i..<(i + len)], b = c[(i + len)..<(i + 2 * len)], d = c[(i + 2 * len)..<(i + 3 * len)]
                if a.elementsEqual(b) && a.elementsEqual(d) { return true }
            }
        }
        return false
    }

    /// 模型說法和引擎事實互相矛盾（身強↔身弱、喜用五行不同、好↔壞判讀）
    static func contradicts(_ out: String, _ facts: String) -> Bool {
        for pair in [("身強", "身弱"), ("Strong", "Weak"), ("fuerte", "débil"), ("forte", "debole")] {
            if (out.contains(pair.0) && facts.contains(pair.1) && !facts.contains(pair.0))
                || (out.contains(pair.1) && facts.contains(pair.0) && !facts.contains(pair.1)) { return true }
        }
        func after(_ s: String, _ key: String) -> String? {
            guard let r = s.range(of: key) else { return nil }
            return String(s[r.upperBound...].prefix(8)).filter { "金木水火土".contains($0) }
        }
        if let a = after(out, "喜用"), let b = after(facts, "喜用"), !a.isEmpty, a != b { return true }
        return false
    }

    static func digitRuns(_ s: String) -> Set<String> {
        var out = Set<String>(), cur = ""
        for ch in s {
            if ch.isASCII && ch.isNumber { cur.append(ch) } else { if !cur.isEmpty { out.insert(cur); cur = "" } }
        }
        if !cur.isEmpty { out.insert(cur) }
        return out
    }

    func generate(prompt: [Int], tokens: inout [Int], onToken: ((String) -> Void)?) -> String {
        let tok = model.tokenizer
        let state = model.makeState()
        var logits: [Float] = []
        for t in prompt { logits = model.step(token: t, state: state) }
        var text = ""
        while tokens.count < options.maxNewTokens && state.length < model.config.n_ctx {
            let next = sample(logits: logits, recent: tokens)
            if next == tok.eos { break }
            tokens.append(next)
            let piece = tok.token(next)
            text += piece
            onToken?(piece)
            if state.length >= model.config.n_ctx { break }
            logits = model.step(token: next, state: state)
        }
        return text
    }

    /// [<u>歷史<a>回覆<eos>]* <u>訊息 [<f>事實框] <a>
    func encodePrompt(message: String, frame: String?, history: [ChatTurn]) -> [Int] {
        let tok = model.tokenizer
        let budget = max(16, model.config.n_ctx - options.maxNewTokens)
        var tail: [Int] = []
        if let frame { tail = [tok.fact] + tok.encode(frame) }
        tail.append(tok.assistant)
        let msg = Array(tok.encode(message).suffix(max(4, budget - tail.count - 1)))
        let current = [tok.user] + msg + tail

        var ctx: [Int] = []
        var i = history.count - 1
        while i >= 1 {
            let u = history[i - 1], a = history[i]
            guard u.role == .user, a.role == .echo, a.source == .neural else { i -= 1; continue }
            let pair = [tok.user] + tok.encode(u.text) + [tok.assistant] + tok.encode(a.text) + [tok.eos]
            if ctx.count + pair.count + current.count > budget { break }
            ctx = pair + ctx
            i -= 2
        }
        return ctx + current
    }

    func sample(logits: [Float], recent: [Int]) -> Int {
        var z = logits
        let tok = model.tokenizer
        for s in 0..<tok.firstRegular where s != tok.eos { z[s] = -.infinity }
        // 演化權重
        if options.evolutionStrength > 0 && evolution.bias.count == z.count {
            for i in tok.firstRegular..<z.count { z[i] += options.evolutionStrength * evolution.bias[i] }
        }
        if options.repetitionPenalty > 1 {
            for t in Set(recent.suffix(16)) {
                z[t] = z[t] > 0 ? z[t] / options.repetitionPenalty : z[t] * options.repetitionPenalty
            }
        }
        if options.temperature <= 0.01 {
            return z.indices.max { z[$0] < z[$1] }!
        }
        var idx = Array(z.indices)
        if options.topK > 0 && options.topK < idx.count {
            idx.sort { z[$0] > z[$1] }
            idx = Array(idx.prefix(options.topK))
        }
        let mx = idx.map { z[$0] }.max()!
        let w = idx.map { expf((z[$0] - mx) / options.temperature) }
        let total = w.reduce(0, +)
        var r = Float(Double(rng.next() >> 11) / Double(1 << 53)) * total
        for (k, i) in idx.enumerated() {
            r -= w[k]
            if r <= 0 { return i }
        }
        return idx.last!
    }
}

/// 出生時間與性別的解析
public enum ProfileParser {
    public struct Update: Equatable { public var hour: Int?; public var minute: Int?; public var male: Bool? }

    /// expectingTime：上一句 NineSun 在問出生時辰，這一句只說「早上七點」也算；expectingGender 同理
    public static func parse(_ raw: String, expectingTime: Bool = false, expectingGender: Bool = false) -> Update? {
        let text = normalizeTime(raw)
        var u = Update()
        let aboutMe = text.contains("我是") || text.contains("性別") || expectingGender
        if aboutMe && ["男生", "男的", "男人", "男性", "性別男", "男孩"].contains(where: { text.contains($0) }) { u.male = true }
        if aboutMe && ["女生", "女的", "女人", "女性", "性別女", "女孩"].contains(where: { text.contains($0) }) { u.male = false }
        if expectingGender && u.male == nil {
            let bare = text.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            if bare == "男" { u.male = true } else if bare == "女" { u.male = false }
        }
        if text.contains("出生") || text.contains("時辰") || text.contains("生的") || expectingTime {
            if let g = RuleBook.match(text, #"(凌晨|半夜|早上|上午|中午|下午|傍晚|晚上)?\s*(\d{1,2})\s*(?:點|:|：|時)\s*(\d{1,2})?"#),
               var h = Int(g[1]), h <= 24 {
                let period = g[0]
                if ["下午", "傍晚", "晚上"].contains(period) && h < 12 { h += 12 }
                if period == "中午" && h < 11 { h += 12 }
                if (period == "凌晨" || period == "半夜") && h == 12 { h = 0 }
                u.hour = h % 24
                u.minute = Int(g[2]) ?? 0
            } else if let g = RuleBook.match(text, #"(子|丑|寅|卯|辰|巳|午|未|申|酉|戌|亥)時"#),
                      let b = GZ.branches.firstIndex(of: g[0]) {
                u.hour = b * 2
                u.minute = 0
            }
        }
        return u == Update() ? nil : u
    }

    static let cnDigit: [Character: Int] = ["零": 0, "〇": 0, "一": 1, "二": 2, "兩": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]

    static func cnNumber(_ w: String) -> Int? {
        let c = Array(w)
        if c.isEmpty || c.count > 3 { return nil }
        if c.count == 1 { return c[0] == "十" ? 10 : cnDigit[c[0]] }
        if c.count == 2 {
            if c[0] == "十" { return cnDigit[c[1]].map { 10 + $0 } }
            if c[1] == "十" { return cnDigit[c[0]].map { $0 * 10 } }
            return nil
        }
        guard c[1] == "十", let a = cnDigit[c[0]], let b = cnDigit[c[2]] else { return nil }
        return a * 10 + b
    }

    /// 「早上七點半」「晚上十一點十五分」→「早上7點30分」「晚上11點15分」
    public static func normalizeTime(_ s: String) -> String {
        var out = s
        guard let re = try? NSRegularExpression(pattern: "([零〇一二兩三四五六七八九十]{1,3})(?=點|時|分)") else { return s }
        let ms = re.matches(in: out, range: NSRange(out.startIndex..., in: out)).reversed()
        for m in ms {
            guard let r = Range(m.range(at: 1), in: out), let n = cnNumber(String(out[r])) else { continue }
            out.replaceSubrange(r, with: String(n))
        }
        return out.replacingOccurrences(of: "點半", with: "點30分")
    }
}

extension ProfileParser {
    /// 英文／西班牙文／義大利文：出生時間、性別（生日日期由 FortuneRouter.parseDate 解析）
    public static func parseForeign(_ raw: String) -> Update? {
        let t = raw.lowercased()
        var u = Update()
        let male = ["i'm a man", "i am a man", "i'm male", "i am male", "i'm a boy", "i'm a guy", "soy hombre", "soy un hombre",
                    "soy chico", "soy varón", "sono un uomo", "sono uomo", "sono un ragazzo", "sono maschio"]
        let female = ["i'm a woman", "i am a woman", "i'm female", "i am female", "i'm a girl", "soy mujer", "soy una mujer",
                      "soy chica", "sono una donna", "sono donna", "sono una ragazza", "sono femmina"]
        if male.contains(where: { t.contains($0) }) { u.male = true }
        if female.contains(where: { t.contains($0) }) { u.male = false }
        let bornWords = ["born", "birth", "nací", "naci", "nacido", "nacida", "nacimiento", "nato", "nata", "nascita"]
        if bornWords.contains(where: { t.contains($0) }),
           let g = RuleBook.match(t, #"(?:at|a las|a la|alle|all'|ore|around)\s*(\d{1,2})(?:[:.h](\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\s*(de la tarde|de la noche|de la mañana|di sera|del pomeriggio|di notte|di mattina)?"#),
           var h = Int(g[0]), h <= 24 {
            let ampm = g[2], part = g[3]
            if (ampm.hasPrefix("p") || ["de la tarde", "de la noche", "di sera", "del pomeriggio", "di notte"].contains(part)) && h < 12 { h += 12 }
            if ampm.hasPrefix("a") && h == 12 { h = 0 }
            u.hour = h % 24
            u.minute = Int(g[1]) ?? 0
        }
        return u == Update() ? nil : u
    }
}

/// 可重現的亂數產生器（測試用可固定種子）。
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
