# drill.py FILE CLASS [filters k=v ...] : groups rows of one class by problem and prints the range of the measures
import sys, collections
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from summ import load, classify, fl
rows = load(sys.argv[1]); cls = sys.argv[2]
flt = dict(a.split("=", 1) for a in sys.argv[3:] if "=" in a and not a.startswith("by="))
by = [a[3:].split(",") for a in sys.argv[3:] if a.startswith("by=")]
by = by[0] if by else ["fixture", "loss", "penalty", "l1frac"]
g = collections.defaultdict(list)
for r in rows:
    if classify(r) != cls: continue
    if any(r[k] != v for k, v in flt.items()): continue
    g[tuple(r[k] for k in by)].append(r)
def rng(rs, k):
    v = [fl(r[k]) for r in rs]; return "%.2g..%.2g" % (min(v), max(v))
print("\t".join(by + ["n", "subopt_lo", "subopt_hi", "kkt_rel", "passes", "min_err"]))
for k in sorted(g):
    rs = g[k]
    pk = "passes" if "passes" in rs[0] else "iterations"
    print("\t".join(k), len(rs), rng(rs, "subopt_lo"), rng(rs, "subopt_hi"), rng(rs, "kkt_rel"), rng(rs, pk), rng(rs, "min_err"), sep="\t")
