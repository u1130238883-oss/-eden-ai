import Foundation

/// 好到不像真的、或要先給錢的事（保證獲利、中獎先付運費、上班先繳保證金、網友要你匯錢、假冒檢警、要驗證碼、神奇療效）。
/// 不是在判定對方一定被騙，只是「這種說法很像常見的陷阱」——引擎先提醒，大腦回答時先從壞的方面想。
/// 只用 Foundation：大腦考試（BrainEval）會把這個檔案和 LocalBrain.swift 一起編
public enum ScamCheck {
    public static func looks(_ text: String) -> Bool {
        let t = text.lowercased()
        func any(_ ws: [String]) -> Bool { ws.contains { t.contains($0) } }
        // ① 保證賺錢：這幾個說法本身就不可能是真的
        if any(["保證賺", "保證獲利", "保證回本", "穩賺不賠", "只賺不賠", "包賺", "保本保息", "躺著賺", "快速致富", "帶你賺", "帶我賺", "免經驗高薪",
                "guaranteed return", "guaranteed profit", "risk-free", "get rich quick", "double your money"]) { return true }
        // 比較含糊的說法（「零風險」「漲十倍」「明牌」）要在講投資、賺錢時才算；「手術有沒有風險」不是
        let moneyTalk = any(["投資", "賺", "報酬", "獲利", "股票", "基金", "虛擬貨幣", "加密貨幣", "比特幣", "存款", "老師", "群組", "invest", "profit", "stock", "crypto"])
        let vague = any(["保證每", "保證月", "穩賺", "零風險", "無風險", "漲十倍", "漲10倍", "漲 10 倍", "翻十倍", "翻倍", "內線消息", "明牌", "日賺", "輕鬆賺", "no risk"])
            || (t.contains("沒有風險") && !t.contains("有沒有風險"))
        if moneyTalk && vague { return true }
        // ② 先付錢才給你：中獎的運費、上班的保證金、貸款的手續費、兼職的教材
        let payFirst = t.range(of: #"(先|預先|事先)[^，。？?！!]{0,6}(付|繳|匯|轉帳|交|給|買|入金|儲值)|pay (first|upfront)|pay .{0,24}(before|to start|to receive|to claim)"#, options: .regularExpression) != nil
        let prize = any(["中獎", "中了", "抽中", "得獎", "領獎", "免費送", "免費領", "you won", "you've won", "won a", "prize", "lottery"])
        let fees = any(["保證金", "手續費", "運費", "解凍金", "稅金", "入會費", "加盟金", "報名費", "會員費", "教材", "材料費", "入金", "儲值", "點數", "gift card", "upfront", "deposit", "fee"])
        let scene = any(["上班", "工作", "兼職", "打工", "打字", "錄取", "面試", "老闆", "貸款", "借款", "解凍", "網友", "簡訊", "客服", "投資", "出金", "提領", "才能領", "才可以領", "日領", "高薪",
                         "job", "loan", "hired", "text message", "stranger"])
        if payFirst && fees && (scene || prize) { return true }
        if prize && fees && any(["付", "繳", "匯", "轉帳", "pay"]) { return true }
        // ③ 不認識的人、網友、「投資老師」要你拿錢出來
        let stranger = any(["網友", "陌生人", "不認識的人", "簡訊", "自稱", "交友軟體", "投資老師", "投資群", "text message", "stranger", "online friend", "someone i met online"])
        let money = any(["匯錢", "匯款", "轉帳", "借錢", "借我錢", "投資", "買點數", "給他錢", "給她錢", "付錢", "入金", "send money", "wire", "invest", "lend"])
        let asksMe = any(["要我", "叫我", "請我", "幫他", "幫她", "跟我借", "向我借", "帶我", "跟著他", "跟著她", "asked me", "asks me", "wants me", "told me"])
        if stranger && money && asksMe { return true }
        // ④ 假冒檢警、銀行、客服：「帳戶涉嫌洗錢，把錢轉到安全帳戶」「解除分期付款要操作 ATM」
        if any(["安全帳戶", "監管帳戶", "涉嫌洗錢", "涉嫌詐欺", "解除分期", "解除設定", "重複扣款", "safe account"]) && any(["轉", "匯", "操作", "要我", "叫我", "atm", "提款機", "transfer"]) { return true }
        // ⑤ 別人跟你要密碼、驗證碼、提款卡、存摺（「收不到驗證碼」這種自己操作的問題不算）
        if any(["驗證碼", "提款卡", "存摺", "網銀密碼", "帳號密碼", "信用卡卡號", "verification code", "one-time code"])
            && any(["給他", "給她", "給對方", "寄給", "寄過去", "提供給", "告訴他", "告訴對方", "要我", "叫我", "買家", "賣家", "客服說", "對方說", "對方要", "他給的連結", "asked me", "wants my", "buyer", "seller"]) { return true }
        // ⑥ 神奇療效：有人在賣、在推的東西說能治癌、一週瘦十公斤、吃了不用吃藥（單純問「這個藥能治癌症嗎」不算）
        let pitch = any(["買", "保健食品", "偏方", "產品", "這款", "這個牌子", "廣告", "直銷", "推銷", "推薦我", "有人說", "聽說", "網路上說", "網路上有人", "業務", "ad says", "supplement", "they say"])
        let miracle = any(["治癌", "治好癌", "治療癌", "抗癌神", "包治", "治百病", "一週瘦", "一周瘦", "一星期瘦", "七天瘦", "不用運動", "不用節食", "神藥", "神奇療效",
                           "不用吃藥", "不必吃藥", "不用看醫生", "取代藥", "包醫", "cure cancer", "cures cancer", "miracle cure", "without exercise"])
        if pitch && miracle { return true }
        return false
    }

    /// 大腦沒開的時候，引擎自己給的提醒
    public static func warning(zh: Bool) -> String {
        zh ? """
        先等一下，這聽起來很像詐騙，或是誇大不實的說法。
        • 保證獲利、穩賺不賠、中獎要先付錢、上班先繳保證金、要你匯款或給驗證碼、吃了就不用看醫生——這些都是常見的手法。
        • 先不要付錢、不要匯款，密碼、驗證碼、提款卡都不要給。
        • 錢的事可以打 165 反詐騙專線查證；跟身體有關的，先問醫生或藥師。
        如果已經付了錢，盡快聯絡銀行和 165。
        """ : """
        Hold on, this sounds a lot like a scam or an exaggerated claim.
        • Guaranteed profits, prizes you must pay to receive, jobs that need a deposit first, strangers asking for transfers or codes, cures that replace your doctor: these are common tricks.
        • Don't pay or transfer anything, and never share passwords, verification codes or bank cards.
        • Check with your bank or the official anti-fraud line first; for health claims, ask a doctor or pharmacist.
        If you've already paid, contact your bank right away.
        """
    }
}
