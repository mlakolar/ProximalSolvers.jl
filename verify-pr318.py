#!/usr/bin/env python3
"""PR #318 premerge check (disposable): new acc- IDs 10/10 ok per version; existing (id, rep) records identical to 55c6640.
usage: verify-pr318.py <post296 run dir> <this run dir>"""
import csv, glob, sys
def load(d):
    m = {}
    for p in glob.glob(f"{d}/*-metrics.tsv"):
        for r in csv.DictReader(open(p), delimiter="\t"): m[(r["id"], r["rep"])] = r
    return m
base = lambda i: i.replace("acc-warm-dense", "warm-dense").replace("acc-dense", "dense")
for v in ("j110", "j113"):
    pre, post = load(f"{sys.argv[1]}/cluster/out-{v}-formal/formal"), load(f"{sys.argv[2]}/cluster/out-{v}-formal/formal")
    acc = sorted(k for k in post if "/acc-" in k[0])
    cols = ["status", "samples", "ok_samples", "measure", "target", "worst_value", "median_value", "data_hash"]
    print(f"{v}: existing (id, rep) {len(pre)}, all present: {set(pre) <= set(post)}; differences per column: "
          + ", ".join(f"{c} {sum(pre[k][c] != post[k][c] for k in pre)}" for c in cols))
    print(f"{v}: acc- records {len(acc)} ({len({k[0] for k in acc})} IDs), ok {sum(post[k]['status'] == 'ok' for k in acc)}, "
          f"data hash equal to the existing f64 case {sum(post[k]['data_hash'] == post[(base(k[0]), k[1])]['data_hash'] for k in acc)}, "
          f"worst gap {max(float(post[k]['worst_value']) for k in acc):.2e}")
