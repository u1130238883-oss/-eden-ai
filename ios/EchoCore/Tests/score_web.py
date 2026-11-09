#!/usr/bin/env python3
"""上網考題打分數：python3 score_web.py web_questions_graded.txt answers1.txt answers2.txt ...
每題的回答要包含每一組關鍵字其中一個；沒有關鍵字的題目只看有沒有正常回答（不是查不到、不是空白）。"""
import re, sys
spec = {}
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"): continue
    q, _, e = line.partition("|")
    spec[q] = [g.split("/") for g in e.split(";")] if e else []
ans = {}
for f in sys.argv[2:]:
    txt = open(f, encoding="utf-8").read()
    for block in txt.split("===== 問：")[1:]:
        q, _, body = block.partition("\n")
        ans[q.strip()] = body
fail_words = ["沒找到跟", "沒有直接講明", "被擋", "擋住", "查不到", "沒找到一份完整"]
ok = n = 0
fails = []
for q, groups in spec.items():
    if q not in ans: continue
    n += 1
    a = ans[q].replace(",", "").replace("，", "，")   # 「299,792,458」和「299792458」一樣
    why = [("缺：" + "/".join(g)) for g in groups if not any(x.lower() in a.lower() for x in g)]
    if any(w in a for w in fail_words): why.append("沒答到")
    if not why: ok += 1
    else: fails.append((q, why, a.strip().replace("\n", " ")[:160]))
print(f"上網考題：{ok}/{n} = {100*ok/max(n,1):.1f}%（沒錄到 {len(spec)-n} 題）")
for q, why, a in fails:
    print(f"✗ {q}  {'；'.join(why)}\n   → {a}")
