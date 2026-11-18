#!/usr/bin/env python3
"""compact per-cell medians: usage compact.py file.tsv [ctrl sides comma] [test sides comma]; prints median ratio per side, A/A envelope, verdict"""
import csv, sys, statistics as st
from collections import defaultdict
path=sys.argv[1]; ctrl=sys.argv[2].split(',') ; test=sys.argv[3].split(',')
rows=list(csv.DictReader(open(path),delimiter='\t'))
keyf=[k for k in rows[0].keys() if k not in("round","side","ns","passes","converged","objective","load1")]
d=defaultdict(lambda: defaultdict(dict))
for r in rows: d[tuple(r[c] for c in keyf)][r["round"]][r["side"]]=float(r["ns"])
print("\t".join(keyf[1:]+["base_us"]+ctrl+test+["AA_maxdev","test_maxdev","verdict"]))
worst=0
for k,rounds in d.items():
    med={s: st.median(v[s]/v["base0"] for v in rounds.values()) for s in ctrl+test}
    base=st.median(v["base0"] for v in rounds.values())/1e3
    aa=max(abs(med[s]-1) for s in ctrl); tt=max(med[s]-1 for s in test)
    verdict="ok" if tt<=max(aa,0.0)+0.01 or tt<0.02 else "CHECK"
    print("\t".join(list(k[1:])+[f"{base:.2f}"]+[f"{med[s]:.3f}" for s in ctrl+test]+[f"{aa:.3f}",f"{tt:+.3f}",verdict]))
