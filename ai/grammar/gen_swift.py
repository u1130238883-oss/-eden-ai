# -*- coding: utf-8 -*-
"""詞性資料 → Swift（ios/EchoCore/Sources/EchoCore/GrammarData.swift）。只放訓練用的詞（驗證用的詞 App 不知道，要靠上下文判斷）。
用法：python3 ai/grammar/gen_swift.py ios/EchoCore/Sources/EchoCore/GrammarData.swift"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lexicon as L  # noqa: E402


def main(dst):
    out = ["// 由 ai/grammar/gen_swift.py 產生，不要手改。資料在 ai/grammar/lexicon.py", "", "enum GrammarData {",
           "    /// 類別 → (詞性 N/V/A/D, 詞)", "    static let words: [(String, String, [String])] = ["]
    for c, (p, tr, _) in L.WORDS.items():
        out.append('        ("%s", "%s", [%s]),' % (c, p, ", ".join('"%s"' % w for w in tr)))
    out += ["    ]", "    /// 功能詞（不是名動形副，仿寫時不變）", "    static let function: [String] = [" + ", ".join('"%s"' % w for w in L.FUNCTION) + "]", "}", ""]
    open(dst, "w", encoding="utf-8").write("\n".join(out))
    print(len(L.WORDS), "類 →", dst)


if __name__ == "__main__":
    main(sys.argv[1])
