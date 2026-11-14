# -*- coding: utf-8 -*-
"""把研究用的名人資料產生成 EchoCore/Celebrities.swift（App 裡可以問「三島由紀夫的命盤」「跟我同命盤的名人」）。
用法：python3 ai/research/gen_celebrities_swift.py ios/EchoCore/Sources/EchoCore/CelebrityData.swift"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from celebrity_cases import PEOPLE  # noqa: E402
from celebrity_data import MORE  # noqa: E402

# 有書信、自傳留下心境的人：逐年的事件與心情（研究筆記 ai/research/README.md §3）
LETTERS = [
    ("三島由紀夫", (1925, 1, 14), [
        (1941, "以筆名發表《花ざかりの森》，隱身在筆名後面開始寫作"), (1944, "學習院第一名畢業、第一本書出版、進東京帝大，離開原本的學校"),
        (1945, "徵兵體檢被誤診不合格而羞愧、妹妹美津子過世、日本戰敗、初戀遠去：一生最暗的一年"), (1946, "帶著稿子去見川端康成並受提拔；初戀嫁給別人"),
        (1949, "《假面的告白》成名"), (1956, "《金閣寺》，聲望高峰"), (1958, "結婚，川端當媒人"), (1959, "《鏡子之家》受挫"),
        (1961, "《宴之後》被控侵犯隱私"), (1964, "隱私官司敗訴"), (1965, "開始寫轉世四部曲《豐饒之海》"), (1968, "川端得諾貝爾獎；成立楯之會"),
        (1969, "寫信給川端：「我怕的不是死，而是死後家人的名譽」"), (1970, "切腹自殺")],
     "跟川端康成的往復書簡（1945–1970）留下他從仰慕、受提拔到晚年託付後事的心境。他的本命盤和 2006 年 1 月 14 日生的人完全一樣。"),
    ("川端康成", (1899, 6, 14), [
        (1901, "父親過世"), (1902, "母親過世"), (1906, "祖母過世"), (1909, "姊姊過世"), (1914, "祖父過世，十五歲成了孤兒"),
        (1921, "與初代的婚約被取消，深受打擊"), (1924, "東大畢業、創辦《文藝時代》"), (1926, "《伊豆的舞孃》、結婚"), (1937, "《雪國》出版得獎"),
        (1947, "摯友橫光利一過世"), (1961, "獲文化勳章"), (1962, "因安眠藥依賴住院"), (1968, "諾貝爾文學獎"), (1970, "三島由紀夫自殺"), (1972, "過世")],
     "本命十二宮有九宮是好，一生卻失去很多親人：好代表那個領域做得成、流得動（他的好年份對上的是作品和榮譽），不代表心情一定快樂。"),
]


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main(dst):
    people = [(n, b, [(y, e) for y, e, *_ in ev], "") for n, b, ev in PEOPLE + MORE]
    people = [p for p in people if p[0] not in {x[0] for x in LETTERS}] + [(n, b, ev, note) for n, b, ev, note in LETTERS]
    out = ["// 由 ai/research/gen_celebrities_swift.py 產生，不要手改。資料：公開、有據可查的生日與人生大事；三島、川端另有書信與傳記裡的心境。",
           "", "extension Celebrities {", "    static let data: [Person] = ["]
    for name, (y, m, d), evs, note in people:
        e = ", ".join(f'({yy}, "{esc(t)}")' for yy, t in evs)
        out.append(f'        Person(name: "{esc(name)}", birth: BirthDay(year: {y}, month: {m}, day: {d}), events: [{e}], note: "{esc(note)}"),')
    out += ["    ]", "}", ""]
    open(dst, "w", encoding="utf-8").write("\n".join(out))
    print(len(people), "people")


if __name__ == "__main__":
    main(sys.argv[1])
