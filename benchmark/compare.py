#!/usr/bin/env python3
"""Compare revisions using paired after/before ratios of repetition medians."""

import argparse
from collections import defaultdict
import json
import math
import statistics

from summarize import markdown, mean_interval, worst_value, write_csv
from validate import MATCH_SETTINGS, fresh_output, load_series, number, validate


FIELDS = (
    "julia id phase paired_runs before_mean_median_ns after_mean_median_ns "
    "paired_time_ratio ci95_low ci95_high timing_assessment before_worst_value "
    "after_worst_value worst_value_change before_median_bytes after_median_bytes "
    "median_bytes_change before_max_bytes after_max_bytes unexpected_allocation"
).split()


def load(root, expected):
    checked = validate(root, expected)
    if not checked["valid"]:
        raise ValueError(f"Invalid results {root}: {checked['issues']}")
    return load_series(root)


def exclusion_reasons(rows, expected):
    by_rep = {int(row["rep"]): row for row in rows}
    reasons = []
    for rep in range(1, expected + 1):
        row = by_rep.get(rep)
        if row is None:
            reasons.append(f"rep{rep:02d}: missing case")
        elif row["status"] != "ok":
            reasons.append(f"rep{rep:02d}: {row['status']}")
        elif not math.isfinite(number(row["median_ns"])) or number(row["median_ns"]) <= 0:
            reasons.append(f"rep{rep:02d}: nonpositive or unavailable median_ns")
    return reasons


def compare(before_root, after_root, output, expected=1):
    output = fresh_output(output)
    before, old_configs, old_catalogs = load(before_root, expected)
    after, new_configs, new_catalogs = load(after_root, expected)
    coverage = dict(shared_measurements=len(before.keys() & after.keys()),
                    before_only=sorted(before.keys() - after.keys()),
                    after_only=sorted(after.keys() - before.keys()), excluded=[])
    grouped = defaultdict(lambda: ([], []))
    for side, rows in enumerate((before, after)):
        for (version, case, _), row in sorted(rows.items()):
            grouped[(version, case)][side].append(row)
    for (version, case), (old, new) in sorted(grouped.items()):
        old_reasons, new_reasons = exclusion_reasons(old, expected), exclusion_reasons(new, expected)
        if old_reasons or new_reasons:
            coverage["excluded"].append(dict(julia=version, id=case,
                                              before=old_reasons, after=new_reasons))
    (output / "coverage.json").write_text(json.dumps(coverage, indent=2) + "\n", encoding="utf-8")
    if old_configs.keys() != new_configs.keys():
        raise ValueError("Julia version coverage differs; inspect coverage.json")
    differences = [(version, key) for version in sorted(old_configs) for key in MATCH_SETTINGS
                   if old_configs[version][key] != new_configs[version][key]]
    if differences:
        raise ValueError(f"Comparison series settings differ: {differences}")
    if coverage["before_only"] or coverage["after_only"]:
        raise ValueError("Case coverage differs; inspect coverage.json")
    definitions = [(version, case) for version in sorted(old_catalogs)
                   for case in sorted(old_catalogs[version])
                   if old_catalogs[version][case] != new_catalogs[version][case]]
    if definitions:
        raise ValueError(f"Catalog/certificate definitions differ (including measure/target): {definitions}")
    hashes = [key for key in sorted(before) if before[key]["data_hash"] != after[key]["data_hash"]]
    if hashes:
        raise ValueError(f"data_hash mismatch for pairs (julia, id, rep): {hashes}")
    excluded = {(row["julia"], row["id"]) for row in coverage["excluded"]}
    results = []
    for (version, case), (old, new) in sorted(grouped.items()):
        if (version, case) in excluded:
            continue
        old_by_rep = {int(row["rep"]): row for row in old}
        new_by_rep = {int(row["rep"]): row for row in new}
        pairs = [(old_by_rep[rep], new_by_rep[rep]) for rep in range(1, expected + 1)]
        old_times = [number(left["median_ns"]) for left, _ in pairs]
        new_times = [number(right["median_ns"]) for _, right in pairs]
        logs = [math.log(new_time) - math.log(old_time)
                for old_time, new_time in zip(old_times, new_times)]
        mu, half = statistics.mean(logs), mean_interval(logs)
        old_bytes = statistics.median(number(row["median_bytes"]) for row in old)
        new_bytes = statistics.median(number(row["median_bytes"]) for row in new)
        old_worst, new_worst = worst_value(old), worst_value(new)
        unexpected = old[0]["phase"] == "workspace" and any(
            number(left["max_bytes"]) == 0 and number(right["max_bytes"]) > 0 for left, right in pairs)
        assessment = ("single run; exploratory" if expected == 1 else
                      "inconclusive" if mu - half <= 0 <= mu + half else
                      "faster" if mu < 0 else "slower")
        results.append(dict(julia=version, id=case, phase=old[0]["phase"], paired_runs=len(pairs),
                            before_mean_median_ns=statistics.mean(old_times),
                            after_mean_median_ns=statistics.mean(new_times),
                            paired_time_ratio=math.exp(mu), ci95_low=math.exp(mu - half),
                            ci95_high=math.exp(mu + half), timing_assessment=assessment,
                            before_worst_value=old_worst, after_worst_value=new_worst,
                            worst_value_change=new_worst - old_worst,
                            before_median_bytes=old_bytes, after_median_bytes=new_bytes,
                            median_bytes_change=new_bytes - old_bytes,
                            before_max_bytes=max(number(row["max_bytes"]) for row in old),
                            after_max_bytes=max(number(row["max_bytes"]) for row in new),
                            unexpected_allocation=unexpected))
    write_csv(output / "comparison.csv", FIELDS, results)
    lines = ["# ProximalSolvers revision comparison", "",
             "Ratios are after/before; a ratio below one indicates a shorter time after. "
             "Intervals use paired log ratios of per-repetition medians, matched by Julia "
             "version, case and repetition. All repetitions of an included case must be ok.", "",
             "Single-run ratios are exploratory and have no confidence interval. An interval "
             "containing one is inconclusive. Excluded cases are not ties.", "",
             "Intervals include input variability and machine noise. They do not correct for "
             "correlated noise or multiple comparisons. Bytes measure Julia heap allocation, "
             "not native allocation or peak memory. Median bytes is the median of repetition "
             "medians. Unexpected allocations flag workspace pairs with zero bytes before "
             "and positive bytes after.", "",
             f"Included cases: {len(results)}. Excluded cases: {len(excluded)}.", "",
             "| Case | Julia | After/before [95% interval] | Worst accuracy before / after | "
             "Median bytes before / after | Assessment |",
             "|---|---|---:|---:|---:|---|"]
    for row in results:
        interval = ("unavailable" if expected == 1 else
                    f"{row['ci95_low']:.6g}, {row['ci95_high']:.6g}")
        note = row["timing_assessment"] + ("; unexpected warmed allocation"
                                           if row["unexpected_allocation"] else "")
        lines.append(f"| {markdown(row['id'])} | {row['julia']} | {row['paired_time_ratio']:.6g} "
                     f"[{interval}] | {row['before_worst_value']:.6g} / {row['after_worst_value']:.6g} | "
                     f"{row['before_median_bytes']:.6g} / {row['after_median_bytes']:.6g} | {note} |")
    if not results:
        lines.append("| No eligible cases | | | | | |")
    lines += ["", "## Excluded cases", "",
              "| Case | Julia | Before reasons | After reasons |", "|---|---|---|---|"]
    for row in coverage["excluded"]:
        lines.append(f"| {markdown(row['id'])} | {row['julia']} | "
                     f"{markdown('; '.join(row['before']) or 'none')} | "
                     f"{markdown('; '.join(row['after']) or 'none')} |")
    if not excluded:
        lines.append("| None | | | |")
    (output / "REPORT.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before")
    parser.add_argument("after")
    parser.add_argument("out")
    parser.add_argument("--expected-runs", type=int, choices=range(1, 11), default=1)
    args = parser.parse_args()
    try:
        compare(args.before, args.after, args.out, args.expected_runs)
    except (ValueError, OSError) as error:
        parser.exit(2, f"{error}\n")
