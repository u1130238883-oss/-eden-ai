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
        outs.add(q)
    return sorted(outs)

rows = []
for name, (kind, phrases) in entries.items():
    for q in variants(name, kind, phrases, 24):
        rows.append((name, q))

# 危機（安全網）：上一輪自己寫、調整過的句子＋加上語氣詞的變化（獨立測試的句子不在這裡）
crisis = [l.strip() for l in open(HERE + '/data/crisis_train.txt', encoding='utf-8') if l.strip()]
for c in crisis:
    rows.append(('__crisis__', c))
    for _ in range(3): rows.append(('__crisis__', R.choice(FILL_PRE) + c + R.choice(FILL_END)))
# 不是知識題（閒聊、心情、算命、工具）：重播題組裡引擎不是用知識庫回答的句子，加上不該觸發危機的句子
none = [l.strip() for f in ('not_crisis_train.txt', 'chat_train.txt') for l in open(HERE + '/data/' + f, encoding='utf-8') if l.strip()]
for q in none: rows.append(('__none__', q))
R.shuffle(rows)
for lab, q in rows: print(lab + '\t' + q)
print(len(entries), 'entries', len(rows), 'rows', sum(1 for l, _ in rows if l == '__none__'), 'none', file=sys.stderr)
