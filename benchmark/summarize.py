#!/usr/bin/env python3
"""Aggregate per-repetition medians with intervals across independent runs."""

import argparse
from collections import Counter, defaultdict
import csv
import math
from pathlib import Path
import statistics

from validate import STATUSES, fresh_output, load_series, number, validate


# Two-sided 95% Student-t critical values, as in ProximalBase's analysis.
T975 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571,
        6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262}


def mean_interval(values):
    """Return the Student-t half-width; one run has no interval."""
    if not 1 <= len(values) <= 10:
        raise ValueError("intervals require between 1 and 10 repetitions")
    if len(values) == 1 or not all(math.isfinite(value) for value in values):
        return math.nan
    return T975[len(values) - 1] * statistics.stdev(values) / math.sqrt(len(values))


def worst_value(rows):
    values = [number(row["worst_value"]) for row in rows]
    return max((value for value in values if not math.isnan(value)), default=math.nan)


def write_csv(path, fields, rows):
    with Path(path).open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def markdown(value):
    return str(value).replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def summarize(root, output, expected=1, versions=None):
    output = fresh_output(output)
    checked = validate(root, expected, versions)
    if not checked["valid"]:
        raise ValueError(f"Invalid results {root}: {checked['issues']}")
    rows, _, _ = load_series(root)
    groups = defaultdict(list)
    for (version, case, _), row in sorted(rows.items()):
        groups[(version, case)].append(row)
    results = []
    for (version, case), group in sorted(groups.items()):
        medians = [number(row["median_ns"]) for row in group]
        complete = all(math.isfinite(value) for value in medians)
        average = statistics.mean(medians) if complete else math.nan
        sd = statistics.stdev(medians) if complete and len(medians) > 1 else math.nan
        half = mean_interval(medians)
        allocations = [number(row["median_bytes"]) for row in group]
        maxima = [number(row["max_bytes"]) for row in group]
        status_counts = Counter(row["status"] for row in group)
        result = dict(julia=version, id=case, group=group[0]["group"], phase=group[0]["phase"],
                      measure=group[0]["measure"], target=number(group[0]["target"]),
                      runs=len(group), timing_runs=sum(math.isfinite(value) for value in medians),
                      mean_ns=average, sd_between_runs_ns=sd,
                      ci95_low_ns=max(0.0, average - half) if math.isfinite(half) else math.nan,
                      ci95_high_ns=average + half,
                      mean_bytes=statistics.mean(allocations),
                      median_bytes=statistics.median(allocations) if complete else math.nan,
                      max_bytes=max(maxima) if complete else math.nan,
                      worst_value=worst_value(group))
        result.update({f"status_{status}": status_counts[status] for status in STATUSES})
        results.append(result)
    write_csv(output / "summary.csv", list(results[0]), results)
    lines = ["# ProximalSolvers benchmark summary", "",
             f"Record integrity: valid. Repetitions per Julia version: {expected}.", "",
             "Time is the arithmetic mean of the per-repetition medians. Each median uses only "
             "ok samples. The Student-t interval uses independent repetitions, never individual "
             "samples. One repetition has a NaN interval. The fastest run is never selected.", "",
             "Every repetition contributes to the summary. If any repetition has no ok samples, "
             "the aggregate time and interval are NaN. Status counts include all repetitions, "
             "including those with numerical failures. Bytes are aggregated from the same ok "
             "samples; mean bytes is the mean of repetition medians. Worst accuracy is the "
             "maximum reported worst_value, ignoring NaN values; status counts retain "
             "uncertifiable results.", "",
             "Intervals include input variability and machine noise. They do not correct for "
             "correlated noise or multiple comparisons. Bytes measure Julia heap allocation, "
             "not native allocation or peak memory.", "",
             "| Case | Julia | Runs with timing / total | Mean median (ns) | 95% interval (ns) | "
             "Mean / median bytes | Worst accuracy | Status counts |",
             "|---|---|---:|---:|---:|---:|---:|---|"]
    for row in results:
        counts = ", ".join(f"{status}={row[f'status_{status}']}" for status in STATUSES
                           if row[f"status_{status}"])
        lines.append(f"| {markdown(row['id'])} | {row['julia']} | {row['timing_runs']} / {row['runs']} | "
                     f"{row['mean_ns']:.6g} | [{row['ci95_low_ns']:.6g}, {row['ci95_high_ns']:.6g}] | "
                     f"{row['mean_bytes']:.6g} / {row['median_bytes']:.6g} | "
                     f"{row['worst_value']:.6g} | {counts} |")
    (output / "SUMMARY.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root")
    parser.add_argument("out_dir")
    parser.add_argument("--expected-runs", type=int, choices=range(1, 11), default=1)
    parser.add_argument("--versions", nargs="+")
    args = parser.parse_args()
    try:
        summarize(args.root, args.out_dir, args.expected_runs, args.versions)
    except (ValueError, OSError) as error:
        parser.exit(2, f"{error}\n")
