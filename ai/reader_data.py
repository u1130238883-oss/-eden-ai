# -*- coding: utf-8 -*-
"""
閱讀理解大腦的教材：載入、轉繁體、切段、做成一題一題的練習。

教材（都是公開、可再利用的資料集，不含任何 AI 產生的文字）：
  - DRCD：台達閱讀理解資料集，台灣維基百科（CC BY-SA 3.0）
  - CMRC 2018：中文機器閱讀理解（CC BY-SA 4.0），簡體轉成繁體

切段的方式和 App 裡 Think.passages 一模一樣：先切句，再湊成 60～160 字一段。
這樣大腦練習時讀到的段落，就是它在手機上讀網頁時會看到的樣子。
"""
import json
import os
import random

SENT_END = set("。！？!?；")


def load_squad(path, convert=None):
    """回傳 [(context, question, answer_text, answer_start)]；沒有答案的 answer_start = -1。
    convert：簡轉繁的函式（逐字轉換，長度不變；轉完對不上位置的題目就丟掉）。"""
    data = json.load(open(path, encoding="utf-8"))["data"]
    out, bad = [], 0
    for art in data:
        for para in art["paragraphs"]:
            ctx = para["context"]
            cctx = convert(ctx) if convert else ctx
            if len(cctx) != len(ctx):
                bad += len(para["qas"])
                continue
            for qa in para["qas"]:
                q = convert(qa["question"]) if convert else qa["question"]
                ans = qa["answers"][0] if qa.get("answers") else None
                if not ans:
                    out.append((cctx, q, "", -1))
                    continue
                a, a0 = ans["text"], ans["answer_start"]
                if ctx[a0:a0 + len(a)] != a:
                    # 有些題目的位置標錯：找最近的那一個
                    hits = [i for i in range(len(ctx)) if ctx.startswith(a, i)]
                    if not hits:
                        bad += 1
                        continue
                    a0 = min(hits, key=lambda i: abs(i - a0))
                out.append((cctx, q, cctx[a0:a0 + len(a)], a0))
    return out, bad


def simplified_to_traditional():
    from opencc import OpenCC  # pip install opencc-python-reimplemented
    cc = OpenCC("s2tw")
    return cc.convert


def passages(text):
    """[(start, end)]：和 Swift 的 Think.passages 同樣的切法（句號、問號、驚嘆號、分號切句，湊成 60～160 字）。"""
    sents = []
    pos = 0
    for line in text.split("\n"):
        lstart = pos
        pos += len(line) + 1
        stripped = line.strip(" \t")
        if not stripped or "｜" in stripped:
            continue
        off = lstart + (len(line) - len(line.lstrip(" \t")))
        cur = off
        for i, ch in enumerate(stripped):
            if ch in SENT_END:
                sents.append((cur, off + i + 1))
                cur = off + i + 1
        if cur < off + len(stripped):
            sents.append((cur, off + len(stripped)))
    out = []
    cur = None
    for s, e in sents:
        if cur is not None and (cur[1] - cur[0]) + (e - s) > 160:
            out.append(cur)
            cur = None
        cur = (s, e) if cur is None else (cur[0], e)
        if cur[1] - cur[0] >= 60:
            out.append(cur)
            cur = None
    if cur is not None and cur[1] - cur[0] >= 15:
        out.append(cur)
    return out


def all_sets(data_dir, convert):
    """訓練用（DRCD 訓練＋測試、CMRC 全部）與考試用（DRCD dev，從來不拿來訓練）。"""
    j = lambda f: os.path.join(data_dir, f)
    train, bad = [], 0
    for f in ["DRCD_training.json", "DRCD_test.json"]:
        s, b = load_squad(j(f))
        train += s
        bad += b
    for f in ["cmrc2018_train.json", "cmrc2018_dev.json", "cmrc2018_trial.json"]:
        if os.path.exists(j(f)):
            s, b = load_squad(j(f), convert)
            train += s
            bad += b
    dev, _ = load_squad(j("DRCD_dev.json"))
    return train, dev, bad


def pretrain_texts(train):
    """讀書用的文章：訓練教材裡所有不重複的段落（考試的文章不在裡面）。"""
    seen, out = set(), []
    for ctx, _, _, _ in train:
        if ctx not in seen:
            seen.add(ctx)
            out.append(ctx)
    return out


if __name__ == "__main__":
    import sys
    d = sys.argv[1]
    tr, dv, bad = all_sets(d, simplified_to_traditional())
    print("train", len(tr), "dev", len(dv), "dropped", bad)
    ctx, q, a, a0 = tr[-1]
    print(q, "→", a)
    print([ctx[s:e] for s, e in passages(ctx)][:3])
