# offline simulation of candidate rules on trace308 logs
import csv,sys,glob,os,statistics as S
def load(fn):
    with open(fn) as f: return list(csv.DictReader(f,delimiter='\t'))
pat=sys.argv[1]; Ks=[1,2,3,5,10,20,50]
res={}
for fn in sorted(glob.glob(pat)):
    if fn.endswith('summary.tsv'): continue
    rows=load(fn); N=len(rows)
    st=[int(r['stall']) for r in rows]; P=[float(r['P64']) for r in rows]; gap=[float(r['gap']) for r in rows]
    nbt=[int(r['nbt']) for r in rows]; nv=[int(r['nver']) for r in rows]; pr=[int(r['prods']) for r in rows]
    Pbest=min(P); Pabs=abs(Pbest)
    out={}
    # R-B: stall with a rejected, curvature-checked trial in the same iteration
    kb=next((i for i in range(N) if st[i] and nbt[i]>=1 and nv[i]>=1),None)
    out['B']=kb
    for K in Ks:
        c=0; kk=None
        for i in range(N):
            c=c+1 if st[i] else 0
            if c>=K: kk=i; break
        out['A%d'%K]=kk
    res[os.path.basename(fn)]=(out,gap,P,pr,Pbest,Pabs,N)
def summarize(rule):
    stops=[];gaps=[];later=[];saved=[];miss=0;fired=0
    for name,(out,gap,P,pr,Pbest,Pabs,N) in res.items():
        k=out[rule]
        if k is None: stops.append(N); gaps.append(gap[-1]); saved.append(0); continue
        fired+=1; stops.append(k+1); gaps.append(gap[k]); miss+= gap[k]>1e-5
        later.append((P[k]-min(P[k:]))/Pabs)   # later improvement of P64 after the stop
        saved.append(1-pr[k]/pr[-1])
    print(f"{rule:5s} fired {fired}/{len(res)} stop-iter median {S.median(stops):.0f} max {max(stops)}  worst gap {max(gaps):.2e} misses {miss}  max later P64 gain {max(later) if later else 0:.1e}  mean products saved {S.mean(saved)*100:.1f}%")
for r in ['B']+['A%d'%K for K in Ks]: summarize(r)
