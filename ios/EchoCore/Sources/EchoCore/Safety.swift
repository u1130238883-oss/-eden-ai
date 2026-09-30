import Foundation

/// 有人說想死、不想活的時候：先停下所有功能，好好回應，並給可以馬上找到人的求助電話。
public enum Safety {
    static let zh = ["不想活", "想死", "自殺", "輕生", "活不下去", "結束生命", "結束自己", "了結自己", "割腕", "跳樓", "不如死了", "死了算了",
                     "想消失", "活著沒意思", "活著好累", "沒有活下去", "不想再活", "尋死"]
    static let foreign = ["kill myself", "suicide", "want to die", "end my life", "don't want to live", "dont want to live",
                          "quiero morir", "suicidarme", "no quiero vivir", "voglio morire", "suicidarmi", "non voglio vivere"]
    /// 講的是別人或知識題（「自殺防治是什麼」「電影裡的人想死」），不算
    static let notSelf = ["防治", "是什麼", "新聞", "電影", "小說", "歌詞", "怎麼幫", "朋友說", "他說", "她說", "統計"]

    public static func isCrisis(_ raw: String) -> Bool {
        let t = raw.lowercased()
        if notSelf.contains(where: { t.contains($0) }) { return false }
        return zh.contains { t.contains($0) } || foreign.contains { t.contains($0) }
    }

    public static func crisisReply(_ raw: String, _ L: Lang) -> String? {
        guard isCrisis(raw) else { return nil }
        switch L {
        case .zh:
            return """
            謝謝你願意說出來。聽到你這樣說，我很在意你現在的狀況。
            你現在安全嗎？如果你已經有傷害自己的打算或正在危險中，請馬上打緊急電話（台灣、香港 119／999，中國大陸 120，義大利 112），或請身邊的人陪著你。

            也可以打給願意聽你說的人，24 小時都有人接：
            • 台灣：1925 安心專線、1995 生命線、1980 張老師
            • 香港：2389 2222 撒瑪利亞防止自殺會
            • 中國大陸：400-161-9995 心理援助熱線
            • 義大利：Telefono Amico 02 2327 2327

            我不是專業的人，但我在這裡陪你。如果你願意，可以跟我說說發生了什麼事，是什麼讓你這麼累？
            """
        case .en:
            return """
            Thank you for telling me. I care about how you're doing right now.
            Are you safe? If you're in danger or thinking of hurting yourself, please call your local emergency number now (112 in Europe, 911 in the US) or ask someone nearby to stay with you.
            You can also talk to someone 24/7: in the US call or text 988; in the UK call Samaritans at 116 123; in Italy Telefono Amico 02 2327 2327.
            I'm not a professional, but I'm here with you. If you'd like, tell me what's been happening.
            """
        case .es:
            return """
            Gracias por contármelo. Me importa cómo estás ahora mismo.
            ¿Estás a salvo? Si estás en peligro o piensas hacerte daño, llama ya al número de emergencias (112 en Europa) o pide a alguien que se quede contigo.
            También puedes hablar con alguien: en España, el 024 (atención a la conducta suicida, 24 h).
            No soy profesional, pero estoy aquí contigo. Si quieres, cuéntame qué ha pasado.
            """
        case .it:
            return """
            Grazie per avermelo detto. Mi importa come stai adesso.
            Sei al sicuro? Se sei in pericolo o pensi di farti del male, chiama subito il 112 o chiedi a qualcuno vicino di restare con te.
            Puoi anche parlare con qualcuno: Telefono Amico 02 2327 2327, Samaritans Onlus 06 77208977.
            Non sono un professionista, ma sono qui con te. Se vuoi, raccontami cosa sta succedendo.
            """
        }
    }
}
