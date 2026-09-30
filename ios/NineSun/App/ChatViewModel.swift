import EchoCore
import SwiftUI

/// 所有 @Published 狀態只在主執行緒修改；推理在背景佇列執行。
final class ChatViewModel: ObservableObject {
    enum Phase { case booting, ready, failed(String) }

    @Published var phase: Phase = .booting
    @Published var turns: [ChatTurn] = []
    @Published var streaming: String?
    @Published var thinking = false
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

    init() {
        options = load("options") ?? SamplingOptions()
        profile = load("profile") ?? UserProfile()
        rules = load("rules") ?? RuleBook()
        language = load("language") ?? UILang.systemDefault
        autoDetect = load("autoDetect") ?? true
        UILang.current = language
        // 以前的版本會把上網查過的答案存在手機裡；現在每次都即時上網查，舊檔刪掉
        try? FileManager.default.removeItem(at: Self.docs.appendingPathComponent("ninesun-webmemory.json"))
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
        guard !text.isEmpty, let engine, !thinking else { return }
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
                    self.lookupWeb(q, reply.lang, quietIfNothing: reply.turn.source == .neural)
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

    /// 問題交給 NineSun 自己上網找（理解 → 搜尋 → 讀網頁 → 比對 → 回答），每次都即時查
    private func lookupWeb(_ q: String, _ L: Lang, quietIfNothing: Bool = false) {
        let book = rules
        thinking = true
        Task { [self] in
            let r = await WebAgent.run(q, facts: nil, lang: L)
            if quietIfNothing && (!r.found || !r.answered) {
                await MainActor.run { self.thinking = false; self.streaming = nil; self.saveHistory() }
                return
            }
            let text = quietIfNothing ? "我再上網查了一下，補充幾個資料：\n\n" + r.text : r.text
            let turn = ChatTurn(role: .echo, text: book.enforce(text), source: .knowledge, card: r.card)
            await MainActor.run { self.finish(turn) }
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
        guard let idx = turns.firstIndex(where: { $0.id == turn.id }), turns[idx].liked == nil,
              let toks = turn.tokens, let engine else { return }
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
