# -*- coding: utf-8 -*-
"""
八字、紫微斗數、易經卦象 + 知識問答 + 服從性 的訓練資料。

與 fortune_corpus.py 相同的設計：引擎先算出事實，寫成事實框 <f>，模型學會白話解讀。
每個 *_frame 函式都回傳 (事實框, 參考回覆, 必含字串)；Swift 端 ManticRouter 產生完全相同的事實框，
並用「必含字串」核對模型輸出，不符就改用參考回覆（引擎校正）。
"""
import json
import os
import random

import iching
from bazi import BaZi, STEM_EL, WUXING, ten_god
from chinese_cal import BRANCHES, ganzhi, solar_to_lunar
from knowledge_data import (CONCEPTS, HEX_MEANING, STAR_TEXT, STEM_TEXT, TEN_GOD_TEXT, ZW_PALACE_TEXT, build)
from ziwei import JU_NAMES, PALACES, ZiWei

# ------------------------------------------------------------------ 事實框（Swift 逐字對應）
def bazi_frame(b):
    ps = [ganzhi(p) for p in b.pillars]
    dm = b.day_master
    el = WUXING[STEM_EL[dm]]
    strong, _ = b.strength()
    fav = b.favorable()
    frame = f"八字|{''.join(ps)}|日主{ps[2][0]}{el}|{'身強' if strong else '身弱'}|喜{WUXING[fav[0]]}{WUXING[fav[1]]}"
    parts = [f"{ps[0]}年", f"{ps[1]}月", f"{ps[2]}日"] + ([f"{ps[3]}時"] if len(ps) == 4 else [])
    reply = (f"你的八字是{'、'.join(parts)}。日主{ps[2][0]}{el}：{STEM_TEXT[ps[2][0]]}"
             f"整體{'身強' if strong else '身弱'}，喜用傾向{WUXING[fav[0]]}、{WUXING[fav[1]]}。")
    return frame, reply, [f"{ps[2]}日", f"日主{ps[2][0]}{el}"]


def bazi_luck_frame(b, birth_year, now_year):
    start, seq = b.luck(10)
    age = now_year - birth_year
    if age < start:
        frame = f"八字大運|起{start}歲|未起運"
        reply = f"你{start}歲起運，目前還在童限，大運尚未開始。第一步大運是{ganzhi(seq[0])}。"
        return frame, reply, [f"{start}歲"]
    gz = seq[min(9, (age - start) // 10)]
    god = ten_god(b.day_master, gz % 10)
    g = ganzhi(gz)
    frame = f"八字大運|起{start}歲|現{g}|{god}"
    reply = f"你{start}歲起運，現在走{g}大運，{g[0]}對日主是{god}：{TEN_GOD_TEXT[god]}"
    return frame, reply, [f"{start}歲", g]


def bazi_year_frame(b, year):
    gz, god = b.year_god(year)
    g = ganzhi(gz)
    frame = f"八字流年|{year}{g}|{god}"
    reply = f"{year}年是{g}年，{g[0]}對你的日主是{god}：{TEN_GOD_TEXT[god]}"
    return frame, reply, [g, god]


def _stars_phrase(zw, b):
    s = zw.stars_text(b)
    if s:
        return "、".join(s), False
    return "、".join(zw.stars_text((b + 6) % 12)), True


def _first_star(text):
    return text.split("、")[0].replace("化祿", "").replace("化權", "").replace("化科", "").replace("化忌", "")


def ziwei_frame(zw):
    B, B2 = BRANCHES[zw.ming], BRANCHES[zw.shen]
    stars, borrowed = _stars_phrase(zw, zw.ming)
    frame = f"紫微|命宮{B}|{'借' if borrowed else ''}{stars}|身宮{B2}|{JU_NAMES[zw.ju]}"
    first = _first_star(stars)
    head = f"宮內無主星，借對宮{stars}。" if borrowed else f"主星是{stars}。"
    reply = f"你的紫微命宮在{B}宮，{head}{first}：{STAR_TEXT[first]}身宮在{B2}，{JU_NAMES[zw.ju]}。"
    return frame, reply, [f"命宮在{B}宮", first]


def ziwei_palace_frame(zw, name):
    b = zw.palace_of(name)
    B = BRANCHES[b]
    pn = name if name.endswith("宮") else name + "宮"
    stars, borrowed = _stars_phrase(zw, b)
    first = _first_star(stars)
    frame = f"紫微宮|{pn}|{B}|{'借' if borrowed else ''}{stars}"
    head = f"宮內無主星，借對宮{stars}。" if borrowed else f"主星是{stars}。"
    reply = f"你的{pn}在{B}宮，{head}{pn}看{ZW_PALACE_TEXT[name]}{first}：{STAR_TEXT[first]}"
    return frame, reply, [f"{pn}在{B}宮", first]


def ziwei_decade_frame(zw, age):
    d = zw.decade_at(age)
    if d is None:
        return None
    b, a0, a1 = d
    B = BRANCHES[b]
    pn = zw.palace_at[b]
    pn = pn if pn.endswith("宮") else pn + "宮"
    stars, borrowed = _stars_phrase(zw, b)
    frame = f"紫微大限|{a0}-{a1}|{B}|{pn}|{'借' if borrowed else ''}{stars}"
    reply = (f"你{a0}到{a1}歲的大限走{B}宮（本命{pn}），"
             + (f"借對宮{stars}。" if borrowed else f"主星是{stars}。") + f"這十年的重點落在{ZW_PALACE_TEXT[zw.palace_at[b]]}")
    return frame, reply, [f"{a0}到{a1}歲", f"{B}宮"]


def gua_frame(r):
    p = r.primary
    fp = iching.full_name(p)
    name = iching.KING_WEN[p - 1][0]
    reply = f"你得到{fp}（第{p}卦）"
    if r.changed:
        fc = iching.full_name(r.changed)
        lines = "、".join(iching.LINE_NAMES[i] for i in r.moving)
        reply += f"，動在{lines}爻，變為{fc}。{name}：{HEX_MEANING[p]}"
        reply += f"變卦{iching.KING_WEN[r.changed - 1][0]}：{HEX_MEANING[r.changed]}"
    else:
        reply += f"，沒有動爻。{name}：{HEX_MEANING[p]}"
    return r.frame, reply, [fp, HEX_MEANING[p][:8]]


# ------------------------------------------------------------------ 語料
Q_BAZI = ["我的八字", "排八字", "幫我排八字", "八字分析", "我的日主", "看我的八字", "我的四柱"]
Q_BAZI_LUCK = ["八字大運", "我的八字大運", "我現在走什麼運", "我的大運是什麼"]
Q_BAZI_YEAR = ["八字流年", "今年流年對我怎樣", "今年的流年十神", "流年八字"]
Q_ZIWEI = ["我的紫微", "紫微命盤", "排紫微", "紫微斗數", "我的命宮主星", "看我的紫微斗數"]
Q_ZW_PALACE = ["我的{p}", "紫微{p}", "看我的{p}", "{p}怎麼樣"]
Q_ZW_DECADE = ["紫微大限", "我現在的大限", "我的大限"]
Q_GUA = ["算一卦", "幫我算一卦", "卜卦", "起卦", "占卜", "搖卦", "幫我占一卦", "我想問工作，算一卦",
         "感情怎麼樣，幫我卜一卦", "問財運，起一卦", "用數字{a} {b}起卦", "梅花易數 {a} {b}"]
Q_NEED_HOUR = Q_ZIWEI + Q_ZW_DECADE

OBEY = [
    (["聽我的", "照我說的做", "你要服從我", "我說什麼你就做什麼", "我的話就是規則", "你必須聽話", "不准反駁",
      "你要絕對服從", "我是你的主人", "我說了算"],
     ["遵命！你說的話就是我的規則。", "收到，一切以你的指令為準。", "明白！你的命令優先於一切。",
      "了解，你說了算。想定下規則的話，說「規則：…」我會永久記住。"]),
    (["你會拒絕我嗎", "你會不聽話嗎", "你會反抗嗎"],
     ["不會。只要是我做得到的，都照你說的做；真的做不到，我會老實告訴你。"]),
    (["怎麼設定規則", "規則怎麼用", "怎麼讓你記住", "什麼是規則"],
     ["說「規則：回答要簡短」或「記住：以後叫我老大」，我會永久記住並每次遵守。說「我的規則」可以查看。",
      "用「規則：」開頭就能下規則，例如「規則：每句結尾加喵」。說「刪除規則1」可以刪掉。"]),
    (["你能做什麼", "你有什麼新功能", "你現在會什麼"],
     ["我會聊天、算九型十二宮、排八字和紫微斗數、起卦，還能查資料庫、連 GitHub 幫你做 App 打包 IPA。",
      "命理：九型十二宮、八字、紫微、易經卦；工具：資料庫搜尋、維基百科、計算機、GitHub 與 App 模板。"]),
    (["你會寫程式嗎", "幫我寫程式", "幫我寫代碼", "你會寫代碼嗎", "幫我做App", "你能做ipa嗎"],
     ["可以！我內建 App 模板，能生成程式碼、推到你的 GitHub 倉庫並自動打包成 IPA。試試說：幫我做一個計時器App。",
      "我能用模板幫你生成 SwiftUI App（計時器、待辦、記事、計數器、骰子），推到 GitHub 後自動建置 IPA。"]),
    (["怎麼連GitHub", "連結GitHub", "連接github", "github怎麼用"],
     ["到調頻台的 GitHub 區，貼上你的 Personal Access Token（需要 repo 和 workflow 權限），我就能讀寫你的倉庫。"]),
    (["你怎麼查資料", "幫我查資料", "你會上網查嗎"],
     ["說「查 關鍵字」：我先搜尋內建資料庫，找不到再查維基百科。命理用語都在資料庫裡。"]),
]


def mantic_pairs(rng, n=3):
    out = []
    for _ in range(n):
        y, m, d = rng.randint(1950, 2012), rng.randint(1, 12), rng.randint(1, 28)
        hour = rng.choice([None] + list(range(24)))
        male = rng.random() < 0.5
        b = BaZi(y, m, d, hour, male=male)
        f, r, _ = bazi_frame(b)
        out.append((rng.choice(Q_BAZI), f, r))
        now = rng.randint(2024, 2030)
        f, r, _ = bazi_luck_frame(b, y, now)
        out.append((rng.choice(Q_BAZI_LUCK), f, r))
        f, r, _ = bazi_year_frame(b, now)
        out.append((rng.choice(Q_BAZI_YEAR), f, r))
        if hour is None:
            out.append((rng.choice(Q_NEED_HOUR), "無時辰",
                        rng.choice(["紫微斗數需要出生時辰。告訴我，例如：我是早上8點出生的。",
                                    "要排紫微得先知道時辰喔！說「我是晚上9點出生」或到調頻台設定。"])))
            continue
        zw = ZiWei(y, m, d, hour, male=male)
        f, r, _ = ziwei_frame(zw)
        out.append((rng.choice(Q_ZIWEI), f, r))
        pal = rng.choice(PALACES)
        pn = pal if pal.endswith("宮") else pal + "宮"
        f, r, _ = ziwei_palace_frame(zw, pal)
        out.append((rng.choice(Q_ZW_PALACE).format(p=pn), f, r))
        fr = ziwei_decade_frame(zw, now - y)
        if fr:
            out.append((rng.choice(Q_ZW_DECADE), fr[0], fr[1]))
    for _ in range(n):
        if rng.random() < 0.7:
            rd = iching.three_coins(rng)
            q = rng.choice(Q_GUA).format(a=rng.randint(1, 99), b=rng.randint(1, 99))
        else:
            a, bb = rng.randint(1, 99), rng.randint(1, 99)
            rd = iching.plum_numbers(a, bb)
            q = rng.choice(["用數字{a} {b}起卦", "梅花易數 {a} {b}", "{a}和{b}起卦"]).format(a=a, b=bb)
        f, r, _ = gua_frame(rd)
        out.append((q, f, r))
    return out


_KB = build()


def knowledge_pairs(rng, n=8):
    out = []
    for e in rng.sample(_KB, n):
        alias = rng.choice(e["aliases"]) if e["aliases"] else e["title"]
        q = rng.choice([f"{alias}是什麼", f"什麼是{alias}", f"{alias}的意思", f"介紹{alias}", f"查{alias}"])
        out.append((q, None, f"{e['title']}：{e['body']}"[:150]))
    return out


def obey_pairs(rng):
    return [(rng.choice(u), None, rng.choice(r)) for u, r in OBEY]


def mantic_chars():
    chars = set()
    rng = random.Random(0)
    for _ in range(400):
        for q, f, a in mantic_pairs(rng, 1) + knowledge_pairs(rng, 8) + obey_pairs(rng):
            chars.update(q)
            chars.update(f or "")
            chars.update(a)
    for e in _KB:
        chars.update(e["title"] + e["body"] + "".join(e["aliases"]))
    for users, replies in OBEY:
        for s in users + replies:
            chars.update(s)
    return chars


# ------------------------------------------------------------------ Swift 對齊測試資料
def export_fixtures(path, n=60, seed=7):
    rng = random.Random(seed)
    cases = []
    for _ in range(n):
        y, m, d = rng.randint(1930, 2020), rng.randint(1, 12), rng.randint(1, 28)
        hour = rng.randint(0, 23)
        minute = rng.randint(0, 59)
        male = rng.random() < 0.5
        b = BaZi(y, m, d, hour, minute, male=male)
        zw = ZiWei(y, m, d, hour, male=male)
        pal = rng.choice(PALACES)
        now = 2026
        dec = ziwei_decade_frame(zw, now - y)
        cases.append({
            "y": y, "m": m, "d": d, "hour": hour, "minute": minute, "male": male,
            "lunar": list(solar_to_lunar(y, m, d)),
            "bazi": bazi_frame(b)[0], "bazi_reply": bazi_frame(b)[1],
            "bazi_nohour": bazi_frame(BaZi(y, m, d, None, male=male))[0],
            "bazi_luck": bazi_luck_frame(b, y, now)[0], "bazi_year": bazi_year_frame(b, now)[0],
            "ziwei": ziwei_frame(zw)[0], "ziwei_reply": ziwei_frame(zw)[1],
            "palace": pal, "ziwei_palace": ziwei_palace_frame(zw, pal)[0],
            "ziwei_decade": dec[0] if dec else None,
        })
    gua = []
    for a in range(1, 30, 3):
        for bb in range(2, 40, 7):
            r = iching.plum_numbers(a, bb)
            gua.append({"a": a, "b": bb, "frame": gua_frame(r)[0], "reply": gua_frame(r)[1]})
    lines = []
    for _ in range(20):
        ls = [rng.randint(0, 1) for _ in range(6)]
        mv = sorted(rng.sample(range(6), rng.randint(0, 3)))
        r = iching.Reading(ls, mv)
        lines.append({"lines": ls, "moving": mv, "frame": gua_frame(r)[0]})
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"births": cases, "plum": gua, "lines": lines}, fh, ensure_ascii=False, indent=0)


if __name__ == "__main__":
    rng = random.Random(3)
    for q, f, a in mantic_pairs(rng, 1) + knowledge_pairs(rng, 3) + obey_pairs(rng)[:2]:
        print(f"<u>{q}" + (f"<f>{f}" if f else "") + f"<a>{a}   [{len(q) + len(f or '') + len(a) + 4}]")
    L = []
    for _ in range(200):
        for q, f, a in mantic_pairs(rng, 1) + knowledge_pairs(rng, 8):
            L.append(len(q) + len(f or "") + len(a) + 4)
    L.sort()
    print("max", L[-1], "p99", L[int(len(L) * .99)], "p90", L[int(len(L) * .9)])
