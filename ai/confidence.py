# -*- coding: utf-8 -*-
"""校準「信心閘」：閒聊回覆的平均字元機率。聽得懂的話題機率高、亂問的話題機率低。
    python3 ai/confidence.py
"""
import numpy as np

from evaluate import load
from train import EOS, chat_prompt

ID = [("你好", None), ("你是誰", None), ("你會算命嗎", None), ("我好累", "感6|日6"), ("今天好累", "感6|日6"), ("謝謝你", None),
      ("我最近好煩", "感6|日3"), ("你今天心情怎樣", None), ("hello", None), ("who are you", None), ("I'm so tired", "en|感6"),
      ("hola", None), ("estoy triste", "es|感4"), ("ciao", None), ("sono stanco", "it|感6")]
OOD = ["請解釋量子力學的測不準原理", "幫我寫一首關於海的詩", "台灣的首都在哪裡", "怎麼煮義大利麵才不會黏", "how do I cook pasta without it sticking",
       "explain the theory of relativity", "cómo se hace una tortilla de patatas", "come si calcola l'IVA", "推薦一部好看的電影",
       "what is the capital of australia", "幫我翻譯這句話成日文", "python 的 list 和 tuple 差在哪"]


def mean_prob(model, tok, text, frame, rng, max_new=60):
    ids = chat_prompt(tok, text, frame)
    T = model.cfg["n_ctx"]
    ps = []
    for _ in range(max_new):
        logits, _ = model.forward(np.array([ids[-T:]]))
        z = logits[0, -1].astype(np.float64)
        full = np.exp(z - z.max()); full /= full.sum()
        z = z / 0.6
        z[np.argsort(z)[:-10]] = -np.inf
        pr = np.exp(z - z.max()); pr /= pr.sum()
        nxt = int(rng.choice(len(pr), p=pr))
        if nxt == EOS:
            break
        ps.append(full[nxt])
        ids.append(nxt)
    return float(np.mean(ps)) if ps else 0.0, tok.decode(ids[len(chat_prompt(tok, text, frame)):])


if __name__ == "__main__":
    model, tok = load()
    rng = np.random.default_rng(3)
    for name, items in (("聽得懂", ID), ("亂問", [(q, None) for q in OOD])):
        vals = []
        print("==", name)
        for q, f in items:
            p, out = mean_prob(model, tok, q, f, rng)
            vals.append(p)
            print(f"  {p:.2f}  {q[:28]:<28} → {out[:50]}")
        print(f"  平均 {np.mean(vals):.2f}  最小 {min(vals):.2f}  最大 {max(vals):.2f}")
