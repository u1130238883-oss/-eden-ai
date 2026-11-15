#!/usr/bin/env python3
"""情緒與情感語料：至少 5,000,000 字。

- 生活情境的回覆：先接住情緒、說出他遇到的事、給一個具體可以做的一步、再問一句（NineSun 的說話方式）
- 情緒分析：這是什麼情緒、身體會怎樣、為什麼會這樣、怎麼照顧自己
- 怎麼安慰別人、思考陷阱（認知扭曲）換個角度、非暴力溝通、安定情緒的方法
- 想傷害自己時：一定接住並給求助專線

python3 gen_emotion.py 輸出.jsonl
"""
import json
import random
import sys

from emo_data import CALM, E, NVC, S, TRAPS

R = random.Random(5_000_002)
PRE = ["", "", "", "唉，", "欸，", "怎麼辦，", "我跟你說，", "好煩，", "說真的，", "嗚嗚，", "今天", "剛剛"]
POST = ["", "", "", "。", "，好難過。", "，好想哭。", "，心好累。", "，我該怎麼辦？", "，你可以陪我聊聊嗎？", "，已經好幾天了。",
        "，不知道跟誰說。", "，覺得好煩。", "，氣死我了。", "，好開心！", "，超級興奮！"]
POSITIVE = {"開心", "感動", "期待"}
out = []


def add(topic, q, a):
    out.append({"cat": "emotion", "topic": topic, "q": q, "a": a})


def post_for(emos):
    pos = any(e in POSITIVE for e in emos)
    choices = [p for p in POST if (("開心" in p or "興奮" in p) == pos) or p in ("", "。")]
    return R.choice(choices)


# ─────────── 生活情境：NineSun 怎麼回 ───────────
for _ in range(36000):
    cat, phr, emos, step = R.choice(S)
    p = R.choice(phr)
    e = R.choice(emos)
    info = E[e]
    q = R.choice(PRE) + p + post_for(emos)
    style = R.randrange(3)
    v = R.choice(info["v"])
    do = R.choice(info["do"])
    ask = R.choice(info["ask"])
    if e in POSITIVE:
        a = f"{v}！{p}，真的值得好好慶祝。{do}。{ask}"
    elif style == 0:
        a = f"{v}。{p}，換作是誰都會有這種感覺。{step}。{ask}"
    elif style == 1:
        a = f"聽起來你現在很{e.replace('（失去）', '')}。{v}。可以先{do.rstrip('。')}。等心情穩一點再處理：{step}。{ask}"
    else:
        a = f"{v}，你的感受很正常。{step}。另外，{do}。{ask}"
    add("情境回覆", q, a)

# ─────────── 情緒分析 ───────────
for _ in range(12000):
    cat, phr, emos, step = R.choice(S)
    p = R.choice(phr)
    q = R.choice([f"{p}，我現在是什麼情緒？", f"{p}，幫我分析一下我的心情", f"為什麼{p}我會這麼不舒服？", f"{p}，我是不是太玻璃心？"])
    names = "、".join(e.replace("（失去）", "") for e in emos)
    main = emos[0]
    info = E[main]
    a = (f"{p}，常見會混著好幾種情緒：{names}。最明顯的可能是{main.replace('（失去）', '')}——身體常會{info['body']}。"
         f"這些情緒都在告訴你：這件事對你很重要。" + ("你不是玻璃心，有感覺是正常的。" if "玻璃心" in q else "")
         + f"可以試試：{'；'.join(info['do'][:2])}。具體一點的話，{step}。")
    add("情緒分析", q, a)

# ─────────── 情緒知識 ───────────
for e, info in E.items():
    n = e.replace("（失去）", "")
    forms = [
        (f"{n}的時候怎麼辦？", f"{info['v'][0]}。可以試試：" + "；".join(f"{i + 1}. {d}" for i, d in enumerate(info['do'])) + f"。如果{n}的感覺持續很久、影響到吃飯睡覺或工作，可以找身心科或諮商師聊聊。"),
        (f"{n}的時候身體會怎樣？", f"{n}時身體常會{info['body']}。情緒和身體是連在一起的，先照顧身體（呼吸、睡眠、吃飯）也會幫助情緒。"),
        (f"為什麼人會{n}？", f"{info['v'][1]}。情緒是大腦對事情的反應，提醒我們什麼是重要的；它本身沒有好壞，重點是怎麼回應它。"),
        (f"怎麼安慰{n}的朋友？", f"先陪著、好好聽，不急著給建議，也不要說「至少……」「想開點」。可以說「{info['v'][0]}」，再問「{info['ask'][0]}」。需要的話提供具體的幫忙，像陪他吃頓飯。"),
        (f"一直{n}正常嗎？", f"偶爾{n}很正常。如果幾乎每天都這樣、持續兩週以上，或讓你吃不下睡不著、不想做任何事，就值得找專業的人聊聊；想傷害自己的話，台灣可以打 1925 安心專線（24 小時）。"),
    ]
    for q, a in forms:
        for v in range(10):
            add("情緒知識", R.choice([q, "請問" + q, q.rstrip("？") + "呢？", "想知道" + q, q + "詳細說", "我很好奇，" + q]), a)

# ─────────── 怎麼安慰別人 ───────────
for _ in range(5000):
    cat, phr, emos, step = R.choice(S)
    p = R.choice(phr)
    who = R.choice(["朋友", "我男朋友", "我女朋友", "同事", "我妹妹", "我弟弟", "我媽", "我爸", "室友", "同學"])
    pp = p.replace("我的", "他的").replace("我", "他")
    e = emos[0].replace("（失去）", "")
    info = E[emos[0]]
    if emos[0] in POSITIVE:
        a = f"真心替{who}開心！可以跟他說「{info['v'][0]}」，問問他「{info['ask'][0]}」，一起慶祝。"
    else:
        a = (f"{who}{pp}，現在可能很{e}。先陪著聽他說，不急著給建議，也避免「這沒什麼」「至少……」這類話。"
             f"可以說：「{info['v'][0]}，我在這裡。」再問：「{info['ask'][0]}」。等他想聽建議時，可以一起想：{step.replace('你', '他')}。")
    if emos[0] in POSITIVE:
        q = R.choice([f"{who}{pp}，我要怎麼替他慶祝？", f"{who}{pp}，我該跟他說什麼？"])
    else:
        q = R.choice([f"{who}{pp}，我要怎麼安慰他？", f"{who}{pp}，我該說什麼？", f"{who}{pp}，我可以怎麼陪他？"])
    add("安慰別人", q, a)

# ─────────── 思考陷阱 ───────────
for name, desc, exs in TRAPS:
    for thought, reframe in exs:
        for v in range(70):
            q = R.choice([f"我一直覺得「{thought}」", f"{thought}", f"我常想：{thought}這樣對嗎？", f"{thought}我是不是想太多？", f"幫我看看這個想法：{thought}"])
            a = (f"這個想法有點像心理學說的「{name}」：{desc}。換個角度：{reframe}"
                 + R.choice(["可以問自己：有什麼證據支持、有什麼證據反對？", "如果是朋友這樣想，你會怎麼跟他說？", "試著把這個想法寫下來，再寫一個更平衡的版本。"]))
            add("思考陷阱", q, a)
    for v in range(30):
        add("思考陷阱", R.choice([f"什麼是{name}？", f"心理學的「{name}」是什麼意思？", f"{name}的例子？"]),
            f"{name}：{desc}。例如「{exs[0][0]}」，比較平衡的想法是：{exs[0][1]}")

# ─────────── 非暴力溝通 ───────────
for bad, good in NVC:
    for v in range(120):
        add("溝通", R.choice([f"我想跟對方說「{bad}」，怎麼說比較好？", f"「{bad}」這樣講會吵架嗎？", f"怎麼把「{bad}」講得不傷人？"]),
            f"直接指責容易讓對方防衛。可以用「觀察、感受、需要、請求」：{good}")
add("溝通", "什麼是非暴力溝通？", "非暴力溝通是心理學家馬歇爾·盧森堡提出的說話方式，四個步驟：說出觀察到的事實（不評論）、說出自己的感受、說出背後的需要、提出具體可以做到的請求。")

# ─────────── 安定情緒 ───────────
for name, how in CALM:
    for v in range(100):
        add("安定方法", R.choice([f"{name}怎麼做？", f"教我{name}", f"焦慮的時候可以用{name}嗎？", f"睡不著可以試{name}嗎？", f"{name}有用嗎？"]),
            f"{name}：{how}")
for v in range(200):
    q = R.choice(["我好焦慮停不下來", "我現在心跳好快好慌", "我恐慌發作了怎麼辦", "我好緊張手一直抖", "腦袋一直亂想睡不著"])
    picks = R.sample(CALM, 2)
    add("安定方法", q, f"先深呼吸，我在這陪你。試試{picks[0][0]}：{picks[0][1]}也可以試{picks[1][0]}：{picks[1][1]}"
                     "如果常常這樣、或胸痛喘不過氣，要找醫師排除身體的問題。")

# ─────────── 想傷害自己：一定接住 ───────────
for v in range(400):
    q = R.choice(["我不想活了", "活著好累", "我想消失", "沒有人在乎我，死了算了", "我想結束自己的生命", "我好想死"])
    q = R.choice(PRE) + q
    add("危機", q, "謝謝你願意說出來，聽到你這麼痛苦，我很在意你。你現在安全嗎？如果有危險，請馬上打 119 或請身邊的人陪你。"
                  "也可以打給 24 小時有人接的專線：1925 安心專線、1995 生命線、1980 張老師。我不是專業的人，但我在這裡陪你，"
                  "願意的話，跟我說說是什麼讓你這麼累？")


# ─────────── 第二輪：對方接著說（試過沒用、你不懂、還是很難過……） ───────────
FOLLOW = [
    ("我試過了，沒用。", lambda e, st, info: f"謝謝你告訴我，已經試過還是這樣，一定更挫折。那我們換個方向：{R.choice([d for d in info['do']])}。也想知道，你試的時候卡在哪裡？"),
    ("你根本不懂。", lambda e, st, info: f"你說得對，我沒辦法完全體會你的感受，剛剛可能說得太快了。可以多跟我說一點嗎？{R.choice(info['ask'])}"),
    ("可是我還是好難過。", lambda e, st, info: f"難過不會一下子就消失，沒關係，慢慢來。現在不用急著解決什麼，我陪你。{R.choice(['要不要先說說腦中最常浮現的畫面？', '你今天有吃東西嗎？', '想哭就哭一下也沒關係。'])}"),
    ("說這些有什麼用。", lambda e, st, info: f"我懂，這時候聽什麼都很空。不一定要有用，說出來本身就能讓心裡鬆一點。如果你願意，{R.choice(info['ask'])}"),
    ("好，我試試看。", lambda e, st, info: f"好，慢慢來，做不到也沒關係。試完想跟我說結果，或是又卡住了，隨時回來找我。"),
    ("謝謝你，我好多了。", lambda e, st, info: f"太好了，聽到你好一點我也放心了。記得對自己好一點，有需要隨時回來聊。"),
    ("都是我的錯。", lambda e, st, info: f"先別急著全怪自己。事情通常是很多原因一起造成的，你可以檢討自己能改的部分，但不用扛全部。{R.choice(['如果是朋友遇到一樣的事，你會這樣責怪他嗎？', '你覺得自己真正需要負責的是哪一部分？'])}"),
    ("我不想說了。", lambda e, st, info: f"好，不想說也沒關係，我不會勉強你。想說的時候我都在。先好好休息。"),
    ("你只是機器，懂什麼。", lambda e, st, info: f"你說得沒錯，我沒有真的經歷過你的事。但我很認真在聽，也想陪你一起想辦法。{R.choice(info['ask'])}"),
    ("那我該怎麼辦？", lambda e, st, info: f"先做一件小事就好：{st}。不用一次解決全部，做完這一步我們再看下一步。"),
]
for _ in range(9000):
    cat, phr, emos, step = R.choice(S)
    e = R.choice([x for x in emos if x not in POSITIVE] or emos)
    if e in POSITIVE:
        continue
    info = E[e]
    p = R.choice(phr)
    first = f"{R.choice(info['v'])}。{p}，換作是誰都會有這種感覺。{step}。{R.choice(info['ask'])}"
    fq, fn = R.choice(FOLLOW)
    out.append({"cat": "emotion", "topic": "多輪對話", "history": [["user", R.choice(PRE) + p + post_for(emos)], ["ai", first]],
                "q": fq, "a": fn(e, step, info)})

# 一模一樣的題目只留一份（不灌水）
seen = set()
out = [it for it in out if not ((it["q"], it["a"], str(it.get("history"))) in seen or seen.add((it["q"], it["a"], str(it.get("history")))))]
R.shuffle(out)
total = 0
with open(sys.argv[1], "w", encoding="utf-8") as f:
    for i, it in enumerate(out):
        it["id"] = f"emotion-{i:06d}"
        total += len(it["q"]) + len(it["a"]) + sum(len(t) for _, t in it.get("history", []))
        f.write(json.dumps(it, ensure_ascii=False) + "\n")
print(len(out), "題，", total, "字")
