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
  ([CDM-01](@ref), #396); matrix responses outside that case, which uses a private
  `BlockIterate` over `vec(B)`;
- weighted `ElasticNet`, `Scaled` penalties, and CD group penalties other than
  `GroupNormL2`;
- intercepts and offsets, generalized losses and compositions;
- monotone or active-set acceleration, APG diagonal preconditioning, ADMM/Newton,
  primal-dual methods, SLOPE and graphical models;
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

**Tests.** `test/core_contracts.jl`, `test/naming.jl` and solver-specific unsupported-input tests.

**Sources.** `docs/src/support.md:L385`, `docs/src/developer/implementation-notes.md:L238`, `docs/src/developer/implementation-notes.md:L240`, `docs/src/developer/implementation-notes.md:L434`, `docs/src/index.md:L9`, `README.md:L96`.
