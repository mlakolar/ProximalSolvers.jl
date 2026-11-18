import collections,csv,hashlib,json,math
from pathlib import Path
R=Path('<REVIEW>')
A=R/'.codex-orchestrator/audit'
rows=list(csv.DictReader(open(A/'review-r2-evidence/gate-details.tsv'),delimiter='\t'))
counts=collections.defaultdict(lambda:[0]*9);worst={}
for r in rows:
 T=r['T'];target=1e-8 if T=='Float64' else 1e-5
 key=T,float(r['tol']),'λ=0' if float(r['fr'])==0 else 'λ>0'
 informative=float(r['Fref'])>1e-20*float(r['F0'])
 tight=informative and float(r['refgap'])<=1e-12
 within=tight and float(r['subopt_hi'])<=target
 above=informative and float(r['subopt_lo'])>target
 refused=float(r['stat'])>=float(r['threshold']);empty=float(r['maxchange'])==0
 eps=2**(-52 if T=='Float64' else -23);wp=float(r['wp'])
 for i,v in enumerate([1,refused,refused and within,above,above and refused,wp>=64*eps,wp>=1e-5,empty,empty and refused]):counts[key][i]+=v
 if within:worst[key]=max(worst.get(key,0),wp)
print('Revised gate output independently checked against R2 per-solve replay:')
with open(A/'evidence/probe_cd_gate_release.txt') as f:
 next(f);next(f)
 for line in f:
  x=line.rstrip().split('\t');key=x[0],float(x[1]),x[2]
  assert [int(v) for v in x[3:12]]==counts[key]
  assert x[12]==format(worst[key],'.3g')
  print(key,counts[key],format(worst[key],'.3g'))
old=json.load(open('<TMP>/snapshot.json'))['project_files']
changed=[f for f,m in old.items() if (R/f).is_file() and hashlib.sha256((R/f).read_bytes()).hexdigest()!=m['sha256']]
print('Changed captured files versus revision 2:',changed)
expected={'.codex-orchestrator/audit/'+f for f in ['report/part1.md','report/part2.md','study/probe_cd_gate.jl','evidence/probe_cd_gate_release.txt']}
assert set(changed)==expected
print('All other captured files unchanged, including source/docs and 20 sweep TSVs.')
print('Native Float64 evaluation counterexamples to universal precision-only invisibility:')
x=2.0**-500;y=2.0**-700;alpha=2.0**300
print('alpha * (2*x*y) =',alpha*(2*x*y),'but 2*(alpha*x)*y =',2*(alpha*x)*y)
d=2.0**-53
print('(1+d)-1 =',(1+d)-1,'but (1-1)+d =',(1-1)+d)
