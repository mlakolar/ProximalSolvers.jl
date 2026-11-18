import sys, glob, os, csv
from sim import *
from an_matrix import fl
def load_sum(path): return list(csv.DictReader(open(path),delimiter='\t'))
tot=0; agree=0; bad=[]
for tag in ['mxd1-2640','mxd2-2640']:
  for d in sorted(glob.glob(E+tag+'/*/')):
    summ=load_sum(d+'run-summary.tsv')
    for T in ['Float32','Float64']:
      for prof in ['H','D','S','A']:
        kw=dict(PROFILES[prof])
        for r in summ:
            if r['T']!=T or r['solver']!='pgd' or r['profile']!=prof: continue
            rows=rd(f"{d}run-iters/{r['design']}-draw{r['draw']}-{T}.tsv")
            k,conv,term=stop(rows,T,**kw)
            tot+=1
            ok = (k==int(r['iterations'])) and (conv==(r['converged']=='true'))
            if ok: agree+=1
            else: bad.append((d.split('/')[-2],T,prof,r['design'],r['draw'],'sim',k,conv,term,'actual',r['iterations'],r['converged'],r['termination']))
print('compared',tot,'agree',agree)
for b in bad[:30]: print(b)
