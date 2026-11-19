#!/usr/bin/env python3
"""Compare centered-quadratic ADMM records across declared PS and PB pins."""

import argparse
from collections import defaultdict
import math
from pathlib import Path
import re
import statistics

from compare import exclusion_reasons, load
from summarize import mean_interval, worst_value, write_csv
from validate import MATCH_SETTINGS, fresh_output, metadata, number, setting


def checked_arm(root, expected, ps_sha, pb_sha):
    if not all(re.fullmatch(r"[0-9a-f]{40}", sha) for sha in (ps_sha, pb_sha)):
        raise ValueError("each stack identity must be a full Git SHA")
    rows, settings, catalogs = load(root, expected)
    for path in Path(root).glob("*-metadata.toml"):
        identity = metadata(path)
        if (identity["proximalsolvers_sha"] != ps_sha or identity["proximalsolvers_dirty"]
                or identity.get("proximalbase_source") != "git"
                or identity.get("proximalbase_rev") != pb_sha):
            raise ValueError(f"unexpected stack identity in {path}")
    for catalog in catalogs.values():
        if not all(case_id.startswith("admm/centered-l1-") for case_id in catalog):
            raise ValueError("expected centered-quadratic ADMM cases")
    return rows, settings, catalogs


def compare_admm(before, after, output, expected, before_ps, before_pb, after_ps, after_pb):
    left, left_settings, left_catalogs = checked_arm(before, expected, before_ps, before_pb)
    right, right_settings, right_catalogs = checked_arm(after, expected, after_ps, after_pb)
    if left.keys() != right.keys() or left_catalogs != right_catalogs:
        raise ValueError("case, repetition or certificate definitions differ")
    match = set(MATCH_SETTINGS) - {"proximalbase_hash", "proximalbase_version"}
    for version, config in left_settings.items():
        for key in sorted(match):
            if setting(config, key) != setting(right_settings[version], key):
                raise ValueError(f"settings differ for Julia {version}: {key}")

    groups = defaultdict(lambda: ([], []))
    for key in sorted(left):
        version, case_id, rep = key
        if left[key]["data_hash"] != right[key]["data_hash"]:
            raise ValueError(f"input hash differs for {version} {case_id} repetition {rep}")
        groups[version, case_id][0].append(left[key])
        groups[version, case_id][1].append(right[key])

    results = []
    for (version, case_id), (old, new) in groups.items():
        reasons = exclusion_reasons(old, expected) + exclusion_reasons(new, expected)
        record = dict(julia=version, id=case_id, excluded="; ".join(reasons),
                      before_worst_kkt=worst_value(old), after_worst_kkt=worst_value(new))
        if not reasons:
            old_times = [number(row["median_ns"]) for row in old]
            new_times = [number(row["median_ns"]) for row in new]
            logs = [math.log(b) - math.log(a) for a, b in zip(old_times, new_times)]
            center, half = statistics.mean(logs), mean_interval(logs)
            record.update(time_ratio=math.exp(center), ci95_low=math.exp(center - half),
                          ci95_high=math.exp(center + half),
                          before_mean_median_ns=statistics.mean(old_times),
                          after_mean_median_ns=statistics.mean(new_times),
                          before_median_bytes=statistics.median(number(r["median_bytes"]) for r in old),
                          after_median_bytes=statistics.median(number(r["median_bytes"]) for r in new))
        results.append(record)

    destination = fresh_output(output)
    fields = (
        "julia id excluded before_worst_kkt after_worst_kkt time_ratio ci95_low ci95_high "
        "before_mean_median_ns after_mean_median_ns before_median_bytes after_median_bytes"
    ).split()
    write_csv(destination / "comparison.csv", fields, results)
    (destination / "README.md").write_text(
        "# Centered-quadratic ADMM stack comparison\n\n"
        f"- Before: PS `{before_ps}`, PB `{before_pb}`\n"
        f"- After: PS `{after_ps}`, PB `{after_pb}`\n"
        f"- {expected} paired repetition(s) per case and Julia version\n\n"
        "Ratios compare complete stacks. The 95% intervals use paired log ratios of "
        "repetition medians. Cases with a failed certificate have no timing ratio. "
        "An interval crossing one is inconclusive.\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before")
    parser.add_argument("after")
    parser.add_argument("out")
    parser.add_argument("--expected-runs", required=True, type=int, choices=range(1, 11))
    for role in ("before", "after"):
        parser.add_argument(f"--{role}-ps", required=True)
        parser.add_argument(f"--{role}-pb", required=True)
    args = parser.parse_args()
    try:
        compare_admm(args.before, args.after, args.out, args.expected_runs,
                     args.before_ps, args.before_pb, args.after_ps, args.after_pb)
    except (ValueError, OSError) as error:
        parser.exit(2, f"{error}\n")
