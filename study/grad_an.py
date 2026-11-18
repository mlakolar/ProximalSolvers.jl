import sys, collections
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from summ import load, classify, fl
for T in ("Float64", "Float32"):
    rows = [r for r in load(sys.argv[1] % T) if r["status"] == "ok"]
    print("=====", T, len(rows))
    # (a) contract: converged => exact kkt_rel < bound
    conv = [r for r in rows if r["converged"] == "true"]
    viol = [r for r in conv if not fl(r["kkt_rel"]) < fl(r["bound"])]
    print("converged:", len(conv), " exact normalized KKT residual >= bound:", len(viol))
    c = collections.Counter((r["solver"], r["options"], r["fixture"], r["penalty"], r["l1frac"]) for r in viol)
    for k in sorted(c):
        rs = [r for r in viol if (r["solver"], r["options"], r["fixture"], r["penalty"], r["l1frac"]) == k]
        print("  ", *k, c[k], "ratio kkt/bound %.3g..%.3g" % (min(fl(r["kkt_rel"]) / fl(r["bound"]) for r in rs), max(fl(r["kkt_rel"]) / fl(r["bound"]) for r in rs)),
              "subopt_hi %.2g..%.2g" % (min(fl(r["subopt_hi"]) for r in rs), max(fl(r["subopt_hi"]) for r in rs)))
    mx = max((fl(r["kkt_rel"]) / fl(r["bound"]) for r in conv if fl(r["kkt_rel"]) == fl(r["kkt_rel"])), default=0)
    print("  max kkt_rel/bound over converged:", "%.4g" % mx)
    # (b) not converged but within target
    ng = [r for r in rows if classify(r) == "notconv/good"]
    c = collections.Counter((r["solver"], r["options"], r["exit"], r["start"], "l1frac>=1" if fl(r["l1frac"]) >= 1 else "l1frac<1") for r in ng)
    print("not converged, within target:", len(ng))
    for k in sorted(c):
        rs = [r for r in ng if (r["solver"], r["options"], r["exit"], r["start"], "l1frac>=1" if fl(r["l1frac"]) >= 1 else "l1frac<1") == k]
        it = sorted(int(r["iterations"]) for r in rs); fg = sorted(int(r["first_good_iter"]) for r in rs)
        kk = sorted(fl(r["kkt_rel"]) / fl(r["bound"]) for r in rs)
        print("  ", *k, c[k], "iters med %d max %d" % (it[len(it)//2], it[-1]), "first_good med %d max %d" % (fg[len(fg)//2], fg[-1]), "kkt/bound med %.2g max %.2g" % (kk[len(kk)//2], kk[-1]))
