import Foundation
import SwiftUI

/// 全域狀態：主命盤、已存的其他人、以及顯示設定。全部存在 UserDefaults。
@MainActor
final class AppState: ObservableObject {

    private enum Key {
        static let owner = "nt.owner"
        static let others = "nt.others"
        static let lang = "nt.lang"
        static let anchor = "nt.yearAnchor"
    }

    /// 本人的命盤資料。為 nil 時顯示輸入畫面。
    @Published var owner: Profile? {
        didSet { save(owner, to: Key.owner) }
    }

    /// 合盤用的其他人。
    @Published var others: [Profile] = [] {
        didSet { save(others, to: Key.others) }
    }

    /// 介面語言。首次啟動時依系統語言判斷。
    @Published var lang: Lang = .zh {
        didSet {
            UserDefaults.standard.set(lang.rawValue, forKey: Key.lang)
            // 主畫面上的名稱也跟著換
            lang.applyAsAppLanguage()
        }
    }

    @Published var yearAnchor: YearAnchor = .birthDerived {
        didSet { UserDefaults.standard.set(yearAnchor.rawValue, forKey: Key.anchor) }
    }

    /// 目前語言的字串輔助。
    var t: T { T(lang) }

    init() {
        let d = UserDefaults.standard
        owner = load(Profile.self, from: Key.owner)
        others = load([Profile].self, from: Key.others) ?? []
        // 舊設定若不屬於這個版本開放的語言（例如換裝了另一個語言版本），退回預設
        if let raw = d.string(forKey: Key.lang), let l = Lang(rawValue: raw),
           Lang.available.contains(l) {
            lang = l
        } else {
            lang = Lang.detect()
        }
        if let raw = d.string(forKey: Key.anchor), let a = YearAnchor(rawValue: raw) {
            yearAnchor = a
        }
        #if DEBUG
        // 自動截圖用：帶 -uiDemo YES 啟動時放一筆示範資料（只在 Debug 版）
        if d.bool(forKey: "uiDemo"), owner == nil {
            owner = Profile(name: "Demo", birth: BirthDate(year: 2006, month: 1, day: 14))
        }
        #endif
        // init 裡的指派不會觸發 didSet，這裡補一次，讓主畫面的名稱一開始就對
        lang.applyAsAppLanguage()
    }

    /// 本人的推算引擎。
    var destiny: Destiny? {
        owner.map { $0.destiny(anchor: yearAnchor) }
    }

    func addOther(_ p: Profile) {
        others.removeAll { $0.id == p.id }
        others.insert(p, at: 0)
        if others.count > 30 { others.removeLast(others.count - 30) }
    }

    func removeOthers(at offsets: IndexSet) {
        others.remove(atOffsets: offsets)
    }

    func reset() {
        owner = nil
        others = []
    }

    // MARK: - 儲存

    private func save<T: Encodable>(_ value: T?, to key: String) {
        let d = UserDefaults.standard
        guard let value, let data = try? JSONEncoder().encode(value) else {
            d.removeObject(forKey: key)
            return
        }
        d.set(data, forKey: key)
    }

    private func load<T: Decodable>(_ type: T.Type, from key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
