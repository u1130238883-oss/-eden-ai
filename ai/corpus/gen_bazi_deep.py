#!/usr/bin/env python3
"""八字看盤、解盤、解運勢（至少 5,000,000 字）＋考題。

盤和解讀來自 NineSun 自己的程式（EchoCoreTests.FortuneDeepExport → deep.jsonl）：
- 四柱十神（每一柱的天干、地支藏干對日主是什麼）、身強身弱、喜用神
- 大運：每一步大運的年齡、干支、十神、對你是喜是忌
- 流年：連續幾年的流年，和「哪一年比較好」的比較
- 流月：整年十二個月
- 主題：感情、錢財、事業、學業、家庭

python3 gen_bazi_deep.py deep.jsonl 輸出.jsonl 考題.jsonl [目標字數]
"""
import hashlib
import json
import random
import re
import sys

R = random.Random(5_000_000)
STEMS = list("甲乙丙丁戊己庚辛壬癸")
BR = list("子丑寅卯辰巳午未申酉戌亥")
ANIMALS = list("鼠牛虎兔龍蛇馬羊猴雞狗豬")
WX = ["木", "火", "土", "金", "水"]
STEM_EL = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4]
BR_EL = [4, 2, 0, 0, 2, 1, 1, 2, 3, 3, 2, 4]
# 地支本氣（主氣）藏干
BR_MAIN = [9, 5, 0, 1, 4, 2, 3, 5, 6, 7, 4, 8]
BR_HIDDEN = {0: [9], 1: [5, 9, 7], 2: [0, 2, 4], 3: [1], 4: [4, 1, 9], 5: [2, 4, 6], 6: [3, 5], 7: [5, 3, 1],
             8: [6, 8, 4], 9: [7], 10: [4, 7, 3], 11: [8, 0]}
GODS_SAME = ["比肩", "劫財"]
GOD_MEAN = {
    "比肩": "自己、兄弟朋友、同輩競爭，代表自主和堅持", "劫財": "朋友、競爭者、合夥，容易分錢也能互相支援",
    "食神": "才華、口福、享受、表達，心態放鬆", "傷官": "才華外露、創意、叛逆，敢說敢挑戰規則",
    "偏財": "外財、機會財、交際、父親；男命也代表感情", "正財": "穩定收入、薪水、務實；男命代表妻子",
    "七殺": "壓力、挑戰、魄力、權威；女命也代表感情", "正官": "規矩、名聲、工作職位、責任；女命代表丈夫",
    "偏印": "偏門學問、靈感、獨處、想法特別", "正印": "長輩、貴人、學業、照顧、證照",
}


def gz(i):
    return STEMS[i % 10] + BR[i % 12]


def god(dm, stem):
    """十神：日主 dm 看天干 stem"""
    a, b = STEM_EL[dm], STEM_EL[stem]
    same = (dm % 2) == (stem % 2)
    rel = (b - a) % 5
    return [["比肩", "劫財"], ["食神", "傷官"], ["偏財", "正財"], ["七殺", "正官"], ["偏印", "正印"]][rel][0 if same else 1]


out, exam = [], []


def add(topic, q, a):
    out.append({"cat": "bazi_deep", "topic": topic, "q": q, "a": a})


def who(c):
    sex = "男" if c["male"] else "女"
    return R.choice([f"我是{c['y']}年{c['m']}月{c['d']}日{c['h']}點{c['mi']:02d}分出生的{sex}生", f"{sex}，國曆{c['y']}/{c['m']}/{c['d']} {c['h']}:{c['mi']:02d}出生",
                     f"{c['y']}年{c['m']}月{c['d']}日{c['h']}點生，{sex}", f"生日{c['y']}-{c['m']:02d}-{c['d']:02d}，{c['h']}點{c['mi']}分，{sex}",
                     f"八字{'　'.join(gz(p) for p in c['pillars'])}，{sex}命"])


def ten_gods(c):
    P = c["pillars"]
    dm = c["dayMaster"]
    names = ["年柱", "月柱", "日柱", "時柱"]
    lines = []
    for i, p in enumerate(P):
        s, b = p % 10, p % 12
        hid = "、".join(f"{STEMS[h]}（{god(dm, h)}）" for h in BR_HIDDEN[b])
        top = "日主（你自己）" if i == 2 else god(dm, s)
        lines.append(f"{names[i]}{gz(p)}：天干{STEMS[s]}{WX[STEM_EL[s]]}是{top}；地支{BR[b]}{WX[BR_EL[b]]}，藏干{hid}。")
    return lines


def count_el(c):
    n = [0] * 5
    for p in c["pillars"]:
        n[STEM_EL[p % 10]] += 1
        n[BR_EL[p % 12]] += 1
    return n


TEASE = ["", "", "", "好，盤我幫你攤開來看。", "來，別緊張，盤又不會咬人。", "行，直接講重點。", "看盤不看玄的，照算出來的講。"]

charts = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")]
target = int(sys.argv[4]) if len(sys.argv) > 4 else 5_200_000
total = 0
for c in charts:
    if total >= target:
        break
    w = who(c)
    P = c["pillars"]
    dm = c["dayMaster"]
    fav = [WX[e] for e in c["favorable"]]
    avoid = [WX[e] for e in range(5) if e not in c["favorable"]]
    strong = "身強" if c["strong"] else "身弱"
    els = count_el(c)
    start = len(out)

    # 四柱十神
    tg = ten_gods(c)
    add("八字十神", R.choice([f"{w}，四柱的十神各是什麼？", f"幫我把八字每一柱的十神列出來：{w}", f"{w}，我的八字十神怎麼看？"]),
        R.choice(TEASE) + "十神都是拿日主（日柱天干）去比：\n" + "\n".join(tg)
        + f"\n日主是{STEMS[dm]}{WX[STEM_EL[dm]]}。十神的意思：" + "；".join(f"{g}＝{GOD_MEAN[g]}" for g in dict.fromkeys(
            [god(dm, p % 10) for i, p in enumerate(P) if i != 2] + [god(dm, BR_MAIN[p % 12]) for p in P])) + "。")

    # 五行、身強弱、喜用
    elline = "、".join(f"{WX[i]}{els[i]}" for i in range(5))
    miss = [WX[i] for i in range(5) if els[i] == 0]
    add("八字五行喜用", R.choice([f"{w}，我五行缺什麼？喜用神是什麼？", f"{w}，我是身強還是身弱？", f"幫我看五行和喜用神：{w}"]),
        f"四柱八個字的五行（天干＋地支本氣）：{elline}。" + (f"表面上缺{'、'.join(miss)}，" if miss else "五行都有，")
        + f"但缺什麼不等於要補什麼，要看日主強弱。\n日主{STEMS[dm]}{WX[STEM_EL[dm]]}，{strong}："
        + ("自己的力量夠，需要洩、需要用，喜" if c["strong"] else "力量不夠，需要被生、被幫，喜") + "、".join(fav)
        + "，忌" + "、".join(avoid) + "。\n生活上：多接觸喜用的五行（顏色、方位、行業、作息），遇到忌神的年份要穩一點。")

    # 大運
    seq = c["luck"]
    ls = c["luckStart"]
    rows = []
    for k, g in enumerate(seq):
        a0 = ls + 10 * k
        s, b = g % 10, g % 12
        good = (STEM_EL[s] in c["favorable"]) + (BR_EL[b] in c["favorable"])
        mood = ["偏辛苦", "有好有壞", "比較順"][good]
        rows.append(f"{a0}–{a0 + 9}歲 {gz(g)}：{STEMS[s]}＝{god(dm, s)}、{BR[b]}＝{god(dm, BR_MAIN[b])}，五行{WX[STEM_EL[s]]}{WX[BR_EL[b]]}，{mood}")
    add("八字大運", R.choice([f"{w}，我的大運怎麼走？", f"{w}，每十年的大運幫我列出來", f"幫我看大運：{w}"]),
        f"{c['luckStart']}歲起運，每十年換一步：\n" + "\n".join(rows) + f"\n判斷方法：大運的干支是喜用神（{'、'.join(fav)}）就順，是忌神就辛苦；地支管得比較重。")
    k = R.randrange(len(seq))
    a0 = ls + 10 * k
    add("八字大運", f"{w}，我{a0 + R.randrange(10)}歲那幾年的大運怎麼樣？", rows[k] + "。" + "這步大運的重點：" + GOD_MEAN[god(dm, seq[k] % 10)] + "；" + GOD_MEAN[god(dm, BR_MAIN[seq[k] % 12])] + "。")

    # 流年（每一年）
    yrs = sorted(c["bazi_years"], key=int)
    for y in yrs:
        add("八字流年", R.choice([f"{w}，{y}年運勢怎麼樣？", f"幫我看{y}年流年：{w}", f"{y}年對我好不好？{w}", f"{w}，{y}年要注意什麼？"]), c["bazi_years"][y])
    # 哪一年比較好
    vs = {y: c["bazi_verdicts"][y] for y in yrs}
    good = [y for y in yrs if vs[y] == "good"]
    bad = [y for y in yrs if vs[y] == "bad"]
    if len(yrs) >= 3:
        add("八字流年比較", R.choice([f"{w}，{yrs[0]}到{yrs[-1]}年哪一年最好？", f"{w}，接下來幾年哪年適合衝、哪年要守？"]),
            "照流年干支對你的喜忌：" + "；".join(f"{y}年{gz(int(y) - 4)}" + {"good": "偏順", "bad": "偏辛苦", "neutral": "持平"}[vs[y]] for y in yrs) + "。"
            + (f"適合衝的是{'、'.join(good)}年；" if good else "沒有特別順的年份，穩穩來；") + (f"要守的是{'、'.join(bad)}年。" if bad else "沒有特別差的年份。"))

    # 流月
    for mm in R.sample(range(12), 6):
        add("八字流月", R.choice([f"{w}，{c['now']}年{mm + 1}月運勢？", f"{w}，{c['now']}年{mm + 1}月適合做決定嗎？"]), c["bazi_months"][mm])

    # 主題
    for t, txt in c["bazi_topics"].items():
        add("八字主題", R.choice([f"{w}，{c['now']}年{t}運如何？", f"幫我用八字看{t}：{w}", f"{w}，我的{t}怎麼樣？"]), txt)

    # 本命
    add("八字解盤", R.choice([f"{w}，幫我看八字本命", f"幫我解盤：{w}", f"{w}，我是什麼樣的命？"]), c["bazi_natal"])

    total += sum(len(it["q"]) + len(it["a"]) for it in out[start:])

    # 考題：流年（看大腦能不能講出流年的十神、說出順或辛苦）、十神、哪年比較好
    if R.random() < 0.06:
        y = R.choice(yrs)
        t = c["bazi_years"][y]
        line = t.split("\n")[2] if len(t.split("\n")) > 2 else ""
        gods = [g for g in GOD_MEAN if g in line]
        exam.append({"q": f"我{y}年的八字流年怎麼樣？", "reading": t, "expect": [gods or ["運"]], "kind": "八字流年"})
    if R.random() < 0.03:
        p = P[R.choice([0, 1, 3])]
        g = god(dm, p % 10)
        exam.append({"q": f"我的八字是{'　'.join(gz(x) for x in P)}，日主{STEMS[dm]}，{gz(p)}這一柱的天干是什麼十神？只回答十神。",
                     "expect": [[g]], "kind": "十神", "maxlen": 80})

seen = set()
out = [it for it in out if not ((it["q"], it["a"]) in seen or seen.add((it["q"], it["a"])))]
R.shuffle(out)
total = 0
with open(sys.argv[2], "w", encoding="utf-8") as f:
    for i, it in enumerate(out):
        it["id"] = f"bzd-{i:06d}"
        total += len(it["q"]) + len(it["a"])
        f.write(json.dumps(it, ensure_ascii=False) + "\n")
kinds = {}
for it in out:
    kinds[it["topic"]] = kinds.get(it["topic"], 0) + 1
print(len(out), "題，", total, "字", kinds)
with open(sys.argv[3], "w", encoding="utf-8") as f:
    for i, e in enumerate(exam):
        e.update({"id": f"bzx-{i:04d}", "cat": "bazi_deep", "lang": "zh"})
        if "reading" in e:
            e["forbid"] = ["【命盤推算結果】"]
        e["split"] = "hold" if int(hashlib.md5(e["id"].encode()).hexdigest(), 16) % 4 == 0 else "dev"
        f.write(json.dumps(e, ensure_ascii=False) + "\n")
print(len(exam), "題考題")
