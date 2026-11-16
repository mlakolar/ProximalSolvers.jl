#!/usr/bin/env python3
"""#307: compare sweep.jl outputs of two arms. usage: compare_sweep.py OUT_X OUT_Y [--all]
Rows are matched by (case, T, scale, solver, start). Prints rows whose outcome, refusal message
class, iterate-after-refusal, scratch, iteration count or converged/stagnated flags differ, or whose
KKT residual or objective error changes by more than a factor of 10 (or crosses 1e-8/1e-4)."""
import csv, math, sys

def load(path):
    rows = {}
    with open(path) as f:
        lines = [l for l in f if l.count(",") >= 16 and not l.startswith("arm,")]
    hdr = "arm,version,case,T,scale,solver,start,outcome,message,x_unchanged,tmp_unchanged,minimum,obj_relerr,kkt,iters,converged,stagnated".split(",")
    for r in csv.reader(lines):
        d = dict(zip(hdr, r))
        k = (d["case"], d["T"], d["scale"], d["solver"], d["start"])
        rows.setdefault(k, []).append(d)
    return rows

def num(s):
    try:
        return float(s)
    except ValueError:
        return math.nan

def msgclass(m):
    for key in ("loss scale", "start from a point", "nonfinite objective", "cannot increase finitely", "curvature",
                "finite", "representable"):
        if key in m:
            return key
    return m[:40]

a, b = load(sys.argv[1]), load(sys.argv[2])
show_all = "--all" in sys.argv
print(f"rows: {sum(map(len, a.values()))} vs {sum(map(len, b.values()))}; keys only in X: {len(a.keys() - b.keys())}, only in Y: {len(b.keys() - a.keys())}")
ndiff = 0
for k in sorted(a.keys() & b.keys()):
    for ra, rb in zip(a[k], b[k]):
        notes = []
        if ra["outcome"] != rb["outcome"]:
            notes.append(f"outcome {ra['outcome']}->{rb['outcome']} ({msgclass(ra['message'])} | {msgclass(rb['message'])})")
        elif ra["outcome"] == "threw" and msgclass(ra["message"]) != msgclass(rb["message"]):
            notes.append(f"message {msgclass(ra['message'])} -> {msgclass(rb['message'])}")
        for f in ("x_unchanged", "tmp_unchanged", "iters", "converged", "stagnated"):
            if ra[f] != rb[f]:
                notes.append(f"{f} {ra[f]}->{rb[f]}")
        for f in ("kkt", "obj_relerr"):
            x, y = num(ra[f]), num(rb[f])
            if math.isnan(x) and math.isnan(y):
                continue
            big = (x > 0 and y > 0 and max(x / y, y / x) > 10) or (x == 0) != (y == 0) and max(x, y) > 1e-14
            cross = any((x <= t) != (y <= t) for t in (1e-8, 1e-4))
            if big or cross or (math.isnan(x) != math.isnan(y)):
                notes.append(f"{f} {x:.3g}->{y:.3g}")
        if notes or show_all:
            ndiff += bool(notes)
            print(" | ".join(k), "::", "; ".join(notes) if notes else "same", f"[kkt {ra['kkt']} -> {rb['kkt']}]")
print("differing rows:", ndiff)
