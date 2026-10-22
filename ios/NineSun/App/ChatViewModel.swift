import EchoCore
import SwiftUI

/// 所有 @Published 狀態只在主執行緒修改；推理在背景佇列執行。
final class ChatViewModel: ObservableObject {
    enum Phase { case booting, ready, failed(String) }

    @Published var phase: Phase = .booting
    @Published var turns: [ChatTurn] = []
    @Published var streaming: String?
    @Published var thinking = false
    /// 請其他 AI 幫忙：金鑰存在鑰匙圈，其他設定存在 UserDefaults
    @Published var openRouterKey = KeyStore.get("openrouter") { didSet { KeyStore.set("openrouter", openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines)) } }
    @Published var geminiKey = KeyStore.get("gemini") { didSet { KeyStore.set("gemini", geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)) } }
    /// 各家 AI 的金鑰，一行一把（Gemini、Claude、ChatGPT、Grok、DeepSeek、Groq、OpenRouter 都可以，照開頭自動認）
    @Published var aiKeys: String = ChatViewModel.initialKeys() { didSet { KeyStore.set("aikeys", aiKeys.trimmingCharacters(in: .whitespacesAndNewlines)) } }
    /// 舊版分開存的 Gemini、OpenRouter 金鑰搬過來
    static func initialKeys() -> String {
        let k = KeyStore.get("aikeys")
        if !k.isEmpty { return k }
        return [KeyStore.get("gemini"), KeyStore.get("openrouter")].filter { !$0.isEmpty }.joined(separator: "\n")
    }
    @Published var aiAuto = true { didSet { save(aiAuto, "aiAuto") } }
    @Published var aiModels = "" { didSet { save(aiModels, "aiModels") } }
    /// 打開：除了算命、命盤，所有的話都交給其他 AI 回答；關掉：NineSun 自己回答
    @Published var aiAlways = false { didSet { save(aiAlways, "aiAlways") } }
    /// 設定頁「測試連線」的結果
    @Published var aiTestResult = ""
    @Published var aiTesting = false
    func testAI() {
        let cfg = aiConfig
        aiTesting = true
        aiTestResult = "測試中…（最多約一分鐘）"
        Task { [self] in
            let r = await AskAIs.test(config: cfg)
            await MainActor.run { self.aiTestResult = r; self.aiTesting = false }
        }
    }
    var aiConfig: AskAIs.Config {
        AskAIs.Config(keys: aiKeys.components(separatedBy: CharacterSet(charactersIn: "\n ,，")))
    }
    @Published var options = SamplingOptions() { didSet { save(options, "options"); applyOptions() } }
    @Published var profile = UserProfile() { didSet { save(profile, "profile") } }
    @Published var rules = RuleBook() { didSet { save(rules, "rules") } }
    /// 介面語言；autoDetect 開啟時回覆語言跟隨每則訊息
    @Published var language: Lang = UILang.systemDefault { didSet { UILang.current = language; save(language, "language") } }
    @Published var autoDetect = true { didSet { save(autoDetect, "autoDetect") } }
    @Published private(set) var evolution: Evolution?
    @Published private(set) var coreSnapshot: PalaceCore.Snapshot?

    private(set) var modelInfo: (params: Int, layers: Int, heads: Int, embd: Int, ctx: Int, vocab: Int) = (0, 0, 0, 0, 0, 0)
    private(set) var knowledgeBases: [Lang: KnowledgeBase] = [:]
    /// 目前介面語言的資料庫
    var knowledge: KnowledgeBase? { knowledgeBases[language] ?? knowledgeBases[.zh] }
    private var engine: EchoEngine?
    private let queue = DispatchQueue(label: "ninesun.inference", qos: .userInitiated)

    private static let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private static let historyURL = docs.appendingPathComponent("ninesun-history.json")
    private static let evolutionURL = docs.appendingPathComponent("ninesun-evolution.json")
    private static let coreURL = docs.appendingPathComponent("ninesun-core.json")
    /// 自我升級的經驗（哪些網站、哪種查法有用），只有幾 KB，不存答案
    private static let tuningURL = docs.appendingPathComponent("ninesun-selftuning.json")
    /// 知識筆記本：查證過的答案（拿來對照，不直接拿來回答）
    private static let notebookURL = docs.appendingPathComponent("ninesun-notebook.json")
    /// 上一個上網查的問題（「繼續查」用）
    private var lastWebQuestion: String?
    /// 沒設定其他 AI 時，提醒過一次就好
    private var aiHintShown = false

    init() {
        options = load("options") ?? SamplingOptions()
        profile = load("profile") ?? UserProfile()
        rules = load("rules") ?? RuleBook()
        language = load("language") ?? UILang.systemDefault
        autoDetect = load("autoDetect") ?? true
        aiAuto = load("aiAuto") ?? true
        aiModels = load("aiModels") ?? ""
        aiAlways = load("aiAlways") ?? false
        UILang.current = language
        // 以前的版本會把上網查過的答案存在手機裡；現在每次都即時上網查，舊檔刪掉
        try? FileManager.default.removeItem(at: Self.docs.appendingPathComponent("ninesun-webmemory.json"))
        if let d = try? Data(contentsOf: Self.tuningURL), let st = try? JSONDecoder().decode(SelfTuning.State.self, from: d) {
            SelfTuning.shared.state = st
        }
        if let d = try? Data(contentsOf: Self.notebookURL), let st = try? JSONDecoder().decode(Notebook.State.self, from: d) {
            Notebook.shared.state = st
        }
        if let data = try? Data(contentsOf: Self.historyURL),
           let saved = try? JSONDecoder().decode([ChatTurn].self, from: data) {
            turns = saved
        }
    }

    // MARK: - 開機

    func boot() {
        guard engine == nil else { return }
        let started = Date()
        queue.async {
            do {
                let model = try EchoModel(bundle: .main)
                let engine = EchoEngine(model: model)
                for L in Lang.allCases { engine.knowledge[L] = try? KnowledgeBase(bundle: .main, lang: L) }
                engine.i18n = try? I18N(bundle: .main)
                engine.chatBank = try? ChatBank(bundle: .main)
                // 大腦（閱讀理解模型）：上網查到的每段文字都由它來讀懂、判斷
                Brain.shared = try? Brain(bundle: .main)
                // 離線字典（英、中、西、義、阿）：翻譯單字用，背景慢慢載入
                DispatchQueue.global(qos: .utility).async { Lexicon.shared = try? Lexicon(bundle: .main) }
                let core = try PalaceCore(bundle: .main)
                if let d = try? Data(contentsOf: Self.coreURL), let s = try? JSONDecoder().decode(PalaceCore.Snapshot.self, from: d) {
                    core.restore(s)
                }
                engine.core = core
                if let d = try? Data(contentsOf: Self.evolutionURL), let e = try? JSONDecoder().decode(Evolution.self, from: d),
                   e.bias.count == model.config.vocab_size {
                    engine.evolution = e
                }
                let c = model.config
                let wait = max(0, 1.4 - Date().timeIntervalSince(started))
                DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                    self.engine = engine
                    self.knowledgeBases = engine.knowledge
                    self.evolution = engine.evolution
                    self.coreSnapshot = core.snapshot
                    self.modelInfo = (model.numParams, c.n_layer, c.n_head, c.n_embd, c.n_ctx, c.vocab_size)
                    self.applyOptions()
                    if self.turns.isEmpty {
                        let hello = self.profile.birthday == nil
                            ? T("訊號接通！我是 NineSun，底層是九型十二宮。告訴我你的生日和出生時間，例如「我是2000年1月1日早上8點出生的女生」，我就能用十二宮、八字、紫微讀懂你。",
                                "Signal connected! I'm NineSun, built on the Nine & Twelve system. Tell me your birthday and birth time, e.g. “I was born on 2000-01-01 at 8am, I'm a woman”, and I'll read you through the twelve palaces, BaZi and Zi Wei. I speak 繁體中文, English, Español and Italiano.",
                                "¡Señal conectada! Soy NineSun, basado en el sistema Nueve y Doce. Dime tu cumpleaños y hora de nacimiento, p. ej. «nací el 2000-01-01 a las 8, soy mujer», y te leeré con los doce palacios, BaZi y Zi Wei.",
                                "Segnale connesso! Sono NineSun, basato sul sistema Nove e Dodici. Dimmi il tuo compleanno e l'ora di nascita, es. «sono nata il 2000-01-01 alle 8, sono una donna», e ti leggerò con i dodici palazzi, BaZi e Zi Wei.")
                            : T("訊號接通！歡迎回來。要看今天運勢、排八字紫微、算一卦，還是隨便聊聊？",
                                "Signal connected! Welcome back. Today's fortune, BaZi, Zi Wei, a hexagram, or just a chat?",
                                "¡Señal conectada! Bienvenido de nuevo. ¿Suerte de hoy, BaZi, Zi Wei, un hexagrama o charlar?",
                                "Segnale connesso! Bentornato. Fortuna di oggi, BaZi, Zi Wei, un esagramma o due chiacchiere?")
                        self.turns.append(ChatTurn(role: .echo, text: self.rules.enforce(hello), source: .tool))
                    }
                    withAnimation(.easeOut(duration: 0.35)) { self.phase = .ready }
                }
            } catch {
                DispatchQueue.main.async { self.phase = .failed("\(error)") }
            }
        }
    }

    var canSend: Bool { engine != nil && !thinking }

    // MARK: - 對話

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, engine != nil, !thinking else { return }
        turns.append(ChatTurn(role: .user, text: text))
        thinking = true
        streaming = ""

        // 「重新查…」：直接上網查最新的
        if text.hasPrefix("重新查") || text.lowercased().hasPrefix("search again") {
            let q = text.replacingOccurrences(of: "重新查", with: "").replacingOccurrences(of: "search again", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
            lookupWeb(q.isEmpty ? text : q, autoDetect ? Lang.detect(text, fallback: language) : language)
            return
        }

        // 「測試AI」：馬上試每一把金鑰，把真正的錯誤原因講出來
        if ["測試ai", "測試 ai", "test ai"].contains(text.trimmingCharacters(in: .whitespaces).lowercased()) {
            let cfg = aiConfig
            thinking = true
            Task { [self] in
                let r = await AskAIs.test(config: cfg)
                await MainActor.run { self.finish(ChatTurn(role: .echo, text: "其他 AI 的連線測試：\n" + r, source: .tool)) }
            }
            return
        }

        // 「問AI …」：一定要問其他 AI（先自己上網查，再同時問幾家、整理、查證）
        if let q = askAIQuestion(text) {
            let L = autoDetect ? Lang.detect(q, fallback: language) : language
            if aiConfig.enabled {
                lookupWeb(q, L, forceAI: true)
            } else {
                finish(ChatTurn(role: .echo, text: "還沒設定 AI 的金鑰：到設定頁的「請其他 AI 幫忙」填入 AI 金鑰（Gemini、Claude、ChatGPT、Grok 等都可以），我就能問它們、整理後給你。", source: .tool))
            }
            return
        }

        // 知識筆記：看看它學到了什麼
        if ["知識筆記", "你的筆記", "你學到了什麼", "你學到什麼"].contains(where: { text.contains($0) }) {
            finish(ChatTurn(role: .echo, text: Notebook.shared.summary(), source: .tool))
            return
        }

        // 不放棄：「繼續查」→ 換個方向把上一題再查一次
        if ["繼續查", "再查一次", "再查查", "繼續研究"].contains(text), let q = lastWebQuestion {
            lookupWeb(q, autoDetect ? Lang.detect(q, fallback: language) : language, reflect: true)
            return
        }

        // 知錯能改：剛剛上網查的答案被說「不對」→ 反省用過的來源、扣分，避開它們換個查法重查
        if Mind.isCorrection(text), let last = turns.dropLast().suffix(3).last(where: { $0.role == .echo && $0.query != nil }), let q = last.query {
            let hosts = SelfTuning.hosts(in: last.text)
            SelfTuning.shared.feedback(kind: SelfTuning.kind(Understanding.frame(q).want), hosts: hosts, positive: false)
            // 記進筆記：這題被說不對（有說正確答案的話也記下來，下次查證）
            Notebook.shared.dispute(q, userSaid: Mind.claim(text))
            saveFile(Notebook.shared.state, Self.notebookURL)
            lookupWeb(q, autoDetect ? Lang.detect(q, fallback: language) : language, avoid: hosts, reflect: true)
            return
        }

        // 翻譯：「蘋果用西班牙文怎麼說」「把這句翻成英文：…」「gracias 是什麼意思」
        if let req = Translate.parse(text) {
            translate(req)
            return
        }

        // 全部交給 AI：算命、命盤、生日這些還是 NineSun 自己算（AI 算不出你的盤），其他的都問 Gemini
        if aiAlways, aiConfig.enabled, !Self.isReading(text) {
            aiChat(text, autoDetect ? Lang.detect(text, fallback: language) : language)
            return
        }

        localReply(text)
    }

    /// NineSun 自己回答（本地的引擎；需要時上網查）
    private func localReply(_ text: String) {
        guard let engine else { return }
        let history = turns
        let ctx = EchoEngine.Context(profile: profile, rules: rules, now: Date(), language: language, autoDetect: autoDetect)
        queue.async {
            let reply = engine.reply(to: text, history: history, context: ctx)
            let snap = engine.core?.snapshot
            DispatchQueue.main.async {
                if let p = reply.profile { self.profile = p }
                if let r = reply.rules { self.rules = r }
                self.coreSnapshot = snap
                if let s = snap { self.saveFile(s, Self.coreURL) }
                if let q = reply.webQuery {
                    self.streaming = nil
                    self.turns.append(reply.turn)
                    // 已經先給了思路庫的答案，網路只是補充：沒查到就不要再跳一則「查不到」
                    // 已經先給了一段像樣的回答（思路庫、建議）時，網路只是補充：沒查到相關的就不要再跳一則
                    self.lookupWeb(q, reply.lang, quietIfNothing: reply.turn.source == .neural || reply.turn.text.count > 40)
                    return
                }
                if let term = reply.webAugment.first {
                    // 先給盤面解讀，再上網查這幾個組合的說法，逐句對照你的盤分析
                    let facts = reply.augmentFacts, L = reply.lang, also = Array(reply.webAugment.dropFirst())
                    self.play(text: reply.turn.text, final: reply.turn) { self.augmentWeb(term, also: also, facts: facts, L) }
                    return
                }
                self.play(text: reply.turn.text, final: reply.turn)
            }
        }
    }

    /// 要 NineSun 自己的命理引擎算的（運勢、命盤、八字、紫微、九型、生日…）
    static func isReading(_ text: String) -> Bool {
        ["運勢", "運氣", "命盤", "命宮", "本命", "八字", "紫微", "流年", "大運", "流月", "九型", "第幾型", "十二宮", "卦", "生日",
         "宮位", "算命", "占卜", "日宮", "夜宮", "fortune", "horoscope"].contains { text.lowercased().contains($0) }
    }

    /// 全部交給 AI 回答：直接問（Gemini 會自己用 Google 搜尋），用 NineSun 的口吻、照你的九型交代；好幾家 AI 時融合成一個答案
    private func aiChat(_ text: String, _ L: Lang) {
        let cfg = aiConfig
        let past = turns.dropLast().suffix(10).compactMap { t -> AskAIs.Turn? in
            t.text.isEmpty ? nil : AskAIs.Turn(fromUser: t.role == .user, text: t.text)
        }
        let persona = ""
        streaming = cfg.names.count > 1 ? "🤖 同時問 " + cfg.names.joined(separator: "、") + "，再融合成我的看法…" : "🤖 思考中…"
        Task { [self] in
            let reply = await AskAIs.chat(text, history: past, evidence: [], lang: L, config: cfg, persona: persona)
            await MainActor.run {
                guard reply.error == nil else {
                    // AI 回答不了（額度用完、忙線…）：不卡住、不報錯，NineSun 自己回答
                    self.streaming = ""
                    self.localReply(text)
                    return
                }
                self.streaming = ""
                self.play(text: reply.text, final: ChatTurn(role: .echo, text: reply.text, source: .knowledge))
            }
        }
    }

    /// 翻譯：單字先查手機裡的字典（馬上有、離線）；句子用手機內建翻譯（iOS 18 起），再不行請 AI 或線上翻譯
    private func translate(_ req: Translate.Request) {
        let cfg = aiConfig
        streaming = "🌐 翻譯成\(req.target.name)…"
        Task { [self] in
            var res: Translate.Result?
            if let lex = Lexicon.shared { res = Translate.dictionary(req, lexicon: lex) }
            if res == nil, #available(iOS 18.0, *) {
                res = await AppleTranslator.shared.translate(req)
            }
            if res == nil, cfg.enabled {
                let r = await AskAIs.chat(Translate.aiPrompt(req), history: [], evidence: [], lang: .zh, config: cfg)
                if r.error == nil, !r.text.isEmpty {
                    res = Translate.Result(text: r.text.trimmingCharacters(in: .whitespacesAndNewlines),
                                           source: req.source ?? Translate.detect(req.text, lexicon: Lexicon.shared),
                                           via: "請 " + cfg.names.joined(separator: "、") + " 翻譯")
                }
            }
            if res == nil { res = await Translate.online(req) }
            let text = res.map { Translate.reply(req, $0) }
                ?? "這句我現在翻不出來。整句翻譯要 iOS 18 以上的內建翻譯（第一次會請你下載語言包），或到設定填 AI 金鑰；也請確認手機有連上網路，再試一次。"
            await MainActor.run {
                self.streaming = ""
                self.play(text: text, final: ChatTurn(role: .echo, text: text, source: .tool))
            }
        }
    }

    /// 「問AI 量子電腦是什麼」→ 要問的問題（沒說的話用上一個問題）
    private func askAIQuestion(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = t.lowercased()
        let prefixes = ["問其他ai", "問其他 ai", "問別的ai", "問別的 ai", "問ai", "問 ai", "ask other ais", "ask other ai", "ask ai"]
        guard let p = prefixes.first(where: { lower.hasPrefix($0) }) else { return nil }
        var rest = String(t.dropFirst(p.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        for w in ["：", ":", "，", ","] where rest.hasPrefix(w) { rest.removeFirst(w.count) }
        rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty { return rest }
        if let q = lastWebQuestion { return q }
        return turns.dropLast().last(where: { $0.role == .user })?.text
    }

    /// 問題交給 NineSun 自己上網找（理解 → 搜尋 → 讀網頁 → 比對 → 回答），每次都即時查
    /// forceAI：「問AI …」——不管自己有沒有把握，都同時問其他 AI
    private func lookupWeb(_ q: String, _ L: Lang, quietIfNothing: Bool = false, avoid: [String] = [], reflect: Bool = false,
                           forceAI: Bool = false) {
        let book = rules
        thinking = true
        lastWebQuestion = q
        let asker = profile.birthday.map { Destiny($0).type }
        let cfg = aiConfig, auto = aiAuto
        let offerAI = !cfg.enabled && !aiHintShown
        // 查資料時一步一步顯示在想什麼（理解問題 → 搜尋 → 閱讀 → 比對），不會像卡住
        let show: @Sendable (String) -> Void = { [weak self] step in DispatchQueue.main.async { self?.streaming = step } }
        Task { [self] in
            let r = await WebAgent.run(q, facts: nil, lang: L, avoid: avoid, reflect: reflect, asker: asker, progress: quietIfNothing ? nil : show)
            if quietIfNothing && (!r.found || !r.answered) {
                await MainActor.run { self.saveFile(SelfTuning.shared.state, Self.tuningURL); self.thinking = false; self.streaming = nil; self.saveHistory() }
                return
            }
            var text = quietIfNothing ? "我再上網查了一下，補充幾個資料：\n\n" + r.text : r.text
            // 沒把握或要推理的題目：同時問其他 AI，整理各家說法、拿網路資料查證後給結論（要先設定金鑰）
            if !quietIfNothing, cfg.enabled, forceAI || (auto && AskAIs.shouldAsk(r)) {
                await MainActor.run { self.streaming = "🤖 正在同時問其他 AI，整理、查證中…" }
                let replies = await AskAIs.ask(q, evidence: r.evidence, lang: L, config: cfg)
                let summary = AskAIs.summarize(question: q, replies: replies, web: r)
                text = r.confident ? text + "\n\n" + summary : summary + "\n\n———\n📌 我自己在網路上查到的：\n\n" + text
            }
            // 沒設定其他 AI、這題又沒把握：說一次可以怎麼讓答案更可靠（一次就好，不一直講）
            var hinted = false
            if !quietIfNothing, offerAI, !r.confident, AskAIs.shouldAsk(r) {
                text += "\n\n💡 這題我沒什麼把握。到設定頁「請其他 AI 幫忙」填 AI 金鑰（Gemini 可以免費申請；Claude、ChatGPT、Grok 也行），以後遇到沒把握的題目，我會問它們、查證後把結論給你。"
                hinted = true
            }
            // tokens 設成空的，泡泡才會出現 👍／👎；query 記下問題，回饋時知道是哪一類問題
            var turn = ChatTurn(role: .echo, text: book.enforce(text), source: .knowledge, card: r.card, tokens: [])
            turn.query = q
            let didHint = hinted
            await MainActor.run {
                if didHint { self.aiHintShown = true }
                self.saveFile(SelfTuning.shared.state, Self.tuningURL)
                self.saveFile(Notebook.shared.state, Self.notebookURL)
                // 答案一段一段打出來，比一下子跳出一大段順
                self.streaming = ""
                self.play(text: turn.text, final: turn)
            }
        }
    }

    /// 八字／紫微解讀之後：上網查這個組合的說法，再對照盤面
    private func augmentWeb(_ term: String, also: [String], facts: String, _ L: Lang) {
        let book = rules
        thinking = true
        streaming = ""
        Task { [self] in
            let r = await WebAgent.run(term, facts: facts, also: also, lang: L)
            let text = r.text.hasPrefix("🔎") ? "我再上網查了網路上對你盤上這些組合的說法，一句一句拿來對照你的盤：\n\n" + r.text : r.text
            let turn = ChatTurn(role: .echo, text: book.enforce(text), source: .knowledge, card: r.card)
            await MainActor.run { self.finish(turn) }
        }
    }

    private func finish(_ turn: ChatTurn) {
        streaming = nil
        thinking = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { turns.append(turn) }
        saveHistory()
    }

    /// 打字機效果（then：打完之後接著做的事）
    private func play(text: String, final: ChatTurn, then: (() -> Void)? = nil) {
        let chars = text.map(String.init)
        var i = 0
        let step = max(1, chars.count / 60)
        func tick() {
            guard i < chars.count else { self.finish(final); then?(); return }
            self.streaming = (self.streaming ?? "") + chars[i..<min(chars.count, i + step)].joined()
            i += step
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.018) { tick() }
        }
        tick()
    }

    // MARK: - 演化回饋

    func feedback(_ turn: ChatTurn, positive: Bool) {
        guard let idx = turns.firstIndex(where: { $0.id == turn.id }), turns[idx].liked == nil else { return }
        // 上網查的答案：👍／👎 調整「這類問題該信哪些網站」的經驗
        if let q = turn.query {
            turns[idx].liked = positive
            SelfTuning.shared.feedback(kind: SelfTuning.kind(Understanding.frame(q).want), hosts: SelfTuning.hosts(in: turn.text), positive: positive)
            saveFile(SelfTuning.shared.state, Self.tuningURL)
            saveHistory()
            return
        }
        guard let toks = turn.tokens, let engine else { return }
        turns[idx].liked = positive
        queue.async {
            if let v = turn.variant {
                engine.evolution.feedback(reply: v, positive: positive)
            } else {
                engine.evolution.feedback(tokens: toks, positive: positive)
            }
            let evo = engine.evolution
            DispatchQueue.main.async {
                self.evolution = evo
                self.saveFile(evo, Self.evolutionURL)
                self.saveHistory()
            }
        }
    }

    func resetEvolution() {
        guard let engine else { return }
        queue.async {
            engine.evolution = Evolution(vocab: engine.model.config.vocab_size)
            engine.core?.resetMemory()
            let evo = engine.evolution, snap = engine.core?.snapshot
            DispatchQueue.main.async {
                self.evolution = evo
                self.coreSnapshot = snap
                self.saveFile(evo, Self.evolutionURL)
                if let snap { self.saveFile(snap, Self.coreURL) }
            }
        }
    }

    func deleteRule(at i: Int) { _ = rules.apply(.delete(i + 1), language) }


    func clear() {
        turns = [ChatTurn(role: .echo, text: T("記憶體已清空，訊號重新開始。", "Memory cleared, signal restarted.",
                                                "Memoria borrada, la señal reinicia.", "Memoria cancellata, il segnale riparte."), source: .tool)]
        saveHistory()
    }

    // MARK: - 儲存

    private func applyOptions() { engine?.options = options }

    private func saveHistory() {
        saveFile(Array(turns.suffix(200)), Self.historyURL)
    }

    private func saveFile<T: Encodable>(_ v: T, _ url: URL) {
        if let data = try? JSONEncoder().encode(v) { try? data.write(to: url, options: .atomic) }
    }

    private func save<T: Encodable>(_ v: T, _ key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(v), forKey: "ninesun.\(key)")
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let d = UserDefaults.standard.data(forKey: "ninesun.\(key)") else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
}
