import XCTest
@testable import EchoCore

/// 網頁錄音帶：
/// - 錄（CI 有網路）：NINESUN_TAPE_OUT=路徑 → 每一題真的上網查，把搜尋結果和網頁文字錄下來
/// - 重播（沒有網路也可以）：NINESUN_TAPE=路徑 → 用錄下來的網頁重跑，看回答有沒有抓到重點
/// 回答寫到 NINESUN_TAPE_ANSWERS（沒設就印出來）
final class WebTapeTests: XCTestCase {
    static func questions() throws -> [String] {
        let env = ProcessInfo.processInfo.environment
        let focus = env["NINESUN_TAPE_FOCUS"] != nil
        // NINESUN_TAPE_SET=graded：大批有標準答案的考題（「問題|關鍵字」，這裡只取問題）
        let name = env["NINESUN_TAPE_SET"].map { "web_questions_" + $0 } ?? (focus ? "web_questions_focus" : "web_questions")
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures"))
        let only = env["NINESUN_TAPE_ONLY"].map { Set($0.split(separator: "|").map(String.init)) }
        var qs = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { String($0.split(separator: "|", maxSplits: 1).first ?? Substring($0)) }
            .filter { only?.contains($0) ?? true }
        // NINESUN_TAPE_SHARD=3/8：好幾台機器分著問（每台的網路位址不同，比較不會被搜尋引擎擋）
        if let sh = env["NINESUN_TAPE_SHARD"]?.split(separator: "/").compactMap({ Int($0) }), sh.count == 2, sh[1] > 0 {
            qs = qs.enumerated().filter { $0.offset % sh[1] == sh[0] }.map(\.element)
        }
        return qs
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
        Intent.shared = try? Intent(weights: Data(contentsOf: res.appendingPathComponent("intent.bin")),
                                    metaJSON: Data(contentsOf: res.appendingPathComponent("intent.json")))
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
                let gap = ProcessInfo.processInfo.environment["NINESUN_TAPE_GAP"].flatMap { UInt64($0) } ?? (focus ? 120 : 8)
                try? await Task.sleep(nanoseconds: gap * 1_000_000_000)
            }
            let w = await WebAgent.run(wq, lang: .zh)
            out += "[題型 \(w.want ?? "-")] \n" + w.text + "\n\n"
            // NINESUN_TAPE_JSONL：把引擎查到的結果（答案、證據、有沒有把握）存成一行一題，拿來出「引擎查＋大腦說」的考題
            if let jp = ProcessInfo.processInfo.environment["NINESUN_TAPE_JSONL"] {
                let row: [String: Any] = ["q": q, "text": WebAgent.plain(w.text), "evidence": w.evidence, "answered": w.answered, "confident": w.confident,
                                          "found": w.found, "want": w.want ?? "", "asis": WebAgent.showAsIs(w)]
                if let d = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]), let h = FileHandle(forWritingAtPath: jp) ?? { FileManager.default.createFile(atPath: jp, contents: nil); return FileHandle(forWritingAtPath: jp) }() {
                    h.seekToEndOfFile(); h.write(d); h.write("\n".data(using: .utf8)!); h.closeFile()
                }
            }
            if ProcessInfo.processInfo.environment["NINESUN_TAPE_DEBUG"] != nil { out += "DEBUG " + Understanding.lastListDebug + "\n\n" }
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
