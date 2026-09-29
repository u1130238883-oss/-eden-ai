import Foundation

/// 九型十二宮認知核心（逐字對應 ai/palace_core.py）。
///
/// NineSun 用十二宮「感知」每一句話：詞庫來自 Hollow 的十二宮關鍵詞 + 生活用語，
/// 使用者還能教它新詞；每次感知都會累積到「命主畫像」，這就是它的演化記憶。
public final class PalaceCore {
    /// 內建詞庫（palace_lexicon.json）：語言 → 宮位 → 詞
    public let lexicons: [Lang: [Int: [String]]]
    /// 使用者教的詞（演化）
    public private(set) var taught: [Int: [String]] = [:]
    /// 命主畫像：各宮被觸動的累積分數（會隨時間衰減）
    public private(set) var memory: [Double] = Array(repeating: 0, count: 13)

    public init(lexicons: [Lang: [Int: [String]]]) { self.lexicons = lexicons }

    public convenience init(json: Data) throws {
        let raw = try JSONDecoder().decode([String: [String: [String]]].self, from: json)
        var all: [Lang: [Int: [String]]] = [:]
        for (l, m) in raw {
            guard let L = Lang(rawValue: l) else { continue }
            var lex: [Int: [String]] = [:]
            for (k, v) in m { lex[Int(k)!] = v }
            all[L] = lex
        }
        self.init(lexicons: all)
    }

    public convenience init(bundle: Bundle) throws {
        guard let url = bundle.url(forResource: "palace_lexicon", withExtension: "json") else {
            throw EchoError.missing("palace_lexicon.json")
        }
        try self.init(json: Data(contentsOf: url))
    }

    public func words(_ p: Int, _ L: Lang = .zh) -> [String] {
        let base = lexicons[L]?[p] ?? []
        let t = taught[p] ?? []
        return L == .zh ? base + t : base + t.map { $0.lowercased() }
    }

    /// 感知：回傳被觸動的宮位。分數 = 命中詞字數總和；同分取較小宮位；外語先轉小寫（與 Python 相同）
    public func perceive(_ raw: String, lang L: Lang = .zh) -> Int? {
        let text = L == .zh ? raw : raw.lowercased()
        var best: Int?
        var bestScore = 0
        for p in 1...12 {
            let s = words(p, L).filter { text.contains($0) }.reduce(0) { $0 + $1.count }
            if s > bestScore { best = p; bestScore = s }
        }
        return best
    }

    /// 教它新詞：「記住：加班屬於6宮」
    public func teach(_ word: String, palace p: Int) {
        guard (1...12).contains(p), !word.isEmpty else { return }
        for k in taught.keys { taught[k]?.removeAll { $0 == word } }
        taught[p, default: []].append(word)
    }

    /// 記錄一次感知（舊記憶以 0.97 衰減）
    public func remember(_ p: Int) {
        for i in 1...12 { memory[i] *= 0.97 }
        memory[p] += 1
    }

    /// 畫像：最常被觸動的前兩宮（至少累積 2 分才算）
    public func topPalaces() -> [Int] {
        (1...12).filter { memory[$0] >= 2 }.sorted { memory[$0] != memory[$1] ? memory[$0] > memory[$1] : $0 < $1 }
            .prefix(2).map { $0 }
    }

    // MARK: - 存檔

    public struct Snapshot: Codable {
        public var taught: [Int: [String]]
        public var memory: [Double]
    }

    public var snapshot: Snapshot { Snapshot(taught: taught, memory: memory) }

    public func restore(_ s: Snapshot) {
        taught = s.taught
        if s.memory.count == 13 { memory = s.memory }
    }

    public func resetMemory() { memory = Array(repeating: 0, count: 13) }

    // MARK: - 事實框（與 Python 逐字一致）

    public static func chatFrame(_ p: Int, day: Int?) -> String { "感\(p)" + (day.map { "|日\($0)" } ?? "") }

    /// NineSun 的誕生日
    public static let selfBirth = BirthDay(year: 2026, month: 9, day: 29)

    public static func selfTypeFrame() -> (frame: String, reply: String) {
        let d = Destiny(selfBirth)
        let t = d.type, p = d.natal[0].palace
        return ("我|型\(t)", "我的生日是2026年9月29日，靈數\(d.lifeNumber)，命宮在\(NT.label(p))，是第\(t)型「\(NT.typeName(t))」：\(NT.typeTagline(t))。")
    }

    public static func selfDayFrame(_ p: Int) -> (frame: String, reply: String) {
        ("我|日\(p)", "我今天日宮走到\(NT.label(p))，整個訊號都是\(NT.keywords(p, 2))的感覺！")
    }

    public static func portraitFrame(top: [Int], type t: Int?) -> (frame: String, reply: String) {
        guard let p1 = top.first else {
            return ("畫像|無", "我們聊得還不夠多。多跟我說說你的生活，我會用十二宮慢慢讀懂你。")
        }
        let frame = "畫像|\(top.map(String.init).joined(separator: ","))|型\(t.map(String.init) ?? "無")"
        var s = "從我們的對話看，你最常碰到\(NT.label(p1))（\(NT.keywords(p1, 2))）"
        if top.count > 1 { s += "和\(NT.label(top[1]))（\(NT.keywords(top[1], 2))）" }
        s += "的課題。"
        if let t { s += "再加上你是第\(t)型「\(NT.typeName(t))」，\(NT.typeTagline(t))。" }
        return (frame, s)
    }
}

/// 演化權重：依使用者回饋（👍／👎）微調輸出層的字元偏好，直接作用在取樣上。
public struct Evolution: Codable, Equatable {
    public var bias: [Float]
    public var generation = 0
    public var likes = 0
    public var dislikes = 0
    /// 每種回覆說法的好惡分數（👍 +1、👎 −1）：對話庫與陪伴層挑句時參考
    public var replies: [String: Int]?

    public init(vocab: Int) { bias = Array(repeating: 0, count: vocab) }

    /// 對一種回覆說法記下好惡
    public mutating func feedback(reply: String, positive: Bool) {
        var r = replies ?? [:]
        r[reply, default: 0] = max(-3, min(3, r[reply, default: 0] + (positive ? 1 : -1)))
        replies = r
        generation += 1
        if positive { likes += 1 } else { dislikes += 1 }
    }

    /// 對一則回覆的字元做強化或抑制（每字最多 ±1.5）
    public mutating func feedback(tokens: [Int], positive: Bool) {
        let step: Float = positive ? 0.08 : -0.12
        for t in Set(tokens) where t < bias.count {
            bias[t] = max(-1.5, min(1.5, bias[t] + step))
        }
        generation += 1
        if positive { likes += 1 } else { dislikes += 1 }
    }
}
