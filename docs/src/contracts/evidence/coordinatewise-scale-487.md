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

The validation of the implementation ran production code at the base `a9fb96c8` and at `00a67e3d` of
[pull request #521](https://github.com/mlakolar/ProximalSolvers.jl/pull/521).

- **Validation.** The round-2 fixtures and the zero-scale, exact-fit and parity fixtures of the plan, Float32 and Float64,
  PGD and APG, with the default options and with `gradtol = 1e-8`, on Julia 1.10.13 and 1.13.4 as separate draws (each
  version on one node), with 256-bit BigFloat references on the stored inputs: 1640 in-scope rows per side and 96 rows of
  the problems that keep the `λmax`-based checks. A row is accurate when its objective excess is at most `1e-6` (also
  reported at `1e-4` for Float32) relative to `|F*|`; for the consistent fixtures, relative to the progress `F0 - F*`
  from the start when that is positive, and otherwise the excess must be exactly zero. Measured outcomes:
  - converged and inaccurate: at the base 108 Float64 rows (PGD 48, APG 60) and 87 Float32 rows (37, 50; 55 at `1e-4`);
    at the head 2 Float64 rows, APG on the nearly collinear free columns of RD1 with the default options in both draws
    (relative excess `6.3e-2`; also converged and inaccurate at the base), and 0 Float32 rows (0 at `1e-4`). No row is
    converged and inaccurate at the head that was not at the base.
  - The 96 rows of the other problems have identical outcomes at the base and the head.
  - Certified and accurate at the base, accurate and not certified at the head: in Float64, 58 rows of the consistent
    (exact-fit) fixtures and 25 others. Of the 25, 23 are at `gradtol = 1e-8` (the offset fixtures O1 and O2, the
    rescalings RS, the duplicated free column RD2, and N2 with APG); they ended by an objective increase or at
    `maxiter` with relative excess at most `7.2e-12`. The other 2 are N2 (100×200, `0.01 λmax`, unweighted) with PGD and
    the default options, certified at the base after 154 and 146 iterations, and at `maxiter = 200` at the head with
    relative excess `3.7e-9` and `4.1e-9`. In Float32, 67 rows (99 at `1e-4`).
  - Not certified at the base and certified and accurate at the head: 96 rows, among them the zero-response and `X = 0`
    fixtures.
  - Iterations, head over base, where both certified accurately: median 1.00 for each precision and method; largest
    1.27 (Float64 PGD), 1.37 (Float64 APG), 1.18 (Float32 PGD), 1.21 (Float32 APG).
  - The diagnostic of the validation script applied the earlier case D to a column scaled by `1e-170`, so in eight
    rows (two draws, two methods, two `gradtol`) it disagreed with the solver, which rescales that column and
    certified; the maintainer chose the scaled norm.

Paired benchmarks: see [pull request #521](https://github.com/mlakolar/ProximalSolvers.jl/pull/521).

**Observations at the implementation against the base.** On Julia 1.13.4 (AMD EPYC 7513), with the default options
unless stated, at the base `a9fb96c8` and at the implementation in pull request #521 (`fdffba3c`, rerun at `00a67e3d`
with the same values):

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
- Exact fits, each with `NormL1(0)` from `x = 0` and the default options unless stated. At the head each proposal is
  refused, by the ordinary comparison where the computed smooth scale is positive (for the one-column fixtures the
  computed residual is parallel to the column) and by case C where the stored loss, and so the smooth scale, is zero,
  and the solve ends at `maxiter` with `converged = false`. The one-column fixtures returned the minimizer for the stored data (relative error 0); the
  diagonal fixture ended at a point fitted to working precision (relative residual about `5.0e-17` in BigFloat). PGD
  and APG:
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
