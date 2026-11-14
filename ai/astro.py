# -*- coding: utf-8 -*-
"""
天文基礎：節氣（太陽視黃經）與朔（新月），用來排八字月柱與農曆。

演算法：Jean Meeus《Astronomical Algorithms》
  - 太陽視黃經：第 25 章低精度公式（誤差約 0.01°，節氣時刻誤差約十幾分鐘）
  - 新月：第 49 章（含 25 項週期修正與 14 項行星修正，誤差約 1 分鐘內）
時區固定為 UTC+8（北京／台北時間）。Swift 端 Astro.swift 為逐行對應的移植。
"""
import math

TZ = 8.0 / 24.0          # UTC+8
SYNODIC = 29.530588861


def jd_from_date(y, m, d, h=0.0):
    """公曆日期（含小數時）→ 儒略日（格里曆）。"""
    if m <= 2:
        y -= 1
        m += 12
    a = y // 100
    b = 2 - a + a // 4
    return math.floor(365.25 * (y + 4716)) + math.floor(30.6001 * (m + 1)) + d + h / 24.0 + b - 1524.5


def date_from_jd(jd):
    """儒略日 → (y, m, d, 小時)。"""
    jd += 0.5
    z = math.floor(jd)
    f = jd - z
    alpha = math.floor((z - 1867216.25) / 36524.25)
    a = z + 1 + alpha - alpha // 4
    b = a + 1524
    c = math.floor((b - 122.1) / 365.25)
    d = math.floor(365.25 * c)
    e = math.floor((b - d) / 30.6001)
    day = b - d - math.floor(30.6001 * e)
    month = e - 1 if e < 14 else e - 13
    year = c - 4716 if month > 2 else c - 4715
    return int(year), int(month), int(day), f * 24.0


def delta_t_days(year):
    """ΔT（TT − UT）近似，單位：日。"""
    t = year - 2000
    if year < 2005:
        dt = 63.86 + 0.3345 * t - 0.060374 * t ** 2 + 0.0017275 * t ** 3 + 0.000651814 * t ** 4 + 0.00002373599 * t ** 5
        if year < 1986:
            u = year - 1975
            dt = 45.45 + 1.067 * u - u * u / 260 - u ** 3 / 718
            if year < 1961:
                u = year - 1950
                dt = 29.07 + 0.407 * u - u * u / 233 + u ** 3 / 2547
    elif year < 2050:
        dt = 62.92 + 0.32217 * t + 0.005589 * t ** 2
    else:
        dt = -20 + 32 * ((year - 1820) / 100) ** 2 - 0.5628 * (2150 - year)
    return dt / 86400.0


def sun_longitude(jde):
    """太陽視黃經（度，0–360），輸入為力學時儒略日。"""
    t = (jde - 2451545.0) / 36525.0
    l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
    m = math.radians(357.52911 + 35999.05029 * t - 0.0001537 * t * t)
    c = ((1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(m)
         + (0.019993 - 0.000101 * t) * math.sin(2 * m) + 0.000289 * math.sin(3 * m))
    omega = math.radians(125.04 - 1934.136 * t)
    lam = l0 + c - 0.00569 - 0.00478 * math.sin(omega)
    return lam % 360.0


def solar_term_jd(year, longitude):
    """指定年份中，太陽視黃經達到 longitude 的時刻（UT 儒略日）。"""
    # 以春分（3/20 附近）為基準估計
    est = jd_from_date(year, 3, 20) + (longitude % 360.0) * 365.2422 / 360.0
    if est >= jd_from_date(year + 1, 1, 1):
        est -= 365.2422
    jde = est
    for _ in range(50):
        diff = (longitude - sun_longitude(jde) + 180.0) % 360.0 - 180.0
        jde += diff * 365.2422 / 360.0
        if abs(diff) < 1e-7:
            break
    return jde - delta_t_days(year)


def new_moon_jde(k):
    """第 k 個新月（k=0 為 2000-01-06）的力學時儒略日。"""
    t = k / 1236.85
    jde = (2451550.09766 + 29.530588861 * k + 0.00015437 * t * t
           - 0.000000150 * t ** 3 + 0.00000000073 * t ** 4)
    e = 1 - 0.002516 * t - 0.0000074 * t * t
    r = math.radians
    m = r(2.5534 + 29.10535670 * k - 0.0000014 * t * t - 0.00000011 * t ** 3)
    mp = r(201.5643 + 385.81693528 * k + 0.0107582 * t * t + 0.00001238 * t ** 3 - 0.000000058 * t ** 4)
    f = r(160.7108 + 390.67050284 * k - 0.0016118 * t * t - 0.00000227 * t ** 3 + 0.000000011 * t ** 4)
    om = r(124.7746 - 1.56375588 * k + 0.0020672 * t * t + 0.00000215 * t ** 3)
    s = math.sin
    corr = (-0.40720 * s(mp) + 0.17241 * e * s(m) + 0.01608 * s(2 * mp) + 0.01039 * s(2 * f)
            + 0.00739 * e * s(mp - m) - 0.00514 * e * s(mp + m) + 0.00208 * e * e * s(2 * m)
            - 0.00111 * s(mp - 2 * f) - 0.00057 * s(mp + 2 * f) + 0.00056 * e * s(2 * mp + m)
            - 0.00042 * s(3 * mp) + 0.00042 * e * s(m + 2 * f) + 0.00038 * e * s(m - 2 * f)
            - 0.00024 * e * s(2 * mp - m) - 0.00017 * s(om) - 0.00007 * s(mp + 2 * m)
            + 0.00004 * s(2 * mp - 2 * f) + 0.00004 * s(3 * m) + 0.00003 * s(mp + m - 2 * f)
            + 0.00003 * s(2 * mp + 2 * f) - 0.00003 * s(mp + m + 2 * f) + 0.00003 * s(mp - m + 2 * f)
            - 0.00002 * s(mp - m - 2 * f) - 0.00002 * s(3 * mp + m) + 0.00002 * s(4 * mp))
    a = [299.77 + 0.107408 * k - 0.009173 * t * t, 251.88 + 0.016321 * k, 251.83 + 26.651886 * k,
         349.42 + 36.412478 * k, 84.66 + 18.206239 * k, 141.74 + 53.303771 * k, 207.14 + 2.453732 * k,
         154.84 + 7.306860 * k, 34.52 + 27.261239 * k, 207.19 + 0.121824 * k, 291.34 + 1.844379 * k,
         161.72 + 24.198154 * k, 239.56 + 25.513099 * k, 331.55 + 3.592518 * k]
    coef = [0.000325, 0.000165, 0.000164, 0.000126, 0.000110, 0.000062, 0.000060,
            0.000056, 0.000047, 0.000042, 0.000040, 0.000037, 0.000035, 0.000023]
    corr += sum(c * math.sin(r(x)) for c, x in zip(coef, a))
    return jde + corr


def new_moon_jd(k):
    jde = new_moon_jde(k)
    y = 2000 + k / 12.3685
    return jde - delta_t_days(y)


def local_day(jd_ut):
    """UT 儒略日 → UTC+8 的「日序號」（整數，同一天相同）。"""
    return math.floor(jd_ut + 0.5 + TZ)


def day_number(y, m, d):
    """公曆日期 → 日序號（與 local_day 同一尺度）。"""
    return int(jd_from_date(y, m, d) + 0.5)


def new_moon_on_or_before(day):
    """回傳日序號 day 當天或之前最近一次新月的日序號。"""
    k = math.floor((day - 2451550.1) / SYNODIC) + 1
    while local_day(new_moon_jd(k)) > day:
        k -= 1
    while local_day(new_moon_jd(k + 1)) <= day:
        k += 1
    return k
