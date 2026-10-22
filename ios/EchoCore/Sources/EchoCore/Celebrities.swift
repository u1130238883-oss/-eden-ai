import Foundation

/// 名人命盤：研究用的名人（公開的生日與人生大事；三島由紀夫、川端康成另有書信與傳記裡的心境）。
/// 可以問「三島由紀夫的命盤」「川端康成的大運」「跟我同命盤的名人」。資料在 CelebrityData.swift（ai/research 產生）。
public enum Celebrities {
    public struct Person {
        public let name: String
        public let birth: BirthDay
        public let events: [(Int, String)]
        /// 書信、傳記留下的心境（大部分名人沒有）
        public let note: String

        /// 「史蒂夫·賈伯斯」也認得「賈伯斯」「史蒂夫賈伯斯」
        var aliases: [String] {
            var a = [name, name.replacingOccurrences(of: "·", with: "")]
            if let last = name.components(separatedBy: "·").last, last.count >= 2, last != name { a.append(last) }
            return a
        }
    }

    public static var all: [Person] { data }

    /// 這句話提到哪位名人（名字最長的優先）
    public static func find(in text: String) -> Person? {
        var best: (Person, Int)?
        for p in data {
            for a in p.aliases where text.contains(a) && a.count > (best?.1 ?? 0) { best = (p, a.count) }
        }
        return best?.0
    }

    /// 在問名人的命盤、運勢（光提到名字、不是在問命理的不算）
    public static func asksChart(_ text: String) -> Person? {
        let words = ["命盤", "九型", "第幾型", "大運", "流年", "運勢", "宮", "命", "算"]
        guard words.contains(where: { text.contains($0) }) else { return nil }
        return find(in: text)
    }

    /// 本命盤跟這個生日一模一樣的名人（年、月、日化成 1–9 之後相同）
    public static func sameChart(as b: BirthDay) -> [Person] {
        let mine = Destiny(b).natal
        return data.filter { Destiny($0.birth).natal == mine && $0.birth != b }
    }

    public static func asksSameChart(_ text: String) -> Bool {
        (text.contains("名人") || text.contains("誰")) && ["同命盤", "一樣的命盤", "命盤一樣", "同一個命盤", "命盤相同", "相同命盤", "同樣的命盤", "跟我一樣"].contains { text.contains($0) }
    }

    /// 名人的命盤與人生：本命、每段大運、每件事那一年的大運與流年（講成對照，不當成預言）
    public static func reading(_ p: Person) -> String {
        let D = Destiny(p.birth)
        var s = "\(p.name)（\(p.birth.display)）第\(D.type)型「\(NT.typeName(D.type))」\n本命："
            + D.natal.map { "\(NT.label($0.palace))「\($0.reading.text)」" }.joined(separator: "、")
        if !p.note.isEmpty { s += "\n" + p.note }
        if !p.events.isEmpty {
            s += "\n\n人生大事對照大運、流年："
            for (y, what) in p.events {
                let lp = D.luckPeriod(y), fy = D.year(y)
                s += "\n• \(y)年（\(y - p.birth.year)歲）\(what)：大運\(lp.start)–\(lp.end)走\(NT.label(lp.row.palace))「\(lp.row.reading.text)」第\(y - lp.start + 1)年，"
                    + "流年\(NT.label(fy.palace))「\(fy.reading.text)」"
            }
        }
        s += "\n\n這是事後對照：盤上的宮位主題常常對得上，好壞不一定。拿來理解他走過的處境，不是證明盤能預言事件。"
        return s
    }

    /// 跟你同命盤的名人
    public static func sameChartReply(_ b: BirthDay?) -> String {
        guard let b else { return "先告訴我你的生日，我才能找跟你同命盤的名人。" }
        let ps = sameChart(as: b)
        guard !ps.isEmpty else { return "我收集的名人裡，暫時沒有本命盤跟你一模一樣的人。" }
        var s = "本命盤跟你一模一樣的名人（年、月、日化成 1–9 後相同，大運也在同樣的年紀換）："
        for p in ps.prefix(5) {
            s += "\n• \(p.name)（\(p.birth.display)）"
            if let e = p.events.first(where: { $0.0 - p.birth.year == Calendar(identifier: .gregorian).component(.year, from: Date()) - b.year }) {
                s += "：他在你現在這個年紀（\(e.0 - p.birth.year)歲）\(e.1)"
            }
        }
        s += "\n同一張盤，走出來的人生可以很不一樣；可以說「\(ps[0].name)的命盤」看他每段大運的經歷。"
        return s
    }
}
