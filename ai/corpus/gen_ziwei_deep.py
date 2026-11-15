#!/usr/bin/env python3
"""紫微斗數排盤、看盤、解盤、解運勢（至少 10,000,000 字）＋考題。

盤和解讀來自 NineSun 自己的程式（EchoCoreTests.FortuneDeepExport → deep.jsonl）：
- 安星：十四主星（紫微系、天府系）怎麼從紫微星推出來、每顆星在哪一宮
- 宮干、十二宮速覽、本命四化
- 十二宮逐宮解讀（含流年盤上變成哪一宮）
- 大限：每個十年
- 流年：連續幾年；流年四化看流年盤（流年命宮起逆排十二宮），括號附本命宮位
  例：2026 丙午年流年命宮在午，廉貞在子 → 廉貞化忌在流年遷移宮（本命田宅宮）
- 流月：斗君起正月

python3 gen_ziwei_deep.py deep.jsonl 輸出.jsonl 考題.jsonl [目標字數]
"""
import hashlib
import json
import random
import sys

R = random.Random(10_000_001)
STEMS = list("甲乙丙丁戊己庚辛壬癸")
BR = list("子丑寅卯辰巳午未申酉戌亥")
PAL = ["命宮", "兄弟", "夫妻", "子女", "財帛", "疾厄", "遷移", "交友", "官祿", "田宅", "福德", "父母"]
SIHUA = {"甲": ["廉貞", "破軍", "武曲", "太陽"], "乙": ["天機", "天梁", "紫微", "太陰"], "丙": ["天同", "天機", "文昌", "廉貞"],
         "丁": ["太陰", "天同", "天機", "巨門"], "戊": ["貪狼", "太陰", "右弼", "天機"], "己": ["武曲", "貪狼", "天梁", "文曲"],
         "庚": ["太陽", "武曲", "太陰", "天同"], "辛": ["巨門", "太陽", "文曲", "文昌"], "壬": ["天梁", "紫微", "左輔", "武曲"],
         "癸": ["破軍", "巨門", "太陰", "貪狼"]}
HUA = ["化祿", "化權", "化科", "化忌"]
ZW_SERIES = [("紫微", 0), ("天機", -1), ("太陽", -3), ("武曲", -4), ("天同", -5), ("廉貞", -8)]
TF_SERIES = [("天府", 0), ("太陰", 1), ("貪狼", 2), ("巨門", 3), ("天相", 4), ("天梁", 5), ("七殺", 6), ("破軍", 10)]
MAIN = [s for s, _ in ZW_SERIES] + [s for s, _ in TF_SERIES]
PALTEXT = {}


def pn(p):
    return p if p.endswith("宮") else p + "宮"


def year_palace(lb, b):
    return PAL[(lb - b) % 12]


out, exam = [], []


def add(topic, q, a):
    out.append({"cat": "ziwei_deep", "topic": topic, "q": q, "a": a})


def who(c):
    sex = "男" if c["male"] else "女"
    return R.choice([f"我是{c['y']}年{c['m']}月{c['d']}日{c['h']}點出生的{sex}生", f"{sex}，國曆{c['y']}/{c['m']}/{c['d']} {c['h']}點出生",
                     f"{c['y']}年{c['m']}月{c['d']}日{c['h']}點生，{sex}", f"生日{c['y']}-{c['m']:02d}-{c['d']:02d} {c['h']}點，{sex}"])


def stars_at(c, b):
    m = c["zw_main"][b]
    a = c["zw_aux"][b]
    hua = c["zw_sihua"]
    s = "、".join(x + hua.get(x, "") for x in m) if m else "空宮（借對宮" + "、".join(c["zw_main"][(b + 6) % 12]) + "）"
    if a:
        s += "，輔星" + "、".join(x + hua.get(x, "") for x in a)
    return s


charts = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")]
target = int(sys.argv[4]) if len(sys.argv) > 4 else 10_300_000
total = 0
for c in charts:
    if total >= target:
        break
    start = len(out)
    w = who(c)
    pa = c["zw_palaceAt"]
    st = c["zw_stars"]
    zwb = st["紫微"]
    tfb = st["天府"]
    ming = c["ming"]
    for p, txt in c["zw_palaces"].items():
        PALTEXT.setdefault(p, txt.split("\n")[0].split("】")[-1].split("管", 1)[-1])

    # 安星：十四主星
    zl = "；".join(f"{s}在{BR[(zwb + o) % 12]}" for s, o in ZW_SERIES)
    tl = "；".join(f"{s}在{BR[(tfb + o) % 12]}" for s, o in TF_SERIES)
    add("紫微安主星", R.choice([f"{w}，十四主星怎麼安？一步一步說", f"{w}，紫微在{BR[zwb]}，其他主星在哪？", f"教我安十四主星：{w}"]),
        f"先用生日和五行局找到紫微星：紫微在{BR[zwb]}宮。\n"
        f"① 紫微系（從紫微往逆時針數）：紫微、隔一宮天機、空一宮、太陽、武曲、天同、空兩宮、廉貞 → {zl}。\n"
        f"② 天府和紫微以寅申為軸對稱：紫微在{BR[zwb]}，天府就在{BR[tfb]}。\n"
        f"③ 天府系（從天府往順時針數）：天府、太陰、貪狼、巨門、天相、天梁、七殺，空三宮後破軍 → {tl}。\n"
        f"排好之後每一宮的主星：" + "；".join(f"{pn(pa[b])}（{BR[b]}）{'、'.join(c['zw_main'][b]) or '空宮'}" for b in [(ming - i) % 12 for i in range(12)]) + "。")
    s1 = R.choice(MAIN)
    add("紫微安主星", f"{w}，我的{s1}在哪一宮？", f"{s1}在{BR[st[s1]]}宮，是你本命的{pn(pa[st[s1]])}（{stars_at(c, st[s1])}）。")

    # 宮干、十二宮速覽
    ys = c["yearStem"]
    add("紫微宮干", R.choice([f"{w}，十二宮的宮干怎麼排？", f"{w}，我命宮的天干是什麼？"]),
        f"宮干用五虎遁：生年天干{STEMS[ys]}，寅宮起{STEMS[(ys % 5 * 2 + 2) % 10]}寅，順著排下去：\n"
        + "、".join(f"{BR[b]}宮{STEMS[c['zw_stemAt'][b]]}{BR[b]}（{pn(pa[b])}）" for b in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 1])
        + f"。\n命宮在{BR[ming]}，宮干是{STEMS[c['zw_stemAt'][ming]]}。")
    add("紫微十二宮", R.choice([f"{w}，十二宮各有什麼星？", f"{w}，把我的紫微命盤十二宮列出來"]),
        "從命宮逆時針排：\n" + "\n".join(f"{pn(pa[b])}（{STEMS[c['zw_stemAt'][b]]}{BR[b]}）：{stars_at(c, b)}" for b in [(ming - i) % 12 for i in range(12)]))

    # 本命四化
    nh = SIHUA[STEMS[ys]]
    add("紫微本命四化", R.choice([f"{w}，我的本命四化在哪？", f"{w}，生年四化怎麼看？"]),
        f"生年天干{STEMS[ys]}，{STEMS[ys]}干四化是{'、'.join(s + h for s, h in zip(nh, HUA))}：\n"
        + "\n".join(f"· {s}{h}在{BR[st[s]]}宮，本命{pn(pa[st[s]])}" + {"化祿": "：天生在這裡有資源、有福氣。", "化權": "：這方面你想掌控、比較有主導權。",
                                                              "化科": "：這方面有好名聲、有貴人。", "化忌": "：一生在這方面比較執著、容易有缺憾，是要修的課題。"}[h]
                    for s, h in zip(nh, HUA) if s in st))

    # 十二宮逐宮解讀
    for p, txt in c["zw_palaces"].items():
        add("紫微宮位", R.choice([f"{w}，紫微看我的{pn(p)}", f"幫我看{pn(p)}：{w}", f"{w}，我的{pn(p)}好不好？"]), txt)

    # 大限
    dec = c["zw_decades"]
    if c["male"] is not None:
        rows = [f"{a}–{b}歲：{BR[br]}宮，本命{pn(pa[br])}（{stars_at(c, br)}）" for br, a, b in dec if a <= 90]
        add("紫微大限", R.choice([f"{w}，我的紫微大限怎麼走？", f"{w}，每個十年的大限列出來"]),
            f"大限從命宮起，{c['ju']}歲開始，每十年一宮；陽男陰女順行、陰男陽女逆行。你是{'陽' if ys % 2 == 0 else '陰'}年生的{'男' if c['male'] else '女'}生，所以{'順' if (ys % 2 == 0) == c['male'] else '逆'}行：\n" + "\n".join(rows))
        br, a, b = R.choice([d for d in dec if d[1] <= 80])
        p = pa[br]
        add("紫微大限", f"{w}，我{R.randint(a, b)}歲那個大限怎麼樣？",
            f"{a}–{b}歲走{BR[br]}宮，也就是本命{pn(p)}（{stars_at(c, br)}）。這十年的主軸是{PALTEXT.get(p, '')}")

    # 流年（每一年），流年四化看流年盤
    for y, txt in c["zw_years"].items():
        add("紫微流年", R.choice([f"{w}，紫微看{y}年流年", f"{y}年紫微運勢：{w}", f"{w}，紫微斗數{y}年怎麼樣？"]), txt)
        hua = c["zw_yearhua"][y]
        lb = (int(y) - 4) % 12
        g = STEMS[(int(y) - 4) % 10]
        lines = [f"{s}{h}在{BR[st[s]]}宮：流年{pn(yp)}（本命{pn(np)}）" for h, s, yp, np in hua if yp]
        add("紫微流年四化", R.choice([f"{w}，{y}年的流年四化落在哪幾宮？", f"{w}，{y}年化忌在哪一宮？", f"{y}年{g}干四化在我盤上哪裡？{w}"]),
            f"{y}年是{g}{BR[lb]}年，流年命宮在{BR[lb]}宮（本命{pn(pa[lb])}）。流年盤從流年命宮起逆時針排：{BR[lb]}流年命宮、{BR[(lb - 1) % 12]}流年兄弟、{BR[(lb - 2) % 12]}流年夫妻……\n"
            f"{g}干四化：{'、'.join(s + h for h, s, _, _ in hua)}。\n" + "\n".join("· " + l for l in lines)
            + "\n看流年要用流年盤的宮位，本命宮位是背景：兩個都被引動。")
        ji = [x for x in hua if x[0] == "化忌" and x[2]]
        if ji:
            h, s, yp, np = ji[0]
            opp = year_palace(lb, (st[s] + 6) % 12)
            add("紫微流年四化", f"{w}，{y}年{s}化忌是在流年{pn(yp)}還是本命{pn(np)}？",
                f"兩個都對，看的角度不同：{y}年流年命宮在{BR[lb]}，{s}在{BR[st[s]]}宮，排在流年盤是流年{pn(yp)}；本命盤上同一宮是{pn(np)}。"
                f"論流年吉凶先看流年{pn(yp)}，再看本命{pn(np)}被引動。化忌沖對宮流年{pn(opp)}，這方面也會被牽動。")

    # 流年宮位換算
    y = R.choice(list(c["zw_years"]))
    lb = (int(y) - 4) % 12
    b = R.randrange(12)
    add("紫微流年宮位", f"{w}，{y}年流年命宮在{BR[lb]}，我本命的{pn(pa[b])}是流年的哪一宮？",
        f"流年盤從流年命宮{BR[lb]}起逆時針排命宮、兄弟、夫妻、子女、財帛、疾厄、遷移、交友、官祿、田宅、福德、父母。"
        f"本命{pn(pa[b])}在{BR[b]}宮，從{BR[lb]}數到{BR[b]}是第{(lb - b) % 12 + 1}宮，所以是流年{pn(year_palace(lb, b))}。")

    # 流月
    add("紫微流月", R.choice([f"{w}，紫微看{c['zw_month_date'][0]}年{c['zw_month_date'][1]}月", f"{w}，這個月紫微流月怎麼樣？"]), c["zw_month"])

    # 本命
    if c.get("zw_natal"):
        add("紫微解盤", R.choice([f"{w}，幫我看紫微命盤", f"紫微斗數解盤：{w}", f"{w}，我的命宮主星代表什麼？"]), c["zw_natal"])

    total += sum(len(it["q"]) + len(it["a"]) for it in out[start:])

    # 考題：流年四化落在流年盤的哪一宮（使用者抓到的錯）、宮位、安星
    if R.random() < 0.07:
        y = R.choice(list(c["zw_years"]))
        hua = c["zw_yearhua"][y]
        ji = [x for x in hua if x[0] == "化忌" and x[2]]
        if ji:
            exam.append({"q": f"紫微斗數{y}年我的化忌在哪一宮？", "reading": c["zw_years"][y],
                         "expect": [["流年" + ji[0][2], "流年" + pn(ji[0][2])], [ji[0][1]]], "kind": "流年化忌"})
    if R.random() < 0.03:
        y = R.choice(list(c["zw_years"]))
        lu = [x for x in c["zw_yearhua"][y] if x[0] == "化祿" and x[2]]
        if lu:
            exam.append({"q": f"紫微看{y}年，我哪方面最順？", "reading": c["zw_years"][y],
                         "expect": [["流年" + lu[0][2], "流年" + pn(lu[0][2])]], "kind": "流年化祿"})
    if R.random() < 0.03:
        p = R.choice(["夫妻", "財帛", "官祿", "遷移", "田宅", "福德"])
        b = c["zw_palaces"][p]
        stars = [s for s in MAIN if s in b.split("\n")[1]] if len(b.split("\n")) > 1 else []
        if stars:
            exam.append({"q": f"紫微斗數看我的{pn(p)}怎麼樣？", "reading": b, "expect": [stars], "kind": "宮位"})

seen = set()
out = [it for it in out if not ((it["q"], it["a"]) in seen or seen.add((it["q"], it["a"])))]
R.shuffle(out)
total = 0
with open(sys.argv[2], "w", encoding="utf-8") as f:
    for i, it in enumerate(out):
        it["id"] = f"zwd-{i:06d}"
        total += len(it["q"]) + len(it["a"])
        f.write(json.dumps(it, ensure_ascii=False) + "\n")
kinds = {}
for it in out:
    kinds[it["topic"]] = kinds.get(it["topic"], 0) + 1
print(len(out), "題，", total, "字", kinds)
with open(sys.argv[3], "w", encoding="utf-8") as f:
    for i, e in enumerate(exam):
        e.update({"id": f"zwx-{i:04d}", "cat": "ziwei_deep", "lang": "zh", "forbid": ["【命盤推算結果】"]})
        e["split"] = "hold" if int(hashlib.md5(e["id"].encode()).hexdigest(), 16) % 4 == 0 else "dev"
        f.write(json.dumps(e, ensure_ascii=False) + "\n")
print(len(exam), "題考題")
