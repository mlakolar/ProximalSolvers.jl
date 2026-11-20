#!/usr/bin/env python3
"""Per-fixture view of the NormLinf criteria (unique certified references only). usage: an400_crit.py DIR"""
import sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from an400 import load, fl, med, TARGET, CERR

d = sys.argv[1]
for T in ("Float64", "Float32"):
    _, rows = load(os.path.join(d, "linf_traj_%s.tsv" % T))
    rows = [r for r in rows if r["exit"] != "error" and r["unique"] == "true" and r["ref_tight"] == "true"]
    fx = sorted({r["fixture"] for r in rows})
    print("== %s  trajectories with a unique certified reference, by fixture" % T)
    tk = lambda r: (r["solver"], r["fixture"], r["loss"], r["l1frac"], r["start"])
    for f in fx:
        tr = {tk(r): r for r in rows if r["fixture"] == f}
        reach = sum(int(r["oracle_iter"]) > 0 for r in tr.values())
        print("  %-10s n=%d reach 1e-4 within 20000 its: %d  oracle iter med %s" % (
            f, len(tr), reach, med([int(r["oracle_iter"]) for r in tr.values() if int(r["oracle_iter"]) > 0])))
    print("  criterion@tau: per fixture 'ok/fired (never) med fire/oracle'; ok = coef err <= 1e-4 at the first fire")
    for crit in ("gen", "kkt", "kktl", "gap", "dx", "df"):
        for tau in ("1e-05", "1e-08"):
            parts = []
            for f in fx:
                rs = [r for r in rows if r["fixture"] == f and r["crit"] == crit and r["tau"] == tau]
                if crit == "gap":
                    rs = [r for r in rs if fl(r["l1frac"]) > 0]
                fired = [r for r in rs if int(r["fire_iter"]) > 0]
                ok = [r for r in fired if fl(r["coef_err"]) <= CERR]
                rat = [int(r["fire_iter"]) / int(r["oracle_iter"]) for r in fired if int(r["oracle_iter"]) > 0]
                parts.append("%s %d/%d(%d) %.2g" % (f[:6], len(ok), len(fired), len(rs) - len(fired), med(rat)))
            print("  %-4s %-6s %s" % (crit, tau, " | ".join(parts)))
    # time to comparable accuracy: fire iteration of kkt vs gen and gap vs gen at the same tau, both fired
    for a, b in (("kkt", "gen"), ("kktl", "gen"), ("gap", "gen")):
        for tau in ("1e-05", "1e-08"):
            A = {tk(r): int(r["fire_iter"]) for r in rows if r["crit"] == a and r["tau"] == tau and int(r["fire_iter"]) > 0}
            B = {tk(r): int(r["fire_iter"]) for r in rows if r["crit"] == b and r["tau"] == tau and int(r["fire_iter"]) > 0}
            ks = [k for k in A if k in B]
            rat = [A[k] / B[k] for k in ks]
            print("  fire(%s)/fire(%s) at %s: n=%d median %.3g, earlier %d, same %d, later %d" % (
                a, b, tau, len(ks), med(rat), sum(x < 1 for x in rat), sum(x == 1 for x in rat), sum(x > 1 for x in rat)))
