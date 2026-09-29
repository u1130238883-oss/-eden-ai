# -*- coding: utf-8 -*-
"""
九型十二宮認知核心：NineSun 用十二宮「感知」世界。

1. 宮位感知（perceive）：每一句話都先用十二宮詞庫比對，找出被觸動的宮位。
   詞庫 = Hollow App 的十二宮關鍵詞（NineTwelveData）+ 生活用語擴充；使用者也能教它新詞（演化）。
2. 認知框：一般對話也帶事實框「感{宮}|日{日宮}」，模型學會用十二宮的角度回應。
3. NineSun 自己的命盤：生日 2026-09-29（誕生日），靈數、九型、每日日宮都由 Hollow 算法得出。
4. 命主畫像：累積使用者常觸動的宮位（App 端記錄），形成「畫像」框。

Swift 端 PalaceCore.swift 逐字對應 perceive() 與各事實框。
"""
import json
import os
import random

import ninetwelve as nt
from fortune_corpus import kw, pn

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 生活用語擴充（原本的 Hollow 關鍵詞之外）
EXTRA = {
    1: ["生氣", "氣死", "煩", "衝動", "脾氣", "火大", "暴躁", "受傷", "我自己"],
    2: ["錢", "薪水", "吃", "餓", "買", "購物", "存款", "花費", "拉麵", "便當", "晚餐", "午餐", "早餐", "價錢", "存錢", "月光", "欠錢", "房租", "沒錢", "賺錢"],
    3: ["聊天", "說話", "學校", "上課", "讀書", "作業", "考試", "放學", "英文", "講話", "學習"],
    4: ["家", "媽媽", "焦慮", "擔心", "害怕", "不安", "房子", "回家", "家人", "緊張", "爸媽", "父母", "家裡", "我媽", "我爸", "原生家庭", "搬回家"],
    5: ["戀愛", "喜歡", "約會", "可愛", "爸爸", "好玩", "遊戲", "唱歌", "玩", "帥", "漂亮"],
    6: ["累", "忙", "加班", "壓力", "疲倦", "想太多", "雜事", "上班累", "熬夜", "瑣事", "很忙", "好忙", "行程"],
    7: ["男友", "女友", "男朋友", "女朋友", "老公", "老婆", "伴侶", "結婚", "分手", "別人", "對方", "吵架", "冷戰", "另一半", "相處", "婚禮", "離婚", "復合"],
    8: ["孤單", "寂寞", "無聊", "生病", "感冒", "頭痛", "健康", "不舒服", "痛", "身體", "醫院", "住院", "胃痛", "肚子痛", "減肥", "失落感"],
    9: ["開心", "高興", "快樂", "幸運", "旅行", "出國", "旅遊", "運氣", "太棒", "希望", "夢想", "棒"],
    10: ["工作", "上班", "老闆", "主管", "公司", "升職", "面試", "失敗", "困難", "麻煩", "沮喪", "搞砸", "辭職", "離職", "業績", "被罵", "罵我", "報告", "考核", "專案"],
    11: ["朋友", "大家", "搬家", "變化", "改變", "網路", "社群", "群組", "背叛", "絕交", "朋友圈", "聚會"],
    12: ["迷茫", "難過", "傷心", "哭", "失眠", "睡不著", "夢", "幻想", "逃避", "暗戀", "秘密", "命運", "追劇", "迷惘", "沒有方向", "不知道要幹嘛", "想不開", "空虛"],
}


def build_lexicon():
    lex = {}
    for p in range(1, 13):
        words = [w for w in nt.PALACE_KEYWORDS[p - 1] if len(w) >= 2] + EXTRA[p]
        seen, out = set(), []
        for w in words:
            if w not in seen:
                seen.add(w)
                out.append(w)
        lex[p] = out
    return lex


LEXICON = build_lexicon()


def build_foreign_lexicon(L):
    """外語詞庫：Hollow 該語言的十二宮關鍵詞（去掉括號說明、小寫、至少 4 字母）+ 生活用語。"""
    from i18n import NT_I18N
    from i18n_chat import LEXICON_EXTRA
    lex = {}
    for p in range(1, 13):
        words = []
        for k in NT_I18N[L]["keywords"][p - 1]:
            base = k.split("(")[0].strip().lower()
            if len(base) >= 4:
                words.append(base)
        words += LEXICON_EXTRA[L][p]
        seen, out = set(), []
        for w in words:
            if w not in seen:
                seen.add(w)
                out.append(w)
        lex[p] = out
    return lex


LEXICONS = {"zh": LEXICON}
for _L in ("en", "es", "it"):
    LEXICONS[_L] = build_foreign_lexicon(_L)


def perceive(text, lexicon=LEXICON, lang="zh"):
    """回傳被觸動的宮位（1–12）或 None。分數 = 命中詞的字數總和；同分取較小的宮位。外語先轉小寫。"""
    if lang != "zh":
        lexicon = LEXICONS[lang]
        text = text.lower()
    best, best_score = None, 0
    for p in range(1, 13):
        s = sum(len(w) for w in lexicon[p] if w in text)
        if s > best_score:
            best, best_score = p, s
    return best


def chat_frame(p, day=None):
    return f"感{p}" + (f"|日{day}" if day else "")


LENS = [
    "從九型十二宮來看，這是{pn}的事，關鍵在{kw}。",
    "這個訊號落在{pn}：{kw}。",
    "我感應到{pn}的能量：{kw}。",
]


def lens_tail(p, day, rng):
    s = rng.choice(LENS).format(pn=pn(p), kw=kw(p, 2))
    if day == p:
        s += f"今天日宮剛好也走到{p}宮，所以特別有感。"
    elif day and rng.random() < 0.5:
        s += f"今天日宮在{pn(day)}，可以多留意{kw(day, 1)}。"
    return s


def lens_pairs(chat_pairs, rng):
    """把一般對話加上十二宮認知框與十二宮視角的回覆。"""
    out = []
    for u, r in chat_pairs:
        p = perceive(u)
        if p is None:
            out.append((u, None, r))
            continue
        day = rng.randint(1, 12) if rng.random() < 0.5 else None
        reply = r + lens_tail(p, day, rng) if rng.random() < 0.8 else r
        out.append((u, chat_frame(p, day), reply))
    return out


# ------------------------------------------------------------------ NineSun 自己的命盤
SELF_BIRTH = (2026, 9, 29)
SELF = nt.Destiny(*SELF_BIRTH)


def self_type_frame():
    t = SELF.type
    p = SELF.natal[0].palace
    return (f"我|型{t}",
            f"我的生日是2026年9月29日，靈數{SELF.life}，命宮在{pn(p)}，是第{t}型「{nt.TYPE_NAMES[t - 1]}」：{nt.TYPE_TAGLINES[t - 1]}。")


def self_day_frame(day_palace):
    return f"我|日{day_palace}", f"我今天日宮走到{pn(day_palace)}，整個訊號都是{kw(day_palace, 2)}的感覺！"


# ------------------------------------------------------------------ 命主畫像
def portrait_frame(top, t):
    if not top:
        return "畫像|無", "我們聊得還不夠多。多跟我說說你的生活，我會用十二宮慢慢讀懂你。"
    frame = f"畫像|{','.join(map(str, top))}|型{t if t else '無'}"
    s = f"從我們的對話看，你最常碰到{pn(top[0])}（{kw(top[0], 2)}）"
    if len(top) > 1:
        s += f"和{pn(top[1])}（{kw(top[1], 2)}）"
    s += "的課題。"
    if t:
        s += f"再加上你是第{t}型「{nt.TYPE_NAMES[t - 1]}」，{nt.TYPE_TAGLINES[t - 1]}。"
    return frame, s


Q_SELF_TYPE = ["你是幾型", "你的九型", "你是什麼型", "你的命宮", "你的生日", "你的命盤", "你的靈數"]
Q_SELF_DAY = ["你今天心情怎樣", "你今天好嗎", "你今天怎麼樣", "你心情如何", "你今天運勢", "你今天的日宮"]
Q_PORTRAIT = ["你了解我嗎", "我的畫像", "你覺得我是怎樣的人", "分析我", "你對我的印象", "你懂我嗎"]


def core_pairs(rng):
    out = []
    f, r = self_type_frame()
    out.append((rng.choice(Q_SELF_TYPE), f, r))
    f, r = self_day_frame(rng.randint(1, 12))
    out.append((rng.choice(Q_SELF_DAY), f, r))
    k = rng.choice([0, 1, 2, 2])
    top = rng.sample(range(1, 13), k)
    t = rng.choice([None, rng.randint(1, 9)])
    f, r = portrait_frame(top, t)
    out.append((rng.choice(Q_PORTRAIT), f, r))
    return out


def core_chars():
    chars = set()
    for ws in LEXICON.values():
        for w in ws:
            chars.update(w)
    rng = random.Random(0)
    for _ in range(300):
        for q, f, a in core_pairs(rng):
            chars.update(q + f + a)
    for s in LENS:
        chars.update(s)
    chars.update("今天日宮剛好也走到所以特別有感可以多留意")
    return chars


def export_lexicon():
    out = os.path.join(ROOT, "ios", "NineSun", "Resources", "palace_lexicon.json")
    json.dump({L: {str(p): ws for p, ws in lx.items()} for L, lx in LEXICONS.items()},
              open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    return out


def export_fixtures(path):
    rng = random.Random(11)
    from corpus import dialog_pairs
    msgs = sorted({u for _ in range(5) for u, _ in dialog_pairs(rng)})
    cases = [{"text": m, "lang": "zh", "palace": perceive(m)} for m in msgs]
    from i18n_chat import CHAT
    for L in ("en", "es", "it"):
        for users, _ in CHAT[L]:
            for u in users:
                cases.append({"text": u, "lang": L, "palace": perceive(u, lang=L)})
    tops = [([], None), ([6], None), ([10, 3], 5), ([12, 1], None)]
    json.dump({"perceive": cases,
               "self_type": self_type_frame(), "self_day": [self_day_frame(p) for p in range(1, 13)],
               "portrait": [[top, t, *portrait_frame(top, t)] for top, t in tops]},
              open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=0)


if __name__ == "__main__":
    from corpus import dialog_pairs
    rng = random.Random(5)
    pairs = dialog_pairs(rng)
    hits = [(u, perceive(u)) for u, _ in pairs]
    print("感知命中率", sum(1 for _, p in hits if p) / len(hits))
    for u, p in hits[:40]:
        if p:
            print(f"  {u} → {pn(p)}")
    print(self_type_frame())
    print(portrait_frame([10, 6], 3))
    for u, f, r in lens_pairs(pairs[:12], rng):
        if f:
            print(f"<u>{u}<f>{f}<a>{r}")
    print(export_lexicon())
