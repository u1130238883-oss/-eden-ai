# -*- coding: utf-8 -*-
"""
易經起卦：三錢法（六爻）與梅花易數（數字起卦、時間起卦）。
回傳本卦、變卦、互卦與動爻。Swift 端 IChing.swift 為逐行對應的移植。

卦的表示：六個爻由下（初爻）到上（上爻），1=陽、0=陰。
"""
import random

# 八卦：先天數 1..8 → (名稱, 象, 三爻由下而上)
TRIGRAMS = {
    1: ("乾", "天", (1, 1, 1)), 2: ("兌", "澤", (1, 1, 0)), 3: ("離", "火", (1, 0, 1)), 4: ("震", "雷", (1, 0, 0)),
    5: ("巽", "風", (0, 1, 1)), 6: ("坎", "水", (0, 1, 0)), 7: ("艮", "山", (0, 0, 1)), 8: ("坤", "地", (0, 0, 0)),
}
_BY_LINES = {v[2]: k for k, v in TRIGRAMS.items()}

# 文王六十四卦序：(卦名, 上卦, 下卦)
KING_WEN = [
    ("乾", "乾", "乾"), ("坤", "坤", "坤"), ("屯", "坎", "震"), ("蒙", "艮", "坎"), ("需", "坎", "乾"), ("訟", "乾", "坎"),
    ("師", "坤", "坎"), ("比", "坎", "坤"), ("小畜", "巽", "乾"), ("履", "乾", "兌"), ("泰", "坤", "乾"), ("否", "乾", "坤"),
    ("同人", "乾", "離"), ("大有", "離", "乾"), ("謙", "坤", "艮"), ("豫", "震", "坤"), ("隨", "兌", "震"), ("蠱", "艮", "巽"),
    ("臨", "坤", "兌"), ("觀", "巽", "坤"), ("噬嗑", "離", "震"), ("賁", "艮", "離"), ("剝", "艮", "坤"), ("復", "坤", "震"),
    ("無妄", "乾", "震"), ("大畜", "艮", "乾"), ("頤", "艮", "震"), ("大過", "兌", "巽"), ("坎", "坎", "坎"), ("離", "離", "離"),
    ("咸", "兌", "艮"), ("恆", "震", "巽"), ("遯", "乾", "艮"), ("大壯", "震", "乾"), ("晉", "離", "坤"), ("明夷", "坤", "離"),
    ("家人", "巽", "離"), ("睽", "離", "兌"), ("蹇", "坎", "艮"), ("解", "震", "坎"), ("損", "艮", "兌"), ("益", "巽", "震"),
    ("夬", "兌", "乾"), ("姤", "乾", "巽"), ("萃", "兌", "坤"), ("升", "坤", "巽"), ("困", "兌", "坎"), ("井", "坎", "巽"),
    ("革", "兌", "離"), ("鼎", "離", "巽"), ("震", "震", "震"), ("艮", "艮", "艮"), ("漸", "巽", "艮"), ("歸妹", "震", "兌"),
    ("豐", "震", "離"), ("旅", "離", "艮"), ("巽", "巽", "巽"), ("兌", "兌", "兌"), ("渙", "巽", "坎"), ("節", "坎", "兌"),
    ("中孚", "巽", "兌"), ("小過", "震", "艮"), ("既濟", "坎", "離"), ("未濟", "離", "坎"),
]
_NAME_TO_NUM = {v[0]: k for k, v in TRIGRAMS.items()}
_HEX_BY_TRI = {(_NAME_TO_NUM[u], _NAME_TO_NUM[l]): i + 1 for i, (_, u, l) in enumerate(KING_WEN)}
assert len(_HEX_BY_TRI) == 64
LINE_NAMES = ["初", "二", "三", "四", "五", "上"]


def hex_number(lines):
    lower = _BY_LINES[tuple(lines[:3])]
    upper = _BY_LINES[tuple(lines[3:])]
    return _HEX_BY_TRI[(upper, lower)]


def hex_lines(num):
    _, u, l = KING_WEN[num - 1]
    return list(TRIGRAMS[_NAME_TO_NUM[l]][2]) + list(TRIGRAMS[_NAME_TO_NUM[u]][2])


def full_name(num):
    """例：11 → 地天泰；1 → 乾為天。"""
    name, u, l = KING_WEN[num - 1]
    ui, li = _NAME_TO_NUM[u], _NAME_TO_NUM[l]
    if u == l:
        return f"{name}為{TRIGRAMS[ui][1]}"
    return f"{TRIGRAMS[ui][1]}{TRIGRAMS[li][1]}{name}"


class Reading:
    def __init__(self, lines, moving):
        self.lines = list(lines)
        self.moving = sorted(set(moving))           # 動爻位置 0..5
        self.primary = hex_number(self.lines)
        changed = [1 - v if i in self.moving else v for i, v in enumerate(self.lines)]
        self.changed = hex_number(changed) if self.moving else None
        self.mutual = hex_number(self.lines[1:4] + self.lines[2:5])

    @property
    def frame(self):
        s = f"卦|{self.primary}{KING_WEN[self.primary - 1][0]}"
        if self.changed:
            s += f"|變{self.changed}{KING_WEN[self.changed - 1][0]}"
        s += "|動" + (",".join(str(i + 1) for i in self.moving) if self.moving else "無")
        return s


def three_coins(rng):
    """三錢法：每爻擲三枚錢，正面 3、反面 2：6 老陰（動）7 少陽 8 少陰 9 老陽（動）。"""
    lines, moving = [], []
    for i in range(6):
        v = sum(rng.choice((2, 3)) for _ in range(3))
        lines.append(1 if v in (7, 9) else 0)
        if v in (6, 9):
            moving.append(i)
    return Reading(lines, moving)


def plum_numbers(a, b):
    """梅花易數・數字起卦：上卦 a%8、下卦 b%8、動爻 (a+b)%6（餘 0 取最大）。"""
    up = a % 8 or 8
    lo = b % 8 or 8
    mv = (a + b) % 6 or 6
    lines = list(TRIGRAMS[lo][2]) + list(TRIGRAMS[up][2])
    return Reading(lines, [mv - 1])


def plum_time(year_branch, lunar_month, lunar_day, hour_branch):
    """梅花易數・時間起卦：年支數（子=1）+ 月 + 日 為上卦；再加時支數為下卦與動爻。"""
    s = year_branch + 1 + lunar_month + lunar_day
    return plum_numbers(s, s + hour_branch + 1)


if __name__ == "__main__":
    assert full_name(1) == "乾為天" and full_name(11) == "地天泰" and full_name(64) == "火水未濟"
    assert hex_number([1, 1, 1, 0, 0, 0]) == 11      # 下乾上坤 = 泰
    assert hex_number([0, 0, 0, 1, 1, 1]) == 12      # 下坤上乾 = 否
    assert hex_number([1, 0, 1, 0, 1, 0]) == 63      # 下離上坎 = 既濟
    for n in range(1, 65):
        assert hex_number(hex_lines(n)) == n
    r = Reading([1, 1, 1, 0, 0, 0], [2])            # 泰卦三爻動 → 臨
    assert r.changed == 19 and r.mutual == 54, (r.changed, r.mutual)   # 互卦 雷澤歸妹
    r = plum_numbers(3, 5)                         # 上離 下巽 → 火風鼎，動爻 2
    assert r.primary == 50 and r.moving == [1]
    print(r.frame, full_name(r.primary), "→", full_name(r.changed))
    print("易經驗證通過 ✓")
