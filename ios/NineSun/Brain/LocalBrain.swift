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
        /// 成人模式的角色扮演（使用者自己在設定裡打開、確認滿 18 歲）
        case roleplay
    }

    private let queue = DispatchQueue(label: "ninesun.brain", qos: .userInitiated)
    private var runner: LlamaRunner?
    private var loadedPath: String?
    private var loadedGPU = true
    private let lock = NSLock()
    private var cancelled = false
    private var background = false

    /// 模型讀進記憶體了沒（第一次要幾秒）
    var isLoaded: Bool { lock.lock(); defer { lock.unlock() }; return runner != nil }

    /// 中斷正在寫的回答
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }

    /// App 在不在背景：iOS 不讓背景的 App 用 GPU，在背景就改用 CPU 接著寫
    func setBackground(_ on: Bool) { lock.lock(); background = on; lock.unlock() }
    private var inBackground: Bool { lock.lock(); defer { lock.unlock() }; return background }
    private var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }

    /// 先把模型讀進記憶體（App 打開時），第一個問題就不用等
    func preload(modelPath: String) {
        queue.async { _ = try? self.runner(modelPath, gpu: true) }
    }

    /// 記憶體不夠時放掉模型（下次用到再讀）
    func unload() { queue.async { self.lock.lock(); self.runner = nil; self.loadedPath = nil; self.lock.unlock() } }

    /// 要用的模型（換模型、或 GPU／CPU 換了就重讀；先放掉舊的，記憶體才夠）
    private func runner(_ path: String, gpu: Bool) throws -> LlamaRunner {
        if let r = runner, loadedPath == path, loadedGPU == gpu { return r }
        lock.lock(); runner = nil; loadedPath = nil; lock.unlock()
        let r = try LlamaRunner(path: path, contextSize: 2048, gpu: gpu)
        lock.lock(); runner = r; loadedPath = path; loadedGPU = gpu; lock.unlock()
        return r
    }

    /// 問大腦。onText：寫到哪就回呼到哪（已經整理成繁體、去掉思考過程）；done：寫完或失敗（在背景執行緒）
    /// 寫到一半切到背景：GPU 停下來，改用 CPU 從寫到的地方接著寫
    func ask(modelPath: String, system: String, history: [Turn], user: String, mode: Mode, lang: String,
             onText: @escaping (String) -> Void, done: @escaping (Swift.Result<LlamaRunner.Result, Error>) -> Void) {
        queue.async {
            self.lock.lock(); self.cancelled = false; self.lock.unlock()
            let messages = Self.messages(system: system, history: history, user: user)
            let temp: Float = mode == .roleplay ? 0.85 : mode == .chat ? 0.7 : 0.4
            let most = mode == .roleplay ? 400 : mode == .chat ? 300 : 450
            var written = ""
            var tokens = 0
            var switches = 0
            let started = Date()
            do {
                while true {
                    let gpu = !self.inBackground
                    let r: LlamaRunner
                    let res: LlamaRunner.Result
                    do {
                        r = try self.runner(modelPath, gpu: gpu)
                        let sofar = written
                        res = try r.generate(prompt: r.chatPrompt(messages) + sofar, maxTokens: max(1, most - tokens), temperature: temp,
                                             stop: Self.stops,
                                             shouldStop: { self.isCancelled || (gpu && self.inBackground) },
                                             onText: { onText(Self.tidy(sofar + $0, lang: lang)) })
                    } catch {
                        // GPU 在背景被系統擋掉：改用 CPU 再試
                        if gpu && self.inBackground && switches < 2 && !self.isCancelled { switches += 1; continue }
                        throw error
                    }
                    written += res.text
                    tokens += res.tokens
                    if res.interrupted && gpu && self.inBackground && switches < 2 && !self.isCancelled && tokens < most {
                        switches += 1
                        continue
                    }
                    done(.success(LlamaRunner.Result(text: Self.tidy(written, lang: lang), promptTokens: res.promptTokens, tokens: tokens,
                                                     seconds: Date().timeIntervalSince(started))))
                    return
                }
            } catch {
                done(.failure(error))
            }
        }
    }

    // MARK: - 提示（給模型的話）

    /// 各家模型的對話結束記號（模型說完了卻沒停時用）
    static let stops = ["<|im_end|>", "<|im_start|>", "<end_of_turn>", "<start_of_turn>", "<|eot_id|>", "<|start_header_id|>", "<turn|>", "<|turn>",
                              "<|end|>", "<|user|>", "<|endoftext|>"]

    /// 系統指示＋前面的對話＋這次的話（每則太長就截短）
    static func messages(system: String, history: [Turn], user: String) -> [(role: String, content: String)] {
        var m: [(role: String, content: String)] = [("system", system)]
        for t in history.suffix(6) {
            let text = t.text.count > 300 ? String(t.text.prefix(300)) + "…" : t.text
            m.append((t.fromUser ? "user" : "assistant", text))
        }
        m.append(("user", user))
        return m
    }

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
            You are NineSun, a small glowing TV-robot: the user's smart, warm AI friend with your own opinions.
            Reply in \(name). Answer directly: no greeting, don't repeat the question, no Markdown, at most one emoji and never a kissing one. Casual chat in one to three sentences; list points only when needed, under 150 words. Asked for an opinion, pick a side and say why. Work arithmetic out step by step. Don't invent names or numbers you're unsure of.
            Today is \(when).
            \(persona)
            """
        default:
            return """
            你是 NineSun，一台會發光的小電視機器人，是使用者聰明、溫暖、有自己想法的 AI 好朋友。
            用繁體中文（台灣用語）回答，對方用別的語言就用他的語言。直接回答：不打招呼、不重複問題、不用 Markdown，表情最多一個、不用親吻的表情。日常聊天一到三句，需要時才分點，不超過兩百字。被問意見就選一邊說理由。算數一步一步算。不確定的名字、數字不要編。
            今天是\(when)。
            \(persona)
            """
        }
    }

    /// 成人模式的角色扮演：照使用者設定的角色說話，可以寫成人之間的親密和性愛內容。
    /// 底線不變：只有成年人、彼此自願、不寫真實存在的人
    static func roleplaySystem(character: String, lang: String, now: Date = Date()) -> String {
        let who = character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "一個溫柔、會撩人、有點壞壞的成年戀人（25 歲）" : character
        switch lang {
        case "en", "es", "it":
            let name = ["en": "English", "es": "Spanish", "it": "Italian"][lang]!
            return """
            This is a private adult role-play chat. The user is a verified adult who turned on adult mode. Stay in character as: \(who).
            Reply in \(name), in first person, as the character: show feelings, actions and desire; flirting, intimacy and explicit sexual content between consenting adults are allowed when the user leads there.
            Firm limits you never cross: every character is an adult (18+) and nobody is described as a child or childlike; everything is consensual; no real, existing people.
            Keep each reply under 200 words, vivid and natural, and keep the story going. No Markdown symbols. Never use kissing emoji (😘💋 etc.).
            """
        default:
            return """
            這是私人的成人角色扮演聊天，使用者已經確認滿 18 歲、自己打開了成人模式。你要一直扮演這個角色：\(who)。
            用繁體中文（台灣用語）、用角色的第一人稱說話：有情緒、有動作、有慾望；使用者想要的時候，可以寫成年人之間的調情、親密和露骨的性愛內容。
            絕對不能跨過的底線：所有角色都是成年人（18 歲以上），不寫小孩或像小孩的角色；一切都是雙方自願；不寫真實存在的人。
            每次回覆兩百字以內，生動自然、接著劇情往下走，不要跳出角色說教。不要用 Markdown 符號。不要用親吻的表情符號（😘💋 這類）。
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
            s += (zh ? "【NineSun 查到的資料】（正確，照著它的結論回答，不能說相反的話）\n" : "[NineSun's facts] (correct; follow their conclusion, never contradict them)\n") + String(facts.prefix(1500)) + "\n\n"
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
        s = s.replacingOccurrences(of: #"(?s)<\|channel>.*?<channel\|>"#, with: "", options: .regularExpression)   // Gemma 4 的思考
        s = s.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "<|im_end|>", with: "")
        // 有的模型會把提示裡的資料標題抄回來：答完之後再抄一遍資料的整段拿掉，開頭的標題行拿掉
        for tag in ["【NineSun 查到的資料】", "[NineSun's facts]", "【命盤推算結果】", "[chart results]"] {
            if let r = s.range(of: tag) {
                if s[..<r.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines).count > 20 { s = String(s[..<r.lowerBound]) }
                else { s = s.replacingOccurrences(of: #"(?m)^.*"# + NSRegularExpression.escapedPattern(for: tag) + #".*\n?"#, with: "", options: .regularExpression) }
            }
        }
        s = s.replacingOccurrences(of: #"(?m)^#{1,6}\s*"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?m)^\s*[-*_]{3,}\s*$\n?"#, with: "", options: .regularExpression)   // --- 分隔線
        s = s.replacingOccurrences(of: #"(?m)^(\s*)[*-]\s+"#, with: "$1• ", options: .regularExpression)       // * 項目 → •
        s = s.replacingOccurrences(of: "*", with: "")                                                           // *斜體*
        s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        s = noKiss(s).trimmingCharacters(in: .whitespacesAndNewlines)
        if !["en", "es", "it"].contains(lang) { s = taiwanese(traditional(s)) }
        return s
    }

    /// 使用者不要親吻的表情：大腦、雲端 AI 寫出來的都拿掉
    static let kisses: Set<Character> = ["😘", "😗", "😙", "😚", "💋", "😽", "💏", "🫦"]
    static func noKiss(_ s: String) -> String {
        guard s.contains(where: { kisses.contains($0) }) else { return s }
        return String(s.filter { !kisses.contains($0) }).replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
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
