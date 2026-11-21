# Deferred and refused features

The current supported combinations are [IN-01](@ref) and the specialized solver
contracts. A retained constructor keyword is not evidence of implemented support.

## [DEF-01 Unsupported capabilities and compatibility sentinels](@id DEF-01)

**Statement.**

The following remain deferred:

- sparse design matrices; sparse vectors and views as coefficient iterates;
  `SparseIterate` for PGD/APG; other group and symmetric owner types;
- matrix-shaped coefficient owners except the dense `Matrix` coefficient of
  least-squares CD with a matrix response and native row-group `GroupNormL2`
  ([CDM-01](@ref), #396) and the dense `Matrix` iterate of the graphical
  lasso with ADMM or PGD ([ADM-04](@ref), [PGD-06](@ref)), and the matrix-response
  entrywise lasso with PGD or APG ([IN-10](@ref)); matrix-response regression
  penalties and storage outside those solver contracts, including weighted
  matrix `NormL1`;
- `Scaled` penalties (including `Scaled` of a weighted `ElasticNet`, whose weighted
  form is specified in [IN-03](@ref)), and CD group penalties other than
  `GroupNormL2`;
- `SqrNormL2` as a CD penalty with a declared center type other than `Nothing`,
  including a zero-valued center or a union-typed center holding `nothing`.
  The uncentered scalar least-squares CD form is specified in [IN-01](@ref).
  PGD/APG, square-root CD and group/matrix CD also exclude `SqrNormL2` penalties;
- weighted `NormL1Nonneg`, nonnegative least squares or nonnegative lasso with APG or with CD on a
  `SparseIterate`, `BlockIterate` or `Matrix`, and the other constrained-penalty combinations
  excluded by [IN-07](@ref) (CD on a dense `Vector` supports the unweighted forms);
- automatic intercept handling and offsets (a column of ones can be supplied as an
  unpenalized coordinate, with penalty weight zero, under the input rules of a weighted
  `NormL1`); generalized losses and
  compositions, except the raw `LogisticLoss` with `NormL1` and `ProximalGradientDescent`
  in the scope of [IN-09](@ref), with `ProxNewton` in the scope of [PN-01](@ref), and with
  `LogisticADMM` in the scope of [LA-01](@ref). For the logistic loss, `AccProxGradDescent`,
  `CDSolver`, `ADMMSolver`, Newton-type methods other than `ProxNewton`, ADMM variants other than
  `LogisticADMM` (adaptive `ρ`, over-relaxation, general linear constraints),
  `Scaled(LogisticLoss)`, observation weights and
  offsets, `Float32` data, sparse designs and penalties other than `NormL1` remain
  deferred, as do Poisson and other generalized linear model losses;
- monotone or active-set acceleration, APG diagonal preconditioning, Newton (other than
  `ProxNewton` for the raw logistic loss, [PN-01](@ref)),
  primal-dual methods, SLOPE and direct precision-matrix solvers other than the
  graphical-lasso routes in [ADM-04](@ref) and [PGD-06](@ref);
- ADMM outside the centered quadratic and unweighted ℓ₁ problem in [ADM-01](@ref),
  the least-squares lasso with a tall or square `Float64` design in [ADM-05](@ref),
  the graphical lasso in [ADM-04](@ref) and the predictor split of sparse logistic
  regression in [LA-01](@ref) (which accepts wide designs), including arbitrary
  function pairs, product spaces, linear constraints, custom norms, scaled or
  `Float32` least-squares losses, wide designs (`n < p`) for the consensus
  least-squares ADMM of [ADM-05](@ref), and over-relaxation or the adaptive penalty
  on a matrix;
- paths, screening, public workspaces, refitting, reweighting, and certificates
  other than the square-root-lasso CD duality certificate;
- generic block, metric, certificate and logging frameworks, and extension
  promises based on the private model/state hooks.

Nondefault requests for deferred features are refused. Some constructor keywords
remain accepted only at their compatibility defaults, so historical signatures can
give informative errors. The solver/options objects do not store those unavailable
features. CD's `kkt_checks = 0` is a compatibility sentinel. `gap = NaN` is also a
placeholder unless square-root-lasso CD has certified its result and stores the
bound; see [RES-01](@ref).

This support reduction and the relation to historical branches are recorded in
[HIST-01](@ref). The private CD model hooks do not establish a public custom-loss or
workspace API; see [ARCH-03](@ref).

**Applies to.** Current development-core constructors, options and public solve dispatch.

**Code.** `src/types.jl`: constructor validation; `src/solve.jl`: supported dispatch and input gates; `src/cd/models.jl`: private seams.

**Tests.** `test/core_contracts.jl`, `test/naming.jl`, `test/nonnegative_lasso.jl`, `test/cd_nonnegative.jl`, `test/logistic_pgd.jl` (the logistic refusals), `test/logistic_proxnewton.jl` (the same refusals for `ProxNewton`), `test/logistic_admm.jl` (the same refusals for `LogisticADMM`) and solver-specific unsupported-input tests.

**Sources.** `docs/src/support.md:L385`, `docs/src/developer/implementation-notes.md:L238`, `docs/src/developer/implementation-notes.md:L240`, `docs/src/developer/implementation-notes.md:L434`, `docs/src/index.md:L9`, `README.md:L96`; the later nonnegative-lasso refusals are specified by [upstream #413 at fd45a42](https://github.com/mlakolar/ProximalSolvers.jl/commit/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8). The narrow ridge extension and remaining refusals are [upstream #420 at 217cde72](https://github.com/mlakolar/ProximalSolvers.jl/commit/217cde72cad2b324e174012accc949da59c1bba5).
