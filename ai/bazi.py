# -*- coding: utf-8 -*-
"""
八字（四柱）排盤與基本分析。Swift 端 BaZi.swift 為逐行對應的移植。

  年柱：以立春為界          月柱：以十二「節」為界（五虎遁定月干）
  日柱：儒略日推算（23:00 起算次日子時）  時柱：五鼠遁定時干
  分析：五行統計（含藏干）、十神、身強弱（簡化評分）、喜用傾向、大運（含起運歲數）、流年
時間一律視為 UTC+8 當地鐘錶時間，不做真太陽時校正。
"""
import math

import astro
from chinese_cal import BRANCHES, STEMS, ganzhi, gz_index

WUXING = "木火土金水"
STEM_EL = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4]           # 甲乙木 丙丁火 戊己土 庚辛金 壬癸水
BRANCH_EL = [4, 2, 0, 0, 2, 1, 1, 2, 3, 3, 2, 4]    # 子水 丑土 寅木 卯木 辰土 巳火 午火 未土 申金 酉金 戌土 亥水
# 地支藏干（本氣在前）
HIDDEN = [[9], [5, 9, 7], [0, 2, 4], [1], [4, 1, 9], [2, 6, 4],
          [3, 5], [5, 3, 1], [6, 8, 4], [7], [4, 7, 3], [8, 0]]
TEN_GODS = ["比肩", "劫財", "食神", "傷官", "偏財", "正財", "七殺", "正官", "偏印", "正印"]


def generates(a):
    return (a + 1) % 5


def controls(a):
    return (a + 2) % 5


def ten_god(day_stem, other_stem):
    dm, ot = STEM_EL[day_stem], STEM_EL[other_stem]
    same_pol = (day_stem % 2) == (other_stem % 2)
    if ot == dm:
        rel = 0
    elif ot == generates(dm):
        rel = 1
    elif ot == controls(dm):
        rel = 2
    elif dm == controls(ot):
        rel = 3
    else:
        rel = 4
    return TEN_GODS[rel * 2 + (0 if same_pol else 1)]


def jie_index(jd_ut):
    """回傳該時刻所屬的節月：0=寅月 … 11=丑月（依太陽視黃經，立春 315° 起每 30°）。"""
    lon = astro.sun_longitude(jd_ut + astro.delta_t_days(2000))
    return int(((lon - 315.0) % 360.0) // 30.0)


class BaZi:
    def __init__(self, y, m, d, hour=None, minute=0, male=True):
        self.male = male
        self.has_hour = hour is not None
        h = hour if hour is not None else 12
        jd = astro.jd_from_date(y, m, d, h + minute / 60.0) - astro.TZ   # UT
        self.jd = jd

        # 年柱（立春為界）
        lichun = astro.solar_term_jd(y, 315)
        yy = y if jd >= lichun else y - 1
        self.year = (yy - 4) % 60
        # 月柱
        mi = jie_index(jd)                       # 0=寅
        mstem = ((self.year % 10) % 5 * 2 + 2 + mi) % 10
        self.month = gz_index(mstem, (mi + 2) % 12)
        # 日柱（23 點起算次日）
        dn = astro.day_number(y, m, d) + (1 if h >= 23 else 0)
        self.day = (dn + 49) % 60
        # 時柱
        if self.has_hour:
            hb = ((h + 1) // 2) % 12
            hstem = ((self.day % 10) % 5 * 2 + hb) % 10
            self.hour = gz_index(hstem, hb)
        else:
            self.hour = None

    @property
    def pillars(self):
        return [p for p in (self.year, self.month, self.day, self.hour) if p is not None]

    @property
    def text(self):
        return "".join(ganzhi(p) for p in self.pillars)

    @property
    def day_master(self):
        return self.day % 10

    def element_counts(self):
        """五行分數：天干 1 分，地支藏干本氣 1 分、中餘氣 0.5／0.3，月支加倍。"""
        c = [0.0] * 5
        for i, p in enumerate(self.pillars):
            c[STEM_EL[p % 10]] += 1.0
            w = 2.0 if i == 1 else 1.0
            for j, hs in enumerate(HIDDEN[p % 12]):
                c[STEM_EL[hs]] += w * (1.0 if j == 0 else (0.5 if j == 1 else 0.3))
        return c

    def strength(self):
        """身強弱：同我（比劫）+ 生我（印）佔比。回傳 (是否身強, 佔比)。"""
        c = self.element_counts()
        dm = STEM_EL[self.day_master]
        support = c[dm] + c[(dm + 4) % 5]
        ratio = support / sum(c)
        return ratio >= 0.45, ratio

    def favorable(self):
        """喜用傾向（簡化）：身強喜 食傷／財／官殺中最弱者起算的兩行；身弱喜 印、比劫。"""
        strong, _ = self.strength()
        dm = STEM_EL[self.day_master]
        c = self.element_counts()
        if strong:
            cands = [generates(dm), controls(dm), (dm + 3) % 5]
            cands.sort(key=lambda e: c[e])
            return cands[:2]
        return [(dm + 4) % 5, dm]

    def gods(self):
        """四柱天干的十神（日柱標為「日主」）。"""
        out = []
        for i, p in enumerate(self.pillars):
            out.append("日主" if i == 2 else ten_god(self.day_master, p % 10))
        return out

    def luck(self, count=8):
        """大運：陽男陰女順排，陰男陽女逆排；起運歲數 = 到下（上）一個節的天數 ÷ 3。"""
        yang_year = (self.year % 10) % 2 == 0
        forward = yang_year == self.male
        # 找相鄰的節
        mi = jie_index(self.jd)
        lon_start = (315 + 30 * mi) % 360
        target = (lon_start + 30) % 360 if forward else lon_start
        y = astro.date_from_jd(self.jd)[0]
        cands = [astro.solar_term_jd(yy, target) for yy in (y - 1, y, y + 1)]
        if forward:
            t = min(x for x in cands if x > self.jd)
            days = t - self.jd
        else:
            t = max(x for x in cands if x <= self.jd)
            days = self.jd - t
        start_age = max(1, round(days / 3.0))
        step = 1 if forward else -1
        return start_age, [(self.month + step * (i + 1)) % 60 for i in range(count)]

    def year_god(self, year):
        """某年流年干支與其天干對日主的十神。"""
        g = (year - 4) % 60
        return g, ten_god(self.day_master, g % 10)


if __name__ == "__main__":
    # 日柱錨點：2000-01-01 戊午日、1949-10-01 甲子日
    assert ganzhi(BaZi(2000, 1, 1).day) == "戊午"
    assert ganzhi(BaZi(1949, 10, 1).day) == "甲子"
    # 年柱以立春為界（2024 立春 2/4 16:27）
    assert ganzhi(BaZi(2024, 2, 4, 12).year) == "癸卯"
    assert ganzhi(BaZi(2024, 2, 4, 18).year) == "甲辰"
    # 月柱：2024-03-01 丙寅月、2024-03-06 丁卯月、2025-01-10 丁丑月
    assert ganzhi(BaZi(2024, 3, 1).month) == "丙寅"
    assert ganzhi(BaZi(2024, 3, 6).month) == "丁卯"
    assert ganzhi(BaZi(2025, 1, 10).month) == "丁丑"
    # 時柱：甲日子時 甲子；戊日午時 戊午
    b = BaZi(2000, 1, 1, 12)          # 戊午日 午時 → 戊午時
    assert ganzhi(b.hour) == "戊午", ganzhi(b.hour)
    b = BaZi(1949, 10, 1, 0)          # 甲子日 子時 → 甲子時
    assert ganzhi(b.hour) == "甲子"
    # 23 點算次日
    assert ganzhi(BaZi(2000, 1, 1, 23).day) == "己未"
    b = BaZi(1990, 5, 20, 8, male=True)
    print(b.text, b.gods(), [round(x, 1) for x in b.element_counts()], b.strength(), b.favorable(), b.luck())
    print("八字驗證通過 ✓")
