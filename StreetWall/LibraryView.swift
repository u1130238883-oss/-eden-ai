import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var store: WallStore
    @EnvironmentObject var toaster: Toaster
    var onPick: (Int) -> Void

    enum Filter: String, CaseIterable { case all = "全部", city = "霓虹街區", neo = "街頭新番", urban = "都市潮流", lime = "黃綠系列", fav = "收藏" }
    @State private var filter: Filter = .all
    @State private var savingAll = false

    private var items: [Wallpaper] {
        switch filter {
        case .all: return Catalog.all
        case .urban: return Catalog.all.filter { $0.series == .urban }
        case .lime: return Catalog.all.filter { $0.series == .lime }
        case .neo: return Catalog.all.filter { $0.series == .neo }
        case .city: return Catalog.all.filter { $0.series == .city }
        case .fav: return Catalog.all.filter { store.favorites.contains($0.id) }
        }
    }

    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TAPE LIBRARY").font(.mono(11)).tracking(3).foregroundStyle(Theme.dim)
                    Text("錄像片庫").font(.display(30)).foregroundStyle(Theme.paper)
                }
                Spacer()
                Text("\(items.count) / \(Catalog.all.count)")
                    .font(.mono(12)).foregroundStyle(Theme.acid)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Filter.allCases, id: \.self) { f in
                        Button {
                            Haptics.tap()
                            withAnimation(.snappy) { filter = f }
                        } label: {
                            Text(f.rawValue)
                                .font(.display(17))
                                .foregroundStyle(filter == f ? Theme.ink : Theme.paper)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 36)
                                .background(Slant(cut: 8).fill(filter == f ? Theme.acid : Theme.panel2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            ScrollView {
                if items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "star.slash").font(.system(size: 36, weight: .bold))
                        Text("還沒有收藏，到頻道頁按「收藏」").font(.mono(12))
                    }
                    .foregroundStyle(Theme.dim)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(items) { wp in
                            Button { onPick(wp.id) } label: { card(wp) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("頻道 \(wp.number) \(wp.title)")
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Button {
                    saveAll()
                } label: {
                    Label(savingAll ? "保存中…" : "把這 \(items.count) 張全部存入相簿", systemImage: "square.and.arrow.down.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))
                .disabled(savingAll || items.isEmpty)
                .padding(16)
            }
        }
        .padding(.top, 6)
    }

    private func card(_ wp: Wallpaper) -> some View {
        let on = wp.id == store.channelID
        return VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Thumb(wp: wp)
                    .aspectRatio(390.0 / 844.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(on ? Theme.acid : Theme.line, lineWidth: on ? 3 : 1)
                    )
                if store.favorites.contains(wp.id) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(5)
                        .background(Circle().fill(Theme.hot))
                        .padding(6)
                }
            }
            HStack(spacing: 6) {
                Text(wp.number)
                    .font(.mono(10))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Slant(cut: 4).fill(wp.accent))
                Text(wp.title)
                    .font(.display(14))
                    .foregroundStyle(Theme.paper)
                    .lineLimit(1)
            }
        }
    }

    private func saveAll() {
        savingAll = true
        let list = items
        Task {
            do {
                try await PhotoSaver.save(list)
                Haptics.ok()
                toaster.show("已存入 \(list.count) 張壁紙")
            } catch {
                Haptics.fail()
                toaster.show(error.localizedDescription)
            }
            savingAll = false
        }
    }
}
