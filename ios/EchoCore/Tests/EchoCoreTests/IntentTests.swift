import XCTest
@testable import EchoCore

/// NineSun 自己訓練的「理解問題」模型：手機上的 Swift 要跟訓練用的 Python 算出一模一樣的結果
/// （同一個雜湊、同一個閱讀模型讀出來的意思、同一套數學）。期望值由 Python 算出（ai/intent/train.py、encode.py）
final class IntentTests: XCTestCase {
    func testMatchesPythonAndUnderstandsQuestions() throws {
        let res = EchoCoreTests.resources
        let brain = try Brain(weights: Data(contentsOf: res.appendingPathComponent("reader.bin")),
                              metaJSON: Data(contentsOf: res.appendingPathComponent("reader.json")))
        let intent = try Intent(weights: Data(contentsOf: res.appendingPathComponent("intent.bin")),
                                metaJSON: Data(contentsOf: res.appendingPathComponent("intent.json")))
        let cases: [(String, String, Float)] = [
            ("格林童話有什麼故事？", "items", 0.9588),
            ("少年維特的煩惱講了什麼", "content", 0.9997),
            ("暗物質是怎麼一回事", "define", 0.9994),
            ("京都和大阪哪個好玩", "place", 0.5560),
            ("失眠怎麼辦", "advice", 1.0000),
            ("天空為什麼是藍色的", "reason", 1.0000),
            ("台北101有多高", "quantity", 1.0000),
            ("我今天好累", "chat", 1.0000),
            ("宮崎駿有哪些作品", "items", 1.0000),
            ("寄生上流值得看嗎", "opinion", 1.0000),
        ]
        for (q, label, p) in cases {
            let top = try XCTUnwrap(intent.top(q, brain: brain), q)
            XCTAssertEqual(top.label, label, q)
            XCTAssertEqual(top.p, p, accuracy: 0.01, q)
        }
        // 沒有閱讀模型就不猜（模型用到「意思」）
        XCTAssertNil(intent.top("格林童話有什麼故事", brain: nil))
    }
}
