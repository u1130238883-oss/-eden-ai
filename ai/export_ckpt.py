# -*- coding: utf-8 -*-
"""從訓練中的 checkpoint 匯出權重（不用等訓練結束就能先建置 App）。"""
import numpy as np

from echo_model import EchoGPT
from train import ROOT, export_all, make_tokenizer

import os

ck = np.load(os.path.join(ROOT, "ai", "ckpt.npz"))
tok = make_tokenizer()
C = ck["p.wte"].shape[1]
model = EchoGPT(tok.vocab_size, n_ctx=ck["p.wpe"].shape[0], n_embd=C, n_head=C // 32,
                n_layer=sum(1 for k in ck.files if k.startswith("p.h") and k.endswith(".ln1_g")))
for k in model.p:
    model.p[k] = ck["p." + k]
export_all(model, tok, extra={"trained_steps": int(ck["t"]), "checkpoint": True})
print("step", int(ck["t"]))
