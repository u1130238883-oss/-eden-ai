#!/usr/bin/env python3
"""「引擎上網查＋大腦說」考卷：用錄下來的真實搜尋，把引擎推理出來的答案和證據交給大腦，看它說出來的對不對。
python3 gen_webbrain.py dump1.jsonl dump2.jsonl ...  （dump 是 WebTapeTests 用 NINESUN_TAPE_JSONL 存的）→ webbrain_routed.jsonl，並更新 run.jsonl"""
import json, sys, os
here = os.path.dirname(os.path.abspath(__file__))
spec = {}
for line in open(os.path.join(here, "../../EchoCore/Tests/EchoCoreTests/Fixtures/web_questions_graded.txt"), encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"): continue
    q, _, e = line.partition("|")
    spec[q] = [g.split("/") for g in e.split(";")] if e else []
rows = [json.loads(l) for f in sorted(sys.argv[1:]) for l in open(f, encoding="utf-8")]
out = []
for r in rows:
    # 長名單、步驟 App 直接顯示引擎的答案，不經過大腦
    if r["asis"] or not r["found"]: continue
    it = {"cat": "webbrain", "q": r["q"], "lang": "zh", "route": "grounded", "expect": spec.get(r["q"], []),
          "forbid": ["我是AI", "無法上網", "沒辦法上網", "無法查詢"]}
    if r["answered"] and r["confident"]:
        it["facts"] = r["text"][:700]; it["evidence"] = r["evidence"][:3]
    else:
        it["evidence"] = r["evidence"][:6]
    out.append(it)
for i, it in enumerate(out):
    it["id"] = f"webbrain-{i:03d}"; it["split"] = "hold" if i % 4 == 3 else "dev"
with open(os.path.join(here, "webbrain_routed.jsonl"), "w", encoding="utf-8") as f:
    for it in out: f.write(json.dumps(it, ensure_ascii=False, sort_keys=True) + "\n")
run = [json.loads(l) for l in open(os.path.join(here, "run.jsonl"), encoding="utf-8")]
run = [d for d in run if not d["id"].startswith("webbrain-")] + out
with open(os.path.join(here, "run.jsonl"), "w", encoding="utf-8") as f:
    for d in run: f.write(json.dumps(d, ensure_ascii=False, sort_keys=True) + "\n")
print(len(out), "題；run 共", len(run))
