import Foundation

/// 判斷：這句話能不能當成這題的答案？不能的話，是哪一種錯——像人看網頁一樣，一句一句問自己：
///   這是網站自己的廣告、操作說明嗎？（「設定後，在 Google 搜尋食譜時，愛料理的食譜會優先出現！」）
///   這是在介紹文章、不是內容嗎？（「這篇文章將教你…」）
///   這是名字由來、典故，不是做法嗎？（「顏色不那麼深，可能因此取名黃燜」）
///   這是留言、心得嗎？（「看起來好好吃」「感謝分享」）
///   這是標題、問句嗎？
///   答案的種類對嗎？（問做法要有動作；問數字要有數字；問時間要有年份……）
///   有講到問的主題嗎？
public enum Judge {
    public enum Verdict: String, CaseIterable {
        case answer      // 可以當答案
        case promo       // 網站自己的廣告、App、會員、按讚分享、搜尋設定
        case meta        // 介紹文章本身（這篇文章、以下、小編、懶人包）
        case trivia      // 名字由來、典故、傳說（問做法、數字時不是答案）
        case opinion     // 留言、心得、讚美（好好吃、感謝分享）
        case question    // 標題、問句
        case wrongType   // 種類不對（問做法沒有動作、問數字沒有數字……）
        case offTopic    // 沒講到問的東西
        case empty       // 太短、不成句
    }

    static let promoWords = ["Google", "google", "App", "APP", "app", "下載", "會員", "登入", "註冊", "訂閱", "追蹤我們", "按讚", "分享給", "分享到", "留言",
                             "收藏", "點擊", "點我", "點此", "優先出現", "粉絲團", "粉絲專頁", "頻道", "本站", "官網", "購物車", "免運", "優惠", "折扣", "客服",
                             "版權", "廣告", "贊助", "合作邀約", "訊息通知", "推播", "加入好友", "掃描", "QR", "連結", "網址", "看更多", "更多食譜", "相關食譜",
                             "立即", "限時", "搶購", "團購", "下單", "專屬", "設定後"]
    static let metaWords = ["這篇文章", "本文", "本篇", "這篇", "文章將", "旨在", "小編", "帶你", "帶大家", "一起來看", "為你整理", "為大家整理", "整理了",
                            "懶人包", "以下", "下面", "延伸閱讀", "推薦閱讀", "相關文章", "上一篇", "下一篇", "目錄", "今天要", "今天就", "分享一道", "跟大家分享"]
    static let triviaWords = ["取名", "命名", "得名", "名字的由來", "由來", "起源於", "源自", "典故", "相傳", "傳說", "據說", "所以叫", "才叫", "會叫",
                              "被稱為", "叫做", "又稱", "名稱", "發源"]
    static let opinionWords = ["好好吃", "看起來好", "看起來很", "太好吃", "超好吃", "真好吃", "感謝分享", "謝謝分享", "收藏了", "學起來", "推推", "必學",
                               "我覺得", "我個人", "大推", "超推", "好喜歡", "愛吃", "最愛", "讚！", "好讚", "XD", "哈哈", "^^", "～～"]
    /// 做法的一步要有動作（做菜、一般的做法、手機電腦操作）
    static let actionWords = ["加入", "放入", "倒入", "加上", "加點", "加水", "下鍋", "切", "洗", "泡", "煮", "炒", "煎", "蒸", "烤", "燉", "燜", "滷", "炸",
                              "拌", "攪", "醃", "調味", "撒", "淋", "鋪", "包", "捲", "揉", "打", "開火", "關火", "轉小火", "轉中火", "大火", "小火", "中火",
                              "起鍋", "盛", "擺", "放", "倒", "撈", "瀝", "冷藏", "冷凍", "靜置", "預熱", "先", "再", "接著", "然後", "最後", "直到", "至",
                              "可以", "建議", "試著", "保持", "避免", "不要", "記得", "每天", "準備", "選擇", "打開", "點選", "按下", "輸入", "開啟", "關閉",
                              "安裝", "更新", "重新", "清除", "檢查", "確認", "練習", "固定", "減少", "增加", "把", "喝", "吃", "睡", "走", "讀", "寫",
                              "存", "記錄", "設定", "規劃", "安排", "找人", "找朋友", "找出", "列出", "拆成", "專心", "休息", "放鬆", "深呼吸", "伸展", "洗淨",
                              "剝", "削", "搓", "壓", "擠", "沖", "冲", "浸", "攤", "翻面", "收汁", "勾芡", "裝盤"]
    static let reasonWords = ["因為", "由於", "原因", "所以", "導致", "造成", "使得", "是因", "引起", "來自", "為了", "機制", "反射", "散射", "源自", "透過", "是由", "因此"]
    static let defineWords = ["是指", "指的是", "是一種", "是一個", "是一門", "稱為", "意思是", "又稱", "簡稱", "定義", "是用來", "是", "指"]

    /// 有數字：阿拉伯數字，或中文數字後面接單位（「一座」「一個」的「一」不算數字）
    static func hasDigit(_ s: String) -> Bool {
        s.contains(where: \.isNumber)
            || s.range(of: "[一二兩三四五六七八九十百千萬億]+(公尺|公里|米|公分|公斤|公克|克|噸|人|萬|億|千|百|年|度|%|倍|分鐘|小時|天|光年|英里|英尺|元|歲|週|月)", options: .regularExpression) != nil
    }

    /// inContext：這句話來自一個已經確定在講這個主題的網頁（食譜裡的「加入雞肉翻炒」不用再提「黃燜雞」）
    public static func check(_ raw: String, want: Understanding.Want, subject: String, question: String = "", inContext: Bool = false) -> Verdict {
        let s = raw.trimmingCharacters(in: .whitespaces)
        // 編號、項目符號（「1.」「Step 5：」「②」「•」「★」）不是內容，先拿掉（「Step 5」的 5 不是答案裡的數字）
        let body = s.replacingOccurrences(of: #"^(?:\s*(?:\d{1,2}[\.、．)）]|[①②③④⑤⑥⑦⑧⑨⑩]|(?:步驟|Step|STEP|step)\s*\d+\s*[:：.、]?|[•●○◆◇■□▶►★☆✓✔➤→·\-\*＊]))+\s*"#, with: "", options: .regularExpression)
        let subj = subject.filter { $0.isLetter || $0.isNumber }
        // 主題本身就有這個字的不算（問「怎麼下載 App」「Google 是什麼」）
        func flagged(_ ws: [String]) -> Bool { ws.contains { body.contains($0) && !subj.contains($0) && !question.contains($0) } }
        // 人看一句話的順序：
        // ① 是留言、心得嗎？（「好讚的分享」很短，也要先認出來）
        if flagged(opinionWords) { return .opinion }
        if body.count < 6 { return .empty }
        // ② 是網站自己的廣告、操作嗎？是在介紹文章嗎？是標題、問句嗎？
        if flagged(promoWords) { return .promo }
        if flagged(metaWords) { return .meta }
        if body.hasSuffix("？") || body.hasSuffix("?") || body.hasSuffix("嗎") { return .question }
        // ③ 問做法、數字、時間、地點、人：名字由來、典故不是答案
        switch want {
        case .steps, .number, .time, .place, .person, .list:
            if flagged(triviaWords) { return .trivia }
        default: break
        }
        // ④ 有講到問的東西嗎？（來自確定在講主題的網頁的步驟可以不提）
        if !inContext, !subj.isEmpty {
            let core = subjectCore(subj)
            if !core.isEmpty, !core.contains(where: { body.contains($0) }) { return .offTopic }
        }
        // ⑤ 答案的種類對嗎？——問題裡本來就有的字不算新資訊（「炸雞是家常菜」的「炸」、「人類登月影響深遠」的「月」不是答案）
        var rest = body
        if subj.count >= 2 { rest = rest.replacingOccurrences(of: subj, with: "") }
        switch want {
        case .steps:
            guard actionWords.contains(where: { rest.contains($0) }) else { return .wrongType }
        case .number:
            guard hasDigit(rest) else { return .wrongType }
        case .time:
            guard rest.contains(where: { $0.isASCII && $0.isNumber }) || rest.range(of: "[一二三四五六七八九十百千]+(年|世紀)|年代|朝|世紀", options: .regularExpression) != nil else { return .wrongType }
        case .reason:
            guard reasonWords.contains(where: { rest.contains($0) }) else { return .wrongType }
        case .place:
            // 要說出地方：位於…、…市／縣／省／國、…部（「在世界上很有名」不算）
            guard rest.range(of: "位於|位在|坐落|座落|首都|地處|[^\\s，。]{1,8}(市|縣|省|州|國|島|區|城|鎮|鄉|村|洲|半島)|(東|西|南|北|中)部", options: .regularExpression) != nil else { return .wrongType }
        default: break
        }
        return .answer
    }

    /// 一般的動作（改善、提升、學習……）不是主題本身：「改善失眠」的主題是「失眠」，「提升專注力」的主題是「專注力」
    static let genericVerbs: Set<String> = ["改善", "提升", "提高", "學習", "學會", "練習", "準備", "開始", "處理", "解決", "克服", "養成", "戒掉", "減少",
                                            "增加", "如何", "怎麼", "方法", "做法", "讓自", "自己", "變得", "保持", "避免", "改掉", "擺脫", "緩解", "跟主", "主管"]

    /// 主題的關鍵片段：整個主題、各個兩字詞（「黃燜雞」→ 黃燜雞、黃燜、燜雞），內容詞的近義詞也算（「好處」↔「益處」）
    static func subjectCore(_ subj: String) -> [String] {
        let c = Array(subj)
        guard c.count >= 2 else { return [] }
        var out = [subj]
        for i in 0..<(c.count - 1) where !(Synthesize.stopChars.contains(c[i]) && Synthesize.stopChars.contains(c[i + 1])) {
            let g = String(c[i...i + 1])
            if !genericVerbs.contains(g) { out.append(g) }
        }
        for w in out where w.count >= 2 && !genericVerbs.contains(w) { out += Synonyms.near(w).filter { !genericVerbs.contains($0) } }
        return out
    }

    public static func isAnswer(_ s: String, want: Understanding.Want, subject: String, question: String = "", inContext: Bool = false) -> Bool {
        check(s, want: want, subject: subject, question: question, inContext: inContext) == .answer
    }
}
