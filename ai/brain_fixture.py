# -*- coding: utf-8 -*-
"""
從匯出的 reader.bin / reader.json（float16）讀回大腦，用和 Swift 的 Brain.read 一模一樣的步驟讀幾段文字，
把結果寫成 Swift 測試要對照的 fixture。

    python3 ai/brain_fixture.py ios/NineSun/Resources ios/EchoCore/Tests/EchoCoreTests/Fixtures/brain.json
"""
import json
import os
import sys

import numpy as np

from reader_model import Reader, ReaderTokenizer, match_features


def load(res_dir, name="reader"):
    meta = json.load(open(os.path.join(res_dir, name + ".json"), encoding="utf-8"))
    raw = np.fromfile(os.path.join(res_dir, name + ".bin"), dtype="<f2").astype(np.float32)
    cfg = meta["config"]
    m = Reader(cfg["vocab_size"], n_ctx=cfg["n_ctx"], n_embd=cfg["n_embd"], n_head=cfg["n_head"], n_layer=cfg["n_layer"])
    for t in meta["tensors"]:
        n = int(np.prod(t["shape"]))
        m.p[t["name"]] = raw[t["offset"]:t["offset"] + n].reshape(t["shape"])
    stoi = {}
    for i, s in enumerate(meta["vocab"]):
        stoi.setdefault(s, i)
    return m, meta, stoi


def read(m, meta, stoi, question, passage, max_answer=40):
    """Brain.read 的 Python 版：長段落切成有重疊的幾段，取最有把握的答案。"""
    sp = meta["specials"]
    unk, cls, sep = sp["unk"], sp["cls"], sp["sep"]
    punct = set(meta.get("punct", []))
    qc = ReaderTokenizer.norm(question)[:meta.get("q_max", 48)]
    q = [stoi.get(c, unk) for c in qc]
    pchars = ReaderTokenizer.norm(passage)
    pc = [stoi.get(c, unk) for c in pchars]
    if not pc:
        return None
    L = meta["config"]["n_ctx"] - 3 - len(q)
    stride = max(L // 2, 1)
    best, start = None, 0
    while True:
        piece = pc[start:start + L]
        tokens = [cls] + q + [sep] + piece + [sep]
        segs = [0] * (len(q) + 2) + [1] * (len(piece) + 1)
        mq, mp = match_features(qc, pchars[start:start + L], punct)
        mat = [0] + mq + [0] + mp + [0]
        base = len(q) + 2
        a = np.array([tokens]); s_ = np.array([segs]); mt = np.array([mat])
        cand = np.ones_like(a, dtype=bool)
        ls, le = m.forward(a, s_, cand, mt)
        ls, le = ls[0], le[0]
        none = ls[0] + le[0]
        pos = list(range(base, base + len(piece)))
        s_top = sorted(pos, key=lambda i: -ls[i])[:20]
        e_top = sorted(pos, key=lambda i: -le[i])[:20]
        for s in s_top:
            for e in e_top:
                if s <= e < s + max_answer:
                    sc = float(ls[s] + le[e] - none)
                    if best is None or sc > best["score"]:
                        a0, b0 = start + s - base, start + e - base
                        best = {"text": passage[a0:b0 + 1], "score": sc, "start": a0, "end": b0}
        if start + L >= len(pc):
            break
        start += stride
    return best


CASES = [
    ("李白是哪個朝代的詩人？", "李白，字太白，號青蓮居士，是唐朝著名的浪漫主義詩人，被後人譽為「詩仙」。他出生於西域碎葉城，少年時隨父遷居綿州昌隆縣。"),
    ("台北101有多高？", "台北101是位於台灣台北市信義區的摩天大樓，樓高508公尺，地上101層，地下5層。2004年落成時是世界最高的建築物。"),
    ("月球距離地球多遠？", "月球是地球唯一的天然衛星。月球與地球的平均距離約為384,400公里，大約是地球直徑的30倍。月球表面布滿了撞擊坑。"),
    ("誰發明了電話？", "電話是一種可以傳送與接收聲音的遠程通訊設備。一般認為亞歷山大·格拉漢姆·貝爾在1876年取得了電話的專利。早期的電話需要接線生轉接。"),
    ("感冒要看哪一科？", "今天天氣很好，我們去公園散步。公園裡有很多人在跑步，還有小朋友在玩溜滑梯。"),
]


if __name__ == "__main__":
    res, out = sys.argv[1], sys.argv[2]
    m, meta, stoi = load(res)
    rows = []
    for q, p in CASES:
        r = read(m, meta, stoi, q, p)
        print(q, "→", r and (r["text"], round(r["score"], 2)))
        rows.append({"question": q, "passage": p, **(r or {"text": "", "score": 0, "start": -1, "end": -1})})
    json.dump(rows, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
