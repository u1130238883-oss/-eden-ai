#!/usr/bin/env python3
"""把語料的核心事實整理成 App 的知識庫（ios/NineSun/Resources/knowledge_zh.json）。
問到這些東西時，引擎把對應的條目當成「查到的資料」交給大腦，大腦照著回答，比憑印象準。
原本的條目（六十四卦、紫微、十神……）保留；這裡產生的條目每次重建時先移除再加回。

python3 build_kb.py
"""
import json
import os

import emo_data
import gen_fortune_tables as F
import med_data
import phil_data
import world_data

HERE = os.path.dirname(os.path.abspath(__file__))
KB = os.path.join(HERE, "../../ios/NineSun/Resources/knowledge_zh.json")
GEN = {"疾病", "急救衛教", "人體器官", "情緒", "思考陷阱", "安定方法", "國家", "化學元素", "行星", "動物", "為什麼", "台灣縣市", "納音",
       "七政四餘", "二十八宿", "地支關係", "哲學家", "名言", "哲學概念", "思想實驗"}

old = [e for e in json.load(open(KB, encoding="utf-8")) if e["cat"] not in GEN]
new = []


def add(cat, title, aliases, body):
    new.append({"cat": cat, "title": title, "aliases": [a for a in aliases if a and a != title], "body": body})


for c in med_data.C:
    add("疾病", c["n"], c["a"], f"症狀：{'、'.join(c['s'])}。原因：{c['c']}。照顧：{c['care']}。要立刻就醫：{'、'.join(c['red'])}。"
                              f"就醫：{c['dept']}。傳染：{c['ct']}。預防：{c['p']}。")
for q, a in med_data.QA:
    t = q.rstrip("？")
    add("急救衛教", t, [], a)
for o, fn, dept in med_data.ORGANS:
    add("人體器官", o, [], f"{o}負責{fn}。有問題看{dept}。")
for e, info in emo_data.E.items():
    n = e.replace("（失去）", "")
    add("情緒", n, [e] if e != n else [], f"{info['v'][0]}。身體常會{info['body']}。可以：{'；'.join(info['do'])}。可以問：{info['ask'][0]}")
for name, desc, exs in emo_data.TRAPS:
    add("思考陷阱", name, [], f"{desc}。例如「{exs[0][0]}」→ {exs[0][1]}")
for name, how in emo_data.CALM:
    add("安定方法", name, [], how)
for name, cap, cont, lang, cur, sight in world_data.COUNTRIES:
    add("國家", name, [], f"首都{cap}，在{cont}，語言{lang}，貨幣{cur}，有名的有{sight}。")
for num, sym, zh, state in world_data.ELEMENTS:
    add("化學元素", zh.split("（")[0], [zh, sym] if "（" in zh else [sym], f"{zh}，化學符號 {sym}，原子序 {num}，常溫下是{state}。")
for i, (p, kind, fact) in enumerate(world_data.PLANETS):
    add("行星", p, [], f"離太陽第 {i + 1} 近的行星，{kind}：{fact}。")
for name, cls, food, fact in world_data.ANIMALS:
    add("動物", name, [], f"{cls}；食性：{food}；{fact}。")
for q, a in world_data.WHY:
    add("為什麼", q.rstrip("？"), [], a)
for name, kind, fact in world_data.TAIWAN:
    add("台灣縣市", name, [name.replace("市", "").replace("縣", "")] if len(name) > 2 else [], f"{kind}，{fact}。")
for k in range(30):
    a, b = F.gz(2 * k), F.gz(2 * k + 1)
    add("納音", f"{a}{b}納音", [a + "納音", b + "納音", F.NAYIN[k]], f"{a}、{b}的納音是{F.NAYIN[k]}，五行屬{F.NAYIN[k][-1]}。")
add("七政四餘", "七政四餘", ["七政", "四餘"], "中國古代星命學：七政是日、月、金、木、水、火、土；四餘是紫氣、月孛、羅睺、計都四顆虛星。依出生時各星所在宮位和二十八宿論命。")
for name, info in F.SIYU:
    add("七政四餘", name, [], info + "。")
for name, alias in F.QIZHENG:
    add("七政四餘", name + "（七政）", [alias], f"{name}古代叫{alias}，是七政之一。")
for i, (x, el, xiang) in enumerate(F.XIU):
    add("二十八宿", x + "宿", [], f"二十八宿第 {i + 1} 宿，屬{xiang}，七曜配屬「{el}」。")
for pair, el in F.LIUHE.items():
    p = "".join(sorted(pair, key=F.BRANCHES.index))
    add("地支關係", p + "六合", [p + "合"], f"{p[0]}{p[1]}六合，合化{el}，代表互相吸引、合作。")
for c in F.CHONG:
    p = "".join(sorted(c, key=F.BRANCHES.index))
    add("地支關係", p + "相沖", [p + "沖"], f"{p[0]}{p[1]}六沖（生肖{F.ANIMALS[F.BRANCHES.index(p[0])]}和{F.ANIMALS[F.BRANCHES.index(p[1])]}），代表衝突、變動、搬遷。")
for tri, el in F.SANHE:
    add("地支關係", tri + "三合", [f"三合{el}局"], f"{tri}三合{el}局，{tri[1]}是中神。")


def pnames(n):
    """「釋迦牟尼（佛陀）」→ 釋迦牟尼、佛陀；「漢娜・鄂蘭」→ 鄂蘭、漢娜鄂蘭"""
    out = []
    if "（" in n:
        a, b = n.rstrip("）").split("（")
        out += [a, b]
    if "・" in n:
        out += [n.split("・")[-1], n.replace("・", "")]
    return out


EXTRA_ALIAS = {"笛卡兒": ["笛卡爾"], "尼采": ["尼採"], "卡繆": ["加繆"], "伊比鳩魯": ["伊壁鳩魯"], "沙特": ["薩特"], "孔恩": ["庫恩"], "海德格": ["海德格爾"],
               "維根斯坦": ["維特根斯坦"], "彌爾": ["密爾", "穆勒"], "齊克果": ["克爾凱郭爾"], "馬基維利": ["馬基雅維利"], "波普": ["波普爾"]}
for n, era, place, school, claims, quote, work, critique, life in phil_data.P:
    add("哲學家", n, pnames(n) + EXTRA_ALIAS.get(n, []),
        f"{place}（{era}），{school}。主要主張：{'；'.join(claims)}。名言：「{quote}」。代表作：{work}。被批評：{critique}。")
    q = quote.replace("（後人概括）", "")
    first = q.split("，")[0].split("；")[0]
    add("名言", q, [first] if len(first) >= 5 and first != q else [], f"「{q}」是{n}（{school}）說的。{n}的主張：{claims[0]}。")
for c in phil_data.C:
    name, d, ex, people, crit = c
    add("哲學概念", name, [], f"{d}。例子：{ex}。代表人物：{'、'.join(people)}。批評：{crit}。")
for name, setup, ask, views in phil_data.T:
    add("思想實驗", name, [], f"{setup}。問題：{ask.rstrip("？?")}？不同看法：{'；'.join(views)}。")

titles = {e["title"] for e in old}
new = [e for e in new if e["title"] not in titles]
json.dump(old + new, open(KB, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(f"原有 {len(old)} 條，新增 {len(new)} 條")
