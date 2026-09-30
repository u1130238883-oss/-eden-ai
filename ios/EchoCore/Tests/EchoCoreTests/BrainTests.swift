import XCTest
@testable import EchoCore

/// 大腦（閱讀理解模型）：Swift 讀出來的答案要和 Python（ai/brain_fixture.py）一模一樣，
/// 而且讀網頁時要挑出真正在回答的那一段，不是開頭那段。
final class BrainTests: XCTestCase {
    struct Case: Decodable {
        let question: String
        let passage: String
        let text: String
        let score: Float
        let start: Int
        let end: Int
    }

    static let resources = EchoCoreTests.resources

    func loadBrain() throws -> Brain {
        guard FileManager.default.fileExists(atPath: Self.resources.appendingPathComponent("reader.bin").path) else {
            throw XCTSkip("reader.bin 還沒訓練好")
        }
        return try Brain(weights: Data(contentsOf: Self.resources.appendingPathComponent("reader.bin")),
                  metaJSON: Data(contentsOf: Self.resources.appendingPathComponent("reader.json")))
    }

    func testReadMatchesPython() throws {
        let brain = try loadBrain()
        guard let url = Bundle.module.url(forResource: "brain", withExtension: "json", subdirectory: "Fixtures") else {
            throw XCTSkip("brain.json 還沒產生")
        }
        for c in try JSONDecoder().decode([Case].self, from: Data(contentsOf: url)) {
            let got = brain.read(question: c.question, passage: c.passage)
            XCTAssertEqual(got?.text, c.text, c.question)
            XCTAssertEqual(got?.start, c.start, c.question)
            XCTAssertEqual(got?.score ?? 0, c.score, accuracy: max(0.05, abs(c.score) * 0.01), c.question)
        }
    }

    func testMatchFeaturesUseCharacters() throws {
        let brain = try loadBrain()
        // 「䶮」不在字表裡，也要對得到；標點不算
        let (mq, mp) = brain.matchFeatures(["劉", "䶮", "？"], ["劉", "䶮", "是", "誰", "？"])
        XCTAssertEqual(mq, [2, 2, 0])
        XCTAssertEqual(mp, [2, 2, 0, 0, 0])
    }

    func testThinkPicksTheAnsweringPassageNotTheOpening() throws {
        let brain = try loadBrain()
        let page = "台北101是位於台灣台北市信義區的摩天大樓，由李祖原聯合建築師事務所設計，是台灣的地標之一。大樓的外觀設計靈感來自竹子，象徵節節高升。"
            + "每年跨年夜都會在這裡施放煙火，吸引數十萬人前往觀賞。\n"
            + "台北101樓高508公尺，地上101層、地下5層，2004年落成時是世界最高的建築物，這個紀錄一直保持到2010年杜拜哈里發塔完工為止。"
        let c = Think.conclude(question: "台北101有多高？", pages: [.init(text: page, host: "zh.wikipedia.org")],
                               snippets: [], brain: brain)
        XCTAssertNotNil(c)
        XCTAssertTrue(c!.text.contains("508"), c!.text)
    }
}
