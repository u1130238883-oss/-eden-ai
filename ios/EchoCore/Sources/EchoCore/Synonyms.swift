import Foundation

/// 近義詞：同一個意思可以用別的詞說（開心＝快樂＝高興；益處＝好處；何處＝哪裡）。
/// ①理解問題時先換成常用的說法 ②判斷句子有沒有講到主題時，近義詞也算 ③回答「X 的近義詞」「X 和 Y 意思一樣嗎」
public enum Synonyms {
    static let index: [String: [Int]] = {
        var d: [String: [Int]] = [:]
        for (i, g) in SynonymData.groups.enumerated() { for w in g { d[w, default: []].append(i) } }
        return d
    }()

    public static func known(_ w: String) -> Bool { index[w] != nil }

    /// 意思相近的詞（不含自己；一個詞有好幾個意思時，每一組都算）
    public static func near(_ w: String) -> [String] {
        var out: [String] = []
        for i in index[w] ?? [] { for x in SynonymData.groups[i] where x != w && !out.contains(x) { out.append(x) } }
        return out
    }

    /// 兩個詞意思相近嗎（在同一組）
    public static func same(_ a: String, _ b: String) -> Bool {
        guard let ia = index[a], let ib = index[b] else { return false }
        return !Set(ia).isDisjoint(with: ib)
    }

    /// 問句裡的用詞換成常用的說法，理解才一致（「何處」→「哪裡」、「有何益處」→「有什麼好處」、「怎麼烹調」→「怎麼做」）
    static let cueSwaps: [(String, String)] = [
        ("何謂", "什麼是"), ("什麼叫做", "什麼是"), ("何處", "哪裡"), ("何地", "哪裡"), ("哪兒", "哪裡"), ("何人", "誰"), ("哪位", "誰"),
        ("何年", "哪一年"), ("何時", "什麼時候"), ("幾時", "什麼時候"), ("何故", "為什麼"), ("緣何", "為什麼"), ("為啥", "為什麼"),
        ("有何", "有什麼"), ("為何物", "是什麼"), ("何物", "什麼"),
        ("益處", "好處"), ("長處", "好處"), ("害處", "壞處"), ("弊端", "壞處"), ("短處", "壞處"),
        ("留意", "注意"), ("當心", "注意"), ("位在", "位於"), ("坐落在", "位於"), ("座落於", "位於"), ("地處", "位於"),
        ("的緣由", "的原因"), ("的緣故", "的原因"), ("的起因", "的原因"), ("的理由", "的原因"), ("的原由", "的原因"),
        ("的含義", "的意思"), ("的涵義", "的意思"), ("的意涵", "的意思"), ("的意義是什麼", "的意思"),
        ("需要留意", "要注意"), ("須注意", "要注意"), ("需注意", "要注意"), ("應注意", "要注意"), ("該注意", "要注意"),
        ("要如何", "怎麼"), ("該如何", "怎麼"), ("如何才能", "怎樣才能"),
    ]

    public static func normalize(_ q: String) -> String {
        var t = q
        for (a, b) in cueSwaps where t.contains(a) {
            if a.hasPrefix("何") {
                // 「如何處理」「任何人」「為何物」的「何」是別的詞的一部分，不換
                t = t.replacingOccurrences(of: "(?<![如任為若奈幾])" + a, with: b, options: .regularExpression)
            } else {
                t = t.replacingOccurrences(of: a, with: b)
            }
        }
        // 「怎麼烹調／料理／烹煮／製作黃燜雞」＝「怎麼做黃燜雞」（「日本料理」的「料理」是名詞，不換）
        t = t.replacingOccurrences(of: "(怎麼|如何|怎樣)(烹調|烹煮|烹飪|料理|製作|弄)", with: "$1做", options: .regularExpression)
        return t
    }

    // MARK: - 回答「近義詞」的問題

    static func strip(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: "「」『』\"'“”‘’ 　"))
    }

    /// 「開心的近義詞是什麼」「快樂有哪些同義詞」「高興可以換成什麼詞」（順序有意義：長的說法先比對）
    static let nearPatterns = [
        #"^(.{1,8}?)(?:有什麼|有哪些|有沒有)(?:近義詞|同義詞|同義字|近義字|意思相近的詞|意思差不多的詞|類似的詞|相近的詞|相似的詞|別的說法|其他說法)$"#,
        #"^(.{1,8}?)(?:可以|能)(?:換成|改成|用)(?:什麼|哪些)(?:詞|說法|字)(?:代替|替換|來說)?$"#,
        #"^(.{1,8}?)的(?:另一種|其他|別的)說法(?:是什麼|有哪些)?$"#,
        #"^(?:跟|和|與)(.{1,8}?)意思(?:一樣|相同|相近|差不多|接近)的(?:詞|字)(?:有哪些|有什麼|是什麼)?$"#,
        #"^(?:還有)?什麼詞(?:跟|和|與)(.{1,8}?)(?:的)?(?:意思)?(?:一樣|相同|相近|差不多|接近)$"#,
        #"^(.{1,8}?)的(?:近義詞|同義詞|相近詞|相似詞|類似詞|近似詞|同義字|近義字)(?:是什麼|是哪些|有哪些|有什麼|有幾個)?$"#,
        #"^(.{1,8}?)(?:近義詞|同義詞|相近詞|相似詞|同義字|近義字)(?:是什麼|是哪些|有哪些|有什麼)?$"#,
    ]
    /// 比較兩個詞：A（和／跟／與／同）B ＋ 比較的說法
    static let pairTail = #"^(?:的)?(?:意思)?(?:是)?(?:一樣|相同|相近|差不多|接近|同義詞|近義詞|一樣的意思|同樣的意思|一個意思|有什麼不同|有什麼差別|有什麼區別|有啥不同|有啥差別|不同|差別|區別|差異|的差別|的不同)(?:的)?(?:意思)?$"#
    static let pairOther = [
        #"^(.{1,8}?)(?:可以|能)(?:換成|改成|代替|替換)(.{1,8}?)$"#,
        #"^(.{1,8}?)(?:能不能|可不可以)(?:換成|改成|代替|替換|用)(.{1,8}?)(?:代替|替換)?$"#,
        #"^(.{1,8}?)(?:是不是|是否)(?:就是)?(.{1,8}?)的意思$"#,
    ]

    public enum Ask { case near(String), pair(String, String) }

    /// 問的是詞本身：只拿掉客套話和結尾，不換說法（「何處」就是在問「何處」這個詞）
    static func plainForWords(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for w in ["請問一下", "請問", "我想知道", "想知道", "想問一下", "想問", "我想問", "欸，", "欸", "可以告訴我", "所以"] where t.hasPrefix(w) && t.count > w.count + 2 {
            t = String(t.dropFirst(w.count)); break
        }
        while let l = t.last, "？?！!。～~ 呢嗎啊呀吧".contains(l), t.count > 2 { t.removeLast() }
        return t
    }

    static func comparesThings(_ t: String, _ a: String, _ b: String) -> Bool {
        !same(a, b) && t.range(of: "不同|差別|差異|區別|比較", options: .regularExpression) != nil
            && t.range(of: "意思|同義|近義|一樣|相同|意義|詞", options: .regularExpression) == nil
    }

    public static func parse(_ raw: String) -> Ask? {
        let t = plainForWords(raw)
        // 「X 可以換成什麼」：在問近義詞
        if let m = Understanding.match(t, #"^(.{1,8}?)(?:可以|能)(?:換成|改成|用)(?:什麼|啥)$"#) { return .near(strip(m[1])) }
        // 先看是不是在比較兩個詞（「理想和夢想是同義詞嗎」不是在問「理想和夢想是」的同義詞）；
        // 但兩邊都要是詞庫裡的詞——「碳中和有什麼近義詞」切成「碳中」「有什麼」不是兩個詞，是在問「碳中和」
        let cands = pairCandidates(t)
        if let p = cands.first(where: { known($0.0) && known($0.1) }) {
            // 「跑步跟游泳有什麼不同」：兩個意思不相近的詞、問「不同、差別」又沒提到意思——是在比較兩樣東西，不是問近義詞
            if comparesThings(t, p.0, p.1) { return nil }
            return .pair(p.0, p.1)
        }
        for p in nearPatterns {
            if let m = Understanding.match(t, p) {
                var w = strip(m[1])
                // 「假的意思差不多」：「假的」本身是一個詞
                if !known(w), known(w + "的"), t.contains(w + "的") { w += "的" }
                if !w.isEmpty, w.count <= 8 { return .near(w) }
            }
        }
        // 兩個都不認得的詞（「Kindle和紙本書的差別」）：只有明說在問意思（意思、同義、近義、一樣）才算近義詞題，不然是在比較兩樣東西
        if let p = cands.first(where: { known($0.0) || known($0.1) }) { return .pair(p.0, p.1) }
        if let p = cands.first, t.range(of: "意思|同義|近義|一樣|相同", options: .regularExpression) != nil { return .pair(p.0, p.1) }
        return nil
    }

    /// 找出兩個詞：每一個「和／跟／與／同」都試著切開，兩邊都是詞庫裡的詞最好（「柔和和親切」要切在第二個「和」）
    static func pairCandidates(_ t: String) -> [(String, String)] {
        let cs = Array(t)
        var candidates: [(String, String)] = []
        for (i, c) in cs.enumerated() where "和跟與同".contains(c) && i >= 1 && i < cs.count - 1 {
            let a = strip(String(cs[..<i]))
            let rest = Array(cs[(i + 1)...])
            // 短的先試：「啥和什麼是一樣的意思」的「是」是動詞，詞是「什麼」
            for j in 1...rest.count where j < rest.count {
                let tail = String(rest[j...]), b = strip(String(rest[..<j]))
                guard !b.isEmpty, b.count <= 8, a.count <= 8, !a.isEmpty, a != b else { continue }
                if Understanding.match(tail, pairTail) != nil { candidates.append((a, b)) }
            }
        }
        for p in pairOther {
            if let m = Understanding.match(t, p) {
                let a = strip(m[1]), b = strip(m[2])
                if !a.isEmpty, !b.isEmpty, a != b { candidates.append((a, b)) }
            }
        }
        // 「什麼詞」「哪些詞」是在問，不是要比較的詞（「X 可以換成什麼詞」「什麼詞跟 X 意思差不多」是在問近義詞）
        let asking = #"^(什麼|哪些|哪個|哪一個|甚麼)(詞|字|說法|詞語)$"#
        candidates.removeAll { Understanding.match($0.0, asking) != nil || Understanding.match($0.1, asking) != nil || $0.0.hasPrefix("什麼詞") }
        return candidates
    }

    /// 用詞庫回答；詞庫裡沒有的詞回傳 nil（交給上網查）
    public static func answer(_ ask: Ask) -> String? {
        switch ask {
        case let .near(w):
            let n = near(w)
            guard !n.isEmpty else { return nil }
            return "「\(w)」意思相近的詞：" + n.prefix(8).joined(separator: "、") + "。\n這些詞多數情況可以互換，只是正式程度、語氣和常用的場合略有不同。"
        case let .pair(a, b):
            guard known(a), known(b) else { return nil }
            if same(a, b) {
                let others = near(a).filter { $0 != b && near(b).contains($0) }.prefix(4)
                return "「\(a)」和「\(b)」意思相近，多數情況可以互換。" + (others.isEmpty ? "" : "同一類的還有：" + others.joined(separator: "、") + "。")
                    + "\n細微的差別在語氣和正式程度，正式的文章常用比較書面的那個。"
            }
            let na = near(a).prefix(3).joined(separator: "、"), nb = near(b).prefix(3).joined(separator: "、")
            return "「\(a)」和「\(b)」意思不一樣，不能互換。\n「\(a)」接近：\(na)\n「\(b)」接近：\(nb)"
        }
    }
}
