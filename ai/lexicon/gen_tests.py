# -*- coding: utf-8 -*-
"""近義詞訓練題：500,000 題
   near：「開心的近義詞是什麼」→ 回答要有同一組的詞
   pair：「開心和快樂意思一樣嗎」→ 同一組說相近、不同組說不一樣
   para：同一個問題換個說法（「羅浮宮位在何處」＝「羅浮宮在哪裡」）→ 理解要一樣（題型、主題）
用法：python3 ai/lexicon/gen_tests.py 輸出.json [--holdout] [--n 500000]"""
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "understanding"))
from synonyms import groups  # noqa: E402
import gen as U  # noqa: E402  （理解訓練題的名稱）

HOLD = "--holdout" in sys.argv
N = int(sys.argv[sys.argv.index("--n") + 1]) if "--n" in sys.argv else (20000 if HOLD else 500000)
R = random.Random(31 if HOLD else 13)
# 「什麼／啥／何物」這一組本身就是問句用語，拿來出比較題會有歧義（「啥和什麼是一樣的意思嗎」），只用在近義詞題
ASKING = {"什麼", "啥", "何物", "為什麼", "為何", "何故", "緣何", "為啥", "怎麼會", "哪裡", "何處", "哪兒", "何地", "什麼地方", "誰", "何人", "哪位",
          "什麼人", "什麼時候", "何時", "幾時", "哪時候", "哪一年", "何年", "哪年", "怎麼", "如何", "怎樣", "怎麼樣", "要怎麼", "什麼是", "何謂", "什麼叫",
          "多少", "若干", "幾多"}
G = groups()
WORDS = sorted({w for g in G for w in g})
INDEX = {}
for i, g in enumerate(G):
    for w in g:
        INDEX.setdefault(w, set()).add(i)


def same(a, b):
    return bool(INDEX.get(a, set()) & INDEX.get(b, set()))


def near_of(w):
    return sorted({x for i in INDEX[w] for x in G[i] if x != w})


NEAR_T = (["{w}的近義詞是什麼", "{w}的近義詞", "{w}有哪些同義詞", "{w}有什麼近義詞", "「{w}」的同義詞有哪些", "{w}可以換成什麼詞",
           "{w}的另一種說法", "跟{w}意思一樣的詞有哪些", "{w}有什麼意思相近的詞", "{w}有沒有別的說法"]
          if not HOLD else ["{w}的同義字有哪些", "和{w}意思相近的詞是什麼", "{w}的相似詞", "什麼詞跟{w}意思差不多", "{w}的其他說法有哪些"])
PAIR_T = (["{a}和{b}意思一樣嗎", "{a}跟{b}的意思差不多嗎", "{a}和{b}是同義詞嗎", "「{a}」跟「{b}」有什麼不同", "{a}可以換成{b}嗎",
           "{a}與{b}是近義詞嗎", "{a}和{b}是一樣的意思嗎"]
          if not HOLD else ["{a}跟{b}一樣意思嗎", "{a}和{b}意思相同嗎", "{a}跟{b}有什麼差別", "{a}是不是就是{b}的意思", "{a}能代替{b}嗎"])
WRAP = ["{q}", "{q}？", "請問{q}", "我想知道{q}", "{q}呢", "欸，{q}", "想問{q}"]

# 同一個問題換個說法：(說法, 題型, 主題的來源)
PARA = [
    ("{x}位在何處", "place", "WHERE"), ("{x}坐落在哪裡", "place", "WHERE"), ("{x}地處哪裡", "place", "WHERE"), ("{x}位在哪個國家", "place", "WHERE"),
    ("何人發明了{x}", "person", "INVENT"), ("{x}是何人發明的", "person", "INVENT"), ("{x}是哪位發明的", "person", "INVENT"),
    ("{x}是何年發生的", "time", "EVENT"), ("{x}發生於何時", "time", "EVENT"), ("{x}是幾時發生的", "time", "EVENT"),
    ("何謂{x}", "definition", "CONCEPT"), ("{x}的含義", "definition", "CONCEPT"), ("{x}的涵義是什麼", "definition", "CONCEPT"),
    ("{x}的意涵", "definition", "CONCEPT"), ("什麼叫做{x}", "definition", "CONCEPT"),
    ("{x}有何益處", "open", "BENEFIT"), ("{x}的益處", "open", "BENEFIT"), ("{x}有什麼長處", "open", "BENEFIT"), ("{x}有何壞處", "open", "BENEFIT"),
    ("{x}的害處有哪些", "open", "BENEFIT"), ("{x}有什麼弊端", "open", "BENEFIT"),
    ("如何烹調{x}", "steps", "DISH"), ("怎麼料理{x}", "steps", "DISH"), ("要如何烹煮{x}", "steps", "DISH"), ("怎樣製作{x}", "steps", "DISH"),
    ("{x}需留意什麼", "steps", "ATTEND"), ("{x}應注意哪些", "steps", "ATTEND"), ("{x}有什麼要當心的", "steps", "ATTEND"), ("{x}需要留意哪些", "steps", "ATTEND"),
    ("{x}該如何處理", "steps", "PROBLEM"), ("遇到{x}要如何處理", "steps", "PROBLEM"),
]
if HOLD:
    PARA = [("{x}座落於哪裡", "place", "WHERE"), ("何謂所謂的{x}", "definition", "CONCEPT"), ("{x}帶來哪些益處", "open", "BENEFIT"),
            ("如何料理{x}", "steps", "DISH"), ("{x}有哪些需要留意的", "steps", "ATTEND"), ("{x}是何時發生的", "time", "EVENT")]
DISHES = ["黃燜雞", "紅燒肉", "番茄炒蛋", "三杯雞", "麻婆豆腐", "滷肉飯", "糖醋排骨", "蔥油餅", "咖哩飯", "牛肉麵", "京醬肉絲", "蚵仔煎", "客家小炒"]
POOLS = {"WHERE": U.WHERE + U.CAPITAL, "INVENT": U.INVENT, "EVENT": U.EVENT, "CONCEPT": U.CONCEPT, "BENEFIT": U.BENEFIT, "DISH": DISHES,
         "ATTEND": U.ATTEND, "PROBLEM": U.PROBLEM}
UNKNOWN = ["量子", "雲端", "區塊鏈", "元宇宙", "演算法", "碳中和", "斯多葛", "多巴胺"]


def one():
    k = R.random()
    if k < 0.3:
        if R.random() < 0.05:
            w = R.choice(UNKNOWN)
            return {"type": "near", "q": R.choice(WRAP).format(q=R.choice(NEAR_T).format(w=w)), "a": w, "b": "", "expect": [], "web": True}
        w = R.choice(WORDS)
        return {"type": "near", "q": R.choice(WRAP).format(q=R.choice(NEAR_T).format(w=w)), "a": w, "b": "", "expect": near_of(w), "web": False}
    if k < 0.6:
        g = R.choice([x for x in G if not set(x) & ASKING])
        if R.random() < 0.5 and len(g) >= 2:
            a, b = R.sample(g, 2)
        else:
            a = R.choice([w for w in WORDS if w not in ASKING])
            b = R.choice([w for w in R.sample(WORDS, 40) if not same(a, w) and w != a and w not in ASKING] or ["工作"])
        return {"type": "pair", "q": R.choice(WRAP).format(q=R.choice(PAIR_T).format(a=a, b=b)), "a": a, "b": b, "expect": ["相近" if same(a, b) else "不一樣"], "web": False}
    t, want, pool = R.choice(PARA)
    x = R.choice(POOLS[pool])
    return {"type": "para", "q": R.choice(WRAP).format(q=t.format(x=x)), "a": x, "b": want, "expect": [], "web": True}


def main(dst):
    out, seen = [], set()
    tries = 0
    while len(out) < N and tries < N * 30:
        tries += 1
        it = one()
        if it["q"] in seen:
            continue
        seen.add(it["q"]); out.append(it)
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    from collections import Counter
    print(len(out), Counter(x["type"] for x in out), "pair 相近", sum(1 for x in out if x["type"] == "pair" and x["expect"] == ["相近"]))


if __name__ == "__main__":
    main(sys.argv[1])
