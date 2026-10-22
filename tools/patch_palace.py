#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""依作者提供的新版十二宮含義，重寫 Swift 與 Kotlin 兩份定本。

    python3 tools/patch_palace.py

四種語言一起改，改完兩個平台的內容一定一致。
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "web", "server"))
sys.path.insert(0, os.path.join(ROOT, "tools"))

import palace_data as P  # noqa: E402

SWIFT = os.path.join(ROOT, "ios", "NineTwelve", "Engine", "PalaceMeanings.swift")
KOTLIN = os.path.join(ROOT, "android", "app", "src", "main", "java", "com",
                      "ninetwelve", "fortune", "engine", "PalaceMeanings.kt")
LANGS = ("zh", "en", "es", "it")

# 作者的新版中文定本，只列出有改動的宮
NEW_ZH = {
    3: ["交流", "交談", "思考", "思想", "思維活躍", "學習", "語言", "年齡比本人小的人",
        "同輩", "同事", "同學", "同胞", "鄰居", "兄弟姐妹", "出門", "學業",
        "靈活", "好動", "離開", "分離", "走了", "活力", "新鮮感", "精神", "甲狀腺"],
    2: ["食物", "物質", "我的錢", "清秀的人", "開銷", "正財", "價值觀", "認知",
        "動力", "口腔"],
    5: ["受人關注", "娛樂", "享樂", "快樂", "桃花", "吸引力", "性", "引人矚目",
        "戀愛", "男性", "被看見", "父親"],
    6: ["勞碌", "忙碌", "思緒混亂無序", "心累", "勞累", "緊張", "議論",
        "日常的事物", "勞動", "想得多", "社交", "交際", "想法", "聚焦",
        "執念", "重複的事情", "注意力", "反覆"],
    7: ["在意別人", "心思在別人身上", "他人", "遇見的人", "羈絆", "一對一關係",
        "伴侶", "情侶", "對象", "戀人", "身邊的人", "婚姻"],
    8: ["偏財", "孤獨", "無聊", "煎熬", "焦灼", "無助", "黑暗", "痛苦",
        "折磨", "感覺時間漫長", "身體", "他人的錢", "別人的隱私和隱秘",
        "別人的私生活", "隱耗", "生存", "體力", "精力", "健康情況"],
    9: ["樂觀", "正向", "愉快", "愉悅", "幸運", "運氣", "宗教", "信仰", "遷移",
        "文件", "文書", "文憑", "國外", "出遠門", "文化", "豁達", "開朗",
        "積極", "理想", "善良", "品德", "盲目", "自大", "意義", "機遇", "機會"],
    11: ["朋友", "群體", "變動", "變化", "特別", "差異", "理智", "理性",
         "精神困擾", "網絡", "不穩定", "波折", "奔波", "折騰", "奔波輾轉",
         "貴人"],
    12: ["沉迷", "迷茫", "幻想", "緣分", "脾氣", "性格", "品行", "道德", "幕後",
         "悲觀", "逃避", "悲傷", "多愁善感", "嚮往", "缺愛", "暗戀", "隱沒",
         "隱藏", "消耗", "隔離", "自我瓦解", "業力", "循環", "投胎", "輪迴",
         "玄秘", "玄學", "隔絕", "隱匿", "欺騙"],
}

# 新出現的詞，四種語言的譯法
NEW_TERMS = {
    "無聊": ("Boredom", "Aburrimiento", "Noia"),
    "品行": ("Conduct", "Conducta", "Condotta"),
    "道德": ("Morality", "Moralidad", "Moralità"),
    "價值觀": ("Values", "Valores", "Valori"),
    "認知": ("Cognition", "Cognición", "Cognizione"),
    "動力": ("Motivation", "Motivación", "Motivazione"),
    "口腔": ("The mouth", "La boca", "La bocca"),
    "別人的隱私和隱秘": ("Other people's privacy and secrets",
                  "La privacidad y los secretos de los demás",
                  "La privacy e i segreti altrui"),
    "別人的私生活": ("Other people's private lives",
                "La vida privada de los demás",
                "La vita privata altrui"),
    "隱耗": ("Unseen drain", "Desgaste oculto", "Logorio nascosto"),
    "生存": ("Survival", "Supervivencia", "Sopravvivenza"),
    "體力": ("Physical strength", "Fuerza física", "Forza fisica"),
    "精力": ("Vitality", "Energía vital", "Energia vitale"),
    "健康情況": ("State of health", "Estado de salud", "Stato di salute"),
    "盲目": ("Blindness", "Ceguera", "Cecità"),
    "自大": ("Arrogance", "Arrogancia", "Arroganza"),
    "意義": ("Meaning", "Significado", "Significato"),
    "活力": ("Liveliness", "Vivacidad", "Vivacità"),
    "新鮮感": ("A sense of novelty", "Sensación de novedad", "Senso di novità"),
    "甲狀腺": ("The thyroid", "La tiroides", "La tiroide"),
    "隔絕": ("Being cut off", "Estar aislado del mundo", "Essere tagliati fuori"),
    "隱匿": ("Hiding away", "Ocultarse", "Nascondersi"),
    "反覆": ("Going back and forth", "Idas y vueltas", "Andirivieni"),
    "被看見": ("Being seen", "Ser visto", "Essere visti"),
    "欺騙": ("Deception", "Engaño", "Inganno"),
    "貴人": ("Benefactors", "Benefactores", "Benefattori"),
    "思想": ("Mindset", "Mentalidad", "Mentalità"),
    "精神": ("Spirit", "Ánimo", "Spirito"),
    "同胞": ("Compatriots", "Compatriotas", "Connazionali"),
}


def build():
    """把新的中文順序套到四種語言上。"""
    lookup = {}
    for i in range(12):
        for j, zh in enumerate(P.KEYWORDS["zh"][i]):
            lookup[zh] = tuple(P.KEYWORDS[l][i][j] for l in ("en", "es", "it"))
    lookup.update(NEW_TERMS)

    table = {l: [list(P.KEYWORDS[l][i]) for i in range(12)] for l in LANGS}
    for palace, zh_list in NEW_ZH.items():
        i = palace - 1
        missing = [w for w in zh_list if w not in lookup]
        if missing:
            sys.exit("這些詞還沒有譯法：%s" % "、".join(missing))
        table["zh"][i] = list(zh_list)
        for k, l in enumerate(("en", "es", "it")):
            table[l][i] = [lookup[w][k] for w in zh_list]
    return table


def wrap(items, indent, width=96):
    pad = " " * indent
    lines, cur = [], ""
    for s in items:
        piece = '"%s", ' % s
        if cur and len(pad) + len(cur) + len(piece) > width:
            lines.append(pad + cur.rstrip())
            cur = ""
        cur += piece
    lines.append(pad + cur.rstrip().rstrip(","))
    return lines


def swift_block(rows):
    out = ["["]
    for i, row in enumerate(rows):
        out.append("        // %d宮" % (i + 1))
        body = wrap(row, 9)
        body[0] = "        [" + body[0].lstrip()
        body[-1] = body[-1] + "],"
        out.extend(body)
    out.append("    ]")
    return "\n".join(out)


def kotlin_block(rows):
    out = ["listOf("]
    for i, row in enumerate(rows):
        out.append("        // 宮 %d" % (i + 1))
        out.append("        listOf(")
        out.extend(wrap(row, 12))
        out.append("        ),")
    out.append("    )")
    return "\n".join(out)


def replace(path, marker, new_block):
    src = open(path, encoding="utf-8").read()
    start = src.index(marker) + len(marker)
    start = src.index("[" if new_block[0] == "[" else "listOf(", start)
    depth, i, opener, closer = 0, start, "([", ")]"
    while i < len(src):
        c = src[i]
        if c == '"':
            i += 1
            while i < len(src):
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == '"':
                    break
                i += 1
        elif c in opener:
            depth += 1
        elif c in closer:
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1
    else:
        sys.exit("找不到 %s 的結尾" % marker)
    return src[:start] + new_block + src[end:]


def main():
    table = build()

    for lang in LANGS:
        marker = "let %s: [[String]] = " % lang
        new = replace(SWIFT, marker, swift_block(table[lang]))
        open(SWIFT, "w", encoding="utf-8").write(new)
    print("rewrote", os.path.relpath(SWIFT, ROOT))

    for lang in LANGS:
        # Kotlin 那邊義大利文叫 ita，因為 it 是 lambda 的保留字
        marker = "val %s: List<List<String>> = " % ("ita" if lang == "it" else lang)
        new = replace(KOTLIN, marker, kotlin_block(table[lang]))
        open(KOTLIN, "w", encoding="utf-8").write(new)
    print("rewrote", os.path.relpath(KOTLIN, ROOT))

    print("每宮條目數:", [len(r) for r in table["zh"]])


if __name__ == "__main__":
    main()
