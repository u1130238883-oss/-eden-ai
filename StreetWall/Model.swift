import SwiftUI
import UIKit
import Photos

// MARK: - Catalog

enum Series: String, CaseIterable, Identifiable {
    case urban = "都市潮流"
    case lime = "黃綠系列"
    case neo = "街頭新番"
    case city = "霓虹街區"
    var id: String { rawValue }
    var code: String {
        switch self {
        case .urban: return "SER.A"
        case .lime: return "SER.B"
        case .neo: return "SER.C"
        case .city: return "SER.D"
        }
    }
}

struct Wallpaper: Identifiable, Hashable {
    let id: Int          // 1...82
    let title: String
    let tag: String
    let series: Series
    let accentHex: UInt32

    var file: String { String(format: "wp%02d", id) }
    var number: String { String(format: "%02d", id) }
    var accent: Color { Color(hex: accentHex) }

    /// 1–20 ship as PNG, 21+ as high-quality JPEG (keeps the IPA and source small).
    var fullURL: URL? {
        Bundle.main.url(forResource: file, withExtension: "png")
            ?? Bundle.main.url(forResource: file, withExtension: "jpg")
    }
    var thumbURL: URL? { Bundle.main.url(forResource: file + "_thumb", withExtension: "jpg") }

    var image: UIImage? { fullURL.flatMap { UIImage(contentsOfFile: $0.path) } }
    var thumb: UIImage? { thumbURL.flatMap { UIImage(contentsOfFile: $0.path) } }
}

enum Catalog {
    static let all: [Wallpaper] = [
        .init(id: 1, title: "NIGHT SHIFT", tag: "SECTOR 09 // ON AIR", series: .urban, accentHex: 0xE8FF3A),
        .init(id: 2, title: "HAZARD", tag: "KEEP OUT · UNSTABLE", series: .urban, accentHex: 0xFFC21A),
        .init(id: 3, title: "COMIC BURST", tag: "GO!! · NEXT EPISODE", series: .urban, accentHex: 0xFF2E88),
        .init(id: 4, title: "CRT STACK", tag: "NO SIGNAL · REC", series: .urban, accentHex: 0x3DFFB0),
        .init(id: 5, title: "GRAFFITI", tag: "WAS HERE '26", series: .urban, accentHex: 0xFF5BC8),
        .init(id: 6, title: "STICKER BOMB", tag: "STAY ODD · LVL UP", series: .urban, accentHex: 0x3D6BFF),
        .init(id: 7, title: "METRO LINES", tag: "LAST TRAIN 00:42", series: .urban, accentHex: 0x7A4DFF),
        .init(id: 8, title: "ARCADE TICKET", tag: "HIGH SCORE 999,990", series: .urban, accentHex: 0xFFD43B),
        .init(id: 9, title: "ROOFTOP", tag: "AFTER HOURS", series: .urban, accentHex: 0xFF8A3D),
        .init(id: 10, title: "OFFLINE", tag: "SIGNAL LOST · ERR 0x09", series: .urban, accentHex: 0xC8FF2E),
        .init(id: 11, title: "SIGNAL", tag: "FREQ 09.47 MHz", series: .lime, accentHex: 0xC6FF1A),
        .init(id: 12, title: "HANDLE WITH CARE", tag: "FRAGILE · THIS SIDE UP", series: .lime, accentHex: 0xD4FF2A),
        .init(id: 13, title: "RADAR", tag: "TARGET LOCKED", series: .lime, accentHex: 0xB8FF2E),
        .init(id: 14, title: "ZERO NINE", tag: "FW 26 / DROP", series: .lime, accentHex: 0x5DB800),
        .init(id: 15, title: "MARQUEE", tag: "GO GO GO", series: .lime, accentHex: 0xB6FF00),
        .init(id: 16, title: "EQUALIZER", tag: "BASS BOOST · 128 BPM", series: .lime, accentHex: 0xF2FF4A),
        .init(id: 17, title: "TILES", tag: "A · M · Y", series: .lime, accentHex: 0xC6FF1A),
        .init(id: 18, title: "ACCESS CARD", tag: "ACCESS GRANTED", series: .lime, accentHex: 0xC6FF1A),
        .init(id: 19, title: "THIS WAY", tag: "EXIT 09 · KEEP MOVING", series: .lime, accentHex: 0xD9FF2E),
        .init(id: 20, title: "LOW BATTERY", tag: "HIGH MOOD · 22%", series: .lime, accentHex: 0xFF4D2E),
        .init(id: 21, title: "NEON NOODLE", tag: "拉麵 · OPEN 24H", series: .neo, accentHex: 0xFF3D9A),
        .init(id: 22, title: "MIXTAPE", tag: "REWIND · REPEAT", series: .neo, accentHex: 0xFF6B2C),
        .init(id: 23, title: "ROUND 2", tag: "FIGHT! · 12 HITS", series: .neo, accentHex: 0xFFE14A),
        .init(id: 24, title: "VENDING", tag: "COLD DRINKS · 24H", series: .neo, accentHex: 0x2EE6FF),
        .init(id: 25, title: "PIXEL CITY", tag: "1-UP · DUSK", series: .neo, accentHex: 0xFF8A3D),
        .init(id: 26, title: "WANTED", tag: "REWARD ₵ 9,999,999", series: .neo, accentHex: 0xE8C27A),
        .init(id: 27, title: "SKATE", tag: "NO LIMIT · KICKFLIP", series: .neo, accentHex: 0xE8FF3A),
        .init(id: 28, title: "KEEP OUT", tag: "禁止進入 · DANGER", series: .neo, accentHex: 0xFFD21A),
        .init(id: 29, title: "MIDNIGHT RUN", tag: "PLAY ▶ · VHS", series: .neo, accentHex: 0xFF2E88),
        .init(id: 30, title: "FIZZ", tag: "LIME · ZERO", series: .neo, accentHex: 0x2EE6C9),
        .init(id: 31, title: "LINE 9", tag: "MIND THE GAP", series: .neo, accentHex: 0xFFC21A),
        .init(id: 32, title: "CONTINUE?", tag: "INSERT COIN", series: .neo, accentHex: 0xFF3D6E),
        .init(id: 33, title: "KARAOKE", tag: "ROOM 09 · ¥500/H", series: .city, accentHex: 0xD4FF1A),
        .init(id: 34, title: "NEON RIOT", tag: "STAGE B · 21:30", series: .city, accentHex: 0xD4FF1A),
        .init(id: 35, title: "HIGH VOLTAGE", tag: "高壓危險", series: .city, accentHex: 0xD4FF1A),
        .init(id: 36, title: "FLOPPY", tag: "SAVE BEFORE YOU QUIT", series: .city, accentHex: 0x121211),
        .init(id: 37, title: "BAM", tag: "COMIC SFX", series: .city, accentHex: 0xEAFF3A),
        .init(id: 38, title: "NEON AVE", tag: "霓虹大道", series: .city, accentHex: 0x1A1A18),
        .init(id: 39, title: "STAY ODD", tag: "LVL 99 · NO SLEEP", series: .city, accentHex: 0xD4FF1A),
        .init(id: 40, title: "NO SLEEP", tag: "TYPE POSTER", series: .city, accentHex: 0xDDFF2A),
        .init(id: 41, title: "RAIN", tag: "PIXEL CITY", series: .city, accentHex: 0xD4FF1A),
        .init(id: 42, title: "CHECKER", tag: "GRAPHIC PATTERN", series: .city, accentHex: 0xEAFF3A),
        .init(id: 43, title: "LIVE HOUSE", tag: "TONIGHT · DOORS 21:00", series: .city, accentHex: 0xEAFF3A),
        .init(id: 44, title: "LINE 9", tag: "UNLIMITED · 7 DAYS", series: .city, accentHex: 0xEAFF3A),
        .init(id: 45, title: "SLIPPERY", tag: "小心地滑", series: .city, accentHex: 0xEAFF3A),
        .init(id: 46, title: "PAGER", tag: "CALL ME 0909", series: .city, accentHex: 0x1A1A1A),
        .init(id: 47, title: "POW", tag: "COMIC SFX", series: .city, accentHex: 0xD4FF1A),
        .init(id: 48, title: "SIXTH ST", tag: "六街", series: .city, accentHex: 0x0B0B0A),
        .init(id: 49, title: "GLITCH", tag: "OK! · RUN", series: .city, accentHex: 0xEAFF3A),
        .init(id: 50, title: "STAY WILD", tag: "TYPE POSTER", series: .city, accentHex: 0x111111),
        .init(id: 51, title: "SNOW", tag: "PIXEL CITY", series: .city, accentHex: 0xFFFFFF),
        .init(id: 52, title: "TARGET", tag: "GRAPHIC PATTERN", series: .city, accentHex: 0xF7FFB3),
        .init(id: 53, title: "NO VACANCY", tag: "HOTEL ZONE 09", series: .city, accentHex: 0xDDFF2A),
        .init(id: 54, title: "ZONE 09", tag: "GATE C7 · SEAT 09A", series: .city, accentHex: 0xD4FF1A),
        .init(id: 55, title: "MAGNETIC FIELD", tag: "強磁場", series: .city, accentHex: 0xDDFF2A),
        .init(id: 56, title: "WALKMAN", tag: "AUTO REVERSE", series: .city, accentHex: 0xD4FF1A),
        .init(id: 57, title: "ZAP", tag: "COMIC SFX", series: .city, accentHex: 0xF7FFB3),
        .init(id: 58, title: "MIDNIGHT RD", tag: "午夜路", series: .city, accentHex: 0x2A2A26),
        .init(id: 59, title: "BIG MOOD", tag: "NOPE · YES", series: .city, accentHex: 0xF7FFB3),
        .init(id: 60, title: "HYPER DRIVE", tag: "TYPE POSTER", series: .city, accentHex: 0xEAFF3A),
        .init(id: 61, title: "SUNRISE", tag: "PIXEL CITY", series: .city, accentHex: 0xF7FFB3),
        .init(id: 62, title: "STRIPE", tag: "GRAPHIC PATTERN", series: .city, accentHex: 0xD4FF1A),
        .init(id: 63, title: "ARCADE", tag: "COIN-OP · 24H", series: .city, accentHex: 0xF7FFB3),
        .init(id: 64, title: "1 PLAY", tag: "VALID ALL CABINETS", series: .city, accentHex: 0xDDFF2A),
        .init(id: 65, title: "FALLING OBJECTS", tag: "注意落物", series: .city, accentHex: 0xF7FFB3),
        .init(id: 66, title: "HANDHELD", tag: "PRESS START", series: .city, accentHex: 0xD4FF1A),
        .init(id: 67, title: "WHAM", tag: "COMIC SFX", series: .city, accentHex: 0xEAFF3A),
        .init(id: 68, title: "ARCADE LN", tag: "電玩巷", series: .city, accentHex: 0x1E1E1B),
        .init(id: 69, title: "COOL", tag: "WOW · ZONE", series: .city, accentHex: 0x111111),
        .init(id: 70, title: "VOID MODE", tag: "TYPE POSTER", series: .city, accentHex: 0x111111),
        .init(id: 71, title: "PINK NIGHT", tag: "PIXEL CITY", series: .city, accentHex: 0xEAFF3A),
        .init(id: 72, title: "WAVE", tag: "GRAPHIC PATTERN", series: .city, accentHex: 0xEAFF3A),
        .init(id: 73, title: "BAR 09", tag: "HAPPY HOUR 18-20", series: .city, accentHex: 0xC2EE14),
        .init(id: 74, title: "VIP CLUB", tag: "No.000909 · BLACK", series: .city, accentHex: 0xEAFF3A),
        .init(id: 75, title: "LASER ZONE", tag: "雷射區域", series: .city, accentHex: 0xC2EE14),
        .init(id: 76, title: "RADIO", tag: "FM 90.9 · NIGHT", series: .city, accentHex: 0xD4FF1A),
        .init(id: 77, title: "BOOM", tag: "COMIC SFX", series: .city, accentHex: 0xD4FF1A),
        .init(id: 78, title: "DOCK 9", tag: "九號碼頭", series: .city, accentHex: 0x2A2A26),
        .init(id: 79, title: "CUTE", tag: "BUT · PSYCHO", series: .city, accentHex: 0x2A2A26),
        .init(id: 80, title: "LOUD &PROUD", tag: "TYPE POSTER", series: .city, accentHex: 0xEAFF3A),
        .init(id: 81, title: "MATRIX", tag: "PIXEL CITY", series: .city, accentHex: 0xD4FF1A),
        .init(id: 82, title: "STARS", tag: "GRAPHIC PATTERN", series: .city, accentHex: 0xEAFF3A),
    ]

    static func byID(_ id: Int) -> Wallpaper? { all.first { $0.id == id } }
}

// MARK: - Pick mode (shared with App Intents)

enum PickMode: String, CaseIterable, Identifiable {
    case sequential, random, favorites
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sequential: return "順序輪播"
        case .random: return "隨機抽選"
        case .favorites: return "收藏隨機"
        }
    }
    var code: String {
        switch self {
        case .sequential: return "SEQ"
        case .random: return "RND"
        case .favorites: return "FAV"
        }
    }
}

// MARK: - Persistent state

enum Keys {
    static let channel = "sw.channel"
    static let favorites = "sw.favorites"
    static let mode = "sw.mode"
    static let shortcutName = "sw.shortcutName2"  // v2: new shortcut name, resets old setups
    static let lastSwitch = "sw.lastSwitch"
}

/// Thread-safe, UserDefaults-backed logic used by both the UI and App Intents.
enum Rotation {
    static var defaults: UserDefaults { .standard }

    static var channelID: Int {
        get {
            let v = defaults.integer(forKey: Keys.channel)
            return Catalog.byID(v) == nil ? 1 : v
        }
        set { defaults.set(newValue, forKey: Keys.channel) }
    }

    static var favorites: Set<Int> {
        get { Set(defaults.array(forKey: Keys.favorites) as? [Int] ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Keys.favorites) }
    }

    static var mode: PickMode {
        get { PickMode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .sequential }
        set { defaults.set(newValue.rawValue, forKey: Keys.mode) }
    }

    static var current: Wallpaper { Catalog.byID(channelID) ?? Catalog.all[0] }

    /// Move to the next wallpaper according to `mode`, persist and return it.
    @discardableResult
    static func advance(mode: PickMode? = nil) -> Wallpaper {
        let m = mode ?? self.mode
        let cur = channelID
        var pool: [Wallpaper]
        switch m {
        case .sequential:
            let next = cur % Catalog.all.count + 1
            channelID = next
            defaults.set(Date().timeIntervalSinceReferenceDate, forKey: Keys.lastSwitch)
            return current
        case .random:
            pool = Catalog.all
        case .favorites:
            let favs = favorites
            pool = Catalog.all.filter { favs.contains($0.id) }
            if pool.isEmpty { pool = Catalog.all }
        }
        if pool.count > 1 { pool.removeAll { $0.id == cur } }
        let pick = pool.randomElement() ?? Catalog.all[0]
        channelID = pick.id
        defaults.set(Date().timeIntervalSinceReferenceDate, forKey: Keys.lastSwitch)
        return pick
    }

    /// Re-encoded PNG data (safe to hand to other apps / Shortcuts).
    static func pngData(for wp: Wallpaper) -> Data? {
        if let url = wp.fullURL, let d = try? Data(contentsOf: url) { return d }
        return wp.image?.pngData()
    }
}

// MARK: - Observable store for the UI

@MainActor
final class WallStore: ObservableObject {
    static let shared = WallStore()

    @Published var channelID: Int = Rotation.channelID
    @Published var favorites: Set<Int> = Rotation.favorites
    @Published var mode: PickMode = Rotation.mode

    var current: Wallpaper { Catalog.byID(channelID) ?? Catalog.all[0] }
    var index: Int { Catalog.all.firstIndex(of: current) ?? 0 }

    func reload() {
        channelID = Rotation.channelID
        favorites = Rotation.favorites
        mode = Rotation.mode
    }

    func select(_ id: Int) {
        guard Catalog.byID(id) != nil else { return }
        Rotation.channelID = id
        channelID = id
    }

    func step(_ delta: Int) {
        let n = Catalog.all.count
        let i = ((index + delta) % n + n) % n
        select(Catalog.all[i].id)
    }

    func shuffle() {
        let wp = Rotation.advance(mode: mode == .sequential ? .random : mode)
        channelID = wp.id
    }

    func toggleFavorite(_ id: Int) {
        var f = favorites
        if f.contains(id) { f.remove(id) } else { f.insert(id) }
        Rotation.favorites = f
        favorites = f
    }

    func setMode(_ m: PickMode) {
        Rotation.mode = m
        mode = m
    }
}

// MARK: - Photos

enum PhotoSaver {
    enum SaveError: LocalizedError {
        case denied
        var errorDescription: String? { "沒有相簿寫入權限，請到 設定 → 隱私 → 照片 開啟。" }
    }

    static func save(_ wallpapers: [Wallpaper]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.denied }
        let urls = wallpapers.compactMap(\.fullURL)
        try await PHPhotoLibrary.shared().performChanges {
            for u in urls {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: u)
            }
        }
    }

    static func save(image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.denied }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

// MARK: - Helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}
