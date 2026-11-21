#!/usr/bin/env python3
"""Summaries of the #515 raw tables.

  python3 summarize.py stage0 results/stage0-<job>
  python3 summarize.py numerical results/correctness-<job>
  python3 summarize.py timing results/bench-<job>

The timing statistic is fixed in bench.jl: the cell ratio is the median of within-pair
candidate/baseline ratios; a repeatable slowdown needs all four warm x execution-order
medians above max(1.05, A/A p90); a repeatable improvement needs all four below
min(0.95, A/A p10).
"""
import argparse
import csv
import gzip
import json
from collections import Counter, defaultdict
from pathlib import Path
from statistics import median

VERSIONS = ("1.10.13", "1.13.4")


def read(path):
    path = Path(path)
    if not path.exists():
        with gzip.open(str(path) + ".gz", "rt", newline="") as stream:
            return list(csv.DictReader(stream, delimiter="\t"))
    with open(path, newline="") as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def quantile(data, prob):
    s = sorted(data)
    x = prob * (len(s) - 1)
    lo = int(x)
    hi = min(len(s) - 1, lo + 1)
    return s[lo] + (x - lo) * (s[hi] - s[lo])


def grouped(rows, keys):
    g = defaultdict(list)
    for r in rows:
        g[tuple(r[k] for k in keys)].append(r)
    return g


def stage0(root):
    out = {}
    for version in VERSIONS:
        rows = read(root / version / "stage0.tsv")
        stops = read(root / version / "stops.tsv")
        fails = [s for s in stops if s["pass"] == "0.0"]
        cells = []
        for r in rows:
            b0, nob, orc, a = (float(r[k]) for k in ("b0_med_ns", "nobudget_med_ns", "oracle_med_ns", "a_med_ns"))
            cells.append(dict(T=r["T"], case=r["case"], p=int(r["p"]), method=r["method"], status=r["status"],
                              iterations=int(r["iterations"]), proposals=int(r["stop_checks"]),
                              proposals_passed=int(r["stop_pass"]), a_status=r["a_status"],
                              b0_us=b0 / 1e3, a_us=a / 1e3, setup_share=(b0 - nob) / b0,
                              failed_check_share=(nob - orc) / b0, rest_over_a=orc / a,
                              b0_allocs=float(r["b0_allocs"]), a_allocs=float(r["a_allocs"])))
        pg = [s for s in stops if s["method"] == "PGD"]
        out[version] = dict(
            cells=cells,
            stop_checks=len(stops), failed=len(fails),
            failed_by_component=Counter(
                f"gap={float(s['gap_ratio']) + float(s['gap_noise_ratio']) > 1},map={float(s['map_ratio']) + float(s['map_noise_ratio']) > 1}"
                for s in fails),
            pgd_passes_with_working_gap_over_budget=sum(1 for s in pg if s["pass"] == "1.0" and float(s["working_gap_ratio"]) > 1),
            pgd_passes=sum(1 for s in pg if s["pass"] == "1.0"))
    return out


def numerical(root):
    summary = {}
    outputs = defaultdict(set)
    for version in VERSIONS:
        for bounds in ("auto", "yes"):
            key = f"{version}-{bounds}"
            rows = read(root / key / "parity.tsv")
            roll = read(root / key / "rollback.tsv")
            arms = {}
            for arm in ("B0", "B1", "B2"):
                a = [r for r in rows if r["arm"] == arm]
                core = [r for r in a if not r["case"].startswith("pf_")]
                ordinary = [r for r in core if r["profile"] == "ordinary"]
                admitted = [r for r in ordinary if r["status"] not in ("start_refused", "start_unresolved")]
                prof = [r for r in a if r["case"].startswith("pf_")]
                arms[arm] = dict(
                    runs=len(a),
                    ordinary_runs=len(ordinary), ordinary_admitted=len(admitted),
                    ordinary_success=sum(r["success"] == "true" for r in admitted),
                    ordinary_success_acceptable=sum(r["success"] == "true" and r["acceptable"] == "true" for r in admitted),
                    mixed_success=sum(r["success"] == "true" for r in core if r["profile"] == "mixed"),
                    tight_success=sum(r["success"] == "true" for r in core if r["profile"] == "tight"),
                    profile_runs=len(prof), profile_success=sum(r["success"] == "true" for r in prof),
                    false_success=sum(r["false_success"] == "true" for r in a),
                    over_cap_accepted=sum(r["over_cap_accepted"] == "true" for r in a),
                    trial_digest_differs=sum(r["trial_digest_equal_B0"] != "true" for r in a),
                    budget_bits_differ=sum(r["cap_bits_equal"] != "true" for r in a),
                    trial_parity_checks=sum(int(r["trial_parity_checks"]) for r in a),
                    mapping_parity_checks=sum(int(r["mapping_parity_checks"]) for r in a),
                    full_checks=sum(int(r["stop_checks"]) - int(r["prescreen_rejects"]) for r in a),
                    proposals=sum(int(r["stop_checks"]) for r in a),
                    prescreen_rejects=sum(int(r["prescreen_rejects"]) for r in a),
                    differs_from_B0=Counter(r["differs_from_B0"] for r in a),
                    decision_differences=[(r["T"], r["case"], r["method"], r["profile"], r["differs_from_B0"])
                                          for r in a if set(r["differs_from_B0"].split(",")) &
                                          {"x", "status", "success", "converged", "iterations", "membership", "trials"}],
                    status=Counter(r["status"] for r in a))
                for r in a:
                    outputs[(r["T"], r["case"], r["method"], r["profile"], arm)].add(r["output_sha256"])
            summary[key] = dict(arms=arms, rollback=[(r["T"], r["method"], r["arm"], r["callback"], r["failure"],
                                                      r["bitwise_rollback"]) for r in roll])
    summary["output_identical_across_configurations"] = all(len(v) == 1 for v in outputs.values())
    summary["cross_arm_output_identical"] = all(
        outputs[k[:4] + ("B0",)] == outputs[k] for k in outputs if k[4] != "B0")
    return summary


def cells(rows, keys, carry=()):
    result = []
    for key, rs in sorted(grouped(rows, keys).items()):
        row = dict(zip(keys, key))
        ratios = [float(r["b_ns"]) / float(r["a_ns"]) for r in rs]
        null = [float(r["aa_b_ns"]) / float(r["aa_a_ns"]) for r in rs]
        order = {f"{w}_{o}": median([float(r["b_ns"]) / float(r["a_ns"]) for r in pair])
                 for (w, o), pair in sorted(grouped(rs, ("warm_order", "order")).items())}
        row.update(pairs=len(rs), ratio=median(ratios), ratio_p10=quantile(ratios, 0.1),
                   ratio_p90=quantile(ratios, 0.9), aa=median(null), aa_p10=quantile(null, 0.1),
                   aa_p90=quantile(null, 0.9), by_order=order,
                   a_ns=median(float(r["a_ns"]) for r in rs), b_ns=median(float(r["b_ns"]) for r in rs),
                   a_ns_p10=quantile([float(r["a_ns"]) for r in rs], 0.1), a_ns_p90=quantile([float(r["a_ns"]) for r in rs], 0.9),
                   b_ns_p10=quantile([float(r["b_ns"]) for r in rs], 0.1), b_ns_p90=quantile([float(r["b_ns"]) for r in rs], 0.9),
                   a_allocs=median(float(r["a_count"]) for r in rs), b_allocs=median(float(r["b_count"]) for r in rs),
                   a_bytes=median(float(r["a_bytes"]) for r in rs), b_bytes=median(float(r["b_bytes"]) for r in rs))
        row["repeatable_slowdown"] = len(order) == 4 and min(order.values()) > max(1.05, row["aa_p90"])
        row["repeatable_improvement"] = len(order) == 4 and max(order.values()) < min(0.95, row["aa_p10"])
        for c in carry:
            vals = {r[c] for r in rs}
            assert len(vals) == 1, (key, c, vals)
            row[c] = rs[0][c]
        result.append(row)
    return result


def timing(root):
    out = {}
    carry_e2e = tuple(f"{s}_{k}" for s in ("a", "b") for k in (
        "status", "claimed", "accurate", "iterations", "gradients", "projections", "proposals",
        "full_checks", "trials", "rejected", "x_sha256"))
    for version in VERSIONS:
        e2e, fixed = [], []
        for warm in ("forward", "reverse"):
            d = root / f"{version}-{warm}"
            e2e += read(d / "solves.tsv")
            fixed += read(d / "fixed.tsv")
        out[version] = dict(
            e2e=cells(e2e, ("T", "case", "p", "design", "method", "a_arm", "b_arm"), carry_e2e),
            fixed=cells(fixed, ("T", "p", "design", "method", "op", "point", "a_arm", "b_arm"),
                        ("check_passes", "b2_screen_rejects")))
    return out


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("kind", choices=["stage0", "numerical", "timing"])
    cli.add_argument("directory", type=Path)
    o = cli.parse_args()
    data = dict(stage0=stage0, numerical=numerical, timing=timing)[o.kind](o.directory)
    print(json.dumps(data, indent=1, sort_keys=True, default=str))
