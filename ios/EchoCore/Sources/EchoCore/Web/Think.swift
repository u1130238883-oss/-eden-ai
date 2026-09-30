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
    }

    /// 把網頁切成段落：一行一行合併，到 120 字以上就成為一段（太長的段落大腦會自己分窗讀）
    static func passages(_ text: String) -> [String] {
        var out: [String] = [], cur = ""
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.contains("｜") else { continue }
            cur += (cur.isEmpty ? "" : "\n") + line
            if cur.count >= 120 { out.append(String(cur.prefix(600))); cur = "" }
        }
        if cur.count >= 20 { out.append(cur) }
        return out
    }

    /// 問題裡的雙字詞（「三島」「由紀」「小說」……），用來粗略挑段落
    static func grams(_ q: String) -> Set<String> {
        let skip: Set<Character> = ["什", "麼", "嗎", "呢", "的", "是", "了", "哪", "誰", "為", "怎", "吧", "啊", "有", "個", "些", "都", "在"]
        let c = Array(q.filter { !$0.isWhitespace && !$0.isPunctuation && !skip.contains($0) })
        guard c.count >= 2 else { return Set(c.map(String.init)) }
        return Set((0..<(c.count - 1)).map { String(c[$0...$0 + 1]) })
    }

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

    static func key(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation && !"「」『』《》()（）".contains($0) }
    }

    static func hostWeight(_ h: String) -> Float {
        let w = Understanding.weight(h)
        return w == 0 ? 0.3 : Float(w)
    }

    public static func conclude(question: String, pages: [Understanding.Evidence], snippets: [Understanding.Evidence],
                                brain: Brain, budget: Int = 28) -> Conclusion? {
        // ① 切段、② 粗挑
        let g = grams(question)
        var cands: [(text: String, host: String, overlap: Int)] = []
        var seen = Set<String>()
        for p in pages + snippets {
            for para in passages(p.text) where seen.insert(String(para.prefix(40))).inserted {
                let n = g.filter { para.contains($0) }.count
                if n > 0 { cands.append((para, p.host, n)) }
            }
        }
        cands.sort { $0.overlap > $1.overlap }
        let chosen = Array(cands.prefix(budget))
        guard !chosen.isEmpty else { return nil }

        // ③ 每一段都讓大腦讀
        var readings: [Reading] = []
        for c in chosen {
            if let sp = brain.read(question: question, passage: c.text), sp.score > 0 {
                readings.append(Reading(passage: c.text, host: c.host, span: sp))
            }
        }
        let allHosts = Array(Set(readings.map(\.host)))
        guard !readings.isEmpty else {
            return Conclusion(text: "", confident: false, read: chosen.count, relevant: 0, hosts: [])
        }

        // ④ 比對：同一個說法（或一個包含另一個）算一組；每個網站在一組裡只算一次，取最有把握的那段
        struct Group { var shown: String; var key: String; var best: [String: Reading] }
        var groups: [Group] = []
        for r in readings.sorted(by: { $0.span.score > $1.span.score }) {
            let k = key(r.span.text)
            guard !k.isEmpty else { continue }
            if let i = groups.firstIndex(where: { $0.key == k || ($0.key.count >= 2 && k.contains($0.key)) || (k.count >= 2 && $0.key.contains(k)) }) {
                if groups[i].best[r.host] == nil { groups[i].best[r.host] = r }
            } else {
                groups.append(Group(shown: r.span.text, key: k, best: [r.host: r]))
            }
        }
        func weight(_ g: Group) -> Float {
            g.best.values.reduce(0) { $0 + min($1.span.score, 8) / 8 * hostWeight($1.host) + 0.2 }
        }
        groups.sort { weight($0) > weight($1) }
        guard let top = groups.first else { return nil }
        let total = groups.reduce(0) { $0 + weight($1) }
        let topW = weight(top)
        func cite(_ r: Reading) -> String { "「\(sentence(around: r.span, in: r.passage))」（\(r.host)）" }

        // ⑤ 下結論
        var t = ""
        let clear = topW >= 0.45 * total || groups.count <= 2
        if clear {
            let lead = top.best.values.max { $0.span.score < $1.span.score }!
            t = "答案：\(top.shown)"
            if top.best.count >= 2 { t += "（\(top.best.count) 個網站都這樣說）" }
            t += "\n依據：" + cite(lead)
            // 說法不一：第二名也有一定份量，而且不是同一件事
            if let second = groups.dropFirst().first, weight(second) >= 0.5 * topW {
                let r = second.best.values.max { $0.span.score < $1.span.score }!
                t += "\n⚠️ 來源說法不一：也有說是「\(second.shown)」，" + cite(r)
            }
            // 補充：其他在回答這個問題、但講法不同的段落（每個網站最多一句）
            var used = Set(top.best.keys)
            var more: [String] = []
            for gp in groups.dropFirst() where more.count < 2 {
                guard let r = gp.best.values.max(by: { $0.span.score < $1.span.score }), used.insert(r.host).inserted else { continue }
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
        return Conclusion(text: t, confident: true, read: chosen.count, relevant: readings.count, hosts: allHosts)
    }
}
