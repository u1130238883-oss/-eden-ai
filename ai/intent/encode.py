# -*- coding: utf-8 -*-
"""用 NineSun 自己預先讀過大量中文的閱讀模型（reader.bin）把一句話變成「意思」：
輸入 [CLS] 句子 [SEP]，取最後一層的 [CLS] 向量和所有字的平均，接起來是 512 維。
看過很多文章的模型知道「怎麼一回事」和「是什麼」意思相近，所以理解問題的模型可以用這個意思來類推沒看過的說法。
數學跟 Swift 的 Brain.logits 一模一樣（float32、LayerNorm eps 1e-5、權重 [輸入, 輸出]）。

用法：python3 ai/intent/encode.py reader.json reader.bin 輸入.tsv 輸出.npy
"""
import json
import sys

import numpy as np


class Encoder:
    def __init__(self, meta_path, bin_path):
        m = json.load(open(meta_path, encoding="utf-8"))
        self.cfg = m["config"]
        raw = np.fromfile(bin_path, dtype="<f2").astype(np.float32)
        self.t = {t["name"]: raw[t["offset"]:t["offset"] + int(np.prod(t["shape"]))].reshape(t["shape"]) for t in m["tensors"]}
        self.stoi = {}
        for i, s in enumerate(m["vocab"]):
            self.stoi.setdefault(s, i)
        self.unk, self.cls, self.sep = m["specials"]["unk"], m["specials"]["cls"], m["specials"]["sep"]
        self.q_max = m.get("q_max", 48)

    @staticmethod
    def norm(s):
        out = []
        for u in s:
            if u == "　":
                out.append(" ")
                continue
            low = u.lower()
            out.append(low if len(low) == 1 else u)
        return out

    @staticmethod
    def ln(x, g, b):
        mu = x.mean(-1, keepdims=True)
        v = ((x - mu) ** 2).mean(-1, keepdims=True)
        return (x - mu) / np.sqrt(v + 1e-5) * g + b

    def encode(self, q):
        chars = self.norm(q)[: self.q_max]
        ids = [self.cls] + [self.stoi.get(c, self.unk) for c in chars] + [self.sep]
        T, C, H = len(ids), self.cfg["n_embd"], self.cfg["n_head"]
        D = C // H
        t = self.t
        x = t["wte"][ids] + t["wpe"][:T] + t["wse"][0] + t["wme"][0]
        for l in range(self.cfg["n_layer"]):
            p = f"h{l}."
            h = self.ln(x, t[p + "ln1_g"], t[p + "ln1_b"])
            qkv = h @ t[p + "w_qkv"] + t[p + "b_qkv"]
            q_, k_, v_ = qkv[:, :C], qkv[:, C:2 * C], qkv[:, 2 * C:]
            y = np.zeros_like(x)
            for hd in range(H):
                sl = slice(hd * D, (hd + 1) * D)
                a = (q_[:, sl] / np.sqrt(D)) @ k_[:, sl].T
                a = np.exp(a - a.max(1, keepdims=True))
                a /= a.sum(1, keepdims=True)
                y[:, sl] = a @ v_[:, sl]
            x = x + y @ t[p + "w_o"] + t[p + "b_o"]
            h2 = self.ln(x, t[p + "ln2_g"], t[p + "ln2_b"])
            f = np.maximum(h2 @ t[p + "w_fc"] + t[p + "b_fc"], 0)
            x = x + f @ t[p + "w_proj"] + t[p + "b_proj"]
        xf = self.ln(x, t["lnf_g"], t["lnf_b"])
        body = xf[1:-1] if T > 2 else xf[:1]
        return np.concatenate([xf[0], body.mean(0)]).astype(np.float32)


def main():
    meta, binp, inp, out = sys.argv[1:5]
    enc = Encoder(meta, binp)
    qs = [line.rstrip("\n").split("\t", 1)[1] for line in open(inp, encoding="utf-8")]
    # 同一句只算一次
    uniq = {q: None for q in qs}
    for i, q in enumerate(uniq):
        uniq[q] = enc.encode(q)
        if i % 20000 == 0:
            print(i, "/", len(uniq), flush=True)
    np.save(out, np.stack([uniq[q] for q in qs]))
    print("寫出", out, len(qs))


if __name__ == "__main__":
    main()
