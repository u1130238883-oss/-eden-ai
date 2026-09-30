import Foundation

/// NineSun 回答問題時的思考習慣（每一題都照做，結果寫在回答裡，使用者看得到）：
///   • 分主次：直接回答問題的放最前面（主要），補充的放後面（次要），離題的丟掉。
///   • 反過來想：刻意去找爭議、誤解、反對的說法，真相常常在「但是」後面。
///   • 有自己的看法：照自己的原則判斷該相信哪個來源、為什麼，也說出什麼情況下會改變想法。
///   • 揣測對方想要什麼：依問題類型，想一步對方接下來可能需要的東西。
///   • 知錯能改：被說「不對」時，先反省上次用了哪些資料，避開它們、換個查法重查。
public enum Mind {
    /// NineSun 的原則（偏好與價值）
    public static let values = ["證據比說法重要", "官方、百科和多數來源優先", "不確定就說不確定", "先回答問題本身，再補充"]

    /// 「但是」「爭議」「迷思」這類轉折、反面的說法
    static let contrast = ["但是", "然而", "不過", "爭議", "批評", "反對", "質疑", "誤解", "迷思", "其實", "並非", "並不是", "相反", "另一種說法", "也有人認為", "有學者認為", "謠言", "錯誤觀念", "不一定"]

    /// 反過來想：找出講到主題、帶有轉折或反面意思的句子
    public static func otherSide(_ sentences: [(text: String, host: String)], topic: Set<String>, exclude: [String], limit: Int = 2) -> [String] {
        var out: [String] = []
        for s in sentences where out.count < limit {
            guard contrast.contains(where: { s.text.contains($0) }) else { continue }
            guard topic.isEmpty || WebAgent.score(s.text, topic) >= 1 else { continue }
            let key = String(s.text.prefix(14))
            if exclude.contains(where: { $0.contains(key) }) || out.contains(where: { $0.contains(key) }) { continue }
            out.append(Cite.quote(s.text, host: s.host, focus: contrast))
        }
        return out
    }

    /// 我的看法：照原則說明為什麼相信這個答案、什麼時候會改變想法
    public static func view(want: Understanding.Want?, answered: Bool, sources: Int, trusted: [String], disagree: Bool, recent: Bool) -> String {
        guard answered else {
            return "這次的資料不夠讓我下結論，我寧可說不知道，也不要把不相關的東西當成答案。"
        }
        var parts: [String] = []
        if !trusted.isEmpty {
            parts.append("我比較相信 " + trusted.prefix(2).joined(separator: "、") + " 的說法，因為它是官方、百科或專業來源")
        } else if sources >= 3 {
            parts.append("有 \(sources) 個來源講法接近，我採用大家一致的部分")
        } else {
            parts.append("目前只有 \(max(sources, 1)) 個來源，我不會把話說死")
        }
        if disagree { parts.append("各來源數字不一樣時，我選多數、而且有權威來源支持的那個") }
        if case .compare = want { parts.append("比較類的問題通常沒有絕對的好壞，關鍵是你重視什麼") }
        if case .reason = want { parts.append("原因常常不只一個，我列的是資料裡講得最直接的那個") }
        if recent { parts.append("這類資料會變，如果你看到更新的官方數字，以那個為準") }
        else { parts.append("如果你有更可靠的資料跟我不一樣，告訴我，我會重新查證") }
        return parts.joined(separator: "；") + "。"
    }

    /// 揣測對方接下來可能想知道的
    public static func followUps(_ fr: Understanding.Frame) -> [String] {
        let s = fr.subject
        switch fr.want {
        case .number: return ["想跟其他同類的東西比一比嗎？", "要我說明這個數字是怎麼算出來的嗎？"]
        case .list: return ["想知道其中哪一個的詳細介紹？"]
        case .reason: return ["要我用更簡單的比喻解釋一次？", "要我查查有沒有不同的說法或爭議？"]
        case .steps: return ["要我告訴你最常失敗的地方和怎麼避免嗎？"]
        case .person: return ["想知道他還有哪些重要的事蹟嗎？"]
        case .place: return ["要我查怎麼去「\(s)」、或那裡有什麼值得看的嗎？"]
        case .time: return ["想知道當時的背景和影響嗎？"]
        case .definition: return ["要我舉一個生活中的例子說明「\(s)」嗎？"]
        case .compare: return ["告訴我你的預算和用途，我幫你挑一個。"]
        case .open: return []
        }
    }

    /// 使用者在說「你答錯了」
    public static func isCorrection(_ text: String) -> Bool {
        // 「對不對」是在問，不是在指正；指正通常很短（「不對吧」「你答錯了」）
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "對不對", with: "")
        guard t.count <= 12 else { return false }
        return ["不對", "錯了", "答錯", "你錯", "不是這樣", "不正確", "亂講", "胡說", "講錯", "說錯", "搞錯", "不是這個", "答非所問", "wrong", "not right", "incorrect"]
            .contains { t.lowercased().contains($0) }
    }
}
