# API and necessity review

The exports in `src/ProximalSolvers.jl` cover solver settings, `solve!`, reusable
workspaces, options/traces, results, coordinate models and square-root losses,
penalty paths, LLA, reweighting, refits and optimality diagnostics. No exports
were removed or renamed. Documented qualified coordinate operations remain
public on Julia versions supporting `public`; Julia 1.10 retains qualified
access without that declaration. Aqua checks ambiguity, undefined exports,
unbound parameters, dependencies, compat and method hygiene. The naming checker
is a lexical aid, not a complete dispatch or API audit; `Lexact` is an existing
documented mathematical/compatibility spelling retained explicitly.

`printEvery`/`normD` keyword and property aliases remain deprecated and usable.
Qualified result types and result accessors are retained. Default option field
ordering is not changed. `LLA` remains a standalone driver rather than being
forced into a solver subtype solely to unify dispatch.

Actual sibling consumers were found by searching source, imports, method
extensions and dependency UUIDs. HighDimensionalModels uses solver/results,
coordinate models, public initialization/cache/scale operations, intercepts,
residuals, GLM predictors/deviance and paths. It defines `_LossModel <: CDModel`
and `solve!` methods. Its `SqrtQuadModel` import and `_saturated` calls are private
coupling. Retain them here; a separate downstream migration should use public
model construction or own the scalar saturated-loss formula rather than promote
private helpers. CovarianceSelection uses ADMM, gradient settings, options and
refits. DiffPrecTest uses CD and paths with Kronecker quadratics. CovSel is a
second checkout of CovarianceSelection, not an independent consumer. The checked
FunctionalGraphicalModels has indirect dependencies through these packages;
FunctionalDataAnalysis references solver-generated historical data, not a direct
runtime solver API. Exact editions and dirty patches are recorded adjacent.

| Machinery | Production purpose / decision |
|---|---|
| Tuple `Blocks` operations | Distinct product-space representation used by ADMM/fused models; retain. One block agrees with an array in tests. |
| Affine image models | Avoid a design product at an extrapolated point; retain with zero-weight parity repaired. |
| Scalar/diagonal metric dispatch | Preserve default scalar operations and correct metric group prox; retain. Not a claim that coordinate diagonals majorize full Hessians. |
| `_GroupEig` / LAPACK workspace | Avoid repeated group eigenvalue work arrays in Float32/64; retain. First construction/growth intentionally allocates. |
| KronModel versus KronUModel | O(1) derivative/O(p²) move versus O(p) derivative/O(p) move; different coordinate workloads justify both. |
| Momentum / Anderson | Distinct random versus cyclic acceleration, guarded acceptance and cache refresh; retain, with cyclic momentum prohibited. |
| Gap evaluator/state | Occasional certificates and safe-screening buffers; restricted/full problem distinction is essential. Checked gap arithmetic replaces duplicated unconditional clamps. |
| Coordinate update helper | Shares validation and the flat-slope correction across generic and fused quadratic kernels; not a public API. |
| SLOPE hybrid workspace | Opt-in algorithm with bounded signed-column cache, cluster invalidation and APG fallback; retain without a broad speed claim. |
| RefitCache | Rank updates/downdates on nearby supports with QR fallback; fixed-data ownership limitation documented rather than inventing a generic data fingerprint. |
| Workspace bootstrap | Optional convenience for maintained cross-package benchmark/test environments. Remove branch veto and package-local path requirement; standard Pkg operations suffice for ordinary development. Historical worker pins remain independent. |
| Active inner certificate | Continue the existing APG state after a heuristic stop until the original restricted proximal equation passes; checked only at proposed stops, counted in inner diagnostics. Needed to avoid repeated premature outer solves. |
| Stable quadratic remainder | Use cached least-squares images or Julia's three-argument dot for a supplied quadratic. No new curvature cache or public trait; avoids objective cancellation. |
| Untested test-suite timing block | Removed the extra unasserted active-set timing solves. Maintained lasso benchmarks already compare those methods; no assertion or tolerance removed. |
| GLM value reduction | Duplicate reduction removed; use the shared zero-weight-aware value routine. |
| Result display | Remove full-vector joining and fragile two-entry indexing; bounded preview has a protected allocation contract. |
| Logging proposal | Existing design notes describe proposals. No TraceOptions/event/result hierarchy introduced. Preserve per-family callback and trace meanings. |

Broad new result status enums, data-mutation detection, public internal kernels,
a cross-package logging contract and a new joint square-root feasibility solver
are deferred redesigns. None is needed to make this repair set reviewable.
