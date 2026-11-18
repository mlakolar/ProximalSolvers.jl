import csv, collections, hashlib, json, math, re
from pathlib import Path
from fractions import Fraction as Q
R=Path('<REVIEW>')
E=R/'.codex-orchestrator/audit/evidence'
TMP=Path('<TMP>')
def load(p,skip=0):
 with open(p) as f:
  for _ in range(skip):next(f)
  return list(csv.DictReader((s for s in f if not s.startswith('#')),delimiter='\t'))
def num(r,k):return float(r[k])
def target(T):return 1e-8 if T=='Float64' else 1e-5
print('1. Raw source/data identity against the round-1 captured edition')
old=json.load(open('<TMP>/snapshot.json'))['project_files']
checked=[]
for f,m in old.items():
 if f.startswith(('src/','docs/')) or (f.startswith('.codex-orchestrator/audit/evidence/sweep-') and f.endswith('.tsv')):
  assert hashlib.sha256((R/f).read_bytes()).hexdigest()==m['sha256'],f
  checked.append(f)
print('unchanged files',len(checked),'including all source/docs and',sum(s.endswith('.tsv') for s in checked),'raw sweep TSVs')
print('2. Corrected default positive-penalty group counts / interval extrema')
for v in ('release','lts'):
 for T in ('Float64','Float32'):
  a=load(E/f'sweep-{v}/cd_group_{T}.tsv')
  z=[r for r in a if r['tol']=='default' and num(r,'l1')>0 and r['converged']=='true']
  b=[r for r in z if num(r,'Fref')>max(0,1e-20*num(r,'F0')) and num(r,'subopt_lo')>target(T)]
  print(v,T,'converged',len(z),'above',len(b))
  for rel in ('true','false'):
   q=[r for r in b if r['relative']==rel]
   if q:print(' relative',rel,'n',len(q),'max(lo),max(hi)',max(num(r,'subopt_lo') for r in q),max(num(r,'subopt_hi') for r in q))
   allq=[r for r in z if r['relative']==rel]
   print(' all converged relative',rel,'max upper',max(num(r,'subopt_hi') for r in allq))
print('3. Warm zero-penalty rankdef stop-pass changes')
for v in ('release','lts'):
 for T in ('Float64','Float32'):
  a=load(E/f'sweep-{v}/cd_scalar_{T}.tsv')
  z=[r for r in a if r['fixture']=='rankdef' and num(r,'l1')==num(r,'l2')==0 and r['start']!='cold' and r['converged']=='true']
  d=[r for r in z if r['tol']=='default']
  c=[r for r in a if r['fixture']=='rankdef' and num(r,'l1')==num(r,'l2')==0 and r['start']=='cold' and r['tol']=='default']
  print(v,T,'all tolerances',len(z),'default',len(d),'default empty pass',sum(num(r,'maxchange')==0 for r in d),'warm max KKT',max(num(r,'kkt_rel') for r in d),'cold max KKT',max(num(r,'kkt_rel') for r in c))
print('4. Detailed replay of the CD gate experiment')
A=load(TMP/'gate-details.tsv')
for T in ('Float64','Float32'):
 z=[r for r in A if r['T']==T and num(r,'tol')==1e-7 and num(r,'fr')>0]
 b=[r for r in z if num(r,'stat')>=num(r,'threshold')]
 print(T,'default positive converged',len(z),'refused',len(b),'proved within by upper',sum(num(r,'subopt_hi')<=target(T) for r in b),'nonempty stopping passes among refused',sum(num(r,'maxchange')>0 for r in b),'zero-change among all',sum(num(r,'maxchange')==0 for r in z))
 z=[r for r in A if r['T']==T and num(r,'tol')==1e-7 and num(r,'fr')==0 and num(r,'subopt_lo')>target(T)]
 i=[r for r in z if num(r,'Fref')>max(0,1e-20*num(r,'F0'))]
 print(T,'lambda0 raw above',len(z),'refused',sum(num(r,'stat')>=num(r,'threshold') for r in z),'using declared cutoff above',len(i),'refused',sum(num(r,'stat')>=num(r,'threshold') for r in i))
print('5. Exact-arithmetic distinction between visit and final residual')
tau=Q(1,10**7)
X=[[Q(1),Q(1),Q(1)],[Q(0),Q(1),Q(0)],[Q(0),Q(0),Q(1)]];y=[Q(1),Q(0),Q(0)]
x=[1+Q(5,2)*tau,-Q(6,5)*tau,-Q(9,5)*tau]
h=[]
for k in range(3):
 r=[y[i]-sum(X[i][j]*x[j] for j in range(3)) for i in range(3)]
 a=sum(X[i][k]**2 for i in range(3));b=sum(X[i][k]*r[i] for i in range(3));d=b/a
 x[k]+=d;h.append(d)
r=[sum(X[i][j]*x[j] for j in range(3))-y[i] for i in range(3)]
g=[sum(X[i][k]*r[i] for i in range(3)) for k in range(3)]
assert h==[tau/2,3*tau/5,3*tau/5] and g[0]==6*tau/5
print('exact scaled pass changes / tau: 1/2, 3sqrt(2)/5, 3sqrt(2)/5; final stat/tau = 6/5')
oldx=Q(1);newx=Q(9,20);preG=Q(11,10)
print('elastic net X=y=1, lambda1=1/10, lambda2=1, old=1: new=9/20; scaled step',abs(newx-oldx),'previsit normalized KKT',preG)
print('6. Scaling exit and accuracy claims')
a=load(E/'probe_scales_release.tsv',skip=1)
for T,exmax in (('Float64',-100),('Float32',-20)):
 for sol in ('pgd','apg'):
  z=[r for r in a if r['T']==T and int(r['ex'])<=exmax and r['solver']==sol]
  print(T,sol,'scaled-down',len(z),'at maxiter',sum(r['its']=='200' for r in z),'early false',[(r['ex'],r['ey'],r['its']) for r in z if r['its']!='200'])
 z=[r for r in a if r['T']==T and r['solver']=='pgd' and r['converged']=='false' and int(r['its'])<200 and int(r['ex'])>=0]
 print(T,'up/high-y PGD early',len(z),'errors by multiplicity',dict(collections.Counter(r['subopt'] for r in z)))
print('7. Exact rational inconsistency of the rounded tall_exact fixture')
for T in ('Float64','Float32'):
 a=[[Q(float(v)) for v in s.split()] for s in open(TMP/f'tall_{T}.tsv')]
 p=len(a[0])-1;m=[r[:] for r in a[:p]]
 for j in range(p):
  i=next(i for i in range(j,p) if m[i][j]);m[j],m[i]=m[i],m[j]
  c=m[j][j];m[j]=[v/c for v in m[j]]
  for i in range(p):
   if i!=j:
    c=m[i][j];m[i]=[v-c*w for v,w in zip(m[i],m[j])]
 x=[r[-1] for r in m]
 assert all(a[i][-1]==sum(u*v for u,v in zip(a[i][:-1],x)) for i in range(p))
 r=a[p][-1]-sum(u*v for u,v in zip(a[p][:-1],x));assert r
 print(T,'first 10 equations nonsingular; row 11 inconsistent; exact residual',r,'approx',float(r))
print('8. Independent exact objective error of cancellation case A')
for T,bits in (('Float64',53),('Float32',24)):
 d=Q(1,2**bits);delta=(d-d/8)**2/(2*(2+d*d))
 print(T,float(delta/(Q(3,2)-delta)))
print('9. Zero-weight coverage')
s=(E/'probe_scales_release.tsv').read_text().splitlines()
for T in ('Float64','Float32'):
 z=[r for r in s if r.startswith('# '+T)]
 assert len(z)==12 and all('converged=true' in r for r in z)
 print(T,'zero-weight solves',len(z),'max normalized KKT',max(float(re.search(r'kkt=([^ ]+)',r)[1]) for r in z))
