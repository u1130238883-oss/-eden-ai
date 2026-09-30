import Foundation

/// 引用規則：
///   • 引文少於 15 個字，每個來源最多一句引文，其他用自己的話說，不照搬原文的句子結構。
///   • 每個來自網路的說法都附上來源標記（「……」（網站）），結尾列出真的用到的來源。
///   • 原始來源（官方、政府、學術、百科）優先；問答網站、論壇、內容農場放最後，除非沒有別的資料。
public enum Cite {
    public static let maxQuote = 14

    /// 從一句話裡取出最重要的一小段（包含關鍵詞的那一段，最多 14 個字）
    public static func fragment(_ sentence: String, focus: [String]) -> String {
        var s = sentence.replacingOccurrences(of: #"\[[^\]]*\]|（[^）]*）|\([^)]*\)"#, with: "", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespaces)
        let chars = Array(s)
        guard !chars.isEmpty else { return "" }
        // 關鍵詞出現的位置
        var pos = 0, focusLen = 0
        for f in focus where !f.isEmpty {
            if let r = s.range(of: f) { pos = s.distance(from: s.startIndex, to: r.lowerBound); focusLen = f.count; break }
        }
        // 從關鍵詞所在的子句開頭取起
        // 往前找到子句開頭；子句開頭離關鍵詞不遠（10 字內）就從開頭取，名字才不會被切掉（「珠穆朗瑪峰…」）
        var clause = pos
        while clause > 0 && !"，；：。、,;:".contains(chars[clause - 1]) { clause -= 1 }
        var start = pos - clause <= 10 ? clause : pos - 6
        // 關鍵詞本身一定要完整（「508公尺」不能變成「508公」）
        if focusLen <= maxQuote { start = max(start, pos + focusLen - maxQuote) }
        var out = ""
        var i = start
        while i < chars.count && out.count < maxQuote {
            let c = chars[i]
            if "。；！？!?".contains(c) { break }
            if "，,".contains(c) && out.count >= 6 { break }
            out.append(c)
            i += 1
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "，、：:；,. "))
    }

    /// 「短引文」（網站）
    public static func quote(_ sentence: String, host: String, focus: [String]) -> String {
        let f = fragment(sentence, focus: focus)
        return f.isEmpty ? "" : "「\(f)」（\(host)）"
    }

    /// 問答網站、論壇、內容農場、轉貼站：除非沒有別的資料，不然不用
    static let lowQuality = ["zhidao.baidu", "wenwen.sogou", "answers.com", "answers.yahoo", "commentcamarche", "quora.com", "reddit.com",
                             "ptt.cc", "dcard.tw", "mobile01", "kknews", "toutiao", "163.com", "sohu.com", "read01", "twgreatdaily",
                             "pinterest", "ifuun", "iask", "xuehua", "360doc", "docin", "doc88", "wenku.baidu", "jingyan.baidu"]
    /// 原始來源：官方、政府、學術、百科
    static let primary = [".gov", ".edu", "gov.tw", "gov.cn", "go.jp", "who.int", "un.org", "wikipedia.org", "nature.com", "science.org",
                          "sciencedirect", "springer", "nih.gov", "arxiv.org", "sec.gov", "cdc.gov", "moe.gov", "cwa.gov"]

    public static func isLowQuality(_ host: String) -> Bool { lowQuality.contains { host.lowercased().contains($0) } }
    public static func isPrimary(_ host: String) -> Bool { primary.contains { host.lowercased().contains($0) } }

    /// 查詢要短（中文最多 16 個字）
    public static func shortQuery(_ q: String) -> String {
        let parts = q.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        var out: [String] = []
        var len = 0
        for p in parts where len + p.count <= 16 && out.count < 6 { out.append(p); len += p.count }
        let s = out.joined(separator: " ")
        return s.isEmpty ? String(q.prefix(16)) : s
    }

    /// 兩個查詢是不是差不多（換湯不換藥的不用再查一次）
    public static func similar(_ a: String, _ b: String) -> Bool {
        func grams(_ s: String) -> Set<String> {
            let c = Array(s.filter { !$0.isWhitespace })
            guard c.count >= 2 else { return [String(c)] }
            return Set((0..<(c.count - 1)).map { String(c[$0...$0 + 1]) })
        }
        let x = grams(a), y = grams(b)
        guard !x.isEmpty, !y.isEmpty else { return a == b }
        return Double(x.intersection(y).count) / Double(x.union(y).count) >= 0.7
    }

    /// 去掉太像的查詢，而且每個都變短
    public static func distinct(_ qs: [String]) -> [String] {
        var out: [String] = []
        for q in qs.map(shortQuery) where !q.isEmpty && !out.contains(where: { similar($0, q) }) { out.append(q) }
        return out
    }

    /// 需要特別小心的領域：偽科學、偏方、產品推薦（充斥廣告）
    public static func skepticNote(_ question: String) -> String? {
        if ["偏方", "根治", "神奇", "秘方", "排毒", "抗癌食物", "包治", "量子能量"].contains(where: { question.contains($0) }) {
            return "⚠️ 這類說法網路上常有誇大或沒有科學根據的內容，我只採用有醫療或學術來源支持的部分；身體的問題請以醫師的判斷為準。"
        }
        if ["推薦", "哪個牌子", "哪款", "買哪", "排行", "評比", "開箱"].contains(where: { question.contains($0) }) {
            return "⚠️ 產品推薦的網頁很多是業配或廣告，我盡量看比較客觀的來源；買之前最好再看看實際使用者的評價。"
        }
        return nil
    }
}
