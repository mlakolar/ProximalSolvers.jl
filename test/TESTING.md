# Minimal-core test tiers

Quick: Aqua, naming, unchanged required Linux CI/gate contracts, fail-closed
inventory/selection, unchanged C0 independent numerical characterization and
new public refusal contracts, explicit PGD stopping contracts and exact-source paired-control policy tests. Standard adds ported scalar cache/scale/helper
regressions, the vector `SparseIterate` coordinate-descent contracts
(`sparse_cd`), the coordinate-descent loss-scale numerics (`cd_numerics`) and the accelerated proximal gradient contracts (`accelerated_pgd`:
analytic, duality-gap, KKT and finite-support references from the raw data;
momentum, rejected trials, restarts and image caches; refusals, nonfinite trials,
curvature overflow and rollback; trace, callbacks, limits and counters), the initial curvature estimate of PGD and APG (`initial_curvature`: the start `min(1, α‖X‖_F²)` at extreme and ordinary scales, an independent KKT residual of the solves that a testset names, and the allocations of the start) and the elastic net with PGD and APG
(`elasticnet`: the residual of the stopping check, closed-form and signed-support BigFloat minimizers, an
independent residual check at each `converged = true` of the file's main solves, a false-stop guard, level types,
rollback and allocations) and with CDSolver (`cd_elasticnet`: BigFloat residual and objective oracle, closed-form
and signed-support references, `NormL1` equality at `λ2 = 0`, flat and out-of-range columns, refusals and rollback) and the weighted lasso `NormL1(λ, w)` with CD, PGD and APG (`weighted_lasso`: a BigFloat
oracle from the stored data with the exact coefficients λ wⱼ, closed-form and signed-support references, the
coefficient range rule at its overflow and underflow boundaries, zero weights and flat columns, the stopping check, the
exceptional coordinate step against BigFloat, refusals before any write or draw, rollback and allocations) and the group lasso with PGD and APG on a dense Vector (`group_pgd`: independent BigFloat references and residual check, a false-stop guard, refusals before any write and allocations) and nonnegative least squares and nonnegative lasso with CDSolver on a dense Vector (`cd_nonnegative`: an independent BigFloat constrained KKT score and objective, closed forms and BigFloat references, CD and PGD to the same external score bound, with the objective difference of the two fits bounded by the unnormalized constrained KKT score of the higher-objective fit times the L1 distance between them plus a BigFloat rounding allowance, flat columns, the exceptional coordinate step against BigFloat, refusals before any write or draw, rollback and allocations) the matrix-response row-group lasso with CDSolver (`multiresponse_cd`: an independent row-wise KKT residual and BigFloat objective, `λmax`, an orthogonal-design reference, agreement with the Kronecker formulation and with the lasso for one response, zero columns, ownership, refusals before any write or draw, and allocations). The nonnegative lasso with dense PGD (`nonnegative_lasso`) checks Float32/Float64 closed forms, independent objective and constrained KKT residuals, positive and zero coordinates, and refusals before writes. Sparse logistic regression with dense PGD (`logistic_pgd`) checks a raw `LogisticLoss` with `NormL1`, with and without penalty weights, against value, gradient and KKT references computed from the data in BigFloat and a damped Newton reference with a numerical witness that its data are not separable; the stopping scale `‖Xᵀ(½ - y)‖∞`; the intercept-only model and levels at and above the slope threshold; steep and almost separated problems; a one-class sample with an unpenalized intercept, which has no minimizer (finite results, and any reported convergence consistent with the recomputed stationarity criterion); overflowed images at the start and in a trial; rejected trials and their recheck in each mode, rollback and limits; refusals before any write or RNG draw; and, for one fixture, allocations (none in warmed iterations, and whole solves against the least-squares control). Sparse logistic regression with dense APG (`logistic_apg`) checks the same loss and penalties: the decisions of the certified test for the logistic image against those for least squares at the factor `¼`; the image and descent inequalities in BigFloat at the final trial of each update of real solves, including updates that raise `L`, use momentum and restart; the start of `L` against PGD's; regularized fits against BigFloat objectives and the KKT scores of every coordinate, with a PGD solve and a tight PGD reference compared through a convexity bound on the objectives; the intercept-only model, an unpenalized fit against a damped Newton reference, steep and almost separated problems and a one-class sample with an unpenalized intercept (finite results, and any reported convergence checked against the independent residual); overflowed starts, trials and extrapolated points; rollback, limits and the counter identities; allocations against the least-squares control; and the refusals of the shared gate before any write. The per-entry stopping thresholds of PGD and APG for weighted `NormL1` and `GroupNormL2` (`entry_thresholds`, #464) are checked against BigFloat references. The fixtures are the #464 least-squares and logistic cases against analytic minimizers; zero, excluded, free and tiny-weight columns; an active entry with a coefficient far above `λmax`; ill-conditioned designs; zero scales; ordinary-weight controls on which the single threshold decides; and the group analogues. Every converged trajectory solve is checked entry by entry (the zero-response solve with positive weights against its exact minimizer `x = 0`), and the rule is checked at fixed points, including points where the earlier single threshold accepts and the entry thresholds reject. The entrywise KKT scales of matrix PGD for the graphical lasso (`logdet_kkt_scale`, #492) are checked on the file's fixtures against exact-arithmetic analytic values and BigFloat references from the stored data (256 bits, and 2048 bits as a chosen reference precision for the two inputs below; scores are converted to Float64 and compared with an allowance for the rounding of the computed score): the reported start score at prescribed points, the stop rule at the converged solves of seeded heterogeneous and ordinary problems, two inputs on which the first pass rounds a decisive violation to zero (a cancellation of `W` against a weight where `S` is small, with one sign, and a zero entry with an overflowing unused endpoint, with both signs, each in both precisions), the diagonal-weight cancellation cases and the `2^51` numerator through `solve!` (the Float32 case is an analogue), the direct and covariance-shifted formulations, a power-of-two rescaling where the unit floor is inactive, direct assertions on the scales, the uncertainty test and single-entry evaluations, and a comparison of the allocation of warmed evaluations at dimensions 12 and 36. Full adds every `.jl` script under `examples/`, including its subfolders, which
`test/examples.jl` discovers by itself, the exploratory benchmark script
(`benchmark_explore`) and the formal benchmark harness on the current core
(`benchmark_formal`: case selection and deferral, inputs, certificates, resets,
source checks and records accepted by `benchmark/validate.py`, with no timing
comparison); a PR that edits a harness file runs the latter. Tiers are cumulative;
Pkg.test defaults full. Every regular file is listed once, missing/duplicate/
unlisted tests and empty selections fail; unknown source defaults full.

The standard `multiresponse_lasso_pgd_apg` tests cover native dense entrywise
lasso in both precisions, with analytic, QR, separate-response CD and BigFloat
references. They check ownership and refusals, traces and rollback, PGD
curvature recovery and APG's Frobenius bound against independent majorization.

The standard `admm` tests cover centered quadratic denoising with an unweighted
ℓ₁ penalty in Float32 and Float64. They compare against BigFloat soft thresholding,
check the raw objective and coordinatewise KKT conditions, and independently
replay a fixed-penalty step to check primal and dual residuals and tolerances.
They also check input refusals, transaction behavior, limits, proximal call
counts, a rounded fixed point with large `ρ`, and extreme relaxation.
Adaptive tests replay the balancing steps, check the update cap and exercise
proposals outside the penalty, reciprocal and scaled dual's ranges. Restart
tests check that resuming with the returned penalty and scaled dual agrees
with an independently verified fresh solution.

The standard `admm_graphical_lasso` tests cover the graphical lasso with
`LogDetLoss` and a matrix-weighted `NormL1` on a dense matrix in Float32 and
Float64, including positive and zero diagonal weights. Analytic optima (1×1,
diagonal, 2×2 at and on both sides of the edge threshold, zero and large
penalty) and seeded problems check the original BigFloat objective and KKT
scores for direct and covariance-shift fits. Gap estimates require a dual
candidate that passes the exact affine constraints and a BigFloat Cholesky
check. The tests also cover graph counts, independent one-step replay, limits,
an exact positive-diagonal fixed point, rounded stagnation, an indefinite
intermediate iterate, a logdet prox output that fails Cholesky, warm starts,
and bitwise rollback on refusals and numerical failures.

The `pgd_graphical_lasso` tests cover matrix PGD for the same problem in Float32 and
Float64, with zero and positive diagonal weights. Analytic fixtures (1×1 with two
level and weight decompositions of one effective weight, diagonal, 2×2 on both sides of
the edge threshold and at it with positive diagonal weights, zero level, zero off-diagonal
weights and large off-diagonal penalty) compare direct PGD with closed-form optima; one
heterogeneous full-weight case has no closed-form comparison. The seeded fixtures with
positive diagonal weights at `(p, n) = (10, 150)` and `(30, 20)` compare direct PGD with PGD
on the shifted covariance, and direct ADMM is compared at `(10, 150)` only. The accuracy
checks recompute the objective and the KKT score in BigFloat and use the duality-gap
estimate of the test helper `independent`, whose comment states when it returns a gap
rather than `NaN`. The helper's score, primal objective and dual bound are those of the
problem with the rounded effective coefficients `T(λ₀)Λ`, which is the original problem for
the fixtures whose coefficient products are exact. The tests also cover refusals and nonmutation, a diagonal threshold that
zeroes a proposal, counters, limits, rounded stagnation and rollback.

The separately approved Linux-only matrix and required gate graph remain
unchanged: stable Julia1 Linux x64 for every tier, full master checks, coverage,
required jobs/merge gate, benchmark analysis and provenance-aware nightly reuse.
No required check runs on macOS or Windows. macOS ARM and Windows run the full suite nightly, on
Julia `1`, in `Nightly.yml` (below); those runs are not required checks, and the macOS leg is where
the deferred macOS C0 case (run42949840807) is checked again. Historical full-suite/platform
measurements and that deferred failure are preserved in
[the historical record](../docs/audit/historical-full-testing.md). See
[complete test provenance](../docs/audit/minimal-core-test-provenance.md).

**Nightly compatibility runs.** `.github/workflows/Nightly.yml` runs the full suite
(`scripts/test.jl --tier=full`), scheduled daily, as four legs that run concurrently, each its own
job: Linux with Julia 1.10, which resolves from `Manifest-v1.10.toml`, and Julia `1` on Linux, on
macOS ARM (`aarch64`) and on Windows, which resolve from `Project.toml` with ProximalBase taken from
`[sources]`. The matrix lists one `include` entry per leg, with 4 test workers (3 on macOS). It is
not a required check and does not change the required Linux Julia 1 jobs of `CI.yml`. It has no skip
or reuse logic: a test job does not read the runs of `CI.yml`, of earlier nights or of another leg,
so a success on one leg cannot suppress the run of another, and each leg has its own record and issue
title. A pull request that edits `Nightly.yml`, `Manifest-v1.10.toml` or `Project.toml` also starts
the four legs, as an advisory result that opens no issue. On scheduled and manual runs the report
job attempts an issue titled `Nightly
failing: Julia <version> - <os>` (the branch name in parentheses when the ref is not `master`), or a
comment on the open issue with that title, for each listed leg that did not succeed; a "Green again"
comment on the open issue of a listed leg that succeeded; and a fallback issue when the leg list
cannot be read or shows no failing leg although the test job did not succeed (the exact conditions
are in `Nightly.yml`). A failed write turns the report job red. Issues are closed by hand. Each leg
attempts to leave a record with its step outcomes and, when the test log contains them, the
recognised final test table and, for a test step that did not succeed, a bounded excerpt of the
failure lines; runner loss can leave no record. Rerun with
`gh workflow run Nightly.yml --ref master`, or locally with
`julia +<version> scripts/test.jl --tier=full` with the leg's Julia version (`1.10` or `1`). GitHub
can delay scheduled runs, and in a public
repository disables them after 60 days without repository activity. Julia 1.11 and later take
ProximalBase from `[sources]` in `Project.toml` and Julia 1.10 ignores it, so the quick test in
`test/aqua.jl` (`pin_problems`) compares the two: `[sources].ProximalBase` must have exactly `url`
and a 40-character lowercase `rev`, and `Manifest-v1.10.toml` must have one ProximalBase entry whose
`repo-url` and `repo-rev` equal the `[sources]` `url` and `rev` and whose `uuid` equals the
ProximalBase UUID in `[deps]`, with a `git-tree-sha1` and no `path` or `repo-subdir`. When
`[sources]` or its ProximalBase entry is removed, or a key other than `url` and `rev` is added
inside that entry, that test fails until `pin_problems` and its cases are changed to the new policy
(`PIN_POLICY` only labels it).

**Nightly CI and one-off cluster verification.** The `Nightly.yml` legs run the full suite on
`master`, on schedule or when dispatched by hand, and as an advisory result on a PR that edits
`Nightly.yml`, `Manifest-v1.10.toml` or `Project.toml`. Each run builds its environments the
same way: Julia 1.10 resolves from `Manifest-v1.10.toml`, Julia `1` from `Project.toml` with
ProximalBase from `[sources]`. They are not required checks; a failure found on a scheduled run is
already merged, and the report job attempts the per-leg issue above. A one-off verification run during a
PR, for example on a cluster (Slurm) or locally on another Julia version, tests the SHA it was run
on, in an environment that the person running it prepares. Its record is a comment on the PR, and it
says nothing about later commits. Julia 1.10 ignores `[sources]`, and such runs on 1.10 that did not use
`Manifest-v1.10.toml` have used a hand-prepared environment: one assertion in `benchmark_formal`
(the `benchmark/validate.py` acceptance check in the testset "formal records") failed in one on Julia
1.10.12 and passes in the nightly's 1.10 leg; the cause there was not diagnosed
([#228 comment](https://github.com/mlakolar/ProximalSolvers.jl/issues/228#issuecomment-6846181312)).
In #272 / #276, a warmed accelerated proximal gradient step allocated 464 bytes on Julia 1.10;
`test/accelerated_pgd.jl` failed there while the required Julia `1` checks passed. A one-off Julia
1.10 run found it, and #276 fixed it with fixed-arity `_se_mul` methods. With the pre-#276 code
restored, the nightly's 1.10 leg fails that test (`464 == 0`) and the required checks stay green, as
shown on the throwaway PR #292. The Julia 1.10.12 and 1.13.3 results reported for #270 / #286 came from
one-off cluster (Slurm) runs of four test files (`core_contracts`, `core_regressions`,
`accelerated_pgd`, `minimal_core_characterization`) at the PR's SHA; the full tier ran in PR CI on
Julia `1` alone. The nightly's 1.10 leg now runs the full suite on master each night.

**Native code.** A test in `test/tier_selection.jl` (quick tier; a change to `src/` plans the full
tier, which includes it) scans every line of the `.jl` files under `src/` (and `ext/`, if it exists)
for text that names a native call or module: `ccall`, `@ccall`, `cglobal`, `llvmcall`;
`LinearAlgebra.LAPACK`, `LinearAlgebra.BLAS` and `Base.Libc`, whatever follows the name; an unqualified
word `LAPACK`, `BLAS` or `Libc`, unless whitespace and then a letter or underscore follow it (so that
"BLAS kernel" in prose does not match); a `:LAPACK`-style symbol; `Libdl`; and a `using` or `import`
statement (`import ... as` included) that names one of these modules, also when it continues on lines
after a trailing `,` or `:`. Comments and strings are scanned too, so a match in a comment or a string
counts (reword it or register the file). `src/` has no match today. The test reads source text only:
an unqualified module name followed by whitespace and an identifier (the macro argument in `@m BLAS x`),
names built at run time (`eval(Symbol(...))`, `getfield` with a computed symbol) and the expansion of
external macros are outside it, and generic calls such as `mul!` or `dot`, which reach BLAS, are not matched; the
nightly legs run them on macOS and Windows. A file with a match fails the test unless a `[[native]]`
entry in `.github/tier-rules.toml` lists it. An entry has the keys `why`, `paths`, `checks`,
`platforms` and `enforcement`: its paths must exist and have a match, its checks must be tests of the
tier lists, its platforms are `macos-latest` and `windows-latest`, and its `enforcement` must name a
mechanism in `IMPLEMENTED_NATIVE_ENFORCEMENT` in `test/tier_selection.jl`. That list is empty,
because `CI.yml` has no macOS or Windows job, so every entry fails the test until a pull request
implements such a mechanism (the pre-merge platform job in the plan and verdict of `CI.yml`, running
the entry's checks on the entry's platforms) and names it there; that pull request also has to
change the assertion in `test/ci_gate.jl` that `CI.yml` has no macOS or Windows job. In short, a
file whose text matches the guard needs a registration, and a registration needs an implemented
enforcement mechanism.

**What a numerical test asserts.** An optimization test states what the code is meant to guarantee.

- *Numerical correctness* is checked against an independent reference: objective quality, the KKT
  residual, the duality gap where one is computed, feasibility, fitted values, and coefficients only
  where the solution is unique. Different trajectories, iteration counts, floating-point bits and
  random-number advancement are accepted when they violate no documented contract. Stopping flags are
  checked for what they report: `converged=true` is not an accuracy certificate, so accuracy comes from
  the independent checks and the flags are checked only for being consistent with the stopping
  rules in `src/`.
- *Mechanical refactors* may show unchanged behavior by exact trajectories, as a diagnostic. An exact
  trajectory is not a correctness requirement for an optimization algorithm.
- *Performance* compares time and computational work at matched, independently verified accuracy,
  and not only at equal iteration counts.
- *Randomized algorithms* use fixed seeds so that a run can be repeated. A seed does not make a
  historical trajectory part of the contract unless a test says so.
- *Exact contracts* stay exact: structural invariants, owner storage semantics, input preservation and
  identity, exact scalar operations, the result API surface, and mutation safety and rollback.

Existing numerical tests are not relaxed wholesale. Each assertion is audited for what it guarantees,
and the accuracy thresholds are not loosened to make a run pass.

The existing Benchmark analysis controls job has no tier or test-reuse condition, so it is
independent of the main tier and nightly test reuse. It runs as three separate matrix
legs (`comparator`, `campaign` and `controls`) that GitHub can run concurrently. The `controls`
leg also executes small exact-source A/B diagnostics using fresh isolated processes, after its
earlier steps succeed, and the job retains the Python benchmark controls. The normal package suite uses the exact current PB pin. Run
`julia --startup-file=no --project=@stdlib scripts/paired_master_diagnostics.jl`
for the paired control; it needs Git/network access and ordinary Julia package
resolution. Side A is the frozen extraction and side B the current tree, each in its own process
with its own source-identity checks and pins.

The paired control compares the 288 records of the two sides by kind. The inventory and the
format are fixed.

- **Optimization records** (`lasso/...`: proximal gradient descent and both coordinate-descent
  orders): both sides must pass the same independent quality checks, each with its own
  normalizer, where `tolerance` is `5e-4` in `Float32` and `2e-6` in `Float64`:
  objective against the signed-support or analytic reference, within `tolerance * max(1, |optimum|)`;
  the returned minimum against the independent objective, within the same bound; the KKT residual,
  within `tolerance * kkt_scale`, where `kkt_scale = max(1, α‖Xᵀy‖∞, λ)` for the loss scale `α` and
  the penalty `λ`; fitted values, within `4 * tolerance * max(1, ‖reference_fit‖∞)`; and, for the
  designs with a unique solution, coefficients, within `4 * tolerance * max(1, ‖reference_point‖∞)`.
  The probe stops at once when a check fails on its own side.
  The current tree must also have stopping flags that satisfy the relations below. Side A is not
  checked for them. For proximal gradient descent, `converged` is the disjunction of `x_converged`, `f_converged` and
  `grad_converged`, `iteration_converged` is `iterations == maxiter`, and a run that did not converge
  reports `iteration_converged`, `f_increased` or `call_limit_reached`. For least-squares coordinate
  descent (the probe's problems), `converged` implies `maxchange < tolerance`, and a run that did not
  converge made `maxpasses` passes; the square-root lasso, whose runs can also stop uncertified, is not
  among them. The source lines for these relations are cited in `check_flags` in
  `scripts/paired_master_diagnostics.jl`. Both sides must have the same result fields. Bits,
  trajectories, iteration counts and random-number advancement may differ: a differing record is
  printed as a `diagnostic:` line and is not a failure.
- **Exact contracts** (`scalar/...` scalar oracle values and `owner/...` storage semantics): the two
  sides must be equal.

The signed-support reference and the wider-precision objective/KKT checks are independent of PB
proximal operators and PS stopping and caches. `test/paired_master.jl` shows on synthetic records that
accurate solutions with different bits pass and that an inaccurate record, a flag inconsistency, a
changed exact record, a missing record and a changed field set fail. The full suite continues to
exercise the broader unchanged C0 oracle and behavioral fixtures.
