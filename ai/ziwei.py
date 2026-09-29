# -*- coding: utf-8 -*-
"""
紫微斗數排盤（三合派基本盤）。Swift 端 ZiWei.swift 為逐行對應的移植。

  輸入：公曆生日、時辰、性別 → 轉農曆（閏月依「前半月算本月、後半月算下月」）
  命宮／身宮、十二宮、宮干（五虎遁）、五行局（命宮納音）
  十四主星、文昌文曲、左輔右弼、祿存擎羊陀羅、地空地劫、生年四化、大限
"""
from chinese_cal import BRANCHES, STEMS, lunar_year_ganzhi, solar_to_lunar

PALACES = ["命宮", "兄弟", "夫妻", "子女", "財帛", "疾厄", "遷移", "交友", "官祿", "田宅", "福德", "父母"]
MAIN_STARS = ["紫微", "天機", "太陽", "武曲", "天同", "廉貞", "天府", "太陰", "貪狼", "巨門", "天相", "天梁", "七殺", "破軍"]
JU_NAMES = {2: "水二局", 3: "木三局", 4: "金四局", 5: "土五局", 6: "火六局"}

# 六十甲子納音五行（每兩個一組）：金=4 火=6 木=3 土=5 水=2（直接用局數表示）
_NAYIN_JU = [4, 6, 3, 5, 4, 6, 2, 5, 4, 3, 2, 5, 6, 3, 2, 4, 6, 3, 5, 4, 6, 2, 5, 4, 3, 2, 5, 6, 3, 2]

# 生年四化：[祿, 權, 科, 忌]
SIHUA = {
    "甲": ["廉貞", "破軍", "武曲", "太陽"], "乙": ["天機", "天梁", "紫微", "太陰"],
    "丙": ["天同", "天機", "文昌", "廉貞"], "丁": ["太陰", "天同", "天機", "巨門"],
    "戊": ["貪狼", "太陰", "右弼", "天機"], "己": ["武曲", "貪狼", "天梁", "文曲"],
    "庚": ["太陽", "武曲", "太陰", "天同"], "辛": ["巨門", "太陽", "文曲", "文昌"],
    "壬": ["天梁", "紫微", "左輔", "武曲"], "癸": ["破軍", "巨門", "太陰", "貪狼"],
}
SIHUA_NAMES = ["化祿", "化權", "化科", "化忌"]
LUCUN = [2, 3, 5, 6, 5, 6, 8, 9, 11, 0]  # 甲…癸 祿存所在地支


def nayin_ju(gz60):
    return _NAYIN_JU[gz60 // 2]


def gz60(stem, branch):
    for i in range(60):
        if i % 10 == stem and i % 12 == branch:
            return i
    raise ValueError


def ziwei_position(ju, day):
    """紫微星位置（地支序號）：找最小 x 使 (day+x) 可被局數整除。"""
    x = 0
    while (day + x) % ju:
        x += 1
    q = (day + x) // ju
    pos = 2 + q - 1                     # 由寅宮起數
    pos = pos - x if x % 2 else pos + x  # 借數為奇數退、偶數進
    return pos % 12


class ZiWei:
    def __init__(self, y, m, d, hour, male=True):
        ly, lm, ld, leap = solar_to_lunar(y, m, d)
        if hour >= 23:  # 晚子時算次日
            import astro
            yy, mm, dd, _ = astro.date_from_jd(astro.day_number(y, m, d) + 1 - 0.5)
            ly, lm, ld, leap = solar_to_lunar(yy, mm, dd)
        if leap and ld > 15:
            lm = lm % 12 + 1
        self.lunar = (ly, lm, ld, leap)
        self.male = male
        self.hour_branch = ((hour + 1) // 2) % 12
        ygz = lunar_year_ganzhi(ly)
        self.year_stem, self.year_branch = ygz % 10, ygz % 12
        h = self.hour_branch

        # 命宮、身宮
        self.ming = (2 + (lm - 1) - h) % 12
        self.shen = (2 + (lm - 1) + h) % 12
        # 十二宮（由命宮逆排）
        self.palace_at = {}
        for i, name in enumerate(PALACES):
            self.palace_at[(self.ming - i) % 12] = name
        # 宮干：五虎遁，寅宮起
        yin_stem = (self.year_stem % 5) * 2 + 2
        self.stem_at = {b: (yin_stem + (b - 2) % 12) % 10 for b in range(12)}
        # 五行局
        self.ju = nayin_ju(gz60(self.stem_at[self.ming], self.ming))

        stars = {b: [] for b in range(12)}
        z = ziwei_position(self.ju, ld)
        for name, off in (("紫微", 0), ("天機", -1), ("太陽", -3), ("武曲", -4), ("天同", -5), ("廉貞", -8)):
            stars[(z + off) % 12].append(name)
        f = (4 - z) % 12
        for name, off in (("天府", 0), ("太陰", 1), ("貪狼", 2), ("巨門", 3), ("天相", 4),
                          ("天梁", 5), ("七殺", 6), ("破軍", 10)):
            stars[(f + off) % 12].append(name)
        self.main = {b: list(v) for b, v in stars.items()}
        # 輔星
        aux = {b: [] for b in range(12)}
        aux[(10 - h) % 12].append("文昌")
        aux[(4 + h) % 12].append("文曲")
        aux[(4 + lm - 1) % 12].append("左輔")
        aux[(10 - (lm - 1)) % 12].append("右弼")
        lc = LUCUN[self.year_stem]
        aux[lc].append("祿存")
        aux[(lc + 1) % 12].append("擎羊")
        aux[(lc - 1) % 12].append("陀羅")
        aux[(11 - h) % 12].append("地空")
        aux[(11 + h) % 12].append("地劫")
        self.aux = aux
        # 四化
        self.sihua = {}
        for star, tag in zip(SIHUA[STEMS[self.year_stem]], SIHUA_NAMES):
            self.sihua[star] = tag

    def star_branch(self, star):
        for b in range(12):
            if star in self.main[b] or star in self.aux[b]:
                return b
        return None

    def palace_of(self, name):
        for b, n in self.palace_at.items():
            if n == name:
                return b
        raise KeyError(name)

    def stars_text(self, b, with_aux=False):
        out = []
        for s in self.main[b] + (self.aux[b] if with_aux else []):
            out.append(s + self.sihua.get(s, ""))
        return out

    def major_text(self, b):
        """宮內主星；空宮時借對宮主星。"""
        s = self.stars_text(b)
        if s:
            return "、".join(s), False
        return "、".join(self.stars_text((b + 6) % 12)), True

    def decades(self):
        """大限：由命宮起，陽男陰女順行、陰男陽女逆行，每宮十年，起於局數歲。"""
        yang = self.year_stem % 2 == 0
        step = 1 if yang == self.male else -1
        return [((self.ming + step * i) % 12, self.ju + 10 * i, self.ju + 10 * i + 9) for i in range(12)]

    def decade_at(self, age):
        for b, a0, a1 in self.decades():
            if a0 <= age <= a1:
                return b, a0, a1
        return None


if __name__ == "__main__":
    # 紫微星安星表抽查
    assert ziwei_position(2, 1) == 1 and ziwei_position(2, 2) == 2    # 水二局 初一丑、初二寅
    assert ziwei_position(3, 1) == 4 and ziwei_position(3, 2) == 1    # 木三局 初一辰、初二丑
    assert ziwei_position(4, 1) == 11 and ziwei_position(5, 1) == 6   # 金四局 初一亥、土五局 初一午
    assert ziwei_position(6, 1) == 9                                   # 火六局 初一酉
    assert ziwei_position(2, 30) == 4 and ziwei_position(2, 29) == 3    # 水二局 三十辰、廿九卯
    # 納音：甲子海中金、丙寅爐中火、戊辰大林木、庚午路旁土、丙子澗下水
    assert nayin_ju(0) == 4 and nayin_ju(2) == 6 and nayin_ju(4) == 3 and nayin_ju(6) == 5 and nayin_ju(12) == 2
    # 紫微在寅 → 天府也在寅；紫微在子 → 天府在辰
    for z, f in ((2, 2), (0, 4), (6, 10)):
        assert (4 - z) % 12 == f
    zw = ZiWei(1990, 5, 20, 8, male=True)
    print("農曆", zw.lunar, "命宮", BRANCHES[zw.ming], "身宮", BRANCHES[zw.shen], JU_NAMES[zw.ju])
    for b in range(12):
        print(f"{STEMS[zw.stem_at[b]]}{BRANCHES[b]} {zw.palace_at[b]:<3} {'、'.join(zw.stars_text(b, True))}")
    print(zw.decades()[:3])
    print("紫微驗證通過 ✓")
