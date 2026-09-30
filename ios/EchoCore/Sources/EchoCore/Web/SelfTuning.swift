import Foundation

/// NineSun 的自我升級：不記答案，只從經驗調整「怎麼查」。
///
/// 每查一次，就記下幾個數字（幾 KB，不會越存越大）：
///   • 哪些網站對哪一類問題真的有答案 → 下次先讀可靠的，常給垃圾的放最後
///   • 哪一類問題第一輪常常查不到 → 下次第一輪就用比較好的查法
///   • 使用者按 👎 → 那次用到的網站和查法扣分
public final class SelfTuning {
    public struct Stat: Codable, Equatable {
        public var tries = 0
        public var wins = 0
        /// 平滑後的成功率（沒資料時是 0.5）
        public var rate: Double { Double(wins + 1) / Double(tries + 2) }
    }
    public struct State: Codable, Equatable {
        /// 網站（依問題類型）："number|zh.wikipedia.org"
        public var sources: [String: Stat] = [:]
        /// 各類問題第一輪就答到的比例
        public var firstRound: [String: Stat] = [:]
        /// 累計學了幾次
        public var lessons = 0
        public init() {}
    }

    public static let shared = SelfTuning()
    private let lock = NSLock()
    private var s = State()

    public init() {}

    public var state: State {
        get { lock.lock(); defer { lock.unlock() }; return s }
        set { lock.lock(); s = newValue; lock.unlock() }
    }

    static let maxSources = 300

    /// 問題類型的名稱（number、list、reason……）
    public static func kind(_ w: Understanding.Want) -> String {
        switch w {
        case .number: return "number"
        case .list: return "list"
        case .reason: return "reason"
        case .steps: return "steps"
        case .person: return "person"
        case .place: return "place"
        case .time: return "time"
        case .definition: return "definition"
        case .compare: return "compare"
        case .open: return "open"
        }
    }

    /// 這個網站對這類問題的經驗分數：可靠 +2，常給垃圾 −3，資料不夠 0
    public func bonus(_ host: String, kind: String) -> Int {
        guard let st = state.sources["\(kind)|\(host)"], st.tries >= 3 else { return 0 }
        if st.rate >= 0.6 { return 2 }
        if st.rate <= 0.25 { return -3 }
        return 0
    }

    /// 這類問題第一輪常常查不到（試過 5 次以上、成功不到三成）：第一輪就加上備用查法
    public func startWithRetry(kind: String) -> Bool {
        guard let st = state.firstRound[kind], st.tries >= 5 else { return false }
        return st.rate < 0.3
    }

    /// 查完一次後學習：讀過的網站算試一次，答案真的用到的網站算成功一次
    public func record(kind: String, firstRoundOK: Bool, answered: Bool, read: [String], used: [String]) {
        lock.lock(); defer { lock.unlock() }
        s.firstRound[kind, default: Stat()].tries += 1
        if firstRoundOK { s.firstRound[kind, default: Stat()].wins += 1 }
        for h in Set(read + used) {
            let k = "\(kind)|\(h)"
            s.sources[k, default: Stat()].tries += 1
            if answered && used.contains(h) { s.sources[k, default: Stat()].wins += 1 }
        }
        s.lessons += 1
        trim()
    }

    /// 使用者回饋：👎 那次用到的網站扣分（多算一次失敗），👍 加分
    public func feedback(kind: String, hosts: [String], positive: Bool) {
        lock.lock(); defer { lock.unlock() }
        for h in Set(hosts) {
            let k = "\(kind)|\(h)"
            s.sources[k, default: Stat()].tries += 1
            if positive { s.sources[k, default: Stat()].wins += 1 }
        }
        s.lessons += 1
        trim()
    }

    /// 最有經驗的網站（給「我的思路」說明用）
    public func trusted(kind: String, among hosts: [String]) -> [String] {
        hosts.filter { bonus($0, kind: kind) > 0 }
    }

    /// 只保留試過最多次的網站，檔案不會一直變大
    private func trim() {
        guard s.sources.count > Self.maxSources else { return }
        let keep = s.sources.sorted { $0.value.tries > $1.value.tries }.prefix(Self.maxSources)
        s.sources = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
    }

    /// 回覆裡「（zh.wikipedia.org）」這種來源標記
    public static func hosts(in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: #"（([A-Za-z0-9][A-Za-z0-9.\-]*\.[A-Za-z]{2,})）"#) else { return [] }
        var out: [String] = []
        for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let r = Range(m.range(at: 1), in: text), !out.contains(String(text[r])) { out.append(String(text[r])) }
        }
        return out
    }
}
