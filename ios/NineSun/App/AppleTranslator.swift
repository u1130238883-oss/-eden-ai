import SwiftUI
import EchoCore
import Translation

/// 手機內建的翻譯（iOS 18 起）：整句翻譯，第一次用某個語言時系統會問要不要下載語言包，之後離線也能翻。
/// 系統只給 SwiftUI 的 .translationTask 拿翻譯工具，所以要有一個看不見的 AppleTranslatorBridge 放在畫面上。
@available(iOS 18.0, *)
final class AppleTranslator: ObservableObject {
    static let shared = AppleTranslator()

    /// 只在主執行緒改
    @Published var configuration: TranslationSession.Configuration?
    private var pending: (id: UUID, text: String, cont: CheckedContinuation<String?, Never>)?
    private let lock = NSLock()

    /// 拿走等待中的那一句（id 對得上才拿）
    private func take(_ id: UUID?) -> (id: UUID, text: String, cont: CheckedContinuation<String?, Never>)? {
        lock.lock(); defer { lock.unlock() }
        guard let p = pending, id == nil || p.id == id else { return nil }
        pending = nil
        return p
    }

    private func peek() -> (id: UUID, text: String)? {
        lock.lock(); defer { lock.unlock() }
        return pending.map { ($0.id, $0.text) }
    }

    /// allowDownload：false 時，語言包還沒下載就直接放棄（不跳出下載畫面讓人等），交給 AI 或線上翻譯
    func translate(_ req: Translate.Request, allowDownload: Bool) async -> Translate.Result? {
        let src = req.source ?? Translate.detect(req.text)
        guard src != req.target else { return nil }
        let from = Locale.Language(identifier: src.rawValue), to = Locale.Language(identifier: req.target.rawValue)
        let status = await LanguageAvailability().status(from: from, to: to)
        if status == .unsupported { return nil }
        if status != .installed && !allowDownload { return nil }
        // 一次只翻一句：前一句還沒翻完就放棄它
        take(nil)?.cont.resume(returning: nil)
        let id = UUID()
        // 已經下載好的語言很快；要先下載語言包的給久一點（使用者要按下載）
        let wait: Double = status == .installed ? 15 : 120
        let text: String? = await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            lock.lock()
            pending = (id, req.text, cont)
            lock.unlock()
            DispatchQueue.main.async {
                if self.configuration?.source == from && self.configuration?.target == to {
                    self.configuration?.invalidate()
                } else {
                    self.configuration = .init(source: from, target: to)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                self.take(id)?.cont.resume(returning: nil)
            }
        }
        guard let t = text, !t.isEmpty else { return nil }
        return Translate.Result(text: t, source: src, via: "手機內建翻譯，離線也能用")
    }

    func run(_ session: TranslationSession) async {
        guard let p = peek() else { return }
        let r = try? await session.translate(p.text)
        take(p.id)?.cont.resume(returning: r?.targetText)
    }
}

/// 看不見的元件：系統透過它把翻譯工具交給 AppleTranslator
@available(iOS 18.0, *)
struct AppleTranslatorBridge: View {
    @ObservedObject var hub = AppleTranslator.shared

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(hub.configuration) { session in
                await hub.run(session)
            }
    }
}
