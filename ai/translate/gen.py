# -*- coding: utf-8 -*-
"""中英西義互相翻譯的訓練題：500,000 題（單字、短語、句子 × 四種語言互翻 × 各種問法）。
每題：q 問句；text 應該翻的內容（null＝不是要翻譯）；target 要翻成的語言代號；kind 單字／短語／句子。
內容來自 Fixtures/translate_corpus.json（5,000 單字＋5,000 短語＋5,000 句子，每條都有中英西義四種）。
驗證題（--holdout）用沒看過的內容（每十條留一條）＋沒看過的問法。
用法：python3 ai/translate/gen.py 輸出.json [--holdout] [--n 500000]"""
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import translate_questions as T  # noqa: E402

HOLD = "--holdout" in sys.argv
N = int(sys.argv[sys.argv.index("--n") + 1]) if "--n" in sys.argv else (20000 if HOLD else 500000)
R = random.Random(97 if HOLD else 79)
CORPUS = json.load(open(os.path.join(HERE, "..", "..", "ios", "EchoCore", "Tests", "EchoCoreTests", "Fixtures", "translate_corpus.json"), encoding="utf-8"))
KINDS = {"words": "word", "phrases": "phrase", "sentences": "sentence"}
LANGS = ["zh", "en", "es", "it"]
ITEMS = [(KINDS[k], i, e) for k, es in CORPUS.items() for i, e in enumerate(es) if (i % 10 == 0) == HOLD]

ZH_T = T.ZH_T + T.ZH_T2
EN_T = T.EN_T + T.EN_T2
ES_T = T.ES_T + T.ES_T2
IT_T = T.IT_T + T.IT_T2
ABBR_T = T.ABBR_T
if HOLD:
    ZH_T = ["{X}換成{L}要怎麼說", "請教一下{X}的{L}說法", "{X}這個用{L}怎麼表達", "能不能用{L}說{X}", "{X}用{L}講是什麼",
            "請幫我翻譯成{L}：{X}", "把這句翻成{L}：{X}", "{X}譯成{L}", "{X}用{L}該怎麼說才對"]
    EN_T = ["what's {X} in {L}?", "translate {X} into {L} please", "how can I say {X} in {L}?", "how should I say {X} in {L}"]
    ES_T = ["¿cómo se dice {X} en {L}?", "traduce {X} al {L}"]
    IT_T = ["come si dice {X} in {L}?", "traduci {X} in {L}"]
    ABBR_T = ["{S}譯{A}：{X}", "{X}，請翻{A}"]
FORE = {"en": T.EN_NAMES, "es": T.ES_NAMES, "it": T.IT_NAMES}
ZHABBR = {"zh": "中", "en": "英", "es": "西", "it": "義"}


def pick(e, l):
    # 「monopatín/patineta」「to return/to give back」：斜線分開的是幾種說法，問的時候只會用其中一種
    return R.choice(e[l].split("/")).strip()


def ok_text(x, src):
    if not x or len(x) > 120:
        return False
    # 中文單字是一個字（「考」「還」「最」）：放進句型會黏成別的詞（「考英文怎麼說」是在問考試），不出題
    if src == "zh" and len(x) == 1:
        return False
    return True


def one():
    if R.random() < 0.03:
        neg = R.choice(T.NEG_PLAIN + T.NEG2 + [t.format(L=R.choice(R.choice(list(T.ZH_NAMES.values())))) for t in T.NEG_T])
        return {"q": neg + R.choice(["", "？", "啊"]), "text": None, "target": None, "kind": "none"}
    kind, _, e = R.choice(ITEMS)
    src = R.choice(LANGS)
    tgt = R.choice([l for l in LANGS if l != src])
    x = pick(e, src)
    if not ok_text(x, src):
        return None
    r = R.random()
    if r < 0.55:
        tpl = R.choice([t for t in ZH_T if not T.ambiguous(t, x)])
        q = tpl.format(X=x, L=R.choice(T.ZH_NAMES[tgt]))
    elif r < 0.65:
        q = R.choice(ABBR_T).format(X=x, A=R.choice(T.ABBR[tgt]), S=ZHABBR[src])
    else:
        ql = R.choice(["en", "es", "it"])
        q = R.choice({"en": EN_T, "es": ES_T, "it": IT_T}[ql]).format(X=x, L=R.choice(FORE[ql][tgt]))
    return {"q": q, "text": x, "target": T.CODE[tgt], "kind": kind}


def main(dst):
    out, seen, tries = [], set(), 0
    while len(out) < N and tries < N * 20:
        tries += 1
        it = one()
        if not it or it["q"] in seen:
            continue
        seen.add(it["q"]); out.append(it)
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    from collections import Counter
    print(len(out), Counter(x["kind"] for x in out), Counter(x["target"] for x in out))


if __name__ == "__main__":
    main(sys.argv[1])
