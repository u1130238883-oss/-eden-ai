import Foundation

/// 易經起卦（逐行對應 ai/iching.py）。爻由下（初爻）到上，1=陽 0=陰。
public enum IChing {
    /// 先天數 1...8：(名, 象, 三爻)
    public static let trigrams: [Int: (name: String, image: String, lines: [Int])] = [
        1: ("乾", "天", [1, 1, 1]), 2: ("兌", "澤", [1, 1, 0]), 3: ("離", "火", [1, 0, 1]), 4: ("震", "雷", [1, 0, 0]),
        5: ("巽", "風", [0, 1, 1]), 6: ("坎", "水", [0, 1, 0]), 7: ("艮", "山", [0, 0, 1]), 8: ("坤", "地", [0, 0, 0]),
    ]
    public static let lineNames = ["初", "二", "三", "四", "五", "上"]

    static func trigramNumber(named n: String) -> Int { trigrams.first { $0.value.name == n }!.key }
    static func trigramNumber(lines l: [Int]) -> Int { trigrams.first { $0.value.lines == l }!.key }

    public static func number(_ lines: [Int]) -> Int {
        let lower = trigramNumber(lines: Array(lines[0..<3]))
        let upper = trigramNumber(lines: Array(lines[3..<6]))
        for i in 0..<64 where trigramNumber(named: ManticData.hexUpper[i]) == upper
            && trigramNumber(named: ManticData.hexLower[i]) == lower {
            return i + 1
        }
        fatalError("unknown hexagram")
    }

    public static func lines(_ num: Int) -> [Int] {
        trigrams[trigramNumber(named: ManticData.hexLower[num - 1])]!.lines
            + trigrams[trigramNumber(named: ManticData.hexUpper[num - 1])]!.lines
    }

    public static func name(_ num: Int) -> String { ManticData.hexNames[num - 1] }

    /// 例：11 → 地天泰，1 → 乾為天
    public static func fullName(_ num: Int) -> String {
        let u = ManticData.hexUpper[num - 1], l = ManticData.hexLower[num - 1]
        let ui = trigrams[trigramNumber(named: u)]!.image, li = trigrams[trigramNumber(named: l)]!.image
        return u == l ? "\(name(num))為\(ui)" : "\(ui)\(li)\(name(num))"
    }

    public struct Reading: Equatable {
        public let lines: [Int]
        public let moving: [Int]
        public let primary: Int
        public let changed: Int?
        public let mutual: Int

        public init(lines: [Int], moving: [Int]) {
            self.lines = lines
            let mv = Array(Set(moving)).sorted()
            self.moving = mv
            primary = IChing.number(lines)
            let ch = lines.enumerated().map { mv.contains($0.offset) ? 1 - $0.element : $0.element }
            changed = mv.isEmpty ? nil : IChing.number(ch)
            mutual = IChing.number(Array(lines[1..<4]) + Array(lines[2..<5]))
        }

        public var frame: String {
            var s = "卦|\(primary)\(IChing.name(primary))"
            if let c = changed { s += "|變\(c)\(IChing.name(c))" }
            s += "|動" + (moving.isEmpty ? "無" : moving.map { String($0 + 1) }.joined(separator: ","))
            return s
        }
    }

    /// 三錢法
    public static func threeCoins<R: RandomNumberGenerator>(using rng: inout R) -> Reading {
        var ls: [Int] = [], mv: [Int] = []
        for i in 0..<6 {
            let v = (0..<3).reduce(0) { acc, _ in acc + (Bool.random(using: &rng) ? 3 : 2) }
            ls.append(v == 7 || v == 9 ? 1 : 0)
            if v == 6 || v == 9 { mv.append(i) }
        }
        return Reading(lines: ls, moving: mv)
    }

    /// 梅花易數・數字起卦
    public static func plum(_ a: Int, _ b: Int) -> Reading {
        let up = a % 8 == 0 ? 8 : a % 8
        let lo = b % 8 == 0 ? 8 : b % 8
        let mv = (a + b) % 6 == 0 ? 6 : (a + b) % 6
        return Reading(lines: trigrams[lo]!.lines + trigrams[up]!.lines, moving: [mv - 1])
    }
}
