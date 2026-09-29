import Foundation

/// 綜合分析：把九型十二宮的每一層（本命 → 九型 → 大運 → 流年 → 流月 → 流日）串成一份有重點的解讀。
/// 推理方式：先找「被好幾層同時觸動的宮位」，那就是現在人生的重點；再依判讀好壞給建議。
public enum FullReading {
    static let triggers = ["完整解讀", "全面分析", "詳細分析", "整體運勢", "全部算", "總結我", "幫我分析", "綜合分析", "深入分析",
                           "完整分析", "全盤", "整體分析", "我的全部", "詳細解讀", "仔細看看我", "全面看看"]

    public static func matches(_ text: String) -> Bool { triggers.contains { text.contains($0) } }

    public static func build(_ D: Destiny, now: Date, R: Reader, profile: UserProfile? = nil) -> ReaderOutput {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: now)
        let y = c.year!, m = c.month!, d = c.day!
        let natal = D.natal[0], ty = D.type
        let lp = D.luckPeriod(y), yr = D.year(y), mo = D.month(m, year: y)
        let (dp, np) = D.day(month: m, day: d)
        let aspects = D.luckAspects(y)
        let trigYear = Set(D.triggeredAspects(y).map(\.palace))
        let trigNatal = D.triggeredNatal(y).map(\.palace)

        // 每一宮被幾層觸動（命宮、大運、流年、流月、日宮、夜宮、引動）
        var weight = [Int: Int]()
        for p in [natal.palace, lp.row.palace, yr.palace, mo.palace, dp, np] { weight[p, default: 0] += 1 }
        for p in trigYear { weight[p, default: 0] += 1 }
        for p in trigNatal { weight[p, default: 0] += 1 }
        let focus = weight.filter { $0.value >= 2 }.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(3)

        var t = "【綜合分析 · \(y)年\(m)月\(d)日】\n"
        t += "\n① 你是誰（本命）\n"
        t += "命宮在\(NT.label(natal.palace))（\(R.topicShort(natal.palace))），本命判讀「\(natal.reading.text)」。\(PalaceLore.text(natal.palace, natal.reading.verdict, .zh))\n"
        t += "九型是第\(ty)型「\(NT.typeName(ty))」：\(NT.typeTagline(ty))。\n"

        t += "\n② 人生現在的階段（大運 \(lp.start)–\(lp.end)）\n"
        t += "大運走\(NT.label(lp.row.palace))，判讀「\(lp.row.reading.text)」。\(PalaceLore.text(lp.row.palace, lp.row.reading.verdict, .zh))\n"
        if !trigNatal.isEmpty { t += "這十年會牽動你本命的" + trigNatal.prefix(3).map { NT.label($0) }.joined(separator: "、") + "。\n" }
        let good = aspects.filter { $0.reading.verdict == .good }.map { R.topicShort($0.palace) }
        let bad = aspects.filter { $0.reading.verdict == .bad }.map { R.topicShort($0.palace) }
        t += "這十年比較順的方面：\(good.isEmpty ? "沒有特別順的" : good.joined(separator: "、"))；要多花心力的：\(bad.isEmpty ? "沒有" : bad.joined(separator: "、"))。\n"

        t += "\n③ 今年（流年 \(y)）\n"
        t += "流年在\(NT.label(yr.palace))，判讀「\(yr.reading.text)」。\(PalaceLore.text(yr.palace, yr.reading.verdict, .zh))\n"
        t += "果落在\(NT.label(yr.reading.result))、因來自\(NT.label(yr.reading.cause))：今年的結果會表現在「\(R.topicShort(yr.reading.result))」，推動它的是「\(R.topicShort(yr.reading.cause))」。\n"
        if !trigYear.isEmpty {
            t += "今年引動大運的" + trigYear.sorted().map { p in "\(p)宮\(R.topicShort(p))（\(aspects[p - 1].reading.text)）" }.joined(separator: "、") + "，這些方面今年特別有感。\n"
        }

        t += "\n④ 這個月（流月 \(m)月）\n"
        t += "流月在\(NT.label(mo.palace))，判讀「\(mo.reading.text)」。\(PalaceLore.text(mo.palace, mo.reading.verdict, .zh))\n"

        t += "\n⑤ 今天（流日）\n"
        t += "白天走\(NT.label(dp))：\(R.tip(dp))\n晚上走\(NT.label(np))：\(R.tip(np))\n"

        t += "\n⑥ 重點與建議\n"
        if focus.isEmpty {
            t += "現在各層沒有特別集中在同一宮，屬於比較分散、平均的時期，照自己的節奏把日常顧好就好。\n"
        } else {
            for (p, n) in focus {
                let v = aspects[p - 1].reading.verdict
                t += "• \(NT.label(p))（\(R.topicShort(p))）同時被\(n)層觸動，是你現在的重點。這十年這方面判讀「\(aspects[p - 1].reading.text)」："
                t += PalaceLore.text(p, v, .zh) + "\n"
            }
        }
        let score = [yr.reading.verdict, lp.row.reading.verdict, mo.reading.verdict].map { [1, 0, -1][$0.rawValue] }.reduce(0, +)
        t += score > 0 ? "整體是順風期：想做的事可以主動推進，但記得留意上面標出的重點。"
            : score < 0 ? "整體是蓄力期：外在阻力比較多，重要決定放慢、先穩住基本盤，把力氣花在上面的重點上。"
            : "整體是持平期：有順有卡，挑最重要的一兩件事專心做。"

        // 其他系統參考：八字流年、紫微流年四化（以九型十二宮為主，這裡只做對照）
        let bd = D.birth
        let b = BaZi(bd.year, bd.month, bd.day, hour: profile?.hour, minute: profile?.minute ?? 0, male: profile?.male ?? true)
        let bs = BaZiReading.yearScore(b, y)
        let fa = BaZiReading.favAndAvoid(b)
        t += "\n\n⑦ 其他系統對照\n"
        t += "八字：日主\(GZ.stems[b.dayMaster])\(BaZi.wuxing[BaZi.stemEl[b.dayMaster]])，\(b.strength().strong ? "身強" : "身弱")，喜\(fa.fav.map { BaZi.wuxing[$0] }.joined(separator: "、"))；\(y)年\(GZ.name(bs.gz))對你是\(BaZiReading.vword(bs.score))的。"
        if let h = profile?.hour {
            let zw = ZiWei(bd.year, bd.month, bd.day, hour: h, male: profile?.male ?? true)
            let hs = ZiWeiReading.yearSihua(zw, year: y)
            t += "\n紫微：命宮主星\(ZiWeiReading.mainStars(zw, zw.ming).stars.joined(separator: "、"))；今年化祿在\(hs.first?.palace.map { ZiWeiReading.pname($0) } ?? "—")，化忌在\(hs.last?.palace.map { ZiWeiReading.pname($0) } ?? "—")。"
        } else {
            t += "\n紫微：告訴我出生時間，就能一起對照紫微斗數。"
        }
        let agree = (BaZiReading.verdict(bs.score) == yr.reading.verdict)
        t += agree ? "\n八字和九型十二宮對今年的判斷一致，可信度更高。" : "\n八字和九型十二宮對今年的看法不完全一樣，以九型十二宮為主，八字當作補充。"
        t += "\n\n想細看哪一塊，可以追問「今年感情運如何」「我的八字今年運勢」「紫微今年運勢」「我什麼時候會升職」。"

        let card = FortuneCard(title: "綜合分析", headline: "命宮 \(NT.label(natal.palace)) · 第\(ty)型",
                               verdict: score > 0 ? .good : (score < 0 ? .bad : .neutral),
                               details: ["大運 \(lp.start)–\(lp.end) \(NT.label(lp.row.palace)) \(lp.row.reading.text)",
                                         "流年 \(y) \(NT.label(yr.palace)) \(yr.reading.text)",
                                         "流月 \(m)月 \(NT.label(mo.palace)) \(mo.reading.text)",
                                         "今日 日\(NT.label(dp)) / 夜\(NT.label(np))"]
                                        + focus.map { "重點 \(NT.label($0.key))（\($0.value)層）" })
        return ReaderOutput(text: R.polish(t), card: card,
                            follow: Followup(scope: "year", label: "\(y)年", row: yr, y: y, m: m, d: d, palace: nil, birthday: D.birth))
    }
}
