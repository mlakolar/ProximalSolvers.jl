import csv, collections, re, statistics
f=float
main=list(csv.DictReader(open('out/eval_main.tsv'),delimiter='\t'))
E=list(csv.DictReader(open('out/eval_E.tsv'),delimiter='\t'))
E64=list(csv.DictReader(open('out/eval_E64.tsv'),delimiter='\t'))
def q(a,p): a=sorted(a); return a[min(len(a)-1,int(p*len(a)))] if a else float('nan')
print("== T1 coverage: certified / N, false certs (ratio < (P-U)/U), unsound (float ratio < BigFloat ratio)")
methods=['R','A','ridge','B','Bm','Bcm','D']
sets=['M81','OPTx','OPTn','NEG']
print("%-6s %-5s"%('set','T')+''.join('%-14s'%m for m in methods))
for s in sets:
  for T in ('Float64','Float32'):
    line="%-6s %-5s"%(s,T[-2:])
    for m in methods:
      rs=[r for r in main if r['set']==s and r['T']==T and r['method']==m]
      c=[r for r in rs if r['ok']=='true']
      fa=[r for r in c if f(r['ratio'])<f(r['lbexc'])-1e-12]
      un=[r for r in rs if r['bigratio'] not in ('NaN','') and r['ratio']!='NaN' and f(r['ratio'])<f(r['bigratio'])-1e-13]
      line+='%-14s'%("%d/%d f%d u%d"%(len(c),len(rs),len(fa),len(un)))
    print(line)
print("\n== T2 certified-ratio quantiles (q10/q50/q90/max)")
for s in ('M81','OPTx'):
  for m in ['A','Bm','Bcm','D']:
    a=[f(r['ratio']) for r in main if r['set']==s and r['method']==m and r['ok']=='true']
    print(s,m,len(a),"%.1e %.1e %.1e %.1e"%(q(a,.1),q(a,.5),q(a,.9),max(a)))
print("\n== T3 failure reasons")
for s in ('M81','OPTx'):
  for m in ['A','Bm','Bcm','D']:
    print(s,m,dict(collections.Counter(r['why'] for r in main if r['set']==s and r['method']==m and r['ok']!='true')))
print("\n== T4 work: D passes at certification; B sweeps; wall time per call (s)")
for s in ('M81','OPTx'):
  ps=[int(re.search(r'passes = (\d+)',r['info']).group(1)) for r in main if r['set']==s and r['method']=='D' and r['ok']=='true']
  print(s,'D passes q50/q90/max',q(ps,.5),q(ps,.9),max(ps))
  for m in ['A','Bm','Bcm','D']:
    t=[f(r['sec']) for r in main if r['set']==s and r['method']==m]
    print(s,m,'sec q50 %.2e q90 %.2e max %.2e'%(q(t,.5),q(t,.9),max(t)))
print("\n== T5 E (smoothing) : transplant-certified of original point; smoothed point itself certifies; passes")
for name,rows in (('E (native T)',E),('E64 (promoted to Float64)',E64)):
  for s in ('M81','OPTx','NEG'):
    for T in ('Float64','Float32'):
      rs=[r for r in rows if r['set']==s and r['T']==T]
      if not rs: continue
      ok=[r for r in rs if r['ok']=='true']; so=[r for r in rs if r['selfok']=='true']
      fa=[r for r in ok if f(r['ratio'])<f(r['lbexc'])-1e-12]
      ps=[int(r['passes']) for r in rs]
      print("%-26s %-5s %-4s N=%3d transplant-ok=%3d false=%d  smoothed-pt-ok=%3d  passes q50=%d q90=%d max=%d"%(name,s,T[-2:],len(rs),len(ok),len(fa),len(so),q(ps,.5),q(ps,.9),max(ps)))
