import SwiftUI
import UniformTypeIdentifiers

/// Where a wallpaper goes. Each target has its own pre-made shortcut, so a
/// problem with one (e.g. iOS rejecting the Home Screen option) can't break the rest.
enum WallTarget: String, CaseIterable, Identifiable {
    case lock, home, both
    var id: String { rawValue }

    /// Shortcut name, identical to the bundled `<name>.shortcut` file.
    var shortcut: String {
        switch self {
        case .lock: return "潮流換壁紙"
        case .home: return "潮流換壁紙主畫面"
        case .both: return "潮流換壁紙兩者"
        }
    }
    var label: String {
        switch self {
        case .lock: return "設為鎖定畫面"
        case .home: return "設為主畫面"
        case .both: return "鎖定畫面＋主畫面"
        }
    }
    var short: String {
        switch self {
        case .lock: return "鎖定畫面"
        case .home: return "主畫面"
        case .both: return "鎖定＋主畫面"
        }
    }
    var icon: String {
        switch self {
        case .lock: return "lock.fill"
        case .home: return "square.grid.2x2.fill"
        case .both: return "rectangle.on.rectangle"
        }
    }
    var bundled: URL? { Bundle.main.url(forResource: shortcut, withExtension: "shortcut") }
}

/// Drives 一鍵套用. iOS lets only the Shortcuts app change the wallpaper, so we put the
/// PNG on the clipboard, run the matching shortcut via x-callback-url and come back here.
@MainActor
final class ApplyCenter: ObservableObject {
    static let scheme = "streetwall"
    static let autoShortcut = "潮流自動換壁紙"
    static var autoBundled: URL? { Bundle.main.url(forResource: autoShortcut, withExtension: "shortcut") }

    /// Shortcut names the user has successfully run at least once.
    @AppStorage("sw.readyTargets6") private var readyRaw = ""
    @AppStorage("sw.autoTarget") var autoTargetRaw = WallTarget.lock.rawValue

    @Published var showSetup = false
    @Published var setupError: String?
    /// One-time guide: switch the Home Screen from "Colore" to "Coppia" in Settings.
    @Published var showHomeGuide = false
    @AppStorage("sw.homeGuideDone") var homeGuideDone = false
    /// Target whose shortcut the setup sheet installs / tests.
    @Published var pending: WallTarget = .lock
    /// Image waiting for the shortcut (current channel or a generated wallpaper).
    private var pendingData: Data?
    private var runningAuto = false

    var autoTarget: WallTarget {
        get { WallTarget(rawValue: autoTargetRaw) ?? .lock }
        set { autoTargetRaw = newValue.rawValue }
    }

    func isReady(_ t: WallTarget) -> Bool { readyRaw.split(separator: ",").contains(Substring(t.rawValue)) }
    private func setReady(_ t: WallTarget, _ v: Bool) {
        var s = Set(readyRaw.split(separator: ",").map(String.init))
        if v { s.insert(t.rawValue) } else { s.remove(t.rawValue) }
        readyRaw = s.sorted().joined(separator: ",")
    }

    // MARK: entry points

    /// 一鍵套用 for the current channel.
    func apply(_ target: WallTarget, toaster: Toaster) {
        guard let data = WallStore.shared.current.fullURL.flatMap({ try? Data(contentsOf: $0) }) else {
            toaster.show("讀取壁紙失敗"); return
        }
        apply(data: data, to: target, toaster: toaster)
    }

    /// 一鍵套用 for any PNG (used by the generator too).
    func apply(data: Data, to target: WallTarget, toaster: Toaster) {
        Haptics.tap()
        pending = target
        pendingData = data
        guard isReady(target) else {
            setupError = nil
            showSetup = true
            return
        }
        run(toaster: toaster)
    }

    func openSetup(_ target: WallTarget) {
        pending = target
        setupError = nil
        showSetup = true
    }

    /// Copies the pending image and runs the pending target's shortcut.
    func run(toaster: Toaster) {
        let data = pendingData ?? WallStore.shared.current.fullURL.flatMap { try? Data(contentsOf: $0) }
        guard let data else { toaster.show("讀取壁紙失敗"); return }
        UIPasteboard.general.setItems(
            [[(data.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? UTType.png : UTType.jpeg).identifier: data]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)]
        )
        launch(pending.shortcut)
    }

    /// Called by the 潮流自動換壁紙 shortcut (streetwall://auto): next channel, then apply.
    func runAuto(toaster: Toaster) {
        let wp = Rotation.advance()
        WallStore.shared.reload()
        guard let data = wp.fullURL.flatMap({ try? Data(contentsOf: $0) }) else { return }
        runningAuto = true
        toaster.show("自動換台 → CH \(wp.number) \(wp.title)")
        pending = autoTarget
        pendingData = data
        // Give the app a moment to come to the foreground before switching to Shortcuts.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            self.run(toaster: toaster)
        }
    }

    private func launch(_ name: String) {
        var c = URLComponents()
        c.scheme = "shortcuts"
        c.host = "x-callback-url"
        c.path = "/run-shortcut"
        c.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "x-success", value: "\(Self.scheme)://applied"),
            URLQueryItem(name: "x-error", value: "\(Self.scheme)://shortcut-error"),
            URLQueryItem(name: "x-cancel", value: "\(Self.scheme)://shortcut-cancel"),
        ]
        guard let url = c.url else { return }
        UIApplication.shared.open(url) { ok in
            if !ok {
                Task { @MainActor in
                    self.setupError = "打不開「捷徑」App。請到 App Store 重新安裝「捷徑」(Shortcuts)。"
                    self.showSetup = true
                }
            }
        }
    }

    /// Best effort: jump to Settings → Wallpaper (falls back to the Settings app).
    func openWallpaperSettings() {
        let candidates = ["App-prefs:Wallpaper", "prefs:root=Wallpaper", "App-prefs:", UIApplication.openSettingsURLString]
        func tryOpen(_ i: Int) {
            guard i < candidates.count, let u = URL(string: candidates[i]) else { return }
            UIApplication.shared.open(u) { ok in
                if !ok { Task { @MainActor in tryOpen(i + 1) } }
            }
        }
        tryOpen(0)
    }

    func openShortcuts() {
        if let u = URL(string: "shortcuts://") { UIApplication.shared.open(u) }
    }

    func handle(_ url: URL, toaster: Toaster) {
        guard url.scheme == Self.scheme else { return }
        switch url.host {
        case "auto", "next":
            runAuto(toaster: toaster)
        case "applied":
            setReady(pending, true)
            showSetup = false
            Haptics.ok()
            toaster.show(runningAuto ? "自動換壁紙完成 ✓" : "已設為\(pending.short) ✓")
            if pending != .lock && !homeGuideDone && !runningAuto {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    self.showHomeGuide = true
                }
            }
            runningAuto = false
        case "shortcut-error":
            setReady(pending, false)
            runningAuto = false
            let msg = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "errorMessage" }?.value
            setupError = "「\(pending.shortcut)」捷徑沒有執行成功。請照下面步驟安裝（或重新安裝）它。" +
                (msg.map { "\n(\($0))" } ?? "")
            showSetup = true
            Haptics.fail()
        case "shortcut-cancel":
            runningAuto = false
            toaster.show("已取消")
        default:
            break
        }
    }
}

// MARK: - Setup guide sheet

struct ShortcutSetupSheet: View {
    @EnvironmentObject var center: ApplyCenter
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var store: WallStore
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false

    var body: some View {
        let t = center.pending
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ONE-TAP SETUP").font(.mono(11)).tracking(3).foregroundStyle(Theme.dim)
                        Text("設定「\(t.short)」").font(.display(30)).foregroundStyle(Theme.paper)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))
                        .accessibilityLabel("關閉")
                }

                // which target
                HStack(spacing: 8) {
                    ForEach(WallTarget.allCases) { x in
                        Button {
                            Haptics.tap()
                            center.pending = x
                            center.setupError = nil
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: x.icon).font(.system(size: 15, weight: .heavy))
                                Text(x.short).font(.display(14)).lineLimit(1).minimumScaleFactor(0.7)
                                Text(center.isReady(x) ? "已安裝" : "未安裝").font(.mono(9)).opacity(0.75)
                            }
                            .foregroundStyle(t == x ? Theme.ink : Theme.paper)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Slant(cut: 9).fill(t == x ? Theme.acid : Theme.panel2))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let err = center.setupError {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(err).font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CutPanel(cut: 12).fill(Theme.hot))
                }

                VStack(alignment: .leading, spacing: 12) {
                    row("1", "按下面「安裝『\(t.shortcut)』」，在分享選單裡選「捷徑」(Comandi rapidi)。")
                    row("2", "按「加入捷徑」(Aggiungi comando rapido)。如果問要不要取代，選「取代」(Sostituisci)。")
                    row("3", "按「測試」。第一次會問能否讀取剪貼簿、能否設定桌布，都選「永遠允許」(Consenti sempre)。")
                    if t != .lock {
                        row("!", "主畫面版本還在測試中。如果它出錯：改用「鎖定畫面」，再到 設定 (Impostazioni) → 桌布 (Sfondo) → 主畫面 → 選「配對」(Coppia)，主畫面就會自動跟鎖定畫面同一張。")
                    }
                }
                .padding(14)
                .background(CutPanel(cut: 14).fill(Theme.panel))
                .overlay(CutPanel(cut: 14).stroke(Theme.line, lineWidth: 1))

                if let file = t.bundled {
                    ShareLink(item: file) {
                        Label("安裝『\(t.shortcut)』", systemImage: "square.and.arrow.down.on.square")
                            .font(.display(19))
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Slant().fill(Theme.acid))
                    }
                } else {
                    Text("這個版本沒有內建捷徑檔（建置時簽名失敗）。").font(.mono(11)).foregroundStyle(Theme.hot)
                }

                Button {
                    center.run(toaster: toaster)
                } label: {
                    Label("測試：設為\(t.short)", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                }
                .buttonStyle(SlantButtonStyle(fill: Theme.acid, outline: true))

                Text("不想用捷徑？也可以先存進相簿，再到「照片」→ 分享 → 「用作桌布」。")
                    .font(.mono(11)).foregroundStyle(Theme.dim)
                Button {
                    saving = true
                    let wp = store.current
                    Task {
                        do {
                            try await PhotoSaver.save([wp])
                            Haptics.ok()
                            toaster.show("CH \(wp.number) 已存入相簿")
                        } catch {
                            toaster.show(error.localizedDescription)
                        }
                        saving = false
                    }
                } label: {
                    Label(saving ? "保存中" : "改為存入相簿", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                }
                .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))
                .disabled(saving)
            }
            .padding(16)
        }
        .background(Theme.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func row(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n).font(.mono(12)).foregroundStyle(Theme.ink)
                .frame(width: 24, height: 24).background(Slant(cut: 5).fill(Theme.acid))
            Text(text).font(.system(size: 14)).foregroundStyle(Theme.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Home Screen one-time guide

/// iOS keeps the Home Screen in "Colore" (solid colour) mode no matter what image a
/// shortcut sets, and shortcuts cannot change that mode - so the user flips it once.
struct HomeGuideSheet: View {
    @EnvironmentObject var center: ApplyCenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HOME SCREEN FIX").font(.mono(11)).tracking(3).foregroundStyle(Theme.dim)
                        Text("主畫面還是純色？").font(.display(30)).foregroundStyle(Theme.paper)
                    }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))
                        .accessibilityLabel("關閉")
                }

                Text("鎖定畫面已經換好了。主畫面變純色，是因為 iOS 把主畫面設成了「顏色」(Colore) 模式，捷徑沒有權限改這個模式。只要手動改一次，之後每次套用主畫面都會跟著換。")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(CutPanel(cut: 12).fill(Theme.acid))

                VStack(alignment: .leading, spacing: 12) {
                    row("1", "按下面「打開設定」，進入 設定 → 桌布 (Impostazioni → Sfondo)。如果只打開了設定首頁，就往下找「Sfondo」。")
                    row("2", "在目前這組桌布下面，點右邊的「主畫面」那張（Schermata Home / 自訂 Personalizza）。")
                    row("3", "底部選第一個選項「配對」(Coppia)——就是跟鎖定畫面同一張圖。不要選「顏色」(Colore)。")
                    row("4", "如果有「模糊」(Sfocatura) 開關，把它關掉，主畫面才會清楚。")
                    row("5", "按右上「完成」(Fine)。回到這裡按「我設好了」。")
                }
                .padding(14)
                .background(CutPanel(cut: 14).fill(Theme.panel))
                .overlay(CutPanel(cut: 14).stroke(Theme.line, lineWidth: 1))

                Button {
                    center.openWallpaperSettings()
                } label: {
                    Label("打開設定", systemImage: "gearshape.fill")
                        .font(.display(19))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Slant().fill(Theme.acid))
                }
                .buttonStyle(.plain)

                Button {
                    center.homeGuideDone = true
                    dismiss()
                } label: {
                    Label("我設好了", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))

                Text("設好「配對」之後，用「設為鎖定畫面」也會同時換主畫面。之後想再看這個說明：自動 分頁 → 主畫面是純色？")
                    .font(.mono(11)).foregroundStyle(Theme.dim)
            }
            .padding(16)
        }
        .background(Theme.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func row(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n).font(.mono(12)).foregroundStyle(Theme.ink)
                .frame(width: 24, height: 24).background(Slant(cut: 5).fill(Theme.acid))
            Text(text).font(.system(size: 14)).foregroundStyle(Theme.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
