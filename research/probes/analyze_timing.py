#!/usr/bin/env python3
# Paired timing: per case, median over rounds of each label's per-process median; ratio X/M; A/A = M2/M.
import csv, sys, statistics as st, math, collections
rows = [r for r in csv.reader(open(sys.argv[1]), delimiter='\t')]
d = collections.defaultdict(lambda: collections.defaultdict(list)); meta = {}
for rnd, lab, ver, prob, T, start, order, med, mn, by, passes, conv in rows:
    k = (prob, T, start, order); d[k][lab].append(float(med)); meta[(k, lab)] = (int(by), int(passes), conv)
ORD = ['core-lasso', 'lasso-B', 'lasso-C', 'lasso-D', 'explore']
labs = ['M2', 'C50', 'CW10', 'CW20']
def ratios(sel, lab):
    out = []
    for k in sel:
        m = st.median(d[k]['M']); x = st.median(d[k][lab]); out.append((x / m, k))
    return out
def gm(v): return math.exp(sum(math.log(x) for x in v) / len(v))
groups = {'ordinary (5 designs, 60 cases)': [k for k in d if any(k[0].startswith(o) for o in ORD)],
          'stress (2 designs, 24 cases)': [k for k in d if k[0].startswith('stress')]}
print(f"{'group':32} {'label':5} {'geomean':>8} {'min':>7} {'max':>7} {'|r-1|>5%':>9}  worst case")
for g, sel in groups.items():
    for lab in labs:
        rs = ratios(sel, lab); v = [r for r, _ in rs]
        worst = max(rs, key=lambda t: abs(t[0] - 1))
        print(f"{g:32} {lab:5} {gm(v):8.4f} {min(v):7.3f} {max(v):7.3f} {sum(abs(x-1)>0.05 for x in v):9d}  {worst[0]:.3f} {'/'.join(worst[1])}")
# bytes and passes identity vs master
for lab in ['C50', 'CW10', 'CW20']:
    db = sum(meta[(k, lab)][0] != meta[(k, 'M')][0] for k in d); dp = sum(meta[(k, lab)][1] != meta[(k, 'M')][1] for k in d)
    nc = sum(meta[(k, lab)][2] != 'true' for k in d)
    print(f"{lab}: cases with different bytes {db}, different passes {dp}, not converged {nc}; master not converged {sum(meta[(k,'M')][2] != 'true' for k in d)}")
# per-round spread of A/A on ordinary
print("ordinary cases with changed passes per label:", {lab: [ '/'.join(k) for k in groups['ordinary (5 designs, 60 cases)'] if meta[(k, lab)][1] != meta[(k, 'M')][1]] for lab in ['C50','CW10','CW20']})
