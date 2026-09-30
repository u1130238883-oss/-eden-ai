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
        return [".gov", ".edu", "wikipedia.org", ".org.tw", "who.int", ".go.jp", "un.org"].contains { h.contains($0) } ? 2 : 1
    }

    static func plain(_ q: String) -> String {
        var t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        for w in ["請問", "請你", "幫我查一下", "幫我查", "查一下", "幫我", "我想知道", "你知道", "告訴我", "想問"] where t.hasPrefix(w) {
            t.removeFirst(w.count)
            break
        }
        t = String(t.filter { !"？?！!。，,；;：:「」 ".contains($0) })
        while let last = t.last, "呢嗎啊呀吧".contains(last) { t.removeLast() }
        return t
    }

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
    public static func frame(_ question: String) -> Frame {
        // 「現在」「目前」只說明要最新的資料，不是主題的一部分
        var t = plain(question)
        for w in recentWords where t.count > w.count + 2 { t = t.replacingOccurrences(of: w, with: "") }
        func F(_ subject: String, _ want: Want, _ s: [String], _ r: [String], _ wiki: [String], _ restated: String) -> Frame {
            Frame(subject: subject, want: want, searches: uniq(s), retry: uniq(r), wikiTitles: uniq(wiki).filter { $0.count >= 2 }, restated: restated)
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
                if let v = a.first, "煮做烤炒蒸泡滷煎燉".contains(v) { food = true; a.removeFirst() }
                target = a
            } else if let m = match(t, #"^(.+?)(?:要|該)?(?:怎麼|如何)(.+)$"#) {
                target = m[1]
                food = m[2].first.map { "煮做烤炒蒸泡滷煎燉".contains($0) } ?? false
            }
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
        if let m = match(t, #"^(?:什麼是)(.+)$"#) ?? match(t, #"^(.+?)(?:是什麼|是啥|什麼意思)"#) {
            return F(m[1], .definition, ["\(m[1]) 是什麼"], ["\(m[1]) 意思"], [m[1]], "你想知道「\(m[1])」是什麼 → 用一兩句話說清楚。")
        }
        return F(t, .open, [t], [], [], "你問的是「\(t)」。")
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
        // 「299,792,458」「299 792 458」（千位用逗號或空格）、「1.496」都要認得
        guard !alt.isEmpty, let re = try? NSRegularExpression(pattern: #"(\d{1,3}(?:[, \x{2009}\x{202F}\x{00A0}]\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)\s*(萬|億)?\s*(?:"# + alt + ")") else { return [] }
        var out: [(Double, String)] = []
        for m in re.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            guard let r = Range(m.range, in: s), let nr = Range(m.range(at: 1), in: s),
                  var v = Double(String(s[nr].filter { $0.isNumber || $0 == "." })) else { continue }
            // 「每平方公里 113,703 人」「人口密度」是比率，不是問的那個數量
            let before = String(s[s.index(r.lowerBound, offsetBy: -min(8, s.distance(from: s.startIndex, to: r.lowerBound)))..<r.lowerBound])
            let after = String(s[r.upperBound..<s.index(r.upperBound, offsetBy: min(3, s.distance(from: r.upperBound, to: s.endIndex)))])
            if !rates && (before.contains("每") || before.contains("密度") || after.hasPrefix("/") || after.hasPrefix("每") || after.hasPrefix("／")) { continue }
            if let mr = Range(m.range(at: 2), in: s) { v *= s[mr] == "萬" ? 1e4 : 1e8 }
            out.append((v, String(s[r])))
        }
        return out
    }

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
        // 先看幾個網站（官方算兩票），一樣的話看被提到幾次（正確的數值通常一再出現，歷史上的估計只提一次）
        guard let bi = groups.indices.max(by: { (w(groups[$0]), mentions[$0]) < (w(groups[$1]), mentions[$1]) }) else { return nil }
        let best = groups[bi]
        // 其他說法：同一種單位、而且有一定可信度的才提（換算成英尺、別的數量不算不同說法）
        func unit(_ x: String) -> String { String(x.drop { $0.isNumber || $0 == "," || $0 == "." || $0 == " " }) }
        let others = groups.filter { $0.shown != best.shown && unit($0.shown) == unit(best.shown) && $0.hosts.count >= 2 }.prefix(3).map(\.shown)
        return (best.shown, best.sentence, best.hosts.count, Array(others))
    }

    static let stop: Set<String> = ["名稱", "國旗", "首都", "面積", "人口", "貨幣", "語言", "備註", "地圖", "列表", "編號", "排名", "代碼",
                                   "簡稱", "英文", "中文", "日文", "位置", "區域", "其他", "參見", "參考", "註釋", "外部連結", "合計", "總計"]

    /// 一個項目的樣子：2～12 個字，沒有句子標點
    static func item(_ raw: String) -> String? {
        var s = raw.replacingOccurrences(of: #"\[[^\]]*\]|（[^）]*）|\([^)]*\)"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^\s*(\d{1,3}[\.、．)）]|[•·\-–])\s*"#, with: "", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespaces)
        // 名字不會有「是、的、於、為、比、稱、僅、最」這些句子用的字（「是世界人口第三多的洲」是一句話，不是一個國家）
        guard (2...12).contains(s.count), !s.contains(where: { "。，：:；;？?！!".contains($0) }),
              !["是", "的", "僅", "稱為", "之一", "位於", "次於", "約為", "大約", "合稱", "全稱", "最北", "最南", "最大", "最高", "第三", "第二"].contains(where: { s.contains($0) }),
              s.filter(\.isNumber).count <= 1, !stop.contains(s) else { return nil }
        return s
    }

    /// 從網頁裡找出名單：表格第一欄、「、」隔開的一串、連續的短行
    public static func extractList(_ pages: [Evidence], noun: String, subject: String) -> (items: [String], hosts: [String]) {
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
            // 連續短行多半是導覽列、側欄：只有字尾明確（縣、省……）的名單才採用，所以不算有主題脈絡
            func flush() { if run.count >= 5 { groups.append((run, p.host, false)) }; run = [] }
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
                if parts.count >= 4 {
                    // 「北歐國家包括挪威、…、冰島等五國。」：去掉開頭的「…包括」和結尾的「等…」
                    if var f = parts.first {
                        for m in ["包括", "包含", "分別是", "分別為", "有", "為", "是", "：", ":"] {
                            if let r = f.range(of: m, options: .backwards) { f = String(f[r.upperBound...]) }
                        }
                        parts[0] = f
                    }
                    if var l = parts.last {
                        for m in ["等", "。", "共", "及其", "；"] { if let r = l.range(of: m) { l = String(l[..<r.lowerBound]) } }
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
                    let its = parts.compactMap { item($0) }
                    // 沒有明確字尾時，同一句要同時講到主題和名詞（「北歐國家包括…」），才算這一類的名單
                    let key = String(noun.prefix(1))
                    _ = key
                    // 「北歐國家包括…」「北歐五國是…」這種開頭本身就是在列名單，不用別的資料印證
                    // 「北歐國家包括」「北歐五國是」「北歐理事會成員國包括」：主題後面不遠處出現名詞（或它的第一個字），接著是在列名單的字
                    let key1 = NSRegularExpression.escapedPattern(for: String(noun.prefix(1)))
                    let intro = !subj.isEmpty && line.range(of: NSRegularExpression.escapedPattern(for: subj) + "[^，。、]{0,8}" + key1
                        + "[^，。、]{0,3}(包括|包含|分別是|分別為|有|是|為|：|:)", options: .regularExpression) != nil
                    if its.count >= 4 { groups.append((its, intro ? "★" + p.host : p.host, line.contains(subj) && line.contains(noun) || intro)) }
                    flush()
                } else if let it = item(line) {
                    run.append(it)
                } else {
                    flush()
                }
            }
            flush()
            flushTable()
            // 作品、書、電影、歌：直接收講到主題的句子裡的《書名》
            if ["作品", "書", "小說", "電影", "歌", "專輯", "劇", "著作", "名著", "戲劇"].contains(where: { noun.contains($0) }) {
                var titles: [String] = []
                let made = ["作品", "劇", "詩", "寫", "創作", "著", "喜劇", "悲劇", "小說", "專輯", "電影", "執導", "主演"]
                for line in p.text.components(separatedBy: "\n") where line.contains(subj) && made.contains(where: { line.contains($0) })
                    && !["譯", "翻譯", "引進", "介紹"].contains(where: { line.contains($0) }) {
                    var rest = Substring(line)
                    while let a = rest.firstIndex(of: "《"), let b = rest[a...].firstIndex(of: "》") {
                        let t = String(rest[rest.index(after: a)..<b])
                        if (1...20).contains(t.count) && !titles.contains(t) { titles.append(t) }
                        rest = rest[rest.index(after: b)...]
                    }
                }
                if titles.count >= 3 { groups.append((titles.prefix(40).map { "《\($0)》" }, p.host, true)) }
            }
        }
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
            return fit * 2 >= g.items.count && fit >= 3
        }
        // 沒有字尾可以檢查時，要有第二份資料印證：另一串（另一句、另一個網站、表格）至少有兩個相同的項目
        var confirmed = good
        if suffix == nil {
            // 名單要有明確的來源：表頭對得上的表格、「X國家包括…」這種在列名單的句子、或《作品》
            confirmed = good.filter { g in g.host.hasPrefix("★") || g.items.first?.hasPrefix("《") == true }
        }
        guard var best = confirmed.max(by: { $0.items.count < $1.items.count }) else { return ([], []) }
        if let suffix {
            best.items = best.items.filter { ($0.hasSuffix(suffix) || $0.hasSuffix("都") || $0.hasSuffix("道") || $0.hasSuffix("府")) && !$0.contains("列表") && !$0.hasPrefix(noun) }
        }
        // 「都道府縣」「省份及地區」這種總稱不是其中一項
        let kinds: Set<Character> = ["縣", "省", "州", "市", "區", "都", "道", "府"]
        best.items = best.items.filter { !$0.contains("列表") && !$0.hasPrefix("按") && $0 != "地區" && Set($0).intersection(kinds).count < 3 }
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
        return (items, hosts.map { $0.hasPrefix("★") ? String($0.dropFirst()) : $0 })
    }

    static let causal = ["因為", "由於", "原因", "所以", "導致", "造成", "使得", "是因", "引起", "來自", "為了", "機制", "反射", "源自", "透過", "是由", "because"]

    /// 在講原因的句子：有因果的詞，也有講到問的那件事
    public static func extractReason(_ ev: [Evidence], pred: String) -> [Evidence] {
        let c = Array(pred)
        let grams = c.count <= 2 ? [pred] : (0..<(c.count - 1)).map { String(c[$0...$0 + 1]) }
        return ev.filter { e in causal.contains { e.text.contains($0) } && grams.contains { e.text.contains($0) } }
            .sorted { a, b in grams.filter { a.text.contains($0) }.count > grams.filter { b.text.contains($0) }.count }
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
            guard let v = Understanding.voteNumber(sents, units: units, subject: fr.subject, rates: attr == "速度") else { return ("", false) }
            var t = "答案：\(v.shown)"
            t += v.votes >= 2 ? "（\(v.votes) 個網站都這樣說）。" : "。"
            t += "\n依據：" + WebSearch.clip(v.sentence.text, 200) + "（\(v.sentence.host)）"
            if !v.others.isEmpty { t += "\n也有 " + v.others.joined(separator: "、") + " 的說法，差別通常在計算方式、統計年份或包含的範圍不同。" }
            if fr.recent {
                t += Understanding.latestYear(v.sentence.text).map { "\n這筆資料是 \($0) 年的，數字可能已經更新，重要的話請看官方最新公布。" }
                    ?? "\n這筆資料沒寫是哪一年的，數字可能已經更新，重要的話請看官方最新公布。"
            }
            if case .number = fr.want, !["數量", "錢", "歲", "距離", "高度", "重量", "深度", "長度", "面積", "時間"].contains(attr) {
                t += "\n要我把這些\(attr)一個一個列出來嗎？"
            }
            return (t, true)
        case let .list(noun):
            let r = Understanding.extractList(pages, noun: noun, subject: fr.subject)
            guard r.items.count >= 4 else { return ("", false) }
            return ("一共找到 \(r.items.count) 個\(noun)：\n" + r.items.joined(separator: "、")
                    + "\n（名單整理自 " + r.hosts.joined(separator: "、") + "；不同資料的算法可能略有差異）", true)
        case let .reason(pred):
            let rs = Understanding.extractReason(sents, pred: pred)
            guard let first = rs.first else { return ("", false) }
            var t = "簡單說：" + WebSearch.clip(first.text, 200) + "（\(first.host)）"
            var used = [String(first.text.prefix(12))]
            for e in rs.dropFirst() where used.count < 3 && !used.contains(String(e.text.prefix(12))) {
                used.append(String(e.text.prefix(12)))
                t += "\n• " + WebSearch.clip(e.text, 150) + "（\(e.host)）"
            }
            return (t, true)
        case let .steps(target):
            guard let s = Understanding.extractSteps(pages, target: target) else { return ("", false) }
            return ("做法（整理自 \(s.host)）：\n" + s.steps.enumerated().map { "\($0.offset + 1). " + WebSearch.clip($0.element, 110) }.joined(separator: "\n"), true)
        case .place:
            // 問首都、位置：句子要講到這個地方本身，還要有「首都」「位於」這類字
            let marks = fr.searches.first?.contains("首都") == true ? ["首都"] : ["位於", "位在", "坐落", "在"]
            // 最好的句子是直接說「法國的首都是巴黎」「東京是日本的首都」；「位於法國首都巴黎的足球俱樂部」只是順帶提到
            let sj = fr.subject
            let best = marks.flatMap { m in ["\(sj)的\(m)是", "\(sj)\(m)是", "\(sj)的\(m)為", "\(sj)\(m)為", "是\(sj)的\(m)", "為\(sj)的\(m)", "\(sj)，\(m)", "\(sj)的\(m)：", "\(m)：", "\(m)為"] }
            let direct = marks.map { sj + $0 } + marks.map { sj + "的" + $0 }
            guard let e = sents.first(where: { e in best.contains { e.text.contains($0) } && !e.text.contains("圈") })
                    ?? sents.first(where: { e in direct.contains { e.text.contains($0) } && !e.text.contains("圈") && !e.text.contains("俱樂部") && !e.text.contains("位於") })
                    ?? sents.first(where: { e in marks.contains { e.text.contains($0) } && !e.text.contains("大部分") && !e.text.contains("例如") && !e.text.contains("如英國") })
            else { return ("", false) }
            return ("答案：" + WebSearch.clip(e.text, 200) + "（\(e.host)）", true)
        case .open where fr.restated.contains("明確的名稱"):
            // 「世界上最高的山是哪座」：句子要有主題的關鍵詞和那一類東西（山、行星……）
            // 「最高的山」：句子要有同樣的「最高」和「山／峰」，只有「山」字（山同洞）不算
            let head = String(fr.subject.last ?? " ")
            let heads = head == "山" ? ["山", "峰"] : [head]
            let sup = Understanding.match(fr.subject, #"(最.)"#)?[1]
            guard let e = sents.first(where: { e in (sup.map { e.text.contains($0) } ?? true)
                && heads.contains { h in sup.map { e.text.contains($0 + "的" + h) || e.text.contains($0 + h) } ?? e.text.contains(h) } })
            else { return ("", false) }
            return ("答案：" + WebSearch.clip(e.text, 200) + "（\(e.host)）", true)
        case let .compare(a, b):
            let ta = termSet(a), tb = termSet(b)
            let both = sents.filter { score($0.text, ta) > 0 && score($0.text, tb) > 0 }
            guard !both.isEmpty else { return ("", false) }
            return ("比較重點：\n" + both.prefix(4).map { "• " + WebSearch.clip($0.text, 150) + "（\($0.host)）" }.joined(separator: "\n"), true)
        default:
            return ("", true)
        }
    }
}
