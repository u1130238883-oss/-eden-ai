# -*- coding: utf-8 -*-
"""大運宮位與流年宮位的關係（對宮、同宮、好壞翻轉、引動）跟人生大事的關係。

事先寫好的假設（看資料之前）：
  H1 變動類大事（搬家出國、離婚分手、離職轉隊、卸任退休）比較常發生在「對宮年」：流年走大運的對宮（大運第 7 年）
  H2 大事比較常發生在「流年跟大運同一對果因、好壞翻轉」的年份（同宮或對宮且一好一壞）
  H3 開始類大事（出道、創業、結婚、當選）比較常發生在大運第 1 年（流年＝大運，同宮）
  H4 大事比較常發生在流年有引動大運十二方面的年份
對照組：同一個人 15～80 歲（不超過今年）、離任何一件事 2 年以上的所有年份。
"""
import os
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
from ninetwelve import Destiny, r12  # noqa: E402
from celebrity_cases import PEOPLE as FIRST  # noqa: E402
from celebrity_data import MORE, kind  # noqa: E402

ALL = FIRST + MORE
THIS_YEAR = 2026


def relation(d, y):
    s, e, lp = d.luck_period(y)
    fy = d.year(y)
    off = y - s                            # 大運第幾年（0 起算）
    gap = (lp.palace - fy.palace) % 12     # 流年離大運幾宮
    same_pair = {lp.reading.result, lp.reading.cause} == {fy.reading.result, fy.reading.cause}
    flip = same_pair and (lp.reading.verdict == 0 and fy.reading.verdict == 2 or lp.reading.verdict == 2 and fy.reading.verdict == 0)
    return {
        "off": off,
        "對宮年": gap == 6,
        "同宮年": gap == 0,
        "同果因且好壞翻轉": flip,
        "流年引動大運方面": bool(d.triggered_aspects(y)),
        "大運壞": lp.reading.verdict == 2,
        "流年壞": fy.reading.verdict == 2,
        "流年好": fy.reading.verdict == 0,
    }


def rate(rows, key):
    return sum(r[key] for r in rows) / max(1, len(rows))


def main():
    events = defaultdict(list)   # 類型 → [relation]
    base = []
    n_people = 0
    for name, (by, bm, bd), evs in ALL:
        d = Destiny(by, bm, bd)
        n_people += 1
        years = [y for y, *_ in evs]
        for y, what, p, sign in evs:
            r = relation(d, y)
            events["全部"].append(r)
            for k in kind(what):
                events[k].append(r)
        last = min(THIS_YEAR, by + 80)
        for yb in range(by + 15, last + 1):
            if all(abs(yb - y) > 2 for y in years):
                base.append(relation(d, yb))
    print(f"{n_people} 位名人、{len(events['全部'])} 件大事；對照年份 {len(base)} 個\n")
    names = {"全部": "全部大事", "change": "變動（搬家出國、離婚、離職轉隊、卸任）", "union": "結婚", "loss": "失去（過世、重病、醜聞、失敗）", "rise": "開始與高峰（出道、創業、當選、得獎）"}
    keys = ["對宮年", "同宮年", "同果因且好壞翻轉", "流年引動大運方面", "大運壞", "流年壞", "流年好"]
    print("| 類型 | 件數 | " + " | ".join(keys) + " |")
    print("|---|---|" + "---|" * len(keys))
    print("| 對照（平常年份） | " + str(len(base)) + " | " + " | ".join(f"{rate(base, k):.0%}" for k in keys) + " |")
    for t in ["全部", "change", "union", "loss", "rise"]:
        rows = events[t]
        print(f"| {names[t]} | {len(rows)} | " + " | ".join(f"{rate(rows, k):.0%}" for k in keys) + " |")
    print("\n大運第幾年（0＝第 1 年＝同宮年，6＝第 7 年＝對宮年）：")
    bc = Counter(r["off"] for r in base)
    for t in ["全部", "change", "rise"]:
        c = Counter(r["off"] for r in events[t])
        n = len(events[t])
        print(f"  {names[t]}：" + "　".join(f"{o + 1}年 {c[o] / n:.0%}" for o in range(9)))
    print("  對照：" + "　".join(f"{o + 1}年 {bc[o] / len(base):.0%}" for o in range(9)))


if __name__ == "__main__":
    main()
