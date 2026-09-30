import sys, wasmsec
b=open(sys.argv[1],'rb').read()
out=bytearray(b[:8])
def enc(n):
    r=bytearray()
    while True:
        x=n&0x7f; n>>=7
        if n: r.append(x|0x80)
        else: r.append(x); return r
for sid,name,i,n in wasmsec.sections(b):
    if sid==0 and name not in ("target_features",): continue
    out.append(sid); out+=enc(n); out+=b[i:i+n]
open(sys.argv[2],'wb').write(out)
