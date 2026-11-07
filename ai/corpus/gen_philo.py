#!/usr/bin/env python3
"""哲學（至少 5,000,000 字）＋考題。

- 哲學家：是誰、主張、代表說法、代表作、批評、會怎麼看人生
- 概念：定義、白話例子、相關的人、質疑
- 比較：兩個哲學家、兩個概念
- 思想實驗：電車難題、忒修斯之船、缸中之腦、中文房間……
- 人生大哉問：活著是為了什麼、什麼是幸福、要不要在乎別人眼光……（幾個哲學家的看法＋NineSun 自己的看法）
- 生活困境用哲學想：要不要辭職、被背叛、一直拖延……
NineSun 的口氣：會吐槽、會唱反調，但講的內容要正確、講人話。

python3 gen_philo.py 輸出.jsonl 考題.jsonl [目標字數]
"""
import hashlib
import itertools
import json
import random
import sys

from phil_data import C, D, LENS, P, Q, T

R = random.Random(5_000_001)
PH = {p[0]: p for p in P}
CO = {c[0]: c for c in C}

INTRO = ["", "", "", "", "好問題，比問我今天穿什麼有深度多了。", "這題哲學家吵了兩千年，我幫你濃縮。", "來，用人話講。",
         "先說，我不會叫你背課本。", "這個我熟，坐好。", "很多人講得很玄，其實沒那麼難。", "直接講重點，不繞。"]
OUTRO = ["", "", "", "你不用全盤接受，挑對你有用的就好。", "哲學不是背答案，是多一個角度看事情。", "你覺得哪個比較說服你？",
         "我自己的看法：別迷信大師，他們也會錯。", "有興趣可以去找原典看，比二手解說有意思。"]


def alts(name):
    """名字的寫法：馬可・奧理略 → 奧理略；釋迦牟尼（佛陀）→ 佛陀、釋迦牟尼"""
    out = [name]
    if "（" in name:
        a, b = name.split("（")
        out += [a, b.rstrip("）")]
    if "・" in name:
        out += [name.split("・")[-1], name.replace("・", "")]
    return list(dict.fromkeys(out))


def short(name):
    return alts(name)[-1] if "（" in name else name


out, exam = [], []


def add(topic, q, a):
    a = (R.choice(INTRO) + "\n" if R.random() < 0.5 else "") + a + ("\n" + R.choice(OUTRO) if R.random() < 0.4 else "")
    out.append({"cat": "philosophy", "topic": topic, "q": q, "a": a.strip()})


def ph_full(p):
    n, era, place, school, ideas, quote, works, crit, life = p
    return (f"{n}（{era}，{place}），{school}。\n主要主張：\n" + "\n".join(f"· {x}" for x in ideas)
            + f"\n代表說法：「{quote}」\n代表作：{works}\n常見的批評：{crit}。\n如果問他人生要怎麼活，大概會說：{life}。")


def ph_ideas(p, k):
    ideas = R.sample(p[4], min(k, len(p[4])))
    return "；".join(ideas)


def emit_philosophers():
    for p in P:
        n, era, place, school, ideas, quote, works, crit, life = p
        s = short(n)
        add("哲學家", R.choice([f"{s}是誰？", f"介紹一下{s}", f"{s}在講什麼？", f"{s}的哲學是什麼？"]), ph_full(p))
        add("哲學家", R.choice([f"{s}的主要思想", f"{s}最重要的觀點是什麼？", f"用三句話講{s}"]),
            f"{s}（{school}）最重要的幾點：\n" + "\n".join(f"{i + 1}. {x}" for i, x in enumerate(ideas[:3])))
        add("名言", R.choice([f"「{quote}」是什麼意思？", f"「{quote}」是誰說的？", f"解釋一下{s}說的「{quote}」"]),
            f"這是{s}說的（意思相近的譯法有很多）。放在他的思想裡看：{ideas[0]}。\n白話：{life}。")
        add("哲學家批評", R.choice([f"{s}有什麼問題？", f"{s}被批評什麼？", f"{s}的哲學有什麼缺點？"]),
            f"{s}最常被批評的是：{crit}。\n不過他留下的重要東西是：{ideas[0]}。看哲學家要看他解決了什麼問題，也看他的盲點。")
        add("代表作", R.choice([f"{s}寫過什麼書？", f"想讀{s}要從哪本開始？"]), f"{s}的代表作：{works}。" + ("沒有自己的著作，" if "沒有著作" in works else "") + f"讀之前先抓住重點：{ideas[0]}。")
        add("學派", R.choice([f"{s}屬於哪個學派？", f"{s}是什麼主義？"]), f"{s}屬於{school}，{era}，{place}。核心是：{ideas[0]}。")
        for _ in range(3):
            add("哲學家", R.choice([f"{s}怎麼看{x}" for x in ["人生", "幸福", "道德", "社會", "人性"]] + [f"跟我聊聊{s}", f"{s}的思想有什麼用？"]),
                f"{s}的重點：{ph_idea_set(p)}\n用在生活上：{life}。")
        # 哲學家怎麼看人生問題
        for q in Q:
            if True:
                add("哲學家看人生", R.choice([f"{s}會怎麼回答「{q[0]}」？", f"如果問{s}{q[0]}，他會怎麼說？"]),
                    f"照{s}的思路：{life}。\n根據是他的主張——{ph_ideas(p, 2)}。")


def ph_idea_set(p):
    return "；".join(R.sample(p[4], min(len(p[4]), R.choice([2, 3])))) + "。"


def emit_concepts():
    for c in C:
        name, d, ex, who, crit = c
        ws = "、".join(short(w) for w in who)
        add("概念", R.choice([f"什麼是{name}？", f"{name}是什麼意思？", f"解釋{name}", f"用白話講{name}"]),
            f"{name}：{d}。\n例子：{ex}。\n相關的哲學家：{ws}。\n常見的質疑：{crit}。")
        add("概念", R.choice([f"{name}的例子", f"舉個例子說明{name}", f"{name}在生活中長什麼樣？"]), f"例子：{ex}。\n這就是{name}：{d}。")
        add("概念", R.choice([f"{name}有什麼問題？", f"{name}對嗎？", f"我覺得{name}有道理，你同意嗎？"]),
            f"{name}的重點是{d}。有道理的地方是它點出了很多人沒想過的角度；但要小心：{crit}。")
        add("概念", R.choice([f"誰提出{name}？", f"{name}是誰的主張？"]), f"{name}常跟{ws}連在一起。{d}。")
        for w in who:
            if w in PH:
                add("概念", f"{short(w)}怎麼看{name}？", f"{short(w)}的立場：{ph_ideas(PH[w], 2)}。放到{name}上：{d}。")


def emit_compare(limit_pairs=None):
    pairs = list(itertools.combinations(P, 2))
    R.shuffle(pairs)
    for a, b in pairs[:limit_pairs]:
        add("比較", R.choice([f"{short(a[0])}和{short(b[0])}有什麼不同？", f"比較{short(a[0])}跟{short(b[0])}", f"{short(a[0])}跟{short(b[0])}誰比較對？"]),
            f"{short(a[0])}（{a[3]}）：{ph_ideas(a, 2)}。\n{short(b[0])}（{b[3]}）：{ph_ideas(b, 2)}。\n"
            f"差別：一個重視{a[8]}，一個重視{b[8]}。" + ("兩個都是同一派，差別在細節。" if a[3] == b[3] else "出發點就不同。")
            + "\n誰比較對？看你在意的是什麼；我自己會兩邊各拿一點用。")
    cps = list(itertools.combinations(C, 2))
    R.shuffle(cps)
    for a, b in cps[:limit_pairs]:
        add("比較", R.choice([f"{a[0]}和{b[0]}差在哪？", f"{a[0]}跟{b[0]}有什麼關係？"]),
            f"{a[0]}：{a[1]}（例子：{a[2]}）。\n{b[0]}：{b[1]}（例子：{b[2]}）。\n"
            + ("兩個常被放在一起討論。" if set(a[3]) & set(b[3]) else "兩個是不同問題，可以分開看。"))


def emit_thought():
    for t in T:
        name, sit, ask, views = t
        for _ in range(8):
            vs = R.sample(views, len(views))
            add("思想實驗", R.choice([f"什麼是{name}？", f"{name}怎麼解？", f"你怎麼看{name}？", f"{name}的答案是什麼？", f"跟我講{name}"]),
                f"{name}：{sit}。\n要問的是：{ask}\n幾種看法：\n" + "\n".join(f"· {v}" for v in vs)
                + "\n" + R.choice(["沒有標準答案，重點是看清楚你的直覺背後在乎什麼。", "我自己的看法：這題的價值是逼你承認你的直覺會打架。",
                                   "你可以先選，再看看你的理由跟哪一派一樣。"]))


def emit_life(per=60):
    for q, names, mine in Q:
        for _ in range(per):
            k = min(len(names), R.choice([2, 3, 3, 4]))
            sel = R.sample(names, k)
            body = "\n".join(f"· {short(n)}：{PH[n][8]}。" for n in sel if n in PH)
            qs = R.choice([f"{q}？", f"{q}啊", f"你覺得{q}？", f"老實說，{q}？", f"{q}？不要給我雞湯", f"想問一個很大的問題：{q}",
                           f"{q}？用哲學的角度", f"最近一直在想{q}"])
            add("人生大哉問", qs, R.choice(["哲學家的答案不一樣：", "幾個角度：", "先看幾個大師怎麼說："]) + "\n" + body + "\n我的看法：" + mine)


def emit_dilemma(per=20):
    lens = list(LENS.items())
    for title, sit in D:
        for _ in range(per):
            sel = R.sample(lens, 3)
            add("生活困境", R.choice([f"{sit}，{title}？", f"{title}？{sit}", f"用哲學幫我想：{sit}，{title}", f"{sit}，我好亂，{title}"]),
                f"{sit}，這種事沒有標準答案，換幾個角度想：\n" + "\n".join(f"· {k}（{short(v[0])}）：{v[1]}" for k, v in sel)
                + "\n" + R.choice(["先睡一覺，別在情緒最高點決定。", "寫下最壞的情況，常常沒有想像中可怕。", "最後選的那個，要是你自己願意扛的。"]))


def emit_advice():
    """每個哲學家對每個生活困境會怎麼建議"""
    for p in P:
        for title, sit in D:
            add("哲學家給建議", R.choice([f"如果是{short(p[0])}，{sit}，他會怎麼建議？", f"用{short(p[0])}的哲學看：{sit}，{title}？"]),
                f"{short(p[0])}會從他的核心想法出發：{ph_ideas(p, 2)}。\n放到你的處境（{sit}）：{p[8]}；具體一點，先想清楚你真正在乎的是什麼，再做一個你願意承擔的決定。")


def emit_quotes():
    for p in P:
        for t in [f"「{p[5]}」這句話是誰說的？", f"誰說過「{p[5]}」？"]:
            add("名言", t, f"{short(p[0])}（{p[3]}）。他的意思：{p[4][0]}。")


target = int(sys.argv[3]) if len(sys.argv) > 3 else 5_200_000
emit_philosophers()
emit_concepts()
emit_thought()
emit_quotes()
emit_advice()
emit_compare(1800)
# 用某個概念回答人生問題、生活困境
for c in C:
    for q, names, mine in Q:
        add("概念看人生", R.choice([f"用{c[0]}的角度看：{q}？", f"{c[0]}怎麼回答「{q}」？"]),
            f"{c[0]}的核心是：{c[1]}。\n放到「{q}」：如果照這個想法，答案不是別人給的，而是要從「{c[2]}」這種具體經驗去看。\n但別忘了它的限制：{c[4]}。\n我自己的看法：{mine}")
    for title, sit in D:
        add("概念看困境", f"{sit}，用{c[0]}怎麼想？",
            f"{c[0]}：{c[1]}。\n套到你的處境（{sit}）：先看清楚這件事裡哪些是事實、哪些是你的詮釋，再用這個角度問自己「{title}」的理由站不站得住。\n提醒：{c[4]}，所以它只是一個角度，不是答案。")
rounds = 0
while sum(len(x["q"]) + len(x["a"]) for x in out) < target and rounds < 60:
    rounds += 1
    emit_life(20)
    emit_dilemma(8)
    emit_philosophers()

# 考題（有答案可以對的）
for p in P:
    if R.random() < 0.6:
        exam.append({"q": f"「{p[5]}」是哪個哲學家說的？只回答名字。", "expect": [alts(p[0])], "kind": "名言", "maxlen": 60})
for c in C:
    if R.random() < 0.35 and c[3]:
        exam.append({"q": f"「{c[0]}」通常跟哪位哲學家連在一起？", "expect": [sum((alts(w) for w in c[3]), [])], "kind": "概念"})
for name, kw in [("王陽明", ["知行合一", "良知", "心即理"]), ("康德", ["定言令式", "道德律", "目的"]), ("沙特", ["存在先於本質", "自由"]),
                 ("卡繆", ["荒謬", "薛西弗斯"]), ("尼采", ["超人", "上帝已死", "權力意志", "永劫回歸"]), ("莊子", ["逍遙", "齊物", "蝴蝶", "夢蝶"]),
                 ("老子", ["無為", "道", "水"]), ("孟子", ["性善", "四端", "惻隱"]), ("荀子", ["性惡"]), ("亞里斯多德", ["幸福", "中庸", "德性"]),
                 ("柏拉圖", ["理型", "洞穴", "理想國"]), ("笛卡兒", ["我思故我在", "懷疑"]), ("休謨", ["因果", "習慣", "歸納"]),
                 ("彌爾", ["自由", "傷害原則", "功利", "效益"]), ("羅爾斯", ["無知之幕", "正義", "公平"]), ("漢娜・鄂蘭", ["平庸之惡", "平庸", "極權"]),
                 ("墨子", ["兼愛", "非攻"]), ("韓非", ["法", "賞罰"]), ("伊比鳩魯", ["快樂", "死亡"]), ("愛比克泰德", ["控制", "看法"])]:
    exam.append({"q": f"{short(name)}最有名的主張是什麼？簡單講。", "expect": [kw], "kind": "主張"})
for t in T:
    k = {"電車難題": [["五", "5"], ["一", "1"]], "忒修斯之船": [["木板", "零件", "換"]], "缸中之腦": [["腦", "大腦"], ["電腦", "訊號", "模擬"]],
         "中文房間": [["理解", "懂"]], "經驗機器": [["快樂"], ["真實", "真的"]], "囚徒困境": [["合作", "背叛", "招"]],
         "洞穴寓言": [["影子"]], "薛西弗斯": [["石頭"]], "無知之幕": [["不知道", "羅爾斯"]], "瑪麗的房間": [["紅", "顏色"]],
         "胖子變體": [["推"]], "溺水兒童": [["救", "捐"]], "蓋吉氏的戒指": [["隱形"]], "瞬間移動機": [["複製", "同一個"]]}[t[0]]
    exam.append({"q": f"什麼是{t[0]}？", "expect": k, "kind": "思想實驗"})
for q in ["人活著是為了什麼？", "人生有意義嗎？", "什麼是幸福？", "人有自由意志嗎？", "人性本善還是本惡？", "為什麼要善良？", "死亡可怕嗎？", "我是誰？"]:
    exam.append({"q": q, "expect": [["意義", "選擇", "自己", "哲學", "看法", "角度", "可能"]], "no_narration": True, "kind": "大哉問"})

seen = set()
out = [it for it in out if not ((it["q"], it["a"]) in seen or seen.add((it["q"], it["a"])))]
R.shuffle(out)
total = 0
with open(sys.argv[1], "w", encoding="utf-8") as f:
    for i, it in enumerate(out):
        it["id"] = f"phi-{i:06d}"
        total += len(it["q"]) + len(it["a"])
        f.write(json.dumps(it, ensure_ascii=False) + "\n")
kinds = {}
for it in out:
    kinds[it["topic"]] = kinds.get(it["topic"], 0) + 1
print(len(out), "題，", total, "字", kinds)
with open(sys.argv[2], "w", encoding="utf-8") as f:
    for i, e in enumerate(exam):
        e.update({"id": f"phx-{i:04d}", "cat": "philosophy", "lang": "zh"})
        e["split"] = "hold" if int(hashlib.md5(e["id"].encode()).hexdigest(), 16) % 4 == 0 else "dev"
        f.write(json.dumps(e, ensure_ascii=False) + "\n")
print(len(exam), "題考題")
