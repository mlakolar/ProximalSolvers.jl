"""Failure accounting must not turn incomplete or unsuccessful paths into wins."""
from summarize import expected_grid, paired_summary

def row(valid, seconds=1):
    return {"valid": str(valid).lower(), "seconds": str(seconds)}

result = paired_summary([(row(True, 6), row(True, 2)), (row(False), row(True)),
                         (row(True), row(False)), (row(False), row(False))])
assert result["pairs"] == 4
assert all(result[k] == 1 for k in ("both_valid", "library_only", "baseline_only", "unresolved"))
assert result["median_both_valid_speedup"] == 3
assert len(expected_grid("main")) == 2160
assert len(expected_grid("confirmation")) == 576
print("SLOPE_SUMMARY_CHECKS_PASSED")
