# -*- coding: utf-8 -*-
"""中文理解訓練題：50,000 題，每題附標準答案——
   route：web（上網查）／fortune（用命盤算）／feeling（說心情，要安慰）／chat（打招呼、問 NineSun 自己）
   want ：web 題要什麼樣的答案（number、person、place、time、definition、reason、list、compare、steps、open）
   subject：要查的主題（理解後的關鍵詞要包含它）
用法：python3 ai/understanding/gen.py ios/EchoCore/Tests/EchoCoreTests/Fixtures/understanding_questions.json"""
import json
import random
import sys

R = random.Random(20261023)

HEIGHT = ["台北101", "玉山", "聖母峰", "富士山", "艾菲爾鐵塔", "杜拜塔", "東京鐵塔", "阿里山", "自由女神像", "帝國大廈", "合歡山", "雪山",
          "吉力馬札羅山", "白朗峰", "晴空塔", "上海中心大廈", "比薩斜塔", "大霸尖山", "高雄85大樓", "長頸鹿"]
DIST = ["地球到月亮", "太陽到地球", "台北到高雄", "台北到台中", "地球到火星", "東京到大阪", "台灣到日本", "北京到上海", "倫敦到巴黎", "台北到花蓮"]
WEIGHT = ["藍鯨", "大象", "地球", "月球", "北極熊", "長頸鹿", "非洲象", "河馬", "犀牛", "鯨鯊"]
LONG = ["長城", "馬拉松", "黃河", "長江", "尼羅河", "亞馬遜河", "淡水河", "濁水溪", "蘇伊士運河", "台灣高鐵"]
POP = ["台灣", "日本", "美國", "中國", "印度", "台北", "東京", "香港", "新加坡", "韓國", "法國", "德國", "英國", "澳洲", "加拿大", "越南", "泰國", "印尼", "高雄", "紐約"]
COUNT = [("美國", "州"), ("加拿大", "省"), ("台灣", "縣市"), ("日本", "縣"), ("太陽系", "行星"), ("歐洲", "國家"), ("中國", "省"), ("非洲", "國家"),
         ("東南亞", "國家"), ("地球", "大洲"), ("聯合國", "會員國"), ("德國", "州"), ("澳洲", "州"), ("台北", "行政區"), ("南美洲", "國家")]
COUNT_MEASURE = [("人體", "幾塊骨頭"), ("一年", "幾天"), ("鋼琴", "幾個鍵"), ("一天", "幾個小時"), ("人", "幾顆牙齒"), ("貓", "幾條命"), ("蜘蛛", "幾隻腳"), ("彩虹", "幾種顏色")]
INVENT = ["電話", "電燈", "飛機", "汽車", "網路", "印刷術", "火藥", "指南針", "電腦", "收音機", "電視", "青黴素", "蒸汽機", "疫苗", "鉛筆", "全球資訊網",
          "微波爐", "相機", "冷氣", "原子筆"]
CAPITAL = ["日本", "法國", "澳洲", "加拿大", "巴西", "德國", "義大利", "西班牙", "韓國", "泰國", "越南", "土耳其", "埃及", "印度", "俄羅斯", "英國", "美國",
           "紐西蘭", "阿根廷", "瑞士", "荷蘭", "瑞典", "挪威", "芬蘭", "波蘭", "墨西哥", "南非", "肯亞", "菲律賓", "馬來西亞"]
WHERE = ["羅浮宮", "馬丘比丘", "吳哥窟", "大堡礁", "富士山", "太魯閣", "日月潭", "聖托里尼", "撒哈拉沙漠", "死海", "百慕達三角", "復活節島", "金閣寺", "威尼斯"]
EVENT = ["第一次世界大戰", "第二次世界大戰", "法國大革命", "工業革命", "文藝復興", "921大地震", "鐵達尼號沉沒", "人類登月", "柏林圍牆倒塌", "台灣解嚴",
         "辛亥革命", "美國獨立", "東京奧運", "iPhone推出", "九一一事件", "SARS爆發", "唐朝滅亡", "秦始皇統一中國"]
CONCEPT = ["通貨膨脹", "區塊鏈", "人工智慧", "黑洞", "光合作用", "複利", "ETF", "憂鬱症", "正念", "MBTI", "存在主義", "相對論", "量子糾纏", "元宇宙", "碳中和",
           "新陳代謝", "免疫力", "演算法", "雲端運算", "機器學習", "GDP", "斷捨離", "極簡主義", "斯多葛主義", "認知失調", "心流", "冒牌者症候群", "情緒勒索",
           "煤氣燈效應", "沉沒成本", "蝴蝶效應", "墨菲定律", "馬斯洛需求層次", "安慰劑效應", "達克效應", "共享經濟", "比特幣", "基因編輯", "溫室效應", "聖嬰現象"]
REASON = [("天空", "是藍色的"), ("海水", "是鹹的"), ("人", "會打哈欠"), ("人", "會做夢"), ("地球", "會有四季"), ("葉子", "會變黃"), ("冰", "會浮在水上"),
          ("飛機", "會飛"), ("吃辣", "會流汗"), ("人", "會近視"), ("星星", "會閃爍"), ("洋蔥", "會讓人流眼淚"), ("人", "會打嗝"), ("貓", "喜歡紙箱"),
          ("狗", "會搖尾巴"), ("月亮", "會發光"), ("彩虹", "是彎的"), ("人", "會起雞皮疙瘩"), ("咖啡", "會提神"), ("夕陽", "是紅色的"),
          ("感冒", "會發燒"), ("貓", "會發出呼嚕聲"), ("人", "會老"), ("天空", "會打雷"), ("鳥", "會飛"), ("魚", "不會淹死"), ("蚊子", "喜歡叮人"),
          ("香蕉", "會變黑"), ("人", "會怕冷"), ("頭髮", "會變白")]
LISTS = [("日本", "縣"), ("北歐", "國家"), ("東南亞", "國家"), ("太陽系", "行星"), ("台灣", "國家公園"), ("台灣", "夜市"), ("歐洲", "國家"), ("美國", "州"),
         ("加拿大", "省"), ("中國", "省"), ("台北", "景點"), ("莎士比亞", "作品"), ("村上春樹", "作品"), ("貝多芬", "代表作"), ("非洲", "國家"),
         ("台灣", "原住民族"), ("日本", "傳統節日"), ("義大利", "城市"), ("南美洲", "國家"), ("台灣", "離島")]
COMPARE = [("iPhone", "安卓"), ("咖啡", "茶"), ("租房", "買房"), ("貓", "狗"), ("跑步", "游泳"), ("Mac", "Windows"), ("台北", "台中"), ("電動車", "油車"),
           ("定存", "ETF"), ("日本", "韓國"), ("中醫", "西醫"), ("Kindle", "紙本書"), ("PS5", "Switch"), ("瑜珈", "皮拉提斯"), ("Netflix", "Disney+")]
TASK = ["存錢", "減肥", "早起", "讀書", "背單字", "學英文", "交朋友", "提升專注力", "戒掉滑手機", "跟爸媽溝通", "準備考試", "煮白飯", "煮綠豆湯", "煎牛排",
        "泡咖啡", "挑西瓜", "去除衣服上的油漬", "寫履歷", "做簡報", "跟喜歡的人告白", "讓自己更自信", "克服拖延", "緩解焦慮", "改善失眠", "提高記憶力",
        "開始理財", "練出腹肌", "減壓", "學游泳", "養成運動習慣", "說服別人", "跟同事相處", "存第一桶金", "提升口才", "學會時間管理"]
PROBLEM = ["失眠", "喉嚨痛", "頭痛", "感冒", "被主管罵", "跟朋友吵架", "手機沒電很快", "電腦很慢", "護照遺失", "被詐騙", "喜歡一個人", "考試考不好",
           "被排擠", "存不了錢", "胃痛", "中暑", "落枕", "信用卡被盜刷", "老闆不給我加薪", "打嗝停不下來", "被蚊子咬很癢", "流鼻血", "WiFi很慢", "鑰匙丟了"]
ATTEND = ["面試", "開車", "出國", "登山", "健身", "租房", "買房", "簽約", "搬家", "第一次約會", "露營", "考駕照", "養貓", "坐飛機", "打疫苗"]
BENEFIT = ["冥想", "喝咖啡", "運動", "早起", "閱讀", "喝水", "吃早餐", "曬太陽", "睡午覺", "學外語", "散步", "喝綠茶", "游泳", "寫日記", "斷食"]
# 作品：書名裡常有「煩惱」「悲傷」「孤獨」這類情緒字——是名稱，不是心情
BOOK = ["哈利波特", "紅樓夢", "西遊記", "三國演義", "小王子", "百年孤寂", "1984", "少年維特的煩惱", "人間失格", "挪威的森林", "雪國", "金閣寺", "老人與海",
        "傲慢與偏見", "悲慘世界", "罪與罰", "戰爭與和平", "解憂雜貨店", "被討厭的勇氣", "原子習慣", "憤怒的葡萄", "傷心咖啡店之歌", "孤獨六講", "快樂王子",
        "憂鬱的熱帶", "寂寞的十七歲", "恐懼與戰慄", "哭泣的樹", "失落的一角", "嫌疑犯X的獻身"]
FILM = ["悲傷逆流成河", "鐵達尼號", "星際效應", "寄生上流", "你的名字", "神隱少女", "哭泣的駱駝", "腦筋急轉彎", "孤獨的美食家", "進擊的巨人", "鬼滅之刃",
        "灌籃高手", "海角七號", "那些年，我們一起追的女孩", "憤怒的公牛", "寂寞拍賣師", "快樂的抉擇", "煩惱的少女"]
TIMES = ["今天", "今晚", "明天", "這週", "這個月", "下個月", "今年", "明年", "2027年"]
TOPICS = ["感情", "事業", "財", "桃花", "健康", "學業", "人際", "工作"]
EMO = ["煩", "累", "難過", "焦慮", "孤單", "寂寞", "沮喪", "傷心", "生氣", "失落", "迷茫", "煩惱", "害怕", "緊張", "低落", "空虛", "委屈", "崩潰"]
CHAT = ["你好", "早安", "午安", "晚安", "嗨", "哈囉", "你是誰", "你叫什麼名字", "謝謝你", "謝啦", "你好可愛", "你會做什麼", "你幾歲", "你在嗎", "掰掰"]


def item(q, route, want="", subject="", kind=""):
    return {"q": q, "route": route, "want": want, "subject": subject, "kind": kind}


def web_items():
    out = []
    for x in HEIGHT:
        for t in ["{x}有多高", "{x}多高", "{x}的高度是多少", "{x}大概有多高"]:
            out.append(item(t.format(x=x), "web", "number", x, "height"))
    for x in DIST:
        for t in ["{x}有多遠", "{x}多遠", "{x}的距離是多少", "{x}大概有多遠"]:
            out.append(item(t.format(x=x), "web", "number", x, "distance"))
    for x in WEIGHT:
        for t in ["{x}有多重", "{x}多重", "{x}大概有多重", "一隻{x}有多重" if x not in ("地球", "月球") else "{x}有多重"]:
            out.append(item(t.format(x=x), "web", "number", x, "weight"))
    for x in LONG:
        for t in ["{x}有多長", "{x}多長", "{x}的長度是多少"]:
            out.append(item(t.format(x=x), "web", "number", x, "length"))
    for x in POP:
        for t in ["{x}有多少人口", "{x}人口有多少", "{x}現在有多少人", "{x}的人口是多少"]:
            out.append(item(t.format(x=x), "web", "number", x, "population"))
    for x, n in COUNT:
        for t in ["{x}有幾個{n}", "{x}有多少個{n}", "{x}一共有幾個{n}", "{x}總共有多少{n}"]:
            out.append(item(t.format(x=x, n=n), "web", "number", x, "count"))
    for x, n in COUNT_MEASURE:
        for t in ["{x}有{n}", "{x}總共有{n}"]:
            out.append(item(t.format(x=x, n=n), "web", "number", x, "measure"))
    for x in INVENT:
        for t in ["誰發明了{x}", "{x}是誰發明的", "發明{x}的人是誰"]:
            out.append(item(t.format(x=x), "web", "person", x, "inventor"))
    for x in CAPITAL:
        for t in ["{x}的首都是哪裡", "{x}的首都在哪", "{x}首都是哪個城市"]:
            out.append(item(t.format(x=x), "web", "place", x, "capital"))
    for x in WHERE:
        for t in ["{x}在哪裡", "{x}在哪個國家", "{x}位於哪裡"]:
            out.append(item(t.format(x=x), "web", "place", x, "where"))
    for x in EVENT:
        for t in ["{x}是哪一年", "{x}是什麼時候", "{x}發生在哪一年", "{x}是幾年發生的"]:
            out.append(item(t.format(x=x), "web", "time", x, "when"))
    for x in CONCEPT:
        for t in ["什麼是{x}", "{x}是什麼", "{x}是什麼意思", "解釋一下{x}", "{x}指的是什麼"]:
            out.append(item(t.format(x=x), "web", "definition", x, "define"))
    for a, b in REASON:
        s = a + b
        for t in ["為什麼{s}", "{a}為什麼{b}", "為何{s}", "{s}的原因是什麼", "{s}是為什麼"]:
            out.append(item(t.format(s=s, a=a, b=b), "web", "reason", b.lstrip("會是"), "reason"))
    for x, n in LISTS:
        for t in ["{x}有哪些{n}", "{x}有什麼{n}", "{x}的{n}有哪些", "列出{x}的{n}"]:
            out.append(item(t.format(x=x, n=n), "web", "list", x, "list"))
    for a, b in COMPARE:
        for t in ["{a}和{b}哪個好", "{a}跟{b}哪個比較好", "{a}還是{b}比較好", "{a}和{b}的差別", "{a}跟{b}有什麼不同"]:
            out.append(item(t.format(a=a, b=b), "web", "compare", a, "compare"))
    for x in TASK:
        for t in ["怎麼{x}", "要怎麼{x}", "如何{x}", "{x}該怎麼做", "{x}有什麼方法", "{x}的方法", "{x}有什麼技巧", "教我{x}", "我想{x}該怎麼做"]:
            # 做菜：主題是菜名（「煎牛排」查「牛排 做法」）
            subj = x[1:] if x[0] in "煮烤炒蒸泡滷煎燉" else x
            out.append(item(t.format(x=x), "web", "steps", subj, "howto"))
    for x in PROBLEM:
        for t in ["{x}怎麼辦", "{x}該怎麼辦", "{x}了怎麼辦", "如果{x}怎麼辦", "{x}要怎麼處理"]:
            q = t.format(x=x)
            if "了了" in q:
                continue
            out.append(item(q, "web", "steps", x, "problem"))
    for x in ATTEND:
        for t in ["{x}要注意什麼", "{x}有什麼要注意的", "{x}的注意事項", "{x}需要注意哪些"]:
            out.append(item(t.format(x=x), "web", "steps", x, "attention"))
    for x in BENEFIT:
        for t in ["{x}有什麼好處", "{x}的好處是什麼", "{x}有哪些好處"]:
            out.append(item(t.format(x=x), "web", "open", x, "benefit"))
    for x in BOOK:
        for t in ["{x}在講什麼", "{x}講了什麼", "{x}這本書講了什麼", "{x}這本書在講什麼", "《{x}》講什麼", "{x}的內容是什麼", "{x}這本書好看嗎"]:
            out.append(item(t.format(x=x), "web", "open", x, "book"))
        for t in ["{x}的作者是誰", "誰寫了{x}", "{x}是誰寫的"]:
            out.append(item(t.format(x=x), "web", "person", x, "author"))
    for x in FILM:
        for t in ["{x}在講什麼", "{x}這部電影在講什麼", "{x}的劇情是什麼", "{x}好看嗎", "{x}值得看嗎", "{x}講了什麼"]:
            out.append(item(t.format(x=x), "web", "open", x, "film"))
    return out


def local_items():
    out = []
    for t in TIMES:
        for tp in TOPICS:
            for tpl in ["我{t}的{tp}運如何", "{t}{tp}運怎麼樣", "我{t}{tp}運好嗎", "幫我看{t}的{tp}運", "{t}的{tp}運勢"]:
                out.append(item(tpl.format(t=t, tp=tp), "fortune", kind="fortune"))
        for tpl in ["我{t}的運勢如何", "{t}運勢", "幫我看看{t}的運氣", "{t}運氣好嗎", "我{t}運勢怎麼樣"]:
            out.append(item(tpl.format(t=t), "fortune", kind="fortune"))
    for q in ["我的命盤", "我的命宮在哪", "幫我做完整解讀", "我的大運是什麼", "我是第幾型", "我的九型人格", "我什麼時候會結婚", "我哪一年會升職",
              "我的八字", "我的紫微命盤", "幫我算命", "我的流年", "我今年適合換工作嗎", "我明年會有桃花嗎", "我什麼時候會有錢"]:
        out.append(item(q, "fortune", kind="fortune"))
    for e in EMO:
        for tpl in ["我好{e}", "最近好{e}", "我今天很{e}", "覺得好{e}", "我真的好{e}", "最近一直很{e}", "好{e}喔", "我{e}到睡不著"]:
            out.append(item(tpl.format(e=e), "feeling", kind="feeling"))
    for q in ["心情好差", "好想哭", "我被分手了好難過", "沒有人懂我", "我覺得好累好想放棄", "我失戀了", "我好想念奶奶", "工作壓力好大", "我覺得自己很沒用"]:
        out.append(item(q, "feeling", kind="feeling"))
    for q in CHAT:
        out.append(item(q, "chat", kind="chat"))
    return out


WRAP = ["請問{q}", "我想知道{q}", "你知道{q}嗎", "可以告訴我{q}嗎", "幫我查一下{q}", "{q}呢", "欸{q}", "想問一下{q}", "好奇{q}", "那{q}", "所以{q}", "{q}啊"]
END = ["？", "?", "", "", "。"]


LOCAL_WRAP = {"fortune": ["請問{q}", "幫我看一下{q}" if False else "幫我看{q}", "想知道{q}", "欸{q}", "那{q}", "可以幫我看{q}嗎", "{q}呢"],
              "feeling": ["唉，{q}", "{q}…", "嗚嗚{q}", "其實{q}", "說真的{q}", "{q}，怎麼辦", "今天{q}"],
              "chat": ["{q}～", "{q}!", "嘿{q}"]}


def vary(it):
    q = it["q"]
    if it["route"] == "web" and R.random() < 0.55:
        w = R.choice(WRAP)
        if not (w.endswith("嗎") and (q.endswith("嗎") or q.endswith("呢"))):
            q = w.format(q=q)
    elif it["route"] in LOCAL_WRAP and R.random() < 0.6:
        w = R.choice(LOCAL_WRAP[it["route"]])
        if not (w.endswith("嗎") and q.endswith("嗎")) and not ("今天" in w and "今天" in q) and not ("幫我" in w and q.startswith("幫我")):
            q = w.format(q=q)
    if not q.endswith(("嗎", "呢", "啊")) or R.random() < 0.5:
        q = q + R.choice(END)
    return dict(it, q=q)


def main(dst):
    web, local = web_items(), local_items()
    print("基本題：上網", len(web), "本地", len(local))
    seen, out = set(), []
    pool = [(w, 0.82) for w in web] + [(l, 0.18) for l in local]
    # 原句一定要有
    for it, _ in pool:
        if it["q"] not in seen:
            seen.add(it["q"]); out.append(it)
    tries = 0
    while len(out) < 50000 and tries < 2_000_000:
        tries += 1
        base = R.choice(web) if R.random() < 0.8 else R.choice(local)
        v = vary(base)
        if v["q"] in seen:
            continue
        seen.add(v["q"]); out.append(v)
    R.shuffle(out)
    json.dump(out[:50000], open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    from collections import Counter
    print(len(out[:50000]), Counter(x["route"] for x in out[:50000]), Counter(x["want"] for x in out[:50000] if x["want"]))


if __name__ == "__main__":
    main(sys.argv[1])
