import SwiftUI

struct SettingsView: View {
    @AppStorage("server") private var server = InstallService.defaultServer
    @AppStorage("serverPassword") private var password = ""
    @State private var testing = false
    @State private var result: (ok: Bool, text: String)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(code: "SYS", title: "設置", subtitle: "CONFIG")

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "安裝伺服器")
                    NeoField(label: "網站地址", placeholder: InstallService.defaultServer, text: $server)
                        .keyboardType(.URL)
                    NeoField(label: "網站密碼（ACCESS_PASSWORD）", placeholder: "在 Render 設置的密碼", text: $password, secure: true)

                    Button {
                        Task { await test() }
                    } label: {
                        HStack(spacing: 8) {
                            if testing { ProgressView().tint(Theme.neon) }
                            Text(testing ? "連接中（伺服器休眠時要等約 1 分鐘）" : "測試連接")
                        }
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(testing)

                    if let result {
                        Text(result.text)
                            .font(.display(16))
                            .foregroundColor(result.ok ? Theme.neon : Theme.danger)
                    }
                }
                .panel()

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "為什麼要伺服器")
                    Text("簽名完全在手機上完成。但 iOS 只允許從 HTTPS 網站安裝 App，所以簽好的 IPA 會上傳到你自己的簽名網站，再從那裡安裝。這樣不依賴手機本地伺服器，系統更新也不容易失效。")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.muted)
                }
                .panel(accent: Theme.cyan)

                VStack(alignment: .leading, spacing: 6) {
                    CautionTape(text: "NEO//SIGN")
                    Text("霓簽 v1.0").font(.display(22)).foregroundColor(.white)
                    Text("簽名引擎：zsign（開源）").font(.mono(11, .medium)).foregroundColor(Theme.muted)
                }
                .panel(accent: Theme.pink)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        do {
            try await InstallService.login(server: server, password: password)
            result = (true, "連接成功 ✓")
        } catch {
            result = (false, error.localizedDescription)
        }
    }
}
