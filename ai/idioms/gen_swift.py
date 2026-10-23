# -*- coding: utf-8 -*-
"""成語資料 → Swift（ios/EchoCore/Sources/EchoCore/IdiomData.swift）
用法：python3 ai/idioms/gen_swift.py ios/EchoCore/Sources/EchoCore/IdiomData.swift"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import idioms as I  # noqa: E402
import importlib.util  # noqa: E402

spec = importlib.util.spec_from_file_location("idiom_gen", os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen.py"))


def main(dst):
    # gen.py 的心情、毛病、主題表（不跑 main）
    saved = sys.argv
    sys.argv = [saved[0], "understand", "/dev/null"]
    G = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(G)
    sys.argv = saved
    L = ["// 由 ai/idioms/gen_swift.py 產生，不要手改。資料在 ai/idioms/idioms.py", "", "enum IdiomData {",
         "    /// 成語|意思|English|Español|Italiano|語氣", '    static let table = """']
    for line in I.DATA.strip().splitlines():
        L.append(line)
    L += ['"""', "", "    /// 近義：每行一組", '    static let near = """']
    L += [l for l in I.NEAR.strip().splitlines()]
    L += ['"""', "", "    /// 反義：左邊每個跟右邊每個相反", '    static let anti = """']
    L += [l for l in I.ANTI.strip().splitlines()]
    L += ['"""', "", "    /// 說自己的心情時，成語代表的心情（Affect.Mood）", "    static let selfMood: [String: String] = ["]
    L += ['        "%s": "%s",' % (k, v) for k, v in G.SELF_MOOD.items()]
    L += ["    ]", "", "    /// 說自己的毛病（要找改善的方法）", "    static let problem: Set<String> = ["]
    L += ['        ' + ", ".join('"%s"' % w for w in G.PROBLEM[i:i + 10]) + "," for i in range(0, len(G.PROBLEM), 10)]
    L += ["    ]", "}", ""]
    open(dst, "w", encoding="utf-8").write("\n".join(L))
    print(len(I.entries()), "個成語 →", dst)


if __name__ == "__main__":
    main(sys.argv[1])
