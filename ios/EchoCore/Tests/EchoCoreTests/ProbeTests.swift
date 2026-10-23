import XCTest
@testable import EchoCore

/// 除錯用：印出幾句話的理解結果
final class ProbeTests: XCTestCase {
    func testProbe() {
        for q in ["請問「同意」和「巨大」是反義詞嗎", "考考你，「不一樣」和「一樣」是反義詞嗎", "什麼詞跟忙意思相反", "消極的相反詞是啥呢", "今天謝啦", "你知道嗎，謝啦", "和平和戰爭是反義詞嗎", "同意跟反對是反義詞嗎",
                  "一石二鳥是什麼意思", "kill two birds with one stone的成語是什麼", "我最近心灰意冷", "我老是三心二意怎麼辦"] {
            print("PROBE「\(q)」 bare=\(Understanding.bare(q)) ant=\(String(describing: Antonyms.parse(q))) mood=\(Affect.detect(q).rawValue) idiom=\(String(describing: Idioms.understand(q)))")
        }
    }
}
