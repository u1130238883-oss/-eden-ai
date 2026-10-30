import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @State private var cacheSize: Int64?
    @State private var confirmClear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(code: "SYS", title: "設置", subtitle: "CONFIG")

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "緩存")
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(cacheSize.map(\.fileSize) ?? "…")
                            .font(.display(40))
                            .foregroundColor(Theme.neon)
                        Text("安裝包和臨時文件")
                            .font(.mono(12, .heavy))
                            .foregroundColor(Theme.muted)
                    }
                    Button {
                        confirmClear = true
                    } label: {
                        Label("清除緩存", systemImage: "trash.fill")
                    }
                    .buttonStyle(NeonButtonStyle(color: Theme.pink, shadow: Theme.neon, foreground: .white))
                    Text("會刪除應用庫裡所有的 IPA 安裝包（包括簽好的），證書會保留。")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.muted)
                }
                .panel(accent: Theme.pink)

                VStack(alignment: .leading, spacing: 6) {
                    CautionTape(text: "NEO//SIGN")
                    Text("霓簽 v1.1").font(.display(22)).foregroundColor(.white)
                    Text("簽名引擎：zsign（開源）").font(.mono(11, .medium)).foregroundColor(Theme.muted)
                }
                .panel(accent: Theme.neon)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .task { cacheSize = await store.cacheSize() }
        .alert("清除緩存？", isPresented: $confirmClear) {
            Button("取消", role: .cancel) {}
            Button("全部刪除", role: .destructive) {
                Task {
                    await store.clearCache()
                    cacheSize = await store.cacheSize()
                }
            }
        } message: {
            Text("所有 IPA 安裝包都會被刪除，不能恢復。")
        }
    }
}
