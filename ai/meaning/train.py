# -*- coding: utf-8 -*-
"""意思比對模型（NineSun 自己的、從零訓練）：
句子 → [閱讀模型讀出來的意思 512 維] + [字的片段 1～3 字，雜湊到 16384 格] → 隱藏層 128（tanh）→ 每個條目一個分數（softmax）。
第二層（監督微調）：知識庫每個條目的很多種問法 → 條目。
第三層（可驗證獎勵）：用模型自己去答訓練題，對錯可以自動判定；答錯的題加重再練（幾輪）。
純 NumPy、手寫反向傳播、Adam。Swift 端（MeaningMatch.swift）用一模一樣的數學。"""
import sys, json, numpy as np
B = 1 << 14; H = 128
def fnv1a(s):
    h = 0x811C9DC5
    for b in s.encode('utf-8'):
        h ^= b; h = (h * 0x01000193) & 0xFFFFFFFF
    return h
def normalize(q):
    q = q.strip().lower()
    for ch in "？?！!。，,、～~ ": q = q.replace(ch, "")
    return q
def features(q):
    t = "^" + normalize(q) + "$"
    out = set()
    for n in (1, 2, 3):
        for i in range(len(t) - n + 1): out.add(fnv1a(t[i:i + n]) % B)
    return sorted(out)

class Model:
    def __init__(s, K, rng):
        s.Wm = (rng.standard_normal((512, H)) * 0.02).astype(np.float32)
        s.E = (rng.standard_normal((B, H)) * 0.02).astype(np.float32)
        s.b = np.zeros(H, np.float32)
        s.P = (rng.standard_normal((K, H)) * 0.05).astype(np.float32)
        s.c = np.zeros(K, np.float32)
        s.dense = ['Wm', 'b', 'P', 'c']
        s.m = {k: np.zeros_like(getattr(s, k)) for k in s.dense}; s.v = {k: np.zeros_like(getattr(s, k)) for k in s.dense}
        s.G = np.zeros(B, np.float32) + 1e-8   # Adagrad for E rows
        s.t = 0
    def hidden(s, M, F):
        z = M @ s.Wm + s.b
        for i, f in enumerate(F): z[i] += s.E[f].sum(0) / np.sqrt(len(f))
        return np.tanh(z)
    def forward(s, M, F):
        h = s.hidden(M, F); return h, h @ s.P.T + s.c
    def step(s, M, F, y, w, lr=2e-3, elr=0.05, wd=1e-5):
        h, lg = s.forward(M, F)
        lg = lg - lg.max(1, keepdims=True); p = np.exp(lg); p /= p.sum(1, keepdims=True)
        n = len(y); loss = -(w * np.log(p[np.arange(n), y] + 1e-9)).sum() / w.sum()
        d = p; d[np.arange(n), y] -= 1; d *= (w / w.sum())[:, None]
        g = {'P': d.T @ h, 'c': d.sum(0)}
        dh = d @ s.P; dz = dh * (1 - h * h)
        g['Wm'] = M.T @ dz; g['b'] = dz.sum(0)
        s.t += 1
        for k in s.dense:
            gk = g[k] + wd * getattr(s, k)
            s.m[k] = 0.9 * s.m[k] + 0.1 * gk; s.v[k] = 0.999 * s.v[k] + 0.001 * gk * gk
            mh = s.m[k] / (1 - 0.9 ** s.t); vh = s.v[k] / (1 - 0.999 ** s.t)
            setattr(s, k, getattr(s, k) - lr * mh / (np.sqrt(vh) + 1e-8))
        for i, f in enumerate(F):
            gr = dz[i] / np.sqrt(len(f))
            s.G[f] += (gr * gr).mean()
            s.E[f] -= elr * gr / np.sqrt(s.G[f])[:, None]
        return loss

def load(prefix):
    qs = open(prefix + '.txt', encoding='utf-8').read().split('\n'); M = np.load(prefix + '.npy')
    return {q: M[i] for i, q in enumerate(qs)}

if __name__ == '__main__':
    work = sys.argv[1]
    rows = [l.rstrip('\n').split('\t') for l in open(work + '/train.tsv', encoding='utf-8') if l.strip()]
    enc = load(work + '/train_enc')
    labels = sorted({r[0] for r in rows}); li = {l: i for i, l in enumerate(labels)}
    X = [(enc[q], features(q), li[l]) for l, q in rows]
    rng = np.random.default_rng(1); model = Model(len(labels), rng)
    w = np.ones(len(X), np.float32)
    def run(epochs, tag):
        for ep in range(epochs):
            order = rng.permutation(len(X)); tot = 0; nb = 0
            for s0 in range(0, len(X), 256):
                idx = order[s0:s0 + 256]
                M = np.stack([X[i][0] for i in idx]); F = [X[i][1] for i in idx]; y = np.array([X[i][2] for i in idx]); ww = w[idx]
                tot += model.step(M, F, y, ww); nb += 1
            print(tag, 'epoch', ep, 'loss %.3f' % (tot / nb), flush=True)
    def reward():
        """可驗證的獎勵：每一題模型挑的條目對不對（自動判定）"""
        ok = np.zeros(len(X), bool)
        for s0 in range(0, len(X), 1024):
            sl = range(s0, min(len(X), s0 + 1024))
            _, lg = model.forward(np.stack([X[i][0] for i in sl]), [X[i][1] for i in sl])
            ok[s0:s0 + len(sl)] = lg.argmax(1) == np.array([X[i][2] for i in sl])
        return ok
    run(int(sys.argv[2]) if len(sys.argv) > 2 else 6, 'SFT')
    for r in range(int(sys.argv[3]) if len(sys.argv) > 3 else 3):
        ok = reward()
        print('RL round', r, 'reward (train acc) %.4f' % ok.mean(), 'wrong', (~ok).sum(), flush=True)
        w = np.where(ok, 1.0, 4.0).astype(np.float32)   # 答錯的加重
        run(2, 'RL%d' % r)
    print('final reward %.4f' % reward().mean())
    np.savez(work + '/model.npz', Wm=model.Wm, E=model.E, b=model.b, P=model.P, c=model.c)
    json.dump(labels, open(work + '/labels.json', 'w', encoding='utf-8'), ensure_ascii=False)
