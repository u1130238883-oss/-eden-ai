import Foundation

/// 大腦（手機上的大型語言模型）開著時，哪些話要交給 NineSun 的命理引擎、哪些直接讓大腦回答。
/// 引擎看到「媽媽、讀書、房子、工作」這種字會當成在問命盤的某一宮；大腦開著時，
/// 只有真的提到命理（運勢、命盤、流年……）或在說心情，才用命盤回答，其他直接讓大腦回答。
public enum BrainRoute {
    /// 提到命理的字
    public static func fortuneWords(_ text: String) -> Bool {
        ["運", "命", "宮", "流年", "大運", "流月", "八字", "紫微", "卦", "九型", "第幾型"].contains { text.contains($0) }
    }

    /// 要 NineSun 自己的命理引擎算的（運勢、命盤、八字、紫微、九型、生日…），或是在說心情
    public static func isReading(_ text: String) -> Bool {
        ["運勢", "運氣", "命盤", "命宮", "本命", "八字", "紫微", "流年", "大運", "流月", "九型", "第幾型", "十二宮", "卦", "生日",
         "宮位", "算命", "占卜", "日宮", "夜宮", "fortune", "horoscope", "astrolog", "destino", "oroscopo", "palace"]
            .contains { text.lowercased().contains($0) }
            || Solace.isFeeling(text)
    }

    /// 這句話真的在問命理（或說心情）
    public static func asksFortune(_ text: String) -> Bool { isReading(text) || fortuneWords(text) }

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
                                                "化科", "化忌", "生肖", "宿", "卦", "格局", "喜用", "日主", "大限", "九型"].contains { text.contains($0) }
        for e in kb.mentioned(in: text, limit: 4)
        where (!["國家", "台灣縣市"].contains(e.cat) || place.contains(where: { text.contains($0) }))
            && (!fortuneCats.contains(e.cat) || fortuneTalk) {
            let line = "\(e.title)：\(e.body)"
            if soft.contains(e.cat) { hint.append(line) } else { facts.append(line) }
        }
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
}
