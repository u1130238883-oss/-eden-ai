"""
產生 NineSun App 圖示（原創設計，絕區零式街頭貼紙風）：
  - 九道光芒的太陽 = 九型
  - 外圈十二段警示環 = 十二宮（其中一段以橘色標示命宮）
  - 中央故障錯位的「9」、網點、斜向色帶、膠帶標籤
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

S = 1024
LIME, INK, CYAN, ORANGE, PINK, PAPER = (212, 255, 31), (12, 12, 14), (51, 225, 255), (255, 107, 20), (255, 61, 127), (242, 240, 230)
FONT = "/usr/share/fonts/truetype/liberation/LiberationSans-BoldItalic.ttf"
CX, CY = 512, 470

img = Image.new("RGB", (S, S), INK)
d = ImageDraw.Draw(img)

# 網點（越往右下越大）
for y in range(0, S, 26):
    for x in range(0 if (y // 26) % 2 == 0 else 13, S, 26):
        r = 1.5 + 6.5 * ((x + y) / (2 * S))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(32, 32, 38))

# 斜向螢光色帶 + 橘色角
band = Image.new("RGBA", (S, S), (0, 0, 0, 0))
b = ImageDraw.Draw(band)
b.polygon([(-100, 880), (1124, 180), (1124, 330), (-100, 1030)], fill=LIME + (40,))
b.polygon([(S * 0.62, 0), (S, 0), (S, S * 0.3)], fill=ORANGE + (255,))
img.paste(band, (0, 0), band)
d = ImageDraw.Draw(img)


def polar(r, a):
    return CX + r * math.cos(a), CY + r * math.sin(a)


def ring_segment(draw, r0, r1, a0, a1, fill, steps=24):
    pts = [polar(r1, a0 + (a1 - a0) * i / steps) for i in range(steps + 1)]
    pts += [polar(r0, a1 - (a1 - a0) * i / steps) for i in range(steps + 1)]
    draw.polygon(pts, fill=fill)


def sticker(draw_fn, shadow=ORANGE, off=(14, 14)):
    """先畫偏移色影，再回傳本體遮罩。"""
    layer = Image.new("L", (S, S), 0)
    draw_fn(ImageDraw.Draw(layer))
    sh = Image.new("RGB", (S, S), shadow)
    img.paste(sh, off, layer)
    return layer


# 十二宮外環
R0, R1 = 318, 392
gap = math.radians(2.6)
top = -math.pi / 2 - math.pi / 12


def draw_ring(dr, fill=255):
    for i in range(12):
        a0 = top + i * 2 * math.pi / 12 + gap
        a1 = top + (i + 1) * 2 * math.pi / 12 - gap
        ring_segment(dr, R0, R1, a0, a1, fill)


mask = sticker(draw_ring)
img.paste(Image.new("RGB", (S, S), LIME), (0, 0), mask)
d = ImageDraw.Draw(img)
# 命宮：頂端一段改為橘色；每段加刻線
ring_segment(d, R0, R1, top + gap, top + 2 * math.pi / 12 - gap, ORANGE)
for i in range(12):
    a = top + (i + 0.5) * 2 * math.pi / 12
    x0, y0 = polar(R0 + 12, a)
    x1, y1 = polar(R1 - 12, a)
    d.line([(x0, y0), (x1, y1)], fill=INK, width=10)

# 九道光芒
RAY_IN, RAY_OUT, HALF = 168, 300, math.radians(11)


def draw_rays(dr, fill=255):
    for i in range(9):
        a = -math.pi / 2 + i * 2 * math.pi / 9
        dr.polygon([polar(RAY_IN, a - HALF), polar(RAY_OUT, a), polar(RAY_IN, a + HALF)], fill=fill)


mask = sticker(draw_rays)
img.paste(Image.new("RGB", (S, S), LIME), (0, 0), mask)
d = ImageDraw.Draw(img)

# 核心圓盤
d.ellipse([CX - 176 + 12, CY - 176 + 12, CX + 176 + 12, CY + 176 + 12], fill=ORANGE)
d.ellipse([CX - 176, CY - 176, CX + 176, CY + 176], fill=INK, outline=LIME, width=18)
for y in range(CY - 150, CY + 150, 10):  # 掃描線
    w = math.sqrt(max(0, 150 ** 2 - (y - CY) ** 2))
    d.line([(CX - w, y), (CX + w, y)], fill=(24, 36, 40), width=2)

# 故障錯位的「9」
font = ImageFont.truetype(FONT, 300)


def glyph(color, dx, dy):
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(lay).text((CX + dx, CY + dy + 8), "9", font=font, fill=color + (255,), anchor="mm")
    return lay


for color, dx in ((PINK, -12), (CYAN, 12)):
    g = glyph(color, dx, 0)
    img.paste(g, (0, 0), g)
main = glyph(LIME, 0, 0)
glow = main.filter(ImageFilter.GaussianBlur(14))
img.paste(glow, (0, 0), glow)
img.paste(main, (0, 0), main)
# 橫向切片錯位
for (y0, h, dx) in ((CY - 40, 18, 16), (CY + 60, 12, -14)):
    box = (CX - 150, y0, CX + 150, y0 + h)
    sl = img.crop(box)
    img.paste(sl, (box[0] + dx, box[1]))

# 底部警示條
d = ImageDraw.Draw(img)
bh = 96
d.rectangle([0, S - bh, S, S], fill=LIME)
for x in range(-bh, S + bh, 76):
    d.polygon([(x, S), (x + bh, S - bh), (x + bh + 38, S - bh), (x + 38, S)], fill=INK)

# 膠帶標籤
tape = Image.new("RGBA", (520, 110), PAPER + (255,))
t = ImageDraw.Draw(tape)
t.rectangle([0, 0, 519, 109], outline=INK, width=8)
t.text((260, 57), "NINESUN", font=ImageFont.truetype(FONT, 78), fill=INK, anchor="mm")
for x in (0, 519):  # 鋸齒撕邊
    for y in range(0, 110, 14):
        t.polygon([(x, y), (x + (10 if x == 0 else -10), y + 7), (x, y + 14)], fill=(0, 0, 0, 0))
tape = tape.rotate(-7, expand=True, resample=Image.BICUBIC)
shadow = Image.new("RGBA", tape.size, INK + (160,))
shadow.putalpha(ImageChops.multiply(tape.getchannel("A"), Image.new("L", tape.size, 160)))
img.paste(shadow, (262, 792), shadow)
img.paste(tape, (250, 780), tape)

out = os.path.join(os.path.dirname(__file__), "..", "NineSun", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")
img.save(out)
print("saved", os.path.normpath(out))
