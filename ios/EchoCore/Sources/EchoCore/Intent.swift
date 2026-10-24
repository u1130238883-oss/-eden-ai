import Foundation

/// NineSun 自己訓練的「理解問題」模型：一句話 → 這句話要的是什麼（列出有哪些、在講什麼、有幾個、為什麼……）。
/// 不是寫死的規則：它從十幾萬句問法裡自己學到哪些字的組合代表哪一種問法，沒看過的說法也能類推。
/// 訓練：ai/intent/train.py（純 NumPy，從零開始）；這裡用一模一樣的雜湊和數學推理。
public final class Intent: @unchecked Sendable {
    nonisolated(unsafe) public static var shared: Intent?

    public let labels: [String]
    let buckets: Int, dim: Int, hidden: Int, ngram: [Int], enc: Int
    let E: [Float], W1: [Float], b1: [Float], W2: [Float], b2: [Float]
    /// 閱讀模型讀出來的意思要先標準化（訓練時的平均、標準差）
    let encMean: [Float], encStd: [Float]

    struct Meta: Codable {
        let labels: [String]
        let buckets: Int
        let dim: Int
        let hidden: Int
        let ngram: [Int]
        let enc: Int?
    }

    public init(weights: Data, metaJSON: Data) throws {
        let m = try JSONDecoder().decode(Meta.self, from: metaJSON)
        labels = m.labels; buckets = m.buckets; dim = m.dim; hidden = m.hidden; ngram = m.ngram; enc = m.enc ?? 0
        let all: [Float] = weights.withUnsafeBytes { raw in
            (0..<(raw.count / 4)).map { Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: $0 * 4, as: UInt32.self))) }
        }
        var off = 0
        func take(_ n: Int) -> [Float] { defer { off += n }; return Array(all[off..<off + n]) }
        let L = labels.count
        let In = dim + enc
        guard all.count == buckets * dim + In * hidden + hidden + hidden * L + L + 2 * enc else { throw EchoError.missing("intent.bin 大小不對") }
        E = take(buckets * dim); W1 = take(In * hidden); b1 = take(hidden); W2 = take(hidden * L); b2 = take(L)
        encMean = take(enc); encStd = take(enc)
    }

    public convenience init(bundle: Bundle, name: String = "intent") throws {
        guard let bin = bundle.url(forResource: name, withExtension: "bin"),
              let json = bundle.url(forResource: name, withExtension: "json") else { throw EchoError.missing("\(name).bin / \(name).json") }
        try self.init(weights: Data(contentsOf: bin), metaJSON: Data(contentsOf: json))
    }

    static func fnv1a(_ s: String) -> UInt32 {
        var h: UInt32 = 0x811C9DC5
        for b in s.utf8 { h ^= UInt32(b); h = h &* 0x01000193 }
        return h
    }

    /// 跟訓練時一樣：小寫、去掉標點和空白，前後加上邊界記號，切成 1～3 個字的片段，雜湊到格子
    func features(_ q: String) -> [Int] {
        var t = q.lowercased()
        t.removeAll { "？?！!。，,、～~ ".contains($0) }
        let s = Array(("^" + t + "$").unicodeScalars)
        var out = Set<Int>()
        for n in ngram where s.count >= n {
            for i in 0...(s.count - n) {
                var piece = String.UnicodeScalarView()
                piece.append(contentsOf: s[i..<i + n])
                out.insert(Int(Intent.fnv1a(String(piece)) % UInt32(buckets)))
            }
        }
        return out.sorted()
    }

    /// 每個題型的機率（由高到低）。brain：NineSun 的閱讀模型（讀出這句話的意思）；模型有用到意思卻沒有閱讀模型時不猜
    public func predict(_ q: String, brain: Brain? = Brain.shared) -> [(label: String, p: Float)] {
        let f = features(q)
        guard !f.isEmpty else { return [] }
        let In = dim + enc
        var h0 = [Float](repeating: 0, count: In)
        for b in f { for d in 0..<dim { h0[d] += E[b * dim + d] } }
        for d in 0..<dim { h0[d] /= Float(f.count) }
        if enc > 0 {
            guard let brain else { return [] }
            let m = brain.meaning(q)
            guard m.count == enc else { return [] }
            for i in 0..<enc { h0[dim + i] = (m[i] - encMean[i]) / encStd[i] }
        }
        var a1 = b1
        for j in 0..<hidden {
            var z = a1[j]
            for d in 0..<In { z += h0[d] * W1[d * hidden + j] }
            a1[j] = max(z, 0)
        }
        let L = labels.count
        var lg = b2
        for k in 0..<L { for j in 0..<hidden { lg[k] += a1[j] * W2[j * L + k] } }
        let mx = lg.max() ?? 0
        let ex = lg.map { exp($0 - mx) }
        let sum = ex.reduce(0, +)
        return zip(labels, ex).map { ($0, $1 / sum) }.sorted { $0.p > $1.p }
    }

    /// 最可能的題型和把握
    public func top(_ q: String, brain: Brain? = Brain.shared) -> (label: String, p: Float)? { predict(q, brain: brain).first }
}
