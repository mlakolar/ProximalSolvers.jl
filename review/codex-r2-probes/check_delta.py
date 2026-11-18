from pathlib import Path
import gzip,csv,collections,json,math
B=Path('<RUN>/evidence')
O=Path('.codex-orchestrator/review-probes-r2')
def rows(f):
 with gzip.open(f,'rt') as z:yield from csv.DictReader(z,delimiter='\t')
def cls(r):
 target=1e-5 if r['T']=='Float32' else 1e-8
 if r['tight']=='true' and float(r['subopt_hi'])<=target:return 'within'
 if r['informative']=='true' and float(r['subopt_lo'])>target:return 'above'
 return 'undecided'
C=collections.Counter(); maxima={}
for f in sorted((B/'sweep-l-xeon').glob('*.tsv.gz')):
 C['files']+=1
 for r in rows(f):
  C['rows']+=1
  if r['status']!='ok' or r['equiv']!='true' or r['mism']!='0':C['invalid']+=1;continue
  if r['converged']!='true':continue
  C['converged']+=1
  if r['relative']!='true':continue
  T=r['T'];fam='scalar' if r['family']=='scalar' else 'group';e=2**(-23 if T=='Float32' else -52)
  if cls(r)=='above' and float(r['E'])>int(r['p'])*float(r['tolerance']):C[f'{fam} {T} false']+=1
  if r['start']!='adv' and (float(r['l1frac'])>0 or float(r['l2par'])>0) and float(r['tol']) in [1e-7,1e-4] and cls(r)!='above':
   k=f'{fam} {T} maxP';maxima[k]=max(maxima.get(k,0),float(r['P'])/(e*float(r['resp'])))
print('fourth sweep',dict(C),maxima,flush=True)
KEY=['family','T','design','loss','pen','l1frac','l2par','start','dir','j','container','order','momentum','seed','tol','relative','maxpasses']
A=collections.defaultdict(collections.Counter);examples=collections.defaultdict(list);counts=collections.Counter()
for f in sorted((B/'proto3-r').glob('*.tsv.gz')):
 d={}
 for r in rows(f):
  if r['module'] in ['master','S1024']:d.setdefault(tuple(r[k] for k in KEY),{})[r['module']]=r
 for v in d.values():
  m,s=v['master'],v['S1024'];T=m['T'];fam='scalar' if m['family']=='scalar' else 'group';inc=int(s['passes'])-int(m['passes'])
  if m['start']=='adv' and fam=='scalar' and m['converged']=='true' and cls(m)=='above':
   counts[T+' master above large']+=1;counts[T+' recovered above large']+=s['converged']=='true' and cls(s)=='within'
  if m['start']!='adv' and inc>0:
   key=fam+' '+T+' '+m['design'];a=A[key];a['n']+=1;a['maxextra']=max(a['maxextra'],inc)
   examples[key].append({'increase':inc,'master':m,'S1024':s})
  if m['start']!='adv' and s['converged']!='true' and int(s['passes'])<int(s['maxpasses']) and m['converged']=='true':counts[T+' ordinary refused']+=1
for k in examples:examples[k]=sorted(examples[k],key=lambda d:d['increase'],reverse=True)[:6]
result={'fourth':dict(C),'fourth_maxima':maxima,'counts':dict(counts),'more_by_design':{k:dict(v) for k,v in A.items()},'examples':dict(examples)}
json.dump(result,open(O/'delta-counts.json','w'),indent=2)
print('prototype counts',dict(counts));print('more passes by design',json.dumps(result['more_by_design'],sort_keys=True),flush=True)
