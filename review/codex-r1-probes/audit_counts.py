import csv,gzip,pathlib,collections,math,json
B=pathlib.Path('<RUN>/evidence')
O=pathlib.Path('.codex-orchestrator/review-probes')
C=collections.Counter(); starts=collections.defaultdict(collections.Counter); rules=collections.defaultdict(collections.Counter); maxima=collections.defaultdict(float); samples={}
eps={'Float32':2**-23,'Float64':2**-52}; target={'Float32':1e-5,'Float64':1e-8}
def cls(r):
 if r['tight']=='true' and float(r['subopt_hi'])<=target[r['T']]:return 'within'
 if r['informative']=='true' and float(r['subopt_lo'])>target[r['T']]:return 'above'
 return 'undecided'
def rows(f):
 with gzip.open(f,'rt') as z:yield from csv.DictReader(z,delimiter='\t')
for f in sorted((B/'sweep-r-epyc').glob('*.gz')):
 for r in rows(f):
  C['rows']+=1
  if r['status']!='ok' or r['equiv']!='true' or r['mism']!='0':C['invalid']+=1;continue
  if r['converged']!='true':continue
  C['conv']+=1
  if r['relative']!='true':continue
  T=r['T']; fam='scalar' if r['family']=='scalar' else 'group'; c=cls(r); e=eps[T]; resp=float(r['resp']); thr=float(r['tolerance']); E=float(r['E']); dres=float(r['dres']); ordinary=r['start']!='adv'; positive=float(r['l1frac'])>0 or float(r['l2par'])>0
  false=c=='above' and E>int(r['p'])*thr
  C[f'{fam} {T} false']+=false
  if false:
   C['false']+=1; C[f'{fam} {T} false empty']+=float(r['maxchange'])==0; C['false without stale']+=dres<thr
   if ordinary and positive:C['ordinary positive false']+=1
  if ordinary:
   C[f'{fam} {T} ordinary conv']+=1;C[f'{fam} {T} ordinary empty']+=float(r['maxchange'])==0;C[f'{fam} {T} ordinary empty above']+=float(r['maxchange'])==0 and c=='above'
  sk=(fam,T,r['start'] if ordinary else 'adv',r['j']); starts[sk]['conv']+=1; starts[sk]['false']+=false
  keep=ordinary and positive and c!='above' and float(r['tol']) in [1e-7,1e-4]
  P=float(r['P']);P0=float(r['P0']);path=float(r['path'])
  if keep:
   C[f'{fam} {T} keep']+=1
   for nm,v in [('P',P),('dres',dres),('Rimg',float(r['Rimg']))]:maxima[f'{fam} {T} {nm}/epsresp']=max(maxima[f'{fam} {T} {nm}/epsresp'],v/(e*resp))
  for floor in [0,16,64,256,1024,4096]:
   L=max(float(r['tol']),floor*e)*resp
   tests={'A':float(r['Aq'])>=floor if floor else float(r['A'])>=thr,'C352':float(r['C352'])>=L,'K':float(r['K296'])>=max(float(r['tol']),floor*e),'R':float(r['Rimg'])>=L,'P':P>=L,'G0':max(P,P0)>=L,'Gpath':P+2*e*path>=L}
   for name,yes in tests.items():
    a=rules[(fam,T,floor,name)];a['keep']+=keep and yes;a['caught']+=false and yes
json.dump({'counts':dict(C),'starts':{' '.join(k):dict(v) for k,v in starts.items()},'rules':{' '.join(map(str,k)):dict(v) for k,v in rules.items()},'maxima':dict(maxima)},open(O/'sweep-audit.json','w'),indent=2)
print('SWEEP',json.dumps(dict(C),sort_keys=True)); print('MAXIMA',dict(maxima),flush=True)
KEY=['family','T','design','loss','pen','l1frac','l2par','start','dir','j','container','order','momentum','seed','tol','relative','maxpasses']
def keyed(f):
 d={}
 for r in rows(f):
  k=tuple(r[x] for x in KEY);d.setdefault(k,{})[r['module']]=r
 return d
pc=collections.Counter();differences=[]
for f in sorted((B/'proto-r').glob('*.gz')):
 a=keyed(f);b=keyed(B/'proto3-r'/f.name)
 for k,v in a.items():
  z=b[k];m=v['master'];fam='scalar' if m['family']=='scalar' else 'group';T=m['T'];ordinary=m['start']!='adv';keep=ordinary and (float(m['l1frac'])>0 or float(m['l2par'])>0) and m['converged']=='true' and cls(m)!='above'
  if any(z['master'][x]!=m[x] for x in ['converged','passes','maxchange','kkt_rel']):pc['masters mismatch']+=1
  if fam=='scalar':
   fm=m['converged']=='true' and cls(m)=='above' and float(m['E'])>int(m['p'])
   sr=z['S1024']; rr=v['R'];fs=sr['converged']=='true' and cls(sr)=='above' and float(sr['E'])>int(sr['p']);fr=rr['converged']=='true' and cls(rr)=='above' and float(rr['E'])>int(rr['p'])
   pc[f'{T} scalar master false']+=fm;pc[f'{T} scalar S false']+=fs;pc[f'{T} scalar R false']+=fr
   if fm and fs and not fr:pc['R removes but S leaves']+=1; differences.append((k,rr,sr))
  for name,r in list(v.items())+[(x,y) for x,y in z.items() if x!='master']:
   if keep:
    pc[f'{fam} {T} {name} keep']+=1;pc[f'{fam} {T} {name} lost']+=r['converged']!='true';pc[f'{fam} {T} {name} more']+=int(r['passes'])>int(m['passes']);pc[f'{fam} {T} {name} differs']+=any(r[x]!=m[x] for x in ['converged','passes','maxchange','kkt_rel'])
    pc[f'{fam} {T} {name} passes']+=int(r['passes'])
   if r['converged']!='true' and int(r['passes'])<int(r['maxpasses']) and cls(r)=='within':pc[f'{fam} {T} {name} refused within']+=1
json.dump({'counts':dict(pc),'R_removes_S_leaves_examples':differences[:2]},open(O/'proto-audit.json','w'),indent=2)
print('PROTO',json.dumps(dict(pc),sort_keys=True))
