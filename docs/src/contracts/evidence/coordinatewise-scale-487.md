# Coordinatewise least-squares stopping: measurements

This page records the measurements behind [STOP-21](@ref) (issue
[#487](https://github.com/mlakolar/ProximalSolvers.jl/issues/487)). They are observations at stated revisions, not
solver guarantees.

## [evidence-coordinatewise-scale-487 Study and provenance](@id evidence-coordinatewise-scale-487)

**Statement.** The rule was chosen from the round-2 study of #487, which replaced only the stationarity check of
master `1a9f196b` (ProximalBase `bc9e888d`) by candidate rules in the same process, kept the iterates, step sizes,
momentum, proximal operators and starting point, and measured each return against a 256-bit BigFloat reference on
the stored data (Julia 1.13.4 and 1.10.13, a cluster with AMD EPYC 7513 nodes). The study, its fixtures, its raw rows
and its scripts are in the [round-2 report](https://github.com/mlakolar/ProximalSolvers.jl/issues/487#issuecomment-7060542089)
and on branch `research/issue-487` at `e7f35093`. Its probe recomputed the residual from `Xx` at each check; the
implementation reads the stored loss value instead, so the decisions of the two can differ by rounding.

- **Rules compared.** The `λmax`-based scale (with the #464 entry thresholds), a profiled reference scale (A), the
  coordinatewise rule (B), a tighten-only hybrid of the two, an absolute-plus-relative threshold (C), a
  backward-error classification (D) and a duality gap (E). On the 72 free-coordinate, tiny-weight, rescaling and
  ill-conditioning rows per type, `converged = true` at a relative objective excess above `1e-6` occurred in 30 Float64
  rows (29 in the replicate draw) under the `λmax`-based scale and in 1 (1) under B, the remaining one an ill-conditioned
  free block (RD1); in Float32 in 30 (27) rows against 0 (0). On the 80 ordinary least-squares rows per type B changed one
  Float64 decision (a false stop removed), and lost certification on 8 (5) accurate Float32 rows while gaining it on 1 (2).
  Iterations of Float64 rows certified under both rules: median ratio 1.00, largest 1.32.
- **Consistent systems.** The study's exact-fit fixture (`F* ≈ 0`) was refused under B and E. For the implementation
  the limitation is that an exact or near-exact fit can be left uncertified ([STOP-21](@ref)); the maintainer accepted
  it for this change.

The validation of the implementation and its benchmarks run against production code at the base `a9fb96c8` and at the
head of [pull request #521](https://github.com/mlakolar/ProximalSolvers.jl/pull/521); their numbers are recorded below
when the runs finish.

- **Validation.** Design: the round-2 fixtures and the zero-scale, exact-fit and parity fixtures of the plan,
  Float32 and Float64, PGD and APG, Julia 1.10.13 and 1.13.4, default options and `gradtol = 1e-8`, with BigFloat
  references on the stored inputs. Each row is classified as converged and accurate, converged and inaccurate, accurate
  and not converged, or neither (accuracy threshold `1e-6` relative objective excess in Float64), with the refusal
  cause at the last check and the exit. Results: *to be recorded* (class counts per precision, method and family, at
  the base and at the head). Two findings of the validation runs at `fdffba3c` are recorded here:
  - In Float64 a small `gradtol` (`1e-8`) on large-offset problems can leave accurate solves uncertified: the rounding
    of the computed gradient exceeds `τ sᵢ`.
  - The coordinatewise scale can need more iterations than the default `maxiter`: on N2 (100×200, `0.01 λmax`), PGD
    was certified at the base after 146 to 151 iterations and reached `maxiter = 200` at the head, with relative
    objective excess `4e-9` to `1e-8`.
- **Benchmarks.** Design: paired in-process comparison with the base loaded as a second module and a head-against-head
  control, at least 30 rounds in alternating order, on 200×50, 2000×500 and 5000×1000 lasso and elastic-net problems
  and one offset problem, PGD and APG, Float64 and Float32; the column pass against the `Xᵀy` product it replaces, the
  time per check, the overhead at a fixed amount of work, and the time to a matched independent-gap target. Results:
  *to be recorded*.

**Observations at the implementation against the base.** On Julia 1.13.4 (AMD EPYC 7513), with the default options
unless stated, at the base `a9fb96c8` and at the implementation in pull request #521 (`fdffba3c`; the rows were rerun
after the thresholds were carried as significand and exponent, with the same values):

| Fixture | Base | Implementation |
|---|---|---|
| #400 offset fixture (intercept free, offset `1e6`, Float64), returned objective | PGD 443.14, APG 2221.9, both `converged = true` | PGD and APG 143.767, both `converged = true` |
| `X = ones(5, 1)`, `y = fill(1e160, 5)`, `α = 1e-100`, `NormL1(0.1 λmax)`: relative coefficient error (iterations) | PGD `-8.2e-6` (9), APG `-1.1e-5` (7) | PGD `-4.7e-7` (11), APG `-9.9e-8` (9) |
| `ElasticNet(0, 1)`, `X = [1f-20]`, `y = [1]` (Float32): relative coefficient error, relative objective excess | PGD `3.2e-8`, `1e-55`; APG `1.1e-7`, `1.3e-54` | PGD `3.2e-8`, `1e-55`; APG `23.6`, `5.5e-38` |
| APG with `α = 1f-30` on the exact fit `X = [1f-23]`, `y = [1f-10]`, scale `1f38` | `converged = true` at iteration 7 | line-search error at iteration 12 (curvature estimate made zero by the factor `α`); the restored point is `1f13` |
| #464 fixture `X = [2.5 1e6; 0 1]`, `y = [1, -1e6]`, `NormL1(999999.27, [0, 1])`, from two near-optimal starts: largest relative objective excess | `4.0e-25` | `1.3e-13` |

- In the `ElasticNet(0, 1)` row the ridge term dominates the curvature, so the coordinatewise threshold of the only
  coordinate is about `τ` while `x* = 1e-20`; the relative coefficient error of APG's stop is large and its objective
  excess is not. In the #464 row the coordinatewise threshold of `x₂`, about `τ ‖X₂‖ ‖r‖ ≈ 1e7`, is far looser than
  the #464 threshold `τ c₂ ≈ 10`, because the residual is about `1e6`.
- Exact fits, each with `NormL1(0)` from `x = 0` and the default options unless stated; at the head each proposal is
  refused by case C (a computed residual parallel to the column, or zero) and the solve returns the exact minimizer at
  `maxiter` with `converged = false`, PGD and APG:
  - `X = ones(5, 1)`, `y = fill(1e160, 5)`, loss scale `1e-100` (Float64);
  - `X = [1.0;;]`, `y = [1e160]`, loss scale `5e-100` (Float64);
  - `X = ones(Float32, 5, 1)` with `y = fill(1f20, 5)` and Float64 loss scales `1e-10` and `1e-30`, `y = fill(1f25, 5)`
    with loss scale `1f-20`, and `y = fill(1f30, 5)` with loss scale `1f-30`;
  - `X = diag(1, 1e-6)`, `y = (0, 1e-156)`, raw loss, `maxiter = 20_000` (PGD).
- In the Learn chapter on floating point, the underflow example (case 2) now returns `converged = false` from PGD and
  APG at the coefficient `0` (`converged = true` at the base); the other Learn examples keep their flags.
- Benchmark campaign baselines of [STOP-20](@ref), whose Float64 options use `gradtol = 1e-11`, are not comparable
  across this change: the threshold of a least-squares lasso stop changed.

**Applies to.** PGD and APG on least squares with `NormL1` or `ElasticNet` on a dense vector.

**Sources.** [Issue #487](https://github.com/mlakolar/ProximalSolvers.jl/issues/487) and
[pull request #521](https://github.com/mlakolar/ProximalSolvers.jl/pull/521).
