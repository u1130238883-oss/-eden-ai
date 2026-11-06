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
}
