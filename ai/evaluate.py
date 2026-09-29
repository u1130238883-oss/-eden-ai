# -*- coding: utf-8 -*-
"""
評估匯出的 NineSun 權重：
  1) 命理解讀的「核對通過率」——隨機生日 × 各種推算，模型輸出是否包含引擎算出的宮位與判讀
  2) 幾段範例對話

    python3 ai/evaluate.py
"""
import json
import os
import random

import numpy as np

import ninetwelve as nt
from echo_model import CharTokenizer, EchoGPT
from fortune_corpus import pn
from train import chat_prompt, generate

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "ios", "NineSun", "Resources")


def load():
    meta = json.load(open(os.path.join(RES, "ninesun.json"), encoding="utf-8"))
    c = meta["config"]
    m = EchoGPT(c["vocab_size"], c["n_ctx"], c["n_embd"], c["n_head"], c["n_layer"])
    flat = np.fromfile(os.path.join(RES, "ninesun.bin"), dtype="<f4")
    for t in meta["tensors"]:
        n = int(np.prod(t["shape"]))
        m.p[t["name"]] = flat[t["offset"]:t["offset"] + n].reshape(t["shape"])
    tok = CharTokenizer([])
    tok.itos = meta["vocab"]
    tok.stoi = {s: i for i, s in enumerate(tok.itos)}
    return m, tok


def cases(rng):
    y, mo, d = rng.randint(1950, 2015), rng.randint(1, 12), rng.randint(1, 28)
    D = nt.Destiny(y, mo, d)
    qy, qm, qd = 2026, rng.randint(1, 12), rng.randint(1, 28)
    out = []
    dp, np_ = D.day(qm, qd)
    out.append(("今日", "今天運勢", f"今日|日{dp}|夜{np_}", [pn(dp), pn(np_)]))
    r = D.month(qm, qy)
    out.append(("流月", "這個月運勢", f"流月|{qm}月|{r.text}", [pn(r.palace), r.reading.text]))
    r = D.year(qy)
    trig = [a.palace for a in D.triggered_aspects(qy)][:3]
    f = f"流年|{qy}|{r.text}" + ("|引" + ",".join(map(str, trig)) if trig else "")
    out.append(("流年", "今年運勢", f, [pn(r.palace), r.reading.text]))
    s, e, r = D.luck_period(qy)
    out.append(("大運", "我的大運", f"大運|{s}-{e}|{r.text}", [pn(r.palace), r.reading.text]))
    r = D.natal[0]
    out.append(("命盤", "我的命盤", f"命盤|命{r.palace}|型{D.type}|{r.text}", [pn(r.palace), r.reading.text]))
    t = D.type
    out.append(("九型", "我是幾型", f"九型|{t}", [f"第{t}型「{nt.TYPE_NAMES[t - 1]}」"]))
    return out


def foreign_eval(model, tok, n=12):
    """英文／西班牙文／義大利文：同樣的事實框核對。"""
    import iching
    from bazi import BaZi
    from ziwei import ZiWei, PALACES
    from i18n import fortune_samples, bazi_sample, bazi_luck_sample, ziwei_sample, ziwei_palace_sample, gua_sample
    from i18n_chat import Q
    rng = random.Random(7)
    total = [0, 0]
    for L in ("en", "es", "it"):
        stats, fails = {}, []
        for _ in range(n):
            y, mo, d = rng.randint(1950, 2012), rng.randint(1, 12), rng.randint(1, 28)
            D = nt.Destiny(y, mo, d)
            items = [(k, Q[L][k][0] if "{d}" not in Q[L][k][0] else Q[L][k][0].format(d=f"{y}-{mo}-{d}"), f, m)
                     for k, f, _, m in fortune_samples(D, 2026, rng.randint(1, 12), rng.randint(1, 28), None, L)]
            hour = rng.randint(0, 23)
            b = BaZi(y, mo, d, hour, male=True)
            f, _, m = bazi_sample(b, L); items.append(("bazi", Q[L]["bazi"][0], f, m))
            f, _, m = bazi_luck_sample(b, y, 2026, L); items.append(("bazi_luck", Q[L]["bazi_luck"][0], f, m))
            zw = ZiWei(y, mo, d, hour, male=True)
            f, _, m = ziwei_sample(zw, L); items.append(("ziwei", Q[L]["ziwei"][0], f, m))
            f, _, m = gua_sample(iching.three_coins(rng), L)
            items.append(("gua", [x for x in Q[L]["gua"] if "{a}" not in x][0], f, m))
            for kind, q, frame, must in items:
                txt = tok.decode(generate(model, tok, chat_prompt(tok, q, frame), max_new=130))
                ok = all(x in txt for x in must)
                a, c = stats.get(kind, (0, 0))
                stats[kind] = (a + ok, c + 1)
                if not ok and len(fails) < 2:
                    fails.append((frame, must, txt))
        a = sum(x for x, _ in stats.values()); c = sum(x for _, x in stats.values())
        total[0] += a; total[1] += c
        print(f"== {L} 核對通過率：{a}/{c} = {a / c:.0%}  " + "  ".join(f"{k}:{x}/{y}" for k, (x, y) in stats.items()))
        for f, m, t in fails:
            print(f"  ✗ {f}  must={m}\n    {t}")
    return total


def main(n=40):
    model, tok = load()
    rng = random.Random(2026)
    stats = {}
    fails = []
    for _ in range(n):
        for kind, q, frame, must in cases(rng):
            txt = tok.decode(generate(model, tok, chat_prompt(tok, q, frame), max_new=130))
            ok = all(m in txt for m in must)
            a, b = stats.get(kind, (0, 0))
            stats[kind] = (a + ok, b + 1)
            if not ok and len(fails) < 6:
                fails.append((frame, txt))
    tot = sum(a for a, _ in stats.values()), sum(b for _, b in stats.values())
    print("== 命理解讀核對通過率（greedy）==")
    for k, (a, b) in stats.items():
        print(f"  {k}: {a}/{b} = {a / b:.0%}")
    print(f"  總計: {tot[0]}/{tot[1]} = {tot[0] / tot[1]:.0%}")
    for f, t in fails:
        print(f"  ✗ {f}\n    {t}")

    foreign_eval(model, tok)
    print("\n== 範例 ==")
    for q, f in [("你好", None), ("你是誰", None), ("你會算命嗎", None), ("7宮是什麼", None),
                 ("第4型是什麼", None), ("第9型壓力大時", None), ("壞3因8是什麼意思", None), ("我好累", None),
                 ("今天運勢", "今日|日5|夜3"), ("今年運勢", "流年|2026|8宮壞9因2|引3,9"),
                 ("我跟1999年8月8日的人合不合", "合盤|命7|好4正2壞6"), ("我的命盤", "無生日"),
                 ("hello", None), ("who are you", None), ("I'm so tired", "en|感6"), ("hola, ¿quién eres?", None),
                 ("estoy triste", "es|感1"), ("ciao, come stai", None), ("today's fortune", "en|今日|日5|夜3"),
                 ("il mio tema", "it|命盤|命8|型8|8宮好9因5")]:
        print(f"> {q}" + (f"  〔{f}〕" if f else ""))
        print("  " + tok.decode(generate(model, tok, chat_prompt(tok, q, f), max_new=130)))


if __name__ == "__main__":
    main()
