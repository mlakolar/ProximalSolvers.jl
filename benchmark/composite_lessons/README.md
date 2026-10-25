# Composite splitting lecture: independent checks and timings

The lecture in `docs/src/composite_lessons.md` develops sparse graph-fused
regression and second-difference trend filtering. Executable examples 15 and
16 compare Condat–Vũ with reference ADMM routines using a common certificate.
This separate environment adds an independent JuMP/HiGHS epigraph QP and
repeated measurements. These dependencies are not runtime or docs dependencies.

From the repository root, on Julia 1.11 or later:

```sh
julia --project=benchmark/composite_lessons -e 'using Pkg; Pkg.instantiate()'
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  julia --project=benchmark/composite_lessons benchmark/composite_lessons/run.jl
```

Julia 1.10 ignores `[sources]`: explicitly `Pkg.develop` this checkout and a
ProximalBase checkout containing merged PR #95 in the environment first. The
sparse ADMM reference uses an allocating CHOLMOD solve fallback before Julia
1.13; the recorded performance comparison uses 1.13.2's in-place solve.

`LESSON_REPEATS` defaults to 3 and `LESSON_OUT` to this directory's ignored
`results/`. All methods start from fresh iterates. ADMM factors and QP models
are rebuilt for each measured repetition. Prepared data/loss objects are
shared; compilation, data generation and final validation are excluded.
Condat–Vũ's setup includes the conservative norm bounds; its solve includes
state initialization. ADMM setup includes normal-matrix formation and a
factorization. QP setup includes model construction. Factor-size diagnostics
are outside the timings.

The common relative certificate target is `1e-6`, checked every 25 iterative
steps. Iterative runs have a 200,000-iteration and 15-second solve limit.
Nonconvergence is retained explicitly, never counted as a successful timing.
QP solve time is capped at 60 seconds; a failed QP prevents writing a comparison
against an invalid reference. HiGHS uses tighter internal tolerances; its
returned solution must also pass the common external certificate.

Ordinary ADMM uses fixed ρ = 1 and 10 on graph regression, and 1, 10 and 100
on trend filtering. The specialized trend ADMM uses ρ = λ = 8. This is a
parameter sensitivity comparison, not a search for the best possible ADMM.
Condat–Vũ uses its default bounded adaptation/restarts. None receives a solved
warm start. Path costs and factor reuse across fits are not measured.

For each method, `comparison.csv` retains the actual run with median total
time, so its setup, solve, iteration and certificate columns belong together.
It also records the min/max total across repetitions, convergence status,
objective/reference values, coefficient error, a certified distance bound,
and the nonzero count of an ADMM Cholesky factor. A zero native factor count
means no factorization; it is not a measurement of total solver memory. QP
iterations and factor counts are `missing`, rather than placeholder zeros.
`environment.txt` records package versions, source revisions and Git blob
hashes for the teaching routines and runner, including uncommitted sources.

The retained `measurements-20261025/` data use Julia 1.13.2, Apple M3, one
Julia thread and one BLAS thread, JuMP 1.32.1 and HiGHS.jl 1.26.1. Each size
uses one seeded data realization. Repeats describe timing variability on that
realization, not variability across datasets or hardware. Random number
streams can differ across Julia versions. The graph's shortcuts, dimensions,
penalties, noise levels, and unnormalized loss are specified in the source
and lecture. The results do not demonstrate universal solver superiority.

Run the independent certificate checks, including arbitrary nonoptimal
primal/dual points, with the existing oracle environment:

```sh
julia --project=test/oracles test/oracles/primal_dual.jl
```

Optional figure regeneration uses Python with Matplotlib and NumPy:

```sh
python benchmark/composite_lessons/figures.py
python benchmark/composite_lessons/report.py
```

The first command reads the retained fit CSVs, writes the two SVGs under
`docs/src/assets/`, and writes PNG previews under ignored `results/`. The
second uses only the Python standard library to regenerate the documentation
tables from the retained comparison CSV. Python is not used during
the Julia documentation build. The recorded figures were rendered with
Matplotlib 3.11.2 and NumPy 2.5.4.
