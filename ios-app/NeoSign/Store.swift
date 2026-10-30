import Foundation
import SwiftUI
import UIKit

// MARK: - 數據模型

struct CertRecord: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var expires: Date
    var password: String
    var profileName: String
    var profileKind: String
    var profileExpires: Date
    var appID: String
    var devices: [String]
    var importedAt: Date

    var isExpired: Bool { min(expires, profileExpires) < Date() }
    var daysLeft: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: min(expires, profileExpires)).day ?? 0)
    }
}

struct AppRecord: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var bundleID: String
    var version: String
    var size: Int64
    var importedAt: Date
    var signedAt: Date?
    var signedWith: String?
    var signedFile: String?
}

struct AppError: LocalizedError {
    var message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum CertFailure: Error {
    case wrongPassword
}

/// 密碼不對時，暫存文件等用戶輸入密碼。
struct PendingCert: Identifiable {
    let id = UUID()
    var p12: URL
    var profile: URL
    var triedPassword: Bool
}

// MARK: - 存儲位置

enum Storage {
    static let root: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NeoSign", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let certs = folder("Certs")
    static let apps = folder("Apps")

    static func folder(_ name: String) -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func size(of dir: URL) -> Int64 {
        let walker = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let file = walker?.nextObject() as? URL {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    static func certDir(_ id: String) -> URL { certs.appendingPathComponent(id, isDirectory: true) }
    static func appDir(_ id: String) -> URL { apps.appendingPathComponent(id, isDirectory: true) }

    static func save<T: Encodable>(_ value: T, in dir: URL) throws {
        try JSONEncoder().encode(value).write(to: dir.appendingPathComponent("meta.json"), options: .atomic)
    }

    static func loadAll<T: Decodable>(_ type: T.Type, in dir: URL) -> [T] {
        let subs = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return subs.compactMap { sub in
            guard let data = try? Data(contentsOf: sub.appendingPathComponent("meta.json")) else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }
    }
}

/// 把耗時工作放到後台線程。
func offMain<T>(_ work: @escaping () throws -> T) async throws -> T {
    try await Task.detached(priority: .userInitiated) { try work() }.value
}

// MARK: - Store

@MainActor
final class Store: ObservableObject {
    @Published private(set) var certs: [CertRecord] = []
    @Published private(set) var apps: [AppRecord] = []
    @Published var busy: String?
    @Published var toast: String?
    @Published var passwordPrompt: PendingCert?
    @Published var selectedCertID: String {
        didSet { UserDefaults.standard.set(selectedCertID, forKey: "selectedCert") }
    }

    private var stagedP12: URL?
    private var stagedProfile: URL?

    init() {
        selectedCertID = UserDefaults.standard.string(forKey: "selectedCert") ?? ""
        certs = Storage.loadAll(CertRecord.self, in: Storage.certs).sorted { $0.importedAt > $1.importedAt }
        apps = Storage.loadAll(AppRecord.self, in: Storage.apps).sorted { $0.importedAt > $1.importedAt }
        if !certs.contains(where: { $0.id == selectedCertID }) {
            selectedCertID = certs.first?.id ?? ""
        }
    }

    var selectedCert: CertRecord? { certs.first { $0.id == selectedCertID } ?? certs.first }

    func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if toast == message { toast = nil }
        }
    }

    // MARK: 導入

    func importFiles(_ urls: [URL]) {
        Task {
            for url in urls {
                await importOne(url)
            }
        }
    }

    private func importOne(_ url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let ext = url.pathExtension.lowercased()
            guard ["ipa", "zip", "p12", "pfx", "mobileprovision"].contains(ext) else {
                throw AppError("不支持這個文件：\(url.lastPathComponent)")
            }
            busy = "讀取 \(url.lastPathComponent)"
            let local: URL
            do {
                local = try await localCopy(of: url)
            } catch {
                busy = nil
                throw AppError("讀取文件失敗：\(error.localizedDescription)")
            }
            busy = nil
            switch ext {
            case "ipa":
                try await importIPA(local)
            case "zip":
                try await importCertZip(local)
            case "p12", "pfx":
                stagedP12 = local
                try await importStaged()
            default:
                stagedProfile = local
                try await importStaged()
            }
        } catch {
            show(error.localizedDescription)
        }
    }

    /// 先把文件複製到 App 自己的臨時目錄。iCloud Drive 裡的文件可能還沒下載到手機，
    /// 用 NSFileCoordinator 讀取會讓系統先下載好。
    private func localCopy(of url: URL) async throws -> URL {
        // 文件選擇器已經複製到 App 的臨時目錄了，直接用，省掉一次大文件複製
        let tempRoot = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path
        if url.resolvingSymlinksInPath().path.hasPrefix(tempRoot) {
            return url
        }
        return try await offMain {
            var coordinatorError: NSError?
            var result: Result<URL, Error> = .failure(AppError("讀取文件失敗"))
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readable in
                do {
                    let dest = Storage.tempDir().appendingPathComponent(url.lastPathComponent)
                    try FileManager.default.copyItem(at: readable, to: dest)
                    result = .success(dest)
                } catch {
                    result = .failure(error)
                }
            }
            if let coordinatorError { throw coordinatorError }
            return try result.get()
        }
    }

    private func importIPA(_ url: URL) async throws {
        busy = "導入 \(url.lastPathComponent)"
        defer { busy = nil }
        let record = try await offMain { try IPATools.importIPA(from: url) }
        apps.insert(record, at: 0)
        show("已導入 \(record.name)")
    }

    private func importCertZip(_ url: URL) async throws {
        busy = "讀取證書"
        defer { busy = nil }
        let found = try await offMain { try CertTools.unpackZip(url) }
        await addCert(p12: found.p12, profile: found.profile, password: found.password ?? "")
    }

    private func importStaged() async throws {
        guard let p12 = stagedP12 else {
            show("已選描述文件，再導入 .p12 證書")
            return
        }
        guard let profile = stagedProfile else {
            show("已選 p12，再導入 .mobileprovision 描述文件")
            return
        }
        stagedP12 = nil
        stagedProfile = nil
        await askPassword(PendingCert(p12: p12, profile: profile, triedPassword: false))
    }

    /// 文件選擇器關閉的動畫還沒結束時彈窗會被系統吞掉，所以稍等一下再彈。
    private func askPassword(_ pending: PendingCert) async {
        try? await Task.sleep(nanoseconds: 800_000_000)
        passwordPrompt = pending
    }

    func addCert(p12: URL, profile: URL, password: String) async {
        do {
            let record = try await offMain { try CertTools.install(p12: p12, profile: profile, password: password) }
            certs.insert(record, at: 0)
            selectedCertID = record.id
            show("證書已導入")
        } catch CertFailure.wrongPassword {
            await askPassword(PendingCert(p12: p12, profile: profile, triedPassword: !password.isEmpty))
        } catch {
            show(error.localizedDescription)
        }
    }

    // MARK: 刪除

    func delete(_ app: AppRecord) {
        try? FileManager.default.removeItem(at: Storage.appDir(app.id))
        apps.removeAll { $0.id == app.id }
    }

    func delete(_ cert: CertRecord) {
        try? FileManager.default.removeItem(at: Storage.certDir(cert.id))
        certs.removeAll { $0.id == cert.id }
        if selectedCertID == cert.id { selectedCertID = certs.first?.id ?? "" }
    }

    // MARK: 緩存

    /// 所有安裝包（原始 IPA + 簽好的 IPA）和臨時文件佔用的空間。
    func cacheSize() async -> Int64 {
        (try? await offMain {
            [Storage.apps, FileManager.default.temporaryDirectory].reduce(Int64(0)) { $0 + Storage.size(of: $1) }
        }) ?? 0
    }

    func clearCache() async {
        busy = "清除緩存"
        let freed = await cacheSize()
        _ = try? await offMain {
            let fm = FileManager.default
            for dir in [Storage.apps, fm.temporaryDirectory] {
                for item in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
                    try? fm.removeItem(at: item)
                }
            }
        }
        apps = []
        stagedP12 = nil
        stagedProfile = nil
        busy = nil
        show("已清除，釋放 \(freed.fileSize)")
    }

    // MARK: 簽名

    func icon(for app: AppRecord) -> UIImage? {
        UIImage(contentsOfFile: Storage.appDir(app.id).appendingPathComponent("icon.png").path)
    }

    func signedURL(for app: AppRecord) -> URL? {
        guard let file = app.signedFile else { return nil }
        let url = Storage.appDir(app.id).appendingPathComponent(file)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func logURL(for app: AppRecord) -> URL {
        Storage.appDir(app.id).appendingPathComponent("sign.log")
    }

    func sign(_ app: AppRecord, with cert: CertRecord, bundleID: String, name: String, version: String) async throws -> AppRecord {
        let dir = Storage.appDir(app.id)
        let certDir = Storage.certDir(cert.id)
        let fileName = IPATools.safeFileName(name.isEmpty ? app.name : name) + "_signed.ipa"
        let output = dir.appendingPathComponent(fileName)
        let log = logURL(for: app)

        if let old = app.signedFile {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(old))
        }

        let code = try await offMain { () -> Int32 in
            let temp = Storage.tempDir()
            defer { try? FileManager.default.removeItem(at: temp) }
            return zs_sign_ipa(certDir.appendingPathComponent("cert.p12").path,
                               cert.password,
                               certDir.appendingPathComponent("cert.mobileprovision").path,
                               dir.appendingPathComponent("source.ipa").path,
                               output.path,
                               temp.path,
                               bundleID, name, version,
                               log.path)
        }
        guard code == 0 else {
            throw AppError("簽名失敗（錯誤碼 \(code)），可以查看日誌")
        }

        var updated = app
        updated.signedAt = Date()
        updated.signedWith = cert.name
        updated.signedFile = fileName
        try Storage.save(updated, in: dir)
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index] = updated
        }
        return updated
    }
}

// MARK: - 證書處理

enum CertTools {
    static func unpackZip(_ zip: URL) throws -> (p12: URL, profile: URL, password: String?) {
        let temp = Storage.tempDir()
        guard zs_unzip(zip.path, temp.path) == 0 else {
            throw AppError("zip 解壓失敗")
        }
        var p12: URL?
        var profile: URL?
        var password: String?
        let walker = FileManager.default.enumerator(at: temp, includingPropertiesForKeys: nil)
        while let file = walker?.nextObject() as? URL {
            if file.lastPathComponent.hasPrefix(".") || file.path.contains("__MACOSX") { continue }
            switch file.pathExtension.lowercased() {
            case "p12", "pfx":
                p12 = file
            case "mobileprovision":
                profile = file
            case "txt":
                // 賣家通常寫成「證書密碼: 1」
                if let text = try? String(contentsOf: file, encoding: .utf8) {
                    password = text.components(separatedBy: CharacterSet(charactersIn: ":：")).last?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            default:
                break
            }
        }
        guard let p12, let profile else {
            throw AppError("zip 裡沒有找到 .p12 和 .mobileprovision")
        }
        return (p12, profile, password)
    }

    static func install(p12: URL, profile: URL, password: String) throws -> CertRecord {
        var nameBuffer = [CChar](repeating: 0, count: 512)
        var notAfter: Int64 = 0
        let result = zs_cert_info(p12.path, password, &nameBuffer, Int32(nameBuffer.count), &notAfter)
        if result == -1 { throw CertFailure.wrongPassword }
        guard result == 0 else { throw AppError("p12 證書文件無效") }

        guard let info = ProfileInfo.parse(try Data(contentsOf: profile)) else {
            throw AppError("描述文件無效")
        }

        let id = UUID().uuidString
        let dir = Storage.certDir(id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: p12, to: dir.appendingPathComponent("cert.p12"))
        try FileManager.default.copyItem(at: profile, to: dir.appendingPathComponent("cert.mobileprovision"))

        let nameBytes = nameBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let record = CertRecord(id: id,
                                name: String(decoding: nameBytes, as: UTF8.self),
                                expires: Date(timeIntervalSince1970: TimeInterval(notAfter)),
                                password: password,
                                profileName: info.name,
                                profileKind: info.kind,
                                profileExpires: info.expires,
                                appID: info.appID,
                                devices: info.devices,
                                importedAt: Date())
        try Storage.save(record, in: dir)
        return record
    }
}

struct ProfileInfo {
    var name: String
    var kind: String
    var expires: Date
    var appID: String
    var devices: [String]

    /// mobileprovision 是 CMS 簽名包，裡面嵌著一段 XML plist，直接截出來解析。
    static func parse(_ data: Data) -> ProfileInfo? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any]
        else { return nil }

        let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
        let devices = plist["ProvisionedDevices"] as? [String] ?? []
        let kind: String
        if plist["ProvisionsAllDevices"] as? Bool == true {
            kind = "企業"
        } else if devices.isEmpty {
            kind = "App Store"
        } else if entitlements["get-task-allow"] as? Bool == true {
            kind = "開發"
        } else {
            kind = "Ad Hoc"
        }
        return ProfileInfo(name: plist["Name"] as? String ?? "?",
                           kind: kind,
                           expires: plist["ExpirationDate"] as? Date ?? .distantPast,
                           appID: entitlements["application-identifier"] as? String ?? "?",
                           devices: devices)
    }
}

// MARK: - IPA 處理

enum IPATools {
    static func importIPA(from source: URL) throws -> AppRecord {
        let id = UUID().uuidString
        let dir = Storage.appDir(id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ipa = dir.appendingPathComponent("source.ipa")
        do {
            try FileManager.default.moveItem(at: source, to: ipa)
            let info = try inspect(ipa: ipa, iconOut: dir.appendingPathComponent("icon.png"))
            let size = (try? FileManager.default.attributesOfItem(atPath: ipa.path)[.size] as? NSNumber)?.int64Value ?? 0
            let record = AppRecord(id: id, name: info.name, bundleID: info.bundleID, version: info.version,
                                   size: size, importedAt: Date())
            try Storage.save(record, in: dir)
            return record
        } catch {
            try? FileManager.default.removeItem(at: dir)
            throw error
        }
    }

    static func inspect(ipa: URL, iconOut: URL) throws -> (name: String, bundleID: String, version: String) {
        let temp = Storage.tempDir()
        defer { try? FileManager.default.removeItem(at: temp) }
        guard zs_unzip_app_meta(ipa.path, temp.path) == 0 else {
            throw AppError("不是有效的 IPA 文件")
        }
        let payload = temp.appendingPathComponent("Payload")
        guard let appDir = (try? FileManager.default.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil))?
                .first(where: { $0.pathExtension == "app" }),
              let plist = NSDictionary(contentsOf: appDir.appendingPathComponent("Info.plist")) as? [String: Any]
        else {
            throw AppError("不是有效的 IPA 文件")
        }
        extractIcon(appDir: appDir, plist: plist, to: iconOut)
        let name = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? appDir.deletingPathExtension().lastPathComponent
        return (name,
                plist["CFBundleIdentifier"] as? String ?? "?",
                plist["CFBundleShortVersionString"] as? String ?? plist["CFBundleVersion"] as? String ?? "1.0")
    }

    private static func extractIcon(appDir: URL, plist: [String: Any], to output: URL) {
        var names: [String] = []
        if let icons = plist["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String] {
            names += files
        }
        if let file = plist["CFBundleIconFile"] as? String { names.append(file) }
        if let files = plist["CFBundleIconFiles"] as? [String] { names += files }
        names = names.map { $0.replacingOccurrences(of: ".png", with: "") }
        if names.isEmpty { names = ["AppIcon"] }

        let files = (try? FileManager.default.contentsOfDirectory(atPath: appDir.path)) ?? []
        let candidates = files.filter { file in
            file.lowercased().hasSuffix(".png") && names.contains { file.hasPrefix($0) }
        }
        func fileSize(_ name: String) -> Int {
            (try? FileManager.default.attributesOfItem(atPath: appDir.appendingPathComponent(name).path)[.size] as? Int) ?? 0
        }
        guard let best = candidates.max(by: { fileSize($0) < fileSize($1) }),
              let image = UIImage(contentsOfFile: appDir.appendingPathComponent(best).path),
              let png = image.pngData()
        else { return }
        try? png.write(to: output)
    }

    static func safeFileName(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|")).joined()
        return cleaned.isEmpty ? "App" : cleaned
    }
}

extension Int64 {
    var fileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
