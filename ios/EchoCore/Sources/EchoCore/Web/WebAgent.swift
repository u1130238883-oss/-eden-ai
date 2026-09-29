import Foundation

/// NineSun 的思考方式（查資料、解問題時都照這個順序，每次都即時上網，不存舊答案）：
///
///   ① 釐清：這是哪一類問題？真正要問的是什麼？口語、簡稱換成正式名稱。
///   ② 拆解：一個大問題拆成幾個小問題（疾病 → 是什麼／症狀／原因／治療／照顧；
///      法律 → 規定／後果／怎麼做／權益），每個小問題分開查。
///   ③ 蒐集：同時問好幾個搜尋來源（Bing、DuckDuckGo、維基百科、新聞、天氣、匯率、股市），都不需要金鑰。
///   ④ 閱讀：打開最相關的網頁，只留下真的在回答那個小問題的句子；跟主題無關的結果直接丟掉。
///   ⑤ 查證：官方、醫院、法院、百科這類來源優先；好幾個來源都這樣說才算可信。
///   ⑥ 反思：來源夠不夠？有沒有互相矛盾？哪裡還不確定？老實說出把握程度。
///   ⑦ 回答：先給結論，再分段說明，附上來源；最後建議下一步（該看哪一科、該問誰、還可以再問什麼）。
public enum WebAgent {
    public enum Kind { case define, reason, method, compare, recommend, news, weather, person, health, legal, fortune, general }

    public struct Plan {
        public let kind: Kind
        public let keywords: String
        /// 去掉「多高」「怎麼煮」這類問法之後的主題（「台北101」「紅燒肉」）
        public let core: String
        public let queries: [String]
        /// 問的是數量（多高、多少、幾歲……），答案裡要有數字
        public let numeric: Bool
    }
    public struct Finding {
        public let text: String
        public let host: String
        public let url: String
        /// 屬於哪一個小問題（-1：整體）
        public var angle: Int = -1
        /// 是不是可信的來源（官方、醫院、法院、百科）
        public var trusted: Bool = false
    }
    public struct Result {
        public let text: String
        public let card: FortuneCard?
        /// 有沒有真的查到東西
        public let found: Bool
        /// 每個來源找到幾筆（診斷用）
        public let engines: [String: Int]
    }

    static let kindName: [Kind: String] = [
        .define: "「是什麼」", .reason: "「為什麼」", .method: "「怎麼做」", .compare: "「比較」", .recommend: "「推薦」",
        .news: "「最新消息」", .weather: "「天氣」", .person: "「人物」", .health: "「健康／疾病」", .legal: "「法律」",
        .fortune: "命理", .general: "一般",
    ]

    // MARK: - ① 釐清問題 ② 規劃搜尋

    public static func understand(_ question: String, L: Lang, fortune: Bool) -> Plan {
        let q = question.lowercased()
        func has(_ ws: [String]) -> Bool { ws.contains { q.contains($0) } }
        let kind: Kind
        if fortune { kind = .fortune }
        else if WebSearch.wantsWeather(q) { kind = .weather }
        else if has(["新聞", "最新", "最近發生", "今天發生", "消息", "股價", "股市", "台股", "美股", "大盤", "匯率", "油價", "金價", "比分",
                     "latest", "news", "noticias", "notizie", "stock market", "exchange rate"]) { kind = .news }
        else if WebStrategy.isLegal(q) { kind = .legal }
        else if WebStrategy.isHealth(q) { kind = .health }
        else if has(["差別", "區別", "比較", "哪個好", "哪一個好", " vs", "difference", "better than", "diferencia", "differenza"]) { kind = .compare }
        else if has(["為什麼", "為何", "原因", "why", "por qué", "perché"]) { kind = .reason }
        else if has(["怎麼", "如何", "方法", "步驟", "教我", "how to", "how do", "how can", "cómo", "come si"]) { kind = .method }
        else if has(["推薦", "有哪些", "哪裡", "recommend", "best ", "recomienda", "consiglia"]) { kind = .recommend }
        else if has(["是誰", "誰是", "who is", "quién es", "chi è"]) { kind = .person }
        else if has(["是什麼", "什麼是", "什麼意思", "定義", "what is", "what are", "meaning", "qué es", "cos'è"]) { kind = .define }
        else { kind = .general }

        let kw = keywords(question)
        let core = coreTopic(kw)
        let numeric = has(["多高", "多大", "多遠", "多久", "多長", "多重", "多少", "幾歲", "幾年", "幾點", "幾個", "幾公", "匯率", "價格", "股價", "人口",
                           "how many", "how much", "how tall", "how far", "how long", "how old", "when did", "when was", "population", "price"])
        var qs = [kw]
        let extra: [Kind: String] = L == .zh
            ? [.define: " 是什麼", .reason: " 原因", .method: " 方法", .compare: " 差別", .recommend: " 推薦", .person: " 簡介"]
            : [.define: " meaning", .reason: " reason", .method: " how to", .compare: " difference", .recommend: " best", .person: " biography"]
        if let e = extra[kind], !kw.hasSuffix(e.trimmingCharacters(in: .whitespaces)) { qs.append(core + e) }
        if core != kw && kind != .weather && kind != .news { qs.append(core) }
        // 原句本身也是很好的搜尋詞（搜尋引擎看得懂自然語言）
        let raw = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.count <= 40 { qs.append(raw) }
        var seen = Set<String>()
        return Plan(kind: kind, keywords: kw, core: core, queries: qs.filter { !$0.isEmpty && seen.insert($0).inserted }, numeric: numeric)
    }

    /// 把口語問句整理成關鍵字
    public static func keywords(_ raw: String) -> String {
        var q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.hasPrefix("請") && !q.hasPrefix("請問") { q.removeFirst() }
        for w in ["請問", "請你", "請幫我", "幫我上網查", "上網查一下", "上網查", "上網搜尋", "上網找", "幫我查一下", "幫我查", "幫我搜尋", "搜尋一下", "搜尋",
                  "查一下", "幫我", "可以告訴我", "告訴我", "你知道", "我想知道", "想問", "一下",
                  "是什麼意思", "什麼意思", "是什麼", "什麼是", "為什麼", "怎麼樣", "如何", "有哪些", "是誰", "誰是",
                  "呀", "啊", "呢", "吧", "嗎", "？", "?", "！", "!", "。", "，", ","] {
            q = q.replacingOccurrences(of: w, with: " ")
        }
        for p in ["search for ", "search ", "look up ", "google ", "busca ", "cerca "] where q.lowercased().hasPrefix(p) {
            q = String(q.dropFirst(p.count))
        }
        if q.hasPrefix("查") { q.removeFirst() }
        let parts = q.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        let out = parts.joined(separator: " ")
        return out.isEmpty ? raw : out
    }

    /// 主題詞：去掉問法（「台北101有多高」→「台北101」、「紅燒肉怎麼煮」→「紅燒肉」）
    public static func coreTopic(_ kw: String) -> String {
        var t = kw
        for w in ["有多高", "多高", "有多大", "多大", "有多遠", "多遠", "要多久", "多久", "有多長", "多長", "有多重", "多重", "多少錢", "是多少", "有多少", "多少",
                  "幾歲", "幾點", "怎麼煮", "怎麼做", "怎麼去", "怎麼用", "怎麼辦", "怎麼樣", "怎樣", "是哪一座", "是哪一個", "是哪個", "是哪裡", "在哪裡",
                  "哪一座", "哪一個", "哪個", "哪裡", "的由來", "的原因", "的意思", "的差別", "的方法", "介紹", "的歷史", "的原理", "會怎樣", "會不會",
                  "要注意什麼", "注意什麼", "該注意", "吃什麼", "有什麼症狀", "的症狀", "症狀", "會被罰", "犯法嗎", "違法嗎", "合法嗎", "犯法", "違法", "合法",
                  "我有", "我得了", "我媽", "我爸", "我", "得了", "有沒有"] {
            t = t.replacingOccurrences(of: w, with: " ")
        }
        let out = t.split(separator: " ").map(String.init).filter { !$0.isEmpty }.joined(separator: " ")
        return out.count >= 2 ? out : kw
    }

    // MARK: - 主流程

    public static func run(_ question: String, facts: String? = nil, lang L: Lang) async -> Result {
        let fortune = facts != nil
        let plan = understand(question, L: L, fortune: fortune)
        let zh = L == .zh
        let strat = zh && !fortune ? WebStrategy.strategy(plan.kind, question: question)
                                   : WebStrategy.Strategy(angles: [], trusted: [], note: nil)
        let canon = zh ? WebStrategy.canonical(plan.core) : nil
        let topic = canon ?? plan.core

        // ②③ 拆成幾組關鍵字，同時上網查（tag -1：整體；0…：各個小問題）
        var jobs: [(tag: Int, q: String, full: Bool)] = []
        for (i, q) in plan.queries.prefix(strat.angles.isEmpty ? 3 : 2).enumerated() { jobs.append((-1, q, i == 0 || strat.angles.isEmpty)) }
        if let canon { jobs.append((-1, canon, true)) }
        for (i, a) in strat.angles.enumerated() { jobs.append((i, topic + a.suffix, false)) }
        let answers = await withTaskGroup(of: (Int, Int, WebSearch.Answer).self) { g -> [(Int, WebSearch.Answer)] in
            for (n, j) in jobs.enumerated() {
                g.addTask { (n, j.tag, await WebSearch.search(j.q, lang: L, news: plan.kind == .news && n == 0, light: !j.full)) }
            }
            var out: [(Int, Int, WebSearch.Answer)] = []
            for await a in g { out.append(a) }
            return out.sorted { $0.0 < $1.0 }.map { ($0.1, $0.2) }
        }

        // ④ 只留下跟主題有關的結果
        var terms = termSet(plan.core)
        if let canon { terms.formUnion(termSet(canon)) }
        let need = max(1, min(3, (termSet(plan.core).count + 1) / 3))
        var hits: [(tag: Int, hit: WebSearch.Hit)] = []
        var lead: String?, leadSource: String?
        var engines: [String: Int] = [:]
        var seenURL = Set<String>()
        for (tag, a) in answers {
            if lead == nil, let l = a.lead { lead = l; leadSource = a.leadSource }
            for (k, v) in a.engines { engines[k, default: 0] += v }
            for h in a.hits where score(h.title + " " + h.snippet, terms) >= need || h.engine == "Google 新聞" {
                if seenURL.insert(WebSearch.normURL(h.url)).inserted { hits.append((tag, h)) }
            }
        }
        if hits.isEmpty && lead == nil {
            return Result(text: Loc.s("webFail", L, plan.keywords), card: nil, found: false, engines: engines)
        }
        func isTrusted(_ url: String) -> Bool { strat.trusted.contains { url.lowercased().contains($0) } }

        // ④ 閱讀網頁：整體挑 2 個、每個小問題挑 1 個（可信的來源優先），同時打開
        func pick(_ tag: Int, _ n: Int) -> [WebSearch.Hit] {
            hits.filter { $0.tag == tag && !$0.hit.url.contains("news.google.com") }.map(\.hit)
                .sorted { (score($0.title + $0.snippet, terms) + (isTrusted($0.url) ? 3 : 0)) > (score($1.title + $1.snippet, terms) + (isTrusted($1.url) ? 3 : 0)) }
                .prefix(n).map { $0 }
        }
        var toRead: [WebSearch.Hit] = pick(-1, strat.angles.isEmpty ? 3 : 2)
        for i in strat.angles.indices { for h in pick(i, 1) where !toRead.contains(where: { $0.url == h.url }) { toRead.append(h) } }
        let pages = await withTaskGroup(of: (WebSearch.Hit, String?).self) { g -> [(WebSearch.Hit, String)] in
            for h in toRead.prefix(7) { g.addTask { (h, await WebSearch.pageText(h.url, L)) } }
            var out: [(WebSearch.Hit, String)] = []
            for await (h, t) in g { if let t { out.append((h, t)) } }
            return out
        }

        // 每一句都判斷：在回答哪一個小問題
        func angleOf(_ s: String, default d: Int) -> Int {
            var best = d, bestN = 0
            for (i, a) in strat.angles.enumerated() {
                let n = a.cues.filter { s.contains($0) }.count
                if n > bestN { best = i; bestN = n }
            }
            return best
        }
        var findings: [Finding] = []
        for (h, page) in pages {
            let text = zh ? WebStrategy.toTraditional(page) : page
            let ss = best(sentences(text), terms: terms, numeric: plan.numeric, core: plan.core, n: strat.angles.isEmpty ? 3 : 8)
            for s in ss {
                findings.append(Finding(text: s, host: WebSearch.host(h.url), url: h.url, angle: angleOf(s, default: -1), trusted: isTrusted(h.url)))
            }
        }
        for (tag, h) in hits where !h.snippet.isEmpty {
            let s = zh ? WebStrategy.toTraditional(h.snippet) : h.snippet
            let a = angleOf(s, default: -1)
            findings.append(Finding(text: s, host: WebSearch.host(h.url), url: h.url, angle: a == -1 && tag >= 0 ? -1 : a, trusted: isTrusted(h.url)))
        }
        let lead2 = lead.map { zh ? WebStrategy.toTraditional($0) : $0 }

        // ⑤ 查證：交叉比對
        let common = consensus(findings.filter { score($0.text, terms) > 0 }, exclude: plan.keywords + topic, cjkOnly: zh)
        let sources = orderedUnique(findings.map(\.host) + (leadSource.map { [$0] } ?? []))
        let trustedHosts = orderedUnique(findings.filter(\.trusted).map(\.host))

        // ⑦ 組回答
        let ranked = rank(findings, terms: terms, common: common, numeric: plan.numeric, core: plan.core)
            .filter { quality($0.text, terms: terms, numeric: plan.numeric, core: plan.core) > 0 }
        var answer = ""
        if let lead2 { answer = lead2 }
        else if let first = (strat.angles.isEmpty ? ranked : ranked.filter { $0.angle <= 0 }).first ?? ranked.first {
            answer = WebSearch.clip(first.text, 240) + "（\(first.host)）"
        }
        // 問數量：直接答案裡沒有數字，就改用有數字、最相關的那句
        if plan.numeric, plan.kind != .weather, !hasNumber(answer, besides: plan.core),
           let withNum = ranked.first(where: { hasNumber($0.text, besides: plan.core) }) {
            answer = WebSearch.clip(withNum.text, 240) + "（\(withNum.host)）" + (lead2.map { "\n\n" + $0 } ?? "")
        }
        var used: [String] = [answer]
        func take(_ fs: [Finding], _ n: Int) -> [String] {
            var out: [String] = []
            for f in fs where out.count < n {
                let s = WebSearch.clip(f.text, 150)
                let key = String(s.prefix(14))
                if used.contains(where: { $0.contains(key) }) { continue }
                used.append(s)
                out.append(s + "（\(f.host)）")
            }
            return out
        }
        var sections: [(String, [String])] = []
        if !strat.angles.isEmpty {
            for (i, a) in strat.angles.enumerated() {
                let fs = ranked.filter { $0.angle == i }.sorted { ($0.trusted ? 1 : 0) > ($1.trusted ? 1 : 0) }
                let pts = take(fs, i == 0 ? 2 : 3)
                if !pts.isEmpty { sections.append((a.title, pts)) }
            }
        } else if plan.kind == .news {
            let heads = hits.filter { $0.hit.engine == "Google 新聞" }.prefix(6).map { WebStrategy.toTraditional($0.hit.snippet) }
            if !heads.isEmpty { sections.append(("最新消息", Array(heads))) }
            if lead2 == nil && !heads.isEmpty { answer = zh ? "我找到這些最新的相關新聞：" : "Latest related news:" }
        } else if !(plan.kind == .weather && lead != nil) {
            let pts = take(ranked, 4)
            if !pts.isEmpty { sections.append((plan.kind == .method ? "步驟／做法" : "重點", pts)) }
        }

        // ⑥ 反思：把握程度與還不確定的地方
        let covered = sections.count
        var confidence: String
        if sources.count >= 3 && (common.count >= 2 || trustedHosts.count >= 1) { confidence = zh ? "高（\(sources.count) 個來源，說法大致一致）" : "high (\(sources.count) sources mostly agree)" }
        else if sources.count >= 2 { confidence = zh ? "中（\(sources.count) 個來源，可以參考）" : "medium (\(sources.count) sources)" }
        else { confidence = zh ? "低（來源少，建議再確認）" : "low (few sources, double-check)" }
        var gaps: [String] = []
        if !strat.angles.isEmpty {
            let missing = strat.angles.indices.filter { i in !sections.contains { $0.0 == strat.angles[i].title } }.map { strat.angles[$0].title }
            if !missing.isEmpty { gaps.append("「" + missing.joined(separator: "、") + "」這部分網路上沒找到清楚的說法") }
        }
        if trustedHosts.isEmpty && !strat.trusted.isEmpty { gaps.append("這次沒有查到官方或專業機構的資料") }
        if !gaps.isEmpty && confidence.hasPrefix("高") { confidence = "中（" + gaps.joined(separator: "；") + "）" }

        var t = ""
        if zh {
            t += "🔎 我的思路\n"
            t += "① 釐清：這是\(kindName[plan.kind] ?? "一般")的問題，主題是「\(plan.core)」"
            if let canon { t += "（正式名稱：\(canon)）" }
            t += "。\n"
            if !strat.angles.isEmpty {
                t += "② 拆解：分成「" + strat.angles.map(\.title).joined(separator: "」→「") + "」幾個小問題，分開上網查。\n"
            } else {
                t += "② 搜尋：" + jobs.prefix(3).map { "「\($0.q)」" }.joined(separator: "、") + "。\n"
            }
            let names = engines.filter { $0.value > 0 && !["instant", "weather"].contains($0.key) }.keys.sorted()
            t += "③ 蒐集：查了 \(jobs.count) 組關鍵字" + (names.isEmpty ? "" : "，從 " + names.joined(separator: "、")) + " 留下 \(hits.count) 個跟主題有關的結果"
            if let leadSource, lead != nil { t += "，另外取得 \(leadSource) 的直接資料" }
            t += "。\n"
            t += "④ 閱讀：打開 \(pages.count) 個網頁，只留下真的在回答問題的句子。\n"
            t += "⑤ 查證：" + (trustedHosts.isEmpty ? "" : "採用了 " + trustedHosts.prefix(3).joined(separator: "、") + " 等可信來源；")
                + (common.isEmpty ? "各來源說法比較分散，挑最相關的整理。" : "好幾個來源都提到「" + common.prefix(4).joined(separator: "」「") + "」。") + "\n"
            if let facts { t += "⑥ 對照你的盤：\(facts)。網路上的說法當作補充，判斷還是以你盤上的喜忌和流年為準。\n" }
            t += "\n📌 " + (fortune ? "網路上的說法" : "回答") + "\n" + answer
            for (title, pts) in sections {
                let numbered = plan.kind == .method || title == "可以怎麼做" || title == "步驟"
                t += "\n\n【\(title)】\n" + pts.enumerated().map { numbered ? "\($0.offset + 1). \($0.element)" : "• \($0.element)" }.joined(separator: "\n")
            }
            if let note = strat.note { t += "\n\n" + note }
            t += "\n\n🤔 我的判斷：把握程度\(confidence)。"
            if !gaps.isEmpty { t += "還不確定的地方：" + gaps.joined(separator: "；") + "。" }
            if covered == 0 && lead == nil { t += "這題網路上的資料跟你問的不太對得上，可以換個說法或講得更具體一點，我再查一次。" }
            t += "\n來源：" + sources.prefix(5).joined(separator: "、")
        } else {
            t += Loc.s("webResult", L, plan.keywords) + "\n\n" + answer
            for (_, pts) in sections { t += "\n\n" + pts.map { "• " + $0 }.joined(separator: "\n") }
            t += "\n\n" + Loc.s("webSources", L) + ": " + sources.prefix(5).joined(separator: ", ") + " · " + confidence
        }

        let links = orderedUnique(ranked.filter(\.trusted).map(\.url) + ranked.map(\.url) + hits.map(\.hit.url))
        let card = FortuneCard(title: fortune ? (zh ? "網路資料對照" : "Web check") : (zh ? "上網查到的資料" : "From the web"),
                               headline: canon ?? plan.keywords,
                               details: Array(links.prefix(5)).map { WebSearch.host($0) + "  " + $0 },
                               link: links.first)
        return Result(text: t, card: card, found: true, engines: engines)
    }

    // MARK: - 挑句子

    static func sentences(_ s: String) -> [String] {
        var out: [String] = [], cur = ""
        for ch in s {
            if ch == "\n" {
                let t = cur.trimmingCharacters(in: .whitespaces)
                if t.count >= 12 && t.count <= 220 { out.append(t) }
                cur = ""
                continue
            }
            cur.append(ch)
            if "。！？!?；".contains(ch) || (ch == "." && cur.count > 40) {
                let t = cur.trimmingCharacters(in: .whitespaces)
                if t.count >= 12 && t.count <= 220 { out.append(t) }
                cur = ""
            }
        }
        return out.filter { !looksLikeJunk($0) }
    }

    /// 選單、版權、Cookie 提示之類的句子
    static func looksLikeJunk(_ s: String) -> Bool {
        let l = s.lowercased()
        let junk = ["cookie", "copyright", "版權所有", "all rights reserved", "登入", "註冊", "訂閱", "javascript", "隱私權", "privacy policy",
                    "點擊", "下載app", "分享到", "上一篇", "下一篇", "sign in", "subscribe", "廣告"]
        if junk.contains(where: { l.contains($0) }) { return true }
        let letters = s.filter { $0.isLetter }.count
        return Double(letters) / Double(max(1, s.count)) < 0.5
    }

    /// 問題的關鍵單位：中文用雙字組、外文用單字
    static func termSet(_ kw: String) -> Set<String> {
        var out = Set<String>()
        let l = kw.lowercased()
        for w in l.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            let c = Array(w)
            if c.contains(where: isCJK) {
                if c.count == 1 { out.insert(String(c)) }
                for i in 0..<max(0, c.count - 1) { out.insert(String(c[i...i + 1])) }
            } else if w.count >= 2 {
                out.insert(String(w))
            }
        }
        return out
    }

    static func score(_ s: String, _ terms: Set<String>) -> Int {
        let l = s.lowercased()
        return terms.filter { l.contains($0) }.count
    }

    /// 一句話適不適合當答案：跟主題的重疊、問數量時有沒有數字，扣掉列表、清單式的句子
    /// 除了主題本身（「台北101」的 101）以外，還有沒有數字
    static func hasNumber(_ s: String, besides core: String) -> Bool {
        s.replacingOccurrences(of: core, with: "").contains(where: \.isNumber)
    }

    static func quality(_ s: String, terms: Set<String>, numeric: Bool, core: String = "") -> Int {
        let hit = score(s, terms)
        guard hit > 0 else { return 0 }
        var q = hit * 4
        if hit * 2 >= terms.count { q += 4 }
        if numeric && hasNumber(s, besides: core) { q += 6 }
        let listy = s.components(separatedBy: "｜").count + s.components(separatedBy: "|").count - 2
            + (s.range(of: #"\d+\.\s*\D+\s*\d+\.\s"#, options: .regularExpression) != nil ? 3 : 0)
            + s.components(separatedBy: "、").count / 6
        q -= listy * 3
        if s.count > 160 { q -= 2 }
        if s.count < 20 { q -= 2 }
        if s.hasSuffix("?") || s.hasSuffix("？") { q -= 6 }
        if s.contains(" - ") && s.count < 60 { q -= 3 }   // 網頁標題
        return q
    }

    /// 和問題最相關的幾句
    static func best(_ ss: [String], terms: Set<String>, numeric: Bool, core: String, n: Int) -> [String] {
        let need = max(1, (terms.count + 1) / 3)
        var seen = Set<String>()
        return ss.filter { score($0, terms) >= need && seen.insert(String($0.prefix(20))).inserted }
            .map { ($0, quality($0, terms: terms, numeric: numeric, core: core)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }.prefix(n).map { $0.0 }
    }

    static func rank(_ fs: [Finding], terms: Set<String>, common: [String], numeric: Bool, core: String) -> [Finding] {
        fs.map { f -> (Finding, Int) in
            (f, quality(f.text, terms: terms, numeric: numeric, core: core) * 2 + common.filter { f.text.contains($0) }.count * 2)
        }.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    static func orderedUnique(_ xs: [String]) -> [String] {
        var seen = Set<String>()
        return xs.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    // MARK: - 交叉比對：好幾個來源都出現的詞

    static func consensus(_ fs: [Finding], exclude: String, cjkOnly: Bool) -> [String] {
        var bySource: [String: Set<String>] = [:]
        for f in fs {
            var grams = Set<String>()
            let chars = Array(f.text)
            for n in 2...4 where chars.count >= n {
                for i in 0...(chars.count - n) {
                    let g = chars[i..<(i + n)]
                    if g.allSatisfy(isCJK) { grams.insert(String(g)) }
                }
            }
            for w in f.text.lowercased().split(whereSeparator: { !$0.isLetter }) where !cjkOnly && w.count >= 5 && w.allSatisfy({ $0.isASCII }) {
                grams.insert(String(w))
            }
            bySource[f.host, default: []].formUnion(grams)
        }
        var count: [String: Int] = [:]
        for (_, g) in bySource { for x in g { count[x, default: 0] += 1 } }
        let stop: Set<String> = ["什麼", "一個", "可以", "我們", "你的", "自己", "這個", "就是", "因為", "所以", "如果", "還是", "沒有", "他們",
                                 "以及", "其實", "如何", "這些", "非常", "需要", "時候", "大家", "的人", "是一", "the", "which", "their",
                                 "about", "there", "these", "would", "other", "could", "should"]
        let ex = exclude.lowercased()
        let cands = count.filter { $0.value >= 2 && !stop.contains($0.key) && !ex.contains($0.key) }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.count > $1.key.count }
        var out: [String] = []
        for (g, _) in cands {
            if out.contains(where: { $0.contains(g) || g.contains($0) }) { continue }
            out.append(g)
            if out.count >= 5 { break }
        }
        return out
    }

    static func isCJK(_ c: Character) -> Bool {
        c.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
    }
}
