# -*- coding: utf-8 -*-
"""
干支與農曆（UTC+8）。

農曆規則（現行《農曆的編算和頒行》）：
  - 朔日為月首；含冬至的月為十一月
  - 兩個冬至月之間若有 13 個月，則第一個不含中氣的月為閏月
"""
import astro

STEMS = "甲乙丙丁戊己庚辛壬癸"
BRANCHES = "子丑寅卯辰巳午未申酉戌亥"
ZODIAC = "鼠牛虎兔龍蛇馬羊猴雞狗豬"
LUNAR_MONTH_NAMES = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "臘"]


def ganzhi(i):
    """六十甲子序號（0=甲子）→ 字串。"""
    return STEMS[i % 10] + BRANCHES[i % 12]


def gz_index(stem, branch):
    """天干、地支序號 → 六十甲子序號。"""
    for i in range(60):
        if i % 10 == stem and i % 12 == branch:
            return i
    raise ValueError("stem/branch parity mismatch")


def lunar_day_name(d):
    if d == 10:
        return "初十"
    if d == 20:
        return "二十"
    if d == 30:
        return "三十"
    tens = ["初", "十", "廿", "三"][(d - 1) // 10]
    return tens + "一二三四五六七八九十"[(d - 1) % 10]


_cache = {}


def _winter_solstice_day(y):
    return astro.local_day(astro.solar_term_jd(y, 270))


def _months_of_span(y):
    """
    回傳從 y-1 年冬至所在月（十一月）起，到 y 年冬至所在月之後一個月為止的月首清單：
    [(月首日序號, 月份數字, 是否閏月), ...]
    """
    if y in _cache:
        return _cache[y]
    ws0, ws1 = _winter_solstice_day(y - 1), _winter_solstice_day(y)
    k0 = astro.new_moon_on_or_before(ws0)
    k1 = astro.new_moon_on_or_before(ws1)
    starts = [astro.local_day(astro.new_moon_jd(k)) for k in range(k0, k1 + 2)]
    n = k1 - k0  # 兩個十一月之間的月數
    leap_idx = -1
    if n == 13:
        # 中氣：黃經為 30 的倍數
        zq = []
        for yy in (y - 1, y):
            for lon in range(0, 360, 30):
                zq.append(astro.local_day(astro.solar_term_jd(yy, lon)))
        for i in range(n):
            a, b = starts[i], starts[i + 1]
            if not any(a <= t < b for t in zq):
                leap_idx = i
                break
    out = []
    num = 11
    for i in range(len(starts) - 1):
        if i == leap_idx:
            out.append((starts[i], (num - 2) % 12 + 1, True))  # 沿用上一個月的數字
            continue
        out.append((starts[i], num, False))
        num = num % 12 + 1
    _cache[y] = out
    return out


def solar_to_lunar(y, m, d):
    """公曆 → (農曆年, 月, 日, 是否閏月)。農曆年以正月初一為界。"""
    day = astro.day_number(y, m, d)
    span_year = y + 1 if day >= _months_of_span(y + 1)[0][0] else y
    months = _months_of_span(span_year)
    for i, (start, num, leap) in enumerate(months):
        nxt = months[i + 1][0] if i + 1 < len(months) else _months_of_span(span_year + 1)[1][0]
        if start <= day < nxt:
            # 十一、十二月（在正月之前）屬於前一個農曆年
            before_new_year = all(not (n == 1 and not lp) for (_, n, lp) in months[:i + 1])
            ly = span_year - 1 if before_new_year else span_year
            return ly, num, day - start + 1, leap
    raise RuntimeError("lunar conversion failed")


def lunar_year_ganzhi(lunar_year):
    return (lunar_year - 4) % 60


def lunar_text(ly, lm, ld, leap):
    return f"{ganzhi(lunar_year_ganzhi(ly))}年{'閏' if leap else ''}{LUNAR_MONTH_NAMES[lm - 1]}月{lunar_day_name(ld)}"


if __name__ == "__main__":
    # 春節（正月初一）
    cny = {2000: (2, 5), 1985: (2, 20), 1990: (1, 27), 2006: (1, 29), 2017: (1, 28), 2020: (1, 25),
           2021: (2, 12), 2022: (2, 1), 2023: (1, 22), 2024: (2, 10), 2025: (1, 29), 2026: (2, 17),
           2030: (2, 3), 1976: (1, 31), 1966: (1, 21), 1955: (1, 24)}
    for y, (m, d) in cny.items():
        r = solar_to_lunar(y, m, d)
        assert r == (y, 1, 1, False), (y, r)
        assert solar_to_lunar(y, m, d - 1 if d > 1 else d)[1:] != (1, 1, False) or d == 1
    # 閏月
    leaps = {2001: 4, 2004: 2, 2006: 7, 2009: 5, 2012: 4, 2014: 9, 2017: 6, 2020: 4, 2023: 2, 2025: 6, 2028: 5, 2033: 11}
    for y, lm in leaps.items():
        found = set()
        for dn in range(astro.day_number(y, 1, 1), astro.day_number(y + 1, 1, 1)):
            yy, mm, dd, _ = astro.date_from_jd(dn - 0.5)
            r = solar_to_lunar(yy, mm, dd)
            if r[3] and r[0] == y:
                found.add(r[1])
        assert found == {lm}, (y, found)
    # 中秋、端午
    assert solar_to_lunar(2024, 9, 17) == (2024, 8, 15, False)
    assert solar_to_lunar(2025, 10, 6) == (2025, 8, 15, False)
    assert solar_to_lunar(2024, 6, 10) == (2024, 5, 5, False)
    assert solar_to_lunar(2025, 7, 25) == (2025, 6, 1, True)   # 閏六月初一
    assert solar_to_lunar(2033, 12, 22) == (2033, 11, 1, True)  # 2033 閏十一月
    print(lunar_text(*solar_to_lunar(2026, 9, 29)))
    print("農曆驗證通過 ✓")
