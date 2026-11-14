import Foundation

/// 世界各國的名字（台灣用語），加上大陸、香港的寫法和英文名。
/// 用途：問「哪些國家」時，網頁上抓到的名單只留真的是國家（地區）的項目——
/// 「3天前」「請選擇護照」「電子旅行授權·6」這種網頁上的按鈕、日期都拿掉；「新西蘭」「Thailand」換成「紐西蘭」「泰國」
public enum Countries {
    /// 台灣用語的國名（含常被列在一起的地區）
    public static let names: [String] = """
    台灣 中國 日本 韓國 南韓 北韓 蒙古 香港 澳門 越南 寮國 柬埔寨 泰國 緬甸 馬來西亞 新加坡 印尼 菲律賓 汶萊 東帝汶 \
    印度 巴基斯坦 孟加拉 斯里蘭卡 尼泊爾 不丹 馬爾地夫 阿富汗 伊朗 伊拉克 敘利亞 約旦 黎巴嫩 以色列 巴勒斯坦 沙烏地阿拉伯 \
    阿拉伯聯合大公國 卡達 巴林 科威特 阿曼 葉門 土耳其 賽普勒斯 喬治亞 亞美尼亞 亞塞拜然 哈薩克 烏茲別克 吉爾吉斯 塔吉克 土庫曼 \
    英國 愛爾蘭 法國 德國 義大利 西班牙 葡萄牙 荷蘭 比利時 盧森堡 瑞士 奧地利 列支敦斯登 摩納哥 安道爾 聖馬利諾 梵蒂岡 馬爾他 \
    希臘 瑞典 挪威 芬蘭 丹麥 冰島 波蘭 捷克 斯洛伐克 匈牙利 羅馬尼亞 保加利亞 斯洛維尼亞 克羅埃西亞 塞爾維亞 波士尼亞與赫塞哥維納 \
    蒙特內哥羅 北馬其頓 阿爾巴尼亞 科索沃 愛沙尼亞 拉脫維亞 立陶宛 白俄羅斯 烏克蘭 摩爾多瓦 俄羅斯 \
    美國 加拿大 墨西哥 瓜地馬拉 貝里斯 宏都拉斯 薩爾瓦多 尼加拉瓜 哥斯大黎加 巴拿馬 古巴 牙買加 海地 多明尼加 巴哈馬 巴貝多 \
    千里達及托巴哥 格瑞那達 聖露西亞 聖文森及格瑞那丁 安地卡及巴布達 聖克里斯多福及尼維斯 多米尼克 \
    巴西 阿根廷 智利 秘魯 哥倫比亞 委內瑞拉 厄瓜多 玻利維亞 巴拉圭 烏拉圭 蓋亞那 蘇利南 \
    埃及 利比亞 突尼西亞 阿爾及利亞 摩洛哥 蘇丹 南蘇丹 衣索比亞 厄利垂亞 吉布地 索馬利亞 肯亞 烏干達 坦尚尼亞 盧安達 蒲隆地 \
    剛果 剛果民主共和國 加彭 喀麥隆 中非 查德 奈及利亞 尼日 馬利 布吉納法索 塞內加爾 甘比亞 幾內亞 幾內亞比索 獅子山 賴比瑞亞 \
    象牙海岸 迦納 多哥 貝南 茅利塔尼亞 維德角 赤道幾內亞 聖多美普林西比 安哥拉 尚比亞 辛巴威 馬拉威 莫三比克 馬達加斯加 \
    模里西斯 塞席爾 葛摩 納米比亞 波札那 南非 賴索托 史瓦帝尼 \
    澳洲 紐西蘭 巴布亞紐幾內亞 斐濟 索羅門群島 萬那杜 薩摩亞 東加 吐瓦魯 吉里巴斯 諾魯 帛琉 馬紹爾群島 密克羅尼西亞 紐埃 庫克群島
    """.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)

    /// 其他寫法 → 台灣用語
    public static let aliases: [String: String] = [
        "韓國": "韓國", "朝鮮": "北韓", "老撾": "寮國", "文萊": "汶萊", "馬爾代夫": "馬爾地夫", "沙特": "沙烏地阿拉伯", "沙特阿拉伯": "沙烏地阿拉伯",
        "沙地阿拉伯": "沙烏地阿拉伯", "阿聯酋": "阿拉伯聯合大公國", "阿拉伯聯合酋長國": "阿拉伯聯合大公國", "杜拜": "阿拉伯聯合大公國", "迪拜": "阿拉伯聯合大公國",
        "卡塔爾": "卡達", "也門": "葉門", "塞浦路斯": "賽普勒斯", "格魯吉亞": "喬治亞", "阿塞拜疆": "亞塞拜然", "哈薩克斯坦": "哈薩克",
        "烏茲別克斯坦": "烏茲別克", "吉爾吉斯斯坦": "吉爾吉斯", "塔吉克斯坦": "塔吉克", "土庫曼斯坦": "土庫曼", "意大利": "義大利",
        "列支敦士登": "列支敦斯登", "聖馬力諾": "聖馬利諾", "馬耳他": "馬爾他", "斯洛文尼亞": "斯洛維尼亞", "克羅地亞": "克羅埃西亞",
        "波黑": "波士尼亞與赫塞哥維納", "波斯尼亞和黑塞哥維那": "波士尼亞與赫塞哥維納", "黑山": "蒙特內哥羅", "馬其頓": "北馬其頓",
        "危地馬拉": "瓜地馬拉", "伯利茲": "貝里斯", "洪都拉斯": "宏都拉斯", "哥斯達黎加": "哥斯大黎加", "多米尼加": "多明尼加",
        "巴巴多斯": "巴貝多", "特立尼達和多巴哥": "千里達及托巴哥", "格林納達": "格瑞那達", "聖盧西亞": "聖露西亞",
        "安提瓜和巴布達": "安地卡及巴布達", "聖基茨和尼維斯": "聖克里斯多福及尼維斯", "厄瓜多爾": "厄瓜多", "圭亞那": "蓋亞那",
        "蘇里南": "蘇利南", "突尼斯": "突尼西亞", "埃塞俄比亞": "衣索比亞", "厄立特里亞": "厄利垂亞", "吉布提": "吉布地",
        "索馬里": "索馬利亞", "肯尼亞": "肯亞", "坦桑尼亞": "坦尚尼亞", "盧旺達": "盧安達", "布隆迪": "蒲隆地", "加蓬": "加彭",
        "乍得": "查德", "尼日利亞": "奈及利亞", "尼日爾": "尼日", "馬里": "馬利", "布基納法索": "布吉納法索", "岡比亞": "甘比亞",
        "塞拉利昂": "獅子山", "利比里亞": "賴比瑞亞", "科特迪瓦": "象牙海岸", "加納": "迦納", "貝寧": "貝南", "毛里塔尼亞": "茅利塔尼亞",
        "佛得角": "維德角", "贊比亞": "尚比亞", "津巴布韋": "辛巴威", "馬拉維": "馬拉威", "莫桑比克": "莫三比克", "毛里求斯": "模里西斯",
        "塞舌爾": "塞席爾", "科摩羅": "葛摩", "博茨瓦納": "波札那", "萊索托": "賴索托", "斯威士蘭": "史瓦帝尼", "澳大利亞": "澳洲",
        "新西蘭": "紐西蘭", "巴布亞新幾內亞": "巴布亞紐幾內亞", "所羅門群島": "索羅門群島", "瓦努阿圖": "萬那杜", "湯加": "東加",
        "圖瓦盧": "吐瓦魯", "基里巴斯": "吉里巴斯", "瑙魯": "諾魯", "帕勞": "帛琉", "大韓民國": "韓國", "中華人民共和國": "中國",
        "美利堅合眾國": "美國", "英格蘭": "英國", "聯合王國": "英國", "俄國": "俄羅斯", "紐澳": "紐西蘭", "捷克共和國": "捷克",
        "斯里蘭卡": "斯里蘭卡", "孟加拉國": "孟加拉", "柬埔寨王國": "柬埔寨", "泰王國": "泰國", "剛果金": "剛果民主共和國", "剛果布": "剛果",
        "中非共和國": "中非", "俄羅斯聯邦": "俄羅斯", "大不列顛及北愛爾蘭聯合王國": "英國", "大不列顛": "英國", "法蘭西": "法國", "法蘭西共和國": "法國", "法蘭西第五共和國": "法國", "美利堅": "美國", "俄羅斯聯邦共和國": "俄羅斯",
        "德意志聯邦共和國": "德國", "日本國": "日本", "大韓民國國": "韓國", "南朝鮮": "韓國", "北朝鮮": "北韓", "朝鮮民主主義人民共和國": "北韓",
        "印度尼西亞": "印尼", "紐埃": "紐埃", "庫克群島": "庫克群島", "多米尼克國": "多米尼克", "汶萊達魯薩蘭國": "汶萊", "中華民國": "台灣", "台灣地區": "台灣", "中國香港": "香港", "中國澳門": "澳門", "中國台灣": "台灣", "荷蘭王國": "荷蘭", "比利時王國": "比利時", "南非共和國": "南非", "聖多美和普林西比": "聖多美普林西比", "東帝汶民主共和國": "東帝汶",
    ]

    static let english: [String: String] = [
        "taiwan": "台灣", "china": "中國", "japan": "日本", "korea": "韓國", "south korea": "韓國", "mongolia": "蒙古", "hong kong": "香港",
        "macau": "澳門", "macao": "澳門", "vietnam": "越南", "laos": "寮國", "cambodia": "柬埔寨", "thailand": "泰國", "myanmar": "緬甸",
        "malaysia": "馬來西亞", "singapore": "新加坡", "indonesia": "印尼", "philippines": "菲律賓", "brunei": "汶萊", "timor-leste": "東帝汶",
        "india": "印度", "pakistan": "巴基斯坦", "bangladesh": "孟加拉", "sri lanka": "斯里蘭卡", "nepal": "尼泊爾", "bhutan": "不丹",
        "maldives": "馬爾地夫", "iran": "伊朗", "iraq": "伊拉克", "jordan": "約旦", "lebanon": "黎巴嫩", "israel": "以色列",
        "saudi arabia": "沙烏地阿拉伯", "uae": "阿拉伯聯合大公國", "united arab emirates": "阿拉伯聯合大公國", "qatar": "卡達", "bahrain": "巴林",
        "kuwait": "科威特", "oman": "阿曼", "yemen": "葉門", "turkey": "土耳其", "türkiye": "土耳其", "georgia": "喬治亞", "armenia": "亞美尼亞",
        "azerbaijan": "亞塞拜然", "kazakhstan": "哈薩克", "uzbekistan": "烏茲別克", "kyrgyzstan": "吉爾吉斯", "tajikistan": "塔吉克",
        "uk": "英國", "united kingdom": "英國", "ireland": "愛爾蘭", "france": "法國", "germany": "德國", "italy": "義大利", "spain": "西班牙",
        "portugal": "葡萄牙", "netherlands": "荷蘭", "belgium": "比利時", "switzerland": "瑞士", "austria": "奧地利", "greece": "希臘",
        "sweden": "瑞典", "norway": "挪威", "finland": "芬蘭", "denmark": "丹麥", "iceland": "冰島", "poland": "波蘭", "russia": "俄羅斯",
        "serbia": "塞爾維亞", "belarus": "白俄羅斯", "usa": "美國", "united states": "美國", "canada": "加拿大", "mexico": "墨西哥",
        "brazil": "巴西", "argentina": "阿根廷", "chile": "智利", "peru": "秘魯", "egypt": "埃及", "morocco": "摩洛哥", "kenya": "肯亞",
        "south africa": "南非", "australia": "澳洲", "new zealand": "紐西蘭", "fiji": "斐濟", "mauritius": "模里西斯", "seychelles": "塞席爾",
        "ecuador": "厄瓜多", "barbados": "巴貝多", "bahamas": "巴哈馬", "grenada": "格瑞那達", "dominica": "多米尼克", "samoa": "薩摩亞",
        "tonga": "東加", "vanuatu": "萬那杜", "suriname": "蘇利南", "bosnia and herzegovina": "波士尼亞與赫塞哥維納", "albania": "阿爾巴尼亞",
        "montenegro": "蒙特內哥羅", "north macedonia": "北馬其頓", "tunisia": "突尼西亞", "madagascar": "馬達加斯加", "ethiopia": "衣索比亞",
    ]

    static let set = Set(names)

    /// 一個項目是不是國家（地區）：是的話回傳台灣用語的名字（「新西蘭 New Zealand」→ 紐西蘭）
    public static func canonical(_ raw: String) -> String? {
        var s = raw.replacingOccurrences(of: #"[（(][^）)]*[）)]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "•·-–*：:")))
        // 「亞美尼亞 Armenia」：中文名後面跟英文名
        // 國旗表情（🇹🇿）、符號拿掉，只留中文字
        let cjk = String(s.unicodeScalars.filter { $0.properties.isIdeographic || $0 == "·" || $0 == "・" }.map(Character.init))
            .replacingOccurrences(of: "·", with: "").replacingOccurrences(of: "・", with: "")
        if !cjk.isEmpty { s = cjk.trimmingCharacters(in: .whitespaces) }
        else if let e = english[s.lowercased().trimmingCharacters(in: .whitespaces)] { return e }
        s = s.replacingOccurrences(of: "臺", with: "台")
        if set.contains(s) { return s }
        if let a = aliases[s] { return a }
        // 「泰國（落地簽）」已經去掉括號；「日本國」「越南社會主義共和國」這種正式名稱
        for suffix in ["共和國", "王國", "國", "聯邦", "試行", "暫停", "新增", "最新", "延長", "入境", "免簽", "落地簽", "電子簽"] where s.hasSuffix(suffix) && s.count > suffix.count + 1 {
            let b = String(s.dropLast(suffix.count))
            if set.contains(b) { return b }
            if let a = aliases[b] { return a }
        }
        return nil
    }

    /// 名單裡的分類標題（「免簽」「落地簽」「電子簽」「亞洲」「歐洲」）：拿來分組，不當項目
    public static func heading(_ raw: String) -> String? {
        let s = raw.replacingOccurrences(of: #"[（(][^）)]*[）)]|[·•\d\s:：、.．]|^[一二三四五六七八九十]+"#, with: "", options: .regularExpression)
            .unicodeScalars.filter { $0.properties.isIdeographic || $0.isASCII }.map(String.init).joined()
        if let v = visaLabel(s) { return v }
        let regions = ["亞洲", "歐洲", "非洲", "美洲", "北美洲", "南美洲", "中美洲", "大洋洲", "中東", "東南亞", "東北亞", "南亞", "中亞", "加勒比海", "加勒比"]
        if regions.contains(s) { return s }
        return nil
    }

    /// 「一、互免簽證」「二、單方面免簽」「落地簽證國家」「電子簽」→ 統一的分類名稱（太長的是一句話，不是標題）
    static func visaLabel(_ s: String) -> String? {
        guard s.count <= 12, !s.contains("。") else { return nil }
        if s.contains("互免") { return "互免簽證" }
        if s.contains("落地") { return "落地簽" }
        if s.contains("電子旅行授權") || s.contains("電子旅遊許可") || s.uppercased().hasPrefix("ETA") { return "電子旅行授權" }
        if s.contains("電子簽") { return "電子簽" }
        if s.contains("免簽") { return "免簽" }
        return nil
    }

    /// 簽證名單的網頁常分成好幾段（互免簽證／單方面免簽／落地簽／電子簽），每段再照洲分成好幾張小表：
    /// 照網頁的順序走，每個國名歸到它上面最近的分類標題底下（「亞洲」「非洲」這種洲名不換分類）
    public static func sectioned(_ pages: [(text: String, host: String)]) -> (items: [String], host: String)? {
        var best: (items: [String], host: String, n: Int)?
        for p in pages {
            var items: [String] = [], label: String?, n = 0, labels = Set<String>()
            for raw in p.text.components(separatedBy: "\n") {
                let line = raw.trimmingCharacters(in: .whitespaces)
                guard !line.isEmpty else { continue }
                let first = line.components(separatedBy: "｜").map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? line
                // 只有簽證種類換分類；「🌏 亞洲」這種洲名只是網頁上的小標，不換
                let plainHead = first.replacingOccurrences(of: #"[（(][^）)]*[）)]|[·•\d\s:：、.．]|^[一二三四五六七八九十]+"#, with: "", options: .regularExpression)
                    .unicodeScalars.filter { $0.properties.isIdeographic || $0.isASCII }.map(String.init).joined()
                if let h = visaLabel(plainHead), first.count <= 14 {
                    if h != label { label = h; items.append(h); labels.insert(h) }
                    continue
                }
                // 一行一個國名，或表格的第一欄（「🇹🇭 泰國 ｜ 30 天」）
                if label != nil, first.count <= 20, canonical(first) != nil { items.append(first); n += 1 }
            }
            if n >= 10, labels.count >= 2, n > (best?.n ?? 0) { best = (items, p.host, n) }
        }
        return best.map { ($0.items, $0.host) }
    }

    /// 問的是國家（地區）的名單嗎
    public static func isCountryNoun(_ noun: String) -> Bool {
        ["國家", "國", "國家和地區", "國家或地區", "國家地區", "地區", "目的地", "成員國", "會員國", "常任理事國", "已開發國家", "發達國家"].contains(noun)
            || noun.hasSuffix("國家")
    }

    /// 把抓到的名單整理成國家：只留國家，標題拿來分組，同一個國家不重複
    public static func tidy(_ items: [String]) -> (groups: [(label: String, names: [String])], dropped: Int) {
        var groups: [(label: String, names: [String])] = [("", [])]
        var seen = Set<String>()
        var dropped = 0
        for it in items {
            if let h = heading(it) {
                if groups[groups.count - 1].names.isEmpty { groups[groups.count - 1].label = h } else { groups.append((h, [])) }
                continue
            }
            guard let c = canonical(it) else { dropped += 1; continue }
            if seen.insert(c).inserted { groups[groups.count - 1].names.append(c) }
        }
        groups = groups.filter { !$0.names.isEmpty }
        // 同一個標題出現兩次（同一頁上下各列一次）：合併
        var merged: [(label: String, names: [String])] = []
        for g in groups {
            if let i = merged.firstIndex(where: { $0.label == g.label }) { merged[i].names += g.names } else { merged.append(g) }
        }
        return (merged, dropped)
    }

    /// 長名單排整齊：每行最多 n 個，不要一大串擠在一起
    public static func lines(_ names: [String], per n: Int = 8) -> String {
        stride(from: 0, to: names.count, by: n).map { names[$0..<min($0 + n, names.count)].joined(separator: "、") }.joined(separator: "\n")
    }
}
