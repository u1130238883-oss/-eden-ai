import Foundation

/// 用大腦讀網頁、自己下結論（不分問題類型、不用模板）：
///   1. 把每個網頁切成一段一段
///   2. 先粗略挑出跟問題有關的段落（省時間）
///   3. 每一段都讓大腦讀：這段有沒有在回答問題？答案是哪幾個字？有多肯定？
///   4. 不同網站的答案互相比對：說法一樣的加在一起，官方、百科的份量比較重
///   5. 有一個說法明顯勝出 → 那就是答案；幾個說法各有道理 → 整理成幾個重點；說法衝突 → 講出來
public enum Think {
    /// 大腦有時只框到名字的一部分（「指達文西」框成「文西」）。資料裡這幾個字每次前面都是同一個字的話，那個字也是名字的一部分。
    /// 名字後面的「頂峰、山頂」也拿掉（「珠穆朗瑪峰頂峰」→「珠穆朗瑪峰」）。
    public static func wholeName(_ ans: String, in texts: [String]) -> String {
        var a = ans
        guard (1...8).contains(a.count), a.allSatisfy(Understanding.isCJK) else { return a }
        for suf in ["頂峰", "山頂", "峰頂", "主峰"] where a.hasSuffix(suf) && a.count > suf.count + 1 {
            let stem = String(a.dropLast(suf.count))
            if stem.hasSuffix("峰") || stem.hasSuffix("山") { a = stem }
        }
        let lead: Set<Character> = Set("的是在和與及或為被由從把將對向於了有指稱叫說即乃之其這那一、都國省市縣")
        for _ in 0..<2 {
            var before: [Character: Int] = [:]
            var total = 0
            for t in texts {
                var from = t.startIndex
                while let r = t.range(of: a, range: from..<t.endIndex) {
                    total += 1
                    if r.lowerBound > t.startIndex { before[t[t.index(before: r.lowerBound)], default: 0] += 1 }
                    from = r.upperBound
                }
            }
            guard total >= 2, before.count == 1, let p = before.first, p.value == total,
                  Understanding.isCJK(p.key), !lead.contains(p.key) else { break }
            a = String(p.key) + a
        }
        return a
    }

    static func withWholeName(_ sp: Brain.Span, _ texts: [String]) -> Brain.Span {
        var s = sp
        s.text = wholeName(sp.text, in: texts)
        return s
    }

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

    /// 不是內容的句子：網頁標題和導覽（「…- 維基百科，自由的百科全書跳至內容」「主條目：…」）、
    /// 食譜列表的卡片（「19 讚20 分…食材：米、水」）、小標題和問句（「5.3. 結局是在讚美毀滅嗎？」）、文章預告（「…解析：…」結尾是「...」）
    static func looksLikeNoise(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        if ["跳至內容", "自由的百科全書", "主條目", "參見：", "另見：", "請參閱", "消歧義", "新增話題", "分類：", "維基百科"].contains(where: { t.contains($0) }) { return true }
        // 頁尾的連結和書目（「參見維特效應外部連結維基共享資源上的相關多媒體資源」「宋碧雲/譯，遠景出版社，1980」）
        if t.hasPrefix("參見") || t.hasPrefix("另見") || ["外部連結", "外部链接", "維基共享資源", "維基文庫", "多媒體資源", "原始文獻", "相關條目", "參考文獻",
                                                     "出版社", "/譯", "／譯", "譯本約", "國家圖書館"].contains(where: { t.contains($0) }) { return true }
        if t.contains("食材：") || (t.contains("讚") && t.contains(where: \.isNumber)) { return true }
        // 參考書目（「（中文） 梁慶標：三島由紀夫《假面自白》主要內容簡介及賞析」）
        if t.hasPrefix("（") || t.contains("簡介及賞析") || t.contains("ISBN") || t.contains("出版社") && t.contains("：") { return true }
        if t.hasSuffix("？") || t.hasSuffix("?") || t.hasSuffix("...") || t.hasSuffix("…") { return true }
        // 文章簡介、hashtag 標題（「這篇文章旨在幫助你瞭解…」「⭐ 免費算命#喜歡一個人#…」）：講的是文章，不是答案
        if t.contains("#") || t.contains("＃") || ["這篇文章", "本篇文章", "旨在", "小編", "懶人包", "延伸閱讀", "推薦閱讀", "帶你了解", "帶你瞭解", "一起來看"].contains(where: { t.contains($0) }) { return true }
        if t.contains(" - ") || t.contains("｜") || t.contains(" | ") { return true }
        if t.range(of: #"^\d+(\.\d+)*[\.、]\s*"#, options: .regularExpression) != nil && t.count <= 40 { return true }
        let digits = t.filter(\.isNumber).count
        return t.count >= 10 && digits * 4 > t.count
    }

    /// 答案的每個字都在問題裡（問「最高的山」答「高山」）：沒有說出新東西；純數字不算
    static func echoes(_ span: String, question: String) -> Bool {
        let k = key(span)
        guard !k.isEmpty, !k.allSatisfy(\.isNumber) else { return false }
        let q = Set(key(question))
        return k.allSatisfy { q.contains($0) }
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
        var rest = Substring(p)
        while let r = rest.range(of: "最" + adj) {
            var after = rest[r.upperBound...]
            if after.hasPrefix("的") { after = after.dropFirst() }
            if words.contains(where: { after.hasPrefix($0) }) { return true }
            rest = rest[r.upperBound...]
        }
        // 「世界第一高峰」也算；完全沒講到「最高」的段落（「高山的定義是…」）不是在回答哪一個最高
        return words.contains { p.contains("第一" + adj + $0) || p.contains("第一" + adj + "的" + $0) }
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
        // 「少年維特的煩惱講了什麼」：書名是一個整體，不能從「的」切開成「少年維特」「煩惱」（講劇情的句子常常不提「煩惱」）
        if let title = Understanding.workTitle(question) {
            return covers(passage, title) && (covers(sentence, title) || plotCues.contains { sentence.contains($0) })
                && !notContent.contains { sentence.contains($0) }
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
        if ["是什麼", "是啥", "什麼意思", "是指什麼"].contains(where: { q.contains($0) }) { return ["是", "指", "稱為", "一種", "簡稱"] }
        if ["怎麼辦", "該怎麼", "怎麼處理", "建議"].contains(where: { q.contains($0) }) {
            return ["可以", "應該", "建議", "最好", "記得", "不要", "避免", "休息", "就醫", "找", "先", "試著", "緩解", "多喝", "補充水分", "多休息"]
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

    /// 頁面切成句子（去掉標題、導覽這類不是內容的）
    static func contentSentences(_ pages: [Understanding.Evidence]) -> [(text: String, host: String)] {
        var out: [(text: String, host: String)] = []
        for p in pages {
            for raw in p.text.components(separatedBy: CharacterSet(charactersIn: "。！？\n")) {
                let t = raw.trimmingCharacters(in: .whitespaces)
                if (8...160).contains(t.count), !looksLikeNoise(t) { out.append((t + "。", p.host)) }
            }
        }
        return out
    }

    static let storyCues = ["描寫", "講述", "描述", "敘述", "故事", "主角", "題材", "探討", "主題", "講的是", "寫的是", "刻畫", "內容"]
    /// 講改編（電影、歌劇）、得獎、翻譯的句子，不是在講作品本身的內容
    static let adaptation = ["電影", "導演", "上映", "歌劇", "舞台劇", "改編", "拍攝", "翻譯", "譯本", "首映", "色調", "獎", "演出", "劇場"]

    /// 一部作品在講什麼：有《書名》和「描寫、講述…」的句子，書名在句子開頭的優先（它是句子在講的東西）
    static func describe(_ title: String, in sents: [(text: String, host: String)], canQuote: (String) -> Bool = { _ in true })
        -> (text: String, host: String)? {
        let mark = "《\(title)》"
        func score(_ s: String) -> Int {
            let head = s.range(of: mark).map { s.distance(from: s.startIndex, to: $0.lowerBound) <= 12 } ?? false
            return (head ? 3 : 0) + storyCues.filter { s.contains($0) }.count
        }
        return sents.filter { s in s.text.contains(mark) && storyCues.contains { s.text.contains($0) }
            && !adaptation.contains { s.text.contains($0) } && canQuote(s.host) }
            .max { score($0.text) < score($1.text) }
    }

    /// 「X的書都講了什麼」：先找出講到他的句子裡最常被提到的作品（《書名》），再找每一部「描寫、講述…」的句子，
    /// 加上一句講他整體作品風格、主題的話。維基百科（CC BY-SA）可以引好幾句，其他網站每個只引一句
    public static func worksDigest(question: String, pages: [Understanding.Evidence]) -> String? {
        guard let m = Understanding.match(question, #"^(.{2,12}?)的(書|作品|小說|電影|歌|詩|劇)"#) else { return nil }
        let who = m[1]
        let sents = contentSentences(pages)
        var count: [String: Int] = [:]
        for s in sents where covers(s.text, who, least: true) {
            // 書名裡有他的名字（《三島由紀夫：人間四幕》）是在講他的作品，不是他寫的
            for t in titles(s.text) where !t.contains(who) && !covers(t, who) { count[t, default: 0] += 1 }
        }
        let top = count.sorted { ($0.value, -$0.key.count) > ($1.value, -$1.key.count) }.prefix(8).map(\.key)
        var quoted: [String: Int] = [:]
        func canQuote(_ h: String) -> Bool { h.contains("wikipedia.org") || (quoted[h] ?? 0) == 0 }
        var lines: [String] = []
        for t in top where lines.count < 3 {
            guard let s = describe(t, in: sents, canQuote: canQuote) else { continue }
            quoted[s.host, default: 0] += 1
            lines.append("• 《\(t)》：" + Cite.whole(s.text, host: s.host, limit: 70))
        }
        let overall = sents.first { s in covers(s.text, who) && !adaptation.contains { s.text.contains($0) } && canQuote(s.host)
            && ["作品多", "作品常", "作品大多", "風格", "主題", "擅長", "探討", "美學", "題材"].contains { s.text.contains($0) } }
        guard !lines.isEmpty || overall != nil else { return nil }
        var out: [String] = []
        if let o = overall { out.append(Cite.whole(o.text, host: o.host)) }
        if !lines.isEmpty { out.append("代表作在講什麼：\n" + lines.joined(separator: "\n")) }
        return out.joined(separator: "\n")
    }

    /// 「iPhone和安卓哪個好」：網路上很少有一句話同時把兩邊講清楚，所以分開找——各自的優缺點各找一句，
    /// 有直接比較兩邊的句子也放上，最後給一個怎麼選的判斷（不硬選邊）
    static let compareAliases: [String: [String]] = [
        "安卓": ["android"], "android": ["安卓"], "iphone": ["ios", "蘋果手機"], "ios": ["iphone"], "蘋果": ["apple", "iphone", "ios"],
        "mac": ["macos", "蘋果電腦"], "windows": ["微軟"], "pc": ["windows", "個人電腦"], "可樂": ["coca-cola"], "咖啡": ["coffee"],
    ]

    public static func compareDigest(_ a: String, _ b: String, pages: [Understanding.Evidence]) -> String? {
        let sents = contentSentences(pages)
        let judge = ["優點", "優勢", "缺點", "劣勢", "適合", "價格", "便宜", "昂貴", "安全", "流暢", "彈性", "自由", "封閉", "開放", "生態",
                     "續航", "隱私", "選擇", "好用", "穩定", "更新", "客製", "相容"]
        // 同一個東西的不同叫法（資料寫「Android」，問的是「安卓」）
        func names(_ x: String) -> [String] { [x.lowercased()] + (compareAliases[x.lowercased()] ?? []) }
        func has(_ s: String, _ x: String) -> Bool { let l = s.lowercased(); return names(x).contains { l.contains($0) } }
        func strength(_ s: String) -> Int { judge.filter { s.contains($0) }.count }
        func pick(_ x: String, _ other: String) -> (text: String, host: String)? {
            sents.filter { has($0.text, x) && !has($0.text, other) && strength($0.text) > 0 && $0.text.count <= 120 }
                .max { strength($0.text) < strength($1.text) }
        }
        let compareWords = ["比", "更", "而", "相較", "不同", "差別", "相比", "則"]
        let both = sents.filter { s in has(s.text, a) && has(s.text, b) && s.text.count <= 140
            && compareWords.contains { w in s.text.contains(w) } }
            .max { strength($0.text) < strength($1.text) }
        let pa = pick(a, b), pb = pick(b, a)
        guard both != nil || (pa != nil && pb != nil) else { return nil }
        var out = ["兩邊各有長處，關鍵是你重視什麼："]
        if let both { out.append("• 直接比較：" + Cite.whole(both.text, host: both.host, limit: 90)) }
        if let pa { out.append("• \(a)：" + Cite.whole(pa.text, host: pa.host, limit: 80)) }
        if let pb { out.append("• \(b)：" + Cite.whole(pb.text, host: pb.host, limit: 80)) }
        out.append("我的看法：沒有絕對比較好的一邊。先想清楚你最在意的是哪一點（價格、好不好上手、能不能自己調整、跟你已經有的東西合不合），照那一點選就不會後悔。")
        return out.joined(separator: "\n")
    }

    /// 作品的類別（「《X》是歌德的書信體小說」）
    static let genres = ["小說", "電影", "動畫", "影集", "電視劇", "連續劇", "漫畫", "作品", "童話", "散文", "寓言", "史詩", "戲劇", "悲劇", "喜劇",
                         "劇本", "紀錄片", "遊戲", "詩集", "繪本", "著作", "名著", "長篇", "短篇", "書"]
    /// 在講劇情的句子會有的字
    static let plotCues = ["描寫", "講述", "描述", "敘述", "故事", "主角", "主人公", "主人翁", "講的是", "寫的是", "刻畫", "劇情", "情節",
                           "愛上", "一生", "經歷", "冒險", "遭遇", "最後", "最終", "結局", "旅程", "成長", "命運", "追尋", "復仇"]
    /// 真的在說故事的字（最重要）、故事裡發生的事、只是提到劇情的字（最不重要）
    static let narrates = ["描寫", "講述", "描述", "敘述", "講的是", "寫的是", "刻畫", "講一個", "說的是"]
    static let events = ["愛上", "一生", "經歷", "冒險", "遭遇", "最後", "最終", "結局", "旅程", "成長", "命運", "追尋", "復仇", "誤闖", "相遇",
                         "自殺", "死去", "離開", "回到", "拯救", "發現", "對抗", "愛情", "友情", "謀害", "殺死", "害死", "篡", "復仇", "報仇",
                         "背叛", "逃離", "變成", "被捕", "揭發", "革命", "驅逐"]
    /// 在講主題、想表達什麼的句子會有的字
    static let themeCues = ["主題", "探討", "反映", "象徵", "批判", "諷刺", "表達了", "揭示", "寓意", "隱喻", "思考", "意義在於", "核心"]
    /// 不是在講作品內容：改編、翻譯、出版、得獎、票房、頁尾連結、寫作經過
    static let notContent = ["改編", "翻拍", "譯本", "翻譯", "譯者", "出版社", "版本", "獎", "票房", "銷量", "暢銷", "參見", "外部連結", "維基",
                             "原始文獻", "多媒體", "ISBN", "評分", "售價", "購買", "下載", "線上看", "免費", "觀看", "首映", "預告", "演員表", "配音"]
    static let backstory = ["創作", "寫成", "寫下", "完成了這", "出版", "發表", "問世", "面世", "靈感", "根據自己", "根據作者", "源自", "自身", "親身", "不同於"]
    /// 句子在講「它」（不提書名，但開頭是「小說講述…」「故事發生在…」「書中…」）
    static let referents = ["小說", "故事", "本書", "該書", "全書", "書中", "此書", "這本書", "這部", "作品", "本片", "該片", "片中", "電影", "影片",
                            "劇中", "全劇", "該劇", "本劇", "此劇", "戲劇", "這齣", "動畫", "漫畫", "主角", "主人公", "全片"]
    /// 在講怎麼看、怎麼寫，不是在講故事（「主軸描寫已經相當精采…導演的巧思」「小說的語言特色」）
    static let meta = ["觀影", "討論", "解讀", "巧思", "讀者", "觀眾", "語言特色", "寫法", "手法", "bonus", "影評", "心得", "推薦", "值得一看", "必看",
                       "我", "超展開", "必然", "趨勢", "作品發展", "表達了", "諷刺", "被視為", "禁書"]

    /// 「金閣寺在講什麼」「少年維特的煩惱講了什麼」：像人回答一樣——先說它是什麼（誰的什麼作品），再說講了什麼故事，最後說想表達什麼。
    /// 句子要在講這部作品：有書名，或出自在介紹這部作品的頁面、開頭是「小說／故事／書中…」；
    /// 改編的電影、翻譯版本、出版經過、頁尾連結都不是內容。書名不切開（「少年維特的煩惱」不是「少年維特」＋「煩惱」）
    public static func aboutWork(question: String, pages: [Understanding.Evidence]) -> String? {
        guard let title = Understanding.workTitle(question) else { return nil }
        let ct = canonText(title)
        func names(_ s: String) -> Bool { canonText(s).contains(ct) }
        struct S { let text: String; let host: String; let named: Bool; let about: Bool; let page: Int; let idx: Int }
        var sents: [S] = []
        for (pi, p) in pages.enumerated() {
            // 頁面在介紹這部作品：前面就提到書名（搜尋結果的摘要、維基百科的條目）
            let about = names(String(p.text.prefix(400)))
            for raw in p.text.components(separatedBy: CharacterSet(charactersIn: "。！？\n")) {
                let t = raw.trimmingCharacters(in: .whitespaces)
                guard (8...170).contains(t.count), !looksLikeNoise(t) else { continue }
                sents.append(S(text: t + "。", host: p.host, named: names(t), about: about, page: pi, idx: sents.count))
            }
        }
        func hits(_ s: String, _ ws: [String]) -> Int { ws.filter { s.contains($0) }.count }
        func clean(_ s: S) -> Bool {
            hits(s.text, notContent) == 0 && !(s.text.contains("《") && !s.text.contains("《\(title)》") && hits(s.text, ["電影", "歌劇", "舞台劇", "版"]) > 0)
        }
        // 沒提書名的句子：開頭就是「小說／故事／書中…」才算在講它；有別的《書名》、「這是一部…」（清單文章在介紹別部）不算
        func talksAboutIt(_ s: S) -> Bool {
            if s.named { return true }
            let others = titles(s.text).contains { canonText($0) != ct }
            return s.about && !others && referents.contains { s.text.hasPrefix($0) }
        }
        // 書店、影評、書評這類專門介紹作品的網站優先
        func pro(_ h: String) -> Int { Cite.isProfessional(h) ? 1 : 0 }
        func headed(_ s: String) -> Bool {
            guard let r = canonText(s).range(of: ct) else { return false }
            return canonText(s).distance(from: canonText(s).startIndex, to: r.lowerBound) <= 3
        }

        // ① 它是什麼：「《少年維特的煩惱》是德國作家歌德的書信體小說」
        // 一定是「《X》是…的小說／電影」這種句子：書名後面馬上接「是／為」（「《1984》曾被列為禁書」「…名言台詞金句」不算）
        func definesIt(_ t: String) -> Bool {
            let c = canonText(t)
            guard let r = c.range(of: ct) else { return false }
            let after = c[r.upperBound...].replacingOccurrences(of: #"^[》」』]?\s*(?:[（(][^）)]{0,40}[）)])?\s*(?:也稱為[^，,]{0,20}[，,])?\s*"#, with: "", options: .regularExpression)
            return after.hasPrefix("是") || after.hasPrefix("為") || after.hasPrefix("，是") || after.hasPrefix("乃")
        }
        let intro = sents.filter { s in s.named && headed(s.text) && definesIt(s.text) && hits(s.text, genres) > 0 && clean(s) && s.text.count <= 120
            && hits(s.text, ["名言", "台詞", "語錄", "金句", "禁書"] + meta) == 0 }
            .max { a, b in (pro(a.host), -a.text.count) < (pro(b.host), -b.text.count) }
        // ② 講了什麼故事
        func plotScore(_ s: S) -> Int {
            hits(s.text, narrates) * 3 + min(hits(s.text, events), 3) * 2 + hits(s.text, plotCues.filter { !narrates.contains($0) && !events.contains($0) })
                + (s.named ? 2 : 0) + pro(s.host) - hits(s.text, backstory) * 2 - hits(s.text, meta) * 3 - (s.text.count > 120 ? 1 : 0)
        }
        let plots = sents.filter { s in hits(s.text, plotCues) > 0 && clean(s) && talksAboutIt(s) && plotScore(s) > 1 }
            .sorted { plotScore($0) > plotScore($1) }
        // ③ 想表達什麼
        let theme = sents.filter { s in hits(s.text, themeCues) > 0 && clean(s) && talksAboutIt(s) && hits(s.text, backstory) == 0 }
            .max { hits($0.text, themeCues) + pro($0.host) < hits($1.text, themeCues) + pro($1.host) }

        guard !plots.isEmpty || theme != nil else { return nil }
        var used = Set<String>()
        var lines: [String] = []
        func add(_ s: S?, _ label: String, limit: Int = 110) {
            guard let s, used.insert(s.text).inserted else { return }
            // 跟已經用的句子幾乎一樣（不同網站轉貼）就不重複
            if lines.count > 0, used.contains(where: { $0 != s.text && Cite.similar($0, s.text) }) { return }
            lines.append(label + Cite.whole(s.text, host: s.host, limit: limit))
        }
        add(intro, "")
        // 跟已經說的句子講同一件事（大半的雙字詞都一樣）：不重複
        func repeats(_ s: S) -> Bool {
            let g = grams(s.text)
            return used.contains { u in Double(g.intersection(grams(u)).count) >= 0.45 * Double(max(g.count, 1)) }
        }
        // ② 故事：最好的劇情句，像人一樣往下讀（後來發生的事接著說）；整理成一段自己的話，不是一句一句貼
        var story: [S] = []
        if let p = plots.first {
            story.append(p)
            used.insert(p.text)
            let next = sents.filter { $0.page == p.page && $0.idx > p.idx && $0.idx <= p.idx + 2 }
            for more in next where hits(more.text, events) > 0 && clean(more) && hits(more.text, backstory) + hits(more.text, meta) == 0 && !repeats(more) {
                story.append(more); used.insert(more.text)
            }
            // 別的網站的說法是另一種講法，不是「後來發生的事」：不接在一起（使用者也覺得重複多餘）
            let told = WorkView.story(story.map(\.text), title: title, events: events)
            let hosts = story.map(\.host).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            if !told.isEmpty { lines.append("📖 故事：" + told + "（" + hosts.joined(separator: "、") + "）") }
            else { for s in story { lines.append("📖 " + Cite.whole(s.text, host: s.host, limit: 110)) } }
        }
        // ③ 主題：從講這部作品的句子找根據，用自己的話解釋（不是只貼一句「象徵」）
        // 判斷主題時，所有在講劇情的句子都算（別的網站的劇情句不放進「故事」，但它講到的「父母貪吃變成豬」還是根據）
        var plotTexts = story.map(\.text)
        for p in plots.prefix(4) where !plotTexts.contains(p.text) { plotTexts.append(p.text) }
        // 在介紹這部作品的頁面上，講主題的句子常常不提書名：整頁都算（有別的《書名》的句子除外）
        let onPage = sents.filter { s in (s.about || s.named) && clean(s) && !titles(s.text).contains { canonText($0) != ct } }
        let found = WorkView.found(in: onPage.map(\.text), plot: plotTexts, title: title)
        let picked = WorkView.strong(found)
        if picked.isEmpty {
            add(theme, "💡 想表達的：")
        } else {
            lines.append("💡 主題：")
            for f in picked {
                let host = onPage.first { $0.text == f.evidence }?.host ?? story.first { $0.text == f.evidence }?.host ?? ""
                let ev = f.evidence.isEmpty || story.contains { $0.text == f.evidence } ? "" : "（資料：" + Cite.whole(f.evidence, host: host, limit: 45) + "）"
                lines.append("• \(f.theme.name)：\(f.theme.explain)" + ev)
            }
            // ④ 我的看法：有明確的立場，不是「各有說法」
            // 這本書／這部片／這部劇：看問題和介紹句怎麼說
            let said = question + (intro?.text ?? "")
            let medium = ["電影", "動畫", "影集", "影片", "電視劇", "這部片"].contains { said.contains($0) } ? "這部片"
                : ["戲劇", "劇本", "舞台劇"].contains { said.contains($0) } ? "這齣戲"
                : ["小說", "書", "童話", "寓言", "散文", "詩"].contains { said.contains($0) } ? "這本書" : "這部作品"
            lines.append("🧠 我的看法：" + WorkView.opinion(title: title, medium: medium, picked: picked.map(\.theme)))
        }
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
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
            guard l.count >= 8, !looksLikeNoise(l) else { continue }
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

    /// explain：要一段說明（整句）而不是幾個字；沒指定時看問題的說法（在講什麼、怎麼辦、為什麼…）
    public static func conclude(question: String, pages: [Understanding.Evidence], snippets: [Understanding.Evidence],
                                brain: Brain, budget: Int = 40, accept: ((String) -> Bool)? = nil, explain: Bool? = nil) -> Conclusion? {
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
        let texts = chosen.map(\.text)
        for c in chosen {
            // accept：答案要像這題要的東西（問距離要有數字和單位……），不像的不算
            if let sp = brain.read(question: question, passage: c.text).map({ withWholeName($0, texts) }), accept?(sp.text) ?? true, !junk(sp.text),
               !echoes(sp.text, question: question), superlativeFits(question: question, passage: c.text) {
                all.append(Reading(passage: c.text, host: c.host, span: sp))
            }
        }
        // 哪些段落算「在回答問題」：大腦有把握的（分數 > 0），或是明顯比其他段落高、又不會低得離譜的
        // （描述型的問題「他的書在講什麼」，相關段落常是 -3，不相關的是 -10 以下）
        let bestScore = all.map(\.span.score).max() ?? -100
        let floor: Float = -6

        // 要一段說明的題目（在講什麼、怎麼辦、為什麼）：不切幾個字當答案，給最在回答問題的整句話（每個網站一句、最多兩句）
        if explain ?? wantsSentences(question) {
            func rank(_ r: Reading) -> Float { (r.span.main >= 0 ? r.span.main * 10 : 0) + r.span.score * 0.3 }
            let pool = all.filter { $0.span.main < 0 || $0.span.none < 0.5 }.sorted { rank($0) > rank($1) }
            var lines: [String] = []
            var usedHosts = Set<String>()
            var shownFrom: [Reading] = []
            // 先找有「講述、描寫」「因為」「可以、建議」這類字的句子（真的在說明），一句都沒有才放寬
            let want = cues(question)
            // 作品在講什麼：一定要是講內容的句子，找不到寧可說沒找到，不拿頁尾、出版資料湊
            let strict = Understanding.workTitle(question) != nil
            for needCue in (want.isEmpty ? [false] : strict ? [true] : [true, false]) where lines.isEmpty {
                for r in pool where lines.count < 2 {
                    guard r.span.main < 0 ? r.span.score > floor : r.span.main >= 0.35 else { continue }
                    let s = sentence(around: r.span, in: r.passage)
                    // 「不表示…便可以治療感冒」是在說不行，不是建議
                    let denies = ["不表示", "並不代表", "不代表", "並不能", "不能用來"].contains { s.contains($0) }
                    guard s.count >= 8, !looksLikeNoise(s), !needCue || (want.contains(where: { s.contains($0) }) && !denies),
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
