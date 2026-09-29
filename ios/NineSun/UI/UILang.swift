import EchoCore
import Foundation

/// 介面語言（由 ChatViewModel 設定）。T(繁中, English, Español, Italiano) 依目前語言取字串。
enum UILang {
    static var current: Lang = .zh

    static var systemDefault: Lang {
        let code = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "zh"
        return Lang(rawValue: String(code)) ?? (code == "zh" ? .zh : .en)
    }
}

func T(_ zh: String, _ en: String, _ es: String, _ it: String) -> String {
    switch UILang.current {
    case .zh: return zh
    case .en: return en
    case .es: return es
    case .it: return it
    }
}
