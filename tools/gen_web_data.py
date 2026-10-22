#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把內容資料整理成網站用的 Python 檔，讓 web/ 可以整包搬去伺服器。

    python3 tools/gen_web_data.py

產生兩個檔：
  web/server/palace_data.py     十二宮含義（來源：iOS 的 PalaceMeanings.swift）
  web/server/enneagram_data.py  九型人格（來源：tools/enneagram_data.py）

兩個都是產生檔，不要直接改，要改請改上面說的來源再重新產生。
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "ios", "NineTwelve", "Engine", "PalaceMeanings.swift")
OUT = os.path.join(ROOT, "web", "server", "palace_data.py")

LANGS = ("zh", "en", "es", "it")


def strip_comments(src):
    """去掉 // 註解，但不要動到字串裡的內容。"""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == '"':
            out.append(c)
            i += 1
            while i < n:
                out.append(src[i])
                if src[i] == "\\":
                    i += 1
                    if i < n:
                        out.append(src[i])
                        i += 1
                    continue
                if src[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def block_after(src, marker):
    """取 marker 之後那一組配對的中括號內容。"""
    start = src.index(marker) + len(marker)
    start = src.index("[", start)
    depth, i = 0, start
    while i < len(src):
        if src[i] == '"':                       # 跳過字串
            i += 1
            while i < len(src):
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == '"':
                    break
                i += 1
        elif src[i] == "[":
            depth += 1
        elif src[i] == "]":
            depth -= 1
            if depth == 0:
                return src[start:i + 1]
        i += 1
    raise ValueError("中括號沒有配對：" + marker)


def strings_in(text):
    return [m.group(1).replace('\\"', '"').replace("\\\\", "\\")
            for m in re.finditer(r'"((?:\\.|[^"\\])*)"', text)]


def rows_in(text):
    """把 [[...], [...]] 拆成每一列的字串陣列。"""
    rows, depth, cur = [], 0, []
    i = 0
    while i < len(text):
        c = text[i]
        if c == '"':
            j = i + 1
            buf = []
            while j < len(text):
                if text[j] == "\\":
                    buf.append(text[j + 1])
                    j += 2
                    continue
                if text[j] == '"':
                    break
                buf.append(text[j])
                j += 1
            if depth >= 2:
                cur.append("".join(buf))
            i = j + 1
            continue
        if c == "[":
            depth += 1
            if depth == 2:
                cur = []
        elif c == "]":
            if depth == 2:
                rows.append(cur)
            depth -= 1
        i += 1
    return rows


def main():
    src = strip_comments(open(SRC, encoding="utf-8").read())

    short = {}
    for lang in LANGS:
        name = "short" + lang.capitalize()
        short[lang] = strings_in(block_after(src, "let %s = " % name))
        if len(short[lang]) != 12:
            sys.exit("%s 應該有 12 個簡稱，實際 %d 個" % (name, len(short[lang])))

    table = {}
    for lang in LANGS:
        table[lang] = rows_in(block_after(src, "let %s: [[String]] = " % lang))
        if len(table[lang]) != 12:
            sys.exit("%s 應該有 12 宮，實際 %d 宮" % (lang, len(table[lang])))

    counts = [len(r) for r in table["zh"]]
    for lang in LANGS:
        got = [len(r) for r in table[lang]]
        if got != counts:
            sys.exit("%s 的條目數與中文不一致：%s vs %s" % (lang, got, counts))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write('# -*- coding: utf-8 -*-\n')
        f.write('"""十二宮含義。\n\n'
                '這個檔案由 tools/gen_palace_py.py 從\n'
                'ios/NineTwelve/Engine/PalaceMeanings.swift 產生，不要直接改。\n'
                '"""\n\n')
        f.write("SHORT = {\n")
        for lang in LANGS:
            f.write("    %r: %r,\n" % (lang, short[lang]))
        f.write("}\n\n")
        f.write("KEYWORDS = {\n")
        for lang in LANGS:
            f.write("    %r: [\n" % lang)
            for row in table[lang]:
                f.write("        %r,\n" % (row,))
            f.write("    ],\n")
        f.write("}\n")

    print("wrote", os.path.relpath(OUT, ROOT))
    print("每宮條目數:", counts)

    # 九型人格：直接把資料檔複製一份過去，讓 web/ 自成一包
    src_e = os.path.join(ROOT, "tools", "enneagram_data.py")
    dst_e = os.path.join(ROOT, "web", "server", "enneagram_data.py")
    body = open(src_e, encoding="utf-8").read()
    note = ("# 這個檔案由 tools/gen_web_data.py 從 tools/enneagram_data.py 複製而來，\n"
            "# 不要直接改；要改請改來源那一份再重新產生。\n")
    with open(dst_e, "w", encoding="utf-8") as f:
        f.write(note + body)
    print("wrote", os.path.relpath(dst_e, ROOT))


if __name__ == "__main__":
    main()
