"""Validate coverage and print paired runtime ratios (candidate / baseline)."""
import csv
import statistics as st
import sys
from collections import defaultdict
rows = list(csv.DictReader(open(sys.argv[1])))
groups = defaultdict(dict)
for row in rows:
    key = (row['case'], row['solver'], row['rep'])
    assert row['mode'] not in groups[key]
    groups[key][row['mode']] = row
assert len(rows) == 180, len(rows)
assert len(groups) == 60
for key, group in groups.items():
    assert set(group) == {'baseline', 'none', 'diagonal'}
    a, b = group['baseline'], group['none']
    for field in ('iterations', 'gap', 'objective', 'backtracks'):
        assert a[field] == b[field], (key, field)
    assert group['diagonal']['converged'] == 'true', key
    assert float(group['diagonal']['gap']) <= 1e-5
print('| Case | Solver | none / baseline median [Q1, Q3] | Diagonal / scalar median | Diagonal iterations | Scalar iterations | Scalar gap |')
print('|---|---|---:|---:|---:|---:|---:|')
for case in ('ls-well', 'ls-scaled', 'logistic-scaled'):
    for solver in ('pgd', 'apg'):
        gs = [g for (c, s, _), g in groups.items() if c == case and s == solver]
        assert len(gs) == 10
        ratios = [float(g['none']['seconds']) / float(g['baseline']['seconds']) for g in gs]
        q1, _, q3 = st.quantiles(ratios, n=4)
        diag = [float(g['diagonal']['seconds']) / float(g['none']['seconds']) for g in gs]
        g = gs[0]
        print(f"| {case} | {solver} | {st.median(ratios):.3f} [{q1:.3f}, {q3:.3f}] | {st.median(diag):.4f} | {g['diagonal']['iterations']} | {g['none']['iterations']} | {float(g['none']['gap']):.3g} |")
print('\nScaled scalar runs at the iteration cap are lower bounds on time to the requested gap, not equal-accuracy speedups.')
