import sys
def leb(b,i):
    r=0;s=0
    while True:
        x=b[i];i+=1;r|=(x&0x7f)<<s;s+=7
        if x<0x80: return r,i
def sections(b):
    i=8;out=[]
    while i<len(b):
        sid=b[i];i+=1
        n,i=leb(b,i)
        name=None
        if sid==0:
            l,j=leb(b,i);name=b[j:j+l].decode()
        out.append((sid,name,i,n));i+=n
    return out
if __name__=="__main__":
    b=open(sys.argv[1],'rb').read()
    for sid,name,i,n in sections(b): print(sid,name,n)

def imports(b):
    for sid,name,i,n in sections(b):
        if sid!=2: continue
        cnt,j=leb(b,i); res=[]
        for _ in range(cnt):
            l,j=leb(b,j); mod=b[j:j+l].decode(); j+=l
            l,j=leb(b,j); fn=b[j:j+l].decode(); j+=l
            kind=b[j]; j+=1
            if kind==0: _,j=leb(b,j)
            elif kind==2:
                fl=b[j]; j+=1; _,j=leb(b,j)
                if fl&1: _,j=leb(b,j)
            elif kind==1: j+=1; fl=b[j]; j+=1; _,j=leb(b,j); 
            elif kind==3: j+=2
            res.append((mod,fn,kind))
        return res
