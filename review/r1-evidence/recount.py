import csv, math, statistics, collections
from pathlib import Path
ROOT=Path('<REVIEW>/.codex-orchestrator/audit/evidence')
def read(path):return list(csv.DictReader(open(path),delimiter='\t'))
def yes(r,k='converged'):return r[k]=='true'
def n(r,k):return float(r[k])
def target(r):return 1e-8 if r['T']=='Float64' else 1e-5
def ok(r):return r['status']=='ok'
def good(r):return r.get('ref_tight','true')=='true' and n(r,'subopt_hi')<=target(r)
def bad(r):return r.get('ref_tight','true')=='true' and n(r,'subopt_lo')>target(r)
def key(r):return tuple(r[k] for k in ('solver','T','fixture','loss','penalty','l1frac','options','start'))
for ver in ('release','lts'):
 print('\nVERSION',ver)
 data={f:read(ROOT/f'sweep-{ver}'/f'{f}_{T}.tsv') for f in () for T in ()}
 total=0
 for fam in ('cd_scalar','cd_group','sqrt','grad'):
  for T in ('Float64','Float32'):
   a=read(ROOT/f'sweep-{ver}'/f'{fam}_{T}.tsv');total+=len(a)
   print(fam,T,'rows',len(a),'statuses',dict(collections.Counter(r['status'] for r in a)))
   if fam=='grad':
    c=[r for r in a if yes(r)]
    print(' conv',len(c),'exact violations',sum(n(r,'kkt_rel')>=n(r,'bound') for r in c),'max ratio',max(n(r,'kkt_rel')/n(r,'bound') for r in c))
    for sol in ('pgd','apg'):
     for opt in ('default','gradtol1e-8','ftol0','strict'):
      z=[r for r in a if r['solver']==sol and r['options']==opt]
      bh=[r for r in z if not yes(r) and n(r,'kkt_rel')<n(r,'bound')]
      inc=[r for r in z if r['exit']=='increase' and good(r)]
      st=[r for r in z if yes(r,'stagnated')]
      print(sol,opt,'conv',sum(yes(r) for r in z),'nonconv-bound',len(bh),'at-maxiter',sum(yes(r,'at_maxiter') for r in bh),'stagnated',len(st),'st ratio max',max((n(r,'kkt_rel')/n(r,'bound') for r in st),default=0),'increase-good',len(inc),'inc ratio median',statistics.median(n(r,'kkt_rel')/n(r,'bound') for r in inc) if inc else 0,'conv-and-increase',sum(yes(r) and yes(r,'f_increased') for r in z))
   elif fam=='sqrt':
    c=[r for r in a if yes(r)]
    print(' certified',len(c),'gap<ideal gap STRICT',sum(n(r,'gap')<n(r,'gap_exact_at_x') for r in c),'gap<subopt_lo STRICT',sum(n(r,'gap')<n(r,'subopt_lo') for r in c))
    base=[r for r in a if r['fixture'] not in ('wide','wide_exact','tall_exact','yzero') and r['relative']=='true']
    for level in ('0.001','0.05','0.3','0.7','1.01','2'):
     for tol in ('default','0.0001'):
      z=[r for r in base if r['lfrac']==level and r['tol']==tol]
      unc=[r for r in z if not yes(r)]
      print(' sqrt',level,tol,'conv',sum(yes(r) for r in z),'of',len(z),'unc hi',max((n(r,'subopt_hi') for r in unc),default=0))
    z=[r for r in a if r['fixture']=='corr95' and r['tol']=='0.0001' and not yes(r)]
    print('corr95 loose uncert',len(z),'gap range',min(n(r,'gap_exact_at_x') for r in z),max(n(r,'gap_exact_at_x') for r in z),'max subopt hi',max(n(r,'subopt_hi') for r in z))
    z=[r for r in a if r['warning']=='maxpasses' and r['tol']=='1.0e-10']
    print('sqrt tight maxpasses',len(z),'max subopt hi',max((n(r,'subopt_hi') for r in z),default=0))
   else:
    d=[r for r in a if r['tol']=='default' and n(r,'l1')>0]
    c=[r for r in d if yes(r)]
    tight=[r for r in c if yes(r,'ref_tight')]
    print('default positive',len(d),'conv',len(c),'tight',len(tight),'bad',sum(bad(r) for r in c),'worst hi tight',max(n(r,'subopt_hi') for r in tight),'max min_err',max(n(r,'min_err') for r in d))
    if fam=='cd_scalar':
     z=[r for r in a if r['tol']=='default' and r['relative']=='false' and int(r['passes'])==100000]
     print('absolute maxpasses',len(z),'subopt hi max',max((n(r,'subopt_hi') for r in z),default=0))
     z=[r for r in a if r['fixture']=='offset' and r['tol']=='default' and r['relative']=='true' and n(r,'l1')==0 and n(r,'l2')==0]
     print('offset zero penalty default relative subopt range',min(n(r,'subopt_lo') for r in z),max(n(r,'subopt_hi') for r in z))
     z=[r for r in a if r['tol']=='0.0001' and yes(r)]
    print('loose conv',len(z),'bad',sum(bad(r) for r in z),'positive bad',sum(bad(r) and n(r,'l1')>0 for r in z))
    if fam=='cd_group':
     proved=[r for r in c if n(r,'subopt_lo')>target(r)]
     hidden=[r for r in proved if not yes(r,'ref_tight')]
     print('CORRECTED group default positive: proved misses',len(proved),'hidden by ref_tight',len(hidden),'worst lo',max(n(r,'subopt_lo') for r in proved),'worst hi',max(n(r,'subopt_hi') for r in proved))
 print('TOTAL',total)
 # Recompute master/X1 pairings.
 for T in ('Float64','Float32'):
  aa={key(r):r for r in read(ROOT/f'sweep-{ver}'/f'grad_{T}.tsv')}
  bb={key(r):r for r in read(ROOT/('sweep-x1' if ver=='release' else 'sweep-x1-lts')/f'grad_{T}.tsv')}
  assert aa.keys()==bb.keys()
  ks=[k for k in aa if aa[k]['options'] not in ('ftol0','strict')]
  eq=[k for k in ks if aa[k]==bb[k]]
  changedcols=collections.Counter(c for k in ks for c in aa[k] if aa[k][c]!=bb[k][c])
  print('X1',T,'ftol>0',len(ks),'ALL columns identical',len(eq),'changes',dict(changedcols))
  ks=[k for k in aa if aa[k]['options'] in ('ftol0','strict')]
  new=[k for k in ks if yes(bb[k]) and not yes(aa[k])]
  print(' X1 new',collections.Counter(bb[k]['solver'] for k in new),'lost',sum(yes(aa[k]) and not yes(bb[k]) for k in ks),'viol',sum(yes(bb[k]) and n(bb[k],'kkt_rel')>=n(bb[k],'bound') for k in ks),'new obj changed',sum(aa[k]['F']!=bb[k]['F'] for k in new),'new bad',sum(bad(bb[k]) for k in new),'iterations',sum(int(aa[k]['iterations']) for k in ks),sum(int(bb[k]['iterations']) for k in ks))
  z=[k for k in aa if yes(bb[k]) and n(bb[k],'kkt_rel')>=n(bb[k],'bound')]
  print(' X1 ALL options exact violations',len(z))
