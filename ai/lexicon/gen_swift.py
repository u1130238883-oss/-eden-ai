# -*- coding: utf-8 -*-
"""把近義詞表寫成 Swift（SynonymData.swift）"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from synonyms import groups  # noqa: E402
from antonyms import pairs  # noqa: E402


def main(dst):
    g = groups()
    L = ["// 由 ai/lexicon/gen_swift.py 從 ai/lexicon/synonyms.py 產生，請勿手動修改。", "", "enum SynonymData {",
         "    /// 每一組是意思相同或很接近的詞（第一個是最常用的說法）", "    static let groups: [[String]] = ["]
    for ws in g:
        L.append("        [" + ", ".join('"%s"' % w for w in ws) + "],")
    L += ["    ]", "", "    /// 反義詞：每一對意思相反（ai/lexicon/antonyms.py）", "    static let antonyms: [(String, String)] = ["]
    for a, b in pairs():
        L.append('        ("%s", "%s"),' % (a, b))
    L += ["    ]", "}", ""]
    open(dst, "w", encoding="utf-8").write("\n".join(L))
    print(len(g), "組 →", dst)


if __name__ == "__main__":
    main(sys.argv[1])
