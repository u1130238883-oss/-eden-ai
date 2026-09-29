# -*- coding: utf-8 -*-
"""
NineSun 的「命理認知」訓練資料：把九型十二宮體系教進 Transformer。

兩種樣本：
  1) 知識型（無事實框）：「5宮是什麼」「第3型是什麼」「好7因3什麼意思」…
       <u>問題<a>回答<eos>
  2) 推算型（有事實框）：App 內的九型十二宮引擎先算出結果，寫成事實框 <f>，
     模型學會「讀懂」事實框並用白話解讀。
       <u>今年運勢怎樣<f>流年|2026|8宮壞9因2|引3,9<a>今年落在8宮「偏財」…<eos>

事實框格式（Swift 端 FortuneRouter 產生完全相同的字串）：
  今日|日{日宮}|夜{夜宮}
  流月|{月}月|{row}
  流年|{年}|{row}|引{引動宮,...}        （無引動則省略 |引…）
  大運|{起}-{迄}|{row}
  命盤|命{命宮}|型{型}|{row0}
  九型|{型}
  合盤|命{命宮}|好{n}正{n}壞{n}
  生日|命{命宮}|型{型}
  無生日
其中 {row} 形如「8宮壞9因2」。
"""
import random

import ninetwelve as nt

P_NAME = nt.PALACE_NAMES
P_KW = nt.PALACE_KEYWORDS


def kw(p, n=3):
    """宮位的前 n 個關鍵詞（排除簡稱本身）——固定取法，讓模型好學。"""
    name = P_NAME[p - 1]
    return "、".join([k for k in P_KW[p - 1] if k != name][:n])


def pn(p):
    return f"{p}宮「{P_NAME[p - 1]}」"


VERDICT_PHRASE = {
    nt.GOOD: ["整體順勢，有助力", "是好的組合，順水推舟", "運勢偏順，可以積極一點"],
    nt.NEUTRAL: ["持平穩定，照常發揮就好", "不好不壞，穩穩走", "中性平穩，重點在自己怎麼做"],
    nt.BAD: ["有阻力，要多留意", "會有些摩擦，放慢腳步", "偏不順，凡事多想一步"],
}


def row_explain(row, label, rng):
    r = row.reading
    v = nt.VERDICTS[r.verdict]
    head = rng.choice([
        f"{label}落在{pn(row.palace)}，判讀「{v}{r.result}因{r.cause}」：{rng.choice(VERDICT_PHRASE[r.verdict])}。",
        f"{label}是{pn(row.palace)}，{v}{r.result}因{r.cause}，{rng.choice(VERDICT_PHRASE[r.verdict])}。",
    ])
    tail = f"果在{pn(r.result)}：{kw(r.result)}；因在{pn(r.cause)}：{kw(r.cause)}。"
    return head + tail


def rand_birth(rng):
    return rng.randint(1950, 2015), rng.randint(1, 12), rng.randint(1, 28)


# ------------------------------------------------------------ 推算型
Q_DAY = ["今天運勢", "今天運勢怎樣", "今日運勢", "今天的運勢如何", "幫我看今天運勢", "今天運氣如何", "日宮夜宮"]
Q_MONTH = ["這個月運勢", "本月運勢", "這個月怎麼樣", "流月", "幫我看這個月", "月運"]
Q_YEAR = ["今年運勢", "今年運勢怎樣", "流年", "幫我看今年", "我的流年", "今年運氣如何", "年運"]
Q_LUCK = ["我的大運", "大運", "這幾年的大運", "幫我看大運", "十年大運"]
Q_NATAL = ["我的命盤", "幫我排命盤", "看我的命盤", "我的命宮", "本命盤"]
Q_TYPE = ["我是幾型", "我是什麼型", "我的九型", "我的性格", "我的人格類型"]
Q_SYN = ["我跟{d}的人合不合", "合盤{d}", "我和{d}生的人配不配", "幫我跟{d}合盤"]
Q_BDAY = ["我的生日是{d}", "我生日{d}", "生日{d}", "記住我的生日{d}"]
Q_ANY = Q_DAY + Q_MONTH + Q_YEAR + Q_LUCK + Q_NATAL + Q_TYPE


def fmt_date(y, m, d, rng):
    return rng.choice([f"{y}年{m}月{d}日", f"{y}-{m}-{d}", f"{y}/{m}/{d}"])


def grounded_samples(rng):
    out = []
    y, m, d = rand_birth(rng)
    D = nt.Destiny(y, m, d)
    qy = rng.randint(2020, 2032)
    qm = rng.randint(1, 12)
    qd = rng.randint(1, 28)

    # 今日
    dp, np_ = D.day(qm, qd)
    frame = f"今日|日{dp}|夜{np_}"
    ans = rng.choice([
        f"今天的日宮是{pn(dp)}，關鍵字：{kw(dp)}。晚上走到{pn(np_)}，留意{kw(np_, 2)}。",
        f"今日訊號：白天{pn(dp)}，重點是{kw(dp)}；夜裡轉到{pn(np_)}，多注意{kw(np_, 2)}。",
    ])
    out.append((rng.choice(Q_DAY), frame, ans))

    # 流月
    row = D.month(qm, qy)
    frame = f"流月|{qm}月|{row.text}"
    out.append((rng.choice(Q_MONTH), frame, row_explain(row, f"{qm}月", rng)))

    # 流年（含引動）
    row = D.year(qy)
    trig = D.triggered_aspects(qy)
    frame = f"流年|{qy}|{row.text}"
    ans = row_explain(row, f"{qy}年", rng)
    if trig:
        ps = [a.palace for a in trig][:3]
        frame += "|引" + ",".join(str(p) for p in ps)
        ans += "今年會引動大運的" + "、".join(f"{p}宮" for p in ps) + "。"
    out.append((rng.choice(Q_YEAR), frame, ans))

    # 大運
    s, e, row = D.luck_period(qy)
    frame = f"大運|{s}-{e}|{row.text}"
    out.append((rng.choice(Q_LUCK), frame, row_explain(row, f"{s}到{e}年的大運", rng)))

    # 命盤
    row0 = D.natal[0]
    t = D.type
    frame = f"命盤|命{row0.palace}|型{t}|{row0.text}"
    ans = (f"你的命宮在{pn(row0.palace)}，本命判讀{nt.VERDICTS[row0.reading.verdict]}{row0.reading.result}"
           f"因{row0.reading.cause}。命宮關鍵字：{kw(row0.palace)}。九型是第{t}型「{nt.TYPE_NAMES[t - 1]}」。")
    out.append((rng.choice(Q_NATAL), frame, ans))

    # 九型
    frame = f"九型|{t}"
    ans = rng.choice([
        f"你是第{t}型「{nt.TYPE_NAMES[t - 1]}」：{nt.TYPE_TAGLINES[t - 1]}。",
        f"依你的靈數，你屬於第{t}型「{nt.TYPE_NAMES[t - 1]}」，特質是{nt.TYPE_TAGLINES[t - 1]}。",
    ])
    out.append((rng.choice(Q_TYPE), frame, ans))

    # 合盤
    oy, om, od = rand_birth(rng)
    life, ch = nt.synastry(D, nt.Destiny(oy, om, od))
    cnt = [sum(1 for r in ch if r.reading.verdict == v) for v in range(3)]
    frame = f"合盤|命{ch[0].palace}|好{cnt[0]}正{cnt[1]}壞{cnt[2]}"
    if cnt[0] > cnt[2]:
        mood = "好的比壞的多，整體合拍！"
    elif cnt[0] < cnt[2]:
        mood = "壞的比較多，相處需要多一點耐心和磨合。"
    else:
        mood = "好壞參半，看你們怎麼經營。"
    ans = (f"你們的合盤命宮在{pn(ch[0].palace)}，重點是{kw(ch[0].palace)}。"
           f"十二宮裡好{cnt[0]}、正{cnt[1]}、壞{cnt[2]}，{mood}")
    out.append((rng.choice(Q_SYN).format(d=fmt_date(oy, om, od, rng)), frame, ans))

    # 設定生日
    frame = f"生日|命{row0.palace}|型{t}"
    ans = rng.choice([
        f"收到，生日已記錄！你的命宮在{pn(row0.palace)}，九型是第{t}型「{nt.TYPE_NAMES[t - 1]}」。想看今天運勢嗎？",
        f"記住了！命宮{pn(row0.palace)}，第{t}型「{nt.TYPE_NAMES[t - 1]}」。隨時問我今年、這個月或今天的運勢。",
    ])
    out.append((rng.choice(Q_BDAY).format(d=fmt_date(y, m, d, rng)), frame, ans))

    # 還沒有生日
    ans = rng.choice([
        "我還不知道你的生日！直接告訴我，例如：我的生日是2000年1月1日。",
        "要先有生日才能推算喔。跟我說「我的生日是2000年1月1日」這樣就可以了。",
    ])
    out.append((rng.choice(Q_ANY), "無生日", ans))
    return out


# ------------------------------------------------------------ 知識型
SECTION_Q = {
    0: ["第{t}型的性格背景", "{t}號怎麼形成的", "第{t}型小時候"],
    1: ["第{t}型的外在表現", "{t}號給人的感覺", "第{t}型平常怎樣"],
    2: ["第{t}型放鬆時", "{t}號安定的時候", "第{t}型成長時會怎樣"],
    3: ["第{t}型壓力大時", "{t}號壓力下會怎樣", "第{t}型自我防衛"],
    4: ["第{t}型健康的特點", "{t}號最好的狀態", "第{t}型的優點"],
    5: ["第{t}型一般的特點", "{t}號的一般狀態", "第{t}型的普通表現"],
    6: ["第{t}型不健康的特點", "{t}號最糟的狀態", "第{t}型的缺點"],
}


def clip(s, n=110):
    if len(s) <= n:
        return s
    cut = s[:n]
    k = max(cut.rfind("。"), cut.rfind("，"))
    return (cut[:k] if k > 20 else cut) + "。"


def knowledge_samples(rng):
    out = []
    p = rng.randint(1, 12)
    el = nt.ELEMENT_NAMES[nt.element_of(p)]
    name = P_NAME[p - 1]
    q = rng.choice([f"{p}宮是什麼", f"{p}宮代表什麼", f"第{p}宮", f"{name}宮是什麼", f"{p}宮的意思"])
    out.append((q, None, rng.choice([
        f"{pn(p)}，五行屬{el}，代表：{kw(p, 6)}。",
        f"{p}宮是「{name}」宮，屬{el}。關鍵字有{kw(p, 6)}。",
    ])))
    out.append((rng.choice([f"{p}宮屬什麼", f"{p}宮的五行"]), None, f"{p}宮「{name}」五行屬{el}。"))

    t = rng.randint(1, 9)
    tn = nt.TYPE_NAMES[t - 1]
    q = rng.choice([f"第{t}型是什麼", f"{t}號人格", f"九型{t}號", f"{tn}是什麼型", f"第{t}型"])
    out.append((q, None, f"第{t}型是「{tn}」：{nt.TYPE_TAGLINES[t - 1]}。"))
    q = rng.choice([f"第{t}型的性格", f"{t}號是什麼樣的人", f"介紹第{t}型", f"{tn}的性格"])
    out.append((q, None, clip(nt.TYPE_SUMMARIES[t - 1])))
    s = rng.randrange(7)
    items = nt.TYPE_SECTIONS[t - 1][s]
    out.append((rng.choice(SECTION_Q[s]).format(t=t), None, clip(rng.choice(items))))

    # 判讀記號
    v = rng.randrange(3)
    a, b = rng.randint(1, 12), rng.randint(1, 12)
    vn = nt.VERDICTS[v]
    out.append((rng.choice([f"{vn}{a}因{b}是什麼意思", f"{vn}{a}因{b}", f"什麼是{vn}{a}因{b}"]), None,
                f"「{vn}{a}因{b}」是{vn}的判讀：結果落在{pn(a)}，起因在{pn(b)}。{rng.choice(VERDICT_PHRASE[v])}。"))
    return out


STATIC_KNOWLEDGE = [
    (["什麼是九型十二宮", "九型十二宮是什麼", "你的命理系統", "你怎麼算命的", "算命原理"],
     ["九型十二宮把出生年、月、日各化成一柱，三柱相加得出靈數：靈數決定九型人格，也決定命宮，再由命宮逆排十二宮。",
      "先把生日化約成三柱，三柱相加得靈數，對應九型人格；再從命宮逆排十二宮，用五行生剋判讀好、正、壞。"]),
    (["你會算命嗎", "可以幫我算命嗎", "你懂命理嗎", "幫我算命", "算命"],
     ["會！我內建九型十二宮、八字、紫微斗數和易經起卦。先告訴我生日和出生時辰就能開始。",
      "當然！九型十二宮、八字、紫微、算卦都是我的底層系統。先跟我說生日，例如：我的生日是2000年1月1日。"]),
    (["什麼是流年", "流年是什麼"], ["流年是某一年落在你本命盤的哪一宮，代表那一年的主題。"]),
    (["什麼是大運", "大運是什麼"], ["大運是九年一段的長期運勢，第一段從出生年開始，之後每九年換一段。"]),
    (["什麼是流月", "流月是什麼"], ["流月由大運三柱加流年三柱，從流年宮位前一宮起排，看每個月的主題。"]),
    (["什麼是合盤", "合盤是什麼"], ["合盤是把兩個人的三柱相加，重新排一張十二宮，看兩人之間好、正、壞各有多少。"]),
    (["什麼是命宮", "命宮是什麼"], ["命宮就是你的靈數所在的宮位，是本命盤的起點，代表你最核心的課題。"]),
    (["什麼是引動", "引動是什麼"], ["引動是流年或大運的宮位，剛好是某一宮的果或因，那一宮的事就會被帶起來。"]),
    (["什麼是日宮", "日宮是什麼", "夜宮是什麼", "什麼是夜宮"], ["日宮看白天的主題，夜宮看晚上要留意的事，由靈數和當天日期推出。"]),
    (["好正壞是什麼", "好正壞是什麼意思", "什麼是好正壞"],
     ["年柱和月柱的五行相生就是好，同一個五行是正，相剋就是壞。"]),
    (["果和因是什麼", "什麼是果因", "果因是什麼意思"],
     ["「好7因3」裡，7是果、3是因：事情的結果表現在7宮，起因來自3宮。"]),
    (["五行相生", "什麼是相生"], ["金生水、水生木、木生火、火生土、土生金。"]),
    (["五行相剋", "什麼是相剋"], ["金剋木、木剋土、土剋水、水剋火、火剋金。"]),
    (["十二宮有哪些", "十二宮是什麼"],
     ["1自我、2物質、3交流、4家庭、5桃花、6勞碌、7他人、8偏財、9愉悅、10事業、11朋友、12沉迷。"]),
    (["九型有哪些", "九型人格有哪些"],
     ["1完美主義者、2熱心助人者、3成就至上者、4浪漫藝術者、5格物致知者、6謹慎忠誠者、7享樂主義者、8天生領導者、9和平主義者。"]),
    (["算命準嗎", "這個準嗎", "我該相信算命嗎"],
     ["命理是參考和提醒，不是定論。真正決定結果的還是你自己的選擇！"]),
]


def fortune_pairs(rng, n_grounded=6, n_knowledge=10):
    out = []
    for _ in range(n_grounded):
        out += grounded_samples(rng)
    for _ in range(n_knowledge):
        out += knowledge_samples(rng)
    for users, replies in STATIC_KNOWLEDGE:
        out.append((rng.choice(users), None, rng.choice(replies)))
    return out


def fortune_chars():
    chars = set()
    rng = random.Random(0)
    for _ in range(3000):
        for q, f, a in fortune_pairs(rng, 1, 1):
            chars.update(q)
            chars.update(f or "")
            chars.update(a)
    for users, replies in STATIC_KNOWLEDGE:
        for s in users + replies:
            chars.update(s)
    for lst in (nt.TYPE_SUMMARIES,):
        for s in lst:
            chars.update(s)
    for t in nt.TYPE_SECTIONS:
        for sec in t:
            for s in sec:
                chars.update(s)
    for ks in P_KW:
        for k in ks:
            chars.update(k)
    return chars


if __name__ == "__main__":
    rng = random.Random(1)
    for q, f, a in fortune_pairs(rng, 1, 1):
        print(f"<u>{q}" + (f"<f>{f}" if f else "") + f"<a>{a}   [{len(q) + len(f or '') + len(a)}]")
