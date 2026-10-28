#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""確認網站用的引擎和 App 算出來的一模一樣（對照原文的同一組範例）。"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "web", "server"))

import engine as E  # noqa: E402

fails = []


def check(label, got, want):
    ok = got == want
    print("  %s  %-28s -> %s" % ("OK " if ok else "!!!", label, got))
    if not ok:
        fails.append("%s: 得到 %r，應為 %r" % (label, got, want))


def fmt(row):
    t = row["triple"]
    v = row["reading"]
    return "%d宮 %d;%d;%d %s%d因%d" % (row["palace"], t[0], t[1], t[2], v[0], v[1], v[2])


print("=== 1. 三柱與靈數 ===")
check("2006-01-14 三柱", E.natal_triple(2006, 1, 14), (8, 1, 5))
check("2006-01-14 靈數", E.life_number(E.natal_triple(2006, 1, 14)), 5)
check("1996-12-19 三柱", E.natal_triple(1996, 12, 19), (7, 3, 1))

print("\n=== 2. 本命盤 8;1;5 ===")
want_natal = ["5宮 9;2;6 壞3因8", "4宮 10;3;7 壞10因5", "3宮 11;4;8 壞12因7",
              "2宮 12;5;9 好2因9", "1宮 1;6;10 壞11因4", "12宮 2;7;11 正11因7",
              "11宮 3;8;12 壞8因3", "10宮 4;9;1 好10因5", "9宮 5;10;2 好12因7",
              "8宮 6;11;3 壞9因2", "7宮 7;12;4 壞4因11", "6宮 8;1;5 正5因7"]
d = E.Destiny(2006, 1, 14)
for got, want in zip(d.natal_chart, want_natal):
    check("本命列", fmt(got), want)

print("\n=== 3. 流年 ===")
for y, want in [(2017, 5), (2018, 4), (2019, 3), (2020, 2), (2021, 1), (2022, 12),
                (2023, 11), (2024, 10), (2025, 9), (2026, 8), (2027, 7), (2028, 6),
                (2006, 4), (2029, 5), (2005, 5), (2035, 11)]:
    check("%d年宮位" % y, d.year_row(y)["palace"], want)

print("\n=== 4. 大運 ===")
lp = d.luck_periods(4)
check("大運區間", [(p["start"], p["end"]) for p in lp],
      [(2006, 2009), (2010, 2018), (2019, 2027), (2028, 2036)])
for p, want in zip(lp, ["4宮 10;3;7 壞10因5", "12宮 2;7;11 正11因7",
                        "3宮 11;4;8 壞12因7", "6宮 8;1;5 正5因7"]):
    check("大運 %d-%d" % (p["start"], p["end"]), fmt(p["row"]), want)
check("2026 所屬大運", (lambda p: (p["start"], p["end"]))(d.luck_period_containing(2026)),
      (2019, 2027))

print("\n=== 5. 日運 ===")
check("靈數5 8月17日", d.day_fortune(8, 17), {"day": 10, "night": 3})
check("靈數5 8月17日（直接）", E.day_fortune_for(5, 8, 17), {"day": 10, "night": 3})
check("靈數7 3月4日", E.day_fortune_for(7, 3, 4), {"day": 12, "night": 5})

print("\n=== 6. 月運 2026年 ===")
want_month = ["7宮 5;3;11 壞4因2", "6宮 6;4;12 正12因10", "5宮 7;5;1 壞8因6",
              "4宮 8;6;2 壞10因8", "3宮 9;7;3 壞12因10", "2宮 10;8;4 好2因12",
              "1宮 11;9;5 壞4因2", "12宮 12;10;6 壞4因6", "11宮 1;11;7 好6因8",
              "10宮 2;12;8 壞8因10", "9宮 3;1;9 壞10因12", "8宮 4;2;10 好2因12"]
for got, want in zip(d.month_chart(2026), want_month):
    check("%d月" % got["month"], fmt(got["row"]), want)

print("\n=== 7. 大運十二方面（2019–2027，以最後一年 2027 為第一宮）===")
asp = d.luck_aspects(2026)
check("大運起訖", (asp["start"], asp["end"]), (2019, 2027))
want_aspects = ["7；12；4 壞4因11", "8；1；5 正5因7", "9；2；6 壞3因8", "10；3；7 壞10因5",
                "11；4；8 壞12因7", "12；5；9 好2因9", "1；6；10 壞11因4", "2；7；11 正11因7",
                "3；8；12 壞8因3", "4；9；1 好10因5", "5；10；2 好12因7", "6；11；3 壞9因2"]
for row, want in zip(asp["aspects"], want_aspects):
    got = "%d；%d；%d %s%d因%d" % (*row["triple"], *row["reading"])
    check("第%d宮" % row["aspect"], got, want)
check("方面編號 1..12", [r["aspect"] for r in asp["aspects"]], list(range(1, 13)))

print("\n=== 7b. 引動（流年引動大運方面、大運引動本命）===")
def trig(rows):
    return ["%d %s%d因%d" % ((r.get("aspect") or r["palace"],) + tuple(r["reading"])) for r in rows]
# 規則：因或果落在所走那一宮（作者 2026-09-28 的例子）
# 2025 走 9宮 → 2019–2027 這段大運裡因或果為9的方面
check("2025 引動", trig(d.triggered_aspects(2025)), ["6 好2因9", "12 壞9因2"])
# 2026 走 8宮
check("2026 引動", trig(d.triggered_aspects(2026)), ["3 壞3因8", "9 壞8因3"])
# 2027 走 7宮
check("2027 引動", trig(d.triggered_aspects(2027)),
      ["2 正5因7", "5 壞12因7", "8 正11因7", "11 好12因7"])
# 2029 走 5宮 → 下一段大運（2028–2036）
check("2029 引動", trig(d.triggered_aspects(2029)), ["1 好10因5", "5 正5因7", "7 壞10因5"])
# 大運 2019–2027 走 3宮 → 本命盤因或果為3的宮位
check("大運 2019–2027 引動", trig(d.triggered_natal_rows(d.luck_period_containing(2026))),
      ["5 壞3因8", "11 壞8因3"])
check("大運 2010–2018 引動", trig(d.triggered_natal_rows(d.luck_period_containing(2012))),
      ["3 壞12因7", "9 好12因7"])
check("大運 2028–2036 引動", trig(d.triggered_natal_rows(d.luck_period_containing(2030))), [])
# 本命 9宮 → 本命盤因或果為9的宮位（作者 2026-10-20 的例子）
check("本命 9宮 引動", trig(d.triggered_natal_by_palace(9)), ["2 好2因9", "8 壞9因2"])
check("本命 1宮 引動", trig(d.triggered_natal_by_palace(1)), [])
# 被影響：大運引動的本命宮位，再影響那段大運十二方面裡因或果為那一宮的各項（作者 2026-10-25 的例子）
p2019 = d.luck_period_containing(2026)
aff = {r["palace"]: trig(d.affected_aspects(r, p2019)) for r in d.triggered_natal_rows(p2019)}
check("大運 2019–2027 本命 5宮 被影響", aff[5], ["2 正5因7", "4 壞10因5", "10 好10因5"])
check("大運 2019–2027 本命 11宮 被影響", aff[11], ["1 壞4因11", "7 壞11因4", "8 正11因7"])

print("\n=== 7c. 名字合盤 ===")
# 作者的例子（2026-10-28）：靈數5，china → c 8宮、h 1宮、i 2宮、n 7宮、a 6宮
check("名字合盤 china", trig(d.name_rows("china")),
      ["8 壞9因2", "1 壞11因4", "2 好2因9", "7 壞4因11", "6 正5因7"])
check("名字合盤 大小寫、空白", trig(d.name_rows("Chi na")), trig(d.name_rows("china")))

print("\n=== 8. 合盤 ===")
b = E.Destiny(2007, 1, 23)
syn = d.synastry(b)
check("合盤三柱", syn["triple"], [5, 2, 10])
check("合盤靈數", syn["life_number"], 8)
want_syn = ["8宮 6;3;11 正11因7", "7宮 7;4;12 好4因7", "6宮 8;5;1 正1因3",
            "5宮 9;6;2 好11因8", "4宮 10;7;3 好10因1", "3宮 11;8;4 好3因12",
            "2宮 12;9;5 正5因7", "1宮 1;10;6 好4因7", "12宮 2;11;7 好9因6",
            "11宮 3;12;8 好8因11", "10宮 4;1;9 壞10因1", "9宮 5;2;10 壞12因3"]
for got, want in zip(syn["chart"], want_syn):
    check("合盤列", fmt(got), want)

print("\n=== 9. 摘要不可以重複宮位簡稱 ===")
# 注意：英／西／義有些關鍵字本身就含逗號（例如 Scattered, disordered thoughts），
# 所以不能靠拆字串來數，直接算那份清單。
import content as C  # noqa: E402


def brief_items(n, lang):
    name = C.palace_short(n, lang)
    return [k for k in C.palace_keywords(n, lang) if k != name][:4]


for lang in ("zh", "en", "es", "it"):
    dup = [n for n in range(1, 13) if C.palace_short(n, lang) in brief_items(n, lang)]
    check("%s 摘要沒有和簡稱重複" % lang, dup, [])
    check("%s 每宮摘要仍是四個" % lang,
          [len(brief_items(n, lang)) for n in range(1, 13)], [4] * 12)
    # 產生出來的字串要真的由這四個接起來
    sep = "、" if lang == "zh" else ", "
    ok = all(C.palace_brief(n, lang) == sep.join(brief_items(n, lang))
             for n in range(1, 13))
    check("%s 字串與清單一致" % lang, ok, True)

print("\n" + "=" * 60)
if fails:
    print("不符 %d 項：" % len(fails))
    for f in fails:
        print("  " + f)
    sys.exit(1)
print("網站引擎與 App 一致，全部通過")
