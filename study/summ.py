# Summary of a sweep TSV: outcome classes by precision against the pre-registered targets
# (relative suboptimality 1e-8 in Float64, 1e-5 in Float32; the repository's CORE_TARGETS).
import csv, sys, collections
TARGET = {"Float64": 1e-8, "Float32": 1e-5}
def fl(v):
    try: return float(v)
    except: return float("nan")
def load(path):
    return list(csv.DictReader(open(path), delimiter="\t"))
def classify(r):
    """Outcome class of a row. A point is above the target (BAD/bad) when a proved lower bound of its
    relative suboptimality exceeds the target; that needs only a reference point with a positive
    objective that is not at the rounding level of F(0), not a tight reference. It is within the target
    (good) when the upper bound, against a reference whose own gap is at most 1e-12, is below it."""
    if r["status"] != "ok": return "error"
    t = TARGET[r["T"]]
    conv = r["converged"] == "true"
    hi, lo = fl(r["subopt_hi"]), fl(r["subopt_lo"])
    tight = r.get("ref_tight", "true") == "true"
    fref, f0 = fl(r.get("Fref", "nan")), fl(r.get("F0", "nan"))
    informative = fref > 0 and fref > 1e-20 * f0
    bad = informative and lo > t and lo != float("inf")
    good = tight and hi <= t
    q = "BAD" if bad else ("good" if good else ("noref" if not tight else "unclear"))
    if conv: return "conv/" + q
    return "notconv/" + q.lower()
if __name__ == "__main__":
    rows = load(sys.argv[1])
    keys = sys.argv[2:] or ["T"]
    c = collections.Counter()
    for r in rows:
        c[tuple(r[k] for k in keys) + (classify(r),)] += 1
    for k in sorted(c): print("\t".join(k), c[k], sep="\t")
