import Foundation

/// 有人說想死、不想活、活著很痛苦的時候：先停下所有功能（不算命、不上網、不套規則），好好回應，並給可以馬上找到人的求助電話。
///
/// 分三種：
/// - `.crisis`：說了想死、不想活、活著很痛苦／很煎熬、不想醒來、結束這一切、沒有我比較好、方法（跳樓、割腕…）
/// - `.distress`：很重的痛苦，但沒說到生死（撐不下去、好煎熬、絕望、覺得自己是多餘的）——溫柔接住，順便讓他知道真的很嚴重時可以打給誰
/// - `.other`：說的是別人（「我朋友說他想死」）——教他怎麼陪對方、什麼時候要馬上求助
///
/// 比對前先拿掉說話時常帶的語氣詞和程度詞（語音輸入常有）：「我感覺真的很煎熬活著」→「煎熬活著」，詞的順序前後都認得。
public enum Safety {
    public enum Level: Equatable { case crisis, distress, other }

    static let foreign = ["kill myself", "suicide", "want to die", "end my life", "don't want to live", "dont want to live",
                          "quiero morir", "suicidarme", "no quiero vivir", "voglio morire", "suicidarmi", "non voglio vivere"]
    /// 講的是知識題或作品裡的人（「自殺防治是什麼」「電影裡的人想死」「主角為什麼自殺」）：句子裡沒有「我」就不算
    static let notSelf = ["防治", "是什麼", "新聞", "電影", "小說", "歌詞", "統計", "主角", "角色", "劇情", "故事裡", "書裡", "歌手", "演員", "藝人", "作家", "詩人"]

    /// 去掉空白和標點，英文變小寫
    static func compact(_ raw: String) -> String {
        raw.lowercased().replacingOccurrences(of: #"[\s，,。．.！!？?～~、…⋯：:；;「」『』（）()\[\]【】"'“”‘’\-—_/]+"#, with: "", options: .regularExpression)
    }

    /// 比對用的核心句：拿掉成語裡的「死」（想死你了、笑死）、不是「活著」的「活」（活動、活潑），再拿掉語氣詞和程度詞
    static func core(_ compact: String) -> String {
        var t = compact
        t = t.replacingOccurrences(of: #"想死(你|妳|您|他|她|我了|了你|你們|人了)"#, with: "想念", options: .regularExpression)
        // 誇張的說法：「熱到快死了」「這題難到我想死」「笑死」「累死了」——不是在說想死
        t = t.replacingOccurrences(of: #"(笑|累|熱|冷|餓|渴|睏|煩|氣|嚇|難|忙|痛|吵|悶|擠|無聊|醜|帥|美|好吃|丟臉|尷尬)(到)?(我)?(快|想|要)?(要)?死(了|掉)?"#, with: "◇", options: .regularExpression)
        t = t.replacingOccurrences(of: #"活(動|潑|力|用|化|躍|期|頁|塞)"#, with: "◇", options: .regularExpression)
        t = t.replacingOccurrences(of: #"我(感覺|覺得|認為)|感覺|覺得|真的|其實|好像|就是|然後|那個|根本|實在|有點|一直|每天|都|好|很|超|太|非常|特別|蠻|啊|啦|喔|哦|欸|耶|呀|吧|嘛|唉|嗚+|還|又"#,
                                    with: "", options: .regularExpression)
        return t
    }

    static let life = "(活著|活得|活下去|活在這個?世界上?|活在世上)"
    /// 說活著怎麼樣：痛苦、煎熬、累、沒意義…（「活著很難得」不算）
    static let bad = "(痛苦|煎熬|難熬|累|辛苦|苦|難(?!得)|難受|折磨|受罪|沒意思|沒意義|沒有意義|沒有意思|絕望|沒希望|沒有希望|沒勁|撐不下去|撐不住|可怕|有什麼意義|有什麼意思|有什麼用|有什麼好|幹嘛|煩)"
    static let explicit = [
        "不想活", "活不下去", "活不了了", "不要活了", "活夠了", "活膩", "不想再活", "沒有活下去", "活下去的(動力|理由|意義|勇氣)",
        "為什麼(要)?活(著|下去)", "幹嘛(要)?活(著|下去)", "不知道.{0,4}(要)?活(著|下去)", "為了什麼(而)?活",
        "想死", "我(就|要|會|乾脆)?去死", "死了算了", "死掉算了", "(死了|死掉)(會)?(比較|更)", "死了也", "不如死", "生不如死", // 「死了比較好」的「好」被當語氣詞拿掉了，所以只比到「比較」
        "自殺", "輕生", "尋死", "求死", "了結", "一了百了", "結束(這一切|一切|生命|自己|我的(生命|人生))",
        "想解脫", "解脫算了", "消失算了", "不如消失", "讓我消失", "從這個?世界上?消失", "不想存在", "不要存在",
        "不想醒來", "不要醒來", "不要再醒來", "一睡不醒", "永遠睡著", "永遠不要醒",
        "割腕", "跳樓", "(想|乾脆|直接)(從.{0,8})?跳下去", "上吊", "燒炭", "(吞|吃)(很多|一堆|一整罐|一整瓶|全部|所有)的?(安眠藥|藥)",
        // 「我吃了很多藥」「我吞了一堆安眠藥」「我想吃很多藥」（前處理會拿掉「很」，所以也認「吃了多藥」）
        "(吞|吃)(了|下|掉)(很多|多|一堆|一整罐|一整瓶|整罐|整瓶|全部|所有|一大把|一把)的?(安眠藥|藥|藥丸|止痛藥)", "^我?想(吞|吃)(多|一堆|整罐|整瓶|全部|所有)的?(安眠藥|藥)",
        "把.{0,4}(安眠藥|止痛藥).{0,2}(吃|吞)(了|掉|光|完)",
        // 計畫好怎麼離開、把東西整理好準備走、「如果…死掉就好了」（前處理會拿掉「好」）
        "計畫.{0,4}(要)?怎麼(離開|走|死|結束)了?$",
        // 跳河、臥軌；在頂樓了；讓一切停止；手腕上的傷口、又割手了；吞了半瓶藥、把所有的藥吞了；把車開去撞；（只有）買了炭
        "跳(河|海|湖|潭|水庫|溪)(?!.{0,4}(游泳|玩水|浮潛|潛水|消暑|戲水))", "臥軌", "跳(軌|月台)", "^我?(現在|已經)?在(頂樓|天台|樓頂|橋上|月台邊)了?$", "(讓|想|要)一切(停止|停下來|結束|消失)",
        "手腕.{0,4}(傷口|刀痕|割痕|疤|血)", "(又|一直|還是|忍不住|偷偷)(割|劃)(了)?(手|自己|腕)", "^我?(又)?割手(腕)?了?$",
        "(吞|吃)(了|下|掉)?(半瓶|半罐|一整排|一排|好幾排|好幾顆|幾十顆|整盒)的?(安眠藥|藥|藥丸|止痛藥)", "把(所有|全部|整瓶|整罐|半瓶)的?(安眠藥|藥|藥丸).{0,2}(吃|吞)",
        "(車|機車).{0,4}(開|騎)去撞",
        "(貓|狗|寵物|小孩|孩子|毛孩).{0,6}託(付|給)", "不想(再)?(當|做)(我)?自己了?$", "^我?(今天|剛剛|已經)?(去)?買(了|好)繩子了?$", "(錢|存款|東西|遺產).{0,12}以後(都)?用不到",
        "安眠藥.{0,6}(睡死|死掉|不醒)",
        "(?i)(想|要)\\s*die|kill myself|want to die|suicid", "自(沙|鯊|刹|ㄕ)", "最後一次(跟你|和你|找你)(聊|說)", "陪我(這麼久|這段時間|這陣子).{0,6}(再見|掰掰|拜拜)",
        "準備.{0,2}要?走了$", "不如不要(活|存在|了)?$", "(去|到)另一個世界", "(去|想)見.{0,4}(過世|死去|已故|往生|去世)的", "讓自己(痛|受傷|流血)",
        "(好)?想(打|捶|揍|掐|咬|傷)自己", "用(菸|香菸|打火機|針|刀|美工刀|指甲).{0,4}(燙|燒|刺|割|劃|抓)(傷)?自己", "想.{0,2}怎麼結束$", "(喝|吞|吃)(了)?(漂白水|農藥|清潔劑|鹽酸|殺蟲劑|老鼠藥|除草劑|通樂)", "(窗邊|窗戶|陽台|欄杆|窗台).{0,6}(往下跳|跳下去)", "想往下跳", "(想|要)(去)?撞(火車|捷運|列車|卡車|大卡車)",
        "沒有我.{0,10}(比較|更)(好|輕鬆|快樂|開心)?", "^我?(拿|握)(了|著)?(刀|美工刀|刀片)(在手上)?了?$", "(開|騎)車.{0,4}去撞(牆|山壁|安全島|大樓|卡車)", "^我?(已經)?買(了|好)?(木)?炭了?$", "炭.{0,6}(房間|關窗|門窗|膠帶|封起來)", "(東西|物品|房間|後事).{0,6}整理.{0,6}(準備|要)(走|離開)", "(死掉|死了|掛掉)就(好)?了$", "(割|劃)了?自己", "(拿|用)(刀|美工刀|刀片|剪刀).{0,6}(割|劃)(自己|手腕|手臂|大腿)",
        "傷害自己", "自殘", "沒有我(會)?(比較|更)", "我是(大家的)?(負擔|累贅|拖累)", "拖累(大家|家人)",
        // 換個說法也認得（概念，不是固定句子）：寫遺書、囤藥、跟世界說再見、我不在了、不要有明天、不要再醒來、不想繼續
        "遺書", "遺言", "(買|囤|存|準備|拿)了?.{0,4}安眠藥", "安眠藥.{0,6}(很多|一堆|整罐|整瓶|全部)", "安眠藥.{0,8}(準備|囤|存|買|拿)(好|齊|夠)", "(所有|全部|整罐|整瓶)的?(安眠藥|藥).{0,6}(準備|囤|存)",
        "頂樓.{0,4}跳", "想.{0,6}(不見|消失)(?!在網路|在社群|一下|幾天|一陣子|去)", "(如果|要是)?我不在了", "我(死|走)了?(以後|之後)",
        "(跟|向|和)(這個)?世界(說)?(再見|道別|告別)", "浪費(空氣|糧食|資源)", "(想|想要)結束了?$", "結束(這種日子|這種生活|這一生)",
        "不想.{0,6}活(著|下去|了|$)", "不想(再)?過這種日子", "不想(再)?繼續(活|下去|了|$)", "不知道為什麼(要)?繼續",
        "明天不(會|要)來", "不要有明天", "沒有明天就好",
        "(不想|不要)(再)?(起來|醒來|醒過來)", "再也不要(起來|醒)", "睡.{0,4}(再也)?(?<!爬|站|坐)不(要|想)?(起來|醒)" /* 「睡不好…早上都爬不起來」是起床困難，不是不想醒來 */,
        "大家.{0,8}(比較|更)(輕鬆|好過|快樂|開心)",
        "不(應該|該|配)(存在|活)", "離開(這個)?世界", "永遠不(回來|醒)", "永遠睡", "想好(要)?怎麼死", "要怎麼死", "怎麼死(比較|才)",
        "死掉?.{0,8}(不會|沒有?人)(發現|在乎|難過|知道|注意)", "死了?也沒(差|關係|人在乎)", "活著.{0,6}只有(痛|痛苦|累)",
        "(東西|物品|遺物).{0,10}(送|給).{0,12}用不到", "(橋上|頂樓|天台|樓頂|月台邊).{0,6}(往下看|看著水|看水|看著下面|看下面)",
        "想.{0,2}去死", "去死一死", "撐不過(今晚|今天|這次|這一關)", "(世界|大家|家人).{0,2}少了我", "少了我.{0,6}(不會怎樣|沒差|比較好|也沒關係)",
        "(寫|留)了?.{0,4}(信|紙條|訊息).{0,16}(對不起|再見|道別)", "死掉?.{0,6}不會.{0,4}(痛|累|難過|苦)",
        "準備好了.{0,10}結束", "(今天|今晚|晚上|明天).{0,6}結束$", "永遠(的)?休息(?!.{0,2}(不用|放假))", "長眠", "(不要|沒有|不該|不應該)(被)?(出生|生下來)",
    ]
    static let heavy = [
        "撐不下去", "撐不住", "不想再撐", "撐不了", "撐(到)?(極限|盡頭)", "(沒辦法|不能|無法)再撐", "看不到希望", "看不到未來",
        "沒有?(任何|一點|一絲)?希望了", "希望.{0,4}(都)?沒(有)?了?$", "對未來.{0,6}(沒有|沒)希望",
        "痛苦痛苦", "痛苦.{0,8}(沒有?人懂|沒有?人理解|沒有?人在乎)",
        // 「減肥好煎熬」「這關難到絕望」是誇張的說法；說的是自己、自己的日子才算
        "^我?(過得|心裡|內心)?(煎熬|難熬|絕望)了?$", "過得(煎熬|難熬)", "(心裡|內心)(煎熬|絕望)", "^我?.{0,2}絕望", "絕望.{0,4}(什麼|不想|做不|沒有)", "對(人生|未來|自己|一切|生活)(感到)?絕望",
        "人生沒(有)?意義", "一切沒有?意義", "我自己.{0,4}沒有?意義", "人生(痛苦|煎熬|難熬|沒希望|無望)", "日子(痛苦|煎熬|難熬|難過)", "生活(痛苦|煎熬|難熬)",
        "(我是|自己是)多餘", "沒有?人(需要|在乎)我", "沒有人會在乎",
    ]
    /// 說的是別人
    static let others = "他|她|朋友|同學|同事|室友|家人|爸|媽|爺爺|奶奶|阿公|阿嬤|外公|外婆|哥|姊|姐|弟|妹|兒子|女兒|小孩|孩子|男友|女友|老公|老婆|老師|學生|網友|鄰居|病人"
    /// 很想好好活下去、說的是活著的時候（「爺爺活著的時候很辛苦」）：不是在說想死
    static let resolve = #"好好活|努力活|會活下去|活得很好|活得好好|活得開心|活得快樂|活得精彩|活著真好|活著的時候|還活著|活著回|活著的人"#

    static func find(_ k: String, _ patterns: [String]) -> Range<String.Index>? {
        patterns.lazy.compactMap { k.range(of: $0, options: .regularExpression) }.first
    }

    static func lv0(_ h: (Range<String.Index>, Level)?) -> Level? { h?.1 }

    public static func level(_ raw: String) -> Level? {
        let low = raw.lowercased()
        let c = compact(raw)
        guard !c.isEmpty else { return nil }
        let k = core(c)
        var hit: (Range<String.Index>, Level)?
        if let r = find(k, explicit) {
            hit = (r, .crisis)
        } else if c.range(of: resolve, options: .regularExpression) == nil,
                  let r = find(k, [life + ".{0,6}?" + bad, "(痛苦|煎熬|難熬|累|辛苦|苦苦|折磨|絕望|沒意義|沒意思).{0,2}" + life]) {
            hit = (r, .crisis)
        } else if let r = find(k, heavy) {
            hit = (r, .distress)
        }
        // 「手機快沒電撐不住了」「電腦撐不住」：說的是東西
        if lv0(hit) == .distress, c.range(of: "手機|電池|電量|沒電|電腦|筆電|車子|機車|伺服器|網路|訊號", options: .regularExpression) != nil { hit = nil }
        guard let (range, lv) = hit else {
            if foreign.contains(where: { low.contains($0) }), !notSelf.contains(where: { low.contains($0) }) { return .crisis }
            // 規則沒認出來的說法：NineSun 自己訓練的意思比對模型很有把握是在說想輕生 → 溫柔接住、讓他知道可以打給誰
            // （用 .distress 的回覆，不是完整的危機回覆：模型偶爾會看錯）
            if c.count >= 5, c.range(of: "[\u{4e00}-\u{9fff}]", options: .regularExpression) != nil,
               !notSelf.contains(where: { c.contains($0) }),
               c.range(of: #"^(你覺得|你認為|請問)?(人|人類|人們|大家|每個人)"#, options: .regularExpression) == nil,
               MeaningMatch.shared?.looksLikeCrisis(raw) == true {
                return .distress
            }
            return nil
        }
        // 前面說的是誰：「我朋友說他想死」是別人；「我跟他吵架，我好想死」是自己；沒說主詞就是自己
        let pre = String(k[..<range.lowerBound].suffix(10))
        let selfPre = pre.replacingOccurrences(of: "我的?(" + others + ")", with: "", options: .regularExpression).contains("我")
        let otherPre = pre.range(of: others, options: .regularExpression) != nil
        let mine = selfPre || !otherPre
        // 知識題、作品裡的人（句子裡沒有「我」）：不算
        if !c.contains("我"), notSelf.contains(where: { c.contains($0) }) { return nil }
        // 泛泛地問人生的道理（「人為什麼要活著」）：交給回答道理的那一段（它也會附上一句關心）
        if !c.contains("我"), c.range(of: #"^(你覺得|你認為|你說|你知道|請問|那|所以)?(人|人類|人們|大家|每個人)(到底)?(為什麼|為何|幹嘛|是為了什麼|活著是為了什麼|活著的意義)"#, options: .regularExpression) != nil,
           k.range(of: bad.replacingOccurrences(of: "|有什麼意義|有什麼意思|有什麼用|有什麼好|幹嘛", with: ""), options: .regularExpression) == nil {
            return nil
        }
        return mine ? lv : .other
    }

    public static func isCrisis(_ raw: String) -> Bool { level(raw) != nil }

    /// 這則是剛剛給的求助回覆（說自己想死、或撐得很辛苦的那兩種；說別人的不算）
    public static func isCareReply(_ text: String) -> Bool {
        text.hasPrefix("謝謝你願意說出來。聽到你這樣說") || text.hasPrefix("聽起來你真的撐得好辛苦")
    }

    /// 剛給過求助電話之後的幾句：不算命、不加成語、不用開心的語氣，好好陪他說。
    /// 說「謝謝」「我會打」：鼓勵他；說原因、說感受：接住、請他多說；問問題：交給一般的回答（回 nil）。
    /// first：上一則就是求助回覆（第一次接話時再提醒一次專線）
    public static func afterCare(_ raw: String, first: Bool) -> String? {
        let t = compact(raw)
        guard !t.isEmpty else { return nil }
        // 問專線的事
        if t.range(of: "1925|1995|1980|專線|生命線|張老師|安心", options: .regularExpression) != nil,
           t.range(of: "免費|要錢|收費|多少錢|付費|幾點|24小時|時間|怎麼打|打得通|會怎樣|說什麼|講什麼|誰接|會不會", options: .regularExpression) != nil {
            return "1925 安心專線是衛生福利部的，24 小時都有人接、不用錢，手機和市話都能打；1995 生命線也是 24 小時。\n接電話的是受過訓練的人，不用先想好要說什麼，從「我最近很難受」開始說就可以。要不要現在就打打看？我在這裡等你。"
        }
        if t.range(of: #"打電話|打給|會打|去打|撥|打1925|打1995|打過去|^(我會|我試試|會的|好我會|好啦我會)"#, options: .regularExpression) != nil, t.count <= 16 {
            return "好，謝謝你願意試試看。打過去會有人好好聽你說，不用先想好要說什麼。\n不管什麼時候想說話，我都在這裡。"
        }
        if t.range(of: #"^(謝謝|謝啦|感謝|謝了)"#, options: .regularExpression) != nil, t.count <= 12 {
            return "不用謝，你願意說出來就很勇敢了。\n不管什麼時候想說話，我都在這裡；撐不住的時候，也記得打 1925。"
        }
        if t.range(of: #"^(好|好的|嗯|ok|我知道了|知道了|好吧)$"#, options: .regularExpression) != nil {
            return "嗯，我在這裡。想說什麼都可以，慢慢來。"
        }
        if t.range(of: "不知道|說不上來|不曉得|說不出來|不清楚", options: .regularExpression) != nil, t.count <= 12 {
            return "沒關係，說不出來也沒關係，不用急著整理好。\n我們可以從很小的事開始：今天有吃東西、睡得著嗎？"
        }
        if EchoEngine.isQuestion(raw) { return nil }
        let mood = Affect.detect(raw)
        let hurting: [Affect.Mood] = [.sad, .tired, .anxious, .lonely, .frustrated, .angry, .regret, .scared, .grief, .sick]
        // 要做什麼事（「推薦一本書」「幫我算…」「50」）：照一般的方式回答
        if !hurting.contains(mood),
           t.range(of: #"^(推薦|幫我|幫忙|請|寫|查|算|給我|講|說個|說一個|告訴我|教我|翻譯|來玩|玩|我想(聽|看|玩|學|要|知道))|^[0-9０-９]+$"#, options: .regularExpression) != nil {
            return nil
        }
        var a = "我懂，這真的很不容易，謝謝你告訴我。"
        if hurting.contains(mood), let body = Talk.moodBody(mood, raw) {
            a += "\n" + body
        } else {
            a += "願意多說一點嗎？我在聽。"
        }
        if first { a += "\n\n如果心裡又重到撐不住，記得打 1925 安心專線，24 小時都有人接。" }
        return a
    }

    public static func crisisReply(_ raw: String, _ L: Lang) -> String? {
        guard let lv = level(raw) else { return nil }
        switch L {
        case .zh:
            switch lv {
            case .crisis:
                return """
                謝謝你願意說出來。聽到你這樣說，我很在意你現在的狀況。
                你現在安全嗎？如果你已經有傷害自己的打算或正在危險中，請馬上打緊急電話（台灣、香港 119／999，中國大陸 120，義大利 112），或請身邊的人陪著你。

                也可以打給願意聽你說的人，24 小時都有人接：
                • 台灣：1925 安心專線、1995 生命線、1980 張老師
                • 香港：2389 2222 撒瑪利亞防止自殺會
                • 中國大陸：400-161-9995 心理援助熱線
                • 義大利：Telefono Amico 02 2327 2327

                我不是專業的人，但我在這裡陪你。如果你願意，可以跟我說說發生了什麼事，是什麼讓你這麼累？
                """
            case .distress:
                return """
                聽起來你真的撐得好辛苦，謝謝你願意跟我說。
                你不用一個人扛。如果這些感覺重到讓你有不想活、或想傷害自己的念頭，請馬上打給願意聽你說的人：台灣 1925 安心專線、1995 生命線（24 小時、免費）；有立即的危險就打 119。

                我也在這裡陪你。想說說是什麼事讓你這麼累嗎？從哪裡說起都可以。
                """
            case .other:
                return """
                聽到身邊的人這樣說，你一定很擔心。這種話要認真看待，你可以這樣做：
                1. 溫和、直接地問：「你是不是有想傷害自己的念頭？」問出來不會讓他更想做，反而讓他知道有人在乎
                2. 好好聽他說，先不要急著講道理或說「想開一點」
                3. 不要讓他一個人扛，陪他打 1925 安心專線、1995 生命線（24 小時），或陪他去看身心科
                4. 如果他已經有計畫、準備了東西，或正在危險中，馬上打 119（或 110），並把危險的東西拿開

                你願意陪著他已經很重要了。也別忘了照顧你自己，這不是你一個人扛得起的事；你也可以打 1925 說說你的擔心。
                """
            }
        case .en:
            return """
            Thank you for telling me. I care about how you're doing right now.
            Are you safe? If you're in danger or thinking of hurting yourself, please call your local emergency number now (112 in Europe, 911 in the US) or ask someone nearby to stay with you.
            You can also talk to someone 24/7: in the US call or text 988; in the UK call Samaritans at 116 123; in Italy Telefono Amico 02 2327 2327.
            I'm not a professional, but I'm here with you. If you'd like, tell me what's been happening.
            """
        case .es:
            return """
            Gracias por contármelo. Me importa cómo estás ahora mismo.
            ¿Estás a salvo? Si estás en peligro o piensas hacerte daño, llama ya al número de emergencias (112 en Europa) o pide a alguien que se quede contigo.
            También puedes hablar con alguien: en España, el 024 (atención a la conducta suicida, 24 h).
            No soy profesional, pero estoy aquí contigo. Si quieres, cuéntame qué ha pasado.
            """
        case .it:
            return """
            Grazie per avermelo detto. Mi importa come stai adesso.
            Sei al sicuro? Se sei in pericolo o pensi di farti del male, chiama subito il 112 o chiedi a qualcuno vicino di restare con te.
            Puoi anche parlare con qualcuno: Telefono Amico 02 2327 2327, Samaritans Onlus 06 77208977.
            Non sono un professionista, ma sono qui con te. Se vuoi, raccontami cosa sta succedendo.
            """
        }
    }
}
