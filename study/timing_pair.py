#!/usr/bin/env python3
"""Two builds of the same prototype in one timing file (the columns "<name> med" other than control):
which cases exceed a ratio of 1.05 in both, with the control within [0.98, 1.02].
usage: python3 -I timing_pair.py FILE..."""
import collections, sys
def med(v):
    v = sorted(v); return v[(len(v) - 1) // 2]
both = collections.Counter(); info = {}
for f in sys.argv[1:]:
    lines = [l.rstrip("\n").split("\t") for l in open(f)]
    head = next(l for l in lines if l[0] == "design")
    rows = [dict(zip(head, l)) for l in lines if len(l) == len(head) and l[0] != "design"]
    a, b = [h[:-4] for h in head if h.endswith(" med") and h != "control med"]
    key = lambda r: (r["design"], r["T"], r["pen"], r["frac"], r["container"], r["order"], r["start"])
    q = [r for r in rows if 0.98 <= float(r["control med"]) <= 1.02]
    lo = lambda r: min(float(r[a + " med"]), float(r[b + " med"])); hi = lambda r: max(float(r[a + " med"]), float(r[b + " med"]))
    mean = lambda r: (float(r[a + " med"]) + float(r[b + " med"])) / 2
    spread = sorted(hi(r) - lo(r) for r in rows)
    warm = [r for r in rows if r["start"] == "warm"]; cold = [r for r in rows if r["start"] == "cold"]
    sub = [r for r in rows if float(r["master ns"]) < 1e3]; small = [r for r in rows if 1e3 <= float(r["master ns"]) < 1e4]; big = [r for r in rows if float(r["master ns"]) >= 1e4]
    extra = sorted((mean(r) - 1) * float(r["master ns"]) for r in warm if r["pen"] != "group" and float(r["master ns"]) < 1e4)
    print(f"{f}: {lines[0][0][:60]}")
    print(f"  cases {len(rows)}, control within 2%: {len(q)}; either build > 1.05: {sum(hi(r) > 1.05 for r in q)}; both builds > 1.05: {sum(lo(r) > 1.05 for r in q)}; both > 1.02: {sum(lo(r) > 1.02 for r in q)}")
    print(f"  mean of the two builds, median over cases (max): all {med([mean(r) for r in rows]):.3f} ({max(mean(r) for r in rows):.3f}); cold {med([mean(r) for r in cold]):.3f} ({max(mean(r) for r in cold):.3f}); warm {med([mean(r) for r in warm]):.3f} ({max(mean(r) for r in warm):.3f})")
    for nm, s in (("master < 1 us", sub), ("1 to 10 us", small), (">= 10 us", big)):
        if s: print(f"    {nm}: {len(s)} cases, median {med([mean(r) for r in s]):.3f}, max {max(mean(r) for r in s):.3f}")
    print(f"  difference between the two builds: median {med(spread):.3f}, 90% {spread[int(0.9 * len(spread))]:.3f}, max {spread[-1]:.3f}; control: max |ratio - 1| {max(abs(float(r['control med']) - 1) for r in rows):.3f}")
    print(f"  extra time on warm vector-penalty solves under 10 us: median {med(extra):.0f} ns, 90% {extra[int(0.9 * len(extra))]:.0f} ns")
    print(f"  outcome differs from master: {sum(r[m + ' outcome'] != 'same' for r in rows for m in (a, b))}; allocation: " + ", ".join(sorted({f"+{int(r[m + ' alloc']) - int(r['master alloc'])} B" for r in rows for m in (a, b)})))
    for r in q:
        if lo(r) > 1.05:
            both[key(r)] += 1; info.setdefault(key(r), []).append((f.split("/")[-2], r[a + " med"], r[b + " med"], r["control med"], r["master ns"]))
print("cases above 1.05 in both builds, by number of files:", dict(collections.Counter(both.values())))
for k, v in info.items(): print("  ", *k, v)
