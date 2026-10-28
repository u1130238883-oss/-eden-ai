# -*- coding: utf-8 -*-
"""常識資料（ai/commonsense/data/*.txt）→ Swift（ios/EchoCore/Sources/EchoCore/CommonsenseData.swift）
用法：python3 ai/commonsense/gen_swift.py ios/EchoCore/Sources/EchoCore/CommonsenseData.swift

資料是「事實」，不是寫好的回答：NineSun 讀懂問題在問哪個東西的哪個屬性，再從事實組出答案
（Commonsense.swift），所以同一筆事實能回答很多種問法（「鯨魚是魚嗎」「鯨魚用什麼呼吸」都靠同一句說明）。"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")

# 每個屬性要怎麼被問到，寫在 Commonsense.swift；這裡只檢查資料有沒有寫錯
KEYS = {"簡介", "是", "不是", "會", "不會", "吃", "住", "壽命", "腳", "說明", "特點", "看法", "首都", "洲", "語言", "貨幣",
        "距離", "溫度", "年齡", "大小", "繞一圈", "形狀", "自轉", "公轉", "衛星", "海洋", "行星", "速度", "沸點", "冰點", "密度",
        "成分", "月份", "骨頭", "牙齒", "肌肉", "心臟", "心跳", "體溫", "血液", "大腦", "染色體", "肺", "腎臟", "最大的器官",
        "最長的骨頭", "最小的骨頭", "水", "顏色", "好處", "壞處", "時間", "年代", "國籍", "代表作", "名言", "發明者", "年份",
        "日期", "習俗", "由來", "步驟", "提醒", "就醫", "項目", "首選", "問", "縣市", "人口", "面積", "都道府縣", "州",
        "大區", "省", "高度", "長度"}


def lines(name):
    for raw in open(os.path.join(DATA, name), encoding="utf-8"):
        line = raw.rstrip("\n")
        if line.startswith("#"):
            continue
        yield line


def blocks(name):
    """@名|別名|類別 開頭，下面是 key=value，直到下一個 @"""
    cur = None
    for line in lines(name):
        if line.startswith("@"):
            if cur:
                yield cur
            name_, alias, kind = line[1:].split("|")
            cur = {"name": name_, "alias": [a for a in alias.split(",") if a], "kind": kind, "attrs": []}
        elif line.strip() and cur is not None:
            k, v = line.split("=", 1)
            cur["attrs"].append((k, v))
    if cur:
        yield cur


def countries():
    for line in lines("countries.txt"):
        if not line.strip():
            continue
        name, alias, capital, cont, lang, cur, note = line.split("|")
        yield {"name": name, "alias": [a for a in alias.split(",") if a], "kind": "國家",
               "attrs": [("簡介", f"位在{cont}的國家，{note}"), ("是", "國家"), ("首都", capital), ("洲", cont),
                         ("語言", lang), ("貨幣", cur), ("特點", note)]}


def check(e, seen):
    for k, v in e["attrs"]:
        key = k.split(":")[0]
        assert key in KEYS or key == "因", f"{e['name']}：不認得的屬性「{k}」"
        assert v.strip(), f"{e['name']}：「{k}」是空的"
        for bad in ("|", '"""', "\\"):
            assert bad not in v and bad not in k, f"{e['name']}：「{k}」裡有不能用的字元 {bad}"
    for a in [e["name"]] + e["alias"]:
        if a in seen and seen[a] != e["name"]:
            print(f"注意：「{a}」同時是 {seen[a]} 和 {e['name']} 的名字", file=sys.stderr)
        seen.setdefault(a, e["name"])


def main(dst):
    ents = list(countries())
    for f in ("animals.txt", "nature.txt", "more.txt", "people.txt", "festivals.txt", "howto.txt", "recommend.txt"):
        ents += list(blocks(f))
    # extra.txt：補充到同名的東西上
    by = {e["name"]: e for e in ents}
    for x in blocks("extra.txt"):
        assert x["name"] in by, "extra.txt：沒有「%s」" % x["name"]
        by[x["name"]]["attrs"] += x["attrs"]
    seen = {}
    for e in ents:
        check(e, seen)
    sup = [l for l in lines("superlatives.txt") if l.strip()]
    for l in sup:
        assert len(l.split("|")) == 5, l
    views = [l for l in lines("views.txt") if l.strip()]
    for l in views:
        assert len(l.split("|")) == 4, l

    out = ["// 由 ai/commonsense/gen_swift.py 產生，不要手改。資料在 ai/commonsense/data/", "", "enum CommonsenseData {",
           "    /// 每一筆：@名|別名|類別，下面每行 屬性=值（因:關鍵詞/關鍵詞＝為什麼）", '    static let entities = """']
    for e in ents:
        out.append("@%s|%s|%s" % (e["name"], ",".join(e["alias"]), e["kind"]))
        out += ["%s=%s" % kv for kv in e["attrs"]]
    out += ['"""', "", "    /// 範圍|最＋什麼|東西|答案|補充", '    static let superlatives = """']
    out += sup
    out += ['"""', "", "    /// A|B|角度|看法", '    static let views = """']
    out += views
    out += ['"""', "}", ""]
    open(dst, "w", encoding="utf-8").write("\n".join(out))
    kinds = {}
    for e in ents:
        kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1
    print(len(ents), "筆事實", kinds, "；", len(sup), "個「最…」；", len(views), "個比較 →", dst)


if __name__ == "__main__":
    main(sys.argv[1])
