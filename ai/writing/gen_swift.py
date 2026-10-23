# -*- coding: utf-8 -*-
"""寫作材料 → Swift（ios/EchoCore/Sources/EchoCore/WritingData.swift）
用法：python3 ai/writing/gen_swift.py ios/EchoCore/Sources/EchoCore/WritingData.swift"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lexicon as L  # noqa: E402


def arr(xs):
    return "[" + ", ".join('"%s"' % x.replace('"', '\\"') for x in xs) + "]"


def main(dst):
    out = ["// 由 ai/writing/gen_swift.py 產生，不要手改。資料在 ai/writing/lexicon.py", "", "enum WritingData {",
           "    struct Cat {", "        let keys, idioms, elevated, avoid, idiomTones, setting, body, simile, inner, end, view, feel: [String]",
           "        let plain, idiomLine: String", "    }", "", "    static let order: [String] = " + arr(L.ORDER),
           "    static let scenes: Set<String> = Set(" + arr(L.SCENE_CATS) + ")", "", "    static let cats: [String: Cat] = ["]
    for k, c in L.CATS.items():
        out.append('        "%s": Cat(' % k)
        for f in ["keys", "idioms", "elevated", "avoid"]:
            out.append("            %s: %s," % (f, arr(c[f])))
        out.append("            idiomTones: %s," % arr(c["idiom"]))
        for f in ["setting", "body", "simile", "inner", "end"]:
            out.append("            %s: %s," % (f, arr(c[f])))
        out.append("            view: %s," % arr(L.VIEW[k]))
        out.append("            feel: %s," % arr(L.FEEL[k]))
        out.append('            plain: "%s", idiomLine: "%s"),' % (c["plain"], c["idiomLine"]))
    out += ["    ]", "", "    /// 平淡的說法 → 高級的說法", "    static let upgrade: [(String, String)] = ["]
    out += ['        ("%s", "%s"),' % p for p in L.UPGRADE]
    out += ["    ]", "    static let simile: [String] = " + arr(L.SIMILE), "    static let scene: [String] = " + arr(L.SCENE),
            "    static let sense: [String] = " + arr(L.SENSE), "}", ""]
    open(dst, "w", encoding="utf-8").write("\n".join(out))
    print(len(L.CATS), "類 →", dst)
    expand(os.path.join(os.path.dirname(dst), "ExpandData.swift"))


def expand(dst):
    """擴寫（中英西義）的材料 → 一張大表，執行時再拆開（避免 Swift 編譯太久）。每行：種類|鍵|語言|內容（欄位用 ¦ 分開）"""
    import expand as X
    rows = []
    for c, xs in X.SUBJ.items():
        for t in xs:
            rows.append(("SUBJ", c, "-", "¦".join(t)))
    for c, xs in X.PRED.items():
        for t in xs:
            rows.append(("PRED", c, "-", "¦".join(t[:4]) + "¦" + ",".join(sorted(t[4])) if t[4] else "¦".join(t[:4]) + "¦"))
    for c, ps in X.COMBOS.items():
        rows.append(("COMBO", c, "-", ",".join(ps)))
    for kind, table in [("SCENE", X.SCENE), ("DETAIL", X.DETAIL)]:
        for c, by in table.items():
            for l, ss in by.items():
                for t in ss:
                    rows.append((kind, c, l, t))
    acts = dict(X.ACT)
    acts["general"] = X.GENERAL
    for c, a in acts.items():
        for slot in ["vivid", "simile", "feel", "view", "end"]:
            for l, ss in a[slot].items():
                for t in ss:
                    rows.append(("ACT." + slot, c, l, t))
        rows.append(("IDIOM", c, "zh", ",".join(a["idioms"])))
        for l, t in a["proverb"].items():
            rows.append(("PROVERB", c, l, t))
    for l, ss in X.EXTRA.items():
        for t in ss:
            rows.append(("EXTRA", "-", l, t))
    for kind, by in X.MARK.items():
        for l, ws in by.items():
            rows.append(("MARK." + kind, "-", l, "¦".join(ws)))
    for r in rows:
        assert "|" not in "".join(r) and "\n" not in "".join(r), r
    out = ["// 由 ai/writing/gen_swift.py 產生，不要手改。資料在 ai/writing/expand.py", "", "enum ExpandData {",
           "    /// 種類|鍵|語言|內容（欄位用 ¦ 分開）", '    static let table = """']
    out += ["|".join(r).replace("\\", "\\\\") for r in rows]
    out += ['"""', "}", ""]
    open(dst, "w", encoding="utf-8").write("\n".join(out))
    print(len(rows), "行擴寫材料 →", dst)


if __name__ == "__main__":
    main(sys.argv[1])
