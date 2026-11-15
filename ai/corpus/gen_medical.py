#!/usr/bin/env python3
"""醫學語料：至少 5,000,000 字的問答與分析。

- 常見疾病：是什麼、症狀、原因、看哪科、怎麼照顧、什麼時候要立刻就醫、會不會傳染、怎麼預防（med_data.C）
- 症狀推理：給幾個症狀（加年紀、天數），列出符合的可能原因、理由、警訊、看哪科（從資料表交叉比對算出來）
- 數值判讀：BMI、血壓、空腹血糖、糖化血色素、體溫、每日喝水量、基礎代謝率（公式算，標準照台灣衛福部／醫學會）
- 急救與衛教、器官功能
每一題的答案都提醒：一般衛教，不能取代醫師診斷，有警訊要就醫。

python3 gen_medical.py 輸出.jsonl
"""
import json
import random
import sys

from med_data import C, ORGANS, QA

R = random.Random(5_000_001)
NOTE = ["（一般衛教資訊，不能取代醫師診斷。）", "（這是衛教參考，實際狀況請讓醫師看過。）", "（僅供參考，不舒服或不確定請就醫。）"]
WHO = [("", ""), ("我", ""), ("我媽媽（65歲）", "elder"), ("我爸爸（70歲）", "elder"), ("我小孩（5歲）", "child"), ("我女兒（8歲）", "child"),
       ("我老公", ""), ("我老婆", ""), ("我朋友", ""), ("我阿嬤（82歲）", "elder"), ("我（懷孕中）", "preg"), ("我寶寶（2個月）", "infant")]
SEX = {"我媽媽（65歲）": "f", "我女兒（8歲）": "f", "我老婆": "f", "我阿嬤（82歲）": "f", "我（懷孕中）": "f", "我爸爸（70歲）": "m", "我老公": "m"}
KID = {"我小孩（5歲）", "我女兒（8歲）", "我寶寶（2個月）"}


def fits(c, who):
    """性別、年紀對得上（小孩不會攝護腺肥大、男生不會經痛）"""
    sx = c.get("sex")
    if sx and who in KID:
        return False
    return not sx or SEX.get(who, sx) == sx
EXTRA = {"elder": "長者症狀常不典型、容易惡化，精神或食慾變差就要早點就醫。", "child": "小孩的用藥劑量要依體重，不要給大人的藥；精神活動力是最重要的觀察重點。",
         "preg": "懷孕期間用藥要先問婦產科醫師，不要自行吃成藥。", "infant": "三個月以下的嬰兒只要發燒（38°C 以上）或精神差、吃奶變少，就要立刻就醫。"}
out = []


def add(topic, q, a):
    out.append({"cat": "medical", "topic": topic, "q": q, "a": a + R.choice(NOTE)})


def red_text(c, k=4):
    return "、".join(c["red"][:k])


# ─────────── 疾病 ───────────
for c in C:
    n = c["n"]
    names = [n] + c["a"]
    for _ in range(14):
        nm = R.choice(names)
        who, kind = R.choice([x for x in WHO if fits(c, x[0])])
        ex = EXTRA.get(kind, "")
        t = R.randrange(9)
        if t == 0:
            add("疾病", R.choice([f"什麼是{nm}？", f"{nm}是什麼病？", f"{nm}是怎麼回事？"]),
                f"{n}是{c['c']}引起的；常見症狀有{'、'.join(c['s'][:5])}。{c['care']}。出現{red_text(c)}要盡快就醫。")
        elif t == 1:
            add("疾病", R.choice([f"{nm}有什麼症狀？", f"怎麼知道自己是不是{nm}？", f"{nm}的徵兆？"]),
                f"{n}常見的症狀：{'、'.join(c['s'])}。但這些症狀也可能是其他問題，要確定還是要給醫師看。特別注意：{red_text(c)}，出現就要立刻就醫。")
        elif t == 2:
            add("就醫", R.choice([f"{who}{nm}要看哪一科？", f"{nm}掛什麼科？", f"{who}好像是{nm}，要去哪看？"]),
                f"{n}可以看{c['dept']}。如果出現{red_text(c, 3)}，直接去急診。{ex}")
        elif t == 3:
            add("照顧", R.choice([f"{who}得了{nm}怎麼辦？", f"{nm}在家怎麼照顧？", f"{who}{nm}要注意什麼？"]),
                f"{c['care']}。要立刻就醫的警訊：{red_text(c)}。{ex}")
        elif t == 4:
            add("警訊", R.choice([f"{nm}什麼時候要去急診？", f"{nm}嚴重的話會怎樣？", f"{nm}有哪些危險徵兆？"]),
                f"出現這些就要馬上就醫或打119：{'、'.join(c['red'])}。平常可以看{c['dept']}。{ex}")
        elif t == 5:
            add("傳染", R.choice([f"{nm}會傳染嗎？", f"{nm}會不會傳給家人？"]), f"{c['ct']}。預防方法：{c['p']}。")
        elif t == 6:
            add("預防", R.choice([f"怎麼預防{nm}？", f"{nm}可以預防嗎？"]), f"預防{n}：{c['p']}。常見原因是{c['c']}，從這裡下手。")
        elif t == 7:
            add("原因", R.choice([f"為什麼會得{nm}？", f"{nm}的原因是什麼？"]), f"{n}常見的原因是{c['c']}。{c['care']}。")
        else:
            s = R.sample(c["s"], min(2, len(c["s"])))
            add("分析", f"{who or '我'}有{s[0]}{('和' + s[1]) if len(s) > 1 else ''}，會是{nm}嗎？",
                f"{'、'.join(s)}確實是{n}常見的症狀，{n}還常會有{'、'.join(x for x in c['s'] if x not in s)[:40] or '其他表現'}。"
                f"不過同樣的症狀也可能是別的原因，建議看{c['dept']}確認。{ex}出現{red_text(c, 3)}就立刻就醫。")

# ─────────── 症狀推理（交叉比對） ───────────
by_sym = {}
for c in C:
    for s in c["s"]:
        by_sym.setdefault(s, []).append(c)
shared = [s for s, cs in by_sym.items() if len(cs) >= 2]
DUR = ["今天開始", "兩天了", "三天了", "一個禮拜了", "兩個禮拜了", "一個月了", "反反覆覆好幾個月"]
for _ in range(9000):
    base = R.choice(C)
    k = min(len(base["s"]), R.choice([2, 2, 3, 3, 4]))
    syms = R.sample(base["s"], k)
    if R.random() < 0.3 and shared:
        extra = R.choice(shared)
        if extra not in syms:
            syms.append(extra)
    who, kind = R.choice([x for x in WHO if fits(base, x[0])])
    dur = R.choice(DUR)
    scored = []
    for c in C:
        if not fits(c, who):
            continue
        hit = [s for s in syms if s in c["s"]]
        if hit:
            scored.append((len(hit) / len(syms), len(hit), c, hit))
    scored.sort(key=lambda x: (-x[1], -x[0], x[2]["n"]))
    top = scored[:3]
    lines = []
    for _, cnt, c, hit in top:
        more = "、".join(x for x in c["s"] if x not in hit)[:30]
        lines.append(f"{c['n']}（符合{'、'.join(hit)}" + (f"；它通常還會有{more}）" if more else "）"))
    reds = []
    for _, _, c, _ in top:
        for r in c["red"]:
            if r not in reds:
                reds.append(r)
    long = dur in ("兩個禮拜了", "一個月了", "反反覆覆好幾個月")
    q = f"{who or '我'}{'、'.join(syms)}，{dur}，可能是什麼？"
    a = (f"依你說的{'、'.join(syms)}，比較可能的方向：" + "；".join(lines) + "。"
         f"建議先看{top[0][2]['dept']}。" + ("症狀拖了這麼久，更應該就醫找出原因。" if long else "")
         + f"出現這些要立刻就醫：{'、'.join(reds[:5])}。" + EXTRA.get(kind, "")
         + "我沒辦法看到你、做檢查，只能從症狀推可能性，不能當作診斷。")
    add("症狀分析", q, a)

# ─────────── 數值判讀 ───────────
for _ in range(7000):
    h = R.randint(140, 195)
    w = R.randint(35, 130)
    bmi = w / (h / 100) ** 2
    if bmi < 18.5:
        cat, adv = "過輕", "體重偏輕，要注意營養是否足夠、有沒有吃不下或體重突然減輕；均衡飲食加上肌力訓練。"
    elif bmi < 24:
        cat, adv = "正常範圍", "維持均衡飲食和規律運動就好。"
    elif bmi < 27:
        cat, adv = "過重", "建議控制熱量、少含糖飲料和油炸、每週運動 150 分鐘，先減 5% 體重就對健康有幫助。"
    else:
        cat, adv = "肥胖", "肥胖會增加三高、脂肪肝、睡眠呼吸中止的風險，建議找家醫科或減重門診一起規劃，飲食和運動雙管齊下。"
    lo, hi = 18.5 * (h / 100) ** 2, 24 * (h / 100) ** 2
    add("BMI", R.choice([f"我身高{h}公分、體重{w}公斤，BMI多少？", f"{h}公分{w}公斤算胖嗎？", f"身高{h}體重{w}，正常嗎？"]),
        f"BMI = {w} ÷ ({h / 100:.2f})² = {bmi:.1f}，屬於{cat}（台灣標準：18.5–24 正常、24–27 過重、27 以上肥胖）。"
        f"以你的身高，正常體重大約在 {lo:.1f} 到 {hi:.1f} 公斤之間。{adv}BMI 沒有分肌肉和脂肪，也要一起看腰圍（男 90、女 80 公分以上算腹部肥胖）。")
for _ in range(5000):
    s = R.randint(88, 200)
    d = R.randint(50, 125)
    if d > s - 15:
        d = s - R.randint(25, 60)
    if s >= 180 or d >= 120:
        cat, adv = "非常高（高血壓危急值）", "休息 5 分鐘再量一次；如果還是這麼高，或合併頭痛、胸痛、喘、視力模糊、手腳無力，立刻就醫或打119。"
    elif s >= 130 or d >= 80:
        cat, adv = "高血壓", "照 722 原則在家量一週記錄下來，給家醫科或心臟內科評估；少鹽、減重、運動、戒菸限酒。"
    elif s >= 120:
        cat, adv = "偏高", "還不到高血壓，但要開始注意少鹽、運動、控制體重，定期追蹤。"
    elif s < 90 or d < 60:
        cat, adv = "偏低", "如果沒有不舒服通常不用擔心；有頭暈、快暈倒、心跳很快，要就醫找原因。"
    else:
        cat, adv = "理想", "繼續保持。"
    add("血壓", R.choice([f"血壓{s}/{d}正常嗎？", f"我量到{s}/{d}，要緊嗎？", f"收縮壓{s}、舒張壓{d}算高嗎？"]),
        f"{s}/{d} mmHg 屬於{cat}（台灣 2022 指引：理想是低於 120/80，在家量 130/80 以上就算高血壓）。{adv}"
        "單次測量會受情緒、活動、咖啡影響，要看多次的平均。")
for _ in range(3500):
    if R.random() < 0.6:
        g = R.randint(55, 260)
        if g < 70:
            cat, adv = "低血糖", "吃 15 公克糖再測；常常這樣要就醫檢查。"
        elif g < 100:
            cat, adv = "正常", "維持就好。"
        elif g < 126:
            cat, adv = "糖尿病前期", "這時候改善飲食、運動、減重，很有機會回到正常；建議每年追蹤。"
        else:
            cat, adv = "可能是糖尿病（要另一天再驗一次確認）", "請找新陳代謝科或家醫科，配合糖化血色素確認。"
        add("血糖", R.choice([f"空腹血糖{g}正常嗎？", f"我空腹血糖驗出來{g}，怎麼辦？"]),
            f"空腹血糖 {g} mg/dL 屬於{cat}（標準：低於 70 低血糖、70–99 正常、100–125 前期、126 以上可能是糖尿病）。{adv}")
    else:
        a1 = R.randint(45, 120) / 10
        if a1 < 5.7:
            cat = "正常"
        elif a1 < 6.5:
            cat = "糖尿病前期"
        else:
            cat = "達到糖尿病的標準（要醫師確認）"
        tgt = "已經是糖尿病的人，一般控制目標是 7% 以下（長者可放寬）。" if a1 >= 6.5 else ""
        add("血糖", R.choice([f"糖化血色素{a1}%是什麼意思？", f"HbA1c {a1} 正常嗎？"]),
            f"糖化血色素反映過去約三個月的平均血糖。{a1}% 屬於{cat}（低於 5.7% 正常、5.7–6.4% 前期、6.5% 以上糖尿病）。{tgt}")
for _ in range(3500):
    t = R.choice([x / 10 for x in range(355, 415)])
    who, kind = R.choice(WHO)
    if t < 37.5:
        cat = "沒有發燒"
    elif t < 38:
        cat = "體溫稍高（還不算發燒）"
    elif t < 39:
        cat = "發燒"
    elif t < 40:
        cat = "高燒"
    else:
        cat = "非常高的高燒"
    urgent = (kind == "infant" and t >= 38) or t >= 40
    add("體溫", R.choice([f"{who or '我'}耳溫{t}度，要看醫生嗎？", f"{who or '我'}體溫{t}度算發燒嗎？"]),
        f"耳溫 {t}°C 屬於{cat}（耳溫或口溫 38°C 以上算發燒）。"
        + ("這個情況要立刻就醫。" if urgent else ("可以多喝水、休息、穿透氣衣物；不舒服可以用退燒藥。重點看精神和活動力，" if t >= 38 else "可以再觀察，"))
        + ("" if urgent else "燒超過三天、精神很差、呼吸喘、抽搐或出疹，就要就醫。") + EXTRA.get(kind, ""))
for _ in range(2500):
    w = R.randint(15, 120)
    ml = w * 30
    add("喝水", R.choice([f"體重{w}公斤一天要喝多少水？", f"我{w}公斤，水要喝多少？"]),
        f"一般建議每公斤體重約 30 毫升：{w} × 30 = {ml} 毫升，約 {ml / 250:.0f} 杯（一杯 250 毫升）。天氣熱、運動、發燒要再多；"
        "有腎臟病、心臟衰竭的人要照醫師的限水建議。")
for _ in range(5000):
    male = R.random() < 0.5
    age = R.randint(18, 80)
    h = R.randint(150, 192) if male else R.randint(145, 180)
    w = R.randint(45, 120)
    bmr = 10 * w + 6.25 * h - 5 * age + (5 if male else -161)
    lvl, f = R.choice([("幾乎不運動", 1.2), ("每週運動 1–3 天", 1.375), ("每週運動 3–5 天", 1.55), ("每週運動 6–7 天", 1.725)])
    tdee = bmr * f
    add("熱量", f"我{'男' if male else '女'}生，{age}歲，{h}公分，{w}公斤，{lvl}，一天需要多少熱量？",
        f"用 Mifflin-St Jeor 公式估算基礎代謝率：10×{w} + 6.25×{h} − 5×{age} {'+ 5' if male else '− 161'} = {bmr:.0f} 大卡；"
        f"乘上活動係數 {f}，每天大約需要 {tdee:.0f} 大卡。想減重可以每天少吃約 300–500 大卡，"
        f"但{'男性' if male else '女性'}不要長期低於 {1500 if male else 1200} 大卡，以免營養不足。這是估算，實際因人而異。")

# ─────────── 衛教問答、器官 ───────────
for q, a in QA:
    for v in range(12):
        who, kind = R.choice(WHO)
        qq = q if v == 0 else R.choice([q, f"想問一下，{q}", f"{q}拜託告訴我", f"{who}想知道：{q}" if who else q, f"{q}詳細一點"])
        add("衛教", qq, a + EXTRA.get(kind, ""))
for organ, fn, dept in ORGANS:
    for v in range(8):
        add("器官", R.choice([f"{organ}的功能是什麼？", f"{organ}是做什麼的？", f"{organ}不好要看哪科？", f"{organ}在身體裡負責什麼？"]),
            f"{organ}負責{fn}。{organ}有問題可以看{dept}。")

# 一模一樣的題目只留一份（不灌水）
seen = set()
out = [it for it in out if not ((it["q"], it["a"]) in seen or seen.add((it["q"], it["a"])))]
R.shuffle(out)
total = 0
with open(sys.argv[1], "w", encoding="utf-8") as f:
    for i, it in enumerate(out):
        it["id"] = f"medical-{i:06d}"
        total += len(it["q"]) + len(it["a"])
        f.write(json.dumps(it, ensure_ascii=False) + "\n")
print(len(out), "題，", total, "字")
