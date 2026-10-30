import SwiftUI

@main
struct NeoSignApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // 從「文件」或其他 App 用「霓簽」打開
                    if url.isFileURL { store.importFiles([url]) }
                }
        }
    }
}

enum MainTab: CaseIterable {
    case apps, certs, settings

    var title: String {
        switch self {
        case .apps: return "應用"
        case .certs: return "證書"
        case .settings: return "設置"
        }
    }

    var icon: String {
        switch self {
        case .apps: return "square.stack.3d.up.fill"
        case .certs: return "checkmark.seal.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: Store
    @State private var tab: MainTab = .apps
    @State private var password = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()
            Halftone(color: Color.white.opacity(0.10))
                .frame(width: 280, height: 280)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .ignoresSafeArea()

            Group {
                switch tab {
                case .apps: LibraryView()
                case .certs: CertsView()
                case .settings: SettingsView()
                }
            }

            TabBar(tab: $tab)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
        }
        .overlay(alignment: .top) { ToastView() }
        .alert("輸入證書密碼",
               isPresented: Binding(get: { store.passwordPrompt != nil },
                                    set: { if !$0 { store.passwordPrompt = nil } })) {
            SecureField("證書密碼", text: $password)
            Button("取消", role: .cancel) { password = "" }
            Button("導入") {
                guard let pending = store.passwordPrompt else { return }
                let entered = password
                password = ""
                Task { await store.addCert(p12: pending.p12, profile: pending.profile, password: entered) }
            }
        } message: {
            Text(store.passwordPrompt?.triedPassword == true ? "密碼不對，再試一次" : "p12 證書需要密碼")
        }
    }
}

struct TabBar: View {
    @Binding var tab: MainTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MainTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { tab = item }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon).font(.system(size: 14, weight: .bold))
                        Text(item.title).font(.display(17))
                    }
                    .foregroundColor(tab == item ? .black : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Slant(cut: 10).fill(tab == item ? Theme.neon : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .background(CutCorner(cut: 14).fill(Theme.panel.opacity(0.96)))
        .overlay(CutCorner(cut: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 18, y: 6)
    }
}

struct ToastView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        VStack(spacing: 8) {
            if let busy = store.busy {
                HStack(spacing: 10) {
                    ProgressView().tint(.black)
                    Text(busy).lineLimit(1)
                }
                .toastStyle(Theme.neon)
            }
            if let toast = store.toast {
                Text(toast).toastStyle(Theme.pink)
                    .onTapGesture { store.toast = nil }
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.toast)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.busy)
    }
}

private extension View {
    func toastStyle(_ color: Color) -> some View {
        self.font(.display(16))
            .foregroundColor(.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Slant(cut: 10).fill(color))
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
