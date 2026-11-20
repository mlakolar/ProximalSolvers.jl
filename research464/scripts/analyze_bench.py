#!/usr/bin/env python3
"""Paired timing summary of bench.tsv: per workload, the ratio new/base within each pair k (median time per process),
its median and range over the six pairs, and whether iterations, counters and the coefficient hash agree."""
import csv, sys, statistics as st
from collections import defaultdict
cols = ['label','slot','work','med','min','alloc','conv','iter','fcalls','gcalls','pcalls','F','kkt','hash']
rows = [dict(zip(cols, r)) for r in csv.reader(open(sys.argv[1]), delimiter='\t')]
d = defaultdict(dict)
for r in rows: d[(r['label'], r['work'])][r['slot']] = r
works = list(dict.fromkeys(r['work'] for r in rows))
print('| workload | A/A base2/base median [min, max] | v1/base median [min, max] | v3/base median [min, max] | base: conv/iter/KKT | v1 | v3 | allocs base/v1/v3 |')
print('|---|---|---|---|---|---|---|---|')
def ratio(new, base, w):
    rs = [float(d[(new, w)][k]['med']) / float(d[(base, w)][k]['med']) for k in map(str, range(1, 7))]
    return f"{st.median(rs):.3f} [{min(rs):.3f}, {max(rs):.3f}]"
for w in works:
    b, p, v = d[('AB-base', w)]['1'], d[('AB-proto', w)]['1'], d[('AB3-v3', w)]['1']
    # consistency across all slots of each label
    for lab in ('AB-base', 'AB-proto', 'AB3-v3', 'AB3-base', 'AA-base', 'AA-base2'):
        hs = {(x['iter'], x['hash']) for x in d[(lab, w)].values()}
        assert len(hs) == 1, (lab, w, hs)
    f = lambda x: f"{x['conv'][0]}/{x['iter']}/{float(x['kkt']):.1e}" + ('' if x['hash'] != b['hash'] or x is b else '=')
    print(f"| {w} | {ratio('AA-base2','AA-base',w)} | {ratio('AB-proto','AB-base',w)} | {ratio('AB3-v3','AB3-base',w)} | "
          f"{b['conv'][0]}/{b['iter']}/{float(b['kkt']):.1e} | {f(p)} | {f(v)} | {b['alloc']}/{p['alloc']}/{v['alloc']} |")
