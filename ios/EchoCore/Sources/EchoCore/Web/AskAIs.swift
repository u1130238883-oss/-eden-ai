import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 請其他 AI 幫忙（用各家正式的 API，金鑰只存在使用者的手機）。
///
/// 流程：NineSun 先自己上網查 → 沒把握、或要推理／比較／步驟的題目 → 同時問幾家 AI →
/// 整理各家的重點、哪裡一致、哪裡不同 → 拿網路上讀到的資料查證 → 給出 NineSun 自己的結論。
///
/// 預設用 OpenRouter：一把金鑰可以問好幾家，免費模型（名稱結尾是 :free）每天有次數上限；
/// 帳戶儲值後也可以指定 Claude、Grok 等付費模型。Gemini 金鑰是選用的（可調低安全過濾）。
public enum AskAIs {
    public struct Config: Equatable, Sendable {
        public var openRouterKey: String
        public var geminiKey: String
        /// 指定 OpenRouter 的模型（空的就自動挑三個不同家的免費模型）
        public var models: [String]

        public init(openRouterKey: String = "", geminiKey: String = "", models: [String] = []) {
            var or = openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines)
            var g = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            // Google AI Studio 的金鑰（AIza 開頭）貼錯格子也照樣用：它是 Gemini 的金鑰，不是 OpenRouter 的
            if or.hasPrefix("AIza") || or.hasPrefix("AQ.") { if g.isEmpty { g = or }; or = "" }
            if g.hasPrefix("sk-or-") { if or.isEmpty { or = g }; g = "" }
            self.openRouterKey = or
            self.geminiKey = g
            self.models = models.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }

        /// Claude（Anthropic 官方 API）
        public var anthropicKey = ""
        /// 跟 OpenAI 格式一樣的幾家（ChatGPT、Grok、DeepSeek、Groq）
        public var compat: [Provider] = []

        public var enabled: Bool { !openRouterKey.isEmpty || !geminiKey.isEmpty || !anthropicKey.isEmpty || !compat.isEmpty }

        /// 貼上好幾把金鑰（一行一把、順序不拘），照開頭認出是哪一家
        public init(keys: [String]) {
            self.init()
            var unknown: [String] = []
            for raw in keys {
                let k = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard k.count >= 10 else { continue }
                // Google AI Studio 的金鑰：舊的是 AIza 開頭，新的是 AQ. 開頭
                if k.hasPrefix("AIza") || k.hasPrefix("AQ.") { if geminiKey.isEmpty { geminiKey = k } }
                else if k.hasPrefix("sk-or-") { if openRouterKey.isEmpty { openRouterKey = k } }
                else if k.hasPrefix("sk-ant-") { if anthropicKey.isEmpty { anthropicKey = k } }
                else if let p = Provider.detect(k) { if !compat.contains(where: { $0.name == p.name }) { compat.append(p) } }
                else { unknown.append(k) }
            }
            // 認不出開頭的金鑰：最可能是 Google 換了新格式，先當成 Gemini 的試試看
            if geminiKey.isEmpty, let k = unknown.first { geminiKey = k }
        }

        /// 認出了哪幾家（設定頁顯示用）
        public var names: [String] {
            (anthropicKey.isEmpty ? [] : ["Claude"]) + compat.map(\.name) + (geminiKey.isEmpty ? [] : ["Gemini"])
                + (openRouterKey.isEmpty ? [] : ["OpenRouter"])
        }
    }

    /// 跟 OpenAI 格式一樣的 AI（同一種呼叫方式，換網址、模型和金鑰）
    public struct Provider: Equatable, Sendable {
        public let name: String
        public let endpoint: String
        /// 依序試：前一個找不到、忙線就換下一個
        public let models: [String]
        public let key: String

        static func detect(_ k: String) -> Provider? {
            if k.hasPrefix("xai-") {
                return Provider(name: "Grok", endpoint: "https://api.x.ai/v1/chat/completions", models: ["grok-4", "grok-3", "grok-3-mini"], key: k)
            }
            if k.hasPrefix("gsk_") {
                return Provider(name: "Groq", endpoint: "https://api.groq.com/openai/v1/chat/completions",
                                models: ["llama-3.3-70b-versatile", "openai/gpt-oss-120b", "llama-3.1-8b-instant"], key: k)
            }
            if k.hasPrefix("sk-") {
                // DeepSeek 的金鑰是 sk- 加 32 個十六進位字；其他 sk- 開頭的是 OpenAI（ChatGPT）
                let rest = k.dropFirst(3)
                if rest.count == 32 && rest.allSatisfy(\.isHexDigit) {
                    return Provider(name: "DeepSeek", endpoint: "https://api.deepseek.com/chat/completions", models: ["deepseek-chat"], key: k)
                }
                return Provider(name: "ChatGPT", endpoint: "https://api.openai.com/v1/chat/completions",
                                models: ["gpt-5-mini", "gpt-4.1-mini", "gpt-4o-mini"], key: k)
            }
            return nil
        }
    }

    /// 一家 AI 的回答
    public struct Reply: Equatable, Sendable {
        public let name: String
        public let text: String
        public let error: String?

        public init(name: String, text: String, error: String?) {
            self.name = name; self.text = text; self.error = error
        }

        public var conclusion: String { AskAIs.conclusion(text) }
        public var points: [String] { AskAIs.points(text) }
    }

    // MARK: - 要不要問

    /// 自己沒把握，或是要推理、比較、步驟的題目（網路上的句子拼不出好答案）就問
    public static func shouldAsk(_ r: WebAgent.Result) -> Bool {
        if !r.found || !r.answered || !r.confident { return true }
        return ["reason", "steps", "compare"].contains(r.want ?? "")
    }

    // MARK: - 問

    static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 45
        c.timeoutIntervalForResource = 60
        c.urlCache = nil
        return URLSession(configuration: c)
    }()

    static func send(_ req: URLRequest) async -> (code: Int, data: Data?) {
        let r = await sendDetailed(req)
        return (r.code, r.data)
    }

    /// 連不上時也帶回原因（逾時、沒有網路、找不到伺服器…）
    static func sendDetailed(_ req: URLRequest) async -> (code: Int, data: Data?, failure: String?) {
        await withCheckedContinuation { c in
            session.dataTask(with: req) { d, r, e in
                c.resume(returning: ((r as? HTTPURLResponse)?.statusCode ?? 0, d, e.map { ($0 as NSError).localizedDescription }))
            }.resume()
        }
    }

    /// 伺服器回的錯誤說明（{"error":{"message":…}} 或 {"message":…}）
    static func serverMessage(_ d: Data?) -> String? {
        guard let d, let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            return d.flatMap { String(data: $0.prefix(200), encoding: .utf8) }.flatMap { $0.isEmpty ? nil : $0 }
        }
        if let e = o["error"] as? [String: Any], let m = e["message"] as? String { return m }
        if let e = o["error"] as? String { return e }
        return o["message"] as? String
    }

    /// 錯誤代碼＋伺服器說明＋該怎麼辦
    static func explain(code: Int, data: Data?, failure: String?) -> String {
        var t = httpError(code)
        if code == 0, let failure { t += "：\(failure)" }
        if let m = serverMessage(data) {
            t += "：\(WebSearch.clip(m, 160))"
            let l = m.lowercased()
            if l.contains("data policy") || l.contains("privacy") {
                t += "\n→ 到 openrouter.ai/settings/privacy，把允許免費模型（Free model publication / training）的選項打開，免費模型才會回答。"
            } else if l.contains("credit") || l.contains("insufficient") {
                t += "\n→ 這個模型要付費，或帳戶額度不夠；不指定模型就會用免費的。"
            } else if l.contains("missing authentication") || l.contains("no auth") {
                t += "\n→ 這不是 OpenRouter 的金鑰（OpenRouter 的是 sk-or-v1- 開頭）。Google AI Studio 的金鑰（AIza 開頭）請貼到「Gemini 金鑰」那一格。"
            } else if l.contains("location") && l.contains("not supported") {
                t += "\n→ Google 不開放你所在的地區使用 Gemini API（例如香港、中國大陸），請改用 OpenRouter。"
            } else if l.contains("user not found") || l.contains("invalid") && l.contains("key") {
                t += "\n→ 金鑰不對：到 openrouter.ai/keys 重新建立一把，整串貼上（sk-or-v1-…）。"
            }
        }
        return t
    }

    /// 給每家 AI 的指示：先一句結論，再幾點重點；不確定就說不確定、不要編造
    static func prompt(_ question: String, evidence: [String], lang L: Lang) -> (system: String, user: String) {
        let system: String
        switch L {
        case .zh: system = "你是 NineSun 的顧問。用繁體中文（台灣用語）回答。第一行用「結論：」開頭，一句話講答案；接著最多 4 點重點，每點一行、用「- 」開頭。不確定就直說不確定，不要編造數字、日期、人名或出處。"
        case .en: system = "You advise NineSun. Start the first line with \"Conclusion:\" and answer in one sentence; then give at most 4 key points, one per line, starting with \"- \". If unsure, say so. Never invent numbers, dates, names or sources."
        case .es: system = "Asesoras a NineSun. Empieza la primera línea con «Conclusión:» y responde en una frase; luego como máximo 4 puntos, uno por línea, empezando con «- ». Si no estás seguro, dilo. No inventes números, fechas, nombres ni fuentes."
        case .it: system = "Consigli NineSun. Inizia la prima riga con «Conclusione:» e rispondi in una frase; poi al massimo 4 punti, uno per riga, che iniziano con «- ». Se non sei sicuro, dillo. Non inventare numeri, date, nomi o fonti."
        }
        var user = question
        if !evidence.isEmpty {
            user += "\n\n" + (L == .zh ? "（參考：NineSun 在網路上讀到的資料，可能不完整或有錯）" : "(For reference — what NineSun read on the web; may be incomplete or wrong)")
            for e in evidence.prefix(6) { user += "\n- " + e }
        }
        return (system, user)
    }

    /// 同時問所有設定好的 AI（OpenRouter 最多三個模型＋Gemini），照順序回傳
    public static func ask(_ question: String, evidence: [String], lang L: Lang, config: Config) async -> [Reply] {
        let p = prompt(question, evidence: evidence, lang: L)
        var pool: [String] = []
        if !config.openRouterKey.isEmpty {
            pool = config.models.isEmpty ? await freeModels() : config.models
        }
        // 三個位置：每個先問自己的模型，失敗（下架、次數用完）就換清單裡下一個沒用到的
        let slots = min(3, pool.count)
        let orKey = config.openRouterKey, gKey = config.geminiKey
        let models = pool
        return await withTaskGroup(of: (Int, Reply).self) { g -> [Reply] in
            for i in 0..<slots {
                let tries = stride(from: i, to: min(models.count, i + 3 * slots), by: slots).map { models[$0] }
                g.addTask {
                    var last = Reply(name: displayNames([tries[0]])[0], text: "", error: "沒有回答")
                    for m in tries {
                        let r = await openRouter(m, name: displayNames([m])[0], system: p.system, user: p.user, key: orKey)
                        if r.error == nil { return (i, r) }
                        last = r
                        // 金鑰錯、連不上：換模型也沒用
                        if r.error?.hasPrefix("金鑰不對") == true || r.error?.hasPrefix("連不上") == true { break }
                    }
                    return (i, last)
                }
            }
            var next = slots
            if !gKey.isEmpty {
                let i = next
                g.addTask { (i, await gemini(system: p.system, user: p.user, key: gKey)) }
                next += 1
            }
            if !config.anthropicKey.isEmpty {
                let i = next, k = config.anthropicKey
                g.addTask { (i, await claude(system: p.system, user: p.user, key: k)) }
                next += 1
            }
            for prov in config.compat {
                let i = next
                g.addTask { (i, await compatible(prov, system: p.system, user: p.user)) }
                next += 1
            }
            var out: [(Int, Reply)] = []
            for await r in g { out.append(r) }
            return out.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    // MARK: - 全部交給 AI 回答（設定頁的開關打開時）

    /// 對話裡的一句（給 AI 看前後文）
    public struct Turn: Equatable, Sendable {
        public let fromUser: Bool
        public let text: String
        public init(fromUser: Bool, text: String) { self.fromUser = fromUser; self.text = text }
    }

    static func chatSystem(evidence: [String], lang L: Lang, persona: String = "") -> String {
        var s: String
        switch L {
        case .zh: s = "你是 NineSun，一個聰明、可靠的 AI 助理。用繁體中文（台灣用語）回答：先直接給答案，再補充最重要的幾個重點；需要步驟就分步驟，需要比較就並排比較。"
            + "說話自然、清楚，不要繞圈子，也不要扯到算命或命理（除非對方問的就是這個）。不要用 Markdown 符號（不要 ** 或 #）。不確定就說不確定，不要編造數字、日期、人名或出處。"
        case .en: s = "You are NineSun, a smart, warm and direct AI assistant. Answer naturally: give the answer first, then the key points, briefly. If unsure, say so; never invent numbers, dates, names or sources."
        case .es: s = "Eres NineSun, un asistente de IA inteligente, cercano y directo. Responde con naturalidad: primero la respuesta, luego lo esencial, sin alargarte. Si no estás seguro, dilo; no inventes datos."
        case .it: s = "Sei NineSun, un assistente IA intelligente, gentile e diretto. Rispondi in modo naturale: prima la risposta, poi i punti chiave, in breve. Se non sei sicuro, dillo; non inventare dati."
        }
        if !persona.isEmpty { s += "\n\n" + persona }
        if !evidence.isEmpty {
            s += (L == .zh ? "\n\n以下是剛才在網路上查到的資料，可以參考（可能不完整或有錯，跟你知道的不同時以可靠的為準）：\n" : "\n\nWeb results just found (may be incomplete or wrong):\n")
                + evidence.prefix(8).map { "- " + $0 }.joined(separator: "\n")
        }
        return s
    }

    /// 去掉 Markdown 符號（**粗體**、# 標題、* 項目），手機上看起來乾淨
    public static func plain(_ t: String) -> String {
        var out: [String] = []
        for var line in t.components(separatedBy: "\n") {
            line = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
            while line.hasPrefix("#") { line.removeFirst() }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") { line = "• " + trimmed.dropFirst(2) }
            out.append(line.trimmingCharacters(in: .whitespaces))
        }
        return out.joined(separator: "\n").replacingOccurrences(of: "\n\n\n", with: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 問一家（帶著對話）；Gemini 會自己用 Google 搜尋最新資料
    static func one(_ who: String, config: Config, system: String, message: String, past: [Turn]) async -> Reply {
        switch who {
        case "Claude": return await claude(system: system, user: message, key: config.anthropicKey, history: past)
        case "Gemini": return await gemini(system: system, user: message, key: config.geminiKey, history: past, search: true)
        case "OpenRouter":
            let pool = config.models.isEmpty ? await freeModels() : config.models
            var last = Reply(name: "OpenRouter", text: "", error: "沒有可用的模型")
            for m in pool.prefix(4) {
                let r = await openRouter(m, name: displayNames([m])[0], system: system, user: message, key: config.openRouterKey, history: past)
                if r.error == nil { return r }
                last = r
                if r.error?.hasPrefix("金鑰不對") == true { break }
            }
            return last
        default:
            guard let p = config.compat.first(where: { $0.name == who }) else { return Reply(name: who, text: "", error: "沒有金鑰") }
            return await compatible(p, system: system, user: message, history: past)
        }
    }

    /// 直接請 AI 回答（帶著最近的對話），用 NineSun 自己的口吻和見解。
    /// 只有一家：請它從幾個角度想過再給出有判斷的答案。好幾家：每一家都先回答，再請其中一家把大家的說法融合成 NineSun 自己的看法。
    public static func chat(_ message: String, history: [Turn], evidence: [String], lang L: Lang, config: Config,
                            persona: String = "") async -> Reply {
        let system = chatSystem(evidence: evidence, lang: L, persona: persona)
        let past = Array(history.suffix(10))
        let who = config.names
        guard !who.isEmpty else { return Reply(name: "AI", text: "", error: "還沒填金鑰") }
        if who.count == 1 {
            let r = await one(who[0], config: config, system: system, message: message, past: past)
            return r.error == nil ? Reply(name: r.name, text: plain(r.text), error: nil) : r
        }
        // 好幾家：同時問
        let drafts = await withTaskGroup(of: (Int, Reply).self) { g -> [Reply] in
            for (i, w) in who.enumerated() { g.addTask { (i, await one(w, config: config, system: system, message: message, past: past)) } }
            var out: [(Int, Reply)] = []
            for await r in g { out.append(r) }
            return out.sorted { $0.0 < $1.0 }.map(\.1)
        }
        let ok = drafts.filter { $0.error == nil }
        guard let first = ok.first else {
            return Reply(name: "AI", text: "", error: drafts.map { $0.name + "：" + ($0.error ?? "") }.joined(separator: "\n"))
        }
        if ok.count == 1 { return Reply(name: first.name, text: plain(first.text), error: nil) }
        // 融合：把各家的回答交給第一家成功的，寫成 NineSun 自己的一個答案
        let notes = ok.map { "【\($0.name)】\n" + WebSearch.clip($0.text, 1200) }.joined(separator: "\n\n")
        let fuse = system + "\n\n下面是幾位顧問對同一個問題的回答。請把它們融合成你（NineSun）自己的一個回答："
            + "先給你的結論；說明大家一致的地方，不同的地方你比較相信哪一個、為什麼；最後加上你自己的見解。不要逐一轉述每一位，也不要提「顧問」這兩個字。\n\n" + notes
        // 由回答成功的其中一家來融合（有 Claude 就用 Claude）
        let okWho = who.indices.filter { drafts[$0].error == nil }.map { who[$0] }
        let writer = okWho.contains("Claude") ? "Claude" : okWho[0]
        let merged = await one(writer, config: config, system: fuse, message: message, past: past)
        guard merged.error == nil else { return Reply(name: first.name, text: plain(first.text), error: nil) }
        return Reply(name: "NineSun（融合 " + ok.map(\.name).joined(separator: "、") + "）", text: plain(merged.text), error: nil)
    }

    // MARK: - ChatGPT、Grok、DeepSeek、Groq（跟 OpenAI 一樣的格式）

    static let retryCodes = [404, 429, 500, 503, 529].map(httpError)

    static func compatible(_ p: Provider, system: String, user: String, history: [Turn] = []) async -> Reply {
        var last = Reply(name: p.name, text: "", error: "沒有回答")
        for m in p.models {
            let r = await chatCompletion(p.endpoint, model: m, name: p.name, system: system, user: user, key: p.key, history: history)
            guard let err = r.error, retryCodes.contains(where: { err.hasPrefix($0) }) else { return r }
            last = r
        }
        return last
    }

    static func chatCompletion(_ endpoint: String, model: String, name: String, system: String, user: String, key: String,
                               history: [Turn] = []) async -> Reply {
        guard let url = URL(string: endpoint) else { return Reply(name: name, text: "", error: "網址錯誤") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let past: [[String: Any]] = history.map { ["role": $0.fromUser ? "user" : "assistant", "content": $0.text] }
        let body: [String: Any] = ["model": model,
                                   "messages": [["role": "system", "content": system]] + past + [["role": "user", "content": user]]]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (code, data, failure) = await sendDetailed(req)
        guard code == 200 else { return Reply(name: name, text: "", error: explain(code: code, data: data, failure: failure)) }
        guard let t = openRouterText(data) else {
            return Reply(name: name, text: "", error: serverMessage(data).map { "沒有回答：" + WebSearch.clip($0, 160) } ?? "沒有回答")
        }
        return Reply(name: name, text: t, error: nil)
    }

    // MARK: - Claude（Anthropic 官方 API）

    static func claude(system: String, user: String, key: String, history: [Turn] = []) async -> Reply {
        var last = Reply(name: "Claude", text: "", error: "沒有回答")
        for model in ["claude-sonnet-5-5", "claude-haiku-5-5", "claude-opus-5-5"] {
            guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { break }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue(key, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let msgs: [[String: Any]] = history.map { ["role": $0.fromUser ? "user" : "assistant", "content": $0.text] }
                + [["role": "user", "content": user]]
            let body: [String: Any] = ["model": model, "max_tokens": 1500, "system": system, "messages": msgs]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            let (code, data, failure) = await sendDetailed(req)
            if code == 200, let t = claudeText(data) { return Reply(name: "Claude", text: t, error: nil) }
            last = Reply(name: "Claude", text: "", error: code == 200 ? "沒有回答" : explain(code: code, data: data, failure: failure))
            guard let err = last.error, retryCodes.contains(where: { err.hasPrefix($0) }) else { return last }
        }
        return last
    }

    static func claudeText(_ d: Data?) -> String? {
        guard let d, let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let content = o["content"] as? [[String: Any]] else { return nil }
        let t = content.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined()
        return t.isEmpty ? nil : t
    }

    // MARK: - OpenRouter

    static func openRouter(_ model: String, name: String, system: String, user: String, key: String, history: [Turn] = []) async -> Reply {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            return Reply(name: name, text: "", error: "網址錯誤")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("NineSun", forHTTPHeaderField: "X-Title")
        let past: [[String: Any]] = history.map { ["role": $0.fromUser ? "user" : "assistant", "content": $0.text] }
        let body: [String: Any] = ["model": model,
                                   "messages": [["role": "system", "content": system]] + past + [["role": "user", "content": user]]]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (code, data, failure) = await sendDetailed(req)
        guard code == 200 else { return Reply(name: name, text: "", error: explain(code: code, data: data, failure: failure)) }
        // 有時候 200 但內容是錯誤（{"error":…}）
        guard let t = openRouterText(data) else {
            return Reply(name: name, text: "", error: serverMessage(data).map { "沒有回答：" + WebSearch.clip($0, 160) } ?? "沒有回答")
        }
        return Reply(name: name, text: t, error: nil)
    }

    /// 設定頁的「測試連線」：每把金鑰各問一句，把成功或真正的錯誤原因列出來
    public static func test(config: Config) async -> String {
        guard config.enabled else { return "還沒填金鑰。" }
        let replies = await ask("請只回答兩個字：收到", evidence: [], lang: .zh, config: config)
        guard !replies.isEmpty else { return "沒有可以問的模型（OpenRouter 的模型清單抓不到）。" }
        return replies.map { r in
            r.error == nil ? "✅ \(r.name)：連上了（回答：\(WebSearch.clip(r.text, 30))）" : "❌ \(r.name)：\(r.error!)"
        }.joined(separator: "\n")
    }

    static func openRouterText(_ d: Data?) -> String? {
        guard let d, let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let ch = o["choices"] as? [[String: Any]], let m = ch.first?["message"] as? [String: Any],
              let t = m["content"] as? String else { return nil }
        let s = stripThinking(t)
        return s.isEmpty ? nil : s
    }

    /// 推理型模型會把思考過程放在 <think>…</think> 裡，只留答案
    static func stripThinking(_ t: String) -> String {
        var s = t
        while let a = s.range(of: "<think>"), let b = s.range(of: "</think>", range: a.upperBound..<s.endIndex) {
            s.removeSubrange(a.lowerBound..<b.upperBound)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func httpError(_ code: Int) -> String {
        switch code {
        case 0: return "連不上（網路或逾時）"
        case 400: return "請求格式不對"
        case 401, 403: return "金鑰不對或沒有權限"
        case 402: return "這個模型要付費（帳戶需要儲值）"
        case 404: return "找不到這個模型"
        case 429: return "今天的免費次數用完了，或問得太頻繁"
        case 500: return "對方伺服器出錯"
        case 503, 529: return "對方忙線中（用的人太多）"
        default: return "沒回應（\(code)）"
        }
    }

    // MARK: - 免費模型

    /// 備用名單（抓不到最新名單時用）
    static let fallbackModels = ["deepseek/deepseek-chat-v3-0324:free", "qwen/qwen3-235b-a22b:free", "meta-llama/llama-3.3-70b-instruct:free"]
    nonisolated(unsafe) static var cachedFree: (date: Date, ids: [String])?

    /// OpenRouter 現在有哪些免費模型（不用金鑰就能查），一天抓一次
    public static func freeModels() async -> [String] {
        if let c = cachedFree, Date().timeIntervalSince(c.date) < 86_400, !c.ids.isEmpty { return c.ids }
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else { return fallbackModels }
        let (code, data) = await send(URLRequest(url: url))
        guard code == 200, let ids = freeModelIDs(data), !ids.isEmpty else { return fallbackModels }
        // 先放挑好的三家，後面接其他免費模型當備用（某個下架或次數用完就換）
        let picked = pickFamilies(ids)
        let rest = ids.filter { id in !picked.contains(id) && !["vision", "-vl", "coder", "embed", "guard", "audio", "image"].contains { id.lowercased().contains($0) } }
        let all = picked + rest
        cachedFree = (Date(), all)
        return all
    }

    static func freeModelIDs(_ d: Data?) -> [String]? {
        guard let d, let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let list = o["data"] as? [[String: Any]] else { return nil }
        return list.compactMap { m -> String? in
            guard let id = m["id"] as? String, id.hasSuffix(":free") else { return nil }
            if let n = m["context_length"] as? Int, n < 8000 { return nil }
            return id
        }
    }

    /// 挑三個不同家的模型（DeepSeek、Qwen、Llama 優先），同一家挑聊天用、參數大的；看圖的、寫程式專用的不要
    static func pickFamilies(_ ids: [String]) -> [String] {
        let order = ["deepseek", "qwen", "meta-llama", "google", "mistralai", "moonshotai", "z-ai", "nvidia", "microsoft"]
        func usable(_ id: String) -> Bool {
            let l = id.lowercased()
            return !["vision", "-vl", "coder", "embed", "guard", "audio", "image"].contains { l.contains($0) }
        }
        func score(_ id: String) -> Double {
            let l = id.lowercased()
            var s = 0.0
            if ["chat", "instruct", "-it"].contains(where: { l.contains($0) }) { s += 2 }
            if ["r1", "thinking", "reason"].contains(where: { l.contains($0) }) { s -= 2 }  // 推理型很慢
            if let m = Understanding.match(l, #"(\d+)b"#)?[1], let n = Double(m) { s += min(n, 700) / 100 }
            return s
        }
        var out: [String] = []
        for fam in order where out.count < 3 {
            let cands = ids.filter { $0.hasPrefix(fam + "/") && usable($0) }
            if let best = cands.max(by: { score($0) < score($1) }) { out.append(best) }
        }
        for id in ids where out.count < 3 && !out.contains(id) && usable(id) { out.append(id) }
        return out
    }

    /// 模型 → 給人看的名字（同一家兩個模型時加上型號）
    static func displayNames(_ models: [String]) -> [String] {
        func family(_ id: String) -> String {
            let owner = id.split(separator: "/").first.map(String.init) ?? id
            let known = ["deepseek": "DeepSeek", "qwen": "Qwen", "meta-llama": "Llama", "google": "Gemma", "mistralai": "Mistral",
                         "anthropic": "Claude", "x-ai": "Grok", "openai": "GPT", "moonshotai": "Kimi", "z-ai": "GLM",
                         "nvidia": "Nemotron", "microsoft": "Phi"]
            if owner == "google" && id.contains("gemini") { return "Gemini" }
            return known[owner] ?? owner.capitalized
        }
        let fams = models.map(family)
        return models.enumerated().map { i, id in
            let f = fams[i]
            guard fams.filter({ $0 == f }).count > 1 else { return f }
            let model = id.split(separator: "/").last.map { String($0).replacingOccurrences(of: ":free", with: "") } ?? id
            return f + "（\(model)）"
        }
    }

    // MARK: - Gemini（選用）

    static func gemini(system: String, user: String, key: String, history: [Turn] = [], search: Bool = false) async -> Reply {
        var last: Reply?
        // 一個模型忙線（503）、找不到（404）、次數用完（429）或出錯（500）就換下一個；金鑰錯、地區不支援就不用再試
        let retry = [404, 429, 500, 503].map(httpError)
        for model in ["gemini-flash-latest", "gemini-2.5-flash", "gemini-2.0-flash", "gemini-flash-lite-latest", "gemini-2.5-flash-lite"] {
            var r = await geminiCall(model, system: system, user: user, key: key, history: history, search: search)
            // 有些模型或帳號不能用 Google 搜尋：不搜尋再問一次
            if search, r.error != nil {
                r = await geminiCall(model, system: system, user: user, key: key, history: history, search: false)
            }
            guard let err = r.error, retry.contains(where: { err.hasPrefix($0) }) else { return r }
            last = r
        }
        if let last { return last }
        return Reply(name: "Gemini", text: "", error: "找不到可用的 Gemini 模型")
    }

    static func geminiCall(_ model: String, system: String, user: String, key: String, history: [Turn] = [], search: Bool = false) async -> Reply {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            return Reply(name: "Gemini", text: "", error: "網址錯誤")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 能調的安全過濾都調到最低（核心的保護 Google 一定會留著）
        let cats = ["HARM_CATEGORY_HARASSMENT", "HARM_CATEGORY_HATE_SPEECH", "HARM_CATEGORY_SEXUALLY_EXPLICIT", "HARM_CATEGORY_DANGEROUS_CONTENT"]
        var body: [String: Any] = [
            "system_instruction": ["parts": [["text": system]]],
            "contents": history.map { ["role": $0.fromUser ? "user" : "model", "parts": [["text": $0.text]]] }
                + [["role": "user", "parts": [["text": user]]]],
            "safetySettings": cats.map { ["category": $0, "threshold": "BLOCK_NONE"] },
        ]
        // 讓 Gemini 自己用 Google 搜尋最新的資料
        if search { body["tools"] = [["google_search": [String: Any]()]] }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (code, data, failure) = await sendDetailed(req)
        guard code == 200 else { return Reply(name: "Gemini", text: "", error: explain(code: code, data: data, failure: failure)) }
        let (text, blocked) = geminiText(data)
        if let text { return Reply(name: "Gemini", text: text, error: nil) }
        return Reply(name: "Gemini", text: "", error: blocked ? "被 Gemini 的安全過濾擋下" : "沒有回答")
    }

    /// Gemini 的回答；被安全過濾擋下時 blocked = true
    static func geminiText(_ d: Data?) -> (text: String?, blocked: Bool) {
        guard let d, let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return (nil, false) }
        if let fb = o["promptFeedback"] as? [String: Any], fb["blockReason"] != nil { return (nil, true) }
        guard let c = (o["candidates"] as? [[String: Any]])?.first else { return (nil, false) }
        let parts = ((c["content"] as? [String: Any])?["parts"] as? [[String: Any]]) ?? []
        let t = parts.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return (t, false) }
        return (nil, (c["finishReason"] as? String) == "SAFETY")
    }

    // MARK: - 讀回答

    static let conclusionMarks = ["結論：", "結論:", "Conclusion:", "Conclusión:", "Conclusione:"]

    /// 一句話的結論（照格式寫的就取「結論：」那行，沒照格式就取第一句）
    public static func conclusion(_ text: String) -> String {
        let plain = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "#", with: "")
        for raw in plain.components(separatedBy: "\n") {
            let l = raw.trimmingCharacters(in: .whitespaces)
            for m in conclusionMarks where l.hasPrefix(m) {
                return WebSearch.clip(String(l.dropFirst(m.count)).trimmingCharacters(in: .whitespaces), 120)
            }
        }
        var out = ""
        for ch in plain.trimmingCharacters(in: .whitespacesAndNewlines) {
            out.append(ch)
            if "。！？!?\n".contains(ch) { break }
        }
        return WebSearch.clip(out.trimmingCharacters(in: .whitespacesAndNewlines), 120)
    }

    /// 重點（「- 」「• 」「1.」開頭的行，最多 4 點）
    public static func points(_ text: String) -> [String] {
        var out: [String] = []
        for raw in text.replacingOccurrences(of: "**", with: "").components(separatedBy: "\n") where out.count < 4 {
            var l = raw.trimmingCharacters(in: .whitespaces)
            if conclusionMarks.contains(where: { l.hasPrefix($0) }) { continue }
            if l.hasPrefix("- ") || l.hasPrefix("• ") || l.hasPrefix("* ") || l.hasPrefix("・") {
                l = String(l.drop(while: { "-•*・ ".contains($0) }))
            } else if let m = Understanding.match(l, #"^\d+[.、)）]\s*(.+)$"#)?[1] {
                l = m
            } else {
                continue
            }
            if !l.isEmpty { out.append(WebSearch.clip(l, 120)) }
        }
        return out
    }

    // MARK: - 比對

    static func numbers(_ s: String) -> Set<String> {
        guard let re = try? NSRegularExpression(pattern: #"\d[\d,，]*(?:\.\d+)?"#) else { return [] }
        let r = NSRange(s.startIndex..., in: s)
        return Set(re.matches(in: s, range: r).compactMap { m in
            Range(m.range, in: s).map { String(s[$0]).replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "，", with: "") }
        })
    }

    static func grams(_ s: String) -> Set<String> {
        let c = Array(Think.canonText(Think.key(s)))
        guard c.count >= 2 else { return Set(c.map(String.init)) }
        return Set((0..<(c.count - 1)).map { String(c[$0...$0 + 1]) })
    }

    static let negations = ["不是", "不會", "不能", "不可", "沒有", "無法", "並非", "不行", "不對", "不需要", "not ", "no ", "cannot", "isn't", "doesn't"]

    /// 兩個說法是不是同一個意思：一個包含另一個、數字對得上，或用的詞大多一樣（肯定、否定要一致）
    static func agree(_ a: String, _ b: String) -> Bool {
        let ka = Think.key(a), kb = Think.key(b)
        guard !ka.isEmpty, !kb.isEmpty else { return false }
        let na = negations.contains { a.lowercased().contains($0) }, nb = negations.contains { b.lowercased().contains($0) }
        if na != nb { return false }
        if ka.contains(kb) || kb.contains(ka) { return true }
        let numA = numbers(a), numB = numbers(b)
        if !numA.isEmpty && !numB.isEmpty { return !numA.isDisjoint(with: numB) }
        let ga = grams(a), gb = grams(b)
        let j = Double(ga.intersection(gb).count) / Double(max(1, ga.union(gb).count))
        return j >= 0.3
    }

    /// 網路上讀到的資料有沒有支持這個說法：跟 NineSun 自己查到的答案一樣、數字對得上，或說法的關鍵詞大多出現在同一句裡
    static func support(_ claim: String, evidence: [String], webAnswer: String?) -> String? {
        if let w = webAnswer, !w.isEmpty, agree(w, claim) { return "跟我在網路上查到的答案「\(w)」一樣" }
        let nums = numbers(claim)
        if !nums.isEmpty, let e = evidence.first(where: { !nums.isDisjoint(with: numbers($0)) }) {
            return "「\(WebSearch.clip(e, 70))」"
        }
        let g = grams(claim)
        guard g.count >= 3 else { return nil }
        if let e = evidence.first(where: { Double(g.intersection(grams($0)).count) / Double(g.count) >= 0.5 }) {
            return "「\(WebSearch.clip(e, 70))」"
        }
        return nil
    }

    // MARK: - 整理成給使用者看的回答

    public static func summarize(question: String, replies: [Reply], web: WebAgent.Result) -> String {
        let ok = replies.filter { $0.error == nil && !$0.text.isEmpty }
        var t = web.confident ? "🤖 我也同時問了 \(replies.count) 個 AI，對照一下：" : "🤖 這題我自己沒把握，所以同時問了 \(replies.count) 個 AI："
        for r in replies {
            if let e = r.error {
                t += "\n\n【\(r.name)】沒有回答（\(e)）"
                continue
            }
            t += "\n\n【\(r.name)】" + r.conclusion
            for p in r.points.prefix(3) { t += "\n  · " + p }
        }
        guard !ok.isEmpty else { return t + "\n\n其他 AI 這次都沒有回答，下面是我自己在網路上查到的。" }

        // 說法一樣的放一組，人多的在前面
        var groups: [[Reply]] = []
        for r in ok {
            if let i = groups.firstIndex(where: { agree($0[0].conclusion, r.conclusion) }) { groups[i].append(r) } else { groups.append([r]) }
        }
        groups.sort { $0.count > $1.count }
        func names(_ g: [Reply]) -> String { g.map(\.name).joined(separator: "、") }
        let top = groups[0]
        if top.count >= 2 {
            t += "\n\n✅ 一致：\(names(top)) 都認為「\(WebSearch.clip(top[0].conclusion, 80))」。"
        }
        let differ = top.count >= 2 ? Array(groups.dropFirst()) : (ok.count >= 2 ? groups : [])
        if !differ.isEmpty {
            t += (top.count >= 2 ? "\n" : "\n\n") + "⚠️ 不同："
                + differ.map { "\(names($0)) 說「\(WebSearch.clip($0[0].conclusion, 60))」" }.joined(separator: "；") + "。"
        }

        // 查證：用網路上讀到的資料檢查每一種說法
        t += "\n\n🧭 NineSun 查證後的結論："
        let checked = groups.map { (group: $0, proof: support($0[0].conclusion, evidence: web.evidence, webAnswer: web.shortAnswer)) }
        if web.confident, let w = web.shortAnswer, !w.isEmpty, !groups.contains(where: { agree($0[0].conclusion, w) }) {
            t += "我在網路上查到的是「\(w)」（有出處，見下面），跟 AI 的說法都不一樣；我以有出處的資料為準，AI 的說法當參考。"
        } else if let best = checked.first(where: { $0.proof != nil }) {
            t += "\(names(best.group)) 的說法「\(WebSearch.clip(best.group[0].conclusion, 80))」有網路資料支持（\(best.proof!)），我採用這個。"
            if best.group.count < top.count { t += "它不是多數，但有證據的比較可信。" }
        } else if top.count >= 2 {
            t += "多數 AI 認為「\(WebSearch.clip(top[0].conclusion, 80))」，但我在網路上沒找到直接的證據，請當參考；重要的事建議再看官方資料。"
        } else if ok.count == 1 {
            t += "只有 \(ok[0].name) 回答，網路上也沒找到能佐證的資料，請把它當參考。"
        } else {
            t += "各家說法不一，網路上也沒找到能判斷的證據，我不下結論；建議看官方或專業的來源。"
        }
        return t
    }
}
