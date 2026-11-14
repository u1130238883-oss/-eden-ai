# -*- coding: utf-8 -*-
"""
訓練 NineSun 並匯出權重到 iOS App。

    python3 ai/train.py --steps 4000

輸出：
    ios/NineSun/Resources/ninesun.bin   權重（float32）
    ios/NineSun/Resources/ninesun.json  設定 + 字表
    ios/EchoCore/Tests/EchoCoreTests/Fixtures/reference.json  Swift 對齊測試用
"""
import argparse
import json
import math
import os
import random
import time

import numpy as np

from corpus import all_chars, dialog_pairs
from echo_model import AST, EOS, FACT, USR, AdamW, CharTokenizer, EchoGPT
from fortune_corpus import fortune_chars, fortune_pairs
from mantic_corpus import knowledge_pairs, mantic_chars, mantic_pairs, obey_pairs
from palace_core import core_chars, core_pairs, lens_pairs
from multilingual_corpus import foreign_pairs, foreign_texts
from echo_model import frequent_words

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def build_stream(tok, n_rounds, seed):
    """把大量隨機對話拼成一條 token 流，並標記哪些位置是 AI 的回覆（只對這些計算 loss）。
    命理樣本會在用戶訊息後附上事實框 <f>（由九型十二宮引擎算出）。"""
    rng = random.Random(seed)
    ids, is_reply = [], []
    for _ in range(n_rounds):
        # 一般對話也經過十二宮感知：帶「感{宮}」認知框
        pairs = (lens_pairs(dialog_pairs(rng), rng) + fortune_pairs(rng) + core_pairs(rng)
                 + mantic_pairs(rng, 6) + knowledge_pairs(rng, 12) + obey_pairs(rng)
                 + foreign_pairs(rng))
        rng.shuffle(pairs)
        for u, f, r in pairs:
            seg_u = chat_prompt(tok, u, f)
            seg_r = tok.encode(r) + [EOS]
            ids += seg_u + seg_r
            is_reply += [0] * len(seg_u) + [1] * len(seg_r)
    return np.array(ids, np.int64), np.array(is_reply, np.float32)


def get_batch(ids, is_reply, B, T, rng):
    ix = rng.integers(0, len(ids) - T - 1, B)
    x = np.stack([ids[i:i + T] for i in ix])
    y = np.stack([ids[i + 1:i + T + 1] for i in ix])
    w = np.stack([is_reply[i + 1:i + T + 1] for i in ix])
    return x, y, w


def generate(model, tok, prompt_ids, max_new=80, temperature=0.0, top_k=0, rng=None):
    ids = list(prompt_ids)
    T = model.cfg["n_ctx"]
    out = []
    for _ in range(max_new):
        ctx = np.array([ids[-T:]])
        logits, _ = model.forward(ctx)
        z = logits[0, -1].astype(np.float64)
        if temperature <= 0:
            nxt = int(z.argmax())
        else:
            z = z / temperature
            if top_k:
                z[np.argsort(z)[:-top_k]] = -np.inf
            pr = np.exp(z - z.max())
            pr /= pr.sum()
            nxt = int(rng.choice(len(pr), p=pr))
        if nxt == EOS:
            break
        ids.append(nxt)
        out.append(nxt)
    return out


def chat_prompt(tok, text, frame=None):
    ids = [USR] + tok.encode(text)
    if frame:
        ids += [FACT] + tok.encode(frame)
    return ids + [AST]


def export_all(model, tok, extra=None):
    """匯出權重到 iOS，並產生 Swift 對齊測試的參考數據。"""
    res = os.path.join(ROOT, "ios", "NineSun", "Resources")
    os.makedirs(res, exist_ok=True)
    model.export(os.path.join(res, "ninesun.bin"), os.path.join(res, "ninesun.json"), tok, extra=extra)

    # ---- Swift 端對齊測試的參考數據
    fx = os.path.join(ROOT, "ios", "EchoCore", "Tests", "EchoCoreTests", "Fixtures")
    os.makedirs(fx, exist_ok=True)
    refs = []
    for t, f in [("你好", None), ("你是誰", None), ("今年運勢", "流年|2026|8宮壞9因2|引3,9"),
                 ("我的八字", "八字|庚午辛巳乙酉庚辰|日主乙木|身弱|喜水木"), ("算一卦", "卦|50鼎|變56旅|動2"),
                 ("今天好累", "感6|日6"), ("today's fortune", "en|今日|日5|夜3"), ("hola", None),
                 ("il mio tema", "it|命盤|命8|型8|8宮好9因5")]:
        prompt = chat_prompt(tok, t, f)
        logits, _ = model.forward(np.array([prompt]))
        refs.append({"prompt": t, "frame": f, "prompt_ids": prompt,
                     "last_logits_head": [float(v) for v in logits[0, -1, :16]],
                     "greedy_ids": generate(model, tok, prompt, max_new=40)})
    with open(os.path.join(fx, "reference.json"), "w", encoding="utf-8") as fh:
        json.dump(refs, fh, ensure_ascii=False, indent=1)
    print("exported.")


def make_tokenizer():
    """中文逐字 + 外語常用單字。字表由語料決定，Python 與 Swift 共用 ninesun.json 裡的字表。"""
    ft = foreign_texts()
    chars = all_chars() | fortune_chars() | mantic_chars() | core_chars()
    for s in ft:
        chars.update(s)
    return CharTokenizer(chars, frequent_words(ft, min_count=5, limit=1500))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", type=int, default=4000)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--ctx", type=int, default=224)
    ap.add_argument("--embd", type=int, default=256)
    ap.add_argument("--heads", type=int, default=8)
    ap.add_argument("--layers", type=int, default=4)
    ap.add_argument("--lr", type=float, default=2e-3)
    ap.add_argument("--seed", type=int, default=1337)
    ap.add_argument("--rounds", type=int, default=360)
    ap.add_argument("--ckpt", default=os.path.join(ROOT, "ai", "ckpt.npz"))
    args = ap.parse_args()

    tok = make_tokenizer()
    ids, is_reply = build_stream(tok, n_rounds=args.rounds, seed=args.seed)
    print(f"vocab={tok.vocab_size} tokens={len(ids)}")

    model = EchoGPT(tok.vocab_size, n_ctx=args.ctx, n_embd=args.embd,
                    n_head=args.heads, n_layer=args.layers, seed=args.seed)
    print(f"params={model.num_params():,}")
    opt = AdamW(model.p, wd=0.01)
    rng = np.random.default_rng(args.seed)
    start = 1
    if os.path.exists(args.ckpt):
        ck = np.load(args.ckpt)
        for k in model.p:
            model.p[k] = ck["p." + k]
            opt.m[k] = ck["m." + k]
            opt.v[k] = ck["v." + k]
        opt.t = int(ck["t"])
        start = opt.t + 1
        print(f"resumed from step {opt.t}")
    warmup = 200
    t0 = time.time()
    ema = None
    for step in range(start, args.steps + 1):
        lr = args.lr * min(1.0, step / warmup) * (0.1 + 0.9 * 0.5 * (1 + math.cos(math.pi * step / args.steps)))
        x, y, w = get_batch(ids, is_reply, args.batch, args.ctx, rng)
        _, loss = model.forward(x, y, w)
        grads = model.backward()
        gnorm = math.sqrt(sum(float((g * g).sum()) for g in grads.values()))
        if gnorm > 1.0:
            for g in grads.values():
                g *= 1.0 / gnorm
        opt.step(model.p, grads, lr)
        ema = loss if ema is None else 0.98 * ema + 0.02 * loss
        if step % 100 == 0 or step == 1:
            print(f"step {step:5d}  loss {ema:.4f}  lr {lr:.2e}  {time.time() - t0:.0f}s", flush=True)
        if step % 250 == 0:
            blob = {"t": np.array(opt.t)}
            for k in model.p:
                blob["p." + k], blob["m." + k], blob["v." + k] = model.p[k], opt.m[k], opt.v[k]
            np.savez(args.ckpt + ".tmp.npz", **blob)
            os.replace(args.ckpt + ".tmp.npz", args.ckpt)

    # ---- 試跑
    tests = [("today's fortune", "en|今日|日5|夜3"), ("I am so tired", "en|感6"), ("hola", None),
             ("sono stanco", "it|感6|日6"), ("cast a hexagram", "en|卦|50鼎|變56旅|動2"),
             ("mi bazi", "es|八字|庚午辛巳乙酉庚辰|日主乙木|身弱|喜水木"), ("who are you", None),
             ("今天好累", "感6|日6"), ("我好焦慮", "感4"), ("你是幾型", "我|型3"), ("我的畫像", "畫像|10,6|型3"),
             ("我的八字", "八字|庚午辛巳乙酉庚辰|日主乙木|身弱|喜水木"), ("算一卦", "卦|50鼎|變56旅|動2"),
             ("紫微斗數", "紫微|命宮申|天同、天梁化權|身宮子|水二局"), ("照我說的做", None), ("什麼是七殺", None),
             ("你好", None), ("你是誰", None), ("我好累", None), ("講個笑話", None),
             ("你會算命嗎", None), ("5宮是什麼", None), ("第3型是什麼", None), ("好7因3是什麼意思", None),
             ("今天運勢", "今日|日5|夜3"), ("今年運勢", "流年|2026|8宮壞9因2|引3,9"),
             ("我的大運", "大運|2019-2027|3宮壞12因7"), ("我是幾型", "九型|5"),
             ("我的命盤", "無生日"), ("我跟2001年3月4日的人合不合", "合盤|命7|好4正2壞6")]
    for t, f in tests:
        print(f"> {t} {f or ''}\n  {tok.decode(generate(model, tok, chat_prompt(tok, t, f), max_new=200))}")

    export_all(model, tok, extra={"trained_steps": args.steps, "final_loss": round(ema, 4)})


if __name__ == "__main__":
    main()
