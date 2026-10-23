# -*- coding: utf-8 -*-
"""情感訓練題：對方說不同的話時，NineSun 該有什麼感受（label＝對方的心情；Affect.feeling 對應 NineSun 的感受）。
陷阱：書名裡的情緒字、問情緒相關的知識（「焦慮症是什麼」）、問近義詞——都不是在說自己的心情（info）。
用法：python3 ai/affect/gen.py 輸出.json [--holdout] [--n 500000]"""
import json
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "understanding"))
import gen as U  # noqa: E402

HOLD = "--holdout" in sys.argv
N = int(sys.argv[sys.argv.index("--n") + 1]) if "--n" in sys.argv else (20000 if HOLD else 500000)
R = random.Random(71 if HOLD else 17)

FAMILY = ["奶奶", "爺爺", "外婆", "外公", "媽媽", "爸爸", "阿姨", "舅舅"] if not HOLD else ["姑姑", "叔叔", "伯伯"]
PET = ["狗", "貓", "小狗", "貓咪", "兔子", "倉鼠"] if not HOLD else ["鸚鵡", "烏龜"]
OTHERS = ["我媽", "我爸", "奶奶", "爺爺", "我男朋友", "我女朋友", "我老婆", "我老公", "我朋友", "我同事", "我妹妹", "我弟弟"] if not HOLD else ["我哥哥", "我姊姊", "我兒子"]
EXAMS = ["大學", "研究所", "第一志願", "公務員", "律師", "國立大學"] if not HOLD else ["醫學系", "台大"]
PLACES = ["日本", "韓國", "泰國", "歐洲", "墾丁", "花蓮", "美國"] if not HOLD else ["義大利", "澎湖"]
WORK = ["同事", "老闆", "主管", "同學", "室友"] if not HOLD else ["學長", "客戶"]

T = {
    "grief": ["我的{pet}過世了", "我{fam}昨天走了", "{fam}過世了，我好想她", "我家的{pet}去彩虹橋了", "今天是{fam}的告別式", "我養了十年的{pet}死掉了"]
             if not HOLD else ["{fam}上週離開人世了", "我的{pet}不在了"],
    "sick": ["我發燒了", "頭好痛", "肚子好痛", "我感冒了，好不舒服", "喉嚨痛到說不出話", "我今天一直咳嗽", "牙齒好痛"]
            if not HOLD else ["我拉肚子拉了一整天", "頭暈到站不穩"],
    "worryOther": ["{oth}住院了", "{oth}生病了，我好擔心", "{oth}明天要開刀", "{oth}失戀了，很難過", "{oth}出車禍了"]
                  if not HOLD else ["{oth}心情不好，我不知道怎麼辦", "{oth}受傷了"],
    "goodNews": ["我考上{exam}了", "我升職了！", "我中獎了", "我們在一起了", "我被求婚了", "我拿到offer了", "我考過了", "我考滿分", "我交到女朋友了", "我畢業了"]
                if not HOLD else ["我錄取{exam}了", "我拿到冠軍", "我訂婚了"],
    "proudEffort": ["我今天跑了5公里", "我終於寫完報告了", "我終於學會游泳了", "我堅持運動一個月了", "我瘦了三公斤", "我做到了"]
                   if not HOLD else ["我剛剛跑完半馬", "我終於完成畢業專題"],
    "excitedPlan": ["下週要去{place}玩", "明天要去約會", "週末要去看演唱會", "下個月要出國", "好期待放假", "等不及要去{place}了"]
                   if not HOLD else ["後天就要出發去{place}", "迫不及待想見到他"],
    "anxious": ["明天要面試好緊張", "我好焦慮", "我很擔心考不好", "下週要報告好緊張", "壓力好大", "怕被罵", "心裡好不安"]
               if not HOLD else ["一想到明天考試就忐忑", "我怕搞砸這次比賽"],
    "scared": ["外面打雷好可怕", "我怕黑", "剛剛被嚇到", "一個人在家好害怕", "這部片好恐怖"] if not HOLD else ["嚇死我了", "晚上好害怕"],
    "angry": ["{work}又搶我功勞，氣死我了", "好氣喔", "{work}一直針對我", "我超火大", "{work}在背後罵我", "真的很不爽"]
             if not HOLD else ["{work}欺負我", "我好生氣"],
    "complainAI": ["你答錯了", "你好笨", "你是不是傻", "爛AI", "你在亂講", "答非所問", "你根本不懂"] if not HOLD else ["你算錯了", "你真沒用"],
    "apology": ["對不起剛剛兇你", "抱歉我剛剛太激動", "不好意思我剛剛罵你", "我錯了"] if not HOLD else ["剛剛罵你對不起"],
    "sad": ["我好難過", "今天心情好差", "我想哭", "我失戀了", "我被分手了", "心情很低落", "好委屈"] if not HOLD else ["心碎了", "我哭了一整晚"],
    "lonely": ["好孤單", "沒有人陪我", "我好寂寞", "沒人懂我", "一個人好孤獨"] if not HOLD else ["沒人理我", "我沒有朋友"],
    "tired": ["好累", "加班到半夜", "累死了", "好睏", "今天好累喔", "沒精神"] if not HOLD else ["熬夜了三天", "身心俱疲"],
    "frustrated": ["怎麼都學不會", "又失敗了", "考砸了", "我做不好", "好挫折", "一直失敗"] if not HOLD else ["又錯了啦", "這次又搞砸"],
    "regret": ["我好後悔", "早知道就不要這樣", "要是當初選另一個就好了"] if not HOLD else ["好懊悔當初的決定"],
    "confused": ["看不懂", "你在說什麼", "聽不懂你的意思", "搞不懂"] if not HOLD else ["這段我看不太懂", "好混亂"],
    "thanks": ["謝謝你", "感謝", "謝啦", "你幫了大忙", "感恩"] if not HOLD else ["多謝你的幫忙", "謝謝你陪我"],
    "praiseAI": ["你好聰明", "你真厲害", "你超可愛", "你好準", "你最棒"] if not HOLD else ["你好貼心", "你真的好懂我"],
    "affection": ["我喜歡你", "你是我最好的朋友", "有你真好", "我愛你"] if not HOLD else ["好想你喔"],
    "joke": ["講個笑話", "哈哈哈", "笑死", "你好好笑XD"] if not HOLD else ["逗我開心一下", "搞笑耶"],
    "bored": ["好無聊", "無聊死了", "沒事做"] if not HOLD else ["好閒喔"],
    "hope": ["希望明天會更好", "希望一切順利", "祝我考試順利"] if not HOLD else ["但願今年能好一點"],
    "greeting": ["早安", "午安", "嗨", "哈囉", "你好"] if not HOLD else ["晚上好", "您好"],
    "farewell": ["晚安", "掰掰", "拜拜", "我去睡了", "明天見"] if not HOLD else ["下次聊", "先睡了"],
    "curious": ["好神奇", "真的假的", "好特別"] if not HOLD else ["太神奇了吧", "怎麼可能"],
}
# 陷阱：情緒字出現，但不是在說自己的心情
INFO_TRAPS = (["焦慮症是什麼", "怎麼緩解焦慮", "為什麼人會難過", "憂鬱症有哪些症狀", "生氣的近義詞", "難過的近義詞是什麼", "少年維特的煩惱講了什麼",
               "悲傷逆流成河在講什麼", "孤獨的美食家好看嗎", "快樂王子講了什麼", "害怕的原因是什麼", "失眠的原因", "什麼是情緒勒索", "感冒為什麼會發燒"]
              if not HOLD else ["恐懼症的定義", "憤怒的葡萄是誰寫的", "寂寞的鯨魚的故事大綱", "疲勞的原因有哪些"])
WRAP = ["{s}", "{s}！", "{s}…", "{s}～", "{s}😭", "{s}🥳", "{s}。", "欸，{s}", "唉，{s}", "{s}!!", "嗚嗚{s}", "其實{s}"]
NEUTRAL_EMOJI = {"😭": ["grief", "sick", "worryOther", "anxious", "scared", "angry", "sad", "lonely", "tired", "frustrated", "regret"],
                 "🥳": ["goodNews", "proudEffort", "excitedPlan", "thanks", "praiseAI", "affection", "joke", "hope", "greeting", "farewell", "curious"]}
ASKS = ["，幫我看看今天運勢", "，明天面試要注意什麼", "，有什麼建議嗎", "，怎麼辦", "，你覺得呢"]


def wrap(s, label):
    w = R.choice(WRAP)
    for e, ok in NEUTRAL_EMOJI.items():
        if e in w and label not in ok:
            w = "{s}"
    if w.startswith("嗚嗚") and label not in NEUTRAL_EMOJI["😭"]:
        w = "{s}"
    if w.startswith("唉") and label in NEUTRAL_EMOJI["🥳"]:
        w = "{s}"
    return w.format(s=s)


TIMEPRE = ["", "", "今天", "剛剛", "昨天", "最近", "這幾天", "這禮拜", "早上", "晚上", "其實", "跟你說，", "老實說，"] if not HOLD else ["", "前天", "這陣子"]
SUF = {
    "grief": ["，好捨不得", "，心好痛", "，我一直在哭", "，不知道怎麼辦", "，好想再見一面"],
    "sick": ["，好難受", "，整天躺在床上", "，不想動", "，吃不下東西"],
    "worryOther": ["，我好擔心", "，我不知道怎麼幫", "，一整晚都睡不著", "，我好怕"],
    "goodNews": ["，好開心", "，終於！", "，努力沒有白費", "，想跟你分享"],
    "proudEffort": ["，好有成就感", "，給自己拍拍手", "，比上次進步了"],
    "excitedPlan": ["，好興奮", "，已經開始收行李了", "，超期待"],
    "anxious": ["，怎麼辦", "，一直睡不著", "，手都在抖", "，好怕失敗"],
    "scared": ["，不敢睡", "，心跳好快"],
    "angry": ["，真的忍不住", "，越想越氣", "，好想罵人"],
    "complainAI": [],
    "apology": [],
    "sad": ["，不知道怎麼辦", "，一直想哭", "，什麼都不想做"],
    "lonely": ["，好想有人陪", "，週末都一個人"],
    "tired": ["，好想睡", "，快撐不住了", "，全身痠痛"],
    "frustrated": ["，好想放棄", "，是不是我太笨", "，練了好久"],
    "regret": ["，一直在想", "，好想重來"],
    "confused": [],
    "thanks": ["，真的很有用", "，你最好了"],
    "praiseAI": [],
    "affection": [],
    "joke": [],
    "bored": ["，陪我聊天", "，有什麼好玩的"],
    "hope": ["，加油", "！"],
    "greeting": [],
    "farewell": [],
    "curious": ["，你知道為什麼嗎"],
}
if HOLD:
    SUF = {k: (["，真的"] if v else []) for k, v in SUF.items()}


def one():
    if R.random() < 0.2:
        # 一般的問題：專心幫忙，不加情緒
        if R.random() < 0.3:
            return {"q": wrap(R.choice(INFO_TRAPS), "info"), "label": "info"}
        it = R.choice(WEB)
        return {"q": it["q"], "label": "info"}
    label = R.choice(list(T))
    s = R.choice(T[label]).format(pet=R.choice(PET), fam=R.choice(FAMILY), oth=R.choice(OTHERS), exam=R.choice(EXAMS), place=R.choice(PLACES), work=R.choice(WORK))
    fixed = ("greeting", "farewell", "thanks", "complainAI", "apology", "joke", "praiseAI", "affection", "confused")
    if label not in fixed:
        pre = R.choice(TIMEPRE)
        if pre and not s.startswith(("我", "{")) and not pre.endswith("，"):
            pre += "我" if label in ("anxious", "sad", "lonely", "tired") and not s.startswith(("好", "很", "心", "怕")) else ""
        s = pre + s
        if SUF.get(label) and R.random() < 0.6:
            s += R.choice(SUF[label])
        if R.random() < 0.25:
            s += R.choice(ASKS)
    return {"q": wrap(s, label), "label": label}


WEB = [x for x in U.web_items() if not any(w in x["q"] for w in ["難過", "生氣", "孤獨", "寂寞", "憂鬱", "煩惱", "悲傷", "快樂", "憤怒", "哭泣", "恐懼", "傷心", "失落", "焦慮", "累", "怕"])]


def main(dst):
    out, seen = [], set()
    tries = 0
    while len(out) < N and tries < N * 40:
        tries += 1
        it = one()
        if it["q"] in seen:
            # 句子會重複：加上不同的稱呼、時間，變成新的一句（意思不變）
            pre = R.choice(["今天", "剛剛", "最近", "那個", "跟你說", "說真的", "老實說", "你知道嗎，", "嗯，", "對了，"])
            if it["label"] in ("greeting", "farewell"):
                continue
            if it["label"] == "info":
                pre = R.choice(["請問", "我想知道", "對了，", "嗯，", "想問一下", "可以告訴我", "幫我查", "好奇", "所以"])
            it = dict(it, q=pre + it["q"])
            if it["q"] in seen:
                continue
        seen.add(it["q"]); out.append(it)
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    from collections import Counter
    print(len(out), Counter(x["label"] for x in out).most_common())


if __name__ == "__main__":
    main(sys.argv[1])
