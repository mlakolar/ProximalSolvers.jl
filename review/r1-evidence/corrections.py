import csv,math,collections
from pathlib import Path
ROOT=Path('<REVIEW>/.codex-orchestrator/audit/evidence')
def rows(ver,fam,T):
 path=ROOT/f'sweep-{ver}'/f'{fam}_{T}.tsv'
 return [(i,r) for i,r in enumerate(csv.DictReader(open(path),delimiter='\t'),2)]
for ver in ('release','lts'):
 print('VERSION',ver)
 for T in ('Float64','Float32'):
  target=1e-8 if T=='Float64' else 1e-5
  a=[(i,r) for i,r in rows(ver,'cd_group',T) if r['tol']=='default' and float(r['l1'])>0 and r['converged']=='true']
  bad=[(i,r) for i,r in a if float(r['subopt_lo'])>target]
  hidden=[(i,r) for i,r in bad if r['ref_tight']=='false']
  print(' group',T,'converged',len(a),'proved misses',len(bad),'hidden',len(hidden),'by fixture/layout/relative',dict(collections.Counter((r['fixture'],r['family'],r['relative']) for i,r in bad)))
  print(' worst lo',max(float(r['subopt_lo']) for i,r in bad),'hi',max(float(r['subopt_hi']) for i,r in bad))
 a=[(i,r) for i,r in rows(ver,'cd_scalar','Float64') if r['tol']=='0.0001' and r['converged']=='true']
 bad=[(i,r) for i,r in a if float(r['Fref'])>0 and float(r['subopt_lo'])>1e-8]
 print(' loose scalar misses (positive Fref lower bounds)',len(bad),'positive',sum(float(r['l1'])>0 for i,r in bad),'hidden positive',sum(float(r['l1'])>0 and r['ref_tight']=='false' for i,r in bad))
 for fam in ('cd_scalar','cd_group'):
  for T in ('Float64','Float32'):
   a=[(i,r) for i,r in rows(ver,fam,T) if float(r['l1'])>0 and math.isfinite(float(r['min_err']))]
   for scope in ('all','default','default-converged'):
    z=[(i,r) for i,r in a if (scope=='all' or r['tol']=='default') and (scope!='default-converged' or r['converged']=='true')]
    i,r=max(z,key=lambda v:float(v[1]['min_err']))
    print(' min_err',fam,T,scope,r['min_err'],'line',i)
 a=[(i,r) for i,r in rows(ver,'cd_scalar','Float32') if r['tol']=='default' and r['relative']=='false' and r['passes']=='100000']
 i,r=max(a,key=lambda v:float(v[1]['subopt_hi']))
 print(' F5 scalar limit subopt_hi',r['subopt_hi'],'line',i)
 for T in ('Float64','Float32'):
  a=[r for i,r in rows(ver,'cd_scalar',T) if r['fixture']=='offset' and r['relative']=='true' and r['tol']=='default' and float(r['l1'])==float(r['l2'])==0]
  print(' F6 offset all starts range',min(float(r['subopt_lo']) for r in a),max(float(r['subopt_hi']) for r in a))
  a=[r for i,r in rows(ver,'sqrt',T) if r['fixture'] in ('wide','wide_exact','tall_exact') and r['converged']=='false']
  print(' F3 exact-fit design max lower bound',T,max(float(r['subopt_lo']) for r in a))
  a=[r for i,r in rows(ver,'grad',T) if r['converged']=='true' and r['f_increased']=='true' and r['options']=='default']
  print(' F7 default converged & increase',T,dict(collections.Counter(r['solver'] for r in a)))
  a=[r for i,r in rows(ver,'grad',T)]
  for sol in ('pgd','apg'):
   for opt in ('ftol0','strict'):
    z=[r for r in a if r['solver']==sol and r['options']==opt and r['converged']=='false' and float(r['kkt_rel'])<float(r['bound'])]
    s0=[r for r in z if r['fixture']=='yzero' and float(r['l1'])==0]
    print(' F2',T,sol,opt,'count',len(z),'undefined 0/0 rows',len(s0),'positive-scale count',len(z)-len(s0),'at maxiter corrected',sum(r['at_maxiter']=='true' for r in z)-sum(r['at_maxiter']=='true' for r in s0))
