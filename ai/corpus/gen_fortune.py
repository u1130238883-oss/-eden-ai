#!/usr/bin/env python3
"""命理語料（五行、八字、紫微斗數、七政四餘）：至少 5,000,000 字的問答。

排盤結果來自 NineSun 自己的程式（EchoCoreTests.FortuneCorpusExport → charts.jsonl），
答案跟 App 算出來的一模一樣；觀念題用下面整理好的對照表。

python3 gen_fortune.py charts.jsonl 輸出.jsonl
"""
import json
import random
import sys

from gen_fortune_tables import *  # noqa: F401,F403
from gen_fortune_tables import R

out = []


def add(topic, q, a):
    out.append({"cat": "fortune", "topic": topic, "q": q, "a": a})


def asks(*forms):
    return R.choice(forms)


# ─────────── 觀念題（每題好幾種問法） ───────────
for s, (yy, img, fang, season, organ) in STEM_INFO.items():
    i = STEMS.index(s)
    for q in [f"天干「{s}」是什麼五行？", f"{s}是陰還是陽？", f"八字裡的{s}代表什麼？", f"{s}木、{s}火這種說法裡，{s}屬什麼？",
              f"日主是{s}的人有什麼特質？"]:
        add("天干", q, f"{s}是第{i + 1}個天干，屬{yy}，象徵{img}。方位在{fang}，季節對應{season}，在中醫對應{organ}。"
                      f"日主是{s}的人，常帶有這種特質；不過八字要看整體四柱的強弱和組合，不能只看日主一個字。")
for b, (yy, an, mon, hrs, fang) in zip(BRANCHES, BRANCH_INFO):
    i = BRANCHES.index(b)
    hid = "、".join(STEMS[h] for h in HIDDEN[i])
    for q in [f"地支「{b}」屬什麼？", f"{b}時是幾點？", f"{b}月是農曆幾月？", f"{b}藏了哪些天干？", f"地支{b}對應哪個生肖？"]:
        add("地支", q, f"{b}是第{i + 1}個地支，屬{yy}，生肖是{an}。{b}時是{hrs}，{b}月是{mon}，方位{fang}。"
                      f"{b}裡面藏的天干（藏干）是{hid}，第一個是本氣。")
for w, (color, fang, season, organ, emo, taste, num, virtue) in WX_INFO.items():
    i = WX.index(w)
    sheng, ke = WX[(i + 1) % 5], WX[(i + 2) % 5]
    shengme, keme = WX[(i + 4) % 5], WX[(i + 3) % 5]
    for q in [f"五行的{w}代表什麼？", f"{w}生什麼？{w}剋什麼？", f"什麼生{w}？什麼剋{w}？", f"五行屬{w}的顏色是什麼？",
              f"{w}對應身體哪裡？", f"缺{w}怎麼補？", f"{w}太多會怎樣？"]:
        add("五行", q, f"{w}：{w}生{sheng}、{w}剋{ke}；生{w}的是{shengme}、剋{w}的是{keme}。"
                      f"顏色{color}、方位{fang}、季節{season}，在中醫對應{organ}，情志是{emo}、味道是{taste}，河圖數是{num}，五常是{virtue}。"
                      f"說「缺{w}」要看整個八字的強弱和喜用神：不是缺什麼就補什麼，若{w}正是喜用，可以多接觸{color}、往{fang}發展、"
                      f"從事和{w}有關的事；若{w}是忌神，補了反而不好。")
add("五行", "五行相生的順序是什麼？", "木生火、火生土、土生金、金生水、水生木，一圈循環。像木頭燒成火、火燒完成灰土、土裡藏金屬、金屬遇冷凝出水、水滋養樹木。")
add("五行", "五行相剋的順序是什麼？", "木剋土、土剋水、水剋火、火剋金、金剋木。像樹根穿破土、土能擋水、水能滅火、火能熔金、金屬斧頭能砍樹。")
add("五行", "五行是哪五個？", "金、木、水、火、土。古人用它們互相生、互相剋的關係，說明萬物的變化。")
for w in WX:
    i = WX.index(w)
    for x in WX:
        j = WX.index(x)
        if i == j:
            rel = f"{w}和{x}是同類，互相幫扶（比和）"
        elif j == (i + 1) % 5:
            rel = f"{w}生{x}"
        elif j == (i + 2) % 5:
            rel = f"{w}剋{x}"
        elif i == (j + 1) % 5:
            rel = f"{x}生{w}"
        else:
            rel = f"{x}剋{w}"
        for q in [f"{w}和{x}是什麼關係？", f"{w}跟{x}合嗎？"]:
            add("五行", q, f"{rel}。五行的關係只有相生、相剋、比和三種；生是幫助、剋是約束，剋不一定是壞事，要看整個命局需不需要。")
for t, info in TEN_INFO.items():
    for q in [f"十神裡的「{t}」是什麼意思？", f"八字{t}多代表什麼？", f"{t}是好是壞？", f"命帶{t}的人個性怎樣？"]:
        add("十神", q, f"{t}：{info}。十神沒有絕對的好壞，要看它是不是命局的喜用神、旺不旺、有沒有被制化。")
add("十神", "十神有哪些？", "比肩、劫財、食神、傷官、偏財、正財、七殺（偏官）、正官、偏印（梟神）、正印。都是用日主（日柱的天干）跟其他天干的五行生剋、陰陽來定的。")
add("十神", "十神怎麼算？", "以日主為我：同五行是比劫（同陰陽比肩、不同劫財）；我生的是食傷（食神、傷官）；我剋的是財（偏財、正財）；"
                       "剋我的是官殺（七殺、正官）；生我的是印（偏印、正印）。陰陽相同的是「偏」的那一個（比肩、食神、偏財、七殺、偏印）。")
for dm in range(10):
    for o in range(10):
        t = ten_god(dm, o)
        add("十神", asks(f"日主{STEMS[dm]}看到{STEMS[o]}是什麼十神？", f"{STEMS[dm]}日主，{STEMS[o]}是十神的什麼？"),
            f"{STEMS[dm]}屬{STEM_INFO[STEMS[dm]][0]}，{STEMS[o]}屬{STEM_INFO[STEMS[o]][0]}，所以{STEMS[o]}是{STEMS[dm]}的「{t}」。{t}：{TEN_INFO[t]}。")
for k in range(30):
    a, b = gz(2 * k), gz(2 * k + 1)
    add("納音", asks(f"{a}的納音是什麼？", f"{a}年生的納音五行是什麼？", f"{b}是什麼命？"),
        f"{a}、{b}的納音是「{NAYIN[k]}」，五行屬{NAYIN[k][-1]}。六十甲子每兩個一組共三十組納音，常用來說「年命」，例如{a}年生的人叫{NAYIN[k]}命。")
for pair, el in LIUHE.items():
    p = "".join(sorted(pair, key=BRANCHES.index))
    add("地支關係", asks(f"{p[0]}和{p[1]}是六合嗎？", f"{p[0]}{p[1]}合化什麼？"), f"是，{p[0]}{p[1]}六合，合化{el}。六合代表互相吸引、合作、有緣分。")
for c in CHONG:
    p = "".join(sorted(c, key=BRANCHES.index))
    add("地支關係", asks(f"{p[0]}{p[1]}相沖是什麼意思？", f"屬{ANIMALS[BRANCHES.index(p[0])]}和屬{ANIMALS[BRANCHES.index(p[1])]}的相沖嗎？"),
        f"是，{p[0]}和{p[1]}六沖（生肖{ANIMALS[BRANCHES.index(p[0])]}和{ANIMALS[BRANCHES.index(p[1])]}）。沖代表衝突、變動、搬遷、分離，"
        f"但也代表突破；合婚只看生肖相沖太粗略，要看整個八字。")
for c in HAI:
    p = "".join(sorted(c, key=BRANCHES.index))
    add("地支關係", f"{p[0]}和{p[1]}是相害嗎？", f"是，{p[0]}{p[1]}六害（又叫六穿），代表暗中的不和、互相拖累、誤會。")
for tri, el in SANHE:
    add("地支關係", asks(f"{tri}三合成什麼局？", f"三合{el}局是哪三個地支？"), f"{tri}三合{el}局：{tri[1]}是中神（帝旺），{tri[0]}是長生、{tri[2]}是墓庫。三合力量比六合大，代表團結、聚集成一股力量。")
for tri, el, fang in SANHUI:
    add("地支關係", f"{tri}三會是什麼？", f"{tri}三會{fang}{el}，是同一個季節的三個月，力量是地支組合裡最強的。")
for tri, name in XING:
    add("地支關係", f"{tri}相刑是什麼？", f"{tri}是「{name}」。刑代表摩擦、刑傷、法律是非或內心糾結。")
add("地支關係", "子卯相刑是什麼？", "子卯是「無禮之刑」，代表不講禮、互相不服。")
add("地支關係", "什麼是自刑？", "辰、午、酉、亥四個地支遇到自己（辰辰、午午、酉酉、亥亥）叫自刑，代表自己跟自己過不去、鑽牛角尖。")
for p, el in STEM_HE:
    add("天干關係", asks(f"{p[0]}{p[1]}合是什麼？", f"{p[0]}跟{p[1]}會合嗎？"), f"會，{p[0]}{p[1]}五合，合化{el}（要有化神的條件才真的化）。天干五合是陽干和隔五位的陰干相合。")
for p in STEM_CHONG:
    add("天干關係", f"{p[0]}{p[1]}相沖嗎？", f"是，{p[0]}{p[1]}相沖（隔七位、同陰陽、五行相剋），代表對立、衝突、變動。")
for s in STEMS:
    for b in BRANCHES:
        add("十二長生", asks(f"{s}在{b}是十二長生的哪個？", f"{s}日主坐{b}是什麼狀態？"),
            f"{s}在{b}是「{changsheng(s, b)}」。十二長生依序是{'、'.join(CS_ORDER)}，"
            f"陽干順行、陰干逆行；{s}的長生在{CS_START[s]}。")
for pal, info in ZW_PALACE.items():
    for q in [f"紫微斗數的{pal}{'宮' if not pal.endswith('宮') else ''}看什麼？", f"{pal}{'宮' if not pal.endswith('宮') else ''}代表什麼？"]:
        add("紫微十二宮", q, f"{pal}{'宮' if not pal.endswith('宮') else ''}看{info}。十二宮從命宮開始逆時針排：命宮、兄弟、夫妻、子女、財帛、疾厄、遷移、交友、官祿、田宅、福德、父母。")
for st, info in ZW_STAR.items():
    for q in [f"紫微斗數的{st}星是什麼意思？", f"{st}坐命的人個性如何？", f"{st}在夫妻宮代表什麼？", f"{st}在財帛宮怎麼看？", f"{st}在官祿宮適合什麼工作？"]:
        if "夫妻" in q:
            a = f"{st}：{info}。在夫妻宮，表示伴侶或感情裡帶有這種特質，也是你在感情中會遇到的課題；還要看四化和同宮的吉煞星。"
        elif "財帛" in q:
            a = f"{st}：{info}。在財帛宮，表示賺錢和用錢的方式帶有這種色彩；要配合化祿、化忌和祿存、擎羊等星一起看。"
        elif "官祿" in q:
            a = f"{st}：{info}。在官祿宮，適合能發揮這種特質的工作；整體還要看命宮、遷移宮和大限。"
        else:
            a = f"{st}是十四主星之一：{info}。坐命時這種特質最明顯，再看三方四正（財帛、官祿、遷移）和四化。"
        add("紫微主星", q, a)
for st, info in ZW_AUX.items():
    add("紫微輔星", asks(f"{st}是什麼星？", f"命宮有{st}代表什麼？"), f"{st}：{info}。輔星、煞星會讓主星的表現加分或減分。")
for sh, info in SIHUA_INFO.items():
    add("四化", asks(f"紫微斗數的{sh}是什麼？", f"{sh}好不好？"), f"{sh}代表{info}。四化依出生年的天干決定（化祿、化權、化科、化忌），是看吉凶變化的關鍵。")
for s, stars in SIHUA_TABLE.items():
    add("四化", asks(f"{s}年生的四化是什麼？", f"天干{s}的四化？"), f"{s}年：{stars[0]}化祿、{stars[1]}化權、{stars[2]}化科、{stars[3]}化忌。")
for ju, name in JU.items():
    add("五行局", asks(f"紫微的{name}是什麼意思？", f"{name}幾歲起大限？"), f"{name}由命宮干支的納音五行決定，大限從{ju}歲開始，每十年換一個宮位。")
add("七政四餘", "七政四餘是什麼？", "七政四餘是中國古代的星命學，用真實天體算命：七政是日、月、金、木、水、火、土七顆星，"
                             "四餘是紫氣、月孛、羅睺、計都四顆虛星。依出生時各星所在的宮位和二十八宿來論命，跟西洋占星有相通之處。")
for name, alias in QIZHENG:
    add("七政四餘", asks(f"七政裡的{name}古代叫什麼？", f"{alias}是哪顆星？"), f"{name}古代叫{alias}，是七政之一。七政是太陽、太陰（月亮）、水星、金星、火星、木星、土星。")
for name, info in SIYU:
    add("七政四餘", asks(f"四餘的{name}是什麼？", f"{name}星吉還是凶？"), f"{name}：{info}。四餘是紫氣、月孛、羅睺、計都。")
for i, (x, el, xiang) in enumerate(XIU):
    add("二十八宿", asks(f"二十八宿的{x}宿屬什麼？", f"{x}宿在哪一方？"), f"{x}宿是二十八宿第{i + 1}宿，屬{xiang}，七曜配屬是「{el}」。"
                                                                    f"每方七宿：東方青龍角亢氐房心尾箕、北方玄武斗牛女虛危室壁、西方白虎奎婁胃昴畢觜參、南方朱雀井鬼柳星張翼軫。")
for br, ci in CIS.items():
    add("七政四餘", asks(f"{br}宮的星次叫什麼？", f"{ci}是哪一宮？"), f"{br}宮的星次是「{ci}」，宮主是{GONG_LORD[br]}。十二星次是古代把黃道分成十二段的名稱。")
for name, lon, br in GUOGONG:
    add("七政四餘", f"{name}之後太陽在哪一宮？", f"依「中氣過宮」，{name}之後太陽進入{br}宮（{CIS[br]}），一直到下一個中氣。"
                                           f"（古法未計歲差；現代七政四餘有的用真實的恆星位置，宮位會差將近一宮。）")

# ─────────── 每一張排好的盤：八字、紫微、七政 ───────────
charts = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")]
PAL = ["年", "月", "日", "時"]
for c in charts:
    y, m, d, h, mi = c["y"], c["m"], c["d"], c["h"], c["mi"]
    sex = "男" if c["male"] else "女"
    who = asks(f"{y}年{m}月{d}日{h}點{mi:02d}分出生的{sex}生", f"{sex}，國曆{y}/{m}/{d} {h}:{mi:02d}出生", f"我是{y}年{m}月{d}日{h}點{mi}分生的{sex}生")
    P = c["pillars"]
    dm = c["dayMaster"]
    dms = STEMS[dm]
    names = [gz(p) for p in P]
    pil = "、".join(f"{PAL[i]}柱{names[i]}" for i in range(4))
    add("八字排盤", f"{who}，八字是什麼？",
        f"八字是：{' '.join(names)}（{pil}）。日主是{dms}，屬{STEM_INFO[dms][0]}。年柱以立春為界、月柱以節氣為界、"
        f"日柱從萬年曆的六十甲子推、時柱用五鼠遁從日干推出。")
    el = c["elements"]
    elt = "、".join(f"{WX[i]}{el[i]}" for i in range(5))
    fav = "、".join(WX[f] for f in c["favorable"])
    strong = "身強" if c["strong"] else "身弱"
    add("八字強弱", asks(f"{who}，日主強還是弱？喜用神是什麼？", f"幫我看{' '.join(names)}這個八字的五行和喜用神"),
        f"日主{dms}（{STEM_INFO[dms][0]}）。把天干和地支藏干加權算五行力量：{elt}（月令加倍）。"
        f"生扶日主的力量（同類加生我）占{round(c['ratio'] * 100)}%，屬於{strong}。"
        + (f"身強喜歡洩、耗、剋，喜用神是{fav}。" if c["strong"] else f"身弱喜歡生扶，喜用神是{fav}。")
        + "這是 NineSun 用簡化的五行力量算法；專業命理師還會看格局、調候、通關，結論可能不同。")
    tg = [ten_god(dm, p % 10) for p in P]
    add("八字十神", asks(f"{' '.join(names)}的十神怎麼排？", f"{who}，天干的十神是什麼？"),
        f"以日主{dms}為我：年干{STEMS[P[0] % 10]}是{tg[0]}、月干{STEMS[P[1] % 10]}是{tg[1]}、時干{STEMS[P[3] % 10]}是{tg[3]}。"
        + "地支藏干：" + "；".join(f"{PAL[i]}支{BRANCHES[P[i] % 12]}藏" + "、".join(f"{STEMS[x]}（{ten_god(dm, x)}）" for x in HIDDEN[P[i] % 12]) for i in range(4))
        + "。")
    k = P[0] // 2
    kd = P[2] // 2
    add("納音", asks(f"{who}，年命納音是什麼？", f"{names[0]}年{names[2]}日生的納音？"),
        f"年柱{names[0]}的納音是{NAYIN[k]}（{NAYIN[k][-1]}），日柱{names[2]}的納音是{NAYIN[kd]}（{NAYIN[kd][-1]}）。生肖屬{ANIMALS[P[0] % 12]}。")
    br = [BRANCHES[p % 12] for p in P]
    rel = []
    for i in range(4):
        for j in range(i + 1, 4):
            a, b = br[i], br[j]
            pair = {a, b}
            if a != b and frozenset(pair) in LIUHE:
                rel.append(f"{PAL[i]}支{a}和{PAL[j]}支{b}六合")
            if pair in CHONG:
                rel.append(f"{PAL[i]}支{a}和{PAL[j]}支{b}相沖")
            if pair in HAI:
                rel.append(f"{PAL[i]}支{a}和{PAL[j]}支{b}相害")
    for tri, e in SANHE:
        if all(x in br for x in tri):
            rel.append(f"地支{tri}三合{e}局")
        elif sum(x in br for x in tri) == 2 and tri[1] in br:
            rel.append(f"{'、'.join(x for x in tri if x in br)}半合{e}")
    add("地支關係", asks(f"{' '.join(names)}的地支有沒有沖合？", f"{who}，命盤地支有什麼刑沖合害？"),
        ("地支是" + "、".join(br) + "。" + ("；".join(rel) + "。" if rel else "四個地支之間沒有明顯的六合、六沖、六害或三合。")
         + "沖代表變動、合代表牽絆和助力；年月相沖常見早年離家，日時相沖常見晚年或子女方面的變動，仍要配合喜忌看。"))
    cs = [changsheng(dms, b) for b in br]
    add("十二長生", f"{' '.join(names)}，日主在四柱的十二長生是什麼？",
        f"日主{dms}在年支{br[0]}是{cs[0]}、月支{br[1]}是{cs[1]}、日支{br[2]}是{cs[2]}、時支{br[3]}是{cs[3]}。"
        f"坐下（日支）是{cs[2]}，代表自己本身的根氣狀態。")
    seq = "、".join(f"{c['luckStart'] + 10 * i}歲{gz(g)}（{ten_god(dm, g % 10)}）" for i, g in enumerate(c["luck"]))
    yang = (P[0] % 10) % 2 == 0
    direction = "順排" if yang == c["male"] else "逆排"
    add("大運", asks(f"{who}，大運怎麼排？幾歲起運？", f"{' '.join(names)}（{sex}）的大運？"),
        f"年干{STEMS[P[0] % 10]}是{'陽' if yang else '陰'}干，{sex}命所以大運{direction}；從出生到最近的節氣日數除以三，{c['luckStart']}歲起運。"
        f"大運依序：{seq}。括號是大運天干對日主的十神。")
    for yy, g, god in R.sample(c["yearGods"], 3):
        add("流年", asks(f"{who}，{yy}年流年怎麼樣？", f"{' '.join(names)}，{yy}年是什麼流年？"),
            f"{yy}年是{gz(g)}年，流年天干{STEMS[g % 10]}對日主{dms}是「{god}」：{TEN_INFO[god]}。"
            f"{'流年五行' + WX[STEM_EL[g % 10]] + ('正是喜用神，整體比較順。' if STEM_EL[g % 10] in c['favorable'] else '不是喜用神，做事要多留意、穩著來。')}"
            f"再看流年地支{BRANCHES[g % 12]}和命盤地支的沖合。")
    add("農曆", asks(f"國曆{y}年{m}月{d}日是農曆哪一天？", f"{y}/{m}/{d}的農曆生日？"),
        f"國曆{y}年{m}月{d}日是農曆{c['lunar']}{'（閏月）' if c['leap'] else ''}。注意：農曆年以正月初一換年，八字的年柱以立春換年，兩者可能不同。")
    z = c["zw"]
    pa = {int(k): v for k, v in z["palaceAt"].items()}
    sa = {int(k): v for k, v in z["stemAt"].items()}
    ming = z["ming"]
    stars = z["main"][ming]
    opp = (ming + 6) % 12
    mstars = "、".join(s + z["sihua"].get(s, "") for s in stars) if stars else f"沒有主星（空宮），借對宮{BRANCHES[opp]}的" + "、".join(z["main"][opp]) + "來看"
    first = stars[0] if stars else (z["main"][opp][0] if z["main"][opp] else None)
    add("紫微命宮", asks(f"{who}，紫微斗數命宮在哪？什麼主星？", f"幫我排紫微：{y}年{m}月{d}日{h}點，{sex}"),
        f"農曆{c['lunar']}、{BRANCHES[z['hourBranch']]}時。命宮在{BRANCHES[ming]}宮（宮干{STEMS[sa[ming]]}），身宮在{BRANCHES[z['shen']]}宮"
        f"（{pa[z['shen']]}），五行局是{JU[z['ju']]}。命宮主星：{mstars}。" + (f"{first}：{ZW_STAR[first]}。" if first else ""))
    sih = "、".join(f"{s}{t}" for s, t in z["sihua"].items())
    add("紫微四化", f"{who}，生年四化在哪幾顆星？",
        f"生年天干{STEMS[z['yearStem']]}，四化是：{sih}。" + "；".join(
            f"{s}{t}在{BRANCHES[b]}宮（{pa[b]}）" for s, t in z["sihua"].items() for b in range(12) if s in z["main"][b] + z["aux"][b]) + "。")
    for want in R.sample(["夫妻", "財帛", "官祿", "遷移", "福德", "疾厄", "田宅", "子女"], 3):
        b = next(k for k, v in pa.items() if v == want)
        ms = z["main"][b]
        star_txt = "、".join(s + z["sihua"].get(s, "") for s in ms) if ms else "沒有主星（借對宮" + "、".join(z["main"][(b + 6) % 12]) + "）"
        ax = "、".join(z["aux"][b]) if z["aux"][b] else "沒有"
        lead = ms[0] if ms else (z["main"][(b + 6) % 12][0] if z["main"][(b + 6) % 12] else None)
        add("紫微宮位", asks(f"{who}，{want}宮怎麼樣？", f"紫微斗數看我的{want}宮：{y}年{m}月{d}日{h}點生"),
            f"{want}宮在{BRANCHES[b]}宮，看{ZW_PALACE[want]}。主星：{star_txt}；輔星：{ax}。"
            + (f"{lead}：{ZW_STAR[lead]}。" if lead else ""))
    age = R.randint(z["decades"][0][1], 80)
    dec = next(x for x in z["decades"] if x[1] <= age <= x[2])
    add("紫微大限", f"{who}，{age}歲走哪個大限？",
        f"{JU[z['ju']]}從{z['decades'][0][1]}歲起大限，{'順' if z['decades'][1][0] == (ming + 1) % 12 else '逆'}行。"
        f"{age}歲在{dec[1]}到{dec[2]}歲的大限，走{BRANCHES[dec[0]]}宮（本命{pa[dec[0]]}宮），大限主星：" + ("、".join(z["main"][dec[0]]) or "空宮") + "。")
    sp = sun_palace(c["sunLon"])
    if sp:
        add("七政四餘", asks(f"{y}年{m}月{d}日出生，七政四餘的太陽在哪一宮？", f"{m}月{d}日生，太陽過宮在哪？"),
            f"那天中午太陽黃經約{c['sunLon']}度，已過「{sp[0]}」，依中氣過宮在{sp[1]}宮（星次{CIS[sp[1]]}），宮主是{GONG_LORD[sp[1]]}。")

# 一模一樣的題目只留一份（不灌水）
seen = set()
out = [it for it in out if not ((it["q"], it["a"]) in seen or seen.add((it["q"], it["a"])))]
R.shuffle(out)
total = 0
with open(sys.argv[2], "w", encoding="utf-8") as f:
    for i, it in enumerate(out):
        it["id"] = f"fortune-{i:06d}"
        total += len(it["q"]) + len(it["a"])
        f.write(json.dumps(it, ensure_ascii=False) + "\n")
print(len(out), "題，", total, "字")
