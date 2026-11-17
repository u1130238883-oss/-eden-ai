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
        ("趕走", "消滅"), ("趕跑", "消滅"), ("要買什麼", "要準備什麼"), ("好臭", "有臭味"), ("很臭", "有臭味"), ("臭臭的", "有臭味"), ("好貴", "太高"),
        ("想不起來", "忘記"), ("想不起", "忘記"),
        // 比較兩個東西：「內向跟外向差在哪裡」＝內向和外向的差別
        ("差在哪裡", "的差別"), ("差在哪", "的差別"), ("有什麼不一樣", "的差別"), ("有什麼不同", "的差別"), ("哪裡不一樣", "的差別"), ("有何不同", "的差別"),
        ("差異", "差別"), ("跟", "和"), ("與", "和"),
        // 「男朋友」「女朋友」不是「朋友」
        ("男朋友", "男友"), ("女朋友", "女友"),
        ("每個國家", "各國"), ("各個國家", "各國"), ("上班", "工作"), ("需要", "要"), ("小嬰兒", "嬰兒"), ("寶寶", "嬰兒"),
        ("刺破", "弄破"), ("戳破", "弄破"), ("挑破", "弄破"), ("擠破", "弄破"), ("越來越卡", "很慢"), ("越來越慢", "很慢"), ("越來越", "很"),
        ("找到吃的", "找到食物"), ("找吃的", "找食物"), ("有什麼好處", "有什麼用"), ("有什麼優惠", "有什麼用"), ("有什麼福利", "有什麼用"),
        ("型態", "狀態"), ("盜用", "盜刷"), ("儲值", "加值"), ("照顧", "保養"), ("哪一種", "什麼"), ("哪種", "什麼"), ("要怎麼做", "怎麼辦"), ("該怎麼做", "怎麼辦"), ("什麼東西", "什麼"), ("是啥", "是什麼"), ("啥", "什麼"),
    ]
    /// 不帶內容的字詞：拿掉之後把句子切成幾段
    static let function = ["怎麼辦", "要怎麼", "該怎麼", "怎麼", "可以", "為什麼", "什麼", "哪裡", "哪些", "比較", "要", "該", "嗎", "呢", "啊", "了", "的", "我", "你",
                           "是", "有", "去", "會", "才", "一下", "喔", "啦", "吧", "請問", "能不能", "能", "一次"]
    /// 加強、進行的字：拿掉但不切開（「壓力很大」＝壓力大、「手機一直當機」＝手機當機）
    static let joinWords = ["一下就", "很快就", "馬上就", "一直在", "正在", "還在", "一直", "好像", "最近", "常常", "很", "都"]
    /// 問的方向；第 0 組是「是不是、可不可以」這種是非題
    static let focusGroups: [[String]] = [["嗎", "要不要", "可不可以", "能不能"],
                                          ["多久", "幾天", "幾個月", "幾年", "多長", "幾小時", "幾個小時", "幾分鐘", "幾秒", "幾週", "幾個禮拜", "幾個星期"],
                                          ["多少錢", "多少", "幾元", "幾塊"],
                                          // 「第一次世界大戰是怎麼開始的」＝為什麼開始；「流星是怎麼形成的」
                                          ["為什麼", "怎麼形成", "怎麼來的", "怎麼開始", "怎麼發生", "怎麼產生", "怎麼出現", "原因"],
                                          ["什麼時候", "何時", "哪一年", "哪年"], ["哪裡", "在哪"], ["是什麼", "什麼是", "什麼意思"], ["幾度"],
                                          // 「一天可以喝幾杯咖啡」＝喝多少
                                          ["幾個", "幾種", "幾次", "多少", "幾杯", "幾碗", "幾顆", "幾片", "幾瓶", "幾罐", "幾隻", "幾張", "幾份", "幾餐", "幾步",
                                           "幾公斤", "幾克", "幾斤", "幾公分", "幾公尺", "幾毫升", "幾歲", "幾人", "幾位", "幾樣", "幾條", "幾本", "幾件", "幾台"]]

    struct Token { let text: String; let lo: Int; let hi: Int }
    struct Segment { let text: [Character]; let tokens: [Token] }
    struct Entry { let entity: Commonsense.Entity; let alias: String; let segments: [Segment]; let tokens: Set<String>; let chars: Int; let focus: Set<Int>; let isFact: Bool }

    static func normalize(_ t: String) -> String {
        var t = t.lowercased()
        for (a, b) in synonyms { t = t.replacingOccurrences(of: a, with: b) }
        // 「頭髮好油」「最近變胖」＝很油、很胖
        t = t.replacingOccurrences(of: "(好|變)(?=[油乾胖瘦黑黃腫癢痛累酸痠悶脹吵臭濕慢])", with: "很", options: .regularExpression)
        // 「台灣飛日本要多久」＝台灣到日本
        t = t.replacingOccurrences(of: "(台灣|台北|桃園|高雄|台中|日本|東京|大阪|香港|韓國|首爾|泰國|曼谷|新加坡|美國|歐洲)飛", with: "$1到", options: .regularExpression)
        // 「去哪繳」「在哪買」＝哪裡（「哪幾種」「哪三個」「哪兒」不是）
        t = t.replacingOccurrences(of: "哪(?![裡些個一二三四五六七八九十幾兒種位天年家邊])", with: "哪裡", options: .regularExpression)
        return t
    }
    static func focus(_ t: String) -> Set<Int> {
        // 「便秘好幾天了」的「幾天」不是在問
        let t = t.replacingOccurrences(of: "好幾", with: "")
        return Set(focusGroups.indices.filter { i in focusGroups[i].contains { t.contains($0) } })
    }
    static func segments(_ t: String) -> [Segment] {
        var t = t.replacingOccurrences(of: #"[，,。.！!？?、；;：:\s~～…]+"#, with: " ", options: .regularExpression)
        // 「第一次世界大戰」的「一次」不是虛詞
        t = t.replacingOccurrences(of: "第一次", with: "第一回")
        for w in joinWords { t = t.replacingOccurrences(of: w, with: "") }
        for w in function { t = t.replacingOccurrences(of: w, with: " ") }
        t = t.replacingOccurrences(of: "第一回", with: "第一次")
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
                // 事實只用問句型的問法（「剩菜可以放多久」「悠遊卡怎麼加值」），不用光名字
                if fact && f.isEmpty && an.range(of: "怎麼|如何|要注意|方法|辦法|步驟|什麼|哪些|哪個|哪裡|誰", options: .regularExpression) == nil { continue }
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

    /// 拿掉虛詞、加強語氣之後剩下的核心（「最近頭一直很痛怎麼辦」→「頭痛」）對到做法的問法：只有一個說法對到才算
    static let exactIndex: [String: (entity: Commonsense.Entity, alias: String)] = {
        var m: [String: (entity: Commonsense.Entity, alias: String)] = [:]
        var clash = Set<String>()
        for e in Commonsense.howtos {
            for a in Set(e.names) {
                let segs = segments(normalize(a))
                guard segs.count == 1, segs[0].text.count >= 2 else { continue }
                let key = String(segs[0].text)
                if let old = m[key], old.entity.name != e.name { clash.insert(key) } else { m[key] = (e, a) }
            }
        }
        for k in clash { m.removeValue(forKey: k) }
        return m
    }()

    /// 最像的那個問法（對不到就 nil）
    static func match(_ raw: String) -> (entity: Commonsense.Entity, alias: String)? {
        let q = normalize(raw)
        guard (3...40).contains(q.count) else { return nil }
        let qs = segments(q)
        // 核心剛好就是某個做法（只問怎麼辦，不是問多久、為什麼、是不是）
        if qs.count == 1, focus(q).isEmpty, let hit = exactIndex[String(qs[0].text)] { return hit }
        var qt = Set<String>()
        var qchars = Set<String>()
        var qlast = Set<String>()   // 每一段的最後一個字（「哪種貓」的「貓」）
        for s in qs { for t in s.tokens { qt.insert(t.text) }; for c in s.text { qchars.insert(String(c)) }; if let l = s.text.last { qlast.insert(String(l)) } }
        let qlen = qs.reduce(0) { $0 + $1.text.count }
        let qf = focus(q)
        let qwh = qf.subtracting([0])
        let askHow = q.range(of: "怎麼|如何|要注意|方法|辦法|建議|步驟", options: .regularExpression) != nil
        var best: (score: (Double, Int, Double, Int), entry: Entry)?
        for e in index {
            let m = e.tokens.filter { qt.contains($0) || ($0.count == 1 && qchars.contains($0)) }
            guard m.count >= 2 else { continue }
            // 每一段最後的重點詞一定要對到（「老闆不給加薪」的「加薪」）
            if e.segments.contains(where: { s in
                guard let last = s.tokens.last else { return false }
                return !m.contains(last.text) || (last.text.count == 1 && !qt.contains(last.text) && !qlast.contains(last.text))
            }) { continue }
            // 比較兩個東西的問句，內容大部分都要用到（「金融卡跟信用卡有什麼不一樣」不是「信用卡怎麼辦」）；
            // 一般的長句常夾著「說真的」「嗚嗚」這類沒內容的話，不這樣要求
            var qcovered = 0
            for s in qs {
                var on = [Bool](repeating: false, count: s.text.count)
                for t in s.tokens where m.contains(t.text) { for k in t.lo..<t.hi { on[k] = true } }
                if s.tokens.count == 1, s.text.count == 1, m.contains(String(s.text[0])) { on[0] = true }
                qcovered += on.filter { $0 }.count
            }
            if q.contains("和"), !e.alias.contains("和"), Double(qcovered) / Double(max(qlen, 1)) < 0.4 { continue }
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
            // 做法裡常常就有「去哪裡辦」；食譜裡就有要煮多久
            // （事實的問法如果是「怎麼…」：「悠遊卡怎麼加值」也回答了在哪裡加值）
            let howAlias = e.alias.range(of: "怎麼|如何", options: .regularExpression) != nil
            let wh = e.isFact && !howAlias ? qwh : qwh.subtracting(e.entity.kind == "做法" ? [1, 5] : [5])
            if !wh.isEmpty && wh.isDisjoint(with: e.focus) { continue }
            // 是非題（「這樣正常嗎」）不能用一張做法清單回答，除非也在問怎麼做
            if qf.contains(0), !e.focus.contains(0), !askHow { continue }
            let score = (cov, m.count, ratio, e.alias.count)
            if best == nil || score > best!.score { best = (score, e) }
        }
        return best.map { ($0.entry.entity, $0.entry.alias) }
    }

    /// 說出一個身體或東西的狀況（「睡覺落枕了」「腳抽筋好痛」「去海邊曬傷了」）：當成在問怎麼辦
    static func problemStatement(_ raw: String, now: Date) -> String? {
        let t = Talk.clean(raw)
        guard (3...14).contains(t.count), !EchoEngine.isQuestion(raw.replacingOccurrences(of: "好幾", with: "很多")),
              t.range(of: "痠|痛|癢|抽筋|曬傷|燙傷|割傷|扭到|落枕|便秘|拉肚子|當機|壞了|不見了|漏水|塞住|發霉|中毒|過敏|咳|流鼻血|腫|頭暈|睡不著|卡住|打不開|開不了", options: .regularExpression) != nil,
              let a = Commonsense.answer(t + "怎麼辦", now: now), a.count >= 20 else { return nil }
        return a
    }

    /// 用最像的問法回答
    static func answer(_ raw: String, now: Date) -> String? {
        guard let (e, alias) = match(raw) else { return problemStatement(raw, now: now) }
        if Commonsense.howtos.contains(where: { $0.name == e.name }) { return Commonsense.formatHowto(e) }
        return Commonsense.answer(alias, now: now)
    }
}
