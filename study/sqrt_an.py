import sys, collections
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from summ import load, fl
for T in ("Float64", "Float32"):
    rows = load(sys.argv[1] % T)
    print("=====", T, len(rows), collections.Counter(r["status"][:5] for r in rows))
    rows = [r for r in rows if r["status"] == "ok"]
    conv = [r for r in rows if r["converged"] == "true"]
    # certificate validity: reported gap >= exact gap at x (same dual direction, BigFloat) and >= rigorous lower bound of the true suboptimality
    bad1 = [r for r in conv if not (fl(r["gap"]) >= fl(r["gap_exact_at_x"]) * (1 - 1e-5))]
    bad2 = [r for r in conv if not (fl(r["gap"]) >= fl(r["subopt_lo"]) * (1 - 1e-5))]
    bad3 = [r for r in conv if not fl(r["gap"]) < 1e-4]
    print("converged:", len(conv), "| reported gap below the exact gap at x:", len(bad1), "| below a proven lower bound of the suboptimality:", len(bad2), "| gap >= 1e-4:", len(bad3))
    if conv:
        print("  slack reported/exact gap: max %.4g" % max(fl(r["gap"]) / fl(r["gap_exact_at_x"]) for r in conv if fl(r["gap_exact_at_x"]) > 0))
    c = collections.Counter()
    for r in rows:
        tight = fl(r["ref_gap"]) <= 1e-9
        hi, lo = fl(r["subopt_hi"]), fl(r["subopt_lo"])
        q = "good" if (tight and hi <= 1e-4) else ("bad" if lo > 1e-4 else ("noref" if not tight else "unclear"))
        c[(r["tol"], r["relative"], "conv" if r["converged"] == "true" else "notconv:" + r["warning"], q)] += 1
    for k in sorted(c): print("  ", *k, c[k])
    # not converged: by fixture / lambda
    c = collections.Counter(); P = collections.defaultdict(list)
    for r in rows:
        if r["converged"] == "true": continue
        k = (r["fixture"], r["lfrac"], r["warning"], "exactfit" if r["exactfit_at_x"] == "true" else "resid>0")
        c[k] += 1; P[k].append(r)
    print("  not converged by problem:")
    for k in sorted(c):
        rs = P[k]
        print("    ", *k, c[k], "passes %d..%d" % (min(int(r["passes"]) for r in rs), max(int(r["passes"]) for r in rs)),
              "subopt_lo %.2g..%.2g" % (min(fl(r["subopt_lo"]) for r in rs), max(fl(r["subopt_lo"]) for r in rs)),
              "subopt_hi %.2g..%.2g" % (min(fl(r["subopt_hi"]) for r in rs), max(fl(r["subopt_hi"]) for r in rs)), "refgap %.2g" % fl(rs[0]["ref_gap"]))
