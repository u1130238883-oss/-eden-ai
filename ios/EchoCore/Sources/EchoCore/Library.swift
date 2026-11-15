import Foundation

/// NineSun 自己知道的作品和清單（ai/commonsense/data/works.txt、lists.txt → CommonsenseData.works / lists）。
///
/// 不用上網就能回答：
/// - 誰寫的：「紅樓夢的作者是誰」「誰寫了老人與海」「鐵達尼號是誰導演的」
/// - 清單：「八大行星有哪些」「四大名著是哪些」「七大洲是什麼」
/// - 一類作品：「有哪些有名的西方文學作品」「出名的西方作品講的都是什麼」
/// - 作品在講什麼（網路查不到、被搜尋引擎擋住、或百科拿錯條目時用）：「老人與海在講什麼」
public enum Library {
    struct Item {
        let name: String
        let aliases: [String]
        var attrs: [(key: String, value: String)]
        func attr(_ k: String) -> String? { attrs.first { $0.key == k }?.value }
        var names: [String] { [name] + aliases }
    }

    static func parse(_ text: String) -> [Item] {
        var out: [Item] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("@") {
                let p = line.dropFirst().split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                out.append(Item(name: p[0], aliases: p[1].split(separator: ",").map(String.init), attrs: []))
            } else if let eq = line.firstIndex(of: "="), !out.isEmpty {
                out[out.count - 1].attrs.append((String(line[..<eq]), String(line[line.index(after: eq)...])))
            }
        }
        return out
    }

    static let works = parse(CommonsenseData.works)
    static let lists = parse(CommonsenseData.lists)

    /// 書名號、空白、語氣詞拿掉
    static func bare(_ s: String) -> String {
        var t = s.filter { !"《》〈〉「」『』\"'“” ？?！!。，,~～".contains($0) && !$0.isWhitespace }
        for w in ["請問一下", "請問", "想問一下", "想問", "我想知道", "你知道", "告訴我", "跟我說", "說說看", "說一下", "介紹一下"] where t.hasPrefix(w) {
            t.removeFirst(w.count)
        }
        while let last = t.last, "呢嗎啊呀喔哦啦吧".contains(last) { t.removeLast() }
        return t
    }

    static func work(named raw: String) -> Item? {
        var n = bare(raw)
        for s in ["這本小說", "這本書", "這部小說", "這部電影", "這部片", "這部動畫", "這部漫畫", "這部作品", "這個故事", "這齣戲", "這部劇",
                  "小說", "電影", "動畫", "漫畫", "這本", "這部", "一書", "一劇"] where n.hasSuffix(s) && n.count > s.count + 1 {
            n.removeLast(s.count); break
        }
        return works.first { $0.names.contains(n) }
    }

    // MARK: - 入口（引擎先問這裡；回 nil 就照原本的方法）

    public static func answer(_ raw: String) -> String? {
        let t = bare(raw)
        guard t.count >= 3, t.count <= 40 else { return nil }
        if ["上網查", "幫我查", "搜尋", "google", "Google"].contains(where: { raw.contains($0) }) { return nil }
        return author(t) ?? list(t) ?? category(t)
    }

    // MARK: 誰寫的、誰導演的

    static func author(_ t: String) -> String? {
        let pats = [#"^(.{2,20}?)的(?:作者|原作者|導演|編劇)(?:是誰|是哪位|是什麼人)?$"#,
                    #"^(.{2,20}?)是誰(?:寫|導演|導|拍|畫|創作|作)的$"#,
                    #"^誰(?:寫|導演|導|拍|畫|創作)(?:了|的)?(.{2,20})$"#,
                    #"^(.{2,20}?)(?:是|由)誰(?:所)?(?:寫|著|執導|導演)$"#,
                    #"^(.{2,20}?)作者是誰$"#]
        guard let g = pats.lazy.compactMap({ RuleBook.match(t, $0) }).first, let w = work(named: g[0]), let a = w.attr("作者") else { return nil }
        var s = "《\(w.name)》"
        if let k = w.attr("類型"), k.contains("電影") || k.contains("動畫電影") {
            s += "：\(a)。"
        } else {
            s += "的作者是\(a)。"
        }
        if let y = w.attr("年代") { s += "\n年代：\(y)。" }
        if let i = w.attr("簡介") { s += "\n它是\(i)。" }
        return s
    }

    // MARK: 清單

    static func list(_ t: String) -> String? {
        let pats = [#"^(.{2,16}?)(?:有|是|包括|包含|分別是|指的是|指)(?:哪些|哪幾個|哪幾種|哪幾位|哪幾項|哪幾|什麼|那些)$"#,
                    #"^(.{2,16}?)(?:有|是)(?:哪些|哪幾個|哪幾)(?:國家|行星|東西|作品|書|人|顏色|呢)?$"#,
                    #"^(?:什麼是|哪些是)(.{2,16})$"#,
                    #"^(.{2,16}?)的(?:名單|清單|名字|名稱|順序)$"#]
        guard let g = pats.lazy.compactMap({ RuleBook.match(t, $0) }).first else { return nil }
        let n = g[0]
        guard let l = lists.first(where: { $0.names.contains(n) }), let items = l.attr("項目") else { return nil }
        // 「五行是什麼」這種問定義的，交給原本的方法（會講意思，不只是列出來）
        if t.hasSuffix("是什麼"), !n.contains(where: { "二三四五六七八九十".contains($0) }) || n == "五行" { return nil }
        var s = "\(l.name)：\(items)。"
        if let x = l.attr("說明") { s += "\n\(x)。" }
        return s
    }

    // MARK: 一類作品（「有名的西方文學作品」「出名的西方作品講的都是什麼」）

    static let famousWords = ["有名", "出名", "著名", "經典", "名著", "知名", "必讀", "必看", "偉大", "重要", "代表", "推薦", "值得"]
    static let workWords = ["文學", "小說", "名著", "作品", "書", "經典", "故事", "劇", "電影", "動畫"]

    static func category(_ t: String) -> String? {
        guard famousWords.contains(where: { t.contains($0) }), workWords.contains(where: { t.contains($0) }) else { return nil }
        // 有具體的作品名就不是在問一類作品
        if works.contains(where: { w in w.names.contains { $0.count >= 2 && t.contains($0) } }) { return nil }
        let region: String
        if ["西方", "歐美", "外國", "國外", "西洋", "歐洲", "英國", "美國", "法國", "俄國", "世界"].contains(where: { t.contains($0) }) { region = "西方" }
        else if ["中國", "中文", "華人", "古典", "四大"].contains(where: { t.contains($0) }) { region = "中國" }
        else if ["日本", "日系"].contains(where: { t.contains($0) }) { region = "日本" }
        else { return nil }
        var pool = works.filter { ($0.attr("地區") ?? "").hasPrefix(region) }
        // 文學、小說、書：不要電影；電影、動畫：只要影像作品
        let wantsFilm = ["電影", "動畫", "片"].contains(where: { t.contains($0) })
        pool = pool.filter { w in
            let k = w.attr("類型") ?? ""
            let film = k.contains("電影") || k.contains("動畫") || k.contains("漫畫")
            return wantsFilm ? film : !film
        }
        // 問小說就只要小說（不要劇本、詩）
        if t.contains("小說") { pool = pool.filter { ($0.attr("類型") ?? "").contains("小說") } }
        // 古典：二十世紀以後的不算
        if t.contains("古典") { pool = pool.filter { w in !["19", "20"].contains(where: { (w.attr("年代") ?? "").hasPrefix($0) }) } }
        guard pool.count >= 3 else { return nil }
        // 每個作者先挑一部（不然前面全是莎士比亞），不夠再補
        let limit = region == "西方" ? 10 : 8
        var picks: [Item] = [], seenAuthors: Set<String> = []
        for w in pool where picks.count < limit && seenAuthors.insert(authorName(w)).inserted { picks.append(w) }
        for w in pool where picks.count < limit && !picks.contains(where: { $0.name == w.name }) { picks.append(w) }
        let asksAbout = ["講", "在說", "說了", "內容", "主題", "關於什麼", "寫什麼", "寫的是", "想表達", "意義", "共同", "都是什麼"].contains(where: { t.contains($0) })
        let place = region == "西方" ? "西方" : region
        var s = asksAbout ? "\(place)有名的作品很多，每一部講的不一樣。挑幾部最常被提到的，說說各自在講什麼：\n"
                          : "\(place)最常被提到的經典\(wantsFilm ? "電影和動畫" : "文學作品")：\n"
        for w in picks {
            let who = authorName(w)
            let what: String
            if asksAbout {
                let theme = (w.attr("主題") ?? "").split(separator: "、").prefix(2).joined(separator: "、")
                what = (w.attr("簡介").map { shortIntro($0) } ?? "") + (theme.isEmpty ? "" : "——講\(theme)")
            } else {
                what = w.attr("簡介").map { shortIntro($0) } ?? ""
            }
            s += "• 《\(w.name)》（\(who)）：\(what)\n"
        }
        if asksAbout && region == "西方" && !wantsFilm {
            s += "\n如果要說它們的共同點：這些作品幾乎都在問同幾個大問題——愛與失去、權力和野心怎麼讓人墮落、一個人該不該對抗社會和命運、苦難之後能不能被救贖。"
            s += "所以它們能流傳幾百年，因為問題到今天還沒有答案。"
        }
        if !s.hasSuffix("\n") { s += "\n" }
        s += "\n想知道哪一部的故事和結局，直接問我「（書名）在講什麼」。"
        return s
    }

    /// 作者的名字（去掉括號裡的補充、「導演」這種字）
    static func authorName(_ w: Item) -> String {
        var a = w.attr("作者") ?? ""
        if let r = a.range(of: "（") { a = String(a[..<r.lowerBound]) }
        a = a.split(separator: "，").first.map(String.init) ?? a
        return a.replacingOccurrences(of: "導演", with: "")
    }

    static func shortIntro(_ s: String) -> String {
        let cut = s.split(separator: "，").first.map(String.init) ?? s
        return cut.count >= 8 ? cut : s
    }

    // MARK: 作品在講什麼（離線版）

    /// 問的是不是某部作品的內容（「老人與海在講什麼」「鐵達尼號的結局」）：回傳那部作品
    public static func workAsked(_ raw: String) -> String? {
        workQuestion(raw)?.name
    }

    static func workQuestion(_ raw: String) -> Item? {
        let t = bare(raw)
        let tails = ["在講什麼", "在講些什麼", "講了什麼", "講了些什麼", "講的是什麼", "講的什麼", "講什麼", "在說什麼", "說了什麼", "說的是什麼",
                     "的故事", "的劇情", "的內容", "的大意", "的結局", "結局是什麼", "的結局是什麼", "的主題", "主題是什麼", "想表達什麼", "想說什麼",
                     "是什麼故事", "是在講什麼", "是講什麼", "的心得", "好看嗎", "值得看嗎", "值得讀嗎"]
        for tail in tails.sorted(by: { $0.count > $1.count }) where t.hasSuffix(tail) && t.count > tail.count + 1 {
            if let w = work(named: String(t.dropLast(tail.count))) { return w }
        }
        return work(named: t)
    }

    /// 離線的作品回答：它是什麼 → 📖 故事 → 🔚 結局 → 💡 主題 → 我的看法
    public static func workAnswer(_ raw: String) -> String? {
        guard let w = workQuestion(raw), let intro = w.attr("簡介") else { return nil }
        let t = bare(raw)
        var s = "《\(w.name)》是\(intro)"
        if let a = w.attr("作者") { s += "（\(a)" + (w.attr("年代").map { "，\($0)" } ?? "") + "）" }
        s += "。"
        let onlyEnding = t.contains("結局")
        let onlyTheme = ["主題", "想表達", "想說"].contains(where: { t.contains($0) })
        if !onlyEnding && !onlyTheme, let x = w.attr("故事") { s += "\n📖 故事：\(x)。" }
        if !onlyTheme, let x = w.attr("結局") { s += "\n🔚 結局：\(x)。" }
        if let x = w.attr("主題") { s += "\n💡 主題：\(x)。" }
        if let x = w.attr("看法") { s += "\n🧠 我的看法：\(x)。" }
        return s
    }
}
