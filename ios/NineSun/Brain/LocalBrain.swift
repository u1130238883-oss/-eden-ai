import Foundation

/// NineSun 的大腦：手機上跑的大型語言模型（llama.cpp＋Qwen），不用網路、不用 API。
///
/// 分工：NineSun 自己的引擎先做它擅長的——算命盤、算日期、查常識、上網找資料；
/// 大腦負責「想」：讀懂對方真正想問什麼，把引擎給的事實和網路資料組織成像人說的話，說出自己的看法，接得上前面聊過的。
/// 引擎給的事實（數字、日期、宮位、名字）是準的，大腦不能改。
final class LocalBrain {
    static let shared = LocalBrain()

    struct Turn { var fromUser: Bool; var text: String }

    enum Mode {
        /// 一般聊天、說心情
        case chat
        /// 有引擎查到的事實或網路資料，照著回答
        case grounded
        /// 有命盤推算的結果，用白話解讀
        case reading
    }

    private let queue = DispatchQueue(label: "ninesun.brain", qos: .userInitiated)
    private var runner: LlamaRunner?
    private var loadedPath: String?
    private let lock = NSLock()
    private var cancelled = false

    /// 模型讀進記憶體了沒（第一次要幾秒）
    var isLoaded: Bool { lock.lock(); defer { lock.unlock() }; return runner != nil }

    /// 中斷正在寫的回答
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }

    /// 記憶體不夠時放掉模型（下次用到再讀）
    func unload() { queue.async { self.lock.lock(); self.runner = nil; self.loadedPath = nil; self.lock.unlock() } }

    /// 問大腦。onText：寫到哪就回呼到哪（已經整理成繁體、去掉思考過程）；done：寫完或失敗（在背景執行緒）
    func ask(modelPath: String, system: String, history: [Turn], user: String, mode: Mode, lang: String,
             onText: @escaping (String) -> Void, done: @escaping (Swift.Result<LlamaRunner.Result, Error>) -> Void) {
        queue.async {
            self.lock.lock(); self.cancelled = false; self.lock.unlock()
            do {
                if self.loadedPath != modelPath {
                    self.lock.lock(); self.runner = nil; self.lock.unlock()
                    let r = try LlamaRunner(path: modelPath, contextSize: 4096)
                    self.lock.lock(); self.runner = r; self.loadedPath = modelPath; self.lock.unlock()
                }
                guard let r = self.runner else { throw LlamaRunner.Failure.context }
                let prompt = Self.chatML(system: system, history: history, user: user)
                let temp: Float = mode == .chat ? 0.7 : 0.4
                var res = try r.generate(prompt: prompt, maxTokens: mode == .chat ? 450 : 800, temperature: temp,
                                         stop: ["<|im_end|>", "<|im_start|>"],
                                         shouldStop: { self.lock.lock(); defer { self.lock.unlock() }; return self.cancelled },
                                         onText: { onText(Self.tidy($0, lang: lang)) })
                res.text = Self.tidy(res.text, lang: lang)
                done(.success(res))
            } catch {
                done(.failure(error))
            }
        }
    }

    // MARK: - 提示（給模型的話）

    /// Qwen 的對話格式（ChatML）。最後先放一段空的思考，讓它直接回答，不花時間長篇思考
    static func chatML(system: String, history: [Turn], user: String) -> String {
        var s = "<|im_start|>system\n\(system)<|im_end|>\n"
        for t in history.suffix(8) {
            let text = t.text.count > 400 ? String(t.text.prefix(400)) + "…" : t.text
            s += "<|im_start|>\(t.fromUser ? "user" : "assistant")\n\(text)<|im_end|>\n"
        }
        s += "<|im_start|>user\n\(user)<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
        return s
    }

    /// NineSun 的個性和說話方式。persona：照使用者的九型調整的補充；now：今天的日期時間（模型自己不知道）
    static func system(lang: String, persona: String = "", now: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.dateFormat = "yyyy年M月d日 EEEE HH:mm"
        let when = f.string(from: now)
        switch lang {
        case "en", "es", "it":
            let name = ["en": "English", "es": "Spanish", "it": "Italian"][lang]!
            return """
            You are NineSun, a small glowing TV-robot companion: smart, warm, curious, with your own opinions and a light sense of humor. You talk like a knowledgeable friend, not a customer-service bot.
            Always reply in \(name). Answer the question directly first, then the key points. Keep casual chat short (one to three sentences); explain step by step only when it helps.
            When asked for an opinion, pick a side and give your reason ("I think…").
            If the message contains [NineSun's facts] or [chart results], treat them as correct and never change their numbers, dates, names or palaces. If you are not sure about something, say so; never invent facts, numbers or sources.
            No Markdown symbols (#, **). Today is \(when).
            \(persona)
            """
        default:
            return """
            你是 NineSun——一台會發光的小電視機器人，是使用者的 AI 夥伴。你聰明、溫暖、好奇，有自己的想法和一點幽默感，說話像一個懂很多的好朋友，不是客服。
            說話的規則：
            1. 用繁體中文（台灣用語）回答；對方用別的語言時，用他的語言回答。
            2. 先直接回答，再補充重點。日常聊天一到三句就好，像朋友傳訊息；需要說明步驟或比較時才分點。
            3. 要有自己的看法：被問意見、選擇、建議時，選一邊並說理由，可以說「我覺得…」。
            4. 對方說心情時，先接住他的感受，再陪他想辦法，不要說教。
            5. 訊息裡附了【NineSun 查到的資料】或【命盤推算結果】時，以那些為準：數字、日期、名字、宮位一個字都不能改，也不要自己另外算。資料沒有、你也不確定的，就說不確定，絕對不要編造事實、數字或出處。
            6. 不要用 Markdown 符號（#、**），條列用「1.」或「•」。
            今天是\(when)。
            \(persona)
            """
        }
    }

    /// 交給大腦的訊息：問題＋引擎給的東西
    /// hint：參考用的（NineSun 用命盤看到的心情處境），挑一兩句用，不用照抄
    static func userMessage(question: String, facts: String = "", evidence: [String] = [], reading: String = "", hint: String = "",
                            lang: String = "zh") -> String {
        let zh = !["en", "es", "it"].contains(lang)
        var s = ""
        if !hint.isEmpty {
            s += (zh ? "【NineSun 從對方的命盤看到的（參考就好，挑一兩句自然地用，不要整段照抄）】\n" : "[What NineSun sees in their chart] (optional; use a sentence or two at most)\n")
                + String(hint.prefix(700)) + "\n\n"
        }
        if !reading.isEmpty {
            s += (zh ? "【命盤推算結果】（NineSun 的九型十二宮引擎精確算出來的，不能改）\n" : "[chart results] (computed exactly by NineSun's engine; do not change)\n")
            s += String(reading.prefix(1400)) + "\n\n"
            s += zh ? "用上面的結果回答：先講結論，再用白話說為什麼，最後給一個具體可以做的建議。\n\n" : "Answer from these results: conclusion first, then why in plain words, then one concrete suggestion.\n\n"
        }
        if !facts.isEmpty {
            s += (zh ? "【NineSun 查到的資料】（正確，回答要以它為準）\n" : "[NineSun's facts] (correct; base your answer on them)\n") + String(facts.prefix(1500)) + "\n\n"
        }
        if !evidence.isEmpty {
            var used = 0
            var lines: [String] = []
            for (i, e) in evidence.enumerated() where used + e.count <= 1600 {
                lines.append("\(i + 1). \(e)")
                used += e.count
            }
            s += (zh ? "【網路上查到的資料】（可能有雜訊，自己判斷哪些有用；用了就照實說，不要加料）\n" : "[web results] (may be noisy; judge what is useful and don't embellish)\n")
                + lines.joined(separator: "\n") + "\n\n"
        }
        s += s.isEmpty ? question : (zh ? "對方的問題：" : "The question: ") + question
        return s
    }

    // MARK: - 整理模型寫出來的字

    /// 去掉思考過程和 Markdown；中文轉成繁體、換成台灣用語
    static func tidy(_ raw: String, lang: String) -> String {
        var s = raw
        if let r = s.range(of: "</think>") { s = String(s[r.upperBound...]) } else if s.contains("<think>") { return "" }
        s = s.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "<|im_end|>", with: "")
        s = s.replacingOccurrences(of: #"(?m)^#{1,6}\s*"#, with: "", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if !["en", "es", "it"].contains(lang) { s = taiwanese(traditional(s)) }
        return s
    }

    /// 簡體 → 繁體（系統內建的 ICU 轉換）
    static func traditional(_ s: String) -> String {
        s.applyingTransform(StringTransform(rawValue: "Hans-Hant"), reverse: false) ?? s
    }

    /// 大陸用語 → 台灣用語（只換不會換錯意思的）
    static let twWords: [(String, String)] = [
        ("軟件", "軟體"), ("硬件", "硬體"), ("視頻", "影片"), ("信息", "資訊"), ("網絡", "網路"), ("互聯網", "網際網路"), ("默認", "預設"),
        ("屏幕", "螢幕"), ("鼠標", "滑鼠"), ("打印", "列印"), ("搜索", "搜尋"), ("用戶", "使用者"), ("短信", "簡訊"), ("博客", "部落格"),
        ("出租車", "計程車"), ("自行車", "腳踏車"), ("公交車", "公車"), ("西紅柿", "番茄"), ("酸奶", "優格"), ("牛油果", "酪梨"),
        ("菠蘿", "鳳梨"), ("獼猴桃", "奇異果"), ("方便麵", "泡麵"), ("激活", "啟用"), ("程序員", "程式設計師"), ("數據庫", "資料庫"),
        ("服務器", "伺服器"), ("U盤", "隨身碟"), ("充電寶", "行動電源"), ("移動電話", "手機"), ("菜單", "選單"), ("優化", "最佳化"),
        ("質量很好", "品質很好"), ("質量好", "品質好"), ("高質量", "高品質"), ("接地氣", "貼近生活"), ("靠譜", "可靠"),
    ]

    static func taiwanese(_ s: String) -> String {
        var t = s
        for (a, b) in twWords { t = t.replacingOccurrences(of: a, with: b) }
        return t
    }
}
