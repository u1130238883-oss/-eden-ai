# -*- coding: utf-8 -*-
"""產生 Swift 端資料表（ManticData.swift）與對齊測試資料（Fixtures/mantic.json）。"""
import json
import os

from iching import KING_WEN
from knowledge_data import HEX_MEANING, STAR_TEXT, STEM_TEXT, TEN_GOD_TEXT, ZW_PALACE_TEXT
from mantic_corpus import export_fixtures

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def sdict(d):
    return "[\n" + "".join(f"        {json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)},\n"
                           for k, v in d.items()) + "    ]"


def sarr(a):
    return "[\n" + "".join(f"        {json.dumps(v, ensure_ascii=False)},\n" for v in a) + "    ]"


src = f'''// 由 ai/gen_swift_data.py 產生，請勿手動修改。
// 內容與 Python 訓練端完全相同，確保「引擎校正」的保底文字和訓練資料一致。

enum ManticData {{
    static let stemText: [String: String] = {sdict(STEM_TEXT)}

    static let tenGodText: [String: String] = {sdict(TEN_GOD_TEXT)}

    static let starText: [String: String] = {sdict(STAR_TEXT)}

    static let ziweiPalaceText: [String: String] = {sdict(ZW_PALACE_TEXT)}

    /// 文王卦序 1...64 的卦名（索引 0 = 第 1 卦）
    static let hexNames: [String] = {sarr([n for n, _, _ in KING_WEN])}

    /// 上卦、下卦
    static let hexUpper: [String] = {sarr([u for _, u, _ in KING_WEN])}
    static let hexLower: [String] = {sarr([l for _, _, l in KING_WEN])}

    static let hexMeaning: [String] = {sarr([HEX_MEANING[i] for i in range(1, 65)])}
}}
'''
out = os.path.join(ROOT, "ios", "EchoCore", "Sources", "EchoCore", "ManticData.swift")
open(out, "w", encoding="utf-8").write(src)
fx = os.path.join(ROOT, "ios", "EchoCore", "Tests", "EchoCoreTests", "Fixtures", "mantic.json")
export_fixtures(fx)
print("wrote", out, "and", fx)
