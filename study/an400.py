#!/usr/bin/env python3
"""Analysis of the #400 tables (standard library only).
usage: an400.py DIR   (DIR holds wl1_<T>.tsv, linf_sweep_<T>.tsv, linf_traj_<T>.tsv)"""
import sys, os, collections, math

TARGET = {"Float64": 1e-8, "Float32": 1e-5}
CERR = 1e-4


def load(path):
    meta, rows, hdr = [], [], None
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("#"):
                meta.append(line[2:])
                continue
            parts = line.split("\t")
            if hdr is None:
                hdr = parts
                continue
            rows.append(dict(zip(hdr, parts)))
    return meta, rows


def fl(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return float("nan")


def med(xs):
    xs = sorted(xs)
    return xs[len(xs) // 2] if xs else float("nan")


def rng(xs):
    xs = [x for x in xs if x == x]
    return "%.3g..%.3g" % (min(xs), max(xs)) if xs else "-"


def common(rows, T, cerr_col="coef_err"):
    """converged / false-convergence / missed-target counts shared by both sweeps"""
    conv = [r for r in rows if r["converged"] == "true"]
    false_obj = [r for r in conv if fl(r["subopt_lo"]) > TARGET[T]]
    false_coef = [r for r in conv if r.get("unique") == "true" and fl(r[cerr_col]) > CERR]
    missed = [r for r in rows if r["converged"] != "true" and fl(r["subopt_hi"]) <= TARGET[T]]
    return conv, false_obj, false_coef, missed


def keyc(rows, cols):
    return collections.Counter(tuple(r[c] for c in cols) for r in rows)


def wl1(path, T):
    meta, rows = load(path)
    print("=" * 100)
    print("WEIGHTED NormL1", T, path)
    for m in meta:
        print("  #", m)
    err = [r for r in rows if r["status"] != "ok"]
    rows = [r for r in rows if r["status"] == "ok"]
    print("solves ok:", len(rows), " errors:", len(err), collections.Counter(r["status"] for r in err).most_common(5))
    print("references tight:", sum(r["ref_tight"] == "true" for r in rows), "of", len(rows))
    conv, false_obj, false_coef, missed = common(rows, T)
    print("converged:", len(conv))
    # contract: converged => independent kkt_rel < bound
    viol = [r for r in conv if not fl(r["kkt_rel"]) < fl(r["bound"])]
    print("CONTRACT converged with independent ||G||inf/S >= bound:", len(viol))
    for k, n in sorted(keyc(viol, ("solver", "options", "fixture", "wset", "l1frac", "loss")).items()):
        rs = [r for r in viol if tuple(r[c] for c in ("solver", "options", "fixture", "wset", "l1frac", "loss")) == k]
        print("   ", *k, n, "ratio", rng([fl(r["kkt_rel"]) / fl(r["bound"]) for r in rs]))
    mx = max((fl(r["kkt_rel"]) / fl(r["bound"]) for r in conv if fl(r["kkt_rel"]) == fl(r["kkt_rel"])), default=0)
    print("  max kkt_rel/bound over converged: %.4g" % mx)
    print("FALSE CONVERGENCE (objective lower bound above target %g):" % TARGET[T], len(false_obj))
    for k, n in sorted(keyc(false_obj, ("solver", "options", "fixture", "wset", "l1frac", "start")).items()):
        rs = [r for r in false_obj if tuple(r[c] for c in ("solver", "options", "fixture", "wset", "l1frac", "start")) == k]
        print("   ", *k, n, "subopt_lo", rng([fl(r["subopt_lo"]) for r in rs]), "kkt/bound", rng([fl(r["kkt_rel"]) / fl(r["bound"]) for r in rs]))
    print("converged, unique reference, coef error > 1e-4:", len(false_coef))
    for k, n in sorted(keyc(false_coef, ("solver", "options", "fixture", "wset", "l1frac")).items()):
        rs = [r for r in false_coef if tuple(r[c] for c in ("solver", "options", "fixture", "wset", "l1frac")) == k]
        print("   ", *k, n, "coef_err", rng([fl(r["coef_err"]) for r in rs]), "xref_inf", rng([fl(r["xref_inf"]) for r in rs]),
              "kkt/bound", rng([fl(r["kkt_rel"]) / fl(r["bound"]) for r in rs]))
    print("MISSED TARGET (not converged, upper bound within target):", len(missed))
    for k, n in sorted(keyc(missed, ("solver", "options", "exit", "wset")).items()):
        print("   ", *k, n)
    print("exit classes by solver x options x wset:")
    for k, n in sorted(keyc(rows, ("solver", "options", "wset", "exit")).items()):
        print("   ", *k, n)
    # control: unweighted vs unit weights, same case
    base = ("solver", "fixture", "loss", "l1frac", "options", "start")
    by = {(r["wset"],) + tuple(r[c] for c in base): r for r in rows}
    diff_conv = diff_it = n = 0
    for k, r in by.items():
        if k[0] != "none":
            continue
        u = by.get(("unit",) + k[1:])
        if u is None:
            continue
        n += 1
        diff_conv += u["converged"] != r["converged"]
        diff_it += u["iterations"] != r["iterations"]
    print("control none vs unit: pairs %d, converged differs %d, iterations differ %d" % (n, diff_conv, diff_it))
    # zero weights
    z = [r for r in rows if r["wset"] == "zeros"]
    zc = [r for r in z if r["converged"] == "true"]
    print("zero-weight rows: %d, converged %d, max kkt/bound over converged %.3g, max gap_at_x over converged %.3g" % (
        len(z), len(zc), max((fl(r["kkt_rel"]) / fl(r["bound"]) for r in zc), default=0),
        max((fl(r["gap_at_x"]) for r in zc), default=0)))


def linf_sweep(path, T):
    meta, rows = load(path)
    print("=" * 100)
    print("NormLinf SWEEP", T, path)
    for m in meta:
        print("  #", m)
    err = [r for r in rows if r["status"] != "ok"]
    rows = [r for r in rows if r["status"] == "ok"]
    print("solves ok:", len(rows), " errors:", len(err), collections.Counter(r["status"] for r in err).most_common(5))
    print("references tight:", sum(r["ref_tight"] == "true" for r in rows), "of", len(rows),
          " unique+tight:", sum(r["ref_tight"] == "true" and r["unique"] == "true" for r in rows))
    conv, false_obj, false_coef, missed = common(rows, T)
    print("converged:", len(conv))
    print("  converged: independent Euclidean KKT / S over bound: median %.3g max %.3g; > 10 x bound: %d; > 100 x bound: %d" % (
        med([fl(r["kkt2_rel"]) / fl(r["bound"]) for r in conv]), max((fl(r["kkt2_rel"]) / fl(r["bound"]) for r in conv), default=0),
        sum(fl(r["kkt2_rel"]) > 10 * fl(r["bound"]) for r in conv), sum(fl(r["kkt2_rel"]) > 100 * fl(r["bound"]) for r in conv)))
    big = [r for r in conv if fl(r["kkt2_rel"]) > 10 * fl(r["bound"])]
    for k, n in sorted(keyc(big, ("solver", "options", "fixture", "l1frac")).items()):
        rs = [r for r in big if tuple(r[c] for c in ("solver", "options", "fixture", "l1frac")) == k]
        print("     >10x", *k, n, "kkt2/bound", rng([fl(r["kkt2_rel"]) / fl(r["bound"]) for r in rs]),
              "subopt_hi", rng([fl(r["subopt_hi"]) for r in rs]), "coef", rng([fl(r["coef_err"]) for r in rs]))
    print("FALSE CONVERGENCE (objective lower bound above target %g):" % TARGET[T], len(false_obj))
    for k, n in sorted(keyc(false_obj, ("solver", "options", "fixture", "l1frac", "start")).items()):
        rs = [r for r in false_obj if tuple(r[c] for c in ("solver", "options", "fixture", "l1frac", "start")) == k]
        print("   ", *k, n, "subopt_lo", rng([fl(r["subopt_lo"]) for r in rs]), "kkt2/bound", rng([fl(r["kkt2_rel"]) / fl(r["bound"]) for r in rs]))
    print("converged, unique reference, coef error > 1e-4:", len(false_coef))
    for k, n in sorted(keyc(false_coef, ("solver", "options", "fixture", "l1frac")).items()):
        rs = [r for r in false_coef if tuple(r[c] for c in ("solver", "options", "fixture", "l1frac")) == k]
        print("   ", *k, n, "coef_err", rng([fl(r["coef_err"]) for r in rs]), "xref_inf", rng([fl(r["xref_inf"]) for r in rs]),
              "subopt_hi", rng([fl(r["subopt_hi"]) for r in rs]))
    print("MISSED TARGET (not converged, upper bound within target):", len(missed))
    for k, n in sorted(keyc(missed, ("solver", "options", "exit")).items()):
        print("   ", *k, n)
    print("exit classes by solver x options:")
    for k, n in sorted(keyc(rows, ("solver", "options", "exit")).items()):
        print("   ", *k, n)
    # coefficient accuracy at the default options, unique references
    for sol in ("pgd", "apg"):
        d = [r for r in conv if r["options"] == "default" and r["solver"] == sol and r["unique"] == "true" and r["ref_tight"] == "true"]
        if d:
            print("  default %s converged unique: %d, coef_err <= 1e-4: %d, max %.3g" % (
                sol, len(d), sum(fl(r["coef_err"]) <= CERR for r in d), max(fl(r["coef_err"]) for r in d)))


def linf_traj(path, T):
    meta, rows = load(path)
    print("=" * 100)
    print("NormLinf CRITERIA (trajectories)", T, path)
    for m in meta:
        print("  #", m)
    rows = [r for r in rows if r["exit"] != "error"]
    trajs = {(r["solver"], r["fixture"], r["loss"], r["l1frac"], r["start"]) for r in rows}
    print("trajectories:", len(trajs), " exits:", collections.Counter(
        next(r["exit"] for r in rows if (r["solver"], r["fixture"], r["loss"], r["l1frac"], r["start"]) == t) for t in trajs))
    uniq = {t for t in trajs if any(r["unique"] == "true" and r["ref_tight"] == "true" and (r["solver"], r["fixture"], r["loss"], r["l1frac"], r["start"]) == t for r in rows)}
    orc = {}
    for r in rows:
        orc[(r["solver"], r["fixture"], r["loss"], r["l1frac"], r["start"])] = int(r["oracle_iter"])
    print("unique+tight trajectories: %d, of which reach coef err <= 1e-4: %d" % (len(uniq), sum(orc[t] > 0 for t in uniq)))
    print("%-5s %-6s %5s %6s %6s | %6s %6s %6s %6s %8s | %6s %6s" % (
        "crit", "tau", "n", "fired", "never", "U:n", "c<=1e-4", "early", "late", "med_ratio", "obj_ok", "obj_bad"))
    for crit in ("gen", "kkt", "kktl", "gap", "dx", "df"):
        for tau in ("0.001", "0.0001", "1e-05", "1e-06", "1e-07", "1e-08", "1e-10", "1e-12"):
            rs = [r for r in rows if r["crit"] == crit and r["tau"] == tau]
            if crit == "gap":
                rs = [r for r in rs if fl(r["l1frac"]) > 0]
            if not rs:
                continue
            fired = [r for r in rs if int(r["fire_iter"]) > 0]
            u = [r for r in fired if r["unique"] == "true" and r["ref_tight"] == "true"]
            cok = [r for r in u if fl(r["coef_err"]) <= CERR]
            early = [r for r in u if int(r["oracle_iter"]) < 0 or int(r["fire_iter"]) < int(r["oracle_iter"])]
            early_bad = [r for r in early if fl(r["coef_err"]) > CERR]
            late = [r for r in u if int(r["oracle_iter"]) > 0 and int(r["fire_iter"]) > int(r["oracle_iter"])]
            ratios = [int(r["fire_iter"]) / int(r["oracle_iter"]) for r in u if int(r["oracle_iter"]) > 0]
            objok = [r for r in fired if fl(r["subopt_lo"]) <= TARGET[T]]
            print("%-5s %-6s %5d %6d %6d | %6d %6d %6d %6d %8.3g | %6d %6d" % (
                crit, tau, len(rs), len(fired), len(rs) - len(fired), len(u), len(cok), len(early_bad), len(late),
                med(ratios), len(objok), len(fired) - len(objok)))
    print("  columns: n = trajectories (gap: lambda > 0 only); fired = criterion below tau at some iterate; U:n = fired with a")
    print("  unique certified reference; c<=1e-4 = of those, max coefficient error <= 1e-4 at the first fire; early = fired")
    print("  with coefficient error > 1e-4; late = fired after the oracle iteration; med_ratio = median fire/oracle")
    print("  iteration; obj_ok/obj_bad = fired with the proved objective lower bound within/above the target %g." % TARGET[T])


if __name__ == "__main__":
    d = sys.argv[1]
    for T in ("Float64", "Float32"):
        for name, fn in (("wl1_%s.tsv", wl1), ("linf_sweep_%s.tsv", linf_sweep), ("linf_traj_%s.tsv", linf_traj)):
            p = os.path.join(d, name % T)
            if os.path.exists(p):
                fn(p, T)
