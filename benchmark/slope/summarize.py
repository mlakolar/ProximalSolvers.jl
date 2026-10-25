"""Validate complete SLOPE evidence and retain unsuccessful paired outcomes."""
import argparse
import collections
import csv
import itertools
import json
import math
import statistics
from pathlib import Path

IDENTITY = ("n", "p", "rho", "sparsity", "weights", "seed", "round", "mode", "method")


def identity(row):
    return (int(row["n"]), int(row["p"]), float(row["rho"]), int(row["sparsity"]),
            row["weights"], int(row["seed"]), int(row["round"]), row["mode"], row["method"])


def expected_grid(phase):
    seeds, rounds = (range(1, 6), range(1, 4)) if phase in ("main", "accuracy_control") else (range(6, 8), range(1, 3))
    return {(n, p, rho, s, w, seed, rep, mode, method)
            for (n, p), rho, s, w, seed, rep, mode, method in itertools.product(
                ((200, 500), (1000, 2000)), (0., .9), (10, 100), ("linear", "bh"),
                seeds, rounds, ("single_0.3", "single_0.05", "path"), ("PG", "APG", "SLOPE.jl"))}


def paired_summary(pairs):
    outcomes = collections.Counter()
    speedups = []
    for base, library in pairs:
        b, lib = base["valid"] == "true", library["valid"] == "true"
        outcome = "both_valid" if b and lib else "baseline_only" if b else "library_only" if lib else "unresolved"
        outcomes[outcome] += 1
        if b and lib:
            speedups.append(float(base["seconds"]) / float(library["seconds"]))
    return {"pairs": len(pairs), **{k: outcomes[k] for k in ("both_valid", "baseline_only", "library_only", "unresolved")},
            "median_both_valid_speedup": statistics.median(speedups) if speedups else None,
            "min_both_valid_speedup": min(speedups) if speedups else None,
            "max_both_valid_speedup": max(speedups) if speedups else None}


def read_files(paths):
    rows = []
    for path in paths:
        with path.open() as handle:
            rows.extend(csv.DictReader(handle))
    return rows


def evaluate(root, phase, out):
    calls, levels = (read_files(sorted(root.glob(f"{kind}-*.csv"))) for kind in ("calls", "levels"))
    index = {}
    for row in calls:
        key = identity(row)
        assert key not in index, ("duplicate call", key)
        index[key] = row
        if row["valid"] == "true":
            assert math.isfinite(float(row["seconds"])) and float(row["seconds"]) > 0
            assert float(row["max_gap"]) <= 1e-6
            assert int(row["returned"]) == int(row["expected"])
    assert set(index) == expected_grid(phase), ("call identity coverage", len(index))
    level_index = {}
    for row in levels:
        key = identity(row) + (int(row["level"]),)
        assert key not in level_index, ("duplicate level", key)
        level_index[key] = row
        if row["valid"] == "true":
            assert math.isfinite(float(row["gap"])) and 0 <= float(row["gap"]) <= 1e-6
            assert float(row["feasibility"]) <= 1 + 1e-12
            assert math.isfinite(float(row["fixedpoint"]))
    expected_levels = {key + (k,) for key in index for k in range(1, 13 if key[7] == "path" else 2)}
    assert set(level_index) == expected_levels, "level identity coverage"
    for key, row in index.items():
        rs = [level_index[key + (k,)] for k in range(1, 13 if key[7] == "path" else 2)]
        assert (row["valid"] == "true") == all(r["valid"] == "true" for r in rs), ("call/level validity disagreement", key)
    paired = collections.defaultdict(list)
    detailed = collections.defaultdict(list)
    for key, row in index.items():
        if key[-1] == "SLOPE.jl":
            continue
        lib = index[key[:-1] + ("SLOPE.jl",)]
        mode = "path" if key[7] == "path" else "single"
        paired[(key[0], key[1], key[2], mode, key[-1])].append((row, lib))
        detailed[(key[0], key[1], key[2], key[3], key[4], key[7], key[-1])].append((row, lib))
    strata = [dict(zip(("n", "p", "rho", "mode", "baseline"), key)) | paired_summary(rs)
              for key, rs in sorted(paired.items())]
    details = [dict(zip(("n", "p", "rho", "sparsity", "weights", "mode", "baseline"), key)) | paired_summary(rs)
               for key, rs in sorted(detailed.items())]
    candidates = []
    for n, p, rho in itertools.product((200, 1000), (500, 2000), (0., .9)):
        records = [r for r in strata if (r["n"], r["p"], r["rho"], r["baseline"]) == (n, p, rho, "APG")]
        if len(records) == 2 and all(r["both_valid"] >= .9 * r["pairs"] and r["median_both_valid_speedup"] >= 3 for r in records):
            candidates.append({"n": n, "p": p, "rho": rho})
    lib = [r for r in calls if r["method"] == "SLOPE.jl"]
    reliability = sum(r["valid"] == "true" for r in lib) / len(lib)
    gate = {"phase": phase, "calls": len(calls), "levels": len(levels),
            "valid_calls": sum(r["valid"] == "true" for r in calls),
            "valid_levels": sum(r["valid"] == "true" for r in levels),
            "library_valid_calls": sum(r["valid"] == "true" for r in lib),
            "library_calls": len(lib), "library_success_rate": reliability,
            "candidate_strata": candidates, "prototype_gate": reliability >= .99 and len(candidates) >= 2,
            "fresh_seed_confirmation_required": phase != "confirmation"}
    diagnostics = {}
    for method in ("PG", "APG", "SLOPE.jl"):
        rows = [r for r in calls if r["method"] == method]
        diagnostics[method] = {"calls": len(rows), "valid": sum(r["valid"] == "true" for r in rows),
                               "statuses": dict(collections.Counter(r["status"] for r in rows))}
        for field in ("coef_inf_vs_library", "prediction_rel_vs_library", "objective_rel_vs_library"):
            values = [float(r[field]) for r in rows if r["valid"] == "true" and math.isfinite(float(r[field]))]
            diagnostics[method]["max_" + field] = max(values) if values else None
    out.mkdir(parents=True, exist_ok=True)
    for name, data in (("gate.json", gate), ("strata.json", strata), ("details.json", details), ("diagnostics.json", diagnostics)):
        (out / name).write_text(json.dumps(data, indent=2, allow_nan=False) + "\n")
    print(json.dumps(gate, indent=2))
    return gate


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--phase", choices=("main", "accuracy_control", "confirmation"), default="main")
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    evaluate(args.root, args.phase, args.out)
