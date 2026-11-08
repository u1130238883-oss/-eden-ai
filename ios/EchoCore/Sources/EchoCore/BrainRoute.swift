import Foundation

/// 大腦（手機上的大型語言模型）開著時，哪些話要交給 NineSun 的命理引擎、哪些直接讓大腦回答。
/// 引擎看到「媽媽、讀書、房子、工作」這種字會當成在問命盤的某一宮；大腦開著時，
/// 只有真的提到命理（運勢、命盤、流年……）或在說心情，才用命盤回答，其他直接讓大腦回答。
public enum BrainRoute {
    /// 提到命理的字
    public static func fortuneWords(_ text: String) -> Bool {
        // 「運動」「捷運」「生命」「故宮」「子宮」這些平常的詞裡也有運、命、宮，先拿掉再看
        let t = withoutEveryday(text)
        return ["運", "命", "宮", "流年", "大運", "流月", "八字", "紫微", "卦", "九型", "第幾型"].contains { t.contains($0) }
    }

    /// 拿掉含有運、命、宮的平常詞（「運動」「捷運」「生命」）
    public static func withoutEveryday(_ text: String) -> String {
        var t = text
        for w in everyday { t = t.replacingOccurrences(of: w, with: "") }
        return t
    }

    static let everyday = ["運動", "運送", "運輸", "運作", "運用", "運算", "運費", "運轉", "運河", "運行", "捷運", "營運", "奧運", "空運", "海運", "貨運", "客運", "託運", "搬運",
                           "命令", "生命", "拼命", "救命", "命名", "革命", "壽命", "使命", "性命", "人命", "要命", "待命", "命中", "致命", "續命",
                           "宮殿", "故宮", "子宮", "迷宮", "王宮", "皇宮", "白宮", "宮崎", "宮廷", "後宮", "宮保", "龍宮", "布達拉宮", "宮頸"]

    /// 要 NineSun 自己的命理引擎算的（運勢、命盤、八字、紫微、九型、生日…），或是在說心情
    public static func isReading(_ text: String) -> Bool {
        ["運勢", "運氣", "命盤", "命宮", "本命", "八字", "紫微", "流年", "大運", "流月", "九型", "第幾型", "十二宮", "卦", "生日",
         "宮位", "算命", "占卜", "日宮", "夜宮", "fortune", "horoscope", "astrolog", "destino", "oroscopo", "palace"]
            .contains { text.lowercased().contains($0) }
            || Solace.isFeeling(text)
    }

    /// 這句話真的在問命理（或說心情）
    public static func asksFortune(_ text: String) -> Bool { isReading(text) || fortuneWords(text) }

    /// 問的是會變的事（「現在」「最新」「最近」「今年」「目前」）：大腦記得的可能過時了，要先上網查、再讓大腦照資料回答
    public static func timeSensitive(_ text: String) -> Bool {
        let t = text.lowercased()
        return ["現在", "最新", "最近", "目前", "今年", "這幾年", "近期", "當前", "now", "latest", "recent", "current", "this year"].contains { t.contains($0) }
            && !asksFortune(text)
    }

    /// 引擎的回答只是在要生日（「我還不知道你的生日…例如：我的生日是2000年1月1日」）
    public static func needsBirthday(_ reply: String) -> Bool {
        ["我的生日是2000", "我是2000年1月1日", "my birthday is 2000", "mi cumpleaños es 2000", "il mio compleanno è 2000"]
            .contains { reply.contains($0) }
    }

    /// 問大腦之前先查知識庫：知識類的條目當成「查到的資料」（大腦照著回答），
    /// 情緒、安定方法這類當成參考（挑一兩句自然地用，還是用聊天的語氣）
    public static func lookup(_ text: String, in kb: KnowledgeBase?) -> (facts: String, hint: String) {
        guard let kb else { return ("", "") }
        let soft: Set<String> = ["情緒", "思考陷阱", "安定方法"]
        var facts: [String] = [], hint: [String] = []
        // 國家、縣市的條目只在問它的首都、語言、貨幣、景點……時才給（問「台灣最高的山」不要給台灣的國家資料）
        let place = ["首都", "語言", "說什麼", "貨幣", "什麼錢", "哪一洲", "哪個洲", "大洲", "景點", "有名", "特色", "好玩", "去哪", "直轄市"]
        // 命理的條目（紫微的「太陽」、地支、卦……）只在問命理時才給（問「太陽是恆星嗎」不要給紫微的太陽星）
        let fortuneCats: Set<String> = ["紫微星曜", "紫微十二宮", "六十四卦", "十神", "天干", "地支", "八卦", "五行", "四化", "概念", "九型十二宮",
                                        "九型人格", "納音", "七政四餘", "二十八宿", "地支關係"]
        let fortuneTalk = asksFortune(text) || ["紫微", "八字", "斗數", "十神", "天干", "地支", "五行", "納音", "七政", "四餘", "星曜", "化祿", "化權",
                                                "化科", "化忌", "生肖", "宿", "卦", "格局", "喜用", "日主", "大限", "九型", "合化", "六合", "三合", "相沖", "六沖", "相刑",
                                                "相害", "四化"].contains { text.contains($0) }
        for e in kb.mentioned(in: text, limit: 4)
        where (!["國家", "台灣縣市"].contains(e.cat) || place.contains(where: { text.contains($0) }))
            && (!fortuneCats.contains(e.cat) || fortuneTalk) {
            let line = "\(e.title)：\(e.body)"
            if soft.contains(e.cat) { hint.append(line) } else { facts.append(line) }
        }
        // 引擎算好的：十神、五行生剋、四化、天干地支、BMI、血壓、血糖、體溫
        facts += BrainFacts.notes(text)
        // 成語：NineSun 的成語辭典（意思、近義、反義）
        if let w = Idioms.find(text), let e = Idioms.entry(w) {
            var line = "成語「\(w)」：\(e.meaning)"
            let near = Idioms.near(w).prefix(3), anti = Idioms.opposites(w).prefix(3)
            if !near.isEmpty { line += "；近義：" + near.joined(separator: "、") }
            if !anti.isEmpty { line += "；反義：" + anti.joined(separator: "、") }
            facts.append(line)
        }
        return (facts.joined(separator: "\n"), hint.joined(separator: "\n"))
    }

    /// 對方心情低落、狀況很糟（而且不是在叫 NineSun 罵他、陪他罵）：大腦換成溫柔安慰的說話方式
    /// previous：對方上一句（上一句在難過，這句「說了也沒用」「都是我的錯」也還是在難過）
    public static func feelingLow(_ raw: String, previous: String? = nil) -> Bool {
        if let p = previous, feelingLow(p), !raw.contains("罵") && !raw.contains("嗆") { return true }
        let t = raw.replacingOccurrences(of: " ", with: "")
        if Safety.isCrisis(t) { return true }
        // 叫它罵、陪他罵，或是在生氣、想發洩：用嘴砲的個性，不是溫柔安慰
        if t.range(of: #"罵我|罵到我|罵醒|嗆我|髒話|陪我罵|一起罵|罵爆|罵一罵|罵他|互嗆|氣死|好氣|超氣|氣炸|火大|靠北|幹|媽的|爛透|很靠北"#, options: .regularExpression) != nil { return false }
        let words = ["難過", "好累", "心好累", "心好亂", "好想哭", "想哭", "不知道怎麼辦", "崩潰", "失戀", "被分手", "被劈腿", "失眠", "睡不著", "焦慮",
                     "孤單", "寂寞", "自責", "好沒用", "很沒用", "什麼都做不好", "想放棄", "撐不下去", "過世", "走了", "被裁", "失業", "卡債", "被詐騙",
                     "被霸凌", "被欺負", "被背叛", "被罵", "被當", "考砸", "沒上", "好怕", "害怕", "恐慌", "壓力好大", "壓力很大", "憂鬱", "心情不好",
                     "心情很差", "好痛苦", "很痛苦", "沒有人在乎", "沒朋友", "沒有朋友", "被排擠", "好委屈", "委屈", "被誤會", "看不到未來", "一事無成",
                     "好低落", "大吵", "沒興趣", "又沒有我", "檢查有異常", "慢性病", "不要跟我說教", "不想說", "都是我的錯", "你根本不懂", "說了也沒用", "提不起勁", "好想家", "生病", "住院", "賠了", "付不出", "被拒絕", "已讀不回", "冷淡", "吵架", "一直出錯",
                     "我只想有人聽", "陪我聊", "安慰我"]
        return words.contains { t.contains($0) } || Solace.isFeeling(t)
    }
}
