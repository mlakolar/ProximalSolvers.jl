"""Recovered summarizer. Does not run Julia or fabricate lost measurements."""
import csv,json,statistics,sys
from pathlib import Path

def records(path):
    lines=Path(path).read_text().splitlines()
    return [s for s in lines if s.startswith('#')], list(csv.DictReader((s for s in lines if not s.startswith('#')),delimiter='\t'))
def stats(values):
    qs=statistics.quantiles(values,n=4)
    return {'n':len(values),'median':statistics.median(values),'p25':qs[0],'p75':qs[2],'min':min(values),'max':max(values)}
meta,rows=records(sys.argv[1]);out={'metadata':meta,'cases':{}}
assert '# sources_unchanged=true' in meta, 'source identity not verified through completed timing session'
assert len(rows)==288, f'incomplete timing session: {len(rows)} rows'
assert all(None not in r and all(v is not None for v in r.values()) for r in rows), 'malformed TSV row'
keys=sorted({tuple(r[k] for k in ('type','n','p','solver')) for r in rows})
assert len(keys)==8, 'expected eight type/size/solver cases'
for key in keys:
    rr=[r for r in rows if tuple(r[k] for k in ('type','n','p','solver'))==key]
    assert len(rr)==36, (key,'incomplete case')
    numerical=list(rr[0])[11:]
    identical={k:len({r[k] for r in rr})==1 for k in numerical}
    modules={}
    for module in ('1','2'):
        mr=[r for r in rr if r['module']==module]
        assert len(mr)==18, (key,module,'unbalanced module samples')
        modules[module]={'seconds':stats([float(r['seconds']) for r in mr]),'bytes':sorted({float(r['bytes']) for r in mr}),'max_gc_seconds':max(float(r['gc_seconds']) for r in mr)}
    pairs=[]
    for triplet in sorted({r['triplet'] for r in rr},key=int):
        tr=sorted((r for r in rr if r['triplet']==triplet),key=lambda r:int(r['position']))
        assert len(tr)==3 and tr[0]['module']==tr[2]['module']!=tr[1]['module']
        outside=(float(tr[0]['seconds'])+float(tr[2]['seconds']))/2
        middle=float(tr[1]['seconds'])
        ratio=middle/outside if tr[0]['module']=='1' else outside/middle
        pairs.append(ratio)
    out['cases'][':'.join(key)]={'samples':len(rr),'modules':modules,'module2_vs_module1_median_ratio':modules['2']['seconds']['median']/modules['1']['seconds']['median'],'bracketed_ratio':stats(pairs),'numerical_fields_identical':all(identical.values()),'differing_fields':[k for k,v in identical.items() if not v]}
if len(sys.argv)>2:
    _,tr=records(sys.argv[2]);different=[]
    tkeys=sorted({tuple(r[k] for k in ('type','n','p','solver','step')) for r in tr})
    assert len(tkeys)==32, 'incomplete finite trajectory set'
    for key in tkeys:
        rr=[r for r in tr if tuple(r[k] for k in ('type','n','p','solver','step'))==key]
        assert len(rr)==2 and {r['module'] for r in rr}=={'1','2'}
        if rr[0]['diagnostics']!=rr[1]['diagnostics']:different.append(':'.join(key))
    out['trajectories']={'paired_steps':len(tkeys),'identical':not different,'differing_steps':different}
out['exact_numerical_match']=all(r['numerical_fields_identical'] for r in out['cases'].values()) and out.get('trajectories',{}).get('identical',True)
print(json.dumps(out,indent=2))
if not out['exact_numerical_match']:sys.exit(1)
