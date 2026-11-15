# Generates the 12 "街頭新番" wallpapers (390x844 CSS px, rendered @3x).
import os, random
D = os.path.dirname(os.path.abspath(__file__))
FONTS = "family=Anton&family=Bangers&family=Bebas+Neue&family=Black+Ops+One&family=Bungee&family=Monoton&family=Permanent+Marker&family=Press+Start+2P&family=Space+Mono:wght@700&family=Noto+Sans+TC:wght@900"
GRAIN = ("background-image:url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='180' height='180'>"
         "<filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='2' stitchTiles='stitch'/>"
         "<feColorMatrix values='0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 .55 0'/></filter>"
         "<rect width='100%' height='100%' filter='url(%23n)'/></svg>\")")

def page(title, body, css="", grain=0.28):
    return f"""<!doctype html><html><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?{FONTS}&display=swap">
<style>body{{margin:0}}*{{box-sizing:border-box}}
.a{{position:absolute}}.c{{display:flex;align-items:center;justify-content:center}}
.grain{{position:absolute;inset:0;{GRAIN};opacity:{grain};mix-blend-mode:multiply;pointer-events:none}}
.mono{{font-family:'Space Mono',monospace}}
{css}</style></head><body>
<div style="width:390px;height:844px;position:relative;overflow:hidden">{body}<div class="grain"></div></div></body></html>"""

W = {}

# 21 NEON NOODLE
noren = "".join(f'<div class="a c" style="left:{8+i*95}px;top:0;width:88px;height:150px;background:#C8102E;border-bottom:6px solid #8E0A20"><div style="width:46px;height:46px;border-radius:50%;border:5px solid #F5EBDD;font:900 22px \'Noto Sans TC\';color:#F5EBDD" class="c">{ch}</div></div>' for i,ch in enumerate("拉麵通宵"))
W["N21Noodle"] = page("Neon Noodle", f"""
<div class="a" style="inset:0;background:radial-gradient(120% 70% at 50% 40%,#1B1F4A 0,#0A0C1C 70%)"></div>
<div class="a" style="inset:0;background-image:linear-gradient(#ffffff08 2px,transparent 2px),linear-gradient(90deg,#ffffff06 2px,transparent 2px);background-size:60px 28px"></div>
<div class="a" style="left:34px;top:300px;width:150px;height:330px;border:5px solid #FF3D9A;border-radius:22px;box-shadow:0 0 10px #FF3D9A,0 0 30px #FF3D9A,inset 0 0 18px #FF3D9A88"></div>
<div class="a" style="left:34px;top:300px;width:150px;height:330px;font:900 118px/1.2 'Noto Sans TC';color:#FFE6F3;text-align:center;writing-mode:vertical-rl;text-shadow:0 0 6px #FF3D9A,0 0 20px #FF3D9A,0 0 44px #FF3D9A;padding-top:14px">拉麵</div>
<div class="a" style="left:200px;top:312px;font:60px/1 'Monoton';color:#E6FDFF;text-shadow:0 0 6px #2EE6FF,0 0 22px #2EE6FF,0 0 40px #2EE6FF">NOO<br>DLE</div>
<div class="a mono" style="left:206px;top:470px;padding:7px 12px;border:2px solid #FFE14A;color:#FFE14A;font-size:15px;letter-spacing:3px;box-shadow:0 0 12px #FFE14A;text-shadow:0 0 8px #FFE14A">OPEN 24H</div>
<svg class="a" style="left:200px;top:520px" width="160" height="110" viewBox="0 0 160 110"><g fill="none" stroke="#ffffff55" stroke-width="5" stroke-linecap="round"><path d="M30 105c-14-18 14-30 0-50s14-30 0-50"/><path d="M80 105c-14-18 14-30 0-50s14-30 0-50"/><path d="M130 105c-14-18 14-30 0-50s14-30 0-50"/></g></svg>
<div class="a" style="left:0;top:660px;width:390px;height:184px">{noren}</div>
<div class="a" style="left:0;top:800px;width:390px;height:44px;background:#06070F"></div>
<div class="a mono" style="left:24px;top:812px;color:#8A90C8;font-size:11px;letter-spacing:2px">SECTOR 09 · BACK ALLEY · ¥980</div>
""", grain=0.35)

# 22 MIXTAPE
W["N22Mixtape"] = page("Mixtape", """
<div class="a" style="inset:0;background:#F1E6CF"></div>
<div class="a" style="right:-90px;top:120px;width:330px;height:330px;border-radius:50%;background:radial-gradient(#FF6B2C 2.6px,transparent 2.8px) 0 0/12px 12px;opacity:.55"></div>
<div class="a" style="left:0;top:250px;width:390px;height:22px;background:repeating-linear-gradient(90deg,#FF6B2C 0 60px,#FFC23D 60px 120px,#2E7DFF 120px 180px)"></div>
<div class="a" style="left:30px;top:310px;width:330px;height:212px;border-radius:16px;background:#1C1B1F;box-shadow:10px 12px 0 #FF6B2C;transform:rotate(-4deg)">
 <div class="a" style="left:18px;top:16px;width:294px;height:122px;border-radius:8px;background:#F7F1E3;overflow:hidden">
  <div class="a" style="left:0;top:0;width:100%;height:30px;background:#FF6B2C"></div>
  <div class="a" style="left:0;top:30px;width:100%;height:8px;background:#FFC23D"></div>
  <div class="a" style="left:12px;top:44px;font:30px 'Permanent Marker';color:#1C1B1F">midnight mix</div>
  <div class="a" style="left:10px;top:4px;font:22px 'Bebas Neue';color:#F7F1E3;letter-spacing:2px">C-90 · VOL.09</div>
  <div class="a" style="left:66px;top:84px;width:162px;height:34px;border-radius:17px;background:#2B2A30"></div>
  <div class="a c" style="left:76px;top:88px;width:26px;height:26px;border-radius:50%;background:#F7F1E3;border:6px dotted #2B2A30"></div>
  <div class="a c" style="left:192px;top:88px;width:26px;height:26px;border-radius:50%;background:#F7F1E3;border:6px dotted #2B2A30"></div>
 </div>
 <div class="a" style="left:70px;top:150px;width:190px;height:50px;background:#2B2A30;clip-path:polygon(10% 0,90% 0,100% 100%,0 100%)"></div>
 <div class="a" style="left:12px;top:178px;width:12px;height:12px;border-radius:50%;background:#55535C"></div>
 <div class="a" style="left:306px;top:178px;width:12px;height:12px;border-radius:50%;background:#55535C"></div>
</div>
<div class="a c" style="left:262px;top:278px;width:96px;height:96px;border-radius:50%;background:#2E7DFF;color:#F7F1E3;font:30px/0.9 'Bangers';text-align:center;transform:rotate(12deg);border:4px solid #1C1B1F">SIDE<br>A</div>
<div class="a" style="left:28px;top:582px;font:76px/0.9 'Anton';color:#1C1B1F;letter-spacing:-1px">REWIND<br><span style="color:#FF6B2C">REPEAT</span></div>
<div class="a mono" style="left:30px;top:742px;color:#5C564A;font-size:11px;line-height:1.7">A1 NIGHT SHIFT ........ 3:47<br>A2 LAST TRAIN ......... 4:09</div>
<div class="a" style="left:-20px;top:560px;width:120px;height:30px;background:#FFC23Dcc;transform:rotate(-30deg)"></div>
""", grain=0.3)

# 23 ROUND 2
lines23 = "".join(f'<div class="a" style="left:195px;top:470px;width:700px;height:{random.Random(i).randint(2,7)}px;background:#ffffff{random.Random(i*7).choice(["18","22","30"])};transform-origin:0 50%;transform:rotate({i*360/48}deg) translateX(150px)"></div>' for i in range(48))
W["N23Round"] = page("Round 2", f"""
<div class="a" style="inset:0;background:linear-gradient(180deg,#1E0838 0,#5B0F4A 45%,#FF3D2E 100%)"></div>
{lines23}
<div class="a" style="left:22px;top:282px;width:150px;height:20px;background:#1E0838;border:3px solid #FFF;transform:skewX(-20deg)"><div style="width:68%;height:100%;background:linear-gradient(#FFE14A,#FF9E1A)"></div></div>
<div class="a" style="left:218px;top:282px;width:150px;height:20px;background:#1E0838;border:3px solid #FFF;transform:skewX(20deg)"><div style="margin-left:auto;width:31%;height:100%;background:linear-gradient(#FFE14A,#FF9E1A)"></div></div>
<div class="a c" style="left:170px;top:270px;width:50px;height:44px;font:34px 'Bebas Neue';color:#FFF;background:#1E0838;border:3px solid #FFF">99</div>
<div class="a mono" style="left:24px;top:310px;color:#FFE14A;font-size:11px">P1 · STREET</div><div class="a mono" style="right:24px;top:310px;color:#FFE14A;font-size:11px">CPU · BOSS</div>
<div class="a" style="left:0;top:380px;width:390px;text-align:center;font:118px/1 'Bangers';color:#FFE14A;letter-spacing:2px;-webkit-text-stroke:7px #1E0838;paint-order:stroke fill;transform:rotate(-7deg);text-shadow:8px 8px 0 #1E0838">ROUND 2</div>
<div class="a" style="left:0;top:500px;width:390px;text-align:center;font:150px/1 'Bangers';color:#FF2E4D;-webkit-text-stroke:8px #FFF;paint-order:stroke fill;transform:rotate(-7deg);text-shadow:10px 10px 0 #1E0838">FIGHT!</div>
<div class="a" style="left:30px;top:700px;padding:6px 14px;background:#FFF;color:#1E0838;font:28px 'Bangers';letter-spacing:1px;transform:rotate(3deg);box-shadow:6px 6px 0 #1E0838">12 HITS COMBO!!</div>
""", grain=0.25)

# 24 VENDING
cols = ["#FF3D2E","#2E7DFF","#FFC23D","#3DFFB0","#FF5BC8","#E8FF3A","#7A4DFF","#FF8A3D","#2EE6FF","#F5F5F0","#FF3D2E","#1C1B1F"]
cans = ""
for i,c in enumerate(cols):
    x = 64 + (i%4)*58; y = 360 + (i//4)*104
    cans += f'<div class="a" style="left:{x}px;top:{y}px;width:40px;height:70px;border-radius:9px 9px 6px 6px;background:linear-gradient(90deg,#0003,transparent 30%,#fff5 45%,transparent 60%),{c};border:2px solid #0006"><div style="margin-top:24px;height:14px;background:#fff9"></div></div>'
    cans += f'<div class="a c mono" style="left:{x-4}px;top:{y+74}px;width:48px;height:16px;background:#111;color:#3DFF6A;font-size:10px">¥{[120,130,150,100][i%4]}</div>'
W["N24Vending"] = page("Vending", f"""
<div class="a" style="inset:0;background:linear-gradient(#0B1E36,#14365C)"></div>
<div class="a" style="left:0;top:760px;width:390px;height:84px;background:#0A1424"></div>
<div class="a" style="left:40px;top:270px;width:310px;height:540px;border-radius:14px;background:#E7ECEF;box-shadow:0 0 60px #2EE6FF55,12px 0 0 #B8C2CA inset"></div>
<div class="a c" style="left:56px;top:284px;width:278px;height:50px;border-radius:8px;background:#0B1E36;font:30px 'Bungee';color:#E6FDFF;text-shadow:0 0 8px #2EE6FF,0 0 22px #2EE6FF">COLD ▸ DRINKS</div>
<div class="a" style="left:56px;top:346px;width:240px;height:322px;border-radius:6px;background:linear-gradient(135deg,#ffffff22,transparent 40%),#0F2440"></div>
{cans}
<div class="a" style="left:302px;top:346px;width:32px;height:120px;border-radius:6px;background:#C9D2D9"></div>
<div class="a" style="left:312px;top:360px;width:12px;height:36px;border-radius:6px;background:#1C1B1F"></div>
<div class="a" style="left:306px;top:420px;width:24px;height:24px;border-radius:50%;background:#FF3D2E;box-shadow:0 0 10px #FF3D2E"></div>
<div class="a" style="left:76px;top:690px;width:200px;height:52px;border-radius:6px;background:#1C1B1F"></div>
<div class="a mono" style="left:90px;top:707px;color:#ffffff88;font-size:12px">PUSH ▸</div>
<div class="a mono" style="left:24px;top:812px;color:#7FA3C8;font-size:11px;letter-spacing:2px">24H · SECTOR 09 · NO CHANGE</div>
""", grain=0.3)

# 25 PIXEL CITY
rnd = random.Random(25)
bld = ""
x = 0
while x < 390:
    w = rnd.choice([30,36,42,48,54]); h = rnd.randint(150,380); top = 844-80-h
    shade = rnd.choice(["#1A1033","#21143F","#140C29"])
    bld += f'<div class="a" style="left:{x}px;top:{top}px;width:{w}px;height:{h}px;background:{shade}"></div>'
    for wy in range(top+12, 844-90, 18):
        for wx in range(x+6, x+w-8, 12):
            if rnd.random() < 0.33:
                bld += f'<div class="a" style="left:{wx}px;top:{wy}px;width:6px;height:8px;background:{rnd.choice(["#FFD15C","#FFB03D","#2EE6FF"])}"></div>'
    x += w + rnd.choice([0,0,4])
W["N25Pixel"] = page("Pixel City", f"""
<div class="a" style="inset:0;background:linear-gradient(#120B33 0,#3B1663 35%,#C2335F 62%,#FF8A3D 78%,#FFC95C 100%)"></div>
<div class="a" style="left:240px;top:290px;width:96px;height:96px;background:#FFE9A8;clip-path:polygon(25% 0,75% 0,75% 8%,92% 8%,92% 25%,100% 25%,100% 75%,92% 75%,92% 92%,75% 92%,75% 100%,25% 100%,25% 92%,8% 92%,8% 75%,0 75%,0 25%,8% 25%,8% 8%,25% 8%);box-shadow:0 0 0 #0000"></div>
<div class="a" style="left:226px;top:276px;width:124px;height:124px;border-radius:50%;background:#FFE9A822;filter:blur(10px)"></div>
{''.join(f'<div class="a" style="left:{rnd.randint(0,385)}px;top:{rnd.randint(60,330)}px;width:3px;height:3px;background:#fff"></div>' for _ in range(40))}
{bld}
<div class="a" style="left:0;top:764px;width:390px;height:80px;background:#0B0720"></div>
<div class="a" style="left:0;top:764px;width:390px;height:4px;background:repeating-linear-gradient(90deg,#FF5BC8 0 12px,transparent 12px 24px)"></div>
<div class="a" style="left:24px;top:790px;font:14px 'Press Start 2P';color:#FFD15C;text-shadow:3px 3px 0 #C2335F">PIXEL CITY</div>
<div class="a" style="right:24px;top:794px;font:9px 'Press Start 2P';color:#ffffffaa">1-UP</div>
""", grain=0.18)

# 26 WANTED
W["N26Wanted"] = page("Wanted", """
<div class="a" style="inset:0;background:#7A5234"></div>
<div class="a" style="inset:0;background:radial-gradient(#0002 1.5px,transparent 1.6px) 0 0/7px 7px,radial-gradient(#fff1 1px,transparent 1.2px) 3px 3px/9px 9px"></div>
<div class="a" style="left:40px;top:270px;width:310px;height:470px;background:#EBDDBB;box-shadow:8px 10px 0 #0005;transform:rotate(-3deg)">
 <div class="a" style="inset:10px;border:3px solid #3B2A1A"></div>
 <div class="a" style="left:0;top:22px;width:100%;text-align:center;font:62px/1 'Black Ops One';color:#3B2A1A;letter-spacing:2px">WANTED</div>
 <div class="a mono" style="left:0;top:88px;width:100%;text-align:center;font-size:11px;color:#6B5338;letter-spacing:3px">FOR LOOKING TOO COOL</div>
 <div class="a c" style="left:55px;top:112px;width:200px;height:180px;background:#D4C29B;border:4px solid #3B2A1A;overflow:hidden">
  <svg width="200" height="180" viewBox="0 0 200 180"><circle cx="100" cy="72" r="38" fill="#3B2A1A"/><path d="M28 180c4-52 36-70 72-70s68 18 72 70z" fill="#3B2A1A"/><text x="100" y="92" text-anchor="middle" font-family="Black Ops One" font-size="56" fill="#EBDDBB">?</text></svg>
 </div>
 <div class="a" style="left:0;top:306px;width:100%;text-align:center;font:24px 'Bebas Neue';color:#6B5338;letter-spacing:3px">REWARD</div>
 <div class="a" style="left:0;top:330px;width:100%;text-align:center;font:56px/1 'Anton';color:#B3261E">₵ 9,999,999</div>
 <div class="a mono" style="left:0;top:404px;width:100%;text-align:center;font-size:11px;color:#3B2A1A;letter-spacing:2px">LAST SEEN · SECTOR 09 · 02:47</div>
</div>
<div class="a" style="left:150px;top:252px;width:110px;height:34px;background:#F2EBD9cc;transform:rotate(4deg)"></div>
<div class="a" style="left:290px;top:690px;width:90px;height:30px;background:#F2EBD9cc;transform:rotate(-38deg)"></div>
<div class="a" style="left:58px;top:280px;width:20px;height:20px;border-radius:50%;background:radial-gradient(circle at 35% 35%,#FF8A80,#C62828);box-shadow:3px 4px 0 #0006"></div>
<div class="a" style="left:24px;top:770px;padding:6px 12px;background:#E8FF3A;color:#111;font:20px 'Bebas Neue';letter-spacing:2px;transform:rotate(-2deg)">ZONE 09 · BOUNTY BOARD</div>
""", grain=0.4)

# 27 SKATE
W["N27Skate"] = page("Skate", """
<div class="a" style="inset:0;background:#A3A39E"></div>
<div class="a" style="inset:0;background:radial-gradient(#0001 1px,transparent 1.5px) 0 0/5px 5px,linear-gradient(#0000 60%,#0002)"></div>
<div class="a" style="left:0;top:96px;width:390px;height:2px;background:#0002"></div><div class="a" style="left:0;top:480px;width:390px;height:2px;background:#0002"></div>
<div class="a" style="left:22px;top:262px;font:112px/1 'Permanent Marker';color:#FF3D9A;opacity:.9;transform:rotate(-8deg);text-shadow:4px 4px 0 #0003">RAD</div>
<div class="a" style="left:44px;top:350px;width:6px;height:70px;background:#FF3D9A;border-radius:3px"></div><div class="a" style="left:118px;top:360px;width:5px;height:90px;background:#FF3D9A;border-radius:3px"></div>
<div class="a" style="left:317px;top:390px;width:30px;height:30px;border-radius:50%;background:#F5F5F0;border:6px solid #2B2B2B"></div><div class="a" style="left:155px;top:338px;width:30px;height:30px;border-radius:50%;background:#F5F5F0;border:6px solid #2B2B2B"></div><div class="a" style="left:205px;top:732px;width:30px;height:30px;border-radius:50%;background:#F5F5F0;border:6px solid #2B2B2B"></div><div class="a" style="left:43px;top:680px;width:30px;height:30px;border-radius:50%;background:#F5F5F0;border:6px solid #2B2B2B"></div>
<div class="a" style="left:120px;top:300px;width:150px;height:500px;border-radius:75px;background:#151515;transform:rotate(18deg);box-shadow:14px 14px 0 #0004;overflow:hidden">
 <div class="a" style="left:0;top:140px;width:150px;height:220px;background:#E8FF3A;clip-path:polygon(55% 0,20% 55%,48% 55%,30% 100%,82% 40%,52% 40%,72% 0)"></div>
 <div class="a" style="left:0;top:40px;width:150px;text-align:center;font:30px 'Bungee';color:#FF3D9A">NO</div>
 <div class="a" style="left:0;top:400px;width:150px;text-align:center;font:30px 'Bungee';color:#FF3D9A">LIMIT</div>
</div>
<div class="a" style="left:30px;top:640px;padding:8px 14px;background:#2E7DFF;color:#fff;font:26px 'Bangers';letter-spacing:1px;border:4px solid #151515;transform:rotate(-6deg)">KICKFLIP CLUB</div>
<div class="a mono" style="left:24px;top:812px;color:#2B2B2B;font-size:11px;letter-spacing:2px">PARK 09 · OPEN TILL LATE</div>
""", grain=0.45)

# 28 KEEP OUT
def tape(top, rot, color, txt, tc="#111"):
    return f'<div class="a c" style="left:-80px;top:{top}px;width:560px;height:52px;background:{color};transform:rotate({rot}deg);box-shadow:0 8px 0 #0006;font:900 22px \'Noto Sans TC\';color:{tc};letter-spacing:4px;white-space:nowrap;overflow:hidden">{txt*3}</div>'
W["N28KeepOut"] = page("Keep Out", f"""
<div class="a" style="inset:0;background:#141414"></div>
<div class="a" style="inset:0;background:repeating-linear-gradient(45deg,#ffffff06 0 14px,transparent 14px 28px)"></div>
<div class="a c" style="left:95px;top:380px;width:200px;height:200px;border-radius:50%;border:22px solid #FF2E2E;background:#F5F5F0"><div style="width:190px;height:22px;background:#FF2E2E;transform:rotate(-45deg)"></div></div>
<div class="a c" style="left:95px;top:380px;width:200px;height:200px;font:900 44px 'Noto Sans TC';color:#141414;letter-spacing:4px">禁區</div>
{tape(300,-14,"#FFD21A","禁止進入 · KEEP OUT · ")}
{tape(560,10,"#FFD21A","施工中 · DO NOT CROSS · ")}
{tape(660,-6,"#FF2E2E","DANGER · 危險 · ","#FFF")}
<div class="a mono" style="left:24px;top:812px;color:#FFD21A;font-size:11px;letter-spacing:2px">AREA 09 · AUTHORIZED ONLY</div>
""", grain=0.35)

# 29 VHS
grid = "".join(f'<div class="a" style="left:0;top:{620+i*i*4}px;width:390px;height:2px;background:#FF3D9A;opacity:{0.4+i*0.05}"></div>' for i in range(1,12))
grid += "".join(f'<div class="a" style="left:195px;top:620px;width:2px;height:420px;background:#FF3D9A88;transform-origin:50% 0;transform:rotate({a}deg)"></div>' for a in range(-75,80,15))
W["N29VHS"] = page("VHS", f"""
<div class="a" style="inset:0;background:linear-gradient(#0D0221 0,#25074A 55%,#0D0221 100%)"></div>
<div class="a" style="left:75px;top:380px;width:240px;height:240px;border-radius:50%;background:linear-gradient(#FFE14A,#FF7A2E 50%,#FF2E88);-webkit-mask:linear-gradient(#000 0 52%,transparent 52% 56%,#000 56% 64%,transparent 64% 69%,#000 69% 76%,transparent 76% 82%,#000 82% 88%,transparent 88%);mask:linear-gradient(#000 0 52%,transparent 52% 56%,#000 56% 64%,transparent 64% 69%,#000 69% 76%,transparent 76% 82%,#000 82% 88%,transparent 88%)"></div>
<div class="a" style="left:0;top:618px;width:390px;height:226px;background:#0D0221"></div>
{grid}
<div class="a" style="left:0;top:520px;width:390px;text-align:center;font:64px/1 'Anton';color:#2EE6FF;transform:translateX(-4px);opacity:.85;letter-spacing:1px">MIDNIGHT RUN</div>
<div class="a" style="left:0;top:520px;width:390px;text-align:center;font:64px/1 'Anton';color:#FF2E4D;transform:translateX(4px);opacity:.85;letter-spacing:1px">MIDNIGHT RUN</div>
<div class="a" style="left:0;top:520px;width:390px;text-align:center;font:64px/1 'Anton';color:#FFF;letter-spacing:1px">MIDNIGHT RUN</div>
<div class="a" style="left:0;top:470px;width:390px;height:6px;background:#ffffff33"></div><div class="a" style="left:0;top:608px;width:390px;height:3px;background:#ffffff22"></div>
<div class="a" style="left:24px;top:300px;font:16px 'Press Start 2P';color:#3DFF6A;text-shadow:0 0 6px #3DFF6A">PLAY ▶</div>
<div class="a" style="right:24px;top:300px;font:12px 'Press Start 2P';color:#3DFF6A;text-shadow:0 0 6px #3DFF6A">SP</div>
<div class="a" style="left:24px;top:770px;font:12px 'Press Start 2P';color:#3DFF6A;text-shadow:0 0 6px #3DFF6A">00:09:26</div>
<div class="a" style="right:24px;top:770px;padding:4px 8px;border:2px solid #fff;color:#fff;font:14px 'Bebas Neue';letter-spacing:2px">HI-FI STEREO</div>
""", grain=0.3)

# 30 SODA POP
rb = random.Random(30)
bub = "".join(f'<div class="a" style="left:{rb.randint(0,370)}px;top:{rb.randint(260,820)}px;width:{(s:=rb.randint(8,34))}px;height:{s}px;border-radius:50%;border:3px solid #ffffffaa;background:radial-gradient(circle at 30% 30%,#fff8,transparent 50%)"></div>' for _ in range(26))
W["N30Soda"] = page("Soda Pop", f"""
<div class="a" style="inset:0;background:linear-gradient(160deg,#2EE6C9,#13B5A8)"></div>
<div class="a" style="left:-60px;top:560px;width:520px;height:340px;border-radius:50%;background:#0E8F86"></div>
{bub}
<div class="a" style="left:0;top:330px;width:390px;text-align:center;font:150px/1 'Bungee';color:#FFF6A8;-webkit-text-stroke:6px #0B3B3A;paint-order:stroke fill;text-shadow:0 10px 0 #0B3B3A;transform:rotate(-5deg)">FIZZ</div>
<svg class="a" style="left:228px;top:470px" width="140" height="140" viewBox="0 0 140 140"><circle cx="70" cy="70" r="62" fill="#E8FF3A" stroke="#0B3B3A" stroke-width="6"/><circle cx="70" cy="70" r="48" fill="#F6FFB0"/><g stroke="#E8FF3A" stroke-width="5">{''.join(f'<line x1="70" y1="70" x2="{70+48*__import__("math").cos(a*0.785)}" y2="{70+48*__import__("math").sin(a*0.785)}"/>' for a in range(8))}</g><circle cx="70" cy="70" r="8" fill="#E8FF3A"/></svg>
<div class="a" style="left:30px;top:520px;padding:8px 16px;background:#FF3D6E;color:#fff;font:30px 'Bangers';letter-spacing:2px;border:4px solid #0B3B3A;border-radius:30px;transform:rotate(-4deg)">LIME · ZERO</div>
<div class="a mono" style="left:24px;top:812px;color:#0B3B3A;font-size:11px;letter-spacing:2px">330ML · SERVE ICE COLD · 09</div>
""", grain=0.2)

# 31 LINE 9
wins = "".join(f'<div class="a" style="left:{22+i*120}px;top:330px;width:100px;height:150px;border-radius:14px;background:linear-gradient(160deg,#5B6A80 0,#1D2433 45%,#2E3A50 60%,#141A26);border:5px solid #C7CDD4"></div>' for i in range(3))
W["N31Line9"] = page("Line 9", f"""
<div class="a" style="inset:0;background:#2A2F38"></div>
<div class="a" style="left:0;top:280px;width:390px;height:400px;background:linear-gradient(#DADFE5,#AEB6C0)"></div>
<div class="a" style="left:0;top:280px;width:390px;height:400px;background:repeating-linear-gradient(90deg,transparent 0 128px,#0001 128px 131px)"></div>
{wins}
<div class="a" style="left:0;top:500px;width:390px;height:26px;background:#FFC21A"></div>
<div class="a c" style="left:300px;top:540px;width:64px;height:64px;border-radius:50%;background:#FFC21A;border:5px solid #1C1B1F;font:40px 'Anton';color:#1C1B1F">9</div>
<div class="a" style="left:18px;top:530px;font:86px/1 'Permanent Marker';color:#FF3D9A;-webkit-text-stroke:3px #1C1B1F;paint-order:stroke fill;transform:rotate(-6deg);text-shadow:5px 5px 0 #2EE6FF">HYPE</div>
<div class="a" style="left:0;top:680px;width:390px;height:164px;background:#3A3F48"></div>
<div class="a" style="left:0;top:690px;width:390px;height:30px;background:#FFD21A;background-image:radial-gradient(#0003 3px,transparent 3.5px);background-size:12px 12px"></div>
<div class="a" style="left:24px;top:740px;font:30px 'Bebas Neue';color:#F5F5F0;letter-spacing:3px">MIND THE GAP</div>
<div class="a mono" style="left:24px;top:812px;color:#9AA3AF;font-size:11px;letter-spacing:2px">LINE 9 · LAST TRAIN 00:42</div>
""", grain=0.3)

# 32 CONTINUE?
W["N32Continue"] = page("Continue", """
<div class="a" style="inset:0;background:#2B1055"></div>
<div class="a" style="inset:0;background:repeating-linear-gradient(45deg,#ffffff08 0 10px,transparent 10px 20px)"></div>
<div class="a" style="left:22px;top:270px;width:346px;height:450px;border-radius:30px;background:#151515;border:10px solid #3A2A6B;box-shadow:0 0 0 6px #7A4DFF,10px 12px 0 6px #0006"></div>
<div class="a" style="left:46px;top:294px;width:298px;height:402px;border-radius:22px;background:radial-gradient(#0B2A1E,#050A08);overflow:hidden">
 <div class="a" style="inset:0;background:repeating-linear-gradient(#0000 0 3px,#0006 3px 4px)"></div>
 <div class="a" style="left:0;top:40px;width:100%;text-align:center;font:22px 'Press Start 2P';color:#E8FF3A;text-shadow:0 0 8px #E8FF3A">CONTINUE?</div>
 <div class="a" style="left:0;top:110px;width:100%;text-align:center;font:150px/1 'Press Start 2P';color:#FF3D6E;text-shadow:0 0 14px #FF3D6E,6px 6px 0 #6B0F2A">9</div>
 <div class="a" style="left:0;top:300px;width:100%;text-align:center;font:12px 'Press Start 2P';color:#2EE6FF;text-shadow:0 0 6px #2EE6FF">INSERT COIN</div>
 <div class="a" style="left:0;top:340px;width:100%;text-align:center;font:10px 'Press Start 2P';color:#ffffffaa">CREDIT 00</div>
 <div class="a" style="left:22px;top:12px;font:10px 'Press Start 2P';color:#fff">♥♥♡</div>
 <div class="a" style="right:20px;top:12px;font:10px 'Press Start 2P';color:#fff">999990</div>
</div>
<div class="a" style="left:120px;top:740px;width:56px;height:56px;border-radius:50%;background:#FF3D6E;box-shadow:0 6px 0 #8E1A3A"></div>
<div class="a" style="left:200px;top:740px;width:56px;height:56px;border-radius:50%;background:#2EE6FF;box-shadow:0 6px 0 #127A88"></div>
<div class="a" style="left:60px;top:748px;width:14px;height:40px;border-radius:7px;background:#ddd"></div><div class="a" style="left:52px;top:736px;width:30px;height:30px;border-radius:50%;background:#E8FF3A"></div>
<div class="a" style="left:290px;top:752px;width:60px;height:30px;border-radius:6px;background:#111;border:3px solid #7A4DFF"></div>
""", grain=0.25)

for k,v in W.items():
    open(os.path.join(D, k + ".html"), "w").write(v)
print(len(W), "written")
