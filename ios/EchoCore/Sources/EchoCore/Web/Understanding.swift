import Foundation

/// 回答之前先想清楚：對方要的是什麼樣的答案？
///   1. 理解：主題是什麼？要一個數字、一份名單、一個原因、一套做法、一個人、一個地方、一個時間、一個定義，還是比較？
///   2. 規劃：照要的答案決定怎麼查。
///   3. 取證：只挑長得像答案的內容。
///   4. 檢查：真的回答了嗎？沒有就換個查法；還是沒有就老實說。
public enum Understanding {
    public enum Want: Equatable {
        case number(attr: String, units: [String])
        case list(noun: String)
        case reason(pred: String)
        case steps(target: String)
        case person
        case place
        case time
        case definition
        case compare(String, String)
        case open
    }

    public struct Frame {
        public let subject: String
        public let want: Want
        public let searches: [String]
        public let retry: [String]
        public let wikiTitles: [String]
        public let restated: String
        /// 答案會隨時間改變（現任、最新、今年、目前……）：要找最新的資料，並說明資料是哪一年的
        public var recent: Bool = false
    }

    static let recentWords = ["現在", "目前", "最新", "今年", "現任", "最近", "現今", "如今", "當前", "今天"]

    /// 對方問的東西會變嗎？會變的話，搜尋要帶上今年，回答要講資料時間
    public static func withRecency(_ f: Frame, question: String, now: Date = Date()) -> Frame {
        guard recentWords.contains(where: { question.contains($0) }) else { return f }
        let y = Calendar(identifier: .gregorian).component(.year, from: now)
        var g = Frame(subject: f.subject, want: f.want, searches: f.searches.map { "\($0) \(y)" } + f.searches, retry: f.retry,
                      wikiTitles: f.wikiTitles, restated: f.restated + "這題的答案會隨時間改變，要找最新的資料，並說明是哪一年的。")
        g.recent = true
        return g
    }

    /// 最近的年份（「2024年統計」→ 2024）
    public static func latestYear(_ s: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: #"(19|20)\d{2}(?=\s*年)"#) else { return nil }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { m in Range(m.range, in: s).flatMap { Int(s[$0]) } }.max()
    }

    /// 官方、學術、百科的來源比一般網站可信，投票時算兩票
    static func weight(_ host: String) -> Int {
        let h = host.lowercased()
        if Cite.isLowQuality(h) { return 0 }
        return Cite.isPrimary(h) || [".org.tw"].contains(where: { h.contains($0) }) ? 2 : 1
    }

    static func plain(_ q: String) -> String {
        var t = clean(q)
        t = String(t.filter { !"？?！!。，,；;：:「」 ".contains($0) })
        while let last = t.last, "呢嗎啊呀吧啦喔哦耶".contains(last) { t.removeLast() }
        return t
    }

    /// 開頭的客套和語氣詞（「請問」「我想知道」「所以」「欸」「可以告訴我…嗎」「你知道…嗎」）不是問題本身，先拿掉；
    /// 「那」只有在當連接詞時才拿掉（「那些年，我們一起追的女孩」「那個人」是名稱的一部分）
    static let openers = ["你可以告訴我", "可以告訴我", "能不能告訴我", "可不可以告訴我", "幫我查一下", "幫我查查", "幫我查", "幫我上網查", "上網查一下", "上網查",
                          "幫我搜尋", "搜尋一下", "查一下", "請問一下", "請問", "請你", "想問一下", "想請問", "我想問一下", "我想問", "想問", "我想知道", "想知道",
                          "我很好奇", "好奇", "你知道", "你曉得", "你懂", "告訴我", "跟我說說", "跟我說", "說說看", "對了", "話說", "順便問一下", "順便問",
                          "所以", "那麼", "欸", "誒", "唉", "嘿", "喂", "嗯",
                          "誰能", "誰可以", "有沒有人知道", "有沒有人能", "有人知道", "有誰知道", "說說"]

    public static func clean(_ q: String) -> String {
        var t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        var changed = true
        while changed {
            changed = false
            for w in openers where t.hasPrefix(w) && t.count > w.count + 1 {
                t = String(t.dropFirst(w.count)).trimmingCharacters(in: CharacterSet(charactersIn: "，,、 "))
                changed = true
            }
            if t.hasPrefix("那"), t.count >= 4, let n = t.dropFirst().first, !"些個裡邊時天年種樣位麼一兩".contains(n) {
                t = String(t.dropFirst()); changed = true
            }
        }
        // 結尾：問號、語氣詞
        while let last = t.last, "？?！!。～~ 呢嗎啊呀吧啦喔哦耶".contains(last), t.count > 2 { t.removeLast() }
        return t
    }

    static let foodWords = ["飯", "菜", "湯", "麵", "蛋", "肉", "魚", "蝦", "雞", "豬", "牛", "餅", "糕", "粥", "醬", "茶", "咖啡", "甜點", "料理", "便當", "披薩", "沙拉", "餃", "包子", "吐司", "麵包"]

    static func match(_ s: String, _ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).map { i in Range(m.range(at: i), in: s).map { String(s[$0]) } ?? "" }
    }

    static func trimTail(_ s: String, _ ws: [String]) -> String {
        var t = s
        var changed = true
        while changed {
            changed = false
            for w in ws where t.hasSuffix(w) && t.count > w.count { t.removeLast(w.count); changed = true }
        }
        return t
    }

    /// 多遠、多高……對應的屬性和單位
    static let dims: [String: (String, [String])] = [
        "遠": ("距離", ["公里", "km", "英里", "光年", "天文單位", "公尺"]),
        "高": ("高度", ["公尺", "米", "英尺"]),
        "重": ("重量", ["公斤", "噸", "克", "kg"]),
        "深": ("深度", ["公尺", "米"]),
        "長": ("長度", ["公里", "公尺", "米"]),
        "大": ("面積", ["平方公里", "公頃"]),
        "久": ("時間", ["年", "天", "小時", "分鐘"]),
        "快": ("速度", ["公里", "公尺", "米", "km/s", "km/h", "m/s", "英里"]),
    ]

    static func unitsFor(_ attr: String) -> [String] {
        if attr.hasSuffix("人口") { return ["人", "萬", "億"] }
        if attr.hasSuffix("錢") || attr.hasSuffix("價格") { return ["元", "美元", "台幣", "萬"] }
        if attr.hasSuffix("歲") || attr.hasSuffix("年齡") { return ["歲"] }
        if attr.hasSuffix("面積") { return ["平方公里", "公頃"] }
        return ["個", "座", "名", "位", "種", "條", "人", "萬", "億"]
    }

    static func uniq(_ xs: [String]) -> [String] {
        var seen = Set<String>()
        return xs.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

// MARK: - 1. 理解問題

extension Understanding {
    public enum Missing { case personal, generic }
    static let personalAttrs = ["名字", "叫什麼", "幾歲", "年紀", "年齡", "生日", "住哪", "住在", "來自", "興趣", "喜歡", "性別", "星座"]
    static let askBits = ["名字", "叫", "什麼", "幾歲", "年紀", "年齡", "生日", "住", "在", "哪裡", "哪", "是", "多高", "多重", "多大", "多少錢",
                          "多少", "價格", "顏色", "多遠", "多久", "有", "誰", "電話", "地址", "的", "意思", "了", "來自", "興趣", "喜歡",
                          "性別", "星座", "幾", "個", "怎麼樣", "如何", "好不好"]

    /// 問題有沒有主語：「名字叫什麼」「多少錢」「是什麼顏色」沒說是誰、是什麼東西
    public static func missingSubject(_ question: String) -> Missing? {
        var t = plain(question)
        for w in ["那麼", "所以", "那", "請問"] where t.hasPrefix(w) { t.removeFirst(w.count); break }
        guard !t.isEmpty, t.count <= 8 else { return nil }
        var rest = t
        for w in askBits.sorted(by: { $0.count > $1.count }) { rest = rest.replacingOccurrences(of: w, with: "") }
        guard rest.isEmpty else { return nil }
        return personalAttrs.contains { t.contains($0) } ? .personal : .generic
    }
}

extension Understanding {
    /// 錯字修正：主題在搜尋結果的標題裡一次都沒出現，卻有兩個以上的標題出現「長度一樣、只差一兩個字」的詞，
    /// 那個詞多半才是正確的名稱（「少年懷特的煩惱」→「少年維特的煩惱」）
    public static func spellFix(_ subject: String, titles: [String]) -> String? {
        let s = Array(subject)
        guard s.count >= 4, s.count <= 20, s.allSatisfy({ WebAgent.isCJK($0) || $0.isLetter || $0.isNumber }) else { return nil }
        if titles.contains(where: { $0.contains(subject) }) { return nil }
        let allow = s.count >= 8 ? 2 : 1
        var count: [String: Int] = [:]
        for t in titles {
            let c = Array(t)
            guard c.count >= s.count else { continue }
            var seen = Set<String>()
            for i in 0...(c.count - s.count) {
                let w = c[i..<(i + s.count)]
                var diff = 0
                for (a, b) in zip(w, s) where a != b { diff += 1; if diff > allow { break } }
                // 頭尾要一樣（只是中間打錯字），整段要是文字
                guard diff >= 1, diff <= allow, w.first == s.first, w.last == s.last, w.allSatisfy({ WebAgent.isCJK($0) || $0.isLetter }) else { continue }
                let k = String(w)
                if seen.insert(k).inserted { count[k, default: 0] += 1 }
            }
        }
        guard let best = count.max(by: { $0.value < $1.value }), best.value >= 2 else { return nil }
        return best.key
    }

    public static func frame(_ question: String) -> Frame {
        // 「現在」「目前」只說明要最新的資料，不是主題的一部分
        var t = plain(question)
        for w in recentWords where t.count > w.count + 2 { t = t.replacingOccurrences(of: w, with: "") }
        // 作品：書名號拿掉，「這本書」「這部電影」只是在說明是什麼，不是名稱的一部分
        t = t.replacingOccurrences(of: #"[《》〈〉「」『』]"#, with: "", options: .regularExpression)
        let workKinds = "書|小說|電影|影片|劇|影集|動畫|漫畫|歌|曲|專輯|作品|遊戲|詩|散文|繪本|紀錄片"
        let stripped = t.replacingOccurrences(of: "(這|那)(本|部|首|篇|齣|套)(\(workKinds))?", with: "", options: .regularExpression)
        if stripped.count >= 4 { t = stripped }
        func F(_ subject: String, _ want: Want, _ s: [String], _ r: [String], _ wiki: [String], _ restated: String) -> Frame {
            Frame(subject: subject, want: want, searches: uniq(s), retry: uniq(r), wikiTitles: uniq(wiki).filter { $0.count >= 2 }, restated: restated)
        }

        // 「教我X」＝「怎麼X」
        if let m = match(t, #"^教我(?:怎麼|如何)?(.{2,})$"#) { return frame("怎麼" + m[1]) }
        // 時間：「X是哪一年」「X是幾年發生的」「X發生在哪一年」「X什麼時候開始」——要的是時間，不是數量也不是地點
        if let m = match(t, #"^(.{2,}?)(?:是|在|於|發生在|發生於|始於)?(?:西元)?(?:哪一年|哪年|幾年|什麼時候|何時|哪個年代)(?:發生|開始|結束|成立|建立|推出|出生|過世|上映|出版)?的?$"#),
           !m[1].hasSuffix("要") && !m[1].hasSuffix("需要") && !m[1].hasSuffix("讀") && !m[1].hasSuffix("活") {
            let subject = trimTail(m[1], ["是", "在", "的", "發生"])
            return F(subject, .time, ["\(subject) 年份", "\(subject) 什麼時候"], ["\(subject) 歷史"], [subject],
                     "你想知道「\(subject)」是什麼時候 → 要一個年份或日期。")
        }
        // 作品的內容、劇情：「雪國的內容是什麼」「海角七號的劇情是什麼」——要的是在講什麼，不是名詞解釋
        if let m = match(t, #"^(.{2,}?)的?(內容|劇情|大綱|主旨|結局|故事|情節)(?:是什麼|是怎樣|在講什麼|講什麼|介紹)?$"#) {
            let subject = m[1]
            return F(subject, .open, ["\(subject) 內容", "\(subject) 劇情"], ["\(subject) 簡介"], [subject],
                     "你想知道「\(subject)」的\(m[2]) → 要講出它在講什麼，不是名詞解釋。")
        }
        // 作者：「誰寫了X」「X是誰寫的」「X的作者是誰」
        if let m = match(t, #"^誰(寫|拍|唱|畫|導演|作曲|設計)了?(.{2,})$"#) {
            return F(m[2], .person, ["\(m[2]) 作者", "誰\(m[1])了\(m[2])"], ["\(m[2]) 簡介"], [m[2]],
                     "你想知道「\(m[2])」是誰\(m[1])的 → 要一個名字。")
        }
        if let m = match(t, #"^(.{2,}?)的(作者|導演|作曲者|作曲家|主唱|編劇|設計師|發明人|發明者|創辦人)是誰$"#) {
            return F(m[1], .person, ["\(m[1]) \(m[2])", t], ["\(m[1]) 簡介"], [m[1]],
                     "你想知道「\(m[1])」的\(m[2])是誰 → 要一個名字。")
        }
        if let m = match(t, #"^發明(.{2,}?)的人是誰$"#) { return frame("誰發明了" + m[1]) }
        // 好處、壞處：「冥想有什麼好處」「游泳有哪些好處」——要幾個重點，不是名單
        // 「作用」「影響」「功效」前面一定要有「有什麼／的」（「光合作用是什麼」的「作用」是名稱的一部分）
        if let m = match(t, #"^(.{2,}?)(?:(?:有什麼|有哪些|的)?(好處|壞處|優點|缺點|優缺點)|(?:有什麼|有哪些|的)(功效|作用|影響))(?:是什麼|有哪些|有什麼)?$"#) {
            let what = m[2].isEmpty ? m[3] : m[2]
            let subject = m[1]
            return F(subject, .open, ["\(subject) \(what)", "\(subject)的\(what)"], ["\(subject) \(what) 研究"], [],
                     "你想知道「\(subject)」的\(what) → 要幾個重點，並說明根據。")
        }
        // 原因：「X是為什麼」「X的原因是什麼」
        if let m = match(t, #"^(.{2,}?)(?:是為什麼|是為何|的原因是什麼|的原因|是什麼原因|是什麼造成的|的原理是什麼|的原理)$"#) {
            return F(m[1], .reason(pred: m[1]), ["\(m[1]) 原因", "為什麼\(m[1])"], ["\(m[1]) 原理"], [],
                     "你想知道「\(m[1])」的原因 → 要講出因果，不是只描述現象。")
        }
        // 定義：「解釋一下X」「X指的是什麼」「X是什麼意思」
        if let m = match(t, #"^(?:解釋一下|解釋|說明一下|介紹一下|定義)(.{2,})$"#) { return frame(m[1] + "是什麼") }
        if let m = match(t, #"^(.{2,}?)(?:指的是什麼|是指什麼|的意思是什麼|是什麼意思|的定義是什麼|的定義|代表什麼)$"#) { return frame(m[1] + "是什麼") }
        // 比較：「A還是B比較好」
        if let m = match(t, #"^(.+?)還是(.+?)(?:比較好|比較|好|呢)$"#) {
            return frame(m[1] + "和" + m[2] + "哪個好")
        }
        // 名單：「義大利的城市有哪些」＝「義大利有哪些城市」
        if let m = match(t, #"^(.{2,}?)的(.{1,6})有哪些$"#), !["好處", "壞處", "優點", "缺點", "方法", "技巧", "注意事項"].contains(m[2]) {
            return frame(m[1] + "有哪些" + m[2])
        }

        // 評價：「孤獨的美食家好看嗎」——要大家的評價、優缺點，最後給結論
        if let m = match(t, #"^(.{2,20}?)(?:好不好看|好看嗎|好看|好不好聽|好聽嗎|好聽|好不好玩|好玩嗎|值得看嗎|值得讀嗎|值得玩嗎|值不值得看|值不值得)$"#) {
            return F(m[1], .open, ["\(m[1]) 評價", "\(m[1]) 心得 推薦"], ["\(m[1]) 評論"], [m[1]],
                     "你想知道「\(m[1])」好不好 → 要大家的評價、優點和缺點，再給一個結論。")
        }

        // 比較：A 和 B 哪個好
        if let m = match(t, #"^(.+?)(?:和|跟|與|還是)(.+?)(?:哪個|哪一個)(?:比較|更)?.+"#)
            ?? match(t, #"^(.+?)(?:和|跟|與)(.+?)(?:的)?(?:差別|區別|不同|差異)"#) {
            let a = m[1], b = m[2]
            return F("\(a)、\(b)", .compare(a, b), ["\(a) \(b) 比較", "\(a) \(b) 優缺點"], ["\(a) vs \(b)"], [],
                     "你想比較「\(a)」和「\(b)」→ 要並排比較優缺點、各適合誰，不是只介紹其中一個。")
        }

        // 誰創立、誰發明……的：「蘋果公司是誰創立的」
        if let m = match(t, #"^(.+?)是誰(創立|創辦|發明|發現|寫|畫|設計|建立|提出|導演|唱)的?$"#) {
            return F(m[1], .person, ["\(m[1]) \(m[2])人", "\(m[1]) 創辦人 歷史"], ["\(m[1]) 歷史"], [m[1]],
                     "你想知道「\(m[1])」是誰\(m[2])的 → 要一個名字，有爭議的話要說明。")
        }
        // 要一個名稱：「世界上最高的山是哪座」「美國總統是誰」
        if let m = match(t, #"^(.+?)是(?:哪座|哪一座|哪個|哪一個|哪位|哪一位|誰|哪國|哪家|哪一家)$"#) {
            let who = t.hasSuffix("誰") || t.hasSuffix("位")
            let compact = m[1].replacingOccurrences(of: "上", with: "").replacingOccurrences(of: "的", with: "")
            return F(m[1], who ? .person : .open, [m[1], t], [compact, compact.hasSuffix("山") ? String(compact.dropLast()) + "峰" : compact + " 是"], [m[1]],
                     "你想知道「\(m[1])」是\(who ? "誰" : "哪一個") → 要一個明確的名稱，再說明根據。")
        }

        // 要建議、技巧：「面試要注意什麼」「減肥有什麼方法」「讀書的技巧」——要可以照著做的重點，不是名單、不是名詞解釋
        if let m = match(t, #"^(.+?)(?:要|該|需要|應該)?(?:有什麼要注意的|有什麼需要注意的|有哪些要注意的|有哪些需要注意的|需要注意哪些|需要注意什麼|注意什麼|注意哪些|注意些什麼|有什麼技巧|有什麼方法|有什麼辦法|有什麼建議|有什麼秘訣|有什麼訣竅|有哪些方法|有哪些技巧|的方法|的技巧|的秘訣|的訣竅|的建議|注意事項)$"#) {
            let subject = trimTail(m[1], ["要", "該", "的"])
            return F(subject, .steps(target: subject), ["\(subject) 注意事項 技巧", "\(subject) 建議", t], ["\(subject) 該怎麼做"], [],
                     "你想知道「\(subject)」有什麼要注意、怎麼做比較好 → 要可以照著做的重點。")
        }

        // 「有沒有什麼方法可以戒菸」「有什麼辦法能早起」：要的是做法，不是名單
        if let m = match(t, #"^(?:有沒有什麼|有沒有|有什麼|有哪些)(?:好的)?(?:方法|辦法|技巧|訣竅|秘訣)(?:可以|能|能夠|讓我)(.{2,})$"#) {
            return frame("怎麼" + m[1])
        }

        // 名單的其他說法：「歐洲有什麼國家」「有哪幾個國家」「包括什麼國家」「列出歐洲的國家」→ 都當成「歐洲有哪些國家」
        let notList = ["用", "意思", "關係", "不同", "差別", "問題", "好處", "壞處", "影響", "特色", "功能", "區別", "用處", "作用", "意義",
                       "方法", "技巧", "秘訣", "訣竅", "建議", "辦法", "注意事項"]
        if let m = match(t, #"^(.+?)(?:有什麼|有啥|有哪幾個|有哪幾種|包括什麼|包含什麼|包括哪幾個)(.{1,6})$"#), !notList.contains(m[2]) {
            var noun = m[2]
            // 「台北有什麼好玩的」「日本有什麼好吃的」：要的是推薦的地方、食物
            if noun.hasPrefix("好玩") { noun = "景點" } else if noun.hasPrefix("好吃") { noun = "美食" }
            return frame(m[1] + "有哪些" + noun)
        }
        if let m = match(t, #"^列出(.+?)(?:的|所有的|所有|全部的|全部)(.{1,6})$"#) {
            return frame(m[1] + "有哪些" + m[2])
        }

        // 名單：X 有哪些 Y
        if let m = match(t, #"^(.*?)哪些(.+)$"#) {
            var pre = m[1], noun = trimTail(m[2], ["的", "列表", "名單", "一覽"])
            if pre.isEmpty, let mm = match(noun, #"^(.+?)(?:在|屬於|位於)(.+)$"#) { noun = mm[1]; pre = mm[2] }
            pre = trimTail(pre, ["都是", "都有", "是", "有", "都", "的", "了", "寫", "畫", "拍", "唱", "做", "出版", "發明", "演"])
            if pre.hasSuffix(noun) && pre.count > noun.count { pre.removeLast(noun.count) }
            pre = trimTail(pre, ["的"])
            let full = pre + noun
            let admin = ["縣", "省", "州", "市", "區"].contains { noun.hasSuffix($0) }
            return F(pre.isEmpty ? noun : pre, .list(noun: noun), ["\(full)列表", "\(pre)有哪些\(noun)"], ["\(pre) \(noun) 名單", "\(full) 一覽"],
                     ["\(full)列表", full] + (admin ? ["\(pre)行政區劃"] : []),
                     "你想知道「\(pre)」有哪些「\(noun)」→ 要一份把每一個都列出來的名單，不是介紹文章。")
        }

        // 多遠、多高……
        if let m = match(t, #"^(.+?)(?:有|大概|大約)?多(遠|高|重|深|長|大|久|快)"#), let d = dims[m[2]] {
            let subject = trimTail(m[1], ["有", "大概", "大約", "的"])
            var spaced = subject
            for w in ["到", "離", "和", "跟"] { spaced = spaced.replacingOccurrences(of: w, with: " ") }
            return F(subject, .number(attr: d.0, units: d.1), ["\(spaced) \(d.0)", t], ["\(spaced) 平均\(d.0) \(d.1[0])"], [],
                     "你想知道「\(subject)」的\(d.0) → 要一個單位正確（\(d.1.prefix(3).joined(separator: "、"))）的數字。")
        }

        // 數量：X 有多少（個）Y
        if let m = match(t, #"^(.+?)(?:一共|總共)?有?(?:多少|幾)(?:個|座|名|位|種|條)?(.*)$"#) {
            let subject = trimTail(m[1], ["一共", "總共", "有", "是", "的"])
            var noun = m[2]
            // 「幾度」「幾天」「幾塊骨頭」「幾歲過世」：這是量詞，單位就是它本身
            let measures = ["度", "天", "年", "歲", "小時", "分鐘", "秒", "公斤", "公尺", "公里", "倍", "%", "次", "代", "層", "樓"]
            if let u = measures.first(where: { noun.hasPrefix($0) }) {
                return F(subject, .number(attr: noun, units: [u]), [t, "\(subject) \(noun)"], ["\(subject)\(noun) 多少"], [subject],
                         "你想知道「\(subject)」是幾\(noun) → 要一個以「\(u)」為單位的數字。")
            }
            if let c = noun.first, "塊隻顆本條張座間棵根台輛艘架位名家所種".contains(c), noun.count >= 2 {
                let thing = String(noun.dropFirst())
                noun = thing
                return F(subject, .number(attr: thing, units: ["\(c)\(thing)", "\(c)"]), [t, "\(subject) \(thing) 數量"], ["\(subject)有多少\(c)\(thing)"], [subject],
                         "你想知道「\(subject)」有幾\(c)\(thing) → 要一個數字；常見說法不同時要說明原因。")
            }
            if noun.isEmpty || noun == "錢" || noun == "歲" {
                let attr = subject + noun
                return F(subject, .number(attr: noun.isEmpty ? "數量" : noun, units: unitsFor(attr)), [t, "\(subject) \(noun)"], ["\(subject) \(noun) 最新"], [],
                         "你想知道「\(t)」→ 要一個有單位的數字，並說明是哪個來源、哪一年的數字。")
            }
            return F(subject, .number(attr: noun, units: ["個\(noun)", "座\(noun)", "種\(noun)", "名\(noun)", noun]), [t, "\(subject) \(noun) 數量"],
                     ["\(subject)\(noun)列表", "\(subject)行政區劃"], ["\(subject)\(noun)列表", subject],
                     "你想知道「\(subject)」有幾個「\(noun)」→ 先給數字；各來源算法不同時要說明差在哪。")
        }

        // 原因：X 為什麼 Y
        if let m = match(t, #"^(.*?)(?:為什麼|為何|怎麼會)(?:會|要|是|都)?(.+)$"#) {
            let pre = m[1], pred = m[2]
            return F(pre.isEmpty ? pred : pre, .reason(pred: pred), ["\(pre)\(pred) 原因", "為什麼\(pre)\(pred)"], ["\(pre) \(pred) 原理"],
                     pre.isEmpty ? [] : [pre],
                     "你想知道「\(pre)\(pred)」的原因 → 要講出因果（因為什麼，所以\(pred)），不是只描述現象。")
        }

        // 做法：怎麼 V X／X 怎麼 V（「怎麼辦」「怎麼樣」不算）
        if !t.hasSuffix("怎麼辦") && !t.hasSuffix("怎麼樣") {
            var target = ""
            var food = false
            if let m = match(t, #"^(?:要|該)?(?:怎麼|如何|怎樣)(?:才能|可以)?(.+)$"#) {
                var a = m[1]
                // 煮、炒、煎……是做菜：主題用菜名查「做法」「食譜」；「做簡報」的「做」不是做菜，要留著
                if let v = a.first, "煮烤炒蒸泡滷煎燉".contains(v) || v == "做" && a.count >= 3 && foodWords.contains(where: { a.contains($0) }) {
                    food = true; a.removeFirst()
                }
                target = a
            } else if let m = match(t, #"^(.+?)(?:要|該)?(?:怎麼|如何)(.+)$"#) {
                food = m[2].first.map { "煮做烤炒蒸泡滷煎燉".contains($0) } ?? false
                // 「跟朋友吵架怎麼和好」：要的是「和好」，不是「吵架」；「做」「處理」這類空泛的動詞才省略
                let generic = ["做", "辦", "處理", "解決", "弄", "應對", "面對", "用", "使用"]
                target = food || generic.contains(m[2]) ? m[1] : m[1] + m[2]
            }
            // 「我想存錢該怎麼做」：主題是「存錢」
            for h in ["我想要", "我想", "我要", "我該", "想要"] where target.hasPrefix(h) && target.count > h.count + 1 { target.removeFirst(h.count); break }
            if !target.isEmpty {
                let s = food ? ["\(target) 做法", "\(target) 食譜 步驟"] : ["如何\(target)", "\(target) 方法 步驟"]
                return F(target, .steps(target: target), s, ["\(target) 教學"], [],
                         "你想知道怎麼\(food ? "做" : "處理")「\(target)」→ 要一步一步、照順序的做法。")
            }
        }

        // 人：誰發明了 X／X 是誰
        if let m = match(t, #"^誰(發明|發現|創立|寫|畫|設計|提出)了?(.+)$"#) {
            return F(m[2], .person, ["\(m[2]) \(m[1])者", "誰\(m[1])了\(m[2])"], ["\(m[2]) 歷史"], [m[2]],
                     "你想知道「\(m[2])」是誰\(m[1])的 → 要一個名字，有爭議的話要說明。")
        }
        if let m = match(t, #"^(.+?)的?首都(?:是|在)?(?:哪裡|哪|什麼)"#) {
            return F(m[1], .place, ["\(m[1]) 首都"], [], [m[1]], "你想知道「\(m[1])」的首都 → 要一個地名。")
        }
        if let m = match(t, #"^(.+?)(?:在哪裡|在哪|位於哪裡)"#) {
            return F(m[1], .place, ["\(m[1]) 位置", "\(m[1]) 位於"], [], [m[1]], "你想知道「\(m[1])」在哪裡 → 要一個地點。")
        }
        if let m = match(t, #"^(.+?)(?:是)?(?:什麼時候|哪一年|何時)"#) {
            return F(m[1], .time, ["\(m[1]) 時間", "\(m[1]) 年份"], [], [m[1]], "你想知道「\(m[1])」的時間 → 要一個日期或年份。")
        }
        // 「感冒了怎麼辦」「老闆不給我加薪怎麼辦」：要可以馬上做的建議
        if let m = match(t, #"^(.{2,16}?)(?:了)?(?:該|要)?怎麼辦$"#) {
            return F(m[1], .steps(target: m[1]), ["\(m[1]) 怎麼辦", "\(m[1]) 處理 建議", t], ["\(m[1]) 該怎麼做"], [],
                     "你遇到「\(m[1])」想知道怎麼辦 → 要可以馬上做的建議，不是名詞解釋。")
        }
        // 「三島由紀夫的書都講了什麼」：先找代表作，再說每一部在講什麼
        if let m = match(t, #"^(.{2,12}?)的(書|作品|小說|電影|歌|詩|劇)(?:都|主要|大多)?(?:是)?(?:在)?(?:講|說|寫)(?:了|些)?什麼"#) {
            let kind = m[2] == "書" ? "作品" : m[2]
            return F(m[1], .open, ["\(m[1]) \(kind)", "\(m[1]) \(kind) 主題", t], ["\(m[1]) 代表作 內容"], [m[1]],
                     "你想知道「\(m[1])」的\(m[2])在講什麼 → 先找出代表作，再說每一部在講什麼。")
        }
        // 「金閣寺在講什麼」：要內容大意（劇情、主題），不是基本資料
        if let m = match(t, #"^(.{1,12}?)(?:是)?(?:在)?(?:講|說)(?:了|些)?什麼"#) {
            return F(m[1], .open, ["\(m[1]) 內容", "\(m[1]) 劇情", t], ["\(m[1]) 主題 介紹"], [m[1]],
                     "你想知道「\(m[1])」在講什麼 → 要內容大意（講了什麼故事、想表達什麼），不是基本資料。")
        }
        if let m = match(t, #"^(?:什麼是)(.+)$"#) ?? match(t, #"^(.+?)(?:是什麼|是啥|什麼意思)"#) {
            return F(m[1], .definition, ["\(m[1]) 是什麼"], ["\(m[1]) 意思"], [m[1]], "你想知道「\(m[1])」是什麼 → 用一兩句話說清楚。")
        }
        // 沒有對上固定的說法：像人一樣，先找「在問什麼」的關鍵字，再把問句的字拿掉，剩下的就是主題
        if let g = general(t) { return g }
        return F(t, .open, [t], [], [], "你問的是「\(t)」。")
    }

    /// 通用的理解：關鍵字可以出現在句子任何地方（「誰是追風箏的孩子的作者」「有沒有什麼方法可以準備多益」「量子力學的意思」）
    /// 順序有意義：做法 → 人 → 時間（「在哪一年」先於「在哪」）→ 地點 → 原因 → 作品內容 → 定義 → 數量
    static let cueGroups: [(String, [String])] = [
        ("steps", ["有沒有什麼方法可以", "有什麼方法可以", "有沒有什麼辦法", "有沒有辦法", "要從哪裡開始", "從哪裡開始", "怎樣才能", "怎麼樣才能", "如何才能",
                   "的技巧有哪些", "的方法有哪些", "的技巧", "的方法", "的秘訣", "的訣竅", "的步驟", "該如何處理", "要如何處理", "如何處理", "怎麼處理",
                   "的話要怎麼辦", "的話怎麼辦", "要怎麼辦", "該怎麼辦", "怎麼辦", "該怎麼做", "要怎麼做", "怎麼做", "該如何", "要如何", "的建議"]),
        ("person", ["誰是", "是誰提出的", "是誰發現的", "是誰發明的", "是誰創造的", "是誰寫的", "是誰拍的", "是誰唱的", "是誰提出", "是誰發現", "是誰發明",
                    "是誰", "的作者", "的發明者", "的發明人", "的創始人", "的創辦人", "的導演", "的主唱", "誰提出了", "誰提出", "誰發現了", "誰發現", "誰發明了",
                    "誰發明", "誰寫了", "誰寫", "是誰的"]),
        ("time", ["是在哪一年發生的", "是在哪一年", "在哪一年", "是哪一年", "哪一年", "哪年", "發生於何時", "是何時", "何時", "是什麼時候", "什麼時候", "哪個年代", "幾年發生"]),
        ("place", ["是在哪個國家", "在哪個國家", "在哪個城市", "是哪國的", "是哪個國家的", "哪個國家", "哪個城市", "位於何處", "在什麼地方", "位於哪裡", "在哪裡", "在哪"]),
        ("reason", ["的原因是什麼", "的原因", "原因是什麼", "是為什麼", "為什麼", "為何", "怎麼會", "為啥", "的原理"]),
        ("work", ["的故事大綱", "故事大綱", "的大綱", "在說什麼", "在講什麼", "講了什麼", "說了什麼", "的劇情", "的內容", "的故事"]),
        ("definition", ["到底是什麼", "究竟是什麼", "是什麼意思", "的意思是什麼", "的意思是", "的意思", "的定義", "是指什麼", "指的是什麼", "指的是", "是什麼",
                        "什麼是", "解釋一下", "解釋", "是啥"]),
        ("number", ["大概多高", "大約多高", "高度多少", "有多高", "多高", "有多重", "多重", "有多遠", "多遠", "有多長", "多長", "多大", "多久", "多少"]),
    ]
    static let leftover = ["有沒有什麼", "有沒有", "可以", "想要", "想", "要", "能", "一下", "的話", "呢", "嗎", "耶", "啊"]

    static func general(_ t: String) -> Frame? {
        for (want, cues) in cueGroups {
            guard let cue = cues.first(where: { t.contains($0) }) else { continue }
            var s = t.replacingOccurrences(of: cue, with: " ")
            for w in leftover where s.hasPrefix(w) || s.hasSuffix(w) {
                if s.hasPrefix(w) { s = String(s.dropFirst(w.count)) }
                if s.hasSuffix(w) { s = String(s.dropLast(w.count)) }
            }
            s = s.trimmingCharacters(in: CharacterSet(charactersIn: " 的是在了，,"))
                .replacingOccurrences(of: " ", with: "")
            guard s.count >= 2 else { continue }
            func F(_ w: Want, _ searches: [String], _ restated: String) -> Frame {
                Frame(subject: s, want: w, searches: uniq(searches), retry: [s], wikiTitles: [s], restated: restated)
            }
            switch want {
            case "steps": return F(.steps(target: s), ["如何\(s)", "\(s) 方法 步驟"], "你想知道怎麼「\(s)」→ 要可以照著做的方法。")
            case "person": return F(.person, ["\(s) \(cue.contains("作者") ? "作者" : "是誰")", t], "你想知道跟「\(s)」有關的是誰 → 要一個名字。")
            case "time": return F(.time, ["\(s) 年份", "\(s) 什麼時候"], "你想知道「\(s)」是什麼時候 → 要一個年份或日期。")
            case "place": return F(.place, ["\(s) 位置", "\(s) 在哪裡"], "你想知道「\(s)」在哪裡 → 要一個地點。")
            case "reason": return F(.reason(pred: s), ["\(s) 原因", "為什麼\(s)"], "你想知道「\(s)」的原因 → 要講出因果。")
            case "work": return F(.open, ["\(s) 內容", "\(s) 劇情"], "你想知道「\(s)」在講什麼 → 要內容大意。")
            case "definition": return F(.definition, ["\(s) 是什麼"], "你想知道「\(s)」是什麼 → 用一兩句話說清楚。")
            default: return F(.number(attr: "數量", units: []), [t, "\(s) 數字"], "你想知道「\(s)」→ 要一個有單位的數字。")
            }
        }
        return nil
    }
}

// MARK: - 3. 取證：只挑長得像答案的內容

extension Understanding {
    public struct Evidence {
        public let text: String
        public let host: String
    }

    /// 數字＋單位（「38.4萬公里」「384,400 公里」），換算成同一個數值方便比對
    static func numbers(_ s: String, units: [String], rates: Bool = false) -> [(value: Double, shown: String)] {
        let alt = units.sorted { $0.count > $1.count }.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        // 「299,792,458」「299 792 458」（千位用逗號或空格）、「1.496」都要認得；「1億5000萬km」前面的「1億」也要算進去
        guard !alt.isEmpty, let re = try? NSRegularExpression(pattern: #"(?:(\d+(?:\.\d+)?)\s*億\s*)?(\d{1,3}(?:[, \x{2009}\x{202F}\x{00A0}]\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)\s*(萬|億)?\s*(?:"# + alt + ")") else { return [] }
        var out: [(Double, String)] = []
        for m in re.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            guard let r = Range(m.range, in: s), let nr = Range(m.range(at: 2), in: s),
                  var v = Double(String(s[nr].filter { $0.isNumber || $0 == "." })) else { continue }
            // 「每平方公里 113,703 人」「人口密度」是比率，不是問的那個數量
            let before = String(s[s.index(r.lowerBound, offsetBy: -min(8, s.distance(from: s.startIndex, to: r.lowerBound)))..<r.lowerBound])
            let after = String(s[r.upperBound..<s.index(r.upperBound, offsetBy: min(3, s.distance(from: r.upperBound, to: s.endIndex)))])
            if !rates && (before.contains("每") || before.contains("密度") || after.hasPrefix("/") || after.hasPrefix("每") || after.hasPrefix("／")) { continue }
            if let mr = Range(m.range(at: 3), in: s) { v *= s[mr] == "萬" ? 1e4 : 1e8 }
            if let yr = Range(m.range(at: 1), in: s), let yi = Double(s[yr]) { v += yi * 1e8 }
            out.append((v, String(s[r])))
        }
        return out
    }

    /// 不是地名的詞：「首都圈」這類、動詞和虛詞（「一般也認為東京是…」的「認為」）、問句本身的「哪裡」
    static let notPlace = ["首都", "圈", "都會", "城市", "地區", "中心", "認為", "表示", "指出", "以為", "現在", "目前", "已經", "仍然",
                           "一直", "當時", "曾經", "因此", "所以", "其中", "之一", "這裡", "那裡", "一般", "通常", "哪裡", "哪個", "什麼"]
    /// 地名不會用這些字開頭（「為東京」「也東京」「他說東京」）；「都柏林」的「都」不在這裡
    static let notPlaceHead: Set<Character> = ["也", "還", "就", "又", "才", "再", "更", "是", "為", "的", "前", "在", "說", "和", "與", "及",
                                               "而", "則", "即", "以", "將", "把", "被", "讓", "給", "對", "從", "向", "當", "但", "並", "且",
                                               "已", "曾", "仍", "他", "她", "它", "這", "那", "其", "此", "認", "稱"]

    /// 問首都：每一句「法國首都巴黎舉辦…」「一般也認為東京是日本的首都」裡的地名投一票
    /// 地名在「首都」後面時，每個前綴都投一票（巴黎、巴黎舉…），票一樣多時取最短的；
    /// 地名在前面時，只投最長、又不是虛詞開頭的那個結尾（「認為東京」→ 東京；「東京都」不會變成「京都」）
    static func capitalVotes(_ texts: [String], subject sj: String) -> [String: Int] {
        var votes: [String: Int] = [:]
        let esc = NSRegularExpression.escapedPattern(for: sj)
        func ok(_ k: String) -> Bool { !notPlace.contains { k.contains($0) } && !notPlaceHead.contains(k.first ?? "的") }
        guard let after = try? NSRegularExpression(pattern: esc + "的?首都(?:是|為|在)?([\\p{Han}]{2,4})"),
              let before = try? NSRegularExpression(pattern: "([\\p{Han}]{2,4})(?:是|為)" + esc + "的?首都") else { return [:] }
        for t in texts {
            let all = NSRange(t.startIndex..., in: t)
            for m in after.matches(in: t, range: all) {
                guard let r = Range(m.range(at: 1), in: t) else { continue }
                let cand = String(t[r])
                for n in 2...cand.count where ok(String(cand.prefix(n))) { votes[String(cand.prefix(n)), default: 0] += 1 }
            }
            for m in before.matches(in: t, range: all) {
                guard let r = Range(m.range(at: 1), in: t) else { continue }
                let cand = String(t[r])
                if let k = (2...cand.count).reversed().map({ String(cand.suffix($0)) }).first(where: ok) { votes[k, default: 0] += 1 }
            }
        }
        return votes
    }

    /// 除錯：上一次數字投票的各組（數值×被提到幾次@幾個網站：第一句）
    nonisolated(unsafe) public static var lastNumberDebug = ""

    /// 各來源說的數字，差不到 3% 的算同一個說法；一個網站一票
    public static func voteNumber(_ ev: [Evidence], units: [String], subject: String, rates: Bool = false)
        -> (shown: String, sentence: Evidence, votes: Int, others: [String])? {
        var groups: [(value: Double, shown: String, sentence: Evidence, hosts: Set<String>)] = []
        var mentions: [Int] = []
        for e in ev {
            // 「比實際數值低了26%」這種歷史上的估計不是答案
            if ["比實際", "當時估計", "古代", "曾估計", "誤差"].contains(where: { e.text.contains($0) }) { continue }
            // 「19世紀…得出 315000 km/s」：講歷史上怎麼測出來的，不是現在的答案
            if e.text.contains("世紀") && ["得出", "計算出", "測得", "估算", "測量法"].contains(where: { e.text.contains($0) }) { continue }
            // 主題本身的數字（「台北101」的 101）不算
            let body = e.text.replacingOccurrences(of: subject, with: "")
            // 「1公尺」這種定義用的數字通常不是答案
            for n in numbers(body, units: units, rates: rates) where n.value > 1 {
                // 「玉山東峰（3,869公尺）」：講的是旁邊另一座峰（東峰、北峰），不是問的那座
                if let r = body.range(of: n.shown) {
                    let pre = body[body.index(r.lowerBound, offsetBy: -min(6, body.distance(from: body.startIndex, to: r.lowerBound)))..<r.lowerBound]
                    if pre.range(of: "[東西南北前後小副]峰", options: .regularExpression) != nil { continue }
                    // 「瑞士8個國家共同經營」：數字前面緊接著另一個地名，是在數別的東西（問的主題已經先拿掉了）
                    if n.shown.contains("個"), let c = pre.last, isCJK(c), !countLead.contains(c) { continue }
                    // 「37個國家立法禁止…」：是在數做某件事的國家，不是總共有幾個；「50個以上」也不是確切的數
                    let post = body[r.upperBound...].prefix(4)
                    if ["立法", "禁止", "已經", "已", "採用", "加入", "支持", "承認", "參加", "使用", "實施", "通過", "簽署", "以上", "以下", "曾", "將", "同意", "反對", "允許"]
                        .contains(where: { post.hasPrefix($0) }) { continue }
                }
                if let i = groups.firstIndex(where: { abs($0.value - n.value) / max($0.value, n.value) < 0.015 }) {
                    groups[i].hosts.insert(e.host)
                    mentions[i] += 1
                } else {
                    groups.append((n.value, n.shown, e, [e.host]))
                    mentions.append(1)
                }
            }
        }
        func w(_ g: (value: Double, shown: String, sentence: Evidence, hosts: Set<String>)) -> Int { g.hosts.reduce(0) { $0 + weight($1) } }
        lastNumberDebug = groups.indices.sorted { mentions[$0] > mentions[$1] }.prefix(6)
            .map { "\(groups[$0].shown)×\(mentions[$0])@\(groups[$0].hosts.count):\(groups[$0].sentence.text.prefix(40))" }.joined(separator: " | ")
        // 先看幾個網站（官方算兩票），一樣的話看被提到幾次（正確的數值通常一再出現，歷史上的估計只提一次）
        guard let bi = groups.indices.max(by: { (w(groups[$0]), mentions[$0]) < (w(groups[$1]), mentions[$1]) }) else { return nil }
        let best = groups[bi]
        // 其他說法：同一種單位、而且有一定可信度的才提（換算成英尺、別的數量不算不同說法）
        func unit(_ x: String) -> String { String(x.drop { $0.isNumber || $0 == "," || $0 == "." || $0 == " " }) }
        let others = groups.filter { $0.shown != best.shown && unit($0.shown) == unit(best.shown) && $0.hosts.count >= 2 }.prefix(3).map(\.shown)
        return (best.shown, best.sentence, best.hosts.count, Array(others))
    }

    /// 「共有 44 個」「由 10 個」：數量前面常見的字；不是這些字（是另一個名字）就不是在數問的東西
    static let countLead: Set<Character> = Set("有共計約達為是含括由成剩近超逾僅只到至和及與或下中內的了在全總個各這那其每多")
    static func isCJK(_ c: Character) -> Bool { c.unicodeScalars.first.map { (0x4E00...0x9FFF).contains($0.value) } ?? false }

    static let stop: Set<String> = ["名稱", "國旗", "首都", "面積", "人口", "貨幣", "語言", "備註", "地圖", "列表", "編號", "排名", "代碼",
                                   "簡稱", "英文", "中文", "日文", "位置", "區域", "其他", "參見", "參考", "註釋", "外部連結", "合計", "總計"]

    /// 一個項目的樣子：2～12 個字，沒有句子標點
    static func item(_ raw: String) -> String? {
        var s = raw.replacingOccurrences(of: #"\[[^\]]*\]|（[^）]*）|\([^)]*\)"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^\s*(\d{1,3}[\.、．)）]|[•·\-–])\s*"#, with: "", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespaces)
        // 名字不會有「是、的、於、為、比、稱、僅、最」這些句子用的字（「是世界人口第三多的洲」是一句話，不是一個國家）
        guard (2...12).contains(s.count), !s.contains(where: { "。，：:；;？?！!".contains($0) }),
              !["是", "的", "僅", "稱為", "之一", "位於", "次於", "約為", "大約", "合稱", "全稱", "最北", "最南", "最大", "最高", "第三", "第二",
                "分為", "劃分", "將", "以下", "如下"].contains(where: { s.contains($0) }),
              s.filter(\.isNumber).count <= 1, !stop.contains(s) else { return nil }
        return s
    }

    /// 「…、瑞典、芬蘭同意成立」：名單最後一項後面接著的動詞不是名字的一部分
    static func cutVerbTail(_ s: String) -> String {
        var t = s
        for v in ["同意", "簽署", "加入", "組成", "成立", "決定", "共同", "均", "皆", "也", "曾", "已", "將", "於", "在", "則", "被", "之間", "的"] {
            if let r = t.range(of: v), t.distance(from: t.startIndex, to: r.lowerBound) >= 2 { t = String(t[..<r.lowerBound]) }
        }
        return t
    }

    /// 最近一次找名單的過程（除錯用）
    nonisolated(unsafe) public static var lastListDebug = ""

    /// 從網頁裡找出名單：表格第一欄、「、」隔開的一串、連續的短行
    /// 「一」「五」「十二」「12」→ 數字
    static func smallNumber(_ s: String) -> Int? {
        if let n = Int(s) { return n }
        let d: [Character: Int] = ["一": 1, "二": 2, "兩": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
        if s == "十" { return 10 }
        if let r = s.firstIndex(of: "十") {
            let tens = s[..<r].isEmpty ? 1 : d[s[s.startIndex]] ?? 0
            let ones = s[s.index(after: r)...].first.flatMap { d[$0] } ?? 0
            return tens * 10 + ones
        }
        return s.count == 1 ? d[s.first!] : nil
    }

    /// 「北歐五國則清楚說明為丹麥、芬蘭、冰島、挪威和瑞典這五個國家」：句子自己說有幾個，列出來的也剛好那麼多——最可信的名單
    public static func countedList(_ pages: [Evidence], noun: String, subject: String) -> (items: [String], hosts: [String])? {
        let subj = subject.filter { $0.isLetter || $0.isNumber }
        let nounRe = noun.hasSuffix("國家") || noun == "國" ? "(?:個國家|國家|國)" : "(?:個)?" + NSRegularExpression.escapedPattern(for: noun)
        let pattern = "([^，。；：、]{1,14}(?:、[^，。；：、]{1,10})+(?:以及|和|及|與)[^，。；：、]{1,10}?)(?:這|等|共|總共|共計)?([一二兩三四五六七八九十\\d]{1,3})" + nounRe
        // 資料裡常說「北歐五國」：句子列的是別的幾國（「…四國同意成立護照聯盟」）就不算
        var known: [Int: Int] = [:]
        if !subj.isEmpty {
            let kr = NSRegularExpression.escapedPattern(for: subj) + "([一二兩三四五六七八九十\\d]{1,3})" + nounRe
            for p in pages {
                for line in p.text.components(separatedBy: "\n") {
                    if let m = match(line, kr), let n = smallNumber(m[1]) { known[n, default: 0] += 1 }
                }
            }
        }
        let usual = known.max { $0.value < $1.value }?.key
        for p in pages {
            for sent in p.text.components(separatedBy: CharacterSet(charactersIn: "。！？\n")) where subj.isEmpty || sent.contains(subj) {
                guard let m = match(sent, pattern), let n = smallNumber(m[2]), n >= 2 else { continue }
                var parts = m[1].components(separatedBy: "、")
                if var f = parts.first {
                    for v in ["包括", "包含", "分別是", "分別為", "說明為", "指的是", "是指", "指", "即", "為", "是", "有", "位於", "：", ":"] {
                        if let r = f.range(of: v, options: .backwards) { f = String(f[r.upperBound...]) }
                    }
                    parts[0] = f
                }
                if let l = parts.last, let r = l.range(of: "以及") ?? l.range(of: "和") ?? l.range(of: "及") ?? l.range(of: "與") {
                    parts[parts.count - 1] = String(l[..<r.lowerBound])
                    parts.append(cutVerbTail(String(l[r.upperBound...])))
                }
                if let usual, usual != n { continue }
                let items = parts.compactMap { item($0) }
                if items.count == n && items.count == parts.count && Set(items).count == n { return (items, [p.host]) }
            }
        }
        return nil
    }

    public static func extractList(_ pages: [Evidence], noun: String, subject: String) -> (items: [String], hosts: [String]) {
        // 句子自己說了有幾個、列出來的數目也對得上：直接用
        if let c = countedList(pages, noun: noun, subject: subject) {
            lastListDebug = "counted=" + c.items.joined(separator: "/")
            return c
        }
        let suffix = ["縣", "省", "州", "市", "區", "島", "山", "河", "湖", "星", "洲", "洋"].first { noun.hasSuffix($0) }
        var groups: [(items: [String], host: String, ctx: Bool)] = []
        let subj = subject.filter { $0.isLetter || $0.isNumber }
        for p in pages {
            var run: [String] = [], table: [String] = []
            // 一個表格算不算這一類的名單：表頭要有這個名詞（「國家」「省份」「名稱」）。導覽框、側欄的表格沒有這種表頭
            var tableHeaderOK = false, tableStarted = false
            func headerFits(_ row: String) -> Bool {
                let cells = row.components(separatedBy: "｜").map { $0.trimmingCharacters(in: .whitespaces) }
                let key = noun.count >= 2 ? String(noun.prefix(2)) : noun
                return cells.prefix(3).contains { $0.contains(noun) || $0.contains(key) || $0 == "名稱" || $0 == "名字" || $0.hasPrefix(String(noun.prefix(1))) && $0.count <= 4 }
            }
            func flushTable() {
                // 表頭對得上的表格本身就是名單（★ 表示不用再找別的資料印證）
                if table.count >= 4 { groups.append((table, tableHeaderOK ? "★" + p.host : p.host, tableHeaderOK)) }
                table = []; tableStarted = false; tableHeaderOK = false
            }
            // 這一串前面幾行有沒有提到主題（「北歐國家包括…」）；側欄、導覽列通常不會
            var recent: [String] = []
            // 這一頁的開頭就在講主題（「歐洲國家列表」），頁面裡的表格就算有脈絡
            func near() -> Bool { !subj.isEmpty && recent.suffix(6).contains { $0.contains(subj) } }
            // 手機版維基的表格：每一格各自一行，一列變成一小串短行（「阿爾巴尼亞／地拉那／東歐…」），
            // 列和列之間被數字（人口、面積）隔開。把這些小串收集起來，連續很多串就是一張表，每串的第一個就是名稱
            var rowRuns: [[String]] = []
            // 連續短行多半是導覽列、側欄：只有字尾明確（縣、省……）的名單才採用，所以不算有主題脈絡
            func flush() {
                if run.count >= 5 { groups.append((run, p.host, false)) }
                if run.count >= 2 && run.count <= 8 { rowRuns.append(run) } else if !rowRuns.isEmpty && run.count > 8 { rowRuns.append([]) }
                run = []
            }
            for line in p.text.components(separatedBy: "\n") {
                defer { recent.append(line) }
                if line.contains("｜") {
                    if !tableStarted { tableStarted = true; tableHeaderOK = headerFits(line); if tableHeaderOK { continue } }
                    // 只看第一欄（名稱），第一欄不像名稱的那一列就跳過，不去拿別欄（首都、人口）
                    if let cell = line.components(separatedBy: "｜").map({ $0.trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }),
                       let first = item(cell) { table.append(first) }
                    continue
                }
                if tableStarted { flushTable() }
                // 名單是用「、」隔開的；「，」隔開的是一句話裡的子句，不是項目
                var parts = line.components(separatedBy: "、")
                let rawFirst = parts.first ?? ""
                if parts.count >= 4 {
                    // 「北歐國家包括挪威、…、冰島等五國。」：去掉開頭的「…包括」和結尾的「等…」
                    if var f = parts.first {
                        for m in ["包括", "包含", "分別是", "分別為", "泛指", "是指", "指", "即", "有", "為", "是", "位於", "：", ":"] {
                            if let r = f.range(of: m, options: .backwards) { f = String(f[r.upperBound...]) }
                        }
                        parts[0] = f
                    }
                    if var l = parts.last {
                        for m in ["等", "。", "共", "及其", "；"] { if let r = l.range(of: m) { l = String(l[..<r.lowerBound]) } }
                        l = cutVerbTail(l)
                        // 「…、挪威和瑞典」：最後兩個用「和／及」連起來
                        if let r = l.range(of: "以及") ?? l.range(of: "和") ?? l.range(of: "及") ?? l.range(of: "與"),
                           l.distance(from: l.startIndex, to: r.lowerBound) >= 2, l.distance(from: r.upperBound, to: l.endIndex) >= 2 {
                            let a = String(l[..<r.lowerBound]), b = String(l[r.upperBound...])
                            parts[parts.count - 1] = a
                            parts.append(b)
                        } else {
                            parts[parts.count - 1] = l
                        }
                    }
                    // 中間的「挪威和冰島及其附屬領土」：去掉「及其…」，「和」連起來的兩個拆開
                    if parts.count >= 3 {
                        var mid: [String] = []
                        for x in parts.dropFirst().dropLast() {
                            var t = x
                            if let r = t.range(of: "及其") { t = String(t[..<r.lowerBound]) }
                            if let r = t.range(of: "和"), t.distance(from: t.startIndex, to: r.lowerBound) >= 2, t.distance(from: r.upperBound, to: t.endIndex) >= 2 {
                                mid += [String(t[..<r.lowerBound]), String(t[r.upperBound...])]
                            } else {
                                mid.append(t)
                            }
                        }
                        parts = [parts[0]] + mid + [parts[parts.count - 1]]
                    }
                    let its = parts.compactMap { item($0) }
                    // 沒有明確字尾時，同一句要同時講到主題和名詞（「北歐國家包括…」），才算這一類的名單
                    let key = String(noun.prefix(1))
                    _ = key
                    // 「北歐國家包括…」「北歐五國是…」這種開頭本身就是在列名單，不用別的資料印證
                    // 「北歐國家包括」「北歐五國是」「北歐理事會成員國包括」：主題後面不遠處出現名詞（或它的第一個字），接著是在列名單的字
                    let key1 = NSRegularExpression.escapedPattern(for: String(noun.prefix(1)))
                    // 「北歐五國（英語：Nordic countries）是位於丹麥」：括號裡的外文名不算
                    let rawFirst = rawFirst.replacingOccurrences(of: #"（[^）]*）|\([^)]*\)"#, with: "", options: .regularExpression)
                    let intro = !subj.isEmpty && rawFirst.range(of: NSRegularExpression.escapedPattern(for: subj) + "[^，。、]{0,8}" + key1
                        + "[^。、]{0,3}(包括|包含|分別是|分別為|泛指|是指|指|即|有|是|為|：|:)[^，。、]{1,8}$", options: .regularExpression) != nil
                    // ●：「北歐五國，指…」這種直接在列名單的句子，最可信
                    if its.count >= 4 { groups.append((its, intro ? "★●" + p.host : p.host, line.contains(subj) && line.contains(noun) || intro)) }
                    flush()
                } else if let it = item(line) {
                    run.append(it)
                } else {
                    flush()
                }
            }
            flush()
            flushTable()
            // 把連續的小串（每一列）的第一個拿出來組成一欄；夠多列才算一張表
            var col: [String] = []
            func flushCol() {
                if col.count >= 8 {
                    let pageAbout = !subj.isEmpty && p.text.components(separatedBy: "\n").prefix(20).contains { $0.contains(subj) }
                    groups.append((col, pageAbout ? "★" + p.host : p.host, pageAbout))
                }
                col = []
            }
            for r in rowRuns {
                if r.isEmpty { flushCol(); continue }
                col.append(r[0])
            }
            flushCol()
            // 「北歐有哪些國家」：大表裡每一列是「國家／首都／地區」，挑地區那一格是北歐的列（◆：照條件挑出來的）
            if !subj.isEmpty {
                let picked = rowRuns.filter { $0.count >= 2 && $0.dropFirst().contains(subj) }.map { $0[0] }
                if picked.count >= 3 { groups.append((picked, "★◆" + p.host, true)) }
            }
            // 作品、書、電影、歌：直接收講到主題的句子裡的《書名》
            if ["作品", "書", "小說", "電影", "歌", "專輯", "劇", "著作", "名著", "戲劇"].contains(where: { noun.contains($0) }) {
                var titles: [String] = []
                let made = ["作品", "劇", "詩", "寫", "創作", "著", "喜劇", "悲劇", "小說", "專輯", "電影", "執導", "主演"]
                for line in p.text.components(separatedBy: "\n") where line.contains(subj) && made.contains(where: { line.contains($0) })
                    && !["譯", "翻譯", "引進", "介紹"].contains(where: { line.contains($0) }) {
                    var rest = Substring(line)
                    while let a = rest.firstIndex(of: "《"), let b = rest[a...].firstIndex(of: "》") {
                        // 「福爾蓬奈（英語：Volpone）」→「福爾蓬奈」；「第一對開本」「全集」是合集，不是一部作品
                        let t = String(rest[rest.index(after: a)..<b])
                            .replacingOccurrences(of: #"（[^）]*）|\([^)]*\)"#, with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespaces)
                        if (1...20).contains(t.count) && !titles.contains(t)
                            && !["對開本", "全集", "選集", "文集"].contains(where: { t.contains($0) }) { titles.append(t) }
                        rest = rest[rest.index(after: b)...]
                    }
                }
                if titles.count >= 3 { groups.append((titles.prefix(40).map { "《\($0)》" }, p.host, true)) }
            }
        }
        // 已經不存在的國家（西德、蘇聯…）出現兩個以上：是在講歷史上的賽事、條約，不是現在的名單
        let defunct = ["西德", "東德", "蘇聯", "捷克斯洛伐克", "南斯拉夫", "奧匈帝國", "普魯士", "鄂圖曼帝國", "英國各協會"]
        groups = groups.filter { g in g.items.filter { defunct.contains($0) }.count < 2 }
        // 一組算不算這一類：有明確字尾（縣、省……）就要多數符合；否則要夠長
        let good = groups.map { g -> (items: [String], host: String, ctx: Bool) in
            var seen = Set<String>()
            // 表頭（「省份」「國家名稱」）不是項目
            let header = { (x: String) in x.hasPrefix(noun) && x.count <= noun.count + 2 }
            return (g.items.filter { $0 != noun && $0 != subject && !header($0) && seen.insert($0).inserted }, g.host, g.ctx)
        }.filter { g in
            // 沒有明確字尾（國家、景點……）時，這一串前後一定要提到主題，不然很可能是側欄
            guard let suffix else { return g.items.count >= 4 && g.ctx }
            let fit = g.items.filter { $0.hasSuffix(suffix) || $0.hasSuffix("都") || $0.hasSuffix("道") || $0.hasSuffix("府") }.count
            // 多數符合，或是符合的夠多（一張表裡混了「地區」也沒關係，後面只留符合的）
            return (fit * 2 >= g.items.count && fit >= 3) || fit >= 5
        }
        // 沒有字尾可以檢查時，要有第二份資料印證：另一串（另一句、另一個網站、表格）至少有兩個相同的項目
        var confirmed = good
        if suffix == nil {
            // 名單要有明確的來源：表頭對得上的表格、「X國家包括…」這種在列名單的句子、或《作品》
            confirmed = good.filter { g in g.host.hasPrefix("★") || g.items.first?.hasPrefix("《") == true }
        }
        lastListDebug = "groups=" + groups.map { "\($0.host):\($0.items.count):\($0.items.prefix(3).joined(separator: "/"))" }.joined(separator: " | ")
            + " good=\(good.count) confirmed=\(confirmed.count)"
        // 有字尾時比「符合的有幾個」，不是比整串多長（城市清單很長，但裡面的「省」很少）
        func fitCount(_ g: (items: [String], host: String, ctx: Bool)) -> Int {
            guard let suffix else { return g.items.count }
            return g.items.filter { $0.hasSuffix(suffix) || $0.hasSuffix("都") || $0.hasSuffix("道") || $0.hasSuffix("府") }.count
        }
        // 先用直接列名單的句子（●），再來是照條件從大表挑出來的（◆），都沒有才比哪一組最多
        // 直接列名單的句子（●）要有別的資料印證一半以上（或只有它），才不會拿到運動賽事「參賽的歐洲國家包括西德、蘇聯…」這種句子
        func corroborated(_ g: (items: [String], host: String, ctx: Bool)) -> Bool {
            let others = good.filter { $0.items != g.items }
            guard !others.isEmpty else { return true }
            return g.items.filter { it in others.contains { $0.items.contains(it) } }.count * 2 >= g.items.count
        }
        let preferred = suffix != nil ? nil
            : confirmed.first(where: { $0.host.hasPrefix("★●") && corroborated($0) }) ?? confirmed.first(where: { $0.host.hasPrefix("★◆") })
        guard var best = preferred ?? confirmed.max(by: { fitCount($0) < fitCount($1) }) else { return ([], []) }
        if let suffix {
            best.items = best.items.filter { ($0.hasSuffix(suffix) || $0.hasSuffix("都") || $0.hasSuffix("道") || $0.hasSuffix("府")) && !$0.contains("列表") && !$0.hasPrefix(noun) }
        }
        // 問國家：「西歐」「東亞」這種地區不是一個國家
        if noun.contains("國") {
            let regions = ["東歐", "西歐", "南歐", "北歐", "中歐", "東亞", "西亞", "南亞", "東南亞", "中亞", "北非", "東非", "西非", "南非洲", "中東", "歐洲", "亞洲", "非洲", "美洲", "大洋洲"]
            best.items = best.items.filter { !regions.contains($0) }
        }
        // 「都道府縣」「省份及地區」這種總稱不是其中一項
        let kinds: Set<Character> = ["縣", "省", "州", "市", "區", "都", "道", "府"]
        best.items = best.items.filter { !$0.contains("列表") && !$0.hasPrefix("按") && $0 != "地區" && Set($0).intersection(kinds).count < 3 }
        // 沒有字尾、又很長的名單（手機版維基把好幾張表疊在一起：「芬蘭／政府首腦／瑞典／議會議長…」）：
        // 一半以上別的資料都沒提到時，只留別的資料也提到的項目（至少要剩 4 個）
        if suffix == nil, best.items.count > 12 {
            var freq: [String: Int] = [:]
            for g in good { for it in Set(g.items) { freq[it, default: 0] += 1 } }
            let agreed = best.items.filter { (freq[$0] ?? 0) >= 2 }
            if agreed.count >= 4 && agreed.count * 2 < best.items.count { best.items = agreed }
        }
        // 別組也出現過的項目，補進來（不同來源互相印證）
        var items = best.items
        var hosts = [best.host]
        for g in good where g.host != best.host {
            let overlap = g.items.filter { items.contains($0) }.count
            if overlap * 2 >= min(g.items.count, items.count) {
                if !hosts.contains(g.host) { hosts.append(g.host) }
            }
        }
        items = Array(items.prefix(80))
        // 同一個網站只列一次（「zh.wikipedia.org、zh.wikipedia.org」）
        var shown: [String] = []
        for h in hosts.map({ h in String(h.drop(while: { "★◆●".contains($0) })) }) where !shown.contains(h) { shown.append(h) }
        return (items, shown)
    }

    static let causal = ["因為", "由於", "原因", "所以", "導致", "造成", "使得", "是因", "引起", "來自", "為了", "機制", "反射", "源自", "透過", "是由", "because"]

    /// 在講原因的句子：有因果的詞，也有講到問的那件事
    public static func extractReason(_ ev: [Evidence], pred: String, subject: String = "") -> [Evidence] {
        let c = Array(pred)
        let grams = c.count <= 2 ? [pred] : (0..<(c.count - 1)).map { String(c[$0...$0 + 1]) }
        let subj = Think.chunks(subject).first ?? ""
        // 表格的一列（「治療 ｜ 治療導致發燒的疾病」）、太短的片段不是在說明原因
        func rank(_ e: Evidence) -> Int { grams.filter { e.text.contains($0) }.count + (subj.isEmpty || !Think.covers(e.text, subj) ? 0 : 2) }
        return ev.filter { e in e.text.count >= 10 && !e.text.contains("｜") && !e.text.contains("|")
            && causal.contains { e.text.contains($0) } && grams.contains { e.text.contains($0) } }
            .enumerated().sorted { a, b in (rank(a.element), -a.offset) > (rank(b.element), -b.offset) }.map(\.element)
    }

    static let stepVerbs = ["加入", "放入", "倒入", "加水", "煮滾", "煮至", "煮約", "小火煮", "大火", "小火", "蒸", "泡水", "浸泡", "洗淨", "切", "攪拌", "關火", "燜", "開火", "撈", "按下", "點選", "設定", "輸入", "分鐘"]

    /// 做法：挑一個講到目標的網頁，照順序拿出一步一步的句子
    public static func extractSteps(_ pages: [Evidence], target: String) -> (steps: [String], host: String)? {
        var best: (steps: [String], host: String)?
        for p in pages where p.text.contains(target) {
            var steps: [String] = []
            for line in p.text.components(separatedBy: "\n") {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard (8...120).contains(s.count), !s.hasSuffix("？"), !s.hasSuffix("?"), !s.contains("｜"),
                      !s.contains("做法。"), !s.contains("等做法") else { continue }
                let numbered = s.range(of: #"^(\d{1,2}[\.、．)）]|[①②③④⑤⑥⑦⑧⑨⑩]|步驟\s*\d+|Step\s*\d+)"#, options: .regularExpression) != nil
                // 食材清單（「去骨雞腿肉切塊、高麗菜切塊、蔥花」）、食譜列表上的卡片標題不是步驟：
                // 步驟要像一句指示（有編號，或有「，」「。」）
                let listy = s.filter { $0 == "、" }.count >= 2 && !s.contains("，") && !s.contains("。")
                guard !listy, numbered || s.contains("，") || s.contains("。") || s.hasSuffix("！") else { continue }
                // 問答（「A: 可能水太多…」）、文章預告（「本文深入探討…」結尾是「…」）不是步驟
                let faq = ["A:", "Q:", "A：", "Q：", "答：", "問："].contains { s.hasPrefix($0) }
                guard !faq, !s.contains("本文"), !s.contains("？"), !s.contains("?"), !s.hasSuffix("…"), !s.hasSuffix("...") else { continue }
                // 每一步都要有動作（加水、煮、泡……），光有編號或營養成分表不算
                if stepVerbs.contains(where: { s.contains($0) }) {
                    let clean = s.replacingOccurrences(of: #"^(\d{1,2}[\.、．)）]|[①②③④⑤⑥⑦⑧⑨⑩]|步驟\s*\d+[:：.]?|Step\s*\d+[:：.]?)\s*"#, with: "", options: .regularExpression)
                    if !steps.contains(clean) { steps.append(clean) }
                }
                if steps.count >= 8 { break }
            }
            if steps.count >= 3, steps.count > (best?.steps.count ?? 0) { best = (steps, p.host) }
        }
        return best
    }
}

// MARK: - 4. 檢查＋組回答

extension WebAgent {
    /// 照「要的答案」從讀到的東西裡找答案；找不到回傳 ok = false（交給下一輪或老實說）
    static func solve(_ fr: Understanding.Frame, pages: [Understanding.Evidence], snippets: [Understanding.Evidence]) -> (text: String, ok: Bool) {
        // 主題裡的中文詞一定要出現（「台北101」只對到「101」的句子，可能在講舉重 101 公斤）
        let subjTerms = termSet(fr.subject).filter { $0.contains(where: isCJK) }
        // 主題拆成幾個名稱（「地球到月亮」→ 地球、月亮；「台灣人口」→ 台灣），每個名稱都要出現；
        // 短的名稱要整個出現（「台北101」只對到「台北」可能在講別的東西），同義寫法（臺／台、月球／月亮）算一樣
        func canon(_ x: String) -> String {
            var y = x
            for (a, b) in [("臺", "台"), ("月球", "月亮"), ("太陽系", "太陽系"), ("大陸", "大陸")] { y = y.replacingOccurrences(of: a, with: b) }
            return y
        }
        var core = canon(fr.subject.filter { $0.isLetter || $0.isNumber })
        for a in ["人口", "價格", "面積", "溫度", "年齡"] where core.hasSuffix(a) && core.count > a.count + 1 { core.removeLast(a.count) }
        let tokens = core.components(separatedBy: CharacterSet(charactersIn: "到和跟與離")).filter { $0.count >= 2 }
        func tokenIn(_ s: String, _ t: String) -> Bool {
            if t.count <= 5 || t.contains(where: { $0.isNumber || ($0.isASCII && $0.isLetter) }) { return s.contains(t) }
            return score(s, termSet(t)) >= (termSet(t).count + 1) / 2
        }
        var predTerms = Set<String>()
        if case let .reason(pred) = fr.want { predTerms = termSet(pred) }
        func relevant(_ s: String) -> Bool {
            if subjTerms.isEmpty || tokens.isEmpty { return true }
            let cs = canon(s)
            if tokens.allSatisfy({ tokenIn(cs, $0) }) { return true }
            // 問原因時，句子講到「發燒」「呼嚕」這件事本身也算（發燒的原因不一定會重提感冒）
            return !predTerms.isEmpty && score(s, predTerms) >= max(1, predTerms.count / 2)
        }
        var sents: [Understanding.Evidence] = []
        for p in pages { for s in sentences(p.text) where relevant(s) { sents.append(.init(text: s, host: p.host)) } }
        for s in snippets where relevant(s.text) && !isQuestionOrFluff(s.text) { sents.append(s) }

        switch fr.want {
        case let .number(attr, units):
            // 會變的資料：只用最新年份的句子（有寫年份的話）
            var pool = sents
            if fr.recent, let newest = sents.compactMap({ Understanding.latestYear($0.text) }).max() {
                let fresh = sents.filter { (Understanding.latestYear($0.text) ?? 0) >= newest }
                if !fresh.isEmpty { pool = fresh }
            }
            guard let v = Understanding.voteNumber(pool, units: units, subject: fr.subject, rates: attr == "速度") else { return ("", false) }
            var t = "答案：\(v.shown)"
            t += v.votes >= 2 ? "（\(v.votes) 個網站都這樣說）。" : "。"
            t += "\n依據：" + Cite.quote(v.sentence.text, host: v.sentence.host, focus: [v.shown])
            if !v.others.isEmpty { t += "\n⚠️ 來源說法不一：也有 " + v.others.joined(separator: "、") + " 的說法，差別通常在計算方式、統計年份或包含的範圍不同。" }
            if fr.recent {
                t += Understanding.latestYear(v.sentence.text).map { "\n這筆資料是 \($0) 年的，數字可能已經更新，重要的話請看官方最新公布。" }
                    ?? "\n這筆資料沒寫是哪一年的，數字可能已經更新，重要的話請看官方最新公布。"
            }
            // 問的是「幾個國家／省／縣」這種數得出名單的東西，才問要不要列出來（光速、骨頭不用）
            if ["國家", "國", "省", "縣", "州", "市", "城市", "島", "區", "郡", "成員國", "作品"].contains(where: { attr.hasSuffix($0) }) {
                t += "\n要我把這些\(attr)一個一個列出來嗎？"
            }
            return (t, true)
        case let .list(noun):
            let r = Understanding.extractList(pages, noun: noun, subject: fr.subject)
            // 句子自己說了有幾個、數目也對得上的名單是完整的（「北歐五國…這五個國家」）
            let counted = Understanding.lastListDebug.hasPrefix("counted=")
            guard r.items.count >= (counted ? 2 : 4) else { return ("", false) }
            let head = counted ? "一共 \(r.items.count) 個\(noun)：" : r.items.count >= 10 ? "一共找到 \(r.items.count) 個\(noun)：" : "我找到的\(noun)有這些（不一定是全部）："
            return (head + "\n" + r.items.joined(separator: "、")
                    + "\n（名單整理自 " + r.hosts.joined(separator: "、") + "；不同資料的算法可能略有差異）", true)
        case let .reason(pred):
            let rs = Understanding.extractReason(sents, pred: pred, subject: fr.subject)
            guard let first = rs.first else { return ("", false) }
            // 問原因要一段說明：引講原因的那一整句（最多 80 字，切到時加「…」），不切成看不懂的幾個字；每個網站最多一句
            var t = "簡單說：" + Cite.whole(first.text, host: first.host)
            var quotedHosts: Set<String> = [first.host]
            var used = [String(first.text.prefix(12))]
            for e in rs.dropFirst() where used.count < 3 && !used.contains(String(e.text.prefix(12))) {
                used.append(String(e.text.prefix(12)))
                guard quotedHosts.insert(e.host).inserted else { continue }
                t += "\n• 另外也有說法：" + Cite.whole(e.text, host: e.host, limit: 60)
            }
            return (t, true)
        case let .steps(target):
            guard let s = Understanding.extractSteps(pages, target: target) else { return ("", false) }
            // 每一步列出重點（太長的取到前一個「，」，切到時加「…」），來源標在最前面
            return ("做法重點（參考 \(s.host)）：\n" + s.steps.enumerated().map { "\($0.offset + 1). " + Cite.step($0.element) }.joined(separator: "\n"), true)
        case .place:
            // 問首都、位置：句子要講到這個地方本身，還要有「首都」「位於」這類字
            let marks = fr.searches.first?.contains("首都") == true ? ["首都"] : ["位於", "位在", "坐落", "在"]
            // 問首都：把每一句「法國首都巴黎…」「東京是日本的首都」裡的地名抓出來投票，比挑一句話可靠
            let sj = fr.subject
            if marks == ["首都"] {
                let votes = Understanding.capitalVotes(sents.map(\.text), subject: sj)
                if let top = votes.max(by: { ($0.value, $0.key.count) < ($1.value, $1.key.count) }), top.value >= 1 {
                    // 同樣票數時，較長的名字只有在不是「名字＋雜字」時才採用
                    let name = votes.filter { $0.value == top.value && top.key.hasPrefix($0.key) }.min(by: { $0.key.count < $1.key.count })?.key ?? top.key
                    // 依據挑最直接的那句（「東京是日本的首都」勝過「日本的首都圈…」）
                    let direct = ["\(name)是\(sj)的首都", "\(sj)的首都是\(name)", "\(sj)首都是\(name)", "\(sj)的首都為\(name)"]
                    let close = ["\(sj)首都\(name)", "\(sj)的首都\(name)", "\(name)為\(sj)首都", "\(name)為\(sj)的首都"]
                    let ex = sents.first { e in direct.contains { e.text.contains($0) } }
                        ?? sents.first { e in close.contains { e.text.contains($0) } && !["圈", "俱樂部", "足球", "球隊"].contains { e.text.contains($0) } }
                        ?? sents.first { $0.text.contains(name) && $0.text.contains("首都") && !$0.text.contains("圈") }
                        ?? sents.first { $0.text.contains(name) && $0.text.contains("首都") }
                    return ("答案：\(name)（\(top.value) 句資料都這樣寫）" + (ex.map { "\n依據：" + Cite.quote($0.text, host: $0.host, focus: [name]) } ?? ""), true)
                }
            }
            let best = marks.flatMap { m in ["\(sj)的\(m)是", "\(sj)\(m)是", "\(sj)的\(m)為", "\(sj)\(m)為", "是\(sj)的\(m)", "為\(sj)的\(m)", "\(sj)，\(m)", "\(sj)的\(m)：", "\(m)：", "\(m)為"] }
            let direct = marks.map { sj + $0 } + marks.map { sj + "的" + $0 }
            guard let e = sents.first(where: { e in best.contains { e.text.contains($0) } && !e.text.contains("圈") })
                    ?? sents.first(where: { e in direct.contains { e.text.contains($0) } && !e.text.contains("圈") && !e.text.contains("俱樂部") && !e.text.contains("位於") })
                    ?? sents.first(where: { e in marks.contains { e.text.contains($0) } && !e.text.contains("大部分") && !e.text.contains("例如") && !e.text.contains("如英國") })
            else { return ("", false) }
            return ("答案：" + Cite.quote(e.text, host: e.host, focus: marks), true)
        case .open where fr.restated.contains("明確的名稱"):
            // 「世界上最高的山是哪座」：句子要有主題的關鍵詞和那一類東西（山、行星……）
            // 「最高的山」：句子要有同樣的「最高」和「山／峰」，只有「山」字（山同洞）不算
            let head = String(fr.subject.last ?? " ")
            let heads = head == "山" ? ["山", "峰"] : [head]
            let sup = Understanding.match(fr.subject, #"(最.)"#)?[1]
            guard let e = sents.first(where: { e in (sup.map { e.text.contains($0) } ?? true)
                && heads.contains { h in sup.map { e.text.contains($0 + "的" + h) || e.text.contains($0 + h) } ?? e.text.contains(h) } })
            else { return ("", false) }
            return ("答案：" + Cite.quote(e.text, host: e.host, focus: (sup.map { [$0] } ?? []) + heads), true)
        case let .compare(a, b):
            let ta = termSet(a), tb = termSet(b)
            let both = sents.filter { score($0.text, ta) > 0 && score($0.text, tb) > 0 }
            guard !both.isEmpty else { return ("", false) }
            var seenHosts = Set<String>()
            let pts = both.filter { seenHosts.insert($0.host).inserted }.prefix(4).map { "• " + Cite.quote($0.text, host: $0.host, focus: [a, b]) }
            return ("比較重點：\n" + pts.joined(separator: "\n"), true)
        default:
            return ("", true)
        }
    }
}
