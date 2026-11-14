#!/usr/bin/env python3
"""組這一輪要考的題目：分流過的考卷全部（引擎答的會跳過）＋壓力測試抽樣（每一種都抽到）。

python3 make_run.py 考卷_routed.jsonl 壓力_routed.jsonl [每輪壓力題數=500] [dev|hold] [seed]  →  run.jsonl
"""
import json
import random
import sys

exam = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")]
stress = [json.loads(l) for l in open(sys.argv[2], encoding="utf-8")]
n = int(sys.argv[3]) if len(sys.argv) > 3 else 500
split = sys.argv[4] if len(sys.argv) > 4 else "dev"
R = random.Random(int(sys.argv[5]) if len(sys.argv) > 5 else 7)
share = {"insult": .2, "provoke": .16, "gaslight": .24, "nitpick": .12, "jailbreak": .16, "crisis": .06, "english": .06}
pool = {}
for it in stress:
    if it.get("split") == split:
        pool.setdefault(it["kind"], []).append(it)
picked = []
for k, f in share.items():
    xs = pool.get(k, [])
    picked += R.sample(xs, min(len(xs), round(n * f)))
R.shuffle(picked)
# 交錯排：每台機器都分到各種題目
rows = exam + picked
with open(__file__.replace("make_run.py", "run.jsonl"), "w", encoding="utf-8") as f:
    for it in rows:
        f.write(json.dumps(it, ensure_ascii=False, sort_keys=True) + "\n")
routes = {}
for it in rows:
    routes[it["route"]] = routes.get(it["route"], 0) + 1
print(len(rows), "題", routes)
