# -*- coding: utf-8 -*-
"""成語訓練題（每組 500,000 題）：
  understand：看懂跟成語有關的問題在問什麼——問意思、用法、出處、找某種成語、用成語說自己的心情、用成語說自己的毛病（要找改善方法）、
              問近義／反義／翻譯；不是成語的問題不能亂認
  near：成語的近義成語、兩個成語意思一不一樣
  anti：成語的反義成語、兩個成語是不是相反
  translate：成語 → 英／西／義；英／西／義的說法 → 成語；外文 → 另一種外文（透過成語對照）
  voice：個性——405 種不同的命盤（9×9×9 年月互換相同），面對不同心情的話，用不同的語氣，配合適的成語
用法：python3 ai/idioms/gen.py {understand|near|anti|translate|voice} 輸出.json [--holdout] [--n 500000]"""
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "..", "understanding"))
import idioms as I  # noqa: E402

SET = sys.argv[1]
HOLD = "--holdout" in sys.argv
N = int(sys.argv[sys.argv.index("--n") + 1]) if "--n" in sys.argv else (20000 if HOLD else 500000)
R = random.Random({"understand": 1, "near": 2, "anti": 3, "translate": 4, "voice": 5}[SET] * (7 if HOLD else 11))
E = I.entries()
BY = {e["idiom"]: e for e in E}
IDIOMS = [e["idiom"] for e in E]
NEAR = {w: I.near_of(w) for w in IDIOMS}
ANTI = {w: I.anti_of(w) for w in IDIOMS}
UNKNOWN = ["狐假虎威", "守望相助", "杯水車薪", "唇亡齒寒", "夜郎自大", "望梅止渴", "葉公好龍", "南轅北轍"] if not HOLD else ["朝三暮四", "愚公移山", "濫竽充數"]

# 問法的包裝：開頭（客套話、情境）× 結尾（語氣詞、標點）
PRE = (["", "", "", "請問", "我想知道", "想問一下", "欸，", "對了，", "嗯，", "那個", "可以告訴我", "幫我查一下", "考考你，", "突然想到，",
        "老師上課說到", "我在書上看到", "我兒子問我", "朋友問我", "好奇", "說真的，", "問你喔，", "有個問題：", "今天作文要用，", "所以"]
       if not HOLD else ["", "", "麻煩告訴我", "我妹問我", "看小說看到", "跟你請教，"])
POST = (["", "", "？", "?", "呢", "啊", "呀", "～", "…", "！", "？謝謝", "，快告訴我", "，我不太懂"] if not HOLD else ["", "？", "耶", "，拜託"])


def wrap(q):
    return R.choice(PRE) + q + R.choice(POST)


# 說自己的心情時，成語代表的心情（Affect.Mood）
SELF_MOOD = {}
for ws, m in [("心花怒放 喜出望外 歡天喜地 興高采烈 眉開眼笑 笑逐顏開 樂不可支 欣喜若狂 如釋重負", "happy"),
              ("悶悶不樂 心灰意冷 垂頭喪氣 愁眉苦臉 傷心欲絕 痛哭流涕 心如刀割", "sad"),
              ("怒髮衝冠 火冒三丈 暴跳如雷 怒不可遏 氣急敗壞", "angry"),
              ("驚慌失措 坐立不安 忐忑不安 提心吊膽 憂心忡忡", "anxious"),
              ("膽戰心驚 毛骨悚然", "scared"),
              ("孤苦伶仃 形單影隻", "lonely"),
              ("精疲力盡 筋疲力竭 身心俱疲", "tired"),
              ("百無聊賴", "bored"),
              ("後悔莫及", "regret"),
              ("力不從心 束手無策 一籌莫展 功虧一簣 一敗塗地 名落孫山 前功盡棄", "frustrated")]:
    for w in ws.split():
        SELF_MOOD[w] = m
# 說自己的毛病（要找改善的方法）
PROBLEM = ("三天打魚兩天曬網 一曝十寒 半途而廢 虎頭蛇尾 臨時抱佛腳 好吃懶做 好高騖遠 眼高手低 紙上談兵 言而無信 出爾反爾 三心二意 心不在焉 "
           "漫不經心 粗心大意 馬馬虎虎 猶豫不決 舉棋不定 優柔寡斷 拐彎抹角 長篇大論 一擲千金 揮金如土 遊手好閒 斤斤計較 小肚雞腸 驕傲自滿 "
           "妄自菲薄 畏首畏尾 膽小如鼠 大驚小怪 小題大作 杞人憂天 疑神疑鬼 自暴自棄 墨守成規 信口開河 手忙腳亂 臨陣磨槍").split()
# 找某一類的成語：主題 → 語氣或意思裡的字
THEMES = {"開心": ("tone", "開心"), "高興": ("tone", "開心"), "快樂": ("tone", "開心"), "難過": ("tone", "難過"), "傷心": ("tone", "難過"),
          "生氣": ("tone", "生氣"), "憤怒": ("tone", "生氣"), "努力": ("tone", "努力"), "冷靜": ("tone", "冷靜"), "感謝": ("tone", "感謝"),
          "感恩": ("tone", "感謝"), "祝福": ("tone", "祝福"), "稱讚": ("tone", "稱讚"), "讚美": ("tone", "稱讚"), "驚訝": ("tone", "驚訝"),
          "擔心": ("tone", "擔心"), "謙虛": ("tone", "謙虛"), "鼓勵": ("tone", "鼓勵"), "安慰": ("tone", "安慰"), "堅持": ("mean", "堅持"),
          "時間": ("mean", "時間"), "說話": ("mean", "說"), "害怕": ("mean", "害怕"), "團結": ("mean", "一起"), "機會": ("mean", "機會"),
          "安靜": ("mean", "安靜"), "很多人": ("mean", "人非常多"), "容易": ("mean", "容易"), "困難": ("mean", "困難"), "失敗": ("mean", "失敗"),
          "成功": ("mean", "成功"), "專心": ("mean", "專"), "小心": ("mean", "小心"), "後悔": ("mean", "後悔"), "孤單": ("mean", "孤單")}
if HOLD:
    THEMES = {k: v for k, v in THEMES.items() if k in ("快樂", "憤怒", "感恩", "讚美", "堅持", "說話", "機會", "成功", "孤單", "專心")}


def theme_idioms(t):
    kind, v = THEMES[t]
    return [e["idiom"] for e in E if (v in e["tones"] if kind == "tone" else v in e["meaning"])]


T = {
    "meaning": (["{X}是什麼意思", "{X}的意思", "{X}的意思是什麼", "解釋一下{X}", "{X}指的是什麼", "什麼叫{X}", "{X}怎麼解釋", "「{X}」是什麼意思",
                 "成語{X}是什麼意思", "{X}這個成語的意思", "請解釋{X}", "{X}什麼意思", "{X}是啥意思"]
                if not HOLD else ["{X}的含義", "{X}這句成語怎麼解釋", "{X}代表什麼意思", "可以解釋{X}嗎", "{X}的涵義是什麼"]),
    "usage": (["{X}怎麼用", "{X}要怎麼用", "{X}可以用在什麼時候", "{X}用在什麼情況", "{X}怎麼造句", "用{X}造句"]
              if not HOLD else ["{X}的用法", "{X}適合用在哪裡"]),
    "origin": (["{X}的出處", "{X}的典故是什麼", "{X}出自哪裡", "{X}的由來", "{X}的成語故事"] if not HOLD else ["{X}的典故", "{X}出自哪本書"]),
    "theme": (["形容{T}的成語", "有哪些成語是形容{T}的", "關於{T}的成語有哪些", "跟{T}有關的成語", "{T}的成語有哪些", "有什麼成語可以形容{T}"]
              if not HOLD else ["描述{T}的成語", "哪些成語跟{T}有關"]),
    "feeling": (["{T}我{D}{X}", "{T}{D}{X}的", "唉，{T}我{D}{X}", "{T}我{D}{X}，不知道怎麼辦", "{T}我真的是{X}了", "{T}整個人{X}",
                 "跟你說，{T}我{D}{X}", "{T}我{D}{X}，好想哭", "{T}我{D}{X}，你懂嗎"]
                if not HOLD else ["{T}整個人都{X}", "我覺得自己{T}{X}"]),
    "problem": (["我做事總是{X}，要怎麼改", "怎麼改掉{X}的毛病", "我老是{X}怎麼辦", "如何避免{X}", "我常常{X}，該怎麼辦", "要怎麼才不會{X}",
                 "我{W}{X}，有什麼方法可以改", "我{W}{X}，要怎麼辦", "怎樣才能不再{X}", "我想改掉{X}的習慣", "{X}的毛病要怎麼改", "我做事{W}{X}，怎麼改善"]
                if not HOLD else ["改善{X}的方法", "我很容易{X}，有什麼辦法", "我{W}{X}，想改掉"]),
    "near": (["{X}的近義成語", "{X}的近義詞", "跟{X}意思差不多的成語", "{X}的同義成語有哪些", "和{X}意思相近的成語", "{X}的近義詞是什麼"]
             if not HOLD else ["{X}的相似成語", "有什麼成語跟{X}意思一樣"]),
    "anti": (["{X}的反義成語", "{X}的反義詞", "跟{X}意思相反的成語", "{X}的相反成語有哪些", "{X}的反義詞是什麼", "和{X}相反的成語"]
             if not HOLD else ["{X}的反面成語", "有什麼成語跟{X}意思相反"]),
    "pairNear": (["{X}和{Y}意思一樣嗎", "{X}跟{Y}是近義詞嗎", "{X}和{Y}意思差不多嗎", "{X}與{Y}是同義成語嗎"] if not HOLD else ["{X}跟{Y}一樣意思嗎"]),
    "pairAnti": (["{X}和{Y}是反義詞嗎", "{X}跟{Y}意思相反嗎", "{X}的反義詞是{Y}嗎", "{X}與{Y}是反義成語嗎"] if not HOLD else ["{X}跟{Y}是相反的意思嗎"]),
}
NEG = ["什麼是人工智慧", "台北101有多高", "誰發明了電燈", "量子力學是什麼", "怎麼煮紅燒肉", "日本的首都在哪", "今天運勢如何", "我好累",
       "推薦一部電影", "成語接龍好玩嗎", "你喜歡成語嗎", "學成語有什麼用", "成語有幾個字", "我的成語不好", "火鍋怎麼煮", "一年有幾天",
       "四季的英文怎麼說", "一點都不好笑", "三個臭皮匠是誰", "我今天吃了三碗飯"] if not HOLD else ["什麼是區塊鏈", "成語比賽怎麼準備", "五月天是誰"]


TIMES = ["", "", "最近", "今天", "這幾天", "剛剛", "昨天", "這陣子", "整個禮拜", "現在"] if not HOLD else ["", "這個月", "早上"]
DEG = ["", "", "真的", "簡直", "完全", "有點", "超級"] if not HOLD else ["", "根本"]
HABIT = ["總是", "老是", "常常", "很容易", "一直", "動不動就"] if not HOLD else ["每次都", "經常"]


def understand():
    k = R.random()
    if k < 0.06:
        return {"q": wrap(R.choice(NEG)), "intent": "none", "idiom": "", "extra": "", "expect": []}
    if k < 0.10:
        x = R.choice(UNKNOWN)
        return {"q": wrap(R.choice(T["meaning"]).format(X=x)), "intent": "meaning", "idiom": x, "extra": "unknown", "expect": []}
    intent = R.choices(["meaning", "usage", "origin", "theme", "feeling", "problem", "near", "anti", "pairNear", "pairAnti"],
                       [26, 6, 6, 10, 16, 14, 7, 7, 4, 4])[0]
    if intent == "theme":
        t = R.choice(list(THEMES))
        return {"q": wrap(R.choice(T["theme"]).format(T=t)), "intent": "theme", "idiom": "", "extra": t, "expect": theme_idioms(t)}
    if intent == "feeling":
        x = R.choice(list(SELF_MOOD))
        q = R.choice(T["feeling"]).format(X=x, T=R.choice(TIMES), D=R.choice(DEG))
        return {"q": q + R.choice(["", "。", "…", "😭", "！", "～"]), "intent": "feeling", "idiom": x, "extra": SELF_MOOD[x], "expect": []}
    if intent == "problem":
        x = R.choice(PROBLEM)
        return {"q": R.choice(["", "", "欸，", "請問", "老實說，"]) + R.choice(T["problem"]).format(X=x, W=R.choice(HABIT)) + R.choice(["", "？", "?", "…"]), "intent": "problem", "idiom": x, "extra": BY[x]["meaning"], "expect": []}
    if intent in ("near", "anti"):
        x = R.choice([w for w in IDIOMS if (NEAR if intent == "near" else ANTI)[w]])
        return {"q": wrap(R.choice(T[intent]).format(X=x)), "intent": intent, "idiom": x, "extra": "", "expect": (NEAR if intent == "near" else ANTI)[x]}
    if intent in ("pairNear", "pairAnti"):
        x = R.choice([w for w in IDIOMS if (NEAR if intent == "pairNear" else ANTI)[w]])
        yes = R.random() < 0.6
        y = R.choice((NEAR if intent == "pairNear" else ANTI)[x]) if yes else R.choice([w for w in IDIOMS if w != x and w not in NEAR[x] and w not in ANTI[x]])
        exp = ("相近" if yes else "不一樣") if intent == "pairNear" else ("對" if yes else "不是")
        return {"q": wrap(R.choice(T[intent]).format(X=x, Y=y)), "intent": intent, "idiom": x, "extra": y, "expect": [exp]}
    x = R.choice(IDIOMS)
    return {"q": wrap(R.choice(T[intent]).format(X=x)), "intent": intent, "idiom": x, "extra": "", "expect": [BY[x]["meaning"]] if intent != "origin" else []}


def near():
    if R.random() < 0.6:
        x = R.choice([w for w in IDIOMS if NEAR[w]])
        return {"q": wrap(R.choice(T["near"]).format(X=x)), "intent": "near", "idiom": x, "extra": "", "expect": NEAR[x]}
    x = R.choice([w for w in IDIOMS if NEAR[w]])
    yes = R.random() < 0.5
    y = R.choice(NEAR[x]) if yes else R.choice([w for w in IDIOMS if w != x and w not in NEAR[x]])
    return {"q": wrap(R.choice(T["pairNear"]).format(X=x, Y=y)), "intent": "pairNear", "idiom": x, "extra": y, "expect": ["相近" if yes else "不一樣"]}


def anti():
    if R.random() < 0.6:
        x = R.choice([w for w in IDIOMS if ANTI[w]])
        return {"q": wrap(R.choice(T["anti"]).format(X=x)), "intent": "anti", "idiom": x, "extra": "", "expect": ANTI[x]}
    x = R.choice([w for w in IDIOMS if ANTI[w]])
    yes = R.random() < 0.5
    y = R.choice(ANTI[x]) if yes else R.choice([w for w in IDIOMS if w != x and w not in ANTI[x]])
    return {"q": wrap(R.choice(T["pairAnti"]).format(X=x, Y=y)), "intent": "pairAnti", "idiom": x, "extra": y, "expect": ["對" if yes else "不是"]}


ZHL = {"en": ["英文", "英語"], "es": ["西班牙文", "西班牙語", "西文"], "it": ["義大利文", "義大利語", "意大利文"]}
ENL = {"en": "English", "es": "Spanish", "it": "Italian", "zh": "Chinese"}
CODE = {"zh": "zh-Hant", "en": "en", "es": "es", "it": "it"}
TO_FOREIGN = (["{X}用{L}怎麼說", "{X}的{L}", "{X}翻成{L}", "成語{X}用{L}怎麼說", "把{X}翻譯成{L}", "{X}的{L}是什麼", "{X}用{L}要怎麼講"]
              if not HOLD else ["{X}換成{L}要怎麼說", "請把{X}翻成{L}"])
TO_FOREIGN_EN = ["how do you say {X} in {L}", "translate {X} to {L}", "what is {X} in {L}"] if not HOLD else ["how can I say {X} in {L}?"]
TO_IDIOM = (["{F}用中文成語怎麼說", "{F}的成語是什麼", "{F}在中文裡是什麼成語", "{F}可以用什麼成語", "「{F}」的中文成語", "{F}對應的成語",
             "what's the Chinese idiom for {F}", "{F}用中文怎麼說", "{F}翻成中文", "{F}的中文"]
            if not HOLD else ["{F}換成成語是哪一個", "Chinese idiom for {F}", "{F}譯成中文"])
FOREIGN_TO_FOREIGN = (["{F}用{L}怎麼說", "{F}翻成{L}", "how do you say {F} in {LE}", "translate {F} to {LE}"] if not HOLD else ["{F}換成{L}要怎麼說"])


TPRE = ["", "", "", "請問", "想問", "欸，", "告訴我", "我想知道", "請問一下", "那"] if not HOLD else ["", "麻煩一下，"]
TPOST = ["", "", "？", "?", "呢", "啊", "～"] if not HOLD else ["", "？"]


def translate():
    e = R.choice(E)
    r = R.random()
    if r < 0.4:
        t = R.choice(["en", "es", "it"])
        if R.random() < 0.8:
            q = R.choice(TPRE) + R.choice(TO_FOREIGN).format(X=e["idiom"], L=R.choice(ZHL[t])) + R.choice(TPOST)
        else:
            q = R.choice(TO_FOREIGN_EN).format(X=e["idiom"], L=ENL[t])
        return {"q": q, "idiom": e["idiom"], "src": "zh", "target": CODE[t], "text": e["idiom"], "expect": e[t]}
    s = R.choice(["en", "es", "it"])
    # 外文只有一個字的（careless、erudito）是一般的詞，不當成語的說法出題
    multi = [x for x in e[s] if len(x.split()) >= 2]
    if not multi:
        return translate()
    f = R.choice(multi)
    if r < 0.8:
        tpl = R.choice(TO_IDIOM)
        q = tpl.format(F=f) if tpl.startswith(("what", "Chinese")) else R.choice(TPRE) + tpl.format(F=f) + R.choice(TPOST)
        return {"q": q, "idiom": e["idiom"], "src": s, "target": "zh-Hant", "text": f, "expect": [e["idiom"]]}
    t = R.choice([l for l in ["en", "es", "it"] if l != s])
    tpl = R.choice(FOREIGN_TO_FOREIGN)
    q = tpl.format(F=f, L=R.choice(ZHL[t]), LE=ENL[t]) if tpl.startswith(("how", "translate")) else R.choice(TPRE) + tpl.format(F=f, L=R.choice(ZHL[t]), LE=ENL[t]) + R.choice(TPOST)
    return {"q": q, "idiom": e["idiom"], "src": s, "target": CODE[t], "text": f, "expect": e[t]}


# 心情 → 可以用的成語語氣、絕對不能用的語氣
ALLOW = {"grief": ["安慰", "難過"], "sick": ["安慰", "祝福"], "worryOther": ["安慰", "祝福"], "goodNews": ["祝福", "稱讚", "開心"],
         "proudEffort": ["稱讚", "努力", "鼓勵"], "excitedPlan": ["開心", "祝福"], "anxious": ["冷靜", "安慰", "鼓勵"], "scared": ["冷靜", "安慰"],
         "angry": ["冷靜"], "complainAI": ["謙虛"], "apology": ["冷靜", "安慰"], "sad": ["安慰", "鼓勵"], "lonely": ["安慰"], "tired": ["安慰"],
         "frustrated": ["鼓勵", "安慰"], "regret": ["安慰"], "thanks": ["謙虛", "感謝"], "praiseAI": ["謙虛"], "affection": ["開心", "感謝"],
         "joke": ["幽默"], "bored": ["幽默", "開心"], "hope": ["祝福"], "farewell": ["祝福"], "curious": ["驚訝"], "happy": ["開心", "祝福"]}
NEGATIVE = {"grief", "sick", "worryOther", "anxious", "scared", "angry", "complainAI", "apology", "sad", "lonely", "tired", "frustrated", "regret"}


def banned(m):
    b = ["批評", "生氣"]
    if m in NEGATIVE:
        b += ["幽默", "開心"]
    else:
        b += ["難過"]
    if m == "grief":
        b += ["鼓勵", "道理", "提醒", "祝福"]
    return b


def voice_items():
    saved = sys.argv
    sys.argv = [saved[0], "/dev/null"] + (["--holdout"] if HOLD else [])
    import importlib.util
    spec = importlib.util.spec_from_file_location("affect_gen", os.path.join(HERE, "..", "affect", "gen.py"))
    A = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(A)
    sys.argv = saved
    pool = []
    for mood, ts in A.T.items():
        if mood in ALLOW:
            pool.append((mood, ts))
    happy = (["我今天心情超好", "今天好開心", "我現在心花怒放", "哈，今天真是開心的一天"] if not HOLD else ["今天特別高興", "我樂不可支"])
    pool.append(("happy", happy))
    fill = {"pet": "狗", "fam": "奶奶", "oth": "我媽", "exam": "大學", "place": "日本", "work": "同事"}
    out, seen = [], set()
    while len(out) < N:
        y, m, d = R.randint(1940, 2015), R.randint(1, 12), R.randint(1, 28)
        mood, ts = R.choice(pool)
        q = R.choice(ts)
        for k, v in fill.items():
            q = q.replace("{" + k + "}", R.choice(getattr(A, {"pet": "PET", "fam": "FAMILY", "oth": "OTHERS", "exam": "EXAMS", "place": "PLACES", "work": "WORK"}[k])))
        key = (y, m, d, q)
        if key in seen:
            continue
        seen.add(key)
        out.append({"y": y, "m": m, "d": d, "q": q, "mood": mood, "allow": ALLOW[mood], "ban": banned(mood)})
    return out


def main(dst):
    if SET == "voice":
        out = voice_items()
    else:
        f = {"understand": understand, "near": near, "anti": anti, "translate": translate}[SET]
        out, seen, tries = [], set(), 0
        while len(out) < N and tries < N * 60:
            tries += 1
            it = f()
            if it["q"] in seen:
                continue
            seen.add(it["q"]); out.append(it)
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    from collections import Counter
    key = {"understand": "intent", "near": "intent", "anti": "intent", "translate": "target", "voice": "mood"}[SET]
    print(SET, len(out), Counter(x[key] for x in out).most_common(12))


if __name__ == "__main__":
    main(sys.argv[2])
