#!/usr/bin/env python3
"""Compact tables for the #400 report. usage: an400_tables.py DIR"""
import sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from an400 import load, fl, TARGET, CERR, med

d = sys.argv[1]
for T in ("Float64", "Float32"):
    _, rows = load(os.path.join(d, "wl1_%s.tsv" % T))
    print("== weighted NormL1 %s: options x weights: n conv | contract-viol | false(obj) | conv&unique coef>1e-4 | missed | max kkt/bound" % T)
    for o in ("default", "ftol0", "gradtol1e-8", "strict"):
        for sol in ("pgd", "apg"):
            line = []
            for w in ("none", "unit", "spread", "zeros"):
                rs = [r for r in rows if r["options"] == o and r["wset"] == w and r["solver"] == sol]
                c = [r for r in rs if r["converged"] == "true"]
                v = sum(not fl(r["kkt_rel"]) < fl(r["bound"]) for r in c)
                fo = sum(fl(r["subopt_lo"]) > TARGET[T] for r in c)
                fc = sum(r["unique"] == "true" and fl(r["coef_err"]) > CERR for r in c)
                m = sum(r["converged"] != "true" and fl(r["subopt_hi"]) <= TARGET[T] for r in rs)
                mx = max((fl(r["kkt_rel"]) / fl(r["bound"]) for r in c), default=0)
                line.append("%s %d/%d|%d|%d|%d|%d|%.2f" % (w, len(c), len(rs), v, fo, fc, m, mx))
            print("  %-11s %s  %s" % (o, sol, "   ".join(line)))
    _, rows = load(os.path.join(d, "linf_sweep_%s.tsv" % T))
    print("== NormLinf sweep %s: options x solver: conv/n | false(obj) | conv&unique coef>1e-4 | missed | kkt2/bound med,max | kktinf/bound max" % T)
    for o in ("default", "ftol0", "gradtol1e-8", "strict"):
        for sol in ("pgd", "apg"):
            rs = [r for r in rows if r["options"] == o and r["solver"] == sol]
            c = [r for r in rs if r["converged"] == "true"]
            fo = sum(fl(r["subopt_lo"]) > TARGET[T] for r in c)
            fc = sum(r["unique"] == "true" and fl(r["coef_err"]) > CERR for r in c)
            m = sum(r["converged"] != "true" and fl(r["subopt_hi"]) <= TARGET[T] for r in rs)
            k2 = [fl(r["kkt2_rel"]) / fl(r["bound"]) for r in c]
            ki = [fl(r["kktinf_rel"]) / fl(r["bound"]) for r in c]
            ex = collections.Counter(r["exit"] for r in rs)
            print("  %-11s %s %d/%d | %d | %d | %d | %.3g,%.3g | %.3g | %s" % (o, sol, len(c), len(rs), fo, fc, m, med(k2), max(k2, default=0), max(ki, default=0), dict(ex)))
