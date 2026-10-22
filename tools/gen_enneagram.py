#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 tools/enneagram_data.py 產生成 Swift 與 Kotlin 兩份程式碼。

    python3 tools/gen_enneagram.py

兩個平台的內容由同一份資料產生，不會有一邊改了另一邊忘了改的問題。
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

import enneagram_data as D  # noqa: E402

LANGS = ("zh", "en", "es", "it")
SWIFT_OUT = os.path.join(ROOT, "ios", "NineTwelve", "Engine", "Enneagram.swift")
KOTLIN_OUT = os.path.join(
    ROOT, "android", "app", "src", "main", "java", "com", "ninetwelve", "fortune",
    "engine", "Enneagram.kt")

HEADER = """十二宮的靈數同時就是九型人格的型號：靈數 5 即第五型。

內容為作者提供的定本（中文），英／西／義為翻譯。
這個檔案由 tools/gen_enneagram.py 產生，不要直接改；
要改內容請改 tools/enneagram_data.py 再重新產生。"""


def esc(s, kotlin=False):
    out = s.replace("\\", "\\\\").replace('"', '\\"')
    if kotlin:
        out = out.replace("$", "\\$")
    return out


def wrap(items, indent, kotlin=False):
    """把字串陣列排成不超過 100 欄的多行。"""
    pad = " " * indent
    lines, cur = [], pad
    for s in items:
        piece = '"' + esc(s, kotlin) + '", '
        if len(cur) + len(piece) > 104 and cur.strip():
            lines.append(cur.rstrip())
            cur = pad
        cur += piece
    lines.append(cur.rstrip().rstrip(","))
    return "\n".join(lines)


# ────────────────────────────── Swift ──────────────────────────────

def swift():
    p = []
    p.append("import Foundation\n")
    p.append("/// " + HEADER.replace("\n", "\n/// ") + "\npublic enum Enneagram {\n")
    p.append("    /// 一共九型。\n    public static let count = 9\n")
    p.append("    /// 每型的段落數。\n    public static let sectionCount = %d\n" % len(D.SECTION_TITLES))
    p.append("""    /// 靈數幾就是第幾型。
    public static func type(forLifeNumber n: Int) -> Int { Num.r9(n) }

    /// 「第五型」／「Type 5」
    public static func label(_ type: Int, lang: Lang) -> String {
        let n = Num.r9(type)
        switch lang {
        case .zh: return "第\\(["一", "二", "三", "四", "五", "六", "七", "八", "九"][n - 1])型"
        case .en: return "Type \\(n)"
        case .es, .it: return "Tipo \\(n)"
        }
    }

    /// 型名，例如「格物致知者」。
    public static func name(_ type: Int, lang: Lang) -> String {
        pick(names, type, lang)
    }

    /// 一行的性格摘要。
    public static func tagline(_ type: Int, lang: Lang) -> String {
        pick(taglines, type, lang)
    }

    /// 開頭的整段介紹。
    public static func summary(_ type: Int, lang: Lang) -> String {
        pick(summaries, type, lang)
    }

    /// 第 index 個段落的標題（0 起算）。
    public static func sectionTitle(_ index: Int, lang: Lang) -> String {
        pick(sectionTitles, index + 1, lang)
    }

    /// 第 index 個段落的條目（0 起算）。
    public static func section(_ type: Int, _ index: Int, lang: Lang) -> [String] {
        let table: [[[String]]]
        switch lang {
        case .zh: table = secZh
        case .en: table = secEn
        case .es: table = secEs
        case .it: table = secIt
        }
        return table[Num.r9(type) - 1][index]
    }

    /// 該型的代表色。九個型號各有一色，彼此分得開。
    public static func rgb(_ type: Int) -> (red: Double, green: Double, blue: Double) {
        let hex = colors[Num.r9(type) - 1]
        return (Double((hex >> 16) & 0xFF) / 255.0,
                Double((hex >> 8) & 0xFF) / 255.0,
                Double(hex & 0xFF) / 255.0)
    }

    private static func pick(_ table: [[String]], _ oneBased: Int, _ lang: Lang) -> String {
        let row = table[oneBased - 1]
        switch lang {
        case .zh: return row[0]
        case .en: return row[1]
        case .es: return row[2]
        case .it: return row[3]
        }
    }
""")

    p.append("    private static let colors: [Int] = [")
    p.append("        " + ", ".join("0x" + D.COLORS[i] for i in range(1, 10)))
    p.append("    ]\n")

    def table(name, rows):
        out = ["    private static let %s: [[String]] = [" % name]
        for row in rows:
            out.append("        [" + ", ".join('"' + esc(row[l]) + '"' for l in LANGS) + "],")
        out.append("    ]\n")
        return "\n".join(out)

    p.append(table("names", [t["name"] for t in D.TYPES]))
    p.append(table("taglines", [t["tagline"] for t in D.TYPES]))
    p.append(table("summaries", [t["summary"] for t in D.TYPES]))
    p.append(table("sectionTitles", D.SECTION_TITLES))

    # 每型每語言各一個常數，避免 Swift 對超大巢狀字面值型別檢查過慢
    for lang in LANGS:
        suffix = lang.capitalize()
        for t in D.TYPES:
            p.append("    private static let sec%s%d: [[String]] = [" % (suffix, t["n"]))
            for sec in t["sections"]:
                p.append("        [")
                p.append(wrap(sec[lang], 12))
                p.append("        ],")
            p.append("    ]\n")
        p.append("    private static let sec%s: [[[String]]] = [%s]\n"
                 % (suffix, ", ".join("sec%s%d" % (suffix, t["n"]) for t in D.TYPES)))

    p.append("}")
    return "\n".join(p) + "\n"


# ────────────────────────────── Kotlin ──────────────────────────────

def kotlin():
    p = []
    p.append("package com.ninetwelve.fortune.engine\n")
    p.append("/**\n * " + HEADER.replace("\n", "\n * ") + "\n */\nobject Enneagram {\n")
    p.append("    /** 一共九型。 */\n    const val COUNT = 9\n")
    p.append("    /** 每型的段落數。 */\n    const val SECTION_COUNT = %d\n" % len(D.SECTION_TITLES))
    p.append("""    /** 靈數幾就是第幾型。 */
    fun typeForLifeNumber(n: Int): Int = Num.r9(n)

    /** 「第五型」／「Type 5」 */
    fun label(type: Int, lang: Lang): String {
        val n = Num.r9(type)
        return when (lang) {
            Lang.ZH -> "第" + listOf("一", "二", "三", "四", "五", "六", "七", "八", "九")[n - 1] + "型"
            Lang.EN -> "Type $n"
            Lang.ES, Lang.IT -> "Tipo $n"
        }
    }

    /** 型名，例如「格物致知者」。 */
    fun name(type: Int, lang: Lang): String = pick(names, type, lang)

    /** 一行的性格摘要。 */
    fun tagline(type: Int, lang: Lang): String = pick(taglines, type, lang)

    /** 開頭的整段介紹。 */
    fun summary(type: Int, lang: Lang): String = pick(summaries, type, lang)

    /** 第 index 個段落的標題（0 起算）。 */
    fun sectionTitle(index: Int, lang: Lang): String = pick(sectionTitles, index + 1, lang)

    /** 第 index 個段落的條目（0 起算）。 */
    fun section(type: Int, index: Int, lang: Lang): List<String> {
        val table = when (lang) {
            Lang.ZH -> secZh
            Lang.EN -> secEn
            Lang.ES -> secEs
            Lang.IT -> secIt
        }
        return table[Num.r9(type) - 1][index]
    }

    /** 該型的代表色，0xRRGGBB。九個型號各有一色，彼此分得開。 */
    fun colorHex(type: Int): Int = colors[Num.r9(type) - 1]

    private fun pick(table: List<List<String>>, oneBased: Int, lang: Lang): String {
        val row = table[oneBased - 1]
        return when (lang) {
            Lang.ZH -> row[0]
            Lang.EN -> row[1]
            Lang.ES -> row[2]
            Lang.IT -> row[3]
        }
    }
""")

    p.append("    private val colors: List<Int> = listOf(")
    p.append("        " + ", ".join("0x" + D.COLORS[i] for i in range(1, 10)))
    p.append("    )\n")

    def table(name, rows):
        out = ["    private val %s: List<List<String>> = listOf(" % name]
        for row in rows:
            out.append("        listOf(" + ", ".join('"' + esc(row[l], True) + '"' for l in LANGS) + "),")
        out.append("    )\n")
        return "\n".join(out)

    p.append(table("names", [t["name"] for t in D.TYPES]))
    p.append(table("taglines", [t["tagline"] for t in D.TYPES]))
    p.append(table("summaries", [t["summary"] for t in D.TYPES]))
    p.append(table("sectionTitles", D.SECTION_TITLES))

    for lang in LANGS:
        suffix = lang.capitalize()
        for t in D.TYPES:
            p.append("    private val sec%s%d: List<List<String>> = listOf(" % (suffix, t["n"]))
            for sec in t["sections"]:
                p.append("        listOf(")
                p.append(wrap(sec[lang], 12, kotlin=True))
                p.append("        ),")
            p.append("    )\n")
        p.append("    private val sec%s: List<List<List<String>>> = listOf(%s)\n"
                 % (suffix, ", ".join("sec%s%d" % (suffix, t["n"]) for t in D.TYPES)))

    p.append("}")
    return "\n".join(p) + "\n"


def main():
    open(SWIFT_OUT, "w", encoding="utf-8").write(swift())
    print("wrote", os.path.relpath(SWIFT_OUT, ROOT))
    open(KOTLIN_OUT, "w", encoding="utf-8").write(kotlin())
    print("wrote", os.path.relpath(KOTLIN_OUT, ROOT))


if __name__ == "__main__":
    main()
