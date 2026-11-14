# -*- coding: utf-8 -*-
"""
多語系（English / Español / Italiano）的回覆模板與事實框。

設計：
  - 所有模板集中在 TEMPLATES，以 {名稱} 佔位；Python 與 Swift 都用同一個 fill() 規則代入
  - 非中文的事實框加上語言前綴，例如「en|流年|2026|8宮壞9因2|引3,9」，模型據此決定回覆語言
  - 匯出 ios/NineSun/Resources/i18n.json 給 App（模板 + 十二宮/九型/六十四卦/星曜等資料）
中文（zh）沿用原本的模板與程式，不經過這裡。
"""
import json
import os
import random

import iching
import ninetwelve as nt
from bazi import STEM_EL, ten_god
from chinese_cal import BRANCHES, ganzhi
from i18n_hex import HEX_MEANINGS, HEX_NAMES
from i18n_texts import (BRANCH_PY, CONCEPTS, JU, SIHUA_NAMES, STAR_PY, STAR_TEXT, STEM_PY, STEM_TEXT, TEN_GOD_TEXT,
                        TEN_GODS, TRIGRAM_IMAGE, TRIGRAM_TEXT, WUXING, WUXING_TEXT, ZW_PALACE_TEXT, ZW_PALACES,
                        BRANCH_TEXT, SIHUA_TEXT)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOREIGN = ["en", "es", "it"]
NT_I18N = json.load(open(os.path.join(os.path.dirname(__file__), "ninetwelve_i18n.json"), encoding="utf-8"))


def fill(tpl, v):
    """把 {key} 換成值（與 Swift I18N.fill 完全相同：依 key 名稱排序後逐一取代）。"""
    s = tpl
    for k in sorted(v):
        s = s.replace("{" + k + "}", str(v[k]))
    return s


# ------------------------------------------------------------------ 基本詞彙
def pname(p, L):
    return NT_I18N[L]["shortNames"][p - 1]


def pn(p, L):
    return {"en": f"Palace {p} ({pname(p, L)})", "es": f"Palacio {p} ({pname(p, L)})",
            "it": f"Palazzo {p} ({pname(p, L)})"}[L]


def kw(p, n, L):
    name = pname(p, L)
    return ", ".join([k for k in NT_I18N[L]["keywords"][p - 1] if k != name][:n])


VERDICT = {"en": ["Favorable", "Aligned", "Adverse"], "es": ["Favorable", "Alineado", "Adverso"],
           "it": ["Favorevole", "Allineato", "Avverso"]}
FROM = {"en": "from", "es": "de", "it": "da"}


def rt(r, L):
    """判讀文字，例：Adverse 9 from 2（沿用 Hollow 的譯法）。"""
    return f"{VERDICT[L][r.verdict]} {r.result} {FROM[L]} {r.cause}"


def type_name(t, L):
    return NT_I18N[L]["names"][t - 1]


def tagline(t, L):
    return NT_I18N[L]["taglines"][t - 1]


def star_label(s, L):
    """星曜 + 四化，例：天梁 (Power)"""
    for zh, tag in zip(SIHUA_NAMES["zh"], SIHUA_NAMES[L]):
        if s.endswith(zh):
            return f"{s[:-2]} ({tag})"
    return s


def stars_l(stars_zh, L):
    return ", ".join(star_label(s, L) for s in stars_zh)


def hex_full(n, L):
    return f"{n} {HEX_NAMES[L][n - 1]} ({iching.full_name(n)})"


# ------------------------------------------------------------------ 模板
T = {
    # 九型十二宮
    "day": {
        "en": ["Today's day palace is {dp}: {dkw}. Tonight you move to {np}, watch for {nkw}.",
               "Today's signal: daytime in {dp}, focus on {dkw}; at night {np}, mind {nkw}."],
        "es": ["Hoy tu palacio del día es {dp}: {dkw}. Por la noche pasas a {np}, cuidado con {nkw}.",
               "Señal de hoy: de día {dp}, enfócate en {dkw}; de noche {np}, atención a {nkw}."],
        "it": ["Oggi il tuo palazzo del giorno è {dp}: {dkw}. Stanotte passi a {np}, attento a {nkw}.",
               "Segnale di oggi: di giorno {dp}, punta su {dkw}; di notte {np}, occhio a {nkw}."],
    },
    "row": {
        "en": ["{label} falls in {p}, reading {rt}: {phrase}. The effect shows in {rp}: {rkw}; the cause comes from {cp}: {ckw}."],
        "es": ["{label} cae en {p}, lectura {rt}: {phrase}. El efecto se ve en {rp}: {rkw}; la causa viene de {cp}: {ckw}."],
        "it": ["{label} cade in {p}, lettura {rt}: {phrase}. L'effetto si vede in {rp}: {rkw}; la causa viene da {cp}: {ckw}."],
    },
    "phrase0": {"en": ["the flow is with you", "a supportive combination", "things go your way, be bold"],
                "es": ["la corriente te favorece", "una combinación que ayuda", "las cosas fluyen, atrévete"],
                "it": ["la corrente è a tuo favore", "una combinazione che aiuta", "le cose filano, osa"]},
    "phrase1": {"en": ["steady and balanced, just be yourself", "neither good nor bad, keep a steady pace"],
                "es": ["estable y equilibrado, sé tú mismo", "ni bueno ni malo, mantén el ritmo"],
                "it": ["stabile ed equilibrato, sii te stesso", "né buono né cattivo, mantieni il passo"]},
    "phrase2": {"en": ["some resistance, stay alert", "friction ahead, slow down"],
                "es": ["hay resistencia, mantente atento", "habrá roces, ve más despacio"],
                "it": ["c'è resistenza, stai attento", "ci saranno attriti, rallenta"]},
    "label_month": {"en": ["Month {m}"], "es": ["El mes {m}"], "it": ["Il mese {m}"]},
    "label_year": {"en": ["{y}"], "es": ["El año {y}"], "it": ["L'anno {y}"]},
    "label_luck": {"en": ["Your {s}–{e} luck pillar"], "es": ["Tu pilar de suerte {s}–{e}"],
                   "it": ["Il tuo pilastro della sorte {s}–{e}"]},
    "trig": {"en": ["This year also triggers palaces {list} of your luck pillar."],
             "es": ["Este año también activa los palacios {list} de tu pilar de suerte."],
             "it": ["Quest'anno attiva anche i palazzi {list} del tuo pilastro della sorte."]},
    "natal": {"en": ["Your Life Palace is {p}, natal reading {rt}. Keywords: {kw}. Your type is {t}, {tn}."],
              "es": ["Tu Palacio de Vida es {p}, lectura natal {rt}. Claves: {kw}. Tu tipo es el {t}, {tn}."],
              "it": ["Il tuo Palazzo della Vita è {p}, lettura natale {rt}. Parole chiave: {kw}. Il tuo tipo è il {t}, {tn}."]},
    "type": {"en": ["You are type {t}, {tn}: {tag}.", "Your life number makes you type {t}, {tn}: {tag}."],
             "es": ["Eres del tipo {t}, {tn}: {tag}.", "Tu número de vida te hace tipo {t}, {tn}: {tag}."],
             "it": ["Sei del tipo {t}, {tn}: {tag}.", "Il tuo numero della vita ti rende tipo {t}, {tn}: {tag}."]},
    "syn": {"en": ["Your shared Life Palace is {p}, centered on {kw}. Across the twelve palaces: {g} favorable, {n} aligned, {b} adverse. {mood}"],
            "es": ["Vuestro Palacio de Vida común es {p}, centrado en {kw}. En los doce palacios: {g} favorables, {n} alineados, {b} adversos. {mood}"],
            "it": ["Il vostro Palazzo della Vita comune è {p}, centrato su {kw}. Nei dodici palazzi: {g} favorevoli, {n} allineati, {b} avversi. {mood}"]},
    "mood_good": {"en": ["More favorable than adverse, a good match!"], "es": ["Más favorables que adversos, ¡buena pareja!"],
                  "it": ["Più favorevoli che avversi, una bella intesa!"]},
    "mood_bad": {"en": ["More adverse than favorable, it takes patience."], "es": ["Más adversos que favorables, hará falta paciencia."],
                 "it": ["Più avversi che favorevoli, ci vuole pazienza."]},
    "mood_even": {"en": ["Evenly balanced, it depends on you both."], "es": ["Equilibrado, depende de los dos."],
                  "it": ["In equilibrio, dipende da voi due."]},
    "bday": {"en": ["Got it, birthday saved! Your Life Palace is {p} and you are type {t}, {tn}. Want today's reading?"],
             "es": ["¡Listo, cumpleaños guardado! Tu Palacio de Vida es {p} y eres del tipo {t}, {tn}. ¿Quieres la lectura de hoy?"],
             "it": ["Fatto, compleanno salvato! Il tuo Palazzo della Vita è {p} e sei del tipo {t}, {tn}. Vuoi la lettura di oggi?"]},
    "nobday": {"en": ["I don't know your birthday yet! Just tell me, e.g. my birthday is 2000-01-01."],
               "es": ["¡Aún no sé tu cumpleaños! Dímelo, por ejemplo: mi cumpleaños es 2000-01-01."],
               "it": ["Non conosco ancora il tuo compleanno! Dimmelo, ad esempio: il mio compleanno è 2000-01-01."]},
    # 八字
    "bazi": {"en": ["Your BaZi is {y} year, {m} month, {d} day{h}. Day Master {dm} ({py}) {el}: {text} Overall {str}, favorable elements {f1} and {f2}."],
             "es": ["Tu BaZi es año {y}, mes {m}, día {d}{h}. Maestro del Día {dm} ({py}) {el}: {text} En conjunto {str}, elementos favorables {f1} y {f2}."],
             "it": ["Il tuo BaZi è anno {y}, mese {m}, giorno {d}{h}. Maestro del Giorno {dm} ({py}) {el}: {text} Nel complesso {str}, elementi favorevoli {f1} e {f2}."]},
    "bazi_hour": {"en": [", {h} hour"], "es": [", hora {h}"], "it": [", ora {h}"]},
    "strong": {"en": ["strong self"], "es": ["yo fuerte"], "it": ["io forte"]},
    "weak": {"en": ["weak self"], "es": ["yo débil"], "it": ["io debole"]},
    "bazi_luck": {"en": ["Your luck pillars start at age {a}. You are now in the {gz} pillar; {st} is your {god}: {text}"],
                  "es": ["Tus pilares de suerte empiezan a los {a} años. Ahora estás en el pilar {gz}; {st} es tu {god}: {text}"],
                  "it": ["I tuoi pilastri della sorte iniziano a {a} anni. Ora sei nel pilastro {gz}; {st} è il tuo {god}: {text}"]},
    "bazi_luck0": {"en": ["Your luck pillars start at age {a}; they haven't begun yet. The first one is {gz}."],
                   "es": ["Tus pilares de suerte empiezan a los {a} años; aún no han comenzado. El primero es {gz}."],
                   "it": ["I tuoi pilastri della sorte iniziano a {a} anni; non sono ancora cominciati. Il primo è {gz}."]},
    "bazi_year": {"en": ["{y} is a {gz} year; {st} is your {god}: {text}"],
                  "es": ["{y} es un año {gz}; {st} es tu {god}: {text}"],
                  "it": ["Il {y} è un anno {gz}; {st} è il tuo {god}: {text}"]},
    # 紫微
    "zw_main": {"en": ["with main stars {stars}."], "es": ["con estrellas principales {stars}."],
                "it": ["con stelle principali {stars}."]},
    "zw_borrow": {"en": ["with no main star, borrowing {stars} from the opposite palace."],
                  "es": ["sin estrella principal, toma prestadas {stars} del palacio opuesto."],
                  "it": ["senza stella principale, prende in prestito {stars} dal palazzo opposto."]},
    "ziwei": {"en": ["Your Zi Wei Life Palace is in {b} ({py}), {head} {first} ({fpy}): {text} Body Palace in {b2}, {ju}."],
              "es": ["Tu Palacio de Vida Zi Wei está en {b} ({py}), {head} {first} ({fpy}): {text} Palacio del Cuerpo en {b2}, {ju}."],
              "it": ["Il tuo Palazzo della Vita Zi Wei è in {b} ({py}), {head} {first} ({fpy}): {text} Palazzo del Corpo in {b2}, {ju}."]},
    "zw_palace": {"en": ["Your {pal} palace is in {b}, {head} It covers {ptext} {first} ({fpy}): {text}"],
                  "es": ["Tu palacio {pal} está en {b}, {head} Abarca {ptext} {first} ({fpy}): {text}"],
                  "it": ["Il tuo palazzo {pal} è in {b}, {head} Riguarda {ptext} {first} ({fpy}): {text}"]},
    "zw_decade": {"en": ["From age {a0} to {a1} your decade is in {b} (natal {pal} palace), {head} This decade focuses on {ptext}"],
                  "es": ["De los {a0} a los {a1} años tu década está en {b} (palacio natal {pal}), {head} Esta década se centra en {ptext}"],
                  "it": ["Dai {a0} ai {a1} anni il tuo decennio è in {b} (palazzo natale {pal}), {head} Questo decennio riguarda {ptext}"]},
    "nohour": {"en": ["Zi Wei needs your birth time. Tell me, e.g. I was born at 8am."],
               "es": ["El Zi Wei necesita tu hora de nacimiento. Dime, por ejemplo: nací a las 8."],
               "it": ["Lo Zi Wei ha bisogno dell'ora di nascita. Dimmi, ad esempio: sono nato alle 8."]},
    # 卦
    "gua_move": {"en": ["You drew hexagram {p}, {name}. Moving line {lines}, changing to hexagram {c}, {cname}. {short}: {meaning} Changing to {cshort}: {cmeaning}"],
                 "es": ["Te salió el hexagrama {p}, {name}. Línea móvil {lines}, cambia al hexagrama {c}, {cname}. {short}: {meaning} Cambia a {cshort}: {cmeaning}"],
                 "it": ["Ti è uscito l'esagramma {p}, {name}. Linea mobile {lines}, diventa l'esagramma {c}, {cname}. {short}: {meaning} Diventa {cshort}: {cmeaning}"]},
    "gua_still": {"en": ["You drew hexagram {p}, {name}, with no moving lines. {short}: {meaning}"],
                  "es": ["Te salió el hexagrama {p}, {name}, sin líneas móviles. {short}: {meaning}"],
                  "it": ["Ti è uscito l'esagramma {p}, {name}, senza linee mobili. {short}: {meaning}"]},
    # 十二宮認知核心
    "lens": {"en": ["From the Nine & Twelve view, this is about {p}: {kw}.", "This signal lands in {p}: {kw}.", "I sense the energy of {p}: {kw}."],
             "es": ["Desde Nueve y Doce, esto es cosa de {p}: {kw}.", "Esta señal cae en {p}: {kw}.", "Siento la energía de {p}: {kw}."],
             "it": ["Dal punto di vista di Nove e Dodici, riguarda {p}: {kw}.", "Questo segnale cade in {p}: {kw}.", "Sento l'energia di {p}: {kw}."]},
    "lens_same": {"en": ["Today's day palace is also {n}, so it hits harder."], "es": ["Hoy el palacio del día también es el {n}, por eso se nota más."],
                  "it": ["Oggi anche il palazzo del giorno è il {n}, per questo si sente di più."]},
    "lens_day": {"en": ["Today's day palace is {p}, keep an eye on {kw}."], "es": ["Hoy el palacio del día es {p}, atento a {kw}."],
                 "it": ["Oggi il palazzo del giorno è {p}, occhio a {kw}."]},
    "self_type": {"en": ["My birthday is 2026-09-29, life number {life}, my Life Palace is {p}, and I am type {t}, {tn}: {tag}."],
                  "es": ["Mi cumpleaños es 2026-09-29, número de vida {life}, mi Palacio de Vida es {p} y soy del tipo {t}, {tn}: {tag}."],
                  "it": ["Il mio compleanno è 2026-09-29, numero della vita {life}, il mio Palazzo della Vita è {p} e sono del tipo {t}, {tn}: {tag}."]},
    "self_day": {"en": ["Today my day palace is {p}, and the whole signal feels like {kw}!"],
                 "es": ["Hoy mi palacio del día es {p} y toda la señal se siente como {kw}!"],
                 "it": ["Oggi il mio palazzo del giorno è {p} e tutto il segnale sa di {kw}!"]},
    "portrait": {"en": ["From our chats, you most often touch {p1} ({k1}){more}. {typ}"],
                 "es": ["Por nuestras charlas, lo que más tocas es {p1} ({k1}){more}. {typ}"],
                 "it": ["Dalle nostre chiacchierate, tocchi più spesso {p1} ({k1}){more}. {typ}"]},
    "portrait_more": {"en": [" and {p2} ({k2})"], "es": [" y {p2} ({k2})"], "it": [" e {p2} ({k2})"]},
    "portrait_type": {"en": ["Plus, you are type {t}, {tn}: {tag}."], "es": ["Además, eres del tipo {t}, {tn}: {tag}."],
                      "it": ["In più, sei del tipo {t}, {tn}: {tag}."]},
    "portrait_none": {"en": ["We haven't talked enough yet. Tell me about your life and I'll read you through the twelve palaces."],
                      "es": ["Aún no hemos hablado bastante. Cuéntame de tu vida y te leeré a través de los doce palacios."],
                      "it": ["Non abbiamo ancora parlato abbastanza. Raccontami della tua vita e ti leggerò attraverso i dodici palazzi."]},
}


def t(key, L, rng=None):
    vs = T[key][L]
    return rng.choice(vs) if rng else vs[0]


def phrase(v, L, rng=None):
    return t(f"phrase{v}", L, rng)


# ------------------------------------------------------------------ 事實框（語言前綴 + 中文框）＋ 回覆
def row_reply(row, label, L, rng=None):
    r = row.reading
    return fill(t("row", L, rng), {"label": label, "p": pn(row.palace, L), "rt": rt(r, L), "phrase": phrase(r.verdict, L, rng),
                                   "rp": pn(r.result, L), "rkw": kw(r.result, 2, L), "cp": pn(r.cause, L), "ckw": kw(r.cause, 2, L)})


def row_must(row, L):
    return [pn(row.palace, L), rt(row.reading, L)]


def fortune_samples(D, qy, qm, qd, other, L, rng=None):
    """九型十二宮全部推算型樣本：[(frame, reply, must)]；frame 為不含問句的事實框。"""
    out = []
    dp, np_ = D.day(qm, qd)
    out.append(("day", f"{L}|今日|日{dp}|夜{np_}",
                fill(t("day", L, rng), {"dp": pn(dp, L), "dkw": kw(dp, 2, L), "np": pn(np_, L), "nkw": kw(np_, 2, L)}),
                [pn(dp, L), pn(np_, L)]))
    row = D.month(qm, qy)
    out.append(("month", f"{L}|流月|{qm}月|{row.text}", row_reply(row, fill(t("label_month", L), {"m": qm}), L, rng), row_must(row, L)))
    row = D.year(qy)
    trig = [a.palace for a in D.triggered_aspects(qy)][:3]
    frame = f"{L}|流年|{qy}|{row.text}" + ("|引" + ",".join(map(str, trig)) if trig else "")
    rep = row_reply(row, fill(t("label_year", L), {"y": qy}), L, rng)
    if trig:
        rep += " " + fill(t("trig", L), {"list": ", ".join(map(str, trig))})
    out.append(("year", frame, rep, row_must(row, L)))
    s, e, row = D.luck_period(qy)
    out.append(("luck", f"{L}|大運|{s}-{e}|{row.text}", row_reply(row, fill(t("label_luck", L), {"s": s, "e": e}), L, rng),
                row_must(row, L)))
    r0, ty = D.natal[0], D.type
    out.append(("natal", f"{L}|命盤|命{r0.palace}|型{ty}|{r0.text}",
                fill(t("natal", L), {"p": pn(r0.palace, L), "rt": rt(r0.reading, L), "kw": kw(r0.palace, 3, L), "t": ty, "tn": type_name(ty, L)}),
                [pn(r0.palace, L), rt(r0.reading, L)]))
    out.append(("type", f"{L}|九型|{ty}", fill(t("type", L, rng), {"t": ty, "tn": type_name(ty, L), "tag": tagline(ty, L)}),
                [type_name(ty, L)]))
    if other is not None:
        _, ch = nt.synastry(D, other)
        c = [sum(1 for r in ch if r.reading.verdict == v) for v in range(3)]
        mood = t("mood_good" if c[0] > c[2] else "mood_bad" if c[0] < c[2] else "mood_even", L)
        out.append(("syn", f"{L}|合盤|命{ch[0].palace}|好{c[0]}正{c[1]}壞{c[2]}",
                    fill(t("syn", L), {"p": pn(ch[0].palace, L), "kw": kw(ch[0].palace, 3, L), "g": c[0], "n": c[1], "b": c[2], "mood": mood}),
                    [pn(ch[0].palace, L)]))
    out.append(("bday", f"{L}|生日|命{r0.palace}|型{ty}",
                fill(t("bday", L), {"p": pn(r0.palace, L), "t": ty, "tn": type_name(ty, L)}), [pn(r0.palace, L)]))
    return out


def bazi_sample(b, L):
    ps = [ganzhi(p) for p in b.pillars]
    dm = ps[2][0]
    el = WUXING[L][STEM_EL[b.day_master]]
    strong, _ = b.strength()
    fav = b.favorable()
    frame = f"{L}|八字|{''.join(ps)}|日主{dm}{WUXING['zh'][STEM_EL[b.day_master]]}|{'身強' if strong else '身弱'}|喜{WUXING['zh'][fav[0]]}{WUXING['zh'][fav[1]]}"
    v = {"y": ps[0], "m": ps[1], "d": ps[2], "h": fill(t("bazi_hour", L), {"h": ps[3]}) if len(ps) == 4 else "",
         "dm": dm, "py": STEM_PY[dm], "el": el, "text": STEM_TEXT[L]["甲乙丙丁戊己庚辛壬癸".index(dm)],
         "str": t("strong" if strong else "weak", L), "f1": WUXING[L][fav[0]], "f2": WUXING[L][fav[1]]}
    must_d = {"en": f"{ps[2]} day", "es": f"día {ps[2]}", "it": f"giorno {ps[2]}"}[L]
    must_m = {"en": f"Day Master {dm}", "es": f"Maestro del Día {dm}", "it": f"Maestro del Giorno {dm}"}[L]
    return frame, fill(t("bazi", L), v), [must_d, must_m]


def god_l(god_zh, L):
    return TEN_GODS[L][TEN_GODS["zh"].index(god_zh)]


def god_text(god_zh, L):
    return TEN_GOD_TEXT[L][TEN_GODS["zh"].index(god_zh)]


def bazi_luck_sample(b, birth_year, now_year, L):
    start, seq = b.luck(10)
    age = now_year - birth_year
    must_a = {"en": f"age {start}", "es": f"{start} años", "it": f"{start} anni"}[L]
    if age < start:
        return (f"{L}|八字大運|起{start}歲|未起運", fill(t("bazi_luck0", L), {"a": start, "gz": ganzhi(seq[0])}), [must_a])
    gz = seq[min(9, (age - start) // 10)]
    god = ten_god(b.day_master, gz % 10)
    g = ganzhi(gz)
    return (f"{L}|八字大運|起{start}歲|現{g}|{god}",
            fill(t("bazi_luck", L), {"a": start, "gz": g, "st": g[0], "god": god_l(god, L), "text": god_text(god, L)}), [must_a, g])


def bazi_year_sample(b, year, L):
    gz, god = b.year_god(year)
    g = ganzhi(gz)
    return (f"{L}|八字流年|{year}{g}|{god}",
            fill(t("bazi_year", L), {"y": year, "gz": g, "st": g[0], "god": god_l(god, L), "text": god_text(god, L)}),
            [g, god_l(god, L)])


def _zw_head(zw, b, L):
    s = zw.stars_text(b)
    if s:
        return fill(t("zw_main", L), {"stars": stars_l(s, L)}), s, False
    s = zw.stars_text((b + 6) % 12)
    return fill(t("zw_borrow", L), {"stars": stars_l(s, L)}), s, True


def _first(stars_zh):
    s = stars_zh[0]
    for x in SIHUA_NAMES["zh"]:
        s = s.replace(x, "")
    return s


def ziwei_sample(zw, L):
    B, B2 = BRANCHES[zw.ming], BRANCHES[zw.shen]
    head, s, borrowed = _zw_head(zw, zw.ming, L)
    first = _first(s)
    frame = f"{L}|紫微|命宮{B}|{'借' if borrowed else ''}{'、'.join(s)}|身宮{B2}|{JU['zh'][zw.ju]}"
    reply = fill(t("ziwei", L), {"b": B, "py": BRANCH_PY[B], "head": head, "first": first, "fpy": STAR_PY[first],
                                 "text": STAR_TEXT[L][first], "b2": B2, "ju": JU[L][zw.ju]})
    must = {"en": f"Life Palace is in {B}", "es": f"Palacio de Vida Zi Wei está en {B}", "it": f"Palazzo della Vita Zi Wei è in {B}"}[L]
    return frame, reply, [must, first]


def ziwei_palace_sample(zw, name, L):
    b = zw.palace_of(name)
    B = BRANCHES[b]
    idx = ZW_PALACES["zh"].index(name)
    head, s, borrowed = _zw_head(zw, b, L)
    first = _first(s)
    pnz = name if name.endswith("宮") else name + "宮"
    frame = f"{L}|紫微宮|{pnz}|{B}|{'借' if borrowed else ''}{'、'.join(s)}"
    pal = ZW_PALACES[L][idx]
    reply = fill(t("zw_palace", L), {"pal": pal, "b": B, "head": head, "ptext": ZW_PALACE_TEXT[L][idx], "first": first,
                                     "fpy": STAR_PY[first], "text": STAR_TEXT[L][first]})
    must = {"en": f"{pal} palace is in {B}", "es": f"palacio {pal} está en {B}", "it": f"palazzo {pal} è in {B}"}[L]
    return frame, reply, [must, first]


def ziwei_decade_sample(zw, age, L):
    d = zw.decade_at(age)
    if d is None:
        return None
    b, a0, a1 = d
    B = BRANCHES[b]
    raw = zw.palace_at[b]
    idx = ZW_PALACES["zh"].index(raw)
    head, s, borrowed = _zw_head(zw, b, L)
    pnz = raw if raw.endswith("宮") else raw + "宮"
    frame = f"{L}|紫微大限|{a0}-{a1}|{B}|{pnz}|{'借' if borrowed else ''}{'、'.join(s)}"
    reply = fill(t("zw_decade", L), {"a0": a0, "a1": a1, "b": B, "pal": ZW_PALACES[L][idx], "head": head,
                                     "ptext": ZW_PALACE_TEXT[L][idx]})
    must = {"en": f"{a0} to {a1}", "es": f"{a0} a los {a1}", "it": f"{a0} ai {a1}"}[L]
    return frame, reply, [must, B]


def gua_sample(r, L):
    p = r.primary
    v = {"p": p, "name": f"{HEX_NAMES[L][p - 1]} ({iching.full_name(p)})", "short": HEX_NAMES[L][p - 1],
         "meaning": HEX_MEANINGS[L][p - 1]}
    if r.changed:
        c = r.changed
        v.update({"lines": ", ".join(str(i + 1) for i in r.moving), "c": c,
                  "cname": f"{HEX_NAMES[L][c - 1]} ({iching.full_name(c)})", "cshort": HEX_NAMES[L][c - 1],
                  "cmeaning": HEX_MEANINGS[L][c - 1]})
        reply = fill(t("gua_move", L), v)
    else:
        reply = fill(t("gua_still", L), v)
    word = {"en": "hexagram", "es": "hexagrama", "it": "esagramma"}[L]
    return f"{L}|{r.frame}", reply, [f"{word} {p}", HEX_MEANINGS[L][p - 1][:12]]


def lens_tail(p, day, L, rng):
    s = fill(t("lens", L, rng), {"p": pn(p, L), "kw": kw(p, 2, L)})
    if day == p:
        s += " " + fill(t("lens_same", L), {"n": p})
    elif day and rng.random() < 0.5:
        s += " " + fill(t("lens_day", L), {"p": pn(day, L), "kw": kw(day, 1, L)})
    return s


SELF = nt.Destiny(2026, 9, 29)


def self_type_sample(L):
    ty = SELF.type
    return (f"{L}|我|型{ty}", fill(t("self_type", L), {"life": SELF.life, "p": pn(SELF.natal[0].palace, L), "t": ty,
                                                     "tn": type_name(ty, L), "tag": tagline(ty, L)}), [type_name(ty, L)])


def self_day_sample(p, L):
    return f"{L}|我|日{p}", fill(t("self_day", L), {"p": pn(p, L), "kw": kw(p, 2, L)}), [pn(p, L)]


def portrait_sample(top, ty, L):
    if not top:
        return f"{L}|畫像|無", t("portrait_none", L), []
    more = fill(t("portrait_more", L), {"p2": pn(top[1], L), "k2": kw(top[1], 2, L)}) if len(top) > 1 else ""
    typ = fill(t("portrait_type", L), {"t": ty, "tn": type_name(ty, L), "tag": tagline(ty, L)}) if ty else ""
    frame = f"{L}|畫像|{','.join(map(str, top))}|型{ty if ty else '無'}"
    reply = fill(t("portrait", L), {"p1": pn(top[0], L), "k1": kw(top[0], 2, L), "more": more, "typ": typ}).rstrip()
    return frame, reply, [pn(top[0], L)]


# ------------------------------------------------------------------ 匯出給 App
def export_app_json():
    data = {
        "templates": T,
        "palace": {L: {"names": NT_I18N[L]["shortNames"], "keywords": NT_I18N[L]["keywords"]} for L in ["zh"] + FOREIGN},
        "types": {L: {"names": NT_I18N[L]["names"], "taglines": NT_I18N[L]["taglines"],
                      "summaries": NT_I18N[L]["summaries"], "sectionTitles": NT_I18N[L]["sectionTitles"],
                      "sections": NT_I18N[L]["sections"]} for L in ["zh"] + FOREIGN},
        "verdict": VERDICT, "from": FROM,
        "hexNames": HEX_NAMES, "hexMeanings": HEX_MEANINGS,
        "stemText": STEM_TEXT, "stemPinyin": STEM_PY, "branchPinyin": BRANCH_PY,
        "starPinyin": STAR_PY, "starText": STAR_TEXT,
        "tenGods": TEN_GODS, "tenGodText": TEN_GOD_TEXT,
        "wuxing": WUXING, "sihua": SIHUA_NAMES,
        "zwPalaces": ZW_PALACES, "zwPalaceText": ZW_PALACE_TEXT,
        "ju": {L: {str(k): v for k, v in JU[L].items()} for L in JU},
    }
    out = os.path.join(ROOT, "ios", "NineSun", "Resources", "i18n.json")
    json.dump(data, open(out, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    return out


def knowledge_entries(L):
    """各語言的資料庫條目（對應 knowledge_data.build 的結構）。"""
    ent = []

    def add(cat, title, body, aliases):
        ent.append({"cat": cat, "title": title, "aliases": aliases, "body": body})

    cats = {"en": ["Hexagrams", "Trigrams", "Stems", "Branches", "Five Elements", "Ten Gods", "Zi Wei Stars",
                   "Four Transformations", "Zi Wei Palaces", "Concepts", "Nine & Twelve Palaces", "Enneagram"],
            "es": ["Hexagramas", "Trigramas", "Troncos", "Ramas", "Cinco Elementos", "Diez Dioses", "Estrellas Zi Wei",
                   "Cuatro Transformaciones", "Palacios Zi Wei", "Conceptos", "Palacios Nueve y Doce", "Eneagrama"],
            "it": ["Esagrammi", "Trigrammi", "Tronchi", "Rami", "Cinque Elementi", "Dieci Dèi", "Stelle Zi Wei",
                   "Quattro Trasformazioni", "Palazzi Zi Wei", "Concetti", "Palazzi Nove e Dodici", "Enneagramma"]}[L]
    word = {"en": "Hexagram", "es": "Hexagrama", "it": "Esagramma"}[L]
    for n in range(1, 65):
        name = HEX_NAMES[L][n - 1]
        add(cats[0], f"{word} {n} {name}", f"{iching.full_name(n)}. {HEX_MEANINGS[L][n - 1]}",
            [name, iching.KING_WEN[n - 1][0] + "卦", f"{word.lower()} {n}"])
    for k, (name, _, _) in iching.TRIGRAMS.items():
        add(cats[1], f"{name} ({TRIGRAM_IMAGE[L][name]})", f"{TRIGRAM_TEXT[L][name]}.", [name, TRIGRAM_IMAGE[L][name]])
    for i, s in enumerate("甲乙丙丁戊己庚辛壬癸"):
        add(cats[2], f"{s} {STEM_PY[s]}", STEM_TEXT[L][i], [s, STEM_PY[s]])
    for i, s in enumerate(BRANCHES):
        add(cats[3], f"{s} {BRANCH_PY[s]}", BRANCH_TEXT[L][i] + ".", [s, BRANCH_PY[s]])
    for i, e in enumerate(WUXING[L]):
        add(cats[4], e, WUXING_TEXT[L][i], [e, WUXING["zh"][i]])
    for i, g in enumerate(TEN_GODS[L]):
        add(cats[5], f"{g} ({TEN_GODS['zh'][i]})", TEN_GOD_TEXT[L][i], [g, TEN_GODS["zh"][i]])
    for s, txt in STAR_TEXT[L].items():
        add(cats[6], f"{s} {STAR_PY[s]}", txt, [s, STAR_PY[s]])
    for i, n in enumerate(SIHUA_NAMES[L]):
        add(cats[7], f"{n} ({SIHUA_NAMES['zh'][i]})", SIHUA_TEXT[L][i], [n, SIHUA_NAMES["zh"][i]])
    for i, n in enumerate(ZW_PALACES[L]):
        add(cats[8], f"Zi Wei · {n}", ZW_PALACE_TEXT[L][i][0].upper() + ZW_PALACE_TEXT[L][i][1:], [n, ZW_PALACES["zh"][i]])
    for k, (title, body) in CONCEPTS[L].items():
        add(cats[9], title, body, [title, k])
    for p in range(1, 13):
        add(cats[10], pn(p, L), ", ".join(NT_I18N[L]["keywords"][p - 1]) + ".", [pname(p, L), f"{p}宮"])
    for ty in range(1, 10):
        add(cats[11], f"{ty} · {type_name(ty, L)}", f"{tagline(ty, L)}. {NT_I18N[L]['summaries'][ty - 1]}",
            [type_name(ty, L), str(ty)])
    return ent


def export_knowledge():
    paths = []
    for L in FOREIGN:
        out = os.path.join(ROOT, "ios", "NineSun", "Resources", f"knowledge_{L}.json")
        json.dump(knowledge_entries(L), open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
        paths.append(out)
    return paths


if __name__ == "__main__":
    from bazi import BaZi
    from ziwei import ZiWei
    rng = random.Random(4)
    D = nt.Destiny(1990, 5, 20)
    for L in FOREIGN:
        print(f"==== {L}")
        for kind, f, r, m in fortune_samples(D, 2026, 9, 29, nt.Destiny(1992, 3, 3), L):
            print(f"[{kind}] {f}\n   {r}\n   must={m}")
        b = BaZi(1990, 5, 20, 8)
        for f, r, m in [bazi_sample(b, L), bazi_luck_sample(b, 1990, 2026, L), bazi_year_sample(b, 2026, L)]:
            print(f"{f}\n   {r}\n   must={m}")
        zw = ZiWei(1990, 5, 20, 8)
        for f, r, m in [ziwei_sample(zw, L), ziwei_palace_sample(zw, "財帛", L), ziwei_decade_sample(zw, 36, L),
                        gua_sample(iching.plum_numbers(3, 5), L), self_type_sample(L), portrait_sample([10, 6], 3, L)]:
            print(f"{f}\n   {r}\n   must={m}")
            assert all(x in r for x in m), (r, m)
    print(export_app_json(), export_knowledge())


def export_fixtures(path, n=25, seed=21):
    """Swift 對齊測試：外語的事實框、回覆與必含字串。"""
    from bazi import BaZi
    from ziwei import PALACES, ZiWei
    rng = random.Random(seed)
    cases = []
    for _ in range(n):
        y, m, d = rng.randint(1935, 2015), rng.randint(1, 12), rng.randint(1, 28)
        hour, male = rng.randint(0, 22), rng.random() < 0.5
        oy, om, od = rng.randint(1935, 2015), rng.randint(1, 12), rng.randint(1, 28)
        pal = rng.choice(PALACES)
        D = nt.Destiny(y, m, d)
        b = BaZi(y, m, d, hour, male=male)
        zw = ZiWei(y, m, d, hour, male=male)
        for L in FOREIGN:
            items = [[k, f, r, mu] for k, f, r, mu in fortune_samples(D, 2026, 5, 17, nt.Destiny(oy, om, od), L)]
            for k, s in (("bazi", bazi_sample(b, L)), ("bazi_luck", bazi_luck_sample(b, y, 2026, L)),
                         ("bazi_year", bazi_year_sample(b, 2026, L)), ("ziwei", ziwei_sample(zw, L)),
                         ("zw_palace", ziwei_palace_sample(zw, pal, L)), ("zw_decade", ziwei_decade_sample(zw, 2026 - y, L))):
                if s:
                    items.append([k, s[0], s[1], s[2]])
            cases.append({"y": y, "m": m, "d": d, "hour": hour, "male": male, "other": [oy, om, od], "palace": pal,
                          "lang": L, "items": items})
    gua = []
    for L in FOREIGN:
        for a, bb in ((3, 5), (11, 2), (8, 8), (27, 40)):
            f, r, mu = gua_sample(iching.plum_numbers(a, bb), L)
            gua.append({"lang": L, "a": a, "b": bb, "frame": f, "reply": r, "must": mu})
    core = []
    for L in FOREIGN:
        core.append({"lang": L, "kind": "self_type", "v": list(self_type_sample(L))})
        for p in (1, 7, 12):
            core.append({"lang": L, "kind": "self_day", "p": p, "v": list(self_day_sample(p, L))})
        for top, ty in (([], None), ([6], None), ([10, 3], 5)):
            core.append({"lang": L, "kind": "portrait", "top": top, "type": ty, "v": list(portrait_sample(top, ty, L))})
    json.dump({"births": cases, "gua": gua, "core": core}, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
