import gzip,csv,collections,json
from pathlib import Path
B=Path('<RUN>/evidence/sweep-r-epyc')
mins={};detail={};A=collections.Counter()
for f in sorted(B.glob('*.tsv.gz')):
 with gzip.open(f,'rt') as z:
  for r in csv.DictReader(z,delimiter='\t'):
   if r['converged']!='true' or r['relative']!='true' or r['start']!='adv':continue
   T=r['T'];tar=1e-5 if T=='Float32' else 1e-8
   if r['informative']!='true' or float(r['subopt_lo'])<=tar or float(r['E'])<=int(r['p'])*float(r['tolerance']):continue
   fam='scalar' if r['family']=='scalar' else 'group';key=(T,r['design'],fam);j=int(r['j'])
   if key not in mins or j<mins[key]:mins[key]=j;detail[key]=r
for T in ['Float32','Float64']:
 for fam in ['scalar','group','either']:
  by={}
  for (t,d,f),j in mins.items():
   if t==T and (f==fam or fam=='either'):by[d]=min(by.get(d,999),j)
  print(T,fam,'designs',len(by),'histogram',dict(sorted(collections.Counter(by.values()).items())),'at8to12',sum(8<=j<=12 for j in by.values()))
  print('designs_by_first_j',json.dumps(dict(sorted(by.items()))))
json.dump({'onsets':{' '.join(k):v for k,v in mins.items()},'first_rows':{' '.join(k):r for k,r in detail.items()}},open('.codex-orchestrator/review-probes-r3/onsets.json','w'),indent=2)
