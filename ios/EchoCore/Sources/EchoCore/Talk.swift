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

    public static func answer(_ raw: String) -> String? {
        let t = clean(raw)
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
            return e.answers[abs(i)]
        }
        return nil
    }
}
