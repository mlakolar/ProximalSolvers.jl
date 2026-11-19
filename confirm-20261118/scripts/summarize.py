"""Summary tables for the #155 confirmation round (protocol §4). Usage: python3 -I summarize.py <tsv glob> [by]
by = family (default) | coarse | T"""
import csv, glob, math, sys
from collections import defaultdict

rows = []
for f in sorted(glob.glob(sys.argv[1])):
    with open(f) as fh:
        rows += list(csv.DictReader(fh, delimiter="\t"))
by = sys.argv[2] if len(sys.argv) > 2 else "family"

def fam(r):
    g = r["group"]
    if by == "coarse":
        g = "dev-fixture" if g == "fixture" else g.split(" ")[0]
    elif by == "T":
        g = ("dev-fixture" if g == "fixture" else "held-out") + " " + r["T"]
        return g
    return g + " " + r["T"]

def q(xs, p):
    xs = sorted(xs)
    if not xs:
        return float("nan")
    return xs[max(0, math.ceil(p * len(xs)) - 1)]

B = lambda v: v == "true"
base = defaultdict(lambda: [0, 0, 0])          # runs, triggered, certified
for r in rows:
    if r["method"] == "M0":
        k = fam(r)
        base[k][0] += 1
        base[k][1] += B(r["triggered"])
        base[k][2] += B(r["certified"])

print("Base solves (M0): runs / certified / triggered (uncertified stop)")
for k in sorted(base):
    print(f"  {k:28s} {base[k][0]:4d} {base[k][2]:4d} {base[k][1]:4d}")

trig = {(r["id"], r["T"], r["config"], r["start"]) for r in rows if r["method"] == "M0" and B(r["triggered"])}
hdr = ("fam", "meth", "trig", "cert", "corr-cert", "near-unc", "nonopt", "falseC", "chg-nodec", "worse", "improved",
       "exhaust", "work q50", "q90", "max", "secs q50", "q90", "max")
print("\nTriggered runs by method")
print("  " + " ".join(f"{h:>9s}" if i > 1 else f"{h:<28s}" if i == 0 else f"{h:<4s}" for i, h in enumerate(hdr)))
agg = defaultdict(list)
for r in rows:
    if (r["id"], r["T"], r["config"], r["start"]) in trig:
        agg[(fam(r), r["method"])].append(r)
for (k, m) in sorted(agg):
    rs = agg[(k, m)]
    n = len(rs)
    cert = sum(B(r["certified"]) for r in rs)
    cc = sum(r["class"] == "correct-certified" for r in rs)
    nu = sum(r["class"] == "nearopt-uncertified" for r in rs)
    no = sum(r["class"] == "nonoptimal" for r in rs)
    fc = sum(B(r["false_cert"]) for r in rs)
    cn = sum(B(r["changed_nodecrease"]) for r in rs)
    wo = sum(B(r["worse"]) for r in rs)
    im = sum(B(r["improved"]) for r in rs)
    ex = sum(B(r["exhausted"]) for r in rs)
    if m == "M0":
        w = [int(r["base"]) for r in rs]; s = [float(r["secs"]) for r in rs]
    else:
        w = [int(r["used"]) for r in rs]; s = [float(r["secs"]) for r in rs]
    vals = (n, cert, cc, nu, no, fc, cn, wo, im, ex, q(w, .5), q(w, .9), max(w), q(s, .5), q(s, .9), max(s))
    out = [f"{k:<28s}", f"{m:<4s}"]
    for v in vals:
        out.append(f"{v:9.3g}" if isinstance(v, float) else f"{v:9d}")
    print("  " + " ".join(out))
