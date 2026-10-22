import Foundation

/// 一筆已儲存的個人出生資料。
public struct Profile: Identifiable, Equatable, Hashable, Codable {
    public var id: UUID
    public var name: String
    public var birth: BirthDate

    public init(id: UUID = UUID(), name: String, birth: BirthDate) {
        self.id = id
        self.name = name
        self.birth = birth
    }

    public func displayName(_ lang: Lang) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? T(lang)("未命名", "Unnamed") : trimmed
    }

    public func destiny(anchor: YearAnchor) -> Destiny {
        Destiny(birth: birth, anchor: anchor)
    }
}
