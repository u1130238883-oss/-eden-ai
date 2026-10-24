import Foundation
import SwiftUI

struct Person: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var birth: BirthDate
}

/// 所有資料只存在本機（UserDefaults），不會上傳。
final class Store: ObservableObject {
    @Published var owner: Person? { didSet { save() } }
    @Published var others: [Person] = [] { didSet { save() } }
    @Published var anchor: YearAnchor = .birthDerived { didSet { save() } }
    @Published var lang: Lang = .zh {
        didSet {
            Lang.current = lang
            save()
        }
    }

    private let defaults = UserDefaults.standard

    init() {
        if let d = defaults.data(forKey: "owner"), let p = try? JSONDecoder().decode(Person.self, from: d) {
            owner = p
        }
        if let d = defaults.data(forKey: "others"), let list = try? JSONDecoder().decode([Person].self, from: d) {
            others = list
        }
        if let raw = defaults.string(forKey: "anchor"), let a = YearAnchor(rawValue: raw) {
            anchor = a
        }
        let l = defaults.string(forKey: "lang").flatMap(Lang.init(rawValue:)) ?? Lang.systemDefault
        Lang.current = l
        lang = l
    }

    var destiny: Destiny? {
        guard let owner else { return nil }
        return Destiny(birth: owner.birth, anchor: anchor)
    }

    var displayName: String {
        let n = owner?.name.trimmingCharacters(in: .whitespaces) ?? ""
        return n.isEmpty ? L("你", "You", "Tú", "Tu") : n
    }

    func addOther(_ p: Person) {
        others.removeAll { $0.name == p.name && $0.birth == p.birth }
        others.insert(p, at: 0)
        if others.count > 20 { others = Array(others.prefix(20)) }
    }

    func reset() {
        owner = nil
        others = []
        anchor = .birthDerived
    }

    private func save() {
        if let owner, let d = try? JSONEncoder().encode(owner) {
            defaults.set(d, forKey: "owner")
        } else {
            defaults.removeObject(forKey: "owner")
        }
        if let d = try? JSONEncoder().encode(others) { defaults.set(d, forKey: "others") }
        defaults.set(anchor.rawValue, forKey: "anchor")
        defaults.set(lang.rawValue, forKey: "lang")
    }
}

enum Today {
    static var components: (year: Int, month: Int, day: Int) {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }
}
