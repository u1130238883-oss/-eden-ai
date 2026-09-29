import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// ECHO-0 的 Transformer 推理引擎（純 Swift，無任何 ML 框架）。
/// 數學與 ai/echo_model.py 完全一致：Pre-LN GPT、ReLU 前饋、權重共享輸出層。
public final class EchoModel {
    public struct Config: Codable {
        public let vocab_size: Int
        public let n_ctx: Int
        public let n_embd: Int
        public let n_head: Int
        public let n_layer: Int
    }

    struct Meta: Codable {
        struct Tensor: Codable { let name: String; let shape: [Int]; let offset: Int }
        struct Specials: Codable { let pad, unk, user, assistant, eos, fact: Int }
        let format: String
        let config: Config
        let vocab: [String]
        let specials: Specials
        let tensors: [Tensor]
        let num_params: Int
    }

    struct Layer {
        var ln1g, ln1b, wqkv, bqkv, wo, bo, ln2g, ln2b, wfc, bfc, wproj, bproj: [Float]
    }

    public let config: Config
    public let tokenizer: CharTokenizer
    public let numParams: Int
    let wte: [Float]
    let wpe: [Float]
    let layers: [Layer]
    let lnfg: [Float]
    let lnfb: [Float]

    public init(weights: Data, metaJSON: Data) throws {
        let meta = try JSONDecoder().decode(Meta.self, from: metaJSON)
        guard meta.format == "echo0-f32-v1" else { throw EchoError.badFormat(meta.format) }
        config = meta.config
        numParams = meta.num_params
        tokenizer = CharTokenizer(vocab: meta.vocab, unk: meta.specials.unk,
                                  user: meta.specials.user, assistant: meta.specials.assistant,
                                  eos: meta.specials.eos, fact: meta.specials.fact)

        let floats: [Float] = weights.withUnsafeBytes { raw in
            let n = raw.count / 4
            var out = [Float](repeating: 0, count: n)
            for i in 0..<n {
                out[i] = Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self)))
            }
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
        wte = try get("wte")
        wpe = try get("wpe")
        lnfg = try get("lnf_g")
        lnfb = try get("lnf_b")
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

    public convenience init(bundle: Bundle, name: String = "ninesun") throws {
        guard let bin = bundle.url(forResource: name, withExtension: "bin"),
              let json = bundle.url(forResource: name, withExtension: "json") else {
            throw EchoError.missing("\(name).bin / \(name).json")
        }
        try self.init(weights: Data(contentsOf: bin), metaJSON: Data(contentsOf: json))
    }

    // MARK: - 推理狀態（KV cache）

    public final class State {
        var keys: [[Float]]
        var values: [[Float]]
        public private(set) var length = 0
        let capacity: Int

        init(layers: Int, capacity: Int, width: Int) {
            self.capacity = capacity
            keys = Array(repeating: [Float](repeating: 0, count: capacity * width), count: layers)
            values = keys
        }

        func advance() { length += 1 }
    }

    public func makeState() -> State {
        State(layers: config.n_layer, capacity: config.n_ctx, width: config.n_embd)
    }

    /// 輸入一個 token，更新 KV cache，回傳下一個 token 的 logits。
    public func step(token: Int, state: State) -> [Float] {
        precondition(state.length < config.n_ctx, "context full")
        let C = config.n_embd, H = config.n_head, D = C / H
        let pos = state.length
        let scale = 1.0 / Float(D).squareRoot()

        var x = [Float](repeating: 0, count: C)
        for i in 0..<C { x[i] = wte[token * C + i] + wpe[pos * C + i] }

        for (l, L) in layers.enumerated() {
            let h = layerNorm(x, L.ln1g, L.ln1b)
            let qkv = matVec(h, L.wqkv, L.bqkv, rows: C, cols: 3 * C)
            // 寫入 KV cache
            for i in 0..<C {
                state.keys[l][pos * C + i] = qkv[C + i]
                state.values[l][pos * C + i] = qkv[2 * C + i]
            }
            var y = [Float](repeating: 0, count: C)
            let T = pos + 1
            var att = [Float](repeating: 0, count: T)
            for hd in 0..<H {
                let off = hd * D
                var mx = -Float.greatestFiniteMagnitude
                for t in 0..<T {
                    var s: Float = 0
                    let kb = t * C + off
                    for d in 0..<D { s += qkv[off + d] * state.keys[l][kb + d] }
                    s *= scale
                    att[t] = s
                    if s > mx { mx = s }
                }
                var sum: Float = 0
                for t in 0..<T { att[t] = expf(att[t] - mx); sum += att[t] }
                for t in 0..<T {
                    let w = att[t] / sum
                    let vb = t * C + off
                    for d in 0..<D { y[off + d] += w * state.values[l][vb + d] }
                }
            }
            let o = matVec(y, L.wo, L.bo, rows: C, cols: C)
            for i in 0..<C { x[i] += o[i] }

            let h2 = layerNorm(x, L.ln2g, L.ln2b)
            var f = matVec(h2, L.wfc, L.bfc, rows: C, cols: 4 * C)
            for i in 0..<f.count where f[i] < 0 { f[i] = 0 }
            let m = matVec(f, L.wproj, L.bproj, rows: 4 * C, cols: C)
            for i in 0..<C { x[i] += m[i] }
        }
        state.advance()

        let xf = layerNorm(x, lnfg, lnfb)
        let V = config.vocab_size
        var logits = [Float](repeating: 0, count: V)
        #if canImport(Accelerate)
        cblas_sgemv(CblasRowMajor, CblasNoTrans, Int32(V), Int32(C), 1, wte, Int32(C), xf, 1, 0, &logits, 1)
        return logits
        #else
        xf.withUnsafeBufferPointer { xp in
            wte.withUnsafeBufferPointer { wp in
                for v in 0..<V {
                    var s: Float = 0
                    let base = v * C
                    for i in 0..<C { s += xp[i] * wp[base + i] }
                    logits[v] = s
                }
            }
        }
        return logits
        #endif
    }

    // MARK: - 基本算子

    func layerNorm(_ x: [Float], _ g: [Float], _ b: [Float]) -> [Float] {
        let n = Float(x.count)
        var mu: Float = 0
        for v in x { mu += v }
        mu /= n
        var varSum: Float = 0
        for v in x { varSum += (v - mu) * (v - mu) }
        let rstd = 1 / (varSum / n + 1e-5).squareRoot()
        var out = [Float](repeating: 0, count: x.count)
        for i in 0..<x.count { out[i] = (x[i] - mu) * rstd * g[i] + b[i] }
        return out
    }

    /// out[j] = sum_i x[i] * W[i, j] + b[j]，W 為 row-major (rows × cols)
    func matVec(_ x: [Float], _ W: [Float], _ b: [Float], rows: Int, cols: Int) -> [Float] {
        var out = b
        #if canImport(Accelerate)
        cblas_sgemv(CblasRowMajor, CblasTrans, Int32(rows), Int32(cols), 1, W, Int32(cols), x, 1, 1, &out, 1)
        return out
        #else
        out.withUnsafeMutableBufferPointer { op in
            W.withUnsafeBufferPointer { wp in
                for i in 0..<rows {
                    let xi = x[i]
                    if xi == 0 { continue }
                    let base = i * cols
                    for j in 0..<cols { op[j] += xi * wp[base + j] }
                }
            }
        }
        return out
        #endif
    }
}

public enum EchoError: Error {
    case badFormat(String)
    case missing(String)
    case truncated(String)
}
