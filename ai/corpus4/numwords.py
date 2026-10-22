# -*- coding: utf-8 -*-
"""0–999 的數字，中文（台灣用法，200 說「兩百」）、English（美式，不加 and）、Español、Italiano。"""

ZH_D = "零一二三四五六七八九"


def zh(n):
    if n < 10:
        return ZH_D[n]
    if n < 20:
        return "十" + (ZH_D[n % 10] if n % 10 else "")
    if n < 100:
        t, u = divmod(n, 10)
        return ZH_D[t] + "十" + (ZH_D[u] if u else "")
    h, r = divmod(n, 100)
    head = ("兩" if h == 2 else ZH_D[h]) + "百"
    if r == 0:
        return head
    if r < 10:
        return head + "零" + ZH_D[r]
    t, u = divmod(r, 10)
    return head + ZH_D[t] + "十" + (ZH_D[u] if u else "")


EN_U = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen",
        "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
EN_T = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]


def en(n):
    if n < 20:
        return EN_U[n]
    if n < 100:
        t, u = divmod(n, 10)
        return EN_T[t] + ("-" + EN_U[u] if u else "")
    h, r = divmod(n, 100)
    return EN_U[h] + " hundred" + (" " + en(r) if r else "")


ES_U = ["cero", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "once", "doce", "trece",
        "catorce", "quince", "dieciséis", "diecisiete", "dieciocho", "diecinueve", "veinte", "veintiuno", "veintidós", "veintitrés",
        "veinticuatro", "veinticinco", "veintiséis", "veintisiete", "veintiocho", "veintinueve"]
ES_T = ["", "", "", "treinta", "cuarenta", "cincuenta", "sesenta", "setenta", "ochenta", "noventa"]
ES_H = ["", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos", "seiscientos", "setecientos", "ochocientos",
        "novecientos"]


def es(n):
    if n < 30:
        return ES_U[n]
    if n < 100:
        t, u = divmod(n, 10)
        return ES_T[t] + (" y " + ES_U[u] if u else "")
    if n == 100:
        return "cien"
    h, r = divmod(n, 100)
    return ES_H[h] + (" " + es(r) if r else "")


IT_U = ["zero", "uno", "due", "tre", "quattro", "cinque", "sei", "sette", "otto", "nove", "dieci", "undici", "dodici", "tredici",
        "quattordici", "quindici", "sedici", "diciassette", "diciotto", "diciannove"]
IT_T = ["", "", "venti", "trenta", "quaranta", "cinquanta", "sessanta", "settanta", "ottanta", "novanta"]


def it(n):
    if n < 20:
        return IT_U[n]
    if n < 100:
        t, u = divmod(n, 10)
        tens = IT_T[t]
        if u in (1, 8):
            tens = tens[:-1]          # ventuno, ventotto
        unit = "tré" if u == 3 else (IT_U[u] if u else "")
        return tens + unit
    h, r = divmod(n, 100)
    head = "cento" if h == 1 else IT_U[h] + "cento"
    if r == 0:
        return head
    tail = it(r)
    if r == 3:
        tail = "tré"
    if 80 <= r < 90:
        head = head[:-1]              # centottanta、duecentottantuno
    return head + tail


def numbers(limit=1000):
    return [{"zh": zh(n), "en": en(n), "es": es(n), "it": it(n)} for n in range(limit)]


if __name__ == "__main__":
    for n in [0, 1, 3, 10, 11, 16, 20, 21, 23, 28, 30, 31, 38, 99, 100, 101, 103, 110, 115, 180, 188, 200, 201, 213, 383, 500, 555, 999]:
        print(n, zh(n), en(n), es(n), it(n), sep=" | ")
