import Foundation

/// 混合分詞器（對應 ai/echo_model.py 的 CharTokenizer）：
/// 以正規式 ` ?[A-Za-zÀ-ÿ']+|.` 預先切分；切出的片段若在字表中就是一個 token（常用外語單字），
/// 否則逐個 Unicode 字元編碼。中文因此逐字，英文／西班牙文／義大利文常用字整字。
public struct CharTokenizer {
    public let vocab: [String]
    let index: [String: Int]
    public let unk: Int
    public let user: Int
    public let assistant: Int
    public let eos: Int
    /// 事實框起始符（命理引擎的推算結果從這裡注入）
    public let fact: Int
    /// 第一個一般字元的 id（前面都是特殊 token）
    public let firstRegular: Int
    static let pretoken = try! NSRegularExpression(pattern: #" ?[A-Za-zÀ-ÿ']+|."#,
                                                   options: [.dotMatchesLineSeparators])

    init(vocab: [String], unk: Int, user: Int, assistant: Int, eos: Int, fact: Int) {
        self.vocab = vocab
        self.unk = unk
        self.user = user
        self.assistant = assistant
        self.eos = eos
        self.fact = fact
        firstRegular = max(unk, user, assistant, eos, fact) + 1
        var idx: [String: Int] = [:]
        for (i, s) in vocab.enumerated() where i >= firstRegular { idx[s] = i }
        index = idx
    }

    public func encode(_ text: String) -> [Int] {
        var out: [Int] = []
        let ns = text as NSString
        for m in CharTokenizer.pretoken.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let piece = ns.substring(with: m.range)
            if let i = index[piece] {
                out.append(i)
            } else {
                // Python 端以 Unicode code point 切分，這裡保持一致
                for s in piece.unicodeScalars { out.append(index[String(s)] ?? unk) }
            }
        }
        return out
    }

    public func decode(_ ids: [Int]) -> String {
        ids.filter { $0 >= firstRegular && $0 < vocab.count }.map { vocab[$0] }.joined()
    }

    public func token(_ id: Int) -> String {
        id >= firstRegular && id < vocab.count ? vocab[id] : ""
    }
}
