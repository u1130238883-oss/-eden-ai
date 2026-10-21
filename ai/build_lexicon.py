"""手機裡的離線字典（lexicon.tsv）：英文、中文、西班牙文、義大利文、阿拉伯文的單字。

資料來源（都是人編的字典，不是 AI 產生的）：
  - ECDICT（MIT 授權）https://github.com/skywind3000/ECDICT ：英文 → 中文，附音標、詞頻
  - 維基詞典（CC BY-SA 3.0）經 https://github.com/Vuizur/Wiktionary-Dictionaries 整理：
    中文、西班牙文、義大利文、阿拉伯文 → 英文；Mandarin 那份用來查拼音

用法：python3 build_lexicon.py ECDICT_DIR WIKT_DIR FREQ_DIR OUT
（FREQ_DIR：https://github.com/hermitdave/FrequencyWords 的 content/2018/<語言>/<語言>_50k.txt，MIT 授權，用來只收常用詞）
每行：語言 \t 詞 \t 讀音 \t 詞性 \t 意思（用「；」分開）\t 常用排名（越小越常用）
  en 的意思是繁體中文；zh、es、it、ar 的意思是英文（手機再用英文對到其他語言）
"""
import csv
import html
import re
import sys

from opencc import OpenCC

s2t = OpenCC("s2tw").convert

FORM_OF = re.compile(r"(form of|plural of|inflection of|participle of|reading of|abbreviation of|initialism of|"
                     r"alternative spelling|misspelling of|synonym of|feminine of|masculine of|singular of|"
                     r"superlative of|comparative of|diminutive of|augmentative of|clipping of|romanization of|"
                     r"conjugated form|first-person|second-person|third-person|gerund of|imperative of)", re.I)


def wikt(path, lang, pinyin=None, limit_glosses=2, common=None):
    """common：常用詞（字幕詞頻前 5 萬）。只收常用詞；變化形（comiendo）是常用詞時記成「→ comer」"""
    out = {}
    redirect = {}
    for line in open(path, encoding="utf-8"):
        if "\t" not in line:
            continue
        head, body = line.rstrip("\n").split("\t", 1)
        forms = head.split("|")
        word = forms[0].strip()
        if not word or len(word) > 30:
            continue
        pron = ""
        if lang == "ar":
            # 阿拉伯文的拉丁字母拼音（šukran）
            lat = [f for f in forms[1:] if re.fullmatch(r"[a-zA-Zʔʕāīūḥṣḍṭẓġḵšṯḏʿʾ' -]+", f)]
            pron = lat[0] if lat else ""
        if lang == "zh":
            if not re.fullmatch(r"[一-鿿]{1,4}", word):
                continue
            word = s2t(word) if s2t(word) != word and not any(s2t(f) == f and f != word for f in forms) else word
            pron = pinyin.get(word, "") if pinyin else ""
        senses = []
        poses = []
        for pos, ol in re.findall(r"<i>([^<]*)</i><br><ol>(.*?)</ol>", body):
            for li in re.findall(r"<li>(.*?)</li>", ol):
                g = html.unescape(re.sub(r"<[^>]+>", "", li)).strip()
                g = re.sub(r"\s*\(Classifier:[^)]*\)", "", g)
                if not g or FORM_OF.search(g) or len(g) > 80:
                    continue
                senses.append(g)
                if pos not in poses:
                    poses.append(pos)
        if not senses:
            continue
        key = word.lower() if lang != "zh" else word
        # 「Gracias」（宏都拉斯的小鎮）不能蓋掉「gracias」（謝謝）：地名讓給一般的詞
        if key in out and not (out[key][2].startswith("name") and not poses[0].startswith("name")):
            continue
        # 常用詞才收；片語（buenos días）每個字都常用也收
        phrase_ok = " " in key and len(key.split()) <= 3 and all(t in common for t in key.split()) if common else False
        if common is not None and key not in common and not phrase_ok and not (lang == "zh" and len(key) <= 2):
            continue
        out[key] = (word, pron, ",".join(poses[:2]), "；".join(senses[:limit_glosses]), (common or {}).get(key, 30000 if " " in key else 99999))
        if common is not None and lang != "zh":
            for f in forms[1:]:
                k = f.strip().lower()
                # 同一個變化形可能出現在好幾個詞底下（sono：essere、abbellire…），選最常用的那個原形
                if k in common and k != key and " " not in k:
                    r = common.get(key, 10**9)
                    if k not in redirect or r < redirect[k][0]:
                        redirect[k] = (r, (f.strip(), "", "→", word, common[k]))
    for k, (_, v) in redirect.items():
        out.setdefault(k, v)
    return out


def frequent(path, convert=None):
    """{詞: 排名}"""
    words = {}
    for i, line in enumerate(open(path, encoding="utf-8")):
        w = line.split(" ")[0].strip().lower()
        if w:
            words.setdefault(convert(w) if convert else w, i)
    return words


def mandarin_pinyin(path):
    py = {}
    for line in open(path, encoding="utf-8"):
        m = re.match(r"([^|\t]+)[^\t]*\t.*?Hanyu Pinyin reading of ([^<]+?)\.?</li>", line)
        if not m:
            continue
        for w in m.group(2).split(","):
            w = w.strip()
            if w and w not in py:
                py[w] = m.group(1)
    return py


def ecdict(path, top=30000):
    out = {}
    for r in csv.DictReader(open(path, encoding="utf-8")):
        w = r["word"].strip()
        if not re.fullmatch(r"[A-Za-z][A-Za-z' -]{0,30}", w) or w.isupper() and len(w) > 1:
            continue
        def rank(x):
            try:
                return int(x) if int(x) > 0 else 10**9
            except ValueError:
                return 10**9
        best = min(rank(r["bnc"]), rank(r["frq"]))
        common = best <= top or r["tag"].strip() or r["oxford"] == "1" or (r["collins"] or "0") not in ("", "0")
        if not common:
            continue
        lines = [l.strip() for l in r["translation"].replace("\\n", "\n").split("\n")]
        lines = [l if len(l) <= 40 else l[:l.rfind(",", 0, 40)] if "," in l[:40] else l[:40]
                 for l in lines if l and not l.startswith("[")][:3]
        if not lines:
            continue
        zh = s2t("；".join(lines))
        key = w.lower()
        if key in out and out[key][4] <= best:
            continue
        out[key] = (w, r["phonetic"].strip(), "", zh, min(best, 99999))
    return out


def main():
    ec, wk, fq, dst = sys.argv[1:5]
    py = mandarin_pinyin(f"{wk}/Mandarin-English Wiktionary dictionary.tsv")
    zh_common = {**frequent(f"{fq}/zh_cn.txt", s2t), **frequent(f"{fq}/zh_tw.txt")}
    tables = {
        "en": ecdict(f"{ec}/ecdict.csv"),
        "zh": wikt(f"{wk}/Chinese-English Wiktionary dictionary.tsv", "zh", py, common=zh_common),
        "es": wikt(f"{wk}/Spanish-English Wiktionary dictionary.tsv", "es", common=frequent(f"{fq}/es.txt")),
        "it": wikt(f"{wk}/Italian-English Wiktionary dictionary.tsv", "it", common=frequent(f"{fq}/it.txt")),
        "ar": wikt(f"{wk}/Arabic-English Wiktionary dictionary.tsv", "ar", common=frequent(f"{fq}/ar.txt")),
    }
    with open(dst, "w", encoding="utf-8") as f:
        f.write("# NineSun 離線字典。英文：ECDICT（MIT）；中文、西班牙文、義大利文、阿拉伯文：維基詞典（CC BY-SA 3.0）\n")
        for lang, t in tables.items():
            for word, pron, pos, gloss, rank in t.values():
                clean = lambda s: s.replace("\t", " ").replace("\n", " ")
                f.write(f"{lang}\t{clean(word)}\t{clean(pron)}\t{clean(pos)}\t{clean(gloss)}\t{rank}\n")
            print(lang, len(t))


if __name__ == "__main__":
    main()
