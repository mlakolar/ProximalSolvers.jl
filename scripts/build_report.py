import csv,glob,collections,statistics as st,re
E='<local>/ps-320/.codex-orchestrator/runs/run-20261118T0124-issue320-31d8/evidence/'
RUN='<local>/ps-320/.codex-orchestrator/runs/run-20261118T0124-issue320-31d8/'
exec(open('<local>/ps-320/.codex-orchestrator/probes/make_tables.py').read().split("out=[]")[0])
tables=open(E+'tables.md').read()
variants=open(E+'variants-table.md').read()
timing=open(E+'timing-table.md').read()
# --- repro table
def repro_table():
    L=['| PS revision (PB) | Julia | case | `converged` | stop | iterations | first proposal | k* | gap at return | KKT_rel at return | status |','|---|---|---|---|---|---|---|---|---|---|---|']
    for r in ['637f06a','9f86a80','dac9f4b']:
        for jv in JVS:
            for a in csv.DictReader(open(f'{E}repro-2640/{r}-{jv}/run-summary.tsv'),delimiter='\t'):
                if a['T']!='Float32' or a['solver']!='pgd' or a['profile']!='H': continue
                pred={'u':'one-ulp objective','f':'rel. objective','fu':'rel.+ulp objective'}.get(a['first_prop_set'],a['first_prop_set'])
                fp='none' if a['first_prop_iter']=='0' else f"it {a['first_prop_iter']}, {pred}, check {'accepted' if a['first_prop_gate']=='true' else 'refused'}; {a['n_prop']} proposal(s), {a['n_gate_reject']} refused"
                L.append(f"| {NAME[r]} | {jv} | {a['design']} draw {a['draw']} | {a['converged']} | {a['termination']} | {a['iterations']} | {fp} | {a['kstar']} | {float(a['gap']):.3e} | {float(a['kkt_rel']):.2e} | {a['status']} |")
    return '\n'.join(L)
# --- raw per-draw table
def raw_table(rows,designs,revs,title):
    L=[f'**{title}**','','| design | draw | '+' | '.join(f'{NAME[r]}, {jv}: conv / stop / iter / gap / k*' for jv in JVS for r in revs)+' |','|---|---|'+'---|'*(len(JVS)*len(revs))]
    for d in designs:
        for k in range(1,11):
            cells=[]
            for jv in JVS:
                for r in revs:
                    x=[q for q in rows if q['rev']==r and q['jv']==jv and q['T']=='Float32' and q['solver']=='pgd' and q['profile']=='H' and q['design']==d and q['draw']==str(k)]
                    x=x[0]; cells.append(f"{'T' if x['conv'] else 'F'} / {x['termination']} / {x['it']} / {x['gapf']:.2e} / {x['kstar']}")
            L.append(f'| {d} | {k} | '+' | '.join(cells)+' |')
    return '\n'.join(L)
hd=['lasso','lasso-B','lasso-B-warm','lasso-C','lasso-D']
ad=['adv-cor-low-cold','adv-cor-low-warm','adv-equi-low-cold','adv-ill-mid-cold','adv-ill-low-cold','adv-ill-low-warm','adv-wide-low-cold']
raw1=raw_table(HARN,hd,['637f06a','dac9f4b'],'Harness designs, Float32 PGD, harness settings H: T/F = `converged`')
raw2=raw_table(ADV,ad,['dac9f4b'],'Adverse set, Float32 PGD, harness settings H, master only')
# --- sums for the summary
def c(rows,rev,jv,T='Float32',solver='pgd',prof='H'): return cnt(sel(rows,rev=rev,jv=jv,T=T,solver=solver,profile=prof))
H_=lambda rev,jv: c(HARN,rev,jv)
A_=lambda rev,jv: c(ADV,rev,jv)
s={}
for rev in REVS:
    for jv in JVS:
        s[('h',rev,jv)]=H_(rev,jv); s[('a',rev,jv)]=A_(rev,jv)
def okmiss(x): return f"{x['ok']} ok / {x['miss']} missed ({x['fs']} with `converged=true`)"
md=open(RUN+'report-template.md').read()
md=md.replace('{{REPRO}}',repro_table()).replace('{{TABLES}}',tables).replace('{{VARIANTS}}',variants).replace('{{TIMING}}',timing).replace('{{RAW1}}',raw1).replace('{{RAW2}}',raw2)
for key,val in {
 'H1':okmiss(s[('h','637f06a','1.10.13')]),'H2':okmiss(s[('h','9f86a80','1.10.13')]),'H3':okmiss(s[('h','dac9f4b','1.10.13')]),
 'H4':okmiss(s[('h','637f06a','1.13.3')]),'H5':okmiss(s[('h','9f86a80','1.13.3')]),'H6':okmiss(s[('h','dac9f4b','1.13.3')]),
}.items(): md=md.replace('{{'+key+'}}',val)
open(RUN+'report-draft.md','w').write(md)
print(len(md),'chars')
