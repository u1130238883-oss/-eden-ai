import sys, json, numpy as np
work, outdir = sys.argv[1], sys.argv[2]
d = np.load(work + '/model.npz'); labels = json.load(open(work + '/labels.json', encoding='utf-8'))
parts = [d['Wm'], d['E'], d['b'], d['P'], d['c']]
blob = np.concatenate([p.astype(np.float32).ravel() for p in parts]).astype('<f2')
blob.tofile(outdir + '/meaning.bin')
meta = {"format": "meaning-f16-v1", "labels": labels, "buckets": int(d['E'].shape[0]), "hidden": int(d['E'].shape[1]), "enc": int(d['Wm'].shape[0])}
# 驗證題挑出來的門檻（pick.py）；沒有就用 App 的預設（0.6／0.5）
import os
if os.path.exists(work + '/pick.json'): meta.update(json.load(open(work + '/pick.json')))
json.dump(meta, open(outdir + '/meaning.json', 'w', encoding='utf-8'), ensure_ascii=False)
print('exported', blob.size, 'params', blob.nbytes / 1e6, 'MB', len(labels), 'labels')
