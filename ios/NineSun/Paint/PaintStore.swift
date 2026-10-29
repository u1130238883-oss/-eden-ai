import Foundation
import ZIPFoundation

/// 畫圖用的模型（Stable Diffusion 的 Core ML 版）：第一次用時下載 zip、解開到手機裡，之後完全離線。
/// 跟大腦的模型一樣用背景下載，切到別的 App 也會繼續。
final class PaintStore: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = PaintStore()
    static let sessionID = "com.ninesun.app.paint-download"

    struct Model: Identifiable, Equatable {
        let id: String
        let name: String
        /// zip 的大小（解開後差不多一樣大）
        let bytes: Int64
        /// 下載網址（第一個不行就換下一個）
        let urls: [String]
    }

    /// 都是 split-einsum（給 iPhone 的神經網路引擎用的）版本，畫面 512×512
    static let models: [Model] = [
        Model(id: "realistic-vision-51", name: "寫實 Realistic Vision 5.1", bytes: 916_522_756,
              urls: ["https://huggingface.co/darkmaniac7/TokForge-RealisticVision-5.1-CoreML-6bit/resolve/main/RealisticVision-5.1_palettized_split_einsum_v2_compiled.zip",
                     "https://huggingface.co/mahmudplx/coreml-realisticvision-5.1-6bit/resolve/main/RealisticVision-5.1_palettized_split_einsum_v2_compiled.zip",
                     "https://hf-mirror.com/darkmaniac7/TokForge-RealisticVision-5.1-CoreML-6bit/resolve/main/RealisticVision-5.1_palettized_split_einsum_v2_compiled.zip"]),
        Model(id: "aom3", name: "動漫 AbyssOrangeMix 3", bytes: 1_973_747_442,
              urls: ["https://huggingface.co/coreml-community/coreml-OrangeMixs/resolve/main/split-einsum/AOM3_split-einsum.zip",
                     "https://hf-mirror.com/coreml-community/coreml-OrangeMixs/resolve/main/split-einsum/AOM3_split-einsum.zip"]),
        Model(id: "counterfeit-3", name: "動漫 Counterfeit 3", bytes: 1_971_792_746,
              urls: ["https://huggingface.co/coreml-community/coreml-Counterfeit/resolve/main/split-einsum/Counterfeit-V3.0_split-einsum.zip",
                     "https://hf-mirror.com/coreml-community/coreml-Counterfeit/resolve/main/split-einsum/Counterfeit-V3.0_split-einsum.zip"]),
    ]

    enum State: Equatable {
        case absent
        case downloading(done: Int64, total: Int64)
        case unzipping
        case ready
        case failed(String)
    }

    @Published private(set) var states: [String: State] = [:]
    @Published var selectedID: String = UserDefaults.standard.string(forKey: "ninesun.paintModel") ?? PaintStore.models[0].id {
        didSet { UserDefaults.standard.set(selectedID, forKey: "ninesun.paintModel") }
    }
    var backgroundCompletion: (() -> Void)?

    private var session: URLSession!
    private var mirror: [String: Int] = [:]
    private var resumeData: [String: Data] = [:]

    static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NineSunPaint")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        var u = base
        var v = URLResourceValues(); v.isExcludedFromBackup = true
        try? u.setResourceValues(v)
        return base
    }()

    override private init() {
        super.init()
        let cfg = URLSessionConfiguration.background(withIdentifier: Self.sessionID)
        cfg.isDiscretionary = false
        cfg.sessionSendsLaunchEvents = true
        cfg.allowsCellularAccess = true
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
        for m in Self.models { states[m.id] = resources(m) != nil ? .ready : .absent }
        session.getAllTasks { tasks in
            for t in tasks { if let id = t.taskDescription { DispatchQueue.main.async { self.states[id] = .downloading(done: t.countOfBytesReceived, total: t.countOfBytesExpectedToReceive) } } }
        }
    }

    private func folder(_ m: Model) -> URL { Self.dir.appendingPathComponent(m.id) }

    /// 解開的模型資料夾（裡面有 TextEncoder.mlmodelc、Unet…）；還沒好就是 nil
    func resources(_ m: Model) -> URL? {
        let marker = folder(m).appendingPathComponent(".resources")
        guard let rel = try? String(contentsOf: marker, encoding: .utf8) else { return nil }
        let u = folder(m).appendingPathComponent(rel)
        return FileManager.default.fileExists(atPath: u.appendingPathComponent("TextEncoder.mlmodelc").path) ? u : nil
    }

    var selected: Model { Self.models.first { $0.id == selectedID } ?? Self.models[0] }
    var readyModel: Model? {
        if states[selected.id] == .ready { return selected }
        return Self.models.first { states[$0.id] == .ready }
    }

    /// 下載的 zip 和解開的都要放得下（多留 500 MB）
    func hasRoom(_ m: Model) -> Bool {
        let v = try? Self.dir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let free = v?.volumeAvailableCapacityForImportantUsage else { return true }
        return free > m.bytes * 2 + 500_000_000
    }

    func download(_ m: Model) {
        guard resources(m) == nil else { states[m.id] = .ready; return }
        guard hasRoom(m) else {
            states[m.id] = .failed("手機空間不夠：需要大約 \(ModelStore.gb(m.bytes * 2 + 500_000_000)) 的空間")
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
        Painter.shared.unload()
        try? FileManager.default.removeItem(at: folder(m))
        states[m.id] = .absent
    }

    // MARK: - 下載的回呼（在背景執行緒）

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription else { return }
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : (Self.models.first { $0.id == id }?.bytes ?? 0)
        DispatchQueue.main.async { self.states[id] = .downloading(done: totalBytesWritten, total: total) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription, let m = Self.models.first(where: { $0.id == id }) else { return }
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            DispatchQueue.main.async { self.states[id] = .failed("下載網址回應 \(http.statusCode)") }
            return
        }
        // 暫存檔函式結束就會被刪掉：先搬走，再慢慢解開
        let zip = Self.dir.appendingPathComponent(m.id + ".zip")
        try? FileManager.default.removeItem(at: zip)
        do { try FileManager.default.moveItem(at: location, to: zip) } catch {
            DispatchQueue.main.async { self.states[id] = .failed("存不進手機：\(error.localizedDescription)") }
            return
        }
        DispatchQueue.main.async { self.states[id] = .unzipping }
        DispatchQueue.global(qos: .userInitiated).async { self.unzip(zip, m) }
    }

    private func unzip(_ zip: URL, _ m: Model) {
        let dst = folder(m)
        let fm = FileManager.default
        try? fm.removeItem(at: dst)
        do {
            try fm.createDirectory(at: dst, withIntermediateDirectories: true)
            try fm.unzipItem(at: zip, to: dst)
        } catch {
            try? fm.removeItem(at: zip)
            DispatchQueue.main.async { self.states[m.id] = .failed("解壓縮失敗：\(error.localizedDescription)") }
            return
        }
        try? fm.removeItem(at: zip)
        // 找出放模型的那一層資料夾（zip 裡面可能多包了幾層）
        var found: String?
        if fm.fileExists(atPath: dst.appendingPathComponent("TextEncoder.mlmodelc").path) { found = "" }
        if found == nil, let e = fm.enumerator(at: dst, includingPropertiesForKeys: nil) {
            for case let u as URL in e where u.lastPathComponent == "TextEncoder.mlmodelc" {
                found = String(u.deletingLastPathComponent().path.dropFirst(dst.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                break
            }
        }
        guard let rel = found else {
            try? fm.removeItem(at: dst)
            DispatchQueue.main.async { self.states[m.id] = .failed("下載的檔案裡沒有模型，請再下載一次") }
            return
        }
        try? rel.write(to: dst.appendingPathComponent(".resources"), atomically: true, encoding: .utf8)
        DispatchQueue.main.async { self.states[m.id] = .ready }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription, let m = Self.models.first(where: { $0.id == id }) else { return }
        if let http = task.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
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
