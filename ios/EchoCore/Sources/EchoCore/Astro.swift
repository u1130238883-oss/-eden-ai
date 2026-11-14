import Foundation

/// 天文基礎（逐行對應 ai/astro.py）：節氣（太陽視黃經）與朔（新月），時區 UTC+8。
public enum Astro {
    static let tz = 8.0 / 24.0
    static let synodic = 29.530588861

    /// Python 風格取餘（結果與除數同號）
    @inline(__always) static func pmod(_ a: Double, _ n: Double) -> Double {
        let r = a.truncatingRemainder(dividingBy: n)
        return r < 0 ? r + n : r
    }

    @inline(__always) static func pmod(_ a: Int, _ n: Int) -> Int {
        let r = a % n
        return r < 0 ? r + n : r
    }

    static func rad(_ d: Double) -> Double { d * .pi / 180 }

    /// 公曆日期（含小數時）→ 儒略日
    public static func jd(_ year: Int, _ month: Int, _ day: Int, hour: Double = 0) -> Double {
        var y = year, m = month
        if m <= 2 { y -= 1; m += 12 }
        let a = Int(floor(Double(y) / 100))
        let b = 2 - a + Int(floor(Double(a) / 4))
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + Double(day) + hour / 24 + Double(b) - 1524.5
    }

    /// 儒略日 → (年, 月, 日, 小時)
    public static func date(fromJD jdIn: Double) -> (Int, Int, Int, Double) {
        let jd = jdIn + 0.5
        let z = floor(jd)
        let f = jd - z
        let alpha = floor((z - 1867216.25) / 36524.25)
        let a = z + 1 + alpha - floor(alpha / 4)
        let b = a + 1524
        let c = floor((b - 122.1) / 365.25)
        let d = floor(365.25 * c)
        let e = floor((b - d) / 30.6001)
        let day = b - d - floor(30.6001 * e)
        let month = e < 14 ? e - 1 : e - 13
        let year = month > 2 ? c - 4716 : c - 4715
        return (Int(year), Int(month), Int(day), f * 24)
    }

    static func deltaTDays(_ year: Double) -> Double {
        let t = year - 2000
        var dt: Double
        if year < 2005 {
            dt = 63.86 + 0.3345 * t - 0.060374 * t * t + 0.0017275 * pow(t, 3) + 0.000651814 * pow(t, 4) + 0.00002373599 * pow(t, 5)
            if year < 1986 {
                let u = year - 1975
                dt = 45.45 + 1.067 * u - u * u / 260 - pow(u, 3) / 718
                if year < 1961 {
                    let u = year - 1950
                    dt = 29.07 + 0.407 * u - u * u / 233 + pow(u, 3) / 2547
                }
            }
        } else if year < 2050 {
            dt = 62.92 + 0.32217 * t + 0.005589 * t * t
        } else {
            dt = -20 + 32 * pow((year - 1820) / 100, 2) - 0.5628 * (2150 - year)
        }
        return dt / 86400
    }

    /// 太陽視黃經（度）
    public static func sunLongitude(_ jde: Double) -> Double {
        let t = (jde - 2451545.0) / 36525.0
        let l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
        let m = rad(357.52911 + 35999.05029 * t - 0.0001537 * t * t)
        let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(m)
            + (0.019993 - 0.000101 * t) * sin(2 * m) + 0.000289 * sin(3 * m)
        let omega = rad(125.04 - 1934.136 * t)
        let lam = l0 + c - 0.00569 - 0.00478 * sin(omega)
        return pmod(lam, 360)
    }

    /// 指定年份中太陽視黃經達到 longitude 的時刻（UT 儒略日）
    public static func solarTermJD(_ year: Int, _ longitude: Double) -> Double {
        var est = jd(year, 3, 20) + pmod(longitude, 360) * 365.2422 / 360
        if est >= jd(year + 1, 1, 1) { est -= 365.2422 }
        var jde = est
        for _ in 0..<50 {
            let diff = pmod(longitude - sunLongitude(jde) + 180, 360) - 180
            jde += diff * 365.2422 / 360
            if abs(diff) < 1e-7 { break }
        }
        return jde - deltaTDays(Double(year))
    }

    static func newMoonJDE(_ kk: Int) -> Double {
        let k = Double(kk)
        let t = k / 1236.85
        var jde = 2451550.09766 + 29.530588861 * k + 0.00015437 * t * t - 0.000000150 * pow(t, 3) + 0.00000000073 * pow(t, 4)
        let e = 1 - 0.002516 * t - 0.0000074 * t * t
        let m = rad(2.5534 + 29.10535670 * k - 0.0000014 * t * t - 0.00000011 * pow(t, 3))
        let mp = rad(201.5643 + 385.81693528 * k + 0.0107582 * t * t + 0.00001238 * pow(t, 3) - 0.000000058 * pow(t, 4))
        let f = rad(160.7108 + 390.67050284 * k - 0.0016118 * t * t - 0.00000227 * pow(t, 3) + 0.000000011 * pow(t, 4))
        let om = rad(124.7746 - 1.56375588 * k + 0.0020672 * t * t + 0.00000215 * pow(t, 3))
        var corr = -0.40720 * sin(mp) + 0.17241 * e * sin(m) + 0.01608 * sin(2 * mp) + 0.01039 * sin(2 * f)
        corr += 0.00739 * e * sin(mp - m) - 0.00514 * e * sin(mp + m) + 0.00208 * e * e * sin(2 * m)
        corr += -0.00111 * sin(mp - 2 * f) - 0.00057 * sin(mp + 2 * f) + 0.00056 * e * sin(2 * mp + m)
        corr += -0.00042 * sin(3 * mp) + 0.00042 * e * sin(m + 2 * f) + 0.00038 * e * sin(m - 2 * f)
        corr += -0.00024 * e * sin(2 * mp - m) - 0.00017 * sin(om) - 0.00007 * sin(mp + 2 * m)
        corr += 0.00004 * sin(2 * mp - 2 * f) + 0.00004 * sin(3 * m) + 0.00003 * sin(mp + m - 2 * f)
        corr += 0.00003 * sin(2 * mp + 2 * f) - 0.00003 * sin(mp + m + 2 * f) + 0.00003 * sin(mp - m + 2 * f)
        corr += -0.00002 * sin(mp - m - 2 * f) - 0.00002 * sin(3 * mp + m) + 0.00002 * sin(4 * mp)
        let a: [Double] = [299.77 + 0.107408 * k - 0.009173 * t * t, 251.88 + 0.016321 * k, 251.83 + 26.651886 * k,
                           349.42 + 36.412478 * k, 84.66 + 18.206239 * k, 141.74 + 53.303771 * k, 207.14 + 2.453732 * k,
                           154.84 + 7.306860 * k, 34.52 + 27.261239 * k, 207.19 + 0.121824 * k, 291.34 + 1.844379 * k,
                           161.72 + 24.198154 * k, 239.56 + 25.513099 * k, 331.55 + 3.592518 * k]
        let coef: [Double] = [0.000325, 0.000165, 0.000164, 0.000126, 0.000110, 0.000062, 0.000060,
                              0.000056, 0.000047, 0.000042, 0.000040, 0.000037, 0.000035, 0.000023]
        for i in 0..<14 { corr += coef[i] * sin(rad(a[i])) }
        jde += corr
        return jde
    }

    public static func newMoonJD(_ k: Int) -> Double {
        newMoonJDE(k) - deltaTDays(2000 + Double(k) / 12.3685)
    }

    /// UT 儒略日 → UTC+8 的日序號
    public static func localDay(_ jdUT: Double) -> Int { Int(floor(jdUT + 0.5 + tz)) }

    /// 公曆日期 → 日序號
    public static func dayNumber(_ y: Int, _ m: Int, _ d: Int) -> Int { Int(jd(y, m, d) + 0.5) }

    static func newMoon(onOrBefore day: Int) -> Int {
        var k = Int(floor((Double(day) - 2451550.1) / synodic)) + 1
        while localDay(newMoonJD(k)) > day { k -= 1 }
        while localDay(newMoonJD(k + 1)) <= day { k += 1 }
        return k
    }
}
