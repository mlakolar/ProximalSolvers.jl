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
import statistics

from summarize import markdown, write_csv
from validate import HEADERS, STATUSES, fresh_output, load_series, number, same_number, validate


ISSUE_110 = "https://github.com/mlakolar/ProximalSolvers.jl/issues/110"
STATUS_FIELDS = tuple(f"status_{status}" for status in STATUSES)
COPIED = ("target", "runs", "timing_runs", "mean_ns", "ci95_low_ns", "ci95_high_ns",
          "worst_value") + STATUS_FIELDS
REQUIRED = ("julia", "id", "group", "phase", "measure") + COPIED
FIELDS = ("comparison_group julia problem phase precision start measure input_mode inputs "
          "configuration id").split() + list(COPIED) + ["timing", "exclusion"]
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


def check_records(row, rows, statuses):
    """List the fields among the status counts, timing runs, worst certificate and mean time in
    which a summary row differs from the validated records. This checks those aggregates only,
    not the intervals or the identity of the series."""
    medians = [number(rep["median_ns"]) for rep in rows]
    values = [number(rep["worst_value"]) for rep in rows]
    observed = dict(timing_runs=sum(math.isfinite(m) for m in medians),
                    mean_ns=statistics.mean(medians) if all(map(math.isfinite, medians)) else math.nan,
                    worst_value=max((v for v in values if not math.isnan(v)), default=math.nan))
    observed.update({f"status_{status}": statuses[status] for status in STATUSES})
    return [key for key, value in observed.items() if not same_number(number(row[key]), value)]


def exclusion(row):
    """Return why a case's time is not shown, or "" when every run is ok against a finite target
    and the mean time is finite."""
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
    statuses = {(entry["julia"], entry["id"]): entry["status_counts"]
                for entry in checked["case_status_counts"]}
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
        reps = [records[(version, case, rep)] for rep in range(1, expected + 1)]
        differ = check_records(row, reps, statuses[(version, case)])
        if differ:
            raise ValueError(f"summary.csv disagrees with the records for {version} {case}: {differ}")
        precision, start, setting = variant_labels(catalog["variant"])
        labels = dict(julia=version, problem=catalog["problem"], phase=row["phase"],
                      precision=precision, start=start, measure=row["measure"],
                      input_mode=catalog["inputs"], configuration=f"{catalog['solver']} {setting}",
                      id=case, **{field: row[field] for field in COPIED})
        hashes = [rep["data_hash"] for rep in reps]
        if "" in hashes:
            ungrouped.append(dict(labels, comparison_group="", inputs="unknown", timing="excluded",
                                  exclusion=f"rep{hashes.index('') + 1:02d} has no data hash; "
                                            "inputs unknown"))
            continue
        inputs = hashlib.sha256("\n".join(hashes).encode()).hexdigest()[:12]
        key = (catalog["problem"], row["phase"], version, precision, start, row["measure"],
               "NaN" if math.isnan(target) else repr(target), catalog["inputs"], inputs)
        groups[key].append(dict(labels, inputs=inputs))
    results = []
    for index, (key, members) in enumerate(sorted(groups.items()), start=1):
        members.sort(key=lambda member: (member["configuration"], member["id"]))
        names = [member["configuration"] for member in members]
        if len(set(names)) != len(names):
            raise ValueError(f"cases with one configuration label share inputs in {key}: "
                             f"{[member['id'] for member in members]}")
        for member in members:
            reason = exclusion(member)
            results.append(dict(member, comparison_group=index,
                                timing="excluded" if reason else "shown", exclusion=reason))
    write_csv(output / "cross_solver.csv", FIELDS, results + ungrouped)
    write_report(output / "REPORT.md", results, ungrouped, expected)
    return results + ungrouped


def number_text(value):
    return f"{number(value):.6g}"


def target_text(value):
    return "none" if math.isnan(number(value)) else number_text(value)


def placeholder(row, configuration):
    """The known labels of a configuration in a group, for matching an ungrouped attempt."""
    target = number(row["target"])
    return (row["problem"], row["phase"], row["julia"], row["precision"], row["start"],
            row["measure"], "NaN" if math.isnan(target) else repr(target), row["input_mode"],
            configuration)


def status_text(row):
    return ", ".join(f"{status}={row[f'status_{status}']}" for status in STATUSES
                     if int(row[f"status_{status}"]))


def case_line(row):
    if row["timing"] == "shown":
        low, high = number(row["ci95_low_ns"]), number(row["ci95_high_ns"])
        interval = (f"[{number_text(row['ci95_low_ns'])}, {number_text(row['ci95_high_ns'])}]"
                    if math.isfinite(low) and math.isfinite(high) else "unavailable")
        mean, note = number_text(row["mean_ns"]), "shown"
    else:
        interval, mean, note = "", "", f"excluded: {row['exclusion']}"
    return (f"| {markdown(row['configuration'])} | {markdown(row['id'])} | {row['status_ok']} / "
            f"{row['runs']} | {mean} | {interval} | {number_text(row['worst_value'])} | "
            f"{status_text(row)} | {note} |")


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
        "A group holds the cases of one Julia version, problem, phase, certificate measure, "
        "target and catalog input mode whose input data hashes agree in every repetition. The "
        "hash covers the problem data the solver received, not the solver or its settings; for "
        "the current-core cases it also covers the start. Precision and start are read from "
        "the case variant and must agree too. A configuration is the catalog solver with the "
        "rest of the variant; configurations are listed alphabetically.", "",
        "A time is shown only when the target is finite and every run is ok, which means the "
        "independent certificate met the target in every sample; summary.csv must agree with "
        "the records on status counts, timing runs, worst certificate and mean time (intervals "
        "are not rechecked). Other cases "
        "show their status counts and worst certificate and no time. \"Not recorded\" marks a "
        "configuration that another case of the same problem, phase and start has and that this "
        "group lacks in the records; \"ungrouped\" marks one that was run with all of this "
        "group's labels but whose input hash is missing (see \"Cases not grouped\").", ""]
    tables = defaultdict(list)
    for row in results:
        tables[(row["problem"], row["phase"])].append(row)
    lone = {placeholder(row, row["configuration"]) for row in ungrouped}
    for (problem, phase), rows in sorted(tables.items()):
        lines += [f"## {markdown(problem)} ({markdown(phase)})", ""]
        configurations = defaultdict(set)
        for row in rows + [row for row in ungrouped if (row["problem"], row["phase"]) == (problem, phase)]:
            configurations[row["start"]].add(row["configuration"])
        by_group = defaultdict(dict)
        for row in rows:
            by_group[row["comparison_group"]][row["configuration"]] = row
        same = ("julia", "precision", "start", "measure", "target", "input_mode")
        labels = defaultdict(set)
        for members in by_group.values():
            first = next(iter(members.values()))
            labels[tuple(first[k] for k in same)].add(first["inputs"])
        for index, members in sorted(by_group.items()):
            first = next(iter(members.values()))
            target = target_text(first["target"])
            lines += [f"### Group {index}: Julia {first['julia']}, precision {first['precision']}, "
                      f"start {first['start']}, {markdown(first['measure'])} target {target}, "
                      f"inputs {first['inputs']} ({markdown(first['input_mode'])})", ""]
            if len(labels[tuple(first[k] for k in same)]) > 1:
                lines += ["Another group has the same labels but different inputs; the two are "
                          "not comparable.", ""]
            lines += ["| Configuration | Case | Ok runs / total | Mean time (ns) | "
                      "95% interval (ns) | Worst certificate | Status counts | Time |",
                      "|---|---|---:|---:|---:|---:|---|---|"]
            for label in sorted(configurations[first["start"]]):
                row = members.get(label)
                if row is not None:
                    lines.append(case_line(row))
                elif placeholder(first, label) in lone:
                    lines.append(f"| {markdown(label)} | | | | | | | ungrouped |")
                else:
                    lines.append(f"| {markdown(label)} | | | | | | | not recorded |")
            lines.append("")
    lines += ["## Cases not grouped", "",
              "Cases whose inputs cannot be identified are not set beside any other case.", "",
              "| Julia | Problem | Phase | Precision | Start | Measure | Target | Input mode | "
              "Configuration | Case | Ok runs / total | Worst certificate | Status counts | Time |",
              "|---|---|---|---|---|---|---:|---|---|---|---:|---:|---|---|"]
    for row in ungrouped:
        lines.append(f"| {row['julia']} | {markdown(row['problem'])} | {markdown(row['phase'])} | "
                     f"{row['precision']} | {row['start']} | {markdown(row['measure'])} | "
                     f"{target_text(row['target'])} | {markdown(row['input_mode'])} | "
                     f"{markdown(row['configuration'])} | {markdown(row['id'])} | "
                     f"{row['status_ok']} / {row['runs']} | {number_text(row['worst_value'])} | "
                     f"{status_text(row)} | excluded: {row['exclusion']} |")
    if not ungrouped:
        lines.append("| None |" + " |" * 13)
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
