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

    /// 「格林童話有什麼故事」「宮崎駿有哪些作品」：問的是一份清單——像人一樣，先說它是什麼，
    /// 再列出網頁上最常被提到的幾個（《書名》、、分開的名字），每一個說它在講什麼，最後說自己的看法
    /// subject：規則認不出這種問法、但理解問題的模型判斷是在問清單時，用問題的主題
    public static func itemsDigest(question: String, pages: [Understanding.Evidence], subject fallback: String? = nil) -> String? {
        guard let ask = Understanding.itemsAsk(question) ?? fallback.map({ (subject: $0, kind: "") }), ask.subject.count >= 2 else { return nil }
        let subject = ask.subject
        let sents = contentSentences(pages)
        var count: [String: Int] = [:]
        for s in sents where covers(s.text, subject, least: true) {
            for t in titles(s.text) where !covers(t, subject) && !subject.contains(t) && t.count <= 12 { count[t, default: 0] += 1 }
        }
        // 名字也常常寫成「灰姑娘、白雪公主、小紅帽」：跟主題同一句、用頓號分開的短名字
        for s in sents where covers(s.text, subject, least: true) && !s.text.contains("《") {
            let parts = s.text.components(separatedBy: "、")
            guard parts.count >= 3 else { continue }
            for (i, p) in parts.enumerated() {
                var name = p
                if i == 0 { name = String(p.split(whereSeparator: { "，：:是有如像".contains($0) }).last ?? Substring(p)) }
                if i == parts.count - 1 { name = String(p.split(whereSeparator: { "，。等和及".contains($0) }).first ?? Substring(p)) }
                name = name.trimmingCharacters(in: .whitespaces)
                if (2...8).contains(name.count), !covers(name, subject) { count[name, default: 0] += 1 }
            }
        }
        let top = count.filter { $0.value >= 1 }.sorted { ($0.value, -$0.key.count) > ($1.value, -$1.key.count) }.prefix(6).map(\.key)
        guard top.count >= 2 else { return nil }
        // 這個寫法（《書名》、各在講什麼、「我會先看」）只適合作品集。「發達國家有哪些」「貓有哪些品種」問的是一般的名單：
        // 主題不像作品、名字也不是用《》寫的，就交給一般的名單整理（不加書名號、不說「我會先看《希臘》」）
        let workWords = ["故事", "童話", "寓言", "神話", "作品", "代表作", "名作", "經典", "書", "小說", "詩", "詞", "散文", "電影", "影集", "劇",
                         "動畫", "漫畫", "歌", "專輯", "曲", "畫", "全集", "選集", "集", "名著", "文章", "篇"]
        let titled = top.filter { t in sents.contains { $0.text.contains("《\(t)》") } }.count
        guard titled * 2 >= top.count || workWords.contains(where: { subject.contains($0) || ask.kind.contains($0) }) else { return nil }
        var lines: [String] = []
        // 它是什麼（有幾個也一起說）
        if let intro = sents.first(where: { s in s.text.hasPrefix("《\(subject)》") || s.text.hasPrefix(subject) }), intro.text.count <= 110,
           ["是", "收錄", "共", "約有", "包含"].contains(where: { intro.text.contains($0) }) {
            lines.append(Cite.whole(intro.text, host: intro.host))
        }
        let what = ask.kind.isEmpty ? "幾個" : "幾個" + ask.kind
        lines.append("📚 最常被提到的\(what)：")
        var described = 0
        for t in top {
            // 每一個說它在講什麼：有《書名》、有講故事的字的句子
            let d = describe(t, in: sents) ?? sents.first { s in s.text.contains(t) && narrates.contains { s.text.contains($0) } && !adaptation.contains { s.text.contains($0) } }
            if let d, described < 4 {
                described += 1
                var body = d.text
                for pre in ["《\(t)》", t] where body.hasPrefix(pre) { body = String(body.dropFirst(pre.count)) }
                body = body.trimmingCharacters(in: CharacterSet(charactersIn: "：:，, "))
                lines.append("• 《\(t)》：" + WebSearch.clip(body, 60) + "（\(d.host)）")
            } else {
                lines.append("• 《\(t)》")
            }
        }
        // 我的看法：這些故事共同在講什麼
        let found = WorkView.found(in: sents.filter { s in top.contains { s.text.contains($0) } }.map(\.text), plot: [], title: subject)
        let picked = WorkView.strong(found)
        if !picked.isEmpty {
            lines.append("🧠 我的看法：" + WorkView.opinion(title: subject, medium: "這些作品", picked: picked.map(\.theme)))
        } else {
            lines.append("🧠 我的看法：如果只挑一個開始，我會先看《\(top[0])》——它是最常被提到的，通常也最能代表\(subject)的味道。")
        }
        return lines.joined(separator: "\n")
    }

    /// 一般的「有哪些」名單（國家、水果、程式語言、品種……）：從講到主題的句子裡，把「、」分開的短名字拿出來，
    /// 看有幾個不同的句子、網站都提到，最常被提到的排前面；問國家、品種的話只留真的是國家、品種的項目。
    /// 不加《》、不說「我會先看」（那是作品集的寫法）
    /// 「七大洲」→ 7、「世界三大宗教」→ 3、「四大名著」→ 4、「十二生肖」→ 12：主題自己說的數目
    static func expectedCount(_ subject: String) -> Int? {
        // 數字後面接「大／個／種／國」（七大洲、北歐五國），或主題開頭就是中文數字（十二生肖）；「iPhone 17」的 17 不是數目
        guard let m = Understanding.match(subject, #"([一二三四五六七八九十兩]{1,3}|\d{1,2})(?:大|個|種|國)"#)
                ?? Understanding.match(subject, #"^([一二三四五六七八九十]{1,3})\p{Han}"#) else { return nil }
        let n = Int(m[1]) ?? Understanding.smallNumber(m[1])
        return n.flatMap { (2...30).contains($0) ? $0 : nil }
    }

    /// 「常見的貓品種」「狗的品種」→ 貓、狗
    public static func breedAnimal(_ subject: String) -> String? {
        Understanding.match(subject, #"^(?:常見的?|有名的?|熱門的?|台灣的?)?(\p{Han}{1,2})的?(?:品種|品系)$"#)?[1]
    }

    /// 是不是一個品種的名字：要是「…貓」「…犬」，而且不是體型、用途、年紀（小型犬、導盲犬、幼犬不是品種）
    public static func isBreed(_ x: String, tail: [String]) -> Bool {
        guard x.count > tail[0].count, tail.contains(where: { x.hasSuffix($0) }) else { return false }
        let kinds = ["小型", "中型", "大型", "超大型", "迷你", "導盲", "搜救", "工作", "警", "軍", "寵物", "幼", "成", "老", "流浪", "家", "野", "公", "母",
                     "長毛", "短毛", "純種", "混種", "米克斯", "名", "獵", "牧羊", "看門", "護衛", "伴侶", "療癒", "聰明", "好養", "安靜", "黏人"]
        let body = String(x.dropLast(tail.first { x.hasSuffix($0) }!.count))
        return !kinds.contains(body) && !(body.count <= 2 && kinds.contains { body.hasPrefix($0) })
    }

    /// 最近一次 plainList 整理出的名單（給呼叫的地方和別的方法比較）
    nonisolated(unsafe) static var lastItems: [String] = []

    public static func plainList(question: String, pages: [Understanding.Evidence], subject: String, noun: String) -> String? {
        let subj = subject.trimmingCharacters(in: .whitespaces)
        guard !subj.isEmpty else { return nil }
        // 「狗」「貓」這種一個字的主題：covers 對一個字永遠成立，改成看有沒有這個字
        func about(_ text: String) -> Bool { subj.count >= 2 ? covers(text, subj, least: true) : text.contains(subj) }
        func isSubject(_ x: String) -> Bool { subj.count >= 2 ? covers(x, subj) : x == subj }
        // 名單常在很長的一句裡（「七大洲是…，即亞洲（Asia）、歐洲（Europe）、…」）：不用一般的 160 字上限
        var sents: [(text: String, host: String)] = []
        for p in pages {
            for raw in p.text.components(separatedBy: CharacterSet(charactersIn: "。！？\n")) {
                let t = raw.trimmingCharacters(in: .whitespaces)
                if (8...600).contains(t.count), !looksLikeNoise(t) { sents.append((t, p.host)) }
            }
        }
        let countryList = Countries.isCountryNoun(noun) || Countries.isCountryNoun(subj) || subj.hasSuffix("國")
        // 「貓有哪些品種」（主題貓、名詞品種），或「常見的貓品種有哪些」（品種寫在主題裡）：品種名都是「…貓」「…犬」
        var animal: String? = ["品種", "種類", "品系"].contains(noun) && (1...2).contains(subj.count) ? subj : nil
        if animal == nil { animal = breedAnimal(subj) }
        // 狗的品種常常不帶「犬」（柯基、貴賓、拉布拉多），不能要求字尾；只拿掉體型、用途（小型犬、導盲犬）
        let dog = animal.map { ["狗", "犬"].contains($0) } ?? false
        let breedTail: [String]? = dog ? nil : animal.map { [String($0.last!)] }
        func fits(_ x: String) -> Bool {
            if countryList { return Countries.canonical(x) != nil }
            if let breedTail { return isBreed(x, tail: breedTail) }
            return true
        }
        let typed = countryList || breedTail != nil
        var count: [String: Int] = [:], hostsOf: [String: Set<String>] = [:], order: [String] = []
        var runs: [(items: [String], host: String, about: Bool)] = []
        var negative: [String: Int] = [:]
        let core = noun.isEmpty ? subj : noun
        var seenSent = Set<String>()
        var counted: [(items: [String], host: String)] = []
        // 括號裡的名單（「由11個獨立國家（汶萊、緬甸、柬埔寨…）組成」）也拿出來當一句看，前面接著括號前的話（知道有幾個）
        var expanded: [(text: String, host: String)] = []
        for s in sents {
            expanded.append(s)
            guard let re = try? NSRegularExpression(pattern: #"[（(]([^（）()]*、[^（）()]*、[^（）()]*)[）)]"#) else { continue }
            let ns = s.text as NSString
            for m in re.matches(in: s.text, range: NSRange(location: 0, length: ns.length)) {
                let before = ns.substring(to: m.range.location)
                expanded.append((String(before.suffix(30)) + "：" + ns.substring(with: m.range(at: 1)), s.host))
            }
        }
        for s in expanded where about(s.text) || s.text.contains(core) {
            // 同一頁重複出現的同一句話（導覽、摘要又印一次）只算一次
            guard seenSent.insert(s.host + "|" + s.text).inserted else { continue }
            let body = s.text.replacingOccurrences(of: #"（[^）]*）|\([^)]*\)|[「」『』《》]"#, with: "", options: .regularExpression)
            let parts = body.components(separatedBy: "、")
            guard parts.count >= (typed ? 2 : 3) else { continue }
            var names: [String] = []
            for (i, p) in parts.enumerated() {
                var cands = [p]
                if i == 0 {
                    var f = String(p.split(whereSeparator: { "，,：:；是有如像即為".contains($0) }).last ?? Substring(p))
                    for w in ["包含", "包括", "例如", "比如", "像是", "譬如", "其中", "分別", "主要", "常見"] {
                        if let r = f.range(of: w, options: .backwards) { f = String(f[r.upperBound...]) }
                    }
                    cands = [f]
                }
                if i == parts.count - 1 {
                    var l = String(p.split(whereSeparator: { "，,。；等".contains($0) }).first ?? Substring(p))
                    l = Understanding.cutVerbTail(l)
                    if let r = l.range(of: "以及") ?? l.range(of: "和") ?? l.range(of: "及") ?? l.range(of: "與"),
                       l.distance(from: l.startIndex, to: r.lowerBound) >= 1, l.distance(from: r.upperBound, to: l.endIndex) >= 1 {
                        cands = [String(l[..<r.lowerBound]), String(l[r.upperBound...])]
                    } else { cands = [l] }
                }
                let shortRun = parts.count >= 5 && parts.filter { $0.trimmingCharacters(in: .whitespaces).count <= 2 }.count * 10 >= parts.count * 6
                for c in cands {
                    let c1 = c.trimmingCharacters(in: .whitespaces)
                    if shortRun, c1.count == 1, c1.unicodeScalars.first?.properties.isIdeographic == true, !typed, !"等和及與的是有".contains(c1) {
                        if !names.contains(c1) { names.append(c1) }
                        continue
                    }
                    // 正式國名可能很長（「大不列顛及北愛爾蘭聯合王國」13 個字）：問國家時先對國名表
                    if countryList, let cc = Countries.canonical(c1) {
                        if !names.contains(cc) { names.append(cc) }
                        continue
                    }
                    guard let it = Understanding.item(c1), !isSubject(it), it != noun, fits(it),
                          !["情況", "資訊", "介紹", "排名", "列表", "名單", "比較", "推薦", "整理", "一覽", "時間", "長度", "日期", "價格", "查證", "說明", "備註", "來源", "版本"].contains(where: { it.contains($0) }),
                          // 「葉菜類、根莖類」是分類，不是一樣一樣的東西（問「有哪些種類」時才要）
                          !(it.hasSuffix("類") && !(noun + subj).contains("類")),
                          !(dog && (it.hasSuffix("犬") || it.hasSuffix("狗")) && !isBreed(it, tail: ["犬", "狗"])),
                          // 問城市：海、海峽、灣、河是地形，不是城市（「西隔東海、黃海、朝鮮海峽」）
                          !((noun + subj).contains("城市") && ["海", "峽", "灣", "洋", "河", "江", "山脈", "島"].contains(where: { it.hasSuffix($0) })) else { continue }
                    let name = countryList ? (Countries.canonical(it) ?? it) : it
                    if !names.contains(name) { names.append(name) }
                }
            }
            guard names.count >= (typed ? 2 : 3) else { continue }
            // 問品種：講毛色、花色的一串（「橘貓、虎斑貓、賓士貓」）是顏色，不是品種
            if breedTail != nil, ["毛色", "花色", "顏色", "米克斯", "混種"].contains(where: { s.text.contains($0) }) { continue }
            // 在講原因的一串（「其中六個由於地震、火災、戰爭而毀壞」）不是名單
            if ["由於", "因為", "原因", "導致", "造成", "毀於"].contains(where: { s.text.contains($0) }) { continue }
            // 反過來想：句子說的是「不是」「候選」「想加入」（「歐盟候選國包括冰島、土耳其…」「日本、印度爭取入常」），
            // 這些名字恰恰不是答案——記下來，除非別的句子明確把它列進去，不然拿掉
            // 講歷史的一串（「1945 年創始時是中華民國、法國、英國、美國和蘇聯」）也不是現在的答案
            if ["候選", "申請加入", "想加入", "希望加入", "尚未", "還不是", "不是", "非成員", "退出", "脫離", "脫歐", "爭取", "觀察員", "前成員",
                "蘇聯", "蘇維埃", "1945", "創始", "當時", "曾是", "曾經", "原本是", "被取代",
                // 想加入的（「四國入常」「擴容」「草案」）
                "入常", "擴容", "四國集團", "草案", "要求增加"].contains(where: { s.text.contains($0) })
                // 殖民過這裡的（「曾被葡萄牙、西班牙、荷蘭殖民」）：名字緊接在「被」後面才算；「泰國是唯一沒有被殖民的」不算
                // 講殖民、侵略的一串（「歐洲列強，特別是葡萄牙、西班牙、荷蘭…開始殖民東南亞」）：這些是外來的國家，不是這個地區的
                || ["殖民", "列強", "侵略", "入侵", "佔領", "占領"].contains(where: { s.text.contains($0) }) {
                for n in names { negative[n, default: 0] += 1 }
                continue
            }
            runs.append((names, s.host, subj.count >= 2 ? covers(s.text, subj) : s.text.contains(subj)))
            // 句子自己說有幾個（「由11個獨立國家…組成」），列出來的剛好那麼多：最可信
            if let m = Understanding.match(s.text, #"([0-9]{1,2}|[一二三四五六七八九十兩]{1,3})(?:個|國|大)"#),
               let n = Int(m[1]) ?? Understanding.smallNumber(m[1]), n == names.count, n >= 3,
               // 那句話要在講問的東西（「台灣的四大族群」不是在講直轄市）
               noun.isEmpty ? (subj.count >= 2 && s.text.contains(subj)) : s.text.contains(noun) {
                counted.append((names, s.host))
            }
            for n in names {
                count[n, default: 0] += 1
                hostsOf[n, default: []].insert(s.host)
                if !order.contains(n) { order.append(n) }
            }
        }
        Understanding.lastListDebug = "plain runs=" + runs.map { "\($0.host):\($0.items.joined(separator: "/"))" }.joined(separator: " | ") + " neg=\(negative)"
        guard !runs.isEmpty else { return nil }
        if let c = counted.first {
            lastItems = c.items
            let hosts = Array(Set(counted.filter { $0.items == c.items }.map(\.host))).sorted()
            return "\(subj)\(noun.isEmpty || subj.hasSuffix(noun) || noun == "國家" && subj.hasSuffix("國") ? "" : "的" + noun)一共 \(c.items.count) 個：\n" + Countries.lines(c.items)
                + "\n（資料自己寫了有 \(c.items.count) 個，列出來的也剛好這麼多；整理自 " + hosts.joined(separator: "、") + "）"
        }
        // 主題自己說了有幾個（「七大洲」「世界三大宗教」「四大名著」）：剛好列出那麼多個的那一串最可信——
        // 只找到六個就再找找看有沒有七個的那句，不要少一個
        if let want = expectedCount(subj), let exact = runs.first(where: { $0.items.count == want }) {
            let hosts = Array(Set(runs.filter { $0.items == exact.items }.map(\.host))).sorted()
            lastItems = exact.items
            return "\(subj)是：\n" + Countries.lines(exact.items) + "\n（一共 \(want) 個，跟「\(subj)」的數目對得上；整理自 " + hosts.joined(separator: "、") + "）"
        }
        func rank(_ a: String, _ b: String) -> Bool {
            let ca = count[a] ?? 0, cb = count[b] ?? 0
            return ca != cb ? ca > cb : (order.firstIndex(of: a) ?? 0) < (order.firstIndex(of: b) ?? 0)
        }
        var items: [String]
        let agreed = order.filter { (count[$0] ?? 0) >= 2 }
        if typed {
            items = order.sorted(by: rank)
        } else if agreed.count >= 4 {
            // 好幾個句子都提到的才算（網頁上一次性的雜字不會被重複提到）；再補上講主題最完整的那一串裡的（「Python」可能只在一句裡）
            items = agreed.sorted(by: rank)
            if let best = runs.filter({ $0.about }).max(by: { $0.items.count < $1.items.count }) {
                for x in best.items where !items.contains(x) && items.count < 12 { items.append(x) }
            }
        } else if let best = runs.filter({ $0.about }).max(by: { $0.items.count < $1.items.count }) ?? runs.max(by: { $0.items.count < $1.items.count }),
                  best.items.count >= 4 {
            items = best.items
        } else { return nil }
        // 反面的句子裡出現得比正面多、而且正面也很少被提到的才拿掉（法國、英國在憲章的舊名單裡也有，但正面被提到很多次，留著）
        let topCount = items.first.flatMap { count[$0] } ?? 0
        items = items.filter { x in
            let c = count[x] ?? 0, n = negative[x] ?? 0
            return !(n >= c && c * 2 < topCount) && c > 0
        }
        // 只被提到一兩次、遠比前面的少的（「安理會常任理事國」的句子順便提到日本、印度想入常）：拿掉
        if !typed, let top = items.first.flatMap({ count[$0] }), top >= 3 {
            let floor = Int((Double(top) * 0.4).rounded(.up))
            let kept = items.filter { (count[$0] ?? 0) >= floor }
            if kept.count >= 3 { items = kept }
        }
        // 同一個東西的兩種寫法（「台北」和「臺北市」）：只留一個（留完整的那個）
        func norm(_ x: String) -> String { x.replacingOccurrences(of: "臺", with: "台") }
        var merged: [String] = []
        for x in items {
            let nx = norm(x)
            if let i = merged.firstIndex(where: { let m = norm($0); return m == nx || m.hasPrefix(nx) && m.count == nx.count + 1 || nx.hasPrefix(m) && nx.count == m.count + 1 }) {
                if x.count > merged[i].count { merged[i] = x }
            } else { merged.append(x) }
        }
        items = merged
        // 大部分名字都是同一個字結尾（臺北市、新北市…；基督教、佛教…）：不是這樣結尾的多半是雜字（「文化」）
        if !typed, items.count >= 4, let tail = items.compactMap({ $0.last }).mostCommon(), items.filter({ $0.last == tail }).count * 10 >= items.count * 6 {
            items = items.filter { $0.last == tail }
        }
        guard items.count >= (typed ? 3 : 4) else { return nil }
        items = Array(items.prefix(countryList ? 60 : 16))
        lastItems = items
        let hosts = Array(Set(items.prefix(8).flatMap { hostsOf[$0] ?? [] })).sorted().prefix(3)
        // 「常見的熱帶水果」＋「熱帶水果」不要說成「常見的熱帶水果的熱帶水果」
        let what = noun.isEmpty || subj.hasSuffix(noun) || noun == "國家" && subj.hasSuffix("國") ? subj : subj + "的" + noun
        let head = items.count >= 10 && countryList ? "一共找到 \(items.count) 個\(noun.isEmpty ? "國家" : noun)：" : "\(what)，常見的有這些（越多網站提到的排越前面）："
        return head + "\n" + Countries.lines(items) + "\n（整理自 " + hosts.joined(separator: "、") + "；不一定是全部）"
    }

    /// 產品類的名單（AI 模型、手機、晶片、遊戲……）：網頁上「聚合 ARC-AGI-2、HLE、編程榜」這種一串是評測項目，不是產品。
    /// 怎麼認：看上下文——緊接在「發布／推出／上線／釋出／開源」後面的名字，或後面接著「模型／手機…」的名字，才是在講一個產品；
    /// 產品名通常有版本號（GPT-6、Gemini 3.8）或好幾個字（Claude Fable），只有「AI」「API」「Google」這種一個詞的是統稱或公司
    static let productNouns = ["模型", "大模型", "手機", "晶片", "顯卡", "遊戲", "產品", "app", "App", "車款", "電動車", "筆電", "相機", "耳機", "手錶", "平板"]

    public static func isProductNoun(_ noun: String) -> Bool { productNouns.contains { noun.contains($0) } }

    public static func releases(pages: [Understanding.Evidence], noun: String) -> (items: [String], hosts: [String])? {
        let head = productNouns.first { noun.contains($0) } ?? noun
        let name = #"([A-Za-z][A-Za-z0-9\.\-]*(?: [A-Za-z0-9][A-Za-z0-9\.\-]*){0,3})"#
        let pats = [#"(?:發布|發佈|推出|上線|釋出|開源|亮相|登場|升級到|更新到|迎來)(?:了|全新的?|新一代的?|最新的?)?\s*"# + name,
                    name + #"\s*(?:這款|這個)?\s*(?:"# + NSRegularExpression.escapedPattern(for: head) + "|大模型|模型)"]
        let generic: Set<String> = ["ai", "api", "llm", "gpu", "cpu", "app", "ios", "android", "ai 模型", "chatbot", "agent", "sota", "pro", "new", "the"]
        var count: [String: Int] = [:], hostsOf: [String: Set<String>] = [:], order: [String] = []
        for p in pages {
            var seen = Set<String>()
            for pat in pats {
                guard let re = try? NSRegularExpression(pattern: pat) else { continue }
                let ns = p.text as NSString
                for m in re.matches(in: p.text, range: NSRange(location: 0, length: ns.length)) {
                    var n = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                    // 句子接著的英文字不是名字的一部分（「GPT-6 Astra and」）
                    n = n.replacingOccurrences(of: #"\s+(and|or|with|to|for|in|on|is|the|vs)\b.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
                    while let l = n.last, ".-".contains(l) { n.removeLast() }
                    let low = n.lowercased()
                    guard n.count >= 3, n.count <= 30, !generic.contains(low),
                          n.contains(where: \.isNumber) || n.split(separator: " ").count >= 2 else { continue }
                    // 「ARC-AGI-2」「HLE」「MMLU」這種全大寫的評測代號，或明說是榜、測試的，不是產品
                    let letters = n.filter(\.isLetter)
                    if letters.count >= 3 && letters == letters.uppercased() && !n.contains(" ") && n.filter(\.isNumber).count <= 1 && !low.hasPrefix("gpt") { continue }
                    guard seen.insert(low).inserted else { continue }
                    count[n, default: 0] += 1
                    hostsOf[n, default: []].insert(p.host)
                    if !order.contains(n) { order.append(n) }
                }
            }
        }
        // 同一個產品的短名字被長名字包含（「Gemini 3.8」和「Gemini 3.8 Flash」）：留長的、票數加總
        var items = order
        // 「Gemini 3」被「Gemini 3.8 Flash」包含、「Claude Fable 5」被「Claude Fable 5.1」包含：是同一個系列被截斷，留完整的
        for a in order { for b in order where b != a && b.hasPrefix(a) && (b.count > a.count) {
            let next = b[b.index(b.startIndex, offsetBy: a.count)]
            if next == " " || next == "." || next.isNumber { count[b, default: 0] += count[a] ?? 0; items.removeAll { $0 == a } }
        } }
        items.sort { (count[$0] ?? 0, -(order.firstIndex(of: $0) ?? 0)) > (count[$1] ?? 0, -(order.firstIndex(of: $1) ?? 0)) }
        guard items.count >= 3 else { return nil }
        let hosts = Array(Set(items.prefix(8).flatMap { hostsOf[$0] ?? [] })).sorted()
        return (Array(items.prefix(12)), Array(hosts.prefix(3)))
    }

    /// 「相對論是誰提出的」「微軟是誰創立的」：找緊接在動詞前面的名字（「愛因斯坦提出相對論」「由比爾·蓋茲創立」），
    /// 看有幾句都這樣說；職稱（物理學家、工程師）拿掉
    public static func whoDid(question: String, pages: [Understanding.Evidence], subject: String) -> String? {
        guard let m = Understanding.match(question.replacingOccurrences(of: " ", with: ""), #"是誰(創立|創辦|發明|發現|寫|畫|設計|建立|提出|導演|唱|作曲|成立)"#) else { return nil }
        let verb = m[1]
        let verbs = verb == "創立" || verb == "創辦" || verb == "成立" || verb == "建立" ? "(?:創立|創辦|成立|創建|建立)" : "(?:" + verb + ")"
        let subj = subject.trimmingCharacters(in: .whitespaces)
        guard subj.count >= 2 else { return nil }
        let pats = [#"由([\p{Han}·．A-Za-z ]{2,14}?)(?:於[^，。]{1,12})?(?:共同|所|一起)?"# + verbs,
                    #"([\p{Han}·．]{2,10})(?:在|於)?(?:\d{4}年)?(?:首先|最早|共同|一起)?"# + verbs,
                    #"(?:創辦人|創始人|發明者|發明人|提出者|作者|發現者)(?:是|為|：|:)?\s*([\p{Han}·．]{2,6})"#]
        let titles = ["好友", "朋友", "同學", "夥伴", "合夥人", "創辦人", "創始人", "物理學家", "科學家", "數學家", "化學家", "生物學家", "發明家", "企業家", "工程師", "作家", "學家", "家", "者", "師", "人", "年", "後來", "當年", "最初", "首先"]
        let bad = ["的", "是", "了", "被", "這", "那", "一", "們", "該", "公司", "團隊", "政府", "共同", "它", "他", "她", "所", "其"]
        var votes: [String: Int] = [:], quote: [String: (String, String)] = [:]
        for p in pages {
            for raw in p.text.components(separatedBy: CharacterSet(charactersIn: "。！？\n")) where raw.contains(subj) && raw.count <= 220 {
                var seen = Set<String>()
                for pat in pats {
                    guard let re = try? NSRegularExpression(pattern: pat) else { continue }
                    let ns = raw as NSString
                    for mm in re.matches(in: raw, range: NSRange(location: 0, length: ns.length)) {
                        var n = ns.substring(with: mm.range(at: 1)).trimmingCharacters(in: .whitespaces)
                        // 「美國物理學家愛因斯坦」→「愛因斯坦」：取最後一個職稱後面的部分
                        for t in titles { if let r = n.range(of: t, options: .backwards), r.upperBound < n.endIndex, n.distance(from: r.upperBound, to: n.endIndex) >= 2 { n = String(n[r.upperBound...]) } }
                        // 「比爾·蓋茲與保羅·艾倫」：兩個人都算
                        for one in n.components(separatedBy: CharacterSet(charactersIn: "與和及、")) {
                            let x = one.trimmingCharacters(in: .whitespaces)
                            guard (2...12).contains(x.count), !x.contains(subj), !subj.contains(x), !bad.contains(where: { x.contains($0) }),
                                  seen.insert(x).inserted else { continue }
                            votes[x, default: 0] += 1
                            if quote[x] == nil { quote[x] = (raw.trimmingCharacters(in: .whitespaces), p.host) }
                        }
                    }
                }
            }
        }
        let ranked = votes.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.count > $1.key.count }
        guard let top = ranked.first, top.value >= 2 || ranked.count == 1 else { return nil }
        // 一起創立的（票數接近的第二個人）也說出來
        var names = [top.key]
        if ranked.count >= 2, ranked[1].value * 2 >= top.value, ranked[1].value >= 2 { names.append(ranked[1].key) }
        let q = quote[top.key]!
        return "答案：\(names.joined(separator: "、"))（\(top.value) 個地方這樣說）。\n依據：" + Cite.whole(q.0, host: q.1)
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
    static let notContent = ["改編", "翻拍", "以原著", "原創內容", "真人版", "外傳", "番外", "衍生", "譯本", "翻譯", "譯者", "出版社", "版本", "獎", "票房", "銷量", "暢銷", "參見", "外部連結", "維基",
                             "原始文獻", "多媒體", "ISBN", "評分", "售價", "購買", "下載", "線上看", "免費", "觀看", "首映", "預告", "演員表", "配音"]
    static let backstory = ["創作", "寫成", "寫下", "完成了這", "出版", "發表", "問世", "面世", "靈感", "根據自己", "根據作者", "源自", "自身", "親身", "不同於",
                            "結合自己", "自己的經歷", "自己刻骨", "作者的", "她的人生", "他的人生", "初戀經歷"]
    /// 句子在講「它」（不提書名，但開頭是「小說講述…」「故事發生在…」「書中…」）
    static let referents = ["小說", "故事", "本書", "該書", "全書", "書中", "此書", "這本書", "這部", "作品", "本片", "該片", "片中", "電影", "影片",
                            "劇中", "全劇", "該劇", "本劇", "此劇", "戲劇", "這齣", "動畫", "漫畫", "主角", "主人公", "全片"]
    /// 在講怎麼看、怎麼寫，不是在講故事（「主軸描寫已經相當精采…導演的巧思」「小說的語言特色」）
    static let meta = ["觀影", "討論", "解讀", "巧思", "讀者", "觀眾", "語言特色", "寫法", "手法", "bonus", "影評", "心得", "推薦", "值得一看", "必看",
                       "我", "超展開", "必然", "趨勢", "作品發展", "表達了", "諷刺", "被視為", "禁書"]

    /// 「金閣寺在講什麼」「少年維特的煩惱講了什麼」：像人回答一樣——先說它是什麼（誰的什麼作品），再說講了什麼故事，最後說想表達什麼。
    /// 句子要在講這部作品：有書名，或出自在介紹這部作品的頁面、開頭是「小說／故事／書中…」；
    /// 改編的電影、翻譯版本、出版經過、頁尾連結都不是內容。書名不切開（「少年維特的煩惱」不是「少年維特」＋「煩惱」）
    /// subject：規則認不出這種問法（「X到底在演什麼」）、但理解問題的模型判斷是在問內容時，用問題的主題
    public static func aboutWork(question: String, pages: [Understanding.Evidence], subject fallback: String? = nil) -> String? {
        guard let title = Understanding.workTitle(question) ?? fallback, title.count >= 2 else { return nil }
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
        // 論壇、表格切下來的碎片（「）相遇…＞＞瀧找工作」「還有與之對抗的年輕人們」）不是一句完整的話
        func fragment(_ t: String) -> Bool {
            if let c = t.first, "）)」』】，、；：＞>".contains(c) { return true }
            if ["還有", "而且", "以及", "和", "與", "並且"].contains(where: { t.hasPrefix($0) }) { return true }
            return t.contains("＞") || t.contains(">") || t.contains("ㄉ") || t.contains("→")
        }
        func clean(_ s: S) -> Bool {
            if fragment(s.text) { return false }
            return hits(s.text, notContent) == 0 && !(s.text.contains("《") && !s.text.contains("《\(title)》") && hits(s.text, ["電影", "歌劇", "舞台劇", "版"]) > 0)
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
        // 問的不是遊戲：「《進擊的巨人》是一款動作遊戲」是改編的同名遊戲，不是原作
        let asksGame = ["遊戲", "手遊", "電玩", "game"].contains { question.contains($0) }
        let intro = sents.filter { s in s.named && headed(s.text) && definesIt(s.text) && hits(s.text, genres) > 0 && clean(s) && s.text.count <= 120
            && hits(s.text, ["名言", "台詞", "語錄", "金句", "禁書"] + meta) == 0
            && (asksGame || hits(s.text, ["遊戲", "手遊", "電玩", "改編"]) == 0) }
            .max { a, b in (pro(a.host), -a.text.count) < (pro(b.host), -b.text.count) }
        // ② 講了什麼故事
        func plotScore(_ s: S) -> Int {
            hits(s.text, narrates) * 3 + min(hits(s.text, events), 3) * 2 + hits(s.text, plotCues.filter { !narrates.contains($0) && !events.contains($0) })
                + (s.named ? 2 : 0) + pro(s.host) - hits(s.text, backstory) * 2 - hits(s.text, meta) * 3 - (s.text.count > 120 ? 1 : 0)
        }
        // 劇情句不能是寫作經過（「簡正在從事《第一印象》的創作」）：找不到真的在講故事的句子，寧可不說故事
        let plots = sents.filter { s in hits(s.text, plotCues) > 0 && clean(s) && talksAboutIt(s) && plotScore(s) > 1 && hits(s.text, backstory) == 0 }
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


extension Array where Element: Hashable {
    /// 出現最多次的那個
    func mostCommon() -> Element? {
        var c: [Element: Int] = [:]
        for x in self { c[x, default: 0] += 1 }
        return c.max { $0.value < $1.value }?.key
    }
}
