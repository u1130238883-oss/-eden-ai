import XCTest
@testable import EchoCore

/// 網頁錄音帶：
/// - 錄（CI 有網路）：NINESUN_TAPE_OUT=路徑 → 每一題真的上網查，把搜尋結果和網頁文字錄下來
/// - 重播（沒有網路也可以）：NINESUN_TAPE=路徑 → 用錄下來的網頁重跑，看回答有沒有抓到重點
/// 回答寫到 NINESUN_TAPE_ANSWERS（沒設就印出來）
final class WebTapeTests: XCTestCase {
    static func questions() throws -> [String] {
        let focus = ProcessInfo.processInfo.environment["NINESUN_TAPE_FOCUS"] != nil
        let url = try XCTUnwrap(Bundle.module.url(forResource: focus ? "web_questions_focus" : "web_questions", withExtension: "txt", subdirectory: "Fixtures"))
        let only = ProcessInfo.processInfo.environment["NINESUN_TAPE_ONLY"].map { Set($0.split(separator: "|").map(String.init)) }
        return try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && (only?.contains($0) ?? true) }
    }

    func run(_ tape: WebTape) async throws {
        #if os(Linux)
        let t = EchoCoreTests(name: "helper", testClosure: { _ in })
        #else
        let t = EchoCoreTests()
        #endif
        let engine = try t.makeEngine(seed: 5)
        var ctx = EchoEngine.Context(now: t.date(2026, 10, 23, 11))
        ctx.profile = UserProfile(birthday: BirthDay(year: 2006, month: 1, day: 14), hour: 8, minute: 0, male: true)
        let res = EchoCoreTests.resources
        Brain.shared = try? Brain(weights: Data(contentsOf: res.appendingPathComponent("reader.bin")),
                                  metaJSON: Data(contentsOf: res.appendingPathComponent("reader.json")))
        WebTape.shared = tape
        defer { WebTape.shared = nil }
        var out = ""
        for q in try WebTapeTests.questions() {
            FileHandle.standardError.write("TAPE> \(q)\n".data(using: .utf8)!)
            let r = engine.reply(to: q, context: ctx)
            out += "===== 問：\(q)\n"
            guard let wq = r.webQuery else {
                out += "（沒上網）" + r.turn.text.prefix(200) + "\n\n"
                continue
            }
            // 錄的時候像一個人在問：一題問完隔一陣子再問下一題（一口氣問太快，搜尋引擎會把我們當機器人擋掉）
            if !tape.replaying {
                let focus = ProcessInfo.processInfo.environment["NINESUN_TAPE_FOCUS"] != nil
                try? await Task.sleep(nanoseconds: (focus ? 40 : 8) * 1_000_000_000)
            }
            let w = await WebAgent.run(wq, lang: .zh)
            out += "[題型 \(w.want ?? "-")] \n" + w.text + "\n\n"
        }
        out += "TAPE searches=\(tape.counts.searches) pages=\(tape.counts.pages) misses=\(tape.misses.count)\n"
        if let p = ProcessInfo.processInfo.environment["NINESUN_TAPE_ANSWERS"] {
            try out.write(toFile: p, atomically: true, encoding: .utf8)
        } else {
            print(out)
        }
    }

    func testRecord() async throws {
        guard let path = ProcessInfo.processInfo.environment["NINESUN_TAPE_OUT"] else { throw XCTSkip("只在 CI 錄") }
        let tape = WebTape(replaying: false)
        try await run(tape)
        try tape.save(to: URL(fileURLWithPath: path))
    }

    func testReplay() async throws {
        guard let path = ProcessInfo.processInfo.environment["NINESUN_TAPE"] else { throw XCTSkip("沒有錄音帶") }
        try await run(WebTape(contentsOf: URL(fileURLWithPath: path)))
    }
}
