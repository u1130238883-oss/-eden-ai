# -*- coding: utf-8 -*-
"""推算引擎。

這個檔案只在伺服器上執行，內容不會送到瀏覽器 —— 瀏覽器只拿得到算完的結果。
規則與 iOS／Android 兩個 App 完全相同，並由 tools/verify_algorithm.py
對照原文逐項驗過。
"""

# ── 化約 ────────────────────────────────────────────────────────────


def r12(n):
    return ((n - 1) % 12) + 1


def r9(n):
    return ((n - 1) % 9) + 1


def digit_root9(n):
    n = abs(n)
    while n > 9:
        n = sum(int(c) for c in str(n))
    return 9 if n == 0 else n


def digit_sum(n):
    return sum(int(c) for c in str(abs(n)))


# ── 五行 ────────────────────────────────────────────────────────────

ELEM = {1: "火", 2: "金", 3: "水", 4: "水", 5: "火", 6: "水",
        7: "金", 8: "火", 9: "木", 10: "土", 11: "土", 12: "木"}
GEN = {"木": "火", "火": "土", "土": "金", "金": "水", "水": "木"}
OVR = {"木": "土", "土": "水", "水": "火", "火": "金", "金": "木"}

ELEM_NAME = {
    "木": {"zh": "木", "en": "Wood", "es": "Madera", "it": "Legno"},
    "火": {"zh": "火", "en": "Fire", "es": "Fuego", "it": "Fuoco"},
    "土": {"zh": "土", "en": "Earth", "es": "Tierra", "it": "Terra"},
    "金": {"zh": "金", "en": "Metal", "es": "Metal", "it": "Metallo"},
    "水": {"zh": "水", "en": "Water", "es": "Agua", "it": "Acqua"},
}

VERDICT_NAME = {
    "好": {"zh": "好", "en": "Favourable", "es": "Favorable", "it": "Favorevole"},
    "正": {"zh": "正", "en": "Steady", "es": "Estable", "it": "Stabile"},
    "壞": {"zh": "壞", "en": "Adverse", "es": "Adverso", "it": "Avverso"},
}

CAUSE_WORD = {"zh": "因", "en": "from", "es": "de", "it": "da"}


def read(triple):
    """回傳 (種類, 果數, 因數)。"""
    y, m, d = triple
    ey, em = ELEM[y], ELEM[m]
    if ey == em:
        return ("正", d, r12(r12(y + d) + r12(m + d)))
    if GEN[ey] == em:
        return ("好", r12(m + d), r12(y + d))
    if GEN[em] == ey:
        return ("好", r12(y + d), r12(m + d))
    if OVR[ey] == em:
        return ("壞", r12(m + d), r12(y + d))
    return ("壞", r12(y + d), r12(m + d))


# ── 盤 ──────────────────────────────────────────────────────────────


def natal_triple(year, month, day):
    return (digit_root9(year), digit_root9(month), digit_root9(day))


def life_number(triple):
    return digit_root9(sum(triple))


def advanced(triple, n):
    return tuple(r12(v + n) for v in triple)


def add_triples(a, b):
    return tuple(r12(x + y) for x, y in zip(a, b))


def day_fortune_for(life_num, month, day):
    """白天（十二進制）與晚上（九進制）的日運。"""
    a = r12(life_num + month)
    b = r12(life_num + a)
    s = digit_sum(month) + digit_sum(day)
    return {"day": r12(b + s), "night": r9(life_num + s)}


def chart(start_palace, first_triple):
    """由 start_palace 起逆序十二宮，三柱每列加一。"""
    rows = []
    for k in range(12):
        palace = ((start_palace - 1 - k) % 12) + 1
        t = advanced(first_triple, k)
        rows.append({"index": k, "palace": palace, "triple": list(t),
                     "reading": read(t)})
    return rows


def natal_chart(triple):
    """本命盤：首列為命宮，三柱由本命三柱加一起算，末列回到本命三柱。"""
    return chart(life_number(triple), advanced(triple, 1))


# ── 流年 · 大運 · 月運 · 日運 · 合盤 ────────────────────────────────


class Destiny:
    """一個人的整張盤。anchor 為 'birth' 或 'fixed2017'。"""

    def __init__(self, year, month, day, anchor="birth"):
        self.birth = (year, month, day)
        self.anchor = anchor
        self.triple = natal_triple(year, month, day)
        self.life_number = life_number(self.triple)
        self.natal_chart = natal_chart(self.triple)

    # 流年
    def row_index(self, year):
        if self.anchor == "fixed2017":
            offset = year - 2017
        else:
            offset = year - self.birth[0] + 1
        return offset % 12

    def year_row(self, year):
        return self.natal_chart[self.row_index(year)]

    def years(self, start, count):
        return [{"year": start + i, "row": self.year_row(start + i)}
                for i in range(count)]

    # 大運
    @property
    def luck_start_position(self):
        return r9(self.life_number + 1)

    def luck_periods(self, count=10):
        first_end = self.birth[0] + (9 - self.luck_start_position)
        out = [{"start": self.birth[0], "end": first_end,
                "row": self.year_row(self.birth[0])}]
        start = first_end + 1
        while len(out) < count:
            out.append({"start": start, "end": start + 8,
                        "row": self.year_row(start)})
            start += 9
        return out

    def luck_period_containing(self, year):
        if year < self.birth[0]:
            end = self.birth[0] - 1
            start = end - 8
            while year < start:
                end = start - 1
                start = end - 8
            return {"start": start, "end": end, "row": self.year_row(start)}
        first_end = self.birth[0] + (9 - self.luck_start_position)
        if year <= first_end:
            return {"start": self.birth[0], "end": first_end,
                    "row": self.year_row(self.birth[0])}
        n = (year - first_end - 1) // 9
        start = first_end + 1 + n * 9
        return {"start": start, "end": start + 8, "row": self.year_row(start)}

    # 大運的十二個方面
    def luck_aspects(self, year):
        """某個大運裡的十二個方面。

        以該大運「最後一年」的年運為第一宮，往下接滿十二宮；
        第 N 宮即以第 N 宮的含義去讀。
        """
        p = self.luck_period_containing(year)
        start = self.row_index(p["end"])
        rows = []
        for i in range(12):
            row = dict(self.natal_chart[(start + i) % 12])
            row["aspect"] = i + 1
            rows.append(row)
        return {"start": p["start"], "end": p["end"],
                "row": p["row"], "aspects": rows}

    # 引動
    def triggered_aspects(self, year):
        """某一年的流年所引動的大運方面（因或果落在流年所走那一宮的各項）。"""
        palace = self.year_row(year)["palace"]
        return [r for r in self.luck_aspects(year)["aspects"]
                if palace in (r["reading"][1], r["reading"][2])]

    def triggered_natal_rows(self, period):
        """某一段大運所引動的本命盤宮位（因或果落在大運所走那一宮的各列）。"""
        return self.triggered_natal_by_palace(period["row"]["palace"])

    def triggered_natal_by_palace(self, palace):
        """本命盤某一宮所引動的本命盤宮位（因或果落在那一宮的各列）。"""
        return [r for r in self.natal_chart
                if palace in (r["reading"][1], r["reading"][2])]

    # 月運
    def month_chart(self, year):
        luck = self.luck_period_containing(year)["row"]
        flow = self.year_row(year)
        base = add_triples(tuple(luck["triple"]), tuple(flow["triple"]))
        first_palace = r12(flow["palace"] - 1)
        rows = chart(first_palace, base)
        return [{"month": i + 1, "row": row} for i, row in enumerate(rows)]

    # 日運
    def day_fortune(self, month, day):
        return day_fortune_for(self.life_number, month, day)

    # 合盤
    def synastry(self, other):
        comp = add_triples(self.triple, other.triple)
        return {"triple": list(comp),
                "life_number": life_number(comp),
                "chart": natal_chart(comp)}
