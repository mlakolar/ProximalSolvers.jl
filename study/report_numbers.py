# Every count and extreme quoted in the report, recomputed from the sweep tables.
# usage: report_numbers.py EVIDENCE_DIR   (prints both Julia versions)
import sys, collections, statistics
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from summ import load, fl, classify, TARGET
E = sys.argv[1]
TS = ("Float64", "Float32")
def L(v, fam, T): return [r for r in load("%s/sweep-%s/%s_%s.tsv" % (E, v, fam, T)) if r["status"] == "ok"]
def mx(rs, k): 
    v = [fl(r[k]) for r in rs if fl(r[k]) == fl(r[k]) and abs(fl(r[k])) != float("inf")]
    return max(v) if v else float("nan")
def mn(rs, k):
    v = [fl(r[k]) for r in rs if fl(r[k]) == fl(r[k]) and abs(fl(r[k])) != float("inf")]
    return min(v) if v else float("nan")
for v in ("release", "lts"):
    print("=" * 20, v)
    tot = sum(len(load("%s/sweep-%s/%s_%s.tsv" % (E, v, fam, T))) for fam in ("cd_scalar", "cd_group", "grad", "sqrt") for T in TS)
    print("1. solves:", tot, {fam: sum(len(L(v, fam, T)) for T in TS) for fam in ("cd_scalar", "cd_group", "grad", "sqrt")})
    # 2. PGD / APG contract
    for T in TS:
        g = L(v, "grad", T)
        conv = [r for r in g if r["converged"] == "true"]
        ex = [r for r in conv if not fl(r["kkt_rel"]) < fl(r["bound"])]
        print("2.", T, "PGD+APG converged", len(conv), "exact KKT >= bound", len(ex), "max ratio %.4f" % max([fl(r["kkt_rel"]) / fl(r["bound"]) for r in ex] or [0]),
              "options of exceedances", dict(collections.Counter(r["options"] for r in ex)),
              "| per solver converged", {s: sum(r["solver"] == s for r in conv) for s in ("pgd", "apg")}, "exceed", {s: sum(r["solver"] == s for r in ex) for s in ("pgd", "apg")})
    for s in ("pgd", "apg"):
        ex = [fl(r["kkt_rel"]) / fl(r["bound"]) for T in TS for r in L(v, "grad", T) if r["solver"] == s and r["converged"] == "true" and not fl(r["kkt_rel"]) < fl(r["bound"])]
        print("2.", s, "both precisions: converged", sum(r["converged"] == "true" for T in TS for r in L(v, "grad", T) if r["solver"] == s), "exceed", len(ex), "max ratio %.4f" % max(ex or [0]))
    # 3. square-root certificates, strict comparisons on the stored values
    for T in TS:
        q = L(v, "sqrt", T)
        c = [r for r in q if r["converged"] == "true"]
        print("3.", T, "sqrt rows", len(q), "certified", len(c), "gap < independent gap at x:", sum(fl(r["gap"]) < fl(r["gap_exact_at_x"]) for r in c),
              "gap < lower bound of suboptimality:", sum(fl(r["gap"]) < fl(r["subopt_lo"]) for r in c), "gap >= 1e-4:", sum(not fl(r["gap"]) < 1e-4 for r in c),
              "y=0 certified with gap 0:", sum(r["fixture"] == "yzero" for r in c), "| not certified:", dict(collections.Counter(r["warning"] for r in q if r["converged"] != "true")))
    # 4. scalar CD default tol, positive penalty
    for T in TS:
        sc = [r for r in L(v, "cd_scalar", T) if r["tol"] == "default" and fl(r["l1frac"]) > 0]
        conv = [r for r in sc if r["converged"] == "true"]
        cl = collections.Counter(classify(r) for r in conv)
        good = [r for r in conv if classify(r) == "conv/good"]
        nr = [r for r in conv if classify(r) == "conv/noref"]
        rd = [r for r in nr if r["fixture"] == "rankdef"]
        print("4.", T, "scalar default lam>0 rows", len(sc), "converged", len(conv), dict(cl), "worst subopt_hi of good %.3g" % mx(good, "subopt_hi"), "worst kkt_rel of good %.3g" % mx(good, "kkt_rel"),
              "| noref by fixture", dict(collections.Counter(r["fixture"] for r in nr)), "rankdef subopt_lo %.2g..%.2g hi max %.2g kkt max %.2g" % (mn(rd, "subopt_lo"), mx(rd, "subopt_lo"), mx(rd, "subopt_hi"), mx(rd, "kkt_rel")),
              "| at maxpasses rel=true", sum(int(r["passes"]) >= 100000 for r in sc if r["relative"] == "true"))
        z = [r for r in L(v, "cd_scalar", T) if r["tol"] == "default" and fl(r["l1frac"]) == 0 and r["converged"] == "true"]
        bz = [r for r in z if classify(r) == "conv/BAD"]
        print("4b.", T, "scalar default lam=0 converged", len(z), "above target", len(bz), dict(collections.Counter((r["fixture"], r["start"]) for r in bz)), "kkt_rel max by start", {s: "%.2g" % mx([r for r in bz if r["start"] == s], "kkt_rel") for s in ("cold", "ref", "pert")})
        off = [r for r in z if r["fixture"] == "offset"]
        print("4c.", T, "offset lam=0 subopt_lo by start", {s: "%.3g..%.3g" % (mn([r for r in off if r["start"] == s], "subopt_lo"), mx([r for r in off if r["start"] == s], "subopt_lo")) for s in ("cold", "ref", "pert")})
    # 5. loose threshold
    lo = [r for r in L(v, "cd_scalar", "Float64") if r["tol"] == "0.0001"]
    b = [r for r in lo if classify(r) == "conv/BAD"]
    print("5. scalar F64 tol=1e-4 rows", len(lo), "converged", sum(r["converged"] == "true" for r in lo), "above target", len(b), "positive penalty", sum(fl(r["l1frac"]) > 0 for r in b))
    # 6. group CD default tol, positive penalty
    for T in TS:
        gr = [r for r in L(v, "cd_group", T) if r["tol"] == "default" and fl(r["l1frac"]) > 0]
        conv = [r for r in gr if r["converged"] == "true"]
        bad = [r for r in conv if classify(r) == "conv/BAD"]
        print("6.", T, "group default lam>0 rows", len(gr), "converged", len(conv), "above target", len(bad), "worst subopt_lo %.3g" % mx(bad, "subopt_lo"), "worst kkt_rel %.3g" % mx(bad, "kkt_rel"),
              "| relative=true:", sum(r["relative"] == "true" for r in bad), "worst %.3g" % mx([r for r in bad if r["relative"] == "true"], "subopt_lo"),
              "| relative=false:", sum(r["relative"] == "false" for r in bad), "worst %.3g" % mx([r for r in bad if r["relative"] == "false"], "subopt_lo"),
              "| by design", dict(collections.Counter((r["fixture"], r["relative"]) for r in bad)), "classes", dict(collections.Counter(classify(r) for r in conv)))
    # 7. ftol = 0 on master: not converged although the exact normalized residual is below the bound (S > 0 only)
    for T in TS:
        g = L(v, "grad", T)
        for opt in ("ftol0", "strict"):
            for s in ("pgd", "apg"):
                rs = [r for r in g if r["options"] == opt and r["solver"] == s]
                zero = [r for r in rs if r["fixture"] == "yzero" and fl(r["l1"]) == 0]
                pos = [r for r in rs if not (r["fixture"] == "yzero" and fl(r["l1"]) == 0)]
                nc = [r for r in pos if r["converged"] != "true" and fl(r["kkt_rel"]) < fl(r["bound"])]
                st = [r for r in rs if r["exit"] == "stagnated"]
                print("7.", T, opt, s, "n", len(rs), "converged", sum(r["converged"] == "true" for r in rs), "S=0 rows", len(zero), "not converged, S>0, below bound", len(nc),
                      "of those maxiter", sum(r["exit"] == "maxiter" for r in nc), "stagnated", sum(r["exit"] == "stagnated" for r in nc), "increase", sum(r["exit"] == "increase" for r in nc),
                      "| all stagnated", len(st), "below bound", sum(fl(r["kkt_rel"]) < fl(r["bound"]) for r in st), "max ratio %.3f" % max([fl(r["kkt_rel"]) / fl(r["bound"]) for r in st] or [0]))
    # 9. square-root lasso: certified fractions on the designs without an exact-fit optimum
    for T in TS:
        q = [r for r in L(v, "sqrt", T) if r["fixture"] not in ("tall_exact", "wide", "wide_exact", "yzero") and r["relative"] == "true"]
        for tol in ("default", "0.0001"):
            out = []
            for lf in ("0.001", "0.05", "0.3", "0.7", "1.01", "2"):
                rs = [r for r in q if r["tol"] == tol and r["lfrac"] == lf]
                un = [r for r in rs if r["converged"] != "true"]
                out.append("%s: %d/%d worst %.2g" % (lf, len(rs) - len(un), len(rs), mx(un, "subopt_hi") if un else 0))
            print("9.", T, "tol", tol, " | ".join(out))
        un = [r for r in q if r["tol"] == "default" and r["converged"] != "true"]
        print("9b.", T, "default uncertified by design", dict(collections.Counter(r["fixture"] for r in un)))
        allq = L(v, "sqrt", T)
        ex = [r for r in allq if r["fixture"] in ("tall_exact", "wide", "wide_exact") and r["converged"] != "true"]
        print("9c.", T, "exact-fit designs not converged", len(ex), dict(collections.Counter(r["warning"] for r in ex)), "largest lower bound of suboptimality %.4g" % mx(ex, "subopt_lo"),
              "| maxpasses at tol=1e-10:", sum(r["warning"] == "maxpasses" and r["tol"] == "1e-10" for r in allq), "worst subopt_hi %.2g" % mx([r for r in allq if r["warning"] == "maxpasses" and r["tol"] == "1e-10"], "subopt_hi"),
              "| relative=false default at maxpasses:", sum(r["warning"] == "maxpasses" and r["tol"] == "default" and r["relative"] == "false" for r in allq), "of", sum(r["tol"] == "default" and r["relative"] == "false" for r in allq))
        cc = [r for r in allq if r["fixture"] == "corr95" and r["lfrac"] == "0.001" and r["tol"] == "0.0001" and r["converged"] != "true" and r["relative"] == "true"]
        if cc: print("9d.", T, "corr95 0.001 tol=1e-4 uncertified", len(cc), "independent gap at x %.3g..%.3g" % (mn(cc, "gap_exact_at_x"), mx(cc, "gap_exact_at_x")), "subopt_hi max %.3g" % mx(cc, "subopt_hi"))
    # 10. objective-increase exits within the target
    for T in TS:
        g = L(v, "grad", T)
        for opt in ("default", "gradtol1e-8"):
            for s in ("pgd", "apg"):
                rs = [r for r in g if r["options"] == opt and r["solver"] == s and r["exit"] == "increase" and classify(r) == "notconv/good"]
                med = statistics.median([fl(r["kkt_rel"]) / fl(r["bound"]) for r in rs]) if rs else float("nan")
                print("10.", T, opt, s, "increase exits within target", len(rs), "of", sum(r["options"] == opt and r["solver"] == s for r in g), "median kkt/bound %.2g" % med)
    # 11. Float32, relative = false, default tol: at maxpasses
    sc = [r for r in L(v, "cd_scalar", "Float32") if r["tol"] == "default" and r["relative"] == "false"]
    mp = [r for r in sc if int(r["passes"]) >= 100000]
    print("11. F32 scalar relative=false default rows", len(sc), "at maxpasses", len(mp), "classes", dict(collections.Counter(classify(r) for r in mp)), "worst subopt_hi %.4g" % mx([r for r in mp if classify(r) == "notconv/good"], "subopt_hi"))
    # 13. flags and the reported minimum
    for T in TS:
        g = L(v, "grad", T)
        print("13.", T, "default: converged and f_increased", {s: sum(r["options"] == "default" and r["solver"] == s and r["converged"] == "true" and r["f_increased"] == "true" for r in g) for s in ("pgd", "apg")})
        for fam in ("cd_scalar", "cd_group"):
            rs = [r for r in L(v, fam, T) if fl(r["l1frac"]) > 0]
            print("13.", T, fam, "positive penalty, max min_err: default tol %.4g, all tols %.4g, converged only %.4g" % (mx([r for r in rs if r["tol"] == "default"], "min_err"), mx(rs, "min_err"), mx([r for r in rs if r["converged"] == "true"], "min_err")))
# 14. cross-version agreement of the flag
print("=" * 20, "cross-version")
for fam in ("cd_scalar", "cd_group", "grad", "sqrt"):
    for T in TS:
        A = load("%s/sweep-release/%s_%s.tsv" % (E, fam, T)); B = load("%s/sweep-lts/%s_%s.tsv" % (E, fam, T))
        print("14.", fam, T, len(A), "same converged", sum(a["converged"] == b["converged"] for a, b in zip(A, B)))
