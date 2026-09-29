import Foundation

/// 紫微斗數排盤（逐行對應 ai/ziwei.py）。
public struct ZiWei {
    public static let palaces = ["命宮", "兄弟", "夫妻", "子女", "財帛", "疾厄", "遷移", "交友", "官祿", "田宅", "福德", "父母"]
    public static let juNames = [2: "水二局", 3: "木三局", 4: "金四局", 5: "土五局", 6: "火六局"]
    static let nayinJu = [4, 6, 3, 5, 4, 6, 2, 5, 4, 3, 2, 5, 6, 3, 2, 4, 6, 3, 5, 4, 6, 2, 5, 4, 3, 2, 5, 6, 3, 2]
    static let sihua: [String: [String]] = [
        "甲": ["廉貞", "破軍", "武曲", "太陽"], "乙": ["天機", "天梁", "紫微", "太陰"],
        "丙": ["天同", "天機", "文昌", "廉貞"], "丁": ["太陰", "天同", "天機", "巨門"],
        "戊": ["貪狼", "太陰", "右弼", "天機"], "己": ["武曲", "貪狼", "天梁", "文曲"],
        "庚": ["太陽", "武曲", "太陰", "天同"], "辛": ["巨門", "太陽", "文曲", "文昌"],
        "壬": ["天梁", "紫微", "左輔", "武曲"], "癸": ["破軍", "巨門", "太陰", "貪狼"],
    ]
    static let sihuaNames = ["化祿", "化權", "化科", "化忌"]
    static let lucun = [2, 3, 5, 6, 5, 6, 8, 9, 11, 0]

    static func ziweiPosition(ju: Int, day: Int) -> Int {
        var x = 0
        while (day + x) % ju != 0 { x += 1 }
        let q = (day + x) / ju
        var pos = 2 + q - 1
        pos = x % 2 == 1 ? pos - x : pos + x
        return Astro.pmod(pos, 12)
    }

    public let lunar: LunarDate
    public let male: Bool
    public let hourBranch: Int
    public let yearStem: Int
    public let ming: Int
    public let shen: Int
    public let ju: Int
    /// 地支 → 宮名
    public let palaceAt: [Int: String]
    /// 地支 → 宮干
    public let stemAt: [Int: Int]
    public let main: [[String]]
    public let aux: [[String]]
    public let sihuaOf: [String: String]

    public init(_ y: Int, _ m: Int, _ d: Int, hour: Int, male: Bool = true) {
        var ld = LunarCalendar.shared.lunar(y, m, d)
        if hour >= 23 {
            let nd = Astro.date(fromJD: Double(Astro.dayNumber(y, m, d) + 1) - 0.5)
            ld = LunarCalendar.shared.lunar(nd.0, nd.1, nd.2)
        }
        lunar = ld
        var lm = ld.month
        if ld.isLeap && ld.day > 15 { lm = lm % 12 + 1 }
        self.male = male
        let h = ((hour + 1) / 2) % 12
        hourBranch = h
        let ygz = Astro.pmod(ld.year - 4, 60)
        yearStem = ygz % 10

        ming = Astro.pmod(2 + (lm - 1) - h, 12)
        shen = Astro.pmod(2 + (lm - 1) + h, 12)
        var pa: [Int: String] = [:]
        for (i, name) in ZiWei.palaces.enumerated() { pa[Astro.pmod(ming - i, 12)] = name }
        palaceAt = pa
        let yinStem = (yearStem % 5) * 2 + 2
        var sa: [Int: Int] = [:]
        for b in 0..<12 { sa[b] = (yinStem + Astro.pmod(b - 2, 12)) % 10 }
        stemAt = sa
        let mingGZ = GZ.index(stem: sa[ming]!, branch: ming)
        ju = ZiWei.nayinJu[mingGZ / 2]

        var stars = [[String]](repeating: [], count: 12)
        let z = ZiWei.ziweiPosition(ju: ju, day: ld.day)
        for (name, off) in [("紫微", 0), ("天機", -1), ("太陽", -3), ("武曲", -4), ("天同", -5), ("廉貞", -8)] {
            stars[Astro.pmod(z + off, 12)].append(name)
        }
        let f = Astro.pmod(4 - z, 12)
        for (name, off) in [("天府", 0), ("太陰", 1), ("貪狼", 2), ("巨門", 3), ("天相", 4), ("天梁", 5), ("七殺", 6), ("破軍", 10)] {
            stars[Astro.pmod(f + off, 12)].append(name)
        }
        main = stars
        var ax = [[String]](repeating: [], count: 12)
        ax[Astro.pmod(10 - h, 12)].append("文昌")
        ax[Astro.pmod(4 + h, 12)].append("文曲")
        ax[Astro.pmod(4 + lm - 1, 12)].append("左輔")
        ax[Astro.pmod(10 - (lm - 1), 12)].append("右弼")
        let lc = ZiWei.lucun[yearStem]
        ax[lc].append("祿存")
        ax[Astro.pmod(lc + 1, 12)].append("擎羊")
        ax[Astro.pmod(lc - 1, 12)].append("陀羅")
        ax[Astro.pmod(11 - h, 12)].append("地空")
        ax[Astro.pmod(11 + h, 12)].append("地劫")
        aux = ax
        var sh: [String: String] = [:]
        for (star, tag) in zip(ZiWei.sihua[GZ.stems[yearStem]]!, ZiWei.sihuaNames) { sh[star] = tag }
        sihuaOf = sh
    }

    public func palaceOf(_ name: String) -> Int { palaceAt.first { $0.value == name }!.key }

    public func starsText(_ b: Int, withAux: Bool = false) -> [String] {
        (main[b] + (withAux ? aux[b] : [])).map { $0 + (sihuaOf[$0] ?? "") }
    }

    /// 大限：(地支, 起歲, 迄歲)
    public func decades() -> [(branch: Int, from: Int, to: Int)] {
        let yang = yearStem % 2 == 0
        let step = yang == male ? 1 : -1
        var out: [(branch: Int, from: Int, to: Int)] = []
        for i in 0..<12 {
            let b: Int = Astro.pmod(ming + step * i, 12)
            let a0: Int = ju + 10 * i
            out.append((branch: b, from: a0, to: a0 + 9))
        }
        return out
    }

    public func decade(atAge age: Int) -> (branch: Int, from: Int, to: Int)? {
        decades().first { $0.from <= age && age <= $0.to }
    }
}
