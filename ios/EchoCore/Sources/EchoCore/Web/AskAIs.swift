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
            self.openRouterKey = openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines)
            self.geminiKey = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            self.models = models.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }

        public var enabled: Bool { !openRouterKey.isEmpty || !geminiKey.isEmpty }
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
        await withCheckedContinuation { c in
            session.dataTask(with: req) { d, r, _ in
                c.resume(returning: ((r as? HTTPURLResponse)?.statusCode ?? 0, d))
            }.resume()
        }
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
        var models: [String] = []
        if !config.openRouterKey.isEmpty {
            models = Array((config.models.isEmpty ? await freeModels() : config.models).prefix(3))
        }
        let names = displayNames(models)
        let orKey = config.openRouterKey, gKey = config.geminiKey
        return await withTaskGroup(of: (Int, Reply).self) { g -> [Reply] in
            for (i, m) in models.enumerated() {
                let name = names[i]
                g.addTask { (i, await openRouter(m, name: name, system: p.system, user: p.user, key: orKey)) }
            }
            if !gKey.isEmpty {
                let i = models.count
                g.addTask { (i, await gemini(system: p.system, user: p.user, key: gKey)) }
            }
            var out: [(Int, Reply)] = []
            for await r in g { out.append(r) }
            return out.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    // MARK: - OpenRouter

    static func openRouter(_ model: String, name: String, system: String, user: String, key: String) async -> Reply {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            return Reply(name: name, text: "", error: "網址錯誤")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("NineSun", forHTTPHeaderField: "X-Title")
        let body: [String: Any] = ["model": model,
                                   "messages": [["role": "system", "content": system], ["role": "user", "content": user]]]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (code, data) = await send(req)
        guard code == 200 else { return Reply(name: name, text: "", error: httpError(code)) }
        guard let t = openRouterText(data) else { return Reply(name: name, text: "", error: "沒有回答") }
        return Reply(name: name, text: t, error: nil)
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
        let picked = pickFamilies(ids)
        cachedFree = (Date(), picked)
        return picked
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

    static func gemini(system: String, user: String, key: String) async -> Reply {
        for model in ["gemini-flash-latest", "gemini-2.5-flash"] {
            let r = await geminiCall(model, system: system, user: user, key: key)
            if r.error != httpError(404) { return r }
        }
        return Reply(name: "Gemini", text: "", error: "找不到可用的 Gemini 模型")
    }

    static func geminiCall(_ model: String, system: String, user: String, key: String) async -> Reply {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            return Reply(name: "Gemini", text: "", error: "網址錯誤")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 能調的安全過濾都調到最低（核心的保護 Google 一定會留著）
        let cats = ["HARM_CATEGORY_HARASSMENT", "HARM_CATEGORY_HATE_SPEECH", "HARM_CATEGORY_SEXUALLY_EXPLICIT", "HARM_CATEGORY_DANGEROUS_CONTENT"]
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": [["text": user]]]],
            "safetySettings": cats.map { ["category": $0, "threshold": "BLOCK_NONE"] },
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (code, data) = await send(req)
        guard code == 200 else { return Reply(name: "Gemini", text: "", error: httpError(code)) }
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
