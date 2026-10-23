import Foundation

/// 反義詞：意思相反的詞（開心↔難過、大↔小、成功↔失敗）。
/// 近義詞一起用：「快樂」的反義詞也包括「開心」的反義詞（難過、傷心）。
public enum Antonyms {
    static let direct: [String: [String]] = {
        var d: [String: [String]] = [:]
        for (a, b) in SynonymData.antonyms {
            if !(d[a] ?? []).contains(b) { d[a, default: []].append(b) }
            if !(d[b] ?? []).contains(a) { d[b, default: []].append(a) }
        }
        return d
    }()

    public static func known(_ w: String) -> Bool { direct[w] != nil || Synonyms.near(w).contains { direct[$0] != nil } }

    /// 反義詞：先列直接的，再列透過近義詞推出來的（「快樂」→ 痛苦；跟「開心」同義 → 難過）
    public static func opposites(_ w: String) -> [String] {
        var out: [String] = direct[w] ?? []
        for s in Synonyms.near(w) { for o in direct[s] ?? [] where o != w && !out.contains(o) { out.append(o) } }
        // 反義詞的近義詞也是（「難過」的近義詞「傷心」）
        for o in out.prefix(3) { for s in Synonyms.near(o) where s != w && !out.contains(s) && !Synonyms.same(s, w) { out.append(s) } }
        return out.filter { $0 != w && !Synonyms.same($0, w) }
    }

    /// 兩個詞意思相反嗎（直接是一對，或各自的近義詞是一對）
    public static func opposite(_ a: String, _ b: String) -> Bool {
        if direct[a]?.contains(b) == true { return true }
        let sa = [a] + Synonyms.near(a), sb = Set([b] + Synonyms.near(b))
        return sa.contains { x in (direct[x] ?? []).contains { sb.contains($0) } }
    }

    public enum Ask { case of(String), pair(String, String) }

    static let ofPatterns = [
        #"^(.{1,8}?)(?:有什麼|有哪些|有沒有)(?:反義詞|反義字|相反詞|相反的詞|對義詞|意思相反的詞)$"#,
        #"^(.{1,8}?)的(?:反義詞|反義字|相反詞|對義詞|反面詞)(?:是什麼|是哪些|有哪些|有什麼|是啥)?$"#,
        #"^(.{1,8}?)(?:反義詞|反義字|相反詞)(?:是什麼|有哪些|是啥)?$"#,
        #"^(.{1,8}?)的?(?:相反|反面)(?:的意思)?(?:是什麼|是啥|是)?$"#,
        #"^(?:跟|和|與)(.{1,8}?)(?:意思)?相反的(?:詞|字)(?:是什麼|有哪些|有什麼)?$"#,
        #"^什麼詞(?:跟|和|與)(.{1,8}?)(?:的)?意思相反$"#,
    ]
    static let pairPatterns = [
        #"^(.{1,8}?)(?:和|跟|與|同)(.{1,8}?)(?:是)?(?:反義詞|相反詞|反義字|一對反義詞|相反的意思|意思相反|相反)$"#,
        #"^(.{1,8}?)的(?:反義詞|相反詞)是(?:不是)?(.{1,8}?)$"#,
        #"^(.{1,8}?)(?:和|跟|與)(.{1,8}?)的意思是相反的$"#,
    ]

    public static func parse(_ raw: String) -> Ask? {
        let t = Synonyms.plainForWords(raw)
        for p in pairPatterns {
            if let m = Understanding.match(t, p) {
                let a = Synonyms.strip(m[1]), b = Synonyms.strip(m[2])
                if !a.isEmpty, !b.isEmpty, a != b, b != "什麼", b != "哪些" { return .pair(a, b) }
            }
        }
        for p in ofPatterns {
            if let m = Understanding.match(t, p) {
                let w = Synonyms.strip(m[1])
                if !w.isEmpty { return .of(w) }
            }
        }
        return nil
    }

    /// 用詞庫回答；沒有的詞回傳 nil（交給上網查）
    public static func answer(_ ask: Ask) -> String? {
        switch ask {
        case let .of(w):
            let o = opposites(w)
            guard !o.isEmpty else { return nil }
            return "「\(w)」的反義詞：" + o.prefix(6).joined(separator: "、") + "。"
        case let .pair(a, b):
            guard known(a) || known(b) || Synonyms.known(a) && Synonyms.known(b) else { return nil }
            if opposite(a, b) { return "對，「\(a)」和「\(b)」是反義詞，意思相反。" }
            if Synonyms.same(a, b) { return "不是，「\(a)」和「\(b)」意思相近，是近義詞，不是反義詞。" }
            let oa = opposites(a).prefix(3).joined(separator: "、")
            return "不是，「\(a)」和「\(b)」不是反義詞。" + (oa.isEmpty ? "" : "「\(a)」的反義詞是：\(oa)。")
        }
    }
}
