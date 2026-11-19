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
  ([CDM-01](@ref), #396) and the dense `Matrix` iterate of the ADMM graphical
  lasso ([ADM-04](@ref)); matrix responses outside the CD case, which uses a private
  `BlockIterate` over `vec(B)`;
- weighted `ElasticNet`, `Scaled` penalties, and CD group penalties other than
  `GroupNormL2`;
- `SqrNormL2` as a CD penalty with a declared center type other than `Nothing`,
  including a zero-valued center or a union-typed center holding `nothing`.
  The uncentered scalar least-squares CD form is specified in [IN-01](@ref).
  PGD/APG, square-root CD and group/matrix CD also exclude `SqrNormL2` penalties;
- weighted `NormL1Nonneg`, nonnegative least squares or nonnegative lasso with APG or CD, and the other
  constrained-penalty combinations excluded by [IN-07](@ref);
- intercepts and offsets, generalized losses and compositions;
- monotone or active-set acceleration, APG diagonal preconditioning, Newton,
  primal-dual methods, SLOPE and direct precision-matrix solvers other than the
  ADMM graphical lasso in [ADM-04](@ref);
- ADMM outside the centered quadratic and unweighted ℓ₁ problem in [ADM-01](@ref)
  and the graphical lasso in [ADM-04](@ref), including arbitrary function pairs,
  product spaces, linear constraints, custom norms, and over-relaxation or the
  adaptive penalty on a matrix;
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

**Tests.** `test/core_contracts.jl`, `test/naming.jl`, `test/nonnegative_lasso.jl` and solver-specific unsupported-input tests.

**Sources.** `docs/src/support.md:L385`, `docs/src/developer/implementation-notes.md:L238`, `docs/src/developer/implementation-notes.md:L240`, `docs/src/developer/implementation-notes.md:L434`, `docs/src/index.md:L9`, `README.md:L96`; the later nonnegative-lasso refusals are specified by [upstream #413 at fd45a42](https://github.com/mlakolar/ProximalSolvers.jl/commit/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8). The narrow ridge extension and remaining refusals are [upstream #420 at 217cde72](https://github.com/mlakolar/ProximalSolvers.jl/commit/217cde72cad2b324e174012accc949da59c1bba5).
