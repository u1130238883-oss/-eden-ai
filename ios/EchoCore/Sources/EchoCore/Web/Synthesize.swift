import Foundation

/// 整理：像人查資料一樣——打開好幾個網站，先想這題要什麼樣的答案，把每個網站的內容拆成一個一個重點，
/// 丟掉標題、文章簡介（「這篇文章旨在…」）、hashtag、廣告；再比對：好幾個網站都講到的重點比較可信；
/// 最後用自己的話寫出來：先講結論，再列幾個重點，不貼別人的標題。
public enum Synthesize {
    /// 這題要的答案長什麼樣子
    public enum Shape: Equatable { case advice, reason, definition, open }

    public struct Point {
        public var text: String
        public var hosts: [String]
        public var score: Double
        var grams: Set<String>
        /// 第一個子句（重點常常在這裡：「先觀察對方」「觀察對方的反應」）
        var head: Set<String>
    }

    static func shape(_ want: Understanding.Want) -> Shape? {
        switch want {
        case .steps: return .advice
        case .reason: return .reason
        case .definition: return .definition
        case .open: return .open
        default: return nil
        }
    }

    // MARK: - 不是內容的句子

    /// 文章簡介、導讀、行銷：講的是「這篇文章」，不是答案本身
    static let metaWords = ["這篇文章", "本文", "文章將", "文章會", "旨在", "小編", "帶你", "帶大家", "一起來看", "一起來了解", "為你整理", "為大家整理",
                            "幫你整理", "整理了", "懶人包", "以下將", "以下是", "以下為", "下面將", "下面是", "本篇", "這篇", "今天要", "今天就",
                            "點擊", "點我", "延伸閱讀", "推薦閱讀", "相關文章", "看更多", "了解更多", "閱讀更多", "繼續閱讀", "立即", "免費",
                            "下載", "訂閱", "追蹤", "按讚", "分享", "留言", "版權", "廣告", "優惠", "折扣", "客服", "登入", "註冊", "目錄",
                            "常見問題", "Q&A", "FAQ", "作者", "編輯", "發布", "更新時間", "瀏覽", "人氣", "算命", "運勢#", "加入會員", "預約",
                            "諮詢", "LINE", "私訊", "報名", "課程", "限時", "活動", "抽獎", "網友", "這裡告訴你", "告訴你", "教你", "秘訣大公開",
                            "你知道嗎", "你是否", "是不是也", "有沒有過", "相信很多人", "很多人都", "不少人"]

    public static func isMeta(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.filter({ $0 == "#" || $0 == "＃" }).count >= 1 { return true }
        if metaWords.contains(where: { t.contains($0) }) { return true }
        if t.hasSuffix("？") || t.hasSuffix("?") { return true }
        if t.contains("｜") || t.contains(" | ") || t.contains(" - ") || t.contains("—") && t.count < 40 { return true }
        if t.contains("http") || t.contains("www.") || t.contains(".com") { return true }
        // 表情符號開頭的多半是標題、行銷文案
        if let f = t.unicodeScalars.first, f.properties.isEmojiPresentation { return true }
        return false
    }

    // MARK: - 清理成乾淨的一句話

    static let leadingFillers = ["首先", "其次", "再來", "再者", "接著", "然後", "最後", "另外", "此外", "還有", "總之", "總而言之", "所以說",
                                 "其實", "那麼", "因此", "而且", "第一", "第二", "第三", "第四", "第五", "簡單來說", "簡單說", "也就是說"]

    public static func clean(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        // 去掉表情符號、[1] 這類註腳
        s = String(String.UnicodeScalarView(s.unicodeScalars.filter { !($0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x2000 && $0.value != 0x3001)) }))
        s = s.replacingOccurrences(of: #"\[\d+\]|\[註\d*\]|\[來源請求\]"#, with: "", options: .regularExpression)
        // 圖片說明（「Photo Credit: 某某 (某某) 正午陽光…」「圖片來源：…」）
        s = s.replacingOccurrences(of: #"^(?i)(?:photo credit|圖片來源|圖片提供|圖／|圖/)\s*[:：]?[^，。]*?[)）]\s*"#, with: "", options: .regularExpression)
        // 編號：「1.」「(2)」「三、」「Step 3：」「第一步，」「• 」
        let numbering = [#"^[\(（]?\d{1,2}[\)）\.、．:：]\s*"#, #"^[一二三四五六七八九十]{1,3}[、\.．:：]\s*"#, #"^(?i)(step|步驟)\s*\d+\s*[:：\.、]?\s*"#,
                         #"^第[一二三四五六七八九十\d]{1,3}(步|點|個|招|種)?[，、：:\s]*"#, #"^[•●○◆◇■□▶►★☆✓✔➤→·\-\*＊]+\s*"#]
        for _ in 0..<2 { for p in numbering { s = s.replacingOccurrences(of: p, with: "", options: .regularExpression) } }
        for _ in 0..<2 {
            for f in leadingFillers where s.hasPrefix(f) && s.count > f.count + 6 {
                s = String(s.dropFirst(f.count)).trimmingCharacters(in: CharacterSet(charactersIn: "，,、：: "))
            }
        }
        // 口語尾巴：「喔」「唷」「啦」「～」「！」
        s = s.replacingOccurrences(of: #"[喔哦唷呦啦囉耶呢～~！!]+([。]?)$"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        // 太長：在逗號的地方切，留前面完整的部分（重點通常在前面）
        if s.count > 80 {
            let cs = Array(s)
            var cut = 0
            for (i, c) in cs.enumerated() where i < 80 && "，；,;".contains(c) { cut = i }
            s = cut >= 20 ? String(cs[..<cut]) : String(cs[..<78])
        }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "，,、；;：: "))
        if let l = s.last, !"。！？.!?」）)".contains(l) { s += "。" }
        return s
    }

    // MARK: - 拆成一個一個的重點

    struct Unit { let text: String; let host: String; let item: Bool }

    static let sentenceEnd = CharacterSet(charactersIn: "。！？!?；;\n")

    static func units(_ page: String, host: String) -> [Unit] {
        var out: [Unit] = []
        let lines = page.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let numbered = line.range(of: #"^([\(（]?\d{1,2}[\)）\.、．:：]|[一二三四五六七八九十]{1,3}[、．]|第[一二三四五六七八九十\d]{1,3}[步點招個]|[•●◆■▶►★✓✔➤])"#, options: .regularExpression) != nil
            let body = clean(line)
            // 小標題（「1. 保持自信」）後面接一段說明：合成「保持自信：說明的第一句」
            if numbered, body.count <= 18, i + 1 < lines.count {
                let next = lines[i + 1]
                if !isMeta(next), next.count >= 12,
                   let first = next.components(separatedBy: sentenceEnd).first(where: { $0.count >= 8 }) {
                    let head = body.trimmingCharacters(in: CharacterSet(charactersIn: "。"))
                    out.append(Unit(text: head + "：" + first, host: host, item: true))
                    i += 2
                    continue
                }
            }
            for part in line.components(separatedBy: sentenceEnd) {
                let p = part.trimmingCharacters(in: .whitespaces)
                guard p.count >= 8, p.count <= 220, !isMeta(p), !WebAgent.looksLikeJunk(p), !Think.looksLikeNoise(p) else { continue }
                // 判斷這句是不是內容：廣告、文章介紹、留言、標題都不要
                let v = Judge.check(p, want: .open, subject: "", inContext: true)
                guard v == .answer else { continue }
                out.append(Unit(text: p, host: host, item: numbered))
            }
            i += 1
        }
        return out
    }

    // MARK: - 比對

    static let stopChars: Set<Character> = Set("的了是在和與及或也都就要會能可以這那你我他她它們個一不有很更最把被讓給對從到為而但如果因為所以")

    static func grams(_ s: String) -> Set<String> {
        let cs = s.filter { WebAgent.isCJK($0) || $0.isLetter || $0.isNumber }.map { $0 }
        var g = Set<String>()
        for i in 0..<max(0, cs.count - 1) where !(stopChars.contains(cs[i]) && stopChars.contains(cs[i + 1])) { g.insert(String(cs[i...i + 1])) }
        return g
    }

    /// 兩句話講的是不是同一件事（重疊的雙字組佔短的那句多少）
    static func same(_ a: Set<String>, _ b: Set<String>) -> Bool {
        let m = min(a.count, b.count)
        guard m >= 3 else { return false }
        return Double(a.intersection(b).count) / Double(m) >= 0.45
    }

    /// 開頭的重點一樣（「先觀察對方：…」和「觀察對方的反應，…」）也算同一件事
    static func same(_ a: Point, _ g: Set<String>, _ h: Set<String>) -> Bool {
        if same(a.grams, g) { return true }
        let shared = a.head.intersection(h).count
        return shared >= 3 && Double(shared) / Double(max(1, min(a.head.count, h.count))) >= 0.6
    }

    static func firstClause(_ s: String) -> String {
        String(s.prefix { !"，,：:；;。".contains($0) })
    }

    /// 開頭在重複問題的子句（「當你喜歡一個人時，」）拿掉
    static func dropEcho(_ s: String, question q: Set<String>) -> String {
        let c = firstClause(s)
        guard c.count < s.count - 6 else { return s }
        let g = grams(c)
        guard g.count >= 2, Double(g.intersection(q).count) / Double(g.count) >= 0.5 else { return s }
        return String(s.dropFirst(c.count + 1)).trimmingCharacters(in: .whitespaces)
    }

    /// 句子裡有沒有「做法」的字眼（可以、建議、先、避免……）
    /// （「要」「多」「先」太常見，「最主要」「需要」不算做法，這裡不用）
    public static func actionable(_ s: String) -> Bool {
        ["可以", "建議", "試著", "試試", "避免", "不要", "記得", "保持", "盡量", "練習", "準備", "應該", "最好", "有助", "改善", "調整", "固定", "減少", "增加"].contains { s.contains($0) }
    }

    static let actionWords = ["可以", "建議", "試著", "試試", "先", "多", "避免", "不要", "別", "記得", "保持", "給自己", "找", "每天", "盡量", "學會",
                              "主動", "練習", "注意", "應該", "要", "適度", "減少", "增加", "培養", "接受", "放下", "停止", "設定", "安排", "選擇"]
    static let reasonWords = ["因為", "由於", "原因", "所以", "導致", "造成", "使得", "是因", "來自", "引起", "刺激", "產生", "散射", "反射", "作用"]
    static let defineWords = ["是指", "指的是", "是一種", "是一個", "稱為", "是一門", "意思是", "又稱", "簡稱", "定義", "是用來"]

    /// 寫得好不好：口語、部落格腔扣分；完整、正式、有根據的句子加分
    static let casual = ["我覺得", "我自己", "小編", "XD", "哈哈", "啦", "喔", "欸", "超級", "真的很", "網友", "大家好", "哈囉", "不囉嗦", "必看", "神器", "懶人包", "爆"]
    static let formal = ["研究", "指出", "根據", "專家", "醫師", "心理師", "因此", "此外", "有助於", "能夠", "建議", "顯示", "發現", "原則", "關鍵"]
    static func style(_ s: String) -> Double {
        -1.5 * Double(casual.filter { s.contains($0) }.count) + min(1.5, 0.5 * Double(formal.filter { s.contains($0) }.count))
    }

    /// 一句話對這題有多好用
    /// pred：「為什麼」問的是主題的哪一點（「天空為什麼是藍色的」→ 藍色）；原因句要講到這一點，只提到天空不算
    static func score(_ u: Unit, shape: Shape, topic: Set<String>, question: Set<String>, pred: Set<String> = []) -> Double {
        let g = grams(u.text)
        // 跟問題幾乎一樣的句子是標題（「喜歡一個人該怎麼辦？」），不是答案
        if !question.isEmpty, Double(g.intersection(question).count) / Double(max(1, g.count)) > 0.7 { return -1 }
        let rel = Double(g.intersection(topic).count)
        var s = min(rel, 3) + style(u.text) + (Cite.isProfessional(u.host) && !u.host.contains("wikipedia") ? 1.5 : 0)
        let n = u.text.count
        s += n >= 14 && n <= 90 ? 1 : (n > 140 ? -1 : 0)
        switch shape {
        case .advice:
            let act = actionWords.filter { u.text.contains($0) }.count
            s += Double(min(act, 2)) + (u.item ? 1.5 : 0)
            // 沒講到主題、也不是那篇文章裡列出來的一點：大概是別的話題
            if rel == 0 && !u.item { s -= 2 }
            // 名詞解釋（「咽喉痛是指…」）不是做法
            if defineWords.contains(where: { u.text.contains($0) }) || u.text.contains("是指") { s -= 3 }
        case .reason:
            // 真的在說因果（因為、使得、導致）≠ 只提到「原因」「原理」這兩個字；歷史（西元、論文、諾貝爾）是背景，不是原因
            let strong = ["因為", "由於", "導致", "造成", "使得", "所以", "因此", "引起", "產生", "是因"].contains { u.text.contains($0) }
            let why = strong || reasonWords.contains { u.text.contains($0) }
            s += strong ? 3 : (why ? 0.5 : -2)
            s += ["散射", "波長", "吸收", "反射", "分子", "作用", "機制", "結構", "壓力", "溫度"].contains { u.text.contains($0) } ? 1 : 0
            if ["西元", "年起", "論文", "諾貝爾", "年前", "世紀", "歷史上"].contains(where: { u.text.contains($0) }) { s -= 2 }
            // 「依然」「仍然」是在回答接下來的疑問（為什麼不是紫色），是補充，不是主要的原因
            if ["依然", "仍然", "還是會"].contains(where: { u.text.contains($0) }) { s -= 1.5 }
            if rel == 0 { s -= 2 }
            // 講到問的那一點（藍色、藍光）才是在回答；只提到主題（天空、雲是白色的）不算
            if !pred.isEmpty { s += pred.contains(where: { u.text.contains($0) }) ? (why ? 2 : 1) : -3 }
            // 「並無法解釋…」是文章的鋪陳，說的是「這樣解釋不通」，不是答案
            if ["無法解釋", "不能解釋", "解釋不了", "並不能說明"].contains(where: { u.text.contains($0) }) { s -= 3 }
        case .definition:
            if defineWords.contains(where: { u.text.contains($0) }) { s += 3 }
            if rel == 0 { s -= 2 }
        case .open:
            if rel == 0 { s -= 1.5 }
        }
        return s
    }

    /// 把各網站的句子分群：講同一件事的放一起，記下有幾個網站都這樣說
    public static func points(question: String, subject: String, shape: Shape, pages: [(host: String, text: String)], pred: String = "") -> [Point] {
        let topic = grams(Understanding.plain(subject))
        // 「為什麼」問的那一點：述語的雙字詞去掉主題的、去掉「是」「的」這種虛字組成的
        // 用關鍵的字（「藍」）而不是詞：網頁會寫「藍光」「藍天」「變藍」
        let topicChars = Set(Understanding.plain(subject))
        let filler: Set<Character> = ["是", "的", "會", "很", "麼", "什", "為", "了", "在", "這", "那", "有", "要", "能", "可", "以", "都", "也", "就", "一", "個", "色"]
        let predG = Set(Understanding.plain(pred).filter { !topicChars.contains($0) && !filler.contains($0) && !$0.isPunctuation }.map(String.init))
        let qg = grams(question)
        var scored: [(Unit, Double)] = []
        for p in pages {
            // 百科只有名詞解釋和作品劇情，沒有「怎麼做」：建議題不用它
            if shape == .advice, p.host.contains("wikipedia") || p.host.contains("baike") || p.host.contains("wikiwand") { continue }
            // 整頁都沒講到主題（問「喜歡一個人」卻是水果去皮的小技巧）：整頁不用
            if topic.count >= 2, Double(grams(p.text).intersection(topic).count) / Double(topic.count) < 0.5 { continue }
            var seen = Set<String>()
            for u in units(p.text, host: p.host) where seen.insert(String(u.text.prefix(12))).inserted {
                let s = score(u, shape: shape, topic: topic, question: qg, pred: predG)
                if s >= (shape == .advice ? 2.5 : 3) { scored.append((u, s)) }
            }
        }
        scored.sort { $0.1 > $1.1 }
        var pts: [Point] = []
        for (u, s) in scored.prefix(200) {
            let text = clean(dropEcho(u.text, question: qg))
            let g = grams(text), h = grams(firstClause(text))
            if let k = pts.firstIndex(where: { same($0, g, h) }) {
                if !pts[k].hosts.contains(u.host) { pts[k].hosts.append(u.host); pts[k].score += 2 }
                continue
            }
            pts.append(Point(text: text, hosts: [u.host], score: s, grams: g, head: h))
        }
        return pts.filter { $0.text.count >= 8 }.sorted { $0.score > $1.score }
    }

    /// 寫出整理好的回答；重點不夠（少於兩個）就回 nil，讓原本的方法處理
    /// lead：已經找到的直接答案（原因、定義），放在最前面，下面補其他網站也提到的重點
    public static func compose(question: String, subject: String, want: Understanding.Want, pages: [(host: String, text: String)], lead: String? = nil) -> String? {
        guard let shape = shape(want) else { return nil }
        var pred = ""
        if case let .reason(p) = want { pred = p }
        var pts = points(question: question, subject: subject, shape: shape, pages: pages, pred: pred)
        if let lead {
            // 已經有直接的答案：只補「別的網站也這樣說」的重點，同一個網站的零散句子不補
            let lg = grams(lead)
            pts.removeAll { same($0.grams, lg) || $0.hosts.count < 2 && lead.contains($0.hosts[0]) }
        }
        let n = shape == .advice ? 5 : (shape == .reason ? 3 : 4)
        let chosen = Array(pts.prefix(n))
        guard chosen.count >= (lead == nil ? 2 : 1) else { return nil }
        var allHosts: [String] = []
        for h in chosen.flatMap(\.hosts) where !allHosts.contains(h) { allHosts.append(h) }
        let marks = ["①", "②", "③", "④", "⑤"]
        func line(_ i: Int, _ p: Point) -> String { marks[i] + " " + p.text + (p.hosts.count >= 2 ? "（\(p.hosts.count) 個網站都提到）" : "") }
        var t = ""
        if let lead {
            // 只留直接答案那一段（後面零散的補充不要）
            let head = lead.components(separatedBy: "\n\n").first ?? lead
            t = head + "\n\n其他網站也提到：\n" + chosen.enumerated().map { line($0.offset, $0.element) }.joined(separator: "\n")
        } else {
            let n = allHosts.count
            switch shape {
            case .advice:
                t = (n >= 2 ? "綜合 \(n) 個網站的建議，可以這樣做：\n" : "可以這樣做：\n")
            case .reason:
                t = "簡單說：" + chosen[0].text + "\n\n其他原因：\n"
            case .definition:
                t = "簡單說：" + chosen[0].text + "\n\n重點：\n"
            case .open:
                t = (n >= 2 ? "綜合 \(n) 個網站的資料，重點如下：\n" : "重點如下：\n")
            }
            let rest = (shape == .reason || shape == .definition) ? Array(chosen.dropFirst()) : chosen
            t += rest.enumerated().map { line($0.offset, $0.element) }.joined(separator: "\n")
            if rest.isEmpty { t = t.replacingOccurrences(of: "\n\n其他原因：\n", with: "").replacingOccurrences(of: "\n\n重點：\n", with: "") }
        }
        t += "\n（參考：" + allHosts.prefix(4).joined(separator: "、") + "）"
        return t
    }
}
