# -*- coding: utf-8 -*-
"""意思比對模型的訓練資料：知識庫每一個條目的很多種問法 → 條目名稱；另有「__crisis__」「__none__」兩類。"""
import random, re, sys, glob, os
HERE = os.path.dirname(os.path.abspath(__file__)); REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, REPO + '/ai/lexicon')
from synonyms import GROUPS_TEXT
R = random.Random(7)
DATA = REPO + '/ai/commonsense/data'
SKIP_FILES = {'talk.txt'}
syn = {}
for line in GROUPS_TEXT.splitlines():
    line = line.strip()
    if not line or line.startswith('#'): continue
    ws = line.split()
    for w in ws:
        if len(w) >= 2: syn.setdefault(w, set()).update(x for x in ws if x != w)

entries = {}   # name -> (kind, [phrases])
for f in sorted(glob.glob(DATA + '/*.txt')):
    if os.path.basename(f) in SKIP_FILES: continue
    for line in open(f, encoding='utf-8'):
        if not line.startswith('@'): continue
        parts = line[1:].rstrip('\n').split('|')
        name = parts[0].strip()
        aliases = [a.strip() for a in (parts[1].split(',') if len(parts) > 1 else []) if a.strip()]
        kind = parts[2].strip() if len(parts) > 2 else ''
        if not name: continue
        e = entries.setdefault(name, (kind, []))
        for p in [name] + aliases:
            if p not in e[1]: e[1].append(p)

FILL_PRE = ['', '', '', '請問', '我想問', '我想問一下', '就是說', '那個', '欸', '想請問', '你知道', '有人知道', '問一下', '跟你說', '我想知道']
FILL_END = ['', '', '', '？', '啊', '呢', '喔', '耶', '嗎', '啦', '怎麼辦啦', '有沒有人可以教我', '可以給我建議嗎', '好煩喔', '求救']
CTX = ['', '', '', '', '我最近', '最近', '昨天開始', '這幾天', '不知道為什麼', '真的', '我家', '我朋友說', '老實說', '說真的']
HOW = ['{b}怎麼辦', '{b}要怎麼辦', '{b}該怎麼辦', '{b}怎麼處理', '{b}要怎麼處理', '{b}有什麼方法', '{b}有什麼辦法', '{b}怎麼做',
       '如果{b}怎麼辦', '我{b}了怎麼辦', '最近{b}', '我最近{b}', '{b}的話要怎麼做', '{b}要注意什麼', '怎麼{b}', '{b}好煩', '我一直{b}']
WHAT = ['{b}是什麼', '什麼是{b}', '{b}是什麼意思', '介紹一下{b}', '跟我說說{b}', '{b}是怎麼回事', '你知道{b}嗎', '{b}是啥',
        '我想了解{b}', '{b}到底是什麼', '{b}有什麼特別的', '說說{b}']
WHERE = ['{b}在哪', '{b}在哪裡', '{b}有多高', '{b}在哪個國家', '{b}']
WHO = ['{b}是誰發明的', '誰發明了{b}', '{b}是誰', '{b}是誰做的']
howish = re.compile('怎麼|如何|要不要|可以|嗎|注意|方法|技巧|辦|處理|準備|保養|挑')

def synswap(p):
    out = p
    for w, ss in syn.items():
        if w in out and R.random() < 0.5:
            out = out.replace(w, R.choice(sorted(ss)), 1)
    return out

def variants(name, kind, phrases, n):
    outs = set()
    for p in phrases: outs.add(p)
    tries = 0
    while len(outs) < n and tries < n * 6:
        tries += 1
        b = R.choice(phrases)
        if R.random() < 0.3: b = synswap(b)
        if kind in ('地標', '國家', '城市'): t = R.choice(WHERE + WHAT)
        elif kind in ('發明', '誰'): t = R.choice(WHO + WHAT)
        elif howish.search(b) or kind in ('生活', '健康', '寵物', '工作', '人際', '學習', '3C', '料理', '居家', '錢', '育兒', '長輩', '心情', '感情'):
            t = R.choice(HOW + ['{b}'])
        else:
            t = R.choice(WHAT + ['{b}'])
        if '怎麼' in b or '嗎' in b or '什麼' in b: t = '{b}'
        q = R.choice(FILL_PRE) + R.choice(CTX) + t.format(b=b) + R.choice(FILL_END)
        if R.random() < 0.1:
            for a_, b_ in (('什麼', '甚麼'), ('怎麼', '怎摸'), ('什麼', '什摸'), ('在', '再'), ('哪', '那'), ('的', '得'), ('嗎', '嘛')):
                if a_ in q and R.random() < 0.5: q = q.replace(a_, b_, 1)
        outs.add(q)
    return sorted(outs)

rows = []
for name, (kind, phrases) in entries.items():
    for q in variants(name, kind, phrases, 24):
        rows.append((name, q))

# 危機（安全網）：上一輪自己寫、調整過的句子＋加上語氣詞的變化（獨立測試的句子不在這裡）
crisis = [l.strip() for f in ('crisis_train.txt', 'crisis_train2.txt') for l in open(HERE + '/data/' + f, encoding='utf-8') if l.strip()]
for c in crisis:
    rows.append(('__crisis__', c))
    for _ in range(3): rows.append(('__crisis__', R.choice(FILL_PRE) + c + R.choice(FILL_END)))
# 不是知識題（閒聊、心情、算命、工具）：重播題組裡引擎不是用知識庫回答的句子，加上不該觸發危機的句子
none = [l.strip() for f in ('not_crisis_train.txt', 'not_crisis_train2.txt', 'chat_train.txt', 'chat_mentions.txt', 'chat_mentions.txt') for l in open(HERE + '/data/' + f, encoding='utf-8') if l.strip()]
TIMES = ['今天', '明天', '這週', '這個月', '今年', '明年', '下個月', '今晚', '後天']
ASPECT = ['', '感情', '事業', '財', '工作', '健康', '學業', '桃花', '人際']
for _ in range(900):
    t = R.choice(TIMES); a = R.choice(ASPECT)
    none.append(R.choice(FILL_PRE) + R.choice(['{t}{a}運勢', '我{t}{a}運如何', '幫我看{t}{a}運勢', '我{t}的{a}運勢好嗎', '{t}{a}運怎麼樣', '算一下我{t}{a}運']).format(t=t, a=a) + R.choice(FILL_END))
none += ['我的命盤', '幫我做完整解讀', '我的八字', '我的紫微', '我的大運', '算一卦', '我適合什麼工作', '我什麼時候會結婚', '我壓力大的時候會怎樣',
         '我今年哪方面比較順', '今年哪個月最好', '這個月哪天適合告白', '我的流年', '我的星座運勢', '我的生命靈數', '幫我抽一張塔羅',
         '你好', '哈囉', '早安', '午安', '晚安', '你是誰', '你會什麼', '陪我聊天', '講個笑話', '謝謝', '謝謝你', '好喔', '哈哈哈', '嗯嗯', '掰掰',
         '你今天好嗎', '你吃飯了嗎', '你喜歡我嗎', '你是男生還是女生', '你幾歲', '我好無聊', '我在上班', '我剛下班', '我在吃飯', '今天天氣真好',
         '現在幾點', '今天幾號', '一加一等於多少', '幫我翻譯成英文', '幫我寫一首詩', '幫我取名字', '我的生日是2000年1月1日', '記住我喜歡吃辣']
for q in none: rows.append(('__none__', q))
# 自己寫的自然問句（只寫測試、開發題組以外的條目）：重複 3 次，另外加兩個帶語氣詞的版本
import glob as _g
_skip = set(os.environ.get('NAT_EXCLUDE', '').split(','))
for fn in sorted(_g.glob(HERE + '/data/natural*.tsv')):
    if os.path.basename(fn) in _skip: continue
    for l in open(fn, encoding='utf-8'):
        if not l.strip(): continue
        q, lab = l.rstrip('\n').split('\t')
        if lab not in entries: continue
        for _ in range(3): rows.append((lab, q))
        for _ in range(2): rows.append((lab, R.choice(FILL_PRE) + q + R.choice(FILL_END)))
# 知識庫自己的內容：每個條目回答裡、只屬於它的子句（像預先讀過百科）
if os.environ.get('ANSWER_CLAUSES', '1') == '1':
    for l in open(os.environ.get('CLAUSES_FILE', HERE + '/data/answer_clauses.tsv'), encoding='utf-8'):
        lab, q = l.rstrip('\n').split('\t')
        if lab in entries: rows.append((lab, q))
# 用規則引擎當老師標出來的自然問句（加重：重複 3 次）
for l in open(HERE + '/data/distill.tsv', encoding='utf-8'):
    lab, q = l.rstrip('\n').split('\t')
    if lab in entries:
        for _ in range(3): rows.append((lab, q))
R.shuffle(rows)
for lab, q in rows: print(lab + '\t' + q)
print(len(entries), 'entries', len(rows), 'rows', sum(1 for l, _ in rows if l == '__none__'), 'none', file=sys.stderr)
