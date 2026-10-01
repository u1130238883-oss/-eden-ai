# -*- coding: utf-8 -*-
"""
訓練 NineSun 的閱讀理解大腦（從零開始，不用任何預訓練權重、不接任何別的 AI）。

用 PyTorch 在 CPU 上訓練（bfloat16 矩陣加速），模型的數學和 reader_model.py（NumPy 參考實作）、
ios/EchoCore/Brain.swift 完全一樣；匯出的 reader.bin / reader.json 直接放進 App。

兩個階段：
  1. 讀書（自我監督）：把文章裡 15% 的字遮起來讓它猜，學會中文的字、詞、句子怎麼接。
     前面再放一句同一篇（或別篇）的句子當「問題」，它得學會到文章裡找對應的地方——這就是閱讀理解要的本事。
  2. 閱讀測驗：問題＋段落 → 答案從第幾個字到第幾個字；段落沒在回答問題就指向 [CLS]。
     段落的切法和 App 讀網頁時一樣（兩三句一段），而且大部分段落故意是「同一篇文章裡沒在回答」的，
     它才學得會挑出真正回答問題的那一段，而不是拿開頭充數。

用法：
  python3 ai/train_reader.py --data DIR --out DIR --pretrain-min 45 --finetune-min 120
  （DIR 裡放 DRCD_*.json 和 cmrc2018_*.json，見 reader_data.py）
"""
import argparse
import contextlib
import json
import math
import os
import random
import time
from collections import Counter

import numpy as np
import torch
import torch.nn.functional as F

from reader_data import all_sets, passages, pretrain_texts, simplified_to_traditional
from reader_model import CLS, PAD, SEP, UNK, Reader, ReaderTokenizer, match_features

PUNCT = set("，。、；：？！「」『』（）()《》〈〉,.;:?!\"' \n-—…·")
MASK_NAME = "<mask>"
T_CTX = 256
Q_MAX = 48
MAX_ANSWER = 40      # 和 Swift 的 Brain.read(maxAnswer:) 一樣


def amp():
    """CPU 有 AMX（bfloat16 矩陣加速）才用半精度，不然 float32 比較快"""
    if os.environ.get("READER_BF16") == "1":
        return torch.autocast("cpu", dtype=torch.bfloat16)
    return contextlib.nullcontext()


# ------------------------------------------------------------------ 模型（和 NumPy 版同一套參數名稱、同樣的數學）
class TorchReader(torch.nn.Module):
    def __init__(self, vocab_size, n_ctx=T_CTX, n_embd=256, n_head=8, n_layer=6, seed=0):
        super().__init__()
        ref = Reader(vocab_size, n_ctx=n_ctx, n_embd=n_embd, n_head=n_head, n_layer=n_layer, seed=seed)
        self.cfg = ref.cfg
        self.names = ref.order()
        self.P = {}
        for k in self.names:
            p = torch.nn.Parameter(torch.from_numpy(ref.p[k].copy()))
            self.register_parameter(k.replace(".", "__"), p)
            self.P[k] = p
        C = n_embd
        # 讀書階段才用的「猜字」輸出層（不匯出給 App）
        self.mlm_w = torch.nn.Parameter(torch.randn(C, C) * 0.02)
        self.mlm_b = torch.nn.Parameter(torch.zeros(C))
        self.mlm_g = torch.nn.Parameter(torch.ones(C))
        self.mlm_lb = torch.nn.Parameter(torch.zeros(C))
        self.mlm_bias = torch.nn.Parameter(torch.zeros(vocab_size))

    def encode(self, idx, seg, mat):
        P, cfg = self.P, self.cfg
        B, T = idx.shape
        C, H = cfg["n_embd"], cfg["n_head"]
        D = C // H
        keep = (idx != PAD)[:, None, None, :]
        x = P["wte"][idx] + P["wpe"][:T] + P["wse"][seg] + P["wme"][mat]
        for l in range(cfg["n_layer"]):
            pre = f"h{l}."
            h = F.layer_norm(x, (C,), P[pre + "ln1_g"], P[pre + "ln1_b"], 1e-5)
            qkv = h @ P[pre + "w_qkv"] + P[pre + "b_qkv"]
            q, k, v = qkv.split(C, dim=-1)
            q = q.view(B, T, H, D).transpose(1, 2)
            k = k.view(B, T, H, D).transpose(1, 2)
            v = v.view(B, T, H, D).transpose(1, 2)
            y = F.scaled_dot_product_attention(q, k, v, attn_mask=keep)
            y = y.transpose(1, 2).reshape(B, T, C)
            x = x + y @ P[pre + "w_o"] + P[pre + "b_o"]
            h2 = F.layer_norm(x, (C,), P[pre + "ln2_g"], P[pre + "ln2_b"], 1e-5)
            x = x + F.relu(h2 @ P[pre + "w_fc"] + P[pre + "b_fc"]) @ P[pre + "w_proj"] + P[pre + "b_proj"]
        return F.layer_norm(x, (C,), P["lnf_g"], P["lnf_b"], 1e-5)

    def span_logits(self, xf, cand):
        lg = xf.float() @ self.P["w_span"] + self.P["b_span"]
        neg = torch.where(cand, 0.0, -1e9)
        return lg[..., 0] + neg, lg[..., 1] + neg

    def mlm_logits(self, xf):
        h = F.gelu(xf @ self.mlm_w + self.mlm_b)
        h = F.layer_norm(h, (h.shape[-1],), self.mlm_g, self.mlm_lb, 1e-5)
        return h.float() @ self.P["wte"].t() + self.mlm_bias

    def to_numpy(self):
        ref = Reader(self.cfg["vocab_size"], **{k: v for k, v in self.cfg.items() if k != "vocab_size"})
        for k in self.names:
            ref.p[k] = self.P[k].detach().float().numpy().copy()
        return ref


# ------------------------------------------------------------------ 分詞
def load_wiki(d, limit):
    """維基百科純文字（一行一段）：接成 300～600 字一篇，讀到 limit 個字為止"""
    import glob
    out, cur, total = [], "", 0
    for f in sorted(glob.glob(os.path.join(d, "wiki_*.txt"))):
        for line in open(f, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            cur += line
            if len(cur) >= 300:
                out.append(cur[:600]); total += len(out[-1]); cur = ""
                if total >= limit:
                    return out
    return out


def build_vocab(texts, min_count=2):
    c = Counter()
    for t in texts:
        c.update(ReaderTokenizer.norm(t))
    chars = [ch for ch, n in c.items() if n >= min_count and ch not in ("\n",)]
    tok = ReaderTokenizer(chars)
    # <mask> 放在字表最後：App 永遠不會用到它
    tok.itos.append(MASK_NAME)
    tok.stoi[MASK_NAME] = len(tok.itos) - 1
    return tok


class Item:
    """一題（或一段讀書用的文章）預先轉好的字與編號"""
    __slots__ = ("chars", "ids")

    def __init__(self, tok, s):
        self.chars = ReaderTokenizer.norm(s)
        self.ids = [tok.stoi.get(c, UNK) for c in self.chars]


# ------------------------------------------------------------------ 閱讀測驗的練習題
def make_sample(qc, qi, pc, pi, ans):
    """問題＋段落 → (ids, seg, mat, base, plen, start, end)；ans = 段落裡的 (開始, 結束) 或 None（沒在回答）"""
    mq, mp = match_features(qc, pc, PUNCT)
    ids = [CLS] + qi + [SEP] + pi + [SEP]
    seg = [0] * (len(qi) + 2) + [1] * (len(pi) + 1)
    mat = [0] + mq + [0] + mp + [0]
    base = len(qi) + 2
    st, en = (base + ans[0], base + ans[1]) if ans else (0, 0)
    return (np.array(ids, np.int32), np.array(seg, np.int8), np.array(mat, np.int8), base, len(pi), st, en)


def windows(L, n):
    """長段落切成有重疊的幾段（和 Swift 一樣：每段 L 字，每次往後移 L/2）"""
    out, start, stride = [], 0, max(L // 2, 1)
    while True:
        out.append((start, min(start + L, n)))
        if start + L >= n:
            break
        start += stride
    return out


def question_pools(tok, train, seed=0):
    """每一題：答案所在的段落（正例）和同一篇裡沒在回答的段落（反例），兩種切法都有：
       - 整篇文章用 256 字的窗切（跟一般閱讀測驗一樣）
       - 兩三句一段（跟 App 讀網頁一樣）"""
    rng = random.Random(seed)
    ctx_cache = {}
    pools = []
    for ctx, q, a, a0 in train:
        if a0 < 0 or not a:
            continue
        qitem = Item(tok, q)
        qc, qi = qitem.chars[:Q_MAX], qitem.ids[:Q_MAX]
        if ctx not in ctx_cache:
            ctx_cache[ctx] = (Item(tok, ctx), passages(ctx))
        citem, psgs = ctx_cache[ctx]
        a1 = a0 + len(a) - 1
        L = T_CTX - 3 - len(qi)
        pos, neg = [], []
        # 整篇切窗
        for s, e in windows(L, len(citem.ids)):
            ans = (a0 - s, a1 - s) if s <= a0 and a1 < e else None
            smp = make_sample(qc, qi, citem.chars[s:e], citem.ids[s:e], ans)
            (pos if ans else neg).append(smp)
        # 兩三句一段
        for ps, pe in psgs:
            for s, e in windows(L, pe - ps):
                s, e = ps + s, ps + e
                ans = (a0 - s, a1 - s) if s <= a0 and a1 < e else None
                if ans is None and s <= a1 and a0 < e:
                    continue  # 答案被切成兩半的段落不當反例
                smp = make_sample(qc, qi, citem.chars[s:e], citem.ids[s:e], ans)
                (pos if ans else neg).append(smp)
        if pos:
            pools.append((qc, qi, pos, neg))
    rng.shuffle(pools)
    return pools, [c for c in ctx_cache]


def epoch_samples(tok, pools, contexts, ctx_items, rng, neg_per_q=2, rand_neg=0.3):
    """這一輪要練的題目：每題的正例全部、同一篇的反例抽幾個、再從別篇文章抽一段當反例。"""
    out = []
    for qc, qi, pos, neg in pools:
        out.extend(pos)
        if neg:
            out.extend(rng.sample(neg, min(neg_per_q, len(neg))))
        if rng.random() < rand_neg:
            other = contexts[rng.randrange(len(contexts))]
            item, psgs = ctx_items[other]
            if psgs:
                ps, pe = psgs[rng.randrange(len(psgs))]
                pe = min(pe, ps + T_CTX - 3 - len(qi))
                out.append(make_sample(qc, qi, item.chars[ps:pe], item.ids[ps:pe], None))
    return out


def batches(samples, rng, tokens=12288):
    """長度差不多的放一起（少算很多 <pad>），每批大約 tokens 個字"""
    order = sorted(range(len(samples)), key=lambda i: len(samples[i][0]) + rng.random() * 8)
    out, cur, cur_max = [], [], 0
    for i in order:
        n = len(samples[i][0])
        if cur and max(cur_max, n) * (len(cur) + 1) > tokens:
            out.append(cur)
            cur, cur_max = [], 0
        cur.append(i)
        cur_max = max(cur_max, n)
    if cur:
        out.append(cur)
    rng.shuffle(out)
    return out


def collate(samples, idxs):
    T = max(len(samples[i][0]) for i in idxs)
    B = len(idxs)
    ids = np.full((B, T), PAD, np.int64)
    seg = np.ones((B, T), np.int64)
    mat = np.zeros((B, T), np.int64)
    cand = np.zeros((B, T), bool)
    st = np.zeros(B, np.int64)
    en = np.zeros(B, np.int64)
    for r, i in enumerate(idxs):
        a, s, m, base, plen, s0, e0 = samples[i]
        n = len(a)
        ids[r, :n], seg[r, :n], mat[r, :n] = a, s, m
        cand[r, 0] = True
        cand[r, base:base + plen] = True
        st[r], en[r] = s0, e0
    t = torch.from_numpy
    return t(ids), t(seg), t(mat), t(cand), t(st), t(en)


# ------------------------------------------------------------------ 讀書（遮字猜字）
def mlm_samples(tok, texts, rng, mask_id):
    """[CLS] 一句話 [SEP] 一段文章 [SEP]：一半的時候那句話就出自這段文章（要學會對照著找），
    一半來自別篇。兩邊各遮 15% 的字讓它猜。"""
    out = []
    V = mask_id  # 真正的字編號都小於 <mask>
    sent_pool = []
    for t in texts:
        for s, e in passages(t):
            sent_pool.append(t[s:e])
    for t in texts:
        L = T_CTX - 3 - 40
        for s, e in windows(L, len(t)):
            chunk = t[s:e]
            if len(chunk) < 20:
                continue
            if rng.random() < 0.5:
                ps = passages(chunk)
                a = chunk[ps[rng.randrange(len(ps))][0]:ps[0][1]] if ps else chunk[:40]
                s0 = rng.randrange(max(1, len(a) - 40 + 1)) if len(a) > 40 else 0
                a = a[s0:s0 + 40]
            else:
                a = sent_pool[rng.randrange(len(sent_pool))][:40]
            qc, pc = ReaderTokenizer.norm(a), ReaderTokenizer.norm(chunk)
            qi = [tok.stoi.get(c, UNK) for c in qc]
            pi = [tok.stoi.get(c, UNK) for c in pc]
            ids = [CLS] + qi + [SEP] + pi + [SEP]
            chars = [None] + qc + [None] + pc + [None]
            labels = [-100] * len(ids)
            for j in range(len(ids)):
                if chars[j] is None or chars[j] in PUNCT or ids[j] == UNK or rng.random() >= 0.15:
                    continue
                labels[j] = ids[j]
                r = rng.random()
                if r < 0.8:
                    ids[j] = mask_id
                elif r < 0.9:
                    ids[j] = rng.randrange(4, V)
                chars[j] = f"\x00{j}"  # 被遮的字不能跟任何字對上
            mq, mp = match_features(chars[1:1 + len(qc)], chars[2 + len(qc):-1], PUNCT)
            seg = [0] * (len(qc) + 2) + [1] * (len(pc) + 1)
            mat = [0] + mq + [0] + mp + [0]
            out.append((np.array(ids, np.int32), np.array(seg, np.int8), np.array(mat, np.int8), np.array(labels, np.int32)))
    return out


def collate_mlm(samples, idxs):
    T = max(len(samples[i][0]) for i in idxs)
    B = len(idxs)
    ids = np.full((B, T), PAD, np.int64)
    seg = np.ones((B, T), np.int64)
    mat = np.zeros((B, T), np.int64)
    lab = np.full((B, T), -100, np.int64)
    for r, i in enumerate(idxs):
        a, s, m, l = samples[i]
        n = len(a)
        ids[r, :n], seg[r, :n], mat[r, :n], lab[r, :n] = a, s, m, l
    t = torch.from_numpy
    return t(ids), t(seg), t(mat), t(lab)


# ------------------------------------------------------------------ 考試
def best_span(ls, le, lo, hi, max_len=MAX_ANSWER):
    """和 Swift 的 Brain.read 一樣：開始、結束各挑前 20 名，找分數最高的組合；分數要減掉 [CLS]（沒有答案）的分數。"""
    pos = np.arange(lo, hi)
    if pos.size == 0:
        return None
    s_top = pos[np.argsort(-ls[lo:hi], kind="stable")[:20]]
    e_top = pos[np.argsort(-le[lo:hi], kind="stable")[:20]]
    none = ls[0] + le[0]
    best = None
    for s in s_top:
        for e in e_top:
            if s <= e < s + max_len:
                sc = ls[s] + le[e] - none
                if best is None or sc > best[2]:
                    best = (int(s), int(e), float(sc))
    return best


@torch.no_grad()
def read_many(model, samples, chunk=256):
    """一次讀很多段：回傳每段的 (開始, 結束, 分數)（段落裡的位置）"""
    out = [None] * len(samples)
    order = sorted(range(len(samples)), key=lambda i: len(samples[i][0]))
    for k in range(0, len(order), chunk):
        idxs = order[k:k + chunk]
        ids, seg, mat, cand, _, _ = collate(samples, idxs)
        with amp():
            xf = model.encode(ids, seg, mat)
        ls, le = model.span_logits(xf, cand)
        ls, le = ls.float().numpy(), le.float().numpy()
        for r, i in enumerate(idxs):
            base, plen = samples[i][3], samples[i][4]
            b = best_span(ls[r], le[r], base, base + plen)
            out[i] = None if b is None else (b[0] - base, b[1] - base, b[2])
    return out


def f1(pred, gold):
    if not pred or not gold:
        return float(pred == gold)
    common = Counter(pred) & Counter(gold)
    n = sum(common.values())
    if n == 0:
        return 0.0
    p, r = n / len(pred), n / len(gold)
    return 2 * p * r / (p + r)


def overlap_pick(q, texts):
    """App 原本粗挑段落的方法：問題裡的雙字詞在段落裡出現幾個（Think.grams）"""
    skip = set("什麼嗎呢的是了哪誰為怎吧啊有個些都在")
    c = [ch for ch in q if not ch.isspace() and ch not in PUNCT and ch not in skip]
    g = {c[i] + c[i + 1] for i in range(len(c) - 1)} if len(c) >= 2 else set(c)
    scores = [sum(1 for x in g if x in t) for t in texts]
    return int(np.argmax(scores))


def evaluate(model, tok, dev, limit=1000, seed=0):
    """考三種：
      em/f1：整篇文章裡找答案（完全答對率、答對幾成）
      pick：文章切成兩三句一段，分數最高的那段有沒有包含答案（App 讀網頁就是這樣挑）
      pick_mix：再混進 4 篇別的文章的段落（像網路上一堆不相干的結果），還挑得到嗎
    同時算「拿開頭那段」和「問題字詞重疊最多」這兩種舊方法當對照。"""
    rng = random.Random(seed)
    items = dev[:limit]
    dev_ctx = list({c for c, _, _, _ in dev})
    full, full_idx, psg, psg_meta = [], [], [], []
    for qi_, (ctx, q, a, a0) in enumerate(items):
        qitem = Item(tok, q)
        qc, qi = qitem.chars[:Q_MAX], qitem.ids[:Q_MAX]
        citem = Item(tok, ctx)
        L = T_CTX - 3 - len(qi)
        for s, e in windows(L, len(citem.ids)):
            full.append(make_sample(qc, qi, citem.chars[s:e], citem.ids[s:e], None))
            full_idx.append((qi_, s))
        own = passages(ctx)
        others = []
        for oc in rng.sample(dev_ctx, 5):
            if oc != ctx and len(others) < 4:
                others.append(oc)
        cands = [(ctx, s, e, True) for s, e in own] + [(oc, s, e, False) for oc in others for s, e in passages(oc)]
        for c, s, e, is_own in cands:
            it = Item(tok, c[s:e])
            ch, ids = it.chars[:L], it.ids[:L]
            psg.append(make_sample(qc, qi, ch, ids, None))
            psg_meta.append((qi_, c, s, min(e, s + L), is_own))
    got_full = read_many(model, full)
    best = {}
    for (qi_, s), r in zip(full_idx, got_full):
        if r and (qi_ not in best or r[2] > best[qi_][2]):
            best[qi_] = (s + r[0], s + r[1], r[2])
    em = f1s = 0.0
    for qi_, (ctx, q, a, a0) in enumerate(items):
        pred = ""
        if qi_ in best:
            s, e, _ = best[qi_]
            pred = "".join(ReaderTokenizer.norm(ctx)[s:e + 1])
        gold = "".join(ReaderTokenizer.norm(a))
        em += float(pred == gold)
        f1s += f1(pred, gold)
    got_psg = read_many(model, psg)
    per_q = {}
    for meta, r in zip(psg_meta, got_psg):
        per_q.setdefault(meta[0], []).append((meta, r))
    hit_own = hit_mix = hit_first = hit_overlap = n = 0
    for qi_, rows in per_q.items():
        ctx, q, a, a0 = items[qi_]
        a1 = a0 + len(a)

        def has(meta):
            _, c, s, e, is_own = meta
            return is_own and s <= a0 and a1 <= e
        own_rows = [x for x in rows if x[0][4]]
        if not any(has(m) for m, _ in own_rows):
            continue  # 答案被切段切斷了，這題不算
        n += 1
        sc = lambda x: x[1][2] if x[1] else -1e9
        hit_own += has(max(own_rows, key=sc)[0])
        hit_mix += has(max(rows, key=sc)[0])
        hit_first += has(own_rows[0][0])
        texts = [m[1][m[2]:m[3]] for m, _ in rows]
        hit_overlap += has(rows[overlap_pick(q, texts)][0])
    k = max(n, 1)
    return dict(em=em / len(items), f1=f1s / len(items), pick=hit_own / k, pick_mix=hit_mix / k,
                first=hit_first / k, overlap_mix=hit_overlap / k, n=n)


# ------------------------------------------------------------------ 訓練迴圈
def lr_at(step, total, peak, warm):
    if step < warm:
        return peak * (step + 1) / warm
    p = min(1.0, (step - warm) / max(1, total - warm))
    return peak * (0.05 + 0.95 * 0.5 * (1 + math.cos(math.pi * p)))


def make_opt(model, params, lr):
    decay = [p for p in params if p.dim() == 2]
    other = [p for p in params if p.dim() != 2]
    return torch.optim.AdamW([{"params": decay, "weight_decay": 0.01}, {"params": other, "weight_decay": 0.0}],
                             lr=lr, betas=(0.9, 0.98), eps=1e-8)


def run_stage(name, model, opt, minutes, peak, warm, make_epoch, step_fn, say, on_check=None, check_every=None, ckpt=None):
    """ckpt：每 10 分鐘存一次進度（模型、優化器、第幾步、用了多久），容器重開後從這裡接著練"""
    t0 = time.time()
    budget = minutes * 60
    step, total, losses = 0, None, []
    ep = 0
    if ckpt and os.path.exists(ckpt):
        z = torch.load(ckpt)
        model.load_state_dict(z["model"]); opt.load_state_dict(z["opt"])
        step, total, ep = z["step"], z["total"], z["ep"] - 1
        t0 -= z["elapsed"]
        say(f"[{name}] resumed at step {step} ({z['elapsed'] / 60:.0f} min done)")
    next_check = check_every and ((time.time() - t0) // 60 // check_every + 1) * check_every
    last_save = time.time()
    while True:
        ep += 1
        for batch in make_epoch(ep):
            if total is None and step == 30:
                per = (time.time() - t0) / 30
                total = int(budget / per)
                say(f"[{name}] {per:.2f}s/step → about {total} steps")
            lr = lr_at(step, total or 10 ** 9, peak, warm)
            for g in opt.param_groups:
                g["lr"] = lr
            loss = step_fn(batch)
            opt.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_([p for g in opt.param_groups for p in g["params"]], 1.0)
            opt.step()
            losses.append(loss.item())
            step += 1
            el = time.time() - t0
            if step % 100 == 0:
                say(f"[{name}] ep {ep} step {step} loss {np.mean(losses[-100:]):.3f} lr {lr:.2e} {el / 60:.1f}min")
            if on_check and next_check and el > next_check * 60:
                next_check += check_every
                on_check(step)
            if ckpt and time.time() - last_save > 300:
                torch.save({"model": model.state_dict(), "opt": opt.state_dict(), "step": step, "total": total,
                            "ep": ep, "elapsed": el}, ckpt + ".tmp")
                os.replace(ckpt + ".tmp", ckpt)
                last_save = time.time()
            if el > budget:
                return step


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--pretrain-min", type=float, default=45)
    ap.add_argument("--finetune-min", type=float, default=120)
    ap.add_argument("--embd", type=int, default=192)
    ap.add_argument("--layers", type=int, default=4)
    ap.add_argument("--heads", type=int, default=4)
    ap.add_argument("--tokens", type=int, default=12288, help="每批大約幾個字")
    ap.add_argument("--eval-limit", type=int, default=1000)
    ap.add_argument("--skip-pretrain", action="store_true", help="沿用 out/pretrained.pt")
    ap.add_argument("--wiki", default="", help="維基百科純文字資料夾（wiki_*.txt），讀書階段多讀這些")
    ap.add_argument("--wiki-chars", type=int, default=40_000_000, help="最多讀幾個字的維基百科")
    ap.add_argument("--wiki-per-epoch", type=int, default=8_000_000, help="每一輪讀書抽幾個字的維基百科")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    torch.set_num_threads(os.cpu_count() or 4)
    torch.manual_seed(0)
    log = open(os.path.join(args.out, "train.log"), "a", encoding="utf-8")

    def say(*a):
        s = " ".join(str(x) for x in a)
        print(s, flush=True)
        log.write(s + "\n")
        log.flush()

    train, dev, _ = all_sets(args.data, simplified_to_traditional())
    random.Random(0).shuffle(dev)
    texts = pretrain_texts(train)
    wiki = load_wiki(args.wiki, args.wiki_chars) if args.wiki else []
    # 字表：教材＋問題＋一部分維基百科（維基的罕見字要出現 5 次以上才收）
    tok = build_vocab(texts + [q for _, q, _, _ in train])
    if wiki:
        c = Counter()
        for t in wiki[:len(wiki) // 3]:
            c.update(ReaderTokenizer.norm(t))
        extra = sorted(ch for ch, n in c.items() if n >= 5 and ch not in tok.stoi and ch != "\n")
        tok = ReaderTokenizer([x for x in tok.itos[4:] if x != MASK_NAME] + extra)
        tok.itos.append(MASK_NAME); tok.stoi[MASK_NAME] = len(tok.itos) - 1
    say(f"wiki texts {len(wiki)} ({sum(map(len, wiki)):,} chars)")
    mask_id = tok.stoi[MASK_NAME]
    say(f"train {len(train)} dev {len(dev)} texts {len(texts)} ({sum(map(len, texts)):,} chars) vocab {tok.vocab_size}")

    model = TorchReader(tok.vocab_size, n_embd=args.embd, n_head=args.heads, n_layer=args.layers)
    core = [model.P[k] for k in model.names]
    say(f"params {sum(p.numel() for p in core):,} (+ reading-practice head)")

    def export(tag, metrics):
        ref = model.to_numpy()
        extra = {"t_ctx": T_CTX, "q_max": Q_MAX, "punct": sorted(PUNCT), "max_answer": MAX_ANSWER,
                 "match": "chars", **{f"dev_{k}": v for k, v in metrics.items()}}
        ref.export(os.path.join(args.out, f"reader{tag}.bin"), os.path.join(args.out, f"reader{tag}.json"), tok, extra=extra)
        json.dump({"itos": tok.itos}, open(os.path.join(args.out, "vocab.json"), "w", encoding="utf-8"), ensure_ascii=False)

    # ---- 1. 讀書
    pre_path = os.path.join(args.out, "pretrained.pt")
    if (args.skip_pretrain or os.path.exists(os.path.join(args.out, "pretrain.done"))) and os.path.exists(pre_path):
        model.load_state_dict(torch.load(pre_path))
        say("loaded pretrained weights")
    elif args.pretrain_min > 0:
        rng = random.Random(1)
        opt = make_opt(model, list(model.parameters()), 1e-3)

        def mlm_epoch(ep):
            ep_texts = list(texts)
            if wiki:
                k = min(len(wiki), args.wiki_per_epoch // 450)
                ep_texts += rng.sample(wiki, k)
            smp = mlm_samples(tok, ep_texts, rng, mask_id)
            say(f"[read] epoch {ep}: {len(smp)} passages")
            for b in batches([(s[0],) for s in smp], rng, args.tokens):
                yield (smp, b)

        def mlm_step(batch):
            smp, b = batch
            ids, seg, mat, lab = collate_mlm(smp, b)
            with amp():
                xf = model.encode(ids, seg, mat)
                sel = lab != -100
                logits = model.mlm_logits(xf[sel])
            return F.cross_entropy(logits.float(), lab[sel])

        run_stage("read", model, opt, args.pretrain_min, 1e-3, 500, mlm_epoch, mlm_step, say,
                  ckpt=os.path.join(args.out, "read.ckpt"))
        torch.save(model.state_dict(), pre_path)
        open(os.path.join(args.out, "pretrain.done"), "w").write("ok")
        say("saved pretrained weights")

    # ---- 2. 閱讀測驗
    t = time.time()
    pools, contexts = question_pools(tok, train)
    ctx_items = {c: (Item(tok, c), passages(c)) for c in contexts}
    say(f"question pools {len(pools)} ({time.time() - t:.0f}s), "
        f"{sum(len(p[2]) for p in pools)} answer windows, {sum(len(p[3]) for p in pools)} non-answer windows")
    rng = random.Random(2)
    opt = make_opt(model, core, 5e-4)
    best = {"f1": -1}
    # 接著練的時候記得之前最好的成績，才不會拿比較差的版本蓋掉
    prev = os.path.join(args.out, "reader.json")
    if os.path.exists(prev):
        pm = json.load(open(prev, encoding="utf-8"))
        best["f1"] = pm.get("dev_f1", -1) + pm.get("dev_pick_mix", 0)
        say(f"best so far f1 {pm.get('dev_f1', 0):.3f}")

    def qa_epoch(ep):
        smp = epoch_samples(tok, pools, contexts, ctx_items, rng)
        say(f"[quiz] epoch {ep}: {len(smp)} samples ({sum(1 for s in smp if s[5] == 0) / len(smp):.0%} non-answer)")
        for b in batches(smp, rng, args.tokens):
            yield (smp, b)

    def qa_step(batch):
        smp, b = batch
        ids, seg, mat, cand, st, en = collate(smp, b)
        with amp():
            xf = model.encode(ids, seg, mat)
        ls, le = model.span_logits(xf, cand)
        return (F.cross_entropy(ls, st) + F.cross_entropy(le, en)) / 2

    def check(step):
        model.eval()
        m = evaluate(model, tok, dev, limit=args.eval_limit)
        model.train()
        say(f"== step {step} " + " ".join(f"{k} {v:.3f}" if isinstance(v, float) else f"{k} {v}" for k, v in m.items()))
        score = m["f1"] + m["pick_mix"]
        if score > best["f1"]:
            best["f1"] = score
            export("", m)
            say("exported reader.bin / reader.json")

    model.train()
    run_stage("quiz", model, opt, args.finetune_min, 5e-4, 300, qa_epoch, qa_step, say, on_check=check, check_every=20,
              ckpt=os.path.join(args.out, "quiz.ckpt"))
    check("final")


if __name__ == "__main__":
    main()
