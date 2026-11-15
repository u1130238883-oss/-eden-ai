import SwiftUI

@main
struct StreetWallApp: App {
    @StateObject private var store = WallStore.shared
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onChange(of: phase) { _, p in
                    // Shortcuts may have switched the channel while we were in the background.
                    if p == .active { store.reload() }
                }
        }
    }
}

enum AppTab: String, CaseIterable {
    case channel = "頻道"
    case library = "片庫"
    case maker = "生成"
    case auto = "自動"
    var code: String {
        switch self {
        case .channel: return "CH"
        case .library: return "LIB"
        case .maker: return "GEN"
        case .auto: return "AUTO"
        }
    }
}

final class Toaster: ObservableObject {
    @Published var message: String?
    private var work: DispatchWorkItem?
    func show(_ msg: String) {
        work?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { message = msg }
        let w = DispatchWorkItem { [weak self] in
            withAnimation(.easeIn(duration: 0.2)) { self?.message = nil }
        }
        work = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: w)
    }
}

struct RootView: View {
    @EnvironmentObject var store: WallStore
    @StateObject private var toaster = Toaster()
    @StateObject private var center = ApplyCenter()
    @State private var tab: AppTab = .channel

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.ink.ignoresSafeArea()
            Halftone(color: Theme.acid.opacity(0.08), spacing: 12, radius: 1.2).ignoresSafeArea()
            Scanlines().ignoresSafeArea()

            Group {
                switch tab {
                case .channel: ChannelView()
                case .library: LibraryView(onPick: { id in
                    store.select(id)
                    Haptics.tap()
                    withAnimation(.snappy) { tab = .channel }
                })
                case .maker: GeneratorView()
                case .auto: AutoView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.bottom, 64)

            tabBar

            if let msg = toaster.message {
                Toast(text: msg)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .environmentObject(toaster)
        .environmentObject(center)
        .onOpenURL { center.handle($0, toaster: toaster) }
        .sheet(isPresented: $center.showSetup) {
            ShortcutSetupSheet()
                .environmentObject(center)
                .environmentObject(toaster)
                .environmentObject(store)
                .presentationDragIndicator(.visible)
        }
        .background {
            Color.clear.sheet(isPresented: $center.showHomeGuide) {
                HomeGuideSheet()
                    .environmentObject(center)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases, id: \.self) { t in
                Button {
                    Haptics.tap()
                    withAnimation(.snappy) { tab = t }
                } label: {
                    HStack(spacing: 4) {
                        Text(t.code).font(.mono(9)).opacity(0.7)
                        Text(t.rawValue).font(.display(19))
                    }
                    .foregroundStyle(tab == t ? Theme.ink : Theme.paper)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Slant(cut: 12).fill(tab == t ? Theme.acid : Theme.panel2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.rawValue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Theme.ink.opacity(0.92)
                .overlay(alignment: .top) { HazardStripe(color: Theme.acid.opacity(0.9), band: 6).frame(height: 4) }
                .ignoresSafeArea()
        )
    }
}
