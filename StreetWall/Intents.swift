import AppIntents
import UniformTypeIdentifiers

// Exposed to the Shortcuts app so users can chain: [下一張壁紙] → [設定壁紙].

enum PickModeEntity: String, AppEnum {
    case sequential, random, favorites

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "切換模式"
    static var caseDisplayRepresentations: [PickModeEntity: DisplayRepresentation] = [
        .sequential: "順序輪播",
        .random: "隨機抽選",
        .favorites: "收藏隨機",
    ]

    var mode: PickMode { PickMode(rawValue: rawValue) ?? .sequential }
}

private func file(for wp: Wallpaper) throws -> IntentFile {
    guard let data = Rotation.pngData(for: wp) else {
        throw IntentError.missing
    }
    let isPNG = data.starts(with: [0x89, 0x50, 0x4E, 0x47])
    return IntentFile(data: data, filename: "\(wp.file).\(isPNG ? "png" : "jpg")", type: isPNG ? .png : .jpeg)
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case missing
    var localizedStringResource: LocalizedStringResource { "找不到壁紙圖片" }
}

private func refreshUI() async {
    await MainActor.run { WallStore.shared.reload() }
}

struct NextWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "下一張壁紙"
    static var description = IntentDescription("切換到下一個頻道，並輸出壁紙圖片。之後接「設定壁紙」動作即可自動換桌布。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "模式", default: .sequential)
    var mode: PickModeEntity

    static var parameterSummary: some ParameterSummary {
        Summary("以 \(\.$mode) 取得下一張壁紙")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let wp = Rotation.advance(mode: mode.mode)
        let f = try file(for: wp)
        await refreshUI()
        return .result(value: f)
    }
}

struct CurrentWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "目前頻道壁紙"
    static var description = IntentDescription("輸出 App 內目前選中頻道的壁紙圖片。")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let f = try file(for: Rotation.current)
        return .result(value: f)
    }
}

struct ChannelWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "指定頻道壁紙"
    static var description = IntentDescription("輸出指定編號（1–82）的壁紙圖片，並切到該頻道。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "頻道", default: 1, inclusiveRange: (1, 82))
    var channel: Int

    static var parameterSummary: some ParameterSummary {
        Summary("取得頻道 \(\.$channel) 的壁紙")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        guard let wp = Catalog.byID(channel) else { throw IntentError.missing }
        Rotation.channelID = wp.id
        let f = try file(for: wp)
        await refreshUI()
        return .result(value: f)
    }
}

struct StreetWallShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextWallpaperIntent(),
            phrases: [
                "\(.applicationName) 下一張壁紙",
                "用 \(.applicationName) 換壁紙",
            ],
            shortTitle: "下一張壁紙",
            systemImageName: "tv"
        )
        AppShortcut(
            intent: CurrentWallpaperIntent(),
            phrases: ["\(.applicationName) 目前壁紙"],
            shortTitle: "目前頻道壁紙",
            systemImageName: "photo"
        )
    }
}
