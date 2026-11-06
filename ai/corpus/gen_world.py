#!/usr/bin/env python3
"""世界理解語料：至少 5,000,000 字的答疑。

- 國家、元素、行星、動物、台灣縣市（world_data 的確定事實）：各種問法，答案附理由和延伸
- 為什麼？日常科學：說明原因
- 用算的（答案保證正確）：日期和星期、相差幾天、幾歲、閏年、單位換算、溫度、時區、
  購物比價、折扣、速度距離時間、單利複利、百分比、平均、比例、工作效率
- 比較與推理：哪個國家在哪一洲、原子序大小、哪種動物是哺乳類……

python3 gen_world.py 輸出.jsonl
"""
import datetime as dt
import json
import random
import sys

from world_data import ANIMALS, COUNTRIES, ELEMENTS, PLANETS, TAIWAN, WHY

R = random.Random(5_000_003)
WEEK = "一二三四五六日"
out = []


def add(topic, q, a):
    out.append({"cat": "world", "topic": topic, "q": q, "a": a})


def pick(*xs):
    return R.choice(xs)


# ─────────── 國家 ───────────
for name, cap, cont, lang, cur, sight in COUNTRIES:
    for _ in range(12):
        t = R.randrange(7)
        if t == 0:
            add("國家", pick(f"{name}的首都是哪裡？", f"{name}首都？", f"{cap}是哪一國的首都？"), f"{name}的首都是{cap}。{name}在{cont}，主要語言是{lang}，用{cur}。")
        elif t == 1:
            add("國家", pick(f"{name}說什麼語言？", f"去{name}要會什麼語言？"), f"{name}的官方或主要語言是{lang}。觀光地區通常英語也能溝通。")
        elif t == 2:
            add("國家", pick(f"{name}用什麼錢？", f"{name}的貨幣是什麼？"), f"{name}使用{cur}。出國前可以先換一點現金，大城市多半也能刷卡。")
        elif t == 3:
            add("國家", pick(f"{name}在哪一洲？", f"{name}是亞洲國家嗎？", f"{name}屬於哪個大洲？"), f"{name}位於{cont}，首都是{cap}。")
        elif t == 4:
            add("國家", pick(f"去{name}玩有什麼特色？", f"{name}有什麼有名的？", f"推薦{name}的景點"), f"{name}有名的有：{sight}。首都{cap}，用{cur}，語言是{lang}。")
        else:
            other = R.choice(COUNTRIES)
            if other[0] == name:
                continue
            same = other[2] == cont
            add("國家比較", f"{name}和{other[0]}在同一個洲嗎？",
                f"{'是' if same else '不是'}。{name}在{cont}，{other[0]}在{other[2]}。" + (f"兩國都用歐元。" if cur == other[4] == "歐元" else ""))

# ─────────── 元素 ───────────
for num, sym, zh, state in ELEMENTS:
    for _ in range(8):
        t = R.randrange(5)
        if t == 0:
            add("元素", pick(f"{zh}的化學符號是什麼？", f"{zh}的元素符號？"), f"{zh}的化學符號是 {sym}，原子序 {num}，常溫下是{state}。")
        elif t == 1:
            add("元素", pick(f"{sym}是什麼元素？", f"化學符號 {sym} 代表什麼？"), f"{sym} 是{zh}，原子序 {num}。")
        elif t == 2:
            add("元素", pick(f"原子序 {num} 是什麼元素？", f"第 {num} 號元素是什麼？"), f"原子序 {num} 是{zh}（{sym}），原子序就是原子核裡的質子數。")
        elif t == 3:
            add("元素", f"{zh}在常溫下是固體、液體還是氣體？", f"{zh}（{sym}）在常溫常壓下是{state}。" + ("常溫是液體的元素只有溴和汞兩種。" if state == "液體" else ""))
        else:
            o = R.choice(ELEMENTS)
            if o[0] == num:
                continue
            big = (zh, num) if num > o[0] else (o[2], o[0])
            add("元素比較", f"{zh}和{o[2]}哪個原子序比較大？", f"{big[0]}比較大（{zh} {num}、{o[2]} {o[0]}）。原子序越大，原子核裡的質子越多。")

# ─────────── 行星 ───────────
for i, (p, kind, fact) in enumerate(PLANETS):
    for q in [f"{p}是第幾顆行星？", f"{p}是什麼樣的行星？", f"{p}有什麼特色？", f"{p}離太陽近還是遠？"]:
        add("行星", q, f"{p}是離太陽第 {i + 1} 近的行星，屬於{kind}：{fact}。太陽系八大行星依序是水星、金星、地球、火星、木星、土星、天王星、海王星。")
    for j, (o, _, _) in enumerate(PLANETS):
        if i != j:
            add("行星比較", f"{p}和{o}哪個離太陽比較近？", f"{p if i < j else o}比較近：{p}是第 {i + 1} 顆、{o}是第 {j + 1} 顆。")
add("行星", "冥王星是行星嗎？", "2006 年國際天文聯合會把冥王星重新分類為「矮行星」，因為它沒有清空自己軌道附近的其他天體，所以太陽系現在是八大行星。")

# ─────────── 動物 ───────────
for name, cls, food, fact in ANIMALS:
    for q, a in [(f"{name}是什麼類的動物？", f"{name}屬於{cls}。{fact}。"), (f"{name}吃什麼？", f"{name}的食性：{food}。{fact}。"),
                 (f"{name}有什麼特別的？", f"{name}：{fact}。牠是{cls}，吃{food}。"), (f"{name}是哺乳類嗎？", f"{'是' if cls.startswith('哺乳') else '不是'}，{name}屬於{cls}。{fact}。")]:
        for v in range(3):
            add("動物", pick(q, "請問" + q, q.rstrip("？") + "呢？"), a)
    for o in R.sample(ANIMALS, 6):
        if o[0] == name:
            continue
        add("動物比較", f"{name}和{o[0]}是同一類動物嗎？",
            f"{'是' if cls.split('（')[0] == o[1].split('（')[0] else '不是'}。{name}是{cls}，{o[0]}是{o[1]}。")

# ─────────── 為什麼 ───────────
for q, a in WHY:
    for v in range(12):
        qq = pick(q, "我一直很好奇，" + q, q + "用簡單的話說", "可以解釋一下" + q.rstrip("？") + "嗎？", "小朋友問我：" + q + "要怎麼回答？", q + "原理是什麼？")
        add("為什麼", qq, a)

# ─────────── 台灣縣市 ───────────
for name, kind, fact in TAIWAN:
    for q in [f"{name}有什麼有名的？", f"{name}是直轄市嗎？", f"去{name}可以去哪裡？"]:
        add("台灣", q, f"{name}是{kind}。{fact}。台灣有 6 個直轄市（台北、新北、桃園、台中、台南、高雄）、3 個市和 13 個縣。")

# ─────────── 日期與時間（用算的） ───────────
D0 = dt.date(1900, 1, 1)
for _ in range(21000):
    d = D0 + dt.timedelta(days=R.randrange(73000))
    t = R.randrange(6)
    if t == 0:
        add("日期", pick(f"{d.year}年{d.month}月{d.day}日是星期幾？", f"{d.year}/{d.month}/{d.day}是禮拜幾？"),
            f"{d.year}年{d.month}月{d.day}日是星期{WEEK[d.weekday()]}。")
    elif t == 1:
        e = d + dt.timedelta(days=R.randrange(1, 4000))
        n = (e - d).days
        add("日期", f"{d.year}年{d.month}月{d.day}日到{e.year}年{e.month}月{e.day}日相差幾天？",
            f"相差 {n} 天（約 {n / 7:.1f} 週、{n / 365.2425:.2f} 年）。算法：把兩個日期都換成從同一天起算的天數再相減，閏年的 2 月 29 日也要算進去。")
    elif t == 2:
        k = R.choice([7, 10, 30, 45, 60, 90, 100, 180, 365, 1000])
        e = d + dt.timedelta(days=k)
        add("日期", f"從{d.year}年{d.month}月{d.day}日算起{k}天後是哪一天？", f"{k} 天後是{e.year}年{e.month}月{e.day}日，星期{WEEK[e.weekday()]}。")
    elif t == 3:
        y = d.year
        leap = (y % 4 == 0 and y % 100 != 0) or y % 400 == 0
        add("日期", pick(f"{y}年是閏年嗎？", f"{y}年二月有幾天？"),
            f"{y}年{'是' if leap else '不是'}閏年，二月有 {29 if leap else 28} 天。規則：能被 4 整除是閏年，但能被 100 整除的不是，除非也能被 400 整除（所以 2000 年是、1900 年不是）。")
    elif t == 4:
        now = d + dt.timedelta(days=R.randrange(3650, 30000))
        age = now.year - d.year - ((now.month, now.day) < (d.month, d.day))
        add("日期", f"{d.year}年{d.month}月{d.day}日出生，到{now.year}年{now.month}月{now.day}日是幾歲？",
            f"足歲 {age} 歲。算法：{now.year} − {d.year} = {now.year - d.year}，" + ("那天還沒過生日要再減 1。" if (now.month, now.day) < (d.month, d.day) else "那天已經過了生日。"))
    else:
        m = d.month
        import calendar
        nd = calendar.monthrange(d.year, m)[1]
        add("日期", f"{d.year}年{m}月有幾天？{m}月1日是星期幾？", f"{d.year}年{m}月有 {nd} 天，{m}月1日是星期{WEEK[dt.date(d.year, m, 1).weekday()]}。")
ZONES = [("台北", 8), ("東京", 9), ("首爾", 9), ("曼谷", 7), ("新加坡", 8), ("新德里", 5.5), ("杜拜", 4), ("莫斯科", 3), ("北京", 8), ("雅加達", 7)]
for _ in range(1500):
    (a, za), (b, zb) = R.sample(ZONES, 2)
    h = R.randrange(24)
    m = R.choice([0, 15, 30, 45])
    t = (h + m / 60 + (zb - za)) % 24
    th, tm = int(t), round((t - int(t)) * 60)
    if tm == 60:
        th, tm = (th + 1) % 24, 0
    diff = zb - za
    add("時區", f"{a}{h}點{m:02d}分的時候，{b}是幾點？",
        f"{b}是 {th}點{tm:02d}分。{a}是 UTC{za:+g}、{b}是 UTC{zb:+g}，{b}比{a}{'快' if diff > 0 else '慢'} {abs(diff):g} 小時（這幾個城市都沒有日光節約時間）。")

# ─────────── 單位換算（用算的） ───────────
CONV = [("公里", "英里", 0.621371), ("英里", "公里", 1.609344), ("公斤", "磅", 2.204623), ("磅", "公斤", 0.45359237), ("英寸", "公分", 2.54),
        ("公分", "英寸", 1 / 2.54), ("英尺", "公分", 30.48), ("公尺", "英尺", 1 / 0.3048), ("公升", "毫升", 1000), ("加侖（美制）", "公升", 3.785411784),
        ("坪", "平方公尺", 3.305785), ("平方公尺", "坪", 0.3025), ("台斤", "公克", 600), ("公斤", "台斤", 1 / 0.6), ("盎司", "公克", 28.349523125),
        ("小時", "分鐘", 60), ("天", "小時", 24), ("公頃", "平方公尺", 10000), ("公噸", "公斤", 1000), ("海里", "公里", 1.852)]
for _ in range(9000):
    a, b, f = R.choice(CONV)
    x = R.choice([R.randint(1, 100), R.randint(1, 1000), round(R.uniform(0.5, 50), 1)])
    y = x * f
    ys = f"{y:,.2f}".rstrip("0").rstrip(".")
    add("換算", pick(f"{x}{a}等於幾{b}？", f"{x}{a}是多少{b}？", f"{x}{a}換成{b}"), f"{x} {a} ≈ {ys} {b}（1 {a} = {f:g} {b}）。")
for _ in range(4000):
    if R.random() < 0.5:
        c = R.randint(-40, 120)
        fh = c * 9 / 5 + 32
        add("溫度", pick(f"攝氏{c}度是華氏幾度？", f"{c}°C 等於幾 °F？"), f"{c}°C = {fh:g}°F。公式：華氏 = 攝氏 × 9/5 + 32。")
    else:
        fh = R.randint(-40, 250)
        c = (fh - 32) * 5 / 9
        add("溫度", pick(f"華氏{fh}度是攝氏幾度？", f"{fh}°F 等於幾 °C？"), f"{fh}°F ≈ {c:.1f}°C。公式：攝氏 = (華氏 − 32) × 5/9。")

# ─────────── 生活計算（用算的） ───────────
ITEMS = ["牛奶", "洗衣精", "衛生紙", "米", "咖啡豆", "洗髮精", "礦泉水", "麥片", "沐浴乳", "醬油"]
for _ in range(7000):
    it = R.choice(ITEMS)
    s1, s2 = R.sample([300, 450, 500, 600, 750, 900, 1000, 1500, 2000, 2500], 2)
    p1, p2 = R.randint(30, 400), R.randint(30, 400)
    u1, u2 = p1 / s1 * 100, p2 / s2 * 100
    better = "A" if u1 < u2 else "B" if u2 < u1 else "一樣"
    add("比價", f"{it}A：{s1}單位賣{p1}元；B：{s2}單位賣{p2}元，哪個比較划算？",
        f"算每 100 單位的價格：A 是 {p1} ÷ {s1} × 100 ≈ {u1:.1f} 元，B 是 {p2} ÷ {s2} × 100 ≈ {u2:.1f} 元，"
        + (f"{better} 比較划算。" if better != "一樣" else "一樣划算。") + "不過也要看用不用得完、會不會過期。")
for _ in range(7000):
    price = R.choice([199, 250, 299, 380, 450, 590, 680, 799, 990, 1280, 1500, 2400, 3600])
    t = R.randrange(4)
    if t == 0:
        z = R.choice([95, 9, 88, 85, 8, 75, 7, 65, 6, 5])
        rate = z / 100 if z > 10 else z / 10
        add("折扣", f"{price}元的東西打{z}折是多少錢？", f"台灣說「打{z}折」是付原價的 {rate * 100:g}%：{price} × {rate:g} = {price * rate:g} 元，省了 {price - price * rate:g} 元。")
    elif t == 1:
        th = R.choice([1000, 2000, 3000])
        off = R.choice([100, 200, 300, 500])
        n = R.randint(1, 6)
        total = price * n
        got = (total // th) * off
        add("折扣", f"買{n}件{price}元的東西，滿{th}送（折）{off}，要付多少？",
            f"總價 {price} × {n} = {total} 元，每滿 {th} 折 {off}：{total} ÷ {th} 取整數 = {total // th}，共折 {got} 元，要付 {total - got} 元。")
    elif t == 2:
        p = R.choice([5, 10, 15, 20, 25, 30])
        add("百分比", f"{price}元漲價{p}%後是多少？", f"{price} × (1 + {p}%) = {price * (1 + p / 100):g} 元。")
    else:
        old, new = price, price + R.randint(-price // 2, price // 2)
        ch = (new - old) / old * 100
        add("百分比", f"從{old}元變成{new}元，變化了百分之幾？", f"(新 − 舊) ÷ 舊 × 100% = ({new} − {old}) ÷ {old} × 100% ≈ {ch:+.1f}%。")
for _ in range(6000):
    t = R.randrange(4)
    if t == 0:
        v = R.choice([4, 5, 12, 15, 30, 40, 60, 80, 90, 100, 110, 300])
        h = R.choice([0.5, 1, 1.5, 2, 2.5, 3, 4, 5])
        add("速度", f"時速{v}公里走{h:g}小時，可以走多遠？", f"距離 = 速度 × 時間 = {v} × {h:g} = {v * h:g} 公里。")
    elif t == 1:
        dist = R.choice([10, 30, 42.195, 60, 120, 200, 350, 400])
        v = R.choice([5, 10, 20, 50, 60, 80, 100, 250, 300])
        tt = dist / v
        add("速度", f"{dist:g}公里的路，時速{v}公里要多久？", f"時間 = 距離 ÷ 速度 = {dist:g} ÷ {v} ≈ {tt:.2f} 小時，約 {int(tt)} 小時 {round((tt - int(tt)) * 60)} 分鐘。")
    elif t == 2:
        P = R.choice([10000, 50000, 100000, 300000, 1000000])
        r = R.choice([1, 1.5, 2, 3, 4, 5, 6])
        n = R.randint(1, 20)
        simple = P * r / 100 * n
        comp = P * (1 + r / 100) ** n - P
        add("利息", f"{P}元年利率{r:g}%，存{n}年，單利和複利各有多少利息？",
            f"單利：{P} × {r:g}% × {n} = {simple:,.0f} 元。複利（每年滾入本金）：{P} × (1 + {r:g}%)^{n} − {P} ≈ {comp:,.0f} 元。時間越長，複利和單利差越多。")
    else:
        a, b = R.randint(2, 12), R.randint(2, 12)
        tt = a * b / (a + b)
        add("工作", f"甲單獨做一件工作要{a}天，乙單獨做要{b}天，兩人一起做要幾天？",
            f"甲一天做 1/{a}，乙一天做 1/{b}，合起來一天做 1/{a} + 1/{b} = {a + b}/{a * b}，所以要 {a * b}/{a + b} ≈ {tt:.2f} 天。")
for _ in range(5000):
    xs = [R.randint(40, 100) for _ in range(R.randint(3, 7))]
    s = sorted(xs)
    med = s[len(s) // 2] if len(s) % 2 else (s[len(s) // 2 - 1] + s[len(s) // 2]) / 2
    add("平均", f"分數{'、'.join(map(str, xs))}，平均和中位數是多少？",
        f"平均 = ({' + '.join(map(str, xs))}) ÷ {len(xs)} = {sum(xs)} ÷ {len(xs)} ≈ {sum(xs) / len(xs):.2f}。中位數：由小到大排成 {'、'.join(map(str, s))}，中間的是 {med:g}。")
for _ in range(4000):
    a, b = R.randint(1, 9), R.randint(1, 9)
    tot = R.randint(2, 20) * (a + b)
    add("比例", f"{tot}元按照{a}:{b}分給兩個人，各分多少？", f"總共 {a + b} 份，一份 {tot} ÷ {a + b} = {tot // (a + b)} 元；一個人 {a} 份 = {tot // (a + b) * a} 元，另一個人 {b} 份 = {tot // (a + b) * b} 元。")


# ─────────── 推理（用算的，附步驟） ───────────
from fractions import Fraction
for _ in range(6000):
    ch, rb = R.randint(1, 40), R.randint(1, 40)
    heads, legs = ch + rb, ch * 2 + rb * 4
    add("推理", f"雞和兔關在一起，共有{heads}個頭、{legs}隻腳，雞和兔各幾隻？",
        f"假設全部都是雞，腳會有 {heads} × 2 = {heads * 2} 隻，比實際少 {legs} − {heads * 2} = {legs - heads * 2} 隻。"
        f"每把一隻雞換成兔多 2 隻腳，所以兔有 {legs - heads * 2} ÷ 2 = {rb} 隻，雞有 {heads} − {rb} = {ch} 隻。驗算：{ch}×2 + {rb}×4 = {legs}。")
PEOPLE = ["小明", "小華", "小美", "阿傑", "小芳", "志明", "春嬌", "大雄", "小玲", "阿豪", "子軒", "思妤"]
ADJ = [("高", "矮"), ("大", "小"), ("快", "慢"), ("重", "輕"), ("早到", "晚到")]
for _ in range(15000):
    n = R.randint(3, 7)
    ps = R.sample(PEOPLE, n)          # 由最 X 到最不 X
    hi, lo = R.choice(ADJ)
    pairs = [(ps[i], ps[i + 1]) for i in range(n - 1)]
    R.shuffle(pairs)
    facts = "，".join(f"{a}比{b}{hi}" for a, b in pairs)
    k = R.randrange(n)
    ask = R.choice(["最" + hi, "最" + lo, f"第{k + 1}{hi}"])
    ans = ps[0] if ask == "最" + hi else ps[-1] if ask == "最" + lo else ps[k]
    add("推理", f"{facts}。誰{ask}？",
        f"把關係串起來排成一列（由{hi}到{lo}）：{' > '.join(ps)}。所以{ask}的是{ans}。")
CATS = [("貓", "哺乳類", "動物"), ("玫瑰", "花", "植物"), ("麻雀", "鳥", "動物"), ("鯊魚", "魚", "動物"), ("蘋果", "水果", "食物"),
        ("鋼琴", "樂器", "物品"), ("鐵", "金屬", "元素"), ("台北", "城市", "地方"), ("醫生", "醫療人員", "人"), ("松樹", "樹", "植物")]
FORMS = [
    ("所有{a}都是{b}，所有{b}都是{c}，所以所有{a}都是{c}。這樣推對嗎？", True, "對。這是標準的三段論：{a}包含在{b}裡，{b}包含在{c}裡，所以{a}一定包含在{c}裡。"),
    ("所有{a}都是{b}，所以所有{b}都是{a}。對嗎？", False, "不對。「所有{a}都是{b}」不能倒過來說；例如所有{a}都是{b}，但{b}不只有{a}。"),
    ("所有{a}都是{b}，X 不是{b}，所以 X 不是{a}。對嗎？", True, "對。如果 X 是{a}，它就一定是{b}；X 不是{b}，所以 X 不可能是{a}（否定後件）。"),
    ("所有{a}都是{b}，X 是{b}，所以 X 是{a}。對嗎？", False, "不對（肯定後件的謬誤）。X 是{b}不代表 X 是{a}，{b}裡還有很多不是{a}的東西。"),
    ("所有{a}都是{b}，X 不是{a}，所以 X 不是{b}。對嗎？", False, "不對（否定前件的謬誤）。X 不是{a}，還是可能是別種{b}。"),
    ("有些{b}是{a}，所以有些{a}是{b}。對嗎？", True, "對。「有些{b}是{a}」代表至少有一個東西同時是{b}和{a}，倒過來說也成立。"),
]
for _ in range(5000):
    a, b, c = R.choice(CATS)
    f, ok, why = R.choice(FORMS)
    add("邏輯", f.format(a=a, b=b, c=c), why.format(a=a, b=b, c=c))
for _ in range(7000):
    t = R.randrange(4)
    if t == 0:
        a, d = R.randint(-20, 50), R.choice([2, 3, 4, 5, 6, 7, 9, 11, -3, -5])
        xs = [a + d * i for i in range(5)]
        add("數列", f"{'、'.join(map(str, xs))}，下一個是多少？", f"每次都{'加' if d > 0 else '減'} {abs(d)}（等差數列），所以下一個是 {xs[-1]} {'+' if d > 0 else '−'} {abs(d)} = {xs[-1] + d}。")
    elif t == 1:
        a, r = R.randint(1, 9), R.choice([2, 3, 4, 5])
        xs = [a * r ** i for i in range(5)]
        add("數列", f"{'、'.join(map(str, xs))}，下一個是多少？", f"每次都乘 {r}（等比數列），所以下一個是 {xs[-1]} × {r} = {xs[-1] * r}。")
    elif t == 2:
        a, b = R.randint(1, 9), R.randint(1, 9)
        xs = [a, b]
        for _ in range(4):
            xs.append(xs[-1] + xs[-2])
        add("數列", f"{'、'.join(map(str, xs))}，下一個是多少？", f"每一項都是前兩項相加（像費氏數列），所以下一個是 {xs[-2]} + {xs[-1]} = {xs[-2] + xs[-1]}。")
    else:
        k = R.randint(1, 6)
        xs = [(i + k) ** 2 for i in range(5)]
        add("數列", f"{'、'.join(map(str, xs))}，下一個是多少？", f"這些是連續整數的平方：{'、'.join(f'{i + k}²' for i in range(5))}，下一個是 {k + 5}² = {(k + 5) ** 2}。")
for _ in range(5000):
    t = R.randrange(4)
    if t == 0:
        s = R.randint(2, 12)
        ways = sum(1 for i in range(1, 7) for j in range(1, 7) if i + j == s)
        fr = Fraction(ways, 36)
        add("機率", f"丟兩顆骰子，點數和是{s}的機率是多少？", f"兩顆骰子共有 6 × 6 = 36 種結果，和是 {s} 的有 {ways} 種，機率是 {ways}/36 = {fr}（約 {ways / 36 * 100:.1f}%）。")
    elif t == 1:
        n = R.randint(1, 8)
        add("機率", f"連丟{n}次硬幣，全部都是正面的機率？", f"每次正面的機率是 1/2，各次互不影響，所以是 (1/2)^{n} = 1/{2 ** n}（約 {100 / 2 ** n:.2f}%）。")
    elif t == 2:
        r, b = R.randint(1, 10), R.randint(1, 10)
        fr = Fraction(r, r + b)
        add("機率", f"袋子裡有{r}顆紅球、{b}顆藍球，隨便拿一顆是紅球的機率？", f"紅球 {r} 顆、總共 {r + b} 顆，機率是 {r}/{r + b} = {fr}（約 {r / (r + b) * 100:.1f}%）。")
    else:
        n = R.randint(1, 5)
        add("機率", f"丟一顆骰子{n}次，至少出現一次6的機率？", f"先算一次都沒出現 6：(5/6)^{n} ≈ {(5 / 6) ** n:.4f}，所以至少一次的機率是 1 − {(5 / 6) ** n:.4f} ≈ {1 - (5 / 6) ** n:.4f}（約 {(1 - (5 / 6) ** n) * 100:.1f}%）。")
import math
for _ in range(6000):
    t = R.randrange(5)
    if t == 0:
        l, w = R.randint(2, 50), R.randint(2, 50)
        add("幾何", f"長{l}公分、寬{w}公分的長方形，面積和周長是多少？", f"面積 = 長 × 寬 = {l} × {w} = {l * w} 平方公分；周長 = (長 + 寬) × 2 = ({l} + {w}) × 2 = {(l + w) * 2} 公分。")
    elif t == 1:
        r = R.randint(1, 30)
        add("幾何", f"半徑{r}公分的圓，面積和圓周長大約多少？", f"面積 = π × r² ≈ 3.14159 × {r}² ≈ {math.pi * r * r:.2f} 平方公分；圓周長 = 2 × π × r ≈ {2 * math.pi * r:.2f} 公分。")
    elif t == 2:
        b, h = R.randint(2, 40), R.randint(2, 40)
        add("幾何", f"底{b}公分、高{h}公分的三角形，面積是多少？", f"三角形面積 = 底 × 高 ÷ 2 = {b} × {h} ÷ 2 = {b * h / 2:g} 平方公分。")
    elif t == 3:
        a, b = R.randint(3, 30), R.randint(3, 30)
        c = math.hypot(a, b)
        add("幾何", f"直角三角形兩股是{a}和{b}，斜邊多長？", f"畢氏定理：斜邊² = {a}² + {b}² = {a * a + b * b}，斜邊 = √{a * a + b * b} ≈ {c:.3f}。")
    else:
        x, y, z = R.randint(1, 20), R.randint(1, 20), R.randint(1, 20)
        add("幾何", f"長{x}、寬{y}、高{z}公分的箱子，容積是多少？可以裝多少公升？", f"體積 = {x} × {y} × {z} = {x * y * z} 立方公分；1 公升 = 1000 立方公分，約 {x * y * z / 1000:g} 公升。")

seen = set()
out = [it for it in out if not ((it["q"], it["a"]) in seen or seen.add((it["q"], it["a"])))]
R.shuffle(out)
total = 0
with open(sys.argv[1], "w", encoding="utf-8") as f:
    for i, it in enumerate(out):
        it["id"] = f"world-{i:06d}"
        total += len(it["q"]) + len(it["a"])
        f.write(json.dumps(it, ensure_ascii=False) + "\n")
print(len(out), "題，", total, "字")
