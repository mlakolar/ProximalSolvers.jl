import csv,glob,os,sys,collections,statistics as st,math
E='<local>/ps-320/.codex-orchestrator/runs/run-20261118T0124-issue320-31d8/evidence/'
REVS=['637f06a','9f86a80','dac9f4b']
def fl(x):
    try: return float(x)
    except: return float('nan')
def load(sets=('mx1-2640','mx2-2640','adv-2640')):
    rows=[]
    for s in sets:
        for f in sorted(glob.glob(E+s+'/*/run-summary.tsv')):
            d=os.path.basename(os.path.dirname(f)); rev,jv=d.split('-',1)
            for r in csv.DictReader(open(f),delimiter='\t'):
                r['rev']=rev; r['jv']=jv; r['set']=s; rows.append(r)
    return rows
def isb(x): return x=='true'
def prep(r):
    r['gapf']=fl(r['gap']); r['tgt']=fl(r['target'])
    r['missed_b']= r['gapf']>r['tgt']
    r['conv']=isb(r['converged'])
    r['fs']= r['conv'] and r['missed_b']
    it=lambda k: int(r[k]) if r[k] not in ('','NaN') else 0
    r['it']=it('iterations')
    r['products']= (1+it('grad_calls')+it('prox_calls')+it('verifications')) if r['solver']=='pgd' and r['grad_calls']!='' else (1+it('grad_calls')+it('prox_calls')+it('fallbacks') if r['grad_calls']!='' else None)
    return r
def counts(rows):
    n=len(rows); c=sum(r['conv'] for r in rows); m=sum(r['missed_b'] for r in rows); fs=sum(r['fs'] for r in rows)
    return n,c,m,fs
