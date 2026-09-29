# -*- coding: utf-8 -*-
"""
NineSun 核心模型：從零實作的 decoder-only Transformer（純 NumPy）。

  - 不依賴 PyTorch / TensorFlow / 任何預訓練權重
  - 前向傳播、反向傳播（手推梯度）、AdamW 優化器全部手寫
  - 架構：Pre-LN GPT，學習式位置嵌入，權重共享的輸出層，ReLU 前饋

Swift 端（ios/EchoCore）用完全相同的數學做推理。
"""
import json

import numpy as np

try:  # 多執行緒的逐元素運算（可選；沒有就退回純 NumPy）
    import numexpr as ne
except ImportError:  # pragma: no cover
    ne = None

SPECIALS = ["<pad>", "<unk>", "<u>", "<a>", "<eos>", "<f>"]
PAD, UNK, USR, AST, EOS, FACT = range(6)


# ------------------------------------------------------------------ 分詞器
import re

# 拉丁字母單字（可帶一個前導空白）或任意單一字元；Swift 端用相同的 ICU 正規式
PRETOKEN = re.compile(r" ?[A-Za-z\u00C0-\u00FF']+|.", re.DOTALL)


class CharTokenizer:
    """混合分詞器：中文逐字；英文／西班牙文／義大利文的常用單字整個成為一個 token，其餘退回逐字。"""

    def __init__(self, chars, words=()):
        self.itos = SPECIALS + sorted(chars) + sorted(set(words) - set(chars))
        self.stoi = {c: i for i, c in enumerate(self.itos)}

    @property
    def vocab_size(self):
        return len(self.itos)

    def encode(self, s):
        out = []
        for m in PRETOKEN.finditer(s):
            piece = m.group(0)
            i = self.stoi.get(piece)
            if i is not None and len(piece) > 0:
                out.append(i)
            else:
                out.extend(self.stoi.get(c, UNK) for c in piece)
        return out

    def decode(self, ids):
        return "".join(self.itos[i] for i in ids if i >= len(SPECIALS))


def frequent_words(texts, min_count=4, limit=3000):
    """從外語語料挑出常用單字（含前導空白版本）。"""
    from collections import Counter
    c = Counter()
    for t in texts:
        for m in PRETOKEN.finditer(t):
            w = m.group(0)
            if len(w.strip()) >= 2:
                c[w] += 1
    return [w for w, n in c.most_common(limit) if n >= min_count]


# ------------------------------------------------------------------ 基本算子
def layernorm_fwd(x, g, b, eps=1e-5):
    mu = x.mean(-1, keepdims=True)
    xc = x - mu
    var = (xc * xc).mean(-1, keepdims=True)
    rstd = 1.0 / np.sqrt(var + eps)
    xhat = xc * rstd
    return xhat * g + b, (xhat, rstd, g)


def layernorm_bwd(dy, cache):
    xhat, rstd, g = cache
    dg = (dy * xhat).reshape(-1, xhat.shape[-1]).sum(0)
    db = dy.reshape(-1, dy.shape[-1]).sum(0)
    dxhat = dy * g
    dx = rstd * (dxhat - dxhat.mean(-1, keepdims=True)
                 - xhat * (dxhat * xhat).mean(-1, keepdims=True))
    return dx, dg, db


def softmax(x):
    m = x.max(-1, keepdims=True)
    if ne is not None:
        e = ne.evaluate("exp(x - m)")
        ssum = e.sum(-1, keepdims=True)
        return ne.evaluate("e / ssum")
    e = np.exp(x - m)
    return e / e.sum(-1, keepdims=True)


# ------------------------------------------------------------------ 模型
class EchoGPT:
    def __init__(self, vocab_size, n_ctx=128, n_embd=128, n_head=4, n_layer=4, seed=0):
        self.cfg = dict(vocab_size=vocab_size, n_ctx=n_ctx, n_embd=n_embd,
                        n_head=n_head, n_layer=n_layer)
        rng = np.random.default_rng(seed)
        C = n_embd
        std = 0.02
        proj_std = 0.02 / np.sqrt(2 * n_layer)

        def w(*shape, s=std):
            return (rng.standard_normal(shape) * s).astype(np.float32)

        p = {"wte": w(vocab_size, C), "wpe": w(n_ctx, C)}
        for l in range(n_layer):
            p[f"h{l}.ln1_g"] = np.ones(C, np.float32)
            p[f"h{l}.ln1_b"] = np.zeros(C, np.float32)
            p[f"h{l}.w_qkv"] = w(C, 3 * C)
            p[f"h{l}.b_qkv"] = np.zeros(3 * C, np.float32)
            p[f"h{l}.w_o"] = w(C, C, s=proj_std)
            p[f"h{l}.b_o"] = np.zeros(C, np.float32)
            p[f"h{l}.ln2_g"] = np.ones(C, np.float32)
            p[f"h{l}.ln2_b"] = np.zeros(C, np.float32)
            p[f"h{l}.w_fc"] = w(C, 4 * C)
            p[f"h{l}.b_fc"] = np.zeros(4 * C, np.float32)
            p[f"h{l}.w_proj"] = w(4 * C, C, s=proj_std)
            p[f"h{l}.b_proj"] = np.zeros(C, np.float32)
        p["lnf_g"] = np.ones(C, np.float32)
        p["lnf_b"] = np.zeros(C, np.float32)
        self.p = p

    def num_params(self):
        return sum(v.size for v in self.p.values())

    # ---------------- forward（保留 cache 供反向傳播）
    def forward(self, idx, targets=None, weights=None):
        p, cfg = self.p, self.cfg
        B, T = idx.shape
        C, H = cfg["n_embd"], cfg["n_head"]
        D = C // H
        scale = np.float32(1.0 / np.sqrt(D))
        mask = np.triu(np.full((T, T), -1e9, dtype=p["wte"].dtype), 1)

        x = p["wte"][idx] + p["wpe"][:T]
        caches = []
        for l in range(cfg["n_layer"]):
            pre = f"h{l}."
            h, c_ln1 = layernorm_fwd(x, p[pre + "ln1_g"], p[pre + "ln1_b"])
            qkv = h @ p[pre + "w_qkv"] + p[pre + "b_qkv"]
            q, k, v = np.split(qkv, 3, axis=-1)
            q = q.reshape(B, T, H, D).transpose(0, 2, 1, 3)
            k = k.reshape(B, T, H, D).transpose(0, 2, 1, 3)
            v = v.reshape(B, T, H, D).transpose(0, 2, 1, 3)
            s = (q @ k.transpose(0, 1, 3, 2)) * scale + mask
            a = softmax(s)
            y = (a @ v).transpose(0, 2, 1, 3).reshape(B, T, C)
            x = x + y @ p[pre + "w_o"] + p[pre + "b_o"]

            h2, c_ln2 = layernorm_fwd(x, p[pre + "ln2_g"], p[pre + "ln2_b"])
            f = h2 @ p[pre + "w_fc"] + p[pre + "b_fc"]
            g = np.maximum(f, 0)
            x = x + g @ p[pre + "w_proj"] + p[pre + "b_proj"]
            caches.append((h, c_ln1, q, k, v, a, y, h2, c_ln2, f, g))

        xf, c_lnf = layernorm_fwd(x, p["lnf_g"], p["lnf_b"])
        if targets is None:
            self._cache = (idx, caches, xf, c_lnf)
            return xf @ p["wte"].T, None

        # 只在有權重（AI 回覆）的位置計算輸出層，省下大部分 softmax
        wts = weights.reshape(-1)
        sel = np.nonzero(wts > 0)[0]
        xsel = xf.reshape(-1, C)[sel]
        flat = softmax(xsel @ p["wte"].T)
        tgt = targets.reshape(-1)[sel]
        w = wts[sel].astype(xf.dtype)
        norm = max(float(w.sum()), 1.0)
        rows = np.arange(sel.size)
        nll = -np.log(flat[rows, tgt] + 1e-9)
        loss = float((nll * w).sum() / norm)
        flat[rows, tgt] -= 1.0
        flat *= (w / norm)[:, None]
        self._cache = (idx, caches, xf, c_lnf)
        self._dlogits = (sel, xsel, flat)
        return None, loss

    # ---------------- backward（手推梯度）
    def backward(self):
        p, cfg = self.p, self.cfg
        idx, caches, xf, c_lnf = self._cache
        sel, xsel, dlogits = self._dlogits
        B, T = idx.shape
        C, H = cfg["n_embd"], cfg["n_head"]
        D = C // H
        scale = np.float32(1.0 / np.sqrt(D))
        grads = {k: np.zeros_like(v) for k, v in p.items()}

        # logits = xf @ wte.T
        grads["wte"] += dlogits.T @ xsel
        dxf = np.zeros((B * T, C), dtype=xf.dtype)
        dxf[sel] = dlogits @ p["wte"]
        dxf = dxf.reshape(B, T, C)
        dx, grads["lnf_g"], grads["lnf_b"] = layernorm_bwd(dxf, c_lnf)

        for l in reversed(range(cfg["n_layer"])):
            pre = f"h{l}."
            h, c_ln1, q, k, v, a, y, h2, c_ln2, f, g = caches[l]

            # MLP 殘差
            dm = dx
            grads[pre + "b_proj"] = dm.reshape(-1, C).sum(0)
            grads[pre + "w_proj"] = g.reshape(-1, 4 * C).T @ dm.reshape(-1, C)
            dg = dm @ p[pre + "w_proj"].T
            df = dg * (f > 0)
            grads[pre + "b_fc"] = df.reshape(-1, 4 * C).sum(0)
            grads[pre + "w_fc"] = h2.reshape(-1, C).T @ df.reshape(-1, 4 * C)
            dh2 = df @ p[pre + "w_fc"].T
            dx2, grads[pre + "ln2_g"], grads[pre + "ln2_b"] = layernorm_bwd(dh2, c_ln2)
            dx = dx + dx2

            # 注意力殘差
            do = dx
            grads[pre + "b_o"] = do.reshape(-1, C).sum(0)
            grads[pre + "w_o"] = y.reshape(-1, C).T @ do.reshape(-1, C)
            dy = (do @ p[pre + "w_o"].T).reshape(B, T, H, D).transpose(0, 2, 1, 3)
            da = dy @ v.transpose(0, 1, 3, 2)
            dv = a.transpose(0, 1, 3, 2) @ dy
            ds = a * (da - (da * a).sum(-1, keepdims=True)) * scale
            dq = ds @ k
            dk = ds.transpose(0, 1, 3, 2) @ q
            dqkv = np.concatenate([
                z.transpose(0, 2, 1, 3).reshape(B, T, C) for z in (dq, dk, dv)
            ], axis=-1)
            grads[pre + "b_qkv"] = dqkv.reshape(-1, 3 * C).sum(0)
            grads[pre + "w_qkv"] = h.reshape(-1, C).T @ dqkv.reshape(-1, 3 * C)
            dh = dqkv @ p[pre + "w_qkv"].T
            dx1, grads[pre + "ln1_g"], grads[pre + "ln1_b"] = layernorm_bwd(dh, c_ln1)
            dx = dx + dx1

        grads["wpe"][:T] += dx.sum(0)
        np.add.at(grads["wte"], idx.reshape(-1), dx.reshape(-1, C))
        return grads

    # ---------------- 匯出給 iOS 端的二進位權重
    def export(self, bin_path, json_path, tokenizer, extra=None):
        order = ["wte", "wpe"]
        for l in range(self.cfg["n_layer"]):
            order += [f"h{l}.{n}" for n in ("ln1_g", "ln1_b", "w_qkv", "b_qkv", "w_o", "b_o",
                                             "ln2_g", "ln2_b", "w_fc", "b_fc", "w_proj", "b_proj")]
        order += ["lnf_g", "lnf_b"]
        tensors, offset = [], 0
        with open(bin_path, "wb") as fh:
            for name in order:
                arr = np.ascontiguousarray(self.p[name], dtype="<f4")
                fh.write(arr.tobytes())
                tensors.append({"name": name, "shape": list(arr.shape), "offset": offset})
                offset += arr.size
        meta = {"format": "echo0-f32-v1", "config": self.cfg, "vocab": tokenizer.itos,
                "specials": {"pad": PAD, "unk": UNK, "user": USR, "assistant": AST, "eos": EOS, "fact": FACT},
                "tensors": tensors, "num_params": int(self.num_params())}
        if extra:
            meta.update(extra)
        with open(json_path, "w", encoding="utf-8") as fh:
            json.dump(meta, fh, ensure_ascii=False)


class AdamW:
    def __init__(self, params, lr=3e-3, betas=(0.9, 0.98), eps=1e-8, wd=0.01):
        self.lr, self.b1, self.b2, self.eps, self.wd = lr, betas[0], betas[1], eps, wd
        self.m = {k: np.zeros_like(v) for k, v in params.items()}
        self.v = {k: np.zeros_like(v) for k, v in params.items()}
        self.t = 0

    def step(self, params, grads, lr):
        self.t += 1
        b1c = 1 - self.b1 ** self.t
        b2c = 1 - self.b2 ** self.t
        for k, g in grads.items():
            self.m[k] = self.b1 * self.m[k] + (1 - self.b1) * g
            self.v[k] = self.b2 * self.v[k] + (1 - self.b2) * g * g
            upd = (self.m[k] / b1c) / (np.sqrt(self.v[k] / b2c) + self.eps)
            if params[k].ndim == 2:
                upd = upd + self.wd * params[k]
            params[k] -= (lr * upd).astype(np.float32)
