"""產生 10000 題翻譯問法的測試題（Swift 的 TranslateQuestionsTests 逐題檢查 Translate.parse 有沒有聽懂）。

每題：q 問句；text 應該翻的內容（null＝不是要翻譯）；target 要翻成的語言代號。
用法：python3 ai/translate_questions.py ios/EchoCore/Tests/EchoCoreTests/Fixtures/translate_questions.json
      python3 ai/translate_questions.py ios/EchoCore/Tests/EchoCoreTests/Fixtures/translate_questions2.json 2   （第二批：新的問法、簡稱「中翻英」）
"""
import json
import random
import sys

random.seed(20261022)

# 要翻的內容：(文字, 原文語言)
CONTENT = [(s, "zh") for s in [
    "你有沒有吃飯", "你吃飯了嗎", "謝謝", "早安", "我愛你", "我很累", "學校", "蘋果", "明天見", "生日快樂", "我想喝咖啡",
    "廁所在哪裡", "這個多少錢", "我會晚一點到", "今天天氣很好", "好久不見", "我不懂", "你好嗎", "我很想你", "晚安", "對不起",
    "請問車站怎麼走", "我是學生", "電腦", "老師", "祝你好運", "我們去看電影吧", "你叫什麼名字", "我肚子餓了", "你在做什麼",
    "我很開心", "這道菜很好吃", "下雨了", "我住在台北", "加油", "小心", "沒關係", "我的手機壞了", "可以幫我拍照嗎", "我迷路了",
    "你怎麼了", "他說他明天會來", "我在學校", "我想學游泳", "這是我的", "你今天過得好嗎", "我不會游泳", "媽媽", "冰淇淋",
    "我喜歡貓", "請給我一杯水", "結帳", "我對花生過敏", "我需要看醫生", "新年快樂", "你住在哪裡", "我們是朋友", "工作很忙",
]] + [(s, "en") for s in [
    "thank you", "good morning", "I love you", "where is the bathroom", "how much is this", "I'm tired", "see you tomorrow",
    "nice to meet you", "I miss you", "happy birthday", "what are you doing", "apple", "school", "coffee", "I'm hungry",
    "it's raining", "good luck", "excuse me", "how are you", "the weather is nice today",
]] + [(s, "es") for s in [
    "gracias", "buenos días", "te quiero", "¿dónde está el baño?", "hasta luego", "mucho gusto", "¿cómo estás?",
    "tengo hambre", "buenas noches", "por favor", "lo siento", "me llamo Ana",
]] + [(s, "it") for s in [
    "grazie", "buongiorno", "ti amo", "dov'è il bagno", "arrivederci", "mi manchi", "quanto costa", "buonanotte",
    "ho fame", "come stai", "piacere di conoscerti", "per favore",
]]

ZH_NAMES = {"en": ["英文", "英語"], "es": ["西班牙文", "西班牙語", "西文"], "it": ["義大利文", "義大利語", "意大利文", "意大利語"],
            "zh": ["中文", "國語", "華語"]}
EN_NAMES = {"en": ["English"], "es": ["Spanish"], "it": ["Italian"], "zh": ["Chinese", "Mandarin"]}
ES_NAMES = {"en": ["inglés"], "es": ["español"], "it": ["italiano"], "zh": ["chino"]}
IT_NAMES = {"en": ["inglese"], "es": ["spagnolo"], "it": ["italiano"], "zh": ["cinese"]}
CODE = {"zh": "zh-Hant", "en": "en", "es": "es", "it": "it"}

ZH_T = [
    "{X}用{L}怎麼說", "{X}用{L}怎麼講", "{X}用{L}說", "{X}用{L}講", "{X}{L}怎麼說", "{X}的{L}", "{X}的{L}是什麼",
    "{X}{L}是什麼", "{X}的{L}怎麼說", "{X}用{L}要怎麼說", "{X}用{L}該怎麼講", "{X}翻成{L}", "{X}翻譯成{L}", "把{X}翻成{L}",
    "把{X}翻譯成{L}", "幫我把{X}翻成{L}", "請把{X}翻譯成{L}", "幫我翻成{L}：{X}", "翻譯成{L}：{X}", "{L}翻譯：{X}",
    "用{L}怎麼說{X}", "用{L}說{X}", "教我用{L}說{X}", "請用{L}說{X}", "我想用{L}說{X}", "用{L}跟他說{X}", "用{L}跟朋友說{X}",
    "這句{L}怎麼說：{X}", "這句話用{L}怎麼說：{X}", "「{X}」用{L}怎麼說", "「{X}」的{L}", "{X}，{L}怎麼說？", "{X}用{L}怎麼寫",
    "{X}用{L}怎麼念", "跟我說{X}的{L}", "告訴我{X}用{L}怎麼說", "請問{X}用{L}怎麼說", "請問{X}的{L}是什麼？", "{X}要怎麼用{L}表達",
    "如何用{L}表達{X}", "{X}用{L}表達", "麻煩用{L}寫：{X}", "可以幫我把{X}翻成{L}嗎", "{X}翻成{L}是什麼", "{X}在{L}裡怎麼說",
    "{X}{L}要怎麼講", "{X}用{L}怎麼說呢", "{X}用{L}要怎麼講啊", "欸，{X}用{L}怎麼說", "那個{X}的{L}是什麼", "{X}的{L}怎麼寫",
    "翻譯一下{X}，翻成{L}", "{X}用{L}來說", "{X}換成{L}怎麼說", "把「{X}」翻譯成{L}", "幫我用{L}翻譯：{X}",
]
EN_T = [
    "how do you say {X} in {L}", "how do you say {X} in {L}?", "how to say {X} in {L}", "translate {X} to {L}",
    "translate {X} into {L}", "translate to {L}: {X}", "what is {X} in {L}", "what's {X} in {L}?", "how would I say {X} in {L}",
    "say {X} in {L}", "can you translate {X} into {L}?", "please translate {X} to {L}", "how do I say {X} in {L}?",
]
ES_T = ["¿cómo se dice {X} en {L}?", "cómo se dice {X} en {L}", "traduce {X} al {L}", "traducir {X} al {L}", "¿Cómo se dice {X} en {L}?"]
IT_T = ["come si dice {X} in {L}?", "traduci {X} in {L}", "come si dice {X} in {L}", "Come si dice {X} in {L}?"]

# 第二批的新問法
ZH_T2 = [
    "{X}{L}怎樣說", "{X}{L}咋說", "{X}用{L}怎麼講比較道地", "{X}用{L}要怎麼講才自然", "{L}：{X}", "{X}（{L}）", "{X}的{L}翻譯",
    "{X}{L}翻譯", "{X} 用{L}", "怎麼用{L}說{X}", "我要怎麼用{L}說{X}", "如果要用{L}說{X}要怎麼說", "{X} 要怎麼翻成{L}",
    "{X} 這句{L}怎麼說", "{X}這句話{L}怎麼說", "{L}的話{X}怎麼說", "{X} 用{L}說的話是什麼", "{X}，{L}", "{X}? {L}",
    "嗨，{X}用{L}怎麼說", "NineSun，{X}用{L}怎麼說", "那{X}用{L}怎麼說", "還有{X}的{L}", "我想知道{X}用{L}怎麼說",
    "可不可以告訴我{X}的{L}", "{X}翻{L}", "幫我翻{L}：{X}", "{L}怎麼講{X}", "想問{X}的{L}怎麼說", "{X}用{L}怎樣講",
]
ABBR = {"en": ["英"], "es": ["西"], "it": ["義", "意"], "zh": ["中"]}
ABBR_T = ["{S}翻{A}：{X}", "{S}翻{A} {X}", "翻{A}：{X}", "幫我翻{A} {X}", "{X} 翻{A}", "{X}，翻{A}", "{X}{S}翻{A}", "{X}翻成{A}文", "{X} {S}翻{A}"]
EN_T2 = ["{X} in {L} please", "what's the {L} for {X}", "what is the {L} word for {X}", "{L} for {X}", "how do you translate {X} into {L}",
         "how do I translate {X} to {L}?", "could you translate {X} to {L}"]
ES_T2 = ["¿cómo digo {X} en {L}?", "¿cómo puedo decir {X} en {L}?", "cómo se escribe {X} en {L}"]
IT_T2 = ["come posso dire {X} in {L}?", "come dico {X} in {L}", "come si scrive {X} in {L}?"]

NEG_T = [
    "你會說{L}嗎", "你會不會講{L}", "我想學{L}", "{L}好難", "{L}怎麼學比較快", "學{L}要多久", "你的{L}很好", "我的{L}程度不好",
    "{L}老師很兇", "{L}課好無聊", "{L}考試考砸了", "我在學{L}", "{L}的文法好複雜", "推薦學{L}的app", "{L}口音怎麼練",
    "你懂{L}嗎", "他說{L}嗎", "義大利人說{L}嗎", "{L}難不難", "你能說{L}嗎", "我{L}說得不好", "{L}單字量要多少", "{L}檢定怎麼報名",
]
NEG_PLAIN = [
    "今天運勢如何", "我今天好累", "什麼是量子力學", "幫我看八字", "明天會下雨嗎", "我愛你", "你叫什麼名字", "台北有什麼好吃的",
    "推薦一部電影", "英文", "西班牙語", "你會講幾種語言", "西班牙說什麼語言", "義大利的首都是哪裡", "你好", "早安", "謝謝你",
    "我今年感情運怎麼樣", "怎麼辦", "為什麼", "我好難過", "1+1等於多少", "你是誰", "幫我算一卦", "英國在哪裡", "西班牙好玩嗎",
    "什麼是中文", "量子力學是什麼意思", "iPhone是什麼", "今天天氣如何", "你母語是什麼", "how are you", "what time is it",
    "I love you", "hola", "grazie mille",
]


def ambiguous(tpl, x):
    """「我不懂英文是什麼」可以是「翻譯我不懂」也可以是「我看不懂英文」：內容最後一個字跟語言黏在一起會變成另一個意思的，不出題"""
    return (x[-1] in "懂學會說講" and "{X}{L}" in tpl) or (x[-1] == "的" and ("{X}{L}" in tpl or "{X}的{L}" in tpl))


def item(q, text, target):
    return {"q": q, "text": text, "target": CODE[target] if target else None}


def positives():
    out = []
    for x, src in CONTENT:
        for t in [l for l in CODE if l != src]:
            if src == "zh":
                for tpl in [t_ for t_ in ZH_T if not ambiguous(t_, x)]:
                    for L in ZH_NAMES[t]:
                        out.append(item(tpl.format(X=x, L=L), x, t))
            else:
                for tpl in ZH_T:
                    for L in ZH_NAMES[t]:
                        out.append(item(tpl.format(X=x, L=L), x, t))
                for tpl in EN_T:
                    for L in EN_NAMES[t]:
                        out.append(item(tpl.format(X=x, L=L), x, t))
            # 外文的問法也可以問中文內容
            for tpl in EN_T:
                for L in EN_NAMES[t]:
                    if src == "zh":
                        out.append(item(tpl.format(X=x, L=L), x, t))
            for tpl in ES_T:
                for L in ES_NAMES[t]:
                    out.append(item(tpl.format(X=x, L=L), x, t))
            for tpl in IT_T:
                for L in IT_NAMES[t]:
                    out.append(item(tpl.format(X=x, L=L), x, t))
    return out


def positives2():
    out = []
    zhsrc = {"zh": "中", "en": "英", "es": "西", "it": "義"}
    for x, src in CONTENT:
        for t in [l for l in CODE if l != src]:
            for tpl in [t_ for t_ in ZH_T2 if not ambiguous(t_, x)]:
                for L in ZH_NAMES[t]:
                    out.append(item(tpl.format(X=x, L=L), x, t))
            for tpl in ABBR_T:
                for A in ABBR[t]:
                    out.append(item(tpl.format(X=x, A=A, S=zhsrc[src]), x, t))
            for tpl in EN_T2:
                for L in EN_NAMES[t]:
                    out.append(item(tpl.format(X=x, L=L), x, t))
            for tpl in ES_T2:
                for L in ES_NAMES[t]:
                    out.append(item(tpl.format(X=x, L=L), x, t))
            for tpl in IT_T2:
                for L in IT_NAMES[t]:
                    out.append(item(tpl.format(X=x, L=L), x, t))
    return out


NEG2 = ["我在翻英文書", "英翻中好難", "中翻英要多少錢", "翻譯社推薦", "你翻譯得不錯", "英國人", "我喜歡西班牙", "義大利麵好吃",
        "我想去義大利玩", "西班牙海鮮飯怎麼做", "英文名字怎麼取", "幫我取一個英文名字", "我英文不好", "英文單字怎麼背",
        "你說英文好聽嗎", "中文好難學嗎", "學西班牙文有用嗎", "義大利文跟西班牙文像嗎", "今天想吃什麼", "我好累喔",
        "西班牙在哪裡", "義大利人很熱情", "翻牆", "翻身", "我英文考100分", "推薦英文歌", "英文老師好帥", "什麼叫翻譯",
        "how do you do", "translate", "中文", "英翻", "翻英"]


def negatives():
    out = []
    for tpl in NEG_T:
        for names in ZH_NAMES.values():
            for L in names:
                out.append(item(tpl.format(L=L), None, None))
    out += [item(q, None, None) for q in NEG_PLAIN]
    return out


def main(dst, batch="1"):
    if batch == "2":
        random.seed(20261023)
        pos, neg = positives2(), [item(q, None, None) for q in NEG2]
        for tpl in NEG_T:
            for names in ZH_NAMES.values():
                neg.append(item("欸 " + tpl.format(L=names[0]), None, None))
    else:
        pos, neg = positives(), negatives()
    random.shuffle(pos)
    # 9000 題要翻譯的 + 1000 題不是（不夠的重複抽，加不同的語氣詞）
    pos = pos[:9000]
    extra = []
    tails = ["", "？", "?", "啊", "～"]
    while len(neg) + len(extra) < 1000:
        n = random.choice(neg)
        extra.append(item(n["q"] + random.choice(tails), None, None))
    data = pos + neg + extra
    data = data[:10000]
    random.shuffle(data)
    json.dump(data, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(len(data), "questions;", sum(1 for d in data if d["text"]), "to translate")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "1")
