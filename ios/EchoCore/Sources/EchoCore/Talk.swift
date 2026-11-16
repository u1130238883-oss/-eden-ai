import Foundation

/// NineSun 自己的話（ai/commonsense/data/talk.txt → CommonsenseData.talk）：
/// 關於自己（有沒有感情、喜歡什麼、幾歲）、自己的看法（AI 會不會取代人類、有沒有外星人、算命準不準）、
/// 笑話、人生的選擇題（該不該換工作、要不要告白、怎麼交到女朋友）。
///
/// 以前這些問題會被當成在說心情、被十二宮感知帶去講宮位（「你喜歡什麼」→「我感覺到戀愛的氣息」），
/// 或是回「這個我沒學過」。問法比對整句（拿掉標點、語氣詞），寫得很準，寧可漏接也不亂攔。
public enum Talk {
    struct Entry {
        let name: String
        let kind: String
        var asks: [NSRegularExpression]
        var answers: [String]
    }

    static let entries: [Entry] = {
        var out: [Entry] = []
        for line in CommonsenseData.talk.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("@") {
                let p = line.dropFirst().split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                out.append(Entry(name: p[0], kind: p.count > 2 ? p[2] : "", asks: [], answers: []))
            } else if line.hasPrefix("問="), !out.isEmpty, let re = try? NSRegularExpression(pattern: String(line.dropFirst(2)), options: [.caseInsensitive]) {
                out[out.count - 1].asks.append(re)
            } else if line.hasPrefix("答="), !out.isEmpty {
                out[out.count - 1].answers.append(String(line.dropFirst(2)).replacingOccurrences(of: "⏎", with: "\n"))
            }
        }
        return out
    }()

    /// 比對用的句子：標點、空白、結尾的語氣詞拿掉，「妳」當「你」
    static func clean(_ raw: String) -> String {
        var t = raw.replacingOccurrences(of: "妳", with: "你").replacingOccurrences(of: "您", with: "你")
        t = t.filter { !"，,。.！!？?～~、：:；;「」『』\"' ".contains($0) && !$0.isWhitespace }
        for p in ["請問一下", "請問", "那", "欸", "嗯", "所以", "NineSun", "ninesun"] where t.hasPrefix(p) && t.count > p.count + 1 { t.removeFirst(p.count) }
        while let l = t.last, "呢啊呀喔哦啦吧耶嘛勒咧捏".contains(l), t.count > 1 { t.removeLast() }
        return t
    }

    /// 這次是第幾次被問到（笑話每次換一個）
    static var asked: [String: Int] = [:]

    public static func answer(_ raw: String) -> String? { detailed(raw)?.text }

    /// 聊天：對方在說自己的事（不是問問題）——照說的內容接話、問下去，不拿宮位亂回（使用者 2026-10-28：「不要用宮位亂回」）
    public static func chat(_ raw: String) -> String? {
        let t = clean(raw)
        guard t.count >= 2, t.count <= 24, !t.contains("嗎"), !t.contains("什麼"), !t.contains("怎麼"), !t.contains("為什麼") else { return nil }
        func m(_ p: String) -> [String]? { RuleBook.match(t, p) }
        // 別人的好消息（「我朋友要結婚了」）：替對方開心，不是「這是你努力換來的」
        if let g = m(#"^我(?:的)?(朋友|好朋友|同事|同學|姐姐|姊姊|哥哥|弟弟|妹妹|媽媽|爸爸|表姐|表哥|堂姐|堂哥|閨蜜|室友)(?:要|快要|下個月要|明年要)?(結婚|生小孩|生寶寶|懷孕|訂婚|升職|考上)(?:了)?$"#) {
            let what = g[1] == "結婚" || g[1] == "訂婚" ? "你會去參加嗎？要準備紅包或禮物的話，我可以幫你想祝福的話。" : "記得跟他說聲恭喜！"
            return "替你\(g[0])開心！🎉 \(what)"
        }
        // 剛做完的事
        if let g = m(#"^我?(?:剛|剛剛|才剛)(下班|下課|放學|回家|到家|起床|睡醒|醒來|吃飽|洗完澡|運動完|考完試|開完會)(?:了)?$"#) {
            switch g[0] {
            case "下班", "下課", "放學", "開完會": return "辛苦了！今天過得怎麼樣？晚餐吃了嗎？"
            case "起床", "睡醒", "醒來": return "早安（不管現在幾點都算）！睡得好嗎？"
            case "回家", "到家": return "歡迎回家～今天還好嗎？先好好休息一下。"
            case "吃飽": return "吃飽了真好～吃了什麼好吃的？"
            case "運動完": return "好棒！運動完記得補充水分、做一下伸展。今天做了什麼運動？"
            case "考完試": return "辛苦了！考得怎麼樣？不管結果如何，先好好放鬆一下。"
            default: return "感覺很舒服吧～接下來有什麼打算？"
            }
        }
        // 做了什麼：看了、吃了、買了、玩了……
        if let g = m(#"^我?(?:今天|剛剛|昨天|剛|早上|晚上|中午|週末)?(?:去)?(看|吃|買|玩|聽|讀|喝|追|逛)(?:了)(.{1,10})$"#) ?? m(#"^我?(?:今天|剛剛|昨天|剛|週末)?去(看|吃|買|玩|逛)(.{1,8})(?:了)$"#) {
            let x = g[1]
            switch g[0] {
            case "看", "追": return "\(x)好看嗎？在講什麼？我想聽聽你的心得。"
            case "吃": return "\(x)好吃嗎？在哪裡吃的？聽起來好想吃看看～"
            case "喝": return "\(x)好喝嗎？下次也推薦給我吧！"
            case "買": return "恭喜入手\(x)！用起來還喜歡嗎？"
            case "玩", "逛": return "\(x)好玩嗎？有什麼印象最深的事？"
            case "聽": return "\(x)好聽嗎？是誰唱的？"
            case "讀": return "\(x)好看嗎？在講什麼？"
            default: break
            }
        }
        // 今天做了的運動、活動（「我今天跑步了」）
        if let g = m(#"^我?(?:今天|剛剛|昨天|早上|晚上)?(跑步|游泳|健身|打球|爬山|騎車|散步|瑜珈|跳舞|上課|加班|打工|讀書|畫畫|煮飯)(?:了)?$"#) {
            return ["加班", "打工"].contains(g[0]) ? "辛苦了！累的話今天早點休息。" : "很棒耶！\(g[0])完感覺怎麼樣？"
        }
        // 要去哪裡、打算做什麼
        if let g = m(#"^我?(?:明天|後天|下週|下禮拜|下個月|週末|這週末|等一下|今天|今晚|過幾天|明年|下次)?(?:要|會|準備|打算|計畫)去(.{1,8}?)(?:玩|旅行|旅遊|出差|了)?$"#) {
            let x = g[0]
            var tip = ""
            if Library.lists.contains(where: { $0.names.contains(x + "的景點") }) { tip = "想知道那邊有什麼好玩的，問我「\(x)有什麼好玩的」。" }
            return "去\(x)！是去玩還是辦事？" + (tip.isEmpty ? "祝你一路順利～" : tip)
        }
        if let g = m(#"^我?(?:最近|現在|正)?在學(.{1,8})$"#) {
            return "學\(g[0])很棒！學多久了？卡住的地方可以問我，我幫你一起想辦法。"
        }
        if let g = m(#"^我?(?:現在|正|還)?在(家|公司|學校|外面|路上|車上|捷運上|公車上|辦公室|圖書館|咖啡廳|醫院|機場)$"#) {
            switch g[0] {
            case "家": return "在家放鬆一下也很好～現在在做什麼呢？"
            case "公司", "辦公室": return "上班辛苦了！今天忙嗎？"
            case "學校", "圖書館": return "加油！在讀什麼呢？需要的話可以問我。"
            case "醫院": return "怎麼了嗎？是你不舒服，還是陪家人？希望一切都好。"
            case "機場": return "要出發去哪裡呢？祝你一路順風！✈️"
            default: return "路上注意安全喔～要去哪裡呢？"
            }
        }
        if let g = m(#"^我?在等(公車|捷運|車|人|朋友|火車|高鐵|飛機|外送)$"#) {
            return "等\(g[0])的時候可以跟我聊聊天～要等很久嗎？"
        }
        // 喜歡的東西（不是人）：「我喜歡下雨天」
        if let g = m(#"^我(?:很|超|最|好)?(?:喜歡|愛)(.{1,8})$"#), !["你", "他", "她", "妳", "一個人", "上一個人", "我自己"].contains(where: { g[0].hasPrefix($0) }) {
            return "\(g[0])真不錯！你最喜歡它哪一點？"
        }
        // 想做的事
        if let g = m(#"^我(?:好|很|超|真的)?想(?:要)?(?:去)?(出去玩|出國|旅行|放假|休息|養狗|養貓|談戀愛|換工作|搬家)$"#) {
            switch g[0] {
            case "養狗", "養貓": return "養寵物很幸福，但也是十幾年的承諾：要想想時間（每天陪伴、散步）、空間、花費（飼料、醫療）。如果都 OK，也可以考慮領養！你喜歡什麼樣的\(g[0] == "養狗" ? "狗" : "貓")？"
            case "出去玩", "旅行", "出國": return "想去哪裡呢？近一點的話週末就能出發，遠一點的可以開始存旅費～告訴我想去哪，我幫你列景點。"
            case "放假", "休息": return "真的需要好好休息一下。能請個假、或週末安排一天什麼都不做嗎？"
            default: return "想\(g[0])的話，有什麼讓你這樣想的原因嗎？我們可以一起想想。"
            }
        }
        if let g = m(#"^我?(?:昨天|昨晚|今天|又|一直)?熬夜(打遊戲|玩遊戲|追劇|看劇|讀書|唸書|趕報告|工作|加班|滑手機)?(?:了)?$"#) {
            let what = g[0].isEmpty ? "" : "\(g[0])到很晚，"
            return "\(what)今天一定很睏吧！記得找時間補個午覺，今晚早點睡，身體會謝謝你的。"
        }
        if m(#"^(?:我)?(?:要|準備|快要)?搬家(?:了)?$"#) != nil {
            return "搬家很累但也很期待吧！搬去哪裡？需要的話我可以幫你列搬家要準備的事。"
        }
        if m(#"^(?:剛剛|外面|今天|現在)?(?:在)?下(?:大|好大的)?雨(?:了)?$"#) != nil {
            return "出門記得帶傘！淋濕了要趕快擦乾、換件衣服，別著涼了。"
        }
        if m(#"^(?:今天|最近|這幾天)?(?:好|很|超)?忙$"#) != nil {
            return "忙碌的一天辛苦了！記得中間喝點水、動一動，不要一直坐著。"
        }
        return nil
    }

    /// 外語的簡單寒暄（英文、西班牙文、義大利文）
    public static func foreign(_ raw: String, _ L: Lang) -> String? {
        let t = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "?!.¿¡ "))
        let table: [(String, [Lang: String])] = [
            (#"^(how are you|how are you doing|how's it going|how r u|what's up|whats up|sup)$"#,
             [.en: "I'm doing well, thanks for asking! How about you? Anything on your mind today?"]),
            (#"^(como estas|cómo estás|que tal|qué tal|como te va|cómo te va)$"#,
             [.es: "¡Estoy bien, gracias por preguntar! ¿Y tú? ¿Cómo va tu día?"]),
            (#"^(come stai|come va|tutto bene)$"#,
             [.it: "Sto bene, grazie! E tu? Com'è andata la giornata?"]),
            (#"^(tell me a joke|say something funny|another joke|joke)$"#,
             [.en: "Why don't scientists trust atoms? Because they make up everything. 😄"]),
            (#"^(cuéntame un chiste|cuentame un chiste|un chiste)$"#,
             [.es: "¿Qué le dice un pez a otro pez? ¡Nada! 🐟"]),
            (#"^(raccontami una barzelletta|una barzelletta|dimmi una barzelletta)$"#,
             [.it: "Qual è il colmo per un elettricista? Non fare scintille a scuola! ⚡"]),
            (#"^(thank you|thanks|thank you so much|thx|ty)$"#, [.en: "You're welcome! Happy to help anytime."]),
            (#"^(ok|okay|k|cool|nice|great|got it|i see|alright|sure)$"#, [.en: "👍 Anything else you'd like to ask or talk about?"]),
            (#"^(haha+|lol+|lmao|hehe+)$"#, [.en: "Glad that made you smile 😄 What's up?"]),
            (#"^(gracias|muchas gracias)$"#, [.es: "¡De nada! Aquí estoy cuando me necesites."]),
            (#"^(grazie|grazie mille)$"#, [.it: "Prego! Sono qui quando vuoi."]),
            (#"^(are you (a )?(robot|ai|human|real person))$"#,
             [.en: "I'm an AI, not a person. I'm NineSun, a little glowing TV robot: I can read your Nine-Twelve chart, BaZi and Zi Wei, answer questions, and look things up online."]),
            (#"^(do you have feelings|do you have emotions|can you feel)$"#,
             [.en: "Not the way people do. I don't get heartbroken or excited, but I'm built to care how you feel and to change how I talk when you're having a hard day."]),
            (#"^(what can you do|what do you do|help)$"#,
             [.en: "I can read your Nine-Twelve chart (today, this month, this year), BaZi and Zi Wei, answer everyday questions, tell jokes, translate, and look things up online. Tell me your birthday to get started!"]),
        ]
        for (p, answers) in table where t.range(of: p, options: .regularExpression) != nil {
            if let a = answers[L] { return a }
        }
        return nil
    }

    /// 剛剛回答的是哪一種（笑話、自己、看法、選擇…），追問時要接得上
    public static func detailed(_ raw: String) -> (text: String, kind: String, name: String)? {
        guard let a = match(raw) else { return nil }
        return a
    }

    /// 追問：笑話「再一個」「不好笑」、選擇題「可是我很怕」、看法「為什麼」
    public static func followUp(_ raw: String, kind: String) -> String? {
        let t = clean(raw)
        switch kind {
        case "笑話":
            if t.range(of: "^(再|再來|再講|再說|多講|多說|還有|還要|換)(一|一個|一則|個|則|點)?(笑話|個|好笑的)?(嗎|啦)?$|^還有嗎$|^還有呢$|^另一個$|^換一個$|^再一次$", options: .regularExpression) != nil {
                return answer("講個笑話")
            }
            if t.range(of: "^(不好笑|好冷|很冷|超冷|太冷了|好爛|很爛|沒梗|好無聊|聽不懂|不懂|冷笑話|尬)", options: .regularExpression) != nil {
                return "哈哈，好啦，這個是冷了一點😅 再給我一次機會：\n" + (answer("講個笑話") ?? "")
            }
            if t.range(of: "^(哈+|笑死|好笑|很好笑|超好笑|XD+|lol)$", options: [.regularExpression, .caseInsensitive]) != nil {
                return "看你笑我也開心！還要再聽一個嗎？"
            }
        case "選擇":
            if t.range(of: "^(可是|但是|但)?我(還是)?(很|好|有點|超|真的)?(怕|害怕|不敢|擔心|猶豫|不確定|很難決定|好難決定|不知道怎麼選|不知道要不要)", options: .regularExpression) != nil {
                return "會怕很正常，代表這件事對你很重要。可以試試這樣想：最壞的情況是什麼？如果真的發生，你有沒有辦法撐過去、有沒有退路？很多時候想清楚最壞的情況，反而就沒那麼怕了。你也不用一次決定，可以先做一個小小的、能回頭的試探。"
            }
        case "自己", "看法":
            if t.range(of: "^(為什麼|為何|怎麼說|為啥|真的嗎|是喔|是哦)$", options: .regularExpression) != nil {
                return "說不上有什麼大道理，這是我跟很多人聊天之後慢慢形成的想法。你呢？你怎麼看？"
            }
        default: break
        }
        return nil
    }

    static func match(_ raw: String) -> (text: String, kind: String, name: String)? {
        var t = clean(raw)
        // 整句只有標點（「？」「...」）：清掉就沒了，用原本的字比對
        if t.isEmpty { t = raw.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard t.count >= 1, t.count <= 30 else { return nil }
        let range = NSRange(t.startIndex..., in: t)
        for e in entries where !e.answers.isEmpty {
            guard e.asks.contains(where: { $0.firstMatch(in: t, range: range) != nil }) else { continue }
            // 聊到自己認識的東西（「我喜歡吃香蕉」）：讓常識接話，說一件那個東西的事
            if e.kind == "閒聊", Commonsense.react(raw) != nil { return nil }
            let n = asked[e.name, default: 0]
            asked[e.name] = n + 1
            // 笑話：每次換一個；其他：同一個問題給同一個回答（多個寫法時照問法輪替）
            let i = e.kind == "笑話" ? (n + t.count) % e.answers.count : t.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % e.answers.count
            return (e.answers[abs(i)], e.kind, e.name)
        }
        return nil
    }
}
