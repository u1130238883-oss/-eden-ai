import SwiftUI
import UIKit

/// 畫圖測試版（NineSun Paint）：只有畫室，用來試手機跑不跑得動畫圖。可以和 NineSun 同時裝。
final class PaintAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        PaintStore.shared.backgroundCompletion = completionHandler
    }
}

/// 畫室要的設定（正式版是 NineSun 的 ChatViewModel）
final class ChatViewModel: ObservableObject {
    @Published var adultMode = UserDefaults.standard.bool(forKey: "paint.adultMode") {
        didSet { UserDefaults.standard.set(adultMode, forKey: "paint.adultMode") }
    }
}

@main
struct PaintTestApp: App {
    @UIApplicationDelegateAdaptor(PaintAppDelegate.self) private var delegate
    @StateObject private var vm = ChatViewModel()
    @State private var confirmAdult = false
    private let store = PaintStore.shared

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                Toggle(isOn: Binding(get: { vm.adultMode }, set: { on in if on { confirmAdult = true } else { vm.adultMode = false } })) {
                    Text("成人模式（18+）").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.paper)
                }
                .tint(Theme.neonPink)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.ink)
                PaintView().environmentObject(vm)
            }
            .background(Theme.ink)
            .preferredColorScheme(.dark)
            .alert("你已經滿 18 歲了嗎？", isPresented: $confirmAdult) {
                Button("我已滿 18 歲") { vm.adultMode = true }
                Button("取消", role: .cancel) {}
            } message: {
                Text("成人模式可以畫成人內容。只畫成年人，不畫真實存在的人。")
            }
        }
    }
}
