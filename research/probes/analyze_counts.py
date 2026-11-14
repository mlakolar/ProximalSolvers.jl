#!/usr/bin/env python3
# Summarize counts311.jl output: per schedule K, against master on the same run key.
import csv, sys, collections, math
rows = list(csv.DictReader(open(sys.argv[1]), delimiter='\t'))
key = lambda r: (r['problem'], r['T'], r['start'], r['order'], r['momentum'], r['seed'], r['tol'])
base = {key(r): r for r in rows if r['K'] == 'master'}
Ks = []
for r in rows:
    if r['K'] not in Ks: Ks.append(r['K'])
KTOL = {'Float32': max(1e-7, 100 * 1.1920929e-7), 'Float64': 1e-7}
def summarize(sel, label):
    print(f"\n### {label}")
    print(f"{'K':>7} {'runs':>5} {'conv':>5} {'kkt>bound':>9} {'kkt>10xM':>8} {'visits/M (sum)':>14} {'max run':>8} {'p95 run':>8} {'passes/M':>9} {'full/M':>7} {'changed':>7}")
    for K in Ks:
        rs = [r for r in sel if r['K'] == K]
        if not rs: continue
        conv = sum(r['converged'] == 'true' for r in rs)
        bad = sum(r['converged'] == 'true' and float(r['kkt']) > KTOL[r['T']] for r in rs)
        worse = sum(float(r['kkt']) > 10 * max(float(base[key(r)]['kkt']), 1e-9) and float(r['kkt']) > 1e-7 for r in rs)
        v = sum(int(r['visits']) for r in rs); vb = sum(int(base[key(r)]['visits']) for r in rs)
        ratios = sorted(int(r['visits']) / int(base[key(r)]['visits']) for r in rs)
        ps = sum(int(r['passes']) for r in rs) / sum(int(base[key(r)]['passes']) for r in rs)
        fs = sum(int(r['nfull']) for r in rs) / sum(int(base[key(r)]['nfull']) for r in rs)
        changed = sum(int(r['visits']) != int(base[key(r)]['visits']) for r in rs)
        print(f"{K:>7} {len(rs):>5} {conv:>5} {bad:>9} {worse:>8} {v/vb:>14.4f} {ratios[-1]:>8.3f} {ratios[int(0.95*(len(ratios)-1))]:>8.3f} {ps:>9.3f} {fs:>7.3f} {changed:>7}")
summarize(rows, "all runs")
for T in ('Float32', 'Float64'):
    summarize([r for r in rows if r['T'] == T], T)
for mom in ('false', 'nothing'):
    summarize([r for r in rows if r['momentum'] == mom and r['order'] == 'random'], f"random, momentum={mom}")
summarize([r for r in rows if r['order'] == 'cyclic'], "cyclic")
probs = []
for r in rows:
    if r['problem'] not in probs: probs.append(r['problem'])
for p in probs:
    summarize([r for r in rows if r['problem'] == p], p)
# worst individual runs for selected K
for K in Ks[1:]:
    rs = sorted((r for r in rows if r['K'] == K), key=lambda r: -int(r['visits']) / int(base[key(r)]['visits']))[:5]
    print(f"\nworst visit ratios for K={K}:")
    for r in rs:
        b = base[key(r)]
        print(f"  {'/'.join(key(r))}: visits {b['visits']}->{r['visits']} passes {b['passes']}->{r['passes']} full {b['nfull']}->{r['nfull']} conv {b['converged']}->{r['converged']} kkt {float(b['kkt']):.2e}->{float(r['kkt']):.2e}")
nonconv = [r for r in rows if r['converged'] != 'true']
print(f"\nnot converged: {len(nonconv)}")
for r in nonconv[:20]:
    print("  ", '/'.join(key(r)), r['K'], r['passes'], r['kkt'])
