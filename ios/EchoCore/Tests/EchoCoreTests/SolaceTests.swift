import XCTest
@testable import EchoCore

/// 安慰：跟 ai/solace.py 逐字一樣；不同生日、不同時間（大運、流年、流月、日夜宮）說出不同的處境
final class SolaceTests: XCTestCase {
    struct Case: Decodable {
        let text: String
        let birthday: [Int]?
        let now: [Int]
        let reply: String?
    }

    func testMatchesPythonReference() throws {
        let data = try Data(contentsOf: Bundle.module.url(forResource: "solace", withExtension: "json", subdirectory: "Fixtures")!)
        let cases = try JSONDecoder().decode([Case].self, from: data)
        XCTAssertGreaterThan(cases.count, 100)
        var bad = 0
        for c in cases {
            let b = c.birthday.map { BirthDay(year: $0[0], month: $0[1], day: $0[2]) }
            let got = Solace.reply(c.text, birthday: b, y: c.now[0], m: c.now[1], d: c.now[2], hour: c.now[3])
            if got != c.reply {
                bad += 1
                if bad <= 3 { XCTFail("「\(c.text)」\(c.birthday ?? []) \(c.now)\n期望：\(c.reply ?? "nil")\n實際：\(got ?? "nil")") }
            }
        }
        XCTAssertEqual(bad, 0)
    }

    func testDifferentBirthdaysSeeDifferentSituations() throws {
        let a = try XCTUnwrap(Solace.reply("我今天好累", birthday: BirthDay(year: 2006, month: 1, day: 14), y: 2026, m: 10, d: 22, hour: 14))
        let b = try XCTUnwrap(Solace.reply("我今天好累", birthday: BirthDay(year: 1990, month: 5, day: 5), y: 2026, m: 10, d: 22, hour: 14))
        XCTAssertNotEqual(a, b)
        for r in [a, b] {
            XCTAssertTrue(r.contains("這幾年（") && r.contains("・今年：") && r.contains("・這個月：") && r.contains("今天白天"), r)
            // 不講算法代號
            XCTAssertNil(r.range(of: #"[好正壞]\d|因\d"#, options: .regularExpression), r)
        }
        // 不是在講心情
        for q in ["我壓力大的時候會怎樣", "今天運勢", "累積了很多點數", "失眠怎麼改善"] { XCTAssertNil(Solace.reply(q, birthday: nil, now: Date()), q) }
        XCTAssertTrue(Solace.isFeeling("我跟男朋友分手了"))
    }
}
