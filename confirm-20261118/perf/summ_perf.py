"""Per cell: median over repetitions of the paired ratio t(v)/t(old), for each process. Usage: python3 -I summ_perf.py perf_1.tsv perf_2.tsv"""
import csv, sys, statistics as st
from collections import defaultdict
res = {}
for f in sys.argv[1:]:
    t = defaultdict(dict)
    for r in csv.DictReader(open(f), delimiter="\t"):
        t[(r["problem"], r["T"], r["cfg"], r["rep"])][r["variant"]] = float(r["seconds_per_solve"])
    cell = defaultdict(lambda: defaultdict(list))
    for (p, T, c, rep), d in t.items():
        for v in ("ctl", "new", "newb"):
            cell[(p, T, c)][v].append(d[v] / d["old"])
    res[f] = {k: {v: st.median(x) for v, x in d.items()} for k, d in cell.items()}
flag = 0
print(f"{'cell':40s} " + "  ".join(f"{f.split('/')[-1]}: ctl  new  newb" for f in sys.argv[1:]))
for k in sorted(next(iter(res.values()))):
    vals = [res[f][k] for f in sys.argv[1:]]
    bad = all(v["new"] > 1.05 and v["newb"] > 1.05 for v in vals)
    flag += bad
    print(f"{' '.join(k):40s} " + "  ".join(f"{v['ctl']:.3f} {v['new']:.3f} {v['newb']:.3f}" for v in vals) + ("  FLAG" if bad else ""))
allv = [res[f][k][v] for f in res for k in res[f] for v in ("new", "newb")]
ctl = [res[f][k]["ctl"] for f in res for k in res[f]]
print(f"prototype ratios: min {min(allv):.3f} max {max(allv):.3f}; A/A: min {min(ctl):.3f} max {max(ctl):.3f}; flagged cells {flag}")
