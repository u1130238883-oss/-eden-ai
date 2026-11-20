# -*- coding: utf-8 -*-
"""用規則引擎當老師：自然的問句 → 引擎回答 → 對到哪個條目的標準回答（只有一個對得上才算）→ (句子, 條目)"""
import re, sys
LEADS = ('辛苦了', '聽起來', '身體不舒服', '先抱抱', '我懂', '抱抱你', '別擔心', '好啊')
def load(fn):
    out = []
    for b in open(fn, encoding='utf-8', errors='ignore').read().split('=== ')[1:]:
        q, _, body = b.partition('\n'); out.append((q.strip(), body.split('\nTest Case')[0].strip()))
    return out
def content(body):
    if '[web:' in body or not body.startswith('[knowledge]'): return []
    t = re.sub(r'^\[\w+\]\s*', '', body)
    ls = [l.strip() for l in t.split('\n') if len(l.strip()) >= 8 and not l.strip().startswith(LEADS)]
    return ls[:2]
names = load(sys.argv[1]); pool = load(sys.argv[2])
key = {}
for n, body in names:
    for l in content(body)[:1]: key.setdefault(l[:24], set()).add(n)
pairs = 0
for q, body in pool:
    if '|' in q or '\t' in q: continue   # 換句話說檢查檔的「問題|答案」格式：會把答案洩漏進訓練
    hits = set()
    for l in content(body):
        hits |= key.get(l[:24], set())
    if len(hits) == 1:
        print(hits.pop() + '\t' + q); pairs += 1
print(pairs, 'pairs from', len(pool), file=sys.stderr)
