import Foundation

/// 使用者規則：使用者說的話就是法律。規則永久保存，並由程式碼在「每一則」回覆上強制執行，
/// 不依賴模型記憶，因此不會被遺忘或違反。支援繁體中文、英文、西班牙文、義大利文。
public struct Rule: Codable, Identifiable, Equatable {
    public enum Kind: String, Codable {
        case address    // 稱呼使用者
        case aiName     // AI 的名字
        case brevity    // 回答簡短
        case suffix     // 句尾附加
        case ban        // 禁用詞
        case trigger    // 我說 A 你就回 B
        case note       // 其他（記錄並列入規則表）
    }

    public var id = UUID()
    public let kind: Kind
    public let a: String
    public let b: String
    public let raw: String

    public var summary: String { summary(.zh) }

    public func summary(_ L: Lang) -> String {
        let t: [Kind: [String]] = [
            .address: ["稱呼你為「%a」", "call you “%a”", "llamarte «%a»", "chiamarti «%a»"],
            .aiName: ["我的名字改為「%a」", "my name is now “%a”", "mi nombre ahora es «%a»", "il mio nome ora è «%a»"],
            .brevity: ["回答保持簡短（一句話）", "keep answers short (one sentence)", "respuestas breves (una frase)",
                       "risposte brevi (una frase)"],
            .suffix: ["每句結尾加上「%a」", "end every reply with “%a”", "terminar cada respuesta con «%a»",
                      "finire ogni risposta con «%a»"],
            .ban: ["禁止說「%a」", "never say “%a”", "nunca decir «%a»", "non dire mai «%a»"],
            .trigger: ["你說「%a」時，我回「%b」", "when you say “%a”, I reply “%b”", "cuando digas «%a», respondo «%b»",
                       "quando dici «%a», rispondo «%b»"],
        ]
        if kind == .note { return a }
        let i = [Lang.zh, .en, .es, .it].firstIndex(of: L)!
        return t[kind]![i].replacingOccurrences(of: "%a", with: a).replacingOccurrences(of: "%b", with: b)
    }

    /// 由程式強制執行，或僅記錄
    public var enforced: Bool { kind != .note }
}

public enum RuleCommand: Equatable {
    case add(Rule)
    case list
    case delete(Int)
    case clear
}

public struct RuleBook: Codable, Equatable {
    public var rules: [Rule] = []
    public init() {}

    // MARK: - 解析

    static let prefixes = ["規則：", "規則:", "規則", "記住：", "記住:", "記住", "命令：", "命令:", "從現在開始", "從今以後", "以後",
                           "rule:", "remember:", "from now on,", "from now on",
                           "regla:", "recuerda:", "a partir de ahora", "desde ahora",
                           "regola:", "ricorda:", "d'ora in poi", "da ora in poi"]
    static let directives = ["你必須", "你要", "不准", "不要再", "不許", "禁止",
                             "always ", "never ", "don't ", "do not ", "call me", "you must",
                             "siempre ", "nunca ", "no digas", "llámame", "llamame",
                             "sempre ", "mai ", "non dire", "chiamami"]

    static func strip(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = t.last, "。！!？?～~ .".contains(last) { t.removeLast() }
        for q in ["「", "」", "\"", "『", "』", "“", "”", "«", "»"] { t = t.replacingOccurrences(of: q, with: "") }
        return t.trimmingCharacters(in: .whitespaces)
    }

    static func match(_ s: String, _ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (1..<m.numberOfRanges).map { Range(m.range(at: $0), in: s).map { String(s[$0]) } ?? "" }
    }

    /// 解析規則指令；不是規則指令就回傳 nil
    public static func parse(_ message: String) -> RuleCommand? {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        let listWords = ["我的規則", "列出規則", "規則列表", "查看規則", "有哪些規則", "my rules", "list rules", "show rules",
                         "mis reglas", "ver reglas", "le mie regole", "mostra regole"]
        if listWords.contains(where: { lower.contains($0) }) { return .list }
        let clearWords = ["清除所有規則", "刪除所有規則", "清空規則", "clear all rules", "delete all rules", "remove all rules",
                          "borra todas las reglas", "elimina todas las reglas", "cancella tutte le regole", "elimina tutte le regole"]
        if clearWords.contains(where: { lower.contains($0) }) { return .clear }
        if let g = match(text, #"(?:刪除|取消|移除)規則\s*(\d+)|(?:delete|remove) rule\s*(\d+)|(?:borra|elimina) (?:la )?regla\s*(\d+)|(?:cancella|elimina) (?:la )?regola\s*(\d+)"#),
           let n = g.compactMap({ Int($0) }).first {
            return .delete(n)
        }

        // 自我介紹名字：「我叫小明」「我的名字是小明」「my name is Sam」→ 以後這樣叫你
        if let g = match(text, #"^(?:我叫|我的名字是|我的名字叫|my name is|me llamo|mi nombre es|mi chiamo|il mio nome è)\s*([^，,。.!！?？\s]{1,12})\s*[。.!！]?$"#),
           !g[0].hasPrefix("你"), !g[0].contains("什麼") {
            return .add(Rule(kind: .address, a: strip(g[0]), b: "", raw: text))
        }
        var body: String?
        for p in prefixes where lower.hasPrefix(p) {
            body = String(text.dropFirst(p.count)); break
        }
        if body == nil, directives.contains(where: { lower.hasPrefix($0) }) { body = text }
        guard var b = body?.trimmingCharacters(in: .whitespaces), !b.isEmpty else { return nil }
        // 問句、生日與出生時間不是規則
        let questionMarks = ["怎麼", "什麼", "嗎", "？", "?", "要不要", "會不會", "能不能", "可不可以", "¿"]
        if questionMarks.contains(where: { text.contains($0) }) { return nil }
        let profileWords = ["生日", "出生", "男生", "女生", "birthday", "born", "cumpleaños", "nací", "compleanno", "nato", "nata"]
        if profileWords.contains(where: { b.lowercased().contains($0) }) { return nil }
        if b.hasPrefix("以後") { b = String(b.dropFirst(2)) }
        if b.hasPrefix("：") || b.hasPrefix(":") || b.hasPrefix(",") { b = String(b.dropFirst()).trimmingCharacters(in: .whitespaces) }
        // 「加班屬於6宮」是教詞，不是規則
        if match(b, #"(.+?)(?:屬於\d{1,2}宮|\s(?:is|belongs to|es|pertenece al|è|appartiene al)\s+(?:palace|palacio|palazzo)\s+\d{1,2})"#) != nil {
            return nil
        }

        func rule(_ k: Rule.Kind, _ a: String, _ bb: String = "") -> RuleCommand {
            .add(Rule(kind: k, a: strip(a), b: strip(bb), raw: text))
        }
        // 觸發
        if let g = match(b, #"(?:當|如果)?我說(.+?)(?:的時候|時)?[，,]?你(?:就|要|必須)?(?:回答|回覆|回|說)(.+)"#) { return rule(.trigger, g[0], g[1]) }
        if let g = match(b, #"(?:when|if) i say (.+?),? (?:you )?(?:reply|answer|respond|say) (.+)"#) { return rule(.trigger, g[0], g[1]) }
        if let g = match(b, #"(?:cuando|si) (?:yo )?diga (.+?),? (?:tú )?(?:responde|contesta|di|dices) (.+)"#) { return rule(.trigger, g[0], g[1]) }
        if let g = match(b, #"(?:quando|se) (?:io )?dico (.+?),? (?:tu )?(?:rispondi|di'|dici|rispondimi) (.+)"#) { return rule(.trigger, g[0], g[1]) }
        // 稱呼
        if let g = match(b, #"(?:叫|稱呼)我(?:為|做)?(.+)"#) { return rule(.address, g[0]) }
        if let g = match(b, #"call me (.+)"#) { return rule(.address, g[0]) }
        if let g = match(b, #"(?:llámame|llamame) (.+)"#) { return rule(.address, g[0]) }
        if let g = match(b, #"chiamami (.+)"#) { return rule(.address, g[0]) }
        // AI 名字
        if let g = match(b, #"你(?:的名字)?(?:改名為|改名叫|改為|改成|改叫|就叫|叫做|叫)(.+)"#) { return rule(.aiName, g[0]) }
        if let g = match(b, #"(?:your name is|call yourself|you are called|rename yourself to) (.+)"#) { return rule(.aiName, g[0]) }
        if let g = match(b, #"(?:tu nombre es|te llamas|llámate|llamate) (.+)"#) { return rule(.aiName, g[0]) }
        if let g = match(b, #"(?:il tuo nome è|ti chiami|chiamati) (.+)"#) { return rule(.aiName, g[0]) }
        // 句尾
        if let g = match(b, #"(?:每句|句尾|結尾|每次回答|每次說話|回答最後).*?(?:加上|加|都說|帶上|帶)(.+)"#) { return rule(.suffix, g[0]) }
        if let g = match(b, #"(?:end|finish) (?:every|each|all|your)? ?(?:sentence|reply|replies|answer|answers|message)s? with (.+)"#) {
            return rule(.suffix, g[0])
        }
        if let g = match(b, #"termina (?:cada|todas las|tus) (?:frase|respuesta|frases|respuestas|mensaje)s? con (.+)"#) { return rule(.suffix, g[0]) }
        if let g = match(b, #"finisci (?:ogni|tutte le|le tue) (?:frase|risposta|frasi|risposte|messaggio) con (.+)"#) { return rule(.suffix, g[0]) }
        // 禁用詞
        if let g = match(b, #"(?:不准|不要|禁止|不許|不可以)(?:再)?(?:說|講|提到|提|用)(.+)"#),
           !["了", "啦", "吧", "話"].contains(strip(g[0])) { return rule(.ban, g[0]) }
        if let g = match(b, #"(?:never|don't|do not) (?:say|use|mention) (.+)"#) { return rule(.ban, g[0]) }
        if let g = match(b, #"(?:no digas|nunca digas|no uses|no menciones) (.+)"#) { return rule(.ban, g[0]) }
        if let g = match(b, #"(?:non dire|mai dire|non usare|non nominare) (.+)"#) { return rule(.ban, g[0]) }
        // 簡短
        if match(b, #"(?:簡短|短一點|簡潔|一句話|少說|精簡|short|brief|concise|one sentence|breve|corto|corta|una frase|conciso)"#) != nil {
            return rule(.brevity, "")
        }
        return rule(.note, b)
    }

    // MARK: - 執行

    public mutating func apply(_ cmd: RuleCommand, _ L: Lang = .zh) -> String {
        let i = [Lang.zh, .en, .es, .it].firstIndex(of: L)!
        switch cmd {
        case .add(let r):
            if [Rule.Kind.brevity, .aiName, .address, .suffix].contains(r.kind) {
                rules.removeAll { $0.kind == r.kind }   // 同類規則以最新為準
            }
            rules.append(r)
            let head = ["收到！已寫入規則第%n條：", "Done! Rule %n saved: ", "¡Hecho! Regla %n guardada: ", "Fatto! Regola %n salvata: "][i]
                .replacingOccurrences(of: "%n", with: "\(rules.count)")
            let tail = r.enforced
                ? ["。我會在每一則回覆強制執行。", ". I'll enforce it on every reply.", ". La aplicaré en cada respuesta.", ". La applicherò a ogni risposta."][i]
                : ["。已記錄在規則表，我會照做。", ". It's in my rulebook and I'll follow it.", ". Está en mi reglamento y la seguiré.", ". È nel mio regolamento e la seguirò."][i]
            return head + r.summary(L) + tail
        case .list:
            if rules.isEmpty {
                return ["目前沒有規則。用「規則：…」下達指令，我會永久遵守。", "No rules yet. Say “Rule: …” and I'll obey it forever.",
                        "Aún no hay reglas. Di «Regla: …» y la obedeceré siempre.", "Nessuna regola. Di' «Regola: …» e la rispetterò per sempre."][i]
            }
            return ["目前的規則：", "Current rules:", "Reglas actuales:", "Regole attuali:"][i] + "\n"
                + rules.enumerated().map { "\($0.offset + 1). \($0.element.summary(L))" }.joined(separator: "\n")
        case .delete(let n):
            guard n >= 1 && n <= rules.count else {
                return ["沒有第%n條規則。說「我的規則」可以查看。", "There's no rule %n. Say “my rules” to see them.",
                        "No hay regla %n. Di «mis reglas» para verlas.", "Non c'è la regola %n. Di' «le mie regole» per vederle."][i]
                    .replacingOccurrences(of: "%n", with: "\(n)")
            }
            let r = rules.remove(at: n - 1)
            return ["已刪除規則第%n條：", "Deleted rule %n: ", "Regla %n eliminada: ", "Regola %n eliminata: "][i]
                .replacingOccurrences(of: "%n", with: "\(n)") + r.summary(L)
        case .clear:
            rules.removeAll()
            return ["所有規則已清除。", "All rules cleared.", "Todas las reglas borradas.", "Tutte le regole cancellate."][i]
        }
    }

    /// 觸發規則：「我說 A 你就回 B」
    public func trigger(for message: String) -> String? {
        let m = RuleBook.strip(message).lowercased()
        return rules.last { $0.kind == .trigger && (m == $0.a.lowercased() || m.contains($0.a.lowercased())) }?.b
    }

    public var aiName: String? { rules.last { $0.kind == .aiName }?.a }

    static func isCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }

    /// 把所有規則套用到回覆上
    public func enforce(_ reply: String) -> String {
        var s = reply
        let cjk = RuleBook.isCJK(reply)
        if let name = aiName { s = s.replacingOccurrences(of: "NineSun", with: name) }
        for r in rules where r.kind == .ban && !r.a.isEmpty {
            s = s.replacingOccurrences(of: r.a, with: String(repeating: "＊", count: r.a.count), options: .caseInsensitive)
        }
        if rules.contains(where: { $0.kind == .brevity }) {
            if cjk, let i = s.firstIndex(where: { "。！？!?\n".contains($0) }), s.index(after: i) < s.endIndex {
                s = String(s[...i])
            } else if !cjk, let re = try? NSRegularExpression(pattern: #"[.!?](?=\s)"#),
                      let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
                      let r = Range(m.range, in: s) {
                s = String(s[..<r.upperBound])
            }
        }
        if let addr = rules.last(where: { $0.kind == .address })?.a, !s.hasPrefix(addr) {
            s = cjk ? "\(addr)，" + s : "\(addr), " + s
        }
        if let suf = rules.last(where: { $0.kind == .suffix })?.a, !s.hasSuffix(suf) {
            s += cjk ? suf : " " + suf
        }
        return s
    }
}
