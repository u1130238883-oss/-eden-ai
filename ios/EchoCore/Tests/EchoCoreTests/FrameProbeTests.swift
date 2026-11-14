import XCTest
@testable import EchoCore

/// 本機看理解結果（PROBE_FRAME="q1|q2"）
final class FrameProbeTests: XCTestCase {
    func testFrameProbe() throws {
        guard let qs = ProcessInfo.processInfo.environment["PROBE_FRAME"] else { throw XCTSkip("probe") }
        for q in qs.split(separator: "|").map(String.init) {
            let f = Understanding.frame(q)
            FileHandle.standardError.write("F> \(q) ⇒ \(f.want) subj=\(f.subject) s=\(f.searches.prefix(2))\n".data(using: .utf8)!)
        }
    }
}



final class CompareProbeTests: XCTestCase {
    func testCompareProbe() throws {
        guard ProcessInfo.processInfo.environment["PROBE_CMP"] != nil else { throw XCTSkip("probe") }
        let D = Destiny(BirthDay(year: 2006, month: 1, day: 14))
        for y in [2026, 2027] {
            FileHandle.standardError.write("C> \(y) year=\(D.year(y).text) trig=\(D.triggeredAspects(y).map(\.text))\n".data(using: .utf8)!)
        }
    }
}
