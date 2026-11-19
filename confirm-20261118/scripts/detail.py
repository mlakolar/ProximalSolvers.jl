"""Detail tables: excess before/after, M1 vs M1g identity, via/stages at exhaustion. Usage: python3 -I detail.py <glob>"""
import csv, glob, sys, math
from collections import defaultdict, Counter
rows = []
for f in sorted(glob.glob(sys.argv[1])):
    rows += list(csv.DictReader(open(f), delimiter="\t"))
key = lambda r: (r["id"], r["T"], r["config"], r["start"])
trig = {key(r) for r in rows if r["method"] == "M0" and r["triggered"] == "true"}
by = defaultdict(dict)
for r in rows:
    if key(r) in trig: by[key(r)][r["method"]] = r
def q(xs, p):
    xs = sorted(xs); return xs[max(0, math.ceil(p*len(xs))-1)] if xs else float("nan")
fam = lambda r: "dev-fixture" if r["group"] == "fixture" else r["group"].split(" ")[0]
ho = lambda d: d["M0"]["group"] != "fixture"
if all("M1g" in d for d in by.values()):
    diff = [k for k, d in by.items() if (d["M1"]["certified"], d["M1"]["via"], d["M1"]["excess"], d["M1"]["used"]) !=
            (d["M1g"]["certified"], d["M1g"]["via"], d["M1g"]["excess"], d["M1g"]["used"])]
    print("M1 vs M1g rows differing (certified, via, excess, used):", len(diff), "of", len(by))
print("\nexcess quantiles q10/q50/q90 among triggered runs")
agg = defaultdict(lambda: defaultdict(list))
for k, d in by.items():
    f = fam(d["M0"]) + " " + d["M0"]["T"]
    for m, r in d.items(): agg[f][m].append(float(r["excess"]))
for f in sorted(agg):
    print(" ", f, "  ".join(f"{m}: {q(v,.1):.1e}/{q(v,.5):.1e}/{q(v,.9):.1e}" for m, v in sorted(agg[f].items())))
print("\nvia counts (held-out only)")
for m in ("M1", "M2", "M2g"):
    if m in next(iter(by.values())):
        print(" ", m, dict(Counter(d[m]["via"] for d in by.values() if ho(d))))
c = Counter((fam(d["M0"]), d["M1"]["iters"]) for d in by.values() if d["M1"]["exhausted"] == "true")
print("\nM1 exhausted runs by (family, stages started):", sorted(c.items()))
c = Counter((fam(d["M0"]), d["M1"]["via"]) for d in by.values() if d["M1"]["class"] == "nonoptimal")
print("\nM1 nonoptimal by (family, via):", sorted(c.items()))
if "M2" in next(iter(by.values())):
    c = Counter((d["M1"]["class"][:7], d["M2"]["class"][:7]) for d in by.values() if ho(d))
    print("\n(M1 class, M2 class) pairs:", sorted(c.items()))
    c = Counter((d["M1"]["class"][:7], d["M2g"]["class"][:7]) for d in by.values() if ho(d))
    print("(M1 class, M2g class) pairs:", sorted(c.items()))
c = Counter((d["M0"]["config"], d["M1"]["class"][:7]) for d in by.values() if ho(d))
print("\nM1 by config:", sorted(c.items()))
c = Counter((d["M0"]["start"], d["M1"]["class"][:7]) for d in by.values() if d["M0"]["group"].startswith("H-mat"))
print("M1 H-mat by start:", sorted(c.items()))
c = Counter((d["M0"]["group"], d["M1"]["class"][:7]) for d in by.values() if d["M0"]["group"].startswith("H-mat"))
print("M1 H-mat by subfamily:", sorted(c.items()))
c = Counter((d["M0"]["id"].split("-")[0] + "-" + d["M0"]["id"].split("-")[1], d["M1"]["class"][:7]) for d in by.values() if d["M0"]["group"] == "H-real")
print("M1 H-real by shape/rho:", sorted(c.items()))
