import Foundation

/// 用大腦讀網頁、自己下結論（不分問題類型、不用模板）：
///   1. 把每個網頁切成一段一段
///   2. 先粗略挑出跟問題有關的段落（省時間）
///   3. 每一段都讓大腦讀：這段有沒有在回答問題？答案是哪幾個字？有多肯定？
///   4. 不同網站的答案互相比對：說法一樣的加在一起，官方、百科的份量比較重
///   5. 有一個說法明顯勝出 → 那就是答案；幾個說法各有道理 → 整理成幾個重點；說法衝突 → 講出來
public enum Think {
    public struct Reading {
        public let passage: String
        public let host: String
        public let span: Brain.Span
    }

    public struct Conclusion {
        /// 給使用者看的回答（已經附上來源）
        public let text: String
        /// 大腦有沒有把握（有的話就用它，不用舊的規則）
        public let confident: Bool
        /// 讀了幾段、幾段真的在回答問題、來自幾個網站
        public let read: Int
        public let relevant: Int
        public let hosts: [String]
        /// 沒有任何一段讓大腦有把握（只是挑了最接近的）
        public var unsure: Bool = false
        /// 大腦選出的答案、它的把握（分數）、有幾段文字支持
        public var answer: String = ""
        public var topScore: Float = 0
        public var support: Int = 0
    }

    /// 把網頁切成段落：每段兩三句（60～160 字）。段落小一點，一個網頁裡不同的重點才會被分別讀到
    static func passages(_ text: String) -> [String] {
        var sents: [String] = []
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.contains("｜") else { continue }
            var cur = ""
            for ch in line {
                cur.append(ch)
                if "。！？!?；".contains(ch) { sents.append(cur); cur = "" }
            }
            if !cur.isEmpty { sents.append(cur) }
        }
        var out: [String] = [], cur = ""
        for s in sents {
            if !cur.isEmpty && cur.count + s.count > 160 { out.append(cur); cur = "" }
            cur += s
            if cur.count >= 60 { out.append(cur); cur = "" }
        }
        if cur.count >= 15 { out.append(cur) }
        return out
    }

    /// 問題裡的雙字詞（「三島」「由紀」「小說」……），用來粗略挑段落
    static func grams(_ q: String) -> Set<String> {
        let skip: Set<Character> = ["什", "麼", "嗎", "呢", "的", "是", "了", "哪", "誰", "為", "怎", "吧", "啊", "有", "個", "些", "都", "在"]
        let c = Array(q.filter { !$0.isWhitespace && !$0.isPunctuation && !skip.contains($0) }.map(canon))
        guard c.count >= 2 else { return Set(c.map(String.init)) }
        return Set((0..<(c.count - 1)).map { String(c[$0...$0 + 1]) })
    }

    /// 異體字當成同一個字（問「台北」、網頁寫「臺北」）
    static func canon(_ c: Character) -> Character { Brain.variants[String(c)].flatMap(\.first) ?? c }
    static func canonText(_ s: String) -> String { String(s.map(canon)) }

    /// 答案附近的那句話（給使用者看依據）
    static func sentence(around span: Brain.Span, in passage: String) -> String {
        let s = Array(passage.unicodeScalars)
        guard span.start < s.count, span.end < s.count else { return span.text }
        let stops: Set<Unicode.Scalar> = ["。", "！", "？", "\n", "；", "!", "?"]
        var a = span.start, b = span.end
        while a > 0 && !stops.contains(s[a - 1]) && span.start - a < 40 { a -= 1 }
        while b + 1 < s.count && !stops.contains(s[b]) && b - span.end < 40 { b += 1 }
        var out = ""
        out.unicodeScalars.append(contentsOf: s[a...min(b, s.count - 1)])
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 不像答案的字（網頁標題、導覽、動詞、連接詞）：大腦抓到這些就不算
    static let junkWords: Set<String> = ["維基百科", "自由的百科全書", "百科全書", "認為", "表示", "指出", "列表", "分類", "新增話題", "跳至內容",
                                         "目錄", "首頁", "編輯", "參考資料", "參考文獻", "外部連結", "相關條目", "本條目", "這個", "那個",
                                         "其中", "以及", "例如", "我們", "你們", "他們", "所以", "因此", "但是", "然而", "可以", "就是"]

    static func junk(_ span: String) -> Bool {
        let k = key(span)
        if k.isEmpty { return true }
        if k.count == 1 && !k.contains(where: \.isNumber) { return true }
        return junkWords.contains(k) || junkWords.contains { k.hasPrefix($0) && k.count <= $0.count + 1 }
    }

    /// 同類的字（問「山」，「峰」「岳」「嶺」也算）
    static let kin: [String: [String]] = ["山": ["峰", "岳", "嶺", "嶽"], "河": ["江", "川", "溪"], "湖": ["潭", "池", "泊"],
                                          "國家": ["國"], "城市": ["市", "城", "都"], "人": ["者", "家"], "動物": ["獸"], "建築": ["樓", "塔", "大廈"]]

    /// 「最高的山是哪座」：段落裡的「最高的…」要是「山」（或峰、岳），「最高的火車站」不算；段落沒提到「最高」就不用這條判斷
    static func superlativeFits(question q: String, passage p: String) -> Bool {
        guard let m = Understanding.match(q, #"最(\p{Han}{1,2}?)的?(\p{Han}{1,4}?)(?:是|為)?(?:哪|什麼|誰)"#) else { return true }
        let adj = m[1], noun = m[2]
        guard !adj.isEmpty, !noun.isEmpty else { return true }
        let words = [noun, String(noun.prefix(1))] + (kin[noun] ?? []) + (kin[String(noun.prefix(1))] ?? [])
        var mentioned = false
        var rest = Substring(p)
        while let r = rest.range(of: "最" + adj) {
            mentioned = true
            var after = rest[r.upperBound...]
            if after.hasPrefix("的") { after = after.dropFirst() }
            if words.contains(where: { after.hasPrefix($0) }) { return true }
            rest = rest[r.upperBound...]
        }
        return !mentioned
    }

    /// 要的是一段說明（在講什麼、怎麼做、怎麼辦、為什麼），不是幾個字的答案
    static func wantsSentences(_ q: String) -> Bool {
        ["在講什麼", "講了什麼", "講什麼", "講些什麼", "內容是什麼", "在說什麼", "說了什麼", "是在講", "怎麼辦", "該怎麼", "怎麼做", "怎麼煮",
         "怎麼處理", "如何", "做法", "步驟", "為什麼", "為何", "原因", "怎麼會", "建議"].contains { q.contains($0) }
    }

    /// 疑問詞和虛詞：拿來把問題切成幾個內容詞組（長的先切）
    static let askWords = ["為什麼會", "為什麼是", "為什麼要", "為何會", "怎麼會", "怎麼辦", "怎麼做", "怎麼煮", "怎麼處理", "該怎麼", "要怎麼",
                           "為什麼", "為何", "如何", "都講了什麼", "都在講什麼", "在講什麼", "講了什麼", "講些什麼", "講什麼", "在說什麼",
                           "說了什麼", "內容是什麼", "是在講", "是什麼", "什麼", "怎麼", "哪些", "哪裡", "嗎", "呢", "吧", "啊", "我", "你", "的", "了"]

    /// 問題裡的內容詞組：「老闆不給我加薪怎麼辦」→ 老闆不給、加薪；「感冒為什麼會發燒」→ 感冒、發燒
    static func chunks(_ q: String) -> [String] {
        var parts = [q.filter { !$0.isPunctuation && !$0.isWhitespace && !$0.isSymbol }]
        for w in askWords { parts = parts.flatMap { $0.components(separatedBy: w) } }
        return parts.filter { $0.count >= 2 }
    }

    /// 這段話有沒有講到這個詞組：短的（三個字以內）要整個出現，長的有一半的雙字詞出現就算；至少要有一個雙字詞時用 least
    static func covers(_ text: String, _ chunk: String, least: Bool = false) -> Bool {
        let t = canonText(text), c = Array(canonText(chunk))
        guard c.count >= 2 else { return true }
        let gs = (0..<(c.count - 1)).map { String(c[$0...$0 + 1]) }
        let hit = gs.filter { t.contains($0) }.count
        if least { return hit >= 1 }
        return c.count <= 3 ? t.contains(String(c)) : hit * 2 >= gs.count
    }

    /// 說明題的句子要真的在講問的那件事：最後一個詞組（加薪、發燒、白飯）句子裡要有，其他的（老闆、感冒）段落裡有就好
    /// 「老闆不給我加薪怎麼辦」不能拿「老闆欠薪不給怎麼辦」的句子來回答
    static func onTopic(question: String, sentence: String, passage: String) -> Bool {
        // 「三島由紀夫的書都講了什麼」：要的是在講他作品的句子（有《書名》、小說、描寫…），段落有提到他就好；
        // 「三島由紀夫獎…紀念日本作家三島由紀夫」有提到他，但不是在講他的書
        if let m = Understanding.match(question, #"^(.{2,12}?)的(書|作品|小說|電影|歌|詩|劇)"#) {
            let works = ["《", "小說", "作品", "描寫", "講述", "描述", "敘述", "故事", "主角", "情節", "主題"]
            return covers(passage, m[1], least: true) && works.contains { sentence.contains($0) }
        }
        let cs = chunks(question)
        guard let focus = cs.last else { return true }
        return covers(sentence, focus) && cs.dropLast().allSatisfy { covers(passage, $0, least: true) }
    }

    /// 說明題的答案句通常會有的字：在講什麼 → 講述、描寫；為什麼 → 因為、由於；怎麼辦 → 可以、建議；怎麼做 → 加入、煮
    static func cues(_ q: String) -> [String] {
        if ["在講什麼", "講了什麼", "講什麼", "講些什麼", "內容是什麼", "在說什麼", "說了什麼", "是在講"].contains(where: { q.contains($0) }) {
            return ["講述", "描寫", "描述", "敘述", "故事", "主題", "探討", "內容", "講的是", "寫的是", "主角", "情節"]
        }
        if ["為什麼", "為何", "原因", "怎麼會"].contains(where: { q.contains($0) }) { return Understanding.causal }
        if ["怎麼辦", "該怎麼", "怎麼處理", "建議"].contains(where: { q.contains($0) }) {
            return ["可以", "應該", "建議", "最好", "記得", "不要", "避免", "休息", "就醫", "找", "先", "試著"]
        }
        if ["怎麼做", "怎麼煮", "如何", "做法", "步驟"].contains(where: { q.contains($0) }) {
            return Understanding.stepVerbs + ["先", "再", "然後", "接著", "最後"]
        }
        return []
    }

    /// 句子裡的《書名》
    static func titles(_ s: String) -> [String] {
        var out: [String] = []
        var rest = Substring(s)
        while let a = rest.firstIndex(of: "《"), let b = rest[a...].firstIndex(of: "》") {
            let t = String(rest[rest.index(after: a)..<b])
            if (1...20).contains(t.count), !out.contains(t) { out.append(t) }
            rest = rest[rest.index(after: b)...]
        }
        return out
    }

    /// 「X的書都講了什麼」：先找出講到他的句子裡最常被提到的作品（《書名》），再找每一部「描寫、講述…」的句子，
    /// 加上一句講他整體作品風格、主題的話。維基百科（CC BY-SA）可以引好幾句，其他網站每個只引一句
    public static func worksDigest(question: String, pages: [Understanding.Evidence]) -> String? {
        guard let m = Understanding.match(question, #"^(.{2,12}?)的(書|作品|小說|電影|歌|詩|劇)"#) else { return nil }
        let who = m[1]
        var sents: [(text: String, host: String)] = []
        for p in pages {
            for raw in p.text.components(separatedBy: CharacterSet(charactersIn: "。！？\n")) {
                let t = raw.trimmingCharacters(in: .whitespaces)
                if (8...160).contains(t.count), !t.contains("｜") { sents.append((t + "。", p.host)) }
            }
        }
        var count: [String: Int] = [:]
        for s in sents where covers(s.text, who, least: true) {
            for t in titles(s.text) where t != who { count[t, default: 0] += 1 }
        }
        let top = count.sorted { ($0.value, -$0.key.count) > ($1.value, -$1.key.count) }.prefix(8).map(\.key)
        let cue = ["描寫", "講述", "描述", "敘述", "故事", "主角", "題材", "探討", "主題", "講的是", "寫的是", "改編自", "刻畫"]
        var quoted: [String: Int] = [:]
        func canQuote(_ h: String) -> Bool { h.contains("wikipedia.org") || (quoted[h] ?? 0) == 0 }
        var lines: [String] = []
        for t in top where lines.count < 3 {
            guard let s = sents.first(where: { s in s.text.contains("《\(t)》") && cue.contains { s.text.contains($0) }
                && !s.text.contains("獎") && canQuote(s.host) }) else { continue }
            quoted[s.host, default: 0] += 1
            lines.append("• 《\(t)》：" + Cite.whole(s.text, host: s.host, limit: 70))
        }
        let overall = sents.first { s in covers(s.text, who) && !s.text.contains("獎") && canQuote(s.host)
            && ["作品多", "作品常", "作品大多", "風格", "主題", "擅長", "探討", "美學", "題材"].contains { s.text.contains($0) } }
        guard !lines.isEmpty || overall != nil else { return nil }
        var out: [String] = []
        if let o = overall { out.append(Cite.whole(o.text, host: o.host)) }
        if !lines.isEmpty { out.append("代表作在講什麼：\n" + lines.joined(separator: "\n")) }
        return out.joined(separator: "\n")
    }

    /// 段落的第一句（給「次要・補充」用，最多 80 字）
    static func lead(_ passage: String) -> String {
        var out = ""
        for ch in passage {
            out.append(ch)
            if "。！？!?；".contains(ch) || out.count >= 80 { break }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 主次：大腦判斷「講的是同一件事、但不是直接回答」的段落，當成次要・補充（每個網站一段、最多兩段）
    static func secondary(_ all: [Reading], excluding used: [Reading]) -> [String] {
        guard all.contains(where: { $0.span.main >= 0 }) else { return [] }
        var seen = Set(used.map { String($0.passage.prefix(30)) })
        var hosts = Set<String>()
        var out: [String] = []
        let cands = all.filter { $0.span.side > 0.3 && $0.span.side + $0.span.main > 2 * $0.span.none }
            .sorted { $0.span.side + $0.span.main > $1.span.side + $1.span.main }
        for r in cands where out.count < 2 {
            guard seen.insert(String(r.passage.prefix(30))).inserted, hosts.insert(r.host).inserted else { continue }
            let l = lead(r.passage)
            // 網頁標題、導覽列（「…- 維基百科，自由的百科全書跳至內容」）不是內容
            guard l.count >= 8, !["跳至內容", "自由的百科全書", "維基百科", "新增話題"].contains(where: { l.contains($0) }) else { continue }
            out.append("• 「\(l)」（\(r.host)）")
        }
        return out
    }

    static func key(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation && !"「」『』《》()（）".contains($0) }
    }

    static func hostWeight(_ h: String) -> Float {
        let w = Understanding.weight(h)
        return w == 0 ? 0.3 : Float(w)
    }

    public static func conclude(question: String, pages: [Understanding.Evidence], snippets: [Understanding.Evidence],
                                brain: Brain, budget: Int = 40, accept: ((String) -> Bool)? = nil) -> Conclusion? {
        // ① 切段、② 粗挑
        let g = grams(question)
        var cands: [(text: String, host: String, overlap: Int)] = []
        var seen = Set<String>()
        for p in pages + snippets {
            for para in passages(p.text) where seen.insert(String(para.prefix(40))).inserted {
                let cp = canonText(para)
                let n = g.filter { cp.contains($0) }.count
                if n > 0 { cands.append((para, p.host, n)) }
            }
        }
        cands.sort { $0.overlap > $1.overlap }
        let chosen = Array(cands.prefix(budget))
        guard !chosen.isEmpty else { return nil }

        // ③ 每一段都讓大腦讀
        var all: [Reading] = []
        for c in chosen {
            // accept：答案要像這題要的東西（問距離要有數字和單位……），不像的不算
            if let sp = brain.read(question: question, passage: c.text), accept?(sp.text) ?? true, !junk(sp.text),
               superlativeFits(question: question, passage: c.text) {
                all.append(Reading(passage: c.text, host: c.host, span: sp))
            }
        }
        // 哪些段落算「在回答問題」：大腦有把握的（分數 > 0），或是明顯比其他段落高、又不會低得離譜的
        // （描述型的問題「他的書在講什麼」，相關段落常是 -3，不相關的是 -10 以下）
        let bestScore = all.map(\.span.score).max() ?? -100
        let floor: Float = -6

        // 要一段說明的題目（在講什麼、怎麼辦、為什麼）：不切幾個字當答案，給最在回答問題的整句話（每個網站一句、最多兩句）
        if wantsSentences(question) {
            func rank(_ r: Reading) -> Float { (r.span.main >= 0 ? r.span.main * 10 : 0) + r.span.score * 0.3 }
            let pool = all.filter { $0.span.main < 0 || $0.span.none < 0.5 }.sorted { rank($0) > rank($1) }
            var lines: [String] = []
            var usedHosts = Set<String>()
            var shownFrom: [Reading] = []
            // 先找有「講述、描寫」「因為」「可以、建議」這類字的句子（真的在說明），一句都沒有才放寬
            let want = cues(question)
            for needCue in (want.isEmpty ? [false] : [true, false]) where lines.isEmpty {
                for r in pool where lines.count < 2 {
                    guard r.span.main < 0 ? r.span.score > floor : r.span.main >= 0.35 else { continue }
                    let s = sentence(around: r.span, in: r.passage)
                    guard s.count >= 8, !needCue || want.contains(where: { s.contains($0) }),
                          onTopic(question: question, sentence: s, passage: r.passage),
                          !usedHosts.contains(r.host) else { continue }
                    usedHosts.insert(r.host)
                    lines.append(Cite.whole(s, host: r.host))
                    shownFrom.append(r)
                }
            }
            if let top = shownFrom.first {
                let sureEnough = top.span.main >= 0 ? top.span.main >= 0.6 : top.span.score > 0
                var t = lines.joined(separator: "\n")
                let side = secondary(all.filter { onTopic(question: question, sentence: lead($0.passage), passage: $0.passage) }, excluding: shownFrom)
                if !side.isEmpty { t += "\n\n【次要・補充】\n" + side.joined(separator: "\n") }
                if !sureEnough { t = "（我讀到的資料沒有直接講明，下面是最接近的內容，把握不高）\n" + t }
                return Conclusion(text: t, confident: true, read: chosen.count, relevant: lines.count,
                                  hosts: Array(Set(shownFrom.map(\.host))), unsure: !sureEnough, answer: "",
                                  topScore: top.span.score, support: lines.count)
            }
            // 沒有一句真的在講這件事：不要退回去切幾個字當答案（「答案：欠薪」），交給別的方法或老實說沒找到
            return Conclusion(text: "", confident: false, read: chosen.count, relevant: 0, hosts: [])
        }
        // 有把握的段落就只用它們；一段都沒有時，才退一步取最接近的兩三段（分數離最高分 2 分以內）
        let sure = all.filter { $0.span.score > 0 }
        // 主次判斷：大腦覺得「跟這題無關」的段落（無關的機率過半）就不拿來湊答案
        let related = all.filter { $0.span.main < 0 || $0.span.none < 0.5 }
        let readings = !sure.isEmpty ? sure
            : Array(related.filter { $0.span.score > floor && $0.span.score > bestScore - 2 }.sorted { $0.span.score > $1.span.score }.prefix(3))
        let unsure = bestScore <= 0
        let allHosts = Array(Set(readings.map(\.host)))
        guard !readings.isEmpty else {
            return Conclusion(text: "", confident: false, read: chosen.count, relevant: 0, hosts: [])
        }

        // ④ 比對：同一個說法（或一個包含另一個）算一組；每個網站在一組裡只算一次，取最有把握的那段
        struct Group { var shown: String; var key: String; var best: [String: Reading]; var count = 1 }
        var groups: [Group] = []
        for r in readings.sorted(by: { $0.span.score > $1.span.score }) {
            let k = key(r.span.text)
            guard !k.isEmpty else { continue }
            if let i = groups.firstIndex(where: { $0.key == k || ($0.key.count >= 2 && k.contains($0.key)) || (k.count >= 2 && $0.key.contains(k)) }) {
                if groups[i].best[r.host] == nil { groups[i].best[r.host] = r }
                groups[i].count += 1
            } else {
                groups.append(Group(shown: r.span.text, key: k, best: [r.host: r]))
            }
        }
        func weight(_ g: Group) -> Float {
            // 每個網站算一次（取最有把握的那段），同一個說法被越多段落提到份量越重
            g.best.values.reduce(0) { $0 + (min($1.span.score, 8) - floor) / (8 - floor) * hostWeight($1.host) + 0.2 }
                + 0.25 * Float(min(g.count - 1, 4))
        }
        groups.sort { weight($0) > weight($1) }
        guard let top = groups.first else { return nil }
        let total = groups.reduce(0) { $0 + weight($1) }
        let topW = weight(top)
        func cite(_ r: Reading) -> String { "「\(sentence(around: r.span, in: r.passage))」（\(r.host)）" }

        // ⑤ 下結論
        var t = ""
        // 大腦有把握時，最好的那個說法就是答案（其他列為補充或不同說法）；沒把握時才整理成幾個重點
        let clear = !unsure || topW >= 0.45 * total || groups.count <= 2
        if clear {
            let lead = top.best.values.max { $0.span.score < $1.span.score }!
            t = "答案：\(top.shown)"
            if top.best.count >= 2 { t += "（\(top.best.count) 個網站都這樣說）" }
            t += "\n依據：" + cite(lead)
            // 說法不一：第二名也有一定份量，而且不是同一件事
            // 只有第二名也很有把握、分數和第一名差不多時，才算說法不一（不然只是不相干的數字）
            let leadScore = lead.span.score
            func bestOf(_ g: Group) -> Reading { g.best.values.max { $0.span.score < $1.span.score }! }
            if let second = groups.dropFirst().first, weight(second) >= 0.5 * topW,
               bestOf(second).span.score > 1, bestOf(second).span.score >= leadScore - 1 {
                let r = bestOf(second)
                t += "\n⚠️ 來源說法不一：也有說是「\(second.shown)」，" + cite(r)
            }
            // 補充：其他在回答這個問題、但講法不同的段落（每個網站最多一句）
            var used = Set(top.best.keys)
            var more: [String] = []
            for gp in groups.dropFirst() where more.count < 2 {
                // 補充也要夠相關：分數離答案不能太遠
                guard let r = gp.best.values.max(by: { $0.span.score < $1.span.score }), r.span.score >= leadScore - 2,
                      used.insert(r.host).inserted else { continue }
                more.append("• " + cite(r))
            }
            if !more.isEmpty { t += "\n\n我還讀到：\n" + more.joined(separator: "\n") }
        } else {
            // 沒有單一的答案（「他的書在講什麼」「怎麼看待……」）：把讀到的幾個重點整理出來
            t = "這題沒有單一的答案，我讀了 \(readings.count) 段相關的內容，整理出這幾個重點："
            var usedHosts: [String: Int] = [:]
            var n = 0
            for gp in groups where n < 5 {
                guard let r = gp.best.values.max(by: { $0.span.score < $1.span.score }), usedHosts[r.host, default: 0] < 2 else { continue }
                usedHosts[r.host, default: 0] += 1
                n += 1
                t += "\n\(n). \(gp.shown) —— " + cite(r)
            }
        }
        let side = secondary(all, excluding: readings)
        if !side.isEmpty { t += "\n\n【次要・補充】\n" + side.joined(separator: "\n") }
        if unsure { t = "（我讀到的資料沒有直接講明，下面是最接近的內容，把握不高）\n" + t }
        let topBest = top.best.values.map(\.span.score).max() ?? 0
        return Conclusion(text: t, confident: true, read: chosen.count, relevant: readings.count, hosts: allHosts, unsure: unsure,
                          answer: top.shown, topScore: topBest, support: top.count)
    }
}
