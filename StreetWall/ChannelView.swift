import SwiftUI

struct ChannelView: View {
    @EnvironmentObject var store: WallStore
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var center: ApplyCenter

    @State private var glitch = false
    @State private var lockPreview = true
    @State private var fullscreen = false
    @State private var saving = false
    @State private var dragX: CGFloat = 0
    @State private var pickTarget = false

    var body: some View {
        let wp = store.current
        VStack(spacing: 12) {
            header(wp)
            GeometryReader { geo in
                HStack(alignment: .top, spacing: 12) {
                    tv(wp, height: geo.size.height)
                    sidePanel(wp)
                }
            }
            actions(wp)
            Shelf()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .fullScreenCover(isPresented: $fullscreen) {
            FullPreview(startID: wp.id)
        }
        .onChange(of: store.channelID) { _, _ in flash() }
        .confirmationDialog("CH \(wp.number) \(wp.title)", isPresented: $pickTarget, titleVisibility: .visible) {
            ForEach(WallTarget.allCases) { t in
                Button(t.label) { center.apply(t, toaster: toaster) }
            }
            Button("安裝 / 重新安裝捷徑") { center.openSetup(.lock) }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: header

    private func header(_ wp: Wallpaper) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STREET//WALL").font(.mono(11)).tracking(3).foregroundStyle(Theme.dim)
                Text("潮流壁紙台").font(.display(30)).foregroundStyle(Theme.paper)
            }
            Spacer()
            HStack(spacing: 6) {
                BlinkDot(color: Theme.hot)
                Text("ON AIR").font(.mono(11)).foregroundStyle(Theme.paper)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .overlay(Slant(cut: 6).stroke(Theme.line, lineWidth: 1.5))
        }
    }

    // MARK: TV

    private func tv(_ wp: Wallpaper, height: CGFloat) -> some View {
        let h = height
        let w = h * 390 / 844
        return ZStack {
            if let img = wp.image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Theme.panel
            }
            if lockPreview { LockOverlay(scale: w / 390) }
            if glitch {
                StaticNoise().background(Color.black.opacity(0.35)).transition(.opacity)
            }
            Scanlines()
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: w * 0.11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: w * 0.11, style: .continuous)
                .stroke(Theme.paper.opacity(0.9), lineWidth: 3)
        )
        .background(
            RoundedRectangle(cornerRadius: w * 0.11, style: .continuous)
                .fill(wp.accent)
                .offset(x: 6, y: 6)
        )
        .offset(x: dragX * 0.25)
        .rotation3DEffect(.degrees(Double(dragX) / 18), axis: (x: 0, y: 1, z: 0))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.snappy) { lockPreview.toggle() } }
        .onLongPressGesture(minimumDuration: 0.35) { Haptics.tap(); fullscreen = true }
        .gesture(
            DragGesture(minimumDistance: 15)
                .onChanged { dragX = $0.translation.width }
                .onEnded { v in
                    if v.translation.width < -50 { store.step(1); Haptics.tap() }
                    else if v.translation.width > 50 { store.step(-1); Haptics.tap() }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { dragX = 0 }
                }
        )
        .accessibilityLabel("目前壁紙 \(wp.title)。左右滑動切換頻道，長按全螢幕預覽。")
    }

    // MARK: side panel

    private func sidePanel(_ wp: Wallpaper) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CH").font(.mono(12)).foregroundStyle(Theme.dim)
            Text(wp.number)
                .font(.display(78))
                .foregroundStyle(wp.accent)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, -14)
            Text(wp.title)
                .font(.display(22))
                .foregroundStyle(Theme.paper)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Tag(text: wp.series.rawValue, fill: Theme.panel2, fg: Theme.paper)
            Text(wp.tag).font(.mono(10)).foregroundStyle(Theme.dim).lineLimit(2)

            Spacer(minLength: 4)

            // channel up / down, like a TV
            VStack(spacing: 8) {
                knob("chevron.up", "上一台") { store.step(-1) }
                knob("shuffle", "隨機") { store.shuffle() }
                knob("chevron.down", "下一台") { store.step(1) }
            }

            Button {
                Haptics.tap()
                store.toggleFavorite(wp.id)
            } label: {
                let fav = store.favorites.contains(wp.id)
                HStack(spacing: 6) {
                    Image(systemName: fav ? "star.fill" : "star")
                    Text(fav ? "已收藏" : "收藏")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SlantButtonStyle(fill: store.favorites.contains(wp.id) ? Theme.hot : Theme.paper, outline: !store.favorites.contains(wp.id)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.snappy, value: wp.id)
    }

    private func knob(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(CutPanel(cut: 8).fill(Theme.acid))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: actions

    private func actions(_ wp: Wallpaper) -> some View {
        HStack(spacing: 10) {
            Button {
                applyNow(wp)
            } label: {
                Label("一鍵套用", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
            }
            .buttonStyle(SlantButtonStyle())

            Button {
                save(wp)
            } label: {
                Label(saving ? "保存中" : "存相簿", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
            }
            .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))
            .disabled(saving)

            if let url = wp.fullURL {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.paper)
                        .frame(width: 50, height: 46)
                        .overlay(Slant().stroke(Theme.paper, lineWidth: 2))
                }
                .accessibilityLabel("分享")
            }
        }
    }

    private func flash() {
        withAnimation(.easeIn(duration: 0.05)) { glitch = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.easeOut(duration: 0.15)) { glitch = false }
        }
    }

    private func save(_ wp: Wallpaper) {
        saving = true
        Task {
            do {
                try await PhotoSaver.save([wp])
                Haptics.ok()
                toaster.show("CH \(wp.number) 已存入相簿")
            } catch {
                Haptics.fail()
                toaster.show(error.localizedDescription)
            }
            saving = false
        }
    }

    private func applyNow(_ wp: Wallpaper) {
        Haptics.tap()
        pickTarget = true
    }
}

// MARK: - Lock-screen overlay

struct LockOverlay: View {
    var scale: CGFloat
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            VStack(spacing: 2 * scale) {
                Text(ctx.date, format: .dateTime.month(.defaultDigits).day().weekday(.wide))
                    .font(.system(size: 19 * scale, weight: .semibold))
                Text(ctx.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.system(size: 92 * scale, weight: .bold, design: .rounded))
                    .padding(.top, -6 * scale)
            }
            .foregroundStyle(.white.opacity(0.92))
            .shadow(color: .black.opacity(0.25), radius: 4 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 62 * scale)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Tape shelf (thumb strip)

struct Shelf: View {
    @EnvironmentObject var store: WallStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Catalog.all) { wp in
                        let on = wp.id == store.channelID
                        Button {
                            Haptics.tap()
                            store.select(wp.id)
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                Thumb(wp: wp)
                                    .frame(width: 44, height: 95)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text(wp.number)
                                    .font(.mono(9))
                                    .foregroundStyle(on ? Theme.ink : Theme.paper)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(on ? Theme.acid : Color.black.opacity(0.7))
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(on ? Theme.acid : Color.clear, lineWidth: 2.5)
                            )
                            .scaleEffect(on ? 1.0 : 0.9)
                            .opacity(on ? 1 : 0.75)
                        }
                        .buttonStyle(.plain)
                        .id(wp.id)
                        .accessibilityLabel("頻道 \(wp.number) \(wp.title)")
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 104)
            .onAppear { proxy.scrollTo(store.channelID, anchor: .center) }
            .onChange(of: store.channelID) { _, id in
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

struct Thumb: View {
    let wp: Wallpaper
    var body: some View {
        if let t = wp.thumb {
            Image(uiImage: t).resizable().scaledToFill()
        } else {
            Theme.panel
        }
    }
}

// MARK: - Full-screen preview

struct FullPreview: View {
    @EnvironmentObject var store: WallStore
    @Environment(\.dismiss) private var dismiss
    @State var startID: Int
    @State private var lock = true

    var body: some View {
        TabView(selection: $startID) {
            ForEach(Catalog.all) { wp in
                ZStack {
                    if let img = wp.image {
                        Image(uiImage: img).resizable().scaledToFill()
                    }
                    if lock { LockOverlay(scale: UIScreen.main.bounds.width / 390) }
                }
                .ignoresSafeArea()
                .tag(wp.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .background(Color.black)
        .statusBarHidden()
        .onTapGesture { withAnimation { lock.toggle() } }
        .overlay(alignment: .bottom) {
            HStack(spacing: 10) {
                Tag(text: "CH \(String(format: "%02d", startID))")
                Spacer()
                Button("設為目前頻道") {
                    store.select(startID)
                    Haptics.ok()
                    dismiss()
                }
                .buttonStyle(SlantButtonStyle())
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))
                .accessibilityLabel("關閉")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
}
