import UIKit
import UniformTypeIdentifiers

/// 直接用 UIKit 的文件選擇器。SwiftUI 的 .fileImporter 和 .sheet 放在同一個頁面時，
/// 按「打開」可能收不到回調；asCopy 也讓系統先把 iCloud 文件下載並複製給我們。
final class DocumentPicker: NSObject, UIDocumentPickerDelegate {
    static let shared = DocumentPicker()

    private var completion: (([URL]) -> Void)?

    func present(completion: @escaping ([URL]) -> Void) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        self.completion = completion
        UIApplication.shared.topViewController()?.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let done = completion
        completion = nil
        done?(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion = nil
    }
}

extension UIApplication {
    /// 當前最上層的 ViewController，用來彈出系統的選擇器和分享面板。
    func topViewController() -> UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

enum ShareSheet {
    /// 系統分享面板：可以「儲存到檔案」，也可以發給別人。
    static func present(_ url: URL) {
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let top = UIApplication.shared.topViewController() else { return }
        sheet.popoverPresentationController?.sourceView = top.view
        top.present(sheet, animated: true)
    }
}
