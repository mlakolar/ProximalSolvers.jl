"""Regenerate the documentation tables from the retained CSV (stdlib only)."""
import csv
from pathlib import Path

root = Path(__file__).resolve().parents[2]
record = Path(__file__).parent / "measurements-20261025"
with (record / "comparison.csv").open() as handle:
    rows = list(csv.DictReader(handle))

names = {"CondatVu": "Condat–Vũ", "ADMM-rho1": "ADMM, ρ = 1", "ADMM-rho10": "ADMM, ρ = 10",
         "ADMM-rho100": "ADMM, ρ = 100", "TV-split-ADMM": "TV-split ADMM, ρ = 8", "HiGHS-QP": "HiGHS QP"}

parts = ["""# Composite splitting: measurement record

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
"""]

for problem, title in (("graph", "Sparse graph-fused regression"), ("trend", "Second-difference trend filtering")):
    parts.append(f"\n## {title}\n\n")
    parts.append("| p | Method | Setup (ms) | Solve (ms) | Total (ms) | Iterations | Certificate | Status |\n")
    parts.append("|--:|:--|--:|--:|--:|--:|--:|:--|\n")
    for row in rows:
        if row["problem"] != problem:
            continue
        times = [f"{1000 * float(row[key]):.3g}" for key in ("setup_seconds", "solve_seconds", "total_seconds")]
        status = "accepted" if row["converged"] == "true" else "**limit**"
        iterations = "—" if row["iterations"] == "missing" else f"{int(row['iterations']):,}"
        parts.append("| " + " | ".join([row["p"], names[row["method"]], *times, iterations,
                                          f"{float(row['certificate']):.2e}", status]) + " |\n")
    if problem == "graph":
        factor = next(row for row in rows if row["problem"] == "graph" and row["p"] == "1024" and row["method"] == "ADMM-rho1")
        parts.append(f"""
At p = 256, ordinary ADMM with ρ = 1 is faster than Condat–Vũ. At p = 1,024
their total costs are close; these few repetitions do not establish a
meaningful speed advantage. Condat–Vũ is competitive here while avoiding a
factorization. The ordinary ADMM Cholesky factor at p = 1,024 contains
{int(factor['factor_nnz']):,} nonzeros, despite sparse design and incidence
inputs. This exposes a storage tradeoff, but we did not measure peak memory
and should not turn a factor count into a total-memory claim.

The QP reference is slower in this experiment and returns a substantially
smaller certificate. Its time is useful context for choosing a method, not
evidence of superiority at equal achieved numerical error. Reusing an ADMM
factor or a QP model across a path could change the comparison.
""")
    else:
        parts.append("""
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
""")

parts.append("""
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
""")
(root / "docs" / "src" / "composite_results.md").write_text("".join(parts))
