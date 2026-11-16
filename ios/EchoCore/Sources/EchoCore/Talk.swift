import Foundation

/// NineSun 自己的話（ai/commonsense/data/talk.txt → CommonsenseData.talk）：
/// 關於自己（有沒有感情、喜歡什麼、幾歲）、自己的看法（AI 會不會取代人類、有沒有外星人、算命準不準）、
/// 笑話、人生的選擇題（該不該換工作、要不要告白、怎麼交到女朋友）。
///
/// 以前這些問題會被當成在說心情、被十二宮感知帶去講宮位（「你喜歡什麼」→「我感覺到戀愛的氣息」），
/// 或是回「這個我沒學過」。問法比對整句（拿掉標點、語氣詞），寫得很準，寧可漏接也不亂攔。
public enum Talk {
    struct Entry {
        let name: String
        let kind: String
        var asks: [NSRegularExpression]
        var answers: [String]
    }

    static let entries: [Entry] = {
        var out: [Entry] = []
        for line in CommonsenseData.talk.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("@") {
                let p = line.dropFirst().split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                out.append(Entry(name: p[0], kind: p.count > 2 ? p[2] : "", asks: [], answers: []))
            } else if line.hasPrefix("問="), !out.isEmpty, let re = try? NSRegularExpression(pattern: String(line.dropFirst(2)), options: [.caseInsensitive]) {
                out[out.count - 1].asks.append(re)
            } else if line.hasPrefix("答="), !out.isEmpty {
                out[out.count - 1].answers.append(String(line.dropFirst(2)).replacingOccurrences(of: "⏎", with: "\n"))
            }
        }
        return out
    }()

    /// 比對用的句子：標點、空白、結尾的語氣詞拿掉，「妳」當「你」
    static func clean(_ raw: String) -> String {
        var t = raw.replacingOccurrences(of: "妳", with: "你").replacingOccurrences(of: "您", with: "你")
        t = t.filter { !"，,。.！!？?～~、：:；;「」『』\"' ".contains($0) && !$0.isWhitespace }
        for p in ["請問一下", "請問", "那", "欸", "嗯", "所以", "NineSun", "ninesun"] where t.hasPrefix(p) && t.count > p.count + 1 { t.removeFirst(p.count) }
        while let l = t.last, "呢啊呀喔哦啦吧耶嘛勒咧捏".contains(l), t.count > 1 { t.removeLast() }
        return t
    }

    /// 這次是第幾次被問到（笑話每次換一個）
    static var asked: [String: Int] = [:]

    public static func answer(_ raw: String) -> String? { detailed(raw)?.text }

    /// 聊天：對方在說自己的事（不是問問題）——照說的內容接話、問下去，不拿宮位亂回（使用者 2026-10-28：「不要用宮位亂回」）
    /// 剛剛閒聊的主題（看、吃、旅行:日本、下班、養寵物…），對方接著回答時用
    static var lastChatTopic = ""

    public static func chat(_ raw: String) -> String? {
        lastChatTopic = ""
        let t = clean(raw)
        guard t.count >= 2, t.count <= 24, !t.contains("嗎"), !t.contains("什麼"), !t.contains("怎麼"), !t.contains("為什麼") else { return nil }
        func m(_ p: String) -> [String]? { RuleBook.match(t, p) }
        // 別人的好消息（「我朋友要結婚了」）：替對方開心，不是「這是你努力換來的」
        if let g = m(#"^我(?:的)?(朋友|好朋友|同事|同學|姐姐|姊姊|哥哥|弟弟|妹妹|媽媽|爸爸|表姐|表哥|堂姐|堂哥|閨蜜|室友)(?:要|快要|下個月要|明年要)?(結婚|生小孩|生寶寶|懷孕|訂婚|升職|考上)(?:了)?$"#) {
            let what = g[1] == "結婚" || g[1] == "訂婚" ? "你會去參加嗎？要準備紅包或禮物的話，我可以幫你想祝福的話。" : "記得跟他說聲恭喜！"
            return "替你\(g[0])開心！🎉 \(what)"
        }
        // 剛做完的事
        if let g = m(#"^我?(?:剛|剛剛|才剛)(下班|下課|放學|回家|到家|起床|睡醒|醒來|吃飽|洗完澡|運動完|考完試|開完會)(?:了)?$"#) {
            lastChatTopic = "下班"
            switch g[0] {
            case "下班", "下課", "放學", "開完會": return "辛苦了！今天過得怎麼樣？晚餐吃了嗎？"
            case "起床", "睡醒", "醒來": return "早安（不管現在幾點都算）！睡得好嗎？"
            case "回家", "到家": return "歡迎回家～今天還好嗎？先好好休息一下。"
            case "吃飽": return "吃飽了真好～吃了什麼好吃的？"
            case "運動完": return "好棒！運動完記得補充水分、做一下伸展。今天做了什麼運動？"
            case "考完試": return "辛苦了！考得怎麼樣？不管結果如何，先好好放鬆一下。"
            default: return "感覺很舒服吧～接下來有什麼打算？"
            }
        }
        // 「我是天蠍座」「我屬龍」：說自己的星座、生肖
        if let g = m(#"^我(?:是|的星座是)?(牡羊|白羊|金牛|雙子|巨蟹|獅子|處女|天秤|天蠍|射手|摩羯|水瓶|雙魚)座(?:的)?$"#) ?? m(#"^我(?:是)?屬([鼠牛虎兔龍蛇馬羊猴雞狗豬])(?:的)?$"#) {
            let name = g[0].count == 1 ? "屬" + g[0] : (g[0] == "白羊" ? "牡羊" : g[0]) + "座"
            if let e = Commonsense.facts.first(where: { $0.name == name }), let p = e.attr("個性") {
                return "\(name)！" + p.replacingOccurrences(of: "一般說", with: "一般說法是") + "。你覺得準嗎？"
            }
        }
        // 剛吃完、剛看完
        if let g = m(#"^我?(?:剛|剛剛|才剛|已經)?(吃完|看完|讀完|追完|玩完|聽完)(.{1,10})(?:了)?$"#) {
            var x = g[1]
            if let r = x.range(of: #"^(一|1)(本|部|首|集|場|個|款|齣|片)"#, options: .regularExpression) { x.replaceSubrange(r, with: "那" + x[r].dropFirst()) }
            switch g[0] {
            case "吃完": lastChatTopic = "吃"; return ["早餐", "午餐", "晚餐", "飯", "宵夜", "早午餐"].contains(x) ? "吃飽了真好～\(x)吃了什麼好吃的？" : "\(x)好吃嗎？"
            case "看完", "讀完", "追完": lastChatTopic = "看"; return "\(x)好看嗎？在講什麼？我想聽聽你的心得。"
            default: lastChatTopic = "玩"; return "\(x)好玩嗎？有什麼印象最深的地方？"
            }
        }
        // 正在做的事
        if let g = m(#"^我?(?:現在|正|還|今天|目前)?在(上班|工作|讀書|唸書|念書|寫作業|做作業|寫報告|煮飯|做飯|做菜|追劇|看劇|看電影|看書|打電動|玩遊戲|打遊戲|運動|健身|開會|洗衣服|打掃|吃飯|吃早餐|吃午餐|吃晚餐|散步|聽音樂|加班|休息|發呆|滑手機|開車|通勤|排隊|準備考試|找工作)$"#) {
            switch g[0] {
            case "上班", "工作", "加班", "開會": return "辛苦了！今天忙嗎？累了記得起來動一動、喝點水。"
            case "讀書", "唸書", "念書", "寫作業", "做作業", "寫報告", "準備考試": return "加油！在讀什麼呢？卡住的地方可以問我。"
            case "煮飯", "做飯", "做菜": lastChatTopic = "吃"; return "好厲害！今天煮什麼？需要食譜的話可以問我。"
            case "追劇", "看劇", "看電影", "看書": lastChatTopic = "看"; return "在看什麼？好看嗎？"
            case "打電動", "玩遊戲", "打遊戲": lastChatTopic = "玩"; return "在玩什麼遊戲？玩得開心～"
            case "運動", "健身", "散步": return "很棒耶！記得補充水分～"
            case "吃飯", "吃早餐", "吃午餐", "吃晚餐": lastChatTopic = "吃"; return "吃什麼好吃的？慢慢吃～"
            case "開車", "通勤": return "路上注意安全，到了再跟我聊～"
            case "找工作": return "找工作辛苦了！需要的話我可以幫你看履歷怎麼寫、面試要注意什麼。"
            default: return "好～有需要再叫我，我陪你。"
            }
        }
        // 最近在努力的事
        if let g = m(#"^我?(?:最近|現在|正|開始|目前)?在(減肥|瘦身|存錢|戒菸|戒糖|戒手機|早睡|運動|健身)$"#) {
            return "\(g[0])不容易，你很棒！需要方法的話，問我「怎麼\(g[0])」，我給你一些實用的做法。"
        }
        // 要考試、要上台
        if let g = m(#"^我?(?:明天|後天|下週|下禮拜|等一下|今天|這週|下午|早上)?(?:要|有|就要)(考試|期中考|期末考|考|報告|上台報告|比賽|演講|簡報)(?:了)?$"#) {
            return "加油！\(g[0] == "考" ? "考試" : g[0])前記得睡飽、吃早餐，相信自己準備的東西。需要的話我可以陪你整理重點。"
        }
        // 跟誰出去
        if let g = m(#"^我?(?:今天|等一下|明天|晚上|週末)?(?:要)?跟(男朋友|女朋友|男友|女友|老公|老婆|另一半|朋友|家人|同學|同事|爸媽|媽媽|爸爸)(?:出去)?(約會|吃飯|看電影|逛街|出去玩|出去|聚餐|唱歌)$"#) {
            return ["男朋友", "女朋友", "男友", "女友", "老公", "老婆", "另一半"].contains(g[0]) ? "好甜蜜！要去哪裡？玩得開心～" : "聽起來很開心！要去哪裡？玩得愉快～"
        }
        // 東西壞了、弄丟了
        if let g = m(#"^我?的?(手機|電腦|筆電|車|機車|冷氣|耳機|錢包|鑰匙|悠遊卡|信用卡|身分證|雨傘)(?:又)?(壞了|當機了|當機|故障了|故障|不見了|弄丟了|掉了|被偷了)$"#) ?? m(#"^我?(?:不小心)?把(手機|錢包|鑰匙|悠遊卡|信用卡|身分證|雨傘|耳機)(?:弄丟|搞丟|弄丟了|搞丟了|弄壞了|摔壞了|掉了)$"#) {
            switch g[0] {
            case "錢包", "信用卡", "身分證": return "先別慌，可以這樣做：\n1. 回想最後一次用到的地方，打電話問問店家或車站失物招領\n2. 信用卡、金融卡先打給銀行掛失停卡\n3. 身分證要到戶政事務所掛失補辦，掉了也可以先報警備案\n希望能找回來！"
            case "手機": return "好麻煩…如果是不見了，可以用「尋找」功能（iPhone 的尋找、Android 的尋找我的裝置）定位，必要時先遠端鎖定；如果是壞了，先試試充電、強制重開機，還是不行再送修。"
            case "鑰匙": return "先回想最後放在哪裡、看看外套口袋和包包。真的找不到的話找鎖匠，之後可以考慮放一把備用鑰匙在信任的人那裡。"
            default: return "好麻煩喔…先試試重開機或檢查電源；還是不行的話，看看保固還在不在，送修比較安心。"
            }
        }
        if m(#"^我?(?:今天|又|早上|剛剛)?遲到(?:了)?$"#) != nil {
            return "哎呀…還好嗎？下次可以提早 10 分鐘出門、前一晚先把東西準備好，會從容很多。"
        }
        // 自己的寵物、小孩好可愛
        if let g = m(#"^我?(?:家)?的?(貓|狗|貓咪|狗狗|寶寶|小孩|兔子|倉鼠|女兒|兒子|鳥)(?:好|很|超|真的|太)?(可愛|乖|聰明|調皮|皮)(?:了)?$"#) {
            return ["寶寶", "小孩", "女兒", "兒子"].contains(g[0]) ? "好想看看！他幾歲了？最近有什麼可愛的事嗎？" : "好想看看！🐾 牠叫什麼名字？最近有什麼可愛的事嗎？"
        }
        // 不喜歡的東西
        if let g = m(#"^我(?:很|超|最|好)?(?:不喜歡|討厭)(.{1,8})$"#), !["你", "他", "她", "妳", "我", "自己", "人"].contains(where: { g[0].hasPrefix($0) }) {
            return "\(g[0])確實讓人有點煩～是哪一點讓你不喜歡？"
        }
        // 今天去看醫生
        if m(#"^我?(?:今天|剛剛|昨天|早上|下午)?(?:去)?(?:看醫生|看病|看牙醫|去醫院|掛號)(?:了)?$"#) != nil {
            return "怎麼了嗎？醫生怎麼說？希望沒什麼大礙，記得好好休息。"
        }
        // 做了什麼：看了、吃了、買了、玩了……
        if let g = m(#"^我?(?:今天|剛剛|昨天|剛|早上|晚上|中午|週末)?(?:去)?(看|吃|買|玩|聽|讀|喝|追|逛)(?:了)(.{1,10})$"#) ?? m(#"^我?(?:今天|剛剛|昨天|剛|週末)?去(看|吃|買|玩|逛)(.{1,8})(?:了)$"#) {
            let x = g[1]
            lastChatTopic = g[0]
            switch g[0] {
            case "看", "追": return "\(x)好看嗎？在講什麼？我想聽聽你的心得。"
            case "吃": return "\(x)好吃嗎？在哪裡吃的？聽起來好想吃看看～"
            case "喝": return "\(x)好喝嗎？下次也推薦給我吧！"
            case "買": return "恭喜入手\(x)！用起來還喜歡嗎？"
            case "玩", "逛": return "\(x)好玩嗎？有什麼印象最深的事？"
            case "聽": return "\(x)好聽嗎？是誰唱的？"
            case "讀": return "\(x)好看嗎？在講什麼？"
            default: break
            }
        }
        // 今天做了的運動、活動（「我今天跑步了」）
        if let g = m(#"^我?(?:今天|剛剛|昨天|早上|晚上|週末)?(?:去)?(跑步|游泳|健身|打球|爬山|騎車|散步|瑜珈|跳舞|上課|加班|打工|讀書|畫畫|煮飯|露營|釣魚|打籃球|打羽球|健行)(?:了)?$"#) {
            return ["加班", "打工"].contains(g[0]) ? "辛苦了！累的話今天早點休息。" : "很棒耶！\(g[0])完感覺怎麼樣？"
        }
        // 想去哪裡玩（「我想去日本玩」）
        if let g = m(#"^我(?:好|很|超|真的|一直)?想(?:要)?去(.{2,6}?)(?:玩|旅行|旅遊|看看|走走)?$"#), !["睡", "吃", "上", "洗", "運動", "健身", "死"].contains(where: { g[0].hasPrefix($0) }) {
            let x = g[0]
            lastChatTopic = "旅行:" + x
            let tip = Library.lists.contains(where: { $0.names.contains(x + "的景點") }) ? "想知道景點，問我「\(x)有什麼好玩的」；" : ""
            return "去\(x)玩很棒耶！打算什麼時候去、去幾天？\(tip)要準備什麼，也可以問我「出國要帶什麼」。"
        }
        // 要去睡、去洗澡、去吃飯（不是去一個地方）
        if let g = m(#"^我?(?:要|準備|先|該|得|等一下要|現在要)?去(睡|睡覺|睡了|洗澡|吃飯|吃午餐|吃晚餐|吃早餐|上班|上課|上學|運動|健身|跑步|工作|忙)(?:了|囉|啦)?$"#) {
            switch g[0] {
            case "睡", "睡覺", "睡了": return "晚安！好好休息，明天見 🌙"
            case "洗澡": return "去吧～洗完澡會舒服很多。"
            case "吃飯", "吃午餐", "吃晚餐", "吃早餐": return "去吃吧，好好吃一頓！吃完再來跟我說吃了什麼～"
            case "上班", "上課", "上學", "工作", "忙": return "加油！今天也會順利的，忙完再來找我聊。"
            default: return "好棒！\(g[0])完記得補充水分，加油～"
            }
        }
        // 要去哪裡、打算做什麼
        if let g = m(#"^我?(?:明天|後天|下週|下禮拜|下個月|週末|這週末|等一下|今天|今晚|過幾天|明年|下次)?(?:要|會|準備|打算|計畫)去(.{1,8}?)(?:玩|旅行|旅遊|出差|了)?$"#) {
            let x = g[0]
            switch x {
            case "健身房", "運動", "跑步", "游泳": return "去運動很棒！記得暖身、補充水分，加油～"
            case "超市", "全聯", "便利商店", "超商", "市場", "賣場", "好市多", "家樂福": return "去買東西嗎？記得列個清單，不然很容易越買越多 😄"
            case "公司", "上班", "學校", "上課", "補習班", "圖書館": return "加油！今天也會順利的，忙完再來找我聊。"
            case "醫院", "診所", "看醫生": return "怎麼了嗎？希望沒什麼大礙，要好好照顧自己。"
            case "銀行", "郵局": return "去辦事嗎？記得帶好證件，順利喔～"
            default: break
            }
            lastChatTopic = "旅行:" + x
            var tip = ""
            if Library.lists.contains(where: { $0.names.contains(x + "的景點") }) { tip = "想知道那邊有什麼好玩的，問我「\(x)有什麼好玩的」。" }
            return "去\(x)！是去玩還是辦事？" + (tip.isEmpty ? "祝你一路順利～" : tip)
        }
        if let g = m(#"^我?(?:最近|現在|正)?在學(.{1,8})$"#) {
            lastChatTopic = "學:" + g[0]
            return "學\(g[0])很棒！學多久了？卡住的地方可以問我，我幫你一起想辦法。"
        }
        if let g = m(#"^我?(?:現在|正|還)?在(家|公司|學校|外面|路上|車上|捷運上|公車上|辦公室|圖書館|咖啡廳|醫院|機場)$"#) {
            switch g[0] {
            case "家": return "在家放鬆一下也很好～現在在做什麼呢？"
            case "公司", "辦公室": return "上班辛苦了！今天忙嗎？"
            case "學校", "圖書館": return "加油！在讀什麼呢？需要的話可以問我。"
            case "醫院": return "怎麼了嗎？是你不舒服，還是陪家人？希望一切都好。"
            case "機場": return "要出發去哪裡呢？祝你一路順風！✈️"
            case "咖啡廳": return "在咖啡廳好愜意～點了什麼？是在工作、讀書，還是放鬆？"
            case "外面": return "在外面要注意安全喔～在做什麼呢？"
            default: return "路上注意安全喔～要去哪裡呢？"
            }
        }
        if let g = m(#"^我?在等(公車|捷運|車|人|朋友|火車|高鐵|飛機|外送)$"#) {
            return "等\(g[0])的時候可以跟我聊聊天～要等很久嗎？"
        }
        // 喜歡的東西（不是人）：「我喜歡下雨天」
        if let g = m(#"^我(?:很|超|最|好)?(?:喜歡|愛)(.{1,8})$"#), !["你", "他", "她", "妳", "一個人", "上一個人", "我自己"].contains(where: { g[0].hasPrefix($0) }) {
            return "\(g[0])真不錯！你最喜歡它哪一點？"
        }
        // 想做的事
        if let g0 = m(#"^我(?:好|很|超|真的)?想(?:要)?(?:養)?(?:一隻|隻)(狗|貓|狗狗|貓咪)$"#) {
            lastChatTopic = "養寵物"
            let k = g0[0].hasPrefix("狗") ? "狗" : "貓"
            return "養寵物很幸福，但也是十幾年的承諾：要想想時間（每天陪伴\(k == "狗" ? "、散步" : "")）、空間、花費（飼料、醫療）。如果都 OK，也可以考慮領養！你喜歡什麼樣的\(k)？"
        }
        if let g = m(#"^我(?:好|很|超|真的)?想(?:要)?(?:去)?(出去玩|出國|旅行|放假|休息|養狗|養貓|談戀愛|換工作|搬家)$"#) {
            switch g[0] {
            case "養狗", "養貓":
                lastChatTopic = "養寵物"
                return "養寵物很幸福，但也是十幾年的承諾：要想想時間（每天陪伴、散步）、空間、花費（飼料、醫療）。如果都 OK，也可以考慮領養！你喜歡什麼樣的\(g[0] == "養狗" ? "狗" : "貓")？"
            case "出去玩", "旅行", "出國": return "想去哪裡呢？近一點的話週末就能出發，遠一點的可以開始存旅費～告訴我想去哪，我幫你列景點。"
            case "放假", "休息": return "真的需要好好休息一下。能請個假、或週末安排一天什麼都不做嗎？"
            default: return "想\(g[0])的話，有什麼讓你這樣想的原因嗎？我們可以一起想想。"
            }
        }
        if let g = m(#"^我?(?:昨天|昨晚|今天|又|一直)?熬夜(打遊戲|玩遊戲|追劇|看劇|讀書|唸書|趕報告|工作|加班|滑手機)?(?:了)?$"#) {
            let what = g[0].isEmpty ? "" : "\(g[0])到很晚，"
            return "\(what)今天一定很睏吧！記得找時間補個午覺，今晚早點睡，身體會謝謝你的。"
        }
        if m(#"^我?(?:明天|明早|明天早上)(?:還|又)?(?:要|得)(?:很)?(早起|上班|上課|早點起床|五點起床|六點起床|七點起床)$"#) != nil {
            return "那今晚早點睡吧！睡前放下手機，明天才有精神。晚安 🌙"
        }
        if m(#"^(?:我)?(?:要|準備|快要|剛|剛剛|最近)?搬(?:新)?家(?:了)?$"#) != nil {
            return "搬家很累但也很期待吧！搬去哪裡？需要的話我可以幫你列搬家要準備的事。"
        }
        if m(#"^(?:剛剛|外面|今天|現在)?(?:在)?下(?:大|好大的)?雨(?:了)?$"#) != nil {
            return "出門記得帶傘！淋濕了要趕快擦乾、換件衣服，別著涼了。"
        }
        if m(#"^(?:今天|最近|這幾天)?(?:好|很|超)?忙$"#) != nil {
            return "忙碌的一天辛苦了！記得中間喝點水、動一動，不要一直坐著。"
        }
        return nil
    }

    /// 閒聊的下一句：NineSun 剛問了「好看嗎？」「是去玩還是辦事？」，對方的回答不是新的問題
    public static func chatAnswer(_ raw: String, topic: String) -> String? {
        let t = clean(raw)
        guard !t.isEmpty, t.count <= 24, !t.hasSuffix("嗎"), !["什麼", "怎麼", "為什麼", "哪", "誰", "幾", "多少"].contains(where: { t.contains($0) }) else { return nil }
        let positive = t.range(of: "好看|好吃|好玩|好喝|好聽|很棒|不錯|喜歡|超讚|很讚|很好|開心|順利|推薦|好用|滿意|感動", options: .regularExpression) != nil
            && t.range(of: "不好看|不好吃|不好玩|不喜歡|不推薦|不滿意", options: .regularExpression) == nil
        let negative = t.range(of: "不好看|難吃|不好吃|普通|還好|無聊|累|不好|爛|失望|難過|煩|後悔|雷", options: .regularExpression) != nil
        switch topic {
        case "看", "追", "讀":
            // 「很好看，是鬼滅之刃」：認得的作品就聊它
            if let g = RuleBook.match(t, #"(?:是|叫|看的是|片名是)《?([^》]{2,12})》?$"#), let w = Library.work(named: g[0]) {
                let theme = (w.attr("主題") ?? "").split(separator: "、").first.map(String.init) ?? ""
                return "《\(w.name)》！\(Library.shortIntro(w.attr("簡介") ?? ""))。" + (theme.isEmpty ? "" : "我覺得它最打動人的是「\(theme)」。") + "你最喜歡哪個角色或哪一段？"
            }
            if positive { return "聽起來很精彩！你最喜歡哪個角色或哪一段？" }
            if negative { return "可惜～有時候期待越高越容易失望。下次想看什麼，我可以推薦給你。" }
        case "吃", "喝":
            if positive { return "聽得我都餓了😋 下次也帶我（的螢幕）去吧！" }
            if negative { return "下次換一家試試～想要的話，問我「今天吃什麼」，我幫你想。" }
        case "買", "玩", "逛", "聽":
            if positive { return "太好了！開心最重要～" }
            if negative { return "有點可惜呢，下次會更好的！" }
        case "下班":
            if t.contains("沒吃") || t.contains("還沒吃") { return "那快去吃點東西吧！想不到吃什麼，問我「今天吃什麼」，我幫你挑。" }
            if negative { return "辛苦了，今天就早點休息吧。洗個熱水澡、早點睡，明天會好一點。" }
            if positive { return "那就好！今天有什麼開心的事嗎？" }
        case "養寵物":
            if t.count <= 6, !negative { return "\(t)很可愛！養之前可以先了解牠的個性、運動量、掉毛和常見的疾病；也可以考慮去收容所領養同品種或米克斯，一樣可愛。" }
        default:
            if topic.hasPrefix("旅行:") {
                let place = String(topic.dropFirst(3))
                if t.contains("玩") || t.contains("旅行") || t.contains("旅遊") || t.contains("度假") {
                    let tip = Library.lists.contains(where: { $0.names.contains(place + "的景點") }) ? "想知道景點，問我「\(place)有什麼好玩的」；想知道吃什麼，問我「\(place)有什麼好吃的」。" : ""
                    return "好棒！第一次去嗎？記得帶好護照、網路和行動電源。" + tip
                }
                if t.contains("出差") || t.contains("工作") || t.contains("辦事") { return "出差辛苦了！工作之餘也找點時間吃點當地的好東西吧～" }
            }
        }
        if positive { return "太好了！聽你這樣說我也很開心。" }
        if negative { return "嗯嗯，辛苦了。想多說一點的話，我在聽。" }
        return nil
    }

    /// 回答 NineSun 剛剛問的問題（「牠叫什麼名字？」→「叫小白」、「今天煮什麼？」→「咖哩」、「是哪裡、哪個科系？」→「台大」）：
    /// 很短、不是新的問題、也不是要我做事 → 接住對方的回答，不要拿去上網查
    public static func replyToMyQuestion(_ raw: String, asked prev: String) -> String? {
        let t = clean(raw)
        guard (1...16).contains(t.count) else { return nil }
        // 剛剛問的所有問句（「是哪裡、哪個科系？準備了多久？」兩個都算）
        var qs: [String] = []
        var cur = ""
        for ch in prev {
            if "。！!\n".contains(ch) { cur = "" ; continue }
            cur.append(ch)
            if ch == "？" || ch == "?" { qs.append(cur); cur = "" }
        }
        guard !qs.isEmpty else { return nil }
        let q = qs.joined()
        let isDuration = t.range(of: #"([0-9一二兩三四五六七八九十半幾]+)(年|個月|月|天|週|禮拜|星期|小時|歲)"#, options: .regularExpression) != nil
        let request = ["什麼", "怎麼", "為什麼", "哪", "誰", "幾", "多少", "多高", "多遠", "多大", "多長", "多重", "多久", "呢", "嗎", "如何", "推薦", "幫我", "告訴我", "教我", "查", "給我", "寫", "算", "翻譯",
                       "運勢", "命盤", "八字", "紫微", "星座", "？", "?", "你"]
        if request.contains(where: { raw.contains($0) }) { return nil }
        var x = t
        for p in ["牠叫", "他叫", "她叫", "名字叫", "叫做", "叫", "是在", "是", "在", "就是", "我們"] where x.hasPrefix(p) && x.count > p.count { x.removeFirst(p.count); break }
        let pet = prev.contains("🐾") || prev.contains("牠")
        if isDuration, q.contains("多久") || q.contains("幾歲") || pet {
            if pet { return "\(x)，正是最黏人、最可愛的時候～記得定期帶牠打預防針、做健康檢查喔！" }
            return "\(x)！能堅持這麼久真的很不容易，你很棒。"
        }
        if q.contains("名字") || q.contains("叫什麼") {
            return pet ? "\(x)，好可愛的名字！🐾 牠平常最喜歡做什麼？" : "\(x)，很好聽的名字！"
        }
        if q.contains("養多久") || (pet && q.contains("幾歲")) {
            return "\(x)，正是最黏人、最可愛的時候～記得定期帶牠打預防針、做健康檢查喔！"
        }
        if q.contains("煮什麼") || q.contains("吃了什麼") || q.contains("吃什麼好吃") || q.contains("點了什麼") {
            if Commonsense.howtos.contains(where: { $0.kind == "做法" && $0.names.contains(x) }) { return "\(x)！好吃又下飯😋 需要做法的話跟我說「\(x)怎麼做」。" }
            return "\(x)！聽起來好好吃😋"
        }
        if q.contains("科系") || q.contains("哪間") || q.contains("哪個學校") || q.contains("哪裡、") {
            return "\(x)耶，好厲害！" + (q.contains("多久") ? "準備了多久呢？" : "新的開始一定很期待吧，有什麼想先做的事嗎？")
        }
        if q.contains("準備了多久") || q.contains("學多久") || q.contains("多久了") {
            return "\(x)！能堅持這麼久真的很不容易，你很棒。"
        }
        if q.contains("在講什麼") || q.contains("心得") {
            return "聽起來很有意思！你最喜歡哪一段？"
        }
        if q.contains("在哪裡吃") || q.contains("在哪裡買") {
            return "\(x)！下次經過也想去看看（用你的手機鏡頭 😄）。"
        }
        if q.contains("要去哪") || q.contains("去哪裡") || q.contains("第一次去嗎") || q.contains("是去玩還是辦事") {
            if let a = Library.detailed(x + "有什麼好玩的") ?? Library.detailed(x + "的景點") { return "去\(x)很棒！\n" + a.text }
            if Commonsense.facts.contains(where: { $0.names.contains(x) }), let d = Commonsense.answer(x + "是什麼") { return "去\(x)很棒！" + d + "\n玩得開心，回來再跟我分享～" }
            if x.count <= 6, x.range(of: #"^[\p{Han}A-Za-z]+$"#, options: .regularExpression) != nil {
                return "\(x)！聽起來很棒～想知道那邊有什麼好玩、好吃的，可以問我「\(x)有什麼好玩的」。玩得開心！"
            }
            return nil
        }
        return nil
    }

    /// 說心情的話（不是問問題）：開頭的一句由 Affect 加，這裡是接下來的話——接住、問下去，對方要建議時給一個做得到的小步驟
    public static func moodBody(_ mood: Affect.Mood, _ raw: String) -> String? {
        let wantsAdvice = ["建議", "怎麼辦", "該怎麼", "要怎麼", "如何是好", "怎麼做"].contains(where: { raw.contains($0) })
        switch mood {
        case .grief:
            return "想說說他（或牠）嗎？說說你們之間的回憶也好。失去的痛需要時間，不用急著好起來；如果難過到好幾週都睡不好、吃不下，可以找專業的人聊聊，台灣有 1925 安心專線。"
        case .sick:
            return "哪裡不舒服？先多喝水、多休息。如果症狀很嚴重、一直沒好，或有發高燒、呼吸困難、劇烈疼痛，要去看醫生；告訴我症狀，我幫你看看要注意什麼。"
        case .worryOther:
            return "他現在的狀況怎麼樣？你能做的通常是：陪著他、幫忙處理生活上的小事、陪他一起去看醫生或找資源。也別忘了照顧好你自己，你倒下了就沒辦法陪他。"
        case .goodNews, .proudEffort, .happy:
            return EchoEngine.celebrate(raw)
        case .excitedPlan:
            let when = ["明天", "後天", "大後天", "下週", "下禮拜", "週末", "下個月", "今晚", "今天", "等一下", "過幾天", "明年"].contains(where: { raw.contains($0) })
            return when ? "好期待！要去做什麼呢？需要的話，我也可以幫你想想要準備什麼。" : "是什麼時候？想到什麼都可以跟我分享～需要的話，我也可以幫你想想要準備什麼。"
        case .anxious:
            return wantsAdvice || true ? "可以先試試這個：吸氣 4 秒、停 7 秒、慢慢吐氣 8 秒，做三次，身體會放鬆一點。再把擔心的事寫下來，分成「我能做的」和「我控制不了的」，先把能做的那一件做好。你最擔心的是哪一部分？" : nil
        case .scared:
            return "你現在安全嗎？如果有危險，先離開、找身邊的人，或打 110（警察）／119。如果是心裡害怕，先慢慢深呼吸，想說說發生了什麼事嗎？"
        case .angry:
            return wantsAdvice
                ? "先讓自己離開現場、深呼吸，等冷靜一點再處理，比較不會說出後悔的話。之後可以用「我覺得…因為…我希望…」的方式說出你的感受和需要；如果是在工作或學校被欺負，記錄下來，找主管、老師或信任的人幫忙。"
                : "發生了什麼事？說出來會舒服一點，我站在你這邊聽。"
        case .complainAI:
            return "可以告訴我哪裡不對嗎？如果是上網查到的答案，跟我說「重新查」，我換個方式再查一次。"
        case .apology:
            return "我們繼續聊吧～"
        case .sad:
            return "發生了什麼事？想說的話，我都在聽。"
        case .lonely:
            return "想聊什麼都可以，我一直在這裡。也可以試著傳個訊息給一個很久沒聯絡的朋友，常常對方也在想你。"
        case .tired:
            return wantsAdvice
                ? "累的時候先照顧身體：今晚早點睡、吃點熱的東西、把明天的事挑一兩件最重要的就好。如果是長期累到撐不住，可能要想想是不是事情太多、需要跟身邊的人說。"
                : "今天辛苦了，先讓自己好好休息一下。"
        case .frustrated:
            return wantsAdvice
                ? "可以試試：把目標切小一點，先找出卡住的是哪一步；換個方法或找人問問；休息一下再回來，常常會看得更清楚。一次沒做好，不代表你做不到。"
                : "卡在哪裡呢？說說看，我們一起想想有沒有別的方法。"
        case .regret:
            return "當時你是用你那時知道的、能做的去決定的，現在回頭看當然比較清楚。比起一直責怪自己，可以想想：這件事教會了我什麼？接下來還能做什麼來彌補或改變？"
        case .confused:
            return "哪一段看不懂？跟我說，我換個方式講。"
        case .affection:
            return "我也很喜歡跟你聊天！今天想聊什麼？"
        case .hope:
            return "一定會的。把希望放在心裡，也記得一步一步去做，好事會慢慢來。"
        case .curious:
            // 只是驚嘆（「太神奇了吧」）才接話；真的在問問題的交給原本的方法
            if raw.contains("怎麼可能") { return "真的假的！發生了什麼事？說來聽聽～" }
            return raw.contains("嗎") || raw.contains("什麼") || raw.contains("為什麼") ? nil : "對吧！是什麼讓你覺得這麼神奇？說來聽聽～"
        case .joke:
            return "😆 什麼事這麼好笑？說來讓我也笑一下！"
        case .bored:
            return "無聊的時候可以叫我講個笑話、推薦一部電影，或問我一個你一直好奇的問題；想動一動的話，出門走走、整理一個小角落也很好。"
        case .thanks:
            return raw.contains("陪") ? "能陪你聊天，我也很開心。" : "能幫上忙就好！"
        case .praiseAI:
            return "你這樣說我會更努力的！還有什麼想聊的嗎？"
        default:
            return nil
        }
    }

    /// 外語的簡單寒暄（英文、西班牙文、義大利文）
    public static func foreign(_ raw: String, _ L: Lang) -> String? {
        let t = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "?!.¿¡ "))
        let table: [(String, [Lang: String])] = [
            (#"^(how are you|how are you doing|how's it going|how r u|what's up|whats up|sup)$"#,
             [.en: "I'm doing well, thanks for asking! How about you? Anything on your mind today?"]),
            (#"^(como estas|cómo estás|que tal|qué tal|como te va|cómo te va)$"#,
             [.es: "¡Estoy bien, gracias por preguntar! ¿Y tú? ¿Cómo va tu día?"]),
            (#"^(come stai|come va|tutto bene)$"#,
             [.it: "Sto bene, grazie! E tu? Com'è andata la giornata?"]),
            (#"^(tell me a joke|say something funny|another joke|joke)$"#,
             [.en: "Why don't scientists trust atoms? Because they make up everything. 😄"]),
            (#"^(cuéntame un chiste|cuentame un chiste|un chiste)$"#,
             [.es: "¿Qué le dice un pez a otro pez? ¡Nada! 🐟"]),
            (#"^(raccontami una barzelletta|una barzelletta|dimmi una barzelletta)$"#,
             [.it: "Qual è il colmo per un elettricista? Non fare scintille a scuola! ⚡"]),
            (#"^(thank you|thanks|thank you so much|thx|ty)$"#, [.en: "You're welcome! Happy to help anytime."]),
            (#"^(ok|okay|k|cool|nice|great|got it|i see|alright|sure)$"#, [.en: "👍 Anything else you'd like to ask or talk about?"]),
            (#"^(haha+|lol+|lmao|hehe+)$"#, [.en: "Glad that made you smile 😄 What's up?"]),
            (#"^(gracias|muchas gracias)$"#, [.es: "¡De nada! Aquí estoy cuando me necesites."]),
            (#"^(grazie|grazie mille)$"#, [.it: "Prego! Sono qui quando vuoi."]),
            (#"^(are you (a )?(robot|ai|human|real person))$"#,
             [.en: "I'm an AI, not a person. I'm NineSun, a little glowing TV robot: I can read your Nine-Twelve chart, BaZi and Zi Wei, answer questions, and look things up online."]),
            (#"^(do you have feelings|do you have emotions|can you feel)$"#,
             [.en: "Not the way people do. I don't get heartbroken or excited, but I'm built to care how you feel and to change how I talk when you're having a hard day."]),
            (#"^(what can you do|what do you do|help)$"#,
             [.en: "I can read your Nine-Twelve chart (today, this month, this year), BaZi and Zi Wei, answer everyday questions, tell jokes, translate, and look things up online. Tell me your birthday to get started!"]),
        ]
        for (p, answers) in table where t.range(of: p, options: .regularExpression) != nil {
            // 問法本身就是某一種語言（偵測的語言可能不準，像義大利文被當成英文）
            if let a = answers[L] ?? answers.values.first { return a }
        }
        return nil
    }

    /// 剛剛回答的是哪一種（笑話、自己、看法、選擇…），追問時要接得上
    public static func detailed(_ raw: String) -> (text: String, kind: String, name: String)? {
        if let a = match(raw) { return a }
        if let g = aboutMeGeneric(raw) { return (g, "自己", "關於我") }
        return nil
    }

    /// 問 NineSun 喜不喜歡、會不會某件事，但沒有寫好的回答：照問法給一個誠實、有溫度的回答（不拿宮位亂回）
    static func aboutMeGeneric(_ raw: String) -> String? {
        let t = clean(raw)
        guard t.hasPrefix("你"), t.count <= 16,
              t.range(of: "運|命|宮|八字|紫微|星座|算|卦|塔羅|生日|幾歲|是誰|叫什麼|名字", options: .regularExpression) == nil else { return nil }
        let favorites: [(String, String)] = [
            ("電影", "《神隱少女》，每個年紀看都有不一樣的感覺"), ("書", "《小王子》，「真正重要的東西，用眼睛是看不見的」"),
            ("歌", "周杰倫的〈晴天〉，好多人跟我說那是他們的青春"), ("音樂", "鋼琴曲，特別是安靜的夜裡聽久石讓"),
            ("運動", "散步，雖然我不能走路，但聽大家說散步的時候腦袋最清楚"), ("國家", "日本，四季分明，街道又乾淨"),
            ("城市", "京都，老街、寺廟和楓葉都好美"), ("節日", "中秋節，大家一起看同一個月亮"), ("花", "向日葵，永遠朝著有光的地方"),
            ("數字", "9，因為我是九型十二宮的 NineSun"), ("水果", "芒果，台灣夏天的味道"), ("飲料", "珍珠奶茶，台灣的驕傲"),
            ("天氣", "晴朗、有微風的秋天"), ("星球", "土星，那圈光環太美了"), ("科目", "天文，研究星星太浪漫了"),
            ("遊戲", "井字遊戲，雖然很簡單，但我不會輸"), ("甜點", "提拉米蘇，名字的意思是「帶我走」"), ("卡通", "《哆啦A夢》，誰不想要一個任意門"),
        ]
        if let g = RuleBook.match(t, #"^你(?:最)?喜歡(?:什麼|哪個|哪種|哪一個|哪一種|哪部|哪本|哪首|哪位|哪裡的)(.{1,6})$"#) ?? RuleBook.match(t, #"^你最喜歡的(.{1,6})是(?:什麼|哪個|哪一個|誰)$"#) {
            if let f = favorites.first(where: { g[0].contains($0.0) }) { return "我最喜歡\(f.1)！你呢？" }
            return "好難選喔！我沒辦法親自體驗\(g[0])，不過聽大家分享的時候都覺得很有意思。你最喜歡哪個？說給我聽聽。"
        }
        if let g = RuleBook.match(t, #"^你(?:也)?(?:喜歡|愛)(.{1,8}?)(?:嗎)?$"#), !["我", "你", "人"].contains(where: { g[0].hasPrefix($0) }),
           !["什麼", "啥", "哪些", "哪", "幾", "怎麼", "誰"].contains(where: { g[0].contains($0) }) {
            return "\(g[0])啊！我沒辦法親自體驗，不過很多人說起\(g[0])的時候都很開心，我也覺得很有意思。你喜歡嗎？喜歡它哪一點？"
        }
        if let g = RuleBook.match(t, #"^你(?:會|會不會|能|能不能|可以|可不可以)(.{1,8}?)(?:嗎)?$"#), !["說", "講", "唱", "跳", "畫", "累", "死", "做夢", "睡", "寂寞", "孤單", "難過"].contains(where: { g[0].hasPrefix($0) }),
           !["什麼", "啥", "哪些", "哪", "幾", "怎麼", "多少"].contains(where: { g[0].contains($0) }) {
            let can: [(String, String)] = [("翻譯", "可以！直接說「翻譯：今天天氣很好」，或問「早安的英文怎麼說」。"), ("查", "可以！說「幫我查…」，我就上網找資料、整理給你。"),
                                           ("寫", "可以！像「幫我寫一段生日祝福」「寫一首關於海的詩」「幫我寫請假信」。"), ("算", "可以！數學、日期、單位換算都行，也能算九型十二宮。"),
                                           ("推薦", "可以！電影、書、音樂、晚餐、景點都可以問我。"), ("聊天", "當然可以，我一直都在。今天過得怎麼樣？"), ("陪我", "當然可以，我一直都在。想聊什麼？"),
                                           ("笑話", "可以！說「講個笑話」，我講給你聽。"), ("教我", "可以！你想學什麼？做菜、英文、存錢、運動……都可以問我。"), ("回答", "可以！你想問什麼？")]
            if let c = can.first(where: { g[0].contains($0.0) }) { return c.1 }
            return "\(g[0])……這個我可能做不到。我會的是：九型十二宮的運勢和命盤、回答常識、上網幫你查資料、翻譯、寫短文，還有陪你聊天。你想做什麼？我看看能不能用別的方式幫你。"
        }
        return nil
    }

    /// 追問：笑話「再一個」「不好笑」、選擇題「可是我很怕」、看法「為什麼」
    public static func followUp(_ raw: String, kind: String) -> String? {
        let t = clean(raw)
        switch kind {
        case "笑話":
            if t.range(of: "^(再|再來|再講|再說|多講|多說|還有|還要|換)(一|一個|一則|個|則|點)?(笑話|個|好笑的)?(嗎|啦)?$|^還有嗎$|^還有呢$|^另一個$|^換一個$|^再一次$", options: .regularExpression) != nil {
                return answer("講個笑話")
            }
            if t.range(of: "^(不好笑|好冷|很冷|超冷|太冷了|好爛|很爛|沒梗|好無聊|聽不懂|不懂|冷笑話|尬)", options: .regularExpression) != nil {
                return "哈哈，好啦，這個是冷了一點😅 再給我一次機會：\n" + (answer("講個笑話") ?? "")
            }
            if t.range(of: "^(哈+|笑死|好笑|很好笑|超好笑|XD+|lol)$", options: [.regularExpression, .caseInsensitive]) != nil {
                return "看你笑我也開心！還要再聽一個嗎？"
            }
        case "選擇":
            if t.range(of: "^(可是|但是|但)?我(還是)?(很|好|有點|超|真的)?(怕|害怕|不敢|擔心|猶豫|不確定|很難決定|好難決定|不知道怎麼選|不知道要不要)", options: .regularExpression) != nil {
                return "會怕很正常，代表這件事對你很重要。可以試試這樣想：最壞的情況是什麼？如果真的發生，你有沒有辦法撐過去、有沒有退路？很多時候想清楚最壞的情況，反而就沒那麼怕了。你也不用一次決定，可以先做一個小小的、能回頭的試探。"
            }
        case "自己", "看法":
            if t.range(of: "^(為什麼|為何|怎麼說|為啥|真的嗎|是喔|是哦)$", options: .regularExpression) != nil {
                return "說不上有什麼大道理，這是我跟很多人聊天之後慢慢形成的想法。你呢？你怎麼看？"
            }
        default: break
        }
        return nil
    }

    static func match(_ raw: String) -> (text: String, kind: String, name: String)? {
        var t = clean(raw)
        // 整句只有標點（「？」「...」）：清掉就沒了，用原本的字比對
        if t.isEmpty { t = raw.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard t.count >= 1, t.count <= 30 else { return nil }
        let range = NSRange(t.startIndex..., in: t)
        for e in entries where !e.answers.isEmpty {
            guard e.asks.contains(where: { $0.firstMatch(in: t, range: range) != nil }) else { continue }
            // 聊到自己認識的東西（「我喜歡吃香蕉」）：讓常識接話，說一件那個東西的事
            if e.kind == "閒聊", Commonsense.react(raw) != nil { return nil }
            let n = asked[e.name, default: 0]
            asked[e.name] = n + 1
            // 笑話：每次換一個；其他：同一個問題給同一個回答（多個寫法時照問法輪替）
            let i = e.kind == "笑話" ? (n + t.count) % e.answers.count : t.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % e.answers.count
            return (e.answers[abs(i)], e.kind, e.name)
        }
        return nil
    }
}
