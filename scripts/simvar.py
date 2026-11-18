import sys, glob, os, csv, collections, statistics as stt
from sim import *
TGT={'Float32':1e-5,'Float64':1e-8}
VARIANTS=[
 ('H (harness settings)',                dict(PROFILES['H'])),
 ('H, increase <= 2 ulp(F) is noise',    dict(PROFILES['H'], incr_c=2)),
 ('H, increase <= 4 ulp(F) is noise',    dict(PROFILES['H'], incr_c=4)),
 ('H, gate floor 32 eps',                dict(PROFILES['H'], floor_mult=32)),
 ('H, gate floor 16 eps',                dict(PROFILES['H'], floor_mult=16)),
 ('H, gate floor 8 eps',                 dict(PROFILES['H'], floor_mult=8)),
 ('H, gate floor 4 eps',                 dict(PROFILES['H'], floor_mult=4)),
 ('H, floor 8 eps + increase<=4 ulp',    dict(PROFILES['H'], floor_mult=8, incr_c=4)),
 ('H + computable gap <= 1e-5 (T arithmetic)',   dict(PROFILES['H'], gapc=1e-5, gapsrc='gapc32')),
 ('H + computable gap <= 1e-5 (Float64 accum.)', dict(PROFILES['H'], gapc=1e-5, gapsrc='gapc64')),
 ('H + gap <= 1e-5 (independent, idealized)',    dict(PROFILES['H'], gapc=1e-5, gapsrc='gap')),
 ('H + computable gap <= 5e-6 (T arithmetic)',   dict(PROFILES['H'], gapc=5e-6, gapsrc='gapc32')),
 ('C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T)', dict(PROFILES['H'], incr_c=4, gapc=1e-5, gapsrc='gapc32')),
 ('C1b: same with gap <= 5e-6 (T)',                             dict(PROFILES['H'], incr_c=4, gapc=5e-6, gapsrc='gapc32')),
 ('C1c: same, idealized independent gap <= 1e-5',                dict(PROFILES['H'], incr_c=4, gapc=1e-5, gapsrc='gap')),
 ('C2: Q + computable gap <= 1e-5 (T)',                          dict(ftol=0, xtol=1e-14, gradtol=1e-7, allow_incr=True, gapc=1e-5, gapsrc='gapc32')),
 ('C2b: Q + idealized independent gap <= 1e-5',                  dict(ftol=0, xtol=1e-14, gradtol=1e-7, allow_incr=True, gapc=1e-5, gapsrc='gap')),
 ('D (library defaults)',                dict(PROFILES['D'])),
 ('S strict stress',                     dict(PROFILES['S'])),
 ('A (ftol 0, gradtol 1e-10)',           dict(PROFILES['A'])),
 ('Q (ftol 0, gradtol target/100)',      None),
]
def run(tags, rev, jv, T, designs=None):
    items=[]
    for tag in tags:
        d=E+f"{tag}/{rev}-{jv}/"
        if not os.path.exists(d+'run-summary.tsv'): continue
        seen=set()
        for r in csv.DictReader(open(d+'run-summary.tsv'),delimiter='\t'):
            if r['T']!=T or r['solver']!='pgd': continue
            key=(r['design'],r['draw'])
            if key in seen: continue
            seen.add(key)
            if designs and r['design'] not in designs: continue
            items.append((r['design'],r['draw'],rd(f"{d}run-iters/{r['design']}-draw{r['draw']}-{T}.tsv")))
    res=[]
    for name,kw in VARIANTS:
        n=conv=fs=miss=truth=runs=0; its=[]; waste=[]
        for design,draw,rows in items:
            kk=dict(kw) if kw is not None else dict(ftol=0,xtol=1e-14,gradtol=TGT[T]/100,allow_incr=True)
            k,c,term=stop(rows,T,**kk)
            n+=1
            kstar=next((int(r['k']) for r in rows if r['gap']<=TGT[T]),None)
            if k is None: runs+=1; continue
            g=rows[k-1]['gap']
            m = g>TGT[T]
            conv+=c; miss+=m; fs+= (c and m); truth+= ((not c) and m); its.append(k)
            if kstar is not None: waste.append(k-kstar)
        res.append((name,n,conv,miss,fs,truth,runs,stt.median(its) if its else None,stt.median(waste) if waste else None))
    return res
if __name__=='__main__':
    tags=sys.argv[1].split(','); T=sys.argv[2]
    for jv in ['1.10.13','1.13.3']:
      for rev in ['637f06a','9f86a80','dac9f4b']:
        print(f'### {tags} {rev} {jv} {T}')
        print('| variant | n | conv=true | missed | false success | truthful missed | runs on (traj. ended) | median stop it | median it after k* |')
        print('|---|---|---|---|---|---|---|---|---|')
        for r in run(tags,rev,jv,T): print('| '+' | '.join(str(x) for x in r)+' |')
