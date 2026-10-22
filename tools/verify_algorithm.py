# -*- coding: utf-8 -*-
"""九型十二宮 演算法驗證 — 對照 Journal.pdf 的所有範例"""

def r12(n):
    return ((n - 1) % 12) + 1

def r9(n):
    return ((n - 1) % 9) + 1

def digit_root9(n):
    """生命靈數式化約：反覆數字和直到 1..9"""
    n = abs(n)
    while n > 9:
        n = sum(int(c) for c in str(n))
    return 9 if n == 0 else n

def digit_sum(n):
    return sum(int(c) for c in str(abs(n)))

# 十二宮五行
ELEM = {1:'火',2:'金',3:'水',4:'水',5:'火',6:'水',7:'金',8:'火',9:'木',10:'土',11:'土',12:'木'}
GEN = {'木':'火','火':'土','土':'金','金':'水','水':'木'}   # a 生 b
OVR = {'木':'土','土':'水','水':'火','火':'金','金':'木'}   # a 克 b

def verdict(y, m, d):
    """回傳 (種類, 果數, 因數)"""
    ey, em = ELEM[y], ELEM[m]
    if ey == em:
        return ('正', d, r12(r12(y + d) + r12(m + d)))
    if GEN[ey] == em:            # 年生月 -> 受生者是月
        return ('好', r12(m + d), r12(y + d))
    if GEN[em] == ey:            # 月生年 -> 受生者是年
        return ('好', r12(y + d), r12(m + d))
    if OVR[ey] == em:            # 年克月 -> 被克者是月
        return ('壞', r12(m + d), r12(y + d))
    return ('壞', r12(y + d), r12(m + d))   # 月克年 -> 被克者是年

def natal_triple(year, month, day):
    y = digit_root9(year)
    m = digit_root9(month)
    d = digit_root9(day)
    return (y, m, d)

def life_number(t):
    return digit_root9(t[0] + t[1] + t[2])

def descending_chart(start_palace, first_triple):
    """由 start_palace 起逆序 12 宮，三柱每列 +1（十二進制）"""
    rows = []
    for k in range(12):
        palace = ((start_palace - 1 - k) % 12) + 1
        t = tuple(r12(v + k) for v in first_triple)
        rows.append((palace, t, verdict(*t)))
    return rows

def natal_chart(triple):
    """本命盤：首列 = 靈數宮，三柱由 本命三柱+1 起算（末列回到本命三柱）"""
    ln = life_number(triple)
    first = tuple(r12(v + 1) for v in triple)
    return descending_chart(ln, first)

def fmt(rows):
    out = []
    for p, t, v in rows:
        out.append("%d宮 %d;%d;%d %s%d因%d" % (p, t[0], t[1], t[2], v[0], v[1], v[2]))
    return out

fails = []
def check(label, got, want):
    ok = got == want
    if not ok:
        fails.append("%s  得到:%s  期望:%s" % (label, got, want))
    print(("  OK  " if ok else " FAIL ") + label + "  -> " + str(got) + ("" if ok else "   期望:" + str(want)))

print("=== 1. 生命靈數化約 (PDF p.1) ===")
check("2006年", digit_root9(2006), 8)
check("1月", digit_root9(1), 1)
check("14日", digit_root9(14), 5)
check("2006-01-14 靈數", life_number((8,1,5)), 5)
check("1996年", digit_root9(1996), 7)
check("12月", digit_root9(12), 3)
check("19日", digit_root9(19), 1)

print()
print("=== 2. 本命盤 8;1;5 十二列 (PDF p.1-2) ===")
expect = [
 "5宮 9;2;6 壞3因8",
 "4宮 10;3;7 壞10因5",
 "3宮 11;4;8 壞12因7",
 "2宮 12;5;9 好2因9",
 "1宮 1;6;10 壞11因4",
 "12宮 2;7;11 正11因7",
 "11宮 3;8;12 壞8因3",
 "10宮 4;9;1 好10因5",
 "9宮 5;10;2 好12因7",
 "8宮 6;11;3 壞9因2",
 "7宮 7;12;4 壞4因11",
 "6宮 8;1;5 正5因7",
]
got = fmt(natal_chart((8,1,5)))
for g, e in zip(got, expect):
    check("本命列", g, e)

print()
print("=== 3. 流年 (PDF p.2)  首列(命宮)= 出生年+11 ===")
BIRTH = 2006
LN = 5
def year_row(birth_year, life_num, target_year):
    idx = (target_year - birth_year + 1) % 12          # 出生年落在第 2 列(索引1)
    palace = ((life_num - 1 - idx) % 12) + 1
    return palace, idx

for y, want_p in [(2017,5),(2018,4),(2019,3),(2020,2),(2021,1),(2022,12),
                  (2023,11),(2024,10),(2025,9),(2026,8),(2027,7),(2028,6),
                  (2006,4),(2029,5),(2005,5),(2035,11)]:
    check("%d年宮位" % y, year_row(BIRTH, LN, y)[0], want_p)

print()
print("=== 4. 大運 (PDF p.2-3) ===")
def luck_periods(birth_year, life_num, count=6):
    pos = (life_num % 9) + 1        # 出生年在九宮的位置
    end = birth_year + (9 - pos)
    periods = [(birth_year, end)]
    s = end + 1
    for _ in range(count - 1):
        periods.append((s, s + 8))
        s += 9
    return periods

lp = luck_periods(BIRTH, LN, 4)
check("大運區間", lp, [(2006,2009),(2010,2018),(2019,2027),(2028,2036)])
rows = natal_chart((8,1,5))
for (s, e), want in zip(lp, ["4宮 10;3;7 壞10因5","12宮 2;7;11 正11因7",
                             "3宮 11;4;8 壞12因7","6宮 8;1;5 正5因7"]):
    idx = (s - BIRTH + 1) % 12
    check("大運 %d-%d 取首年運" % (s, e), fmt([rows[idx]])[0], want)

print()
print("=== 5. 日運 (PDF p.3) ===")
def day_fortune(life_num, month, day):
    a = r12(life_num + month)
    b = r12(life_num + a)
    return r12(b + digit_sum(month) + digit_sum(day))

def night_fortune(life_num, month, day):
    return r9(life_num + digit_sum(month) + digit_sum(day))

check("靈數5 8月17日 白天", day_fortune(5, 8, 17), 10)
check("靈數7 3月4日 白天",  day_fortune(7, 3, 4), 12)
check("靈數5 8月17日 晚上", night_fortune(5, 8, 17), 3)
check("靈數7 3月4日 晚上",  night_fortune(7, 3, 4), 5)

print()
print("=== 6. 月運 2026年 (PDF p.3) ===")
# 大運盤(2019-2027) = 3宮 11;4;8 ; 流年2026 = 8宮 6;11;3
luck_t = (11, 4, 8)
year_t = (6, 11, 3)
base = tuple(r12(a + b) for a, b in zip(luck_t, year_t))
check("月運基礎三柱", base, (5, 3, 11))
# 首月宮位 = 流年宮位 - 1
first_palace = ((8 - 1 - 1) % 12) + 1
check("1月宮位", first_palace, 7)
expect_m = [
 "7宮 5;3;11 壞4因2",
 "6宮 6;4;12 正12因10",
 "5宮 7;5;1 壞8因6",
 "4宮 8;6;2 壞10因8",
 "3宮 9;7;3 壞12因10",
 "2宮 10;8;4 好2因12",
 "1宮 11;9;5 壞4因2",
 "12宮 12;10;6 壞4因6",
 "11宮 1;11;7 好6因8",
 "10宮 2;12;8 壞8因10",
 "9宮 3;1;9 壞10因12",
 "8宮 4;2;10 好2因12",
]
# 月運盤：首列就是 base（不 +1）
got_m = fmt(descending_chart(first_palace, base))
for g, e in zip(got_m, expect_m):
    check("月運列", g, e)

print()
print("=== 7. 合盤 (PDF p.4) ===")
a = natal_triple(2006, 1, 14)
b = natal_triple(2007, 1, 23)
check("盤A", a, (8,1,5))
check("盤B", b, (9,1,5))
comp = tuple(r12(x + y) for x, y in zip(a, b))
check("合盤三柱", comp, (5,2,10))
check("合盤靈數", life_number(comp), 8)
expect_s = [
 "8宮 6;3;11 正11因7",
 "7宮 7;4;12 好4因7",
 "6宮 8;5;1 正1因3",
 "5宮 9;6;2 好11因8",
 "4宮 10;7;3 好10因1",
 "3宮 11;8;4 好3因12",
 "2宮 12;9;5 正5因7",
 "1宮 1;10;6 好4因7",
 "12宮 2;11;7 好9因6",
 "11宮 3;12;8 好8因11",
 "10宮 4;1;9 壞10因1",
 "9宮 5;2;10 壞12因3",   # 文件原寫「因7」，作者已確認為筆誤
]
got_s = fmt(natal_chart(comp))
for g, e in zip(got_s, expect_s):
    check("合盤列", g, e)

print()
print("=" * 60)
if fails:
    print("不符 %d 項：" % len(fails))
    for f in fails:
        print("  " + f)
else:
    print("全部 %s 項通過" % "範例")
