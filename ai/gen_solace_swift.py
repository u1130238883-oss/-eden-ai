# -*- coding: utf-8 -*-
"""把 solace.py 的詞表寫成 Swift（SolaceData.swift），兩邊用同一份資料，輸出才會逐字一樣。
用法：python3 gen_solace_swift.py ../ios/EchoCore/Sources/EchoCore/SolaceData.swift
"""
import json
import sys

import solace as S


def lit(x):
    return json.dumps(x, ensure_ascii=False)


def arr(xs):
    return "[" + ", ".join(lit(x) for x in xs) + "]"


def main(dst):
    L = ["// 由 ai/gen_solace_swift.py 從 ai/solace.py 產生，請勿手動修改。", "", "enum SolaceData {"]
    L.append("    /// (心情代號, 關鍵詞, 對應的宮位, 接住情緒的話)")
    L.append("    static let feelings: [(kind: String, keys: [String], palaces: [Int], lead: [String])] = [")
    for kind, keys, palaces, lead in S.FEELINGS:
        L.append(f"        ({lit(kind)}, {arr(keys)}, {arr(palaces)}, {arr(lead)}),")
    L.append("    ]")
    L.append(f"    static let notFeeling: [String] = {arr(S.NOT_FEELING)}")
    L.append("    static let topicHints: [(palace: Int, words: [String])] = [")
    for p, ws in S.TOPIC_HINTS:
        L.append(f"        ({p}, {arr(ws)}),")
    L.append("    ]")
    L.append(f"    static let domainShort: [String] = {arr(S.DOMAIN_SHORT)}")
    L.append(f"    static let causeShort: [String] = {arr(S.CAUSE_SHORT)}")
    L.append("    static let western: [(meaning: String, comfort: String)] = [")
    for a, b in S.WESTERN:
        L.append(f"        ({lit(a)}, {lit(b)}),")
    L.append("    ]")
    L.append("    static let typeStress: [(stress: String, toward: Int, grow: String)] = [")
    for a, t, b in S.TYPE_STRESS:
        L.append(f"        ({lit(a)}, {t}, {lit(b)}),")
    L.append("    ]")
    L.append(f"    static let smallStep: [String] = {arr(S.SMALL_STEP)}")
    L.append(f"    static let westernKinds: Set<String> = {arr(sorted(S.WESTERN_KINDS))}")
    L.append("    static let ask: [String: String] = [")
    for k, v in S.ASK.items():
        L.append(f"        {lit(k)}: {lit(v)},")
    L.append("    ]")
    L.append(f"    static let closing: [String] = {arr(S.CLOSING)}")
    L.append(f"    static let heavy: [String] = {arr(S.HEAVY)}")
    L.append(f"    static let care = {lit(S.CARE)}")
    L.append(f"    static let noBirthday = {lit(S.NO_BIRTHDAY)}")
    L.append(f"    static let again = {lit(S.AGAIN)}")
    L.append("    static let aspect: [String: Int] = [" + ", ".join(f"{lit(k)}: {v}" for k, v in S.ASPECT.items()) + "]")
    L.append("    static let areaName: [Int: String] = [" + ", ".join(f"{k}: {lit(v)}" for k, v in S.AREA_NAME.items()) + "]")
    L.append("    static let emotion: [(good: String, bad: String)] = [")
    for g, b in S.EMOTION:
        L.append(f"        ({lit(g)}, {lit(b)}),")
    L.append("    ]")
    L.append("}")
    open(dst, "w", encoding="utf-8").write("\n".join(L) + "\n")


if __name__ == "__main__":
    main(sys.argv[1])
