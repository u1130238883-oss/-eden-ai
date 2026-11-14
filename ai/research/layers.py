# -*- coding: utf-8 -*-
"""每一層分開看：事件年 vs 同一個人其他年份，對應宮位出現的比例（對照組用同一人 15～75 歲、離事件 3 年以上的所有年份）"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
from ninetwelve import Destiny  # noqa
from celebrity_cases import PEOPLE  # noqa

ALT = {10: [10, 9, 5], 8: [8, 12], 7: [7, 5], 5: [5, 10], 9: [9, 3]}

def layers(d, y, ps):
    s, e, lp = d.luck_period(y)
    fy = d.year(y)
    asp = d.luck_aspects(y)
    trig_nat = {r.palace for r in d.triggered_natal(y)}
    trig_asp = {a.palace for a in d.triggered_aspects(y)}
    P = set(ps)
    return {
        "①大運走這宮": lp.palace in P,
        "②大運果因是這宮": bool(P & {lp.reading.result, lp.reading.cause}),
        "③大運引動本命這宮": bool(P & trig_nat),
        "④大運這一方面是好": any(asp[p - 1].reading.verdict == 0 for p in ps),
        "④大運這一方面是壞": any(asp[p - 1].reading.verdict == 2 for p in ps),
        "⑤流年走這宮": fy.palace in P,
        "⑥流年果因是這宮": bool(P & {fy.reading.result, fy.reading.cause}),
        "⑦流年引動大運這一方面": bool(P & trig_asp),
    }

def run(mapping):
    ev, base = {}, {}
    ne = nb = 0
    for name, (by, bm, bd), events in PEOPLE:
        d = Destiny(by, bm, bd)
        for y, what, p, sign in events:
            ps = mapping(p)
            for k, v in layers(d, y, ps).items(): ev[k] = ev.get(k, 0) + v
            ne += 1
            for yb in range(by + 15, by + 76):
                if abs(yb - y) <= 2: continue
                for k, v in layers(d, yb, ps).items(): base[k] = base.get(k, 0) + v
                nb += 1
    for k in ev:
        print(f"  {k}: 事件年 {ev[k] / ne:.0%}　其他年份 {base[k] / nb:.0%}")

print("只看對應的一宮：")
run(lambda p: [p])
print("放寬（事業也看 9、5；死亡也看 12；結婚也看 5；走紅也看 10；出國也看 3）：")
run(lambda p: ALT.get(p, [p]))
for sign in "+-":
    print("好事" if sign == "+" else "壞事", "：")
    keep = [(n, b, [e for e in ev if e[3] == sign]) for n, b, ev in PEOPLE]
    import celebrity_cases as cc
    old = cc.PEOPLE
    PEOPLE[:] = keep
    run(lambda p: [p])
    PEOPLE[:] = old
