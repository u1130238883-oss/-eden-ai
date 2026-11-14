import Foundation

/// 確定性工具：小模型不擅長精確計算與讀取時鐘，這些交給工具處理。
public enum ToolRouter {
    public static func handle(_ message: String, now: Date = Date(), lang: Lang = .zh) -> String? {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if lang == .zh, let r = timeAnswer(text, now: now) { return r }
        if lang != .zh, let r = foreignTime(text.lowercased(), now: now, lang) { return r }
        if let r = mathAnswer(text, lang) { return r }
        return nil
    }

    static func foreignTime(_ t: String, now: Date, _ L: Lang) -> String? {
        let timeQ = ["what time", "time is it", "qué hora", "que hora", "che ore", "che ora"]
        let dateQ = ["what's the date", "what is the date", "what day is it", "today's date", "qué día es", "que dia es",
                     "qué fecha", "che giorno è", "che data", "che giorno e"]
        let loc = Locale(identifier: ["en": "en_US", "es": "es_ES", "it": "it_IT"][L.rawValue] ?? "en_US")
        if timeQ.contains(where: { t.contains($0) }) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"; f.locale = loc
            return Loc.s("time.now", L, f.string(from: now))
        }
        if dateQ.contains(where: { t.contains($0) }) {
            let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .none; f.locale = loc
            f.calendar = Calendar(identifier: .gregorian)
            return Loc.s("time.date", L, f.string(from: now))
        }
        return nil
    }

    // MARK: - 時間 / 日期

    static func timeAnswer(_ text: String, now: Date) -> String? {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: now)
        let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
        if ["幾點", "現在時間", "什麼時間", "幾時"].contains(where: { text.contains($0) }) || text == "時間" {
            return String(format: "現在是 %02d:%02d。訊號時鐘校準完畢！", c.hour!, c.minute!)
        }
        if ["星期幾", "禮拜幾", "週幾"].contains(where: { text.contains($0) }) {
            return "今天是星期\(weekdays[c.weekday! - 1])。"
        }
        if ["幾號", "日期", "幾月幾"].contains(where: { text.contains($0) }) || (text.contains("今天") && text.contains("幾")) {
            return "今天是 \(c.year!) 年 \(c.month!) 月 \(c.day!) 日，星期\(weekdays[c.weekday! - 1])。"
        }
        return nil
    }

    // MARK: - 四則運算

    static func mathAnswer(_ text: String, _ L: Lang = .zh) -> String? {
        var expr = L == .zh ? text : text.lowercased()
        if L != .zh {
            for f in ["what is", "what's", "how much is", "calculate", "cuánto es", "cuanto es", "calcula", "quanto fa", "calcola"] {
                expr = expr.replacingOccurrences(of: f, with: "")
            }
            for (a, b) in [("divided by", "/"), ("dividido por", "/"), ("dividido entre", "/"), ("diviso per", "/"), ("diviso", "/"),
                           ("plus", "+"), ("minus", "-"), ("times", "*"), ("más", "+"), ("menos", "-"), ("por", "*"),
                           ("entre", "/"), ("più", "+"), ("meno", "-"), ("per", "*")] {
                expr = expr.replacingOccurrences(of: a, with: b)
            }
        }
        for (a, b) in [("加上", "+"), ("減去", "-"), ("乘以", "*"), ("除以", "/"),
                       ("加", "+"), ("減", "-"), ("乘", "*"), ("×", "*"), ("÷", "/"),
                       ("＋", "+"), ("－", "-"), ("＊", "*"), ("／", "/"), ("（", "("), ("）", ")"),
                       ("x", "*"), ("X", "*")] {
            expr = expr.replacingOccurrences(of: a, with: b)
        }
        for filler in ["等於多少", "等於幾", "是多少", "等於", "多少", "幫我算", "請問", "算一下", "計算", "=", "？", "?", "。", " "] {
            expr = expr.replacingOccurrences(of: filler, with: "")
        }
        let allowed = Set("0123456789.+-*/()")
        guard !expr.isEmpty, expr.allSatisfy({ allowed.contains($0) }),
              expr.contains(where: { "+-*/".contains($0) }),
              expr.contains(where: { $0.isNumber }) else { return nil }
        var p = ExprParser(Array(expr))
        guard let v = p.parse() else { return nil }
        guard v.isFinite else { return Loc.s("math.div0", L) }
        let shown: String
        if v == v.rounded() && abs(v) < 1e15 {
            shown = String(Int64(v))
        } else {
            shown = String(format: "%.6g", v)
        }
        return Loc.s("math", L, expr, shown)
    }
}

/// 遞迴下降的算式解析器：expr := term (('+'|'-') term)*
struct ExprParser {
    let s: [Character]
    var i = 0
    init(_ s: [Character]) { self.s = s }

    mutating func parse() -> Double? {
        guard let v = expr(), i == s.count else { return nil }
        return v
    }

    mutating func expr() -> Double? {
        guard var v = term() else { return nil }
        while i < s.count, s[i] == "+" || s[i] == "-" {
            let op = s[i]; i += 1
            guard let r = term() else { return nil }
            v = op == "+" ? v + r : v - r
        }
        return v
    }

    mutating func term() -> Double? {
        guard var v = factor() else { return nil }
        while i < s.count, s[i] == "*" || s[i] == "/" {
            let op = s[i]; i += 1
            guard let r = factor() else { return nil }
            v = op == "*" ? v * r : v / r
        }
        return v
    }

    mutating func factor() -> Double? {
        guard i < s.count else { return nil }
        if s[i] == "-" { i += 1; return factor().map { -$0 } }
        if s[i] == "(" {
            i += 1
            guard let v = expr(), i < s.count, s[i] == ")" else { return nil }
            i += 1
            return v
        }
        let start = i
        while i < s.count, s[i].isNumber || s[i] == "." { i += 1 }
        return Double(String(s[start..<i]))
    }
}
