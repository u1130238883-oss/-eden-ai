# -*- coding: utf-8 -*-
"""認知判斷題：給一個問題和一句網頁上的話，判斷「這句話能不能當答案」，不能的話是哪一種錯。
   answer（可以當答案）／promo（網站廣告、App、會員、搜尋設定）／meta（介紹文章本身）／trivia（名字由來、典故）／
   opinion（留言、心得）／question（標題、問句）／wrongType（種類不對）／offTopic（沒講到問的東西）
ctx=True：這句話來自已經確定在講這個主題的網頁（食譜裡的「加入雞肉翻炒」不用再提菜名）。
用法：python3 ai/cognition/gen.py 輸出.json [--holdout] [--n 500000]"""
import json
import random
import sys

HOLD = "--holdout" in sys.argv
N = int(sys.argv[sys.argv.index("--n") + 1]) if "--n" in sys.argv else (20000 if HOLD else 500000)
R = random.Random(99 if HOLD else 2026)

if not HOLD:
    DISHES = {"黃燜雞": "雞腿肉", "紅燒肉": "五花肉", "番茄炒蛋": "番茄", "蛋炒飯": "白飯", "滷肉飯": "豬絞肉", "三杯雞": "雞腿", "麻婆豆腐": "豆腐",
              "宮保雞丁": "雞胸肉", "糖醋排骨": "排骨", "牛肉麵": "牛腱", "蔥油餅": "麵粉", "酸辣湯": "豆腐", "咖哩飯": "馬鈴薯", "炒米粉": "米粉",
              "蒸蛋": "雞蛋", "綠豆湯": "綠豆", "紅豆湯": "紅豆", "鹹粥": "白米", "水餃": "絞肉", "炸雞": "雞腿", "麻油雞": "雞腿", "清蒸魚": "鱸魚",
              "炒青菜": "青菜", "馬鈴薯燉肉": "馬鈴薯", "味噌湯": "豆腐"}
    TASKS = ["存錢", "早起", "學英文", "戒掉滑手機", "減肥", "準備面試", "整理房間", "提升專注力", "改善失眠", "交朋友", "跟主管溝通", "克服拖延"]
    NUMS = {"台北101": ("高", "508公尺"), "玉山": ("高", "3952公尺"), "聖母峰": ("高", "8848公尺"), "台灣": ("人口", "約2300萬人"),
            "日本": ("人口", "約1億2000萬人"), "地球到月亮": ("距離", "約38萬公里"), "長城": ("長", "約2萬公里"), "富士山": ("高", "3776公尺")}
    EVENTS = {"第二次世界大戰": "1939年", "法國大革命": "1789年", "人類登月": "1969年", "柏林圍牆倒塌": "1989年", "台灣解嚴": "1987年", "辛亥革命": "1911年"}
    PLACES = {"羅浮宮": "法國巴黎", "吳哥窟": "柬埔寨暹粒省", "馬丘比丘": "秘魯南部", "太魯閣": "台灣花蓮縣", "日月潭": "台灣南投縣", "金閣寺": "日本京都市"}
    REASONS = {"天空是藍色的": "陽光中的藍光波長短，被空氣分子散射得比較多", "海水是鹹的": "河水把岩石裡的鹽分帶進海裡，水蒸發後鹽留了下來",
               "人會打哈欠": "大腦需要調節溫度和清醒程度", "葉子會變黃": "秋天葉綠素分解，原本被遮住的黃色色素顯現出來"}
    CONCEPTS = {"通貨膨脹": "物價持續上漲、貨幣購買力下降的現象", "光合作用": "植物利用光能把二氧化碳和水轉成養分的過程",
                "區塊鏈": "一種把交易紀錄分散儲存、難以竄改的技術", "正念": "專注在當下、不帶評判地覺察自己的練習", "複利": "利息也會再產生利息的計算方式"}
    SITES = ["愛料理", "icook", "食譜網", "料理123", "美食部落"]
else:
    DISHES = {"京醬肉絲": "豬里肌", "鳳梨蝦球": "蝦仁", "蚵仔煎": "蚵仔", "客家小炒": "魷魚", "苦瓜鹹蛋": "苦瓜", "沙茶牛肉": "牛肉片", "日式豬排": "豬排",
              "韓式拌飯": "白飯", "義大利麵": "麵條", "南瓜濃湯": "南瓜"}
    TASKS = ["學游泳", "準備多益", "養成閱讀習慣", "整理衣櫃", "存第一桶金", "練習演講"]
    NUMS = {"東京鐵塔": ("高", "333公尺"), "阿里山": ("高", "2481公尺"), "香港": ("人口", "約750萬人"), "台北到高雄": ("距離", "約350公里")}
    EVENTS = {"甲午戰爭": "1894年", "阿波羅13號": "1970年", "九二一大地震": "1999年", "珍珠港事件": "1941年"}
    PLACES = {"泰姬瑪哈陵": "印度阿格拉市", "布達拉宮": "西藏拉薩市", "雪梨歌劇院": "澳洲雪梨市", "墾丁": "台灣屏東縣"}
    REASONS = {"冰會浮在水上": "水結冰後密度變小", "洋蔥會讓人流淚": "切開後釋放的硫化物刺激眼睛"}
    CONCEPTS = {"元宇宙": "結合虛擬實境與網路的共享虛擬空間", "斷捨離": "減少物品、只留下真正需要的整理觀念", "碳中和": "排放的碳與吸收的碳互相抵銷"}
    SITES = ["好食光", "廚房日記"]

ALL_SUBJ = list(DISHES) + TASKS + list(NUMS) + list(EVENTS) + list(PLACES) + list(REASONS) + list(CONCEPTS)

# ---------- 正確的答案 ----------
DISH_STEPS = (["{i}洗淨切塊，用醬油和米酒醃10分鐘。", "鍋中加入1大匙油燒熱，放入{i}翻炒至上色。", "加入蒜頭和薑片拌炒出香味。",
               "倒入清水蓋過食材，轉小火燉煮20分鐘。", "加入醬油、糖調味，煮至收汁。", "起鍋前加入青椒拌勻，即可盛盤。", "把{i}瀝乾水分備用。"]
              if not HOLD else
              ["先把{i}汆燙去血水，撈起備用。", "熱鍋後下{i}，以中火煎到兩面金黃。", "淋上調好的醬汁，蓋上鍋蓋燜5分鐘。", "最後撒上蔥花，關火裝盤。"])
TASK_STEPS = (["每天固定一個時間練習，先從十分鐘開始。", "建議把目標拆成小步驟，一次只做一件事。", "可以找朋友一起，互相提醒。",
               "記得把進度記錄下來，看得到成果比較能持續。", "避免一次給自己太大的壓力。"]
              if not HOLD else ["先訂一個做得到的小目標，達成後再加一點。", "把需要的東西準備好放在看得到的地方。", "累了就休息一下，隔天再繼續。"])

PROMO = (["設定後，在Google搜尋食譜時，{site}的食譜會優先出現！", "下載{site} App，收藏更多{x}的食譜。", "加入會員即可收藏這道{x}。",
          "按讚追蹤我們的粉絲團，每天都有新食譜！", "點我看更多{x}的做法。", "訂閱頻道，開啟小鈴鐺不錯過新影片。", "掃描QR Code加入LINE好友領優惠。",
          "限時優惠：鍋具組打8折，立即搶購！", "本站文章版權所有，轉載請註明出處。", "更多食譜請看相關食譜專區。"]
         if not HOLD else ["想看更多{x}？下載我們的App就能收藏。", "成為會員，每週寄送{site}精選食譜到你的信箱。", "喜歡這篇的話，記得按讚分享給朋友。"])
META = (["這篇文章將教你如何做出好吃的{x}。", "以下為大家整理{x}的懶人包。", "今天要跟大家分享{x}。", "小編這次實際試了{x}。",
         "本文帶你一次了解{x}。"] if not HOLD else ["這篇要介紹的是{x}。", "下面就來看看{x}吧。", "本篇整理了{x}的重點。"])
TRIVIA = (["{x}的名字由來，相傳源自山東。", "煮出來的顏色比較淺，可能因此取名「{x}」。", "據說{x}最早是一家老店的招牌。", "{x}又稱家常版，名稱很有趣。"]
          if not HOLD else ["傳說{x}和一位古代皇帝有關。", "{x}這個名稱的典故有好幾種說法。"])
OPINION = (["看起來好好吃！", "感謝分享，收藏了！", "我覺得{x}超實用。", "試了好幾次，家人都說好吃XD", "太好吃了，大推！"]
           if not HOLD else ["好讚的分享～～", "學起來了，謝謝分享！", "我個人最愛這個{x}。"])
QUESTION = (["{x}要多久？", "為什麼我的{x}會失敗？", "{x}可以用電鍋嗎？"] if not HOLD else ["請問{x}要準備什麼？", "{x}難不難？"])


WRAP = ["{q}", "{q}？", "請問{q}", "我想知道{q}", "{q}呢", "欸，{q}", "可以告訴我{q}嗎", "想問{q}"]
NUMBERING = ["", "", "", "1. ", "2、", "3）", "步驟4：", "Step 5：", "②", "③ ", "• ", "★"]
TAILS = ["", "", "。", "！", "～"]
NOTES = ["", "", "", "小提醒：", "Tips：", "重點："]


def item(q, want, subject, s, ctx, label):
    q = R.choice(WRAP).format(q=q)
    s = s.replace("10分鐘", "%d分鐘" % R.choice([5, 8, 10, 15, 20, 30])).replace("20分鐘", "%d分鐘" % R.choice([15, 20, 25, 40]))
    s = s.replace("1大匙", R.choice(["1大匙", "2大匙", "少許", "適量"])).replace("8折", R.choice(["7折", "8折", "85折", "9折"]))
    deco = R.choice(NUMBERING) + (R.choice(NOTES) if label == "answer" else "")
    s = deco + s.rstrip("。！～") + R.choice(TAILS) if label not in ("question",) else deco + s
    return {"q": q, "want": want, "subject": subject, "s": s, "ctx": ctx, "label": label}


def gen_one():
    kind = R.choice(["dish", "dish", "task", "number", "time", "place", "reason", "define"])
    if kind == "dish":
        x = R.choice(list(DISHES)); i = DISHES[x]
        q, want = R.choice(["怎麼做{x}", "{x}的做法", "{x}怎麼煮", "教我做{x}"]).format(x=x), "steps"
        good = R.choice(DISH_STEPS).format(i=i)
        good_open = "{x}的做法：".format(x=x) + good
    elif kind == "task":
        x = R.choice(TASKS)
        q, want = R.choice(["怎麼{x}", "{x}的方法", "如何{x}"]).format(x=x), "steps"
        good = R.choice(TASK_STEPS)
        good_open = "想要{x}，".format(x=x) + good
    elif kind == "number":
        x = R.choice(list(NUMS)); attr, v = NUMS[x]
        q, want = "{x}有多{a}".format(x=x, a=attr[0] if attr in ("高", "長") else "少") if attr != "距離" else "{x}有多遠".format(x=x), "number"
        good = good_open = R.choice(["{x}的{a}是{v}。", "根據統計，{x}{a}{v}。"]).format(x=x, a=attr, v=v)
    elif kind == "time":
        x = R.choice(list(EVENTS)); v = EVENTS[x]
        q, want = "{x}是哪一年".format(x=x), "time"
        good = good_open = R.choice(["{x}發生於{v}。", "{x}是在{v}。"]).format(x=x, v=v)
    elif kind == "place":
        x = R.choice(list(PLACES)); v = PLACES[x]
        q, want = "{x}在哪裡".format(x=x), "place"
        good = good_open = R.choice(["{x}位於{v}。", "{x}在{v}，是著名的景點。"]).format(x=x, v=v)
    elif kind == "reason":
        x = R.choice(list(REASONS)); v = REASONS[x]
        q, want = "為什麼{x}".format(x=x), "reason"
        good = good_open = R.choice(["{x}，是因為{v}。", "主要原因是{v}，所以{x}。"]).format(x=x, v=v)
    else:
        x = R.choice(list(CONCEPTS)); v = CONCEPTS[x]
        q, want = "什麼是{x}".format(x=x), "definition"
        good = good_open = R.choice(["{x}是指{v}。", "所謂{x}，指的是{v}。"]).format(x=x, v=v)

    site = R.choice(SITES)
    r = R.random()
    ctx = R.random() < 0.5
    if r < 0.40:
        # 正確的答案：不在主題網頁裡時，句子本身要講到主題
        s = good if (ctx and kind in ("dish", "task")) else good_open
        return item(q, want, x, s, ctx, "answer")
    if r < 0.50:
        return item(q, want, x, R.choice(PROMO).format(x=x, site=site), ctx, "promo")
    if r < 0.58:
        return item(q, want, x, R.choice(META).format(x=x), ctx, "meta")
    if r < 0.66 and want in ("steps", "number", "time", "place"):
        return item(q, want, x, R.choice(TRIVIA).format(x=x), ctx, "trivia")
    if r < 0.74:
        return item(q, want, x, R.choice(OPINION).format(x=x), ctx, "opinion")
    if r < 0.81:
        return item(q, want, x, R.choice(QUESTION).format(x=x), ctx, "question")
    if r < 0.92:
        # 種類不對：講到主題，但不是這題要的東西
        wrong = {"steps": ["{x}是一道很受歡迎的家常菜。" if kind == "dish" else "{x}是很多人的新年願望。", "{x}的熱量大約中等。" if kind == "dish" else "{x}這件事因人而異。"],
                 "number": ["{x}是世界知名的地標。", "{x}非常有名，吸引許多觀光客。"],
                 "time": ["{x}影響非常深遠。", "{x}改變了許多人的生活。"],
                 "place": ["{x}非常有名，每年吸引許多遊客。", "{x}的建築很壯觀。"],
                 "reason": ["{x}是很常見的現象。", "很多人都注意過{x}這件事。"],
                 "definition": None}[want]
        if wrong:
            return item(q, want, x, R.choice(wrong).format(x=x), ctx, "wrongType")
    # 沒講到問的東西：另一個主題的句子，而且不在這個主題的網頁裡
    other = R.choice([o for o in ALL_SUBJ if o != x and not set(o) & set(x)])
    s = R.choice(["{o}是很多人喜歡的話題。", "關於{o}，有很多不同的說法。", "{o}最近很受注目。"]).format(o=other)
    return item(q, want, x, s, False, "offTopic")


def main(dst):
    out, seen = [], set()
    tries = 0
    while len(out) < N and tries < N * 20:
        tries += 1
        it = gen_one()
        key = (it["q"], it["s"], it["ctx"])
        if key in seen:
            continue
        seen.add(key)
        out.append(it)
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    from collections import Counter
    print(len(out), "題（不同的組合", len(seen), "）", Counter(x["label"] for x in out))


if __name__ == "__main__":
    main(sys.argv[1])
