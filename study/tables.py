# Headline tables of the report from the sweep TSVs.  usage: tables.py SWEEPDIR
import sys, collections
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from summ import load, fl, classify, TARGET
D = sys.argv[1]
def pen(r): return float(r.get("l1frac", r.get("lfrac")))
print("## CD least squares (scalar and group): converged and within the target, by precision, threshold and penalty")
for fam in ("cd_scalar", "cd_group"):
    for T in ("Float64", "Float32"):
        rows = [r for r in load("%s/%s_%s.tsv" % (D, fam, T)) if r["status"] == "ok"]
        for tol in sorted(set(r["tol"] for r in rows)):
            for relv in ("true", "false"):
                for lam in ("lam>0", "lam=0"):
                    rs = [r for r in rows if r["tol"] == tol and r["relative"] == relv and (pen(r) > 0) == (lam == "lam>0")]
                    if not rs: continue
                    c = collections.Counter(classify(r) for r in rs)
                    conv = [r for r in rs if r["converged"] == "true" and r["ref_tight"] == "true"]
                    worst = max((fl(r["subopt_hi"]) for r in conv), default=float("nan"))
                    wk = max((fl(r["kkt_rel"]) for r in conv if fl(r["kkt_rel"]) < 1e300), default=float("nan"))
                    me = max((fl(r["min_err"]) for r in rs if fl(r["min_err"]) < 1e300), default=float("nan"))
                    mp = sum(int(r["passes"]) >= 100000 for r in rs)
                    print(fam, T, "tol=" + tol, "relative=" + relv, lam, "n=%d" % len(rs), dict(sorted(c.items())), "worst subopt of converged %.2g" % worst, "worst kkt_rel %.2g" % wk, "max min_err %.2g" % me, "at maxpasses %d" % mp, sep="\t")
print("## PGD / APG by options")
for T in ("Float64", "Float32"):
    rows = [r for r in load("%s/grad_%s.tsv" % (D, T)) if r["status"] == "ok"]
    for sol in ("pgd", "apg"):
        for opt in ("default", "default-20k", "allow-inc", "gradtol1e-8", "ftol0", "strict"):
            rs = [r for r in rows if r["solver"] == sol and r["options"] == opt]
            c = collections.Counter(r["exit"] for r in rs)
            good = collections.Counter(r["exit"] for r in rs if classify(r) == "notconv/good")
            convbad = sum(classify(r) == "conv/BAD" for r in rs)
            viol = sum(r["converged"] == "true" and not fl(r["kkt_rel"]) < fl(r["bound"]) for r in rs)
            both = sum(r["converged"] == "true" and r["f_increased"] == "true" for r in rs)
            bothm = sum(r["converged"] == "true" and r["at_maxiter"] == "true" for r in rs)
            print(T, sol, opt, "n=%d" % len(rs), dict(sorted(c.items())), "not converged but within target: %s" % dict(sorted(good.items())),
                  "converged above target %d" % convbad, "converged with exact KKT>=bound %d" % viol, "converged&f_increased %d" % both, "converged&at_maxiter %d" % bothm, sep="\t")
print("## square-root lasso")
for T in ("Float64", "Float32"):
    rows = [r for r in load("%s/sqrt_%s.tsv" % (D, T)) if r["status"] == "ok"]
    conv = [r for r in rows if r["converged"] == "true"]
    inval = sum(not (fl(r["gap"]) >= fl(r["subopt_lo"]) * (1 - 1e-5) and fl(r["gap"]) >= fl(r["gap_exact_at_x"]) * (1 - 1e-5) and fl(r["gap"]) < 1e-4) for r in conv)
    c = collections.Counter((r["warning"] if r["converged"] != "true" else "certified") for r in rows)
    print(T, "n=%d" % len(rows), dict(c), "invalid certificates %d" % inval, "max min_err %.2g" % max(fl(r["min_err"]) for r in rows), sep="\t")
