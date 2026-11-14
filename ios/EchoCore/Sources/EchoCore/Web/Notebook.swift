import Foundation

/// NineSun 的知識筆記本：查證過、有把握的答案記下來（答案、哪一天、哪些網站、查到幾次）。
///
/// 筆記不拿來直接回答——每一題還是即時上網查；筆記是拿來「對照」的：
///   • 這次查到的跟以前記的一樣 → 說出來（查到同樣答案越多次越可信）
///   • 不一樣 → 說出來，以這次的資料為準，更新筆記（會變的資料本來就該更新）
///   • 被使用者說「不對」過 → 下次查同一題時特別說明，這次的資料跟使用者說的一不一樣
public final class Notebook {
    public struct Note: Codable, Equatable {
        public var question: String
        public var answer: String
        public var hosts: [String]
        public var date: Date
        /// 查到同樣答案幾次
        public var times: Int = 1
        /// 使用者說過這個答案不對
        public var disputed: Bool = false
        /// 使用者說的正確答案（「不對，是 1912 年」）
        public var userSaid: String?
    }

    public struct State: Codable, Equatable {
        public var notes: [String: Note] = [:]
        public init() {}
    }

    public static let shared = Notebook()
    private let lock = NSLock()
    private var s = State()

    public init() {}

    public var state: State {
        get { lock.lock(); defer { lock.unlock() }; return s }
        set { lock.lock(); s = newValue; lock.unlock() }
    }

    static let maxNotes = 400

    /// 同一題的鑰匙：主題＋要的東西（「台北101有多高」「台北101多高啊」都是「台北101|number」）
    public static func key(_ q: String) -> String {
        let f = Understanding.frame(q)
        let subject = Understanding.plain(f.subject.isEmpty ? q : f.subject)
        return subject + "|" + SelfTuning.kind(f.want)
    }

    public func note(for q: String) -> Note? { state.notes[Notebook.key(q)] }

    /// 這次查完：跟筆記對照，回傳要告訴使用者的話（第一次記下時不說），並更新筆記。
    /// recent：會變的資料（「現任」「最新」），答案不同是正常的
    public func compare(_ q: String, answer raw: String, hosts: [String], recent: Bool = false, now: Date = Date()) -> String? {
        let answer = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty, answer.count <= 40 else { return nil }
        let k = Notebook.key(q)
        lock.lock(); defer { lock.unlock() }
        let fresh = Note(question: q, answer: answer, hosts: Array(hosts.prefix(3)), date: now)
        guard var n = s.notes[k] else {
            s.notes[k] = fresh
            trim()
            return nil
        }
        let days = max(0, Int(now.timeIntervalSince(n.date) / 86_400))
        let when = days == 0 ? "今天稍早" : "\(days) 天前"
        let a = Think.key(answer), b = Think.key(n.answer)
        let same = !a.isEmpty && !b.isEmpty && (a == b || a.contains(b) || b.contains(a))
        var line: String
        if n.disputed {
            // 被指正過：這次特別對照使用者說的
            if let u = n.userSaid.map(Think.key), !u.isEmpty, a.contains(u) || u.contains(a) {
                line = "📒 你上次說答案不對（你說是「\(n.userSaid!)」），這次查到的資料跟你說的一樣，你是對的，筆記已經更正。"
            } else if let u = n.userSaid {
                line = "📒 你上次說是「\(u)」，但這次的資料指向「\(answer)」。我把兩個都記著；如果你有可靠的出處，告訴我，我再查證。"
            } else if same {
                line = "📒 你上次說「\(n.answer)」不對，我換了查法重查，資料還是指向同一個答案；如果你知道正確的，告訴我，我會再查證。"
            } else {
                line = "📒 你上次說「\(n.answer)」不對，這次查到的是「\(answer)」，筆記已經更正。"
            }
            n = fresh
        } else if same {
            n.times += 1
            n.date = now
            n.hosts = Array(Set(n.hosts + hosts).prefix(4))
            line = "📒 跟我\(when)查到、記在筆記裡的一樣（第 \(n.times) 次查到同樣的答案）。"
        } else {
            line = "📒 我筆記裡記的是「\(n.answer)」（\(when)），這次查到的不一樣。"
                + (recent ? "這類資料會變，以這次的為準，筆記已經更新。" : "我以這次的資料為準、更新筆記，但兩種說法你都可以再確認。")
            n = fresh
        }
        s.notes[k] = n
        return line
    }

    /// 使用者說上一個答案不對（可能也說了正確答案）
    public func dispute(_ q: String, userSaid: String?) {
        let k = Notebook.key(q)
        lock.lock(); defer { lock.unlock() }
        var n = s.notes[k] ?? Note(question: q, answer: "", hosts: [], date: Date())
        n.disputed = true
        if let u = userSaid, !u.isEmpty { n.userSaid = u }
        s.notes[k] = n
    }

    /// 「你的筆記」：最近學到的幾條
    public func summary(limit: Int = 8) -> String {
        let notes = state.notes.values.filter { !$0.answer.isEmpty }.sorted { $0.date > $1.date }
        guard !notes.isEmpty else { return "我的知識筆記還是空的。每次上網查到有把握的答案，我都會記下來，下次查同一題時拿來對照。" }
        let f = DateFormatter()
        f.dateFormat = "M/d"
        var t = "📒 我的知識筆記（共 \(notes.count) 條，最近的 \(min(limit, notes.count)) 條）：\n"
        for n in notes.prefix(limit) {
            t += "• \(Understanding.plain(n.question))：\(n.answer)（\(f.string(from: n.date))" + (n.times > 1 ? "，查到 \(n.times) 次" : "") + (n.disputed ? "，你說過不對" : "") + "）\n"
        }
        return t + "筆記不會直接拿來回答——每次還是重新上網查，再跟筆記對照。"
    }

    private func trim() {
        guard s.notes.count > Notebook.maxNotes else { return }
        let old = s.notes.sorted { $0.value.date < $1.value.date }.prefix(s.notes.count - Notebook.maxNotes)
        for (k, _) in old { s.notes.removeValue(forKey: k) }
    }
}
