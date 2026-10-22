import Foundation

/// 介面語言。
///
/// 這份程式碼同時支援四種語言。預設版本開放繁體中文與英文；
/// 帶 `LOCALE_LATIN` 旗標建置時為西班牙文與義大利文；
/// 帶 `LOCALE_ALL` 旗標建置時四種語言全部開放，可在設定裡直接切換。
public enum Lang: String, CaseIterable, Codable, Sendable {
    case zh
    case en
    case es
    case it

    public var title: String {
        switch self {
        case .zh: return "繁體中文"
        case .en: return "English"
        case .es: return "Español"
        case .it: return "Italiano"
        }
    }

    /// 這個版本開放的語言。
    public static var available: [Lang] {
        #if LOCALE_ALL
        return [.zh, .en, .es, .it]
        #elseif LOCALE_LATIN
        return [.es, .it]
        #else
        return [.zh, .en]
        #endif
    }

    /// 找不到合適語言時的預設值。
    public static var fallback: Lang { available[0] }

    /// 對應到 App 裡的 .lproj 資料夾，也就是主畫面名稱存放的地方。
    public var bundleCode: String {
        switch self {
        case .zh: return "zh-Hant"
        case .en: return "en"
        case .es: return "es"
        case .it: return "it"
        }
    }

    /// 讓主畫面上的 App 名稱跟著 App 裡選的語言走。
    ///
    /// iOS 沒有讓 App 直接改主畫面名稱的方法：那個名稱是系統挑好 .lproj
    /// 之後從裡面讀出來的。系統挑哪一個 .lproj，看的是「這個 App 偏好的語言」，
    /// 而那個偏好就存在 App 自己的 AppleLanguages 設定裡。把選好的語言寫進去，
    /// 系統下次載入這個 App 的名稱時就會換成該語言的寫法。
    public func applyAsAppLanguage() {
        let d = UserDefaults.standard
        guard d.stringArray(forKey: "AppleLanguages")?.first != bundleCode else { return }
        d.set([bundleCode], forKey: "AppleLanguages")
    }

    /// 依系統語言推測，推測結果不在這個版本內時退回預設。
    public static func detect() -> Lang {
        let code = (Locale.preferredLanguages.first ?? "en").lowercased()
        let guess: Lang
        if code.hasPrefix("zh")      { guess = .zh }
        else if code.hasPrefix("es") { guess = .es }
        else if code.hasPrefix("it") { guess = .it }
        else                         { guess = .en }
        return available.contains(guess) ? guess : fallback
    }
}

/// 多語字串輔助。
///
/// 用法：`t("今日", "Today", "Hoy", "Oggi")` —— 各語言的文字並排寫在一起，方便對照。
/// 西／義文可以省略，省略時退回英文。
public struct T: Sendable {
    public let lang: Lang

    public init(_ lang: Lang) { self.lang = lang }

    /// 依目前語言取字串。
    public func callAsFunction(_ zh: String, _ en: String,
                               _ es: String? = nil, _ it: String? = nil) -> String {
        switch lang {
        case .zh: return zh
        case .en: return en
        case .es: return es ?? en
        case .it: return it ?? en
        }
    }

    public var isZH: Bool { lang == .zh }

    // MARK: - 領域詞彙

    /// 「5宮」／「Palace 5」／「Palacio 5」／「Palazzo 5」
    public func palace(_ n: Int) -> String {
        self("\(n)宮", "Palace \(n)", "Palacio \(n)", "Palazzo \(n)")
    }

    /// 「5宮・桃花」／「Palace 5 · Peach Blossom」
    public func palaceNamed(_ n: Int) -> String {
        "\(palace(n))\(self("・", " · "))\(Palace.shortName(n, lang: lang))"
    }

    /// 「金」／「Metal」／「Metal」／「Metallo」
    public func element(_ e: Element) -> String { e.name(lang) }

    /// 「壞」／「Adverse」／「Adverso」／「Avverso」
    public func verdict(_ v: Verdict) -> String { v.name(lang) }

    /// 「壞3因8」／「Adverse 3 from 8」
    public func reading(_ r: Reading) -> String { r.text(lang) }

    /// 判讀中間那個小字：「因」／「from」／「de」／「da」
    public var causeParticle: String { self("因", "from", "de", "da") }

    /// 「果」／「Effect」／「Efecto」／「Effetto」
    public var effectWord: String { self("果", "Effect", "Efecto", "Effetto") }
    /// 「因」／「Cause」／「Causa」／「Causa」
    public var causeWord: String { self("因", "Cause", "Causa", "Causa") }

    public var lifeNumber: String {
        self("靈數", "Life Number", "Número de Vida", "Numero di Vita")
    }
    public var lifePalace: String {
        self("命宮", "Life Palace", "Palacio de Vida", "Palazzo della Vita")
    }

    public var yearPillar: String {
        self("年柱", "Year Pillar", "Pilar del Año", "Pilastro dell'Anno")
    }
    public var monthPillar: String {
        self("月柱", "Month Pillar", "Pilar del Mes", "Pilastro del Mese")
    }
    public var dayPillar: String {
        self("日柱", "Day Pillar", "Pilar del Día", "Pilastro del Giorno")
    }

    /// 三柱寫法：中文用全形分號，其餘用斜線
    public func triple(_ t: Triple) -> String {
        self("\(t.year)；\(t.month)；\(t.day)", "\(t.year) / \(t.month) / \(t.day)")
    }

    /// 年份：「2026年」／「2026」
    public func year(_ y: Int) -> String { self("\(y)年", "\(y)") }

    /// 月份縮寫
    public func month(_ m: Int) -> String {
        let i = max(1, min(12, m)) - 1
        switch lang {
        case .zh: return "\(m)月"
        case .en: return ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][i]
        case .es: return ["ene", "feb", "mar", "abr", "may", "jun",
                          "jul", "ago", "sep", "oct", "nov", "dic"][i]
        case .it: return ["gen", "feb", "mar", "apr", "mag", "giu",
                          "lug", "ago", "set", "ott", "nov", "dic"][i]
        }
    }

    /// 日期：「2006年1月14日」／「14 Jan 2006」
    public func date(_ b: BirthDate) -> String {
        self("\(b.year)年\(b.month)月\(b.day)日",
             "\(b.day) \(month(b.month)) \(b.year)")
    }

    /// 年月柱的五行關係說明
    public func relation(_ r: Reading) -> String {
        let ey = element(r.yearElement)
        let em = element(r.monthElement)
        let yearWord = self("年", "Year", "Año", "Anno")
        let monthWord = self("月", "Month", "Mes", "Mese")
        switch r.relation {
        case .same:
            return self("同為\(ey)", "both \(ey)", "ambos \(ey)", "entrambi \(ey)")
        case .yearGeneratesMonth:
            return self("\(ey)生\(em)（年生月）",
                        "\(ey) generates \(em) (\(yearWord) → \(monthWord))",
                        "\(ey) genera \(em) (\(yearWord) → \(monthWord))",
                        "\(ey) genera \(em) (\(yearWord) → \(monthWord))")
        case .monthGeneratesYear:
            return self("\(em)生\(ey)（月生年）",
                        "\(em) generates \(ey) (\(monthWord) → \(yearWord))",
                        "\(em) genera \(ey) (\(monthWord) → \(yearWord))",
                        "\(em) genera \(ey) (\(monthWord) → \(yearWord))")
        case .yearControlsMonth:
            return self("\(ey)剋\(em)（年剋月）",
                        "\(ey) controls \(em) (\(yearWord) → \(monthWord))",
                        "\(ey) domina \(em) (\(yearWord) → \(monthWord))",
                        "\(ey) domina \(em) (\(yearWord) → \(monthWord))")
        case .monthControlsYear:
            return self("\(em)剋\(ey)（月剋年）",
                        "\(em) controls \(ey) (\(monthWord) → \(yearWord))",
                        "\(em) domina \(ey) (\(monthWord) → \(yearWord))",
                        "\(em) domina \(ey) (\(monthWord) → \(yearWord))")
        }
    }

    /// 好／正／壞的一句話解釋
    public func verdictHint(_ v: Verdict) -> String {
        switch v {
        case .good:
            return self("年月相生", "Year and Month generate",
                        "el Año y el Mes se generan", "l'Anno e il Mese si generano")
        case .neutral:
            return self("年月同五行", "Year and Month share an element",
                        "el Año y el Mes comparten elemento",
                        "l'Anno e il Mese condividono l'elemento")
        case .bad:
            return self("年月相剋", "Year and Month control",
                        "el Año y el Mes se dominan", "l'Anno e il Mese si dominano")
        }
    }
}
