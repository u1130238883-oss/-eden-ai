import SwiftUI

struct SignView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("server") private var server = InstallService.defaultServer
    @AppStorage("serverPassword") private var serverPassword = ""

    @State private var app: AppRecord
    @State private var certID = ""
    @State private var bundleID = ""
    @State private var displayName = ""
    @State private var version = ""
    @State private var showAdvanced = false
    @State private var phase: Phase = .idle
    @State private var log: LogText?

    enum Phase: Equatable {
        case idle, signing, signed, installing, installed
        case failed(String)
    }

    init(app: AppRecord) {
        _app = State(initialValue: app)
    }

    private var cert: CertRecord? {
        store.certs.first { $0.id == certID } ?? store.selectedCert
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Halftone(color: Theme.pink.opacity(0.18))
                .frame(height: 220)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    certSection
                    advancedSection
                    actionSection
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            certID = store.selectedCert?.id ?? ""
            if store.signedURL(for: app) != nil { phase = .signed }
        }
        .sheet(item: $log) { item in
            LogSheet(text: item.text)
        }
    }

    // MARK: 區塊

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SIGN // 簽名")
                    .font(.mono(12, .heavy))
                    .foregroundColor(Theme.neon)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(width: 34, height: 30)
                        .background(Slant(cut: 6).fill(Theme.neon))
                }
            }
            HStack(spacing: 14) {
                AppIconView(image: store.icon(for: app), size: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name).font(.display(30)).foregroundColor(.white).lineLimit(2)
                    Text("\(app.bundleID) · v\(app.version)")
                        .font(.mono(11, .medium))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                }
            }
            CautionTape(text: tapeText)
        }
    }

    private var tapeText: String {
        switch phase {
        case .idle: return "READY TO SIGN"
        case .signing: return "SIGNING..."
        case .signed: return "SIGNED"
        case .installing: return "UPLOADING..."
        case .installed: return "INSTALLING"
        case .failed: return "ERROR"
        }
    }

    private var certSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "選擇證書")
            if store.certs.isEmpty {
                Text("還沒有證書，先到「證書」頁導入")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.pink)
            }
            ForEach(store.certs) { item in
                Button { certID = item.id } label: {
                    HStack {
                        Image(systemName: item.id == cert?.id ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(item.id == cert?.id ? Theme.neon : Theme.muted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            Text(item.isExpired ? "已過期" : "還有 \(item.daysLeft) 天 · \(item.profileKind)")
                                .font(.mono(10, .medium))
                                .foregroundColor(item.isExpired ? Theme.danger : Theme.muted)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Slant(cut: 8).fill(item.id == cert?.id ? Theme.panel2 : Theme.panel))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { showAdvanced.toggle() }
            } label: {
                HStack {
                    SectionLabel(text: "進階選項（可不填）")
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(Theme.muted)
                }
            }
            .buttonStyle(.plain)
            if showAdvanced {
                NeoField(label: "新 Bundle ID", placeholder: app.bundleID, text: $bundleID)
                NeoField(label: "新名稱", placeholder: app.name, text: $displayName)
                NeoField(label: "新版本號", placeholder: app.version, text: $version)
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch phase {
            case .signing, .installing:
                VStack(alignment: .leading, spacing: 10) {
                    Text(phase == .signing ? "正在手機上簽名…" : "上傳到安裝伺服器…（休眠時要等約 1 分鐘）")
                        .font(.display(18))
                        .foregroundColor(.white)
                    ScanBar()
                }
                .panel()

            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text(message).font(.system(size: 15, weight: .bold)).foregroundColor(Theme.danger)
                    Button("查看簽名日誌") { showLog() }
                        .font(.mono(12, .heavy))
                        .foregroundColor(Theme.cyan)
                }
                .panel(accent: Theme.danger)
                signButton(title: "重新簽名")

            case .idle:
                signButton(title: "開始簽名")

            case .signed, .installed:
                if phase == .installed {
                    Text("已打開安裝彈窗，選「安裝」後回到桌面查看進度")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.neon)
                }
                Button {
                    Task { await install() }
                } label: {
                    Label("安裝到手機", systemImage: "arrow.down.app.fill")
                }
                .buttonStyle(NeonButtonStyle())

                if let url = store.signedURL(for: app) {
                    ShareLink(item: url) {
                        Label("分享 / 保存 IPA", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(GhostButtonStyle(color: Theme.cyan))
                }

                Button("用其他設置重新簽名") { phase = .idle }
                    .font(.mono(12, .heavy))
                    .foregroundColor(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func signButton(title: String) -> some View {
        Button {
            Task { await sign() }
        } label: {
            Label(title, systemImage: "signature")
        }
        .buttonStyle(NeonButtonStyle())
        .disabled(cert == nil)
        .opacity(cert == nil ? 0.4 : 1)
    }

    // MARK: 動作

    private func sign() async {
        guard let cert else { return }
        phase = .signing
        do {
            app = try await store.sign(app, with: cert,
                                       bundleID: bundleID.trimmingCharacters(in: .whitespaces),
                                       name: displayName.trimmingCharacters(in: .whitespaces),
                                       version: version.trimmingCharacters(in: .whitespaces))
            phase = .signed
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func install() async {
        guard let ipa = store.signedURL(for: app) else { return }
        guard !serverPassword.isEmpty else {
            phase = .failed("先到「設置」填寫安裝伺服器的網站密碼")
            return
        }
        phase = .installing
        do {
            let url = try await InstallService.upload(ipa: ipa, server: server, password: serverPassword)
            _ = await UIApplication.shared.open(url)
            phase = .installed
        } catch {
            phase = .failed("安裝失敗：\(error.localizedDescription)")
        }
    }

    private func showLog() {
        let text = (try? String(contentsOf: store.logURL(for: app), encoding: .utf8)) ?? ""
        log = LogText(text: text.isEmpty ? "（沒有日誌）" : text)
    }
}

private struct LogText: Identifiable {
    let id = UUID()
    let text: String
}

private struct LogSheet: View {
    var text: String

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                Text(text)
                    .font(.mono(11, .regular))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }
}
