#!/usr/bin/env python3
"""#314 pre/post-#296 comparison (disposable). Reads the probe TSVs of both runs.
usage: compare314.py <pre run dir> <post run dir>"""
import csv, math, statistics, sys
from collections import Counter, defaultdict
pre, post = sys.argv[1:3]
def rows(d, part):
    out = []
    for v in ("j110", "j113"):
        p = f"{d}/cluster/out-{v}-{part}"
        with open(p) as fh: out += [r for r in csv.DictReader(fh, delimiter="\t") if r["profile"] != "Haa"]
    return out
def gm(xs):
    xs = [x for x in xs if x > 0]; return math.exp(sum(map(math.log, xs)) / len(xs)) if xs else float("nan")
fs = lambda r: r["converged"] == "true" and r["pass"] != "true"
ok = lambda r: r["pass"] == "true"
T = lambda r: r["T"].replace("Float", "F")
for label, part in (("Phase A, 20 harness cases x 10 draws x 2 versions", "formal/probe-harness.tsv"),
                    ("Phase B confirmation set (conf), 180 problems x 2 versions per row", "probe-conf/probe-conf.tsv")):
    R = {"pre": rows(pre, part), "post": rows(post, part)}
    key = lambda r: (r["julia"], r["id"], r["draw"], r["profile"])
    idx = {k: {key(r): r for r in R[k]} for k in R}
    print(f"### {label}\n")
    print("| solver | T | profile | pass pre → post | false success pre → post | converged pre → post | stagnated pre → post | maxiter pre → post | iters med pre → post | products med pre → post | return time post/pre (gm) | k* changed |")
    print("|---|---|---|---|---|---|---|---|---|---|---:|---:|")
    for s in ("pg", "apg"):
        for t in ("F64", "F32"):
            for p in ("D", "H", "S", "P1", "P2"):
                a = [r for r in R["pre"] if r["solver"] == s and T(r) == t and r["profile"] == p]
                b = [r for r in R["post"] if r["solver"] == s and T(r) == t and r["profile"] == p]
                if not a: continue
                c = lambda rr, f: sum(map(f, rr))
                term = lambda rr, x: sum(r["termination"] == x for r in rr)
                conv = lambda rr: sum(r["converged"] == "true" for r in rr)
                med = lambda rr, f: statistics.median(int(r[f]) for r in rr)
                rat = gm([int(idx["post"][key(r)]["time_med_ns"]) / int(r["time_med_ns"]) for r in a if key(r) in idx["post"]])
                kch = sum(idx["post"][key(r)]["kstar"] != r["kstar"] for r in a if key(r) in idx["post"])
                print(f"| {s} | {t} | {p} | {c(a, ok)} → {c(b, ok)} / {len(b)} | {c(a, fs)} → {c(b, fs)} | {conv(a)} → {conv(b)} | "
                      f"{term(a, 'stagnated')} → {term(b, 'stagnated')} | {term(a, 'maxiter')} → {term(b, 'maxiter')} | "
                      f"{med(a, 'iterations'):.0f} → {med(b, 'iterations'):.0f} | {med(a, 'products'):.0f} → {med(b, 'products'):.0f} | {rat:.2f} | {kch} |")
    print()
    # data/trajectory identity: data hashes should match; k* (trajectory) may change only via stopping (it should not)
    dh = sum(idx["post"][k]["data_hash"] != r["data_hash"] for k, r in idx["pre"].items() if k in idx["post"])
    print(f"Problems matched pre/post: {len(set(idx['pre']) & set(idx['post']))} of {len(idx['pre'])}; data-hash differences: {dh}.\n")
