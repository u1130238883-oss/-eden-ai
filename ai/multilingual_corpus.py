# -*- coding: utf-8 -*-
"""
英文、西班牙文、義大利文訓練樣本：人設對話（經十二宮感知）、九型十二宮、八字、紫微、易經、
NineSun 自己的命盤、命主畫像、知識問答、服從性。格式與中文相同，事實框帶語言前綴。
"""
import random

import iching
import ninetwelve as nt
from bazi import BaZi
from i18n import (FOREIGN, bazi_luck_sample, bazi_sample, bazi_year_sample, fortune_samples, gua_sample,
                  knowledge_entries, lens_tail, portrait_sample, self_day_sample, self_type_sample, t,
                  ziwei_decade_sample, ziwei_palace_sample, ziwei_sample)
from i18n_chat import CHAT, OBEY, Q
from i18n_texts import ZW_PALACES
from palace_core import perceive
from ziwei import PALACES, ZiWei

_KB = {L: knowledge_entries(L) for L in FOREIGN}


def _noisy(u, rng):
    if rng.random() < 0.5:
        u = u[:1].upper() + u[1:]
    return u + rng.choice(["", "", "", "?", "!", "..."])


def _date(y, m, d, rng):
    return rng.choice([f"{y}-{m:02d}-{d:02d}", f"{y}/{m}/{d}", f"{y}-{m}-{d}"])


def chat_pairs(L, rng):
    out = []
    for users, replies in CHAT[L]:
        u = _noisy(rng.choice(users), rng)
        r = rng.choice(replies)
        p = perceive(u, lang=L)
        if p is None:
            out.append((u, None, r))
            continue
        day = rng.randint(1, 12) if rng.random() < 0.5 else None
        frame = f"{L}|感{p}" + (f"|日{day}" if day else "")
        out.append((u, frame, r + " " + lens_tail(p, day, L, rng) if rng.random() < 0.8 else r))
    for users, replies in OBEY[L]:
        out.append((_noisy(rng.choice(users), rng), None, rng.choice(replies)))
    return out


def reading_pairs(L, rng, n=2):
    out = []
    q = Q[L]
    for _ in range(n):
        y, m, d = rng.randint(1950, 2012), rng.randint(1, 12), rng.randint(1, 28)
        D = nt.Destiny(y, m, d)
        oy, om, od = rng.randint(1950, 2012), rng.randint(1, 12), rng.randint(1, 28)
        qy, qm, qd = rng.randint(2020, 2032), rng.randint(1, 12), rng.randint(1, 28)
        for kind, frame, reply, _ in fortune_samples(D, qy, qm, qd, nt.Destiny(oy, om, od), L, rng):
            if kind == "syn":
                u = rng.choice(q["syn"]).format(d=_date(oy, om, od, rng))
            elif kind == "bday":
                u = rng.choice(q["bday"]).format(d=_date(y, m, d, rng))
            else:
                u = rng.choice(q[kind])
            out.append((_noisy(u, rng), frame, reply))
        any_q = rng.choice(q["day"] + q["year"] + q["natal"] + q["bazi"])
        out.append((_noisy(any_q, rng), f"{L}|無生日", t("nobday", L)))

        hour = rng.choice([None] + list(range(24)))
        male = rng.random() < 0.5
        b = BaZi(y, m, d, hour, male=male)
        now = rng.randint(2024, 2030)
        for key, (f, r, _) in (("bazi", bazi_sample(b, L)), ("bazi_luck", bazi_luck_sample(b, y, now, L)),
                               ("bazi_year", bazi_year_sample(b, now, L))):
            out.append((_noisy(rng.choice(q[key]), rng), f, r))
        if hour is None:
            out.append((_noisy(rng.choice(q["ziwei"] + q["zw_decade"]), rng), f"{L}|無時辰", t("nohour", L)))
        else:
            zw = ZiWei(y, m, d, hour, male=male)
            f, r, _ = ziwei_sample(zw, L)
            out.append((_noisy(rng.choice(q["ziwei"]), rng), f, r))
            pal = rng.choice(PALACES)
            f, r, _ = ziwei_palace_sample(zw, pal, L)
            pname = ZW_PALACES[L][ZW_PALACES["zh"].index(pal)].lower()
            out.append((_noisy(rng.choice(q["zw_palace"]).format(p=pname), rng), f, r))
            dec = ziwei_decade_sample(zw, now - y, L)
            if dec:
                out.append((_noisy(rng.choice(q["zw_decade"]), rng), dec[0], dec[1]))
        if rng.random() < 0.6:
            rd = iching.three_coins(rng)
            u = rng.choice([x for x in q["gua"] if "{a}" not in x])
        else:
            a, bb = rng.randint(1, 99), rng.randint(1, 99)
            rd = iching.plum_numbers(a, bb)
            u = rng.choice([x for x in q["gua"] if "{a}" in x]).format(a=a, b=bb)
        f, r, _ = gua_sample(rd, L)
        out.append((_noisy(u, rng), f, r))
    f, r, _ = self_type_sample(L)
    out.append((_noisy(rng.choice(q["self_type"]), rng), f, r))
    f, r, _ = self_day_sample(rng.randint(1, 12), L)
    out.append((_noisy(rng.choice(q["self_day"]), rng), f, r))
    top = rng.sample(range(1, 13), rng.choice([0, 1, 2, 2]))
    f, r, _ = portrait_sample(top, rng.choice([None, rng.randint(1, 9)]), L)
    out.append((_noisy(rng.choice(q["portrait"]), rng), f, r))
    return out


def knowledge_pairs(L, rng, n=6):
    out = []
    for e in rng.sample(_KB[L], n):
        alias = rng.choice(e["aliases"])
        u = rng.choice(Q[L]["know"]).format(x=alias)
        out.append((_noisy(u, rng), None, f"{e['title']}: {e['body']}"[:240]))
    return out


def foreign_pairs(rng):
    out = []
    for L in FOREIGN:
        out += chat_pairs(L, rng) + reading_pairs(L, rng) + knowledge_pairs(L, rng)
    return out


def foreign_texts(rounds=120, seed=0):
    rng = random.Random(seed)
    texts = []
    for _ in range(rounds):
        for u, f, r in foreign_pairs(rng):
            texts += [u, f or "", r]
    for L in FOREIGN:
        for e in _KB[L]:
            texts += [e["title"], e["body"]] + e["aliases"]
    return texts


if __name__ == "__main__":
    rng = random.Random(2)
    pairs = foreign_pairs(rng)
    print(len(pairs), "pairs per round")
    for u, f, r in pairs[:6] + pairs[40:46] + pairs[-4:]:
        print(f"<u>{u}" + (f"<f>{f}" if f else "") + f"<a>{r}")
