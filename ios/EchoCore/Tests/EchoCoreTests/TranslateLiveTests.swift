import XCTest
@testable import EchoCore

/// 真的連網：從四語語料抽一批，用 Google 翻譯翻，跟語料的答案比。只在 CI 的「Live translation check」步驟跑（NINESUN_LIVE=1）。
/// 對不上的列出來，常見又翻錯的說法就補進道地說法表（Native.swift）。
final class TranslateLiveTests: XCTestCase {
    func testGoogleAgainstCorpus() async throws {
        guard ProcessInfo.processInfo.environment["NINESUN_LIVE"] == "1" else { throw XCTSkip("只在 CI 連網時跑") }
        let url = try XCTUnwrap(Bundle.module.url(forResource: "translate_corpus", withExtension: "json", subdirectory: "Fixtures"))
        let c = try JSONDecoder().decode(TranslateCorpusTests.Corpus.self, from: Data(contentsOf: url))
        var rng = SystemRandomNumberGenerator()
        let langs: [(String, Translate.Code)] = [("zh", .zh), ("en", .en), ("es", .es), ("it", .it)]
        var lines: [String] = [], ok = 0, n = 0, failed = 0
        for (group, items) in [("單字", c.words), ("短語", c.phrases), ("句子", c.sentences)] {
            for item in items.shuffled(using: &rng).prefix(40) {
                let all = ["zh": item.zh, "en": item.en, "es": item.es, "it": item.it]
                let s = langs.randomElement(using: &rng)!
                let t = langs.filter { $0.0 != s.0 }.randomElement(using: &rng)!
                let src = all[s.0]!.components(separatedBy: "/")[0]
                guard let r = await Translate.google(.init(text: src, source: s.1, target: t.1)) else { failed += 1; continue }
                n += 1
                let refs = all[t.0]!.components(separatedBy: "/").map(TranslateCorpusTests.norm)
                let got = [r.text] + r.alternatives
                if got.contains(where: { refs.contains(TranslateCorpusTests.norm($0)) || refs.contains("to" + TranslateCorpusTests.norm($0)) }) {
                    ok += 1
                } else {
                    lines.append("LIVE-TR ✗ [\(group)] \(s.0)→\(t.0) 「\(src)」 Google：「\(r.text)」 語料：「\(all[t.0]!)」")
                }
                try await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        let summary = "LIVE-TR 跟語料一樣：\(ok)/\(n)（連不上 \(failed) 題）"
        let out = ([summary] + lines).joined(separator: "\n")
        print(out)
        if let p = ProcessInfo.processInfo.environment["NINESUN_LIVE_OUT"] { try? out.write(toFile: p, atomically: true, encoding: .utf8) }
    }
}
