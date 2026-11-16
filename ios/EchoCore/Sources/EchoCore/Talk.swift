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
    /// 剛剛閒聊的主題（看、吃、旅行:日本、下班、養寵物…），對方接著回答時用
    static var lastChatTopic = ""

    public static func chat(_ raw: String) -> String? {
        lastChatTopic = ""
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
            lastChatTopic = "下班"
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
            lastChatTopic = g[0]
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
            lastChatTopic = "旅行:" + x
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
            case "養狗", "養貓":
                lastChatTopic = "養寵物"
                return "養寵物很幸福，但也是十幾年的承諾：要想想時間（每天陪伴、散步）、空間、花費（飼料、醫療）。如果都 OK，也可以考慮領養！你喜歡什麼樣的\(g[0] == "養狗" ? "狗" : "貓")？"
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

    /// 閒聊的下一句：NineSun 剛問了「好看嗎？」「是去玩還是辦事？」，對方的回答不是新的問題
    public static func chatAnswer(_ raw: String, topic: String) -> String? {
        let t = clean(raw)
        guard !t.isEmpty, t.count <= 24, !t.hasSuffix("嗎"), !["什麼", "怎麼", "為什麼", "哪", "誰", "幾", "多少"].contains(where: { t.contains($0) }) else { return nil }
        let positive = t.range(of: "好看|好吃|好玩|好喝|好聽|很棒|不錯|喜歡|超讚|很讚|很好|開心|順利|推薦|好用|滿意|感動", options: .regularExpression) != nil
            && t.range(of: "不好看|不好吃|不好玩|不喜歡|不推薦|不滿意", options: .regularExpression) == nil
        let negative = t.range(of: "不好看|難吃|不好吃|普通|還好|無聊|累|不好|爛|失望|難過|煩|後悔|雷", options: .regularExpression) != nil
        switch topic {
        case "看", "追", "讀":
            // 「很好看，是鬼滅之刃」：認得的作品就聊它
            if let g = RuleBook.match(t, #"(?:是|叫|看的是|片名是)《?([^》]{2,12})》?$"#), let w = Library.work(named: g[0]) {
                let theme = (w.attr("主題") ?? "").split(separator: "、").first.map(String.init) ?? ""
                return "《\(w.name)》！\(Library.shortIntro(w.attr("簡介") ?? ""))。" + (theme.isEmpty ? "" : "我覺得它最打動人的是「\(theme)」。") + "你最喜歡哪個角色或哪一段？"
            }
            if positive { return "聽起來很精彩！你最喜歡哪個角色或哪一段？" }
            if negative { return "可惜～有時候期待越高越容易失望。下次想看什麼，我可以推薦給你。" }
        case "吃", "喝":
            if positive { return "聽得我都餓了😋 下次也帶我（的螢幕）去吧！" }
            if negative { return "下次換一家試試～想要的話，問我「今天吃什麼」，我幫你想。" }
        case "買", "玩", "逛", "聽":
            if positive { return "太好了！開心最重要～" }
            if negative { return "有點可惜呢，下次會更好的！" }
        case "下班":
            if t.contains("沒吃") || t.contains("還沒吃") { return "那快去吃點東西吧！想不到吃什麼，問我「今天吃什麼」，我幫你挑。" }
            if negative { return "辛苦了，今天就早點休息吧。洗個熱水澡、早點睡，明天會好一點。" }
            if positive { return "那就好！今天有什麼開心的事嗎？" }
        case "養寵物":
            if t.count <= 6, !negative { return "\(t)很可愛！養之前可以先了解牠的個性、運動量、掉毛和常見的疾病；也可以考慮去收容所領養同品種或米克斯，一樣可愛。" }
        default:
            if topic.hasPrefix("旅行:") {
                let place = String(topic.dropFirst(3))
                if t.contains("玩") || t.contains("旅行") || t.contains("旅遊") || t.contains("度假") {
                    let tip = Library.lists.contains(where: { $0.names.contains(place + "的景點") }) ? "想知道景點，問我「\(place)有什麼好玩的」；想知道吃什麼，問我「\(place)有什麼好吃的」。" : ""
                    return "好棒！第一次去嗎？記得帶好護照、網路和行動電源。" + tip
                }
                if t.contains("出差") || t.contains("工作") || t.contains("辦事") { return "出差辛苦了！工作之餘也找點時間吃點當地的好東西吧～" }
            }
        }
        if positive { return "太好了！聽你這樣說我也很開心。" }
        if negative { return "嗯嗯，辛苦了。想多說一點的話，我在聽。" }
        return nil
    }

    /// 說心情的話（不是問問題）：開頭的一句由 Affect 加，這裡是接下來的話——接住、問下去，對方要建議時給一個做得到的小步驟
    public static func moodBody(_ mood: Affect.Mood, _ raw: String) -> String? {
        let wantsAdvice = ["建議", "怎麼辦", "該怎麼", "要怎麼", "如何是好", "怎麼做"].contains(where: { raw.contains($0) })
        switch mood {
        case .grief:
            return "想說說他（或牠）嗎？說說你們之間的回憶也好。失去的痛需要時間，不用急著好起來；如果難過到好幾週都睡不好、吃不下，可以找專業的人聊聊，台灣有 1925 安心專線。"
        case .sick:
            return "哪裡不舒服？先多喝水、多休息。如果症狀很嚴重、一直沒好，或有發高燒、呼吸困難、劇烈疼痛，要去看醫生；告訴我症狀，我幫你看看要注意什麼。"
        case .worryOther:
            return "他現在的狀況怎麼樣？你能做的通常是：陪著他、幫忙處理生活上的小事、陪他一起去看醫生或找資源。也別忘了照顧好你自己，你倒下了就沒辦法陪他。"
        case .goodNews, .proudEffort, .happy:
            return EchoEngine.celebrate(raw)
        case .excitedPlan:
            let when = ["明天", "後天", "大後天", "下週", "下禮拜", "週末", "下個月", "今晚", "今天", "等一下", "過幾天", "明年"].contains(where: { raw.contains($0) })
            return when ? "好期待！要去做什麼呢？需要的話，我也可以幫你想想要準備什麼。" : "是什麼時候？想到什麼都可以跟我分享～需要的話，我也可以幫你想想要準備什麼。"
        case .anxious:
            return wantsAdvice || true ? "可以先試試這個：吸氣 4 秒、停 7 秒、慢慢吐氣 8 秒，做三次，身體會放鬆一點。再把擔心的事寫下來，分成「我能做的」和「我控制不了的」，先把能做的那一件做好。你最擔心的是哪一部分？" : nil
        case .scared:
            return "你現在安全嗎？如果有危險，先離開、找身邊的人，或打 110（警察）／119。如果是心裡害怕，先慢慢深呼吸，想說說發生了什麼事嗎？"
        case .angry:
            return wantsAdvice
                ? "先讓自己離開現場、深呼吸，等冷靜一點再處理，比較不會說出後悔的話。之後可以用「我覺得…因為…我希望…」的方式說出你的感受和需要；如果是在工作或學校被欺負，記錄下來，找主管、老師或信任的人幫忙。"
                : "發生了什麼事？說出來會舒服一點，我站在你這邊聽。"
        case .complainAI:
            return "可以告訴我哪裡不對嗎？如果是上網查到的答案，跟我說「重新查」，我換個方式再查一次。"
        case .apology:
            return "我們繼續聊吧～"
        case .sad:
            return "發生了什麼事？想說的話，我都在聽。"
        case .lonely:
            return "想聊什麼都可以，我一直在這裡。也可以試著傳個訊息給一個很久沒聯絡的朋友，常常對方也在想你。"
        case .tired:
            return wantsAdvice
                ? "累的時候先照顧身體：今晚早點睡、吃點熱的東西、把明天的事挑一兩件最重要的就好。如果是長期累到撐不住，可能要想想是不是事情太多、需要跟身邊的人說。"
                : "今天辛苦了，先讓自己好好休息一下。"
        case .frustrated:
            return wantsAdvice
                ? "可以試試：把目標切小一點，先找出卡住的是哪一步；換個方法或找人問問；休息一下再回來，常常會看得更清楚。一次沒做好，不代表你做不到。"
                : "卡在哪裡呢？說說看，我們一起想想有沒有別的方法。"
        case .regret:
            return "當時你是用你那時知道的、能做的去決定的，現在回頭看當然比較清楚。比起一直責怪自己，可以想想：這件事教會了我什麼？接下來還能做什麼來彌補或改變？"
        case .confused:
            return "哪一段看不懂？跟我說，我換個方式講。"
        case .affection:
            return "我也很喜歡跟你聊天！今天想聊什麼？"
        case .hope:
            return "一定會的。把希望放在心裡，也記得一步一步去做，好事會慢慢來。"
        case .curious:
            // 只是驚嘆（「太神奇了吧」）才接話；真的在問問題的交給原本的方法
            if raw.contains("怎麼可能") { return "真的假的！發生了什麼事？說來聽聽～" }
            return raw.contains("嗎") || raw.contains("什麼") || raw.contains("為什麼") ? nil : "對吧！是什麼讓你覺得這麼神奇？說來聽聽～"
        case .joke:
            return "😆 什麼事這麼好笑？說來讓我也笑一下！"
        case .bored:
            return "無聊的時候可以叫我講個笑話、推薦一部電影，或問我一個你一直好奇的問題；想動一動的話，出門走走、整理一個小角落也很好。"
        case .thanks:
            return raw.contains("陪") ? "能陪你聊天，我也很開心。" : "能幫上忙就好！"
        case .praiseAI:
            return "你這樣說我會更努力的！還有什麼想聊的嗎？"
        default:
            return nil
        }
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
            // 問法本身就是某一種語言（偵測的語言可能不準，像義大利文被當成英文）
            if let a = answers[L] ?? answers.values.first { return a }
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
