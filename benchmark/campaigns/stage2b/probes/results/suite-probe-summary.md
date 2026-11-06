# Readiness probe summary (exploratory; not a candidate evaluation, not a benchmark)

Subject: ProximalSolvers source 7b9b5295 (src identical to b0de3f7), Project.toml compat widened in a scratch copy
to `ProximalBase = "0.5.3, 0.6"`, ProximalBase developed from a detached checkout of master 233c11cc284284fbd29df487308b4ee962f875a1.
Command: Pkg.test(; test_args=["--jobs=8"]) (full tier), check-bounds as Pkg.test forces.

| Julia | Overall pass | Overall error | Total | wall | exit |
|---|---|---|---|---|---|
| 1.10.12 | 114108 | 109 | 114217 | 5m00.4s | 1 |
| 1.13.3  | 114119 | 109 | 114228 | 5m12.9s | 1 |

Files with errors (identical counts on both versions), 6 of 55:
symmetric_penalty_combinations 79; symmetric_penalties 20; symmetric_penalties_basics 4; flat_coordinates 3; audit_regressions 2; coordinate_descent 1 (test/coordinate_descent.jl:53, KronQuadratic).
Every error is `ArgumentError: the array <w|c|C> of <penalty/loss> must be symmetric on a SymmetricSparseIterate` (exact-symmetry rule). The other 49 files pass.
The owner is still an AbstractMatrix on this commit, so the x.p / owner-redesign breakage is NOT yet exercised.
