# -*- coding: utf-8 -*-
"""寫作訓練題（500,000 題）：
  expand：擴寫（中英西義），「擴寫：樹在成長」「Expand: The tree is growing.」——至少原句的 9 倍長（中文算字，英西義算單字），
          要有環境、感受、觀點、比喻、成語／諺語，提到主角，不混其他語言、不重複
  detail：詳寫人物的情緒和動作（「小明哭了，請詳寫」）——還要有高級詞，不能有衝突的情緒（哭的時候不能「興高采烈」）
  polish：修改一段寫得平淡的文字（「幫我修改這段：小明哭了。小明很傷心。」）
  none：不是要寫作（「描寫是什麼意思」「小明哭了」）
驗證題（--holdout）：沒看過的主角、動作、人名、問法——檢查是真的會寫，不是背題目。
用法：python3 ai/writing/gen.py 輸出.json [--holdout] [--n 500000]"""
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import expand as X  # noqa: E402
import lexicon as L  # noqa: E402

HOLD = "--holdout" in sys.argv
N = int(sys.argv[sys.argv.index("--n") + 1]) if "--n" in sys.argv else (20000 if HOLD else 500000)
R = random.Random(131 if HOLD else 113)
LI = {"zh": 0, "en": 1, "es": 2, "it": 3}

# 句子前面的時間、地點（讓題目更多樣）
PRE = {"zh": ["", "", "清晨，", "雨後，", "夜裡，", "春天裡，", "今天，", "不知不覺中，", "在陽光下，", "傍晚時分，"],
       "en": ["", "", "In the morning, ", "After the rain, ", "At night, ", "In spring, ", "Today, ", "Quietly, ", "In the sunlight, ", "At dusk, "],
       "es": ["", "", "Por la mañana, ", "Después de la lluvia, ", "De noche, ", "En primavera, ", "Hoy, ", "En silencio, ", "Bajo el sol, ", "Al atardecer, "],
       "it": ["", "", "Al mattino, ", "Dopo la pioggia, ", "Di notte, ", "In primavera, ", "Oggi, ", "In silenzio, ", "Sotto il sole, ", "Al tramonto, "]}
# 句子後面的補充（只給英西義，讓題目更多樣）
POST = {"en": ["", "", " today", " again", " in the quiet morning", " under the blue sky", " once more", " in the evening light"],
        "es": ["", "", " hoy", " otra vez", " en la mañana tranquila", " bajo el cielo azul", " una vez más", " con la luz de la tarde"],
        "it": ["", "", " oggi", " di nuovo", " nel mattino tranquillo", " sotto il cielo azzurro", " ancora una volta", " nella luce della sera"]}
MORE_ASK = {"en": ["Expand this sentence: {O}.", "Please expand: {O}.", "Expand into a paragraph: {O}.", "Develop this sentence: {O}.", "Elaborate on this: {O}."],
            "es": ["Amplía esta frase: {O}.", "Por favor, amplía: {O}.", "Desarrolla: {O}.", "Escribe un párrafo sobre esto: {O}!", "Amplía, por favor: {O}."],
            "it": ["Espandi questa frase: {O}.", "Per favore, espandi: {O}.", "Sviluppa: {O}.", "Scrivi un paragrafo su questo: {O}!", "Espandi, per favore: {O}."]}
DETAIL_PRE = ["", "", "", "今天，", "那天，", "放學後，", "昨天晚上，", "週末，", "下課的時候，", "回到家，"]
if HOLD:
    POST = {"en": ["", " at last"], "es": ["", " por fin"], "it": ["", " finalmente"]}
    DETAIL_PRE = ["", "那一刻，"]
if HOLD:
    PRE = {"zh": ["", "冬日裡，"], "en": ["", "In winter, "], "es": ["", "En invierno, "], "it": ["", "D'inverno, "]}
WRAP = ["", "", "", "作業：", "老師出的題目：", "考考你，"] if not HOLD else ["", "題目："]

NAMES = ["小明", "小美", "小華", "媽媽", "爸爸", "奶奶", "爺爺", "老師", "弟弟", "妹妹", "哥哥", "姊姊", "我", "他", "她", "小玲", "阿明", "小強"]
HOLD_NAMES = ["小芳", "阿傑", "外公", "陳大文", "小宇"]
EVENTS = {
    "sad": ["哭了", "哭得很傷心", "掉眼淚了", "偷偷地哭了", "考試考砸了，哭了", "被老師罵了，很難過", "失戀了，很傷心", "難過得說不出話", "委屈地哭了"],
    "happy": ["笑了", "開心地笑了", "考了一百分，好開心", "收到禮物，很高興", "得獎了", "贏了比賽，開心得跳起來", "笑得好開心"],
    "angry": ["生氣了", "發脾氣了", "氣炸了", "跟朋友吵架了", "氣得說不出話"],
    "scared": ["害怕了", "被嚇到了", "做惡夢了", "怕黑", "嚇得發抖"],
    "nervous": ["要上台表演，很緊張", "面試前很緊張", "比賽前好緊張", "要演講了", "緊張得手心冒汗"],
    "moved": ["感動得哭了", "收到一封信，很感動", "和家人團聚了", "熱淚盈眶"],
    "lonely": ["一個人在家，很孤單", "好寂寞", "想家了", "很孤獨"],
    "tired": ["很累", "加班到深夜，累壞了", "累得睡著了"],
    "surprised": ["嚇了一跳", "愣住了", "驚訝得說不出話", "收到驚喜"],
    "shy": ["害羞了", "臉紅了", "被稱讚，不好意思地笑了"],
    "regret": ["後悔了", "說錯話，好後悔", "做錯事，很懊悔"],
    "excited": ["明天要去旅行，好期待", "迫不及待想出國", "要去遊樂園了"],
    "run": ["在操場上跑步", "參加賽跑", "跑馬拉松", "在接力賽裡衝刺"],
    "study": ["在讀書", "認真寫作業", "準備考試", "在圖書館看書"],
    "eat": ["吃晚餐", "吃媽媽做的菜", "在夜市吃小吃", "喝了一碗熱湯"],
    "sleep": ["睡著了", "在午睡", "打瞌睡", "做了一個好夢"],
    "sing": ["在唱歌", "在台上唱歌", "彈鋼琴", "參加合唱比賽"],
    "walk": ["在公園散步", "走在回家的路上", "在海邊漫步", "去逛街"],
    "wait": ["在車站等人", "等公車", "在等一個消息"],
}
HOLD_EVENTS = {"sad": ["掉下了眼淚", "忍不住落淚"], "happy": ["哈哈大笑", "高興極了"], "angry": ["發起了脾氣"], "scared": ["嚇壞了"],
               "moved": ["被同學的話感動了"], "tired": ["累壞了"], "run": ["跑完了一千公尺"], "study": ["專心地做功課"], "sing": ["拉小提琴"]}
SCENES = {"rain": ["下雨天", "下雨了", "一場大雨", "窗外的雨"], "snow": ["下雪了", "雪景", "第一場雪"], "sunset": ["夕陽", "黃昏的海邊", "美麗的晚霞"],
          "night": ["夜晚的星空", "月亮", "安靜的夜晚"]}
HOLD_SCENES = {"rain": ["雷陣雨"], "snow": ["漫天飛雪"], "sunset": ["日落時分"], "night": ["滿天星斗的夜"]}
DETAIL_ASK = ["{c}，請詳寫", "請把「{c}」寫得更生動", "用優美的文字描寫{c}", "{c}，幫我詳寫", "詳寫「{c}」", "{c}，寫得生動一點", "描寫{c}",
              "把{c}寫得感人一點", "詳寫：{c}", "{c}。請詳細描寫", "請用優美的句子寫{c}", "{c}，用高級的詞寫一段"]
HOLD_DETAIL_ASK = ["請用生動的筆觸描寫{c}", "把{c}寫成一段優美的文字", "{c}，寫得有畫面一點", "{c}，請寫得富有感情"]
POLISH_ASK = ["幫我修改這段：{d}", "潤飾一下：{d}", "{d}幫我改得更好", "請幫我把這段寫得更好：{d}", "改寫：{d}", "修改一下這段話：{d}"]
HOLD_POLISH_ASK = ["這段寫得不好，幫我修改：{d}", "{d}可以怎麼改"]
NONE = ["小明哭了", "我好難過", "怎麼寫好作文", "描寫是什麼意思", "擴寫和縮寫有什麼不同", "寫作業好累", "我寫完報告了", "詳寫的英文怎麼說",
        "什麼是修辭法", "樹在成長", "the tree is growing", "老師要我們擴寫，怎麼辦", "我不會寫作文", "下雨了"] if not HOLD else ["擴寫要注意什麼", "作文怎麼寫才會高分"]


def units(s, lang):
    if lang == "zh":
        return sum(1 for ch in s if "一" <= ch <= "鿿")
    return len([w for w in s.split() if any(c.isalnum() for c in w)])


def cap(s):
    return s[0].upper() + s[1:] if s else s


def expand_item():
    lang = R.choice(["zh", "zh", "en", "es", "it"])
    li = LI[lang]
    subj = HOLD_SUBJ = X.HOLD_SUBJ if HOLD else None
    sc = R.choice(list(X.COMBOS))
    pool_s = X.SUBJ[sc] + (X.HOLD_SUBJ[sc] if HOLD else [])
    s = R.choice(X.HOLD_SUBJ[sc]) if HOLD and R.random() < 0.6 else R.choice(pool_s)
    pc = R.choice(X.COMBOS[sc])
    preds = [p for p in X.PRED[pc] + (X.HOLD_PRED.get(pc, []) if HOLD else []) if p[4] is None or sc in p[4]]
    if HOLD and R.random() < 0.5:
        preds = [p for p in X.HOLD_PRED.get(pc, []) if p[4] is None or sc in p[4]] or preds
    if not preds:
        return None
    p = R.choice(preds)
    sw, pw = s[li], p[li]
    if lang == "zh":
        o = R.choice(PRE["zh"]) + sw + pw
        q = R.choice(WRAP) + R.choice(X.ASK["zh"] if not HOLD else X.HOLD_ASK["zh"] + X.ASK["zh"][:2]).format(O=o)
        subject = sw
    else:
        pre = R.choice(PRE[lang])
        o = ((pre + sw + " " + pw) if pre else cap(sw) + " " + pw) + R.choice(POST[lang])
        q = R.choice(X.ASK[lang] + MORE_ASK[lang] if not HOLD else X.HOLD_ASK[lang] + X.ASK[lang][:1]).format(O=o)
        subject = sw
    return {"q": q, "kind": "expand", "lang": lang, "original": o, "subject": subject, "cat": sc + "/" + pc, "min": 9 * units(o, lang)}


def detail_item():
    if R.random() < 0.15:
        sc = R.choice(list(SCENES))
        c = R.choice(SCENES[sc] + (HOLD_SCENES[sc] if HOLD else []))
        q = R.choice(WRAP) + R.choice(DETAIL_ASK if not HOLD else HOLD_DETAIL_ASK).format(c=c)
        return {"q": q, "kind": "detail", "lang": "zh", "original": c, "subject": "", "cat": sc, "min": 9 * units(c, "zh")}
    cat = R.choice(list(EVENTS))
    evs = EVENTS[cat] + (HOLD_EVENTS.get(cat, []) if HOLD else [])
    e = R.choice(evs)
    n = R.choice(HOLD_NAMES if HOLD and R.random() < 0.6 else NAMES)
    c = R.choice(DETAIL_PRE) + n + e
    q = R.choice(WRAP) + R.choice(DETAIL_ASK if not HOLD else HOLD_DETAIL_ASK).format(c=c)
    return {"q": q, "kind": "detail", "lang": "zh", "original": c, "subject": n, "cat": cat, "min": 9 * units(c, "zh")}


def polish_item():
    cat = R.choice(list(EVENTS))
    e = R.choice(EVENTS[cat])
    n = R.choice(HOLD_NAMES if HOLD else NAMES)
    plain = L.CATS[cat]["plain"]
    d = R.choice(["{n}{e}。{n}很{p}。", "{n}{e}。{n}真的很{p}。", "{n}{e}，{n}很{p}。", "今天{n}{e}。{n}覺得很{p}。"]).format(n=n, e=e, p=plain)
    q = R.choice(POLISH_ASK if not HOLD else HOLD_POLISH_ASK).format(d=d)
    return {"q": q, "kind": "polish", "lang": "zh", "original": d, "subject": n, "cat": cat, "min": max(9 * units(d, "zh"), 80)}


QUOTA = {"expand": 0.62, "detail": 0.27, "polish": 0.08, "none": 0.03}


def one(kind):
    if kind == "none":
        return {"q": R.choice(WRAP) + R.choice(NONE) + R.choice(["", "？", "。", "呢"]), "kind": "none", "lang": "", "original": "", "subject": "", "cat": "", "min": 0}
    return {"expand": expand_item, "detail": detail_item, "polish": polish_item}[kind]()


def main(dst):
    out, seen, tries = [], {}, 0
    count = {k: 0 for k in QUOTA}
    while len(out) < N and tries < N * 30:
        tries += 1
        kind = R.choices(list(QUOTA), list(QUOTA.values()))[0]
        if count[kind] >= QUOTA[kind] * N * 1.02:
            continue
        it = one(kind)
        if not it:
            continue
        k = it["q"]
        # 不是寫作的題目很少，允許重複；其他的不重複
        if it["kind"] != "none" and k in seen:
            continue
        count[kind] += 1
        seen[k] = 1
        it["elevated"] = L.CATS[it["cat"]]["elevated"] if it["kind"] in ("detail", "polish") else []
        it["avoid"] = L.CATS[it["cat"]]["avoid"] if it["kind"] in ("detail", "polish") else []
        out.append(it)
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    from collections import Counter
    print(len(out), Counter(x["kind"] for x in out), Counter(x["lang"] for x in out))


if __name__ == "__main__":
    main(sys.argv[1])
