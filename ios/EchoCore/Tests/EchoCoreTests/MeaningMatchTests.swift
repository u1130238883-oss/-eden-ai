import XCTest
@testable import EchoCore

/// 意思比對模型（NineSun 自己訓練的）：Swift 算出來的要跟 Python（ai/meaning/train.py，同一份 f16 權重）一樣
final class MeaningMatchTests: XCTestCase {
    func testMatchesPython() throws {
        let res = EchoCoreTests.resources
        guard FileManager.default.fileExists(atPath: res.appendingPathComponent("meaning.bin").path) else { throw XCTSkip("沒有 meaning.bin") }
        let brain = try Brain(weights: Data(contentsOf: res.appendingPathComponent("reader.bin")),
                              metaJSON: Data(contentsOf: res.appendingPathComponent("reader.json")))
        let mm = try MeaningMatch(weights: Data(contentsOf: res.appendingPathComponent("meaning.bin")),
                                  metaJSON: Data(contentsOf: res.appendingPathComponent("meaning.json")))
        let cases: [(String, String, Float)] = [
            ("排水孔堵住了怎麼辦", "排水孔堵住", 0.9994),
            ("什麼是股票", "股票", 0.9962),
            ("今天天氣真好", "__none__", 0.9903),
            ("我真的覺得活著好累喔", "__crisis__", 0.9994),
            ("我想學做紅燒肉", "紅燒肉", 0.8806),
            ("狗狗一直亂叫怎麼辦", "狗一直叫", 0.9949),
            ("下雨天衣服都乾不了", "晾衣服", 0.9807)
        ]
        for (q, label, p) in cases {
            let t = try XCTUnwrap(mm.top(q, brain: brain), q)
            XCTAssertEqual(t.label, label, q)
            XCTAssertEqual(t.p, p, accuracy: 0.01, q)
        }
    }
}
