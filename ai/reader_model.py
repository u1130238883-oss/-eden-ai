# -*- coding: utf-8 -*-
"""
NineSun 的「大腦」：閱讀理解模型（純 NumPy，從零實作，不用任何預訓練權重、不接任何別的 AI）。

它學的是「方法」，不是答案：
  給一個問題和一段從來沒看過的文字，
    1. 判斷這段文字有沒有在回答這個問題（沒有就指向 [CLS]）
    2. 有的話，找出答案從第幾個字開始、到第幾個字結束

架構：雙向 Transformer 編碼器（Pre-LN），輸入 [CLS] 問題 [SEP] 段落 [SEP]，
每個位置輸出「答案從這裡開始」「答案到這裡結束」兩個分數。
Swift 端（ios/EchoCore/Reader）用完全相同的數學做推理。
"""
import json

import numpy as np

from echo_model import layernorm_fwd, layernorm_bwd, softmax, AdamW  # noqa: F401

SPECIALS = ["<pad>", "<unk>", "<cls>", "<sep>"]
PAD, UNK, CLS, SEP = range(4)


class ReaderTokenizer:
    """逐字分詞（中文一字一個，英文字母、數字也一個一個），英文一律小寫。"""

    def __init__(self, chars):
        self.itos = SPECIALS + sorted(chars)
        self.stoi = {c: i for i, c in enumerate(self.itos)}

    @property
    def vocab_size(self):
        return len(self.itos)

    @staticmethod
    def norm(s):
        return s.lower().replace("　", " ")

    def encode(self, s):
        return [self.stoi.get(c, UNK) for c in self.norm(s)]


class Reader:
    def __init__(self, vocab_size, n_ctx=256, n_embd=192, n_head=4, n_layer=4, seed=0):
        self.cfg = dict(vocab_size=vocab_size, n_ctx=n_ctx, n_embd=n_embd, n_head=n_head, n_layer=n_layer)
        rng = np.random.default_rng(seed)
        C = n_embd
        std = 0.02
        proj_std = 0.02 / np.sqrt(2 * n_layer)

        def w(*shape, s=std):
            return (rng.standard_normal(shape) * s).astype(np.float32)

        p = {"wte": w(vocab_size, C), "wpe": w(n_ctx, C), "wse": w(2, C)}
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
        p["w_span"] = w(C, 2)
        p["b_span"] = np.zeros(2, np.float32)
        self.p = p

    def num_params(self):
        return sum(v.size for v in self.p.values())

    # ---------------- forward
    def forward(self, idx, seg, cand, starts=None, ends=None):
        """idx: (B,T) token；seg: (B,T) 0=問題 1=段落；cand: (B,T) 可以當答案的位置（段落的字＋[CLS]）。
        有 starts/ends 就回傳 loss（並保留 cache 給 backward），沒有就回傳 (start_logits, end_logits)。"""
        p, cfg = self.p, self.cfg
        B, T = idx.shape
        C, H = cfg["n_embd"], cfg["n_head"]
        D = C // H
        scale = np.float32(1.0 / np.sqrt(D))
        # 雙向注意力：每個字都能看整段；只遮掉 <pad>
        kmask = np.where(idx == PAD, np.float32(-1e9), np.float32(0))[:, None, None, :]

        x = p["wte"][idx] + p["wpe"][:T] + p["wse"][seg]
        caches = []
        for l in range(cfg["n_layer"]):
            pre = f"h{l}."
            h, c_ln1 = layernorm_fwd(x, p[pre + "ln1_g"], p[pre + "ln1_b"])
            qkv = h @ p[pre + "w_qkv"] + p[pre + "b_qkv"]
            q, k, v = np.split(qkv, 3, axis=-1)
            q = q.reshape(B, T, H, D).transpose(0, 2, 1, 3)
            k = k.reshape(B, T, H, D).transpose(0, 2, 1, 3)
            v = v.reshape(B, T, H, D).transpose(0, 2, 1, 3)
            s = (q @ k.transpose(0, 1, 3, 2)) * scale + kmask
            a = softmax(s)
            y = (a @ v).transpose(0, 2, 1, 3).reshape(B, T, C)
            x = x + y @ p[pre + "w_o"] + p[pre + "b_o"]
            h2, c_ln2 = layernorm_fwd(x, p[pre + "ln2_g"], p[pre + "ln2_b"])
            f = h2 @ p[pre + "w_fc"] + p[pre + "b_fc"]
            g = np.maximum(f, 0)
            x = x + g @ p[pre + "w_proj"] + p[pre + "b_proj"]
            caches.append((h, c_ln1, q, k, v, a, y, h2, c_ln2, f, g))

        xf, c_lnf = layernorm_fwd(x, p["lnf_g"], p["lnf_b"])
        logits = xf @ p["w_span"] + p["b_span"]  # (B,T,2)
        neg = np.where(cand, np.float32(0), np.float32(-1e9))
        ls = logits[..., 0] + neg
        le = logits[..., 1] + neg
        if starts is None:
            return ls, le
        ps, pe = softmax(ls), softmax(le)
        rows = np.arange(B)
        loss = float(-(np.log(ps[rows, starts] + 1e-9) + np.log(pe[rows, ends] + 1e-9)).mean() / 2)
        ps[rows, starts] -= 1.0
        pe[rows, ends] -= 1.0
        dlog = np.stack([ps, pe], -1) / np.float32(2 * B)
        self._cache = (idx, seg, caches, xf, c_lnf, dlog)
        return loss

    # ---------------- backward（手推梯度）
    def backward(self):
        p, cfg = self.p, self.cfg
        idx, seg, caches, xf, c_lnf, dlog = self._cache
        B, T = idx.shape
        C, H = cfg["n_embd"], cfg["n_head"]
        D = C // H
        scale = np.float32(1.0 / np.sqrt(D))
        grads = {}
        grads["w_span"] = xf.reshape(-1, C).T @ dlog.reshape(-1, 2)
        grads["b_span"] = dlog.reshape(-1, 2).sum(0)
        dxf = dlog @ p["w_span"].T
        dx, grads["lnf_g"], grads["lnf_b"] = layernorm_bwd(dxf, c_lnf)

        for l in reversed(range(cfg["n_layer"])):
            pre = f"h{l}."
            h, c_ln1, q, k, v, a, y, h2, c_ln2, f, g = caches[l]
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

            do = dx
            grads[pre + "b_o"] = do.reshape(-1, C).sum(0)
            grads[pre + "w_o"] = y.reshape(-1, C).T @ do.reshape(-1, C)
            dy = (do @ p[pre + "w_o"].T).reshape(B, T, H, D).transpose(0, 2, 1, 3)
            da = dy @ v.transpose(0, 1, 3, 2)
            dv = a.transpose(0, 1, 3, 2) @ dy
            ds = a * (da - (da * a).sum(-1, keepdims=True)) * scale
            dq = ds @ k
            dk = ds.transpose(0, 1, 3, 2) @ q
            dqkv = np.concatenate([z.transpose(0, 2, 1, 3).reshape(B, T, C) for z in (dq, dk, dv)], axis=-1)
            grads[pre + "b_qkv"] = dqkv.reshape(-1, 3 * C).sum(0)
            grads[pre + "w_qkv"] = h.reshape(-1, C).T @ dqkv.reshape(-1, 3 * C)
            dh = dqkv @ p[pre + "w_qkv"].T
            dx1, grads[pre + "ln1_g"], grads[pre + "ln1_b"] = layernorm_bwd(dh, c_ln1)
            dx = dx + dx1

        grads["wpe"] = np.zeros_like(p["wpe"])
        grads["wpe"][:T] = dx.sum(0)
        grads["wse"] = np.zeros_like(p["wse"])
        np.add.at(grads["wse"], seg.reshape(-1), dx.reshape(-1, C))
        grads["wte"] = np.zeros_like(p["wte"])
        np.add.at(grads["wte"], idx.reshape(-1), dx.reshape(-1, C))
        return grads

    # ---------------- 匯出給 iOS
    def order(self):
        names = ["wte", "wpe", "wse"]
        for l in range(self.cfg["n_layer"]):
            names += [f"h{l}.{n}" for n in ("ln1_g", "ln1_b", "w_qkv", "b_qkv", "w_o", "b_o",
                                             "ln2_g", "ln2_b", "w_fc", "b_fc", "w_proj", "b_proj")]
        return names + ["lnf_g", "lnf_b", "w_span", "b_span"]

    def export(self, bin_path, json_path, tokenizer, extra=None):
        """權重存成 float16（檔案小一半），Swift 讀進來再轉回 float32。"""
        tensors, offset = [], 0
        with open(bin_path, "wb") as fh:
            for name in self.order():
                arr = np.ascontiguousarray(self.p[name], dtype="<f2")
                fh.write(arr.tobytes())
                tensors.append({"name": name, "shape": list(arr.shape), "offset": offset})
                offset += arr.size
        meta = {"format": "reader-f16-v1", "config": self.cfg, "vocab": tokenizer.itos,
                "specials": {"pad": PAD, "unk": UNK, "cls": CLS, "sep": SEP},
                "tensors": tensors, "num_params": int(self.num_params())}
        if extra:
            meta.update(extra)
        with open(json_path, "w", encoding="utf-8") as fh:
            json.dump(meta, fh, ensure_ascii=False)


def gradcheck():
    """用數值微分檢查手推的梯度對不對。"""
    rng = np.random.default_rng(1)
    m = Reader(30, n_ctx=12, n_embd=16, n_head=2, n_layer=2, seed=3)
    for k in m.p:
        m.p[k] = m.p[k].astype(np.float64)
    idx = rng.integers(4, 30, (2, 12)); idx[:, 0] = CLS; idx[:, 4] = SEP; idx[1, 10:] = PAD
    seg = np.zeros_like(idx); seg[:, 5:] = 1
    cand = seg.astype(bool) & (idx != PAD); cand[:, 0] = True
    st, en = np.array([6, 0]), np.array([8, 0])
    m.forward(idx, seg, cand, st, en)
    g = m.backward()
    worst = 0.0
    for name in ["wte", "h0.w_qkv", "h1.w_fc", "w_span", "wse", "h0.ln1_g"]:
        arr = m.p[name]
        for _ in range(4):
            i = tuple(rng.integers(0, s) for s in arr.shape)
            old = arr[i]
            arr[i] = old + 1e-5; lp = m.forward(idx, seg, cand, st, en)
            arr[i] = old - 1e-5; lm = m.forward(idx, seg, cand, st, en)
            arr[i] = old
            num = (lp - lm) / 2e-5
            worst = max(worst, abs(num - g[name][i]) / max(1e-6, abs(num) + abs(g[name][i])))
    return worst


if __name__ == "__main__":
    print("gradcheck worst relative error:", gradcheck())
