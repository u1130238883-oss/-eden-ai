import SwiftUI

@main
struct NineSunApp: App {
    @StateObject private var vm = ChatViewModel()

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
