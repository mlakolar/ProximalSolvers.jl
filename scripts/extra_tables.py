#!/usr/bin/env python3
"""(1) status / input-hash deltas between the existing (637f06a) and fresh (a0a06477) series on shared
cases; (2) eligible timing table of the fresh series (mean of repetition medians, Student-t 95% half-width
as % of mean, copied from cross_solver.csv). Descriptive only.
usage: extra_tables.py existing_cross.csv fresh_cross.csv existing_records_dir fresh_records_dir out.md
"""
import csv
import glob
import os
import statistics
import sys
from collections import defaultdict

ex_csv, fr_csv, ex_dir, fr_dir, out = sys.argv[1:6]


def load(p):
    d = {}
    for r in csv.DictReader(open(p, newline="")):
        d.setdefault((r["julia"], r["id"]), r)
    return d


def hashes(root):
    h = defaultdict(dict)
    for f in glob.glob(os.path.join(root, "julia-*-metrics.tsv")):
        jl = os.path.basename(f).split("-")[1]
        for r in csv.DictReader(open(f, newline=""), delimiter="\t"):
            h[(jl, r["id"])][int(r["rep"])] = r["data_hash"]
    return h


ex, fr = load(ex_csv), load(fr_csv)
hx, hf = hashes(ex_dir), hashes(fr_dir)
L = ["# Existing (637f06a) vs fresh (a0a06477): status and inputs on shared cases", ""]
L.append("Same CPU kind (Xeon E5-2640 v4), Julia 1.10.13 / 1.13.3, harness hashes differ (cases.jl gained "
         "cases). Descriptive: these are two revisions in separate jobs, not a paired comparison.")
for jl in sorted({k[0] for k in fr}):
    shared = sorted(k for k in fr if k[0] == jl and k in ex)
    same_in = sum(hx[k] == hf[k] for k in shared)
    changed = [k for k in shared if ex[k]["status_ok"] != fr[k]["status_ok"] or ex[k]["worst_value"] != fr[k]["worst_value"]]
    L += ["", f"## Julia {jl}: {len(shared)} shared cases; per-repetition input hashes equal in {same_in}; "
          f"ok count or worst certificate differs in {len(changed)}", ""]
    if changed:
        L += ["| Case | Ok runs existing → fresh | Worst certificate existing → fresh |", "|---|---:|---:|"]
        for k in changed:
            L.append(f"| `{k[1]}` | {ex[k]['status_ok']} → {fr[k]['status_ok']} | "
                     f"{float(ex[k]['worst_value']):.3g} → {float(fr[k]['worst_value']):.3g} |")
    new = sorted(k[1] for k in fr if k[0] == jl and k not in ex)
    L += ["", f"New in the fresh catalog ({len(new)}): " + ", ".join(f"`{i}`" for i in new)]

L += ["", "# Eligible timings, fresh series", "",
      "Mean of the 10 repetition medians in µs, and the case's own 95% interval half-width as % of the mean. "
      "Only cases with a finite target and every run ok. Per-case intervals over repetitions, not "
      "cross-solver comparisons.", ""]
probs = ["lasso", "lasso-B", "lasso-C", "lasso-D", "lasso-weighted", "group-lasso"]
for jl in sorted({k[0] for k in fr}):
    cells = defaultdict(dict)
    hw = []
    for k, r in fr.items():
        if k[0] != jl or r["timing"] != "shown":
            continue
        _, prob, solver, variant, _ = r["id"].split("/")
        m = float(r["mean_ns"])
        h = (float(r["ci95_high_ns"]) - m) / m * 100
        hw.append(h)
        cells[f"{solver} {variant}"][prob] = f"{m/1000:.3g} (±{h:.0f}%)"
    L += [f"## Julia {jl} ({len(hw)} timed cases; half-width median {statistics.median(hw):.1f}%, "
          f"range {min(hw):.1f}–{max(hw):.1f}%)", "",
          "| Configuration | " + " | ".join(probs) + " |", "|---|" + "---:|" * len(probs)]
    for cfg in sorted(cells):
        L.append(f"| {cfg} | " + " | ".join(cells[cfg].get(p, "") for p in probs) + " |")
    L.append("")
open(out, "w").write("\n".join(L) + "\n")
print(out)
