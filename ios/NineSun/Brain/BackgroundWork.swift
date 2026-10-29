import UIKit
import BackgroundTasks

/// 大腦寫回答寫到一半，使用者切到別的 App、設定或鎖螢幕：跟系統要時間，讓回答在背景寫完。
/// - 一般的背景時間（beginBackgroundTask，大約 30 秒）
/// - iOS 26 起再加「繼續處理」的工作（BGContinuedProcessingTask）：系統會顯示進度，寫多久都可以
/// 背景不能用 GPU，LocalBrain 會自己改用 CPU 接著寫。
final class BackgroundWork {
    static let identifier = "com.ninesun.app.brain-answer"

    /// 正在寫的那一則（同時只有一則）
    private static var current: BackgroundWork?
    private static var registered = false

    private var taskID: UIBackgroundTaskIdentifier = .invalid
    private var continued: AnyObject?
    private var written = 0
    private var ended = false

    /// App 一打開就叫：記住 App 在前景還是背景
    static func setUp() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            LocalBrain.shared.setBackground(true)
        }
        nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            LocalBrain.shared.setBackground(false)
        }
        // 要離開畫面了（切 App、回主畫面、鎖螢幕）：還在寫的話，請系統讓它繼續
        nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            current?.askToContinue()
        }
    }

    /// 開始寫一則回答（主執行緒）
    static func start() -> BackgroundWork {
        current?.end()
        let w = BackgroundWork()
        w.taskID = UIApplication.shared.beginBackgroundTask(withName: "NineSun brain") { [weak w] in w?.endBackgroundTime() }
        current = w
        return w
    }

    /// 寫了多少字（給系統顯示進度；任何執行緒）
    func tick(_ count: Int) {
        DispatchQueue.main.async {
            self.written = count
            if #available(iOS 26.0, *), let t = self.continued as? BGContinuedProcessingTask {
                t.progress.completedUnitCount = Int64(min(95, 5 + count / 4))
            }
        }
    }

    /// 寫完了（任何執行緒）
    func end() {
        let finish = {
            guard !self.ended else { return }
            self.ended = true
            if #available(iOS 26.0, *), let t = self.continued as? BGContinuedProcessingTask {
                t.progress.completedUnitCount = 100
                t.setTaskCompleted(success: true)
            }
            self.continued = nil
            self.endBackgroundTime()
            if BackgroundWork.current === self { BackgroundWork.current = nil }
        }
        if Thread.isMainThread { finish() } else { DispatchQueue.main.async(execute: finish) }
    }

    private func endBackgroundTime() {
        if taskID != .invalid { UIApplication.shared.endBackgroundTask(taskID); taskID = .invalid }
    }

    private func askToContinue() {
        guard !ended, continued == nil else { return }
        guard #available(iOS 26.0, *) else { return }
        if !Self.registered {
            Self.registered = true
            _ = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.identifier, using: .main) { task in
                guard let task = task as? BGContinuedProcessingTask else { task.setTaskCompleted(success: true); return }
                // 已經寫完了：馬上結束
                guard let w = BackgroundWork.current, !w.ended else { task.setTaskCompleted(success: true); return }
                w.continued = task
                task.progress.totalUnitCount = 100
                task.progress.completedUnitCount = Int64(min(95, 5 + w.written / 4))
                task.expirationHandler = { [weak w] in
                    if let w, w.continued === task { w.continued = nil }
                    task.setTaskCompleted(success: false)
                }
            }
        }
        let request = BGContinuedProcessingTaskRequest(identifier: Self.identifier, title: "NineSun 正在寫回答",
                                                       subtitle: "切到別的 App 也會繼續寫")
        request.strategy = .fail
        try? BGTaskScheduler.shared.submit(request)
    }
}
