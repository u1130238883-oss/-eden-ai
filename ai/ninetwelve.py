# -*- coding: utf-8 -*-
"""
九型十二宮（Nine & Twelve）推算引擎 —— Python 版。

逐函式對應 Hollow App 的 Engine.swift（見 claude/hollow-ipa 分支 HANDOFF.md §3），
用來為 ECHO-0 生成「命理認知」訓練資料。iOS 端使用 Swift 版（EchoCore/NineTwelve.swift）。
"""
import json
import os
from dataclasses import dataclass

_DATA = json.load(open(os.path.join(os.path.dirname(__file__), "ninetwelve_zh.json"), encoding="utf-8"))
PALACE_NAMES = _DATA["shortNames"]          # [12]
PALACE_KEYWORDS = _DATA["keywords"]         # [12][...]
TYPE_NAMES = _DATA["names"]                 # [9]
TYPE_TAGLINES = _DATA["taglines"]           # [9]
TYPE_SUMMARIES = _DATA["summaries"]         # [9]
TYPE_SECTION_TITLES = _DATA["sectionTitles"]  # [7]
TYPE_SECTIONS = _DATA["sections"]           # [9][7][...]

METAL, WOOD, WATER, FIRE, EARTH = range(5)
ELEMENT_NAMES = ["金", "木", "水", "火", "土"]
GENERATES = {METAL: WATER, WATER: WOOD, WOOD: FIRE, FIRE: EARTH, EARTH: METAL}
OVERCOMES = {METAL: WOOD, WOOD: EARTH, WATER: FIRE, FIRE: METAL, EARTH: WATER}
PALACE_ELEMENT = [FIRE, METAL, WATER, WATER, FIRE, WATER, METAL, FIRE, WOOD, EARTH, EARTH, WOOD]
VERDICTS = ["好", "正", "壞"]
GOOD, NEUTRAL, BAD = range(3)


def r9(n):
    return (n - 1) % 9 + 1


def r12(n):
    return (n - 1) % 12 + 1


def digit_sum(n):
    return sum(int(c) for c in str(abs(n)))


def life_digit(n):
    v = abs(n)
    while v > 9:
        v = digit_sum(v)
    return 9 if v == 0 else v


def element_of(palace):
    return PALACE_ELEMENT[r12(palace) - 1]


@dataclass(frozen=True)
class Triple:
    y: int
    m: int
    d: int

    @staticmethod
    def make(y, m, d):
        return Triple(r12(y), r12(m), r12(d))

    def __add__(self, o):
        return Triple.make(self.y + o.y, self.m + o.m, self.d + o.d)

    def adv(self, n):
        return Triple.make(self.y + n, self.m + n, self.d + n)

    @property
    def life(self):
        return life_digit(self.y + self.m + self.d)


@dataclass(frozen=True)
class Reading:
    verdict: int
    result: int  # 果
    cause: int   # 因

    @property
    def text(self):
        return f"{VERDICTS[self.verdict]}{self.result}因{self.cause}"


@dataclass(frozen=True)
class Row:
    index: int
    palace: int
    triple: Triple
    reading: Reading

    @property
    def text(self):
        return f"{self.palace}宮{self.reading.text}"


def read(t):
    ye, me = element_of(t.y), element_of(t.m)
    a, b = r12(t.y + t.d), r12(t.m + t.d)
    if ye == me:
        return Reading(NEUTRAL, t.d, r12(a + b))
    if GENERATES[ye] == me:
        return Reading(GOOD, b, a)
    if GENERATES[me] == ye:
        return Reading(GOOD, a, b)
    if OVERCOMES[ye] == me:
        return Reading(BAD, b, a)
    return Reading(BAD, a, b)


def chart(start, t0):
    return [Row(i, r12(start - i), t0.adv(i), read(t0.adv(i))) for i in range(12)]


def natal_style(t):
    return chart(t.life, t.adv(1))


class Destiny:
    def __init__(self, y, m, d):
        self.by, self.bm, self.bd = y, m, d
        self.triple = Triple.make(life_digit(y), life_digit(m), life_digit(d))
        self.life = self.triple.life
        self.natal = natal_style(self.triple)

    @property
    def type(self):
        return r9(self.life)

    def row_index(self, year):
        return (year - self.by + 1) % 12

    def year(self, y):
        return self.natal[self.row_index(y)]

    @property
    def _first_end(self):
        return self.by + (8 - self.life % 9)

    def luck_period(self, y):
        if y < self.by:
            upper = self.by
            while y < upper - 9:
                upper -= 9
            s, e = upper - 9, upper - 1
        else:
            s, e = self.by, self._first_end
            if y > e:
                s = e + 1 + ((y - e - 1) // 9) * 9
                e = s + 8
        return s, e, self.year(s)

    def luck_aspects(self, y):
        s, e, _ = self.luck_period(y)
        k0 = self.row_index(e)
        out = []
        for i in range(1, 13):
            r = self.natal[(k0 + i - 1) % 12]
            out.append(Row(r.index, i, r.triple, r.reading))
        return out

    def triggered_aspects(self, y):
        p = self.year(y).palace
        return [a for a in self.luck_aspects(y) if a.reading.result == p or a.reading.cause == p]

    def triggered_natal(self, y):
        p = self.luck_period(y)[2].palace
        return [r for r in self.natal if r.reading.result == p or r.reading.cause == p]

    def month_chart(self, y):
        _, _, lp = self.luck_period(y)
        yr = self.year(y)
        return chart(r12(yr.palace - 1), lp.triple + yr.triple)

    def month(self, m, y):
        return self.month_chart(y)[r12(m) - 1]

    def day(self, m, d):
        s = digit_sum(m) + digit_sum(d)
        base = r12(self.life + r12(self.life + m))
        return r12(base + s), r9(self.life + s)


def synastry(a, b):
    t = a.triple + b.triple
    return t.life, natal_style(t)


if __name__ == "__main__":
    # HANDOFF.md §3.8 驗證範例
    d = Destiny(2006, 1, 14)
    print("本命：", "、".join(r.text for r in d.natal))
    assert "、".join(r.text for r in d.natal) == (
        "5宮壞3因8、4宮壞10因5、3宮壞12因7、2宮好2因9、1宮壞11因4、12宮正11因7、"
        "11宮壞8因3、10宮好10因5、9宮好12因7、8宮壞9因2、7宮壞4因11、6宮正5因7")
    assert d.year(2025).text == "9宮好12因7"
    assert [a.text for a in d.triggered_aspects(2025)] == ["6宮好2因9", "12宮壞9因2"]
    assert d.year(2026).text == "8宮壞9因2"
    assert [a.text for a in d.triggered_aspects(2026)] == ["3宮壞3因8", "9宮壞8因3"]
    s, e, row = d.luck_period(2026)
    assert (s, e, row.text) == (2019, 2027, "3宮壞12因7")
    assert [r.text for r in d.triggered_natal(2026)] == ["5宮壞3因8", "11宮壞8因3"]
    print("HANDOFF §3.8 驗證通過 ✓")
