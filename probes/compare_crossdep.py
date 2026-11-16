#!/usr/bin/env python3
"""#307 cross-dependency comparison of two formal benchmark series (arms A->B, A->C).

Runs the harness's own benchmark/compare.py with exactly two settings exempted from its series
matching: the declared ProximalBase identity keys `proximalbase_version` and `proximalbase_hash`.
Every other check of compare.py stays: Julia version coverage, the remaining series settings
(suite, groups, harness_hash, julia_threads, blas_threads, blas, cpu_model, samples/time limits,
seed scheme, case filter), case coverage, catalog and certificate definitions (measure, target),
and per-(julia, id, rep) data hashes. A difference in any of them is refused as in compare.py.

The script additionally requires that the exempted keys are the only start-metadata keys of
validate.SERIES_SETTINGS that differ (outside the proximalsolvers_* keys that compare.py already
exempts), records their values on both sides, and labels REPORT.md as a cross-dependency report.

usage: compare_crossdep.py HARNESS_ROOT BEFORE AFTER OUT --expected-runs N
"""
import argparse
import sys
from pathlib import Path

DECLARED = ("proximalbase_version", "proximalbase_hash")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("harness_root")
    ap.add_argument("before")
    ap.add_argument("after")
    ap.add_argument("out")
    ap.add_argument("--expected-runs", type=int, choices=range(1, 11), default=1)
    a = ap.parse_args()
    sys.path.insert(0, str(Path(a.harness_root) / "benchmark"))
    import validate
    import compare

    missing = [k for k in DECLARED if k not in compare.MATCH_SETTINGS]
    if missing:
        ap.exit(2, f"declared keys not in compare.MATCH_SETTINGS (harness changed?): {missing}\n")
    _, old_cfg, _ = compare.load(a.before, a.expected_runs)
    _, new_cfg, _ = compare.load(a.after, a.expected_runs)
    if old_cfg.keys() != new_cfg.keys():
        ap.exit(2, "Julia version coverage differs\n")
    declared_values = {}
    for v in sorted(old_cfg):
        for k in validate.SERIES_SETTINGS:
            if k.startswith("proximalsolvers_"):
                continue
            o, n = validate.setting(old_cfg[v], k), validate.setting(new_cfg[v], k)
            if o != n and k not in DECLARED:
                ap.exit(2, f"undeclared difference for julia {v}: {k}: {o!r} != {n!r}\n")
            if k in DECLARED:
                declared_values[(v, k)] = (o, n)
    compare.MATCH_SETTINGS = tuple(k for k in compare.MATCH_SETTINGS if k not in DECLARED)
    try:
        compare.compare(a.before, a.after, a.out, a.expected_runs)
    except (ValueError, OSError) as e:
        ap.exit(2, f"{e}\n")
    report = Path(a.out) / "REPORT.md"
    head = ["# CROSS-DEPENDENCY comparison (#307)", "",
            "Produced by compare_crossdep.py: the harness's compare.py with only the declared",
            f"ProximalBase identity keys exempted from series matching: {', '.join(DECLARED)}.", "",
            "| julia | key | before | after |", "|---|---|---|---|"]
    head += [f"| {v} | {k} | {o} | {n} |" for (v, k), (o, n) in sorted(declared_values.items())]
    report.write_text("\n".join(head) + "\n\n" + report.read_text(encoding="utf-8"), encoding="utf-8")


if __name__ == "__main__":
    main()
