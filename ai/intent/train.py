# -*- coding: utf-8 -*-
"""訓練 NineSun 自己的「理解問題」模型（純 NumPy，從零開始，不用別人的權重）。

模型：一句話切成 1～3 個字的片段（「有什麼」「什麼故」「故事」…），每個片段用 FNV-1a 雜湊到 2^15 個格子，
加總後經過一層隱藏層（64 個神經元、ReLU）→ 每個題型一個分數 → softmax。
它從資料裡自己學到哪些片段代表哪一種問法；沒看過的說法，只要片段相近就能類推。
Swift 端（EchoCore/Intent.swift）用一模一樣的雜湊和數學推理。

另外接上 NineSun 自己的閱讀模型（reader.bin，預先讀過大量中文）讀出來的「意思」（ai/intent/encode.py，512 維）：
片段告訴它字長什麼樣子，意思告訴它這些字在說什麼——沒看過的說法（「怎麼一回事」）也能靠意思類推到「是什麼」。

用法：python3 ai/intent/train.py train.tsv holdout.tsv 輸出資料夾 [train_enc.npy holdout_enc.npy]
"""
import json
import struct
import sys

import numpy as np

BUCKETS = 1 << 15
HIDDEN = 64
NGRAM = (1, 2, 3)


def fnv1a(s):
    h = 0x811C9DC5
    for b in s.encode("utf-8"):
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def normalize(q):
    q = q.strip().lower()
    for ch in "？?！!。，,、～~ ":
        q = q.replace(ch, "")
    return q


def features(q):
    """句子 → 雜湊後的格子（重複的算一次）。前後加上邊界記號，讓模型知道「開頭」「結尾」（「什麼是X」和「X是什麼」）"""
    t = "^" + normalize(q) + "$"
    out = set()
    for n in NGRAM:
        for i in range(len(t) - n + 1):
            out.add(fnv1a(t[i:i + n]) % BUCKETS)
    return sorted(out)


def load(path):
    xs, ys = [], []
    with open(path, encoding="utf-8") as f:
        for line in f:
            lab, q = line.rstrip("\n").split("\t", 1)
            xs.append(features(q))
            ys.append(lab)
    return xs, ys


def forward(E, W1, b1, W2, b2, batch, enc=None):
    # 每句：所有格子的向量平均（＋閱讀模型讀出來的意思，已經標準化）
    D = E.shape[1]
    h0 = np.zeros((len(batch), W1.shape[0]), dtype=np.float32)
    for i, f in enumerate(batch):
        h0[i, :D] = E[f].mean(axis=0)
    if enc is not None:
        h0[:, D:] = enc
    z1 = h0 @ W1 + b1
    a1 = np.maximum(z1, 0)
    logits = a1 @ W2 + b2
    return h0, z1, a1, logits


def main():
    tr, ho, out = sys.argv[1], sys.argv[2], sys.argv[3]
    xs, ys = load(tr)
    hx, hy = load(ho)
    enc_tr = enc_ho = None
    mu = sd = None
    if len(sys.argv) > 5:
        enc_tr, enc_ho = np.load(sys.argv[4]), np.load(sys.argv[5])
        mu, sd = enc_tr.mean(0), enc_tr.std(0) + 1e-4
        enc_tr, enc_ho = ((enc_tr - mu) / sd).astype(np.float32), ((enc_ho - mu) / sd).astype(np.float32)
    ENC = 0 if enc_tr is None else enc_tr.shape[1]
    labels = sorted(set(ys))
    li = {l: i for i, l in enumerate(labels)}
    y = np.array([li[l] for l in ys])
    hyi = np.array([li[l] for l in hy])
    rng = np.random.default_rng(0)
    D = 48
    E = (rng.standard_normal((BUCKETS, D)) * 0.1).astype(np.float32)
    W1 = (rng.standard_normal((D + ENC, HIDDEN)) * np.sqrt(2 / (D + ENC))).astype(np.float32)
    b1 = np.zeros(HIDDEN, dtype=np.float32)
    W2 = (rng.standard_normal((HIDDEN, len(labels))) * np.sqrt(1 / HIDDEN)).astype(np.float32)
    b2 = np.zeros(len(labels), dtype=np.float32)
    params = [E, W1, b1, W2, b2]
    m = [np.zeros_like(p) for p in params]
    v = [np.zeros_like(p) for p in params]
    lr, B, step = 3e-3, 128, 0

    def evaluate(X, Y, EN=None):
        correct = 0
        for s in range(0, len(X), 1024):
            _, _, _, lg = forward(E, W1, b1, W2, b2, X[s:s + 1024], None if EN is None else EN[s:s + 1024])
            correct += int((lg.argmax(1) == Y[s:s + 1024]).sum())
        return correct / len(X)

    for epoch in range(4):
        order = rng.permutation(len(xs))
        for s in range(0, len(order), B):
            idx = order[s:s + B]
            batch = [xs[i] for i in idx]
            h0, z1, a1, lg = forward(E, W1, b1, W2, b2, batch, None if enc_tr is None else enc_tr[idx])
            p = np.exp(lg - lg.max(1, keepdims=True))
            p /= p.sum(1, keepdims=True)
            g = p
            g[np.arange(len(idx)), y[idx]] -= 1
            g /= len(idx)
            gW2 = a1.T @ g
            gb2 = g.sum(0)
            ga1 = g @ W2.T
            gz1 = ga1 * (z1 > 0)
            gW1 = h0.T @ gz1
            gb1 = gz1.sum(0)
            gh0 = gz1 @ W1[:D].T
            gE = np.zeros_like(E)
            for i, f in enumerate(batch):
                gE[f] += gh0[i] / len(f)
            step += 1
            for k, (pp, gg) in enumerate(zip(params, [gE, gW1, gb1, gW2, gb2])):
                m[k] = 0.9 * m[k] + 0.1 * gg
                v[k] = 0.999 * v[k] + 0.001 * gg * gg
                mh = m[k] / (1 - 0.9 ** step)
                vh = v[k] / (1 - 0.999 ** step)
                pp -= lr * mh / (np.sqrt(vh) + 1e-8)
        et = None if enc_tr is None else enc_tr[:20000]
        print(f"epoch {epoch + 1}: 訓練 {evaluate(xs[:20000], y[:20000], et):.4f}  沒看過的說法 {evaluate(hx, hyi, enc_ho):.4f}", flush=True)

    # 錯在哪
    _, _, _, lg = forward(E, W1, b1, W2, b2, hx, enc_ho)
    pred = lg.argmax(1)
    wrong = {}
    with open(ho, encoding="utf-8") as f:
        qs = [l.rstrip("\n").split("\t", 1)[1] for l in f]
    for q, a, b in zip(qs, hyi, pred):
        if a != b:
            wrong.setdefault(f"{labels[a]}→{labels[b]}", []).append(q)
    for k, v_ in sorted(wrong.items(), key=lambda kv: -len(kv[1]))[:15]:
        print(f"  {k}: {len(v_)}  例：{v_[:3]}")

    # 匯出：intent.json（題型、設定）＋ intent.bin（float32：E、W1、b1、W2、b2 依序）
    meta = {"format": "intent-f32-v1", "labels": labels, "buckets": BUCKETS, "dim": D, "hidden": HIDDEN, "ngram": list(NGRAM), "enc": ENC}
    with open(f"{out}/intent.json", "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False)
    with open(f"{out}/intent.bin", "wb") as f:
        for p_ in params:
            f.write(p_.astype("<f4").tobytes())
        if ENC:
            f.write(mu.astype("<f4").tobytes())
            f.write(sd.astype("<f4").tobytes())
    print("寫出", out, "大小", sum(p_.size for p_ in params) * 4 // 1024, "KB")


if __name__ == "__main__":
    main()
