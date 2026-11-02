import SwiftUI
import UIKit

/// 大腦在背景下載完時，系統會叫醒 App 交代事情；大腦寫回答時切到背景要繼續寫
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 大腦寫到一半切到背景也要繼續寫
        BackgroundWork.setUp()
        return true
    }

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
