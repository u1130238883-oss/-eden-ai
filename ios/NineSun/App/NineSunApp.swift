import SwiftUI
import UIKit

/// 大腦在背景下載完時，系統會叫醒 App 交代事情
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        ModelStore.shared.backgroundCompletion = completionHandler
    }
}

@main
struct NineSunApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var vm = ChatViewModel()
    /// 一開 App 就把下載接回來（上次還沒下載完的）
    private let models = ModelStore.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch vm.phase {
                case .ready:
                    ChatView().transition(.opacity)
                case .booting:
                    BootView().transition(.opacity)
                case .failed(let msg):
                    BootView(error: msg)
                }
            }
            .environmentObject(vm)
            .preferredColorScheme(.dark)
            .onAppear { vm.boot() }
        }
    }
}
