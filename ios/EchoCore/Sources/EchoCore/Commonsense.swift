import Foundation

/// NineSun 自己的常識：國家、動物、自然、宇宙、人體、人物、發明、節日、「最…的」、怎麼做、推薦。
///
/// 資料是一筆一筆的「事實」（CommonsenseData，由 ai/commonsense 產生），不是寫好的回答。
/// 回答時先讀懂問題：問的是哪個東西（大貓熊、熊貓、貓熊都是同一個）、問它的什麼（吃什麼、住哪、會不會、是不是、為什麼、有幾個…），
/// 再從事實推出答案、組成句子——所以沒看過的問法也能答：
/// 「鯨魚是魚嗎」→ 鯨魚屬於哺乳類，魚是另一類 → 不是，再用說明解釋為什麼；
/// 「狗可以吃巧克力嗎」→ 狗的食物裡寫著不能吃巧克力，巧克力的說明寫著原因 → 不可以；
/// 「月亮會發光嗎」→ 關於月亮發光的解釋裡寫著「自己不會發光」→ 不會。
/// 查不到、推不出來就回傳 nil，交給上網查。
public enum Commonsense {
    struct Entity {
        let name: String
        let aliases: [String]
        let kind: String
        var attrs: [(key: String, value: String)]
        func attr(_ k: String) -> String? { attrs.first { $0.key == k }?.value }
        var classes: [String] { (attr("是") ?? "").split(separator: "、").map(String.init) }
        var notClasses: String { attr("不是") ?? "" }
        /// 為什麼：關鍵詞 → 解釋
        var whys: [(keys: [String], text: String)] {
            attrs.filter { $0.key.hasPrefix("因:") }.map { (String($0.key.dropFirst(2)).split(separator: "/").map(String.init), $0.value) }
        }
        var names: [String] { [name] + aliases }
    }

    static let all: [Entity] = {
        var out: [Entity] = []
        for line in CommonsenseData.entities.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("@") {
                let p = line.dropFirst().split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                out.append(Entity(name: p[0], aliases: p[1].split(separator: ",").map(String.init), kind: p[2], attrs: []))
            } else if let eq = line.firstIndex(of: "=") {
                out[out.count - 1].attrs.append((String(line[..<eq]), String(line[line.index(after: eq)...])))
            }
        }
        return out
    }()
    static let howKinds: Set<String> = ["做法", "健康", "學習", "生活"]
    static let facts = all.filter { !howKinds.contains($0.kind) && $0.kind != "推薦" }
    static let howtos = all.filter { howKinds.contains($0.kind) }
    static let recommends = all.filter { $0.kind == "推薦" }

    /// 句子裡提到的東西（長的名字先比對，不重疊），照出現的順序
    static func mentions(_ t: String, in pool: [Entity]) -> [(entity: Entity, range: Range<String.Index>, alias: String)] {
        var found: [(Entity, Range<String.Index>, String)] = []
        let names = pool.flatMap { e in e.names.map { (e, $0) } }.filter { !$0.1.isEmpty }.sorted { $0.1.count > $1.1.count }
        for (e, n) in names {
            var from = t.startIndex
            while let r = t.range(of: n, range: from..<t.endIndex) {
                if !found.contains(where: { $0.1.overlaps(r) }) { found.append((e, r, n)) }
                from = r.upperBound
            }
        }
        return found.sorted { $0.1.lowerBound < $1.1.lowerBound }
    }

    /// 問法裡的詞、解釋的關鍵詞、屬性名稱、分類、其他東西的名字：一個東西的名字落在這些更長的詞裡面就不算提到它
    /// （「發光」的光、「結冰」的冰、「水果」的水、「繞太陽一圈」的太陽），除非那個詞本來就是在講它自己（「會打雷」的打雷）
    static let protected: [String: Set<String>] = {
        var w: [String: Set<String>] = [:]
        func add(_ word: String, _ owner: String?) {
            guard word.count >= 2 else { return }
            if let o = owner { w[word, default: []].insert(o) } else if w[word] == nil { w[word] = [] }
        }
        for (_, ws) in cues { ws.forEach { add($0, nil) } }
        defineCues.forEach { add($0, nil) }
        classWords.keys.forEach { add($0, nil) }
        for e in all {
            e.names.forEach { add($0, e.name) }
            for a in e.attrs {
                if a.key.hasPrefix("因:") { a.key.dropFirst(2).split(separator: "/").forEach { add(String($0), e.name) } } else { add(a.key, e.name) }
            }
        }
        ["發光", "結冰", "下雨", "颳風", "海洋", "人口", "人類", "地球上", "陸地上", "日期", "月份", "冰點", "沸點"].forEach { add($0, nil) }
        return w
    }()
    static let protectedWords = protected.keys.sorted { $0.count > $1.count }

    /// 名字後面可以接的字（「貓會」「鯨魚是」「月亮離」），單字的名字（人、象、光）後面一定要是這些，才是在講它
    static let follow = Set("的是會有可能為在和跟與還都也不要吃住喝怎幾多哪呢嗎吧啊一每離從用說講叫被到最真屬怕愛喜就算比")
    /// 名字前面可以接的字（「喝咖啡」「養貓」「為什麼貓」「被蚊子」）
    static let lead = Set("的是和跟與或及在從到把被對喝吃養看去用愛個隻種位麼麽何說問了過著會要能讓有沒切煮炒烤泡做買種摸抱歡")
    /// 名字後面接這些字就是另一個詞（「咖啡店」「太陽眼鏡」「火星文」）
    static let compound = Set("店館廳院站場廠街路園機器片劇屋林餅糖粉醬汁杯包票卡眼鏡文語系族界間座塊")

    static func realMentions(_ t: String, in pool: [Entity]) -> [(entity: Entity, range: Range<String.Index>, alias: String)] {
        var covers: [(Range<String.Index>, Set<String>)] = []
        for w in protectedWords where t.contains(w) {
            var from = t.startIndex
            while let r = t.range(of: w, range: from..<t.endIndex) { covers.append((r, protected[w]!)); from = r.upperBound }
        }
        func startsProtected(_ i: String.Index) -> Bool {
            let tail = t[i...]
            return protectedWords.contains { tail.hasPrefix($0) } || ["什麼", "哪", "誰", "多", "幾", "怎"].contains { tail.hasPrefix($0) }
        }
        return mentions(t, in: pool).filter { m in
            if covers.contains(where: { c, owners in
                c.overlaps(m.range) && t.distance(from: c.lowerBound, to: c.upperBound) > m.alias.count && !owners.contains(m.entity.name)
            }) { return false }
            let prev = m.range.lowerBound > t.startIndex ? t[t.index(before: m.range.lowerBound)] : nil
            let next = m.range.upperBound < t.endIndex ? t[m.range.upperBound] : nil
            // 前面是別的字（「老人」「曬太陽」「現象」）：是另一個詞的一部分
            if let p = prev, p.isLetter, !lead.contains(p) { return false }
            // 「發明原子筆的人是誰」的「人」是「那個人」，不是在問人類
            if m.alias == "人", prev == "的" { return false }
            guard let n = next else { return true }
            if compound.contains(n) { return false }
            // 「挪威的森林」「人間失格」：名字後面接「的」再接一個不認得的東西，是更長的名稱
            if n == "的" {
                let after = t.index(after: m.range.upperBound)
                if after < t.endIndex, !startsProtected(after) { return false }
            }
            if m.alias.count == 1, !follow.contains(n), !startsProtected(m.range.upperBound) { return false }
            return true
        }
    }

    /// 這句話在講哪些東西（名字和別名），給測試檢查有沒有認錯主角
    public static func subjects(_ raw: String) -> [String] {
        let t = Everyday.clean(raw)
        return (realMentions(t, in: facts) + mentions(t, in: howtos)).flatMap { $0.entity.names }
    }

    // MARK: - 入口

    public static func answer(_ raw: String, now: Date = Date()) -> String? {
        let t = Everyday.clean(raw)
        guard t.count >= 2, t.count <= 40 else { return nil }
        // 明白叫我上網查的（「幫我查一下…」「搜尋…」）就上網
        if ["查", "搜尋", "上網", "google", "Google", "維基"].contains(where: { raw.contains($0) }) { return nil }
        // 在說心情（「我難過到睡不著怎麼辦」）：先陪他，不是給方法
        if ["到睡不著", "難過", "傷心", "孤單", "寂寞", "害怕", "失落", "低落", "生氣", "煩惱", "好煩", "很煩", "焦慮", "憂鬱", "想哭", "心情"]
            .contains(where: { t.contains($0) }) && t.contains("我") { return nil }
        if let a = howto(t) { return a }
        if let a = recommend(t) { return a }
        if fortuneish(t) { return nil }
        if let a = compare(t) { return a }
        if let a = superlative(t) { return a }
        return about(t, now: now)
    }

    /// 算命、運勢的問題不歸這裡（「屬蛇的人今年會好嗎」「月亮星座」）
    static func fortuneish(_ t: String) -> Bool {
        ["運勢", "命盤", "命宮", "星座", "八字", "紫微", "流年", "屬", "卦", "宮", "運氣", "財運", "桃花", "命理", "算命", "上升", "合盤"]
            .contains { t.contains($0) }
    }

    static let asking = ["嗎", "呢", "還是", "什麼", "幾", "多少", "哪", "誰", "怎麼", "如何", "為什麼", "為何", "是不是", "會不會", "有沒有", "能不能",
                         "可不可以", "可以", "介紹", "多久", "多遠", "多高", "多大", "多長", "多深", "多快", "多熱", "多冷"]

    // MARK: - 聊到某個東西

    static let likeWords = ["好可愛", "很可愛", "超可愛", "可愛", "好萌", "好乖", "好帥", "好美", "好漂亮", "好酷", "好厲害", "好喜歡", "很喜歡",
                            "超喜歡", "最喜歡", "我喜歡", "我愛", "好好吃", "好好喝", "好聰明", "好有趣"]

    /// 「貓咪好可愛」「我最喜歡大貓熊」：不是在問問題，是在分享——接著聊，說一件自己知道、對方可能不知道的事
    public static func react(_ raw: String) -> String? {
        let t = Everyday.clean(raw)
        guard t.count <= 20, !asking.contains(where: { t.contains($0) }), let like = likeWords.first(where: { t.contains($0) }),
              !fortuneish(t), let m = realMentions(t, in: facts).first else { return nil }
        let e = m.entity
        guard let fact = e.attr("特點") ?? e.attr("說明") else { return nil }
        let word = m.alias
        let adj = like.hasPrefix("好") || like.hasPrefix("很") || like.hasPrefix("超") ? String(like.dropFirst()) : like
        let agree: String
        if like.contains("喜歡") || like == "我愛" { agree = "我也很喜歡\(word)！" }
        else { agree = "對啊，\(word)真的很\(adj)！" }
        let ask: String
        switch e.kind {
        case "動物": ask = e.classes.contains("寵物") ? "你有養\(word)嗎？還是在哪裡看到的？" : "你在哪裡看過\(word)？動物園還是影片？"
        case "食物", "飲料": ask = "你平常最喜歡怎麼吃？"
        case "人物": ask = "你最喜歡他的哪一點？"
        default: ask = "你是怎麼開始喜歡\(word)的？"
        }
        return "\(agree)跟你說一件我知道的事：\(fact)。\n\(ask)"
    }

    // MARK: - 怎麼做

    static let howCues = ["怎麼", "如何", "要怎樣", "該怎樣", "方法", "步驟", "教我", "做法", "要怎", "該怎", "秘訣", "技巧", "撇步", "辦法", "建議", "訣竅"]

    static func howto(_ t: String) -> String? {
        guard howCues.contains(where: { t.contains($0) }) else { return nil }
        var hit = mentions(t, in: howtos).first?.entity
        // 「白飯怎麼煮」「英文怎麼學」「錢怎麼存」：動詞放回前面再找一次
        if hit == nil, let g = RuleBook.match(t, #"^(?:我的?)?(.{1,4}?)(?:要|該)?(?:怎麼|如何|怎樣)(.)"#) {
            hit = mentions(g[1] + g[0], in: howtos).first?.entity
        }
        guard let e = hit else { return nil }
        let steps = (e.attr("步驟") ?? "").split(separator: "；").enumerated().map { "\($0.offset + 1). \($0.element)" }
        guard !steps.isEmpty else { return nil }
        let symptom = ["感冒", "發燒", "頭痛", "睡不著", "拉肚子"].contains(e.name)
        var s = e.kind == "做法" ? "\(e.name)的步驟：" : symptom ? "\(e.name)的時候可以這樣做：" : "想\(e.name)，可以這樣做："
        s += "\n" + steps.joined(separator: "\n")
        if let x = e.attr("提醒") { s += "\n\n小提醒：\(x)。" }
        if let x = e.attr("看法") { s += "\n\n\(x)。" }
        if let x = e.attr("就醫") { s += "\n\n⚠️ 什麼時候要看醫生：\(x)。" }
        return s
    }

    // MARK: - 推薦

    static func recommend(_ t: String) -> String? {
        var core = t
        for p in ["我現在", "我今天", "我真的", "我覺得", "現在", "今天", "真的", "我"] where core.hasPrefix(p) { core.removeFirst(p.count); break }
        while let l = core.last, "了喔啦耶啊呀哦欸".contains(l) { core.removeLast() }
        if ["好無聊", "很無聊", "無聊死", "無聊死了", "無聊", "超無聊", "好悶", "沒事做", "好閒", "很閒", "不知道要幹嘛", "不知道要做什麼", "不知道做什麼"].contains(core),
           let e = recommends.first(where: { $0.name == "無聊" }) {
            let items = (e.attr("項目") ?? "").split(separator: "；").map(String.init)
            let seed = abs(Calendar(identifier: .gregorian).component(.hour, from: Date()) &+ t.count)
            let pick = (0..<min(4, items.count)).map { items[(seed + $0) % items.count] }
            let list = pick.map { "• " + $0 }.joined(separator: "\n")
            let best = e.attr("首選") ?? "", ask = e.attr("問") ?? ""
            return "無聊的時候，來試試這幾個：\n\(list)\n\n\(best)。\n\(ask)"
        }
        let cue = ["推薦", "介紹幾", "介紹一", "好看的", "好聽的", "好玩的", "該看什麼", "看什麼好", "聽什麼好", "吃什麼好", "吃什麼", "去哪裡玩",
                   "哪裡好玩", "養什麼", "有什麼好看", "有什麼好聽", "有什麼好玩", "有什麼好吃"].contains { t.contains($0) }
            && !["好處", "壞處", "為什麼"].contains(where: { t.contains($0) })
        guard cue, realMentions(t, in: facts).isEmpty, let e = mentions(t, in: recommends).first?.entity else { return nil }
        let items = (e.attr("項目") ?? "").split(separator: "；").map(String.init)
        guard !items.isEmpty else { return nil }
        // 每次換幾個不一樣的（照日期和問法輪替），但首選固定
        let seed = abs(t.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } &+ Calendar(identifier: .gregorian).component(.day, from: Date()))
        let pick = (0..<min(4, items.count)).map { items[(seed + $0) % items.count] }
        var s = "我推薦這幾個：\n" + pick.map { "• " + $0 }.joined(separator: "\n")
        if let x = e.attr("首選") { s += "\n\n如果只能選一個：\(x)。" }
        if let x = e.attr("問") { s += "\n\(x)" }
        return s
    }

    // MARK: - 比較（哪個比較好）

    static func compare(_ t: String) -> String? {
        guard ["哪個", "哪一個", "還是", "比較", "誰比較", "哪種"].contains(where: { t.contains($0) }) else { return nil }
        for line in CommonsenseData.views.split(separator: "\n") {
            let p = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard t.contains(p[0]), t.contains(p[1]) else { continue }
            let angles = p[2].split(separator: ",").map(String.init)
            if angles.isEmpty || angles.contains(where: { t.contains($0) }) { return p[3] + "。" }
        }
        return nil
    }

    // MARK: - 最…的…

    static let adjectives = ["最長壽", "最多人", "最高", "最長", "最大", "最深", "最小", "最快", "最冷", "最熱", "最遠", "最近", "最硬"]
    static let scopes: [(String, [String])] = [
        ("世界", ["全世界", "世界上", "世界", "全球", "地球上"]), ("台灣", ["台灣", "臺灣"]), ("中國", ["中國"]), ("日本", ["日本"]),
        ("義大利", ["義大利", "意大利"]), ("亞洲", ["亞洲"]), ("歐洲", ["歐洲"]), ("非洲", ["非洲"]), ("美洲", ["美洲", "南美", "北美"]),
        ("太陽系", ["太陽系"]), ("人體", ["人體", "人身上", "身體", "人的"]), ("陸地", ["陸地", "陸上"]),
    ]

    static func superlative(_ t0: String) -> String? {
        var t = t0
        if t.contains("人口最多") { t = t.replacingOccurrences(of: "人口最多", with: "最多人") }
        guard let adj = adjectives.first(where: { t.contains($0) }) else { return nil }
        // 「第二高」「最高的人」這種不是在問第一名的東西，交給上網
        if t.contains("第二") || t.contains("第三") { return nil }
        let scope = scopes.first { $0.1.contains { t.contains($0) } }?.0
        let rows = CommonsenseData.superlatives.split(separator: "\n").map { $0.split(separator: "|", omittingEmptySubsequences: false).map(String.init) }
        let cand = rows.filter { $0[1] == adj }
        // 問的東西：「山」「河流」「動物」…（長的先比）
        var best: ([String], String)?
        for r in cand {
            for n in r[2].split(separator: ",").map(String.init) where t.contains(n) {
                if best == nil || n.count > best!.1.count || (n.count == best!.1.count && r[0] == (scope ?? "世界")) {
                    if scope == nil || r[0] == scope || (scope == "世界" && r[0] == "世界") { best = (r, n) }
                    else if best == nil && scope == nil { best = (r, n) }
                }
            }
        }
        // 沒說範圍：「最大的器官」是人體、「最大的行星」是太陽系
        if best == nil, scope == nil {
            for r in cand { for n in r[2].split(separator: ",").map(String.init) where t.contains(n) && best == nil { best = (r, n) } }
        }
        guard let (r, noun) = best, scope == nil || r[0] == scope else { return nil }
        let place = ["世界": "世界上", "陸地": "陸地上", "太陽系": "太陽系裡", "人體": "人體"][r[0]] ?? r[0]
        let what = adj == "最多人" ? "人口最多" : adj
        return "\(place)\(what)的\(noun)是\(r[3])。\(r[4])。"
    }

    // MARK: - 問某個東西

    static let classWords: [String: String] = [
        "魚": "魚類", "魚類": "魚類", "鳥": "鳥類", "鳥類": "鳥類", "哺乳動物": "哺乳類", "哺乳類": "哺乳類", "爬蟲類": "爬行類", "爬蟲": "爬行類",
        "爬行動物": "爬行類", "爬行類": "爬行類", "兩棲類": "兩棲類", "兩棲動物": "兩棲類", "昆蟲": "昆蟲", "蟲": "昆蟲", "水果": "水果", "蔬菜": "蔬菜",
        "菜": "蔬菜", "植物": "植物", "動物": "動物", "真菌": "真菌", "堅果": "堅果", "豆類": "豆類", "穀物": "穀物", "行星": "行星", "恆星": "恆星",
        "星星": "恆星", "衛星": "衛星", "國家": "國家", "熊": "熊科", "貓科": "貓科", "貓科動物": "貓科", "犬科": "犬科", "猴子": "猴子", "猿": "猿",
        "肉食動物": "肉食動物", "草食動物": "草食動物", "雜食動物": "雜食動物", "寵物": "寵物", "冷血動物": "冷血動物", "軟體動物": "軟體動物",
    ]

    /// 屬性 ← 問法
    static let cues: [(key: String, words: [String])] = [
        ("首都", ["首都", "首府"]),
        ("洲", ["哪一洲", "哪個洲", "哪洲", "什麼洲", "哪一個洲", "哪個大陸"]),
        ("語言", ["什麼語言", "哪種語言", "哪些語言", "說什麼話", "講什麼話", "官方語言", "說什麼語", "講什麼語", "語言", "說哪種", "講哪種"]),
        ("貨幣", ["貨幣", "什麼錢", "用什麼幣", "錢叫什麼", "什麼幣", "哪種錢"]),
        ("日期", ["幾月幾號", "幾月幾日", "幾號", "哪一天", "哪天", "什麼時候", "幾月", "日期", "是星期幾"]),
        ("習俗", ["習俗", "要做什麼", "做什麼", "有什麼活動", "怎麼過", "傳統", "慶祝"]),
        ("由來", ["由來", "起源", "典故", "為什麼要過", "怎麼來的", "傳說", "紀念誰", "紀念什麼"]),
        ("吃", ["吃什麼", "吃些什麼", "吃哪些", "食物", "以什麼為食", "吃啥", "愛吃", "喜歡吃", "要吃"]),
        ("住", ["住在哪", "住哪", "生活在哪", "棲息", "在哪裡生活", "哪裡有", "分布", "住在什麼地方", "在哪裡", "在哪"]),
        ("壽命", ["活多久", "壽命", "活幾年", "能活", "可以活", "活多少年", "活到幾歲", "多長壽"]),
        ("顏色", ["什麼顏色", "顏色", "什麼色", "哪種顏色", "幾種顏色", "幾種色"]),
        ("腳", ["幾條腿", "幾隻腳", "幾隻腿", "幾條腳", "幾條腕", "幾隻手", "有腳嗎", "有沒有腳"]),
        ("年代", ["哪個朝代", "什麼朝代", "朝代", "哪個年代", "什麼年代", "什麼時候的人", "哪一年出生", "哪年出生", "什麼時候出生", "活在什麼時候",
                "哪個時代", "什麼時代", "哪一年生", "生卒"]),
        ("國籍", ["哪國人", "哪裡人", "什麼國家的人", "哪個國家的人", "國籍", "是哪裡的", "哪一國人"]),
        ("代表作", ["代表作", "作品", "寫過", "寫了什麼", "寫了哪些", "有名的", "成就", "貢獻", "做了什麼", "做過什麼", "畫過", "發現了什麼",
                  "發明了什麼", "為什麼有名", "有什麼名", "做過哪些"]),
        ("名言", ["名言", "說過什麼", "名句", "說過哪些", "說過的話", "詩句"]),
        ("發明者", ["誰發明", "發明者", "誰發現", "誰創造", "誰做出", "發明的", "誰想出", "是誰做的", "發明人", "誰造的", "誰做的"]),
        ("年份", ["哪一年發明", "什麼時候發明", "哪年發明", "何時發明", "發明於", "什麼時候出現", "哪一年出現"]),
        ("月份", ["哪幾個月", "幾月到幾月", "哪個月", "月份", "幾月"]),
        ("好處", ["好處", "優點", "益處", "有什麼好", "對身體好"]),
        ("壞處", ["壞處", "缺點", "副作用", "危害", "對身體不好", "風險"]),
        ("沸點", ["沸點", "沸騰", "燒開", "煮沸", "會滾", "煮開"]),
        ("冰點", ["冰點", "結冰", "凝固", "結成冰"]),
        ("高度", ["多高", "高度", "海拔", "有多高", "幾公尺高"]),
        ("長度", ["多長", "長度", "有多長", "幾公里長"]),
        ("距離", ["多遠", "距離", "離地球", "離我們", "遠嗎"]),
        ("溫度", ["多熱", "溫度", "幾度", "多冷", "多燙"]),
        ("年齡", ["幾歲", "多老", "年齡", "存在多久", "多少年了", "多少歲"]),
        ("大小", ["多大", "大小", "直徑", "體積", "有多大"]),
        ("速度", ["多快", "速度", "時速", "每秒"]),
        ("形狀", ["形狀", "什麼形狀", "長什麼樣"]),
        ("公轉", ["公轉", "繞太陽一圈", "繞太陽轉一圈", "繞著太陽轉一圈"]),
        ("繞一圈", ["繞地球一圈", "繞地球轉一圈", "繞一圈"]),
        ("自轉", ["自轉", "轉一圈"]),
        ("成分", ["成分", "由什麼組成", "組成", "含有什麼", "裡面有什麼"]),
        ("時間", ["睡幾個小時", "要睡多久", "睡多久", "幾個小時", "多久"]),
        ("人口", ["人口", "多少人", "幾個人"]),
        ("面積", ["面積", "多少平方公里"]),
    ]

    static let defineCues = ["是誰", "是什麼", "什麼是", "誰是", "介紹", "簡介", "是幹嘛的", "是做什麼的", "是幹什麼的", "認識", "知道", "是哪位",
                             "什麼東西", "怎樣的人", "什麼樣的人", "是個什麼"]

    static func about(_ t: String, now: Date) -> String? {
        if let a = reverseWork(t) { return a }
        // 「發明飛機的人是誰」「電燈的發明者」→ 飛機是誰發明的
        if let g = RuleBook.match(t, #"^(?:發明|發現)(.{1,10}?)的(?:人|是誰)"#) ?? RuleBook.match(t, #"^(.{1,10}?)的(?:發明者|發明人)"#),
           let e = facts.first(where: { $0.names.contains(g[0]) }), let v = e.attr("發明者") {
            let said = g[0] == e.name ? e.name : "\(g[0])（\(e.name)）"
            return "\(said)的發明者：\(v)。"
        }
        let ms = realMentions(t, in: facts)
        let whyAsk = ["為什麼", "為何", "怎麼會", "原因", "為啥", "幹嘛", "何以", "怎麼來的"].contains(where: { t.contains($0) })
        guard let first = ms.first else { return reverseCapital(t) ?? (whyAsk ? globalWhy(t) : nil) }
        let e = first.entity
        guard asking.contains(where: { t.contains($0) }) || t.hasSuffix("嗎") else { return nil }
        // 主角後面的話（「無尾熊是熊嗎」→「是熊嗎」：後面的「熊」是在問的分類，不是另一個主角）
        let after = String(t[first.range.upperBound...])
        // 句子裡提到的所有東西（包括被更長的詞包住的），找屬性時當備用
        let loose = mentions(t, in: facts).map { $0.entity }
        // 句子裡除了東西的名字之外剩下的話
        var rest = t
        for m in ms.reversed() { rest.replaceSubrange(m.range, with: "　") }
        let mentioned = ms.map { $0.entity }

        // 為什麼
        if whyAsk {
            return why(t, mentioned) ?? globalWhy(t)
        }
        // 節日的日期
        if e.kind == "節日", ["幾月幾號", "幾月幾日", "幾號", "哪一天", "哪天", "什麼時候", "幾月", "日期", "星期幾", "禮拜幾"].contains(where: { t.contains($0) }) {
            return festivalAnswer(e, now: now)
        }
        // A 還是 B
        if let g = RuleBook.match(rest, #"是(.+?)還是(.+?)(?:呢|啊)?$"#) {
            return choice(e, g[0], g[1])
        }
        // 是不是、會不會、能不能、有沒有
        if let a = yesNo(t, after, e, mentioned) { return a }
        // 有幾個…、有多少…
        if let a = count(rest, mentioned) { return a }
        // 直接說出屬性的名字（「人的體溫」「水的沸點」）
        for o in mentioned {
            if let a = o.attrs.filter({ !$0.key.hasPrefix("因:") && $0.key.count >= 2 && !["簡介", "說明", "特點", "看法"].contains($0.key) && t.contains($0.key) })
                .max(by: { $0.key.count < $1.key.count }) { return phrase(o, a.key, a.value, now: now) }
        }
        // 問某個屬性（主角沒有，就看句子裡提到的其他東西：「人一天要睡幾個小時」→ 睡覺）
        for (key, words) in cues where words.contains(where: { t.contains($0) }) {
            if let owner = (mentioned + loose).first(where: { $0.attr(key) != nil }) { return phrase(owner, key, owner.attr(key)!, now: now) }
        }
        // 沒有直接對應的屬性：找跟問題相關的解釋（「太陽從哪邊升起」→ 太陽東升西落的解釋）
        if let w = bestWhy(t, mentioned, skipNames: true, minLen: 2), !defineCues.contains(where: { t.contains($0) }) { return w }
        // 是什麼、是誰、介紹
        if defineCues.contains(where: { t.contains($0) }) || rest.trimmingCharacters(in: CharacterSet(charactersIn: "　")) .isEmpty {
            var left = after
            for w in defineCues.sorted(by: { $0.count > $1.count }) + ["一下", "呢", "嗎", "啊", "呀", "的", "這個", "那個", "意思", "東西", "一種", "個"] {
                left = left.replacingOccurrences(of: w, with: "")
            }
            let kinds: Set<String> = ["人", "動物", "植物", "國家", "地方", "節日", "星球", "人物", "食物", "飲料", "發明", "東西"]
            guard left.isEmpty || classWords[left] != nil || kinds.contains(left) else { return nil }
            return define(e, now: now)
        }
        return nil
    }

    /// 「東京是哪個國家的首都」
    static func reverseCapital(_ t: String) -> String? {
        guard t.contains("首都"), ["哪個國家", "哪一國", "哪國", "什麼國家", "哪裡"].contains(where: { t.contains($0) }) else { return nil }
        for e in facts where e.kind == "國家" {
            guard let c = e.attr("首都") else { continue }
            let city = String(c.prefix { $0 != "（" && $0 != "(" })
            if city.count >= 2, t.hasPrefix(city) { return "\(city)是\(e.name)的首都。\(e.name)\(e.attr("簡介").map { "是" + $0 } ?? "")。" }
        }
        return nil
    }

    // MARK: 為什麼

    static func bestWhy(_ t: String, _ es: [Entity], skipNames: Bool = false, minLen: Int = 1) -> String? {
        var best: (Int, String)?
        for e in es {
            for w in e.whys {
                // 沒問為什麼時，關鍵詞剛好是東西自己的名字（「打雷」）不算相關
                for k in w.keys where k.count >= minLen && t.contains(k) && k.count > (best?.0 ?? 0) && !(skipNames && es.contains { $0.names.contains(k) }) {
                    best = (k.count, w.text)
                }
            }
        }
        return best.map { $0.1 + "。" }
    }

    /// 沒提到主角的為什麼（「為什麼會打哈欠」「夕陽為什麼是紅的」）：在所有的解釋裡找關鍵詞最吻合的一個，要明顯勝出才算
    static func globalWhy(_ t: String) -> String? {
        var scored: [(Int, Double, String)] = []
        for e in facts {
            for w in e.whys {
                let hit = w.keys.filter { $0.count >= 2 && t.contains($0) }
                let score = hit.filter { h in !hit.contains { $0 != h && $0.contains(h) } }.reduce(0) { $0 + $1.count }
                if score >= 2 { scored.append((score, Double(hit.count) / Double(w.keys.count), w.text)) }
            }
        }
        scored.sort { $0.0 != $1.0 ? $0.0 > $1.0 : $0.1 > $1.1 }
        guard let top = scored.first,
              scored.count == 1 || scored[1].0 < top.0 || scored[1].1 < top.1 || scored[1].2 == top.2 else { return nil }
        return top.2 + "。"
    }

    /// 「誰寫了少年維特的煩惱」「蒙娜麗莎是誰畫的」「論語的作者是誰」→ 從人物的代表作反查
    static func reverseWork(_ t: String) -> String? {
        let pats = [#"^誰(?:寫|畫|作|唱|發明|發現|創作|譜)了?(.{2,20})$"#, #"^(.{2,20}?)是誰(?:寫|畫|作|唱|創作|譜)的$"#, #"^(.{2,20}?)的作者是誰$"#,
                    #"^(.{2,20}?)的作者$"#]
        guard let g = pats.lazy.compactMap({ RuleBook.match(t, $0) }).first else { return nil }
        let work = g[0].filter { !"《》〈〉「」".contains($0) }
        guard work.count >= 2 else { return nil }
        for e in facts where e.kind == "人物" {
            guard let w = e.attr("代表作"), w.contains(work) else { continue }
            let kind = w.contains("《\(work)》") ? "《\(work)》" : "〈\(work)〉"
            return "\(kind)的作者是\(e.name)。\(e.name)是\(e.attr("簡介") ?? "")。" + (e.attr("年代").map { "他生活在\($0)。" } ?? "")
        }
        return nil
    }

    static func why(_ rest: String, _ es: [Entity]) -> String? {
        if let w = bestWhy(rest, es) { return w }
        // 節日的為什麼（「端午節為什麼要吃粽子」）：說由來
        if let f = es.first(where: { $0.kind == "節日" }), let x = f.attr("由來") { return "\(f.name)的由來：\(x)。" }
        // 「為什麼企鵝不會飛」這類：問的是「不會」裡的事，用說明回答
        for e in es {
            if let no = e.attr("不會"), no.split(separator: "、").contains(where: { rest.contains(String($0.prefix(2))) }), let x = e.attr("說明") { return x + "。" }
        }
        return nil
    }

    // MARK: 是不是／會不會

    /// 某段話裡提到 x 的地方，前面是不是否定（不、不是、不會、沒有）
    static func negated(_ text: String, _ x: String) -> Bool? {
        guard let r = text.range(of: x) else { return nil }
        let before = String(text[text.startIndex..<r.lowerBound].suffix(3))
        return ["不是", "不會", "沒有", "不能", "不", "無法", "沒"].contains { before.hasSuffix($0) }
    }

    static func yesNo(_ t: String, _ after: String, _ e: Entity, _ es: [Entity]) -> String? {
        let isYN = t.hasSuffix("嗎") || ["是不是", "會不會", "能不能", "可不可以", "有沒有", "是否"].contains { t.contains($0) }
        guard isYN else { return nil }
        var r = after
        for s in ["嗎", "呢"] where r.hasSuffix(s) { r.removeLast() }
        for (a, b) in [("是不是", "是"), ("會不會", "會"), ("能不能", "能"), ("可不可以", "可以"), ("有沒有", "有"), ("是否", "是")] {
            r = r.replacingOccurrences(of: a, with: b)
        }
        for p in ["真的", "也", "都", "到底", "其實", "本身"] where r.hasPrefix(p) { r.removeFirst(p.count) }

        // 能不能吃：「狗可以吃巧克力嗎」
        if RuleBook.match(r, #"^(?:可以|能|能夠)吃(.*)$"#) != nil, let food = es.dropFirst().first {
            let diet = e.attr("吃") ?? ""
            let banned = diet.range(of: "不能吃").map { String(diet[$0.upperBound...]) } ?? ""
            if food.names.contains(where: { banned.contains($0) }) {
                let reason = food.attr("說明").map { "\n" + $0 + "。" } ?? ""
                return "不可以！\(e.name)不能吃\(food.name)。\(reason)"
            }
            return nil
        }
        // 是：「鯨魚是魚嗎」「番茄是水果嗎」「地球是圓的嗎」
        if r.hasPrefix("是") {
            var x = String(r.dropFirst())
            for p in ["一種", "一個", "一隻", "一顆", "屬於"] where x.hasPrefix(p) { x.removeFirst(p.count) }
            if x.isEmpty { return nil }
            let core = x.hasSuffix("的") ? String(x.dropLast()) : x
            // 明確說不是
            if !e.notClasses.isEmpty, e.notClasses.contains(core) {
                return "不是。\(e.attr("說明") ?? e.notClasses)。"
            }
            if let cls = classWords[core] {
                let yes = e.classes.contains { $0 == cls || $0.hasSuffix(cls) || $0.hasSuffix(core) }
                let note = e.attr("說明").map { $0 + "。" } ?? ""
                if yes { return "是的，\(e.name)是\(e.classes.first { $0 == cls || $0.hasSuffix(cls) || $0.hasSuffix(core) }!)。\(note)" }
                let what = e.classes.first.map { "\(e.name)是\($0)" } ?? ""
                return "不是。" + (note.isEmpty ? what + "。" : note)
            }
            return judge(core, e, es, yes: "是的", no: "不是")
        }
        // 會、能、可以：「貓會游泳嗎」「企鵝會飛嗎」
        for v in ["會", "能夠", "能", "可以"] where r.hasPrefix(v) {
            let x = String(r.dropFirst(v.count))
            guard x.count >= 1 else { return nil }
            func item(_ list: String?) -> String? { list?.split(separator: "、").map(String.init).first { $0.hasPrefix(x) || $0.contains(x) && x.count >= 2 } }
            if let it = item(e.attr("不會")) {
                let why = e.whys.first { $0.keys.contains { $0.contains(x) || x.contains($0) } }?.text ?? e.attr("說明").flatMap { $0.contains(x) ? $0 : nil }
                // 不會這個，但會別的（「鴕鳥不會飛，不過牠跑得很快」）
                let but = e.attr("會")?.split(separator: "、").first.map { "不過\(e.name)會\($0)。" } ?? ""
                return "不會。\(e.name)不會\(it)。" + (why.map { $0 + "。" } ?? but)
            }
            if let it = item(e.attr("會")) {
                var s = "會！"
                if let p = it.range(of: "（") { s += "\(e.name)會\(it[..<p.lowerBound])\(it[p.lowerBound...])。" } else { s += "\(e.name)會\(it)。" }
                return s
            }
            return judge(x, e, es, yes: v == "會" ? "會" : "可以", no: v == "會" ? "不會" : "不行")
        }
        // 有：「人有尾巴嗎」→ 有對應的屬性就說
        if r.hasPrefix("有") {
            let x = String(r.dropFirst())
            if let v = e.attr(x) {
                if v.hasPrefix("沒有") || v.hasPrefix("不") { return "沒有，\(e.name)\(v)。" + (e.attr("說明").map { $0 + "。" } ?? "") }
                return "有。\(phrase(e, x, v, now: Date()))"
            }
        }
        return nil
    }

    /// 在相關的事實裡找到這件事，看是肯定還是否定（「月亮會發光嗎」→「月亮自己不會發光」→ 不會）
    static func judge(_ x: String, _ e: Entity, _ es: [Entity], yes: String, no: String) -> String? {
        guard x.count >= 1 else { return nil }
        var texts: [String] = []
        for o in es {
            texts += o.whys.filter { $0.keys.contains { $0.contains(x) || x.contains($0) } }.map { $0.text }
            texts += o.attrs.filter { !$0.key.hasPrefix("因:") && $0.key != "簡介" }.map { $0.value }
            if let s = o.attr("簡介") { texts.append(s) }
        }
        for s in texts {
            guard let neg = negated(s, x) else { continue }
            let sentence = s.hasSuffix("。") ? s : s + "。"
            return (neg ? no : yes) + "。" + sentence
        }
        return nil
    }

    static func choice(_ e: Entity, _ a: String, _ b: String) -> String? {
        func has(_ x: String) -> Bool {
            let c = classWords[x] ?? x
            return e.classes.contains { $0 == c || $0.hasSuffix(c) }
        }
        let note = e.attr("說明").map { $0 + "。" } ?? ""
        switch (has(a), has(b)) {
        case (true, true): return "兩個都對！" + note
        case (true, false): return "是\(a)。" + note
        case (false, true): return "是\(b)。" + note
        default:
            return e.classes.first.map { "都不是，\(e.name)是\($0)。" + note }
        }
    }

    // MARK: 有幾個

    static let nounAlias: [String: String] = ["骨": "骨頭", "牙": "牙齒", "腿": "腳", "顏色": "顏色", "色": "顏色", "月亮": "衛星", "肌肉": "肌肉",
                                              "血": "血液", "腎": "腎臟", "州": "州", "縣市": "縣市", "縣": "縣市", "省": "省"]

    static func count(_ rest: String, _ es: [Entity]) -> String? {
        guard let g = RuleBook.match(rest.replacingOccurrences(of: "　", with: ""), #"(?:幾|多少)(?:個|顆|根|塊|條|隻|種|位|名|座|節|對|片|公升)?([\p{Han}]{1,4})"#) else { return nil }
        var noun = g[0]
        for s in ["呢", "嗎", "啊"] where noun.hasSuffix(s) { noun.removeLast() }
        guard !noun.isEmpty else { return nil }
        let candidates = [noun, nounAlias[noun], noun.count > 1 ? nounAlias[String(noun.prefix(1))] : nil, String(noun.prefix(2))].compactMap { $0 }
        for e in es {
            for k in candidates { if let v = e.attr(k) { return phrase(e, k, v, now: Date()) } }
            if let a = e.attrs.first(where: { !$0.key.hasPrefix("因:") && $0.key.count >= 2 && noun.hasPrefix($0.key) }) { return phrase(e, a.key, a.value, now: Date()) }
        }
        return nil
    }

    // MARK: 說成一句話

    static func phrase(_ e: Entity, _ key: String, _ v: String, now: Date) -> String {
        let n = e.name
        var s: String
        switch key {
        case "首都": s = "\(n)的首都是\(v)。"
        case "洲": s = "\(n)在\(v)。"
        case "語言": s = "\(n)主要說\(v)。"
        case "貨幣": s = "\(n)用的貨幣是\(v)。"
        case "吃": s = v.hasPrefix("依") ? "\(n)\(v)。" : "\(n)\(e.kind == "節日" ? "會吃" : "吃")\(v)。"
        case "住": s = v.hasPrefix("依") ? "\(n)\(v)。" : "\(n)住在\(v)。"
        case "壽命": s = "\(n)的壽命：\(v)。"
        case "腳":
            if v.hasPrefix("沒有") { s = "\(n)\(v)。" }
            else if let r = v.range(of: "隻") { s = "\(n)有 \(v[..<r.upperBound])腳\(v[r.upperBound...])。" }
            else { s = "\(n)有 \(v)。" }
        case "年代": s = "\(n)生活在\(v)。"
        case "國籍": s = v.contains("出生") ? "\(n)是\(v)。" : v.contains("（") ? "\(n)是\(v.replacingOccurrences(of: "（", with: "人（"))。" : "\(n)是\(v)人。"
        case "代表作": s = "\(n)的代表作和成就：\(v)。"
        case "名言": s = "\(n)的名言：「" + v.split(separator: "；").joined(separator: "」「") + "」"
        case "發明者": s = "\(n)的發明者：\(v)。"
        case "就醫": s = v + "。"
        case "年份": s = "\(n)出現在\(v)。"
        case "日期": return festivalAnswer(e, now: now)
        case "習俗": s = "\(n)的習俗：\(v)。"
        case "由來": s = "\(n)的由來：\(v)。"
        case "好處": s = "\(n)的好處：\(v)。"
        case "壞處": s = "要注意的地方：\(v)。"
        default:
            let head = String(v.prefix { !"：，；（".contains($0) })
            if v.first?.isNumber == true, head.count <= 8, !["距離", "溫度", "沸點", "冰點", "速度", "年齡", "大小", "密度", "時間", "人口", "面積", "高度", "長度"].contains(key) {
                s = "\(n)有 " + (head.contains(key) ? v : head + key + String(v.dropFirst(head.count))) + "。"
            } else if v.first?.isNumber == true {
                s = "\(n)的\(key)是 \(v)。"
            } else if ["離", "在", "從", "大約", "約"].contains(where: { v.hasPrefix($0) }) {
                s = "\(n)\(v)。"
            } else {
                s = v.contains(key) || v.hasPrefix(n) ? v + "。" : "\(n)的\(key)：\(v)。"
            }
        }
        // 國家的首都：補一句（「最大的城市是伊斯坦堡，不是首都」「中華民國政府在台北」）
        if key == "首都", let note = e.attr("特點") { s += note + "。" }
        return s
    }

    static func define(_ e: Entity, now: Date) -> String? {
        guard let intro = e.attr("簡介") else { return nil }
        var s = "\(e.name)是\(intro)。"
        switch e.kind {
        case "人物":
            if let x = e.attr("年代") { s += "\n他生活在\(x)。" }
            if let x = e.attr("代表作") { s += "\n代表作和成就：\(x)。" }
            if let x = e.attr("名言") { s += "\n名言：「" + (x.split(separator: "；").first.map(String.init) ?? x) + "」" }
        case "國家":
            if let c = e.attr("首都"), let l = e.attr("語言") { s += "\n首都是\(c)，主要說\(l)，貨幣是\(e.attr("貨幣") ?? "")。" }
        case "節日":
            s += "\n" + festivalAnswer(e, now: now)
            if let x = e.attr("吃") { s += "\n這天會吃\(x)。" }
        case "發明":
            if let x = e.attr("發明者") { s += "\n\(x)。" }
        default:
            if let x = e.attr("說明") { s += "\n\(x)。" }
            if let x = e.attr("特點") { s += "\n有趣的是：\(x)。" }
        }
        if let x = e.attr("看法") { s += "\n\n我的看法：\(x)。" }
        return s
    }

    // MARK: - 節日的日期

    static func festivalNamed(_ t: String) -> Entity? {
        let alt = ["過年": "春節", "新年": "春節", "聖誕": "聖誕節", "耶誕": "聖誕節"]
        let key = alt[t] ?? t
        return facts.first { $0.kind == "節日" && $0.names.contains(key) }
    }

    /// 今天之後（含今天）最近的一次
    static func nextDate(of e: Entity, from now: Date) -> Date? {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: now)
        let y = Everyday.ymd(now).y
        for yy in [y, y + 1] {
            if let d = date(of: e, year: yy), d >= today { return d }
        }
        return nil
    }

    /// 某一年（國曆）裡的那一天
    static func date(of e: Entity, year y: Int) -> Date? {
        guard let rule = e.attr("日期") else { return nil }
        let p = rule.split(separator: ":").map(String.init)
        let a = p[1].split(separator: "-").map(String.init)
        switch p[0] {
        case "solar":
            return Everyday.make(y, Int(a[0])!, Int(a[1])!)
        case "nth":
            let (m, n, wd) = (Int(a[0])!, Int(a[1])!, Int(a[2])!)
            guard let first = Everyday.make(y, m, 1) else { return nil }
            let w = Everyday.ymd(first).w
            return Everyday.make(y, m, 1 + (wd - w + 7) % 7 + (n - 1) * 7)
        case "term":
            let day = Astro.localDay(Astro.solarTermJD(y, Double(a[0])!))
            let (yy, mm, dd, _) = Astro.date(fromJD: Double(day) - 0.5)
            return Everyday.make(yy, mm, dd)
        case "lunar":
            // 國曆這一年裡，農曆是那個月日的那一天（除夕＝正月初一的前一天）
            var d = Everyday.make(y, 1, 1)!
            let cal = Calendar(identifier: .gregorian)
            for _ in 0..<366 {
                let c = Everyday.ymd(d)
                guard c.y == y else { break }
                let l = LunarCalendar.shared.lunar(c.y, c.m, c.d)
                if a[1] == "last" {
                    let next = cal.date(byAdding: .day, value: 1, to: d)!, nc = Everyday.ymd(next)
                    let nl = LunarCalendar.shared.lunar(nc.y, nc.m, nc.d)
                    if nl.month == 1 && nl.day == 1 && !nl.isLeap { return d }
                } else if !l.isLeap && l.month == Int(a[0])! && l.day == Int(a[1])! {
                    return d
                }
                d = cal.date(byAdding: .day, value: 1, to: d)!
            }
            return nil
        default:
            return nil
        }
    }

    static func festivalAnswer(_ e: Entity, now: Date) -> String {
        guard let rule = e.attr("日期"), let next = nextDate(of: e, from: now) else { return e.attr("簡介").map { "\(e.name)是\($0)。" } ?? "" }
        let kind = rule.split(separator: ":")[0]
        let a = rule.split(separator: ":")[1].split(separator: "-").map(String.init)
        var how = ""
        switch kind {
        case "solar": how = "每年國曆 \(a[0]) 月 \(a[1]) 日"
        case "lunar": how = a[1] == "last" ? "農曆一年的最後一天" : "每年農曆\(GZ.monthNames[Int(a[0])! - 1])月\(GZ.lunarDayName(Int(a[1])!))"
        case "nth": how = "每年 \(a[0]) 月的第\(["", "一", "二", "三", "四"][Int(a[1])!])個星期\(Everyday.weekdays[Int(a[2])! - 1])"
        default: how = "跟著節氣走，每年日期差一兩天"
        }
        let cal = Calendar(identifier: .gregorian)
        let n = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: next).day ?? 0
        var when = n == 0 ? "就是今天！" : "下一次是 \(Everyday.show(next, year: true))，還有 \(n) 天。"
        let y = Everyday.ymd(now).y
        if n > 0, Everyday.ymd(next).y > y, let past = date(of: e, year: y) { when = "今年的已經在 \(Everyday.show(past))過了，" + when }
        var s = "\(e.name)是\(how)。\(when)"
        if let x = e.attr("說明"), x.count < 60 { s += x + "。" }
        else if kind != "solar", let x = e.attr("簡介"), x.contains("台灣") || x.contains("大陸") { s += x + "。" }
        if ["兒童節", "父親節", "教師節", "國慶日", "感恩節"].contains(e.name), let x = e.attr("簡介") { s = x + "。" + when }
        return s
    }

    /// 某一天是什麼節日（「今天是什麼日子」）
    static func festival(on day: Date) -> String? {
        let y = Everyday.ymd(day).y
        let cal = Calendar(identifier: .gregorian)
        return facts.filter { $0.kind == "節日" }.first { e in date(of: e, year: y).map { cal.isDate($0, inSameDayAs: day) } ?? false }?.name
    }
}
