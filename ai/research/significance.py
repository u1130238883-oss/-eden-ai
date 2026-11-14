# -*- coding: utf-8 -*-
"""顯著性：事件年的比例跟平常年份比（二項檢定，雙尾），並把第一批、第二批名人分開看能不能重現。"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from structure import relation, THIS_YEAR  # noqa: E402
from celebrity_cases import PEOPLE as FIRST  # noqa: E402
from celebrity_data import MORE, kind  # noqa: E402
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from ninetwelve import Destiny  # noqa: E402


def binom_p(k, n, p):
    """雙尾二項檢定"""
    pk = lambda i: math.comb(n, i) * p ** i * (1 - p) ** (n - i)
    obs = pk(k)
    return min(1.0, sum(pk(i) for i in range(n + 1) if pk(i) <= obs * (1 + 1e-9)))


def collect(people, want):
    ev, base = [], []
    for name, (by, bm, bd), evs in people:
        d = Destiny(by, bm, bd)
        ys = [y for y, *_ in evs]
        for y, what, p, s in evs:
            if want in kind(what) or want == "全部": ev.append(relation(d, y))
        for yb in range(by + 15, min(THIS_YEAR, by + 80) + 1):
            if all(abs(yb - y) > 2 for y in ys): base.append(relation(d, yb))
    return ev, base


tests = [("change", "對宮年"), ("change", "大運壞"), ("change", "流年壞"), ("change", "流年好"), ("union", "流年好"), ("union", "對宮年"),
         ("rise", "流年壞"), ("loss", "流年引動大運方面"), ("rise", "同宮年")]
print(f"共做 {len(tests)} 個檢定：要 p < {0.05 / len(tests):.4f} 才算顯著（Bonferroni）\n")
for group, label in [("全部名人", FIRST + MORE), ("第一批", FIRST), ("第二批", MORE)]:
    print(f"== {group}")
    for want, key in tests:
        ev, base = collect(label, want)
        k, n = sum(r[key] for r in ev), len(ev)
        p0 = sum(r[key] for r in base) / len(base)
        print(f"  {want:6s} {key}：{k}/{n} = {k / max(1, n):.0%}（平常 {p0:.0%}） p = {binom_p(k, n, p0):.3f}")
