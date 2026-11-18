#!/usr/bin/env python3
"""Set the per-case summaries of different solvers side by side, by problem and accuracy target.

The readout is descriptive: it copies values from summary.csv and does not rank solvers or
test differences between them. The matched-accuracy comparison protocol is #110.
"""

import argparse
from collections import defaultdict
import csv
import hashlib
import math
from pathlib import Path

from summarize import markdown, write_csv
from validate import HEADERS, STATUSES, fresh_output, load_series, number, same_number, validate


ISSUE_110 = "https://github.com/mlakolar/ProximalSolvers.jl/issues/110"
STATUS_FIELDS = tuple(f"status_{status}" for status in STATUSES)
COPIED = ("target", "runs", "timing_runs", "mean_ns", "ci95_low_ns", "ci95_high_ns",
          "worst_value") + STATUS_FIELDS
REQUIRED = ("julia", "id", "group", "phase", "measure") + COPIED
FIELDS = ("comparison_group julia problem phase precision start measure inputs configuration "
          "id").split() + list(COPIED) + ["timing", "exclusion"]
PRECISIONS = ("f64", "f32")


def variant_labels(variant):
    """Read precision, start and setting from a variant such as `acc-warm-dense-f64`.

    Variants without a precision suffix (the historical `R`, `B`, `tight`) encode neither.
    """
    parts = variant.split("-")
    if parts[-1] not in PRECISIONS:
        return "not encoded", "not encoded", variant
    rest = parts[:-1]
    return parts[-1], "warm" if "warm" in rest else "cold", "-".join(p for p in rest if p != "warm")


def read_summary(path):
    with (Path(path) / "summary.csv").open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        missing = [field for field in REQUIRED if field not in (reader.fieldnames or ())]
        if missing:
            raise ValueError(f"summary.csv lacks columns {missing}")
        rows = list(reader)
    summary = {}
    for row in rows:
        key = (row["julia"], row["id"])
        if key in summary:
            raise ValueError(f"summary.csv repeats {key}")
        summary[key] = row
    return summary


def exclusion(row):
    """Return why a case's time is not shown, or "" when every run met the finite target."""
    target, runs = number(row["target"]), int(row["runs"])
    if math.isnan(target):
        return "no accuracy target"
    if int(row["status_ok"]) != runs or int(row["timing_runs"]) != runs:
        return "not every run ok"
    if not number(row["worst_value"]) <= target:
        return "worst certificate above the target"
    if not math.isfinite(number(row["mean_ns"])):
        return "no finite time"
    return ""


def readout(root, summary_dir, output, expected=1, versions=None):
    checked = validate(root, expected, versions)
    if not checked["valid"]:
        raise ValueError(f"Invalid results {root}: {checked['issues']}")
    summary = read_summary(summary_dir)
    records, _, catalogs = load_series(root)
    cases = {(version, case) for version, case, _ in records}
    if summary.keys() != cases:
        raise ValueError("summary.csv does not match the records: "
                         f"missing={sorted(cases - summary.keys())}, "
                         f"extra={sorted(summary.keys() - cases)}")
    output = fresh_output(output)
    groups, ungrouped = defaultdict(list), []
    for (version, case), row in sorted(summary.items()):
        catalog = dict(zip(HEADERS["catalog"], catalogs[version][case]))
        target = math.nan if catalog["target"] == "NaN" else catalog["target"]
        if any(row[key] != catalog[key] for key in ("group", "phase", "measure")) or \
                not same_number(number(row["target"]), target):
            raise ValueError(f"summary.csv disagrees with the catalog for {version} {case}")
        if int(row["runs"]) != expected:
            raise ValueError(f"summary.csv has {row['runs']} runs for {version} {case}, "
                             f"expected {expected}")
        hashes = [records[(version, case, rep)]["data_hash"] for rep in range(1, expected + 1)]
        if "" in hashes:
            ungrouped.append((version, case, f"rep{hashes.index('') + 1:02d} has no data hash"))
            continue
        precision, start, setting = variant_labels(catalog["variant"])
        inputs = hashlib.sha256("\n".join(hashes).encode()).hexdigest()[:12]
        key = (catalog["problem"], row["phase"], version, precision, start, row["measure"],
               "NaN" if math.isnan(target) else repr(target), inputs)
        groups[key].append((f"{catalog['solver']} {setting}", case, row))
    results = []
    for index, (key, members) in enumerate(sorted(groups.items()), start=1):
        problem, phase, version, precision, start, measure, _, inputs = key
        members.sort(key=lambda member: member[:2])
        labels = [label for label, _, _ in members]
        if len(set(labels)) != len(labels):
            raise ValueError(f"cases with one configuration label share inputs in {key}: "
                             f"{[case for _, case, _ in members]}")
        for label, case, row in members:
            reason = exclusion(row)
            results.append(dict(comparison_group=index, julia=version, problem=problem, phase=phase,
                                precision=precision, start=start, measure=measure, inputs=inputs,
                                configuration=label, id=case, **{f: row[f] for f in COPIED},
                                timing="excluded" if reason else "shown", exclusion=reason))
    write_csv(output / "cross_solver.csv", FIELDS, results)
    write_report(output / "REPORT.md", results, ungrouped, expected)
    return results


def number_text(value):
    return f"{number(value):.6g}"


def write_report(path, results, ungrouped, expected):
    lines = [
        "# ProximalSolvers cross-solver readout", "",
        f"Repetitions per Julia version: {expected}. Descriptive and per case: this readout copies "
        "the per-case values of summary.csv (shown here to six significant digits; "
        "cross_solver.csv carries them unchanged) and sets cases of different solvers side by "
        "side. It does not rank solvers or test differences between them. Each interval is the "
        "case's own Student-t interval over repetitions, not a paired comparison between "
        "solvers, so overlapping or separate intervals are not a test. The matched-accuracy "
        f"comparison protocol is #110 ({ISSUE_110}).", "",
        "A group holds the cases of one Julia version, problem, phase, certificate measure and "
        "target whose input data hashes agree in every repetition (the hash covers the data, "
        "precision, penalty and start, not the solver settings). Precision, start and "
        "configuration are read from the case variant. Configurations are listed "
        "alphabetically.", "",
        "A time is shown only when every run is ok, which means the independent certificate "
        "met the finite target in every sample. Other cases show their status counts and worst "
        "certificate and no time. \"Not recorded\" marks a configuration that another group of "
        "the same problem, phase and start has and that this group lacks in the records.", ""]
    tables = defaultdict(list)
    for row in results:
        tables[(row["problem"], row["phase"])].append(row)
    for (problem, phase), rows in sorted(tables.items()):
        lines += [f"## {markdown(problem)} ({markdown(phase)})", ""]
        configurations = defaultdict(set)
        for row in rows:
            configurations[row["start"]].add(row["configuration"])
        by_group = defaultdict(dict)
        for row in rows:
            by_group[row["comparison_group"]][row["configuration"]] = row
        labels = defaultdict(set)
        for members in by_group.values():
            first = next(iter(members.values()))
            labels[tuple(first[k] for k in ("julia", "precision", "start", "measure", "target"))].add(
                first["inputs"])
        for index, members in sorted(by_group.items()):
            first = next(iter(members.values()))
            target = "none" if math.isnan(number(first["target"])) else number_text(first["target"])
            lines.append(f"### Group {index}: Julia {first['julia']}, precision {first['precision']}, "
                         f"start {first['start']}, {markdown(first['measure'])} target {target}, "
                         f"inputs {first['inputs']}")
            lines.append("")
            if len(labels[tuple(first[k] for k in ("julia", "precision", "start", "measure",
                                                   "target"))]) > 1:
                lines += ["Another group has the same labels but different inputs; the two are "
                          "not comparable.", ""]
            lines += ["| Configuration | Case | Ok runs / total | Mean time (ns) | "
                      "95% interval (ns) | Worst certificate | Status counts | Time |",
                      "|---|---|---:|---:|---:|---:|---|---|"]
            for label in sorted(configurations[first["start"]]):
                row = members.get(label)
                if row is None:
                    lines.append(f"| {markdown(label)} | | | | | | | not recorded |")
                    continue
                counts = ", ".join(f"{status}={row[f'status_{status}']}" for status in STATUSES
                                   if int(row[f"status_{status}"]))
                if row["timing"] == "shown":
                    low, high = number(row["ci95_low_ns"]), number(row["ci95_high_ns"])
                    interval = (f"[{number_text(row['ci95_low_ns'])}, {number_text(row['ci95_high_ns'])}]"
                                if math.isfinite(low) and math.isfinite(high) else "unavailable")
                    mean, note = number_text(row["mean_ns"]), "shown"
                else:
                    interval, mean, note = "", "", f"excluded: {row['exclusion']}"
                lines.append(f"| {markdown(label)} | {markdown(row['id'])} | {row['status_ok']} / "
                             f"{row['runs']} | {mean} | {interval} | "
                             f"{number_text(row['worst_value'])} | {counts} | {note} |")
            lines.append("")
    lines += ["## Cases not grouped", "",
              "Cases whose inputs cannot be identified are not set beside any other case.", "",
              "| Case | Julia | Reason |", "|---|---|---|"]
    for version, case, reason in ungrouped:
        lines.append(f"| {markdown(case)} | {version} | {reason} |")
    if not ungrouped:
        lines.append("| None | | |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", help="results directory with the process records")
    parser.add_argument("summary_dir", help="output directory of summarize.py for the same records")
    parser.add_argument("out_dir")
    parser.add_argument("--expected-runs", type=int, choices=range(1, 11), default=1)
    parser.add_argument("--versions", nargs="+")
    args = parser.parse_args()
    try:
        readout(args.root, args.summary_dir, args.out_dir, args.expected_runs, args.versions)
    except (ValueError, OSError) as error:
        parser.exit(2, f"{error}\n")
