import Foundation
import UIKit
import UserNotifications

/// 大腦的模型檔：第一次用的時候下載到手機裡（App 本身不放，不然 IPA 會好幾 GB），之後完全離線。
/// 用背景下載：切到別的 App、鎖螢幕也會繼續；斷線可以接著下載；下載完檢查是不是真的模型檔（GGUF）。
final class ModelStore: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = ModelStore()

    struct Model: Identifiable, Equatable {
        let id: String
        let name: String
        let file: String
        /// 大約的大小（顯示用；實際以下載時伺服器說的為準）
        let bytes: Int64
        /// 下載網址（第一個不行就換下一個）
        let urls: [String]
    }

    /// 大腦只剩 Gemma 4 E4B Mahou NSFW（使用者要求把官方原版 Gemma 4 E4B 拿掉，2026-11-18）
    /// （拿掉的模型：手機裡選了它的改選這個，舊檔打開 App 時會刪掉，還沒下載完的會取消）
    static let models: [Model] = [
        Model(id: "gemma4-e4b-mahou", name: "Gemma 4 E4B Mahou NSFW",
              file: "gemma4-e4b-mahou-nsfw.Q4_K_M.gguf", bytes: 5_302_273_152,
              urls: ["https://huggingface.co/mradermacher/gemma4-e4b-mahou-nsfw-GGUF/resolve/main/gemma4-e4b-mahou-nsfw.Q4_K_M.gguf",
                     "https://hf-mirror.com/mradermacher/gemma4-e4b-mahou-nsfw-GGUF/resolve/main/gemma4-e4b-mahou-nsfw.Q4_K_M.gguf"]),
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
    /// 正在下載的（避免同一個模型同時下載兩份）——只在主執行緒改
    private var active: Set<String> = []
    /// 斷掉後自動接著下載的次數（有進度就歸零）
    private var retries: [String: Int] = [:]
    /// 使用者自己按了「取消」的（不要再自動接著下載）
    private var userStopped: Set<String> = []

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
        // 以前選的模型已經拿掉了：改選清單上的（不然下載好了還顯示「用這個」）
        if !Self.models.contains(where: { $0.id == selectedID }) { selectedID = Self.models[0].id }
        for m in Self.models { states[m.id] = isReady(m) ? .ready : .absent }
        // 拿掉的舊模型還留在手機裡：刪掉，空出空間
        let keep = Set(Self.models.map(\.file))
        for f in (try? FileManager.default.contentsOfDirectory(atPath: Self.dir.path)) ?? [] where f.hasSuffix(".gguf") && !keep.contains(f) {
            try? FileManager.default.removeItem(at: Self.dir.appendingPathComponent(f))
        }
        // 上次還沒下載完的（App 被關掉又打開）接回來
        session.getAllTasks { tasks in
            for t in tasks {
                guard let id = t.taskDescription else { continue }
                // 拿掉的模型還在下載：取消
                guard Self.models.contains(where: { $0.id == id }) else { t.cancel(); continue }
                DispatchQueue.main.async {
                    self.active.insert(id)
                    self.states[id] = .downloading(done: t.countOfBytesReceived, total: t.countOfBytesExpectedToReceive)
                }
            }
            // 上次下載到一半（App 被關掉、手機重開）：幾秒後自動從斷掉的地方接著下載
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                for m in Self.models where !self.active.contains(m.id) && !self.isReady(m)
                    && FileManager.default.fileExists(atPath: self.resumeURL(m.id).path) {
                    self.download(m)
                }
            }
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
    /// 只用設定頁選的那一個（開關顯示的就是它）：選的還沒下載好就不用大腦，不偷偷改用別的模型
    /// （使用者截圖：新的預設模型還沒下載、設定頁顯示「已關閉」，App 卻在用舊的 Mahou 回答）
    var readyModel: Model? {
        states[selected.id] == .ready ? selected : nil
    }

    /// 手機剩下的空間夠不夠（多留 500 MB）
    func hasRoom(_ m: Model) -> Bool {
        let v = try? Self.dir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let free = v?.volumeAvailableCapacityForImportantUsage else { return true }
        return free > m.bytes + 500_000_000
    }

    /// 中斷的下載接著下載用的資料：存成檔案，App 被關掉再打開也能從斷掉的地方接著下載
    private func resumeURL(_ id: String) -> URL { Self.dir.appendingPathComponent("\(id).resume") }

    private func takeResume(_ id: String) -> Data? {
        let mem = resumeData.removeValue(forKey: id)
        let disk = try? Data(contentsOf: resumeURL(id))
        try? FileManager.default.removeItem(at: resumeURL(id))
        return mem ?? disk
    }

    /// App 不在前景時（背景下載完、失敗）跳通知告訴使用者
    private func notify(_ title: String, _ body: String) {
        guard UIApplication.shared.applicationState != .active else { return }
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    func download(_ m: Model) {
        guard !isReady(m) else { states[m.id] = .ready; return }
        guard !active.contains(m.id) else { return }
        userStopped.remove(m.id)
        // 下載好的時候要在背景通知（第一次下載時問一次可不可以通知）
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        guard hasRoom(m) else {
            states[m.id] = .failed("手機空間不夠：需要大約 \(Self.gb(m.bytes + 500_000_000)) 的空間")
            return
        }
        let task: URLSessionDownloadTask
        let shown: Int64
        if case .downloading(let d, _) = states[m.id] ?? .absent { shown = d } else { shown = 0 }
        if let data = takeResume(m.id) {
            task = session.downloadTask(withResumeData: data)
        } else {
            let i = min(mirror[m.id] ?? 0, m.urls.count - 1)
            task = session.downloadTask(with: URL(string: m.urls[i])!)
        }
        task.taskDescription = m.id
        active.insert(m.id)
        states[m.id] = .downloading(done: shown, total: m.bytes)
        task.resume()
    }

    func cancel(_ m: Model) {
        session.getAllTasks { tasks in
            for t in tasks where t.taskDescription == m.id { t.cancel() }
            DispatchQueue.main.async {
                self.states[m.id] = .absent
                self.resumeData[m.id] = nil
                self.active.remove(m.id)
                self.retries[m.id] = nil
                self.userStopped.insert(m.id)
                try? FileManager.default.removeItem(at: self.resumeURL(m.id))
            }
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
        DispatchQueue.main.async {
            // 使用者按了取消就不要再把進度蓋回去
            guard self.active.contains(id) else { return }
            self.retries[id] = 0
            self.states[id] = .downloading(done: totalBytesWritten, total: total)
        }
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
        DispatchQueue.main.async {
            self.active.remove(id)
            self.states[id] = ok ? .ready : .failed("下載的檔案不完整，請再下載一次")
            if ok { self.notify("NineSun 的大腦下載好了", "\(m.name) 已經下載完成，打開 App 就能用。") }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription, let m = Self.models.first(where: { $0.id == id }) else { return }
        if let http = task.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            // 這個網址不行：換下一個網址（接著下載的資料可能是舊網址的，不用了）
            let next = (mirror[id] ?? 0) + 1
            DispatchQueue.main.async {
                self.active.remove(id)
                self.resumeData[id] = nil
                try? FileManager.default.removeItem(at: self.resumeURL(id))
                if next < m.urls.count { self.mirror[id] = next; self.download(m) }
                else {
                    self.states[id] = .failed("下載網址都連不上（\(http.statusCode)）")
                    self.notify("NineSun 的大腦下載失敗", "下載網址都連不上，打開 App 再試一次。")
                }
            }
            return
        }
        guard let error else { DispatchQueue.main.async { self.active.remove(id); self.retries[id] = nil }; return }
        let ns = error as NSError
        let data = ns.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        // 使用者按了「取消」：不接著下載
        if ns.code == NSURLErrorCancelled, data == nil { DispatchQueue.main.async { self.active.remove(id) }; return }
        // 網路斷了、App 被滑掉、系統暫停：自動從斷掉的地方接著下載（等一下再試，最多試 8 次；有進度就重新算）
        DispatchQueue.main.async {
            self.active.remove(id)
            if let data { self.resumeData[id] = data; try? data.write(to: self.resumeURL(id)) }
            let n = (self.retries[id] ?? 0) + 1
            self.retries[id] = n
            if n <= 8 {
                // App 在背景時系統只叫醒一下下：馬上排下一次（交給系統的背景下載去等網路）；在前景就等幾秒再試
                let wait = UIApplication.shared.applicationState == .active ? Double(min(60, n * 5)) : 0
                DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                    // 這段時間使用者按了取消就不要再下載
                    if !self.userStopped.contains(id), !self.isReady(m) { self.download(m) }
                }
            } else {
                self.states[id] = .failed(data != nil ? "下載中斷了（\(error.localizedDescription)），按「繼續下載」接著下載" : "下載失敗：\(error.localizedDescription)")
                self.notify("NineSun 的大腦下載中斷了", "打開 App 按「繼續下載」，會從斷掉的地方接著下載。")
            }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async { self.backgroundCompletion?(); self.backgroundCompletion = nil }
    }
}
