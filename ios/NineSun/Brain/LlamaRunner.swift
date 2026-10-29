import Foundation
import llama

/// 在手機上跑大型語言模型（llama.cpp，模型檔是 GGUF）。
/// 不能同時從兩個地方呼叫：LocalBrain 只在自己的序列佇列上用它。
final class LlamaRunner {
    enum Failure: Error, CustomStringConvertible {
        case load(String), context, tokenize, decode(Int32)
        var description: String {
            switch self {
            case .load(let p): return "模型讀不進來（\(p)）"
            case .context: return "記憶體不夠，建立不了模型的工作區"
            case .tokenize: return "這段文字切不成模型看得懂的字"
            case .decode(let c): return "模型運算失敗（\(c)）"
            }
        }
    }

    struct Result {
        var text: String
        var promptTokens: Int
        var tokens: Int
        var seconds: Double
        /// 沒寫完就停了（被叫停、或運算失敗——例如切到背景，系統不讓用 GPU）：text 是停之前寫好的
        var interrupted = false
        var tokensPerSecond: Double { seconds > 0 ? Double(tokens) / seconds : 0 }
    }

    private let model: OpaquePointer
    private let ctx: OpaquePointer
    private let vocab: OpaquePointer
    let contextSize: Int
    private let batchSize: Int
    /// 工作區（KV 快取）裡現在放的字：下一次開頭一樣的部分（系統指示、前面的對話）就不用再算一次
    private var cached: [llama_token] = []

    private static let backendOnce: Void = {
        llama_backend_init()
        // llama.cpp 的訊息很多，只留錯誤
        llama_log_set({ level, text, _ in
            if level == GGML_LOG_LEVEL_ERROR, let text { fputs(String(cString: text), stderr) }
        }, nil)
    }()

    /// gpu：用 Metal（手機的 GPU）；模擬器和沒有 GPU 的電腦要關掉
    init(path: String, contextSize: Int = 4096, batchSize: Int = 512, gpu: Bool = true, threads: Int? = nil) throws {
        _ = Self.backendOnce
        var mp = llama_model_default_params()
        mp.n_gpu_layers = gpu ? 999 : 0
        guard let m = llama_model_load_from_file(path, mp) else { throw Failure.load((path as NSString).lastPathComponent) }
        var cp = llama_context_default_params()
        let n = threads ?? max(1, min(6, ProcessInfo.processInfo.activeProcessorCount - 2))
        cp.n_ctx = UInt32(contextSize)
        cp.n_batch = UInt32(batchSize)
        cp.n_ubatch = UInt32(batchSize)
        cp.n_threads = Int32(n)
        cp.n_threads_batch = Int32(n)
        guard let c = llama_init_from_model(m, cp) else { llama_model_free(m); throw Failure.context }
        guard let v = llama_model_get_vocab(m) else { llama_free(c); llama_model_free(m); throw Failure.load("vocab") }
        model = m; ctx = c; vocab = v
        self.contextSize = Int(llama_n_ctx(c))
        self.batchSize = Int(cp.n_batch)
    }

    deinit {
        llama_free(ctx)
        llama_model_free(model)
    }

    /// 照這個模型自己的對話格式把對話排好（Qwen 是 ChatML、Gemma 是 <start_of_turn>、Llama 3 是 <|start_header_id|>…）。
    /// llama.cpp 認不得的格式就用 ChatML。Qwen 這種會先想很久的模型，最後先放一段空的思考，讓它直接回答
    func chatPrompt(_ messages: [(role: String, content: String)]) -> String {
        let tmpl = llama_model_chat_template(model, nil).map { String(cString: $0) }
        // Gemma 4（<|turn>user … <turn|>）llama.cpp 還不會排，自己排
        if (tmpl ?? "").contains("<|turn>") {
            return messages.map { "<|turn>\($0.role == "assistant" ? "model" : $0.role)\n\($0.content)<turn|>\n" }.joined() + "<|turn>model\n"
        }
        let cRoles = messages.map { strdup($0.role) }
        let cContents = messages.map { strdup($0.content) }
        defer { cRoles.forEach { free($0) }; cContents.forEach { free($0) } }
        var chat = (0..<messages.count).map { llama_chat_message(role: cRoles[$0], content: cContents[$0]) }
        var buf = [CChar](repeating: 0, count: messages.reduce(0) { $0 + $1.content.utf8.count } * 2 + 512)
        var n = llama_chat_apply_template(tmpl, &chat, chat.count, true, &buf, Int32(buf.count))
        if n > Int32(buf.count) {
            buf = [CChar](repeating: 0, count: Int(n) + 1)
            n = llama_chat_apply_template(tmpl, &chat, chat.count, true, &buf, Int32(buf.count))
        }
        var out: String
        if n > 0 {
            out = String(decoding: buf.prefix(Int(n)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        } else {
            out = messages.map { "<|im_start|>\($0.role)\n\($0.content)<|im_end|>\n" }.joined() + "<|im_start|>assistant\n"
        }
        if (tmpl ?? "").contains("<think>") && out.hasSuffix("<|im_start|>assistant\n") { out += "<think>\n\n</think>\n\n" }
        return out
    }

    /// 文字 → 模型的字（special：<|im_start|> 這種控制字要認出來；開頭記號 BOS 照模型的規定加，Gemma、Llama 要、Qwen 不要）
    func tokenize(_ text: String, special: Bool = true) throws -> [llama_token] {
        let bytes = Int32(text.utf8.count)
        var cap = Int(bytes) + 8
        while true {
            var out = [llama_token](repeating: 0, count: cap)
            let n = llama_tokenize(vocab, text, bytes, &out, Int32(cap), true, special)
            if n >= 0 { return Array(out.prefix(Int(n))) }
            guard -Int(n) > cap else { throw Failure.tokenize }
            cap = -Int(n)
        }
    }

    private func piece(_ t: llama_token) -> [UInt8] {
        var buf = [CChar](repeating: 0, count: 64)
        var n = llama_token_to_piece(vocab, t, &buf, Int32(buf.count), 0, false)
        if n < 0 {
            buf = [CChar](repeating: 0, count: Int(-n))
            n = llama_token_to_piece(vocab, t, &buf, Int32(buf.count), 0, false)
        }
        return buf.prefix(Int(max(0, n))).map { UInt8(bitPattern: $0) }
    }

    /// 接著 prompt 往下寫。onText 每多出完整的幾個字就回呼一次（中文一個字可能拆成好幾個 token，湊完整才給）；
    /// stop 裡的任何一個出現就停；shouldStop 回傳 true 就中斷（使用者取消、記憶體警告）。
    func generate(prompt: String, maxTokens: Int = 700, temperature: Float = 0.7, topP: Float = 0.8, topK: Int32 = 20,
                  repeatPenalty: Float = 1.05, stop: [String] = [], seed: UInt32 = 0,
                  shouldStop: () -> Bool = { false }, onText: (String) -> Void = { _ in }) throws -> Result {
        let started = Date()
        var tokens = try tokenize(prompt)
        // 太長：留下開頭（系統指示）和最後面（問題），中間的資料截掉
        let room = contextSize - maxTokens - 8
        if tokens.count > room, room > 256 {
            let head = room / 3
            tokens = Array(tokens.prefix(head)) + Array(tokens.suffix(room - head))
        }
        let promptTokens = tokens.count
        // 跟上一次開頭一樣的字留在工作區裡，只算後面新的（至少算最後一個字，才有下一個字的機率）
        let mem = llama_get_memory(ctx)
        var keep = 0
        while keep < min(cached.count, tokens.count - 1) && cached[keep] == tokens[keep] { keep += 1 }
        if keep == 0 || !llama_memory_seq_rm(mem, 0, llama_pos(keep), -1) {
            llama_memory_clear(mem, true)
            keep = 0
        }
        cached = []
        var i = keep
        while i < tokens.count {
            let n = min(batchSize, tokens.count - i)
            let rc = tokens.withUnsafeMutableBufferPointer { b in llama_decode(ctx, llama_batch_get_one(b.baseAddress! + i, Int32(n))) }
            if rc != 0 { cached = []; llama_memory_clear(mem, true); throw Failure.decode(rc) }
            i += n
        }
        cached = tokens

        let sp = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(sp) else { throw Failure.context }
        defer { llama_sampler_free(chain) }
        llama_sampler_chain_add(chain, llama_sampler_init_penalties(llama_vocab_n_tokens(vocab), 64, repeatPenalty, 0, 0))
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(topK))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(topP, 1))
        if temperature <= 0 {
            llama_sampler_chain_add(chain, llama_sampler_init_greedy())
        } else {
            llama_sampler_chain_add(chain, llama_sampler_init_temp(temperature))
            llama_sampler_chain_add(chain, llama_sampler_init_dist(seed == 0 ? UInt32.random(in: 1...UInt32.max) : seed))
        }

        var bytes: [UInt8] = []
        var text = ""
        var produced = 0
        var interrupted = false
        while produced < maxTokens {
            if shouldStop() { interrupted = true; break }
            var t = llama_sampler_sample(chain, ctx, -1)
            if llama_vocab_is_eog(vocab, t) { break }
            produced += 1
            bytes += piece(t)
            // 只把完整的 UTF-8 字交出去
            if let s = String(bytes: bytes, encoding: .utf8) {
                text += s
                bytes.removeAll()
                if let hit = stop.compactMap({ text.range(of: $0) }).min(by: { $0.lowerBound < $1.lowerBound }) {
                    text = String(text[..<hit.lowerBound])
                    onText(text)
                    break
                }
                onText(text)
            }
            if tokens.count + produced >= contextSize - 1 { break }
            let rc = llama_decode(ctx, llama_batch_get_one(&t, 1))
            if rc != 0 { cached = []; llama_memory_clear(llama_get_memory(ctx), true); interrupted = true; break }
            cached.append(t)
        }
        return Result(text: text, promptTokens: promptTokens, tokens: produced, seconds: Date().timeIntervalSince(started), interrupted: interrupted)
    }
}
