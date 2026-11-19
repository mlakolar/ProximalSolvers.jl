"""Compare the Julia 1.10 cross-check rows with the matching 1.13 rows (M0, M1). Usage: python3 -I compare_versions.py <113 glob> <110 glob>"""
import csv, glob, sys
from collections import Counter
def load(g):
    d = {}
    for f in glob.glob(g):
        for r in csv.DictReader(open(f), delimiter="\t"):
            d[(r["id"], r["T"], r["config"], r["start"], r["method"])] = r
    return d
a, b = load(sys.argv[1]), load(sys.argv[2])
keys = [k for k in b if k[4] in ("M0", "M1")]
same_class = sum(a[k]["class"] == b[k]["class"] for k in keys)
same_all = sum((a[k]["class"], a[k]["certified"], a[k]["used"], a[k]["base"]) == (b[k]["class"], b[k]["certified"], b[k]["used"], b[k]["base"]) for k in keys)
print(f"rows compared {len(keys)}; same class {same_class}; same (class, certified, base, used) {same_all}")
for m in ("M0", "M1"):
    for v, lab in ((a, "1.13"), (b, "1.10")):
        c = Counter((k[1], v[k]["class"]) for k in keys if k[4] == m)
        fc = sum(v[k]["false_cert"] == "true" for k in keys if k[4] == m)
        cn = sum(v[k]["changed_nodecrease"] == "true" for k in keys if k[4] == m)
        print(f"  {m} {lab}: {dict(sorted(c.items()))} false_cert={fc} changed_nodecrease={cn}")
diff = [k for k in keys if a[k]["class"] != b[k]["class"]]
for k in diff:
    print("  differs:", k, a[k]["class"], "->", b[k]["class"], a[k]["excess"], b[k]["excess"])
