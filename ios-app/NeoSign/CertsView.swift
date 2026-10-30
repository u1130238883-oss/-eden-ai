import SwiftUI
import UniformTypeIdentifiers

struct CertsView: View {
    @EnvironmentObject private var store: Store
    @State private var importing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(code: "CERT", title: "證書", subtitle: "IDENTITY")

                Button { importing = true } label: {
                    Label("導入證書", systemImage: "key.fill")
                }
                .buttonStyle(NeonButtonStyle())

                Text("直接選賣家給的證書 zip 就行，會自動讀出 p12、描述文件和密碼。也可以同時選 .p12 和 .mobileprovision 兩個文件。")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)

                if store.certs.isEmpty {
                    EmptyHint(title: "還沒有證書", detail: "簽名前要先導入一張證書")
                } else {
                    SectionLabel(text: "點擊設為默認 · 長按刪除")
                    ForEach(store.certs) { cert in
                        CertCard(cert: cert, selected: cert.id == store.selectedCert?.id)
                            .onTapGesture { store.selectedCertID = cert.id }
                            .contextMenu {
                                Button(role: .destructive) { store.delete(cert) } label: {
                                    Label("刪除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { store.importFiles(urls) }
        }
    }
}

struct CertCard: View {
    var cert: CertRecord
    var selected: Bool
    @State private var showDevices = false

    private var statusColor: Color {
        if cert.isExpired { return Theme.danger }
        return cert.daysLeft < 30 ? Theme.pink : Theme.neon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cert.name)
                        .font(.display(20))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(cert.appID)
                        .font(.mono(11, .medium))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if selected { Tag(text: "使用中", color: Theme.neon) }
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(cert.isExpired ? "已過期" : "\(cert.daysLeft)")
                    .font(.display(cert.isExpired ? 26 : 40))
                    .foregroundColor(statusColor)
                if !cert.isExpired {
                    Text("天後到期").font(.mono(12, .heavy)).foregroundColor(statusColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("證書 \(cert.expires.formatted(date: .numeric, time: .omitted))")
                    Text("描述文件 \(cert.profileExpires.formatted(date: .numeric, time: .omitted))")
                }
                .font(.mono(10, .medium))
                .foregroundColor(Theme.muted)
            }

            HStack(spacing: 6) {
                Tag(text: cert.profileKind, color: Theme.cyan, filled: false)
                if !cert.devices.isEmpty {
                    Button { showDevices.toggle() } label: {
                        Tag(text: "\(cert.devices.count) 台設備 \(showDevices ? "▲" : "▼")", color: Theme.muted, filled: false)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showDevices {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(cert.devices, id: \.self) { udid in
                        Text(udid).font(.mono(11, .medium)).foregroundColor(.white).textSelection(.enabled)
                    }
                    Text("Ad Hoc 證書只能裝在這些 UDID 的設備上")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.muted)
                }
            }
        }
        .panel(accent: statusColor)
        .overlay(alignment: .topTrailing) {
            if selected {
                CutCorner(cut: 16).stroke(Theme.neon, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
    }
}
