import SwiftUI
import UIKit

@main
struct NineTwelveApp: App {
    @StateObject private var state = AppState()
    @StateObject private var subscription = Subscription()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(subscription)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var sub: Subscription
    /// 目前的分頁。Debug 版可用 -uiTab N 指定開啟時的分頁（自動截圖用）。
    @State private var selection: Int = {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: "uiTab")
        #else
        return 0
        #endif
    }()

    var body: some View {
        let t = state.t
        if state.owner == nil {
            OnboardingView()
        } else {
            TabView(selection: $selection) {
                // 今日免費：日運是入口，讓人先看得到東西
                TodayView()
                    .tabItem { Label(t("今日", "Today", "Hoy", "Oggi"),
                                     systemImage: "sun.and.horizon.fill") }
                    .tag(0)

                // 以下三頁需要會員
                gated(t("命盤", "Chart", "Carta", "Carta")) { NatalView() }
                    .tabItem { Label(t("命盤", "Chart", "Carta", "Carta"),
                                     systemImage: "circle.grid.3x3.fill") }
                    .tag(1)

                gated(t("運程", "Fortune", "Destino", "Sorte")) { FortuneView() }
                    .tabItem { Label(t("運程", "Fortune", "Destino", "Sorte"),
                                     systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(2)

                gated(t("合盤", "Synastry", "Sinastría", "Sinastria")) { SynastryView() }
                    .tabItem { Label(t("合盤", "Synastry", "Sinastría", "Sinastria"),
                                     systemImage: "person.2.fill") }
                    .tag(3)

                SettingsView()
                    .tabItem { Label(t("設定", "Settings", "Ajustes", "Impostazioni"),
                                     systemImage: "gearshape.fill") }
                    .tag(4)
            }
        }
    }

    /// 有會員就顯示內容，沒有就顯示解鎖畫面。
    @ViewBuilder
    private func gated<Content: View>(_ title: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        if sub.isActive {
            content()
        } else {
            PaywallView(title: title)
        }
    }
}
