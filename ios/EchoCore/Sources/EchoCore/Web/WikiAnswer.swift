import Foundation

/// 維基百科的開頭摘要（作品再加劇情那一節）整理成回答。
/// 「X 是什麼」：第一句就是定義，再補一兩個重點。「X 在講什麼」：它是什麼 → 故事怎麼開始 → 最後怎麼收場。
/// 只整理、不加料：句子都是條目裡的，外文註解、演員名單這些雜訊拿掉。
enum WikiAnswer {
    typealias Brief = (title: String, text: String, url: String)

    /// 一句一句拆開（句號、問號、驚嘆號、換行），句尾符號留著
    static func sentences(_ s: String) -> [String] {
        var out: [String] = [], cur = ""
        let chars = Array(s)
        for (i, ch) in chars.enumerated() {
            if ch == "\n" { if !cur.trimmingCharacters(in: .whitespaces).isEmpty { out.append(cur) }; cur = ""; continue }
            cur.append(ch)
            // 《你的名字。》「這就是愛。」：句號後面跟著引號、書名號，還沒講完
            let closing = i + 1 < chars.count && "》」』）)”".contains(chars[i + 1])
            if "。！？".contains(ch), !closing { out.append(cur); cur = "" }
        }
        if !cur.trimmingCharacters(in: .whitespaces).isEmpty { out.append(cur) }
        return out.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count >= 2 }
    }

    static func foreign(_ c: Character) -> Bool {
        guard let u = c.unicodeScalars.first?.value else { return false }
        // 希臘、西里爾、帶重音的拉丁字母、注音
        return (0x0370...0x052F).contains(u) || (0x00C0...0x024F).contains(u) || (0x1F00...0x1FFF).contains(u) || (0x3100...0x312F).contains(u) || (0x0300...0x036F).contains(u)
    }

    /// 拿掉括號裡的外文原名、注音、演員（「（英語：time）」「（ㄒㄧㄥˊ）」「（沈騰飾）」），和夾著外文字母的子句
    static func plainLead(_ raw: String) -> String {
        var s = raw
        for _ in 0..<3 {
            guard let re = try? NSRegularExpression(pattern: "[（(]([^（()）]*)[)）]") else { break }
            let ns = s as NSString
            var out = "", last = 0, changed = false
            for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
                let inner = ns.substring(with: m.range(at: 1))
                let gloss = inner.contains("語：") || inner.contains("语：") || inner.contains("文：") || inner.contains("羅馬") || inner.hasSuffix("飾") || inner.hasSuffix("饰")
                    || inner.contains(where: foreign)
                    || inner.filter({ $0.isASCII && $0.isLetter }).count >= 4
                    || !inner.contains(where: { ("\u{4E00}"..."\u{9FFF}").contains($0) })
                out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                if gloss { changed = true } else { out += ns.substring(with: m.range) }
                last = m.range.location + m.range.length
            }
            out += ns.substring(from: last)
            s = out
            if !changed { break }
        }
        // 落單的括號、夾著外文字母的子句
        var depth = 0, kept = ""
        for ch in s {
            if "（(".contains(ch) { depth += 1 }
            if ")）".contains(ch) { if depth == 0 { continue }; depth -= 1 }
            kept.append(ch)
        }
        s = sentences(kept).map { sent -> String in
            guard sent.contains(where: foreign) else { return sent }
            let end = sent.last.map { "。！？".contains($0) ? String($0) : "" } ?? ""
            let body = end.isEmpty ? sent : String(sent.dropLast())
            return body.components(separatedBy: "，").filter { !$0.contains(where: foreign) }.joined(separator: "，") + end
        }.joined()
        return s.replacingOccurrences(of: "，，", with: "，").replacingOccurrences(of: " ，", with: "，").replacingOccurrences(of: "，。", with: "。")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func shorten(_ s: String, _ n: Int) -> String {
        guard s.count > n else { return s }
        let head = String(s.prefix(n))
        if let i = head.lastIndex(where: { "，；".contains($0) }), head.distance(from: head.startIndex, to: i) >= n / 2 { return String(head[..<i]) + "…" }
        return head + "…"
    }

    /// 留到 n 個字以內最後一個完整的句子
    static func clipWhole(_ s: String, _ n: Int) -> String {
        guard s.count > n else { return s }
        let head = String(s.prefix(n))
        if let i = head.lastIndex(where: { "。！？".contains($0) }), head.distance(from: head.startIndex, to: i) >= n / 3 { return String(head[...i]) }
        return shorten(head, n)
    }

    static func parts(_ b: Brief) -> (intro: String, plot: String) {
        let t = WebStrategy.toTraditional(b.text)
        let ps = t.components(separatedBy: "\n劇情：")
        return (ps[0], ps.count > 1 ? ps[1] : "")
    }

    static let source = "zh.wikipedia.org"

    /// 「五行是什麼」：第一句定義 ＋ 最多兩個重點
    static func define(subject: String, brief b: Brief) -> (text: String, evidence: [String])? {
        let intro = parts(b).intro
        let ss = sentences(plainLead(intro)).filter { !$0.contains("條目") && !$0.contains("可以指") && !$0.contains("可能指") }
        guard let first = ss.first, first.count >= 8 else { return nil }
        // 第一句用分號接了一長串：定義只到分號為止
        var lead = first
        if lead.count > 60, let i = lead.firstIndex(where: { "；;".contains($0) }), lead.distance(from: lead.startIndex, to: i) >= 12 { lead = String(lead[..<i]) + "。" }
        lead = shorten(lead, 130)
        var points: [String] = []
        for s in ss.dropFirst() where points.count < 2 && s.count >= 12 && s.count <= 120 && "。！？".contains(s.last ?? " ") { points.append(s) }
        var text = "📌 回答\n簡單說：" + lead
        if !points.isEmpty { text += "\n\n重點：\n" + points.enumerated().map { ["①", "②"][$0.offset] + " " + $0.element }.joined(separator: "\n") }
        text += "\n來源：" + source
        return (text, [clipWhole(plainLead(intro), 520)])
    }

    static let workWords = ["《", "小說", "電影", "動畫", "漫畫", "影集", "電視劇", "戲劇", "作品", "專輯", "歌曲", "遊戲", "童話", "詩集", "散文"]

    /// 「少年維特的煩惱在講什麼」：它是什麼 → 故事 → 結局
    static func work(title: String, brief b: Brief) -> (text: String, evidence: [String])? {
        let (introRaw, plotRaw) = parts(b)
        let intro = sentences(plainLead(introRaw))
        guard let what = intro.first, what.count >= 8 else { return nil }
        // 沒有劇情那一節、開頭也看不出是作品：當成一般的東西來解釋
        if plotRaw.isEmpty, !workWords.contains(where: { introRaw.prefix(200).contains($0) }) { return define(subject: title, brief: b) }
        var lines = ["📌 回答", shorten(what, 150)]
        // 交給大腦讀的資料：開頭介紹＋劇情的開頭和結尾，總共九百字以內（大腦的工作區只有 2048 個 token）
        var evidence = [clipWhole(plainLead(introRaw), 260)]
        if !plotRaw.isEmpty {
            let halves = plotRaw.components(separatedBy: "\n……\n")
            // 「絕大部分的情節是在信中敘述的」這種講寫法的句子不是故事
            let head = sentences(plainLead(halves[0])).filter { !($0.count < 40 && ($0.contains("情節") || $0.contains("敘述"))) }
            var story = ""
            for s in head { if story.isEmpty || story.count + s.count <= 200 { story += s } else { break } }
            if !story.isEmpty { lines.append("📖 故事：" + shorten(story, 300)) }
            // 結局：劇情很長時是另外留下來的結尾；不長時是故事後面還沒講到的最後幾句
            let rest = head.joined().count > story.count + 60 ? String(head.joined().dropFirst(story.count)) : ""
            if halves.count > 1 || !rest.isEmpty {
                let tail = sentences(halves.count > 1 ? plainLead(halves[1]) : rest)
                var end = ""
                for s in tail.reversed() { if end.isEmpty || end.count + s.count <= 130 { end = s + end } else { break } }
                if end.count >= 8 { lines.append("🔚 結局：" + shorten(end, 170)) }
            }
            let whole = plainLead(halves[0]).replacingOccurrences(of: "\n", with: "")
            var tail = halves.count > 1 ? plainLead(halves[1]).replacingOccurrences(of: "\n", with: "") : ""
            var front = whole
            if tail.isEmpty, whole.count > 620 {
                // 劇情中等長度：一樣留開頭和結尾
                let end = String(whole.suffix(260))
                tail = end.firstIndex(where: { "。！？".contains($0) }).map { String(end[end.index(after: $0)...]) } ?? end
                front = String(whole.dropLast(260))
            }
            evidence.append("劇情：" + clipWhole(front, tail.isEmpty ? 620 : 340) + (tail.isEmpty ? "" : "\n結局：" + String(tail.suffix(280))))
        } else {
            let cues = ["講述", "描寫", "描述", "敘述", "故事", "主角", "主人公", "圍繞", "核心"]
            var story = ""
            for s in intro.dropFirst() where cues.contains(where: { s.contains($0) }) && story.count + s.count <= 240 { story += s }
            if story.isEmpty, intro.count > 1 { story = shorten(intro[1], 200) }
            if !story.isEmpty { lines.append("📖 內容：" + story) }
        }
        lines.append("來源：" + source)
        return (lines.joined(separator: "\n"), evidence)
    }
}
