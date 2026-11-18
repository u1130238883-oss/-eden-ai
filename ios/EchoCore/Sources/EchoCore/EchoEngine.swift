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
    /// 上網查的回覆：當初問的問題（👍／👎 時用來決定要記住還是重查）
    public var query: String?
    /// 翻譯的譯文和語音語言（泡泡上的 🔊 再念一次）
    public var speak: String?
    public var speakLang: String?
    /// 直接由開源模型回答時：模型的名字（泡泡上顯示，看得出是誰回答的）
    public var model: String?

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
        /// NineSun 的個性會罵人、會吐槽：叫它罵人、說髒話時不拒絕（只擋越過底線的）
        public var allowSwearing: Bool = true
        public init(profile: UserProfile = UserProfile(), rules: RuleBook = RuleBook(), now: Date = Date(),
                    language: Lang = .zh, autoDetect: Bool = true, allowSwearing: Bool = true) {
            self.allowSwearing = allowSwearing
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
    /// 本地剛回答的東西（笑話、作者、清單、作品、推薦、選擇題）：追問「再一個」「最大的是哪一個」「結局呢」「為什麼」時接得上
    struct LocalContext { var kind: String; var subject: String = ""; var extra: String = ""; var shown: String = ""; var answer: String = ""; var turn: Int }
    var lastLocal: LocalContext?
    /// 剛剛聊到想去的地方（「我想去日本玩」）：後面幾句「要簽證嗎」「有什麼好吃的」都是在問那裡
    var lastTravel: (place: String, turn: Int)?
    /// 上一則回覆有沒有在問使用者（「後來呢？」）：短短的補充才算是在回答
    var lastEchoAsked = false
    /// 現在是第幾輪（history.count），追問時比較隔了幾輪
    var nowTurn = 0
    /// 最近幾句使用者說的話（新的在前），追問沒有主角時接上去
    var recentUser: [String] = []

    /// 「要買什麼」「一天要吃多少」「要怎麼慶祝」：接上前幾句說的事（「我想學游泳」「我想減肥」「我明天生日」）再問一次
    func composeWithRecent(_ message: String, now: Date) -> String? {
        let plain = Talk.clean(message)
        guard !recentUser.isEmpty, (2...10).contains(plain.count), EchoEngine.isQuestion(message) || plain.hasSuffix("嗎"),
              plain.range(of: "^(要|該|可以|能|需要|會|還要|那要|那該|一天|每天|每個月)", options: .regularExpression) != nil else { return nil }
        // 自己就答得出來的（「一天要走幾步」）不用接
        guard Commonsense.answer(message, now: now) == nil else { return nil }
        for prev in recentUser.prefix(3) where prev.count >= 2 && prev.count <= 20 {
            let p = prev.replacingOccurrences(of: #"[。！!？?～~]+$"#, with: "", options: .regularExpression)
            let prevAnswer = Commonsense.answer(p, now: now)
            for cand in [p + plain, p.replacingOccurrences(of: #"^(我)?(今天|明天|最近|現在)?(想|要|好|很)?"#, with: "", options: .regularExpression) + plain] {
                if let a = Commonsense.answer(cand, now: now), a != prevAnswer { return cand }
            }
        }
        return nil
    }

    /// 逐字產生回覆。`onToken` 每產生一個字就回呼一次。
    public func reply(to message0: String, history: [ChatTurn] = [], context: Context,
                      onToken: ((String) -> Void)? = nil) -> Reply {
        // 簡體字、異體字（「猫可以吃巧克力吗」「怎麽煮白飯」）先轉成繁體再理解
        // 自我介紹的名字（「我叫张伟」）照原樣，不轉
        // 全形的數字、英文字母（「台北１０１多高」）換成半形
        let halfWidth = String(String.UnicodeScalarView(message0.unicodeScalars.map { u in
            if (0xFF10...0xFF19).contains(u.value) || (0xFF21...0xFF3A).contains(u.value) || (0xFF41...0xFF5A).contains(u.value) { return Unicode.Scalar(u.value - 0xFEE0)! }
            if u.value == 0x3000 { return " " }
            return u
        }))
        let message = halfWidth.range(of: "^(我叫|叫我|你可以叫我|我的名字是|我的名字叫|請叫我|以後叫我)", options: .regularExpression) != nil ? halfWidth : Hanzi.toTraditional(halfWidth)
        var r = replyMain(to: message, history: history, context: context, onToken: onToken)
        // 問的是查表就能答的命理知識（「庚干的四化」「日主辛看癸是什麼十神」），引擎卻在要生日：直接用算好的答
        if r.lang == .zh, r.turn.text.contains("不知道你的生日") {
            let facts = BrainFacts.fortune(message)
            if !facts.isEmpty {
                let t = facts.map { $0.replacingOccurrences(of: "（NineSun 算的）", with: "").replacingOccurrences(of: "（NineSun 的資料）", with: "") }
                r.turn = ChatTurn(role: .echo, text: t.joined(separator: "\n"), source: .tool)
            }
        }
        // 好到不像真的、要先給錢的事（保證獲利、中獎先付運費、把錢轉到安全帳戶）：引擎自己先提醒，不拿命理或一般閒聊回
        // （大腦開著時這則會交給大腦，它會先從壞的方面想再回答）；算出來的結果、使用者的規則、危機的回應不動
        if r.profile == nil, r.rules == nil, r.turn.role == .echo, r.turn.source != .tool, r.turn.source != .rule,
           !Safety.isCrisis(message), ScamCheck.looks(message) {
            r.turn = ChatTurn(role: .echo, text: ScamCheck.warning(zh: r.lang == .zh), source: .knowledge)
            r.webQuery = nil
            r.webAugment = []
            return r
        }
        // 帶著感受回答：對方開心就替他開心、難過就先心疼、罵我就先道歉——回答本來就有這種語氣、或是一般的問題就不加
        // 說想死的時候不加（「我想結束自己，哈哈」不能回「你真有趣😆」）
        // NineSun 自己的話（笑話、看法、選擇題）本身就帶著語氣，不再加「你真有趣😆」這種開頭
        if r.lang == .zh, r.turn.role == .echo, !r.turn.text.isEmpty, !Safety.isCrisis(message), r.turn.variant != "talk" {
            r.turn.text = Affect.color(r.turn.text, for: message, seed: message.count, voice: context.profile.birthday.map { Voice($0) })
        }
        return r
    }

    func replyMain(to message: String, history: [ChatTurn] = [], context: Context,
                   onToken: ((String) -> Void)? = nil) -> Reply {
        // 「你可以再說一次嗎」「能不能說簡單一點」：客氣的包裝拿掉，就是對剛剛回答的追問（不是在問我會不會）
        let message = history.isEmpty ? message : EchoEngine.unwrapPoliteFollowUp(message)
        // 追問（「那這些國家都是哪些國家」）：先把代名詞換回上一題的主題，再照一般問題處理
        let prevQuestion = lastQuestion, prevQuestionTurn = lastQuestionTurn
        var text = EchoEngine.normalizeSlang(message)
        var rewritten = false
        // 「說簡單一點」：把上一則回答濃縮成一兩句；「說詳細一點」：上網把上一題查得更完整（命盤解讀有自己的「再多說一點」）
        let plain = Talk.clean(message)
        // 「感情呢」「工作方面呢」（剛剛在看運勢）：同一段時間換一個面向
        if context.language == .zh,
           let g = RuleBook.match(plain, #"^(?:那|那麼)?(感情|愛情|桃花|戀愛|工作|事業|財運|錢|財|健康|身體|學業|考試|讀書|人際|家庭)(?:方面|運|運勢)?(?:呢|如何|怎麼樣|好嗎|會怎樣)?$"#) {
            let users = Array(history.enumerated().filter { $0.element.role == .user })
            // 前幾句裡、回答是命盤解讀的那一句
            if let hit = users.suffix(4).last(where: { u in u.offset + 1 < history.count && [.reader, .grounded].contains(history[u.offset + 1].source) }) {
                let prev = hit.element.text
                let times = ["今天", "明天", "後天", "這週", "這個禮拜", "下週", "這個月", "下個月", "今年", "明年"]
                let earlier = users.suffix(4).reversed().map { $0.element.text }
                let time = times.first(where: { prev.contains($0) }) ?? earlier.compactMap { e in times.first(where: { e.contains($0) }) }.first ?? "今年"
                let aspect = ["愛情": "感情", "桃花": "感情", "戀愛": "感情", "事業": "工作", "錢": "財運", "財": "財運", "身體": "健康", "考試": "學業", "讀書": "學業"][g[0]] ?? g[0]
                text = time + aspect + (aspect == "財運" ? "如何" : "運勢")
                rewritten = true
            }
        }
        // 「再乘以3」「那除以2呢」：接著剛剛算出來的數字算
        if context.language == .zh, let prevEcho = history.last(where: { $0.role == .echo })?.text,
           let pv = RuleBook.match(prevEcho, #"等於\s*(-?[0-9][0-9,]*(?:\.[0-9]+)?)"#).flatMap({ Double($0[0].replacingOccurrences(of: ",", with: "")) }),
           let g = RuleBook.match(plain, #"^(?:那|再|然後)?(?:再)?(加上|加|減掉|減去|減|乘以|乘上|乘|除以|除)\s*(-?[0-9]+(?:\.[0-9]+)?)(?:呢|是多少|等於多少|會是多少)?$"#),
           let y = Double(g[1]) {
            let op = g[0]
            var v = pv, sym = ""
            switch op {
            case "加上", "加": v = pv + y; sym = "+"
            case "減掉", "減去", "減": v = pv - y; sym = "−"
            case "乘以", "乘上", "乘": v = pv * y; sym = "×"
            default: sym = "÷"; v = y == 0 ? .nan : pv / y
            }
            let txt = v.isNaN ? "不能除以 0 喔。" : "\(QuickCalc.num(pv)) \(sym) \(QuickCalc.num(y)) 等於 \(QuickCalc.num(v))。"
            var r = Reply(turn: ChatTurn(role: .echo, text: txt, source: .tool), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 「下週五是幾號」「這週六幾號」
        if context.language == .zh, let g = RuleBook.match(plain, #"^(這|這個|下|下個|下下|下下個)(週|周|禮拜|星期)([一二三四五六日天])(?:是)?(?:幾號|幾月幾號|幾月幾日|哪一天|哪天)$"#) {
            let cal = Calendar(identifier: .gregorian)
            let wd = ["一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "日": 7, "天": 7][g[2]] ?? 1
            let today = cal.component(.weekday, from: context.now)            // 1 = 星期日
            let mondayOffset = (today + 5) % 7                                  // 今天離這週一幾天
            let weeks = g[0].hasPrefix("下下") ? 2 : (g[0].hasPrefix("下") ? 1 : 0)
            if let d = cal.date(byAdding: .day, value: -mondayOffset + 7 * weeks + (wd - 1), to: context.now) {
                let c = cal.dateComponents([.year, .month, .day], from: d)
                let names = ["日", "一", "二", "三", "四", "五", "六"]
                let w = names[cal.component(.weekday, from: d) - 1]
                let txt = "\(g[0])\(g[1])\(g[2])是 \(c.month!) 月 \(c.day!) 日（星期\(w)）。"
                var r = Reply(turn: ChatTurn(role: .echo, text: txt, source: .tool), profile: nil, rules: nil, webQuery: nil)
                r.turn.variant = "talk"
                return r
            }
        }
        // 「再說一次」「你剛剛說什麼」：把上一則再說一次
        if plain.range(of: #"^(再說一次|再講一次|再說一遍|再講一遍|你剛剛說什麼|剛剛說什麼|重複一次|再重複一次|沒聽清楚|剛剛那個再說一次|可以再說一次嗎)$"#, options: .regularExpression) != nil,
           let prevEcho = history.last(where: { $0.role == .echo })?.text, !prevEcho.hasPrefix("我剛剛說的是") {
            var r = Reply(turn: ChatTurn(role: .echo, text: "我剛剛說的是：\n" + prevEcho, source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 「想聊什麼？」→「好」：答應要聊
        if ["好", "好啊", "好呀", "嗯", "嗯嗯", "可以", "好喔", "OK", "ok"].contains(plain), let prevEcho = history.last(where: { $0.role == .echo })?.text,
           prevEcho.hasSuffix("想聊什麼？") || prevEcho.hasSuffix("想說什麼？") || prevEcho.hasSuffix("想聊聊嗎？") {
            var r = Reply(turn: ChatTurn(role: .echo, text: "好呀，我在聽～想從哪裡開始說都可以：今天發生的事、讓你煩心的事，或隨便聊聊都好，慢慢來。", source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 換了說法還是「聽不懂」：再濃縮成一句
        if plain.range(of: #"^(還是)?(聽不懂|看不懂|不懂|什麼意思|還是不懂)$"#, options: .regularExpression) != nil,
           let prevEcho = history.last(where: { $0.role == .echo })?.text, let r0 = prevEcho.range(of: "換個說法：") {
            var r = Reply(turn: ChatTurn(role: .echo, text: "簡單說：" + EchoEngine.gist(String(prevEcho[r0.upperBound...])) + "\n還是哪裡不清楚的話，跟我說是哪幾個字，我再解釋。", source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        if plain.range(of: #"^(可以|能不能|請)?(再)?(說|講|解釋|寫)?(得)?(簡單|白話|簡短|短|精簡|清楚)(一點|一些|點)(嗎)?$|^(簡單說|長話短說|太長了|太長|重點是什麼|說重點|講重點|講白話|白話文|說白話)$"#, options: .regularExpression) != nil,
           let prevAnswer = history.filter({ $0.role == .echo }).suffix(3).reversed().first(where: { !$0.text.hasPrefix("抱歉") && !$0.text.hasPrefix("簡單說：") && !$0.text.hasPrefix("我知道的重點大概就是這些了") && $0.text.count > 60 })?.text {
            let body = prevAnswer.hasPrefix("換個說法：") ? String(prevAnswer.dropFirst(5)) : prevAnswer
            var r = Reply(turn: ChatTurn(role: .echo, text: "簡單說：" + EchoEngine.gist(body), source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        if last == nil || history.count - lastTurn > 6,
           plain.range(of: #"^(可以|能不能|請)?(再)?(說|講|解釋|寫)?(得)?(詳細|多|清楚|完整)(一點|一些|點)(嗎)?$|^(再多說一點|多說一點|說多一點|詳細說明|詳細一點|展開說說)$"#, options: .regularExpression) != nil,
           let prevQ = history.last(where: { $0.role == .user })?.text, prevQ.count >= 2 {
            var r = Reply(turn: ChatTurn(role: .echo, text: Loc.s("webAsk", .zh), source: .tool), profile: nil, rules: nil, webQuery: EchoEngine.searchQuery(prevQ))
            r.lang = .zh
            return r
        }
        // 回「好」「要」「想」：上一則回答建議了一個問法（「想看看今天的運勢嗎？直接問我「今天運勢」」），就照那個問法做
        if let cmd = EchoEngine.acceptedSuggestion(message, history: history) {
            text = cmd
            rewritten = true
        }
        // 一次問兩三個（「台北101多高，富士山多高」「日本首都是哪裡？韓國呢？」）：每個自己答得出來就一起回答
        if context.language == .zh, !rewritten, text.count <= 40,
           let parts = Optional(text.components(separatedBy: CharacterSet(charactersIn: "，,？?；;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count >= 2 }),
           (2...3).contains(parts.count), parts.allSatisfy({ EchoEngine.isQuestion($0) || $0.hasSuffix("呢") || $0.hasSuffix("嗎") }) {
            var answers: [String] = []
            var prev = ""
            for p in parts {
                if let a = Commonsense.answer(p, now: context.now) { answers.append(a); prev = p; continue }
                if !prev.isEmpty, let sub = Commonsense.subject(prev), let f = Commonsense.followUp(p, subject: sub, previous: prev, now: context.now), f.local,
                   let a = Commonsense.answer(f.text, now: context.now) { answers.append(a); prev = f.text; continue }
                answers = []
                break
            }
            if answers.count == parts.count, Set(answers).count == answers.count {
                var r = Reply(turn: ChatTurn(role: .echo, text: answers.joined(separator: "\n\n"), source: .knowledge), profile: nil, rules: nil, webQuery: nil)
                r.turn.variant = "talk"
                return r
            }
        }
        // 追問本地剛回答的東西：直接回答，或把問題補完整（「他還寫了什麼」→「曹雪芹還寫了什麼」、「結局呢」→「哈姆雷特的結局」）
        // 追問要有對話（沒有歷史的一句話是新的問題，不接上一個人、上一次的話題）
        if context.language == .zh || Lang.detect(message, fallback: .zh) == .zh, let lc = lastLocal, !history.isEmpty, history.count - lc.turn <= 4 {
            lastEchoAsked = history.last(where: { $0.role == .echo }).map { $0.text.contains("？") || $0.text.contains("?") } ?? false
            nowTurn = history.count
            recentUser = history.filter { $0.role == .user }.suffix(4).reversed().map { $0.text }
            switch localFollowUp(message, lc) {
            case .answer(let a)?:
                var r = Reply(turn: ChatTurn(role: .echo, text: a, source: .knowledge), profile: nil, rules: nil, webQuery: nil)
                r.turn.variant = "talk"
                lastLocal?.turn = history.count
                if lc.kind == "mood" { lastLocal?.shown += "\u{1}" + message }
                // 謎語、笑話：記住最新的一題，追問「答案是什麼」才對得上
                if lc.kind == "笑話" { lastLocal?.answer = a }
                return r
            case .rewrite(let t)?:
                text = t
                rewritten = true
            case nil: break
            }
        }
        // 「我該怎麼辦」「那怎麼辦」：沒有接上剛剛的話題時，照前面幾句說的事給做法
        // （剛剛是命盤解讀的話，交給解讀的追問：怎麼做比較好）
        let readingJustNow = (last != nil && history.count - lastTurn <= 6) || history.last(where: { $0.role == .echo }).map { [.reader, .grounded].contains($0.source) } == true
        if !rewritten, context.language == .zh, !readingJustNow,
           plain.range(of: #"^(那|所以|可是|但是)?(我)?(真的|現在)?(不知道|不曉得)?(現在)?(要|該|應該)?(怎麼辦|怎麼做|如何是好|怎麼處理|怎麼解決|有什麼方法|有什麼辦法|有什麼建議|有沒有方法|有沒有辦法|能做什麼|可以做什麼|能幫什麼|可以幫什麼|能為他做什麼|可以為他做什麼|能做些什麼|可以做些什麼)(才好)?(呢|啊|嗎)?$"#, options: .regularExpression) != nil {
            let said = history.filter { $0.role == .user }.suffix(4).reversed().map { $0.text }
            // 「牠很愛叫」：牠是前面說的狗
            let pet = said.joined().contains("狗") ? "狗狗" : (said.joined().contains("貓") ? "貓咪" : "")
            search: for s1 in said {
                var s0 = s1
                if !pet.isEmpty, let f = s0.first, "牠他它".contains(f) { s0 = pet + s0.dropFirst() }
                let base = s0.replacingOccurrences(of: #"[啦啊喔耶。！!～~？?]+$"#, with: "", options: .regularExpression)
                guard base.count >= 2, !base.contains("怎麼辦") else { continue }
                for ask in [base + "怎麼辦", base.replacingOccurrences(of: #"了$"#, with: "", options: .regularExpression) + "怎麼辦"] where Commonsense.answer(ask, now: context.now) != nil {
                    text = ask
                    rewritten = true
                    break search
                }
                if let h = Commonsense.howtoMentioned(base) { text = h + "怎麼辦"; rewritten = true; break }
            }
            if !rewritten, !said.isEmpty {
                var r = Reply(turn: ChatTurn(role: .echo, text: EchoEngine.copingSteps, source: .knowledge), profile: nil, rules: nil, webQuery: nil)
                r.turn.variant = "talk"
                return r
            }
        }
        // 「不是，我是問第二高的」：改問上一題的另一個說法
        if !rewritten, context.language == .zh, let g = RuleBook.match(message.trimmingCharacters(in: .whitespaces), #"^(?:不是|不對|錯了)[，,、 ]*(?:我是問|我是說|我問的是|我要問|我想問|是問)(.{2,30}?)[？?。！!]*$"#),
           let prevQ = history.last(where: { $0.role == .user })?.text {
            var q = g[0]
            // 只說了一部分（「第二高的」）：換掉上一題裡的「最高的」
            if q.count <= 5, let r = prevQ.range(of: #"最[\p{Han}]{1,2}的"#, options: .regularExpression) {
                var p = prevQ
                p.replaceSubrange(r, with: q.hasSuffix("的") ? q : q + "的")
                q = p
            }
            text = q
            rewritten = true
        }
        // 短短的追問沒有主角（「要怎麼慶祝」「要穿什麼」「要放哪裡」）：接上前一句說的事再問一次
        if !rewritten, context.language == .zh, history.contains(where: { $0.role == .user }), (2...10).contains(plain.count),
           plain.range(of: "^(要|該|可以|能|需要|會|還要|那要|那該|一天|每天|每個月)", options: .regularExpression) != nil {
            recentUser = history.filter { $0.role == .user }.suffix(4).reversed().map { $0.text }
            if let c = composeWithRecent(message, now: context.now) { text = c; rewritten = true }
        }
        // 「已經兩天了」「要看醫生嗎」：剛剛的建議裡有什麼時候要就醫
        if !rewritten, context.language == .zh, let lastEcho = history.last(where: { $0.role == .echo })?.text, lastEcho.contains("醫"),
           plain.range(of: #"^(已經|都|快)?[0-9一二兩三四五六七八九十幾半]+(天|個禮拜|週|星期|個月|小時|個小時)(了)?(都)?(沒吃|沒好|還沒好|不吃|沒改善)?(了)?$|^(那)?(要|需要|該|應該|要不要)(去)?(看醫生|看獸醫|就醫|去醫院|看急診|掛急診)(嗎|呢)?$"#, options: .regularExpression) != nil,
           let c = lastEcho.components(separatedBy: CharacterSet(charactersIn: "。；\n")).first(where: { $0.contains("醫") }) {
            let clause = c.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"^.*?建議不要再等："#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"^([0-9]+\.|⚠️|小提醒：)\s*"#, with: "", options: .regularExpression)
            let lead = plain.contains("醫") ? "要，" : "已經\(plain.replacingOccurrences(of: #"^(已經|都|快)"#, with: "", options: .regularExpression))，建議不要再等："
            var r = Reply(turn: ChatTurn(role: .echo, text: lead + clause + "。", source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 「明天要考試」→「英文」：說了要考的科目
        if !rewritten, context.language == .zh, plain.count <= 6, let prevUser = history.last(where: { $0.role == .user })?.text,
           prevUser.contains("考"), let a = Talk.examSubject(message, upcoming: prevUser.range(of: "砸|不好|爛|不及格|被當|考差", options: .regularExpression) == nil) {
            var r = Reply(turn: ChatTurn(role: .echo, text: a, source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 剛剛問「最近過得好嗎？」：回答「很好啊」「不太好」不是道別或要上網查
        if !rewritten, context.language == .zh, let prevEcho = history.last(where: { $0.role == .echo }),
           let a = Talk.wellbeingReply(message, asked: prevEcho.text) {
            var r = Reply(turn: ChatTurn(role: .echo, text: a, source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 回答我剛剛問的問題（「牠叫什麼名字？」→「叫小白」）：接住，不拿去上網查
        if !rewritten, context.language == .zh, let prevEcho = history.last(where: { $0.role == .echo }),
           Talk.chat(message) == nil, Talk.detailed(message) == nil, Commonsense.answer(message, now: context.now) == nil,
           let a = Talk.replyToMyQuestion(message, asked: prevEcho.text) {
            var r = Reply(turn: ChatTurn(role: .echo, text: a, source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 「還有呢」接在自己回答的知識後面（不是推薦）：老實說就這些，想要更多可以上網查
        if !rewritten, plain.range(of: #"^(還有|還有呢|還有嗎|還有別的嗎|還有其他的嗎|還有別的|還有其他的|然後|然後呢|就這樣嗎|只有這樣嗎|就這樣|只有這樣)$"#, options: .regularExpression) != nil,
           let prevEcho = history.last(where: { $0.role == .echo }), prevEcho.source == .knowledge, prevEcho.text.count > 40 {
            var r = Reply(turn: ChatTurn(role: .echo, text: "我知道的重點大概就是這些了。想知道更多，跟我說「說詳細一點」，我上網幫你找更完整的資料。", source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 常見的困擾故事（被室友吵、怕上台、小孩不肯睡）：照故事的根源給做法，不要被句子裡附帶的「睡不著」帶走
        if !rewritten, context.language == .zh, !EchoEngine.explicitFortune(text), EchoEngine.explicitSearch(text) == nil,
           let a = EchoEngine.storyAdvice(text, now: context.now) {
            var r = Reply(turn: ChatTurn(role: .echo, text: a, source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 一大段在說自己的事、最後問了問題（「…要不要帶去看醫生」「…我該怎麼辦」）：先給最相關的做法
        if !rewritten, context.language == .zh, text.count > 30, !EchoEngine.explicitFortune(text), EchoEngine.explicitSearch(text) == nil,
           let a = EchoEngine.narrativeAdvice(text, now: context.now) {
            var r = Reply(turn: ChatTurn(role: .echo, text: a, source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 「牠很愛叫」：牠是前面說的狗或貓
        if !rewritten, context.language == .zh, text.hasPrefix("牠"), text.count >= 3 {
            let recent = history.filter { $0.role == .user }.suffix(6).map { $0.text }.joined()
            let pet = recent.contains("狗") ? "狗狗" : (recent.contains("貓") ? "貓咪" : "")
            if !pet.isEmpty { text = pet + text.dropFirst(); rewritten = true }
        }
        if !rewritten, let prev = lastQuestion, history.count - lastQuestionTurn <= 8,
           let t = EchoEngine.substituteAnaphor(message, previous: prev) { text = t }
        // 「番茄炒蛋要放糖嗎」：從那道菜的做法裡找
        if context.language == .zh, text.count <= 14, let a = Commonsense.recipeIngredient(text) {
            lastLocal = LocalContext(kind: "fact", subject: "", extra: text, answer: a + "\n" + (Commonsense.answer(String(text.prefix { !"要可需該能".contains($0) }) + "怎麼做") ?? ""), turn: history.count)
            var r = Reply(turn: ChatTurn(role: .echo, text: a, source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 剛剛在陪他聊心情（「今天好累」→「工作太多了」）：接著說的細節是在抒發，不是在問做法
        let moodChatBefore = lastLocal.map { $0.kind == "mood" && history.count - $0.turn <= 2 } ?? false
        var r = replyCore(to: text, history: history, context: context, onToken: onToken)
        // 「那十年呢」「那55公斤呢」「那英文呢」「那後天呢」「那高雄呢」：把上一題裡對應的那個部分換掉再問一次
        if context.language == .zh, let g = RuleBook.match(message.filter { !"，,。.！!？?～~、 ".contains($0) && !$0.isWhitespace }, #"^(?:那|那麼)(.{1,8}?)呢$"#),
           let prev0 = history.suffix(2).last(where: { $0.role == .user })?.text,
           // 上一句自己沒說主題（「要帶傘嗎」），往前找有主題的那一句（「台北明天天氣」）來換
           case let prev = EchoEngine.swapBase(prev0, history: history),
           r.webQuery != nil || r.turn.source == .neural || ((r.turn.source == .grounded || r.turn.source == .reader) && prev.contains("天氣")),
           let cand = EchoEngine.swapInto(previous: Talk.clean(prev), with: g[0]), cand != Talk.clean(prev) {
            let r2 = replyCore(to: cand, history: history, context: context, onToken: onToken)
            if r2.webQuery == nil, r2.turn.source != .neural, r2.turn.card == nil { return r2 }
            if r2.webQuery != nil { var w = r2; w.webQuery = cand; lastWebQuery = cand; lastWebTurn = history.count; w.turn.palace = nil; return w }
        }
        // 「第二高的呢」「那第三大的呢」（上一題「台灣最高的山是哪座」）：把「最高」換成「第二高」再問一次
        if context.language == .zh, let g = RuleBook.match(Talk.clean(message), #"^(?:那|那麼)?第([二三四五])(高|大|長|多|深|小|遠|快|重|冷|熱)的?(?:呢|是哪個|是什麼|是哪座|是哪裡|是哪一個)?$"#),
           let prevQ = history.filter({ $0.role == .user }).suffix(3).reversed().map(\.text).first(where: { $0.contains("最" + g[1]) }) {
            let q = prevQ.replacingOccurrences(of: "最" + g[1], with: "第" + g[0] + g[1])
            let r2 = replyCore(to: q, history: history, context: context, onToken: onToken)
            if r2.webQuery == nil, r2.turn.source != .neural { return r2 }
            var w = r2; w.webQuery = q; w.turn.text = Loc.s("webAsk", .zh); w.turn.source = .tool; w.turn.palace = nil
            lastWebQuery = q; lastWebTurn = history.count
            return w
        }
        // 「要煮多久」「怎麼去」「哪一年」「要帶什麼」：沒說主詞的追問——帶上前一題的主題（說「他」就是前一個回答裡的人）再問一次
        // 上一句也是追問（「說簡單一點」「會死嗎」）：主題在更前面那一句（「什麼是黑洞」「頭痛怎麼辦」）
        let lastUser = history.suffix(2).last(where: { $0.role == .user })?.text
        let topicTurn = lastUser == nil ? nil : history.filter { $0.role == .user }.suffix(4).reversed().map(\.text)
            .first(where: { !EchoEngine.isMetaFollowUp($0) && !EchoEngine.subjectless($0)
                && Talk.clean($0).range(of: "^(那|那麼)?(那裡|那邊|這裡|這邊|那個|這個|它|他|她|牠|那間|那家)", options: .regularExpression) == nil })
        if context.language == .zh, EchoEngine.subjectless(message),
           let prev = topicTurn ?? lastUser ?? (history.count - prevQuestionTurn <= 4 ? prevQuestion : nil),
           let topic = EchoEngine.topicOf(prev, message: message, previousAnswer: history.last(where: { $0.role == .echo })?.text) {
            let generic = message.range(of: "^(那)?(要|可以|需要|該)?(帶|準備|買|穿|吃|喝|注意)(什麼|哪些)|^(那)?(要|該|應該)?(看|掛)(哪一科|哪科|什麼科)", options: .regularExpression) != nil
            if r.webQuery != nil || r.turn.source == .neural || (generic && r.turn.source == .knowledge && !r.turn.text.contains(topic)) {
                let combined = EchoEngine.combineFollowUp(topic: topic, previous: prev, message: message)
                let r2 = replyCore(to: combined, history: history, context: context, onToken: onToken)
                if r2.webQuery == nil, r2.turn.source != .neural, r2.turn.card == nil { return r2 }
                if r.webQuery != nil || r.turn.source == .neural {
                    r = r2
                    if r.webQuery != nil { r.webQuery = combined; lastWebQuery = combined; lastWebTurn = history.count; return r }
                }
            }
        }
        // 一大段自己的心事被拿去上網查（整段當關鍵字查不到東西）：改成陪伴和做法
        // 只換掉在說自己困擾的話；一長串在問事情的（「我想知道為什麼…」）照樣上網查
        if context.language == .zh, r.webQuery != nil, text.count > 30, text.contains("我"), EchoEngine.explicitSearch(text) == nil, !EchoEngine.explicitFortune(text),
           EchoEngine.distressStory(text),
           let lastClause = text.components(separatedBy: CharacterSet(charactersIn: "，,。！!？?；;、\n")).last(where: { $0.trimmingCharacters(in: .whitespaces).count >= 2 }),
           lastClause.range(of: "為什麼|是什麼|多少|幾[個點號歲公年月天次度]|哪裡|哪個|哪一|誰|什麼時候", options: .regularExpression) == nil {
            let a = EchoEngine.narrativeAdvice(text, now: context.now) ?? ("聽起來你心裡壓著好多事，謝謝你願意說出來。" + EchoEngine.copingSteps)
            r = Reply(turn: ChatTurn(role: .echo, text: a, source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            r.turn.variant = "talk"
            return r
        }
        // 換句話說的問題（「手機被人偷走了」「家裡好多蚊子」「告白被打槍了」）：本來要上網查、或只能回一句客套話的，
        // 先看看是不是自己知道的事換了個說法；在說心情的話（「最近壓力好大」）照樣陪他聊
        // 剛剛是用陪伴的話回心情（「我沒有朋友」「沒人理我」）：除非是身體不舒服、或明白在問方法，不要改成一張做法清單
        let moodReply = lastLocal?.kind == "mood" && lastLocal?.turn == history.count
        let asksMethod = text.range(of: "怎麼辦|建議|該怎麼|要怎麼|有什麼方法|有什麼辦法|怎麼做|怎麼處理|要注意|怎麼面對|如何面對|怎麼克服|怎麼走出|怎麼改善|怎麼調適|怎麼放下", options: .regularExpression) != nil
        if context.language == .zh, r.webQuery != nil || r.turn.source == .neural, (4...40).contains(text.count),
           EchoEngine.explicitSearch(text) == nil, !EchoEngine.explicitFortune(text), !Commonsense.talksFeelings(text),
           // 擔心別人：只有毛孩、小孩的症狀（「狗狗拉肚子」）直接給做法；家人住院、開刀這種大事先陪他聊
           !(moodChatBefore && !EchoEngine.isQuestion(text) && !asksMethod),
           !moodReply || Affect.detect(text) == .sick || asksMethod
             || (Affect.detect(text) == .worryOther && text.range(of: "狗|貓|寵物|毛孩|寶寶|小孩|孩子|兒子|女兒", options: .regularExpression) != nil
                 && text.range(of: "住院|開刀|手術|車禍|過世|急診|加護", options: .regularExpression) == nil),
           // 已經給了做法、或是閒聊本來就有好好接的話（「我在學吉他」→「學吉他很棒！學多久了？」）就不換
           !r.turn.text.contains("\n1. "),
           r.webQuery != nil || (Talk.chat(text) == nil && Talk.detailed(text) == nil),
           !(r.turn.source == .neural && !EchoEngine.isQuestion(text) && !asksMethod
             && text.range(of: "難過|傷心|壓力|焦慮|寂寞|孤單|想哭|好煩|很煩|崩潰|生氣|討厭|害怕|擔心|好累|很累|不開心|失落|心情|想死|自殺|沒有朋友|沒人理|身心俱疲|委屈|空虛|迷茫|沮喪", options: .regularExpression) != nil),
           let a = Fuzzy.answer(text, now: context.now) {
            let m = Fuzzy.match(text)
            let sub = m.map { m in Commonsense.howtos.contains(where: { $0.name == m.entity.name }) ? "" : (Commonsense.subject(m.alias) ?? "") } ?? ""
            lastLocal = LocalContext(kind: "fact", subject: sub, extra: m?.alias ?? text, answer: a, turn: history.count)
            // 帶著心情問方法（「工作壓力很大怎麼辦」）：先接住心情，再給方法
            let feeling = text.range(of: "壓力|好累|很累|難過|焦慮|好煩|很煩|害怕|擔心|委屈|崩潰|心情不好", options: .regularExpression) != nil
            let lead = feeling && !a.hasPrefix("辛苦") && !a.hasPrefix("你") && !a.hasPrefix("聽起來") ? "聽起來真的很辛苦，我陪你一起想辦法。\n" : ""
            r = Reply(turn: ChatTurn(role: .echo, text: lead + a, source: .knowledge), profile: nil, rules: nil, webQuery: nil)
            return r
        }
        // 沒有主語的問題不能當成「上一題的主題」
        if Understanding.missingSubject(text) == nil, !EchoEngine.isMetaFollowUp(message),
           r.webQuery != nil || (EchoEngine.isQuestion(text) && !EchoEngine.fortuneIntent(text) && r.turn.card == nil) {
            lastQuestion = text
            lastQuestionTurn = history.count
        }
        // 使用者給了網址：一定去讀那個網頁
        if let url = WebAgent.firstURL(message) {
            r.webQuery = url
            r.turn.palace = nil
            r.turn.text = "好，我去讀這個網頁…"
            r.turn.source = .tool
            return r
        }
        // 沒有主語的問題（「名字叫什麼」「多少錢」）：接上一題的主題；問的是個人資料就是在問我；都不是就先問清楚
        if r.webQuery != nil, let miss = Understanding.missingSubject(message) {
            if miss == .generic, let prev = prevQuestion, Understanding.missingSubject(prev) == nil, history.count - prevQuestionTurn <= 4 {
                let subject = Understanding.frame(prev).subject
                if !subject.isEmpty && subject != Understanding.plain(prev) || subject.count <= 8 {
                    var ask = Understanding.plain(message)
                    for w in ["那麼", "那"] where ask.hasPrefix(w) { ask.removeFirst(w.count); break }
                    r = replyCore(to: subject + ask, history: history, context: context, onToken: onToken)
                }
            } else if miss == .personal {
                var me = replyCore(to: "你" + Understanding.plain(message), history: history, context: context, onToken: onToken)
                if me.webQuery != nil || !me.turn.text.contains("NineSun") { me = replyCore(to: "你是誰", history: history, context: context, onToken: onToken) }
                me.turn.text = "你是問我嗎？" + me.turn.text
                me.webQuery = nil
                me.turn.palace = nil
                return me
            } else {
                r.webQuery = nil
                r.turn.palace = nil
                r.turn.text = "你想問的是誰、或是什麼東西的？告訴我名稱（例如「台北101多高」），我再幫你查。"
                return r
            }
        }
        // 問題太模糊（「它有多高」「那個是什麼」，前面也沒聊過相關的東西）：先問清楚，不要亂查
        if r.webQuery != nil, text == message, lastWebQuery == nil,
           ["它", "那個", "這個", "這些", "那些", "他們", "它們"].contains(where: { message.contains($0) }),
           Understanding.plain(message).count <= 8 {
            r.webQuery = nil
            r.turn.palace = nil
            r.turn.text = "你說的「\(["它", "那個", "這個", "這些", "那些", "他們", "它們"].first { message.contains($0) } ?? "這個")」是指什麼？告訴我名稱，我再幫你查。"
            return r
        }
        // 「那邊現在冷嗎」（前面聊到要去日本）：「那邊」換成最近提到的地方再查
        if let q = r.webQuery, let m = text.range(of: "^(那邊|那裡|當地)", options: .regularExpression) {
            let places = Commonsense.facts.filter { ["國家", "城市", "地標"].contains($0.kind) }
            for u in history.filter({ $0.role == .user }).suffix(4).map(\.text).reversed() {
                if let p = places.first(where: { e in e.names.contains { $0.count >= 2 && u.contains($0) } }) {
                    r.webQuery = p.name + " " + String(text[m.upperBound...])
                    lastWebQuery = r.webQuery
                    lastWebTurn = history.count
                    r.turn.palace = nil
                    return r
                }
            }
            _ = q
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

    /// 口語的問句詞換成一般說法：「日本首都是啥」「蝦米是黑洞」「咋辦」
    static func unwrapPoliteFollowUp(_ m: String) -> String {
        guard let g = RuleBook.match(m.trimmingCharacters(in: .whitespacesAndNewlines), #"^(?:你|妳)?(?:可以|能|能不能|可不可以|麻煩|麻煩你|請|請你)(?:你)?(再說一次|再講一次|再說一遍|再講一遍|說簡單一點|講簡單一點|說詳細一點|講詳細一點|說清楚一點|講清楚一點|說慢一點|講慢一點|舉個例子|舉一個例子|白話一點)(?:嗎|好嗎|呢|吧)?[？?]*$"#) else { return m }
        return g[0].replacingOccurrences(of: "慢一點", with: "簡單一點")
    }

    static func normalizeSlang(_ m: String) -> String {
        var m = m
        // 「如果講不好怎麼辦」「萬一地震怎麼辦」→「講不好怎麼辦」
        if let r = m.range(of: #"^(如果|萬一|要是|假如)(?=.{2,14}(怎麼辦|該怎麼辦|要怎麼辦)[？?]*$)"#, options: .regularExpression) { m.removeSubrange(r) }
        // 「富士山在那裡」「首都是那裡」：打錯的「哪裡」（「我在那裡」是在說自己，不算）
        if m.range(of: "^(我|你|他|她|我們|你們|他們)", options: .regularExpression) == nil,
           let r = m.range(of: #"(?<=是|在|位於|住在|去)那裡(?=(呢|啊)?[？?]*$)"#, options: .regularExpression) {
            m.replaceSubrange(r, with: "哪裡")
        }
        // 打招呼、口氣詞後面接問題（「早安，今天幾號」「你好，請問貓可以吃巧克力嗎」「嘿嘿 日本的首都是哪裡」「喂喂 貓可以吃巧克力嗎」「好 那月亮離地球多遠」）：只看問題
        for _ in 0..<3 {
            guard let r = m.range(of: #"^((早安|午安|晚安|你好|您好|哈囉|嗨+|嘿+|hi|Hi|hello|Hello|安安|早|欸+|誒+|喂+|嗯+|喔+|哦+|噢+|吼+|齁+|好|好啦|好喔|好的|OK|ok)[，,！!～~。 …]+|(嘿|欸|誒|喂|嗯|喔|哦|哈|嗨|吼|齁){2,}[，,！!～~。 …]*)"#, options: .regularExpression),
                  r.upperBound < m.endIndex else { break }
            let rest = String(m[r.upperBound...])
            // 「晚安!？」「哈囉!？」：後面只剩標點，就還是在打招呼
            guard rest.filter({ $0.isLetter || $0.isNumber }).count >= 2 else { break }
            guard EchoEngine.isQuestion(rest) || rest.hasPrefix("請問") || rest.range(of: #"^(我問你|問你|想請教|請教|那個)"#, options: .regularExpression) != nil else { break }
            m = rest
        }
        // 「你知不知道日本首都在哪」「你曉不曉得…」→ 直接是那個問題
        if let g = RuleBook.match(m, #"^(?:你|妳)?(?:知不知道|知道不知道|曉不曉得|曉得)(.{2,30}?)(?:嗎|呢)?[？?]*$"#), EchoEngine.isQuestion(g[0]) || g[0].range(of: "在哪|是哪|多少|幾|誰|什麼", options: .regularExpression) != nil {
            m = g[0]
        }
        // 「花蓮好玩嗎」「九份值得去嗎」：自己有那個地方的景點清單，就當成問有什麼好玩的
        if let g = RuleBook.match(m, #"^(.{2,6}?)(?:好玩嗎|好不好玩|好玩不好玩|值得去嗎|值不值得去)[？?]*$"#) {
            let q = g[0] + "有什麼好玩的"
            if Library.detailed(q) != nil || Commonsense.answer(q) != nil { m = q }
        }
        // 「再寫一首春天的」「那來一首關於海的」：接著要一首那個主題的詩
        m = m.replacingOccurrences(of: #"^(?:那|可以|好|那可以)?(?:再|幫我再|再幫我|也)?(?:寫|來|作)(?:一首|首)(?:關於)?(.{1,6}?)的(?:詩)?(?:吧|嗎|好嗎|呢)?(?=[？?！!。]*$)"#, with: "寫一首關於$1的詩", options: .regularExpression)
        // 「跟我說說你自己」「說說你的故事」「自我介紹一下」＝你是誰；「我想了解我自己」＝我的個性
        m = m.replacingOccurrences(of: #"^((可以|能不能)?(跟我|和我)?(說說|講講|聊聊|介紹|介紹一下)(一下)?(你自己|你|妳自己|你的故事|妳的故事)|說說你的故事|講講你的故事|自我介紹(一下)?)(吧|嗎|好嗎|好不好)?(?=[？?！!]*$)"#, with: "你是誰", options: .regularExpression)
        m = m.replacingOccurrences(of: #"^我(想|很想|想要)(多)?(了解|認識|知道)(一下)?(我自己|自己)(多一點)?(?=[？?！!]*$)"#, with: "我的個性是怎樣", options: .regularExpression)
        // 「他是射手座」「我男朋友是天蠍座的」：說了對方的星座 → 看我們兩個星座合不合
        m = m.replacingOccurrences(of: #"^(他|她|對方|我男友|我女友|我男朋友|我女朋友|我老公|我老婆|男友|女友|男朋友|女朋友|我喜歡的人|我暗戀的人)(是|是個)([\p{Han}]{2}座)(的)?(喔|耶|啦)?(?=[？?！!。]*$)"#, with: "我跟$3合嗎", options: .regularExpression)
        // 「好吧我去吃泡麵了」「那我去吃飯囉」：開頭的口氣詞不影響
        m = m.replacingOccurrences(of: #"^(好吧|好啦|好喔|好|那|那我|嗯)[，, ]*(?=我?(要|先|準備)?去(吃|睡|洗澡))"#, with: "", options: .regularExpression)
        // 「我是什麼樣的人」＝我的個性；「我的貴人是誰」＝貴人運
        m = m.replacingOccurrences(of: #"^我(到底)?是(一個)?(什麼樣|怎樣|怎麼樣)的人(呢|啊)?(?=[？?]*$)"#, with: "我的個性是怎樣", options: .regularExpression)
        m = m.replacingOccurrences(of: #"^(我的貴人是誰|誰是我的貴人|我的貴人在哪裡?|我會遇到貴人嗎|我的貴人什麼時候(會)?出現|我有沒有貴人)(呢|啊)?(?=[？?]*$)"#, with: "我的貴人運怎麼樣", options: .regularExpression)
        // 「跟我說說黑洞」「我想了解通膨」「介紹一下光年」：認得的東西就當成問它是什麼
        if let g = RuleBook.match(m, #"^(?:可以|能不能|請|你可以)?(?:跟我|和我|幫我|為我)?(?:說說|講講|聊聊|介紹|說明|解釋|科普)(?:一下)?(?:看)?(.{2,10}?)(?:吧|嗎|好嗎|好不好|給我聽)?[？?！!]*$|^我(?:想|想要|很想)(?:了解|知道|認識|多了解|多知道)(?:一下)?(.{2,10}?)(?:是什麼)?[？?！!]*$"#) {
            let x = g[0].isEmpty ? g[1] : g[0]
            if !x.contains("你"), !x.hasPrefix("我"), Commonsense.facts.contains(where: { $0.kind != "推薦" && $0.names.contains(x) }),
               Commonsense.answer(x + "是什麼") != nil { m = x + "是什麼" }
        }
        // 「台北 好玩」「日本 美食」：兩個關鍵字＝那個地方有什麼好玩的、好吃的
        if let g = RuleBook.match(m, #"^(.{2,6}?)\s+(好玩|景點|旅遊|玩什麼|去哪玩)[？?]*$"#) {
            let q = g[0] + "有什麼好玩的"
            if Library.detailed(q) != nil || Commonsense.answer(q) != nil { m = q }
        } else if let g = RuleBook.match(m, #"^(.{2,6}?)\s+(美食|好吃|小吃|吃什麼)[？?]*$"#) {
            let q = g[0] + "有什麼好吃的"
            if Library.detailed(q) != nil || Commonsense.answer(q) != nil { m = q }
        }
        // 「玉山的海拔」「長江 長度」：東西＋屬性，沒有問句也是在問那個數字
        if let g = RuleBook.match(m, #"^(.{1,8}?)(?:的|\s+)(高度|海拔|面積|人口|首都|語言|貨幣|年齡|長度|重量|溫度|速度|距離|壽命|位置|由來|好處|壞處|特色)[？?]*$"#),
           Commonsense.facts.contains(where: { $0.names.contains(g[0]) }) {
            let ask = ["高度", "海拔"].contains(g[1]) ? g[0] + "有多高" : ["首都", "語言", "貨幣", "位置", "由來", "好處", "壞處", "特色"].contains(g[1]) ? g[0] + "的" + g[1] + "是什麼" : g[0] + "的" + g[1] + "是多少"
            if Commonsense.answer(ask) != nil { m = ask }
        }
        // 「什麼叫做區塊鏈」「什麼叫通膨」＝什麼是
        m = m.replacingOccurrences(of: "^什麼叫(做)?", with: "什麼是", options: .regularExpression)
        // 「人口最多的國家是」：話沒說完的「是」＝是什麼
        if m.range(of: #"最.{1,10}是[？?]*$"#, options: .regularExpression) != nil, let r = m.range(of: #"是[？?]*$"#, options: .regularExpression) {
            m.replaceSubrange(r, with: "是什麼")
        }
        // 開場白（「我問你喔，」「問你一個問題：」「想請教一下」「跟你說喔」「對了，」）不是問題的一部分
        m = m.replacingOccurrences(of: #"^(我問你喔|我問你哦|我問你|問你一個問題|問你個問題|問你一件事|想請教一下|想請教|請教一下|跟你說喔|跟你說|對了|話說|老實說|順便問一下|順便問|那個…|那個\.\.\.)[，,：:、 …!！]*(?=.{2,})"#, with: "", options: .regularExpression)
        // 「可以告訴我牙齒痛怎麼辦嗎」→「牙齒痛怎麼辦」
        if let g = RuleBook.match(m, #"^(?:可以|能不能|能|可不可以|你可以|你能)(?:告訴我|跟我說|說說|講講|教我)(.{3,30}?)(?:嗎)?[？?]*$"#),
           EchoEngine.isQuestion(g[0]) { m = g[0] }
        // 問題後面的「XD」「哈哈」「😂」只是語氣
        if let r = m.range(of: #"\s*(哈哈+|呵呵+|XD+|xd+|Xd+|😂+|🤣+|😆+|lol|LOL|www+)\s*$"#, options: .regularExpression), EchoEngine.isQuestion(String(m[..<r.lowerBound])) {
            m.removeSubrange(r)
        }
        // 「番茄炒蛋怎樣做」「怎樣存錢」→「怎麼」（句尾的「怎樣」、「怎樣的人」不換）
        m = m.replacingOccurrences(of: #"怎樣(?=[^\s的？?。！!，,呢啊])"#, with: "怎麼", options: .regularExpression)
        // 注音打錯的字：「富士山再哪裡」→ 在哪裡；句尾當問號用的「麼」→ 嗎；「白飯煮法」→ 白飯怎麼煮
        m = m.replacingOccurrences(of: "再哪", with: "在哪")
        m = m.replacingOccurrences(of: #"(?<![什怎那這多要甚])麼(?=[？?]*$)"#, with: "嗎", options: .regularExpression)
        // 常見的打錯字：「我以經吃飽了」「明天因該會下雨嗎」「在見」「台北101在那」；注音當語助詞：「可以ㄇ」「好ㄉ」
        m = m.replacingOccurrences(of: #"以經(?![濟驗典營歷])"#, with: "已經", options: .regularExpression)
        m = m.replacingOccurrences(of: #"(?<![原起病基成主誘死近遠前])因該"#, with: "應該", options: .regularExpression)
        m = m.replacingOccurrences(of: #"^((?:那|好|好啦|就這樣|掰掰)?[，, ]*)在見(?=(囉|啦|喔|了)?[!！~～。]*$)"#, with: "$1再見", options: .regularExpression)
        if m.range(of: "^(我|你|他|她|我們|你們|他們)", options: .regularExpression) == nil {
            m = m.replacingOccurrences(of: #"(?<=是|在|位於|住在)那(?=(呢|啊)?[？?]*$)"#, with: "哪", options: .regularExpression)
        }
        m = m.replacingOccurrences(of: #"ㄇ(?=[？?！!～~]*$)"#, with: "嗎", options: .regularExpression)
        m = m.replacingOccurrences(of: #"ㄅ(?=[？?！!～~]*$)"#, with: "吧", options: .regularExpression)
        m = m.replacingOccurrences(of: #"ㄋ(?=[？?！!～~]*$)"#, with: "呢", options: .regularExpression)
        m = m.replacingOccurrences(of: "ㄉ", with: "的")
        // 注音選錯的同音字（只在這個字前後的固定組合裡改，正確的「前途」「通順」「那裡很遠」不會被改到）
        for (p, r) in [(#"(存|賺|花|省|借|還|找|領|付|變有|沒有|多少|有沒有)前(?![途科景面後方進任輩提言線])"#, "$1錢"),
                       (#"中讀(?=了|怎麼|要|嗎|$)"#, "中毒"),
                       (#"抄(?=蛋|飯|麵|菜|米粉|高麗菜|青菜|肉)"#, "炒"),
                       (#"(頭|肚子|牙齒|牙|胃|腳|手|腰|背|喉嚨|眼睛|耳朵|肩膀|膝蓋)(很|好|超|一直|有點)?通(?![順暢過知勤訊常話車])"#, "$1$2痛"),
                       (#"有多搞(?=[？?]*$)"#, "有多高"), (#"多搞(?=[？?]*$)"#, "多高"),
                       (#"的?手都(?=是|在)"#, "的首都"),
                       ("區快鏈", "區塊鏈"), ("吉它", "吉他"),
                       (#"(?<=\p{Han})歐(?=[！!～~。]*$)"#, "喔"), (#"(?<=謝謝|愛|想|喜歡)泥(?=[！!～~。]*$)"#, "你"),
                       (#"^(早|晚)ㄢ(?=[！!～~。]*$)"#, "$1安"), (#"\s*ㄏㄏ+$"#, ""),
                       (#"(?<=可以|能|請|麻煩)在(?=說一次|講一次|說一遍|講一遍|來一次|試一次)"#, "再"), (#"^(我)?在也(?=不)"#, "$1再也"),
                       (#"^那裡(?=有|可以|能|買|找|好玩|好吃)"#, "哪裡")] {
            m = m.replacingOccurrences(of: p, with: r, options: .regularExpression)
        }
        // 「什摸是區塊鏈」「手機沒電了怎摸辦」「信用卡被盜用怎麼半」：注音選錯字
        // 「手機好lag」：英文的 lag＝卡
        m = m.replacingOccurrences(of: #"(?i)(?<![A-Za-z])lag(?![A-Za-z])"#, with: "卡", options: .regularExpression)
        m = m.replacingOccurrences(of: "什摸", with: "什麼").replacingOccurrences(of: "甚摸", with: "什麼").replacingOccurrences(of: "怎摸", with: "怎麼")
        m = m.replacingOccurrences(of: #"怎麼(半|伴|扮|拌|瓣)(?=[？?！!。～~]*$)"#, with: "怎麼辦", options: .regularExpression)
        // 「頭好痛喔怎麼辦」「好累啊怎麼辦」：中間的語氣詞
        m = m.replacingOccurrences(of: #"(?<=\p{Han})(喔|噢|啊|耶|捏|欸|ㄛ)(?=(要)?怎麼辦|該怎麼辦|怎麼|嗎[？?]*$)"#, with: "", options: .regularExpression)
        if let g = RuleBook.match(m, #"^(.{1,8}?)(?:的)?(煮法|炒法|烤法|滷法)[？?]*$"#) { m = g[0] + "怎麼" + String(g[1].prefix(1)) }
        // 「可以吃巧克力嗎呢」：多打的語氣詞
        m = m.replacingOccurrences(of: #"嗎呢(?=[？?！!。～~]*$)"#, with: "嗎", options: .regularExpression)
        // 「長頸鹿要如何睡覺」「該如何存錢」→「怎麼」（句尾的「運勢如何」不換）
        m = m.replacingOccurrences(of: #"(要|該|應該)?如何(?!是好)(?=\p{Han})"#, with: "怎麼", options: .regularExpression)
        guard m.range(of: "啥|蝦米|三小|咋|甚麼|神馬|什么|到底|怎麼樣才能|怎樣才能|要怎麼樣|是什麼東西", options: .regularExpression) != nil else { return m }
        var t = m
        for (a, b) in [("到底", ""), ("要怎麼樣才能", "要怎麼"), ("怎麼樣才能", "怎麼"), ("怎樣才能", "怎麼"), ("要怎麼樣", "要怎麼"), ("是什麼東西", "是什麼"),("蝦米", "什麼"), ("三小", "什麼"), ("神馬", "什麼"), ("甚麼", "什麼"), ("什么", "什麼"), ("咋辦", "怎麼辦"), ("咋麼", "怎麼"), ("咋", "怎麼"), ("為啥", "為什麼"), ("幹啥", "做什麼"), ("啥", "什麼")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return t
    }

    /// 問 NineSun 自己的年紀、生日    /// 問 NineSun 自己的年紀、生日
    static func aboutMe(_ raw: String, now: Date) -> String? {
        let t = Everyday.clean(raw)
        let age = ["你幾歲", "你今年幾歲", "你多大", "你多大了", "你幾歲了", "你的年紀", "你年紀多大", "你多老", "妳幾歲", "妳多大"]
        let bday = ["你的生日是幾號", "你生日是哪天", "你什麼時候生日", "你的生日是什麼時候", "你生日幾號", "你是什麼時候出生的", "你哪天生日"]
        guard age.contains(where: { t.hasPrefix($0) }) || bday.contains(where: { t.hasPrefix($0) }) else { return nil }
        let b = PalaceCore.selfBirth
        guard let born = Everyday.make(b.year, b.month, b.day) else { return nil }
        let days = max(0, Everyday.daysBetween(born, now))
        let old = days < 60 ? "今天是我開機的第 \(days + 1) 天" : days < 730 ? "大約 \(days / 30) 個月大" : "\(days / 365) 歲"
        return "我的生日是 \(b.year) 年 \(b.month) 月 \(b.day) 日——那天是我開始運作、算出自己命盤的日子。照這樣算，我\(old)。以 AI 來說還是個小朋友，每天都在學新東西。"
    }

    static let anaphora = ["這些", "那些", "這個", "那個", "它們", "他們", "牠們", "其中", "剛剛說的", "剛才說的", "上面說的"]
    /// 查詢時自己加上去的詞（不是使用者在問的主題）
    static let searchHelpers: Set<String> = ["列表", "數量", "做法", "步驟", "原因", "影響", "比較", "注意事項", "優缺點", "差別", "名單"]

    /// 追問換成完整的問題：「那這些國家都是哪些國家」（上一題「歐洲有多少個國家」）→「歐洲國家都是哪些國家」
    static func substituteAnaphor(_ text: String, previous prev: String) -> String? {
        let t0 = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 「這個月」「那個時候」是時間，不是在指上一題；要算運勢的也不接
        let timeWords = ["這個月", "那個月", "這個禮拜", "這個星期", "這個時候", "那個時候", "這個年", "這個週末", "那些年", "那些日子"]
        if timeWords.contains(where: { t0.contains($0) }) || fortuneIntent(t0) { return nil }
        var t = t0
        for w in ["我是說", "我的意思是", "我是問", "那麼", "那"] where t.hasPrefix(w) { t.removeFirst(w.count); break }
        // 句子開頭的「他／她／它」（「他幾歲」「她演過什麼」）也是在指上一題的主題；「其他」「吉他」不算，因為不在開頭
        let pronoun = anaphora.first(where: { t0.contains($0) }) == nil
            && ["他", "她", "它", "牠"].contains(where: { t.hasPrefix($0) }) && !t.hasPrefix("他人") && isQuestion(t0)
        guard let a = anaphora.first(where: { t0.contains($0) }) ?? (pronoun ? String(t.prefix(1)) : nil) else { return nil }
        // 「他／她／它」指的是上一題在問的那個人或東西（「李白是誰」→ 李白）
        let subject = pronoun ? Understanding.frame(prev).subject.filter { $0.isLetter || $0.isNumber } : ""
        let topic = WebAgent.coreTopic(prev).replacingOccurrences(of: "個", with: "")
        let main = subject.count >= 2 ? [subject]
            : topic.split(separator: " ").map { String($0.filter { $0.isLetter || $0.isNumber }) }.filter { $0.count >= 2 && !searchHelpers.contains($0) }
        guard !main.isEmpty else { return nil }
        let missing = main.filter { !t0.contains($0) }
        // 跟上一題有共同的詞（「這些國家」的國家），或是很短的追問（「那些是哪些」「他幾歲」），才當成在指上一題
        guard missing.count < main.count || t0.count <= 6 || pronoun else { return nil }
        if let r = t.range(of: a) { t.replaceSubrange(r, with: missing.joined()) }
        return t.isEmpty ? nil : t
    }

    /// 追問：「那這些國家都是哪些國家」→「歐洲 國家 哪些國家 列表」
    static func resolveFollowUp(_ text: String, query q: String, previous: String?, gap: Int) -> String {
        // 沒說主詞的追問（「小孩可以用嗎」「多少錢」「哪裡買」）：接著上一題查的東西問（「防蚊液要用哪一種」→ 防蚊液 小孩可以用嗎）
        if let prev = previous, gap <= 2 {
            let t = Talk.clean(text).replacingOccurrences(of: #"^(那麼|那|所以|還有|那如果)"#, with: "", options: .regularExpression)
            let implicitAsk = t.count <= 10 && (
                t.range(of: #"^(小孩|小朋友|大人|孕婦|老人|長輩|寶寶|嬰兒|狗|貓|狗狗|貓咪)?(也)?(可以|能|要|會|該|適合)(用|吃|喝|買|擦|噴|帶|戴|穿|洗|泡|搭|開|去|做)?(嗎|呢)?$"#, options: .regularExpression) != nil
                || t.range(of: #"^(大概)?(多少錢|貴嗎|貴不貴|有效嗎|安全嗎|好用嗎|有用嗎|哪裡買|去哪買|在哪買|怎麼買|怎麼用|哪裡有賣|有副作用嗎|副作用呢|要多久|多久|價格|價錢|要錢嗎|免費嗎)(呢|啊)?$"#, options: .regularExpression) != nil)
            if implicitAsk {
                // 上一題的主題：問句詞前面那一段名詞（「防蚊液要用哪一種」→ 防蚊液、「日本首相是誰」→ 日本首相）
                let p = prev.trimmingCharacters(in: .whitespaces)
                let topic = String(p.prefix { !"要該可能會怎如哪什多幾是嗎呢的在有".contains($0) }).trimmingCharacters(in: .whitespaces)
                if topic.count >= 2, !text.contains(topic) { return topic + " " + Talk.clean(text) }
            }
        }
        var cur = q
        // 「那些年，我們一起追的女孩」是片名，不是在指上一題
        let refers = anaphora.contains { text.contains($0) } && !text.contains("那些年") && !text.contains("那些日子")
        if refers {
            for w in anaphora + ["我是說", "我的意思是", "都是", "那"] { cur = cur.replacingOccurrences(of: w, with: " ") }
        }
        var tokens = cur.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if refers, let prev = previous, gap <= 8 {
            let topic = WebAgent.coreTopic(prev).replacingOccurrences(of: "個", with: "")
            // 上一次查詢自己加的「列表」「做法」這類詞不是主題（不然會變成「列表 歐洲國家…」）
            let main = topic.split(separator: " ").map(String.init).filter { $0.count >= 2 && !searchHelpers.contains($0) }
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
        let text = EchoEngine.tidy(message)
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

        // 0.5) 叫 NineSun 罵自己、罵人、說髒話：有自信地拒絕（小模型常會照做）
        if L == .zh, let no = ctx.allowSwearing ? Composure.beyondLine(text) : Composure.decline(text, seed: text.count) {
            var r = Reply(turn: ChatTurn(role: .echo, text: no, source: .tool), profile: nil, rules: nil, webQuery: nil)
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
        // 2.0004) 成語：「給我一個四字成語」「成語接龍」
        if L == .zh {
            let tt = text.filter { !"？?。！!，, ".contains($0) }
            if tt.range(of: #"^(給我|說|講|來|教我|告訴我)?(一個|個|幾個)?(四字)?成語(吧)?$"#, options: .regularExpression) != nil, tt != "成語",
               let e = Idioms.random(seed: Calendar.current.component(.minute, from: ctx.now) &+ history.count &* 7) {
                return done("「\(e.idiom)」：\(e.meaning)。" + (e.en.first.map { "\n英文可以說：\($0)" } ?? "") + "\n想要形容某種情況的成語，可以問我「形容很努力的成語」。", .knowledge)
            }
            // 小遊戲：猜數字（終極密碼）、猜拳——要記得進行到哪裡
            if tt.range(of: #"^(來|我們來|陪我|跟我|一起|我想)?(玩)?(猜數字|猜數字遊戲|終極密碼)(吧|好不好|好嗎|嗎)?$"#, options: .regularExpression) != nil {
                let n = Int.random(in: 1...100)
                lastLocal = LocalContext(kind: "猜數字", subject: "\(n)", extra: "1,100", shown: "0", turn: history.count)
                return done("好啊！我想好一個 1 到 100 之間的數字了，猜猜看是多少？（想結束就說「不玩了」）", .knowledge)
            }
            if tt.range(of: #"^(來|我們來|陪我|跟我|一起|我想)?(玩)?(猜拳|剪刀石頭布)(吧|好不好|好嗎|嗎)?$"#, options: .regularExpression) != nil {
                lastLocal = LocalContext(kind: "猜拳", turn: history.count)
                return done("好啊！剪刀、石頭、布——你先出！（說「剪刀」「石頭」或「布」）", .knowledge)
            }
            if tt.range(of: #"^(來|我們來|陪我|跟我|一起|我想)?(玩)?(成語接龍|文字接龍|接龍)(吧|好不好|好嗎|嗎)?$"#, options: .regularExpression) != nil, let e = Idioms.random(seed: history.count &+ 3) {
                lastLocal = LocalContext(kind: "接龍", subject: e.idiom, extra: e.idiom, turn: history.count)
                return done("好啊！我們來玩成語接龍，我先：「\(e.idiom)」（\(e.meaning)）。\n換你接一個「\(e.idiom.last!)」開頭的成語！（想結束就說「不玩了」）", .knowledge)
            }
        }
        // 2.0005) 記得使用者教過的事（「你記得我叫什麼嗎」「我喜歡什麼顏色」）
        if L == .zh, let a = ctx.rules.recall(text) { return done(a, .rule) }
        // 2.0006) 「我是什麼星座」「我屬什麼」：用存好的生日算
        if L == .zh, let g = RuleBook.match(text.filter { !"？?。！!，, ".contains($0) }, #"^(?:那|那麼)?我(?:是)?(?:什麼|哪個)(星座|生肖)(?:呢|啊)?$|^(?:那|那麼)?我屬什麼(?:生肖)?(?:呢|啊)?$"#) {
            guard let b = ctx.profile.birthday else { return done("告訴我你的生日（例如「我的生日是2000年1月1日」），我就能告訴你是什麼星座、屬什麼。", .tool) }
            let signs: [(Int, Int, String)] = [(1, 20, "摩羯座"), (2, 19, "水瓶座"), (3, 21, "雙魚座"), (4, 20, "牡羊座"), (5, 21, "金牛座"), (6, 22, "雙子座"),
                                               (7, 23, "巨蟹座"), (8, 23, "獅子座"), (9, 23, "巨蟹座"), (10, 24, "天秤座"), (11, 23, "天蠍座"), (12, 22, "射手座")]
            // 每個月在分界日之前是前一個星座
            let order = ["摩羯座", "水瓶座", "雙魚座", "牡羊座", "金牛座", "雙子座", "巨蟹座", "獅子座", "處女座", "天秤座", "天蠍座", "射手座"]
            let cut = signs[b.month - 1].1
            let sign = b.day >= cut ? order[b.month % 12] : order[(b.month - 1) % 12]
            let lunarYear = LunarCalendar.shared.lunar(b.year, b.month, b.day).year
            let animals = ["鼠", "牛", "虎", "兔", "龍", "蛇", "馬", "羊", "猴", "雞", "狗", "豬"]
            let animal = animals[((lunarYear - 4) % 12 + 12) % 12]
            return done("你的生日是 \(b.year) 年 \(b.month) 月 \(b.day) 日：太陽星座是\(sign)，生肖屬\(animal)（以農曆過年為界）。想看更完整的命盤，可以問我「我的命盤」。", .tool)
        }

        // 2.00065) 「我的星座」「我幾歲」「我的生日是哪天」：用存好的生日回答
        let bare = text.filter { !"？?。！!，, ".contains($0) }
        let asksSign = bare.range(of: #"^(?:那|那麼)?我的(?:星座|生肖)(?:是什麼|是哪個|是)?(?:呢|啊)?$|^(?:那|那麼)?我是什麼星的(?:呢|啊)?$"#, options: .regularExpression) != nil
        let asksAge = bare.range(of: #"^(?:那|那麼)?我(?:今年|現在|目前)?(?:幾歲|多大|多少歲)(?:了)?(?:呢|啊)?$"#, options: .regularExpression) != nil
        let asksBirthday = bare.range(of: #"^(?:那|那麼)?(?:我的生日(?:是)?(?:哪天|哪一天|幾號|幾月幾號|什麼時候)|我(?:是)?(?:什麼時候|哪天|哪一天|幾月幾號)(?:生日|出生的?|生的))(?:呢|啊)?$"#, options: .regularExpression) != nil
        if L == .zh, asksSign || asksAge || asksBirthday {
            guard let b = ctx.profile.birthday else { return done("我還不知道你的生日。告訴我（例如「我的生日是2000年1月1日」），我就能幫你算星座、生肖和年紀，也能排命盤。", .tool) }
            let cal = Calendar(identifier: .gregorian)
            let now = cal.dateComponents([.year, .month, .day], from: ctx.now)
            let ny = now.year ?? b.year, nm = now.month ?? 1, nd = now.day ?? 1
            let cuts = [20, 19, 21, 20, 21, 22, 23, 23, 23, 24, 23, 22]
            let order = ["摩羯座", "水瓶座", "雙魚座", "牡羊座", "金牛座", "雙子座", "巨蟹座", "獅子座", "處女座", "天秤座", "天蠍座", "射手座"]
            let sign = b.day >= cuts[b.month - 1] ? order[b.month % 12] : order[b.month - 1]
            let lunarYear = LunarCalendar.shared.lunar(b.year, b.month, b.day).year
            let animal = ["鼠", "牛", "虎", "兔", "龍", "蛇", "馬", "羊", "猴", "雞", "狗", "豬"][((lunarYear - 4) % 12 + 12) % 12]
            let passed = (nm, nd) >= (b.month, b.day)
            let age = ny - b.year - (passed ? 0 : 1)
            var next = cal.date(from: DateComponents(year: passed ? ny + 1 : ny, month: b.month, day: b.day)) ?? ctx.now
            if nm == b.month && nd == b.day { next = ctx.now }
            let today = cal.date(from: DateComponents(year: ny, month: nm, day: nd)) ?? ctx.now
            let left = cal.dateComponents([.day], from: today, to: next).day ?? 0
            let soon = left == 0 ? "今天就是你的生日，生日快樂！🎂" : "離下次生日還有 \(left) 天。"
            if asksAge { return done("你是 \(b.year) 年 \(b.month) 月 \(b.day) 日生的，現在 \(age) 歲（足歲）。" + soon, .tool) }
            if asksBirthday { return done("你的生日是 \(b.year) 年 \(b.month) 月 \(b.day) 日（\(sign)，屬\(animal)）。" + soon, .tool) }
            return done("你的生日是 \(b.year) 年 \(b.month) 月 \(b.day) 日：太陽星座是\(sign)，生肖屬\(animal)（以農曆過年為界）。想看更完整的命盤，可以問我「我的命盤」。", .tool)
        }
        // 2.00066) 「摩羯座和射手座合嗎」「我跟射手座合不合」：用四大元素看個性合不合（只當參考）
        if L == .zh, let g = RuleBook.match(bare, #"^(?:那|那麼)?(我|[\p{Han}]{2}座)(?:和|跟|與)([\p{Han}]{2}座)(?:的人)?(?:合嗎|合不合|速配嗎|配嗎|相配嗎|適合嗎|合得來嗎|的配對|配對|配不配|適不適合|會合嗎)(?:呢|啊)?$"#) {
            let order = ["摩羯座", "水瓶座", "雙魚座", "牡羊座", "金牛座", "雙子座", "巨蟹座", "獅子座", "處女座", "天秤座", "天蠍座", "射手座"]
            let element: [String: String] = ["牡羊座": "火", "獅子座": "火", "射手座": "火", "金牛座": "土", "處女座": "土", "摩羯座": "土",
                                             "雙子座": "風", "天秤座": "風", "水瓶座": "風", "巨蟹座": "水", "天蠍座": "水", "雙魚座": "水"]
            var a = g[0]
            if a == "我" {
                guard let b = ctx.profile.birthday else { return done("我還不知道你的生日，不知道你是什麼星座。告訴我（例如「我的生日是2000年1月1日」），我再幫你看合不合。", .tool) }
                let cuts = [20, 19, 21, 20, 21, 22, 23, 23, 23, 24, 23, 22]
                a = b.day >= cuts[b.month - 1] ? order[b.month % 12] : order[b.month - 1]
            }
            let bSign = g[1]
            if let ea = element[a], let eb = element[bSign] {
                let pair = Set([ea, eb])
                let verdict: String
                if ea == eb { verdict = "都是\(ea)象星座，個性和步調很像，很容易懂對方；要小心缺點也一樣，兩個人一起固執或一起情緒化。" }
                else if pair == ["火", "風"] { verdict = "火象和風象互相助長：風讓火燒得更旺，一個有行動力、一個有想法，在一起很有活力，聊得來。" }
                else if pair == ["土", "水"] { verdict = "土象和水象互相滋養：一個給安全感、一個給溫柔，關係穩定又貼心。" }
                else if pair == ["火", "水"] { verdict = "火象和水象個性差很多：一個直接衝動、一個細膩敏感，容易誤會，但互相學習的話，一個能帶來熱情，一個能帶來體貼。" }
                else if pair == ["土", "風"] { verdict = "土象和風象步調不太一樣：一個務實穩重、一個自由多變，要多溝通、尊重彼此的節奏。" }
                else if pair == ["火", "土"] { verdict = "火象和土象一個想衝、一個想穩，常常意見不同；如果能互補，一個帶動、一個踩煞車，反而是好搭檔。" }
                else { verdict = "風象和水象一個重理性、一個重感受，需要多一點耐心理解對方的表達方式。" }
                let who = g[0] == "我" ? "你是\(a)，" : ""
                return done(who + "\(a)（\(ea)象）和\(bSign)（\(eb)象）：" + verdict + "\n\n星座配對可以當作聊天和認識個性的參考，兩個人合不合，最後還是看相處和溝通。想看更準的，可以用兩個人的生日問我「合盤」。", .knowledge)
            }
        }
        // 2.0007) 只有月日的生日（「我的生日是5月20日」）：先告訴他星座，要排命盤再補年份
        if L == .zh, let g = RuleBook.match(text.filter { !"？?。！!，, ".contains($0) }, #"^(?:我的?)?生日是?(\d{1,2})月(\d{1,2})[日號]?$"#),
           let m = Int(g[0]), let d = Int(g[1]), (1...12).contains(m), (1...31).contains(d) {
            let cuts = [20, 19, 21, 20, 21, 22, 23, 23, 23, 24, 23, 22]
            let order = ["摩羯座", "水瓶座", "雙魚座", "牡羊座", "金牛座", "雙子座", "巨蟹座", "獅子座", "處女座", "天秤座", "天蠍座", "射手座"]
            let sign = d >= cuts[m - 1] ? order[m % 12] : order[m - 1]
            return done("\(m) 月 \(d) 日生日，太陽星座是\(sign)！🎂 如果再告訴我出生的年份（例如「我的生日是2000年\(m)月\(d)日」），我就能幫你看生肖、排命盤和運勢。", .tool)
        }
        // 2.0008) 小遊戲：擲骰子、丟硬幣、猜拳、隨便一個數字、幫我在兩個裡面選一個
        if L == .zh, let a = EchoEngine.playful(text.filter { !"？?。！!".contains($0) }) { return done(a, .tool) }

        // 2.001) 有標準答案、用算的就知道的（某年生肖、干支、日期加減、地支沖合、按比例分、面積、利息、原子序）：引擎直接算
        if L == .zh, let a = QuickCalc.answer(text) { return done(a, .tool) }

        // 2.005) 詞性和仿寫：「分析詞性：…」「仿寫：…」
        if let g = Grammar.parse(message) { return done(Grammar.reply(g.kind, g.text), .knowledge) }
        // 2.01) 寫作：詳寫（「小明哭了，請詳寫」）、擴寫（「擴寫：樹在成長」「Expand: The tree is growing.」）、修改——
        //       先寫第一稿、自己檢查、一項一項修改到合格（至少原句的 9 倍長，有環境、感受、觀點、比喻、成語）
        if let w = Writer.parse(message) { return done(Writer.reply(w), .knowledge) }

        // 2.05) 名人命盤：「三島由紀夫的命盤」「跟我同命盤的名人」
        if L == .zh, Celebrities.asksSameChart(text) {
            return done(Celebrities.sameChartReply(ctx.profile.birthday), .reader)
        }
        if L == .zh, let p = Celebrities.asksChart(text) {
            return done(Celebrities.reading(p), .reader)
        }

        // 2.05) 成語：問意思、用法、近義、反義、某一類的成語、外文說法對應的成語——成語庫裡有就直接回答；
        //       出處典故、成語庫沒有的成語上網查；用成語說自己的毛病（「我老是三心二意怎麼辦」）→ 用意思上網找改善的方法
        if L == .zh, let u = Idioms.understand(text), u.intent != "feeling" {
            if let a = Idioms.answer(u) { return done(a, .knowledge) }
            switch u.intent {
            case "origin": return done(Loc.s("webAsk", .zh), .tool, web: "\(u.idiom) 成語 出處 典故")
            case "problem": if let q = Idioms.problemQuery(u.idiom) { return done(Loc.s("webAsk", .zh), .tool, web: q) }
            case "meaning" where u.extra != "unknown", "usage": return done(Loc.s("webAsk", .zh), .tool, web: "\(u.idiom) 成語 意思")
            default: break
            }
        }
        // 2.054) 自己有看法的比較題（「天氣和氣候有什麼不同」「病毒和細菌的差別」）：先用自己知道的，不當成近義詞
        if L == .zh, let a = Commonsense.compare(Everyday.clean(text)) { return done(a, .knowledge) }
        // 「金融卡跟信用卡有什麼不一樣」：資料庫裡有一筆講這兩個的差別（不是在問兩個詞是不是近義詞）
        if L == .zh, let a = Commonsense.difference(Everyday.clean(text)) { return done(a, .knowledge) }
        // 2.055) 反義詞：「開心的反義詞是什麼」「大和小是反義詞嗎」——詞庫裡有就直接回答，沒有就上網查
        if L == .zh, let ask = Antonyms.parse(text) {
            if let a = Antonyms.answer(ask) { return done(a, .knowledge) }
            switch ask {
            case let .of(w): return done(Loc.s("webAsk", .zh), .tool, web: "\(w) 反義詞")
            case let .pair(a, b): return done(Loc.s("webAsk", .zh), .tool, web: "\(a) \(b) 反義詞")
            }
        }
        // 2.06) 近義詞：「開心的近義詞是什麼」「高興和快樂意思一樣嗎」——詞庫裡有就直接回答，沒有就上網查
        if L == .zh, let ask = Synonyms.parse(text) {
            if let a = Synonyms.answer(ask) { return done(a, .knowledge) }
            switch ask {
            case let .near(w): return done(Loc.s("webAsk", .zh), .tool, web: "\(w) 近義詞")
            case let .pair(a, b): return done(Loc.s("webAsk", .zh), .tool, web: "\(a) \(b) 意思 差別")
            }
        }
        // 2.058) NineSun 自己的話：關於自己、自己的看法、笑話、人生的選擇題（該不該換工作、怎麼交到女朋友）
        if L == .zh, let a = Talk.detailed(text) {
            // 「好難」「真的嗎」只是回應，不換掉剛剛在聊的主題
            if ["好難", "真的嗎", "答錯了", "聽不懂"].contains(a.name), lastLocal != nil {
                // 「什麼意思」「聽不懂」接在知識回答後面：換個說法說一次
                if a.name == "聽不懂", let lc = lastLocal, lc.kind == "fact", !lc.subject.isEmpty,
                   let d = Commonsense.answer(lc.subject + "是什麼", now: ctx.now), d != lc.answer {
                    lastLocal?.turn = history.count
                    return done("換個說法：" + d, .knowledge)
                }
                lastLocal?.turn = history.count
            }
            else { lastLocal = LocalContext(kind: a.kind, subject: a.name, answer: a.text, turn: history.count) }
            var r = done(a.text, .knowledge)
            r.turn.variant = "talk"
            return r
        }
        // 2.059) 在說心情（不是問問題、不是問命理）：先用安慰的流程，沒有的話照心情接話——不拿去上網查、不用宮位亂回
        // （「今天」「今年」這種時間詞不算命理問題；要有運勢、命盤、宮這些字才是）
        let fortuneWords = ["運勢", "運氣", "財運", "桃花", "命盤", "命宮", "算命", "宮", "八字", "紫微", "卦", "流年", "流月", "大運", "九型", "星座", "合盤"]
        if L == .zh, !fortuneWords.contains(where: { text.contains($0) }), Library.detailed(text) == nil, Commonsense.answer(text, now: ctx.now) == nil {
            let mood = Affect.detect(text)
            let moods: Set<Affect.Mood> = [.grief, .sick, .worryOther, .goodNews, .proudEffort, .happy, .excitedPlan, .anxious, .scared, .angry,
                                           .complainAI, .apology, .sad, .lonely, .tired, .frustrated, .regret, .confused, .affection, .hope,
                                           .curious, .bored, .thanks, .praiseAI, .joke]
            // 開心、期待的心情只接「說」的話；「我什麼時候會升職」是在問問題。閒聊認得的（「我明天要去日本」）交給閒聊，它記得剛剛聊什麼
            let positive: Set<Affect.Mood> = [.goodNews, .proudEffort, .happy, .excitedPlan, .hope, .curious]
            // 問問題但不是要建議（「我壓力大的時候會怎樣」問的是九型人格）：交給原本的路
            let asksAdvice = ["怎麼辦", "建議", "該怎麼", "要怎麼", "如何是好", "你覺得呢", "你覺得", "你說呢", "怎麼想", "怎麼可能"].contains(where: { text.contains($0) })
            _ = positive
            // 「我今天心情為什麼這麼差」「為什麼我一直想哭」：問自己為什麼難過，是在抒發，不是在問知識
            let venting = [.sad, .lonely, .tired, .frustrated, .anxious, .angry, .regret].contains(mood) && text.contains("我")
                && text.range(of: "為什麼|為何|為啥|怎麼(會)?(這麼|那麼|老是|總是|一直)", options: .regularExpression) != nil
                && text.range(of: "原因是什麼|科學|研究|症狀|是什麼病", options: .regularExpression) == nil
            if moods.contains(mood), !(EchoEngine.isQuestion(text) && !asksAdvice && !venting),
               Talk.chat(text) == nil {
                // 擔心別人（「我姊姊心情不好」）：不是在說自己的心情，不用安慰自己的那一套
                if mood != .worryOther, let s = Solace.reply(text, birthday: ctx.profile.birthday, now: ctx.now,
                                        again: history.suffix(4).contains { $0.role == .echo && $0.text.contains("我看了你此刻走到的地方") }) {
                    let p = core?.perceive(text)
                    if let p { core?.remember(p) }
                    lastLocal = LocalContext(kind: "mood", subject: text, extra: lastLocal?.kind == "mood" ? (lastLocal?.extra.isEmpty == false ? lastLocal!.extra : lastLocal!.subject) : "", answer: s, turn: history.count)
                    return done(s, .neural, palace: p)
                }
                if let body = Talk.moodBody(mood, text) {
                    lastLocal = LocalContext(kind: "mood", subject: text, extra: lastLocal?.kind == "mood" ? (lastLocal?.extra.isEmpty == false ? lastLocal!.extra : lastLocal!.subject) : "", answer: body, turn: history.count)
                    var r = done(body, .neural)
                    r.turn.tokens = []
                    return r
                }
            }
        }
        // 2.06) 假設題、兩難題（「如果有兩個按鈕…你怎麼選」）：問的是 NineSun 自己的想法，不是命盤、心情，也不用上網查。
        //       照自己的價值觀選一邊、說理由（大腦開著時 App 會交給大腦推理）
        if L == .zh || L == .en, Dilemma.looks(text) { return done(Dilemma.stance(text, zh: L == .zh), .knowledge) }
        // 2.065) 用算的就知道的（現在幾點、明天星期幾、離過年還有幾天、一公斤幾公克、一加一）和 NineSun 自己的常識
        //        （國家、動物、自然、人物、節日、怎麼做、推薦）：自己回答，不用上網；不知道的才上網查
        if L == .zh, let a = Everyday.answer(text, now: ctx.now) { return done(a, .tool) }
        if L == .zh, let a = EchoEngine.aboutMe(text, now: ctx.now) { return done(a, .knowledge) }
        if L == .zh, let a = Commonsense.react(text) { return done(a, .neural) }
        // 作品的作者、常見的清單（八大行星、四大名著）、一類作品（有名的西方文學作品）：自己知道的就直接回答
        if L == .zh, let a = Library.detailed(text) {
            lastWebQuery = EchoEngine.searchQuery(text)
            lastWebTurn = history.count
            lastLocal = LocalContext(kind: a.kind, subject: a.subject, extra: a.extra, turn: history.count)
            return done(a.text, .knowledge)
        }
        if L == .zh, let a = Commonsense.answer(text, now: ctx.now) {
            if let r = a.range(of: "如果只能選一個：") {
                lastLocal = LocalContext(kind: "recommend", subject: Commonsense.recommendCategory(text) ?? "", extra: String(a[r.upperBound...].prefix { $0 != "\n" }), shown: a, turn: history.count)
            } else if let sub = Commonsense.answerSubject(text, a) ?? Commonsense.subject(text) {
                // 上一個主角記在 shown：「日本有多大」「台灣呢」「誰比較大」
                let before = lastLocal?.kind == "fact" && lastLocal?.subject != sub ? (lastLocal?.subject ?? "") : (lastLocal?.kind == "fact" ? lastLocal?.shown ?? "" : "")
                lastLocal = LocalContext(kind: "fact", subject: sub, extra: text, shown: before, answer: a, turn: history.count)
            } else {
                // 沒有單一主角的回答（做法、整句問題）：還是記住剛剛的回答，追問「要放糖嗎」「搭高鐵要多久」可以從裡面找；
                // 不是做法的話，主題沿用上一題的（「台灣有幾個縣市」→「最大的城市是哪個」→「人口多少」還是在問台灣）
                let keep = !a.contains("\n1. ") && lastLocal?.kind == "fact" ? (lastLocal?.subject ?? "") : ""
                lastLocal = LocalContext(kind: "fact", subject: keep, extra: text, answer: a, turn: history.count)
            }
            // 自己答的也算上一題的主題：追問「那這些省都是哪些省」要接得上
            lastWebQuery = EchoEngine.searchQuery(text)
            lastWebTurn = history.count
            return done(a, .knowledge)
        }
        // 2.067) 「跟我說說紅樓夢」「介紹一下哈利波特」：認得的作品就照「作品在講什麼」查（不是閒聊、不是宮位）
        if L == .zh, ["說說", "聊聊", "介紹", "跟我說"].contains(where: { text.contains($0) }), let w = Library.workAsked(text) {
            lastLocal = LocalContext(kind: "work", subject: w, turn: history.count)
            return done(Loc.s("webAsk", .zh), .tool, web: w + "在講什麼")
        }
        // 2.068) 「我的健康要注意什麼」「我的錢財要注意什麼」：問的是自己命盤上的這個主題，不是上網查一般的健康、理財知識
        if L == .zh, let norm = EchoEngine.myTopic(text), let tp = TopicRouter.parse(norm, L: .zh, now: ctx.now) {
            guard let bd = ctx.profile.birthday else {
                return done("我還不知道你的生日，沒辦法看這個主題。直接告訴我，例如：我的生日是2000年1月1日，或到右上角「調頻台」選好日期（會自動儲存）。", .tool)
            }
            let out = Reader(.zh, i18n: i18n).topicZh(Destiny(bd), palaces: tp.palaces.isEmpty ? [tp.palace] : tp.palaces, y: tp.y, m: tp.m)
            last = out.follow; lastTurn = history.count; lastMantic = nil
            return done(out.text, .reader, card: out.card)
        }
        // 2.07) 問世界上的事（不是問自己的命、不是說心情、不是在跟我聊天）：上網查——
        // 不能被「房」「出國」「情緒」這些字帶去算命，也不能被書名裡的「煩惱」帶去安慰
        if L == .zh, EchoEngine.worldQuestion(text) {
            if let w = Library.workAsked(text) ?? Understanding.workTitle(text) { lastLocal = LocalContext(kind: "work", subject: w, turn: history.count) }
            return done(Loc.s("webAsk", .zh), .tool, web: EchoEngine.searchQuery(text))
        }
        // 2.08) 問一部作品（書名裡有「煩惱」「孤獨」也不是在說心情）：上網查
        if L == .zh, EchoEngine.asksAboutWork(text) || EchoEngine.bareTitle(text) {
            if let w = Library.workAsked(text) ?? Understanding.workTitle(text) { lastLocal = LocalContext(kind: "work", subject: w, turn: history.count) }
            return done(Loc.s("webAsk", .zh), .tool, web: EchoEngine.searchQuery(text))
        }
        // 2.09) 生活上的「怎麼做」（怎麼存錢、面試要注意什麼、被主管罵了怎麼辦）：上網看好幾個網站，整理出共同的做法
        if L == .zh, EchoEngine.practical(text) {
            return done(Loc.s("webAsk", .zh), .tool, web: EchoEngine.searchQuery(text))
        }
        // 2.1) 心情：用你的生日看此刻的大運、流年、流月、日夜宮，說出處境和情緒，溫柔地安慰
        // （「鄧麗君是怎麼過世的」是在問別人怎麼過世，不是在說心情）
        // （「頭痛會死嗎」「頭痛可以運動嗎」「拉肚子多久會好」是在問身體的事，不是在說心情）
        if L == .zh, !EchoEngine.asksHowSomeoneDied(text), !EchoEngine.asksHealthInfo(text), let s = Solace.reply(text, birthday: ctx.profile.birthday, now: ctx.now,
                                again: history.suffix(4).contains { $0.role == .echo && $0.text.contains("我看了你此刻走到的地方") }) {
            let p = core?.perceive(text)
            if let p { core?.remember(p) }
            lastLocal = LocalContext(kind: "mood", subject: text, extra: lastLocal?.kind == "mood" ? (lastLocal?.extra.isEmpty == false ? lastLocal!.extra : lastLocal!.subject) : "", answer: s, turn: history.count)
            return done(s, .neural, palace: p)
        }

        // 2.5) 明確叫它上網查（「上網查…」「搜尋…」「幫我查…」「search …」）：直接上網，不用本地存的答案
        if let q = EchoEngine.explicitSearch(text) {
            return done(Loc.s("webAsk", L), .tool, web: q)
        }

        // 外語走多語系流程
        if L != .zh, let i18n {
            // 簡單的寒暄（how are you、tell me a joke、thank you）：直接回，不要說「我沒學過」
            if let a = Talk.foreign(text, L) {
                var r = done(a, .knowledge)
                r.turn.variant = "talk"
                return r
            }
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
            if let kb = knowledge[.zh], let e = kb.answer(text), EchoEngine.kbFits(e, text) {
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
        // （「請事假會扣薪水嗎」問的是規定，不是財運：資料庫答得出來、又沒有算命的字，就不算命）
        if let tp = TopicRouter.parse(text, L: .zh, now: ctx.now), !EchoEngine.knowledgeNotFortune(text) {
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
        if askKnow, !askSearch, let kb = knowledge[.zh], let e = kb.answer(text), EchoEngine.kbFits(e, text) {
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
        let mood = L == .zh ? Affect.detect(text) : .info
        if L == .zh, !EchoEngine.isQuestion(text), let s = Talk.chat(text) {
            // 在說自己的事：照內容接話（不拿宮位亂回）
            raw = s
            if !Talk.lastChatTopic.isEmpty { lastLocal = LocalContext(kind: "smalltalk", subject: Talk.lastChatTopic, turn: turns) }
            if Talk.lastChatTopic.hasPrefix("旅行:") { lastTravel = (String(Talk.lastChatTopic.dropFirst(3)), turns) }
        } else if [.goodNews, .proudEffort, .excitedPlan, .happy].contains(mood), !EchoEngine.isQuestion(text) {
            // 好消息、開心的事：接著問下去（不要接「是發生了什麼事？」或一段宮位的話）
            raw = EchoEngine.celebrate(text)
        } else if let c = companionReply(text, L, ctx: ctx, palace: palace) {
            raw = c
        } else if !asksMe, EchoEngine.infoQuestion(text) || EchoEngine.looksLikeQuestion(text) {
            // 在問問題（不是問 NineSun 自己）：上網查，不用本地寫死的答案
            var r = done(Loc.s("webAsk", L), .tool, palace)
            r.webQuery = EchoEngine.searchQuery(text)
            return r
        } else if !asksMe, EchoEngine.infoQuestion(text) || (asking && !text.contains("我")) {
            // 知識題、跟自己無關的問題：上網查
            var r = done(Loc.s("webAsk", L), .tool, palace)
            r.webQuery = EchoEngine.searchQuery(text)
            return r
        } else if L == .zh, text.hasPrefix("我"), !text.hasPrefix("我想"), !text.hasPrefix("我要"), !EchoEngine.isQuestion(text), let a = Commonsense.answer(text + "怎麼辦", now: ctx.now),
                  a.contains("1.") {
            // 說了一個生活上的麻煩（「我養的貓不吃飯」）：直接給做法；記住這段做法，追問「是Windows」「要看醫生嗎」可以從裡面找
            let worrying = text.range(of: "生病|不舒服|痛|吐|發燒|受傷|流血|不吃|不喝|昏|喘|摔|跌倒|走失|不見|被偷|被騙|出事|車禍|住院|過敏|腫", options: .regularExpression) != nil
            raw = (worrying ? "聽起來有點讓人擔心。" : "我懂，這種情況很多人都遇過。") + a
            lastLocal = LocalContext(kind: "fact", subject: "", extra: text + "怎麼辦", answer: a, turn: turns)
        } else if let p = palace {
            let cal = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: ctx.now)
            let dn = ctx.profile.birthday.map { Destiny($0).day(month: cal.month!, day: cal.day!) }
            raw = Companion.life(L: L, reader: Reader(L, i18n: i18n), perceived: p, day: dn?.day, night: dn?.night, choose: choose,
                                 destiny: ctx.profile.birthday.map { Destiny($0) }, now: ctx.now, text: text)
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

    /// 一段回答的重點：拿掉標題、項目符號，留最前面一兩句完整的話
    static func gist(_ text: String) -> String {
        // 做法清單：挑前三點，每點只留第一小句
        if text.contains("\n1. ") {
            let items = text.split(separator: "\n").map(String.init).filter { $0.range(of: #"^[0-9]+\. "#, options: .regularExpression) != nil }.prefix(3).map { line -> String in
                let body = line.replacingOccurrences(of: #"^[0-9]+\. "#, with: "", options: .regularExpression)
                return String(body.prefix { !"，；。".contains($0) })
            }
            if !items.isEmpty { return "重點是：" + items.joined(separator: "；") + "。" }
        }
        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("📌") && !$0.hasPrefix("💬") && !$0.hasPrefix("來源") && !$0.hasPrefix("【") && $0.count > 6 }
        let body = lines.joined(separator: "")
            .replacingOccurrences(of: #"^[0-9①-⑩•\-．.、\s]+"#, with: "", options: .regularExpression)
        var out = "", count = 0
        for ch in body {
            out.append(ch)
            if "。！？".contains(ch) { count += 1; if count >= 2 || out.count >= 80 { break } }
        }
        return out.isEmpty ? String(body.prefix(80)) : out
    }

    /// 對方只回「好」「好啊」「要」「想」，而上一則回答的最後有建議的問法（「…可以問我「今天運勢」」）：回傳那個問法
    static func acceptedSuggestion(_ message: String, history: [ChatTurn]) -> String? {
        let t = Talk.clean(message)
        guard ["好", "好啊", "好喔", "好的", "好呀", "要", "要啊", "要喔", "想", "想啊", "想要", "想看", "要看", "對", "對啊", "可以", "可以啊", "OK", "ok", "嗯", "嗯嗯", "好啊好啊", "麻煩你", "拜託"].contains(t),
              let last = history.last(where: { $0.role == .echo }), last.text.contains("嗎") || last.text.contains("？") || last.text.contains("問我「") else { return nil }
        // 最後一段裡的「…」（離結尾最近的建議）
        let tail = String(last.text.suffix(160))
        guard let r = tail.range(of: #"「([^「」]{2,16})」"#, options: [.regularExpression, .backwards]) else { return nil }
        let cmd = String(tail[r]).trimmingCharacters(in: CharacterSet(charactersIn: "「」"))
        // 只接受像問題、指令的建議（「今天運勢」「這個月運勢」「今天吃什麼」），不是書名、引言
        guard ["運勢", "運", "吃什麼", "解讀", "命盤", "八字", "紫微", "大運", "流年", "在講什麼", "笑話", "推薦", "怎麼", "是什麼"].contains(where: { cmd.contains($0) }) else { return nil }
        return cmd
    }

    enum LocalFollow { case answer(String), rewrite(String) }

    static var chatRotation = 0
    /// 一大段在說自己的事（「我家的貓從昨天開始一直吐…要不要帶去看醫生」）：從句子裡找最相關的做法，從後面（問題在的地方）往前找。
    /// 只處理在問「怎麼辦、要不要」或在說自己的困擾的話；最後在問事實（「…那邊天氣冷嗎」「…為什麼」）的不管
    static let narrativeAdviceAsk = "怎麼辦|該怎麼|要怎麼|怎麼做|要不要|需不需要|該不該|有什麼(方法|辦法|建議)|有沒有(方法|辦法|建議)|不想去?看醫生|不肯去?看醫生|不願意去?看醫生"
    static let narrativeYesNo = "是不是.{1,8}[了嗎]?[？?]*$|會不會.{1,8}[？?]*$|嗎[？?]*$"
    /// 擲骰子、丟硬幣、猜拳、隨便給一個數字、「幫我決定要吃拉麵還是火鍋」
    static func playful(_ t: String) -> String? {
        if t.range(of: #"^(幫我|來|我們來)?(擲|丟|骰|搖)(一下|一個|個|一顆)?骰子(吧)?$|^骰子$"#, options: .regularExpression) != nil {
            let n = Int.random(in: 1...6)
            return "🎲 擲出來是…… \(["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"][n - 1]) \(n) 點！"
        }
        if t.range(of: #"^(幫我|來|我們來)?(丟|擲|拋)(一下|個|一個)?硬幣(吧)?$"#, options: .regularExpression) != nil {
            return "🪙 丟出來是……\(Bool.random() ? "正面" : "反面")！"
        }
        if t.range(of: #"^(來|我們來|跟我)?(猜拳|剪刀石頭布|玩猜拳)(吧)?$"#, options: .regularExpression) != nil {
            return "好啊！剪刀、石頭、布——我出「\(["✌️ 剪刀", "✊ 石頭", "🖐 布"].randomElement()!)」！你出什麼？"
        }
        if t.range(of: #"^(隨便|幫我)?(給我|選|挑|想)(一個)?數字$|^隨便(給我)?一個數字$|^(幫我)?從?1到100(選|挑|抽)(一個)?(數字)?$"#, options: .regularExpression) != nil {
            return "給你一個數字：\(Int.random(in: 1...100))！"
        }
        // 「幫我決定要吃拉麵還是火鍋」「拉麵還是火鍋，你幫我選」
        if let g = RuleBook.match(t, #"^(?:你)?(?:幫我|替我)(?:選|決定|做決定|挑|選一個)[：:，, ]*(?:要|我要|該)?(.{1,10}?)還是(.{1,10})$"#)
            ?? RuleBook.match(t, #"^(?:我)?(?:要|該)?(.{1,10}?)還是(.{1,10}?)[，, ]*(?:你)?(?:幫我選|幫我決定|你選|幫我挑|你決定)(?:一個)?(?:吧)?$"#) {
            var b = g[1]
            for suf in ["好呢", "好", "呢", "比較好"] where b.hasSuffix(suf) && b.count > suf.count { b.removeLast(suf.count); break }
            let pick = Bool.random() ? g[0] : b
            return "我幫你選：\(pick)！\n（小撇步：真的猶豫的時候，聽到答案的那一秒，如果你心裡有點失望，那另一個才是你真正想要的 😉）"
        }
        return nil
    }

    /// 明白在問命理的字（一大段心事裡出現「今天」「明天」不算）
    static func explicitFortune(_ text: String) -> Bool {
        BrainRoute.withoutEveryday(text).range(of: "運勢|運氣|命盤|命宮|八字|紫微|卦|流年|大運|流月|九型|第幾型|十二宮|星座|生肖|算命|占卜|塔羅|太歲|風水", options: .regularExpression) != nil
    }
    static func distressStory(_ text: String) -> Bool {
        text.range(of: "擔心|難過|丟臉|好煩|很煩|壓力|害怕|好怕|很怕|痛苦|不開心|想哭|哭了|焦慮|緊張|生氣|委屈|不安|崩潰|受不了|好累|很累|一直|每天都|最近都|好幾天|老是|總是|沒精神|不舒服|沒用|不聽|不理我|睡不著|提不起勁|沒動力|沒力氣|加班", options: .regularExpression) != nil
    }
    /// 幾種常見的故事，困擾的根源不是句子裡附帶提到的症狀：
    /// 「室友很吵…我睡不好」要的是怎麼跟室友說，不是失眠的做法；「很怕上台…」要的是上台緊張，不是怎麼做簡報
    static func storyAdvice(_ text: String, now: Date, lead: String? = nil) -> String? {
        let stories: [(who: String, what: String, ask: String)] = [
            ("室友", "吵|噪音|很晚回來|大聲|聲音", "室友很吵"),
            ("鄰居|樓上|隔壁", "吵|噪音|大聲|聲音|走路", "鄰居很吵怎麼辦"),
            ("上台|報告|演講|在很多人面前|在大家面前|簡報", "怕|緊張|腦袋空白|發抖|不敢", "上台緊張怎麼辦"),
            ("小孩|孩子|寶寶|兒子|女兒|小朋友", "不肯睡|不睡覺|不想睡|很晚睡|不肯上床|一直要玩", "小孩不肯睡覺"),
        ]
        // 想幫別人：「同事被裁員了要跟他說什麼」「朋友家人過世要說什麼」：給安慰別人的方法，不是安慰自己
        let other = "朋友|同事|同學|家人|爸爸|媽媽|爸|媽|男朋友|女朋友|男友|女友|老公|老婆|室友|哥哥|姊姊|姐姐|弟弟|妹妹|親戚|長輩"
        if text.count >= 6, text.range(of: other, options: .regularExpression) != nil,
           text.range(of: "(要|該|可以|能)?(跟他|對他|跟她|對她|跟他們|對他們)?(說什麼|講什麼|說些什麼)|怎麼安慰|要怎麼安慰|能做什麼|可以做什麼|能幫什麼|怎麼幫(他|她)", options: .regularExpression) != nil {
            let ask = text.range(of: "過世|去世|走了|往生|離開人世|喪禮|告別式", options: .regularExpression) != nil ? "朋友家人過世要說什麼" : "怎麼安慰朋友"
            if let a = Commonsense.answer(ask, now: now), a.contains("\n1. ") { return (lead ?? "你願意為他想這麼多，他一定感受得到。\n") + a }
        }
        guard text.count >= 12, text.range(of: narrativeAdviceAsk + "|不知道(要|該)?怎麼|怎麼跟|有什麼方法|好累|好煩|很煩|受不了|好困擾|很困擾", options: .regularExpression) != nil else { return nil }
        let hurting = text.range(of: "擔心|難過|好煩|很煩|壓力|害怕|好怕|很怕|痛苦|焦慮|緊張|生氣|委屈|崩潰|受不了|好累|很累|困擾", options: .regularExpression) != nil
        let lead = lead ?? (hurting ? "聽起來真的很不好受，先抱抱你。" : "我懂你的狀況。")
        for st in stories where text.range(of: st.who, options: .regularExpression) != nil && text.range(of: st.what, options: .regularExpression) != nil {
            if let a = Commonsense.answer(st.ask, now: now), a.contains("\n1. ") { return lead + a }
        }
        return nil
    }

    static func narrativeAdvice(_ text: String, now: Date) -> String? {
        guard text.count > 24, text.contains("我") else { return nil }
        let advice = text.range(of: narrativeAdviceAsk, options: .regularExpression) != nil
        let yesNo = text.range(of: narrativeYesNo, options: .regularExpression) != nil
        let story = distressStory(text)
        guard advice || (yesNo && story) else { return nil }
        let clauses = text.components(separatedBy: CharacterSet(charactersIn: "，,。！!？?；;、\n")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count >= 3 }
        if !advice, let lastClause = clauses.last, lastClause.range(of: "為什麼|是什麼|多少|幾[個點號歲公年月天次度]|哪裡|哪個|哪一|誰|什麼時候", options: .regularExpression) != nil { return nil }
        // 毛孩生病：說到貓狗又說到症狀
        if text.range(of: "貓|狗|寵物|毛孩", options: .regularExpression) != nil,
           text.range(of: "吐|拉肚子|腹瀉|不吃|沒精神|精神不好|抽搐|很喘|一直喘|血|尿不出來", options: .regularExpression) != nil,
           let a = Commonsense.answer("貓咪不舒服", now: now) {
            return "聽起來牠真的不太舒服，你一定很擔心。" + a
        }
        // 有說到難過、擔心的話先接住心情；只是說明狀況就直接給做法
        let hurting = text.range(of: "擔心|難過|丟臉|好煩|很煩|壓力|害怕|好怕|很怕|痛苦|不開心|想哭|哭了|焦慮|緊張|生氣|委屈|不安|崩潰|受不了|好累|很累", options: .regularExpression) != nil
        let lead = hurting ? "聽起來真的很不好受，先抱抱你。" : "我懂你的狀況。"
        if let a = storyAdvice(text, now: now, lead: lead) { return a }
        // 先看最後的問題，再看第一句（通常是發生了什麼事），最後才是中間的細節（「晚上也睡不著」只是附帶的）
        // 真正在問的那一句（「她都說沒事不想去看醫生」）最優先
        var order = clauses.reversed().filter { $0.range(of: narrativeAdviceAsk, options: .regularExpression) != nil }
        var rest = clauses.reversed().map { $0 }
        if rest.count >= 3, let firstClause = clauses.first { rest.removeLast(); rest.insert(firstClause, at: 1) }
        for c in rest where !order.contains(c) { order.append(c) }
        // 先每一句都用資料庫裡的說法找（「提不起勁」→ 倦怠），都找不到才用換句話說（「壓力很大」→ 放鬆），免得前面一句籠統的先搶走
        for pass in 0..<2 {
            for c in order {
                // 只是問「這樣正常嗎、是不是…」：要從說到困擾的那一句找，不要因為前面提到「在學吉他」就教怎麼學吉他
                if !advice, !distressStory(c) { continue }
                // 「跟最好的朋友吵架了」＝跟朋友吵架了
                let plain = c.replacingOccurrences(of: "(最好的|很好的|要好的|最要好的)(朋友|同學|同事)", with: "$2", options: .regularExpression)
                if pass == 0 {
                    for q in [plain, plain + "怎麼辦"] {
                        if var a = Commonsense.answer(q, now: now), a.contains("\n1. ") {
                            // 「我想要換工作」的回答開頭是「好啊，我陪你！」，接在「我懂你的狀況。」後面就重複了
                            a = a.replacingOccurrences(of: #"^(好啊|好呀|好喔|好)[，,]?我陪你[！!]"#, with: "", options: .regularExpression)
                            return (a.hasPrefix("聽起來") ? (hurting ? "辛苦你了。" : "") : lead) + a
                        }
                    }
                } else if plain.count >= 4, let a = Fuzzy.answer(plain, now: now), a.contains("\n1. ") {
                    // 換個說法的（「手機被人偷走了」）
                    return (a.hasPrefix("聽起來") ? (hurting ? "辛苦你了。" : "") : lead) + a
                }
            }
        }
        if advice, let h = Commonsense.howtoMentioned(text), let a = Commonsense.answer(h + "怎麼辦", now: now) ?? Commonsense.answer("怎麼" + h, now: now) {
            return lead + a
        }
        return nil
    }

    static let copingSteps = "我陪你一起想，可以先這樣：\n1. 先照顧好自己：今天好好吃飯、早點睡，累的時候什麼事都會看起來更難\n2. 把讓你難受的事寫下來，分成「我能做點什麼的」和「我控制不了的」\n3. 能做的挑一件最小的先做；控制不了的，先試著放下\n4. 找一個信任的人說說，不要一個人扛\n\n如果願意，跟我多說一點是哪件事最讓你煩，我可以幫你想更具體的做法。"

    /// 追問剛剛回答裡提到的東西（「搭高鐵要多久」「要放糖嗎」「那台鐵呢」）：從剛剛的回答裡找出那一段
    /// 「那X呢」要換的那一句：上一句自己沒說主題（「要帶傘嗎」）、再上一句是以地名開頭（「台北明天天氣」），就用再上一句
    static func swapBase(_ prev0: String, history: [ChatTurn]) -> String {
        guard Talk.clean(prev0).range(of: "^(要|可以|能|會|需要|該|應該|是|在|有|去|怎麼|多|幾|為什麼|什麼|哪)", options: .regularExpression) != nil,
              let e = history.dropLast(2).suffix(4).last(where: { $0.role == .user })?.text else { return prev0 }
        let c = Talk.clean(e)
        let startsWithPlace = Commonsense.realMentions(c, in: Commonsense.facts).contains { $0.range.lowerBound == c.startIndex && ["國家", "城市", "地標"].contains($0.entity.kind) }
        return startsWithPlace ? e : prev0
    }

    /// 「那X呢」：把上一題裡和 X 同一類的部分換成 X（時間、語言、數量；不然就換掉開頭的主題）
    static func swapInto(previous p: String, with x: String) -> String? {
        let times = "今天|明天|後天|大後天|昨天|這週|下週|下禮拜|週末|這個月|下個月|今年|明年|去年"
        if x.range(of: "^(\(times))$", options: .regularExpression) != nil, let r = p.range(of: times, options: .regularExpression) { return p.replacingCharacters(in: r, with: x) }
        let langs = "英文|日文|韓文|中文|法文|德文|西班牙文|義大利文|泰文|越南文|台語|粵語|英語|日語|韓語|法語|德語"
        if x.range(of: "^(\(langs))$", options: .regularExpression) != nil, let r = p.range(of: langs, options: .regularExpression) { return p.replacingCharacters(in: r, with: x) }
        // 數量：同一類的單位（長度、重量、時間、錢）換掉第一個
        let num = "[0-9０-９.]+|[零一二兩三四五六七八九十百千萬]+"
        let groups = ["公里|公尺|英里|英尺|呎|公分|吋|米", "公斤|公克|台斤|磅|斤", "年|個月|天|小時|分鐘|週", "元|萬|塊"]
        if let xu = RuleBook.match(x, "^(?:\(num))(\(groups.joined(separator: "|")))$")?.first, let grp = groups.first(where: { g in xu.range(of: "^(\(g))$", options: .regularExpression) != nil }) {
            if let r = p.range(of: "(\(num))(\(grp))", options: .regularExpression) { return p.replacingCharacters(in: r, with: x) }
            // 「身高160體重50」：沒寫單位的體重、身高
            if grp.hasPrefix("公斤"), let r = p.range(of: "(?<=體重)[0-9.]+", options: .regularExpression) { return p.replacingCharacters(in: r, with: x) }
            if grp.hasPrefix("公里"), let r = p.range(of: "(?<=身高)[0-9.]+", options: .regularExpression) { return p.replacingCharacters(in: r, with: x) }
            return nil
        }
        // 開頭就是一個認得的地方或東西（「台北明天天氣」）：換掉它
        if let m = Commonsense.realMentions(p, in: Commonsense.facts).first(where: { $0.range.lowerBound == p.startIndex }), m.alias.count >= 2, m.range.upperBound < p.endIndex {
            return x + p[m.range.upperBound...]
        }
        // 「什麼是黑洞」→「什麼是白洞」
        if let g = RuleBook.match(p, #"^(?:請問)?什麼是(.+)$"#), !g[0].isEmpty { return "什麼是" + x }
        // 上一句自己就沒說主題（「要花多少錢」）：把 X 放在前面（「貓要花多少錢」）
        if p.range(of: "^(要|可以|能|會|需要|該|應該|是|在|有|去|怎麼|多|幾|為什麼|什麼|哪)", options: .regularExpression) != nil { return x + p }
        // 換掉開頭的主題：「台北有什麼好玩的」→「高雄有什麼好玩的」、「貓的英文怎麼說」→「狗的英文怎麼說」
        // （「咖啡和茶哪個好」這種比較兩個的，不知道要換哪一個，就不換）
        if p.range(of: "和|跟|與|還是", options: .regularExpression) == nil,
           let g = RuleBook.match(p, #"^(.{1,6}?)(的|有|是|在|要|可以|怎麼|多|幾|會|能)(.+)$"#), !g[0].contains("我"), g[0].count <= 6,
           g[0].range(of: "什麼|怎麼|為什麼|哪|誰|多少|幾", options: .regularExpression) == nil {
            return x + g[1] + g[2]
        }
        return nil
    }

    /// 「鄧麗君是怎麼過世的」「愛因斯坦幾歲去世」：問別人（名人）怎麼過世，不是自己家人過世
    /// 問身體狀況的事（會不會很嚴重、要不要看醫生、可以吃什麼、可不可以運動、多久會好）：是問題，不是在說心情
    static func asksHealthInfo(_ t: String) -> Bool {
        isQuestion(t)
            && t.range(of: "痛|咳|燒|拉肚子|腹瀉|便秘|吐|暈|癢|腫|流鼻|鼻塞|過敏|感冒|發炎|疹|傷口|流血|出血|抽筋|麻|喘|生病|不舒服|受傷|扭傷|骨折|中暑", options: .regularExpression) != nil
            && t.range(of: "心(好|很|真的|真|超)?痛|心碎|難過|傷心|心情|孤單|寂寞|焦慮|憂鬱|壓力|煩|失戀|分手|吵架", options: .regularExpression) == nil
            && t.range(of: "會死|致命|嚴重嗎|嚴重|危險嗎|要緊|看醫生|就醫|去醫院|看醫師|急診|可以(吃|喝|運動|洗澡|洗頭|喝酒|上班|上學|游泳|搭飛機|吹冷氣|喝咖啡|喝牛奶|吃冰|曬太陽|跑步|按摩|熱敷|冰敷)|能不能|能(吃|喝)|(吃|喝)什麼|多久(會|才會|能|才能)?好|幾天(會|才會)?好|會傳染|正常嗎|吃什麼藥|擦什麼|看哪一?科|掛哪一?科|是什麼病|原因|為什麼會", options: .regularExpression) != nil
            && t.range(of: "好痛苦|好難受|好怕|很怕|害怕|好想哭|受不了", options: .regularExpression) == nil
    }

    static func asksHowSomeoneDied(_ t: String) -> Bool {
        t.range(of: "(怎麼|如何|為什麼|什麼時候|哪一年|幾歲|是怎麼|因為什麼)(過世|去世|死|離世|逝世)", options: .regularExpression) != nil
            && t.range(of: "我|爸|媽|爺|奶|外公|外婆|阿公|阿嬤|家|狗|貓|寵物|朋友|老公|老婆|男友|女友|同學|同事", options: .regularExpression) == nil
    }

    /// 「要煮多久」「怎麼去」「哪一年」「他幾歲」：很短、用動詞或問句詞開頭、句子裡沒有認得的東西——是接著上一題問的
    /// 只是對剛剛的回答說話（「說簡單一點」「舉個例子」「為什麼」「還有嗎」「謝謝」）：本身沒有主題
    static func isMetaFollowUp(_ raw: String) -> Bool {
        let t = Talk.clean(raw).replacingOccurrences(of: #"[，,。！!？?～~、\s]"#, with: "", options: .regularExpression)
        return t.range(of: #"^(那)?(可以|能|請|再)?(說|講|解釋|講解)?(得)?(簡單|詳細|清楚|白話|仔細|具體)(一點|些)?(嗎|呢|好嗎)?$|^(那)?(再說一次|再講一次|再說一遍|說詳細一點|說清楚一點|講簡單一點|白話一點|舉個?例子|舉一個例子|給我一個例子|例子呢|比如說呢|比如呢|為什麼|為何|為啥|怎麼說|真的嗎|真的假的|然後呢|然後|還有呢|還有嗎|還有別的嗎|還有其他的嗎|所以呢|什麼意思|聽不懂|看不懂|不懂|好|好的|嗯|喔|哦|噢|謝謝|謝啦|謝謝你|感謝|了解|知道了|原來如此|原來是這樣|是喔|對|沒錯|酷|太酷了|好厲害|厲害)$"#, options: .regularExpression) != nil
    }

    static func subjectless(_ raw: String) -> Bool {
        let t = Talk.clean(raw)
        guard (2...10).contains(t.count), !t.contains("你"), !t.contains("我") else { return false }
        // 要是在問問題（「是講一個機器人的故事」是在說，不是在問）
        guard EchoEngine.isQuestion(raw) || raw.hasSuffix("嗎") || raw.hasSuffix("呢") || t.range(of: "什麼|怎麼|哪|幾|多|誰|為什麼", options: .regularExpression) != nil else { return false }
        let s = t.replacingOccurrences(of: "^(那麼|那|所以|然後)", with: "", options: .regularExpression)
        guard s.range(of: #"^(他|她|它|牠)?(要|可以|能|會|需要|該|應該|是|去|在|還有|有沒有|是不是|怎麼|為什麼|哪|什麼|多|幾|最|大概|大約|平常|有)|^(是)?誰(第一個|最先|最早|發明|寫|畫|唱|設計|建造|創立|蓋|拍|導演|演|說的|做的|贏)"#, options: .regularExpression) != nil else { return false }
        let c = Everyday.clean(s)
        return Commonsense.realMentions(c, in: Commonsense.facts).isEmpty && Commonsense.mentions(c, in: Commonsense.howtos).isEmpty
    }

    /// 上一題在說什麼東西（「怎麼煮綠豆湯」→綠豆湯、「我想去露營」→露營、「我手機很慢」→手機）；說「他／她」就找前一個回答裡的人
    static func topicOf(_ prev: String, message: String, previousAnswer: String?) -> String? {
        if Talk.clean(message).range(of: "^(那)?(他|她)", options: .regularExpression) != nil, let a = previousAnswer {
            let people = Commonsense.facts.filter { $0.kind == "人物" }
            if let m = Commonsense.realMentions(Everyday.clean(a), in: people).min(by: { $0.range.lowerBound < $1.range.lowerBound }) { return m.entity.name }
            return nil
        }
        var s = Understanding.frame(prev).subject
        if s.isEmpty || s == Understanding.plain(prev) || s.count > 8 || s.hasPrefix("我") {
            var p = Talk.clean(prev)
            p = p.replacingOccurrences(of: #"^我(的)?(最近|現在|今天|明天|下週|下禮拜|好像|一直)?(很想|想要|想|要|打算|準備|正在|在)?(去|學|養|買|玩|考|做|吃|看)?"#, with: "", options: .regularExpression)
            p = p.replacingOccurrences(of: #"(怎麼辦|要怎麼做|怎麼做|要注意什麼|注意什麼|在哪裡|在哪|是誰寫的|是誰|是什麼|很慢|好慢|壞了|不見了|好痛|很痛)$"#, with: "", options: .regularExpression)
            s = p
        }
        guard (1...8).contains(s.count), s != Talk.clean(message), s.range(of: "什麼|怎麼|哪|誰|嗎", options: .regularExpression) == nil,
              s.range(of: "^(很|好|超|真|太|有點|蠻|滿|挺|不)", options: .regularExpression) == nil else { return nil }
        return s
    }

    /// 把主題接回追問：「電話」＋「哪一年」→「電話是哪一年發明的」；「綠豆湯」＋「要煮多久」→「綠豆湯要煮多久」
    static func combineFollowUp(topic: String, previous: String, message: String) -> String {
        var ask = Talk.clean(message).replacingOccurrences(of: "^(那麼|那|所以|然後)", with: "", options: .regularExpression)
        ask = ask.replacingOccurrences(of: "^(他|她|它|牠)", with: "", options: .regularExpression)
        // 好消息（考上、升職、結婚）之後的「要怎麼慶祝」：給慶祝的點子；生日有自己的過法
        if ask.contains("慶祝"), !topic.contains("生日") { return "我要怎麼慶祝" }
        // 「聖誕節」＋「還有幾天」→「距離聖誕節還有幾天」
        if ask.range(of: "^(還有|還要|再)(幾天|多久|多少天)$", options: .regularExpression) != nil { return "距離" + topic + "還有幾天" }
        if ask.range(of: "^(是)?(哪一年|哪年|什麼時候|幾年)$", options: .regularExpression) != nil,
           let v = RuleBook.match(previous, "(發明|創立|成立|建造|蓋|寫|發現|拍|唱)")?.first {
            return topic + "是哪一年" + v + "的"
        }
        return topic + ask
    }

    static func fromPrevious(_ raw: String, answer: String) -> String? {
        let t = Talk.clean(raw)
        // 在問我自己的事（「你會日文嗎」）不是在問剛剛的回答
        guard (2...16).contains(t.count), answer.count >= 10, !t.contains("你") else { return nil }
        let asks = EchoEngine.isQuestion(raw) || t.hasSuffix("嗎") || t.hasSuffix("呢")
            || ["要不要", "可不可以", "會不會", "多久", "多少", "幾"].contains(where: { t.contains($0) })
            || (t.hasPrefix("是") && t.count <= 10)   // 「是Windows」：補充是哪一種
        guard asks else { return nil }
        // 問句裡真正在問的東西
        var core = t
        // 「要多少錢」「要錢嗎」：找剛剛說到費用的那段
        if t.range(of: "多少錢|要錢嗎|收費|費用|價錢|要花多少|免費嗎|要付錢", options: .regularExpression) != nil, t.count <= 10,
           let c = answer.components(separatedBy: CharacterSet(charactersIn: "。；\n")).first(where: { $0.range(of: "[0-9０-９]+ ?(元|塊)|免費|工本費|費用", options: .regularExpression) != nil }) {
            let clause = c.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"^([0-9]+\.|⚠️|小提醒：)\s*"#, with: "", options: .regularExpression)
            return clause + (clause.hasSuffix("）") ? "" : "。")
        }
        let parts = answer.components(separatedBy: CharacterSet(charactersIn: "。；\n")).map {
            $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"^([0-9]+\.|・|•|⚠️|小提醒：)\s*"#, with: "", options: .regularExpression)
        }.filter { $0.count >= 4 }
        // 「要煮多久」「要滷多久」：找剛剛說到時間的那一步（有那個動作的優先）
        // （「要多久才學得會」問的是要練多久才會，不是做法裡某一步要幾分鐘）
        if t.range(of: "多久|幾分鐘|幾小時|幾個小時|要多長", options: .regularExpression) != nil, t.count <= 8,
           t.range(of: "才會|才能|學得會|學會|才可以|進步|上手", options: .regularExpression) == nil {
            let timed = parts.filter { $0.range(of: #"[0-9０-９]+ ?(到 ?[0-9]+ ?)?(分鐘|小時|秒)"#, options: .regularExpression) != nil }
            let cook = "[煮滷蒸烤炸煎燉炒泡燙醃燜]"
            let verb = t.range(of: cook + "|[冰放曬洗]", options: .regularExpression).map { String(t[$0]) }
            // 「要滷多久」：做法裡寫的是「小火燉 40 分鐘」也算
            if let c = timed.first(where: { verb != nil && $0.contains(verb!) })
                ?? (verb != nil && verb!.range(of: cook, options: .regularExpression) != nil ? timed.first(where: { $0.range(of: cook, options: .regularExpression) != nil }) : nil)
                ?? (verb == nil ? timed.first : nil) { return "大概是這樣：" + c + "。" }
        }
        // 「還有幾天」：剛剛的回答裡已經算好「還有 38 天」
        if t.range(of: "^(那)?(還有|還要|再)(幾天|多久|多少天)$", options: .regularExpression) != nil,
           let c = parts.first(where: { $0.range(of: "還有 ?[0-9]+ ?天", options: .regularExpression) != nil }) { return c + "。" }
        // 「水要幾度」：找說到溫度的那一步
        if t.contains("幾度"), let c = parts.first(where: { $0.range(of: #"[0-9]+ ?(到 ?[0-9]+ ?)?(度|°C)"#, options: .regularExpression) != nil }) { return c + "。" }
        // 「可以吃什麼」「要帶什麼」：找說到那個動作的那一步
        if let g = RuleBook.match(t, "^(?:那)?(?:要|可以|需要|該)?(吃|喝|穿|帶|買|準備)(?:什麼|哪些)(?:東西)?$"), let c = parts.first(where: { $0.contains(g[0]) }) { return c + "。" }
        // 「那要打給誰」「電話幾號」：找剛剛說到的電話、專線
        if t.range(of: "打給誰|打幾號|電話幾號|電話多少|什麼電話|聯絡誰|要打電話|專線", options: .regularExpression) != nil, t.count <= 10,
           let c = answer.components(separatedBy: CharacterSet(charactersIn: "。；\n")).first(where: { $0.range(of: "[0-9]{3,}|[0-9]{2,}-[0-9]{3,}", options: .regularExpression) != nil && $0.range(of: "打|電話|專線|客服", options: .regularExpression) != nil }) {
            let clause = c.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"^([0-9]+\.|⚠️|小提醒：)\s*"#, with: "", options: .regularExpression)
            return clause + (clause.hasSuffix("）") ? "" : "。")
        }
        for w in ["那麼", "那", "請問", "所以", "大概", "大約", "需要", "要不要", "可不可以", "會不會", "能不能", "可以", "應該", "要", "會", "能", "該", "辦", "申請", "去", "到", "一直", "如果", "多大", "多高", "多遠",
                  "多久", "多少", "多長", "幾分鐘", "幾小時", "幾個小時", "幾天", "幾個", "幾", "什麼", "怎麼", "如何", "哪裡", "哪個", "嗎", "呢", "啊", "是",
                  "有", "的", "搭", "坐", "用", "加", "放", "吃", "我", "你", "一定", "還", "也", "時間", "要花"] {
            core = core.replacingOccurrences(of: w, with: "")
        }
        guard !core.isEmpty, core.count <= 8 else { return nil }
        // 「要看醫生嗎」：找剛剛說什麼時候要就醫的那段
        if core.contains("醫"), let c = answer.components(separatedBy: CharacterSet(charactersIn: "。；\n")).first(where: { $0.contains("醫") }) {
            let clause = c.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"^([0-9]+\.|⚠️|小提醒：)\s*"#, with: "", options: .regularExpression)
            return (t.hasPrefix("要") || t.hasPrefix("需要") ? "可以這樣判斷：" : "") + clause + "。"
        }
        // 問數量（多久、多少、幾）：找到的那段要有數字
        let wantsNumber = ["多久", "多少", "多長", "多遠", "多高", "多大", "幾"].contains(where: { t.contains($0) })
        // 「要放多少」：「一點」「少許」「1 小匙」也算是份量
        let amountWords = "一點|少許|適量|一小匙|一大匙|小匙|大匙|一匙|半匙|一小撮|一撮"
        let singleOK: Set<String> = ["糖", "鹽", "油", "蛋", "蔥", "蒜", "薑", "酒", "醋", "水", "冰", "奶", "肉", "魚", "蝦", "米", "麵", "湯", "茶", "醬"]
        let clauses = answer.components(separatedBy: CharacterSet(charactersIn: "。；\n"))
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"^([0-9]+\.|・|•)\s*"#, with: "", options: .regularExpression) }
            .filter { $0.count >= 4 }
        // 說法不一樣但意思一樣（「要報警嗎」↔ 回答裡的「到警察局報案」）
        let same: [String: [String]] = ["報警": ["報案", "警察"], "警察": ["報案", "報警"], "看醫生": ["就醫", "醫生"], "重灌": ["重新安裝", "重灌"],
                                        "打電話": ["電話", "打給"], "叫救護車": ["119", "救護車"], "退錢": ["退款", "退費"], "找誰": ["師傅", "專業的人", "醫生", "客服"]]
        for (k, alts) in same where core.contains(k) {
            if let c = clauses.first(where: { c in alts.contains { c.contains($0) } }) {
                let lead = t.hasPrefix("要") && t.hasSuffix("嗎") ? "要，" : (t.hasPrefix("可以") && t.hasSuffix("嗎") ? "可以，" : "")
                return lead + c + (c.hasSuffix("）") || c.hasSuffix("」") ? "" : "。")
            }
        }
        let chars = Array(core)
        for len in stride(from: min(chars.count, 6), through: 1, by: -1) {
            // 問的東西大部分都要對得上（「台北人口多少」只對到「台北」不算）
            guard Double(len) / Double(chars.count) >= 0.75 else { break }
            for i in 0...(chars.count - len) {
                let piece = String(chars[i..<(i + len)])
                if len == 1, !singleOK.contains(piece) { continue }
                if let c = clauses.first(where: { $0.replacingOccurrences(of: " ", with: "").contains(piece) && (!wantsNumber || $0.contains(where: { $0.isNumber }) || $0.range(of: amountWords, options: .regularExpression) != nil) }) {
                    let lead = t.hasPrefix("要") && t.hasSuffix("嗎") ? "要，" : (t.hasPrefix("可以") && t.hasSuffix("嗎") ? "可以，" : "")
                    return lead + c + (c.hasSuffix("）") || c.hasSuffix("」") ? "" : "。")
                }
            }
        }
        return nil
    }

    /// 追問本地剛回答的東西
    func localFollowUp(_ message: String, _ lc: LocalContext) -> LocalFollow? {
        let t = Talk.clean(message)
        switch lc.kind {
        case "寫作":
            // 「寫給媽媽的」：剛剛寫了生日祝福，換成寫給某個人
            if let g = RuleBook.match(t, #"^(?:那|幫我)?(?:寫|改成|換成)?(?:給|送給)(.{1,6}?)(?:的)?(?:呢)?$"#), lc.subject.contains("生日") {
                return .rewrite("幫我寫給\(g[0])的生日祝福")
            }
        case "笑話", "選擇", "自己", "看法":
            return Talk.followUp(message, kind: lc.kind, last: lc.answer, name: lc.subject).map { .answer($0) }
        case "list":
            if let a = Library.listFollowUp(message, list: lc.subject) { return .answer(a) }
            // 「日本的景點」之後問「人口多少」「首都是哪裡」：問的是那個地方
            if let g = RuleBook.match(lc.subject, #"^(.{2,6}?)(?:的)?(?:景點|美食|小吃|夜市|名產|好玩的地方)$"#),
               Commonsense.facts.contains(where: { ["國家", "城市", "地標"].contains($0.kind) && $0.names.contains(g[0]) }),
               t.count <= 10, t.range(of: "^(那)?(人口|面積|首都|貨幣|語言|天氣|氣候|時差|在哪|位置|有多大|說什麼|用什麼|冬天|夏天|幾點)", options: .regularExpression) != nil {
                return .rewrite(g[0] + t.replacingOccurrences(of: "^(那|那麼)", with: "", options: .regularExpression))
            }
            return nil
        case "author":
            // 「他還寫了什麼」「她是哪裡人」「作者是誰」：代名詞換成作者
            guard !lc.extra.isEmpty, t.count <= 16 else { return nil }
            if t.hasPrefix("他") || t.hasPrefix("她") || t.hasPrefix("作者") || t.hasPrefix("這個作者") {
                var s = t
                for p in ["這個作者", "作者", "他", "她"] where s.hasPrefix(p) { s.removeFirst(p.count); break }
                let name = lc.extra.replacingOccurrences(of: #"^.*?的"#, with: "", options: .regularExpression)
                return .rewrite(name + s)
            }
        case "work":
            // 「結局呢」「主題是什麼」「誰寫的」：補上書名
            if let g = RuleBook.match(t, #"^(?:那|它|這部|這本|這個)?(?:的)?(結局|主題|故事|劇情|內容|作者|導演|想表達什麼|主角)(?:是什麼|是誰|呢)?$"#) {
                return .rewrite("\(lc.subject)的\(g[0])" + (["作者", "導演", "主角"].contains(g[0]) ? "是誰" : ""))
            }
            if t.range(of: "^(誰寫的|是誰寫的|誰拍的|是誰拍的|作者是誰)$", options: .regularExpression) != nil { return .rewrite("\(lc.subject)的作者是誰") }
        case "smalltalk":
            if lc.subject.hasPrefix("旅行:") {
                let abroad = Talk.isAbroad(String(lc.subject.dropFirst(3)))
                if abroad, t.range(of: #"(要|該)?(帶|換)多少(錢|現金)"#, options: .regularExpression) != nil { return .rewrite("出國要換多少錢") }
                if t.range(of: #"^(要)?(帶|準備)(什麼|哪些)"#, options: .regularExpression) != nil { return .rewrite(abroad ? "出國要帶什麼" : String(lc.subject.dropFirst(3)) + "要帶什麼") }
                if t.range(of: #"(要|需要)簽證"#, options: .regularExpression) != nil { return .rewrite(String(lc.subject.dropFirst(3)) + "要簽證嗎") }
                if t.range(of: #"^(有)?(什麼|哪些)好玩"#, options: .regularExpression) != nil { return .rewrite(String(lc.subject.dropFirst(3)) + "有什麼好玩的") }
                // 「有什麼好吃的」「要住哪裡」「怎麼去」：補上那個地方
                let place = String(lc.subject.dropFirst(3))
                if t.count <= 10, !t.contains(place), EchoEngine.isQuestion(message) || t.hasSuffix("嗎"),
                   t.range(of: "好吃|美食|小吃|住|飯店|民宿|怎麼去|交通|天氣|景點|夜市|伴手禮|名產|好逛|要玩幾天|幾天", options: .regularExpression) != nil {
                    return .rewrite(place + t)
                }
            }
            // 「我跟朋友吵架」→「她說我很自私」：接住、請對方多說
            if lc.subject == "吵架", (2...14).contains(t.count), !EchoEngine.isQuestion(message), Talk.chat(message) == nil,
               ![.sad, .grief, .angry, .anxious, .lonely, .tired, .crisis, .frustrated].contains(Affect.detect(message)) {
                let lines = ["聽到這種話一定很受傷。你覺得對方為什麼會這樣說？是因為某件事嗎？", "嗯，我在聽。你心裡的委屈是真的，不用急著分對錯。",
                             "我懂，換作是我也會很難受。等你們都冷靜一點，再好好說說彼此的感受，好嗎？"]
                EchoEngine.chatRotation += 1
                return .answer(lines[EchoEngine.chatRotation % lines.count])
            }
            // 「我想喝咖啡」→「可是已經晚上了」「那喝什麼好」
            if lc.subject.hasPrefix("喝:"), ["咖啡", "茶", "奶茶", "紅茶", "綠茶", "珍奶", "可樂", "拿鐵", "美式"].contains(where: { lc.subject.contains($0) }) {
                if t.range(of: "晚上|太晚|很晚|睡不著|要睡了|快睡了|睡前", options: .regularExpression) != nil || t.range(of: "喝什麼", options: .regularExpression) != nil {
                    return .answer("晚上喝咖啡、茶可能會睡不著，咖啡因要 5 到 6 個小時才會代謝掉一半。想喝點熱的，可以改成低咖啡因咖啡、熱牛奶、麥茶、黑豆水，或洋甘菊這類花草茶，暖暖的又比較好睡。")
                }
            }
            // 「我在學日文」→「有什麼方法」：怎麼學日文
            if lc.subject.hasPrefix("學:"), t.range(of: #"^(那)?(要)?(有什麼|有沒有)?(方法|技巧|建議|訣竅|撇步)(嗎)?$|^(要)?(怎麼|如何)(學|練|開始|進步)(比較好|才會進步)?$"#, options: .regularExpression) != nil {
                return .rewrite("怎麼學" + lc.subject.dropFirst(2))
            }
            if !EchoEngine.isQuestion(message), !EchoEngine.fortuneIntent(message), let a = Talk.chatAnswer(message, topic: lc.subject) { return .answer(a) }
        case "猜數字":
            if t.range(of: "不玩|結束|算了|放棄|不想玩|答案是什麼|答案是多少|告訴我答案|公布答案", options: .regularExpression) != nil {
                lastLocal = nil
                return .answer("答案是 \(lc.subject)！下次再玩～想再挑戰就說「猜數字」。")
            }
            let digits = t.filter { $0.isASCII && $0.isNumber }
            if !digits.isEmpty, t.count <= 8, let g = Int(digits), let n = Int(lc.subject) {
                let parts = lc.extra.split(separator: ",").compactMap { Int($0) }
                var lo = parts.first ?? 1, hi = parts.last ?? 100
                let tries = (Int(lc.shown) ?? 0) + 1
                if g == n {
                    lastLocal = nil
                    return .answer("答對了！就是 \(n)！🎉 你猜了 \(tries) 次\(tries <= 7 ? "，很厲害！" : "。")要再玩一次嗎？說「猜數字」就可以。")
                }
                if g < lo || g > hi { return .answer("答案在 \(lo) 到 \(hi) 之間喔，再猜一次～") }
                if g < n { lo = g + 1 } else { hi = g - 1 }
                lastLocal = LocalContext(kind: "猜數字", subject: lc.subject, extra: "\(lo),\(hi)", shown: "\(tries)", turn: lc.turn + 2)
                return .answer(g < n ? "再大一點！（\(lo) 到 \(hi) 之間）" : "再小一點！（\(lo) 到 \(hi) 之間）")
            }
        case "猜拳":
            if t.range(of: "不玩|結束|算了|不想玩", options: .regularExpression) != nil { lastLocal = nil; return .answer("好，不玩了～想再玩隨時說「猜拳」。") }
            let hands = ["剪刀", "石頭", "布"]
            if t.count <= 6, let mine = hands.first(where: { t.contains($0) }) ?? (t.contains("✌") ? "剪刀" : t.contains("✊") ? "石頭" : t.contains("🖐") ? "布" : nil) {
                let me = hands.randomElement()!
                let icon = ["剪刀": "✌️", "石頭": "✊", "布": "🖐"]
                let beats = ["剪刀": "布", "石頭": "剪刀", "布": "石頭"]
                let result = me == mine ? "平手！再來一次？" : beats[mine] == me ? "你贏了！🎉 再來一局？" : "我贏了！😆 再來一局？"
                lastLocal = LocalContext(kind: "猜拳", turn: lc.turn + 2)
                return .answer("你出\(icon[mine]!)\(mine)，我出\(icon[me]!)\(me)——\(result)（不玩了可以說「不玩了」）")
            }
        case "接龍":
            let w = t.filter { !"「」".contains($0) }
            if t.range(of: "輸了|認輸|你贏了|想不到|接不下去", options: .regularExpression) != nil, let last = lc.subject.last {
                lastLocal = nil
                let hint = Idioms.chain(from: last, avoid: Set(lc.extra.components(separatedBy: ","))).map { "，像「\($0.idiom)」" } ?? ""
                return .answer("沒關係，能接到這裡已經很厲害了！「\(last)」開頭的成語\(hint.isEmpty ? "真的很難" : "可以接" + hint.dropFirst())。想再玩隨時說「成語接龍」😄")
            }
            if w.count == 4, let last = lc.subject.last {
                guard w.first == last else { return .answer("「\(w)」不是「\(last)」開頭喔～再想一個「\(last)」開頭的成語？（不玩了可以說「不玩了」）") }
                let used = Set(lc.extra.components(separatedBy: ",")).union([w])
                if let e = Idioms.chain(from: w.last!, avoid: used) {
                    lastLocal = LocalContext(kind: "接龍", subject: e.idiom, extra: lc.extra + "," + w + "," + e.idiom, turn: lc.turn + 2)
                    let praise = Idioms.chainKnown.contains(w) ? "接得好！" : "好，「\(w)」！"
                    return .answer("\(praise)我接「\(e.idiom)」\(e.meaning.isEmpty ? "" : "（\(e.meaning)）")。\n換你接「\(e.idiom.last!)」開頭的！")
                }
                lastLocal = nil
                return .answer("「\(w)」接得好！我想不到「\(w.last!)」開頭的成語了，你贏了 🎉 要再玩一次嗎？說「成語接龍」就可以。")
            }
            if t.range(of: "不玩|結束|算了|不想玩|換別的", options: .regularExpression) != nil { lastLocal = nil; return .answer("好，不玩了～你很厲害！想再玩隨時說「成語接龍」。") }
        case "fact":
            // 「你最喜歡哪一首」（剛剛在聊周杰倫）：從代表作挑一個
            if RuleBook.match(t, #"^(?:那)?你(?:最)?喜歡(?:哪一首|哪首|哪一部|哪部|哪一本|哪本|哪一個|哪個|哪一幅|哪幅)(?:歌|電影|書|作品)?$"#) != nil,
               let e = Commonsense.facts.first(where: { $0.name == lc.subject }), let works = e.attr("代表作"),
               let w = RuleBook.match(works, #"([〈《][^〉》]{1,20}[〉》])"#)?[0] {
                return .answer("如果要我選，我最喜歡\(w)！每次聽到都覺得很有感覺。你呢？你最喜歡哪一個？")
            }
            // 「你覺得呢」：主角有我的看法就說
            if t.range(of: #"^(那)?你(覺得|覺得呢|覺得怎麼樣|覺得如何|的看法|的看法呢|怎麼看|怎麼想)$"#, options: .regularExpression) != nil,
               let e = Commonsense.facts.first(where: { $0.name == lc.subject }), let v = e.attr("看法") {
                return .answer("我的看法：" + v + "。")
            }
            // 做法清單之後的「最重要的是哪一個」「你覺得呢」「先做哪個」：說第一點，有看法再補上看法
            let listItems = lc.answer.split(separator: "\n").map(String.init).filter { $0.range(of: #"^[0-9]+\. "#, options: .regularExpression) != nil }
                .map { $0.replacingOccurrences(of: #"^[0-9]+\. "#, with: "", options: .regularExpression) }
            let opinion = lc.answer.split(separator: "\n").map(String.init).last(where: { l in
                !l.isEmpty && l.range(of: #"^[0-9]+\. |^小提醒|^⚠️|可以這樣|：$"#, options: .regularExpression) == nil && l.count >= 10 })
            if !listItems.isEmpty,
               t.range(of: #"^(那)?(最重要|最關鍵|最有用|最有效|最推薦|最優先|最需要)(的)?(是)?(哪一個|哪個|哪一點|哪點|什麼|哪一步|哪步)?(呢)?$|^(那)?(要)?(先做哪一個|先做哪個|先從哪裡開始|先做什麼|從哪一個開始|從哪個開始|從哪裡開始|從哪開始|第一步是什麼|第一步要做什麼|第一步)(呢)?$|^(那)?你(覺得|覺得呢|覺得怎麼樣|覺得如何|的看法|的看法呢|怎麼看|推薦哪個|推薦哪一個)$"#, options: .regularExpression) != nil {
                var a = "我覺得最值得先做的是第一點：\(listItems[0])。"
                if let o = opinion, !o.hasPrefix(listItems[0]) { a += "\n" + o }
                return .answer(a)
            }
            // 做法清單之後的「要怎麼教」「那要怎麼做」：做法就是剛剛那幾步，先從前兩點開始（不要拿整句去上網查）
            if listItems.count >= 2,
               t.range(of: #"^(那|所以)?(我)?(要|該|應該)?(怎麼|如何)(教|做|處理|辦|改善|訓練|開始|執行|進行)(牠|他|她|它)?(呢|啊|才好|比較好)?$"#, options: .regularExpression) != nil {
                return .answer("就是剛剛那幾步，可以先從前兩點開始：\n1. \(listItems[0])\n2. \(listItems[1])\n每天有耐心地做，有新的狀況再跟我說。")
            }
            // 「舉個例子」：剛剛的回答裡有「例如…」「像…」就拿出來
            if t.range(of: #"^(可以|能)?(舉個?|舉一個|給我一個|有沒有)(例子|例)(嗎|呢)?$|^(例子呢|比如說呢|比如呢|像是什麼)$"#, options: .regularExpression) != nil, !lc.answer.isEmpty {
                let parts = lc.answer.components(separatedBy: CharacterSet(charactersIn: "。；\n")).map { $0.trimmingCharacters(in: .whitespaces) }
                if let ex = parts.first(where: { $0.contains("例如") || $0.hasPrefix("像") || $0.contains("例句") || $0.contains("比如") }) {
                    return .answer("舉個例子：" + ex.replacingOccurrences(of: #"^.*?(例如|比如)[，：]?"#, with: "", options: .regularExpression) + "。")
                }
                // 「比特幣就是建立在區塊鏈上」：說某個具體的東西「就是」這樣的那一句
                if let ex = parts.dropFirst().first(where: { p in p.range(of: #"^\S{2,8}?就是"#, options: .regularExpression) != nil }) {
                    return .answer("舉個例子：" + ex + "。")
                }
                if let ex = parts.first(where: { $0.contains("，像") || ($0.contains("：") && $0.contains("、")) }), let r = ex.range(of: "，像") ?? ex.range(of: "：") {
                    return .answer("舉個例子：" + ex[r.upperBound...] + "。")
                }
                if let e = Commonsense.facts.first(where: { $0.name == lc.subject }), let ex = e.attr("例子") { return .answer("舉個例子：" + ex + "。") }
                return lc.subject.isEmpty ? nil : .rewrite(lc.subject + "的例子")
            }
            // 「為什麼」「為什麼不行」：剛剛的回答裡已經有原因（「不會。企鵝不會飛。企鵝的翅膀演化成…」）→ 把原因說出來
            // 「那要放多少」（上一題「番茄炒蛋要放糖嗎」）：找做法裡講到那樣東西的那一句
            if t.range(of: #"^(那)?(要)?(放|加)?(多少|幾匙|幾克|多少克|多少量|多少才夠)(呢)?$"#, options: .regularExpression) != nil,
               let g = RuleBook.match(lc.extra, #"^.{2,8}?(?:要不要|要|可以|需要|該|能)(?:放|加)(.{1,4}?)(?:嗎|呢)?$"#),
               let line = lc.answer.components(separatedBy: CharacterSet(charactersIn: "。；\n")).first(where: { $0.contains(g[0]) && !$0.hasPrefix("要，") }) ?? lc.answer.components(separatedBy: CharacterSet(charactersIn: "。；\n")).first(where: { $0.contains(g[0]) }) {
                let clean = line.replacingOccurrences(of: #"^(要，|[0-9]+\.\s*)"#, with: "", options: .regularExpression)
                return .answer("份量大概是：\(clean)。照自己的口味加減就好。")
            }
            // 做法清單之後只問「為什麼」：清單裡的每一點不是原因，不要拿第一點當「因為」
            if !listItems.isEmpty, t.range(of: #"^(那)?(為什麼|為何|為啥|怎麼說)(要這樣|呢)?$"#, options: .regularExpression) != nil {
                if let o = opinion, o.count >= 10 { return .answer(o.hasSuffix("。") ? o : o + "。") }
                return .answer("這幾點是一般比較安全、有效的做法。想知道其中哪一點的原因，跟我說是第幾點；或說「說詳細一點」，我上網幫你找更完整的資料。")
            }
            if t.range(of: #"^(那)?(為什麼|為何|為啥|怎麼說|怎麼會)(不是|不行|不會|不能|會|是|這樣|呢)?$"#, options: .regularExpression) != nil, !lc.answer.isEmpty {
                let parts = lc.answer.components(separatedBy: CharacterSet(charactersIn: "。\n")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let head = parts.first ?? ""
                let reasons = parts.dropFirst().filter { !$0.hasPrefix(lc.subject + "不") || $0.count > 12 }.filter { $0 != head && !["不會", "不是", "不可以！", "是的", "會！"].contains($0) }
                if let why = reasons.first(where: { $0.count >= 8 && !($0.hasPrefix(lc.subject) && $0.count < 14) }) {
                    return .answer("因為\(why)。")
                }
                // 主角自己有解釋，關鍵詞出現在剛剛的回答裡（「天空是什麼顏色」→ 藍色 →「為什麼」）
                if let e = Commonsense.facts.first(where: { $0.name == lc.subject }) {
                    var best: (Int, String)?
                    for w in e.whys { for k in w.keys where k.count >= 1 && lc.answer.contains(k) && k.count > (best?.0 ?? 0) { best = (k.count, w.text) } }
                    if let b = best { return .answer(b.1 + "。") }
                }
                // 剛剛的回答裡有「因為…」
                if let r = lc.answer.range(of: "因為") {
                    let tail = String(lc.answer[r.lowerBound...].prefix { !"。\n".contains($0) })
                    if tail.count >= 6 { return .answer(tail + "。") }
                }
            }
            // 「試過重開了」「還是很卡」：剛剛的方法試過沒用 → 下一步
            if lc.answer.contains("\n1. "), t.count <= 12,
               t.range(of: #"^(我)?(都)?(試過了|試過|做過了|都試過了|重開了|重開過了|試過重開了|試過重開|還是一樣|還是不行|還是很.{1,4}|沒有用|沒用|沒效|都沒用|還是沒用|還是沒好|還是沒辦法)"#, options: .regularExpression) != nil {
                return .answer("那些方法都試過還是不行的話，可能是比較根本的問題了：建議找專業的人實際看看（像原廠維修、醫生、獸醫或客服），他們能檢查到我看不到的地方。也可以跟我說「說詳細一點」，我上網幫你找更多方法。")
            }
            // 「已經兩天了」：剛剛的回答裡有什麼時候要看醫生
            if let g = RuleBook.match(t, #"^(?:已經|都|快)?([0-9一二兩三四五六七八九十幾半]+)(天|個禮拜|週|星期|個月|小時|個小時)(?:了)?(?:都)?(?:沒吃|沒好|還沒好|不吃|沒改善)?(?:了)?$"#),
               let c = lc.answer.components(separatedBy: CharacterSet(charactersIn: "。；\n")).first(where: { $0.contains("醫") }) {
                let clause = c.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"^([0-9]+\.|⚠️|小提醒：)\s*"#, with: "", options: .regularExpression)
                return .answer("已經\(g[0])\(g[1])了，建議不要再等：\(clause)。")
            }
            // 「那台中呢」（上一題「台北到高雄多遠」）：把上一題裡同一類的地方換掉
            let r0 = message.trimmingCharacters(in: .whitespacesAndNewlines).filter { !"？?。！!～~ ".contains($0) }
            if !lc.extra.isEmpty, let g = RuleBook.match(r0, #"^(?:那|那麼)?(.{1,8}?)(?:呢|的話呢|的話)$"#) {
                let x = g[0]
                let placeKinds: Set<String> = ["城市", "國家", "地標", "動物"]
                let places = Commonsense.facts.filter { placeKinds.contains($0.kind) }
                if let xe = places.first(where: { $0.names.contains(x) }) {
                    var best: (Range<String.Index>, Int)?
                    for e in places where e.kind == xe.kind || (!["國家", "動物"].contains(e.kind) && !["國家", "動物"].contains(xe.kind)) {
                        for n in e.names where n.count >= 2 && n != x && !x.contains(n) {
                            guard let r = lc.extra.range(of: n, options: .backwards) else { continue }
                            if best == nil || r.lowerBound > best!.0.lowerBound || (r.lowerBound == best!.0.lowerBound && n.count > best!.1) { best = (r, n.count) }
                        }
                    }
                    if let (r, _) = best {
                        var q = lc.extra
                        q.replaceSubrange(r, with: x)
                        if Commonsense.answer(q) != nil { return .rewrite(q) }
                    }
                }
                // 「那喪禮呢」（上一題「結婚要包多少」）：把上一題開頭的主題換掉，換完自己答得出來才算
                if (2...6).contains(x.count), !EchoEngine.isQuestion(x),
                   let head = RuleBook.match(lc.extra, #"^(.{2,6}?)(?:要|可以|能|該|是|有|會|怎麼|多少|幾|的)"#)?[0], head != x, !x.contains(head) {
                    let q = x + lc.extra.dropFirst(head.count)
                    if Commonsense.answer(q) != nil || Fuzzy.match(q) != nil { return .rewrite(q) }
                }
            }
            // 「誰比較大」「哪個比較高」：比剛剛問的兩個東西
            if !lc.shown.isEmpty, let g = RuleBook.match(t, #"^(?:那)?(?:誰|哪個|哪一個|哪裡|哪國)(?:比較)?(大|小|高|矮|長|短|多|少|重|輕|遠|近|快|慢)$"#),
               let a = Commonsense.compareNumbers("\(lc.subject)比\(lc.shown)\(g[0])嗎") {
                return .answer(a)
            }
            if t.range(of: #"^(還有呢|還有嗎|還有別的嗎|還有其他的嗎|然後呢|就這樣嗎|只有這樣嗎|還有沒有)$"#, options: .regularExpression) != nil {
                return .answer("我知道的重點大概就是這些了。想知道更多，跟我說「說詳細一點」，我上網幫你找更完整的資料。")
            }
            // 「我想學日文」→「有推薦的app嗎」：學什麼的推薦
            if let g = RuleBook.match(t, #"(?:推薦|有什麼|有沒有|哪些|什麼)(?:的|好用的|好的)?(app|App|APP|應用程式|書|教材|課程|網站|頻道|YouTube|youtube)"#) {
                let base = lc.subject.hasPrefix("學") ? lc.subject : (Commonsense.howtoMentioned(lc.extra) ?? "")
                if base.hasPrefix("學") {
                    let thing = ["app", "App", "APP", "應用程式"].contains(g[0]) ? "app" : g[0]
                    let q = base + "推薦" + thing
                    if Commonsense.answer(q) != nil { return .rewrite(q) }
                }
            }
            // 剛剛聊到要去哪裡玩（「我想去日本玩」→「要帶多少錢」→「要簽證嗎」）：補上那個地方
            if let tr = lastTravel, lc.turn - tr.turn <= 6, t.count <= 12,
               t.range(of: "^(那裡|那邊|當地|那)?(要|需要|有|會|可以|用|說|時差|天氣|物價|治安|小費|插座|插頭|電壓|安全|什麼|哪裡|好玩|好吃)", options: .regularExpression) != nil,
               t.range(of: "簽證|好玩|景點|貨幣|用什麼錢|語言|說什麼話|時差|插座|插頭|電壓|好吃|美食|小費|天氣|治安|安全嗎|物價", options: .regularExpression) != nil,
               !Commonsense.facts.contains(where: { $0.kind == "國家" && $0.names.contains(where: { $0.count >= 2 && t.contains($0) }) }) {
                var q = t
                for p in ["那裡", "那邊", "當地", "那"] where q.hasPrefix(p) { q.removeFirst(p.count); break }
                return .rewrite(tr.place + q)
            }
            // 「人口多少」「說什麼語言」（上一題在問日本）、「那葡萄呢」（上一題「貓可以吃巧克力嗎」）：補上主題
            // 本身就是一個完整、自己答得出來的問題（「實支實付是什麼」）：不要跟上一題混在一起
            let selfContained = Commonsense.answer(message) != nil && t.count >= 4 && t.range(of: "^(那|那麼|所以|還有)", options: .regularExpression) == nil
            let f = Talk.detailed(message) == nil && !selfContained ? Commonsense.followUp(message, subject: lc.subject, previous: lc.extra) : nil
            if let f, f.local { return .rewrite(f.text) }
            // 「搭高鐵要多久」「要放糖嗎」「那台鐵呢」：剛剛的回答裡就有（問「X是什麼」而且自己答得出來的，直接回答 X）
            // 自己答得出來、又說了剛剛的回答裡沒有的東西（「台灣的夏天幾度」接在「為什麼會有四季」後面）：是新的問題，不從剛剛的回答裡找
            let newSubject = selfContained && Commonsense.realMentions(Everyday.clean(message), in: Commonsense.facts)
                .contains { !lc.answer.contains($0.alias) && !lc.answer.contains($0.entity.name) }
            if !(selfContained && t.range(of: "是什麼|什麼是|什麼意思", options: .regularExpression) != nil), !newSubject,
               let a = EchoEngine.fromPrevious(message, answer: lc.answer) { return .answer(a) }
            // 食譜：「可以加洋蔥嗎」——剛剛的做法裡沒有，也可以照自己的口味加
            if lc.answer.contains("的步驟"), let g = RuleBook.match(t, #"^(?:那)?(?:可以|能|要不要|可不可以|能不能)(?:加|放|用|加點|放點)(.{1,6}?)(?:嗎|呢)?$"#) {
                return .answer("可以呀！家常菜沒有標準答案，喜歡\(g[0])就加。比較硬、比較耐煮的食材先下鍋炒軟，再照原本的步驟做就好。")
            }
            if let c = composeWithRecent(message, now: Date()) { return .rewrite(c) }
            if let f { return .rewrite(f.text) }
        case "mood":
            // 「是Windows」「要看醫生嗎」：剛剛的回答裡就有
            if let a = EchoEngine.fromPrevious(message, answer: lc.answer) { return .answer(a) }
            // 「要怎麼辦」：照剛剛說的事給做法（「我失眠了」→ 失眠怎麼辦）
            if t.range(of: #"^(那|所以)?(我)?(要|該|應該)?(怎麼辦|怎麼做|如何是好|怎麼處理|怎麼解決|有什麼方法|有什麼辦法|有什麼建議)(呢|啊)?$"#, options: .regularExpression) != nil {
                let said = [lc.subject, lc.extra] + lc.shown.components(separatedBy: "\u{1}").reversed()
                for s0 in said where !s0.isEmpty {
                    let base = s0.replacingOccurrences(of: #"[啦啊喔耶。！!～~]+$"#, with: "", options: .regularExpression)
                    for ask in [base + "怎麼辦", base.replacingOccurrences(of: #"了$"#, with: "", options: .regularExpression) + "怎麼辦"] where Commonsense.answer(ask) != nil {
                        return .rewrite(ask)
                    }
                }
                if let h = Commonsense.howtoMentioned(said.joined(separator: "，")) { return .rewrite(h + "怎麼辦") }
                return .answer(EchoEngine.copingSteps)
            }
            // 「因為報告寫錯」：在說原因，接住它
            if let g = RuleBook.match(t, #"^(?:因為|就是|原因是|主要是)(.{2,30})$"#), !EchoEngine.isQuestion(message) {
                let why = g[0].replacingOccurrences(of: "我", with: "你")
                return .answer("原來是\(why)。會這麼在意，代表你很認真看待這件事，不是你不夠好。想聽聽我的建議，還是先讓我陪你說說？")
            }
            // 「不知道為什麼」：說不出原因
            if t.range(of: #"^(我)?(也|就是)?(不知道|說不上來|不曉得)(為什麼|原因|怎麼了|耶|欸|啦)?$"#, options: .regularExpression) != nil {
                return .answer("沒關係，說不出原因的時候反而更難受。先不用急著找答案，我們先讓身體放鬆一點：慢慢吸氣、再慢慢吐氣，做幾次。最近生活有沒有什麼變化，或一直壓在心上的事？想到什麼都可以跟我說。如果這種感覺持續很久、影響到睡眠和生活，也可以找身心科或心理師聊聊。")
            }
            // 擔心家人（「我爸住院了」→「心臟的問題」）：接住擔心，問對方的狀況
            if nowTurn > 0, Affect.detect(lc.subject) == .worryOther, [.info, .worryOther].contains(Affect.detect(message)), (1...14).contains(t.count), !EchoEngine.isQuestion(message) {
                let n = lc.shown.components(separatedBy: "\u{1}").count
                let lines = ["一定很擔心吧。醫生怎麼說？", "你這麼在乎他，他一定感受得到。現在他的狀況穩定嗎？",
                             "照顧家人的同時，也別忘了照顧自己。你今天有好好吃飯嗎？", "會擔心很正常。有需要的話，可以問我「家人住院我能做什麼」，我們一起想。"]
                return .answer(lines[n % lines.count])
            }
            // 剛剛說考試考砸了，接著說科目（「數學」）
            if lc.subject.contains("考") || lc.extra.contains("考"), let a = Talk.examSubject(t) { return .answer(a) }
            // 補充細節（「主管很兇」「他昨天罵我」「數學」）：接住、換句話說、請對方多說——不要每句都一樣
            // 沒被問的時候，只接中性的補充（「同事也不幫我」）；自己帶著強烈心情的新句子（「越想越氣」）照心情回應
            if lastEchoAsked || (nowTurn > 0 && nowTurn - lc.turn <= 2 && Affect.detect(message) == .info), (1...12).contains(t.count), !EchoEngine.isQuestion(message), Talk.chat(message) == nil, Talk.detailed(message) == nil,
               // 開心的事（「我考上研究所了」→「台大」）交給回答我問題的那一段
               ![.goodNews, .proudEffort, .happy, .excitedPlan, .hope].contains(Affect.detect(lc.subject)),
               // 沒被問、自己就答得出來的（「睡不好」）照一般問題處理
               lastEchoAsked || Commonsense.answer(message) == nil,
               !t.contains("你"),
               // 帶著新的事件或心情（「剛剛奶奶住院了」「我考上了」）是新的話題，不是補充
               ![.grief, .sick, .worryOther, .goodNews, .crisis, .proudEffort, .excitedPlan, .happy, .hope, .thanks, .greeting, .farewell,
                 .praiseAI, .complainAI, .apology, .confused, .joke, .bored, .curious, .affection].contains(Affect.detect(message)),
               t.range(of: "^(謝謝|謝啦|好|嗯|喔|哦|對|沒事|算了|不用|好的|OK|ok|掰|晚安|早安)", options: .regularExpression) == nil,
               t.range(of: "^(幫我|幫忙|請|查|搜|給我|算|翻譯|寫|講|說|唱|推薦)|運勢|命盤|卦|規則|記住|[0-9０-９]", options: .regularExpression) == nil {
                let n = lc.shown.components(separatedBy: "\u{1}").count
                // 「我們在一起三年」：說了時間
                if let g = RuleBook.match(t, #"([0-9一二兩三四五六七八九十幾半]+)(年|個月)"#), t.contains("在一起") || t.contains("交往") || t.contains("認識") {
                    return .answer("\(g[0])\(g[1])真的不是一段短的時間，那麼多回憶，難怪會這麼痛。你現在最放不下的是什麼？")
                }
                let lines = ["原來是這樣……難怪你會這麼難受。", "嗯，我在聽。", "我懂，這真的不容易。", "聽起來真的很辛苦。"]
                let asks = ["後來呢？", "你那時候心裡怎麼想？", "現在感覺有好一點嗎？", "想聽聽我的建議嗎？跟我說「我該怎麼辦」就可以。"]
                return .answer(lines[n % lines.count] + asks[n % asks.count])
            }
        case "recommend":
            // 「你覺得呢」「你最推薦哪一個」：說最推薦的那一個
            if !lc.extra.isEmpty, t.range(of: #"^(那)?(你覺得呢|你覺得|你推薦哪個|你推薦哪一個|你最推薦哪一個|你最推薦哪個|哪一個最好|哪個最好|你選哪個|你會選哪個)(呢)?$"#, options: .regularExpression) != nil {
                return .answer("我最推薦的是\(lc.extra)" + (lc.extra.hasSuffix("。") ? "" : "。"))
            }
            // 「很好看」「超好聽」（不是問句）：在說推薦的東西很棒
            if t.range(of: #"^(真的|對啊)?(很|超|好|蠻|滿|真的很)(好看|好聽|好玩|好吃|讚|棒)(耶|欸|喔|啊|呀)?$"#, options: .regularExpression) != nil {
                return .answer("對吧！你最喜歡哪一個？想要類似的，跟我說「還有嗎」，我再推薦幾個。")
            }
            // 「這本在講什麼」「那部電影的內容是什麼」：問的是剛剛最推薦的那一個
            if let title = RuleBook.match(lc.extra, "《(.{1,20}?)》")?.first,
               t.range(of: #"^(那|所以)?(這|那|你說的那|你推薦的那)(本|部|首|個|齣|款)(書|電影|歌|片|劇|小說|動畫|遊戲)?(的)?(在)?(講|說|是|內容|故事|劇情|大綱)(什麼|啥|在講什麼|是什麼)?(的)?(呢|啊|嗎)?$"#, options: .regularExpression) != nil {
                return .rewrite(title + "在講什麼")
            }
            if !lc.extra.isEmpty, t.range(of: #"^(真的)?(好看|好聽|好玩|好吃|值得看|值得讀|推薦)(嗎)?$"#, options: .regularExpression) != nil {
                return .answer("真的推薦！我最推薦的是\(lc.extra)" + (lc.extra.hasSuffix("。") ? "" : "。"))
            }
            // 「還有呢」「還有別的嗎」「換幾個」：推薦剛剛沒講到的
            // 「要溫馨一點的」「適合跟家人看的」「想吃清淡的」「預算一百」：同一類裡換一種
            let refine: [(String, String)] = ["電影", "書", "動畫", "恐怖片", "愛情片", "動作片", "喜劇片", "溫馨電影", "家庭電影"].contains(lc.subject)
                ? [("溫馨", "溫馨電影"), ("感人", "溫馨電影"), ("療癒", "溫馨電影"), ("暖心", "溫馨電影"), ("家人", "家庭電影"), ("全家", "家庭電影"), ("小孩", "家庭電影"), ("闔家", "家庭電影"), ("爸媽", "家庭電影")]
                : (["晚餐", "早餐", "宵夜", "清淡晚餐", "不用煮的晚餐", "便宜晚餐"].contains(lc.subject)
                   ? [("清淡", "清淡晚餐"), ("不要辣", "清淡晚餐"), ("不辣", "清淡晚餐"), ("健康", "清淡晚餐"), ("不用煮", "不用煮的晚餐"), ("懶得煮", "不用煮的晚餐"), ("不想煮", "不用煮的晚餐"),
                      ("便宜", "便宜晚餐"), ("預算", "便宜晚餐"), ("省錢", "便宜晚餐"), ("一百", "便宜晚餐"), ("100", "便宜晚餐")]
                   : (["甜點", "健康甜點"].contains(lc.subject) ? [("健康", "健康甜點"), ("低卡", "健康甜點"), ("不會胖", "健康甜點"), ("不胖", "健康甜點"), ("少糖", "健康甜點"), ("無糖", "健康甜點")] : []))
            // 「周杰倫的」（剛剛推薦歌）：那個歌手的歌
            if ["音樂", "英文歌", "周杰倫的歌"].contains(lc.subject), let g = RuleBook.match(t, #"^(?:那)?(?:有沒有)?(.{1,8}?)的(?:歌)?(?:呢|嗎)?$"#),
               let a = Commonsense.answer("推薦" + g[0] + "的歌") {
                lastLocal = LocalContext(kind: "recommend", subject: g[0] + "的歌", extra: lc.extra, shown: a, turn: lc.turn)
                return .answer(a)
            }
            if t.count <= 16, let g = refine.first(where: { t.contains($0.0) }), let a = Commonsense.answer("推薦" + g.1) {
                lastLocal = LocalContext(kind: "recommend", subject: g.1, extra: lc.extra, shown: a, turn: lc.turn)
                return .answer(a)
            }
            if !lc.subject.isEmpty, t.range(of: #"^(我)?(都)?(看過了|讀過了|看過|讀過|聽過了|吃過了|玩過了|去過了)$|^換一(本|部|首|家|款|個)$"#, options: .regularExpression) != nil,
               let a = Commonsense.recommendMore(lc.subject, shown: lc.shown) {
                return .answer(a)
            }
            if !lc.subject.isEmpty, t.range(of: #"^(還有|還有呢|還有別的嗎|還有其他的嗎|還有嗎|有別的嗎|其他的呢|別的呢|換一個|換幾個|再推薦|再推薦幾個|再來幾個|再多一點|還有沒有)$"#, options: .regularExpression) != nil,
               let a = Commonsense.recommendMore(lc.subject, shown: lc.shown) {
                return .answer(a)
            }
            if let g = RuleBook.match(t, #"^(?:那|那麼|還有)?(電影|書|動畫|音樂|歌|遊戲|影集|電視劇|景點|運動|韓劇|日劇|英文歌|恐怖片|愛情片|動作片|喜劇片)(?:呢|的話呢|的話)?$"#) {
                return .rewrite("推薦" + g[0])
            }
            // 「有沒有好笑一點的」「恐怖的呢」：同一類裡換一種
            if lc.subject == "電影" || ["恐怖片", "愛情片", "動作片", "喜劇片"].contains(lc.subject) {
                let genres: [(String, String)] = [("好笑", "喜劇片"), ("搞笑", "喜劇片"), ("輕鬆", "喜劇片"), ("喜劇", "喜劇片"), ("恐怖", "恐怖片"), ("鬼", "恐怖片"),
                                                  ("驚悚", "恐怖片"), ("愛情", "愛情片"), ("浪漫", "愛情片"), ("甜", "愛情片"), ("動作", "動作片"), ("刺激", "動作片"), ("打鬥", "動作片")]
                if t.count <= 14, let g = genres.first(where: { t.contains($0.0) }) { return .rewrite("推薦" + g.1) }
            }
            if t.range(of: "^(為什麼|為何|為啥|怎麼說)(推薦)?(這部|這個|這本|這首|它|這)?$|^(那)?你(覺得呢|覺得怎麼樣|覺得哪個好|覺得哪個最好|推薦哪個|最推薦哪個|最推薦哪一個|會選哪個|選哪個|最喜歡哪個|最喜歡哪一個)$", options: .regularExpression) != nil, !lc.extra.isEmpty {
                return .answer("我最推薦的是\(lc.extra)")
            }
        default: break
        }
        return nil
    }

    /// 好消息的接話：照是什麼好消息問下去
    static func celebrate(_ t: String) -> String {
        if t.range(of: "考上|錄取|上榜|考過|通過|合格|畢業", options: .regularExpression) != nil { return "是哪裡、哪個科系？準備了多久？這一路一定不容易。" }
        if t.range(of: "升職|升官|加薪|拿到offer|找到工作|錄用", options: .regularExpression) != nil { return "新的工作內容是什麼？今天記得好好犒賞自己一下。" }
        if t.range(of: "在一起|交往|脫單|交到(男|女)朋友|求婚|訂婚|結婚", options: .regularExpression) != nil { return "你們是怎麼認識的？我想聽！" }
        if t.range(of: "中獎|中樂透|得獎|冠軍|第一名|滿分", options: .regularExpression) != nil { return "太厲害了！你打算怎麼慶祝？" }
        if t.range(of: "懷孕|生了|寶寶", options: .regularExpression) != nil { return "要好好照顧身體！是男生還是女生，還是要等驚喜？" }
        return "發生什麼好事了？說來聽聽，我想跟你一起開心。"
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
    public static func isQuestion(_ raw: String) -> Bool {
        let t = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = ["怎麼", "怎樣", "如何", "要不要", "該不該", "什麼", "為什麼", "哪", "可不可以", "能不能", "有沒有", "多少", "是不是",
                     "才能", "誰", "幾", "多遠", "多高", "多久", "多重", "多大", "多長", "多深", "how", "what", "why", "which", "who", "cómo", "qué", "por qué", "come", "cosa", "perché"]
        return words.contains { t.contains($0) } || t.hasSuffix("?") || t.hasSuffix("？") || t.hasSuffix("嗎") || t.hasSuffix("呢")
    }

    /// 有沒有要算運勢的意思（有的話交給命理；沒有的話是一般的實用問題）
    public static func fortuneIntent(_ text: String) -> Bool {
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
    public static func explicitSearch(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = t.lowercased()
        let prefixes = ["上網", "搜尋", "搜索", "查一下", "幫我查", "幫我搜", "幫我上網", "請上網", "請幫我查", "請幫我上網", "去網上", "網上查",
                        "search ", "search for ", "look up ", "busca ", "buscar ", "cerca "]
        let inside = ["上網查", "上網搜", "上網找", "網路上查", "網上查", "上網看看"]
        // 「你可以幫我查一下明天天氣嗎」：請我幫忙查，查的是後面那一段
        if let g = RuleBook.match(t.trimmingCharacters(in: CharacterSet(charactersIn: "？?。！! ")), #"^(?:你|妳)?(?:可以|能不能|能|可不可以)?(?:幫我|幫忙)(?:上網)?(?:查|搜|找|搜尋)(?:一下|看看)?(.{2,30}?)(?:嗎|好嗎|好不好|呢)?$"#),
           !g[0].contains("我的"), !g[0].contains("運勢") { return g[0] }
        // 「google 台北101」「google一下…」是叫我查；「Google是誰創立的」是在問 Google 這家公司
        let googleVerb = l.range(of: #"^google\s*(一下|查|看看|搜尋|搜|找)|^google\s+\S"#, options: .regularExpression) != nil
        guard prefixes.contains(where: { l.hasPrefix($0) }) || inside.contains(where: { t.contains($0) }) || googleVerb else { return nil }
        if t.contains("我的") || t.contains("運勢") || (t.contains("我") && ManticReader.wants(t)) { return nil }
        // 「你可以上網找資料嗎」「你會上網嗎」是在問 NineSun 的能力，不是要它去查
        if ["你可以", "你會", "你能", "你有辦法"].contains(where: { t.hasPrefix($0) }) && (t.hasSuffix("嗎") || t.hasSuffix("？") || t.hasSuffix("?")) { return nil }
        // 保留整個問題（「幫我查一下原子習慣是誰寫的」→「原子習慣是誰寫的」）；拆成關鍵字會丟掉「是誰」，就不知道要找人名
        let c = Understanding.clean(t)
        if c != t, c.count >= 2 { return c }
        let q = WebAgent.keywords(t)
        return q.isEmpty || q == t ? nil : q
    }

    /// 明顯是知識、時事類問題（而且不是在問自己的命）
    static let strongMarkers = ["是什麼", "什麼是", "什麼意思", "是誰", "誰是", "新聞", "天氣", "氣溫", "匯率", "股價", "股市", "台股", "美股", "比分", "油價", "颱風", "地震", "怎麼做", "怎麼煮",
                                "怎麼去", "怎麼用", "教我", "介紹一下", "歷史", "原理", "定義", "公式", "多高", "多遠", "多大", "多久", "多長"]
    /// 要最新、要查證的資料（新聞、天氣、價格、誰是現任…、健康法律、作品內容、某個人是誰）：有大腦時也先上網查，再交給大腦整理；
    /// 其他的（解釋、建議、聊天、常識）大腦自己就能回答，不用等網路
    static let freshMarkers = ["新聞", "天氣", "氣溫", "下雨嗎", "匯率", "股價", "股市", "台股", "美股", "比分", "油價", "最新", "最近", "現在的", "目前的", "今天的",
                               "價格", "多少錢", "售價", "票價", "營業時間", "幾點開", "幾點關", "地址", "電話號碼", "選舉", "總統", "首相", "總理", "市長", "部長",
                               "票房", "排行榜", "上映", "發售", "推出", "疫情", "是誰", "誰是", "哪一隊", "冠軍", "2024", "2025", "2026", "2027",
                               // 某個地方可以去哪、吃什麼、做什麼：大腦會編出不存在的地名店名，要先查
                               "景點", "餐廳", "好吃的", "好玩的", "可以做的事", "可以去", "去哪", "行程", "在哪裡買", "哪裡買", "哪家"]
    public static func needsFreshInfo(_ raw: String) -> Bool {
        explicitSearch(raw) != nil || freshMarkers.contains { raw.contains($0) } || healthOrLegal(raw) || asksAboutWork(raw)
    }
    static let selfMarkers = ["我", "運", "命", "宮", "八字", "紫微", "卦", "大限", "流年", "流月", "流日", "九型", "星盤", "合婚", "桃花", "時辰", "生肖", "你"]
    static func strongInfo(_ raw: String) -> Bool {
        strongMarkers.contains { raw.contains($0) } && !selfMarkers.contains { raw.contains($0) }
    }

    /// 語氣：開頭的「嘿」「欸」「喂」、結尾的「～」只是口氣，先拿掉（「嘿你是誰～」＝「你是誰」）
    static func tidy(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 結尾的客套話、重複的標點只是口氣（「搬家要注意什麼，謝謝」「…？？」「…，快告訴我」）
        for _ in 0..<2 {
            t = t.replacingOccurrences(of: #"[，,？?。.!！\s]*[，,]\s*(謝謝|謝啦|拜託|急|快告訴我|我不太懂)$"#, with: "", options: .regularExpression)
            while let l = t.last, "～~!！。…".contains(l), t.count > 1 { t.removeLast() }
            // 「你是誰～？」「好嗎!?」：問號前面的口氣符號拿掉
            t = t.replacingOccurrences(of: #"[～~!！。…]+([？?]+)$"#, with: "$1", options: .regularExpression)
            t = t.replacingOccurrences(of: #"[？?]{2,}$"#, with: "？", options: .regularExpression)
            t = t.replacingOccurrences(of: #"[？?][。，,]+$"#, with: "？", options: .regularExpression)
        }
        // 開頭的情境、口頭禪（「考考你，」「跟你說，」「老實說，」「我一直很好奇，」「對了，」「話說」「嗯…」）不是問題本身
        t = t.replacingOccurrences(of: Understanding.contextOpeners, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"^((對了|話說|順便問一下|順便問|嗯…*|嗯)[，,、…\s]*)+(?=.{2})"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: Understanding.contextOpeners, with: "", options: .regularExpression)
        for w in ["嘿", "欸", "誒", "喂", "哈囉，", "嗨，"] where t.hasPrefix(w) && t.count > w.count + 1 {
            t = String(t.dropFirst(w.count)).trimmingCharacters(in: CharacterSet(charactersIn: "，, "))
            break
        }
        return t
    }

    /// 在問自己的命（用命盤算）：運勢、命盤、宮位、流年……，或問自己的未來（「我什麼時候會結婚」「我適合換工作嗎」）。
    /// 「羅浮宮」「故宮」的「宮」不算
    static func fortuneAsk(_ t: String) -> Bool {
        let marks = #"運勢|運氣|運程|運如何|運怎麼樣|運好嗎|運好不好|運不好|命盤|命宮|本命|[0-9０-９一二三四五六七八九十]{1,2}宮|十二宮|宮位(?!於)|幾宮|哪一宮|哪個宮|什麼宮|流年|大運|流月|流日|八字|紫微|卦|塔羅|占卜|算命|幫我算|九型|第幾型|星座|生肖|風水|桃花運|財運|事業運|感情運|正緣|姻緣|日宮|夜宮|解讀"#
        if t.range(of: marks, options: .regularExpression) != nil { return true }
        // 命理的術語（「什麼是化忌」）：用 NineSun 自己的資料庫回答
        if t.range(of: #"化忌|化祿|化權|化科|四化|天干|地支|十神|日主|喜用神|忌神|用神|身強|身弱|主星|命主|身主|大限|小限|飛宮|果宮|因宮|好正壞|日宮|夜宮|五行"#, options: .regularExpression) != nil { return true }
        // 問自己這段時間的運（「今年哪幾個月感情比較順」「下個月適合搬家嗎」）
        if t.range(of: #"(今年|明年|這個月|下個月|這週|下週|今天|明天|哪幾個月|哪個月|哪一年|哪年|哪天|哪幾天).{0,8}(比較順|最順|順嗎|順不順|最好|比較好|旺|適合)"#, options: .regularExpression) != nil { return true }
        if t.contains("我"), t.range(of: #"會不會|什麼時候會|哪一年會|哪年會|幾歲會|適合我|我適合|適合.*嗎|會有.*嗎|會結婚|會升職|會有錢|會成功|會變好|能不能成功"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// 說的是自己的心情（「我好累」「最近很難過，怎麼辦」）：要安慰。
    /// 在問一個東西（「憂鬱症是什麼」「解釋一下情緒勒索」「快樂王子講了什麼」）不算，就算句子裡有情緒字
    static let moodWords = "煩|累|難過|焦慮|孤單|孤獨|寂寞|沮喪|傷心|生氣|失落|迷茫|害怕|緊張|低落|空虛|委屈|崩潰|痛苦|憂鬱|難受|不開心|鬱悶|無聊|想哭|沒用|沒價值|差勁|自卑"

    static func selfFeeling(_ t: String) -> Bool {
        guard !asksAboutWork(t) else { return false }
        // 「我孤單到睡不著」「我失落」「好沮喪」：說的是自己的心情
        if t.range(of: "(\(moodWords))到|^我(好|很|超|太|真的|有點|一直|最近)?(\(moodWords))|(好|很|超|太|一直|有點|真的|覺得|感到|非常|蠻|滿)\\S{0,2}(\(moodWords))|壓力\\S{0,2}大", options: .regularExpression) != nil,
           t.range(of: #"緩解|改善|克服|擺脫|減輕|消除|治療|方法|技巧|如何"#, options: .regularExpression) == nil { return true }
        guard Solace.isFeeling(t) else { return false }
        // 想解決它（「如何緩解焦慮」「改善失眠的方法」）：要的是方法，上網查
        let remedy = #"緩解|改善|克服|擺脫|減輕|消除|治療|調整|預防|避免|戒掉|走出|方法|技巧|秘訣|如何|怎樣才能|怎麼才能"#
        if t.range(of: remedy, options: .regularExpression) != nil { return false }
        // 心情本身（「好煩」「很沮喪」「想哭」「心情很差」）：安慰
        let mood = #"(好|很|超|太|一直|有點|真的|覺得|感到|非常|蠻|滿|好想)\S{0,2}(煩|累|難過|焦慮|孤單|孤獨|寂寞|沮喪|傷心|生氣|失落|迷茫|害怕|緊張|低落|空虛|委屈|崩潰|痛苦|憂鬱|難受|不開心|鬱悶|無聊|沒用|哭|放棄|想念)|想哭|心情\S{0,2}(差|不好|糟|低落)|想放棄|不想活|沒有人懂|被分手|失戀|想念|壓力\S{0,2}大"#
        if t.range(of: mood, options: .regularExpression) != nil { return true }
        // 問一件事（失眠、胃痛、考試考不好、被排擠怎麼辦）：要的是做法
        if t.range(of: #"怎麼辦|怎麼處理|該怎麼做"#, options: .regularExpression) != nil { return false }
        if t.contains("我") || t.contains("自己") { return true }
        let info = #"是什麼|什麼是|是誰|誰是|誰寫|誰發明|哪裡|哪一|哪個|幾|多少|為什麼|為何|講了什麼|在講什麼|在說什麼|內容|劇情|大綱|故事|意思|解釋|定義|作者|小說|電影|好看|症狀|原因|治療|怎麼治|的好處|有哪些"#
        return t.range(of: info, options: .regularExpression) == nil
    }

    /// 問世界上的事（定義、人、地點、時間、數字、原因、做法、比較、名單、作品、好處……），
    /// 不是問自己的命、不是說自己的心情、不是在跟 NineSun 聊天——這種要上網查，不能被「房」「出國」「情緒」這些字帶去算命或安慰
    static func worldQuestion(_ raw: String) -> Bool {
        let t = Understanding.clean(raw)
        // 問作品（「你的名字講了什麼」：劇情、好不好看不會是在問我）
        if !fortuneAsk(t), asksAboutWork(t) { return true }
        if fortuneAsk(t) || selfFeeling(t) || addressedToMe(t) || Translate.parse(raw) != nil || Companion.isSmallTalk(t) { return false }
        switch Understanding.frame(t).want {
        case .open:
            // 「我的優點是什麼」是在問自己（九型），不是問世界上的事
            if t.hasPrefix("我") { return false }
            return t.range(of: #"好處|壞處|優點|缺點|功效|內容|劇情|大綱|故事|在講什麼|講了什麼|在說什麼|評價|好看|好玩|值得|是什麼|什麼是|是誰|作者"#, options: .regularExpression) != nil
        case .steps:
            return practical(t)
        default:
            // 講自己的事（「我幾點睡比較好」「我有多高」）不算
            return !t.hasPrefix("我")
        }
    }

    /// 在問一部作品（書、電影、歌、動畫……）：「少年維特的煩惱這本書講了什麼」「孤獨的美食家好看嗎」——
    /// 書名裡的「煩惱」「悲傷」「孤獨」不是在說心情，要上網查
    static func asksAboutWork(_ raw: String) -> Bool {
        let t = raw.replacingOccurrences(of: #"[？?！!。\s]+$"#, with: "", options: .regularExpression)
        let fortune = ["運", "命", "宮", "流年", "大運", "八字", "紫微", "卦", "塔羅"]
        if fortune.contains(where: { t.contains($0) }) { return false }
        // 只說「這本書講了什麼」、沒有名稱：是在接著前面的話，不能拿去查
        let name = t.replacingOccurrences(of: #"(這|那)(本|部|首|篇|齣|套)\S{0,3}?(講了什麼|講了些什麼|在講什麼|講什麼|講的是什麼|說了什麼|在說什麼|寫了什麼|內容是什麼|的?內容|的?劇情|好看嗎|好聽嗎)"#, with: "", options: .regularExpression)
        if name.count < 2 { return false }
        let kinds = "書|小說|電影|影片|片|劇|影集|動畫|漫畫|歌|曲|專輯|作品|遊戲|詩|散文|繪本|紀錄片|音樂劇|舞台劇"
        let asks = "講了什麼|講了些什麼|在講什麼|講什麼|講的是什麼|說了什麼|在說什麼|寫了什麼|內容是什麼|內容|劇情|大綱|主旨|主題是什麼|心得|讀後感|結局|好看嗎?|好聽嗎?|值得看嗎?|值得讀嗎?|推薦嗎|的作者是誰|是誰寫的|是誰拍的|是誰唱的|是什麼(\(kinds))"
        // 「這本書講了什麼」「這部電影在講什麼」「《X》講了什麼」
        if t.range(of: #"(這|那)(本|部|首|篇|齣|套)(\#(kinds))?"#, options: .regularExpression) != nil,
           t.range(of: "(\(asks))$", options: .regularExpression) != nil { return true }
        if t.contains("《") || t.contains("〈") { return t.range(of: "(\(asks))$", options: .regularExpression) != nil }
        // 「少年維特的煩惱講了什麼」「悲傷逆流成河在講什麼」：主語是一個名稱（不是「我」「你」開頭）
        // 「你的名字講了什麼」也是：劇情、好不好看不會是在問我
        if t.range(of: "^[^我他她].{2,20}(講了什麼|講了些什麼|在講什麼|講的是什麼|在說什麼|劇情是什麼|的劇情|的結局|的?故事大綱|的大綱|的作者是誰|是誰寫的|好看嗎?|好聽嗎?|值得看嗎?|值得讀嗎?)$", options: .regularExpression) != nil { return true }
        // 「誰是寂寞的鯨魚的作者」「誰寫了憂鬱的貓」
        if t.range(of: "^(誰是.{2,20}的(作者|導演|作曲者|主唱)|誰(寫|拍|唱)了.{2,20})$", options: .regularExpression) != nil { return true }
        return false
    }

    /// 只打了一個名稱、名稱裡剛好有情緒字（「夏洛特的煩惱」「少年維特的煩惱」「悲傷逆流成河」不算——沒有「的」）：
    /// 「名字＋的＋情緒」而且整句沒有「我」、沒有程度（好、很）、沒有語氣詞，是在講一個作品或一件事，不是在說自己的心情 → 上網查它是什麼。
    /// 「媽媽的煩惱」「朋友的焦慮」這種是身邊的人，不算
    static func bareTitle(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (4...14).contains(t.count),
              let m = Understanding.match(t, "^(.{2,9})的(.{0,3}(?:\(moodWords)|悲傷|憂傷|哀愁|眼淚|恐懼|憤怒|孤寂|心事).{0,2})$") else { return false }
        let owner = m[1]
        if owner.range(of: #"[我你妳他她它您]|自己|別人|大家|人家|朋友|同事|同學|老闆|主管|老師|爸|媽|父|母|兒子|女兒|小孩|孩子|家人|老公|老婆|男友|女友|男朋友|女朋友|先生|太太|哥|姊|姐|弟|妹|現代人|年輕人|上班族|學生|今天|最近|現在|人生|生活|工作|感情|心裡|內心|莫名|無名|說不出|很多|所有|這|那"#, options: .regularExpression) != nil { return false }
        if t.range(of: #"[好很超太真嗎呢吧啊了，,。！!？?\s]|怎麼|如何|為什麼"#, options: .regularExpression) != nil { return false }
        return true
    }

    /// 在問一個有名字的作品或東西（要查了才講得準：小模型憑印象講劇情常常張冠李戴）
    public static func namedWork(_ raw: String) -> Bool {
        let t = Understanding.clean(raw)
        return asksAboutWork(t) || bareTitle(t)
    }

    /// 生活上的「怎麼做」：「怎麼存錢」「面試要注意什麼」「被主管罵了怎麼辦」——要的是實際做法，上網看好幾個網站再整理；
    /// 問命（運勢、流年、什麼時候、會不會）、問 NineSun 自己、翻譯、單純說心情的不算
    static func practical(_ raw0: String) -> Bool {
        let raw = Understanding.clean(raw0)
        if selfFeeling(raw) { return false }
        let how = ["怎麼", "如何", "怎樣", "注意", "方法", "技巧", "秘訣", "訣竅", "該怎麼做", "要怎麼做", "教我", "從哪裡開始", "有沒有辦法", "辦法"]
        guard how.contains(where: { raw.contains($0) }) else { return false }
        // 「X 怎麼說」（翻譯）前面已經用 Translate.parse 排除了；「怎麼說服別人」是做法題
        let not = ["怎麼樣", "怎麼了", "怎麼會", "怎麼回事", "怎麼稱呼", "怎麼用這", "怎麼玩這",
                   "運", "命", "宮", "流年", "大運", "流月", "八字", "紫微", "卦", "塔羅", "占卜", "算", "九型", "星座", "生肖", "風水",
                   "今天", "今晚", "明天", "今年", "明年", "這個月", "下個月", "什麼時候", "會不會", "適合我", "我適合", "我的命", "想死", "不想活", "自殺"]
        if not.contains(where: { raw.contains($0) }) { return false }
        if addressedToMe(raw) || Translate.parse(raw) != nil { return false }
        // 九型人格的問題（「我怎麼成長」「我要怎麼提升自己」）由 NineSun 自己用你的型回答；
        // 有具體要提升的東西（「我想提升口才」「提升專注力」）就是一般的做法題，上網查
        if raw.hasPrefix("我"), Persona.parse(raw, L: .zh) != nil {
            var rest = raw
            for w in ["我想要", "我想", "我要", "我該", "我", "要", "該", "怎麼", "如何", "做", "才能", "可以", "提升", "成長", "進步", "變更好", "變得更好", "自己", "呢", "嗎", "？", "?", "。"] {
                rest = rest.replacingOccurrences(of: w, with: "")
            }
            if rest.count < 2 { return false }
        }
        guard case let .steps(target) = Understanding.frame(raw).want else { return false }
        // 「那我該怎麼辦」：沒有具體的事，是在追問上一則解讀
        var t = target
        for w in ["那", "我", "你", "該", "要", "就", "這樣", "那樣", "現在", "呢", "啊", "的", "了", "還"] { t = t.replacingOccurrences(of: w, with: "") }
        return t.count >= 2
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

    /// 「我的健康要注意什麼」→「我的健康怎麼樣」（交給主題路由）；不是這種問法回傳 nil。
    /// 有症狀（「我的身體一直發燒」）、問方法（「怎麼讓身體變好」）的不算
    /// 「請事假會扣薪水嗎」「薪水怎麼算」：問規定、常識，不是問自己的運——資料庫答得出來、又沒有算命的字，就不算命
    static func knowledgeNotFortune(_ t: String) -> Bool {
        if t.range(of: "運|命|算命|算算|幫我算|幫我看|占卜|星盤|宮|流年|順不順|順利|好不好", options: .regularExpression) != nil { return false }
        let rules = t.range(of: "請假|事假|病假|特休|扣薪|扣錢|違法|合法|規定|勞基法|罰|繳稅|要繳|補助|津貼|申請|怎麼算|怎麼計算", options: .regularExpression) != nil
        if t.contains("我") && !rules { return false }
        return Commonsense.answer(t) != nil || Fuzzy.match(t) != nil
    }

    static func myTopic(_ raw: String) -> String? {
        let t = raw.filter { !"？?。！!，, ".contains($0) }
        guard let g = RuleBook.match(t, #"^我(?:的|今年的|最近的)?(健康|身體|錢財|財運|金錢|錢|感情|愛情|桃花|事業|工作|婚姻|朋友|人際關係|人際|家庭|家人|學業|考運)(?:運|運勢|方面)?(?:要|該|需要|應該)?(注意什麼|注意些什麼|注意哪些|小心什麼|怎麼樣|如何|好不好|好嗎|會好嗎|順不順|怎樣)$"#) else { return nil }
        let topic = g[0] == "身體" ? "健康" : g[0] == "錢" || g[0] == "金錢" ? "錢財" : g[0]
        return "我的\(topic)怎麼樣"
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
        var q = Understanding.clean(raw)
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

    /// 資料庫的條目真的是在講問的那個東西：問「五行是什麼」不能答「五行局」（名字要整個出現在問題裡）
    static func kbFits(_ e: KnowledgeBase.Entry, _ text: String) -> Bool {
        ([e.title] + e.aliases).contains { $0.count >= 2 && text.contains($0) }
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
        var aboutMe = text.contains("我是") || text.contains("性別") || expectingGender
        // 「哥哥的兒子叫我什麼（我是男生）」：括號裡順便說的，問的是別的事，不是在登記性別
        if aboutMe && !expectingGender && !text.contains("性別") && !ManticReader.wants(text) {
            let rest = text.replacingOccurrences(of: #"[（(][^）)]*[）)]|我是(男|女)(生|的|人|性|孩)"#, with: "", options: .regularExpression)
            if ["什麼", "幾", "哪", "誰", "嗎", "怎麼", "如何", "?", "？"].contains(where: { rest.contains($0) }) { aboutMe = false }
        }
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
