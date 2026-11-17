import Foundation

/// 換句話說也找得到：「手機被人偷走了」＝手機被偷了怎麼辦、「家裡好多蚊子」＝家裡蚊子很多、「告白被打槍了」＝告白被拒絕。
/// 用詞的重疊（中文兩個字一組、英文一個字一組）比對資料庫裡的問法；規則很嚴：
/// 那句問法的內容要全部（或幾乎全部）對到、每一段最後的重點詞一定要對到、問的方向（多少、多久、為什麼…）要一樣。
/// 只在引擎本來要上網查、或只能回一句客套話的時候才用。
enum Fuzzy {
    /// 同義、口語的說法換成資料庫裡的說法（兩邊都會換）
    static let synonyms: [(String, String)] = [
        ("沒拿回來", "要不回來"), ("拿不回來", "要不回來"), ("退不回來", "要不回來"), ("要小心", "要注意"), ("小心什麼", "注意什麼"),
        ("不好好吃飯", "不吃飯"), ("都不吃飯", "不吃飯"), ("加鹽", "放鹽"), ("摩托車", "機車"), ("弄丟", "不見"), ("搞丟", "不見"), ("遺失", "不見"),
        ("打槍", "拒絕"), ("發好人卡", "拒絕"), ("孩子", "小孩"), ("辭職", "離職"), ("堵住", "塞住"), ("好卡", "很慢"), ("很卡", "很慢"), ("卡卡", "很慢"),
        ("破掉", "破"), ("好多", "很多"), ("超多", "很多"), ("老是", "一直"), ("總是", "一直"), ("丟給我", "推給我"), ("改成", "轉成"), ("去哪換", "怎麼換"),
        ("吃太撐", "吃太飽"), ("剩下的菜", "剩菜"), ("偷走", "偷"), ("被人偷", "被偷"), ("筆記型電腦", "筆電"), ("嗆到", "換氣"), ("怎樣", "怎麼"),
        ("如何", "怎麼"), ("咋辦", "怎麼辦"), ("該怎麼辦", "怎麼辦"), ("要怎麼辦", "怎麼辦"),
    ]
    /// 不帶內容的字詞：拿掉之後把句子切成幾段
    static let function = ["怎麼辦", "要怎麼", "該怎麼", "怎麼", "可以", "什麼", "哪裡", "哪些", "比較", "要", "該", "嗎", "呢", "啊", "了", "的", "我", "你", "很",
                           "一直", "都", "是", "有", "去", "會", "才", "一下", "喔", "啦", "吧", "請問", "能不能", "能"]
    /// 問的方向；第 0 組是「是不是、可不可以」這種是非題
    static let focusGroups: [[String]] = [["嗎", "要不要", "可不可以", "能不能"], ["多久", "幾天", "幾個月", "幾年", "多長"], ["多少錢", "多少", "幾元", "幾塊"],
                                          ["為什麼"], ["什麼時候", "何時", "哪一年", "哪年"], ["哪裡", "在哪"], ["是什麼", "什麼是", "什麼意思"], ["幾度"], ["幾個", "幾種", "幾次"]]

    struct Token { let text: String; let lo: Int; let hi: Int }
    struct Segment { let text: [Character]; let tokens: [Token] }
    struct Entry { let entity: Commonsense.Entity; let alias: String; let segments: [Segment]; let tokens: Set<String>; let chars: Int; let focus: Set<Int>; let isFact: Bool }

    static func normalize(_ t: String) -> String {
        var t = t.lowercased()
        for (a, b) in synonyms { t = t.replacingOccurrences(of: a, with: b) }
        return t
    }
    static func focus(_ t: String) -> Set<Int> {
        Set(focusGroups.indices.filter { i in focusGroups[i].contains { t.contains($0) } })
    }
    static func segments(_ t: String) -> [Segment] {
        var t = t.replacingOccurrences(of: #"[，,。.！!？?、；;：:\s~～…]+"#, with: " ", options: .regularExpression)
        for w in function { t = t.replacingOccurrences(of: w, with: " ") }
        return t.split(separator: " ").map { seg in
            let cs = Array(seg)
            var toks: [Token] = []
            var i = 0
            while i < cs.count {
                let latin = cs[i].isASCII && (cs[i].isLetter || cs[i].isNumber)
                var j = i
                while j < cs.count, (cs[j].isASCII && (cs[j].isLetter || cs[j].isNumber)) == latin { j += 1 }
                if latin {
                    toks.append(Token(text: String(cs[i..<j]), lo: i, hi: j))
                } else if j - i == 1 {
                    toks.append(Token(text: String(cs[i]), lo: i, hi: j))
                } else {
                    for k in i..<(j - 1) { toks.append(Token(text: String(cs[k...k + 1]), lo: k, hi: k + 2)) }
                }
                i = j
            }
            return Segment(text: cs, tokens: toks)
        }
    }

    static let index: [Entry] = {
        var out: [Entry] = []
        func add(_ e: Commonsense.Entity, fact: Bool) {
            for a in Set(e.names) where a.count >= 3 {
                let an = normalize(a)
                let f = focus(an)
                if fact && f.isEmpty { continue }   // 事實只用問句型的問法（「剩菜可以放多久」），不用光名字
                let segs = segments(an)
                let toks = Set(segs.flatMap { $0.tokens.map(\.text) })
                guard toks.count >= 2 else { continue }
                out.append(Entry(entity: e, alias: a, segments: segs, tokens: toks, chars: segs.reduce(0) { $0 + $1.text.count }, focus: f, isFact: fact))
            }
        }
        for e in Commonsense.howtos { add(e, fact: false) }
        for e in Commonsense.facts where e.kind != "推薦" { add(e, fact: true) }
        return out
    }()

    /// 最像的那個問法（對不到就 nil）
    static func match(_ raw: String) -> (entity: Commonsense.Entity, alias: String)? {
        let q = normalize(raw)
        guard (3...40).contains(q.count) else { return nil }
        let qs = segments(q)
        var qt = Set<String>()
        var qchars = Set<String>()
        for s in qs { for t in s.tokens { qt.insert(t.text) }; for c in s.text { qchars.insert(String(c)) } }
        let qf = focus(q)
        let qwh = qf.subtracting([0])
        var best: (score: (Double, Int, Double, Int), entry: Entry)?
        for e in index {
            let m = e.tokens.filter { qt.contains($0) || ($0.count == 1 && qchars.contains($0)) }
            guard m.count >= 2 else { continue }
            // 每一段最後的重點詞一定要對到（「老闆不給加薪」的「加薪」）
            if e.segments.contains(where: { s in
                guard let last = s.tokens.last else { return false }
                return !m.contains(last.text) || (last.text.count == 1 && !qt.contains(last.text))
            }) { continue }
            var covered = 0
            for s in e.segments {
                var on = [Bool](repeating: false, count: s.text.count)
                for t in s.tokens where m.contains(t.text) { for k in t.lo..<t.hi { on[k] = true } }
                covered += on.filter { $0 }.count
            }
            let cov = Double(covered) / Double(max(e.chars, 1))
            let ratio = Double(m.count) / Double(e.tokens.count)
            guard ratio >= 0.75 || cov >= 0.999 else { continue }
            // 問的方向要一樣
            if !e.focus.isEmpty && e.focus.isDisjoint(with: qf) { continue }
            let wh = e.isFact ? qwh : qwh.subtracting([5])   // 做法裡常常就有「去哪裡辦」
            if !wh.isEmpty && wh.isDisjoint(with: e.focus) { continue }
            let score = (cov, m.count, ratio, e.alias.count)
            if best == nil || score > best!.score { best = (score, e) }
        }
        return best.map { ($0.entry.entity, $0.entry.alias) }
    }

    /// 用最像的問法回答
    static func answer(_ raw: String, now: Date) -> String? {
        guard let (e, alias) = match(raw) else { return nil }
        if Commonsense.howtos.contains(where: { $0.name == e.name }) { return Commonsense.formatHowto(e) }
        return Commonsense.answer(alias, now: now)
    }
}
