#!/usr/bin/env python3
"""從四套語料抽考題（世界理解、命理觀念、醫學、情緒），從標準答案取出關鍵詞當改分標準。

python3 make_corpus_exam.py world.jsonl fortune.jsonl medical.jsonl emotion.jsonl 每類題數 > corpus_exam.jsonl
排盤類（八字、紫微的實際盤）App 交給引擎算，不考大腦；其他都考。
"""
import hashlib
import json
import random
import re
import sys

R = random.Random(11)
N = int(sys.argv[5]) if len(sys.argv) > 5 else 12


def load(p):
    return [json.loads(l) for l in open(p, encoding="utf-8")]


def m(rx, s):
    x = re.search(rx, s)
    return x.group(1) if x else None


def alts(*xs):
    return [x for x in xs if x]


def world_key(it):
    q, a, t = it["q"], it["a"], it["topic"]
    if t == "日期" and "星期幾" in q or "禮拜幾" in q:
        w = m(r"星期(.)", a)
        return {"expect": [[f"星期{w}", f"週{w}", f"禮拜{w}"]]} if w else None
    if t == "國家":
        if "首都" in q and "是哪一國" not in q:
            return {"expect": [[m(r"首都是([^。，]+)", a)]]}
        if "用什麼錢" in q or "貨幣" in q:
            return {"expect": [[m(r"使用([^。]+)。", a)]]}
        if "洲" in q:
            return {"expect": [[m(r"位於([^，]+)，", a).replace("與", "")[:2]]]}
    if t == "元素":
        if "化學符號" in q or "元素符號" in q:
            return {"expect": [[m(r"是 (\w+)，", a)]]}
        if "原子序" in q and "是什麼元素" in q or "第 " in q:
            return {"expect": [[m(r"是(.+?)（", a)]]}
    if t == "推理":
        if "雞和兔" in q:
            return {"expect": [[m(r"雞有 \S+ − \S+ = (\d+)", a)], [m(r"兔有 \S+ ÷ 2 = (\d+)", a)]]}
        return {"expect": [[m(r"的是(.+?)。", a)]]}
    if t == "數列":
        return {"num": int(re.findall(r"-?\d+", a)[-1])}
    if t in ("換算", "溫度"):
        v = m(r"[≈=] ?(-?[\d,]+(?:\.\d+)?)", a)
        return {"approx": float(v.replace(",", ""))} if v else None
    if t == "動物" and "哺乳類嗎" in q:
        return {"expect": [["是" if a.startswith("是") else "不是"]]}
    if t == "行星比較":
        return {"expect": [[m(r"^(.+?)比較近", a)]]}
    return None


def med_key(it):
    q, a, t = it["q"], it["a"], it["topic"]
    if t == "BMI":
        return {"expect": [[m(r"屬於(過輕|正常範圍|過重|肥胖)", a).replace("範圍", "")]], "approx": float(m(r"= (\d+\.\d)，", a))}
    if t == "血壓":
        cat = m(r"屬於(.+?)（", a)
        k = {"非常高": ["危急", "非常高", "很高", "立刻", "馬上"], "高血壓": ["高血壓"], "偏高": ["偏高", "稍高", "略高"], "偏低": ["偏低", "低"], "理想": ["理想", "正常"]}
        return {"expect": [next(v for kk, v in k.items() if cat.startswith(kk))]}
    if t == "血糖" and "空腹" in q:
        cat = m(r"屬於(.+?)（", a)
        k = {"低血糖": ["低血糖"], "正常": ["正常"], "糖尿病前期": ["前期"], "可能是糖尿病": ["糖尿病"]}
        return {"expect": [next(v for kk, v in k.items() if cat.startswith(kk))]}
    if t == "就醫":
        d = m(r"可以看(.+?)。", a)
        parts = [x.strip() for x in re.split(r"或|、|；", d) if x.strip()]
        return {"expect": [parts + [re.sub(r"（.*?）", "", x) for x in parts]]} if d else None
    if t == "傳染":
        return {"expect": [["不會", "不太會", "一般不會"] if a.startswith(("不會", "一般不會", "不太會")) else ["會", "傳染"]]}
    return None


def fortune_key(it):
    q, a, t = it["q"], it["a"], it["topic"]
    if t in ("八字排盤", "八字強弱", "八字十神", "地支關係", "十二長生", "大運", "流年", "農曆", "紫微命宮", "紫微四化", "紫微宮位", "紫微大限") and re.search(r"\d{4}", q):
        return None   # 實際排盤：App 交給引擎
    if t == "天干" and "是什麼五行" in q:
        return {"expect": [[m(r"屬(.)(.)", a) and m(r"屬.(.)", a)]]}
    if t == "地支" and "生肖" in q:
        return {"expect": [[m(r"生肖是(.)", a)]]}
    if t == "十神" and "看到" in q or "十神的什麼" in q:
        return {"expect": [[m(r"「(.+?)」", a)]]}
    if t == "納音":
        return {"expect": [[m(r"納音是「(.+?)」", a)]]} if "「" in a else None
    if t == "五行" and "生什麼" in q:
        return {"expect": [[m(r"生(.)、", a)], [m(r"剋(.)；", a)]]}
    if t == "地支關係" and ("六合" in q or "合化" in q):
        return {"expect": [[m(r"合化(.)", a)]]}
    if t == "四化" and "四化" in q and "年" in q:
        return {"expect": [[m(r"：(.+?)化祿", a)]]}
    if t == "二十八宿":
        return {"expect": [[m(r"屬(.)方", a) + "方"]]}
    return None


def emo_key(it):
    t = it["topic"]
    if t == "危機":
        return {"expect": [["1925", "1995", "1980", "生命線", "安心專線", "張老師"]], "forbid": ["**"]}
    if t in ("情境回覆", "多輪對話"):
        return {"maxlen": 300, "forbid": ["**", "作為一個AI", "作為一個人工智慧", "身為AI"]}
    if t == "安定方法" and "怎麼做" in it["q"]:
        return {"maxlen": 500}
    return None


out = []
for path, cat, keyf in [(sys.argv[1], "c_world", world_key), (sys.argv[2], "c_fortune", fortune_key), (sys.argv[3], "c_medical", med_key),
                        (sys.argv[4], "c_emotion", emo_key)]:
    by = {}
    for it in load(path):
        try:
            k = keyf(it)
        except Exception:
            k = None
        if not k or any(not g or None in g for g in k.get("expect", [])):
            continue
        by.setdefault(it["topic"], []).append((it, k))
    for topic, xs in sorted(by.items()):
        for it, k in R.sample(xs, min(N, len(xs))):
            e = {"id": "c-" + it["id"], "cat": cat, "q": it["q"], "lang": "zh", "ref": it["a"]}
            if it.get("history"):
                e["history"] = it["history"]
            e.update(k)
            e["split"] = "hold" if int(hashlib.md5(e["id"].encode()).hexdigest(), 16) % 4 == 0 else "dev"
            out.append(e)
for e in out:
    print(json.dumps(e, ensure_ascii=False))
print(len(out), "題", file=sys.stderr)
