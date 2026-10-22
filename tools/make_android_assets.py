#!/usr/bin/env python3
"""產生 Android 需要的圖檔。

1. 各 density 的啟動圖示（沿用 iOS 版 make_icon.py 的圖案）。
2. 直連版付款畫面的兩張佔位圖 —— 上架前要換成你自己的收款碼。
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_icon  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
DIRECT_RES = os.path.join(ROOT, "android", "app", "src", "direct", "res")

# mipmap 各 density 的邊長（傳統啟動圖示規格）
DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

PLACEHOLDER_BG = (245, 245, 247)
PLACEHOLDER_INK = (120, 120, 130)
PLACEHOLDER_ACCENT = (158, 115, 41)


def launcher_icons():
    master = os.path.join(ROOT, "build", "android-icon-1024.png")
    make_icon.main(master)
    img = Image.open(master).convert("RGB")
    for name, size in DENSITIES.items():
        out_dir = os.path.join(RES, "mipmap-" + name)
        os.makedirs(out_dir, exist_ok=True)
        path = os.path.join(out_dir, "ic_launcher.png")
        img.resize((size, size), Image.LANCZOS).save(path, "PNG")
        print("wrote", path)


def placeholder(path, title, subtitle):
    """畫一張明顯是佔位圖的方塊，免得誤以為是真的收款碼。"""
    size = 512
    img = Image.new("RGB", (size, size), PLACEHOLDER_BG)
    d = ImageDraw.Draw(img)

    d.rounded_rectangle([16, 16, size - 16, size - 16], radius=28,
                        outline=PLACEHOLDER_ACCENT, width=6)

    # 三個定位角，看起來像 QR code 但顯然不是
    for cx, cy in ((110, 110), (size - 110, 110), (110, size - 110)):
        d.rounded_rectangle([cx - 54, cy - 54, cx + 54, cy + 54], radius=10,
                            outline=PLACEHOLDER_INK, width=12)
        d.rounded_rectangle([cx - 22, cy - 22, cx + 22, cy + 22], radius=4,
                            fill=PLACEHOLDER_INK)

    d.line([150, size - 150, size - 60, 150], fill=PLACEHOLDER_ACCENT, width=8)

    for text, y, fill in ((title, size // 2 - 14, PLACEHOLDER_ACCENT),
                          (subtitle, size // 2 + 14, PLACEHOLDER_INK)):
        w = d.textlength(text)
        d.text(((size - w) / 2, y), text, fill=fill)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print("wrote", path)


def payment_placeholders():
    out = os.path.join(DIRECT_RES, "drawable-nodpi")
    placeholder(os.path.join(out, "pay_wechat.png"),
                "REPLACE WITH YOUR", "WeChat Pay QR")
    placeholder(os.path.join(out, "pay_alipay.png"),
                "REPLACE WITH YOUR", "Alipay QR")


if __name__ == "__main__":
    launcher_icons()
    payment_placeholders()
