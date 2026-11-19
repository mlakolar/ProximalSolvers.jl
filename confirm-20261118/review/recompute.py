import csv,glob,math,json,hashlib,statistics,collections,pathlib
R=pathlib.Path.cwd().parent
rows=[r for f in sorted(glob.glob(str(R/'out/heldout_all_113_*.tsv'))) for r in csv.DictReader(open(f),delimiter='\t')]
key=lambda r:tuple(r[x] for x in ('id','T','config','start'))
assert len({key(r)+(r['method'],) for r in rows})==len(rows)
bases={key(r):r for r in rows if r['method']=='M0'}
trig={k for k,r in bases.items() if r['triggered']=='true'}
h=[r for r in rows if key(r) in trig and r['group']!='fixture']
q=lambda a,p:sorted(a)[math.ceil(p*len(a))-1]
print('total rows/base/triggered/heldout',len(rows),len(bases),len(trig),len([r for r in h if r['method']=='M0']))
for m in ('M0','M1','M1g','M2','M2g'):
 a=[r for r in h if r['method']==m]
 print(m,'counts',collections.Counter(r['class'] for r in a),'work',[q([int(r['base'] if m=='M0' else r['used']) for r in a],p) for p in (.5,.9,1)],'secs',[q([float(r['secs']) for r in a],p) for p in (.5,.9,1)])
 for col in ('false_cert','changed_nodecrease','worse','improved','exhausted'): print(col,sum(r[col]=='true' for r in a),end='; ')
 print()
 if m!='M0':
  assert all(int(r['budget'])==min(100000-int(r['base']),max(2000,20*int(r['base']))) and 0<=int(r['used'])<=int(r['budget']) for r in a)
 for group in ('H-mat','H-real','H-cor','H-small'):
  b=[r for r in a if r['group'].split()[0]==group]
  print(group,'median excess',q([float(r['excess']) for r in b],.5),'midpoint',statistics.median([float(r['excess']) for r in b]))
a=[r for r in h if r['method']=='M1']
print('work/base',[q([int(r['used'])/int(r['base']) for r in a],p) for p in (.5,.9,1)])
print('uncert ratios',[q([float(r['ratio']) for r in a if r['certified']=='false'],p) for p in (.1,.5,.9)])
print('small by lambda',collections.Counter((r['id'].split('-')[1],r['class']) for r in a if r['group']=='H-small'))
print('cross mismatch cfg',collections.Counter())
main={key(r)+(r['method'],):r for r in rows}
cross=[r for f in glob.glob(str(R/'out/heldout_cross_110_*.tsv')) for r in csv.DictReader(open(f),delimiter='\t')]
print(collections.Counter(r['config'] for r in cross if (r['base'],r['used'])!=(main[key(r)+(r['method'],)]['base'],main[key(r)+(r['method'],)]['used'])))
for tag in ('A1',):
 with open(R/f'perf/local2_{tag}.tsv') as f: data=list(csv.DictReader((x for x in f if not x.startswith('#')),delimiter='\t'))
 print(tag,'cols',list(data[0]));globals()[tag]=data
print('oracle max',max(float(p.read_text().splitlines()[0]) for p in (R/'out/oracle').glob('*.txt')))
# preserved governing evidence
out=pathlib.Path.cwd()/'governing';out.mkdir(exist_ok=True)
manifest={}
for name in ('protocol.md','state.md','prototype.diff'):
 p=R/name;data=p.read_bytes();(out/name).write_bytes(data);manifest[str(p)]=hashlib.sha256(data).hexdigest()
(out/'hashes.json').write_text(json.dumps(manifest,indent=2))
