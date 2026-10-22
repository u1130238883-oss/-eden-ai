import XCTest
@testable import EchoCore

/// 四語翻譯語料（ai/corpus4 產生）：5000 單字、5000 短語、5000 句子。
/// 每一項用四種語言輪流當原文，包進不同的問法（中文問法、英西義的問法），NineSun 都要聽懂「要翻的就是這一段、翻成哪種語言」；
/// 道地說法表（Native）有對到的話，答案要跟語料一致。
final class TranslateCorpusTests: XCTestCase {
    struct Item: Decodable { let zh, en, es, it: String }
    struct Corpus: Decodable { let words, phrases, sentences: [Item] }

    static let langs: [(String, Translate.Code)] = [("zh", .zh), ("en", .en), ("es", .es), ("it", .it)]
    static let zhName: [Translate.Code: String] = [.zh: "中文", .en: "英文", .es: "西班牙文", .it: "義大利文"]
    static let enName: [Translate.Code: String] = [.zh: "Chinese", .en: "English", .es: "Spanish", .it: "Italian"]
    static let esName: [Translate.Code: String] = [.zh: "chino", .en: "inglés", .es: "español", .it: "italiano"]
    static let itName: [Translate.Code: String] = [.zh: "cinese", .en: "inglese", .es: "spagnolo", .it: "italiano"]
    static let abbr: [Translate.Code: String] = [.zh: "中", .en: "英", .es: "西", .it: "義"]

    func text(_ i: Item, _ l: String) -> String {
        let s = ["zh": i.zh, "en": i.en, "es": i.es, "it": i.it][l]!
        return s.components(separatedBy: "/").first!.trimmingCharacters(in: .whitespaces)
    }

    /// 第 k 種問法
    func wrap(_ x: String, src: String, to t: Translate.Code, _ k: Int) -> String {
        let Z = Self.zhName[t]!, A = Self.abbr[t]!
        let zhForms = ["\(x)用\(Z)怎麼說", "把\(x)翻成\(Z)", "\(x)的\(Z)是什麼", "翻譯成\(Z)：\(x)", "「\(x)」用\(Z)怎麼講",
                       "請問\(x)用\(Z)怎麼說？", "\(x) 翻\(A)", "\(Z)：\(x)", "幫我把「\(x)」翻譯成\(Z)", "\(x)這句\(Z)怎麼說"]
        switch src {
        case "en":
            let forms = ["how do you say \(x) in \(Self.enName[t]!)", "translate \(x) to \(Self.enName[t]!)"] + zhForms.prefix(3)
            return forms[k % forms.count]
        case "es":
            let forms = ["¿cómo se dice \(x) en \(Self.esName[t]!)?", "traduce \(x) al \(Self.esName[t]!)"] + zhForms.prefix(3)
            return forms[k % forms.count]
        case "it":
            let forms = ["come si dice \(x) in \(Self.itName[t]!)?", "traduci \(x) in \(Self.itName[t]!)"] + zhForms.prefix(3)
            return forms[k % forms.count]
        default:
            return zhForms[k % zhForms.count]
        }
    }

    /// 道地說法跟語料寫法不同、但人工看過兩種都對的（例：可惜 → ¡Qué pena! 和 lamentablemente）
    static let reviewed: Set<String> = [
        "可惜→es", "hasta luego→zh-Hant", "等一下→en", "of course→zh-Hant", "un momento→zh-Hant", "I don't know→zh-Hant",
        "be careful→es", "good luck→zh-Hant", "buona fortuna→es", "excuse me→es", "感謝→it", "good luck→es", "buona fortuna→zh-Hant",
        "隨便→en", "拜拜→it", "注意→en", "等等→it", "祝你好運→es", "保重→en", "好吃→it",
    ]

    static func norm(_ s: String) -> String {
        s.lowercased().folding(options: .diacriticInsensitive, locale: nil).filter { $0.isLetter || $0.isNumber }
    }

    func testCorpus() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "translate_corpus", withExtension: "json", subdirectory: "Fixtures"))
        let c = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
        var bad: [String: [String]] = [:], total: [String: Int] = [:]
        var nativeBad: [String] = []
        for (group, items) in [("單字", c.words), ("短語", c.phrases), ("句子", c.sentences)] {
            for (n, item) in items.enumerated() {
                for (li, (l, _)) in Self.langs.enumerated() {
                    let src = text(item, l)
                    // 目標語言輪流換（不能跟原文一樣）
                    let others = Self.langs.filter { $0.0 != l }
                    let (tl, tc) = others[(n + li) % 3]
                    let q = wrap(src, src: l, to: tc, n / 3 + li)
                    total[group, default: 0] += 1
                    let r = Translate.parse(q)
                    // 「請問」是客氣話，翻進去或不翻進去意思都對（同 TranslateQuestionsTests）
                    let ok = r.map { ($0.text == src || Self.norm($0.text) == Self.norm(src) || Self.norm($0.text) == Self.norm("請問" + src)
                                     || Self.norm("那個" + $0.text) == Self.norm(src)) && $0.target == tc } ?? false
                    if !ok {
                        bad[group, default: []].append("✗ \(q)  →  \(r.map { "「\($0.text)」/\($0.target.rawValue)" } ?? "沒聽懂")　應該：「\(src)」/\(tc.rawValue)")
                    }
                    // 道地說法表：對到的話要跟語料一致（語料任何一個說法都算對）
                    if let nat = Native.lookup(.init(text: src, source: nil, target: tc)) {
                        let refs = (["zh": item.zh, "en": item.en, "es": item.es, "it": item.it][tl] ?? "").components(separatedBy: "/").map(Self.norm)
                        let mine = [nat.text] + nat.alternatives
                        let key = "\(src)→\(tc.rawValue)"
                        if !mine.contains(where: { refs.contains(Self.norm($0)) || refs.contains("to" + Self.norm($0)) }) && !Self.reviewed.contains(key) {
                            nativeBad.append("✗ 道地說法 \(src) → \(tc.rawValue)：表裡是「\(nat.text)」，語料是「\(refs.joined(separator: " / "))」")
                        }
                    }
                }
            }
        }
        var lines: [String] = []
        for g in ["單字", "短語", "句子"] {
            let b = bad[g]?.count ?? 0
            lines.append("TRANSLATE-CORPUS \(g)：\(total[g]! - b)/\(total[g]!) 聽懂")
        }
        lines.append("TRANSLATE-CORPUS 道地說法跟語料不一致：\(nativeBad.count)")
        print(lines.joined(separator: "\n"))
        if let out = ProcessInfo.processInfo.environment["NINESUN_TC_OUT"] {
            let all = (bad["單字"] ?? []) + (bad["短語"] ?? []) + (bad["句子"] ?? []) + nativeBad
            try? all.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
        }
        let failures = bad.values.reduce(0) { $0 + $1.count } + nativeBad.count
        XCTAssertEqual(failures, 0, (Array((bad["單字"] ?? []).prefix(10)) + Array((bad["短語"] ?? []).prefix(10))
                                      + Array((bad["句子"] ?? []).prefix(10)) + Array(nativeBad.prefix(10))).joined(separator: "\n"))
    }
}
