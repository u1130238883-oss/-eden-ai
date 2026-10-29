import Foundation

/// 大腦的模型檔：第一次用的時候下載到手機裡（App 本身不放，不然 IPA 會好幾 GB），之後完全離線。
/// 用背景下載：切到別的 App、鎖螢幕也會繼續；斷線可以接著下載；下載完檢查是不是真的模型檔（GGUF）。
final class ModelStore: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = ModelStore()

    struct Model: Identifiable, Equatable {
        let id: String
        let name: String
        let detail: String
        let file: String
        /// 大約的大小（顯示用；實際以下載時伺服器說的為準）
        let bytes: Int64
        /// 下載網址（第一個不行就換下一個）
        let urls: [String]
    }

    /// 全部都是開放（拿掉拒絕／無審查）的模型。有限制的標準版已經拿掉
    static let models: [Model] = [
        Model(id: "qwen35-4b-open", name: "開放版 Qwen3.5 4B（預設）", detail: "拿掉拒絕的版本，中文最好、最聰明；iPhone 15 Pro 以上",
              file: "Huihui-Qwen3.5-4B-abliterated.Q4_K_M.gguf", bytes: 2_707_514_688,
              urls: ["https://huggingface.co/mradermacher/Huihui-Qwen3.5-4B-abliterated-GGUF/resolve/main/Huihui-Qwen3.5-4B-abliterated.Q4_K_M.gguf",
                     "https://hf-mirror.com/mradermacher/Huihui-Qwen3.5-4B-abliterated-GGUF/resolve/main/Huihui-Qwen3.5-4B-abliterated.Q4_K_M.gguf",
                     "https://huggingface.co/mradermacher/Huihui-Qwen3.5-4B-abliterated-i1-GGUF/resolve/main/Huihui-Qwen3.5-4B-abliterated.i1-Q4_K_M.gguf"]),
        Model(id: "gemma4-e2b-open", name: "開放版 Gemma 4 E2B", detail: "Google 最新的小模型拿掉拒絕的版本，聊天自然、多國語言好",
              file: "Huihui-gemma-4-E2B-it-abliterated.Q4_K_M.gguf", bytes: 3_427_874_272,
              urls: ["https://huggingface.co/mradermacher/Huihui-gemma-4-E2B-it-abliterated-GGUF/resolve/main/Huihui-gemma-4-E2B-it-abliterated.Q4_K_M.gguf",
                     "https://hf-mirror.com/mradermacher/Huihui-gemma-4-E2B-it-abliterated-GGUF/resolve/main/Huihui-gemma-4-E2B-it-abliterated.Q4_K_M.gguf"]),
        Model(id: "gemma3-4b-open", name: "開放版 Gemma 3 4B", detail: "角色扮演、寫故事很有畫面感",
              file: "gemma-3-4b-it-abliterated.q4_k_m.gguf", bytes: 2_489_894_016,
              urls: ["https://huggingface.co/mlabonne/gemma-3-4b-it-abliterated-GGUF/resolve/main/gemma-3-4b-it-abliterated.q4_k_m.gguf",
                     "https://hf-mirror.com/mlabonne/gemma-3-4b-it-abliterated-GGUF/resolve/main/gemma-3-4b-it-abliterated.q4_k_m.gguf"]),
        Model(id: "dolphin3-3b", name: "Dolphin 3.0（Llama 3.2 3B）", detail: "有名的無審查模型，什麼都照你說的做；英文最好",
              file: "Dolphin3.0-Llama3.2-3B-Q4_K_M.gguf", bytes: 2_019_382_400,
              urls: ["https://huggingface.co/bartowski/Dolphin3.0-Llama3.2-3B-GGUF/resolve/main/Dolphin3.0-Llama3.2-3B-Q4_K_M.gguf",
                     "https://hf-mirror.com/bartowski/Dolphin3.0-Llama3.2-3B-GGUF/resolve/main/Dolphin3.0-Llama3.2-3B-Q4_K_M.gguf",
                     "https://huggingface.co/mradermacher/Dolphin3.0-Llama3.2-3B-GGUF/resolve/main/Dolphin3.0-Llama3.2-3B.Q4_K_M.gguf"]),
        Model(id: "llama32-3b-uncensored", name: "無審查 Llama 3.2 3B", detail: "重新訓練過的無審查版，大膽直接；英文最好",
              file: "Llama-3.2-3B-Instruct-uncensored.Q4_K_M.gguf", bytes: 2_241_004_096,
              urls: ["https://huggingface.co/mradermacher/Llama-3.2-3B-Instruct-uncensored-GGUF/resolve/main/Llama-3.2-3B-Instruct-uncensored.Q4_K_M.gguf",
                     "https://hf-mirror.com/mradermacher/Llama-3.2-3B-Instruct-uncensored-GGUF/resolve/main/Llama-3.2-3B-Instruct-uncensored.Q4_K_M.gguf"]),
        Model(id: "phi4-mini-open", name: "開放版 Phi-4 mini", detail: "微軟的小模型拿掉拒絕的版本，推理、數學比較強",
              file: "Phi-4-mini-instruct-abliterated.Q4_K_M.gguf", bytes: 2_491_875_424,
              urls: ["https://huggingface.co/mradermacher/Phi-4-mini-instruct-abliterated-GGUF/resolve/main/Phi-4-mini-instruct-abliterated.Q4_K_M.gguf",
                     "https://hf-mirror.com/mradermacher/Phi-4-mini-instruct-abliterated-GGUF/resolve/main/Phi-4-mini-instruct-abliterated.Q4_K_M.gguf"]),
        Model(id: "smollm3-3b-open", name: "開放版 SmolLM3 3B", detail: "小又快，舊一點的手機也跑得動；英文、歐洲語言好",
              file: "Huihui-SmolLM3-3B-abliterated.Q4_K_M.gguf", bytes: 1_915_306_368,
              urls: ["https://huggingface.co/mradermacher/Huihui-SmolLM3-3B-abliterated-GGUF/resolve/main/Huihui-SmolLM3-3B-abliterated.Q4_K_M.gguf",
                     "https://hf-mirror.com/mradermacher/Huihui-SmolLM3-3B-abliterated-GGUF/resolve/main/Huihui-SmolLM3-3B-abliterated.Q4_K_M.gguf"]),
        Model(id: "qwen35-2b-open", name: "開放版 Qwen3.5 2B（輕量）", detail: "最小最快最省電，比較笨；舊手機用這個",
              file: "Huihui-Qwen3.5-2B-abliterated.Q4_K_M.gguf", bytes: 1_270_809_024,
              urls: ["https://huggingface.co/mradermacher/Huihui-Qwen3.5-2B-abliterated-GGUF/resolve/main/Huihui-Qwen3.5-2B-abliterated.Q4_K_M.gguf",
                     "https://hf-mirror.com/mradermacher/Huihui-Qwen3.5-2B-abliterated-GGUF/resolve/main/Huihui-Qwen3.5-2B-abliterated.Q4_K_M.gguf"]),
        Model(id: "gemma4-e4b-rp", name: "（實驗）Gemma 4 E4B 角色扮演版", detail: "專門調過角色扮演、最大膽，但檔案 5.3 GB，要 12 GB 記憶體的手機（iPhone 17 Pro）",
              file: "gemma-4-E4B-it-SDFT_Heretic_RP.Q4_K_M.gguf", bytes: 5_335_286_208,
              urls: ["https://huggingface.co/mradermacher/gemma-4-E4B-it-SDFT_Heretic_RP-GGUF/resolve/main/gemma-4-E4B-it-SDFT_Heretic_RP.Q4_K_M.gguf",
                     "https://hf-mirror.com/mradermacher/gemma-4-E4B-it-SDFT_Heretic_RP-GGUF/resolve/main/gemma-4-E4B-it-SDFT_Heretic_RP.Q4_K_M.gguf"]),
    ]

    enum State: Equatable {
        case absent
        case downloading(done: Int64, total: Int64)
        case ready
        case failed(String)
    }

    @Published private(set) var states: [String: State] = [:]
    /// 要用哪一個
    @Published var selectedID: String = UserDefaults.standard.string(forKey: "ninesun.brainModel") ?? ModelStore.models[0].id {
        didSet { UserDefaults.standard.set(selectedID, forKey: "ninesun.brainModel") }
    }
    /// 系統在背景下載完時給的「做完了要叫我」
    var backgroundCompletion: (() -> Void)?

    private var session: URLSession!
    private var mirror: [String: Int] = [:]
    private var resumeData: [String: Data] = [:]

    static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NineSunBrain")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        var u = base
        var v = URLResourceValues(); v.isExcludedFromBackup = true
        try? u.setResourceValues(v)
        return base
    }()

    override private init() {
        super.init()
        let cfg = URLSessionConfiguration.background(withIdentifier: "com.ninesun.app.brain-download")
        cfg.isDiscretionary = false
        cfg.sessionSendsLaunchEvents = true
        cfg.allowsCellularAccess = true
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
        for m in Self.models { states[m.id] = isReady(m) ? .ready : .absent }
        // 拿掉的舊模型（有限制的標準版、輕量版）還留在手機裡：刪掉，空出空間
        let keep = Set(Self.models.map(\.file))
        for f in (try? FileManager.default.contentsOfDirectory(atPath: Self.dir.path)) ?? [] where f.hasSuffix(".gguf") && !keep.contains(f) {
            try? FileManager.default.removeItem(at: Self.dir.appendingPathComponent(f))
        }
        // 上次還沒下載完的（App 被關掉又打開）接回來
        session.getAllTasks { tasks in
            for t in tasks { if let id = t.taskDescription { DispatchQueue.main.async { self.states[id] = .downloading(done: t.countOfBytesReceived, total: t.countOfBytesExpectedToReceive) } } }
        }
    }

    func path(_ m: Model) -> URL { Self.dir.appendingPathComponent(m.file) }

    /// 檔案在、大小合理、開頭是 GGUF
    func isReady(_ m: Model) -> Bool {
        let p = path(m)
        guard let a = try? FileManager.default.attributesOfItem(atPath: p.path), let size = a[.size] as? Int64, size > 100_000_000,
              let h = FileHandle(forReadingAtPath: p.path) else { return false }
        defer { try? h.close() }
        return h.readData(ofLength: 4) == Data("GGUF".utf8)
    }

    var selected: Model { Self.models.first { $0.id == selectedID } ?? Self.models[0] }

    /// 要用的模型：選的那個下載好了就用它，不然用任何一個下載好的
    var readyModel: Model? {
        if states[selected.id] == .ready { return selected }
        return Self.models.first { states[$0.id] == .ready }
    }

    /// 手機剩下的空間夠不夠（多留 500 MB）
    func hasRoom(_ m: Model) -> Bool {
        let v = try? Self.dir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let free = v?.volumeAvailableCapacityForImportantUsage else { return true }
        return free > m.bytes + 500_000_000
    }

    func download(_ m: Model) {
        guard !isReady(m) else { states[m.id] = .ready; return }
        guard hasRoom(m) else {
            states[m.id] = .failed("手機空間不夠：需要大約 \(Self.gb(m.bytes + 500_000_000)) 的空間")
            return
        }
        let task: URLSessionDownloadTask
        if let data = resumeData.removeValue(forKey: m.id) {
            task = session.downloadTask(withResumeData: data)
        } else {
            let i = min(mirror[m.id] ?? 0, m.urls.count - 1)
            task = session.downloadTask(with: URL(string: m.urls[i])!)
        }
        task.taskDescription = m.id
        states[m.id] = .downloading(done: 0, total: m.bytes)
        task.resume()
    }

    func cancel(_ m: Model) {
        session.getAllTasks { tasks in
            for t in tasks where t.taskDescription == m.id { t.cancel() }
            DispatchQueue.main.async { self.states[m.id] = .absent; self.resumeData[m.id] = nil }
        }
    }

    func delete(_ m: Model) {
        LocalBrain.shared.unload()
        try? FileManager.default.removeItem(at: path(m))
        states[m.id] = .absent
    }

    static func gb(_ b: Int64) -> String { String(format: "%.1f GB", Double(b) / 1_000_000_000) }

    // MARK: - 下載的回呼（在背景執行緒）

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription else { return }
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : (Self.models.first { $0.id == id }?.bytes ?? 0)
        DispatchQueue.main.async { self.states[id] = .downloading(done: totalBytesWritten, total: total) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription, let m = Self.models.first(where: { $0.id == id }) else { return }
        // 伺服器回錯誤頁（404、被擋）也會「下載完成」：先看狀態碼
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            DispatchQueue.main.async { self.states[id] = .failed("下載網址回應 \(http.statusCode)") }
            return
        }
        // 暫存檔函式結束就會被刪掉，一定要在這裡搬走
        let dst = path(m)
        try? FileManager.default.removeItem(at: dst)
        do {
            try FileManager.default.moveItem(at: location, to: dst)
        } catch {
            DispatchQueue.main.async { self.states[id] = .failed("存不進手機：\(error.localizedDescription)") }
            return
        }
        let ok = isReady(m)
        if !ok { try? FileManager.default.removeItem(at: dst) }
        DispatchQueue.main.async { self.states[id] = ok ? .ready : .failed("下載的檔案不完整，請再下載一次") }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription, let m = Self.models.first(where: { $0.id == id }) else { return }
        if let http = task.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            // 這個網址不行：換下一個網址
            let next = (mirror[id] ?? 0) + 1
            DispatchQueue.main.async {
                if next < m.urls.count { self.mirror[id] = next; self.download(m) }
                else { self.states[id] = .failed("下載網址都連不上（\(http.statusCode)）") }
            }
            return
        }
        guard let error else { return }
        let ns = error as NSError
        if ns.code == NSURLErrorCancelled, ns.userInfo[NSURLSessionDownloadTaskResumeData] == nil { return }
        let data = ns.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        DispatchQueue.main.async {
            if let data { self.resumeData[id] = data }
            self.states[id] = .failed(data != nil ? "下載中斷了（\(error.localizedDescription)），按「繼續下載」接著下載" : "下載失敗：\(error.localizedDescription)")
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async { self.backgroundCompletion?(); self.backgroundCompletion = nil }
    }
}
