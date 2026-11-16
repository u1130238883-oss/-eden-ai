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

    public static func answer(_ raw: String) -> String? { detailed(raw)?.text }

    /// 剛剛回答的是哪一種（笑話、自己、看法、選擇…），追問時要接得上
    public static func detailed(_ raw: String) -> (text: String, kind: String, name: String)? {
        guard let a = match(raw) else { return nil }
        return a
    }

    /// 追問：笑話「再一個」「不好笑」、選擇題「可是我很怕」、看法「為什麼」
    public static func followUp(_ raw: String, kind: String) -> String? {
        let t = clean(raw)
        switch kind {
        case "笑話":
            if t.range(of: "^(再|再來|再講|再說|多講|多說|還有|還要|換)(一|一個|一則|個|則|點)?(笑話|個|好笑的)?(嗎|啦)?$|^還有嗎$|^還有呢$|^另一個$|^換一個$|^再一次$", options: .regularExpression) != nil {
                return answer("講個笑話")
            }
            if t.range(of: "^(不好笑|好冷|很冷|超冷|太冷了|好爛|很爛|沒梗|好無聊|聽不懂|不懂|冷笑話|尬)", options: .regularExpression) != nil {
                return "哈哈，好啦，這個是冷了一點😅 再給我一次機會：\n" + (answer("講個笑話") ?? "")
            }
            if t.range(of: "^(哈+|笑死|好笑|很好笑|超好笑|XD+|lol)$", options: [.regularExpression, .caseInsensitive]) != nil {
                return "看你笑我也開心！還要再聽一個嗎？"
            }
        case "選擇":
            if t.range(of: "^(可是|但是|但)?我(還是)?(很|好|有點|超|真的)?(怕|害怕|不敢|擔心|猶豫|不確定|很難決定|好難決定|不知道怎麼選|不知道要不要)", options: .regularExpression) != nil {
                return "會怕很正常，代表這件事對你很重要。可以試試這樣想：最壞的情況是什麼？如果真的發生，你有沒有辦法撐過去、有沒有退路？很多時候想清楚最壞的情況，反而就沒那麼怕了。你也不用一次決定，可以先做一個小小的、能回頭的試探。"
            }
        case "自己", "看法":
            if t.range(of: "^(為什麼|為何|怎麼說|為啥|真的嗎|是喔|是哦)$", options: .regularExpression) != nil {
                return "說不上有什麼大道理，這是我跟很多人聊天之後慢慢形成的想法。你呢？你怎麼看？"
            }
        default: break
        }
        return nil
    }

    static func match(_ raw: String) -> (text: String, kind: String, name: String)? {
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
            return (e.answers[abs(i)], e.kind, e.name)
        }
        return nil
    }
}
