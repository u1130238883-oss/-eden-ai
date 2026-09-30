# -*- coding: utf-8 -*-
"""
訓練 NineSun 的閱讀理解大腦。

教材：DRCD（台達閱讀理解資料集，台灣維基百科的文章＋問題＋答案在文中的位置）。
它不會記住這些答案（考試時用的是完全沒看過的文章），學到的是：
  看懂問題 → 在文章裡找到在回答它的地方 → 沒有就說沒有。

用法：
  python3 train_reader.py --data DIR --out DIR [--hours 3]
"""
import argparse
import json
import os
import random
import time
from collections import Counter

import numpy as np

from reader_model import Reader, ReaderTokenizer, AdamW, PAD, CLS, SEP, match_features

PUNCT = set("，。、；：？！「」『』（）()《》〈〉,.;:?!\"' \n-—…·")

T_CTX = 256
Q_MAX = 48


def load_squad(path):
    data = json.load(open(path, encoding="utf-8"))["data"]
    out = []  # (context, question, answer_text, answer_start)
    for art in data:
        for para in art["paragraphs"]:
            ctx = para["context"]
            for qa in para["qas"]:
                ans = qa["answers"][0] if qa.get("answers") else None
                out.append((ctx, qa["question"], ans["text"] if ans else "", ans["answer_start"] if ans else -1))
    return out


def build_vocab(samples, min_count=2):
    c = Counter()
    for ctx, q, _, _ in samples:
        c.update(ReaderTokenizer.norm(ctx))
        c.update(ReaderTokenizer.norm(q))
    return ReaderTokenizer([ch for ch, n in c.items() if n >= min_count and ch not in ("\n",)])


def windows(tok, q, ctx):
    """把長文章切成一段段（有重疊），每段配上問題。回傳 [(ids, seg, cand, offset)]。"""
    qi = tok.encode(q)[:Q_MAX]
    ci = tok.encode(ctx)
    L = T_CTX - 3 - len(qi)
    stride = max(L // 2, 1)
    out = []
    start = 0
    while True:
        piece = ci[start:start + L]
        ids = [CLS] + qi + [SEP] + piece + [SEP]
        mq, mp = match_features(qi, piece, tok.punct_ids)
        mat = [0] + mq + [0] + mp + [0]
        seg = [0] * (len(qi) + 2) + [1] * (len(piece) + 1)
        pad = T_CTX - len(ids)
        cand = [True] + [False] * (len(qi) + 1) + [True] * len(piece) + [False] + [False] * pad
        out.append((ids + [PAD] * pad, seg + [1] * pad, cand, start, len(qi) + 2, len(piece), mat + [0] * pad))
        if start + L >= len(ci):
            break
        start += stride
    return out


def featurize(tok, samples, neg_keep=0.3, rand_neg=0.3, seed=0):
    rng = random.Random(seed)
    ctxs = list({s[0] for s in samples})
    X, S, M, ST, EN, MT = [], [], [], [], [], []
    for ctx, q, a, a0 in samples:
        if a0 < 0:
            continue
        a1 = a0 + len(a) - 1
        # 答案位置對不上原文的（資料錯誤）就跳過
        if ctx[a0:a0 + len(a)] != a:
            continue
        for ids, seg, cand, off, base, plen, mat in windows(tok, q, ctx):
            if off <= a0 and a1 < off + plen:
                st, en = base + a0 - off, base + a1 - off
            else:
                if rng.random() > neg_keep:
                    continue
                st = en = 0
            X.append(ids); S.append(seg); M.append(cand); ST.append(st); EN.append(en); MT.append(mat)
        # 拿別篇文章來問同一個問題：要學會說「這段沒在回答」
        if rng.random() < rand_neg:
            other = rng.choice(ctxs)
            if other != ctx:
                ids, seg, cand, off, base, _, mat = rng.choice(windows(tok, q, other))
                X.append(ids); S.append(seg); M.append(cand); ST.append(0); EN.append(0); MT.append(mat)
    return (np.array(X, np.int32), np.array(S, np.int8), np.array(M, bool),
            np.array(ST, np.int32), np.array(EN, np.int32), np.array(MT, np.int8))


def best_span(ls, le, cand, max_len=40):
    """一段裡最好的答案（開始、結束、分數）；分數比 [CLS] 低就代表這段沒有答案。"""
    idx = np.nonzero(cand)[0]
    idx = idx[idx > 0]
    if idx.size == 0:
        return None
    s_top = idx[np.argsort(-ls[idx])[:20]]
    e_top = idx[np.argsort(-le[idx])[:20]]
    best = None
    for s in s_top:
        for e in e_top:
            if s <= e < s + max_len:
                sc = ls[s] + le[e]
                if best is None or sc > best[2]:
                    best = (int(s), int(e), float(sc))
    return best


def f1(pred, gold):
    if not pred or not gold:
        return float(pred == gold)
    common = Counter(pred) & Counter(gold)
    n = sum(common.values())
    if n == 0:
        return 0.0
    p, r = n / len(pred), n / len(gold)
    return 2 * p * r / (p + r)


def evaluate(model, tok, samples, limit=600, batch=32):
    """用沒看過的文章考試：EM（完全答對）、F1（答對幾成）、拒答率。"""
    em = f1s = 0.0
    n = 0
    for ctx, q, a, a0 in samples[:limit]:
        ws = windows(tok, q, ctx)
        ids = np.array([w[0] for w in ws], np.int32)
        seg = np.array([w[1] for w in ws], np.int8)
        cand = np.array([w[2] for w in ws], bool)
        mat = np.array([w[6] for w in ws], np.int8)
        ls, le = model.forward(ids, seg, cand, mat)
        best = None
        for i, w in enumerate(ws):
            b = best_span(ls[i], le[i], cand[i])
            if b and (best is None or b[2] > best[2]):
                best = (i, *b)
        pred = ""
        if best:
            i, s, e, _ = best
            off, base = ws[i][3], ws[i][4]
            pred = ReaderTokenizer.norm(ctx)[off + s - base: off + e - base + 1]
        gold = ReaderTokenizer.norm(a)
        em += float(pred == gold)
        f1s += f1(pred, gold)
        n += 1
    return em / n, f1s / n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--hours", type=float, default=3.0)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--embd", type=int, default=192)
    ap.add_argument("--layers", type=int, default=4)
    ap.add_argument("--resume", action="store_true")
    ap.add_argument("--extra", nargs="*", default=[], help="更多 SQuAD 格式的教材（例如轉成繁體的 CMRC）")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    log = open(os.path.join(args.out, "train.log"), "a", encoding="utf-8")

    def say(*a):
        s = " ".join(str(x) for x in a)
        print(s, flush=True)
        log.write(s + "\n"); log.flush()

    train = load_squad(os.path.join(args.data, "DRCD_training.json"))
    for f in args.extra:
        train += load_squad(os.path.join(args.data, f))
    dev = load_squad(os.path.join(args.data, "DRCD_dev.json"))
    random.Random(0).shuffle(dev)
    tok = build_vocab(train)
    tok.punct_ids = frozenset(tok.stoi[c] for c in PUNCT if c in tok.stoi)
    say(f"train {len(train)} dev {len(dev)} vocab {tok.vocab_size}")
    X, S, M, ST, EN, MT = featurize(tok, train)
    say(f"features {len(X)}  (no-answer {(ST == 0).mean():.2f})")

    model = Reader(tok.vocab_size, n_ctx=T_CTX, n_embd=args.embd, n_head=4, n_layer=args.layers)
    ckpt = os.path.join(args.out, "reader.npz")
    opt = AdamW(model.p, lr=args.lr, wd=0.01)
    step0 = 0
    if args.resume and os.path.exists(ckpt):
        z = np.load(ckpt)
        for k in model.p:
            model.p[k] = z[k]
        step0 = int(z["__step"])
        for k in model.p:
            opt.m[k] = z["m." + k]; opt.v[k] = z["v." + k]
        opt.t = step0
        say(f"resumed at step {step0}")
    say(f"params {model.num_params():,}")

    t0 = time.time()
    budget = args.hours * 3600
    steps_per_epoch = len(X) // args.batch
    # 估計總步數：先跑幾步量速度
    rng = np.random.default_rng(step0)
    order = rng.permutation(len(X))
    pos = 0
    step = step0
    total = None
    best_f1 = -1
    losses = []
    while True:
        if pos + args.batch > len(order):
            order = rng.permutation(len(X)); pos = 0
        b = order[pos:pos + args.batch]; pos += args.batch
        # 批次裡最長的那筆決定長度（短的就不用算整個 256）
        Tb = int(max(np.nonzero(X[b] != PAD)[1].max() + 1, 16))
        if total is None and step - step0 == 20:
            per = (time.time() - t0) / 20
            total = step0 + int(budget / per)
            say(f"{per:.2f}s/step → about {total - step0} steps ({(total - step0) / steps_per_epoch:.2f} epochs)")
        T_total = total or 10 ** 9
        warm = 300
        lr = args.lr * min(1.0, (step + 1) / warm) * (0.5 * (1 + np.cos(np.pi * min(1.0, step / max(T_total, 1)))) * 0.95 + 0.05)
        loss = model.forward(X[b, :Tb], S[b, :Tb], M[b, :Tb], MT[b, :Tb], ST[b], EN[b])
        g = model.backward()
        # 梯度裁剪
        norm = np.sqrt(sum(float((v * v).sum()) for v in g.values()))
        if norm > 1.0:
            for k in g:
                g[k] *= 1.0 / norm
        opt.step(model.p, g, lr)
        losses.append(loss)
        step += 1
        done = time.time() - t0 > budget
        if step % 50 == 0:
            say(f"step {step} loss {np.mean(losses[-50:]):.3f} lr {lr:.2e} {time.time() - t0:.0f}s")
        if step % 1000 == 0 or done:
            em, f = evaluate(model, tok, dev, limit=400)
            say(f"== step {step} dev EM {em:.3f} F1 {f:.3f}")
            z = {k: v for k, v in model.p.items()}
            z.update({"m." + k: v for k, v in opt.m.items()})
            z.update({"v." + k: v for k, v in opt.v.items()})
            z["__step"] = np.array(step)
            np.savez(ckpt, **z)
            if f > best_f1:
                best_f1 = f
                model.export(os.path.join(args.out, "reader.bin"), os.path.join(args.out, "reader.json"), tok,
                             extra={"dev_em": em, "dev_f1": f, "step": step, "t_ctx": T_CTX, "q_max": Q_MAX, "punct": sorted(PUNCT)})
                say(f"exported (best F1 {f:.3f})")
        if done:
            break


if __name__ == "__main__":
    main()
