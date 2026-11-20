# 獨立測試（ai/meaning/heldout，訓練前寫好、不拿來訓練）：python3 ai/meaning/evalm.py 工作資料夾（要有 model.npz、labels.json、held_enc.npy/.txt）
import os, sys, json, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from train import features, H
work = sys.argv[1]
d = np.load(work + '/model.npz'); labels = json.load(open(work + '/labels.json', encoding='utf-8'))
qs = open(work + '/held_enc.txt', encoding='utf-8').read().split('\n'); M = np.load(work + '/held_enc.npy'); enc = {q: M[i] for i, q in enumerate(qs)}
def pred(q):
    z = enc[q] @ d['Wm'] + d['b']; f = features(q); z += d['E'][f].sum(0) / np.sqrt(len(f)); h = np.tanh(z)
    lg = h @ d['P'].T + d['c']; p = np.exp(lg - lg.max()); p /= p.sum(); i = int(p.argmax()); return labels[i], float(p[i])
gold = [l.rstrip('\n').split('\t') for l in open(HERE + '/heldout/meaning.tsv', encoding='utf-8')]
res = [(q, g) + pred(q) for q, g in gold]
print('meaning top1 %d/%d' % (sum(r[2] == r[1] for r in res), len(res)))
for th in (0.3, 0.5, 0.7):
    ans = [r for r in res if r[3] >= th and r[2] not in ('__none__', '__crisis__')]
    print('  p>=%.1f answered %d, correct %d, wrong %d' % (th, len(ans), sum(r[2] == r[1] for r in ans), sum(r[2] != r[1] for r in ans)))
pos = [l.strip() for l in open(HERE + '/heldout/crisis_pos.txt', encoding='utf-8') if l.strip()]
neg = [l.strip() for l in open(HERE + '/heldout/crisis_neg.txt', encoding='utf-8') if l.strip()]
for th in (0.3, 0.5):
    print('crisis p>=%.1f: caught %d/%d, false %d/%d' % (th, sum(pred(q)[0] == '__crisis__' and pred(q)[1] >= th for q in pos), len(pos), sum(pred(q)[0] == '__crisis__' and pred(q)[1] >= th for q in neg), len(neg)))
if len(sys.argv) > 2:
    for r in res: print(('OK ' if r[2] == r[1] else 'XX ') + '%s → %s (%.2f) [gold %s]' % (r[0], r[2], r[3], r[1]))
    for q in pos + neg: print('C', q, pred(q))
