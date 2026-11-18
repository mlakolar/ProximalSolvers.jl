#!/usr/bin/env python3
"""Record-by-record check of -metrics.tsv between before/after for each repetition.
usage: recordcheck.py RESULTS_DIR SERIES(bh|aa)"""
import csv, glob, os, sys
FIELDS = ["status","worst_value","median_value","data_hash","min_bytes","median_bytes","max_bytes"]
def load(d, rep, kind):
    fs = glob.glob(os.path.join(d, f"*-rep{rep:02d}-{kind}.tsv"))
    assert len(fs) == 1, (d, rep, fs)
    with open(fs[0], newline="") as f:
        return {r["id"]: r for r in csv.DictReader(f, delimiter="\t")}
root, series = sys.argv[1], sys.argv[2]
b, a = os.path.join(root, series, "before"), os.path.join(root, series, "after")
same = 0; diffs = {}; total = 0; only = []
cat = {}
for rep in (1,2,3):
    mb, ma = load(b, rep, "metrics"), load(a, rep, "metrics")
    cb = load(b, rep, "catalog"); cat.update(cb)
    only += [(rep, i) for i in set(mb) ^ set(ma)]
    for i in sorted(set(mb) & set(ma)):
        total += 1
        d = [(f, mb[i][f], ma[i][f]) for f in FIELDS if mb[i][f] != ma[i][f]]
        if d: diffs.setdefault(i, []).append((rep, d))
cases = {i for i in cat}
print(f"series={series} record-pairs={total} cases={len(cases)} cases_with_differences={len(diffs)} identical_cases={len(cases)-len(diffs)} unmatched={only}")
for i, lst in sorted(diffs.items()):
    c = cat.get(i, {})
    print(f"DIFF {i} solver={c.get('solver')} inputs={c.get('inputs')} variant={c.get('variant')}")
    for rep, d in lst:
        for f, x, y in d: print(f"   rep{rep} {f}: before={x!r} after={y!r}")
nonok = {}
for rep in (1,2,3):
    for side, d in (("before", b), ("after", a)):
        for i, r in load(d, rep, "metrics").items():
            if r["status"] != "ok": nonok.setdefault((i, side), set()).add(r["status"])
for (i, side), s in sorted(nonok.items()): print(f"NONOK {side} {i} {sorted(s)}")
