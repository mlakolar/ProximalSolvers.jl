import csv,glob,os,collections,statistics as st,sys
E='<local>/ps-320/.codex-orchestrator/runs/run-20261118T0124-issue320-31d8/evidence/'
REVS=['637f06a','9f86a80','dac9f4b']; JVS=['1.10.13','1.13.3']
NAME={'637f06a':'637f06a + PB c123d56','9f86a80':'9f86a80 + PB 50db4b1','dac9f4b':'dac9f4b + PB a19c59a'}
def f(x):
    x=x.replace('f0','') if x.endswith('f0') else x
    try: return float(x)
    except: return float('nan')
def load(tags,cpu='2640'):
    rows=[]
    for tag in tags:
        for fn in sorted(glob.glob(E+f'{tag}/*/run-summary.tsv')):
            d=fn.split('/')[-2]; rev,jv=d.split('-',1)
            for r in csv.DictReader(open(fn),delimiter='\t'):
                r['rev']=rev; r['jv']=jv; r['set']=tag
                r['gapf']=f(r['gap']); r['tgt']=f(r['target'])
                r['miss']=r['gapf']>r['tgt']; r['conv']=r['converged']=='true'
                r['fs']=r['miss'] and r['conv']; r['nonconv_miss']=r['miss'] and not r['conv']
                r['it']=int(r['iterations']) if r['iterations'] else 0
                def iv(k): return int(r[k]) if r[k] not in ('','NaN') else 0
                r['prod']=(1+iv('grad_calls')+iv('prox_calls')+(iv('verifications') if r['solver']=='pgd' else iv('fallbacks')))
                rows.append(r)
    return rows
HARN=load(['mxd1-2640','mxd2-2640']); ADV=load(['advd-2640'])
def sel(rows,**kw):
    return [r for r in rows if all(r[k]==v for k,v in kw.items())]
def cnt(rs):
    return dict(n=len(rs),conv=sum(r['conv'] for r in rs),ok=sum(not r['miss'] for r in rs),miss=sum(r['miss'] for r in rs),fs=sum(r['fs'] for r in rs),nc=sum(r['nonconv_miss'] for r in rs))
out=[]
def P(s=''): out.append(s)
# ---- T2/T3: counts per arm
def table(rows,title,T,solver,profs):
    P(f'**{title}** ({T} {solver.upper()}; cells are `converged=true` / target missed / false success = `converged=true` and missed, out of n)')
    P()
    hdr='| profile | '+' | '.join(f'{NAME[r]}, {jv}' for jv in JVS for r in REVS)+' |'
    P(hdr); P('|---|'+'---|'*(len(REVS)*len(JVS)))
    for p in profs:
        cells=[]
        for jv in JVS:
            for r in REVS:
                c=cnt(sel(rows,rev=r,jv=jv,T=T,solver=solver,profile=p))
                cells.append(f"{c['conv']} / {c['miss']} / {c['fs']} (n={c['n']})")
        P(f'| {p} | '+' | '.join(cells)+' |')
    P()
PR=['H','D','S','A','Q']
table(HARN,'Harness designs, 5 designs x 10 draws','Float32','pgd',PR)
table(ADV,'Adverse set, 7 designs x 10 draws','Float32','pgd',PR)
table(HARN,'Harness designs','Float64','pgd',PR)
table(ADV,'Adverse set','Float64','pgd',PR)
table(HARN,'Harness designs','Float32','apg',PR)
table(ADV,'Adverse set','Float32','apg',PR)
# ---- per design breakdown H and Q (dac9f4b)
P('**Per design, Float32 PGD, harness settings H, master (dac9f4b): `converged=true` / missed / false success (n=10 per cell)**')
P()
des=[]
for r in HARN+ADV:
    if r['design'] not in des: des.append(r['design'])
P('| design | '+' | '.join(JVS)+' |'); P('|---|---|---|')
for d in des:
    cells=[]
    for jv in JVS:
        rs=sel(HARN+ADV,rev='dac9f4b',jv=jv,T='Float32',solver='pgd',profile='H',design=d); c=cnt(rs)
        cells.append(f"{c['conv']} / {c['miss']} / {c['fs']}")
    P(f'| {d} | '+' | '.join(cells)+' |')
P()
# ---- mechanism classes, H, F32 PGD
def klass(r):
    if not r['miss']: return None
    if r['conv']:
        return 'false convergence: objective test proposed (%s), stationarity check accepted%s' % ({'u':'one-ulp','fu':'relative+one-ulp','f':'relative'}.get(r['first_prop_set'],r['first_prop_set']), '' if r['n_gate_reject']=='0' else ' after earlier refusals')
    if r['termination']=='f_increased':
        return 'truthful stop on a rounding-level objective increase, stationarity check had refused %s proposal(s)' % ('1 or more' if int(r['n_gate_reject'] or 0)>0 else 'no (none made)')
    return 'truthful stop: '+r['termination']
for name,rows in [('Harness designs',HARN),('Adverse set',ADV)]:
    P(f'**Mechanism of the missed records, Float32 PGD, harness settings H ({name})**')
    P()
    P('| class | '+' | '.join(f'{NAME[r]}, {jv}' for jv in JVS for r in REVS)+' |'); P('|---|'+'---|'*6)
    keys=collections.OrderedDict()
    cc={}
    for jv in JVS:
        for r in REVS:
            rs=[x for x in sel(rows,rev=r,jv=jv,T='Float32',solver='pgd',profile='H') if x['miss']]
            cc[(r,jv)]=collections.Counter(klass(x) for x in rs)
            for k in cc[(r,jv)]: keys.setdefault(k,0)
            cc[(r,jv)]['_miss']=len(rs)
    for k in sorted(keys):
        P(f'| {k} | '+' | '.join(str(cc[(r,jv)][k]) for jv in JVS for r in REVS)+' |')
    P('| **total missed** | '+' | '.join(str(cc[(r,jv)]['_miss']) for jv in JVS for r in REVS)+' |')
    P()
# gate-vs-independent
P('**Stationarity check versus the independent KKT residual (Float32 PGD, H)**: among `converged=true` records, the independent normalized KKT residual (Float64, rounded data) relative to the check threshold `64 eps(Float32) = 7.63e-06`')
P()
P('| set | converged=true | independent KKT_rel >= 7.63e-06 | max independent KKT_rel | max gap among converged=true |'); P('|---|---|---|---|---|')
for name,rows in [('harness',HARN),('adverse',ADV)]:
    rs=[r for r in rows if r['T']=='Float32' and r['solver']=='pgd' and r['profile']=='H' and r['conv']]
    P(f"| {name} | {len(rs)} | {sum(f(r['kkt_rel'])>=64*2**-23 for r in rs)} | {max(f(r['kkt_rel']) for r in rs):.3e} | {max(r['gapf'] for r in rs):.3e} |")
P()
# ---- gap and KKT ratio among FS
fs=[r for r in HARN if r['T']=='Float32' and r['solver']=='pgd' and r['profile']=='H' and r['fs']]
P(f"Among the {len(fs)} false successes on the harness designs (H, Float32 PGD, all arms and versions): gap {min(r['gapf'] for r in fs):.2e} to {max(r['gapf'] for r in fs):.2e} (median {st.median(r['gapf'] for r in fs):.2e}); gap / KKT_rel {min(r['gapf']/f(r['kkt_rel']) for r in fs):.1f} to {max(r['gapf']/f(r['kkt_rel']) for r in fs):.1f} (median {st.median(r['gapf']/f(r['kkt_rel']) for r in fs):.1f}).")
fa=[r for r in ADV if r['T']=='Float32' and r['solver']=='pgd' and r['profile']=='H' and r['fs']]
P(f"Among the {len(fa)} false successes on the adverse set: gap {min(r['gapf'] for r in fa):.2e} to {max(r['gapf'] for r in fa):.2e}; gap / KKT_rel {min(r['gapf']/f(r['kkt_rel']) for r in fa):.1f} to {max(r['gapf']/f(r['kkt_rel']) for r in fa):.1f} (median {st.median(r['gapf']/f(r['kkt_rel']) for r in fa):.1f}).")
mm=[r for r in HARN+ADV if r['T']=='Float32' and r['solver']=='pgd' and r['profile']=='H' and r['nonconv_miss']]
P(f"Gap at the return of the {len(mm)} truthful misses (H, Float32 PGD, harness+adverse): median {st.median(r['gapf'] for r in mm):.2e}, maximum {max(r['gapf'] for r in mm):.2e}.")
P()
# ---- work / accuracy per profile (dac9f4b)
P('**Accuracy versus work by option profile, Float32 PGD, master (dac9f4b)**: `n`, `converged=true`, missed, false success, truthful misses, median iterations, median products (1 + gradient + prox evaluations + curvature verifications), median iterations after the first iterate that meets the target (k*; negative = the solve returned before it)')
P()
P('| set | Julia | profile | n | converged | missed | false success | truthful miss | iterations med | products med | it after k* med | terminations |'); P('|---|---|---|---|---|---|---|---|---|---|---|---|')
for name,rows in [('harness',HARN),('adverse',ADV)]:
    for jv in JVS:
        for p in ['D','H','S','A','Q']:
            rs=sel(rows,rev='dac9f4b',jv=jv,T='Float32',solver='pgd',profile=p); c=cnt(rs)
            aft=[int(r['iters_after_kstar']) for r in rs if r['iters_after_kstar'] not in ('','-1')]
            terms=collections.Counter(r['termination'] for r in rs)
            P(f"| {name} | {jv} | {p} | {c['n']} | {c['conv']} | {c['miss']} | {c['fs']} | {c['nc']} | {st.median(r['it'] for r in rs):g} | {st.median(r['prod'] for r in rs):g} | {st.median(aft) if aft else '-'} | {', '.join(f'{k} {v}' for k,v in sorted(terms.items()))} |")
P()
open(E+'tables.md','w').write('\n'.join(out))
print('\n'.join(out))
