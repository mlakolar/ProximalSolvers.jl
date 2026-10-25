# Composite splitting: measurement record

Read [Choosing a splitting for a composite problem](@ref composite_lessons)
for the objectives, derivations, certificate, and interpretation of the
algorithms. These tables are generated from the retained CSV by
`benchmark/composite_lessons/report.py`.

The measurements use Julia 1.13.2 on Apple M3, one Julia thread and one BLAS
thread, with JuMP 1.32.1 and HiGHS.jl 1.26.1. Each row is the run with median
total time among three repetitions of one seeded instance. Setup and solve
times below are **milliseconds**. Compilation and data generation are excluded;
norm bounds, normal-matrix formation, factorizations and QP model construction
are included where required. All iterative methods are accepted at the same
relative certificate target, 10⁻⁶, checked every 25 steps. HiGHS solves to
tighter internal tolerances and passes the same external acceptance check.

The iteration cap is 200,000 and the iterative solve-time limit is 15 seconds.
A row marked **limit** did not attain the target. Its elapsed time is not a
time to convergence. QP iterations are not recorded. These are CPU single-fit
measurements, not a comparison of warm-started paths or a hardware survey.

## Sparse graph-fused regression

| p | Method | Setup (ms) | Solve (ms) | Total (ms) | Iterations | Certificate | Status |
|--:|:--|--:|--:|--:|--:|--:|:--|
| 256 | Condat–Vũ | 0.0117 | 8.86 | 8.87 | 1,200 | 8.51e-07 | accepted |
| 256 | ADMM, ρ = 1 | 1.28 | 2.14 | 3.42 | 100 | 7.25e-07 | accepted |
| 256 | ADMM, ρ = 10 | 1.28 | 12 | 13.3 | 550 | 7.91e-07 | accepted |
| 256 | HiGHS QP | 1.63 | 190 | 192 | — | 3.30e-13 | accepted |
| 1024 | Condat–Vũ | 0.0203 | 49.5 | 49.5 | 1,600 | 8.60e-07 | accepted |
| 1024 | ADMM, ρ = 1 | 23.9 | 38.1 | 62.1 | 175 | 9.29e-07 | accepted |
| 1024 | ADMM, ρ = 10 | 14.5 | 113 | 128 | 575 | 6.99e-07 | accepted |
| 1024 | HiGHS QP | 4.71 | 4.1e+03 | 4.1e+03 | — | 4.45e-13 | accepted |

At p = 256, ordinary ADMM with ρ = 1 is faster than Condat–Vũ. At p = 1,024
their total costs are close; these few repetitions do not establish a
meaningful speed advantage. Condat–Vũ is competitive here while avoiding a
factorization. The ordinary ADMM Cholesky factor at p = 1,024 contains
511,035 nonzeros, despite sparse design and incidence
inputs. This exposes a storage tradeoff, but we did not measure peak memory
and should not turn a factor count into a total-memory claim.

The QP reference is slower in this experiment and returns a substantially
smaller certificate. Its time is useful context for choosing a method, not
evidence of superiority at equal achieved numerical error. Reusing an ADMM
factor or a QP model across a path could change the comparison.

## Second-difference trend filtering

| p | Method | Setup (ms) | Solve (ms) | Total (ms) | Iterations | Certificate | Status |
|--:|:--|--:|--:|--:|--:|--:|:--|
| 400 | Condat–Vũ | 0.00713 | 126 | 126 | 21,325 | 9.97e-07 | accepted |
| 400 | ADMM, ρ = 1 | 0.132 | 1.97e+03 | 1.97e+03 | 200,000 | 4.28e-04 | **limit** |
| 400 | ADMM, ρ = 10 | 0.121 | 1.09e+03 | 1.09e+03 | 113,625 | 9.98e-07 | accepted |
| 400 | ADMM, ρ = 100 | 0.121 | 107 | 107 | 11,375 | 9.87e-07 | accepted |
| 400 | TV-split ADMM, ρ = 8 | 0.0814 | 17.5 | 17.5 | 225 | 9.24e-07 | accepted |
| 400 | HiGHS QP | 3.16 | 52.1 | 55.3 | — | 1.02e-12 | accepted |
| 1600 | Condat–Vũ | 0.011 | 852 | 852 | 35,975 | 9.98e-07 | accepted |
| 1600 | ADMM, ρ = 1 | 0.343 | 7.97e+03 | 7.97e+03 | 200,000 | 7.22e-04 | **limit** |
| 1600 | ADMM, ρ = 10 | 0.495 | 7.3e+03 | 7.3e+03 | 182,725 | 9.99e-07 | accepted |
| 1600 | ADMM, ρ = 100 | 0.33 | 712 | 713 | 18,275 | 9.99e-07 | accepted |
| 1600 | TV-split ADMM, ρ = 8 | 0.0445 | 329 | 329 | 300 | 7.03e-07 | accepted |
| 1600 | HiGHS QP | 54.2 | 2.64e+03 | 2.69e+03 | — | 4.98e-11 | accepted |

The specialized TV-split ADMM is the fastest tested method at both lengths.
Its advantage is a better decomposition: a tridiagonal solve and a direct
TV proximal operation. Ordinary ADMM improves markedly when ρ increases from
1 to 100; comparing only ρ = 1 would give a misleading picture. At ρ = 1 it
hits the iteration cap with a certificate still above the target.

Condat–Vũ remains a valid general solution, but these data favor the
specialized splitting for this unweighted chain problem. The ranking of QP
and first-order methods also changes with sequence length. These are teaching
implementations and a small parameter comparison, not a claim about the best
available specialized trend-filtering software.

## Accuracy, variability and reproduction

The raw CSV records min/max total times across repetitions, objectives,
coefficient discrepancies from the QP reference, and strong-convexity distance
bounds. All reference comparisons check those discrepancies against the
certificates, including results that hit a limit. A correct loose bound does
not mean such a result reached the requested accuracy.

The normal test suite executes both lecture examples. The independent oracle
suite checks the common lower bound at arbitrary primal/dual points against
the QP optimum, and checks the exact dual expression for trend filtering.
The test results are correctness evidence separate from elapsed-time claims.

See the [recreation recipe and retained records](https://github.com/mlakolar/ProximalSolvers.jl/tree/master/benchmark/composite_lessons).
The record includes package versions, source revisions, source-file Git blob
hashes and fit CSVs used for the figures. The solver implementation is the
merged issue-23 code; the teaching helpers and benchmark runner are additional
sources identified individually by their hashes.
