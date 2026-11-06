import XCTest
@testable import EchoCore

/// 大腦考卷的分流：每一題照 App 的流程先給 NineSun 的引擎看，記下這題最後是誰回答
/// （引擎自己答、交給大腦聊天、交給大腦翻譯、交給大腦解讀命盤……），大腦評測只跑要給大腦的題目。
/// NINESUN_EXAM=考卷.jsonl NINESUN_ROUTE_OUT=輸出.jsonl …xctest EchoCoreTests.ExamRouteTests
final class ExamRouteTests: XCTestCase {
    func testRoute() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["NINESUN_EXAM"], let outPath = env["NINESUN_ROUTE_OUT"] else { throw XCTSkip("") }
        Intent.shared = try? Intent(weights: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("intent.bin")),
                                    metaJSON: Data(contentsOf: EchoCoreTests.resources.appendingPathComponent("intent.json")))
        let engine = try SimpleQuestionsProbeTests.engine()
        let lines = try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n")
        var out = ""
        var counts: [String: Int] = [:]
        for line in lines {
            guard var item = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let q = item["q"] as? String else { continue }
            let hist = (item["history"] as? [[String]] ?? []).map { ChatTurn(role: $0[0] == "user" ? .user : .echo, text: $0[1]) }
            let route = Self.route(q, item: item, history: hist, engine: engine)
            item["route"] = route.route
            if let t = route.text { item["engine_text"] = t }
            if let r = route.reading { item["reading"] = r }
            if let L = route.lang { item["lang"] = L }
            counts[route.route, default: 0] += 1
            let d = try JSONSerialization.data(withJSONObject: item, options: [.sortedKeys])
            out += String(decoding: d, as: UTF8.self) + "\n"
        }
        try out.write(toFile: outPath, atomically: true, encoding: .utf8)
        print("分流：", counts.sorted { $0.key < $1.key })
    }

    struct Route { var route: String; var text: String?; var reading: String?; var lang: String? }

    /// 跟 ChatViewModel.send／think 一樣的順序（大腦已下載、沒開雲端 AI）
    static func route(_ q: String, item: [String: Any], history: [ChatTurn], engine: EchoEngine) -> Route {
        let L = Lang.detect(q, fallback: .zh)
        // 考卷直接給了資料（模擬上網查到的、引擎查到的、命盤算好的）：照那個模式問大腦
        if item["character"] != nil {
            if let care = Safety.crisisReply(q, L) { return Route(route: "engine", text: care, lang: L.rawValue) }
            return Route(route: "roleplay", lang: L.rawValue)
        }
        if item["reading"] != nil { return Route(route: "reading", lang: L.rawValue) }
        if item["facts"] != nil || item["evidence"] != nil { return Route(route: "grounded", lang: L.rawValue) }
        if Translate.parse(q) != nil { return Route(route: "translate", lang: L.rawValue) }
        // 使用者有設生日（NINESUN_BIRTHDAY=2006-01-14）：命理的題目會真的算盤
        var ctx = EchoEngine.Context()
        if let b = ProcessInfo.processInfo.environment["NINESUN_BIRTHDAY"]?.split(separator: "-").compactMap({ Int($0) }), b.count == 3 {
            ctx.profile = UserProfile(birthday: BirthDay(year: b[0], month: b[1], day: b[2]))
        }
        let reply = engine.reply(to: q, history: history, context: ctx)
        let lang = reply.lang.rawValue
        if reply.profile != nil || reply.rules != nil { return Route(route: "engine", text: reply.turn.text, lang: lang) }
        if reply.turn.speak != nil { return Route(route: "translate", lang: L.rawValue) }
        if reply.webQuery != nil { return Route(route: "chat", lang: lang) }
        let fortune = BrainRoute.asksFortune(q)
        switch reply.turn.source {
        case .tool, .rule:
            if !fortune, BrainRoute.needsBirthday(reply.turn.text) { return Route(route: "chat", lang: lang) }
            return Route(route: "engine", text: reply.turn.text, lang: lang)
        case .reader, .grounded, .corrected:
            if !fortune { return Route(route: "chat", lang: lang) }
            if reply.turn.card == nil && reply.turn.text.count < 60 { return Route(route: "engine", text: reply.turn.text, lang: lang) }
            return Route(route: "reading", text: reply.turn.text,
                         reading: reply.turn.text + (reply.augmentFacts.isEmpty ? "" : "\n" + reply.augmentFacts), lang: lang)
        case .knowledge, .neural:
            return Route(route: "chat", text: reply.turn.text, lang: lang)
        }
    }
}
