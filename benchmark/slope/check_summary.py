"""Failure accounting must not turn incomplete or unsuccessful paths into wins."""
import csv
import contextlib
import io
import tempfile
from pathlib import Path
from summarize import IDENTITY, evaluate, expected_grid, paired_summary

def silent_evaluate(*args):
    with contextlib.redirect_stdout(io.StringIO()):
        return evaluate(*args)

def row(valid, seconds=1):
    return {"valid": str(valid).lower(), "seconds": str(seconds)}

result = paired_summary([(row(True, 6), row(True, 2)), (row(False), row(True)),
                         (row(True), row(False)), (row(False), row(False))])
assert result["pairs"] == 4
assert all(result[k] == 1 for k in ("both_valid", "library_only", "baseline_only", "unresolved"))
assert result["median_both_valid_speedup"] == 3
assert len(expected_grid("main")) == 2160
assert len(expected_grid("confirmation")) == 576

# Exercise the full validation path: complete main grid, missing/duplicate calls,
# and a truncated warm path whose call incorrectly claims success.
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    calls, levels = [], []
    for key in sorted(expected_grid("main")):
        call = dict(zip(IDENTITY, key)) | {"valid": "true", "seconds": 1 if key[-1] == "SLOPE.jl" else 4,
            "max_gap": 0, "returned": 12 if key[7] == "path" else 1,
            "expected": 12 if key[7] == "path" else 1, "status": "target",
            "coef_inf_vs_library": 0, "prediction_rel_vs_library": 0, "objective_rel_vs_library": 0}
        calls.append(call)
        for k in range(1, call["expected"] + 1):
            levels.append(dict(zip(IDENTITY, key)) | {"valid": "true", "level": k, "gap": 0,
                                                       "feasibility": 1, "fixedpoint": 0})
    def write(kind, rows):
        with (root / f"{kind}-1.csv").open("w") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
            writer.writeheader(); writer.writerows(rows)
    write("calls", calls); write("levels", levels)
    result = silent_evaluate(root, "main", root / "out")
    assert result["prototype_gate"] and result["valid_levels"] == 10080
    for malformed_calls, malformed_levels in ((calls[:-1], levels), (calls + [calls[0]], levels),
                                                (calls, levels[:-1])):
        write("calls", malformed_calls); write("levels", malformed_levels)
        try:
            silent_evaluate(root, "main", root / "bad")
        except AssertionError:
            pass
        else:
            raise AssertionError("incomplete or duplicate evidence accepted")
print("SLOPE_SUMMARY_CHECKS_PASSED")
