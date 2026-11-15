#!/usr/bin/env python3
"""八字、紫微斗數的排盤、看盤、解盤、解運勢：至少 10,000,000 字的訓練與測試。

排盤結果和解讀都來自 NineSun 自己的程式（EchoCoreTests.FortuneReadingsExport → readings.jsonl）：
- 八字排盤步驟：年柱以立春分界、月柱看節氣＋五虎遁、日柱查萬年曆、時柱用五鼠遁（23 點後算隔天）
- 紫微排盤步驟：寅宮起正月順數到生月、再逆數生時安命宮；順數生時安身宮；命宮干支納音定五行局；依生日和局數安紫微星
- 解盤、解運勢：App 的 BaZiReading（本命、流年、流月、感情／錢財／事業／學業／家庭）、ZiWeiReading（本命、流年、宮位）

python3 gen_fortune_read.py readings.jsonl 輸出.jsonl 考題.jsonl
"""
import hashlib
import json
import random
import re
import sys

R = random.Random(10_000_000)
STEMS = list("甲乙丙丁戊己庚辛壬癸")
BR = list("子丑寅卯辰巳午未申酉戌亥")
ANIMALS = list("鼠牛虎兔龍蛇馬羊猴雞狗豬")
NAYIN = ["海中金", "爐中火", "大林木", "路旁土", "劍鋒金", "山頭火", "澗下水", "城頭土", "白蠟金", "楊柳木",
         "泉中水", "屋上土", "霹靂火", "松柏木", "長流水", "沙中金", "山下火", "平地木", "壁上土", "金箔金",
         "覆燈火", "天河水", "大驛土", "釵釧金", "桑柘木", "大溪水", "沙中土", "天上火", "石榴木", "大海水"]
JU = {2: "水二局", 3: "木三局", 4: "金四局", 5: "土五局", 6: "火六局"}
TIGER = {0: "甲己之年丙作首", 1: "乙庚之歲戊為頭", 2: "丙辛之年尋庚起", 3: "丁壬壬寅順水流", 4: "戊癸之年甲寅求"}
RAT = {0: "甲己還加甲", 1: "乙庚丙作初", 2: "丙辛從戊起", 3: "丁壬庚子居", 4: "戊癸何方發，壬子是真途"}
MONTHS = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "臘"]


def gz(i):
    return STEMS[i % 10] + BR[i % 12]


def gzi(stem, branch):
    for i in range(60):
        if i % 10 == stem and i % 12 == branch:
            return i


out, exam = [], []


def add(topic, q, a):
    out.append({"cat": "fortune_read", "topic": topic, "q": q, "a": a})


def who(c):
    sex = "男" if c["male"] else "女"
    return R.choice([f"我是{c['y']}年{c['m']}月{c['d']}日{c['h']}點{c['mi']:02d}分出生的{sex}生", f"{sex}，國曆{c['y']}/{c['m']}/{c['d']} {c['h']}:{c['mi']:02d}出生",
                     f"{c['y']}年{c['m']}月{c['d']}日{c['h']}點生，{sex}", f"生日{c['y']}-{c['m']:02d}-{c['d']:02d}，{c['h']}點{c['mi']}分，{sex}"])


def bazi_steps(c):
    P = c["pillars"]
    y, m, d, h = c["y"], c["m"], c["d"], c["h"]
    ly, lm, ld, lh = c["lichun"]
    before = (m, d, h) < (lm, ld, lh)
    ys = P[0] % 10
    hb = ((h + 1) // 2) % 12
    steps = [
        f"① 年柱：八字的年以立春分界。{y}年的立春在{lm}月{ld}日{lh}點左右，你生在立春{'之前，所以年柱算前一年' if before else '之後'}，年柱是{gz(P[0])}（生肖屬{ANIMALS[P[0] % 12]}）。",
        f"② 月柱：月份以「節」分界，你生在{c['jie']}之後、下一個節之前，是{BR[P[1] % 12]}月；月干用五虎遁「{TIGER[ys % 5]}」：年干{STEMS[ys]}的寅月是{STEMS[(ys % 5 * 2 + 2) % 10]}寅，"
        f"往後數到{BR[P[1] % 12]}月就是{gz(P[1])}。",
        f"③ 日柱：日柱是六十甲子一天一天輪，查萬年曆得到{gz(P[2])}{'（23 點以後出生，日柱算隔天）' if h >= 23 else ''}。日柱的天干{STEMS[P[2] % 10]}就是日主，代表你自己。",
        f"④ 時柱：{h}點是{BR[hb]}時；時干用五鼠遁「{RAT[(P[2] % 10) % 5]}」：日干{STEMS[P[2] % 10]}的子時是{STEMS[((P[2] % 10) % 5 * 2) % 10]}子，往後數到{BR[hb]}時就是{gz(P[3])}。",
        f"所以八字是：{gz(P[0])}　{gz(P[1])}　{gz(P[2])}　{gz(P[3])}。",
    ]
    yang = (P[0] % 10) % 2 == 0
    fw = yang == c["male"]
    steps.append(f"⑤ 大運：年干{STEMS[ys]}是{'陽' if yang else '陰'}干、{'男' if c['male'] else '女'}命，所以{'順' if fw else '逆'}排；"
                 f"從出生數到{'下一個' if fw else '上一個'}節氣的天數除以三，{c['luckStart']}歲起運，第一步大運是{gz(c['luck'][0])}。")
    return "\n".join(steps)


def ziwei_steps(c):
    lm = c["lunarMonth"]
    eff = lm % 12 + 1 if c["leap"] and c["lunarDay"] > 15 else lm
    hb = c["hourBranch"]
    ming, shen = c["ming"], c["shen"]
    ys = c["yearStem"]
    mg = gzi(c["mingStem"], ming)
    s = [f"① 先換成農曆：{c['lunar']}，{BR[hb]}時。" + ("（閏月下半月算下個月）" if c["leap"] and c["lunarDay"] > 15 else ""),
         f"② 安命宮：從寅宮起正月，順數到生月（{MONTHS[eff - 1]}月）到{BR[(2 + eff - 1) % 12]}宮，再從那裡起子時逆數到生時（{BR[hb]}時），命宮在{BR[ming]}宮。",
         f"③ 安身宮：同樣到{BR[(2 + eff - 1) % 12]}宮後，順數到生時，身宮在{BR[shen]}宮。",
         f"④ 定宮干：用五虎遁，生年天干{STEMS[ys]}的寅宮是{STEMS[(ys % 5 * 2 + 2) % 10]}寅，命宮{BR[ming]}的宮干是{STEMS[c['mingStem']]}，命宮干支{gz(mg)}。",
         f"⑤ 定五行局：命宮干支{gz(mg)}的納音是{NAYIN[mg // 2]}，屬{NAYIN[mg // 2][-1]}，所以是{JU[c['ju']]}，大限從{c['ju']}歲起。",
         f"⑥ 安紫微星：用生日（農曆{c['lunarDay']}日）和局數{c['ju']}推算，紫微星在{BR[c['ziwei']]}宮；紫微系、天府系的其他主星再依固定的距離排出。"]
    return "\n".join(s)


charts = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")]
for c in charts:
    w = who(c)
    ny = c["now"]
    names = "、".join(gz(p) for p in c["pillars"])
    add("八字排盤步驟", R.choice([f"{w}，八字怎麼排？一步一步教我", f"{w}，幫我排八字，說明每一柱怎麼來的", f"教我排這個八字：{w}"]), bazi_steps(c))
    add("八字解盤", R.choice([f"{w}，幫我看八字本命", f"幫我解盤：{w}", f"我的八字是{names}，幫我看看", f"{w}，我是什麼樣的命？"]), c["bazi_natal"])
    add("八字流年", R.choice([f"{w}，{ny}年運勢怎麼樣？", f"幫我看{ny}年流年：{w}", f"{ny}年對我好不好？{w}"]), c["bazi_year"])
    add("八字主題", R.choice([f"{w}，{ny}年{c['topic']}運如何？", f"幫我用八字看{c['topic']}：{w}", f"{w}，我的{c['topic']}怎麼樣？"]), c["bazi_topic"])
    if R.random() < 0.5:
        yy, mm, _ = c["month"]
        add("八字流月", f"{w}，{yy}年{mm}月運勢？", c["bazi_month"])
    add("紫微排盤步驟", R.choice([f"{w}，紫微斗數命宮怎麼安？一步一步說", f"教我排紫微：{w}", f"{w}，我的紫微命盤怎麼排出來的？"]), ziwei_steps(c))
    if c.get("zw_natal"):
        add("紫微解盤", R.choice([f"{w}，幫我看紫微命盤", f"紫微斗數解盤：{w}", f"{w}，我的命宮主星代表什麼？"]), c["zw_natal"])
        add("紫微流年", R.choice([f"{w}，紫微看{ny}年流年", f"{ny}年紫微運勢：{w}"]), c["zw_year"])
    add("紫微宮位", R.choice([f"{w}，紫微看我的{c['zw_palace_name']}宮", f"幫我看{c['zw_palace_name']}宮：{w}"]), c["zw_palace"])

    # 考題：App 的「命盤推算結果」交給大腦，看它有沒有把重點講出來
    if R.random() < 0.035:
        yr = c["bazi_year"]
        gods = [g for g in ["比肩", "劫財", "食神", "傷官", "偏財", "正財", "七殺", "正官", "偏印", "正印"] if g in yr.split("\n")[2]] if len(yr.split("\n")) > 2 else []
        exam.append({"q": f"我{ny}年運勢怎麼樣？", "reading": yr, "expect": [gods or ["運"], ["順", "辛苦", "壓力", "機會", "小心", "好", "累", "卡"]], "kind": "流年"})
    if R.random() < 0.025:
        t = c["bazi_topic"]
        star = re.search(r"你的(妻星|夫星|財星|官星|印星|食傷)", t)
        exam.append({"q": f"我{ny}年{c['topic']}運如何？", "reading": t, "expect": [[c["topic"], star.group(1) if star else c["topic"]]], "kind": "主題"})
    if R.random() < 0.025:
        p = c["zw_palace"]
        stars = re.findall(r"(紫微|天機|太陽|武曲|天同|廉貞|天府|太陰|貪狼|巨門|天相|天梁|七殺|破軍)", p.split("\n")[1] if len(p.split("\n")) > 1 else p)
        if stars:
            exam.append({"q": f"紫微斗數看我的{c['zw_palace_name']}宮怎麼樣？", "reading": p, "expect": [list(dict.fromkeys(stars))], "kind": "宮位"})

seen = set()
out = [it for it in out if not ((it["q"], it["a"]) in seen or seen.add((it["q"], it["a"])))]
R.shuffle(out)
total = 0
with open(sys.argv[2], "w", encoding="utf-8") as f:
    for i, it in enumerate(out):
        it["id"] = f"fread-{i:06d}"
        total += len(it["q"]) + len(it["a"])
        f.write(json.dumps(it, ensure_ascii=False) + "\n")
kinds = {}
for it in out:
    kinds[it["topic"]] = kinds.get(it["topic"], 0) + 1
print(len(out), "題，", total, "字", kinds)
with open(sys.argv[3], "w", encoding="utf-8") as f:
    for i, e in enumerate(exam):
        e.update({"id": f"fr-{i:04d}", "cat": "fortune_read", "lang": "zh", "forbid": ["【命盤推算結果】"]})
        e["split"] = "hold" if int(hashlib.md5(e["id"].encode()).hexdigest(), 16) % 4 == 0 else "dev"
        f.write(json.dumps(e, ensure_ascii=False) + "\n")
print(len(exam), "題考題")
