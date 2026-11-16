#!/usr/bin/env python3
"""#307: summarize latency_driver CSVs. usage: analyze_latency.py DIR... (each DIR holds latency-<arm>.csv)
Prints, per Julia version and arm: precompile (PB, PS seconds; cache MB), load seconds, and for each
(solver, T, loss, position) the median [min-max] over processes of the first-call wall time and its
compile time, and of the repeated call; plus the six-solve raw-LS sum (position = first solve and
second solve separately)."""
import csv, statistics as st, sys
from collections import defaultdict
from pathlib import Path

def med(xs):
    return st.median(xs) if xs else float("nan")

def rng(xs):
    return f"{med(xs):8.3f} [{min(xs):7.3f}-{max(xs):7.3f}]" if xs else "-"

for d in sys.argv[1:]:
    for f in sorted(Path(d).glob("latency-*.csv")):
        pre, load, first = [], [], defaultdict(list)
        ver = arm = None
        for row in csv.reader(open(f)):
            if not row or row[0] != "CSV":
                continue
            if row[1] == "meta" and row[2] in ("arm", "version"):
                if row[2] == "arm": arm = row[3]
                else: ver = row[3]
            elif row[1] == "precompile":
                pre.append((float(row[5]), float(row[6]), int(row[7]) / 1e6, int(row[8]) / 1e6))
            elif row[1] == "load":
                load.append(float(row[5]))
            elif row[1] == "first":
                _, _, a, v, s, T, order, rep, tl, cl, tf, cf = row[:12]
                rest = row[12:]
                for pos in (0, 1):
                    kind, t1, k1, t2, k2, mn, eq = rest[7 * pos: 7 * pos + 7]
                    first[(s, T, kind, pos)].append((int(t1) / 1e9, int(k1) / 1e9, int(t2) / 1e9, int(k2) / 1e9, rep, eq))
        print(f"\n=== {d}  julia {ver}  arm {arm}")
        if pre:
            print("precompile PB s %s | PS s %s | cache PB MB %.2f PS MB %.2f" % (
                rng([p[0] for p in pre]), rng([p[1] for p in pre]), pre[-1][2], pre[-1][3]))
        print("load s", rng(load))
        print("solver T       loss   pos  n   first wall s [min-max]          first compile s          repeat wall ms")
        for key in sorted(first):
            v = first[key]
            print(f"{key[0]:4} {key[1]:8} {key[2]:6} {key[3]}  {len(v):2}  {rng([x[0] for x in v])}  {rng([x[1] for x in v])}  {med([x[2] for x in v])*1e3:8.3f}"
                  + ("" if all(x[5] == "true" for x in v) else "  repeat!=first"))
        for kind in ("raw", "scaled"):
            for pos in (0, 1):
                tot = [sum(first[(s, T, kind, pos)][i][0] for s in ("cd", "pg", "apg") for T in ("Float32", "Float64"))
                       for i in range(min(len(first[(s, T, kind, pos)]) for s in ("cd", "pg", "apg") for T in ("Float32", "Float64")))]
                print(f"six-solve {kind} pos{pos} sum s (paired by process index): {rng(tot)}")
