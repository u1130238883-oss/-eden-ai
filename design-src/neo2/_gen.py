# Generates 50 "霓虹街區" wallpapers (390x844 CSS px -> 1170x2532 @3x).
# 10 families x 5 variants. Keep y 90-260 calm for the lock-screen clock.
import os, random, math, json
D = os.path.dirname(os.path.abspath(__file__))
FONTS = ("family=Anton&family=Bangers&family=Bebas+Neue&family=Black+Ops+One&family=Bungee&family=Bungee+Shade"
         "&family=Monoton&family=Permanent+Marker&family=Press+Start+2P&family=Rubik+Mono+One&family=Space+Mono:wght@700"
         "&family=Noto+Sans+TC:wght@900&family=Orbitron:wght@900&family=Righteous")
GRAIN = ("background-image:url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='180' height='180'>"
         "<filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='2' stitchTiles='stitch'/>"
         "<feColorMatrix values='0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 .5 0'/></filter>"
         "<rect width='100%' height='100%' filter='url(%23n)'/></svg>\")")

def page(body, grain=0.22):
    body = recolor(body)
    return f"""<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?{FONTS}&display=swap">
<style>body{{margin:0}}*{{box-sizing:border-box}}.a{{position:absolute}}.c{{display:flex;align-items:center;justify-content:center}}
.m{{font-family:'Space Mono',monospace}}.grain{{position:absolute;inset:0;{GRAIN};opacity:{grain};mix-blend-mode:multiply;pointer-events:none}}</style>
</head><body><div style="width:390px;height:844px;position:relative;overflow:hidden">{body}<div class="grain"></div></div></body></html>"""

def mono(x, y, t, col, size=11, extra=""):
    return f'<div class="a m" style="left:{x}px;top:{y}px;color:{col};font-size:{size}px;letter-spacing:2px;{extra}">{t}</div>'

def glow(c, r=(6, 18, 36)):
    return ",".join(f"0 0 {v}px {c}" for v in r)

OUT = {}   # name -> (html, meta)

# ---- lime / yellow-green palette (matches the 黃綠系列) ----
# Yellow-leaning lime on black (like SIGNAL / RADAR) - no dark greens.
LIME, ACID, LITE, MOSS, OLIVE, DEEP = "#D4FF1A", "#EAFF3A", "#F7FFB3", "#C2EE14", "#2A2A26", "#1A1A18"
INK, INK2, INK3, PAPER = "#0B0B0A", "#121211", "#1E1E1B", "#F2F2E8"

import colorsys, re as _re
def _lime(hexs):
    """Map any stray saturated non-green colour onto the lime ramp by lightness."""
    h = hexs.lstrip('#'); a = ''
    if len(h) == 3: h = ''.join(c * 2 for c in h)
    if len(h) == 8: h, a = h[:6], h[6:]
    if len(h) != 6: return hexs
    r, g, b = (int(h[k:k + 2], 16) / 255 for k in (0, 2, 4))
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    if ss < 0.35 or ll < 0.12 or ll > 0.93 or 0.17 <= hh <= 0.215:
        return hexs
    ramp = OLIVE if ll < 0.32 else MOSS if ll < 0.45 else LIME if ll < 0.62 else ACID
    return ramp + a
def recolor(html):
    return _re.sub(r'#[0-9A-Fa-f]{8}\b|#[0-9A-Fa-f]{6}\b|#[0-9A-Fa-f]{3}\b', lambda m: _lime(m.group()), html)
def dark(c):
    h = c.lstrip('#')[:6]
    return sum(int(h[k:k+2], 16) for k in (0, 2, 4)) < 3 * 110

# ---------- 1. NEON SIGNS ----------
NEON = [
    ("KARAOKE", "卡拉OK", LIME, LITE, "#0B0B0A", "ROOM 09 · ¥500/H"),
    ("LIVE HOUSE", "現場", ACID, LIME, "#0B0B0A", "TONIGHT · DOORS 21:00"),
    ("NO VACANCY", "客滿", "#DDFF2A", ACID, "#0B0B0A", "HOTEL ZONE 09"),
    ("ARCADE", "電玩", LITE, LIME, "#0B0B0A", "COIN-OP · 24H"),
    ("BAR 09", "酒吧", MOSS, ACID, "#0B0B0A", "HAPPY HOUR 18-20"),
]
for i, (en, zh, c1, c2, bg, sub) in enumerate(NEON):
    rnd = random.Random(100 + i)
    bricks = f'<div class="a" style="inset:0;background-image:linear-gradient(#ffffff07 2px,transparent 2px),linear-gradient(90deg,#ffffff06 2px,transparent 2px);background-size:{rnd.choice([52,60,68])}px 26px"></div>'
    arrow = f'<svg class="a" style="left:40px;top:640px" width="310" height="80" viewBox="0 0 310 80"><path d="M10 40H270M240 12L290 40L240 68" fill="none" stroke="{c2}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" style="filter:drop-shadow(0 0 6px {c2}) drop-shadow(0 0 16px {c2})"/></svg>'
    body = f"""<div class="a" style="inset:0;background:radial-gradient(110% 60% at 50% 48%,{bg}ee,#000 85%)"></div>{bricks}
<div class="a" style="left:34px;top:300px;width:322px;height:250px;border:5px solid {c1};border-radius:26px;box-shadow:{glow(c1,(8,26))},inset 0 0 20px {c1}66"></div>
<div class="a" style="left:34px;top:328px;width:322px;text-align:center;font:900 {92 if len(zh) <= 3 else 68}px/1 'Noto Sans TC';color:#fff;text-shadow:{glow(c1)}">{zh}</div>
<div class="a" style="left:34px;top:{462 - min(44, int(300 / (0.82 * len(en)))) // 2}px;width:322px;text-align:center;font:{min(44, int(300 / (0.82 * len(en))))}px/1 'Monoton';color:#fff;text-shadow:{glow(c2)};white-space:nowrap">{en}</div>
{arrow}{mono(24, 800, sub, '#ffffff99')}"""
    OUT[f"neon{i}"] = (page(body, 0.3), (en, sub, c1))

# ---------- 2. TICKETS / PASSES ----------
TK = [
    ("CONCERT", "NEON RIOT", "STAGE B · 21:30", LIME, PAPER, INK),
    ("METRO PASS", "LINE 9", "UNLIMITED · 7 DAYS", ACID, INK2, LIME),
    ("BOARDING", "ZONE 09", "GATE C7 · SEAT 09A", LIME, LITE, INK),
    ("ARCADE TOKEN", "1 PLAY", "VALID ALL CABINETS", "#DDFF2A", "#191919", "#DDFF2A"),
    ("MEMBER", "VIP CLUB", "No.000909 · BLACK", ACID, INK3, ACID),
]
for i, (kind, big, sub, acc, paper, ink) in enumerate(TK):
    rnd = random.Random(200 + i)
    bars = "".join(f'<div style="width:{rnd.randint(1,4)}px;height:52px;background:{ink};margin-right:{rnd.randint(1,3)}px"></div>' for _ in range(36))
    bg = [INK2, LIME, DEEP, INK, OLIVE][i]
    rot = [-6, 4, -3, 7, -5][i]
    body = f"""<div class="a" style="inset:0;background:{bg}"></div>
<div class="a" style="inset:0;background:radial-gradient({acc}55 2px,transparent 2.4px) 0 0/14px 14px;opacity:.6"></div>
<div class="a" style="left:40px;top:290px;width:310px;height:420px;border-radius:18px;background:{paper};transform:rotate({rot}deg);box-shadow:12px 14px 0 #0006;overflow:hidden">
 <div class="a" style="left:0;top:0;width:100%;height:56px;background:{acc}"></div>
 <div class="a" style="left:20px;top:14px;font:26px 'Bebas Neue';letter-spacing:4px;color:{'#111' if i!=4 else '#111'}">{kind}</div>
 <div class="a m" style="right:18px;top:20px;font-size:12px;color:#111">#{rnd.randint(1000,9999)}</div>
 <div class="a" style="left:20px;top:84px;font:84px/0.95 'Anton';color:{ink};width:270px">{big}</div>
 <div class="a m" style="left:22px;top:270px;font-size:12px;color:{ink};opacity:.8">{sub}</div>
 <div class="a" style="left:-18px;top:296px;width:36px;height:36px;border-radius:50%;background:{bg}"></div>
 <div class="a" style="right:-18px;top:296px;width:36px;height:36px;border-radius:50%;background:{bg}"></div>
 <div class="a" style="left:26px;top:313px;width:258px;border-top:3px dashed {ink};opacity:.5"></div>
 <div class="a" style="left:24px;top:340px;display:flex">{bars}</div>
</div>
{mono(24, 800, 'ADMIT ONE · NON-TRANSFERABLE', '#ffffffaa' if dark(bg) else '#111')}"""
    OUT[f"ticket{i}"] = (page(body, 0.3), (big, sub, acc))

# ---------- 3. WARNING SIGNS ----------
WS = [
    ("HIGH VOLTAGE", "高壓危險", LIME, '<path d="M110 30L60 120H100L80 190L150 90H108L130 30Z" fill="#111"/>'),
    ("SLIPPERY", "小心地滑", ACID, '<circle cx="100" cy="55" r="16" fill="#111"/><path d="M95 75L80 130L120 125M88 100L130 95M80 130L60 175M100 128L140 170" stroke="#111" stroke-width="14" stroke-linecap="round" fill="none"/><path d="M40 185H170" stroke="#111" stroke-width="8"/>'),
    ("MAGNETIC FIELD", "強磁場", "#DDFF2A", '<path d="M60 60V120A40 40 0 0 0 140 120V60" stroke="#111" stroke-width="30" fill="none"/><path d="M45 45h30v24h-30zM125 45h30v24h-30z" fill="#F5F5F0" stroke="#111" stroke-width="6"/>'),
    ("FALLING OBJECTS", "注意落物", LITE, '<rect x="70" y="30" width="44" height="44" fill="#111" transform="rotate(20 92 52)"/><rect x="110" y="86" width="32" height="32" fill="#111" transform="rotate(-15 126 102)"/><path d="M60 175Q100 120 140 175Z" fill="#111"/>'),
    ("LASER ZONE", "雷射區域", MOSS, '<circle cx="60" cy="110" r="22" fill="#111"/><path d="M82 110H175" stroke="#111" stroke-width="8"/><path d="M150 85L175 110L150 135" stroke="#111" stroke-width="8" fill="none"/>'),
]
for i, (en, zh, col, icon) in enumerate(WS):
    stripe = f"repeating-linear-gradient(-45deg,{col} 0 22px,#111 22px 44px)"
    body = f"""<div class="a" style="inset:0;background:#141414"></div>
<div class="a" style="left:0;top:0;width:390px;height:40px;background:{stripe}"></div>
<div class="a" style="left:0;top:804px;width:390px;height:40px;background:{stripe}"></div>
<svg class="a" style="left:55px;top:280px" width="280" height="250" viewBox="0 0 280 250"><path d="M140 12L268 236H12Z" fill="{col}" stroke="#111" stroke-width="14" stroke-linejoin="round"/><g transform="translate(40 40) scale(1)">{icon}</g></svg>
<div class="a c" style="left:30px;top:560px;width:330px;height:84px;background:{col};font:900 50px 'Noto Sans TC';color:#111;letter-spacing:6px">{zh}</div>
<div class="a" style="left:30px;top:652px;width:330px;text-align:center;font:34px 'Bebas Neue';color:{col};letter-spacing:6px">{en}</div>
{mono(30, 712, 'AUTHORIZED PERSONNEL ONLY · ZONE 09', '#ffffff77', 10)}"""
    OUT[f"warn{i}"] = (page(body, 0.35), (en, zh, col))

# ---------- 4. RETRO TECH ----------
def floppy(c):
    return f"""<div class="a" style="left:55px;top:290px;width:280px;height:290px;background:{c};border-radius:10px;box-shadow:12px 12px 0 #0006">
<div class="a" style="left:60px;top:0;width:160px;height:96px;background:#C9CDD2"><div style="margin:14px 0 0 104px;width:30px;height:66px;background:{c}"></div></div>
<div class="a" style="left:30px;top:140px;width:220px;height:140px;background:#F5F1E6;border-radius:4px"><div style="height:16px;background:#FF3D6E"></div>
<div style="padding:14px;font:30px 'Permanent Marker';color:#1a1a1a">backup_09</div></div></div>"""
TECH = [
    ("FLOPPY", "SAVE BEFORE YOU QUIT", INK2, ACID, "floppy"),
    ("PAGER", "CALL ME 0909", "#1A1A1A", LIME, "pager"),
    ("WALKMAN", "AUTO REVERSE", LIME, "#1A1A1A", "walk"),
    ("HANDHELD", "PRESS START", LIME, ACID, "hand"),
    ("RADIO", "FM 90.9 · NIGHT", LIME, "#1A1A1A", "radio"),
]
for i, (title, sub, c1, c2, kind) in enumerate(TECH):
    bg = [ACID, "#121211", PAPER, "#121211", "#0B0B0A"][i]
    if kind == "floppy":
        obj = floppy(c1)
    elif kind == "pager":
        obj = f"""<div class="a" style="left:45px;top:330px;width:300px;height:190px;border-radius:30px;background:#2A2A2A;box-shadow:0 0 0 6px #3A3A3A,12px 14px 0 6px #0007">
<div class="a" style="left:24px;top:28px;width:252px;height:84px;border-radius:10px;background:#9FC24A;box-shadow:inset 0 0 18px #0005"><div style="padding:16px;font:24px 'Press Start 2P';color:#1F2A10">0909-520</div></div>
<div class="a" style="left:40px;top:132px;width:40px;height:26px;border-radius:13px;background:#555"></div><div class="a" style="left:96px;top:132px;width:40px;height:26px;border-radius:13px;background:#555"></div><div class="a" style="left:210px;top:128px;width:52px;height:34px;border-radius:17px;background:{c2}"></div></div>"""
    elif kind == "walk":
        obj = f"""<div class="a" style="left:60px;top:280px;width:270px;height:340px;border-radius:22px;background:{c1};box-shadow:12px 12px 0 #0004">
<div class="a" style="left:22px;top:30px;width:226px;height:150px;border-radius:12px;background:#1A1A1A"><div class="a c" style="left:40px;top:44px;width:56px;height:56px;border-radius:50%;background:#F1E6CF;border:10px dotted #1A1A1A"></div><div class="a c" style="left:130px;top:44px;width:56px;height:56px;border-radius:50%;background:#F1E6CF;border:10px dotted #1A1A1A"></div></div>
<div class="a" style="left:22px;top:204px;font:44px/1 'Bungee';color:#1A1A1A">WALK</div>
<div class="a" style="left:22px;top:270px;display:flex;gap:10px">{''.join('<div style="width:40px;height:30px;border-radius:6px;background:#1A1A1A"></div>' for _ in range(5))}</div></div>"""
    elif kind == "hand":
        obj = f"""<div class="a" style="left:22px;top:330px;width:346px;height:200px;border-radius:100px;background:linear-gradient(135deg,#1E1E1B,#0B0B0A);border:4px solid {c1};box-shadow:0 0 24px {c1}66,12px 12px 0 #0007">
<div class="a" style="left:96px;top:30px;width:154px;height:120px;border-radius:12px;background:#0B0B0A;border:3px solid #444;padding:10px"><div style="width:100%;height:100%;border-radius:6px;background:linear-gradient({c2}33,{c2}11);padding:12px;font:11px/1.9 'Press Start 2P';color:{c2}">PRESS<br>START<br>&gt; 1P</div></div>
<div class="a" style="left:28px;top:84px;width:52px;height:16px;border-radius:4px;background:#0B0B0A"></div><div class="a" style="left:46px;top:66px;width:16px;height:52px;border-radius:4px;background:#0B0B0A"></div>
<div class="a" style="left:276px;top:62px;width:26px;height:26px;border-radius:50%;background:#FF3D6E"></div><div class="a" style="left:300px;top:94px;width:26px;height:26px;border-radius:50%;background:{c2}"></div>
<div class="a" style="left:144px;top:166px;width:24px;height:8px;border-radius:4px;background:#666"></div><div class="a" style="left:178px;top:166px;width:24px;height:8px;border-radius:4px;background:#666"></div></div>"""
    else:
        obj = f"""<div class="a" style="left:40px;top:320px;width:310px;height:230px;border-radius:18px;background:#E8E2D2;box-shadow:12px 12px 0 #0007">
<div class="a" style="left:20px;top:20px;width:150px;height:190px;border-radius:12px;background:radial-gradient(#333 3px,transparent 3.5px) 0 0/10px 10px,#555"></div>
<div class="a" style="left:184px;top:20px;width:106px;height:60px;border-radius:6px;background:#111;color:{c1};font:22px/60px 'Orbitron';text-align:center;text-shadow:0 0 8px {c1}">90.9</div>
<div class="a" style="left:200px;top:104px;width:70px;height:70px;border-radius:50%;background:#333;border:6px solid #999"></div></div>"""
    body = f"""<div class="a" style="inset:0;background:{bg}"></div>
<div class="a" style="inset:0;background:repeating-linear-gradient(90deg,#0000000a 0 2px,transparent 2px 18px)"></div>
{obj}
<div class="a" style="left:28px;top:660px;font:64px/1 'Anton';color:{ {'walk': '#1A1A1A', 'radio': c1, 'floppy': '#1A1A1A'}.get(kind, c2) };letter-spacing:1px">{title}</div>
{mono(30, 734, sub, '#ffffffaa' if i in (1,3,4) else '#1a1a1aaa', 12)}"""
    OUT[f"tech{i}"] = (page(body, 0.28), (title, sub, c1))

# ---------- 5. COMIC SFX ----------
SFX = [("BAM!", ACID, INK), ("POW!", LIME, DEEP), ("ZAP!", LITE, "#2A2A26"),
       ("WHAM!", ACID, OLIVE), ("BOOM!", LIME, INK3)]
for i, (w, fill, bg) in enumerate(SFX):
    rnd = random.Random(500 + i)
    pts = []
    for k in range(28):
        a = k / 28 * 2 * math.pi
        r = 175 if k % 2 == 0 else rnd.randint(100, 130)
        pts.append(f"{195 + r * math.cos(a):.0f},{470 + r * math.sin(a):.0f}")
    rays = "".join(f'<div class="a" style="left:195px;top:470px;width:600px;height:{rnd.randint(4,14)}px;background:#ffffff22;transform-origin:0 50%;transform:rotate({k*15+rnd.randint(-4,4)}deg)"></div>' for k in range(24))
    body = f"""<div class="a" style="inset:0;background:{bg}"></div>{rays}
<div class="a" style="inset:0;background:radial-gradient(#0003 2.2px,transparent 2.5px) 0 0/11px 11px"></div>
<svg class="a" style="left:0;top:0" width="390" height="844"><polygon points="{' '.join(pts)}" fill="{fill}" stroke="#111" stroke-width="9" stroke-linejoin="round"/></svg>
<div class="a" style="left:0;top:405px;width:390px;text-align:center;font:118px/1 'Bangers';color:#111;transform:rotate({rnd.choice([-8,-5,6])}deg);letter-spacing:2px;text-shadow:5px 5px 0 #fff">{w}</div>
<div class="a" style="left:26px;top:700px;padding:8px 14px;background:#fff;border:4px solid #111;font:24px 'Bangers';color:#111;transform:rotate(-3deg);box-shadow:6px 6px 0 #111">EP.{rnd.randint(10,99)} · TO BE CONTINUED</div>"""
    OUT[f"sfx{i}"] = (page(body, 0.2), (w.strip('!'), "COMIC SFX", fill))

# ---------- 6. STREET SIGNS ----------
SS = [
    ("NEON AVE", "霓虹大道", "#1A1A18", "09"), ("SIXTH ST", "六街", INK, "06"),
    ("MIDNIGHT RD", "午夜路", "#2A2A26", "24"), ("ARCADE LN", "電玩巷", INK3, "88"), ("DOCK 9", "九號碼頭", "#2A2A26", "9"),
]
for i, (en, zh, col, num) in enumerate(SS):
    sky = [ACID, LIME, "#2A2A26", "#DDFF2A", MOSS][i]
    body = f"""<div class="a" style="inset:0;background:linear-gradient({sky},#151515 92%)"></div>
<div class="a" style="left:182px;top:250px;width:26px;height:600px;background:linear-gradient(90deg,#555,#999 40%,#555)"></div>
<div class="a" style="left:28px;top:320px;width:334px;height:110px;border-radius:12px;background:{col};border:6px solid #F5F5F0;box-shadow:8px 10px 0 #0005">
<div class="a" style="left:18px;top:8px;font:900 46px 'Noto Sans TC';color:#F5F5F0;letter-spacing:6px">{zh}</div>
<div class="a" style="left:20px;top:64px;font:30px 'Bebas Neue';color:#F5F5F0;letter-spacing:4px">{en}</div>
<div class="a c" style="right:16px;top:20px;width:58px;height:58px;border-radius:50%;background:#F5F5F0;color:{col};font:26px 'Anton'">{num}</div></div>
<div class="a" style="left:64px;top:470px;width:262px;height:130px;border-radius:10px;background:#F5F5F0;border:5px solid #111;transform:rotate(-2deg)">
<div class="a" style="left:16px;top:10px;font:22px 'Bebas Neue';color:#111;letter-spacing:3px">BUS STOP · 巴士站</div>
<div class="a" style="left:16px;top:42px;display:flex;gap:8px">{''.join(f'<div class="c" style="width:52px;height:40px;border-radius:6px;background:{c};color:#fff;font:22px Anton">{n}</div>' for n,c in [("9",OLIVE),("N9","#111"),("24",DEEP),("X","#2A2A26")])}</div>
<div class="a m" style="left:16px;top:94px;font-size:10px;color:#111">NEXT 02 MIN · LAST 00:42</div></div>
{mono(24, 800, 'ZONE 09 · STREET INDEX', '#ffffff88')}"""
    OUT[f"street{i}"] = (page(body, 0.3), (en, zh, col))

# ---------- 7. STICKER SHEETS ----------
SK = [(PAPER, ["STAY ODD", "LVL 99", "NO SLEEP", "★", "HYPE", "09"]),
      ("#111111", ["GLITCH", "OK!", "RUN", "☆", "LOUD", "404"]),
      (ACID, ["BIG MOOD", "NOPE", "YES", "✦", "LATE", "777"]),
      (DEEP, ["COOL", "WOW", "ZONE", "✚", "VIBE", "24/7"]),
      (LIME, ["CUTE", "BUT", "PSYCHO", "♥", "XOXO", "13"])]
PAL = [LIME, ACID, LITE, "#111111", OLIVE, MOSS, PAPER, "#2A2A26", "#DDFF2A"]
for i, (bg, words) in enumerate(SK):
    rnd = random.Random(700 + i)
    spots = [(30, 300), (210, 290), (40, 430), (250, 420), (60, 560), (220, 570)]
    items = ""
    for k, ((x, y), w) in enumerate(zip(spots, words)):
        c = rnd.choice([p for p in PAL if p != bg])
        tc = "#fff" if dark(c) else "#111"
        shape = rnd.choice(["border-radius:14px", "border-radius:50px", "border-radius:50%", "border-radius:4px"])
        size = 110 if "50%" in shape else None
        dims = f"width:{size}px;height:{size}px;" if size else "padding:10px 18px;"
        fs = 44 if len(w) <= 3 else 30
        items += f'<div class="a c" style="left:{x}px;top:{y}px;{dims}{shape};background:{c};border:5px solid #fff;box-shadow:0 0 0 3px #111,6px 8px 0 3px #0005;font:{fs}px Bungee;color:{tc};transform:rotate({rnd.randint(-14,14)}deg);white-space:nowrap">{w}</div>'
    tape = f'<div class="a" style="left:120px;top:270px;width:140px;height:34px;background:#ffffffaa;transform:rotate(-6deg)"></div>'
    body = f"""<div class="a" style="inset:0;background:{bg}"></div>
<div class="a" style="inset:0;background:radial-gradient(#00000014 1.5px,transparent 1.8px) 0 0/10px 10px"></div>{tape}{items}
{mono(24, 800, 'STICKER SHEET No.' + str(i+1).zfill(2), '#ffffffaa' if dark(bg) else '#111a')}"""
    OUT[f"sticker{i}"] = (page(body, 0.2), (words[0], " · ".join(words[1:3]), PAL[i]))

# ---------- 8. TYPE POSTERS ----------
TP = [("NO", "SLEEP", "#0B0B0C", "#DDFF2A", PAPER), ("STAY", "WILD", LIME, "#111111", "#2A2A26"),
      ("HYPER", "DRIVE", INK2, ACID, LIME), ("VOID", "MODE", PAPER, "#111111", OLIVE),
      ("LOUD", "&PROUD", DEEP, ACID, LITE)]
for i, (a1, a2, bg, c1, c2) in enumerate(TP):
    f1 = min(190, int(340 / (0.46 * len(a1))))
    f2 = min(170, int(340 / (0.46 * len(a2))))
    body = f"""<div class="a" style="inset:0;background:{bg}"></div>
<div class="a" style="left:24px;top:{440 - f1}px;font:{f1}px/0.86 'Anton';color:{c1};white-space:nowrap">{a1}</div>
<div class="a" style="left:24px;top:448px;font:{f2}px/0.86 'Anton';color:transparent;-webkit-text-stroke:3px {c2};white-space:nowrap">{a2}</div>
<div class="a" style="left:24px;top:{456 + f2}px;width:342px;height:14px;background:{c2}"></div>
<div class="a" style="left:0;top:690px;width:390px;height:28px;background:repeating-linear-gradient(-45deg,{c1} 0 14px,transparent 14px 28px)"></div>
{mono(24, 740, 'VOL.' + str(i+9).zfill(2) + ' · ZONE 09 · EST 2026', c2, 11)}
<div class="a c" style="right:24px;top:740px;width:54px;height:54px;border-radius:50%;border:3px solid {c1};color:{c1};font:22px Anton">{i+1:02d}</div>"""
    OUT[f"type{i}"] = (page(body, 0.25), (f"{a1} {a2}", "TYPE POSTER", c1))

# ---------- 9. PIXEL SCENES ----------
PX = [("RAIN", ["#050505", "#121211", "#2A2A26"], LIME), ("SNOW", ["#0D140A", "#2A2A26", MOSS], "#FFFFFF"),
      ("SUNRISE", [INK, OLIVE, ACID], LITE), ("LIME NIGHT", ["#0B0B0A", "#1E3310", "#C2EE14"], ACID),
      ("MATRIX", ["#050505", "#0B0B0A", "#1A1A18"], LIME)]
for i, (name, sky, fx) in enumerate(PX):
    rnd = random.Random(900 + i)
    bld, x = "", 0
    while x < 390:
        w = rnd.choice([30, 36, 42, 48]); h = rnd.randint(140, 360); top = 764 - h
        bld += f'<div class="a" style="left:{x}px;top:{top}px;width:{w}px;height:{h}px;background:{rnd.choice(["#0A0A09","#111110","#070707"])}"></div>'
        for wy in range(top + 12, 750, 18):
            for wx in range(x + 6, x + w - 8, 12):
                if rnd.random() < 0.3:
                    bld += f'<div class="a" style="left:{wx}px;top:{wy}px;width:6px;height:8px;background:{rnd.choice([fx,ACID,MOSS])}"></div>'
        x += w
    if name == "RAIN":
        fxl = "".join(f'<div class="a" style="left:{rnd.randint(0,390)}px;top:{rnd.randint(0,760)}px;width:2px;height:{rnd.randint(10,22)}px;background:{fx}aa;transform:rotate(12deg)"></div>' for _ in range(140))
    elif name == "SNOW":
        fxl = "".join(f'<div class="a" style="left:{rnd.randint(0,390)}px;top:{rnd.randint(0,800)}px;width:{(s:=rnd.choice([3,3,6]))}px;height:{s}px;background:#fff"></div>' for _ in range(150))
    elif name == "MATRIX":
        fxl = "".join(f'<div class="a" style="left:{k*16}px;top:{rnd.randint(-200,300)}px;font:12px/14px \'Press Start 2P\';color:{fx};opacity:{rnd.choice([.3,.5,.8])};writing-mode:vertical-rl">{"".join(rnd.choice("01ZONE09") for _ in range(rnd.randint(8,26)))}</div>' for k in range(25))
    else:
        sun = LITE if name == 'SUNRISE' else ACID
        fxl = f'<div class="a" style="left:130px;top:{470 if name=="SUNRISE" else 300}px;width:130px;height:130px;background:{sun};clip-path:polygon(25% 0,75% 0,75% 8%,92% 8%,92% 25%,100% 25%,100% 75%,92% 75%,92% 92%,75% 92%,75% 100%,25% 100%,25% 92%,8% 92%,8% 75%,0 75%,0 25%,8% 25%,8% 8%,25% 8%)"></div>'
        fxl += "".join(f'<div class="a" style="left:{rnd.randint(0,385)}px;top:{rnd.randint(40,320)}px;width:3px;height:3px;background:#fff"></div>' for _ in range(36))
    body = f"""<div class="a" style="inset:0;background:linear-gradient({sky[0]},{sky[1]} 55%,{sky[2]})"></div>{fxl}{bld}
<div class="a" style="left:0;top:764px;width:390px;height:80px;background:#050505"></div>
<div class="a" style="left:24px;top:792px;font:13px 'Press Start 2P';color:{fx}">{name}</div>
<div class="a" style="right:24px;top:796px;font:9px 'Press Start 2P';color:#ffffffaa">STAGE {i+2}</div>"""
    OUT[f"pixel{i}"] = (page(body, 0.12), (name, "PIXEL CITY", fx))

# ---------- 10. GRAPHIC PATTERNS ----------
GP = [("CHECKER", "#111", LIME, ACID), ("TARGET", "#0B0B0C", "#DDFF2A", LITE),
      ("STRIPE", ACID, "#111", LIME), ("WAVE", DEEP, LIME, ACID), ("STARS", INK, MOSS, ACID)]
for i, (name, bg, c1, c2) in enumerate(GP):
    if name == "CHECKER":
        pat = f'<div class="a" style="inset:0;background:conic-gradient({c1} 25%,{bg} 0 50%,{c1} 0 75%,{bg} 0) 0 0/64px 64px;transform:perspective(500px) rotateX(48deg) scale(2.2);transform-origin:50% 100%"></div>'
    elif name == "TARGET":
        pat = f'<div class="a" style="left:-260px;top:-50px;width:910px;height:910px;border-radius:50%;background:repeating-radial-gradient(circle,{c1} 0 18px,{bg} 18px 40px);opacity:.9"></div>'
    elif name == "STRIPE":
        pat = f'<div class="a" style="inset:0;background:repeating-linear-gradient(115deg,{c1} 0 26px,{bg} 26px 64px)"></div>'
    elif name == "WAVE":
        paths = "".join(f'<path d="M-20 {y} Q 60 {y-40} 140 {y} T 300 {y} T 460 {y}" fill="none" stroke="{c1}" stroke-width="10" opacity="{.35 if k%2 else .9}"/>' for k, y in enumerate(range(20, 860, 44)))
        pat = f'<svg class="a" style="left:0;top:0" width="390" height="844">{paths}</svg>'
    else:
        rnd = random.Random(1000)
        pat = "".join(f'<div class="a" style="left:{rnd.randint(0,370)}px;top:{rnd.randint(0,820)}px;font-size:{rnd.choice([14,22,34])}px;color:{rnd.choice([c1,c2,"#fff"])}">✦</div>' for _ in range(70))
    tc = "#fff" if dark(c2) else "#111"
    body = f"""<div class="a" style="inset:0;background:{bg}"></div>{pat}
<div class="a c" style="left:55px;top:350px;width:280px;height:280px;border-radius:50%;background:{c2};border:8px solid #111;box-shadow:12px 12px 0 #111">
<div style="text-align:center;font:{min(56, int(220 / (0.95 * len(name))))}px/1.1 'Rubik Mono One';color:{tc}">{name}<br><span style="font-size:22px;letter-spacing:4px">ZONE·09</span></div></div>
<div class="a" style="left:24px;top:780px;padding:6px 12px;background:#111;color:{c2};font:14px 'Space Mono';letter-spacing:3px">PATTERN/{i+1:02d}</div>"""
    OUT[f"pattern{i}"] = (page(body, 0.18), (name, "GRAPHIC PATTERN", c2))

order = [f"{f}{i}" for i in range(5) for f in ["neon", "ticket", "warn", "tech", "sfx", "street", "sticker", "type", "pixel", "pattern"]]
meta = []
for n, key in enumerate(order, start=33):
    html, (title, tag, accent) = OUT[key]
    open(os.path.join(D, f"W{n:02d}.html"), "w").write(html)
    meta.append({"id": n, "title": title, "tag": tag, "accent": accent})
json.dump(meta, open(os.path.join(D, "meta.json"), "w"), ensure_ascii=False, indent=0)
print(len(meta), "written")
