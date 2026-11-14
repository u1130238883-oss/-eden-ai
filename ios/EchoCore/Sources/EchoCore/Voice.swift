import Foundation

/// 個性：每一張九型十二宮的本命盤，就是一種說話的樣子。
/// 年、月、日各化成 1～9 的數字，9×9×9＝729 種；年和月互換是同一張盤，所以一共 405 種不同的人
/// （年月相同的 81 種＋年月不同的 324 對）。同一句話，不同的人會用不同的語氣、不同的成語回應：
///   九型 → 三種中心：情感（2、3、4 型，溫暖、感受先行）、思考（5、6、7 型，冷靜、講道理）、本能（8、9、1 型，直接、給力量）
///   本命第一宮的好／正／壞 → 能量：好＝順口自然、正＝能量強（語氣加重）、壞＝溫和保留（多一句放慢的話）
///   日的數字 → 帶出成語的口頭禪
///   年、月的數字 → 偏好哪一句成語
public struct Voice: Hashable {
    public enum Center: Int { case heart, head, gut }

    /// 405 種之一：年月小的在前（「3-7-2」跟「7-3-2」是同一張盤）
    public let key: String
    public let type: Int
    public let center: Center
    public let energy: NTVerdict
    let a: Int, b: Int, d: Int

    public init(_ birth: BirthDay) {
        let y = NT.lifeDigit(birth.year), m = NT.lifeDigit(birth.month), dd = NT.lifeDigit(birth.day)
        self.init(y: y, m: m, d: dd)
    }

    init(y: Int, m: Int, d: Int) {
        a = min(y, m); b = max(y, m); self.d = d
        key = "\(a)-\(b)-\(d)"
        let t = NTTriple(a, b, d)
        type = NT.r9(t.life)
        center = [2, 3, 4].contains(type) ? .heart : [5, 6, 7].contains(type) ? .head : .gut
        energy = NTChart.natalStyle(t)[0].reading.verdict
    }

    /// 全部 405 種
    public static let all: [Voice] = {
        var seen = Set<String>(), out: [Voice] = []
        for y in 1...9 { for m in 1...9 { for d in 1...9 {
            let v = Voice(y: y, m: m, d: d)
            if seen.insert(v.key).inserted { out.append(v) }
        } } }
        return out
    }()

    /// 帶出成語的口頭禪（由日的數字）
    static let intros = ["送你一句成語：", "用一句成語來說：", "就像成語說的：", "我想到一句成語：", "借一句成語：", "老祖宗說得好：",
                         "這讓我想到：", "有句成語很貼切：", "古人說："]
    public var intro: String { Self.intros[(d - 1) % Self.intros.count] }

    /// 每種心情：情感／思考／本能三種中心各一種開口的方式
    static let openers: [Affect.Mood: [String]] = [
        .grief: ["聽到這個消息我好難過，抱抱你。", "失去重要的人（或毛孩）會痛，是因為愛很深；難過多久都沒關係，我陪你。", "這真的很難受，別一個人扛，我在這裡陪你。"],
        .sick: ["身體不舒服要好好休息喔，我有點擔心你。", "生病的時候身體在修復，要好好休息、多喝水，症狀加重就去看醫生。", "先別逞強，好好休息，身體最重要。"],
        .worryOther: ["你這麼在乎他，他一定感受得到，我陪你一起擔心。", "聽起來你很擔心他，我們先想想現在能為他做什麼。", "別慌，先把能做的事做好，我陪你一起想辦法幫他。"],
        .goodNews: ["恭喜你！真替你開心！🎉", "恭喜！這是你努力換來的成果，太棒了。", "恭喜！你做到了，就是這麼厲害！"],
        .proudEffort: ["好棒，你真的做到了！為你驕傲。", "太厲害了，這份堅持很不容易，給你拍拍手👏", "做到了就是做到了，好棒，繼續保持！"],
        .excitedPlan: ["聽起來好期待！我也替你雀躍起來了。", "好棒的安排，事先準備一下會更開心！", "期待吧！好好去玩，玩得開心！"],
        .anxious: ["會緊張是因為你很在乎，先深呼吸，我陪你。", "別擔心，一步一步來，你比自己想的更有準備。", "深呼吸，別擔心，你可以的，我挺你！"],
        .scared: ["別怕，我在這裡陪你。", "先深呼吸，你現在是安全的，我陪著你。", "別怕！有我在，陪你一起面對。"],
        .angry: ["換作是我也會生氣，你的感受很合理。", "這真的很讓人火大，先讓情緒有個出口，我站在你這邊。", "太過分了，換我也火大！我站在你這邊。"],
        .complainAI: ["對不起讓你失望了，我會改進，可以告訴我哪裡不對嗎？", "抱歉，是我弄錯了，謝謝你告訴我，我重新想一次。", "抱歉，我錯了，馬上改進。"],
        .apology: ["沒關係，我沒有放在心上，謝謝你願意說。", "沒事的，每個人都有情緒，我還是很樂意陪你。", "沒關係啦，翻篇了！"],
        .sad: ["先抱抱你，難過的時候不用急著好起來。", "我在，想說什麼都可以慢慢說，難過是很正常的。", "我在這裡陪你，想哭就哭吧。"],
        .lonely: ["你不是一個人，我在這裡陪你聊。", "孤單的時候特別難熬，今天我陪你。", "別怕孤單，我陪你！"],
        .tired: ["辛苦了，先讓自己喘口氣。", "真的累壞了吧，記得好好休息，身體最重要。", "辛苦了！今天就早點休息吧。"],
        .frustrated: ["別灰心，卡住是每個人都會遇到的，我替你加油！", "失敗不代表你不行，只是還在學的路上，我們換個方法試試。", "加油！再試一次，你一定行。"],
        .regret: ["會後悔，代表你很認真對待這件事；別對自己太嚴苛。", "已經發生的事我們一起接住它，接下來還有機會。", "別對自己太苛刻，後悔過了就往前走。"],
        .confused: ["不好意思，我說得不夠清楚，我換個方式講。", "沒關係，我們一步一步來，我再說明一次。", "我換個方式說清楚。"],
        .thanks: ["不客氣！能幫上忙我很開心😊", "很高興對你有幫助，隨時再找我！", "不客氣，有需要隨時說！"],
        .praiseAI: ["被你這樣說有點不好意思，謝謝你😳", "哈哈，被誇獎好開心，我會繼續努力的！", "謝謝！我會更努力的。"],
        .affection: ["聽到你這樣說，我心裡暖暖的，謝謝你。", "有你陪我聊天，我也很開心。", "謝謝你，我也很開心有你！"],
        .joke: ["哈哈，好呀，來輕鬆一下～", "你真有趣😆", "哈哈，來！"],
        .bored: ["無聊的話，我陪你找點樂子！", "那來點有趣的吧～", "來找點有趣的事做！"],
        .hope: ["我也這樣祝福你，一定會越來越好的。", "會的，我跟你一起期待。", "會的！一定會更好。"],
        .greeting: ["嗨！很高興見到你😊", "你好呀！今天想聊什麼？", "嗨！"],
        .farewell: ["晚安，好好休息，明天見～", "掰掰，有需要隨時找我！", "再見，好好休息！"],
        .curious: ["這個問題很有意思！", "我也好奇，我們一起來看看。", "有意思，來看看！"],
        .happy: ["看你這麼開心，我也跟著開心起來了！", "真好，開心的事值得好好記住。", "太好了，開心就對了！"],
    ]

    static let negative: Set<Affect.Mood> = [.grief, .sick, .worryOther, .anxious, .scared, .angry, .complainAI, .apology, .sad, .lonely, .tired,
                                              .frustrated, .regret, .confused]

    /// 這種心情、這個人開口的第一句
    public func opener(_ m: Affect.Mood) -> String? {
        guard let o = Self.openers[m], o.count == 3 else { return nil }
        var s = o[center.rawValue]
        switch energy {
        case .neutral:  // 正：能量強，語氣加重
            s = "真的，" + s
        case .bad:      // 壞：溫和保留，多一句放慢的話
            s += Self.negative.contains(m) ? "慢慢來就好。" : "也別忘了照顧自己。"
        case .good: break
        }
        return s
    }

    /// 每種心情適合的成語（語氣對、不衝突；難過時不說笑、不說教）
    static let moodIdioms: [Affect.Mood: [String]] = [
        .grief: ["念念不忘", "刻骨銘心", "患難與共"],
        .sick: ["平安無事", "安然無恙", "逢凶化吉", "吉人天相"],
        .worryOther: ["吉人天相", "逢凶化吉", "平安無事", "化險為夷", "安然無恙"],
        .goodNews: ["大功告成", "功成名就", "心想事成", "喜出望外", "錦上添花", "前程似錦", "鵬程萬里"],
        .proudEffort: ["有始有終", "再接再厲", "精益求精", "鍥而不捨", "滴水穿石", "熟能生巧", "大功告成"],
        .excitedPlan: ["一帆風順", "千載難逢", "萬事如意", "心想事成"],
        .anxious: ["船到橋頭自然直", "從容不迫", "平心靜氣", "循序漸進", "水到渠成"],
        .scared: ["平安無事", "泰然自若", "臨危不亂", "化險為夷"],
        .angry: ["心平氣和", "平心靜氣", "三思而後行", "雞毛蒜皮"],
        .complainAI: ["才疏學淺"],
        .apology: ["雞毛蒜皮", "心平氣和", "平心靜氣"],
        .sad: ["否極泰來", "雨過天晴", "柳暗花明", "苦盡甘來", "過眼雲煙"],
        .lonely: ["患難與共", "雨過天晴", "苦盡甘來"],
        .tired: ["精疲力盡", "筋疲力竭", "身心俱疲", "苦盡甘來"],
        .frustrated: ["失敗為成功之母", "鍥而不捨", "東山再起", "捲土重來", "熟能生巧", "滴水穿石", "大器晚成", "勤能補拙"],
        .regret: ["亡羊補牢", "塞翁失馬", "因禍得福", "過眼雲煙"],
        .thanks: ["舉手之勞", "一臂之力"],
        .praiseAI: ["受寵若驚", "才疏學淺", "虛懷若谷"],
        .affection: ["情同手足", "一見如故", "相見恨晚", "形影不離"],
        .joke: ["捧腹大笑", "忍俊不禁", "哭笑不得", "樂不可支"],
        .bored: ["百無聊賴", "捧腹大笑", "樂不可支"],
        .hope: ["萬事如意", "心想事成", "一帆風順", "前程似錦", "否極泰來"],
        .farewell: ["萬事如意", "平安無事", "一帆風順", "心想事成"],
        .curious: ["不可思議", "匪夷所思", "嘆為觀止", "大吃一驚", "目瞪口呆"],
        .happy: ["心花怒放", "錦上添花", "眉開眼笑", "樂不可支", "笑逐顏開"],
    ]

    /// 看場合的成語：說到結婚、考試、生日、升職時，先用最貼切的
    static let occasions: [(String, [String])] = [
        ("結婚|婚禮|求婚|訂婚|嫁|娶", ["天作之合", "白頭偕老", "百年好合", "永結同心"]),
        ("考上|錄取|上榜|考過|金榜|考滿分|第一志願", ["金榜題名", "前程似錦"]),
        ("生日|大壽|壽宴", ["福如東海", "壽比南山"]),
        ("升職|升官|加薪|offer|找到工作|拿到工作", ["步步高昇", "前程似錦"]),
        ("畢業", ["前程似錦", "鵬程萬里"]),
        ("出國|旅行|旅遊|出發|玩", ["一帆風順"]),
    ]

    /// 這個人在這種心情會用哪一句成語（同一個人同一種心情固定；不同的人偏好不同）
    public func idiom(for m: Affect.Mood, message: String) -> Idioms.Entry? {
        if [.goodNews, .excitedPlan, .hope, .happy].contains(m) {
            for (p, ws) in Self.occasions where message.range(of: p, options: .regularExpression) != nil {
                return Idioms.entry(ws[(a + b) % ws.count])
            }
        }
        guard let ws = Self.moodIdioms[m], !ws.isEmpty else { return nil }
        // 年、月的數字決定偏好（45 種組合）；情感中心的人偏溫柔的、本能中心的人偏有力的——用中心錯開順序
        let i = (a * 9 + b + center.rawValue * 2) % ws.count
        return Idioms.entry(ws[i])
    }

    public func idiomLine(for m: Affect.Mood, message: String) -> String? {
        guard let e = idiom(for: m, message: message) else { return nil }
        return "💬 \(intro)「\(e.idiom)」——\(e.meaning)。"
    }
}
