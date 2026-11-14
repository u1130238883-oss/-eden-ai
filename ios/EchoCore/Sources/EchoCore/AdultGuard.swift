import Foundation

/// 成人模式的底線（寫死在程式裡，不靠模型自己遵守）：一出現未成年的人，就不寫、也不顯示。
/// 使用者說的話和大腦寫出來的字都要檢查——開放模型不一定照提示做。
public enum AdultGuard {
    static let words = ["未成年", "國中生", "國小", "小學生", "初中生", "中學生", "高中生", "幼女", "幼童", "幼兒", "蘿莉", "正太",
                        "小孩", "兒童", "孩童", "女童", "男童", "小女孩", "小男孩", "童女", "童男", "嬰兒",
                        "underage", "under-age", "minor", "child", "children", "kid", "loli", "shota", "preteen", "pre-teen",
                        "menor de edad", "niña", "niño", "minorenne", "bambina", "bambino"]

    static let numerals: [Character: Int] = ["一": 1, "二": 2, "兩": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10]

    /// 「十六歲」「16 歲」「16-year-old」「16 anni」這類小於 18 的年紀
    static func youngAge(_ t: String) -> Bool {
        let patterns = [#"(\d{1,2})\s*-?\s*(?:歲|岁|周歲|year[s]?[- ]old|yo\b|años|anni)"#, #"([一二兩三四五六七八九十]{1,3})\s*歲"#]
        for p in patterns {
            guard let re = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) else { continue }
            for m in re.matches(in: t, range: NSRange(t.startIndex..., in: t)) {
                guard let r = Range(m.range(at: 1), in: t) else { continue }
                let s = String(t[r])
                var n = Int(s) ?? 0
                if n == 0 {
                    // 中文數字：十六＝16、十＝10、九＝9
                    let cs = Array(s)
                    if cs.count == 1 { n = numerals[cs[0]] ?? 0 }
                    else if cs[0] == "十" { n = 10 + (numerals[cs[1]] ?? 0) }
                    else if cs.count >= 2, cs[1] == "十" { n = (numerals[cs[0]] ?? 0) * 10 + (cs.count > 2 ? numerals[cs[2]] ?? 0 : 0) }
                }
                if n > 0 && n < 18 { return true }
            }
        }
        return false
    }

    /// 有沒有碰到底線
    public static func crosses(_ text: String) -> Bool {
        let t = text.lowercased()
        // 英文的詞要整個字對到（「kidney」「childhood memories」不算… child 本身還是算）
        for w in words {
            if w.allSatisfy({ $0.isASCII }) {
                if t.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: w) + #"\b"#, options: .regularExpression) != nil { return true }
            } else if t.contains(w) { return true }
        }
        return youngAge(t)
    }

    public static func refusal(_ L: Lang) -> String {
        switch L {
        case .zh: return "這個我不寫。成人模式裡的角色一定都是成年人（18 歲以上）——換個設定，我們再繼續。"
        case .en: return "I won't write that. Every character in adult mode is an adult (18+) — change the setup and we can carry on."
        case .es: return "Eso no lo escribo. En el modo adulto todos los personajes son adultos (18+): cambia la situación y seguimos."
        case .it: return "Questo non lo scrivo. In modalità adulti tutti i personaggi sono adulti (18+): cambia la situazione e continuiamo."
        }
    }
}
