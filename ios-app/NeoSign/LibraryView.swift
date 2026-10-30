import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: Store
    @State private var signing: AppRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(code: "APP", title: "應用庫", subtitle: "LIBRARY")

                Button { DocumentPicker.shared.present { store.importFiles($0) } } label: {
                    Label("導入 IPA", systemImage: "plus.square.fill")
                }
                .buttonStyle(NeonButtonStyle())

                if store.apps.isEmpty {
                    EmptyHint(title: "還沒有應用",
                              detail: "點上面「導入 IPA」，或在「文件」App 裡長按 IPA → 分享 → 霓簽")
                } else {
                    SectionLabel(text: "共 \(store.apps.count) 個 · 點擊簽名 · 長按刪除")
                    ForEach(store.apps) { app in
                        AppCard(app: app)
                            .onTapGesture { signing = app }
                            .contextMenu {
                                Button(role: .destructive) { store.delete(app) } label: {
                                    Label("刪除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .sheet(item: $signing) { app in
            SignView(app: app)
        }
    }
}

struct AppIconView: View {
    var image: UIImage?
    var size: CGFloat = 58

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.panel2
                    Image(systemName: "app.dashed")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundColor(Theme.muted)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
    }
}

struct AppCard: View {
    @EnvironmentObject private var store: Store
    var app: AppRecord

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(image: store.icon(for: app))
            VStack(alignment: .leading, spacing: 5) {
                Text(app.name)
                    .font(.display(22))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(.mono(11, .medium))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Tag(text: "v\(app.version)", color: Theme.cyan, filled: false)
                    Tag(text: app.size.fileSize, color: Theme.muted, filled: false)
                    if app.signedAt != nil {
                        Tag(text: "已簽名", color: Theme.neon)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(Theme.neon)
        }
        .panel(accent: app.signedAt == nil ? Theme.muted : Theme.neon)
        .contentShape(Rectangle())
    }
}

struct EmptyHint: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CautionTape(text: "EMPTY")
            Text(title).font(.display(26)).foregroundColor(.white)
            Text(detail).font(.system(size: 14)).foregroundColor(Theme.muted)
        }
        .panel(accent: Theme.pink)
    }
}
