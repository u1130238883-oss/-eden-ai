import Foundation

/// NineSun 自己訓練的「意思比對」模型：一句話 → 知識庫裡它在問的是哪一個條目（或是「想輕生」、或「不是在問知識」）。
/// 不是寫死的規則：用閱讀模型（Brain，預先讀過大量中文）讀出這句話的意思，加上字的片段，
/// 從三萬多句換了說法的問題裡學會「不同說法、同一個意思」。
/// 訓練：ai/meaning/train.py（純 NumPy，從零開始；監督微調＋用可自動判定對錯的獎勵加重練錯題）；這裡用一模一樣的數學。
public final class MeaningMatch: @unchecked Sendable {
    nonisolated(unsafe) public static var shared: MeaningMatch?

    public let labels: [String]
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
        labels = m.labels; buckets = m.buckets; hidden = m.hidden; enc = m.enc
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

    /// 模型很有把握這句話是在說想輕生（規則沒認出來的說法）
    public func looksLikeCrisis(_ q: String) -> Bool {
        // 句子要碰到這個話題（生死、消失、醒不來、結束、撐不下去、藥、跳、傷害自己、再見、意義、負擔、希望…）模型才算數：
        // 「我覺得自己很沒用」是在說自己沒價值，交給原本的回答，不要一下子就給求助電話
        guard q.range(of: "死|活|生命|消失|不見|醒|結束|解脫|了結|撐|痛苦|煎熬|存在|世界|離開|藥|跳|傷害|割|再見|遺|意義|累|負擔|拖累|多餘|希望|絕望|永遠|一了百了",
                      options: .regularExpression) != nil, let t = cachedTop(q) else { return false }
        return t.label == "__crisis__" && t.p >= crisisMin
    }

    /// 換了說法的問題：模型很有把握是知識庫裡的哪一個條目，就用那個條目回答
    public func answer(_ q: String, now: Date) -> String? {
        guard let t = cachedTop(q), t.p >= answerMin, !t.label.hasPrefix("__") else { return nil }
        // 常識檢查：條目的名稱和問題至少要有一個相同的中文字（不能跳到完全不相干的條目）
        let han = { (s: String) in Set(s.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }) }
        guard !han(t.label).isDisjoint(with: han(q)) else { return nil }
        return Commonsense.answer(t.label, now: now) ?? Commonsense.answer(t.label + "怎麼辦", now: now)
    }
}
