import os, sys, numpy as np
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = REPO + '/ios/NineSun/Resources'
from multiprocessing import Pool
sys.path.insert(0, REPO + '/ai/intent')
from encode import Encoder
E = None
def init():
    global E
    E = Encoder(RES + '/reader.json', RES + '/reader.bin')
def enc(q): return E.encode(q)
if __name__ == '__main__':
    inp, out = sys.argv[1], sys.argv[2]
    qs = sorted({l.rstrip('\n').split('\t')[-1] for l in open(inp, encoding='utf-8') if l.strip()})
    with Pool(4, initializer=init) as p: vs = p.map(enc, qs, chunksize=200)
    np.save(out + '.npy', np.stack(vs)); open(out + '.txt', 'w', encoding='utf-8').write('\n'.join(qs))
    print(len(qs), 'encoded')
