#!/usr/bin/env python3
"""#110 A/A analysis, statistics 1-5 of PREREGISTRATION-aa110.md. Standard library only.
usage: aa_analysis.py <out dir of the job> <compare dir root> <report.md> [--reps N]
Expects <out>/<v>-A, <out>/<v>-B record dirs, <out>/work/<v>-<s>-rep<r>.tsv, and
<compare root>/<v>/comparison.csv written by benchmark/compare.py <A> <B> for each version v.
"""
import csv
import glob
import math
import os
import random
import statistics
import sys
from collections import defaultdict

out, cmp_root, report = sys.argv[1:4]
REPS = int(sys.argv[sys.argv.index("--reps") + 1]) if "--reps" in sys.argv else 10
VERS = sorted({os.path.basename(p).rsplit("-", 1)[0] for p in glob.glob(os.path.join(out, "j1*-A"))})


def primary(cid):
    parts = cid.split("/")
    if parts[0] == "cd" and parts[3] != "R":
        return True
    return parts[0] == "gradient" and parts[3].startswith("acc-")


def metrics(d):
    m = {}
    for f in glob.glob(os.path.join(d, "julia-*-metrics.tsv")):
        for r in csv.DictReader(open(f, newline=""), delimiter="\t"):
            m[(r["id"], int(r["rep"]))] = r
    return m


def work(v, s):
    w = {}
    for r in range(1, REPS + 1):
        p = os.path.join(out, "work", f"{v}-{s}-rep{r}.tsv")
        if not os.path.exists(p):
            continue
        lines = [ln for ln in open(p) if not ln.startswith("#")]
        for row in csv.DictReader(lines, delimiter="\t"):
            w[(row["id"], r)] = (row["diagnostics"], row["data_hash"], row["status"])
    return w


def boot_ci(d_by_rep, n=10000, seed=110):
    reps = sorted(d_by_rep)
    rng = random.Random(seed)
    stats = []
    for _ in range(n):
        pick = [rng.choice(reps) for _ in reps]
        vals = [x for r in pick for x in d_by_rep[r]]
        stats.append(math.exp(statistics.fmean(vals)))
    stats.sort()
    return stats[int(0.025 * n)], stats[int(0.975 * n) - 1]


L = ["# #110 A/A campaign: analysis (statistics of PREREGISTRATION-aa110.md)", ""]
summary = {}
for v in VERS:
    A, B = metrics(os.path.join(out, f"{v}-A")), metrics(os.path.join(out, f"{v}-B"))
    ids = sorted({k[0] for k in A})
    cmp = {r["id"]: r for r in csv.DictReader(open(os.path.join(cmp_root, v, "comparison.csv"), newline=""))}
    ok_both = [c for c in ids if all(A[(c, r)]["status"] == "ok" and B[(c, r)]["status"] == "ok"
                                     for r in range(1, REPS + 1))]
    hash_eq = sum(A[(c, r)]["data_hash"] == B[(c, r)]["data_hash"] for c in ids for r in range(1, REPS + 1))
    L += [f"## {v}", "", f"- Cases {len(ids)}; ok in every run on both sides: {len(ok_both)}. "
          f"Input hashes equal A vs B in {hash_eq} of {len(ids) * REPS} case-repetitions."]
    # statistic 1
    keys = list(next(iter(cmp.values())).keys()) if cmp else []
    rcol = next((k for k in keys if "ratio" in k and "low" not in k and "high" not in k), None)
    lcol = next((k for k in keys if "low" in k), None)
    hcol = next((k for k in keys if "high" in k), None)
    rows, cnt = [], defaultdict(lambda: defaultdict(int))
    for c in ids:
        r = cmp.get(c, {})
        try:
            ratio, lo, hi = float(r[rcol]), float(r[lcol]), float(r[hcol])
        except (KeyError, TypeError, ValueError):
            ratio = lo = hi = float("nan")
        cls = "primary" if primary(c) else "diagnostic"
        if c not in ok_both:
            cnt[cls]["excluded (not ok in every run)"] += 1
            rows.append((cls, c, "", "", "excluded"))
            continue
        side = "above 1" if lo > 1 else "below 1" if hi < 1 else "contains 1"
        cnt[cls][side] += 1
        rows.append((cls, c, f"{ratio:.4f}", f"[{lo:.4f}, {hi:.4f}]", side))
    for cls in ("primary", "diagnostic"):
        L.append(f"- Per-case intervals, {cls}: " + ", ".join(f"{k} {n}" for k, n in sorted(cnt[cls].items())))
    # statistics 2-3
    subsets = {"all primary": lambda c: True, "Float64 primary": lambda c: c.endswith("f64/call"),
               "Float32 primary": lambda c: c.endswith("f32/call")}
    L += ["", "| Subset | Cases | G = exp(mean log B/A) | 95% bootstrap over repetitions | Cases with ratio > 1 / < 1 |",
          "|---|---:|---:|---:|---:|"]
    for name, pred in subsets.items():
        cs = [c for c in ok_both if primary(c) and pred(c)]
        if not cs:
            continue
        d = {r: [math.log(float(B[(c, r)]["median_ns"])) - math.log(float(A[(c, r)]["median_ns"])) for c in cs]
             for r in range(1, REPS + 1)}
        g = math.exp(statistics.fmean([x for r in d for x in d[r]]))
        lo, hi = boot_ci(d)
        ups = sum(float(cmp[c][rcol]) > 1 for c in cs)
        L.append(f"| {name} | {len(cs)} | {g:.4f} | [{lo:.4f}, {hi:.4f}] | {ups} / {len(cs) - ups} |")
        summary[(v, name)] = (g, lo, hi, ups, len(cs))
    g, lo, hi, ups, n = summary.get((v, "Float64 primary"), (float("nan"),) * 3 + (0, 0))
    same = max(ups, n - ups) / n if n else float("nan")
    side_ok = (g > 1.10 and ups / n >= 0.9) or (g < 1 / 1.10 and (n - ups) / n >= 0.9) if n else False
    smaller = (g > 1.03 or g < 0.97) and (lo > 1 or hi < 1)
    verdict = ("RECURS" if side_ok else
               "did not recur in this campaign" + ("; a smaller installation offset" if smaller else ""))
    L += ["", f"- §12 offset reading (Float64 primary): G = {g:.4f}, share of cases on the majority side "
          f"{same:.2f} → **{verdict}**."]
    # statistic 4
    wa, wb = work(v, "A"), work(v, "B")
    pairs = [(c, r) for c in ids for r in range(1, REPS + 1)]
    have = [k for k in pairs if k in wa and k in wb]
    uneq = [k for k in have if wa[k][0] != wb[k][0]]
    hmis = [k for k in have if wa[k][1] != A[k]["data_hash"] or wb[k][1] != B[k]["data_hash"]]
    L.append(f"- Work receipts: {len(have)} of {len(pairs)} case-repetitions present on both sides; "
             f"work counters unequal A vs B in {len(uneq)}; receipt data hash differs from the timed record in {len(hmis)}.")
    for k in uneq[:10]:
        L.append(f"  - unequal: `{k[0]}` rep {k[1]}: A `{wa[k][0]}` / B `{wb[k][0]}`")
    L += ["", "| Class | Case | B/A ratio | 95% interval | Interval |", "|---|---|---:|---:|---|"]
    L += [f"| {a} | `{b}` | {c} | {d} | {e} |" for a, b, c, d, e in sorted(rows)]
    L.append("")
open(report, "w").write("\n".join(L) + "\n")
print(report)
