# -*- coding: utf-8 -*-
"""驗證題：5,000 題「沒看過」的問法和名稱（訓練題裡沒有），檢查是真的理解、不是背題目。
用法：python3 ai/understanding/holdout.py ios/EchoCore/Tests/EchoCoreTests/Fixtures/understanding_holdout.json"""
import json
import random
import sys

R = random.Random(777)
HEIGHT = ["101大樓", "阿爾卑斯山", "埃菲爾鐵塔", "台中國家歌劇院", "日月潭的水", "長頸鹿寶寶", "北極星", "台北小巨蛋"]
CONCEPT = ["量子力學", "心理學", "經濟學", "供需法則", "邊際效用", "社會契約論", "行為經濟學", "文化大革命", "後現代主義", "暗物質",
           "NFT", "Web3", "API", "大數據", "5G", "疫苗", "抗生素", "冷戰", "全球化", "新冠肺炎"]
REASON = [("海浪", "會一直拍打"), ("人", "會流眼淚"), ("貓", "會舔毛"), ("天空", "會下雨"), ("冰箱", "會結霜"), ("手機", "會發燙"), ("鐵", "會生鏽"),
          ("草", "是綠色的"), ("火", "是熱的"), ("海", "是藍色的")]
TASK = ["準備多益", "養多肉植物", "跟主管提加薪", "整理房間", "學吉他", "寫好一篇作文", "戒菸", "保養皮膚", "挑選筆電", "照顧新生兒"]
PROBLEM = ["鄰居很吵", "手機掉進水裡", "被同學嘲笑", "電腦中毒", "腳抽筋", "牙齒痛", "車子拋錨", "網路斷線"]
BOOK = ["追風箏的孩子", "牧羊少年奇幻之旅", "麥田捕手", "蒼蠅王", "動物農莊", "殺死一隻知更鳥", "憂鬱的貓", "哭泣的女人", "寂寞的鯨魚", "快樂的死"]
PERSON_THING = ["電話", "相對論", "進化論", "萬有引力", "DNA雙螺旋", "元素週期表", "印刷術", "電燈泡"]
PLACE = ["比薩斜塔", "大笨鐘", "泰姬瑪哈陵", "雪梨歌劇院", "自由女神像", "布達拉宮", "白金漢宮", "故宮博物院", "凡爾賽宮", "紫禁城"]
EVENT = ["甲午戰爭", "珍珠港事件", "阿波羅登月", "柏林圍牆倒下", "台灣第一次總統直選", "車諾比核災", "南京條約", "鴉片戰爭"]
FORT = ["我下週的運勢", "我這禮拜運氣怎樣", "今年我的事業運", "我最近財運好不好", "幫我看我的流年", "我的命宮代表什麼", "我明年感情順嗎", "我哪一年運最好"]
FEEL = ["我心好累", "最近壓力超大", "我覺得好孤獨", "今天好想哭", "我真的好焦慮喔", "被罵了好委屈", "我好想放棄", "失戀了好痛"]


def it(q, route, want="", subject=""):
    return {"q": q, "route": route, "want": want, "subject": subject, "kind": "holdout-" + (want or route)}


def items():
    out = []
    for x in HEIGHT:
        out += [it(f"{x}大概多高", "web", "number", x), it(f"{x}高度多少", "web", "number", x)]
    for x in CONCEPT:
        out += [it(f"{x}到底是什麼", "web", "definition", x), it(f"誰能解釋一下{x}", "web", "definition", x),
                it(f"{x}的意思", "web", "definition", x), it(f"跟我說說{x}是什麼", "web", "definition", x)]
    for a, b in REASON:
        out += [it(f"為什麼{a}{b}呢", "web", "reason", ""), it(f"{a}{b}的原因", "web", "reason", ""), it(f"{a}怎麼會{b.lstrip('會')}", "web", "reason", "")]
    for x in TASK:
        out += [it(f"有沒有什麼方法可以{x}", "web", "steps", x), it(f"想{x}要從哪裡開始", "web", "steps", x), it(f"{x}的技巧有哪些", "web", "steps", x),
                it(f"怎樣才能{x}", "web", "steps", x)]
    for x in PROBLEM:
        out += [it(f"{x}該如何處理", "web", "steps", x), it(f"{x}的話要怎麼辦", "web", "steps", x)]
    for x in BOOK:
        out += [it(f"{x}這本小說在說什麼", "web", "open", x), it(f"誰是{x}的作者", "web", "person", x), it(f"{x}的故事大綱", "web", "open", x)]
    for x in PERSON_THING:
        out += [it(f"{x}是誰提出的", "web", "person", x), it(f"是誰發現{x}的", "web", "person", x)]
    for x in PLACE:
        out += [it(f"{x}在哪個城市", "web", "place", x), it(f"{x}是在哪個國家", "web", "place", x)]
    for x in EVENT:
        out += [it(f"{x}是在哪一年發生的", "web", "time", x), it(f"{x}發生於何時", "web", "time", x)]
    for q in FORT:
        out.append(it(q, "fortune"))
    for q in FEEL:
        out.append(it(q, "feeling"))
    return out


WRAP = ["請問{q}", "我想問{q}", "{q}？", "欸，{q}", "你知道{q}嗎", "說說{q}", "{q}呢？", "所以{q}", "{q}耶"]


def main(dst):
    base = items()
    seen, out = set(), []
    for b in base:
        seen.add(b["q"]); out.append(b)
    while len(out) < 5000:
        b = R.choice(base)
        w = R.choice(WRAP)
        if w.endswith("嗎") and b["q"].endswith(("嗎", "呢")):
            continue
        q = w.format(q=b["q"]) + R.choice(["", "", "?", "。"])
        if q in seen:
            if len(seen) > 4000 and R.random() < 0.02:
                break
            continue
        seen.add(q); out.append(dict(b, q=q))
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(len(base), "種問法與名稱 →", len(out), "題")


if __name__ == "__main__":
    main(sys.argv[1])
