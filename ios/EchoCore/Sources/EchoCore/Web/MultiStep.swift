import Foundation

/// 要分兩步想的問題：「台北101比玉山高多少」「玉山和富士山哪個高」「太陽的質量是地球的幾倍」。
/// 像人一樣：先分別查兩個數字，換成同一個單位，再相減、比大小或算倍數，並把每一步寫出來。
public enum MultiStep {
    public enum Op: Equatable, Sendable { case diff, which, ratio }

    public struct Plan: Equatable, Sendable {
        public let a: String, b: String
        /// 比的是什麼（高、重、人口……）
        public let adj: String
        public let op: Op
        /// 分別要查的兩個小問題
        public let subA: String, subB: String
    }

    static let adjs = ["便宜", "年輕", "高", "重", "大", "長", "遠", "快", "深", "寬", "貴", "老", "多", "矮", "輕", "小", "短", "近", "慢", "淺", "窄", "少", "低"]
    /// 反義詞 → 要查的那一邊（問「矮多少」也是查「多高」）
    static let base: [String: String] = ["矮": "高", "低": "高", "輕": "重", "小": "大", "短": "長", "近": "遠", "慢": "快", "淺": "深",
                                         "窄": "寬", "少": "多", "便宜": "貴", "年輕": "老"]
    static let opposite: [String: String] = ["高": "矮", "重": "輕", "大": "小", "長": "短", "遠": "近", "快": "慢", "深": "淺",
                                             "寬": "窄", "多": "少", "貴": "便宜", "老": "年輕"]
    /// 「X 的人口」「X 的面積」：比的是這個量
    static let attrs = ["人口", "面積", "高度", "海拔", "距離", "質量", "重量", "體重", "身高", "年齡", "價格", "長度", "深度", "速度",
                        "半徑", "直徑", "體積", "溫度", "GDP", "壽命"]

    public static func parse(_ raw: String) -> Plan? {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "？?。！!"))
        guard q.count <= 40 else { return nil }
        let A = "(" + adjs.joined(separator: "|") + ")"
        var a = "", b = "", adj = "", op = Op.diff
        if let m = Understanding.match(q, "^(.{1,20}?)比(.{1,20}?)" + A + "(?:了|出)?(多少倍|幾倍|多少|幾|多遠|多高)$") {
            a = m[1]; b = m[2]; adj = m[3]; op = m[4].contains("倍") ? .ratio : .diff
        } else if let m = Understanding.match(q, "^(.{1,20}?)(?:和|跟|與|還是)(.{1,20}?)(?:哪個|哪一個|哪座|哪一座|哪條|哪一條|哪國|哪一國|誰)(?:比較|更|最)?" + A + "$") {
            a = m[1]; b = m[2]; adj = m[3]; op = .which
        } else if let m = Understanding.match(q, "^(.{1,20}?)是(.{1,20}?)的(?:幾倍|多少倍)$") {
            a = m[1]; b = m[2]; op = .ratio
        } else if let m = Understanding.match(q, "^(.{1,20}?)(?:和|跟|與)(.{1,20}?)(?:的)?(?:" + attrs.joined(separator: "|") + ")?(?:相差|差了|差)(?:多少|幾)$") {
            a = m[1]; b = m[2]; op = .diff
        } else {
            return nil
        }
        a = a.trimmingCharacters(in: .whitespaces); b = b.trimmingCharacters(in: .whitespaces)
        // 「台灣人口比日本多多少」：B 也要帶上「人口」
        let attr = attrs.first { a.contains($0) } ?? attrs.first { b.contains($0) } ?? attrs.first { q.contains($0) }
        if let attr {
            if !a.contains(attr) { a += "的" + attr }
            if !b.contains(attr) { b += "的" + attr }
        }
        guard !a.isEmpty, !b.isEmpty, a != b else { return nil }
        // 不是在比數量的（「我比他高多少分」「你比較喜歡哪個」）：兩邊都要像一個東西的名字
        for x in [a, b] where ["我", "你", "他", "她", "誰", "這", "那"].contains(where: { x.hasPrefix($0) }) { return nil }
        let look = base[adj] ?? adj
        func sub(_ x: String) -> String? {
            if let attr {
                switch attr {
                case "人口": return x + "有多少"
                case "面積": return x + "有多大"
                case "距離": return x + "有多遠"
                case "高度", "海拔", "身高": return x + "有多高"
                default: return x + "是多少"
                }
            }
            switch look {
            case "高": return x + "有多高"
            case "重": return x + "有多重"
            case "長": return x + "有多長"
            case "遠": return x + "有多遠"
            case "大": return x + "的面積有多大"
            case "深": return x + "有多深"
            case "快": return x + "有多快"
            case "寬": return x + "有多寬"
            case "貴": return x + "多少錢"
            case "多": return x + "有多少"
            case "老": return x + "幾歲"
            default: return nil
            }
        }
        guard let sa = sub(a), let sb = sub(b) else { return nil }
        return Plan(a: a, b: b, adj: adj, op: op, subA: sa, subB: sb)
    }

    // MARK: - 數字和單位

    /// 單位 → (哪一類, 換成基本單位要乘多少)
    static let unitTable: [(String, String, Double)] = [
        ("平方公里", "area", 1), ("km²", "area", 1), ("平方公尺", "area", 1e-6), ("公頃", "area", 0.01),
        ("公里/小時", "speed", 1), ("km/h", "speed", 1), ("公里/秒", "speed", 3600), ("km/s", "speed", 3600), ("m/s", "speed", 3.6),
        ("公尺/秒", "speed", 3.6), ("米/秒", "speed", 3.6),
        ("公里", "len", 1000), ("千米", "len", 1000), ("km", "len", 1000), ("公分", "len", 0.01), ("厘米", "len", 0.01), ("cm", "len", 0.01),
        ("英尺", "len", 0.3048), ("英里", "len", 1609.344), ("公尺", "len", 1), ("米", "len", 1), ("m", "len", 1),
        ("公斤", "mass", 1), ("千克", "mass", 1), ("kg", "mass", 1), ("公噸", "mass", 1000), ("噸", "mass", 1000), ("克", "mass", 0.001),
        ("萬人", "people", 1e4), ("億人", "people", 1e8), ("人", "people", 1),
        ("美元", "usd", 1), ("新台幣", "twd", 1), ("台幣", "twd", 1), ("元", "twd", 1),
        ("歲", "age", 1), ("年", "year", 1), ("℃", "temp", 1), ("度", "temp", 1),
    ]

    /// 「3,952公尺」「1.496億公里」→ (數值, 單位, 類別, 換成基本單位後)
    public static func quantity(_ raw: String) -> (value: Double, unit: String, kind: String, base: Double)? {
        // 全形數字「１億」→「1億」
        let s = String(String.UnicodeScalarView(raw.unicodeScalars.map { (0xFF10...0xFF19).contains($0.value) ? Unicode.Scalar($0.value - 0xFF10 + 0x30)! : $0 }))
        let units = unitTable.map(\.0)
        // 「1億2321萬9千人」：好幾段加起來
        if let m = Understanding.match(s, #"(?:(\d+(?:\.\d+)?)億)?(?:(\d+(?:\.\d+)?)萬)?(?:(\d+(?:\.\d+)?)千)?(\d+)?\s*("# + units.sorted { $0.count > $1.count }.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")"),
           [m[1], m[2], m[3]].filter({ !$0.isEmpty }).count >= 2 {
            let v = (Double(m[1]) ?? 0) * 1e8 + (Double(m[2]) ?? 0) * 1e4 + (Double(m[3]) ?? 0) * 1e3 + (Double(m[4]) ?? 0)
            if let u = unitTable.first(where: { $0.0 == m[5] }) {
                let factor = (u.0 == "萬人" || u.0 == "億人") ? 1 : u.2
                return (v, u.0, u.1, v * factor)
            }
        }
        guard let n = Understanding.numbers(s, units: units, rates: true).first else { return nil }
        // 最長、而且在數字後面的單位
        guard let u = unitTable.filter({ n.shown.hasSuffix($0.0) }).max(by: { $0.0.count < $1.0.count }) else { return nil }
        // numbers() 已經把「萬」「億」算進去了；「萬人」「億人」的萬／億也已經乘過，單位只算「人」
        let factor = (u.0 == "萬人" || u.0 == "億人") ? 1 : u.2
        return (n.value, u.0, u.1, n.value * factor)
    }

    static func fmt(_ v: Double) -> String {
        let a = abs(v)
        if a >= 1e8 { return trim(String(format: "%.2f", v / 1e8)) + "億" }
        if a >= 1e5 { return trim(String(format: "%.1f", v / 1e4)) + "萬" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = a < 10 ? 2 : (a < 1000 ? 1 : 0)
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }

    static func trim(_ s: String) -> String {
        guard s.contains(".") else { return s }
        var t = s
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return t
    }

    /// 兩個答案換成同一個單位後，算出結果。回傳（回答那一句, 計算那一步）
    public static func compute(_ p: Plan, _ ansA: String, _ ansB: String) -> (answer: String, math: String)? {
        guard let qa = quantity(ansA), let qb = quantity(ansB), qa.kind == qb.kind, qb.base != 0 else { return nil }
        // 用 A 的單位表示（A 是「萬人」時用「人」，fmt 會自己寫成萬、億）
        let unitFactor = unitTable.first { $0.0 == qa.unit }.map { (qa.unit == "萬人" || qa.unit == "億人") ? 1 : $0.2 } ?? 1
        let shownUnit = (qa.unit == "萬人" || qa.unit == "億人") ? "人" : qa.unit
        let va = qa.base / unitFactor, vb = qb.base / unitFactor
        let look = base[p.adj] ?? (p.adj.isEmpty ? "多" : p.adj)
        let more = look, less = opposite[look] ?? "少"
        switch p.op {
        case .ratio:
            let r = qa.base / qb.base
            let math = "\(fmt(va))\(shownUnit) ÷ \(fmt(vb))\(shownUnit) ≈ \(trim(String(format: r >= 10 ? "%.0f" : "%.2f", r)))"
            return ("\(p.a)大約是\(p.b)的 \(trim(String(format: r >= 10 ? "%.0f" : "%.2f", r))) 倍。", math)
        case .diff, .which:
            let d = abs(va - vb)
            let math = "\(fmt(max(va, vb)))\(shownUnit) − \(fmt(min(va, vb)))\(shownUnit) = \(fmt(d))\(shownUnit)"
            if d / max(abs(va), abs(vb), 1e-9) < 0.005 { return ("\(p.a)和\(p.b)差不多（都是 \(fmt(va))\(shownUnit) 左右）。", math) }
            let (big, small) = va > vb ? (p.a, p.b) : (p.b, p.a)
            let ratio = max(va, vb) / max(min(va, vb), 1e-9)
            let times = ratio >= 1.5 ? "，大約是 \(trim(String(format: ratio >= 10 ? "%.0f" : "%.1f", ratio))) 倍" : ""
            if p.op == .which {
                return ("\(big)比較\(more)：比\(small)\(more) \(fmt(d))\(shownUnit)\(times)。", math)
            }
            // 「A 比 B 高多少」但其實 A 比較矮：照實講
            let asked = base[p.adj] == nil ? more : less
            let aIsBigger = va > vb
            if (asked == more) == aIsBigger {
                return ("\(p.a)比\(p.b)\(p.adj) \(fmt(d))\(shownUnit)\(times)。", math)
            }
            return ("其實\(p.a)比\(p.b)\(aIsBigger ? more : less) \(fmt(d))\(shownUnit)（你問的是\(p.adj)多少，但查到的數字剛好相反）。", math)
        }
    }

    /// 「答案：508公尺（3 個網站都這樣說）。」→「508公尺」；來源網站
    static func short(_ text: String) -> (answer: String, host: String)? {
        guard let a = Understanding.match(text, #"答案：([^（。\n]+)"#)?[1].trimmingCharacters(in: .whitespaces), !a.isEmpty else { return nil }
        let host = Understanding.match(text, #"依據：[^\n]*（([A-Za-z0-9.-]+\.[A-Za-z]{2,})）"#)?[1] ?? ""
        return (a, host)
    }

    /// 分兩步查，再算
    static func solve(_ p: Plan, lang L: Lang, progress: (@Sendable (String) -> Void)?) async -> WebAgent.Result? {
        progress?("① 這題要分兩步想：先查「\(p.subA)」和「\(p.subB)」，再來比")
        async let ra = WebAgent.run(p.subA, lang: L)
        async let rb = WebAgent.run(p.subB, lang: L)
        let (x, y) = await (ra, rb)
        progress?("② 兩題都查完了，換成同一個單位來算")
        func from(_ h: String) -> String { h.isEmpty ? "" : "（\(h)）" }
        let oa = short(x.text), ob = short(y.text)
        guard let sa = oa, let sb = ob, let c = compute(p, sa.answer, sb.answer) else {
            // 兩個都沒查到：交給一般的查法；查到一個、或單位對不起來：照實說做到哪一步，不亂湊答案
            guard oa != nil || ob != nil else { return nil }
            let lines: [String] = [
                "📌 回答",
                "這題要先分別查兩個數字再比較，但我只查到一部分，沒辦法算出可靠的結果：",
                "① 「\(p.subA)」→ " + (oa.map { $0.answer + from($0.host) } ?? "沒查到清楚的數字"),
                "② 「\(p.subB)」→ " + (ob.map { $0.answer + from($0.host) } ?? "沒查到清楚的數字"),
                oa != nil && ob != nil ? "③ 兩個數字的單位對不起來，不能直接相減。" : "③ 少了一個數字，先不算，免得給你錯的答案。",
                "可以換個說法再問一次，或分開問這兩題。",
            ]
            var r = WebAgent.Result(text: lines.joined(separator: "\n"), card: nil, found: true, engines: x.engines)
            r.want = "multistep"
            r.answered = false
            r.timing = "分兩步：\(x.timing) ｜ \(y.timing)"
            return r
        }
        let lines = [
            "📌 回答",
            c.answer,
            "🧠 我的思考步驟：",
            "① 先查「\(p.subA)」→ \(sa.answer)\(from(sa.host))",
            "② 再查「\(p.subB)」→ \(sb.answer)\(from(sb.host))",
            "③ 換成同一個單位再算：\(c.math)",
            "🤔 把握程度" + (x.confident && y.confident ? "高（兩個數字都有可靠來源）。" : "中（其中一個數字來源不多，建議再確認）。"),
        ]
        var engines = x.engines
        for (k, v) in y.engines { engines[k, default: 0] += v }
        var r = WebAgent.Result(text: lines.joined(separator: "\n"), card: nil, found: true, engines: engines)
        r.confident = x.confident && y.confident
        r.shortAnswer = c.answer
        r.evidence = Array(x.evidence.prefix(2)) + Array(y.evidence.prefix(2))
        r.want = "multistep"
        r.timing = "分兩步：\(x.timing) ｜ \(y.timing)"
        return r
    }
}
