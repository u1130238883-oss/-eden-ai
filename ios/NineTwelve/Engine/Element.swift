import Foundation

/// 五行。
public enum Element: String, CaseIterable, Codable, Sendable {
    case metal = "金"
    case wood  = "木"
    case water = "水"
    case fire  = "火"
    case earth = "土"

    /// 十二宮的五行歸屬。
    ///
    /// 金：2宮、7宮
    /// 木：9宮、12宮
    /// 水：3宮、4宮、6宮
    /// 火：1宮、5宮、8宮
    /// 土：10宮、11宮
    public static func of(palace: Int) -> Element {
        switch Num.r12(palace) {
        case 2, 7:      return .metal
        case 9, 12:     return .wood
        case 3, 4, 6:   return .water
        case 1, 5, 8:   return .fire
        default:        return .earth   // 10, 11
        }
    }

    /// 我所生者（木生火、火生土、土生金、金生水、水生木）。
    public var generates: Element {
        switch self {
        case .wood:  return .fire
        case .fire:  return .earth
        case .earth: return .metal
        case .metal: return .water
        case .water: return .wood
        }
    }

    /// 我所剋者（木剋土、土剋水、水剋火、火剋金、金剋木）。
    public var overcomes: Element {
        switch self {
        case .wood:  return .earth
        case .earth: return .water
        case .water: return .fire
        case .fire:  return .metal
        case .metal: return .wood
        }
    }

    /// 屬於此五行的所有宮位。
    public var palaces: [Int] {
        (1...12).filter { Element.of(palace: $0) == self }
    }

    /// 五行名稱。譯法採用各語言命理文獻通用的說法。
    public func name(_ lang: Lang) -> String {
        switch lang {
        case .zh: return rawValue
        case .en:
            switch self {
            case .metal: return "Metal"
            case .wood:  return "Wood"
            case .water: return "Water"
            case .fire:  return "Fire"
            case .earth: return "Earth"
            }
        case .es:
            switch self {
            case .metal: return "Metal"
            case .wood:  return "Madera"
            case .water: return "Agua"
            case .fire:  return "Fuego"
            case .earth: return "Tierra"
            }
        case .it:
            switch self {
            case .metal: return "Metallo"
            case .wood:  return "Legno"
            case .water: return "Acqua"
            case .fire:  return "Fuoco"
            case .earth: return "Terra"
            }
        }
    }
}
