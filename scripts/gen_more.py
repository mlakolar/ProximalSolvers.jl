import csv,glob,statistics as st,collections,sys
from simvar import *
E_='<local>/ps-320/.codex-orchestrator/runs/run-20261118T0124-issue320-31d8/evidence/'
out=[]
def P(s=''): out.append(s)
# --- variants table (master), harness and adverse, both jv
sel_names=['H (harness settings)','H, increase <= 4 ulp(F) is noise','H, gate floor 16 eps','H, gate floor 8 eps','H, floor 8 eps + increase<=4 ulp',
  'C1: H, increase<=4 ulp noise + computable gap <= 1e-5 (T)','C1b: same with gap <= 5e-6 (T)','C1c: same, idealized independent gap <= 1e-5',
  'S strict stress','Q (ftol 0, gradtol target/100)']
P('**Simulated stopping-rule variants on the recorded Float32 PGD trajectories (master dac9f4b)**: cells are `converged=true` / missed / false success / truthful miss (n = 50 harness, 70 adverse)')
P()
P('| variant | harness 1.10.13 | harness 1.13.3 | adverse 1.10.13 | adverse 1.13.3 |'); P('|---|---|---|---|---|')
res={}
for setname,tags in [('harness',['mxd1-2640','mxd2-2640']),('adverse',['advd-2640'])]:
    for jv in ['1.10.13','1.13.3']:
        res[(setname,jv)]={r[0]:r for r in run(tags,'dac9f4b',jv,'Float32')}
runson=0
for name in sel_names:
    cells=[]
    for setname in ['harness','adverse']:
        for jv in ['1.10.13','1.13.3']:
            r=res[(setname,jv)][name]; cells.append(f"{r[2]} / {r[3]} / {r[4]} / {r[5]}"); runson+=r[6]
    P(f'| {name} | '+' | '.join(cells)+' |')
P()
P(f'(Trajectories ended before a stop for {runson} of the simulated variant evaluations above; the others stopped within the recorded trajectory.)')
P()
open(E_+'variants-table.md','w').write('\n'.join(out))
# --- timing table
rows={}
for jv in ['1.10.13','1.13.3']:
    rows[jv]=list(csv.DictReader(open(E_+f'time-4116/dac9f4b-{jv}/run-timing.tsv'),delimiter='\t'))
T=[]
def Q(s=''): T.append(s)
Q('**Return time and time to target, Float32 PGD, master (dac9f4b), Intel Xeon Silver 4116 (exclusive node), 1 Julia thread, 1 BLAS thread, minimum over 11 rounds of rotating arms, 5 draws of each of 4 harness designs per Julia version**')
Q()
Q('Median over the 20 problems of each Julia version of the per-problem ratio (arm minimum time) / (H minimum time); range in brackets. `TTT` = time to target: the solve stopped at k*, the first iterate whose independent gap meets 1e-5.')
Q()
Q('| arm | 1.10.13 | 1.13.3 |'); Q('|---|---|---|')
def ratios(jv,arm):
    keyed=collections.defaultdict(dict)
    for r in rows[jv]: keyed[(r['design'],r['draw'])][r['arm']]=float(r['min_ns'])
    rs=[v[arm]/v['H'] for v in keyed.values() if arm in v]
    return f"{st.median(rs):.3f} [{min(rs):.3f}, {max(rs):.3f}]"
for arm,desc in [('Haa','H again (A/A control)'),('D','D library defaults'),('TTT','time to target'),('Q','Q (ftol 0, gradtol 1e-7)'),('S','S strict stress'),('A','A (#314 candidate)')]:
    Q(f'| {arm}: {desc} | {ratios("1.10.13",arm)} | {ratios("1.13.3",arm)} |')
Q()
Q('Median minimum return time of H in microseconds, by design (the A/A copy agrees to 0.2%):')
Q()
Q('| design | 1.10.13 H | 1.10.13 TTT | 1.10.13 S | 1.13.3 H | 1.13.3 TTT | 1.13.3 S |'); Q('|---|---|---|---|---|---|---|')
for d in ['lasso','lasso-B','lasso-C','lasso-D']:
    cells=[]
    for jv in ['1.10.13','1.13.3']:
        for arm in ['H','TTT','S']:
            v=[float(r['min_ns']) for r in rows[jv] if r['design']==d and r['arm']==arm]; cells.append(f'{st.median(v)/1e3:.1f}')
    Q(f'| {d} | '+' | '.join(cells)+' |')
Q()
Q('Warmed allocation per `solve!` (bytes, `Base.gc_bytes` difference of a repeated call) does not depend on the option profile: ')
for jv in ['1.10.13','1.13.3']:
    by=collections.defaultdict(dict)
    for r in rows[jv]: by[(r['design'],r['draw'])][r['arm']]=int(r['alloc_bytes'])
    same=sum(len(set(v.values()))==1 for v in by.values())
    mm=[ (k,v) for k,v in by.items() if len(set(v.values()))>1]
    allv=[x for v in by.values() for x in v.values()]
    Q(f'- Julia {jv}: {same} of {len(by)} problems allocate the same number of bytes in every arm; range over all runs {min(allv)} to {max(allv)} bytes; exceptions: '+('none' if not mm else '; '.join(f"{k[0]} draw {k[1]} {v}" for k,v in mm)))
Q()
open(E_+'timing-table.md','w').write('\n'.join(T))
print('\n'.join(out)); print('\n'.join(T))
