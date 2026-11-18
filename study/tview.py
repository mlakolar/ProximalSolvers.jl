#!/usr/bin/env python3
"""Print one table of a tables file aligned. usage: python3 -I tview.py FILE PREFIX [filter substring ...]"""
import sys
f, pre, flt = sys.argv[1], sys.argv[2], sys.argv[3:]
out, on = [], False
for line in open(f):
    line = line.rstrip("\n")
    if line.startswith(pre):
        on = True; print(line); continue
    if on:
        if not line.strip() or line.startswith("#"):
            break
        c = line.split("\t")
        if len(out) == 0 or all(s in line for s in flt):
            out.append(c)
w = [max(len(r[i]) if i < len(r) else 0 for r in out) for i in range(max(len(r) for r in out))]
w = [min(x, 22) for x in w]
for r in out:
    print("  ".join(x[:22].ljust(w[i]) for i, x in enumerate(r)))
