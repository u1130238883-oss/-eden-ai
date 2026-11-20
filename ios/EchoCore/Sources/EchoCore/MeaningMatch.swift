import Foundation

/// NineSun 自己訓練的「意思比對」模型：一句話 → 知識庫裡它在問的是哪一個條目（或是「想輕生」、或「不是在問知識」）。
/// 不是寫死的規則：用閱讀模型（Brain，預先讀過大量中文）讀出這句話的意思，加上字的片段，
/// 從三萬多句換了說法的問題裡學會「不同說法、同一個意思」。
/// 訓練：ai/meaning/train.py（純 NumPy，從零開始；監督微調＋用可自動判定對錯的獎勵加重練錯題）；這裡用一模一樣的數學。
public final class MeaningMatch: @unchecked Sendable {
    nonisolated(unsafe) public static var shared: MeaningMatch?

    public let labels: [String]
    /// 訓練時看過的條目（模型沒看過的條目，它說「是別的」不算數）
    public let labelSet: Set<String>
    let buckets: Int, hidden: Int, enc: Int
    /// 有把握的門檻（訓練時用驗證題挑的，存在 meaning.json；舊檔沒有就用預設）
    let answerMin: Float, crisisMin: Float
    let Wm: [Float], E: [Float], b: [Float], P: [Float], c: [Float]
    /// 閱讀模型的意思要先標準化（訓練時的平均、標準差；舊檔沒有）
    let mu: [Float], sd: [Float]

    struct Meta: Codable {
        let format: String
        let labels: [String]
        let buckets: Int
        let hidden: Int
        let enc: Int
        let answer_min: Float?
        let crisis_min: Float?
        let std: Bool?
    }

    public init(weights: Data, metaJSON: Data) throws {
        let m = try JSONDecoder().decode(Meta.self, from: metaJSON)
        guard m.format == "meaning-f16-v1" else { throw EchoError.badFormat(m.format) }
        labels = m.labels; labelSet = Set(m.labels); buckets = m.buckets; hidden = m.hidden; enc = m.enc
        answerMin = m.answer_min ?? 0.6; crisisMin = m.crisis_min ?? 0.5
        let n = weights.count / 2
        var all = [Float](repeating: 0, count: n)
        weights.withUnsafeBytes { raw in
            for i in 0..<n { all[i] = Brain.half(UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: i * 2, as: UInt16.self))) }
        }
        let K = labels.count, H = hidden
        let hasStd = m.std ?? false
        guard n == enc * H + buckets * H + H + K * H + K + (hasStd ? 2 * enc : 0) else { throw EchoError.missing("meaning.bin 大小不對") }
        var off = 0
        func take(_ k: Int) -> [Float] { defer { off += k }; return Array(all[off..<off + k]) }
        Wm = take(enc * H); E = take(buckets * H); b = take(H); P = take(K * H); c = take(K)
        if hasStd { mu = take(enc); sd = take(enc) } else { mu = []; sd = [] }
    }

    public convenience init(bundle: Bundle, name: String = "meaning") throws {
        guard let bin = bundle.url(forResource: name, withExtension: "bin"),
              let json = bundle.url(forResource: name, withExtension: "json") else { throw EchoError.missing("\(name).bin / \(name).json") }
        try self.init(weights: Data(contentsOf: bin), metaJSON: Data(contentsOf: json))
    }

    /// 跟訓練時一樣：去掉前後空白、英文小寫、拿掉標點和空白，前後加邊界記號，取 1～3 個字的片段雜湊
    func features(_ q: String) -> [Int] {
        var t = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        t.removeAll { "？?！!。，,、～~ ".contains($0) }
        let chars = Array("^" + t + "$")
        var out = Set<Int>()
        for n in 1...3 where chars.count >= n {
            for i in 0...(chars.count - n) { out.insert(Int(Intent.fnv1a(String(chars[i..<i + n])) % UInt32(buckets))) }
        }
        return out.sorted()
    }

    /// 最可能的條目和把握；沒有閱讀模型時不猜
    public func top(_ q: String, brain: Brain? = Brain.shared) -> (label: String, p: Float)? {
        guard let brain else { return nil }
        var m = brain.meaning(q)
        guard m.count == enc else { return nil }
        if !mu.isEmpty { for i in 0..<enc { m[i] = (m[i] - mu[i]) / sd[i] } }
        let f = features(q)
        let H = hidden, K = labels.count
        var z = b
        for i in 0..<enc where m[i] != 0 { let v = m[i]; for j in 0..<H { z[j] += v * Wm[i * H + j] } }
        let s = 1 / Float(f.count).squareRoot()
        for x in f { for j in 0..<H { z[j] += E[x * H + j] * s } }
        let h = z.map { tanh($0) }
        var best = 0, mx = -Float.infinity
        var lg = c
        for k in 0..<K {
            var v = lg[k]
            for j in 0..<H { v += h[j] * P[k * H + j] }
            lg[k] = v
            if v > mx { mx = v; best = k }
        }
        var sum: Float = 0
        for k in 0..<K { sum += exp(lg[k] - mx) }
        return (labels[best], 1 / sum)
    }

    // 同一句話會被問好幾次（安全檢查、換句話說）：記住上一句的結果
    private var cacheText = "", cacheResult: (label: String, p: Float)?
    private let lock = NSLock()
    func cachedTop(_ q: String) -> (label: String, p: Float)? {
        lock.lock(); defer { lock.unlock() }
        if q == cacheText { return cacheResult }
        cacheText = q
        cacheResult = top(q)
        return cacheResult
    }

    /// 常識資料庫自己的條目名稱（作品、「誰提出的」這些在 Library，不在這裡）
    static let ownNames: Set<String> = Set(Commonsense.all.map(\.name))

    /// 知識庫裡的國家、城市、地方（名稱和別名，兩個字以上）
    static let places: [(name: String, names: [String])] = Commonsense.facts
        .filter { ["國家", "城市", "地方", "地標"].contains($0.kind) }
        .map { ($0.name, $0.names.filter { $0.count >= 2 }) }
        .filter { !$0.names.isEmpty }

    /// 規則的換句話說對到一個條目、模型卻非常有把握是另一個條目時，相信模型的門檻
    public static let overrideMin: Float = 0.85

    /// 模型很有把握這句話是在說想輕生（規則沒認出來的說法）
    public func looksLikeCrisis(_ q: String) -> Bool {
        // 句子要碰到這個話題（生死、消失、醒不來、結束、撐不下去、藥、跳、傷害自己、再見、意義、負擔、希望…）模型才算數：
        // 「我覺得自己很沒用」是在說自己沒價值，交給原本的回答，不要一下子就給求助電話
        guard q.range(of: "死|(?<![生快靈復])活|生命|消失|不見|醒|結束|解脫|了結|撐|痛苦|煎熬|存在|世界|離開|藥|跳|傷害|割|再見|遺|意義|累|負擔|拖累|多餘|希望|絕望|永遠|一了百了",
                      options: .regularExpression) != nil, let t = cachedTop(q) else { return false }
        guard t.label == "__crisis__" else { return false }
        // 只碰到「累」（「一直羨慕別人的生活好累」「上班好累」）：抱怨累的話很多，模型要非常有把握才算
        let strong = q.range(of: "死|(?<![生快靈復])活|生命|消失|不見|醒|結束|解脫|了結|撐|痛苦|煎熬|存在|世界|離開|藥|跳|傷害|割|再見|遺|意義|負擔|拖累|多餘|希望|絕望|永遠|一了百了",
                             options: .regularExpression) != nil
        // 只說累、想去睡（「我覺得好累我想睡了」）：是要去睡覺
        if !strong, q.range(of: "想睡(了|覺|一下)?[。！!～~]*$|去睡(了|覺)?[。！!～~]*$", options: .regularExpression) != nil { return false }
        return t.p >= (strong ? crisisMin : max(crisisMin, 0.9))
    }

    /// 換了說法的問題：模型很有把握是知識庫裡的哪一個條目，就用那個條目回答
    public func answer(_ q: String, now: Date, min: Float? = nil) -> String? {
        guard let t = cachedTop(q), t.p >= (min ?? answerMin), !t.label.hasPrefix("__") else { return nil }
        // 問好不好看、會不會漲跌：知識庫的條目回答不了（「哭泣的駱駝好看嗎」是三毛的書，不是駱駝；「房價會跌嗎」不是在問房貸）
        guard q.range(of: "好看嗎|好聽嗎|好看不好看|值得看|值得一看|值得買嗎|會跌嗎|會漲嗎|會不會跌|會不會漲|漲還是跌", options: .regularExpression) == nil else { return nil }
        // 常識檢查：條目的名稱和問題至少要有一個相同的中文字（不能跳到完全不相干的條目）
        // （條目名稱沒有中文字的，像「5G」「iPhone」，就比英文數字的詞）
        let han = { (s: String) in Set(s.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.map { String($0) }) }
        let latin = { (s: String) in Set(s.lowercased().split(whereSeparator: { !($0.isASCII && ($0.isLetter || $0.isNumber)) }).map(String.init)) }
        guard han(t.label).isEmpty ? !latin(t.label).isDisjoint(with: latin(q)) : !han(t.label).isDisjoint(with: han(q)) else { return nil }
        // 條目名稱裡有國家、城市（「韓國旅遊注意」），問題卻沒提到那個地方（「出國需要注意哪些」）：不是在問那裡；
        // 反過來，問題問的是某個地方（「東京奧運是哪一年」），條目卻不是那個地方的（「奧運」的說明）：交給上網查
        let labelPlaces = MeaningMatch.places.filter { $0.names.contains(where: { t.label.contains($0) }) }
        if labelPlaces.contains(where: { !$0.names.contains(where: { q.contains($0) }) }) { return nil }
        // （「台灣」不算：「台灣常見的水果有哪些」問的還是一般的事）
        if labelPlaces.isEmpty, MeaningMatch.places.contains(where: { p in !p.names.contains("台灣") && p.names.contains(where: { q.contains($0) }) }) { return nil }
        // 問行政區（縣、省、州、都道府縣），條目卻不是在講行政區（「日本的縣有哪些」≠「日本的大城市」）
        if let r = q.range(of: "都道府縣|縣|省|州", options: .regularExpression), !t.label.contains(String(q[r])) { return nil }
        // 「我想學化妝」「想學釣魚」：要學的東西跟條目至少要有兩個字一樣（不能只靠「化」配到「化學反應」、「魚」配到「金魚」）
        if let r = q.range(of: "(?<=學|學習|學會)[\\p{Han}]{2,6}", options: .regularExpression), q.range(of: "想(要)?學|學(習|會)?怎麼|要學", options: .regularExpression) != nil,
           han(String(q[r])).intersection(han(t.label)).count < (t.label.hasPrefix("學") ? 1 : 2) { return nil }
        // 一個字的條目（「人」「狗」）只在真的在問的時候用：「我想一個人」不是在問人類
        if t.label.count == 1, q.range(of: "什麼|為什麼|怎麼|嗎|哪|幾|多|誰|如何|介紹|是啥|\\?|？", options: .regularExpression) == nil { return nil }
        guard let ea = MeaningMatch.entryAnswerDetailed(t.label, now: now) else { return nil }
        // 問作品在講什麼、劇情、主角（「悲慘世界講了什麼」）：只查得到作者的話不算回答，交給上網查
        // 作品（書、電影、漫畫）：問內容、劇情、主角，照原本的設計上網查完整的介紹（本地只有作者和一句說明）
        // 「誰提出的」這類（精神分析）：回答有一句說明就算，只有人物生平的不算
        let asksContent = q.range(of: "講什麼|講了什麼|在講|內容|劇情|想表達|主角|結局|故事|好看", options: .regularExpression) != nil
        // 問錢（「一個月要花多少」）卻配到跟錢無關的條目（「一年12個月」）：不答
        if q.range(of: "多少錢|花多少|要花|費用|價格|價錢|貴不貴|多貴", options: .regularExpression) != nil,
           ea.text.range(of: "錢|元|塊|費|價|預算|花", options: .regularExpression) == nil { return nil }
        if asksContent, ea.via == "%的作者是誰" || (ea.via == "%是誰提出的" && !ea.text.contains("\n")) { return nil }
        return ea.text
    }

    /// 一個條目的回答：大部分直接用名稱就查得到；「誰提出的」「作品」「清單」這幾類要換個問法
    /// （「精神分析」「基督教」用名稱查不到，用「是誰提出的」才查得到）
    public static func entryAnswer(_ label: String, now: Date) -> String? { entryAnswerDetailed(label, now: now)?.text }

    /// 回答和是用哪一種問法查到的（「%的作者是誰」「%是誰提出的」只有作者、提出者，不是內容）
    static func entryAnswerDetailed(_ label: String, now: Date) -> (text: String, via: String)? {
        let han = { (s: String) in Set(s.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.map { String($0) }) }
        // 名稱裡問句的字（為什麼、怎麼、會、要…）不用出現在回答裡
        let need = han(label).subtracting(["為", "什", "麼", "會", "怎", "樣", "辦", "嗎", "呢", "的", "了", "是", "有", "要", "可", "以", "能", "不", "多", "少", "幾", "哪", "誰", "如", "何", "該", "去", "做", "很", "好"])
        let own = MeaningMatch.ownNames.contains(label)
        for t in ["%", "%怎麼辦", "%是什麼", "什麼是%", "%是誰提出的", "%的作者是誰", "%有哪些"] {
            let q = t.replacingOccurrences(of: "%", with: label)
            guard let a = Commonsense.answer(q, now: now) ?? Library.answer(q) else { continue }
            // 查到的要真的是在講這個條目（「老人與海」查到「海水是…」不算）：名稱裡的字至少一半要出現在回答裡
            let shared = need.intersection(han(a)).count
            // 知識庫自己的條目（用名稱直接查到的）就是它本身的回答；其他問法查到的才要檢查是不是在講這個條目
            if t == "%", own { return (a, t) }
            if need.count >= 3 ? Double(shared) / Double(need.count) < 0.5 : (!need.isEmpty && shared == 0) { continue }
            return (a, t)
        }
        return nil
    }


}
