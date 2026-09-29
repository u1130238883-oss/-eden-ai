import Foundation

/// 命理上網查資料的解題思路：網路上寫的都是「通論」，一定要拿回來對照自己的盤，才知道哪句適用。
///
///   ① 認出盤上的關鍵組合：八字看日主、身強身弱、月令格局、喜用神；紫微看命宮主星、化忌落在哪一宮。
///   ② 拆成幾個方面上網查：含義與性格 → 喜忌 → 感情 → 事業財運 → 健康（紫微：含義 → 性格 → 影響 → 化解）。
///   ③ 讀網頁，只留下真的在講這個組合的句子。
///   ④ 逐句對照你的盤：
///      · 網路說「喜某五行」，而那正是你的喜用神 → ✅ 適用
///      · 網路說「喜某五行」，但那是你的忌神 → ⚠️ 不適用（網路寫的是另一種盤）
///      · 網路講「身強的人」，你是身弱 → ⚠️ 不適用；講的跟你一樣 → ✅ 適用
///      · 紫微講到你命宮的主星、你化忌所在的宮位 → ✅ 講的就是你
///   ⑤ 綜合：留下適用的說法、排除不適用的，以你自己盤上的喜用和流年為準，給結論和具體建議。
enum WebFortune {
    struct Chart {
        var dayMaster: String?
        var strong: Bool?
        var fav: [String] = []
        var avoid: [String] = []
        var yearVerdict: String?
        var mingStars: String?
        var jiPalace: String?
        var isZiwei: Bool { mingStars != nil }
    }

    static let elements = ["木", "火", "土", "金", "水"]

    /// 從 ManticReader 給的盤面重點讀回結構（「你的日主是癸水，身弱，喜金、水，忌土、火、木；2026年丙午對你是壞的」）
    static func parse(_ facts: String) -> Chart {
        var c = Chart()
        c.dayMaster = WebSearch.first(#"日主是(\S{2})"#, facts, group: 1)
        if facts.contains("身強") { c.strong = true } else if facts.contains("身弱") { c.strong = false }
        if let f = WebSearch.first(#"喜([^，；。]+)"#, facts, group: 1) { c.fav = elements.filter { f.contains($0) } }
        if let a = WebSearch.first(#"忌([^，；。]+)"#, facts, group: 1) { c.avoid = elements.filter { a.contains($0) } }
        c.yearVerdict = WebSearch.first(#"(\d{4}年\S{2}對你是\S+?的)"#, facts, group: 1)
        if let m = WebSearch.first(#"命宮主星是([^，；。]+)"#, facts, group: 1), m != "空宮" { c.mingStars = m }
        c.jiPalace = WebSearch.first(#"化忌在([^，；。]+)"#, facts, group: 1)
        return c
    }

    /// 命理問題的「小問題」
    static func strategy(_ term: String) -> WebStrategy.Strategy {
        let z = term.contains("紫微")
        if z {
            return WebStrategy.Strategy(angles: [
                .init(title: "這個組合的含義", suffix: " 代表什麼", cues: ["代表", "象徵", "主", "意思", "含義", "表示"]),
                .init(title: "性格與特質", suffix: " 性格", cues: ["性格", "個性", "特質", "為人", "個性上"]),
                .init(title: "會帶來的影響", suffix: " 影響", cues: ["影響", "容易", "導致", "感情", "財", "事業", "健康"]),
                .init(title: "化解與建議", suffix: " 化解 建議", cues: ["化解", "建議", "宜", "應該", "注意", "可以", "避免"]),
            ], trusted: [], note: nil)
        }
        return WebStrategy.Strategy(angles: [
            .init(title: "含義與性格", suffix: " 性格 特點", cues: ["性格", "個性", "特質", "為人", "聰明", "溫柔", "代表"]),
            .init(title: "喜忌（用神）", suffix: " 喜用神", cues: ["喜", "用神", "忌", "宜", "補", "需要"]),
            .init(title: "感情", suffix: " 感情 婚姻", cues: ["感情", "婚姻", "配偶", "桃花", "另一半", "夫妻"]),
            .init(title: "事業與財運", suffix: " 事業 財運", cues: ["事業", "工作", "財", "錢", "行業", "職業"]),
            .init(title: "健康", suffix: " 健康", cues: ["健康", "身體", "疾病", "腎", "心臟", "脾胃", "肝", "肺"]),
        ], trusted: [], note: nil)
    }

    /// 主題詞：八字抓「癸水日主」，紫微抓「太陰坐命宮」這類組合
    static func base(_ term: String) -> String {
        term.replacingOccurrences(of: "紫微斗數 ", with: "").replacingOccurrences(of: "八字 ", with: "")
            .components(separatedBy: " ").first ?? term
    }

    enum Verdict { case fits, conflicts, neutral }

    /// 一句網路上的說法，放到你的盤上適不適用
    static func judge(_ s: String, _ c: Chart) -> (Verdict, String) {
        var fits: [String] = [], conflicts: [String] = []
        for e in elements {
            let likes = ["喜" + e, "用" + e, "宜" + e, "補" + e, e + "為用", e + "為喜", "需要" + e, "以" + e + "為"]
            let hates = ["忌" + e, e + "為忌", "怕" + e, e + "太旺", e + "過旺", e + "太多"]
            if likes.contains(where: { s.contains($0) }) {
                if c.fav.contains(e) { fits.append("說喜\(e)，正好是你的喜用神") }
                else if c.avoid.contains(e) { conflicts.append("說喜\(e)，但\(e)在你的盤是忌神") }
            }
            if hates.contains(where: { s.contains($0) }) {
                if c.avoid.contains(e) { fits.append("說忌\(e)，跟你的忌神一致") }
                else if c.fav.contains(e) { conflicts.append("說忌\(e)，但\(e)在你的盤是喜用神") }
            }
        }
        if let strong = c.strong {
            let saysStrong = s.contains("身強") || s.contains("身旺")
            let saysWeak = s.contains("身弱")
            if saysStrong && !saysWeak {
                if strong { fits.append("講的是身強的人，跟你一樣") } else { conflicts.append("講的是身強的人，你是身弱") }
            }
            if saysWeak && !saysStrong {
                if strong { conflicts.append("講的是身弱的人，你是身強") } else { fits.append("講的是身弱的人，跟你一樣") }
            }
        }
        if let m = c.mingStars, m.count >= 2 {
            let stars = stride(from: 0, to: m.count - 1, by: 2).map { String(Array(m)[$0..<min(m.count, $0 + 2)]) }
            if let st = stars.first(where: { s.contains($0) }) { fits.append("講到你命宮的\(st)") }
        }
        if let p = c.jiPalace, s.contains("化忌"), s.contains(p) { fits.append("講到化忌在\(p)，正是你的情況") }
        if !conflicts.isEmpty { return (.conflicts, conflicts.joined(separator: "；")) }
        if !fits.isEmpty { return (.fits, fits.joined(separator: "；")) }
        return (.neutral, "")
    }

    /// 綜合判斷
    static func conclude(_ c: Chart, fits: Int, conflicts: Int, total: Int, facts: String) -> String {
        var t = "📝 綜合判斷\n你的盤：\(facts)。\n"
        t += "網路上找到的 \(total) 個說法裡，\(fits) 個跟你的盤對得上"
        t += conflicts > 0 ? "，\(conflicts) 個不適用。" : "。"
        if conflicts > 0 {
            t += "不適用的原因多半是：網路寫的是「通論」或另一種盤（例如\(c.strong == false ? "身強" : "身弱")的人），五行喜忌剛好跟你相反，所以那幾句不要照單全收。"
        }
        if total - fits - conflicts > 0 && fits == 0 && conflicts == 0 {
            t += "這些說法都比較籠統，沒有碰到你盤上的關鍵（喜忌、身強弱），只能當背景知識。"
        }
        if !c.fav.isEmpty {
            let idx = c.fav.compactMap { elements.firstIndex(of: $0) }
            t += "\n對你來說，判斷好壞的標準是你自己的喜用神（\(c.fav.joined(separator: "、"))）"
            if !c.avoid.isEmpty { t += "，少碰忌神（\(c.avoid.joined(separator: "、"))）" }
            t += "。具體可以這樣做：\n" + idx.map { "• " + ManticReader.elementAdvice[$0] }.joined(separator: "\n")
        }
        if let y = c.yearVerdict { t += "\n另外，\(y)，網路上的年運說法要配合這一點來看。" }
        if c.isZiwei {
            t += "\n紫微的說法要看整張盤：同一顆星在不同宮位、跟哪些星同宮、有沒有化忌，意思都會變。上面標 ✅ 的，是講到你命宮主星或化忌宮位的，參考價值最高。"
        }
        return t
    }
}
