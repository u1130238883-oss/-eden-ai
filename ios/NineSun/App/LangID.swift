import EchoCore
import NaturalLanguage

/// 判斷原文是哪種語言：用手機內建的語言辨識（離線），比只看常見字準很多（「ti amo」「lo siento」這種短句也認得）。
/// 蘋果內建翻譯一定要知道原文語言，認錯就會翻壞。
enum LangID {
    static let map: [NLLanguage: Translate.Code] = [
        .traditionalChinese: .zh, .simplifiedChinese: .zhHans, .english: .en, .spanish: .es, .italian: .it,
        .japanese: .ja, .korean: .ko, .french: .fr, .german: .de, .russian: .ru, .portuguese: .pt, .arabic: .ar,
    ]

    static func detect(_ text: String) -> Translate.Code {
        let quick = Translate.detect(text)
        // 中日韓、阿拉伯、俄文看字就知道（繁簡交給原本的判斷：都當繁中處理）
        if ![Translate.Code.en, .es, .it].contains(quick) { return quick }
        let r = NLLanguageRecognizer()
        // 使用者最常用的是英、西、義，給一點偏好
        r.languageHints = [.english: 0.4, .spanish: 0.3, .italian: 0.3]
        r.languageConstraints = Array(map.keys)
        r.processString(text)
        guard let best = r.languageHypotheses(withMaximum: 1).first, best.value >= 0.3, let c = map[best.key] else { return quick }
        return c == .zhHans ? .zh : c
    }
}
