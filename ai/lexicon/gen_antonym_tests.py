# -*- coding: utf-8 -*-
"""反義詞訓練題：500,000 題
   of：「開心的反義詞是什麼」→ 回答要有相反的詞；詞庫沒有的詞要上網查
   pair：「大和小是反義詞嗎」→ 是一對就說「對」、不是就說「不是」（近義詞要說是近義詞）
   trap：問法像反義詞但其實在問別的（「反義詞是什麼意思」「相反數怎麼算」）→ 不能當成反義詞題
用法：python3 ai/lexicon/gen_antonym_tests.py 輸出.json [--holdout] [--n 500000]"""
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from antonyms import pairs  # noqa: E402
from synonyms import groups  # noqa: E402

HOLD = "--holdout" in sys.argv
N = int(sys.argv[sys.argv.index("--n") + 1]) if "--n" in sys.argv else (20000 if HOLD else 500000)
R = random.Random(53 if HOLD else 37)
P = pairs()
OPP = {}
for a, b in P:
    OPP.setdefault(a, set()).add(b)
    OPP.setdefault(b, set()).add(a)
G = groups()
NEAR = {}
for g in G:
    for w in g:
        NEAR.setdefault(w, set()).update(x for x in g if x != w)
WORDS = sorted(OPP)


def opposite(a, b):
    if b in OPP.get(a, ()):
        return True
    sb = {b} | NEAR.get(b, set())
    return any(o in sb for x in {a} | NEAR.get(a, set()) for o in OPP.get(x, ()))


OF_T = (["{w}的反義詞是什麼", "{w}的反義詞", "{w}的相反詞是什麼", "{w}有什麼反義詞", "{w}有哪些反義詞", "「{w}」的反義詞有哪些", "{w}的反義字",
         "跟{w}相反的詞是什麼", "和{w}意思相反的詞有哪些", "{w}的相反是什麼", "{w}反義詞", "什麼詞跟{w}意思相反", "{w}的相反詞有哪些"]
        if not HOLD else ["{w}的對義詞是什麼", "與{w}相反的字有哪些", "{w}有沒有反義詞", "{w}的反面詞", "{w}相反詞是啥"])
PAIR_T = (["{a}和{b}是反義詞嗎", "{a}跟{b}是相反詞嗎", "{a}的反義詞是{b}嗎", "{a}與{b}意思相反嗎", "{a}和{b}是一對反義詞嗎", "{a}跟{b}意思相反嗎",
           "「{a}」和「{b}」是反義詞嗎"]
          if not HOLD else ["{a}的反義詞是不是{b}", "{a}同{b}是反義詞嗎", "{a}和{b}的意思是相反的嗎", "{a}跟{b}是反義字嗎"])
WRAP = ["{q}", "{q}？", "請問{q}", "我想知道{q}", "{q}呢", "欸，{q}", "想問{q}", "考考你，{q}"]
UNKNOWN = ["量子", "雲端", "區塊鏈", "元宇宙", "演算法", "斯多葛", "多巴胺", "光合作用"] if not HOLD else ["熵", "相對論", "通膨"]
TRAPS = (["反義詞是什麼意思", "什麼是反義詞", "反義詞和近義詞有什麼不同", "相反數怎麼算", "相反數是什麼", "反義詞的英文怎麼說", "怎麼教小孩反義詞",
          "反義詞練習題", "反面教材是什麼意思", "我跟他意見相反怎麼辦", "物極必反是什麼意思"]
         if not HOLD else ["反義詞是誰發明的", "反義字有什麼用", "相反的英文", "負負得正是什麼意思"])


def one():
    k = R.random()
    if k < 0.45:
        if R.random() < 0.05:
            w = R.choice(UNKNOWN)
            return {"type": "of", "q": R.choice(WRAP).format(q=R.choice(OF_T).format(w=w)), "a": w, "b": "", "expect": [], "web": True}
        w = R.choice(WORDS)
        return {"type": "of", "q": R.choice(WRAP).format(q=R.choice(OF_T).format(w=w)), "a": w, "b": "", "expect": sorted(OPP[w]), "web": False}
    if k < 0.97:
        r = R.random()
        if r < 0.5:
            a, b = R.choice(P)
            if R.random() < 0.5:
                a, b = b, a
        elif r < 0.7:
            g = R.choice([g for g in G if len(g) >= 2 and any(w in OPP for w in g)])
            a, b = R.sample(g, 2)
        else:
            a = R.choice(WORDS)
            b = R.choice([w for w in R.sample(WORDS, 30) if w != a and not opposite(a, w) and not opposite(w, a)] or ["桌子"])
        yes = opposite(a, b) or opposite(b, a)
        return {"type": "pair", "q": R.choice(WRAP).format(q=R.choice(PAIR_T).format(a=a, b=b)), "a": a, "b": b, "expect": ["對" if yes else "不是"], "web": False}
    return {"type": "trap", "q": R.choice(WRAP).format(q=R.choice(TRAPS)), "a": "", "b": "", "expect": [], "web": True}


def main(dst):
    out, seen, tries = [], set(), 0
    while len(out) < N and tries < N * 40:
        tries += 1
        it = one()
        if it["q"] in seen and it["type"] != "trap":
            continue
        if it["type"] == "trap" and sum(1 for x in out[-200:] if x["type"] == "trap") > 6:
            continue
        seen.add(it["q"]); out.append(it)
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    from collections import Counter
    print(len(out), Counter(x["type"] for x in out), "pair 對", sum(1 for x in out if x["type"] == "pair" and x["expect"] == ["對"]))


if __name__ == "__main__":
    main(sys.argv[1])
