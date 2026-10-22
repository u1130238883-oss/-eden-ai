#!/usr/bin/env python3
"""產生 App 圖示：外圈十二宮、內圈九宮。"""
import math
import os
import sys
from PIL import Image, ImageDraw

SIZE = 1024
SS = 4  # 超取樣倍率
S = SIZE * SS

BG_TOP = (26, 26, 38)
BG_BOTTOM = (12, 12, 18)
GOLD = (198, 154, 66)
GOLD_SOFT = (150, 116, 52)
INK = (232, 226, 212)


def lerp(a, b, t):
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))


def main(out_path):
    img = Image.new("RGB", (S, S), BG_BOTTOM)
    d = ImageDraw.Draw(img)

    # 垂直漸層背景
    for y in range(S):
        d.line([(0, y), (S, y)], fill=lerp(BG_TOP, BG_BOTTOM, y / S))

    cx = cy = S / 2

    # 外圈：十二宮
    r_outer = S * 0.355
    d.ellipse([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer],
              outline=GOLD_SOFT, width=int(S * 0.006))

    for i in range(12):
        ang = math.radians(-90 + i * 30)
        x = cx + r_outer * math.cos(ang)
        y = cy + r_outer * math.sin(ang)
        r = S * 0.030 if i == 0 else S * 0.019
        col = GOLD if i == 0 else GOLD_SOFT
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)

    # 內圈：九宮
    r_inner = S * 0.205
    d.ellipse([cx - r_inner, cy - r_inner, cx + r_inner, cy + r_inner],
              outline=GOLD_SOFT, width=int(S * 0.004))

    for i in range(9):
        ang = math.radians(-90 + i * 40)
        x = cx + r_inner * math.cos(ang)
        y = cy + r_inner * math.sin(ang)
        r = S * 0.021 if i == 0 else S * 0.013
        col = GOLD if i == 0 else INK
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)

    # 中心：三柱三橫
    bar_w = S * 0.115
    bar_h = S * 0.020
    for k, gap in enumerate((-1, 0, 1)):
        w = bar_w * (1.0 - abs(gap) * 0.22)
        y = cy + gap * S * 0.055
        d.rounded_rectangle(
            [cx - w, y - bar_h / 2, cx + w, y + bar_h / 2],
            radius=bar_h / 2,
            fill=GOLD if gap == 0 else INK,
        )

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, "PNG")
    print("wrote", out_path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")
