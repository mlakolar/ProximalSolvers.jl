#!/usr/bin/env python3
"""Markdown tables for the #400 report from both version directories. usage: report_tables.py REL_DIR LTS_DIR"""
import sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from an400 import load, fl, med, TARGET, CERR

REL, LTS = sys.argv[1], sys.argv[2]
WELL = ("orth", "gauss", "tall_exact", "corr95")
ILL = ("colscale", "offset")

def pair(a, b):
    return str(a) if a == b else "%s (%s)" % (a, b)

def untight(d):
    for T in ("Float64", "Float32"):
        for name in ("wl1", "linf_sweep"):
            _, rows = load(os.path.join(d, "%s_%s.tsv" % (name, T)))
            c = collections.Counter(r["fixture"] for r in rows if r["ref_tight"] != "true")
            print("untight refs", name, T, dict(c))

def wl1_stats(d, T, w):
    _, rows = load(os.path.join(d, "wl1_%s.tsv" % T))
    rs = [r for r in rows if r["wset"] == w]
    c = [r for r in rs if r["converged"] == "true"]
    return dict(n=len(rs), conv=len(c), viol=sum(not fl(r["kkt_rel"]) < fl(r["bound"]) for r in c),
                mx="%.4f" % max(fl(r["kkt_rel"]) / fl(r["bound"]) for r in c),
                fobj=sum(fl(r["subopt_lo"]) > TARGET[T] for r in c),
                fcoef=sum(r["unique"] == "true" and r["fixture"] in WELL and fl(r["coef_err"]) > CERR for r in c),
                missed=sum(r["converged"] != "true" and fl(r["subopt_hi"]) <= TARGET[T] for r in rs))

def linf_stats(d, T, o):
    _, rows = load(os.path.join(d, "linf_sweep_%s.tsv" % T))
    rs = [r for r in rows if r["options"] == o]
    c = [r for r in rs if r["converged"] == "true"]
    return dict(n=len(rs), conv=len(c), kinf=sum(not fl(r["kktinf_rel"]) < fl(r["bound"]) for r in c),
                k2="%.2f" % max(fl(r["kkt2_rel"]) / fl(r["bound"]) for r in c),
                fobj=sum(fl(r["subopt_lo"]) > TARGET[T] for r in c),
                fcoef=sum(r["unique"] == "true" and fl(r["coef_err"]) > CERR for r in c),
                missed=sum(r["converged"] != "true" and fl(r["subopt_hi"]) <= TARGET[T] for r in rs))

def crit_stats(d, T, crit, tau):
    _, rows = load(os.path.join(d, "linf_traj_%s.tsv" % T))
    rows = [r for r in rows if r["exit"] != "error" and r["crit"] == crit and r["tau"] == tau]
    if crit == "gap":
        rows = [r for r in rows if fl(r["l1frac"]) > 0]
    out = {}
    for name, fx in (("well", WELL), ("ill", ILL)):
        rs = [r for r in rows if r["fixture"] in fx and r["unique"] == "true" and r["ref_tight"] == "true"]
        fired = [r for r in rs if int(r["fire_iter"]) > 0]
        ok = [r for r in fired if fl(r["coef_err"]) <= CERR]
        out[name] = "%d/%d/%d" % (len(ok), len(fired), len(rs))
    allf = [r for r in rows if int(r["fire_iter"]) > 0]
    out["obj"] = "%d/%d" % (sum(fl(r["subopt_lo"]) <= TARGET[T] for r in allf), len(allf))
    return out

untight(REL)
for T in ("Float64", "Float32"):
    print("\n#### Weighted `NormL1`, %s: all options, starts, levels, fixtures, both solvers (1.13.4; 1.10.13 in parentheses where it differs)\n" % T)
    print("| Weights | Solves | Converged | Converged with independent ‖G‖∞/S ≥ bound | Max ‖G‖∞/S / bound | Converged, objective above target | Converged, coef. error > 1e-4 (orth, gauss, tall_exact, corr95) | Not converged, within target |")
    print("|---|---|---|---|---|---|---|---|")
    for w, lab in (("none", "unweighted (control)"), ("unit", "unit"), ("spread", "spread 2^[−2,2]"), ("zeros", "spread + two zeros")):
        a, b = wl1_stats(REL, T, w), wl1_stats(LTS, T, w)
        print("| %s | %d | %s | %s | %s | %s | %s | %s |" % (lab, a["n"], pair(a["conv"], b["conv"]), pair(a["viol"], b["viol"]), pair(a["mx"], b["mx"]),
              pair(a["fobj"], b["fobj"]), pair(a["fcoef"], b["fcoef"]), pair(a["missed"], b["missed"])))
for T in ("Float64", "Float32"):
    print("\n#### `NormLinf` sweep, %s: PGD + APG, all levels, fixtures and starts (1.13.4; 1.10.13 in parentheses where it differs)\n" % T)
    print("| Options | Solves | Converged | Converged with independent ∞-norm KKT/S ≥ bound | Max Euclidean KKT/S / bound | Converged, objective above target | Converged, coef. error > 1e-4 (unique ref.) | Not converged, within target |")
    print("|---|---|---|---|---|---|---|---|")
    for o in ("default", "ftol0", "gradtol1e-8", "strict"):
        a, b = linf_stats(REL, T, o), linf_stats(LTS, T, o)
        print("| %s | %d | %s | %s | %s | %s | %s | %s |" % (o, a["n"], pair(a["conv"], b["conv"]), pair(a["kinf"], b["kinf"]), pair(a["k2"], b["k2"]),
              pair(a["fobj"], b["fobj"]), pair(a["fcoef"], b["fcoef"]), pair(a["missed"], b["missed"])))
for T in ("Float64", "Float32"):
    print("\n#### `NormLinf` criteria along trajectories, %s (1.13.4; 1.10.13 in parentheses where it differs)\n" % T)
    print("Each cell: at the first iterate where the criterion is below τ, coefficient error ≤ 1e-4 / fired / trajectories with a unique certified reference. Well-conditioned: orth, gauss, tall_exact, corr95 (160 trajectories); ill-conditioned: colscale, offset (80). Last column: fired with the proved objective lower bound within target / fired, over all 416 trajectories (gap: 328 with λ > 0).\n")
    print("| Criterion | τ | Well-conditioned | Ill-conditioned | Objective within target |")
    print("|---|---|---|---|---|")
    for crit in ("gen", "kkt", "kktl", "gap", "dx", "df"):
        for tau in ("1e-05", "1e-08"):
            a, b = crit_stats(REL, T, crit, tau), crit_stats(LTS, T, crit, tau)
            print("| `%s` | %s | %s | %s | %s |" % (crit, tau, pair(a["well"], b["well"]), pair(a["ill"], b["ill"]), pair(a["obj"], b["obj"])))
