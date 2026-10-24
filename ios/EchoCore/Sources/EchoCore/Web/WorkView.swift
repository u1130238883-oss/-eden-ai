import Foundation

/// 作品的主見：讀完資料，用自己的話說出它的主題、我的看法（不是一直引用別人的句子）。
/// 主題從講這部作品的句子裡找根據（至少兩句提到，或劇情裡就有），沒有根據的不亂說。
enum WorkView {
    struct Theme {
        let name: String
        /// 句子裡有這些字，就是在講這個主題
        let words: [String]
        /// 用自己的話解釋：這個主題在故事裡是什麼樣子
        let explain: String
        /// 表面上看起來像什麼（給「表面上…其實…」用）
        let surface: String
        /// 我的看法：為什麼這個主題重要、它打動人的地方
        let view: String
        /// 適合誰看
        let audience: String
        /// 還要有這些字其中一個才算（「愛而不得」要有挫折、訂婚、失戀……不然只是一般的愛情故事）
        var needs: [String] = []
        /// 表面的主題（愛情、死亡、戰爭）：故事看起來是這樣，但通常不是它成為經典的原因
        var surfaceOnly = false
    }

    static let themes: [Theme] = [
        Theme(name: "愛而不得", words: ["愛上", "愛情", "戀愛", "戀人", "單戀", "暗戀", "失戀", "訂婚", "情人"],
              explain: "故事的核心是一段無法圓滿的感情：主角把全部的熱情放在一個得不到的人身上，越投入越痛苦。",
              surface: "一段愛情故事",
              view: "我覺得主角的悲劇不只是太癡情，而是他把人生全部的意義都押在一段感情上，一旦落空，就什麼都不剩了。",
              audience: "曾經很用力地喜歡過一個人",
              needs: ["訂婚", "挫折", "失戀", "自殺", "無望", "得不到", "單戀", "拒絕", "分離", "悲痛", "絕望"], surfaceOnly: true),
        Theme(name: "愛情", words: ["愛上", "愛情", "戀愛", "戀人", "婚姻", "結婚", "傲慢", "偏見"],
              explain: "愛情是推動故事的力量：角色在相處、誤會和和解裡，慢慢看清對方，也看清自己。",
              surface: "一段愛情故事",
              view: "我覺得它好看的地方是，愛情在裡面不是終點，而是讓角色放下成見、變成更好的人的過程。",
              audience: "喜歡細膩的感情故事"),
        Theme(name: "個人和社會的衝突", words: ["封建", "格格不入", "禮教", "等級", "世俗", "庸俗", "體制", "鄙陋", "社會的"],
              explain: "主角的痛苦不只來自個人遭遇，也來自他跟身處的社會格格不入——規矩、階級和世俗的眼光，讓他找不到容身的地方。",
              surface: "一個人的遭遇",
              view: "這才是它到今天還有力量的原因：很多人都有過「自己跟周圍格格不入」的時候，它把那種喘不過氣的感覺寫得很真實。",
              audience: "常覺得自己跟周圍格格不入"),
        Theme(name: "追求自我和自由", words: ["自由", "解放", "個性", "自我", "束縛", "做自己"],
              explain: "作品在問：一個人能不能照自己的心意活，而不是照別人規定的樣子活。",
              surface: "一段個人經歷",
              view: "我認為它真正的價值是把「想做自己」的渴望說得理直氣壯——就算結局不圓滿，那份渴望本身就值得被看見。",
              audience: "正在想自己到底要什麼樣的人生"),
        Theme(name: "成長", words: ["成長", "長大", "獨立", "勇氣", "蛻變", "學會"],
              explain: "主角從依賴、害怕，慢慢變成能靠自己面對困難的人；故事真正的變化，發生在角色的心裡。",
              surface: "一場奇幻的冒險",
              view: "我覺得它好看的地方在於，成長不是靠別人拯救，而是主角在一次次害怕裡，自己決定往前走。",
              audience: "正在面對陌生環境、需要一點勇氣"),
        Theme(name: "絕望與死亡", words: ["自殺", "死亡", "絕望", "無望", "悲痛", "悲劇", "死去"],
              explain: "結局走向死亡，讓人看到一個人被情感和處境逼到盡頭時有多脆弱。",
              surface: "一個悲傷的結局",
              view: "它不是在美化死亡，而是在提醒：當一個人覺得無路可走時，身邊的人和社會其實都有責任。",
              audience: "想讀一部會讓人沉思很久的悲劇", surfaceOnly: true),
        Theme(name: "孤獨", words: ["孤獨", "寂寞", "孤單", "疏離", "隔閡"],
              explain: "角色身邊不是沒有人，卻沒有人真正懂他；孤獨是貫穿全篇的底色。",
              surface: "一段平靜的日常",
              view: "我覺得它最動人的地方，是把那種「說了也沒人懂」的孤單寫得很安靜，卻很重。",
              audience: "有過說不出口的孤單"),
        Theme(name: "人性與欲望", words: ["貪婪", "欲望", "慾望", "貪吃", "貪心", "人性", "自私", "善良", "良知"],
              explain: "故事把人的貪心、自私和善良放在一起對照，讓人看清欲望怎麼把人變成另一個樣子。",
              surface: "一個奇幻或驚險的故事",
              view: "我認為它最厲害的地方是不說教：它只是讓你看到角色怎麼被欲望一步步改變，答案留給你自己想。",
              audience: "喜歡會讓人反思自己的故事"),
        Theme(name: "善與惡", words: ["善良", "邪惡", "嫉妒", "懲罰", "惡毒", "狡猾", "繼母", "巫婆", "詛咒", "承諾", "誠實", "壞人", "好人", "報應"],
              explain: "故事把善良和惡意放在一起：守信、勇敢、心地好的人最後被看見，貪心、嫉妒、狡猾的人付出代價。",
              surface: "給小孩聽的床邊故事",
              view: "我覺得它們好看的地方，是用很簡單的情節講很重的道理；長大再讀，會發現這些故事其實很殘酷、很真實——它們是在教孩子認識世界有多危險，也提醒善良要帶著勇氣。",
              audience: "想找能跟孩子一起讀、又能自己重新想一想的故事"),
        Theme(name: "不被打倒的意志", words: ["堅持", "搏鬥", "不放棄", "奮鬥", "抗爭", "意志", "尊嚴", "打不倒", "打敗"],
              explain: "主角面對的對手比他強大太多，但他沒有放棄；重點不是贏，而是怎麼面對失敗。",
              surface: "一場力量懸殊的戰鬥",
              view: "我覺得它最有力量的一句話就是它整個故事本身：人可以被打敗，但不能被擊垮。",
              audience: "正在撐一件很難的事"),
        Theme(name: "權力怎麼腐化人", words: ["極權", "權力", "獨裁", "監控", "統治", "革命", "宣傳", "洗腦", "特權"],
              explain: "故事裡原本說要追求平等的人，一旦掌握權力就慢慢變成他們反對的樣子；它在寫權力怎麼一點一點改變人和規則。",
              surface: "一則寓言或未來故事",
              view: "我認為它到今天還不過時，因為它寫的不是某一個國家，而是任何權力沒有被制衡時都可能發生的事。",
              audience: "關心社會、喜歡思考制度"),
        Theme(name: "貧富差距", words: ["貧富", "階級", "窮人", "富人", "貧窮", "富有", "底層", "上流"],
              explain: "作品把不同階層的人放在同一個空間裡，讓差距變得看得見、摸得到。",
              surface: "一個緊張的故事",
              view: "我覺得它最狠的地方是沒有誰是單純的壞人——是整個處境把人推向那樣的選擇。",
              audience: "對社會不平等有感觸"),
        Theme(name: "家人", words: ["父母", "父親", "母親", "家人", "親情", "家庭", "兒子", "女兒"],
              explain: "家人之間的愛與誤解是故事的重心，很多選擇都是為了家人做的。",
              surface: "一段家庭故事",
              view: "我覺得它讓人在意的是：最親的人，往往也是最難好好說話的人。",
              audience: "跟家人之間有說不清的心結", surfaceOnly: true),
        Theme(name: "友情", words: ["友情", "朋友", "友誼", "夥伴", "同伴"],
              explain: "角色之間的陪伴和信任，是他們撐過難關的力量。",
              surface: "一段冒險",
              view: "我認為它最溫暖的地方，是讓人相信有人願意陪你走一段很難的路。",
              audience: "想念以前一起拼過的朋友"),
        Theme(name: "命運", words: ["命運", "宿命", "註定", "預言"],
              explain: "角色越想擺脫命運，越一步步走進命運安排的路；故事在問人能不能決定自己的結局。",
              surface: "一連串的巧合",
              view: "我覺得它的重點不是命運有多可怕，而是人在命運面前做的每個選擇都還是算數的。",
              audience: "喜歡思考人生的選擇"),
        Theme(name: "復仇與正義", words: ["復仇", "報仇", "正義", "背叛", "冤屈"],
              explain: "故事圍繞著一個人被背叛後的復仇，也在問復仇能不能真的帶來正義。",
              surface: "一個大快人心的復仇故事",
              view: "我認為它最耐人尋味的，是報了仇之後主角並沒有真的得到平靜——正義和復仇不是同一件事。",
              audience: "喜歡情節緊湊、又有深度的故事"),
        Theme(name: "戰爭", words: ["戰爭", "戰火", "士兵", "戰場", "侵略"],
              explain: "戰爭不是背景而是主角：它讓普通人做出平常不會做的選擇。",
              surface: "一段歷史",
              view: "我覺得它最有分量的地方，是讓人看到戰爭裡每個「數字」背後都是一個人。",
              audience: "想了解歷史裡的人"),
        Theme(name: "夢想與追尋", words: ["夢想", "追尋", "尋找", "旅程", "天命", "寶藏"],
              explain: "主角踏上旅程去找一個目標，但一路上的經歷，比找到的東西更重要。",
              surface: "一趟冒險",
              view: "我認為它真正想說的是：答案常常不在終點，而是在你願意出發的那一刻。",
              audience: "正在猶豫要不要追一個夢"),
        Theme(name: "真正重要的東西", words: ["馴養", "責任", "看不見", "本質", "大人", "純真", "童心", "玫瑰"],
              explain: "作品用孩子的眼光看大人的世界，提醒我們真正重要的東西——愛、責任、關係——是用心才看得見的。",
              surface: "一本童話",
              view: "我覺得它寫給大人看比寫給小孩看更有意思：它讓人發現自己長大以後丟掉了什麼。",
              audience: "覺得生活只剩忙碌、想找回一點初心"),
        Theme(name: "文明與人類的未來", words: ["文明", "宇宙", "外星", "科技", "人類的命運", "地球", "科幻"],
              explain: "故事把人類放到更大的尺度上看：當文明面對未知，人性、科學和生存會被怎麼考驗。",
              surface: "一部科幻小說",
              view: "我認為它厲害的地方是用很大的格局寫很真實的人性——科幻只是外殼，裡面講的是人會怎麼選擇。",
              audience: "喜歡大格局、會讓人想很久的故事", needs: ["文明", "科幻", "宇宙"]),
    ]

    /// 主題出現在哪些句子：劇情句算兩次（故事本身就在講它），至少要有兩分才算
    /// 當根據的句子：有書名、講到越多這個主題的字越好，長度適中；側欄連結、標題（「【小說連載】…」「上一篇」）不算
    /// 寫作背景（作者的真實經歷、角色的原型）不是作品的內容，不拿來當主題的根據
    static let background = ["創作", "原型", "真實", "根據自身", "親身", "作者", "寫作", "出版", "靈感", "源自", "激發", "啟發", "取材", "同事",
                             "禁書", "被視為", "列為", "又譯", "原名", "譯名"]

    /// 角色的名字：在好幾句劇情裡都出現的雙字詞（維特、綠蒂、千尋），當根據的句子有講到角色比較好
    static func characters(_ plot: [String]) -> Set<String> {
        var count: [String: Int] = [:]
        for p in plot {
            let c = Array(p.filter { $0.isLetter && !$0.isASCII })
            guard c.count >= 2 else { continue }
            for g in Set((0..<(c.count - 1)).map { String(c[$0...$0 + 1]) }) { count[g, default: 0] += 1 }
        }
        let common: Set<String> = ["故事", "小說", "一個", "他們", "自己", "之後", "最後", "世界", "少年", "少女", "成長", "愛上", "講述", "描寫"]
        return Set(count.filter { $0.value >= 2 && !common.contains($0.key) }.keys)
    }

    static func evidence(_ cands: [String], theme t: Theme, title: String, people: Set<String> = []) -> String? {
        let junk = ["【", "連載", "上一篇", "下一篇", "留言", "分享", "延伸閱讀", "目錄", "標籤", "這本書給我", "很想再", "動機"]
        func score(_ s: String) -> Int {
            // 「我才發現…」是心得，不是根據：扣分
            (s.contains(title) ? 3 : 0) + (people.contains { s.contains($0) } ? 2 : 0) - (s.contains("我") ? 2 : 0) + t.words.filter { s.replacingOccurrences(of: title, with: "").contains($0) }.count * 2
                - (s.count > 60 ? 2 : 0) - (s.count < 14 ? 3 : 0)
        }
        // 要講到這部作品或裡面的角色（「耶路撒冷用來自殺的手槍」講的是真實人物，不是小說）
        return cands.filter { s in (10...90).contains(s.count) && !junk.contains { s.contains($0) } && !background.contains { s.contains($0) }
            && (s.contains(title) || people.contains { s.contains($0) } || ["這部", "作品", "小說", "故事", "書中", "本書", "全書", "劇中", "片中"].contains { s.hasPrefix($0) }) }
            .max { score($0) < score($1) }
    }

    static func found(in sentences: [String], plot: [String], title: String = "") -> [(theme: Theme, score: Int, evidence: String)] {
        var out: [(theme: Theme, score: Int, evidence: String)] = []
        let people = characters(plot)
        for t in themes {
            // 同一組字：已經是「愛而不得」就不再算一般的「愛情」
            if t.name == "愛情", out.contains(where: { $0.theme.name == "愛而不得" }) { continue }
            if !t.needs.isEmpty, !(sentences + plot).contains(where: { s in t.needs.contains { s.contains($0) } }) { continue }
            // 書名裡的字不算（《寄生上流》的「上流」不是在講貧富）
            func has(_ s: String) -> Bool { let x = title.isEmpty ? s : s.replacingOccurrences(of: title, with: ""); return t.words.contains { x.contains($0) } }
            let inPlot = plot.filter(has)
            let inAll = sentences.filter(has)
            let score = inPlot.count * 2 + inAll.count
            // 找不到夠好的根據句也沒關係：主題本身很明顯（分數高）就照樣說，只是不附引文
            guard score >= 2 else { continue }
            let ev = evidence(inAll.filter { !plot.contains($0) }, theme: t, title: title, people: people) ?? inPlot.first ?? ""
            if ev.isEmpty && score < 4 { continue }
            out.append((t, score, ev))
        }
        return out.sorted { $0.score > $1.score }
    }

    /// 劇情句整理成一段話：去掉開頭的背景、評論（「小說描寫…的體驗和感受，表現了作者…」）和「《X》講述」這類開頭，
    /// 被截斷的半句（「…請託掌管者…」）不要；後面接著發生的事用「後來」「最後」串起來
    static func story(_ sentences: [String], title: String, events: [String]) -> String {
        let commentary = ["表現了", "作者", "體驗和感受", "反映", "象徵", "探討", "批判", "寓意", "表達了", "諷刺", "必然", "趨勢"]
        var parts: [String] = []
        for (i, s) in sentences.enumerated() {
            var body = s.trimmingCharacters(in: CharacterSet(charactersIn: "。 "))
            // 截斷的句子：只留到最後一個完整的子句
            let trimmed = body.replacingOccurrences(of: #"[\s\.…]+$"#, with: "", options: .regularExpression)
            if trimmed != body {
                body = trimmed
                guard let cut = body.lastIndex(where: { "，；,;".contains($0) }) else { continue }
                body = String(body[..<cut])
            }
            var clauses = body.components(separatedBy: CharacterSet(charactersIn: "，；：,;:"))
            while let c = clauses.first, clauses.count > 1, commentary.contains(where: { c.contains($0) }) { clauses.removeFirst() }
            // 開頭沒有事情發生的短句（「《老人與海》的故事很簡單」）：拿掉
            while let c = clauses.first, clauses.count > 1, c.replacingOccurrences(of: "《\(title)》", with: "").count <= 10, !events.contains(where: { c.contains($0) }) {
                clauses.removeFirst()
            }
            clauses = clauses.filter { c in !commentary.contains { c.contains($0) } }
            guard var head = clauses.first else { continue }
            head = head.replacingOccurrences(of: "《\(title)》", with: "")
            head = head.replacingOccurrences(of: #"^(?:這部|小說|故事|書中|全書|電影|影片|劇中)?(?:劇情)?(?:主要)?(?:描寫|講述|描述|敘述|寫的是|講|說)(?:了|的是|著)?"#,
                                             with: "", options: .regularExpression)
            // 接著發生的事：「之後，」換成「後來」，最後一句用「最後」
            if i > 0, ["之後", "後來", "然後", "接著"].contains(head) { clauses.removeFirst(); head = clauses.first ?? "" }
            if clauses.isEmpty { continue }
            clauses[0] = head
            var t = clauses.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "，")
            if i > 0 && !t.hasPrefix("最後") && !t.hasPrefix("後來") { t = (i == sentences.count - 1 && sentences.count > 2 ? "最後" : "後來") + t }
            if !t.isEmpty { parts.append(t) }
        }
        var out = ""
        for p in parts where out.isEmpty || out.count + p.count <= 170 { out += (out.isEmpty ? "" : "；") + p }
        return out.isEmpty ? "" : out + "。"
    }

    /// 只留夠有根據的主題：第一名一定留；後面的分數要有第一名的一半以上、至少 3 分
    static func strong(_ found: [(theme: Theme, score: Int, evidence: String)]) -> [(theme: Theme, score: Int, evidence: String)] {
        guard let top = found.first else { return [] }
        var rest = Array(found.dropFirst())
        var out = [top]
        // 最有根據的是表面的主題（愛情、死亡）：第二個先找比較深的主題（有根據就好），才說得出「表面上…其實…」
        if top.theme.surfaceOnly, let i = rest.firstIndex(where: { !$0.theme.surfaceOnly && $0.score >= 2 }) {
            out.append(rest.remove(at: i))
        } else if let second = rest.first, second.score >= 3 {
            out.append(rest.removeFirst())
        }
        if out.count == 2, let third = rest.first, third.score >= max(3, (top.score + 1) / 2) { out.append(third) }
        return out
    }

    /// 我的看法：挑最有根據的一兩個主題，說出明確的立場，最後說適合誰。
    /// 最有根據的主題是表面的（愛情、死亡）→「表面上是…，但真正讓它成為經典的是…」；本身就夠深 → 直接說它的核心是什麼
    static func opinion(title: String, medium: String, picked: [Theme]) -> String {
        guard let a = picked.first else { return "" }
        func soft(_ v: String) -> String { v.replacingOccurrences(of: #"^(?:我認為|我覺得)"#, with: "", options: .regularExpression) }
        var t = ""
        if a.surfaceOnly, let deep = picked.dropFirst().first(where: { !$0.surfaceOnly }) {
            t = "我認為《\(title)》表面上是\(a.surface)，但真正讓它成為經典的，是它對「\(deep.name)」的刻畫。"
            t += a.view.replacingOccurrences(of: #"^我認為"#, with: "我覺得", options: .regularExpression) + "而且，" + soft(deep.view)
        } else if let b = picked.dropFirst().first {
            t = "我認為《\(title)》最核心的是「\(a.name)」，再加上「\(b.name)」，讓它不只是\(a.surface)。"
            t += a.view.replacingOccurrences(of: #"^我認為"#, with: "我覺得", options: .regularExpression) + "而且，" + soft(b.view)
        } else {
            t = "我認為《\(title)》最值得看的，是它對「\(a.name)」的刻畫。" + a.view
        }
        t += "如果你\(a.audience)，\(medium)會讓你很有共鳴。"
        return t
    }
}
