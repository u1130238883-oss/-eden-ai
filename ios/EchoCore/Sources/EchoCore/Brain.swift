import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// NineSun 的大腦：閱讀理解模型（純 Swift 推理，數學和 ai/reader_model.py 完全一樣）。
///
/// 它學會的是「讀懂」這個方法，不是背答案：
///   給一個問題和一段從沒看過的文字 → 判斷這段有沒有在回答問題 → 有的話指出答案是哪幾個字。
/// 上網查到的每一段文字都讓它讀一次，由它決定哪些有用、答案是什麼，不用替每種問題寫規則。
public final class Brain {
    public struct Config: Codable {
        public let vocab_size: Int
        public let n_ctx: Int
        public let n_embd: Int
        public let n_head: Int
        public let n_layer: Int
    }

    struct Meta: Codable {
        struct Tensor: Codable { let name: String; let shape: [Int]; let offset: Int }
        struct Specials: Codable { let pad, unk, cls, sep: Int }
        let format: String
        let config: Config
        let vocab: [String]
        let specials: Specials
        let tensors: [Tensor]
        let num_params: Int
        let q_max: Int?
        let punct: [String]?
    }

    struct Layer {
        var ln1g, ln1b, wqkv, bqkv, wo, bo, ln2g, ln2b, wfc, bfc, wproj, bproj: [Float]
    }

    /// 讀一段文字的結果
    public struct Span {
        /// 答案（原文裡的那幾個字）
        public let text: String
        /// 有多肯定這段在回答問題：答案分數減掉「這段沒有答案」的分數；大於 0 表示它認為有答案
        public let score: Float
        /// 答案在段落裡的位置（Unicode 字元）
        public let start: Int
        public let end: Int
    }

    public let config: Config
    public let numParams: Int
    let stoi: [String: Int]
    let unk: Int, cls: Int, sep: Int
    let qMax: Int
    let wte, wpe, wse, wme, lnfg, lnfb, wspan, bspan: [Float]
    /// 標點：不算「跟問題一樣的字」
    let punct: Set<String>
    let layers: [Layer]

    public init(weights: Data, metaJSON: Data) throws {
        let meta = try JSONDecoder().decode(Meta.self, from: metaJSON)
        guard meta.format == "reader-f16-v2" else { throw EchoError.badFormat(meta.format) }
        config = meta.config
        numParams = meta.num_params
        var map: [String: Int] = [:]
        for (i, s) in meta.vocab.enumerated() where map[s] == nil { map[s] = i }
        stoi = map
        unk = meta.specials.unk; cls = meta.specials.cls; sep = meta.specials.sep
        qMax = meta.q_max ?? 48
        punct = Set(meta.punct ?? [])
        // float16 → float32
        let floats: [Float] = weights.withUnsafeBytes { raw in
            let n = raw.count / 2
            var out = [Float](repeating: 0, count: n)
            for i in 0..<n { out[i] = Brain.half(UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: i * 2, as: UInt16.self))) }
            return out
        }
        var table: [String: [Float]] = [:]
        for t in meta.tensors {
            let count = t.shape.reduce(1, *)
            guard t.offset + count <= floats.count else { throw EchoError.truncated(t.name) }
            table[t.name] = Array(floats[t.offset..<(t.offset + count)])
        }
        func get(_ k: String) throws -> [Float] {
            guard let v = table[k] else { throw EchoError.missing(k) }
            return v
        }
        wte = try get("wte"); wpe = try get("wpe"); wse = try get("wse"); wme = try get("wme")
        lnfg = try get("lnf_g"); lnfb = try get("lnf_b")
        wspan = try get("w_span"); bspan = try get("b_span")
        var ls: [Layer] = []
        for l in 0..<config.n_layer {
            let p = "h\(l)."
            ls.append(Layer(ln1g: try get(p + "ln1_g"), ln1b: try get(p + "ln1_b"),
                            wqkv: try get(p + "w_qkv"), bqkv: try get(p + "b_qkv"),
                            wo: try get(p + "w_o"), bo: try get(p + "b_o"),
                            ln2g: try get(p + "ln2_g"), ln2b: try get(p + "ln2_b"),
                            wfc: try get(p + "w_fc"), bfc: try get(p + "b_fc"),
                            wproj: try get(p + "w_proj"), bproj: try get(p + "b_proj")))
        }
        layers = ls
    }

    public convenience init(bundle: Bundle, name: String = "reader") throws {
        guard let bin = bundle.url(forResource: name, withExtension: "bin"),
              let json = bundle.url(forResource: name, withExtension: "json") else {
            throw EchoError.missing("\(name).bin / \(name).json")
        }
        try self.init(weights: Data(contentsOf: bin), metaJSON: Data(contentsOf: json))
    }

    /// App 啟動時載入一次，之後上網查資料都用它
    nonisolated(unsafe) public static var shared: Brain?

    static func half(_ h: UInt16) -> Float {
        let sign = UInt32(h >> 15) << 31
        let exp = Int((h >> 10) & 0x1f)
        let frac = UInt32(h & 0x3ff)
        if exp == 0 {
            if frac == 0 { return Float(bitPattern: sign) }
            // 非正規數
            let v = Float(frac) / 1024 * pow(2, -14)
            return sign == 0 ? v : -v
        }
        if exp == 31 { return Float(bitPattern: sign | 0x7f80_0000 | (frac << 13)) }
        return Float(bitPattern: sign | (UInt32(exp - 15 + 127) << 23) | (frac << 13))
    }

    // MARK: - 分詞（逐字、小寫；和 Python 一樣以 Unicode 字元為單位）

    /// 逐字小寫、全形空白換成半形；每個字各自轉，長度不變（和 Python 的 ReaderTokenizer.norm 一樣）
    static func norm(_ s: String) -> [String] {
        s.unicodeScalars.map { u in
            if u == "\u{3000}" { return " " }
            let l = String(u).lowercased()
            return l.unicodeScalars.count == 1 ? l : String(u)
        }
    }

    func ids(_ chars: [String]) -> [Int] { chars.map { stoi[$0] ?? unk } }

    // MARK: - 讀

    /// 讀一段文字，找出最像答案的那幾個字。長文章會切成幾段（有重疊）分別讀，取最有把握的。
    public func read(question: String, passage: String, maxAnswer: Int = 40) -> Span? {
        let qChars = Array(Brain.norm(question).prefix(qMax))
        let q = ids(qChars)
        let scalars = Array(passage.unicodeScalars)
        let pChars = Brain.norm(passage)
        let pc = ids(pChars)
        guard !pc.isEmpty, pc.count == scalars.count else { return nil }
        let L = config.n_ctx - 3 - q.count
        guard L > 8 else { return nil }
        let stride = max(L / 2, 1)
        var best: Span?
        var start = 0
        while true {
            let piece = Array(pc[start..<min(start + L, pc.count)])
            let tokens = [cls] + q + [sep] + piece + [sep]
            let segs = [Int](repeating: 0, count: q.count + 2) + [Int](repeating: 1, count: piece.count + 1)
            let (mq, mp) = matchFeatures(qChars, Array(pChars[start..<min(start + L, pChars.count)]))
            let base = q.count + 2
            let (ls, le) = logits(tokens, segs, [0] + mq + [0] + mp + [0])
            let none = ls[0] + le[0]
            // 開始、結束各挑分數最高的 20 個位置組合（結束不能在開始之前、長度有上限）
            let pos = Array(base..<(base + piece.count))
            let sTop = pos.sorted { ls[$0] > ls[$1] }.prefix(20)
            let eTop = pos.sorted { le[$0] > le[$1] }.prefix(20)
            for s in sTop {
                for e in eTop where s <= e && e < s + maxAnswer {
                    let sc = ls[s] + le[e] - none
                    if best == nil || sc > best!.score {
                        let a = start + s - base, b = start + e - base
                        var text = ""
                        text.unicodeScalars.append(contentsOf: scalars[a...b])
                        best = Span(text: text, score: sc, start: a, end: b)
                    }
                }
            }
            if start + L >= pc.count { break }
            start += stride
        }
        return best
    }

    /// 每個字有沒有出現在另一邊：2＝同一個雙字詞，1＝同一個字，0＝沒有（和 Python 的 match_features 一樣）。
    /// 比的是字本身，不是字表編號，所以字表裡沒有的罕見字（人名、地名）也對得到；標點、空白不算。
    /// 異體字：比對時當成同一個字（問「台北」、維基寫「臺北」）。和 Python 的 VARIANTS 一樣
    static let variants: [String: String] = ["臺": "台", "裏": "裡", "着": "著", "爲": "為", "衆": "眾", "綫": "線", "峯": "峰", "羣": "群",
                                             "册": "冊", "啓": "啟", "牀": "床", "敎": "教", "眞": "真", "鷄": "雞", "麪": "麵",
                                             "衞": "衛", "銹": "鏽", "竪": "豎", "滙": "匯"]

    func matchFeatures(_ q0: [String], _ p0: [String]) -> ([Int], [Int]) {
        let q = q0.map { Brain.variants[$0] ?? $0 }, p = p0.map { Brain.variants[$0] ?? $0 }
        struct Pair: Hashable { let a: String, b: String }
        func grams(_ x: [String]) -> Set<Pair> { x.count < 2 ? [] : Set((0..<(x.count - 1)).map { Pair(a: x[$0], b: x[$0 + 1]) }) }
        let qs = Set(q), ps = Set(p), qg = grams(q), pg = grams(p)
        func feat(_ a: [String], _ set: Set<String>, _ g: Set<Pair>) -> [Int] {
            a.indices.map { i in
                let t = a[i]
                if punct.contains(t) || t.unicodeScalars.allSatisfy({ $0.properties.isWhitespace }) { return 0 }
                if (i > 0 && g.contains(Pair(a: a[i - 1], b: t))) || (i + 1 < a.count && g.contains(Pair(a: t, b: a[i + 1]))) { return 2 }
                return set.contains(t) ? 1 : 0
            }
        }
        return (feat(q, ps, pg), feat(p, qs, qg))
    }

    /// 前向傳播：回傳每個位置「答案從這裡開始／到這裡結束」的分數
    func logits(_ tokens: [Int], _ segs: [Int], _ mat: [Int]) -> (start: [Float], end: [Float]) {
        let T = tokens.count, C = config.n_embd, H = config.n_head, D = C / H
        var x = [Float](repeating: 0, count: T * C)
        for t in 0..<T {
            for c in 0..<C { x[t * C + c] = wte[tokens[t] * C + c] + wpe[t * C + c] + wse[segs[t] * C + c] + wme[mat[t] * C + c] }
        }
        let scale = 1 / Float(D).squareRoot()
        for ly in layers {
            let h = Brain.layerNorm(x, ly.ln1g, ly.ln1b, T, C)
            let qkv = Brain.matmul(h, ly.wqkv, ly.bqkv, T, C, 3 * C)
            var y = [Float](repeating: 0, count: T * C)
            for hd in 0..<H {
                // 取出這個 head 的 q、k、v（T×D）
                var q = [Float](repeating: 0, count: T * D), k = q, v = q
                for t in 0..<T {
                    for d in 0..<D {
                        q[t * D + d] = qkv[t * 3 * C + hd * D + d] * scale
                        k[t * D + d] = qkv[t * 3 * C + C + hd * D + d]
                        v[t * D + d] = qkv[t * 3 * C + 2 * C + hd * D + d]
                    }
                }
                var a = Brain.matmulT(q, k, T, D, T)   // 每個字對每個字的注意力分數
                for i in 0..<T {
                    var m: Float = -.greatestFiniteMagnitude
                    for j in 0..<T { m = max(m, a[i * T + j]) }
                    var sum: Float = 0
                    for j in 0..<T { let e = exp(a[i * T + j] - m); a[i * T + j] = e; sum += e }
                    for j in 0..<T { a[i * T + j] /= sum }
                }
                let yh = Brain.matmul(a, v, [Float](repeating: 0, count: D), T, T, D)
                for t in 0..<T { for d in 0..<D { y[t * C + hd * D + d] = yh[t * D + d] } }
            }
            let o = Brain.matmul(y, ly.wo, ly.bo, T, C, C)
            for i in 0..<(T * C) { x[i] += o[i] }
            let h2 = Brain.layerNorm(x, ly.ln2g, ly.ln2b, T, C)
            var f = Brain.matmul(h2, ly.wfc, ly.bfc, T, C, 4 * C)
            for i in 0..<f.count where f[i] < 0 { f[i] = 0 }
            let pr = Brain.matmul(f, ly.wproj, ly.bproj, T, 4 * C, C)
            for i in 0..<(T * C) { x[i] += pr[i] }
        }
        let xf = Brain.layerNorm(x, lnfg, lnfb, T, C)
        let lg = Brain.matmul(xf, wspan, bspan, T, C, 2)
        return ((0..<T).map { lg[$0 * 2] }, (0..<T).map { lg[$0 * 2 + 1] })
    }

    static func layerNorm(_ x: [Float], _ g: [Float], _ b: [Float], _ T: Int, _ C: Int) -> [Float] {
        var out = [Float](repeating: 0, count: T * C)
        for t in 0..<T {
            var mu: Float = 0
            for c in 0..<C { mu += x[t * C + c] }
            mu /= Float(C)
            var v: Float = 0
            for c in 0..<C { let d = x[t * C + c] - mu; v += d * d }
            let r = 1 / (v / Float(C) + 1e-5).squareRoot()
            for c in 0..<C { out[t * C + c] = (x[t * C + c] - mu) * r * g[c] + b[c] }
        }
        return out
    }

    /// A(M×K)·B(N×K)ᵀ
    static func matmulT(_ a: [Float], _ b: [Float], _ M: Int, _ K: Int, _ N: Int) -> [Float] {
        var out = [Float](repeating: 0, count: M * N)
        #if canImport(Accelerate)
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasTrans, Int32(M), Int32(N), Int32(K), 1, a, Int32(K), b, Int32(K), 0, &out, Int32(N))
        #else
        a.withUnsafeBufferPointer { A in
            b.withUnsafeBufferPointer { B in
                out.withUnsafeMutableBufferPointer { O in
                    for i in 0..<M {
                        for j in 0..<N {
                            var s: Float = 0
                            for d in 0..<K { s += A[i * K + d] * B[j * K + d] }
                            O[i * N + j] = s
                        }
                    }
                }
            }
        }
        #endif
        return out
    }

    /// (T×K)·(K×N) + b
    static func matmul(_ a: [Float], _ w: [Float], _ b: [Float], _ T: Int, _ K: Int, _ N: Int) -> [Float] {
        var out = [Float](repeating: 0, count: T * N)
        for t in 0..<T { for n in 0..<N { out[t * N + n] = b[n] } }
        #if canImport(Accelerate)
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, Int32(T), Int32(N), Int32(K), 1, a, Int32(K), w, Int32(N), 1, &out, Int32(N))
        #else
        a.withUnsafeBufferPointer { A in
            w.withUnsafeBufferPointer { W in
                out.withUnsafeMutableBufferPointer { O in
                    for t in 0..<T {
                        for k in 0..<K {
                            let av = A[t * K + k]
                            if av == 0 { continue }
                            let wr = k * N, orow = t * N
                            for n in 0..<N { O[orow + n] += av * W[wr + n] }
                        }
                    }
                }
            }
        }
        #endif
        return out
    }
}
