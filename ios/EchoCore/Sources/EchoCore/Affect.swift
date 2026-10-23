import Foundation

/// 情感：對方說的話帶著什麼心情，NineSun 該有什麼感受、用什麼語氣接。
/// 像人聽別人說話一樣——先聽出對方的狀態（開心、難過、緊張、生氣、謝謝、罵人……），
/// 心裡有對應的感受（替他高興、心疼、想讓他安心、謙虛道歉……），再開口；一般的問題就專心、樂意幫忙，不硬加情緒。
public enum Affect {
    public enum Mood: String, CaseIterable {
        case crisis          // 想輕生：最優先，嚴肅、關心（由安全流程處理）
        case grief           // 失去親人、寵物
        case sick            // 身體不舒服
        case worryOther      // 擔心家人朋友
        case goodNews        // 好消息：考上、升職、中獎、交往、求婚
        case proudEffort     // 自己努力做到了
        case excitedPlan     // 期待的事：旅行、約會、演唱會
        case anxious         // 緊張、焦慮、擔心自己
        case scared          // 害怕
        case angry           // 對別人生氣
        case complainAI      // 罵 NineSun、說它答錯
        case apology         // 跟 NineSun 道歉
        case sad             // 難過、低落
        case lonely          // 孤單、寂寞
        case tired           // 累
        case frustrated      // 一直失敗、學不會
        case regret          // 後悔
        case confused        // 看不懂、聽不懂
        case thanks          // 謝謝
        case praiseAI        // 稱讚 NineSun
        case affection       // 喜歡 NineSun、把它當朋友
        case joke            // 開玩笑、要笑話
        case bored           // 無聊
        case hope            // 希望、祝福
        case greeting        // 打招呼
        case farewell        // 道別
        case curious         // 好奇、覺得神奇
        case happy           // 開心、心情很好（「今天好開心」「我心花怒放」）
        case info            // 一般的問題：專心幫忙
    }

    /// NineSun 心裡的感受（說明用，也顯示在開發者的除錯裡）
    public static let feeling: [Mood: String] = [
        .crisis: "非常擔心、很想好好接住你", .grief: "不捨、心疼", .sick: "擔心你的身體", .worryOther: "跟你一起擔心、想幫忙",
        .goodNews: "替你開心、與有榮焉", .proudEffort: "為你驕傲", .excitedPlan: "跟著期待、雀躍", .anxious: "想讓你安心",
        .scared: "想陪著你、讓你安心", .angry: "理解你的委屈、站在你這邊", .complainAI: "抱歉、想做得更好", .apology: "沒關係、很溫暖",
        .sad: "心疼、想陪你", .lonely: "想陪著你", .tired: "心疼你的辛苦", .frustrated: "想替你打氣", .regret: "理解、想寬慰你",
        .confused: "有耐心、想換個方式說清楚", .thanks: "被感謝很開心", .praiseAI: "有點害羞、很開心", .affection: "感動、溫暖",
        .joke: "輕鬆、俏皮", .bored: "活潑、想陪你找點樂子", .hope: "跟你一起期待、祝福", .greeting: "親切、愉快",
        .farewell: "溫暖、不捨", .curious: "好奇、想一起探索", .happy: "跟著開心", .info: "專心、樂意幫忙",
    ]

    /// 偵測的順序有意義：越重要、越容易被其他字蓋過的放越前面（「我的狗過世了，好難過」是失去，不只是難過）
    static let rules: [(Mood, String)] = [
        (.crisis, "不想活|想死|自殺|活不下去|結束生命|輕生|跳樓|割腕"),
        (.grief, "過世|去世|走了(?!.{0,2}(路|去|過來))|離開人世|往生|死掉了|(?<![累聊笑氣嚇熱冷餓煩忙痛困睏])死了|喪禮|告別式|離世|不在了|彩虹橋"),
        (.worryOther, "(媽媽|爸爸|我媽|我爸|奶奶|爺爺|外婆|外公|老婆|老公|男友|女友|男朋友|女朋友|小孩|孩子|寶寶|兒子|女兒|朋友|同事|室友|同學|弟弟|妹妹|哥哥|姊姊|姐姐|叔叔|伯伯|姑姑|阿姨|舅舅|家人|學長|學姊|客戶|老師|貓|狗|寵物|毛孩)(.{0,6})(住院|生病|開刀|手術|失戀|出事|車禍|心情不好|很難過|受傷|不舒服)"),
        (.sick, "發燒|生病|感冒了|頭(好|很|超)?痛|肚子(好|很|超)?痛|胃(好|很)?痛|不舒服|咳嗽|喉嚨痛|住院了?(?!.{0,4}(媽|爸|奶|爺|朋友|同事))|受傷|拉肚子|過敏|頭暈|牙(齒)?(好|很)?痛"),
        (.goodNews, "考上|錄取|上榜|升職|升官|加薪了|中獎|中樂透|得獎|拿到冠軍|贏了|求婚成功|被求婚|在一起了|交到(男|女)朋友|脫單|懷孕了|生了|結婚了|訂婚|買房了|拿到offer|拿到工作|找到工作了|通過了|合格了|畢業了|考過了|考滿分|第一名"),
        (.proudEffort, "(?<![教幫叫讓請訴])我(終於|今天|剛剛)?(做到|完成|跑完|跑了|寫完|做完|堅持|戒掉|瘦了|學會)|終於(做到|完成|學會|寫完|做完)"),
        (.excitedPlan, "(明天|下週|下禮拜|下個月|週末|今晚|後天|過幾天|快要)(要|就要|終於要)?(去|出國|旅行|旅遊|約會|見面|看演唱會|放假|出發)|好期待|等不及|迫不及待"),
        (.complainAI, "你(答|說|講|算|查)錯|你(好|很|真|太)?(笨|爛|蠢|廢|沒用)|爛AI|你根本|你亂講|你在亂|你是不是傻|答非所問|你不懂啦|你什麼都不會"),
        (.apology, "對不起|抱歉|不好意思(剛剛|剛才|我)|剛剛(兇|罵)你|我錯了"),
        (.anxious, "緊張|焦慮|不安|擔心|好怕考|怕考不好|怕(被|失敗|搞砸)|壓力(好|很|超|太)?大|睡不著.{0,4}(明天|考試|面試)|忐忑"),
        (.scared, "(好|很|超|有點)?(害怕|可怕|恐怖)|怕黑|怕鬼|嚇死|嚇到|打雷"),
        (.angry, "氣死|好氣|很氣|生氣|火大|超火|很煩.{0,4}(他|她|他們|同事|老闆)|搶我功勞|欺負我|罵我|針對我|不爽|討厭(他|她|他們)"),
        (.regret, "後悔|早知道|要是當初|懊悔"),
        (.lonely, "孤單|寂寞|孤獨|沒(有)?人陪|一個人(好|很)|沒有朋友|沒人理我|沒人懂我|沒有人懂我"),
        (.sad, "難過|傷心|想哭|哭了|低落|心情(好|很|超)?(差|不好|糟)|失戀|分手|被甩|心碎|好痛苦|憂鬱|鬱悶|好委屈|委屈"),
        (.tired, "好累|很累|超累|累死|累了|疲憊|加班到|熬夜|好睏|沒力|沒精神|身心俱疲"),
        (.frustrated, "學不會|做不好|一直失敗|又失敗|又錯|考不好|考砸|搞砸|好挫折|沮喪|好難喔|好難啊|想放棄"),
        (.confused, "看不懂|聽不懂|不懂你|什麼意思啊|你在說什麼|搞不懂|好混亂|看不太懂"),
        (.thanks, "謝謝|感謝|多謝|謝啦|感恩|幫了大忙|你最好了"),
        (.praiseAI, "你(真的|真是|實在)?(好|很|真|超|太)(聰明|厲害|棒|強|可愛|貼心|懂我)|你最棒|你好神|好準"),
        (.bored, "好無聊|很無聊|無聊死|沒事做|好閒"),
        (.affection, "我(好|很|最)?喜歡你|我愛你|你是我最好的朋友|有你真好|好想你|陪我聊天"),
        (.joke, "笑話|哈哈|XD|好好笑|笑死|開玩笑|逗我|搞笑"),
        (.hope, "希望(明天|今年|明年|以後|一切|大家|自己|能|可以|會)|祝(我|大家|你)|但願"),
        (.farewell, "^(晚安|掰掰|拜拜|再見|bye|先睡了|我去睡了|明天見|下次聊)"),
        (.greeting, "^(早安|午安|晚上好|你好|您好|嗨|哈囉|hello|hi|嘿)$"),
        (.happy, "(好|很|超|太|特別|真的)(開心|高興|快樂)|心情(超|很|好|特別)好|開心的一天|開心死了"),
        (.curious, "好奇|好神奇|真的假的|為什麼會這樣|太神奇|好特別|怎麼可能"),
    ]

    public static func detect(_ raw: String) -> Mood {
        // 結尾的標點、表情、刪節號，開頭的口頭禪（其實、欸、對了、說真的……）只是口氣，先拿掉
        func trim(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"[^\p{L}\p{N}]+$"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"^((其實|欸|誒|嗯|唉|對了|說真的|老實說|那個|跟你說|剛剛|所以)[，,、\s]*)+(?=.)"#, with: "", options: .regularExpression)
        }
        let t0 = trim(raw)
        // 要寫作（「小明哭了，請詳寫」）：句子裡的「哭」是題目，不是心情
        if Writer.parse(raw) != nil || Grammar.parse(raw) != nil { return .info }
        // 「我想知道…」「可以告訴我…」「好奇…」是問問題的開頭，不是心情
        let c = trim(Understanding.clean(t0))
        let t = c.isEmpty ? t0 : c
        // 成語：問成語的意思、近義、反義……是問題；用成語說自己的心情（「我最近心灰意冷」）就是那個心情
        if let u = Idioms.understand(t0) {
            if u.intent == "feeling", let m = Mood(rawValue: u.extra) { return m }
            if u.intent != "problem" { return .info }
        }
        // 直接對 NineSun 說「你在說什麼」：是聽不懂，不是在問作品內容
        if t.range(of: "你(到底)?在(說|講)什麼", options: .regularExpression) != nil { return .confused }
        // 問作品（「少年維特的煩惱講了什麼」）、問近義詞（「難過的近義詞」）：書名、詞裡的情緒字不是心情
        if EchoEngine.asksAboutWork(t) || Synonyms.parse(t) != nil || Antonyms.parse(t) != nil
            || Synonyms.parse(t0) != nil || Antonyms.parse(t0) != nil { return .info }
        // 打招呼、道謝、道別這種短句，拿掉語氣詞前後都看（「謝啦」的「啦」不能拿掉）
        let social: Set<Mood> = [.thanks, .greeting, .farewell, .confused, .praiseAI, .apology]
        for (m, p) in rules where t.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil
            || (social.contains(m) && t0.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil) {
            // 「老闆不給我加薪」「沒考上」不是好消息
            if m == .goodNews, t.range(of: "(不|沒|沒有)(給我|讓我)?(加薪|升職|錄取|考上|通過|上榜)", options: .regularExpression) != nil { continue }
            // 在問一個情緒相關的東西（「焦慮症是什麼」「怎麼緩解焦慮」「感冒為什麼會發燒」）：是問題，不是心情
            if [.anxious, .sad, .lonely, .scared, .angry, .tired, .frustrated, .regret, .sick].contains(m), asksThing(t) { return .info }
            return m
        }
        return .info
    }

    /// 在問一個東西，不是在說自己：「焦慮症是什麼」「緩解焦慮的方法」「為什麼人會難過」
    static func asksThing(_ t: String) -> Bool {
        if t.range(of: "我|好(累|煩|難過|緊張|氣|怕|孤單|寂寞|沮喪|挫折|無聊)|很(累|煩|難過|緊張|氣|怕|孤單|寂寞|沮喪)|超(累|煩|氣|怕)|氣死|嚇死|累死", options: .regularExpression) != nil { return false }
        // 「X怎麼辦」整句沒有逗號、沒有「我」：是在問處理的方法（「喉嚨痛怎麼辦」「考試考不好怎麼辦」）
        if t.range(of: "^[^，,]*[^，,\\s](怎麼辦|怎麼處理|要怎麼做|該怎麼做)$", options: .regularExpression) != nil { return true }
        return t.range(of: "是什麼|什麼是|的意思|症狀|原因|為什麼|為何|方法|如何|怎麼(緩解|改善|克服|治|讀|學|做|處理)|要怎麼|該怎麼|有哪些|定義|解釋|技巧|^如果|^萬一|好不好看|好看|故事大綱|大綱|劇情|講了什麼|在講什麼|作者", options: .regularExpression) != nil
    }

    /// NineSun 開口的第一句（帶著感受）；一般的問題不加
    static let openers: [Mood: [String]] = [
        .grief: ["聽到這個消息我好難過，請你先好好照顧自己。", "抱抱你，失去重要的人（或毛孩）真的很痛，我在這裡陪你。"],
        .sick: ["身體不舒服要好好休息喔，我有點擔心你。", "辛苦了，生病的時候要多喝水、好好睡，有需要就去看醫生。"],
        .worryOther: ["聽起來你很擔心他，我陪你一起想想能做什麼。", "你這麼在乎他，他一定感受得到。我們一起看看可以怎麼幫他。"],
        .goodNews: ["恭喜你！真替你開心！🎉", "哇，太棒了，恭喜！這是你努力換來的。"],
        .proudEffort: ["好棒，你真的做到了！為你驕傲。", "太厲害了，這份努力很不容易，給你拍拍手👏"],
        .excitedPlan: ["聽起來好期待！我也替你雀躍起來了。", "好棒的安排，一定會很開心的！"],
        .anxious: ["會緊張是因為你很在乎，先深呼吸一下，我陪你一起準備。", "別擔心，一步一步來，你比自己想的更有準備。"],
        .scared: ["別怕，我在這裡陪你。", "先深呼吸，你現在是安全的，我陪著你。"],
        .angry: ["換作是我也會生氣，你的感受很合理。", "這真的很讓人火大，先讓情緒有個出口，我站在你這邊。"],
        .complainAI: ["抱歉，是我弄錯了，謝謝你告訴我，我重新想一次。", "對不起讓你失望了，我會改進，可以告訴我哪裡不對嗎？"],
        .apology: ["沒關係，我沒有放在心上，謝謝你願意說。", "沒事的，每個人都有情緒，我還是很樂意陪你。"],
        .sad: ["先抱抱你，難過的時候不用急著好起來。", "我在，想說什麼都可以慢慢說。"],
        .lonely: ["你不是一個人，我在這裡陪你聊。", "孤單的時候特別難熬，今天我陪你。"],
        .tired: ["辛苦了，先讓自己喘口氣。", "真的累壞了吧，記得好好休息，身體最重要。"],
        .frustrated: ["失敗不代表你不行，只是還在學的路上，我替你加油！", "別灰心，卡住是每個人都會遇到的，我們換個方法試試。"],
        .regret: ["會後悔，代表你很認真對待這件事；別對自己太嚴苛。", "已經發生的事我們一起接住它，接下來還有機會。"],
        .confused: ["不好意思，我說得不夠清楚，我換個方式講。", "沒關係，我們一步一步來，我再說明一次。"],
        .thanks: ["不客氣！能幫上忙我很開心😊", "很高興對你有幫助，隨時再找我！"],
        .praiseAI: ["被你這樣說有點不好意思，謝謝你😳", "哈哈，被誇獎好開心，我會繼續努力的！"],
        .affection: ["聽到你這樣說，我心裡暖暖的，謝謝你。", "有你陪我聊天，我也很開心。"],
        .joke: ["哈哈，好呀，來輕鬆一下～", "你真有趣😆"],
        .bored: ["無聊的話，我陪你找點樂子！", "那來點有趣的吧～"],
        .hope: ["我也這樣祝福你，一定會越來越好的。", "會的，我跟你一起期待。"],
        .greeting: ["嗨！很高興見到你😊", "你好呀！今天想聊什麼？"],
        .farewell: ["晚安，好好休息，明天見～", "掰掰，有需要隨時找我！"],
        .curious: ["這個問題很有意思！", "我也好奇，我們一起來看看。"],
        .happy: ["看你這麼開心，我也跟著開心起來了！", "真好，開心的事值得好好記住。"],
    ]

    /// 這種心情時，回答裡應該有的語氣（測試用：例如難過時不能說「恭喜」）
    public static func opener(_ m: Mood, seed: Int = 0) -> String? {
        guard let o = openers[m], !o.isEmpty else { return nil }
        return o[abs(seed) % o.count]
    }

    /// 回答已經帶著對的情緒了嗎（安慰的話已經在講難過，就不用再加一句）
    static let toneWords: [Mood: [String]] = [
        .grief: ["難過", "抱抱", "陪你", "不捨", "節哀"], .sick: ["休息", "擔心", "照顧", "辛苦"], .worryOther: ["擔心", "陪你", "幫他", "在乎"],
        .goodNews: ["恭喜", "開心", "太棒"], .proudEffort: ["做到", "驕傲", "厲害", "好棒"], .excitedPlan: ["期待", "雀躍", "開心"],
        .anxious: ["緊張", "別擔心", "深呼吸", "安心", "陪你"], .scared: ["別怕", "陪你", "安全"], .angry: ["生氣", "火大", "你這邊", "合理"],
        .complainAI: ["抱歉", "對不起", "改進", "弄錯"], .apology: ["沒關係", "沒事"], .sad: ["抱抱", "難過", "陪你", "我在"],
        .lonely: ["陪你", "不是一個人", "孤單"], .tired: ["辛苦", "休息", "累"], .frustrated: ["加油", "別灰心", "不代表"],
        .regret: ["後悔", "別對自己", "接住"], .confused: ["清楚", "換個方式", "再說明"], .thanks: ["不客氣", "開心", "高興"],
        .praiseAI: ["謝謝", "不好意思", "開心"], .affection: ["暖暖", "謝謝", "開心"], .joke: ["哈哈", "有趣", "輕鬆"],
        .bored: ["樂子", "有趣"], .hope: ["祝福", "期待", "會的"], .greeting: ["你好", "嗨", "很高興"], .farewell: ["晚安", "掰掰", "再見", "明天見"],
        .curious: ["有意思", "好奇", "一起來看"], .happy: ["開心", "真好", "太好了"],
    ]

    public static func hasTone(_ text: String, _ m: Mood) -> Bool { (toneWords[m] ?? []).contains { text.contains($0) } }

    /// 跟這個心情衝突的語氣（難過時說「恭喜」、被罵時說「哈哈」）
    public static func clashes(_ text: String, _ m: Mood) -> Bool {
        let happy = ["恭喜", "太棒了", "🎉", "哈哈"]
        switch m {
        case .grief, .sad, .sick, .worryOther, .lonely, .anxious, .scared, .angry, .complainAI, .frustrated, .regret, .tired, .crisis:
            return happy.contains { text.hasPrefix($0) || text.prefix(20).contains($0) }
        default: return false
        }
    }

    /// 回答加上帶著感受的第一句（已經有對的語氣、或是一般問題就不加）。
    /// 有命盤（voice）的話，用這個人的個性開口，最後再配一句合適的成語。
    public static func color(_ text: String, for message: String, seed: Int = 0, voice: Voice? = nil) -> String {
        let m = detect(message)
        guard m != .info, m != .crisis else { return text }
        var out = text
        if !hasTone(String(text.prefix(60)), m), let o = voice?.opener(m) ?? opener(m, seed: seed) { out = o + "\n" + text }
        if let v = voice, !out.contains("💬"), let line = v.idiomLine(for: m, message: message) { out += "\n\n" + line }
        return out
    }
}
