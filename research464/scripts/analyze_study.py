#!/usr/bin/env python3
"""Summarize study464.tsv: per rule, material false stops and lost stops; per case group, a compact table."""
import csv, sys
from collections import defaultdict, OrderedDict

rows = list(csv.DictReader(open(sys.argv[1]), delimiter='\t'))
MAT = 1e-3     # a converged stop with a relative objective excess above this is "materially wrong"
# working-precision accuracy target for "a good stop": Float64 1e-8, Float32 1e-5 (the #352 targets)
def good(r):
    return float(r['relgap']) <= (1e-8 if r['T'] == 'Float64' else 1e-5)

groups = OrderedDict()
for r in rows:
    groups.setdefault((r['case'], r['loss'], r['T'], r['method'], r['start']), {})[r['rule']] = r

rules = ['v0', 'v1', 'v2', 'v3', 'gv1']
tot = defaultdict(lambda: defaultdict(int))
for k, g in groups.items():
    for rule, r in g.items():
        conv = r['converged'] == 'true'
        gap = float(r['relgap'])
        t = tot[rule]
        t['solves'] += 1
        t['converged'] += conv
        t['false_material'] += conv and gap > MAT
        t['false_any'] += conv and not good(r)
        v0 = g['v0']
        # a lost stop: v0 stopped at a point that meets the accuracy target, this rule did not converge
        t['lost_good_stop'] += (v0['converged'] == 'true' and good(v0) and not conv)
        t['same_decision'] += r['decision_vs_v0'] == 'same'
        t['iters'] += int(r['iter'])

print('| rule | solves | converged | converged, excess > 1e-3 | converged, above target | v0 stopped on target, rule did not converge | decision = v0 | total iterations |')
print('|---|---|---|---|---|---|---|---|')
for rule in rules:
    if rule in tot:
        t = tot[rule]
        print(f"| {rule} | {t['solves']} | {t['converged']} | {t['false_material']} | {t['false_any']} | {t['lost_good_stop']} | {t['same_decision']} | {t['iters']} |")

print()
print('| case | T | solver | start | ' + ' | '.join(f'{r}: conv/iter/excess' for r in ['v0', 'v1', 'v2', 'v3']) + ' |')
print('|---|---|---|---|' + '---|' * 4)
for k, g in groups.items():
    cells = []
    for rule in (['v0', 'v1', 'v2', 'v3'] if 'v1' in g else ['v0', 'gv1']):
        r = g.get(rule)
        if r is None:
            cells.append('')
            continue
        flag = 'T' if r['converged'] == 'true' else ('F*' if r['stagnated'] == 'true' else ('F+' if r['f_increased'] == 'true' else 'F'))
        cells.append(f"{flag}/{r['iter']}/{float(r['relgap']):.1e}")
    while len(cells) < 4:
        cells.append('')
    print(f'| {k[0]} | {k[2][-2:]} | {k[3]} | {k[4]} | ' + ' | '.join(cells) + ' |')
