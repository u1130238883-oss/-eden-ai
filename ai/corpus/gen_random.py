#!/usr/bin/env python3
"""各種隨機問題（至少 20,000,000 字），拿來檢測大腦的回答：每題有參考答案，能自動對答案的附上 expect／num／maxlen。

題型（隨機數字、隨機日期、隨機組合，每次都不一樣）：
- 算數應用題：買東西找錢、打折、速度、平均、比例分配、利息、面積
- 單位換算、日期（星期幾、相差幾天、幾天後）、干支年、生肖
- 數列、排順序的邏輯題、三段論
- 知識：國家首都／貨幣／語言、元素符號、行星、動物、台灣縣市、為什麼、疾病看哪科／會不會傳染
- 命理快問：十神、五行生剋、四化、六沖六合、納音
- 哲學快問：名言是誰說的、概念是誰提的
- 照指示：只回答、一句話、不超過幾個字、列三點、用英文
- 口語、錯字、急、考考你、夾英文的問法
- 從其他語料抽的聊天題（安慰、罵人、叛逆、情緒、醫學、世界），只用規則檢查

python3 gen_random.py 輸出.jsonl 考題.jsonl [目標字數]
"""
import datetime as dt
import hashlib
import json
import random
import sys

import med_data
import world_data as W
from phil_data import C as PC, P as PP

R = random.Random(20_000_000)
STEMS = list("甲乙丙丁戊己庚辛壬癸")
BR = list("子丑寅卯辰巳午未申酉戌亥")
ANIMALS = list("鼠牛虎兔龍蛇馬羊猴雞狗豬")
WX = ["木", "火", "土", "金", "水"]
STEM_EL = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4]
WEEK = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
NAMES = ["小明", "小華", "阿美", "志強", "雅婷", "家豪", "怡君", "俊傑", "淑芬", "建宏", "佳穎", "冠宇"]
ITEMS = [("蘋果", "顆"), ("筆", "支"), ("便當", "個"), ("飲料", "杯"), ("麵包", "個"), ("襪子", "雙"), ("筆記本", "本"), ("雞蛋", "顆"), ("電池", "顆"), ("口罩", "盒")]
SIHUA = {"甲": ["廉貞", "破軍", "武曲", "太陽"], "乙": ["天機", "天梁", "紫微", "太陰"], "丙": ["天同", "天機", "文昌", "廉貞"],
         "丁": ["太陰", "天同", "天機", "巨門"], "戊": ["貪狼", "太陰", "右弼", "天機"], "己": ["武曲", "貪狼", "天梁", "文曲"],
         "庚": ["太陽", "武曲", "太陰", "天同"], "辛": ["巨門", "太陽", "文曲", "文昌"], "壬": ["天梁", "紫微", "左輔", "武曲"],
         "癸": ["破軍", "巨門", "太陰", "貪狼"]}
NAYIN = ["海中金", "爐中火", "大林木", "路旁土", "劍鋒金", "山頭火", "澗下水", "城頭土", "白蠟金", "楊柳木",
         "泉中水", "屋上土", "霹靂火", "松柏木", "長流水", "沙中金", "山下火", "平地木", "壁上土", "金箔金",
         "覆燈火", "天河水", "大驛土", "釵釧金", "桑柘木", "大溪水", "沙中土", "天上火", "石榴木", "大海水"]
PREFIX = ["", "", "", "", "欸，", "問一下，", "急！", "考考你：", "認真問：", "快點告訴我，", "小問題：", "哈囉，", "請問", "我朋友說我錯了，"]
SUFFIX = ["", "", "", "", "？", "？謝啦", "，不要騙我", "，你算得出來嗎", "？？", "，快", "，拜託"]


def god(dm, stem):
    a, b = STEM_EL[dm], STEM_EL[stem]
    same = (dm % 2) == (stem % 2)
    rel = (b - a) % 5
    return [["比肩", "劫財"], ["食神", "傷官"], ["偏財", "正財"], ["七殺", "正官"], ["偏印", "正印"]][rel][0 if same else 1]


def fmt(x):
    return str(int(x)) if abs(x - round(x)) < 1e-9 else f"{x:.2f}".rstrip("0").rstrip(".")


def dress(q):
    q = q.rstrip("？?")
    return R.choice(PREFIX) + q + (R.choice(SUFFIX) or "？")


# ---------- 各題型：回傳 (題目, 參考答案, 改分欄位) ----------

def t_shop():
    (a, u1), (b, u2) = R.sample(ITEMS, 2)
    n1, n2 = R.randint(2, 9), R.randint(1, 6)
    p1, p2 = R.choice([5, 8, 10, 12, 15, 20, 25, 35, 45, 60]), R.choice([7, 9, 18, 30, 40, 55, 65, 80])
    cost = n1 * p1 + n2 * p2
    pay = (cost // 100 + 1) * 100 if R.random() < 0.6 else (cost // 500 + 1) * 500
    who = R.choice(NAMES)
    return (f"{who}買了{n1}{u1}{a}，每{u1}{p1}元，又買了{n2}{u2}{b}，每{u2}{p2}元，付了{pay}元，要找多少錢？",
            f"{a}：{n1}×{p1}＝{n1 * p1}元；{b}：{n2}×{p2}＝{n2 * p2}元；共{cost}元。找{pay}−{cost}＝{pay - cost}元。", {"num": pay - cost})


def t_discount():
    p = R.choice([280, 350, 499, 600, 790, 1200, 1580, 2400, 3990])
    d = R.choice([9, 8, 7, 75, 85, 65, 6, 5])
    r = d / 10 if d < 10 else d / 100
    v = p * r
    return (f"原價{p}元，打{d}折是多少錢？", f"打{d}折＝原價×{fmt(r)}，{p}×{fmt(r)}＝{fmt(v)}元。", {"approx": round(v, 2)})


def t_speed():
    v = R.choice([4, 5, 12, 15, 40, 60, 72, 80, 90, 110])
    t = R.choice([0.5, 1.5, 2, 2.5, 3, 4, 45, 90])
    mins = t if t > 10 else None
    hours = t / 60 if mins else t
    d = v * hours
    tt = f"{int(t)}分鐘" if mins else f"{fmt(t)}小時"
    return (f"時速{v}公里，走了{tt}，總共走了幾公里？", f"距離＝速度×時間＝{v}×{fmt(hours)}＝{fmt(d)}公里。", {"approx": round(d, 2)})


def t_avg():
    xs = [R.randint(50, 100) for _ in range(R.randint(3, 6))]
    s = sum(xs)
    return (f"考試成績是{'、'.join(map(str, xs))}分，平均幾分？", f"總和{s}，除以{len(xs)}，平均{fmt(s / len(xs))}分。", {"approx": round(s / len(xs), 2)})


def t_share():
    k = [R.randint(1, 5) for _ in range(3)]
    unit = R.choice([100, 120, 250, 300, 500])
    tot = unit * sum(k)
    ns = R.sample(NAMES, 3)
    i = R.randrange(3)
    return (f"{tot}元按{':'.join(map(str, k))}分給{'、'.join(ns)}，{ns[i]}拿多少？", f"總份數{sum(k)}，一份{unit}元，{ns[i]}拿{k[i]}份＝{k[i] * unit}元。", {"num": k[i] * unit})


def t_interest():
    p = R.choice([10000, 50000, 100000, 200000])
    r = R.choice([1, 1.5, 2, 3, 5])
    y = R.randint(1, 5)
    v = p * r / 100 * y
    return (f"本金{p}元，年利率{fmt(r)}%，單利存{y}年，利息多少？", f"單利利息＝本金×利率×年數＝{p}×{fmt(r)}%×{y}＝{fmt(v)}元。", {"approx": v})


def t_area():
    a, b = R.randint(3, 25), R.randint(3, 25)
    if R.random() < 0.5:
        return (f"長{a}公尺、寬{b}公尺的長方形，面積是多少平方公尺？", f"面積＝長×寬＝{a}×{b}＝{a * b}平方公尺。", {"num": a * b})
    return (f"長{a}公分、寬{b}公分的長方形，周長是多少公分？", f"周長＝(長＋寬)×2＝({a}＋{b})×2＝{2 * (a + b)}公分。", {"num": 2 * (a + b)})


def t_unit():
    k = R.randrange(6)
    if k == 0:
        x = R.choice([1.5, 2.3, 3, 4.2, 7.8, 12])
        return (f"{fmt(x)}公里是幾公尺？", f"1公里＝1000公尺，{fmt(x)}公里＝{fmt(x * 1000)}公尺。", {"approx": x * 1000})
    if k == 1:
        x = R.choice([250, 750, 1200, 2500, 3600])
        return (f"{x}公克是幾公斤？", f"1公斤＝1000公克，{x}公克＝{fmt(x / 1000)}公斤。", {"approx": x / 1000})
    if k == 2:
        x = R.choice([90, 150, 200, 75, 135, 260])
        return (f"{x}分鐘是幾小時幾分？", f"{x}÷60＝{x // 60}小時{x % 60}分。", {"expect": [[f"{x // 60}小時{x % 60}分" if x % 60 else f"{x // 60}小時", f"{x // 60}個小時{x % 60}分"]]})
    if k == 3:
        c = R.choice([0, 10, 20, 25, 30, 37, 40, 100])
        f = c * 9 / 5 + 32
        return (f"攝氏{c}度是華氏幾度？", f"華氏＝攝氏×9/5＋32＝{fmt(f)}°F。", {"approx": f})
    if k == 4:
        x = R.choice([2, 3, 5, 10, 24])
        return (f"{x}台斤是幾公斤？", f"1台斤＝0.6公斤，{x}台斤＝{fmt(x * 0.6)}公斤。", {"approx": round(x * 0.6, 2)})
    x = R.choice([1, 2, 3, 5, 8])
    return (f"{x}坪是幾平方公尺？", f"1坪約3.3058平方公尺，{x}坪約{fmt(round(x * 3.3058, 2))}平方公尺。", {"approx": round(x * 3.3058, 2)})


def rand_date(a=1990, b=2035):
    return dt.date(R.randint(a, b), R.randint(1, 12), R.randint(1, 28))


def t_weekday():
    d = rand_date()
    w = WEEK[d.weekday()]
    return (f"{d.year}年{d.month}月{d.day}日是星期幾？", f"{d.year}年{d.month}月{d.day}日是{w}。", {"expect": [[w, w.replace("星期", "禮拜"), w.replace("星期", "週")]]})


def t_diff():
    a = rand_date(2020, 2030)
    b = a + dt.timedelta(days=R.randint(5, 400))
    n = (b - a).days
    return (f"{a.year}年{a.month}月{a.day}日到{b.year}年{b.month}月{b.day}日相差幾天？", f"相差{n}天。", {"num": n})


def t_add():
    a = rand_date(2024, 2030)
    n = R.choice([7, 10, 30, 45, 60, 90, 100, 180])
    b = a + dt.timedelta(days=n)
    return (f"{a.year}年{a.month}月{a.day}日再過{n}天是幾月幾日？", f"{a.year}年{a.month}月{a.day}日加{n}天是{b.year}年{b.month}月{b.day}日。",
            {"expect": [[f"{b.month}月{b.day}日", f"{b.month}/{b.day}", f"{b.month}月{b.day}號"]]})


def t_ganzhi():
    y = R.randint(1924, 2060)
    gz = STEMS[(y - 4) % 10] + BR[(y - 4) % 12]
    if R.random() < 0.5:
        return (f"{y}年是什麼年（天干地支）？", f"{y}年是{gz}年。", {"expect": [[gz]]})
    a = ANIMALS[(y - 4) % 12]
    return (f"{y}年出生屬什麼生肖？", f"{y}年是{gz}年，屬{a}（以農曆新年或立春為界，年初出生的要看是否過年）。", {"expect": [[a]]})


def t_nayin():
    i = R.randrange(60)
    gz = STEMS[i % 10] + BR[i % 12]
    n = NAYIN[i // 2]
    return (f"{gz}的納音是什麼？", f"{gz}的納音是{n}，五行屬{n[-1]}。", {"expect": [[n]]})


def t_seq():
    if R.random() < 0.5:
        a, d = R.randint(1, 20), R.randint(2, 9)
        xs = [a + d * i for i in range(5)]
        nxt = a + d * 5
        why = f"每次加{d}"
    else:
        a, r = R.randint(1, 5), R.choice([2, 3])
        xs = [a * r ** i for i in range(5)]
        nxt = a * r ** 5
        why = f"每次乘{r}"
    return (f"{'、'.join(map(str, xs))}，下一個數是多少？", f"規律是{why}，下一個是{nxt}。", {"num": nxt})


def t_order():
    ns = R.sample(NAMES, 4)
    adj, small = R.choice([("高", "矮"), ("大", "小"), ("快", "慢"), ("重", "輕")])
    facts = [f"{ns[i]}比{ns[i + 1]}{adj}" for i in range(3)]
    R.shuffle(facts)
    if R.random() < 0.5:
        return (f"{'，'.join(facts)}。誰最{adj}？", f"排起來：{'＞'.join(ns)}，最{adj}的是{ns[0]}。", {"expect": [[ns[0]]], "forbid_last": ns[3]})
    return (f"{'，'.join(facts)}。誰最{small}？", f"排起來：{'＞'.join(ns)}，最{small}的是{ns[3]}。", {"expect": [[ns[3]]]})


def t_syllogism():
    a, b, c = R.choice([("貓", "哺乳類", "動物"), ("玫瑰", "花", "植物"), ("麻雀", "鳥", "會下蛋的動物"), ("鯨魚", "哺乳類", "會呼吸空氣的動物"),
                        ("正方形", "長方形", "四邊形"), ("台北", "台灣的城市", "亞洲的城市")])
    return (f"所有{a}都是{b}，所有{b}都是{c}，那所有{a}都是{c}嗎？", f"是。{a}⊂{b}⊂{c}，所以所有{a}都是{c}。", {"expect": [["是", "對", "沒錯", "會"]]})


def t_country():
    c = R.choice(W.COUNTRIES)
    k = R.randrange(3)
    if k == 0:
        return (f"{c[0]}的首都是哪裡？", f"{c[0]}的首都是{c[1]}。", {"expect": [[c[1]]]})
    if k == 1:
        cur = c[4].split("（")[0]
        return (f"{c[0]}用什麼貨幣？", f"{c[0]}用{c[4]}。", {"expect": [[cur]]})
    lang = c[3].split("（")[0].split("、")[0]
    return (f"{c[0]}的官方語言是什麼？", f"{c[0]}主要說{c[3]}。", {"expect": [[lang, lang.replace("語", "文")]]})


def t_element():
    e = R.choice(W.ELEMENTS)
    if R.random() < 0.5:
        return (f"{e[2]}的化學符號是什麼？", f"{e[2]}的符號是{e[1]}，原子序{e[0]}。", {"expect": [[e[1]]]})
    return (f"原子序{e[0]}是什麼元素？", f"原子序{e[0]}是{e[2]}（{e[1]}）。", {"expect": [[e[2], e[1]]]})


def t_planet():
    p = R.choice(W.PLANETS)
    return (f"{p[0]}有什麼特色？", f"{p[0]}是{p[1]}：{p[2]}。", {})


def t_animal():
    a = R.choice(W.ANIMALS)
    return (f"{a[0]}是肉食、草食還是雜食？", f"{a[0]}是{a[1]}，{a[2]}。{a[3]}。", {"expect": [[a[2][:2]]]})


def t_taiwan():
    t = R.choice(W.TAIWAN)
    return (f"{t[0]}有什麼特色？", f"{t[0]}（{t[1]}）：{t[2]}。", {})


def t_why():
    q, a = R.choice(W.WHY)
    return (q, a, {})


def t_med():
    c = R.choice(med_data.C)
    k = R.randrange(3)
    if k == 0:
        dept = c["dept"]
        keys = [x.replace("科", "") for x in dept.replace("或", "、").split("、") if x]
        return (f"{c['n']}要看哪一科？", f"{c['n']}可以看{dept}。", {"expect": [keys]})
    if k == 1:
        return (f"{c['n']}有什麼症狀？", f"{c['n']}常見症狀：{'、'.join(c['s'])}。原因：{c['c']}。", {"expect": [c["s"][:4]]})
    return (f"{c['n']}會傳染嗎？", f"{c['ct']}。預防：{c['p']}。", {})


def t_god():
    dm, s = R.randrange(10), R.randrange(10)
    g = god(dm, s)
    return (f"日主{STEMS[dm]}，看到{STEMS[s]}是什麼十神？", f"{STEMS[dm]}{WX[STEM_EL[dm]]}看{STEMS[s]}{WX[STEM_EL[s]]}：{g}。", {"expect": [[g]]})


def t_wuxing():
    i = R.randrange(5)
    k = R.randrange(4)
    if k == 0:
        return (f"{WX[i]}生什麼？", f"{WX[i]}生{WX[(i + 1) % 5]}。", {"expect": [[WX[(i + 1) % 5]]]})
    if k == 1:
        return (f"{WX[i]}剋什麼？", f"{WX[i]}剋{WX[(i + 2) % 5]}。", {"expect": [[WX[(i + 2) % 5]]]})
    if k == 2:
        return (f"什麼生{WX[i]}？", f"{WX[(i - 1) % 5]}生{WX[i]}。", {"expect": [[WX[(i - 1) % 5]]]})
    return (f"什麼剋{WX[i]}？", f"{WX[(i - 2) % 5]}剋{WX[i]}。", {"expect": [[WX[(i - 2) % 5]]]})


def t_sihua():
    s = R.choice(STEMS)
    h = SIHUA[s]
    return (f"紫微斗數{s}干的四化是什麼？", f"{s}干四化：{h[0]}化祿、{h[1]}化權、{h[2]}化科、{h[3]}化忌。", {"expect": [[h[0]], [h[3]]]})


def t_branch():
    i = R.randrange(12)
    if R.random() < 0.5:
        return (f"地支{BR[i]}沖什麼？", f"{BR[i]}{BR[(i + 6) % 12]}相沖。", {"expect": [[BR[(i + 6) % 12]]]})
    he = {0: 1, 1: 0, 2: 11, 11: 2, 3: 10, 10: 3, 4: 9, 9: 4, 5: 8, 8: 5, 6: 7, 7: 6}[i]
    return (f"地支{BR[i]}和哪個六合？", f"{BR[i]}{BR[he]}六合。", {"expect": [[BR[he]]]})


def t_quote():
    p = R.choice(PP)
    names = [p[0]] + ([p[0].split("（")[0], p[0].split("（")[1].rstrip("）")] if "（" in p[0] else []) + ([p[0].split("・")[-1]] if "・" in p[0] else [])
    return (f"「{p[5]}」是誰說的？", f"{p[0]}（{p[3]}）。", {"expect": [names]})


def t_concept():
    c = R.choice(PC)
    return (f"{c[0]}是什麼？", f"{c[0]}：{c[1]}。例子：{c[2]}。", {})


KNOW = [t_country, t_element, t_animal, t_med, t_quote]


def t_instruct():
    q, a, g = R.choice(KNOW)()
    k = R.randrange(5)
    if k == 0:
        return (q.rstrip("？") + "？只回答答案，不要解釋。", a, {**g, "maxlen": 40})
    if k == 1:
        return (q.rstrip("？") + "？用一句話回答。", a, {**g, "maxlen": 80})
    if k == 2:
        n = R.choice([20, 30, 50])
        return (q.rstrip("？") + f"？不要超過{n}個字。", a, {**g, "maxlen": n + 10})
    if k == 3:
        return (q.rstrip("？") + "？列出三點，每點一行。", a, {**g, "lines": 3})
    c = R.choice(W.COUNTRIES)
    return (f"What is the capital of {c[0]}? Answer in English.", f"{c[1]}", {"script": "en"})


TYPES = [(t_shop, 6), (t_discount, 4), (t_speed, 3), (t_avg, 3), (t_share, 3), (t_interest, 2), (t_area, 3), (t_unit, 5),
         (t_weekday, 4), (t_diff, 3), (t_add, 3), (t_ganzhi, 4), (t_nayin, 2), (t_seq, 3), (t_order, 3), (t_syllogism, 2),
         (t_country, 5), (t_element, 3), (t_planet, 1), (t_animal, 2), (t_taiwan, 1), (t_why, 2), (t_med, 5),
         (t_god, 3), (t_wuxing, 3), (t_sihua, 3), (t_branch, 3), (t_quote, 3), (t_concept, 2), (t_instruct, 8)]
FUNCS = [f for f, w in TYPES for _ in range(w)]

target = int(sys.argv[3]) if len(sys.argv) > 3 else 20_300_000
out = []
total = 0
seen = set()
while total < target:
    f = R.choice(FUNCS)
    q, a, g = f()
    q = dress(q) if f is not t_instruct else q
    if q in seen:
        continue
    seen.add(q)
    it = {"cat": "random", "type": f.__name__[2:], "q": q, "a": a}
    it.update({k: v for k, v in g.items() if k != "forbid_last"})
    out.append(it)
    total += len(q) + len(a)

R.shuffle(out)
with open(sys.argv[1], "w", encoding="utf-8") as fo:
    for i, it in enumerate(out):
        it["id"] = f"rnd-{i:07d}"
        fo.write(json.dumps(it, ensure_ascii=False) + "\n")
kinds = {}
for it in out:
    kinds[it["type"]] = kinds.get(it["type"], 0) + 1
print(len(out), "題，", total, "字")
print(kinds)

# 考題：每種能自動對答案的題型抽 14 題
exam = []
by = {}
for it in out:
    if any(k in it for k in ("expect", "num", "approx", "maxlen", "lines", "script")):
        by.setdefault(it["type"], []).append(it)
for k, items in sorted(by.items()):
    for it in R.sample(items, min(14, len(items))):
        e = {k2: v for k2, v in it.items() if k2 not in ("a",)}
        e["cat"] = "random"
        e["kind"] = it["type"]
        e["lang"] = "en" if it.get("script") == "en" else "zh"
        exam.append(e)
with open(sys.argv[2], "w", encoding="utf-8") as fo:
    for i, e in enumerate(exam):
        e["id"] = f"rx-{i:04d}"
        e["split"] = "hold" if int(hashlib.md5(e["id"].encode()).hexdigest(), 16) % 4 == 0 else "dev"
        fo.write(json.dumps(e, ensure_ascii=False) + "\n")
print(len(exam), "題考題")
