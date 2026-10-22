# -*- coding: utf-8 -*-
"""組出四語翻譯測試語料：5000 單字、5000 短語、5000 句子。
用法：python3 ai/corpus4/build.py ios/EchoCore/Tests/EchoCoreTests/Fixtures/translate_corpus.json
每一項：{"zh","en","es","it"}，同一格用 / 分開其他說法（第一個是主要答案）。"""
import glob
import json
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from numwords import numbers  # noqa: E402
from nouns import ADJS, NOUNS, SUBJECTS, VERB_CATS, VERBS  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ZH_NUM = {2: "兩", 3: "三", 4: "四", 5: "五", 6: "六", 7: "七", 8: "八", 9: "九", 10: "十"}
EN_NUM = {2: "two", 3: "three", 4: "four", 5: "five", 6: "six", 7: "seven", 8: "eight", 9: "nine", 10: "ten"}
ES_NUM = {2: "dos", 3: "tres", 4: "cuatro", 5: "cinco", 6: "seis", 7: "siete", 8: "ocho", 9: "nueve", 10: "diez"}
IT_NUM = {2: "due", 3: "tre", 4: "quattro", 5: "cinque", 6: "sei", 7: "sette", 8: "otto", 9: "nove", 10: "dieci"}
DIRECT_ADJ = {"大", "小", "新", "舊", "長", "短", "熱", "冷"}   # 「大房子」不用加「的」
COLORS = {"紅色", "藍色", "綠色", "黃色", "黑色", "白色", "灰色"}


def cap(s):
    if s.startswith("¿"):
        return "¿" + s[1:2].upper() + s[2:]
    return s[:1].upper() + s[1:]


def item(zh, en, es, it):
    return {"zh": zh, "en": en, "es": es, "it": it}


# ---------- 單字 ----------
def words():
    out, seen = [], set()
    for path in sorted(glob.glob(os.path.join(HERE, "w*.txt"))):
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            zh, en, es, it = line.split("|")
            zh = re.sub(r"（[^）]*）", "", zh)          # 「離婚（名詞）」→「離婚」
            key = (zh, en.split("/")[0].lower())
            if key in seen:
                continue
            seen.add(key)
            out.append(item(zh, en, es, it))
    nums = numbers(1000)
    have = {w["zh"] for w in out}
    out += [n for n in nums if n["zh"] not in have]
    return out


# ---------- 短語 ----------
def adj_noun(a, n, number=None):
    zh_adj = a.zh if a.zh in DIRECT_ADJ else a.zh + "的"
    if number is None:
        return item(zh_adj + n.zh, f"{a.en} {n.en}", f"{n.es} {a.es(n.es_g)}", f"{n.it} {a.it(n.it_g)}")
    k = number
    return item(f"{ZH_NUM[k]}{n.mw}{zh_adj}{n.zh}", f"{EN_NUM[k]} {a.en} {n.en_pl}",
                f"{ES_NUM[k]} {n.es_pl} {a.es(n.es_g, True)}", f"{IT_NUM[k]} {n.it_pl} {a.it(n.it_g, True)}")


def phrases():
    out = []
    singular = [n for n in NOUNS if not n.plural_only]
    for n in singular:
        for a in ADJS:
            if n.cat in a.cats:
                out.append(adj_noun(a, n))
        for k in range(2, 11):
            out.append(item(f"{ZH_NUM[k]}{n.mw}{n.zh}", f"{EN_NUM[k]} {n.en_pl}", f"{ES_NUM[k]} {n.es_pl}", f"{IT_NUM[k]} {n.it_pl}"))
        out.append(item("我的" + n.zh, "my " + n.en, "mi " + n.es, n.it_my()))
        out.append(item("你的" + n.zh, "your " + n.en, "tu " + n.es, ("il tuo " if n.it_g == "m" else "la tua ") + n.it))
        out.append(item("我們的" + n.zh, "our " + n.en, ("nuestro " if n.es_g == "m" else "nuestra ") + n.es,
                        ("il nostro " if n.it_g == "m" else "la nostra ") + n.it))
        out.append(item("這" + n.mw + n.zh, "this " + n.en, n.es_this(), n.it_this()))
        out.append(item("那" + n.mw + n.zh, "that " + n.en, n.es_that(), n.it_that()))
        if n.cat in ("obj", "food", "cloth", "vehicle"):
            out.append(item("買" + n.zh_one(), "buy " + n.en_indef(), "comprar " + n.es_indef(), "comprare " + n.it_indef()))
            out.append(item("賣" + n.zh_one(), "sell " + n.en_indef(), "vender " + n.es_indef(), "vendere " + n.it_indef()))
        if n.cat in ("obj", "animal", "vehicle", "cloth"):
            out.append(item("找到" + n.zh_one(), "find " + n.en_indef(), "encontrar " + n.es_indef(), "trovare " + n.it_indef()))
            out.append(item("畫" + n.zh_one(), "draw " + n.en_indef(), "dibujar " + n.es_indef(), "disegnare " + n.it_indef()))
    # 數字＋形容詞＋名詞補足
    rng = random.Random(4)
    extra = []
    for n in singular:
        for a in ADJS:
            if n.cat in a.cats and n.cat != "person":
                for k in (2, 3, 4, 5):
                    extra.append(adj_noun(a, n, k))
    rng.shuffle(extra)
    return out + extra


# ---------- 句子 ----------
def sentences():
    out = []
    singular = [n for n in NOUNS if not n.plural_only]
    for n in singular:
        # 主詞＋動詞＋一個東西
        for vk, (vzh, ven, ven3, ves, vit, _) in VERBS.items():
            if n.cat not in VERB_CATS[vk]:
                continue
            for szh, sen, ses, sit, idx in SUBJECTS:
                en_v = ven3 if idx == 2 else ven
                it_obj = n.it_indef()
                if vk == "need":
                    it_obj = it_obj.replace("un'", "un'")
                es_s = cap(f"{ses}{ves[idx]} {n.es_indef()}.")
                it_s = cap(f"{sit}{vit[idx]} {it_obj}.")
                out.append(item(f"{szh}{vzh}{n.zh_one()}。", f"{sen.capitalize() if sen != 'I' else 'I'} {en_v} {n.en_indef()}.", es_s, it_s))
        # 這／那＋名詞＋很＋形容詞
        for a in ADJS:
            if n.cat not in a.cats or a.zh in COLORS or a.zh == "壞掉的":
                continue
            out.append(item(f"這{n.mw}{n.zh}很{a.zh}。", f"This {n.en} is very {a.en}.",
                            cap(f"{n.es_this()} es muy {a.es(n.es_g)}."), cap(f"{n.it_this()} è molto {a.it(n.it_g)}.")))
            out.append(item(f"那{n.mw}{n.zh}很{a.zh}。", f"That {n.en} is very {a.en}.",
                            cap(f"{n.es_that()} es muy {a.es(n.es_g)}."), cap(f"{n.it_that()} è molto {a.it(n.it_g)}.")))
            out.append(item(f"{n.zh}很{a.zh}嗎？", f"Is the {n.en} {a.en}?",
                            f"¿{cap(n.es_def())} es {a.es(n.es_g)}?", cap(f"{n.it_def()} è {a.it(n.it_g)}?")))
        out.append(item(f"{n.zh}在哪裡？", f"Where is the {n.en}?", f"¿Dónde está {n.es_def()}?", f"Dov'è {n.it_def()}?"))
        if n.cat in ("obj", "cloth", "vehicle", "animal"):
            for k in (2, 3, 4, 5):
                out.append(item(f"我有{ZH_NUM[k]}{n.mw}{n.zh}。", f"I have {EN_NUM[k]} {n.en_pl}.", f"Tengo {ES_NUM[k]} {n.es_pl}.",
                                f"Ho {IT_NUM[k]} {n.it_pl}."))
            out.append(item(f"我在找我的{n.zh}。", f"I'm looking for my {n.en}.", f"Estoy buscando mi {n.es}.", f"Sto cercando {n.it_my()}."))
            out.append(item(f"我找不到我的{n.zh}。", f"I can't find my {n.en}.", f"No encuentro mi {n.es}.", f"Non trovo {n.it_my()}."))
            out.append(item(f"這是我的{n.zh}。", f"This is my {n.en}.", f"{'Este' if n.es_g == 'm' else 'Esta'} es mi {n.es}.",
                            f"{'Questo' if n.it_g == 'm' else 'Questa'} è {n.it_my()}."))
        if n.cat in ("obj", "food", "cloth"):
            out.append(item(f"你有{n.zh}嗎？", f"Do you have {n.en_indef()}?", f"¿Tienes {n.es_indef()}?", f"Hai {n.it_indef()}?"))
            out.append(item(f"請給我{n.zh_one()}。", f"Please give me {n.en_indef()}.", f"Dame {n.es_indef()}, por favor.",
                            f"Dammi {n.it_indef()}, per favore."))
        if n.cat in ("obj", "food", "cloth", "vehicle"):
            out.append(item(f"這{n.mw}{n.zh}多少錢？", f"How much is this {n.en}?", f"¿Cuánto cuesta {n.es_this()}?", f"Quanto costa {n.it_this()}?"))
            out.append(item(f"我買了{n.zh_one()}。", f"I bought {n.en_indef()}.", f"Compré {n.es_indef()}.", f"Ho comprato {n.it_indef()}."))
        out.append(item(f"我喜歡這{n.mw}{n.zh}。", f"I like this {n.en}.", f"Me gusta {n.es_this()}.", f"Mi piace {n.it_this()}."))
        for a in ADJS:
            if a.zh in COLORS and n.cat in a.cats and n.cat in ("obj", "cloth", "vehicle"):
                out.append(item(f"那{n.mw}{n.zh}是{a.zh}的。", f"That {n.en} is {a.en}.", cap(f"{n.es_that()} es {a.es(n.es_g)}."),
                                cap(f"{n.it_that()} è {a.it(n.it_g)}.")))
    return out


def main(dst):
    rng = random.Random(20261023)
    w, p, s = words(), phrases(), sentences()
    print(f"可用：單字 {len(w)}、短語 {len(p)}、句子 {len(s)}")

    def take(xs, n):
        xs = list({json.dumps(x, ensure_ascii=False, sort_keys=True): x for x in xs}.values())
        rng.shuffle(xs)
        return xs[:n]
    data = {"words": take(w, 5000), "phrases": take(p, 5000), "sentences": take(s, 5000)}
    json.dump(data, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print({k: len(v) for k, v in data.items()})


if __name__ == "__main__":
    main(sys.argv[1])
