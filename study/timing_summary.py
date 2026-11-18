#!/usr/bin/env python3
"""Summary of a timing378 output. usage: python3 -I timing_summary.py FILE...
Per file and module: over the cases, the median and the largest of the per-case median ratio to master;
the number of cases whose median ratio exceeds 1.05 (and 1.02) while the control's is within [0.98, 1.02];
split by the size of master's solve and by the start."""
import sys

def med(v):
    v = sorted(v); return v[(len(v) - 1) // 2] if v else float("nan")

for f in sys.argv[1:]:
    lines = [l.rstrip("\n").split("\t") for l in open(f)]
    head = next(l for l in lines if l[0] == "design")
    rows = [dict(zip(head, l)) for l in lines if len(l) == len(head) and l[0] != "design"]
    mods = [h[:-4] for h in head if h.endswith(" med")]
    print(f"== {f}: {lines[0][0][:110]}")
    print(f"   {len(rows)} cases; {lines[-1][0][:80]}")
    bins = [("all", lambda r: True), ("master < 1 us", lambda r: float(r["master ns"]) < 1e3), ("1 to 10 us", lambda r: 1e3 <= float(r["master ns"]) < 1e4),
            ("10 to 1000 us", lambda r: 1e4 <= float(r["master ns"]) < 1e6), (">= 1 ms", lambda r: float(r["master ns"]) >= 1e6),
            ("cold", lambda r: r["start"] == "cold"), ("warm", lambda r: r["start"] == "warm"),
            ("Float32", lambda r: r["T"] == "Float32"), ("Float64", lambda r: r["T"] == "Float64"), ("groups", lambda r: r["pen"] == "group")]
    print("   " + "subset".ljust(16) + "cases".ljust(7) + "".join((m + ": median, max, >1.05, >1.02 (control quiet)").ljust(52) for m in mods))
    for bn, bf in bins:
        sel = [r for r in rows if bf(r)]
        if not sel: continue
        out = "   " + bn.ljust(16) + str(len(sel)).ljust(7)
        for m in mods:
            v = [float(r[m + " med"]) for r in sel]
            quiet = [r for r in sel if 0.98 <= float(r["control med"]) <= 1.02]
            n5 = sum(float(r[m + " med"]) > 1.05 for r in quiet); n2 = sum(float(r[m + " med"]) > 1.02 for r in quiet)
            out += f"{med(v):.3f}, {max(v):.3f}, {n5}, {n2} ({len(quiet)})".ljust(52)
        print(out)
    for m in mods:
        if m == "control": continue
        worst = sorted(rows, key=lambda r: -float(r[m + " med"]))[:5]
        for r in worst:
            print(f"   worst {m}: {r[m + ' med']} (max {r[m + ' max']}; control {r['control med']}) {r['design']} {r['T']} {r['pen']} {r['frac']} {r['container']} {r['order']} {r['start']} passes {r['passes']} master {r['master ns']} ns; outcome {r[m + ' outcome']}; alloc {r['master alloc']} -> {r[m + ' alloc']}")
    diff = [(r["design"], r["T"], m, r[m + " outcome"]) for r in rows for m in mods if r[m + " outcome"] != "same"]
    alloc = [(r["design"], r["T"], r["start"], m, r["master alloc"], r[m + " alloc"]) for r in rows for m in mods if r[m + " alloc"] != r["master alloc"]]
    print(f"   outcomes differing from master: {len(diff)} {diff[:4]}; allocation differing: {len(alloc)} {alloc[:4]}")
