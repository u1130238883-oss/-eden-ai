# -*- coding: utf-8 -*-
"""詞性＋仿寫訓練題（500,000 篇小短文）：
  每篇 2～4 句，由句型（lexicon.TEMPLATES）＋同一類的詞組成，附上每個內容詞的詞性（名詞 N、動詞 V、形容詞 A、副詞 D）。
  題目有兩種問法：分析詞性（「找出這段話的名詞、動詞、形容詞、副詞：…」）、仿寫（「照這段話的結構仿寫一段：…」）。
  仿寫的標準：詞性的順序完全一樣、功能詞（的、地、著、了…）一樣，但每個內容詞都換成別的詞。
驗證題（--holdout）：沒看過的詞（企鵝、徐徐、晶瑩…）、沒看過的句型——要從上下文判斷詞性（「X地」是副詞、「很X」是形容詞）。
用法：python3 ai/grammar/gen.py 輸出.json [--holdout] [--n 500000]"""
import json
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lexicon as L  # noqa: E402

HOLD = "--holdout" in sys.argv
N = int(sys.argv[sys.argv.index("--n") + 1]) if "--n" in sys.argv else (20000 if HOLD else 500000)
R = random.Random(171 if HOLD else 151)

ASK_TAG = ["找出這段話的名詞、動詞、形容詞、副詞：{t}", "分析詞性：{t}", "這段話哪些是名詞、哪些是動詞、形容詞、副詞？{t}", "標出詞性：{t}",
           "請分辨這段話的詞性：{t}", "{t}\n這段話的名詞、動詞、形容詞、副詞是哪些？"]
ASK_IMI = ["照這段話的結構仿寫一段：{t}", "仿寫：{t}", "模仿這段話寫一段：{t}", "用同樣的結構寫一段不同的短文：{t}", "請仿寫這段短文：{t}",
           "{t}\n請照著這個句型仿寫"]
if HOLD:
    ASK_TAG = ["幫我看看這段話的詞性：{t}", "{t}\n請標出每個詞的詞性"]
    ASK_IMI = ["依照這段話的句子結構，仿寫一段：{t}", "{t}\n照樣造句，寫一段新的"]


def pick(cat, used):
    p, tr, ho = L.WORDS[cat]
    pool = tr + ho if HOLD else tr
    if HOLD and ho and R.random() < 0.5:
        pool = ho
    cands = [w for w in pool if w not in used] or pool
    return R.choice(cands)


def sentence(tpl):
    out, tokens, used = "", [], set()
    for part in re.split(r"(\{[a-z]+\})", tpl):
        if part.startswith("{"):
            cat = part[1:-1]
            w = pick(cat, used)
            used.add(w)
            out += w
            tokens.append([w, L.pos_of(cat)])
        else:
            out += part
    return out, tokens


def one():
    k = R.randint(2, 4)
    tpls = L.TEMPLATES + (L.HOLD_TEMPLATES * 3 if HOLD else [])
    text, tokens = "", []
    for t in R.sample(tpls, k):
        s, tk = sentence(t)
        text += s
        tokens += tk
    kind = "tag" if R.random() < 0.5 else "imitate"
    q = R.choice(ASK_TAG if kind == "tag" else ASK_IMI).format(t=text)
    return {"q": q, "text": text, "kind": kind, "tokens": tokens}


def main(dst):
    out, seen, tries = [], set(), 0
    while len(out) < N and tries < N * 20:
        tries += 1
        it = one()
        if it["q"] in seen:
            continue
        seen.add(it["q"]); out.append(it)
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    from collections import Counter
    print(len(out), Counter(x["kind"] for x in out), "平均", sum(len(x["tokens"]) for x in out) / len(out), "個內容詞")


if __name__ == "__main__":
    main(sys.argv[1])
