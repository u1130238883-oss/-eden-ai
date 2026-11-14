#!/usr/bin/env python3
"""「百科摘要＋大腦說」考題：真的上網錄下來的結果（WebTapeTests 的 NINESUN_TAPE_JSONL，web-shots 分支的 web_rows.jsonl），
照 App 的做法交給大腦（百科的摘要＋劇情的開頭和結尾當 facts），看它講得對不對、有沒有講完、有沒有亂編。
python3 gen_wiki.py web_rows.jsonl → wiki_routed.jsonl，並併進 new.jsonl、mini.jsonl"""
import json, sys, os
here = os.path.dirname(os.path.abspath(__file__))
EXPECT = {
    "時間是什麼": [["時間"], ["先後", "順序", "過去", "尺度", "維度", "衡量", "度量"]],
    "愛是什麼": [["愛"], ["情感", "感情", "依戀", "關愛", "在乎"]],
    "五行是什麼": [["金"], ["木"], ["水"], ["火"], ["土"]],
    "通貨膨脹是什麼": [["物價", "價格"], ["漲", "購買力"]],
    "民主是什麼": [["人民", "公民"], ["政體", "制度", "統治", "做主", "參與", "權"]],
    "幸福是什麼": [["幸福"], ["滿足", "快樂"]],
    "陰陽是什麼": [["陰陽"], ["相反", "對立", "兩種", "依賴", "相成"]],
    "相對論是什麼": [["愛因斯坦"], ["時空", "引力", "狹義", "廣義"]],
    "區塊鏈是什麼": [["區塊"], ["密碼", "加密", "竄改", "篡改", "交易", "帳本", "去中心"]],
    "存在主義是什麼": [["存在"], ["哲學", "意義", "自己", "行為"]],
    "夏洛特的煩惱": [["夏洛"], ["電影", "喜劇"], ["回到", "重回", "重新", "校園", "夢"]],
    "夏洛特的煩惱講的是什麼": [["夏洛"], ["回到", "重回", "重新", "校園", "夢"], ["馬冬梅", "秋雅", "婚禮", "老婆", "妻子"]],
    "少年維特的煩惱講的是什麼": [["維特"], ["綠蒂"], ["自殺", "自盡", "開槍", "死", "絕望", "訂婚", "無望"]],
    "百年孤寂在講什麼": [["馬奎斯", "馬康多", "波恩地亞"], ["家族"], ["興衰", "七代", "一百年", "百年"]],
    "小王子在講什麼": [["小王子"], ["飛行員", "敘述者", "沙漠", "玫瑰", "星球", "狐狸"]],
    "刺激1995講的是什麼": [["安迪"], ["監獄", "入獄", "坐牢", "牢"], ["瑞德", "朋友", "逃", "自由", "希望"]],
    "哈利波特在講什麼": [["哈利"], ["佛地魔", "霍格華茲", "魔法"]],
    "三體在講什麼": [["葉文潔", "三體"], ["外星", "文明", "三體人", "地球"]],
    "老人與海在講什麼": [["聖地牙哥", "老漁夫", "老人"], ["魚"]],
    "進擊的巨人在講什麼": [["巨人"], ["城牆", "牆", "人類", "艾連"]],
    "你的名字講了什麼": [["瀧", "三葉", "新海誠"], ["交換", "身體", "彗星"]],
}
WORKS = {q for q in EXPECT if "講" in q or q == "夏洛特的煩惱"}
rows = [json.loads(l) for f in sys.argv[1:] for l in open(f, encoding="utf-8")]
out = []
for r in rows:
    q = r["q"]
    if q not in EXPECT or not r["found"] or not r["confident"]: continue
    work = q in WORKS
    it = {"cat": "work" if work else "wikidef", "q": q, "lang": "zh", "route": "grounded", "expect": EXPECT[q], "complete": True,
          "maxlen": 420, "forbid": ["我是AI", "無法上網", "沒辦法上網", "（中間略）", "📌", "📖", "🔚"]}
    # App（ChatViewModel.lookupWeb）：百科的摘要和劇情整段當成查到的資料
    it["facts"] = "\n".join(r["evidence"])[:1000] + "\n（資料來源：維基百科）"
    out.append(it)
for i, it in enumerate(out):
    it["id"] = f"wiki-{i:03d}"; it["split"] = "dev"
with open(os.path.join(here, "wiki_routed.jsonl"), "w", encoding="utf-8") as f:
    for it in out: f.write(json.dumps(it, ensure_ascii=False, sort_keys=True) + "\n")
for name in ("new.jsonl", "mini.jsonl"):
    p = os.path.join(here, name)
    old = [json.loads(l) for l in open(p, encoding="utf-8")]
    old = [d for d in old if not d["id"].startswith("wiki-")] + out
    with open(p, "w", encoding="utf-8") as f:
        for d in old: f.write(json.dumps(d, ensure_ascii=False, sort_keys=True) + "\n")
print(len(out), "wiki items")
