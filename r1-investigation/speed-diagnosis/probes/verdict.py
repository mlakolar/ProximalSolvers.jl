#!/usr/bin/env python3
"""verdict.py FILE CTRL TEST : per-file summary: cells, max/min median ratio of TEST sides, A/A envelope (CTRL sides), cells where a TEST side exceeds 1.05 or exceeds max(A/A,1)+0.02; lists those cells."""
import csv, sys, statistics as st
from collections import defaultdict
path=sys.argv[1]; ctrl=sys.argv[2].split(','); test=sys.argv[3].split(',')
rows=list(csv.DictReader(open(path),delimiter='\t'))
keyf=[k for k in rows[0].keys() if k not in("round","side","ns","passes","converged","objective","load1")]
d=defaultdict(lambda: defaultdict(dict))
for r in rows: d[tuple(r[c] for c in keyf)][r["round"]][r["side"]]=float(r["ns"])
allm={s:[] for s in ctrl+test}; bad=[]; cells=0; geo={s:[] for s in ctrl+test}
for k,rounds in d.items():
    cells+=1
    med={s: st.median(v[s]/v["base0"] for v in rounds.values()) for s in ctrl+test}
    for s in med: allm[s].append(med[s])
    aa=max(abs(med[s]-1) for s in ctrl); tt=max(med[s] for s in test)
    if tt>1.05 or tt-1>aa+0.02: bad.append((k,tt,aa))
import math
print(f"{path.split('/')[-1]}: cells={cells}")
for s in ctrl+test: print(f"  {s:12s} median-ratio range [{min(allm[s]):.3f}, {max(allm[s]):.3f}] geo-mean {math.exp(sum(math.log(x) for x in allm[s])/len(allm[s])):.4f}")
print("  cells with TEST max > 1.05 or > 1+max(A/A dev)+0.02:", len(bad))
for k,tt,aa in bad: print("   ", "|".join(k[1:]), f"test={tt:.3f} A/A_dev={aa:.3f}")
