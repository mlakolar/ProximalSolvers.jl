#!/usr/bin/env python3
"""Validate matched Discovery outputs and retain every failed request."""
import argparse
import csv
import json
import math
from pathlib import Path
from statistics import median

METHODS = ("apg", "hybrid", "libslope")


def read(path):
    with path.open() as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def summarize(folder):
    rows = [r for path in sorted(folder.glob("worker-[1-4].tsv")) for r in read(path)]
    levels = [r for path in sorted(folder.glob("worker-[1-4].tsv.levels.tsv")) for r in read(path)]
    expected = {(case, block, method) for case in range(1, 221)
                for block in range(1, 4) for method in METHODS}
    by_key = {}
    for row in rows:
        key = (int(row["case"]), int(row["round"]), row["method"])
        assert key not in by_key
        by_key[key] = row
        if row["status"] == "ok":
            assert math.isfinite(float(row["seconds"])) and float(row["seconds"]) > 0
            assert int(row["julia_bytes"]) > 0
            if row["method"] == "libslope":
                assert int(row["converged"]) == -1 # unavailable, never manufactured
                assert int(row["cpp_bytes"]) > 0 and int(row["cpp_calls"]) > 0
            elif row["method"] == "hybrid":
                assert int(row["pg_steps"]) + int(row["cd_sweeps"]) == int(row["iterations"])
        assert 0 <= int(row["returned"]) <= int(row["depth"])
    assert set(by_key) == expected, "missing or unexpected requests"
    groups = {key: [] for key in expected}
    for row in levels:
        key = (int(row["case"]), int(row["round"]), row["method"])
        groups[key].append(row)
    for key, group in groups.items():
        row = by_key[key]
        assert sorted(int(r["level"]) for r in group) == list(range(1, int(row["returned"]) + 1))
        passed = row["status"] == "ok" and len(group) == int(row["depth"])
        for r in group:
            valid = (math.isfinite(float(r["gap"])) and float(r["gap"]) <= 1e-6 and
                     math.isfinite(float(r["residual"])) and float(r["residual"]) <= 1e-7)
            assert valid == (r["certified"] == "true")
            passed = passed and valid
        assert passed == (row["certified"] == "true")
    cases = {}
    for case in range(1, 221):
        cases[case] = {m: [by_key[(case, block, m)] for block in range(1, 4)] for m in METHODS}
    strata = {}
    for case, methods in cases.items():
        r = methods["apg"][0]
        phase = "main" if int(r["seed"]) <= 3 else "confirmation"
        key = (r["cohort"], phase, float(r["rho"]), r["storage"])
        strata.setdefault(key, []).append(methods)
    output = []
    for (cohort, phase, rho, storage), pairs in sorted(strata.items()):
        item = {"cohort": cohort, "phase": phase, "rho": rho, "storage": storage,
                "requested_cases": len(pairs), "requested_timing_blocks": 3 * len(pairs)}
        item["methods"] = {}
        for method in METHODS:
            selected = [r for p in pairs for r in p[method]]
            good = [r for r in selected if r["certified"] == "true"]
            item["methods"][method] = {
                "certified_blocks": len(good),
                "fit_accuracy_blocks": sum(len(groups[(int(r["case"]), int(r["round"]), method)]) == int(r["depth"]) and
                    all(v["certified"] == "true" for v in groups[(int(r["case"]), int(r["round"]), method)]) for r in selected),
                "protocol_failure_blocks": sum(r["status"] != "ok" for r in selected),
                "internal_flag_failure_blocks": None if method == "libslope" else sum(r["converged"] != r["depth"] for r in selected),
                "reported_converged_levels": None if method == "libslope" else sum(int(r["converged"]) for r in selected),
                "requested_levels": sum(int(r["depth"]) for r in selected),
                "max_gap": max(float(r["max_gap"]) for r in selected),
                "max_residual": max(float(r["max_residual"]) for r in selected),
                "median_ms": 1000 * median(float(r["seconds"]) for r in good) if good else None,
                "median_julia_bytes": median(int(r["julia_bytes"]) for r in good) if good else None,
                "median_cpp_requested_bytes": median(int(r["cpp_bytes"]) for r in good) if method == "libslope" and good else None,
                "blocks_with_fallback": sum(int(r["fallbacks"]) > 0 for r in selected) if method == "hybrid" else None,
            }
        item["paired_over_apg"] = {}
        for method in ("hybrid", "libslope"):
            valid = [p for p in pairs if all(r["certified"] == "true" for m in ("apg", method) for r in p[m])]
            time_ratios = [median(float(r["seconds"]) for r in p[method]) /
                           median(float(r["seconds"]) for r in p["apg"]) for p in valid]
            comparison = {"certified_cases": len(valid), "time_wins": sum(r < 1 for r in time_ratios),
                          "median_time_ratio": median(time_ratios) if valid else None}
            if method == "hybrid":
                allocations = [median(int(r["julia_bytes"]) for r in p[method]) /
                               median(int(r["julia_bytes"]) for r in p["apg"]) for p in valid]
                comparison.update(median_julia_allocation_ratio=median(allocations) if valid else None,
                                  allocation_wins=sum(r < 1 for r in allocations))
            item["paired_over_apg"][method] = comparison
        output.append(item)
    failures = [r for r in rows if r["certified"] != "true" or
                (r["method"] != "libslope" and r["converged"] != r["depth"])]
    result = {"cases": 220, "timing_blocks_per_method": 660,
              "requested_levels_all_methods": sum(int(r["depth"]) for r in rows),
              "returned_levels_all_methods": len(levels), "strata": output, "failed_or_flagged_requests": failures,
              "acceptance": {"relative_dual_gap": 1e-6, "null_gradient_normalized_residual": 1e-7},
              "allocation_scope": "Julia GC allocation bytes for Julia and bridge buffers; wrapped static-native malloc/calloc/realloc requests and operator new for libslope. DSOs/runtime allocations are not a complete native-heap profile; RSS is measured separately. No cross-runtime heap-byte ratio is asserted."}
    def rss_records(rssfile):
        rss = read(rssfile)
        assert {(int(r["case"]), r["method"]) for r in rss} == {(i, m) for i in (1, 20, 169, 171) for m in METHODS}
        for r in rss:
            expected_levels = 6 if int(r["case"]) == 1 else 12
            valid = (int(r["returned"]) == expected_levels and
                     math.isfinite(float(r["max_gap"])) and float(r["max_gap"]) <= 1e-6 and
                     math.isfinite(float(r["max_residual"])) and float(r["max_residual"]) <= 1e-7)
            assert valid == (r["certified"] == "true")
            values = (folder / r.get("timing_file", "rss-{}-{}.time".format(r["case"], r["method"]))).read_text().strip().split()
            assert len(values) == 3 and values[2] == "0"
            r["peak_process_mib"] = int(values[0]) / 1024
            r["process_seconds"] = float(values[1])
        return rss
    for name, filename in (("rss", "rss-validation.tsv"), ("rss_primary", "rss-validation-v1.tsv")):
        if (folder / filename).exists():
            result[name] = rss_records(folder / filename)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=Path(__file__).resolve().parent / "evidence")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    result = summarize(args.input)
    target = args.output or args.input / "summary.json"
    if args.check:
        assert json.loads(target.read_text()) == result
    else:
        target.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print("Validated {} requests / {} returned levels; {} failed or internally flagged requests retained.".format(
        3 * result["timing_blocks_per_method"], result["returned_levels_all_methods"], len(result["failed_or_flagged_requests"])))


if __name__ == "__main__":
    main()
