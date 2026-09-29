import Foundation

/// NineSun 上網查資料的「解題思路」：不同種類的問題，要從不同的方面去查，最後分段回答。
///
/// 例：問「甲減是什麼」（健康／疾病）
///   ① 先認出主題：甲減 = 甲狀腺機能低下症（口語、簡稱先換成正式名稱，兩個都查）
///   ② 拆成幾個方面分別搜尋：是什麼 → 症狀 → 原因 → 治療 → 飲食與日常照顧
///   ③ 每個方面打開網頁閱讀，只留下講到那個方面的句子（症狀就找「症狀、表現、出現」這類句子）
///   ④ 醫院、衛福部、醫學資料庫的說法優先；好幾個來源都講的才算可信
///   ⑤ 分段回答，附上來源；健康問題最後提醒看哪一科
enum WebStrategy {
    struct Angle {
        let title: String
        /// 加在主題後面的搜尋詞
        let suffix: String
        /// 句子裡要出現這些詞，才算在講這個方面
        let cues: [String]
    }

    struct Strategy {
        let angles: [Angle]
        /// 優先採用的網站
        let trusted: [String]
        let note: String?
    }

    static let healthWords = ["病", "症", "癌", "炎", "甲狀腺", "甲減", "甲亢", "糖尿", "血壓", "血脂", "血糖", "尿酸", "痛風", "症狀", "治療", "藥",
                              "過敏", "感冒", "發燒", "咳嗽", "失眠", "頭痛", "胃痛", "腹瀉", "便秘", "肝", "腎", "心臟", "中風", "憂鬱", "焦慮", "懷孕",
                              "月經", "經痛", "疫苗", "橋本", "貧血", "骨質", "關節", "皮膚", "濕疹", "痘", "結節", "腫瘤", "荷爾蒙", "激素", "維生素",
                              "disease", "symptom", "treatment", "thyroid", "diabetes", "cancer", "enfermedad", "síntoma", "malattia", "sintomi"]

    static let legalWords = ["法律", "違法", "合法", "犯法", "觸法", "判刑", "判決", "罰款", "罰鍰", "罰則", "提告", "告他", "被告", "訴訟", "律師", "法院",
                             "契約", "合約", "租約", "押金", "房東", "房客", "離婚", "贍養", "撫養", "監護", "遺產", "繼承", "遺囑", "勞基法", "資遣",
                             "加班費", "勞資", "工資", "車禍", "肇事", "賠償", "詐騙", "罪", "刑法", "民法", "著作權", "侵權", "法條", "誹謗", "妨害",
                             "存證信函", "調解", "上訴", "緩刑", "保險理賠", "消保", "退貨", "定型化契約", "lawyer", "legal", "illegal", "lawsuit", "abogado", "avvocato"]

    static func isLegal(_ q: String) -> Bool {
        let l = q.lowercased()
        return legalWords.contains { l.contains($0) }
    }

    static func isHealth(_ q: String) -> Bool {
        let l = q.lowercased()
        return healthWords.contains { l.contains($0) }
    }

    /// 口語、簡稱 → 正式名稱（兩個都拿去查）
    static let synonyms: [String: String] = [
        "甲減": "甲狀腺機能低下症", "甲低": "甲狀腺機能低下症", "甲狀腺功能減退": "甲狀腺機能低下症", "甲狀腺功能低下": "甲狀腺機能低下症",
        "甲亢": "甲狀腺機能亢進症", "甲狀腺功能亢進": "甲狀腺機能亢進症", "橋本": "橋本氏甲狀腺炎", "三高": "高血壓 高血糖 高血脂",
        "心梗": "心肌梗塞", "腦梗": "腦梗塞", "胃食道逆流": "胃食道逆流症", "新冠": "COVID-19", "老年癡呆": "失智症", "老人癡呆": "失智症",
        "婦科": "婦科疾病", "大姨媽": "月經", "姨媽痛": "經痛", "高尿酸": "高尿酸血症", "脂肪肝": "脂肪肝", "多囊": "多囊性卵巢症候群",
    ]

    static func canonical(_ core: String) -> String? {
        for (k, v) in synonyms.sorted(by: { $0.key.count > $1.key.count }) where core.contains(k) && !core.contains(v) {
            return core.replacingOccurrences(of: k, with: v)
        }
        return nil
    }

    static let medicalSites = ["mohw.gov.tw", "hpa.gov.tw", "cdc.gov.tw", "nhi.gov.tw", "fda.gov.tw", "cgmh.org.tw", "ntuh.gov.tw", "vghtpe.gov.tw",
                               "vghtc.gov.tw", "vghks.gov.tw", "mmh.org.tw", "ndmctsgh.edu.tw", "kmuh.org.tw", "cmuh.org.tw", "tzuchi", "chimei.org.tw",
                               "skh.org.tw", "wanfang.gov.tw", "tmuh.org.tw", "ktgh.com.tw", "edah.org.tw", "hosp", "hospital", ".org.tw", "wikipedia.org",
                               "mayoclinic.org", "nhs.uk", "msdmanuals.com", "medlineplus.gov", "who.int", "commonhealth.com.tw", "heho.com.tw",
                               "health.udn.com", "top1health.com", "edh.tw", "kingnet.com.tw", "hellodoctor", "helloyishi"]

    static func strategy(_ kind: WebAgent.Kind, question: String) -> Strategy {
        switch kind {
        case .legal:
            return Strategy(angles: [
                Angle(title: "相關法律規定", suffix: " 法律規定", cues: ["法", "第", "條", "規定", "依據", "依照", "明定", "規範"]),
                Angle(title: "會有什麼後果", suffix: " 罰則", cues: ["罰", "處", "有期徒刑", "拘役", "罰金", "罰鍰", "賠償", "責任", "無效"]),
                Angle(title: "可以怎麼做", suffix: " 程序 流程", cues: ["申請", "提出", "程序", "流程", "向", "法院", "報案", "存證信函", "調解", "申訴", "蒐證", "證據"]),
                Angle(title: "要注意的權益", suffix: " 權益 注意事項", cues: ["權益", "權利", "注意", "期限", "時效", "保留", "證據", "避免"]),
            ], trusted: ["law.moj.gov.tw", "judicial.gov.tw", "moj.gov.tw", "mol.gov.tw", "laf.org.tw", "lawbank.com.tw", "legis-pedia.com",
                         "cpc.ey.gov.tw", "npa.gov.tw", ".gov.tw", "lawyer", "law"],
            note: "⚠️ 以上是法律資料整理，只能當參考。每個案子的事實、證據和時間點都不一樣，結果可能不同；牽涉到自己的權益，請找律師確認。沒有預算可以問「法律扶助基金會」（電話 412-8518，手機請加 02），或各地法院、區公所的免費法律諮詢。")
        case .health:
            let dept = question.contains("甲狀腺") || question.contains("甲減") || question.contains("甲亢") || question.contains("橋本")
                || question.contains("糖尿") || question.contains("荷爾蒙") ? "新陳代謝科（內分泌科）" : "家醫科或相關專科"
            return Strategy(angles: [
                Angle(title: "是什麼", suffix: " 是什麼", cues: ["是一種", "是指", "指的是", "稱為", "又稱", "疾病", "狀態", "功能"]),
                Angle(title: "常見症狀", suffix: " 症狀", cues: ["症狀", "表現", "出現", "感到", "容易", "怕冷", "疲倦", "疲勞", "水腫", "體重", "掉髮", "心悸", "便秘"]),
                Angle(title: "原因", suffix: " 原因", cues: ["原因", "導致", "引起", "造成", "因為", "缺乏", "免疫", "遺傳", "風險"]),
                Angle(title: "治療", suffix: " 治療", cues: ["治療", "藥物", "服用", "補充", "手術", "控制", "追蹤", "劑量", "抽血"]),
                Angle(title: "飲食與日常照顧", suffix: " 飲食 注意事項", cues: ["飲食", "避免", "注意", "多吃", "少吃", "攝取", "運動", "作息", "碘"]),
            ], trusted: medicalSites,
            note: "⚠️ 以上是網路資料整理，只能當參考，不能取代醫師的診斷。症狀持續或變嚴重，請到\(dept)檢查（通常會抽血驗相關指數）。")
        case .define:
            return Strategy(angles: [
                Angle(title: "是什麼", suffix: " 是什麼", cues: ["是一種", "是指", "指的是", "稱為", "又稱", "定義"]),
                Angle(title: "特點與例子", suffix: " 特點", cues: ["特點", "特色", "特徵", "包括", "例如", "優點", "缺點"]),
            ], trusted: ["wikipedia.org", ".gov.tw", ".edu.tw"], note: nil)
        case .method:
            return Strategy(angles: [
                Angle(title: "步驟", suffix: " 步驟", cues: ["步驟", "首先", "然後", "接著", "最後", "先", "再", "加入", "放入", "分鐘"]),
                Angle(title: "注意事項", suffix: " 注意事項", cues: ["注意", "避免", "小心", "不要", "記得", "秘訣", "技巧"]),
            ], trusted: [".gov.tw", "wikipedia.org"], note: nil)
        case .reason:
            return Strategy(angles: [
                Angle(title: "原因", suffix: " 原因", cues: ["原因", "因為", "導致", "造成", "由於", "所以"]),
                Angle(title: "影響", suffix: " 影響", cues: ["影響", "結果", "後果", "使得"]),
            ], trusted: ["wikipedia.org", ".gov.tw", ".edu.tw"], note: nil)
        case .compare:
            return Strategy(angles: [
                Angle(title: "差別", suffix: " 差別", cues: ["差別", "差異", "不同", "區別", "而", "則", "相比"]),
                Angle(title: "怎麼選", suffix: " 優缺點", cues: ["優點", "缺點", "適合", "建議", "選擇"]),
            ], trusted: ["wikipedia.org"], note: nil)
        case .person:
            return Strategy(angles: [
                Angle(title: "簡介", suffix: " 簡介", cues: ["出生", "是", "擔任", "現任", "曾任", "畢業"]),
                Angle(title: "最近", suffix: " 最新", cues: ["最近", "日前", "今年", "宣布", "表示"]),
            ], trusted: ["wikipedia.org", ".gov.tw"], note: nil)
        case .recommend:
            return Strategy(angles: [
                Angle(title: "推薦", suffix: " 推薦", cues: ["推薦", "必", "人氣", "排名", "首選", "熱門"]),
                Angle(title: "評價", suffix: " 評價", cues: ["評價", "好評", "缺點", "心得", "價格"]),
            ], trusted: [], note: nil)
        default:
            return Strategy(angles: [], trusted: [], note: nil)
        }
    }

    // MARK: - 簡體 → 繁體（常用字；網路上的簡體結果轉成繁體再給你看）

    static let s2t: [Character: Character] = {
        let s = "这们说为发过时会国实产医疗药证减状腺们个来对没么还进经动种现应该当内关觉让从体长问题变东车门买卖钱见开么样后学习写书读听说话语讯认识记设计网络电脑视频图书馆营养饮食热量维生钙铁锌补充检查验血压压糖尿病癌肿瘤炎症疼痛头脑颈腰背脚胀肠胃肝肾脏肺心脏脉脑湿疹荨麻疹过敏紧张焦虑忧郁睡眠质量调节激荷尔蒙减退亢进桥险严重轻微适宜饮这样处办务员导师级据带务条环节总结选择优缺点区别差异历史传统专业标准规则价格费用优惠质量种类广东岛湾北门诊挂号医院诊所护理药师处方剂量疗程复诊术后并发恢复预防预约缓解减轻显著别让给还没过产妇孕婴儿岁龄问题该选择听觉满许级态区县乡镇边远迁运输线铁飞机场馆园灯烟杂报纸间隐私权网站页链点击载简繁体湾"
        let t = "這們說為發過時會國實產醫療藥證減狀腺們個來對沒麼還進經動種現應該當內關覺讓從體長問題變東車門買賣錢見開麼樣後學習寫書讀聽說話語訊認識記設計網絡電腦視頻圖書館營養飲食熱量維生鈣鐵鋅補充檢查驗血壓壓糖尿病癌腫瘤炎症疼痛頭腦頸腰背腳脹腸胃肝腎臟肺心臟脈腦濕疹蕁麻疹過敏緊張焦慮憂鬱睡眠質量調節激荷爾蒙減退亢進橋險嚴重輕微適宜飲這樣處辦務員導師級據帶務條環節總結選擇優缺點區別差異歷史傳統專業標準規則價格費用優惠質量種類廣東島灣北門診掛號醫院診所護理藥師處方劑量療程復診術後並發恢復預防預約緩解減輕顯著別讓給還沒過產婦孕嬰兒歲齡問題該選擇聽覺滿許級態區縣鄉鎮邊遠遷運輸線鐵飛機場館園燈煙雜報紙間隱私權網站頁鏈點擊載簡繁體灣"
        var m: [Character: Character] = [:]
        for (a, b) in zip(s, t) where a != b { m[a] = b }
        return m
    }()

    static func toTraditional(_ s: String) -> String {
        // 系統內建的完整簡轉繁（ICU Hans-Hant）；不支援時才用上面的常用字表
        if let t = s.applyingTransform(StringTransform(rawValue: "Hans-Hant"), reverse: false) { return t }
        return String(s.map { s2t[$0] ?? $0 })
    }
}
