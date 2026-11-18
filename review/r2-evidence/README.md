Delta round-2 reviewer evidence. Original report/study/evidence and round-1 review/evidence were not edited.

- report_numbers.txt and tables-*.txt were regenerated with the supplied scripts and match the supplied outputs exactly.
- independent-recount.txt and independent-corrections.txt rerun the independent round-1 Python queries on the unchanged raw sweep tables.
- gate_details.jl is a temporary copy of the author's gate probe with per-solve output added; it writes gate-details.tsv and reproduces the author's summary.
- probe-rounding-master.txt reruns the author's master rounding probe. Only the printed package directory differs.
- extra_probes.jl checks targeted scaling exits and exports round-trip-exact tall-fixture data. check_delta.py verifies the raw counts, exact rational examples and exact rational inconsistency of the rounded tall fixture. check-delta.txt is its output.

Julia commands used the existing project and writable depot from round 1, with timeout 600 and the direct Julia 1.13.4 binary. Runs were sequential. The explicit direct binary avoids juliaup's read-only global lockfile. Scripts retain the absolute source paths and temporary output directory <TMP> used in this workspace.

The revision-2 snapshot and its adjacent source bundle are retained in <TMP>. snapshot-verification.txt also verifies the unchanged PB and X1 dependency snapshots from round 1.
