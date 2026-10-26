#!/usr/bin/env python3
"""Regenerate and validate the bounded hybrid decision, including failed levels."""
import argparse
import csv
import hashlib
import itertools
import json
import math
import re
from pathlib import Path
from statistics import median

ROOT = Path(__file__).resolve().parent
KEY = ("seed", "rho", "storage", "sparsity", "weights", "depth")


def read(path):
    with path.open() as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def summarize(name, seeds):
    rows = read(ROOT / "evidence" / f"{name}.tsv")
    levels = read(ROOT / "evidence" / f"{name}.tsv.levels.tsv")
    expected = set(itertools.product(map(str, seeds), ("0.0", "0.99"),
                                    ("dense", "sparse"), ("8", "32"),
                                    ("linear", "stepped"), ("6", "12"),
                                    ("apg", "hybrid")))
    by_key = {}
    for row in rows:
        key = tuple(row[k] for k in (*KEY, "method"))
        assert key not in by_key
        by_key[key] = row
        assert float(row["tol"]) == 1e-8
        assert 0 < int(row["full_products"]) <= int(row["products"])
        assert float(row["seconds"]) > 0 and int(row["bytes"]) > 0
    assert set(by_key) == expected
    groups = {key: [] for key in expected}
    for level in levels:
        groups[tuple(level[k] for k in (*KEY, "method"))].append(level)
    for key, group in groups.items():
        row = by_key[key]
        depth = int(row["depth"])
        assert sorted(int(x["level"]) for x in group) == list(range(1, depth + 1))
        assert depth == int(row["levels"])
        assert sum(x["converged"] == "true" for x in group) == int(row["converged"])
        assert sum(float(x["gap"]) <= 1e-6 for x in group) == int(row["certified"])
        assert sum(int(x["iterations"]) for x in group) == int(row["iterations"])
        assert max(float(x["gap"]) for x in group) == float(row["max_gap"])
        assert max(float(x["residual"]) for x in group) == float(row["max_residual"])
        for x in group:
            assert 0 <= int(x["iterations"]) <= 10_000
            assert 0 <= int(x["nonzeros"]) <= int(x["working_size"]) <= 120
            assert 0 <= int(x["clusters"]) <= int(x["nonzeros"])
            assert math.isfinite(float(x["gap"]))
    totals = {}
    for method in ("apg", "hybrid"):
        selected = [r for r in rows if r["method"] == method]
        totals[method] = {
            "paths": len(selected),
            **{field: sum(int(r[field]) for r in selected)
               for field in ("levels", "converged", "certified")},
            "max_gap": max(float(r["max_gap"]) for r in selected),
        }
    strata = []
    for rho, storage in itertools.product(("0.0", "0.99"), ("dense", "sparse")):
        pairs = [{r["method"]: r for r in pair} for key, pair in itertools.groupby(
            sorted(rows, key=lambda r: tuple(r[k] for k in KEY)),
            key=lambda r: tuple(r[k] for k in KEY)) if key[1:3] == (rho, storage)]
        certified = [p for p in pairs if all(
            r["converged"] == r["certified"] == r["levels"] for r in p.values())]
        ratios = {}
        observations = {}
        if certified:
            for metric in ("seconds", "bytes", "products", "full_products", "entries"):
                ratios[metric] = median(float(p["hybrid"][metric]) / float(p["apg"][metric])
                                        for p in certified)
            ratios["entries_including_clusters"] = median(
                (int(p["hybrid"]["entries"]) + int(p["hybrid"]["cluster_entries"])) /
                int(p["apg"]["entries"]) for p in certified)
            observations = {
                "hybrid_time_wins": sum(float(p["hybrid"]["seconds"]) < float(p["apg"]["seconds"])
                                        for p in certified),
                "hybrid_allocation_wins": sum(int(p["hybrid"]["bytes"]) < int(p["apg"]["bytes"])
                                              for p in certified),
                "median_path_ms": {m: 1000 * median(float(p[m]["seconds"]) for p in certified)
                                   for m in ("apg", "hybrid")},
                "median_cumulative_allocation_mib": {
                    m: median(int(p[m]["bytes"]) for p in certified) / 2**20
                    for m in ("apg", "hybrid")},
            }
        strata.append({"rho": float(rho), "storage": storage,
                       "requested_pairs": len(pairs), "certified_pairs": len(certified),
                       "observations_on_certified_pairs": observations,
                       "median_hybrid_over_apg_on_certified_pairs": ratios})
    failures = [r for r in levels if r["converged"] != "true" or float(r["gap"]) > 1e-6]
    accuracy_pass = all(t["converged"] == t["certified"] == t["levels"]
                        for t in totals.values())
    work_pass = all(s["median_hybrid_over_apg_on_certified_pairs"].get("full_products", 1) <= .5
                    for s in strata if s["rho"] == .99)
    return {"totals": totals, "strata": strata, "failed_levels": failures,
            "accuracy_gate_pass": accuracy_pass, "work_gate_pass": work_pass,
            "promote_to_production": accuracy_pass and work_pass}


def specialist_controls():
    """Within-build solver comparisons from the prior, independent study."""
    output = {}
    for cohort, expected_pairs in (("main", 36), ("confirmation", 16)):
        folder = ROOT.parent / "first_order" / "evidence" / "20261025" / cohort
        rows = [r for path in sorted(folder.glob("calls-*.csv"))
                for r in csv.DictReader(path.open())]
        pairs = {}
        for row in rows:
            key = tuple(row[k] for k in ("n", "p", "rho", "sparsity", "weights", "seed", "round"))
            assert row["method"] not in pairs.setdefault(key, {})
            pairs[key][row["method"]] = row
        strata = []
        for rho in ("0.0", "0.9"):
            selected = [p for k, p in pairs.items() if k[2] == rho]
            assert len(selected) == expected_pairs
            for pair in selected:
                assert all(pair[m]["valid"] == "true" and pair[m]["returned"] == "12"
                           for m in ("native_hybrid_strong", "native_pgd_strong", "native_fista_strong"))
            comparisons = {}
            for reference in ("native_pgd_strong", "native_fista_strong"):
                ratios = [float(p["native_hybrid_strong"]["seconds"]) / float(p[reference]["seconds"])
                          for p in selected]
                comparisons[reference] = {"median_time_ratio": median(ratios),
                                          "hybrid_time_wins": sum(r < 1 for r in ratios)}
            strata.append({"rho": float(rho), "paired_timing_blocks": len(selected),
                           "hybrid_strong_over_reference": comparisons})
        output[cohort] = strata
    return {"source_commit": "a9899cbf3677ea63236d54dc18626ad3a5aeddc6",
            "libslope_version": "6.5.2", "n": 1000, "p": 2000, "cohorts": output,
            "note": "Historical within-build controls; not a comparison with the current screened APG engine."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    hashes = re.findall(r'^"([^"]+\.jl)" = "([0-9a-f]{64})"$',
                        (ROOT / "evidence" / "environment.toml").read_text(), re.M)
    assert len(hashes) == 3
    for path, digest in hashes:
        # The production hash identifies the measured revision; later solver
        # changes must not invalidate historical evidence. Benchmark kernels
        # themselves stay paired with these recorded numerical results.
        if path.startswith("src/"):
            continue
        assert hashlib.sha256((ROOT.parents[2] / path).read_bytes()).hexdigest() == digest, \
            f"measured source changed: {path}"
    calibration = read(ROOT / "evidence" / "calibration-v1.tsv")
    final = read(ROOT / "evidence" / "main.tsv")
    assert len(calibration) == len(final) == 192
    for before, after in zip(calibration, final):
        assert all(before[k] == after[k] for k in (*KEY, "method", "iterations", "products",
                   "entries", "cluster_entries", "converged", "certified", "max_gap", "max_residual"))
    result = {"main": summarize("main", (1, 2, 3)),
              "confirmation": summarize("confirmation", (11, 12))}
    result["decision"] = "go" if all(r["promote_to_production"] for r in result.values()) else "no-go"
    result["specialist_controls"] = specialist_controls()
    target = ROOT / "summary.json"
    if args.write:
        target.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    else:
        assert json.loads(target.read_text()) == result, "summary does not match raw evidence"
    print(f"Hybrid pilot: {result['decision']}; all requested paths and failures accounted for.")


if __name__ == "__main__":
    main()
