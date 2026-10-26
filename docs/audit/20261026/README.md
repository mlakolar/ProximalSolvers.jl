# ProximalSolvers implementation and compatibility audit

This is review evidence, outside the user manual. The candidate starts at
`bba7c1a263c83613c68708731eedb4a1e2711f6f` (the full base commit is recorded in the Git history and validation
summary). The primary `ProximalOPT.jl` checkout at
`9041e236f3de8ffdc02103e5a505993463e00bb1` contained extensive staged and unstaged
work. None of it was overlaid on this branch. Existing changes were compared
separately; many migration changes were already upstream. The primary checkout
and sibling working files were not reset, stashed, switched or edited.

Canonical identity: `mlakolar/ProximalSolvers.jl`, Julia module/package
`ProximalSolvers`, UUID `fc4971f5-6616-4709-9bfc-89a819252f6b`, version metadata
0.1.1 unchanged. The old Git remote redirects to this repository. No open solver
PR existed when the audit began. Discussions of merged PRs #96–#99 were read;
they contained coverage reports and no outstanding human review requests.
ProximalBase PR #128 was separately identified and tested by source revision.

The source-level review covers every implementation file below and the complete
principal dispatch paths. It reconstructs the update and stopping contracts,
checks immediate ProximalBase interface dependencies, and uses independent
numerical checks. It does not prove general convergence theorems, validate every
possible user oracle or establish absence of bugs. ProximalBase's mathematical
oracles are trusted dependencies apart from interface and numerical checks.

See [validation](validation.md), [API and necessity review](api-and-necessity.md),
[mathematical contracts](contracts.md), and the maintained
[architecture manual](../../src/architecture.md).

## Findings

All findings are confirmed with high confidence unless qualified below. P1 means
wrong solutions or false success; P2 covers contract, failure, installation or
material reporting defects. Regression names refer to `test/audit_regressions.jl`.

| ID | Priority | Source and public behavior | Evidence and repair | Compatibility / coverage |
|---|---|---|---|---|
| PS-01 | P1 | `cd/models.jl`, `quadratic.jl`, `kron.jl`, `kronu.jl`, `groups.jl`, `gap.jl`: a flat quadratic coordinate discarded a nonzero linear term; its residual also returned zero | `A=0, b=-1, NormL1(.1)` returned zero with success for an unbounded problem. Shared checked scalar update rejects unsupported nonzero slopes; flat block quadratics also reject them. A penalized nonzero flat coordinate no longer has zero diagnostic residual. | Valid positive-curvature updates retained. Degenerate linear directions now fail explicitly; use another solver or positive curvature. Regression: flat curvature. |
| PS-02 | P1 | `cd/glm.jl`: an objective offset could make an incomplete Newton step appear converged | A logistic scalar loss plus `1e12` stopped after one nonstationary step. Objective stagnation now triggers an original-gradient proximal residual and intercept-score check. | Tighter truthful success flag; no new result fields. Regression: GLM stopping. |
| PS-03 | P1 | `sqrtlasso.jl`, `sqrtquadratic.jl`: coordinatewise optimality at a nonsmooth exact fit was reported as success | `X=[1 1;0 .01]`, start `[1,-1]`, `y=X*start`, `λ=.1`: returned objective `.20`, while zero gives `.01`. Exact fits with positive penalty are conservatively uncertified. Zero objective remains certified. | The point is preserved, `converged=false`, warning explains lack of certificate. A joint subgradient feasibility algorithm is deferred; no global claim remains for this corner case. |
| PS-04 | P1 | `solvers/admm.jl`: supplied `u=x` silently corrupted the returned primal point | Scalar and cross-tuple aliases now reject before mutation. Nonfinite/negative ADMM tolerances and infinite rho reject; nonfinite residual comparisons cannot establish success. | Previously invalid storage is rejected; valid separate warm starts preserved. Regression: ADMM storage. |
| PS-05 | P1 | `cd/gap.jl`, `cd/glm.jl`, `quic.jl`, `primal_dual.jl`: unconditional clipping could turn material weak-duality violations into zero gaps | Shared checked arithmetic rejects nonfinite values and material negative gaps. Only negative differences within `8eps*max(abs(P),abs(D))` receive the documented roundoff treatment. Safe screening cannot use a nonfinite gap. Composite public gaps expose raw `P-D`. | Deliberately changes invalid certificates; small roundoff is explicit. Regression: invalid certificates. Mathematical feasibility of custom duals is still the caller's responsibility. |
| PS-06 | P1 | `models.jl`, `quic.jl`, `generic_newton.jl`: asymmetric L1 weights could make QUIC's inner direction use the wrong off-diagonal penalty | QUIC averages transposed weights, preserving their sum on symmetric matrices. Generic Newton retains its documented averaging. Ordinary symmetric CD rejects asymmetric L1/nonnegative-L1/elastic-net weights as its manual requires. | Supported symmetric weights retained; QUIC's formerly incorrect asymmetric case repaired. Regression compares identical randomized schedules and an independent gap. |
| PS-07 | P2 | `line_searches.jl`, gradient kernels, `solve.jl`: searches could increase curvature indefinitely or leave a rejected point in caller storage | Finite-progress guards bound failed searches; APG requires a finite accepted loss. The solve engine restores the last accepted point on an exception and rejects a nonfinite accepted objective. | An error replaces a hang/invalid result. The APG cancellation regression now permits bounded failure or independently
accurate success, checked against BigFloat data; it no longer mandates a
particular failure trajectory. New invalid-oracle regression checks restoration in all three methods. |
| PS-08 | P2 | `cd/drivers.jl`: explicit refit support did not restrict the whole point | An identity design refit with support `[1]` kept an old nonzero second coefficient. Refit now zeros excluded coordinates before fitting and validates unique in-range indices. | Aligns with documented support-restricted fit; empty support yields zero. Existing selected-support QR and cache behavior retained. |
| PS-09 | P2 | `image_models.jl`, `cd/glm.jl`, `gap.jl`: zero-weight Poisson terms evaluated `0*Inf` | Predictor 1000 on an observation of weight zero made the image path disagree with ProximalBase. Omitted observations are skipped before scalar loss/derivative evaluation, including IRLS work. Duplicate GLM value reduction removed. | Matches the supplied weighted objective. Regression checks four solver families against direct loss values and stationarity. |
| PS-10 | P2 | `Project.toml`, bootstrap and installation guidance | Compat `"0.5.3, 0.5"` allowed 0.5.2, which fails loading at missing `GroupMCP`. Minimum corrected to 0.5.3. Removed the package's sibling-path source requirement and bootstrap branch veto; standard Pkg development documented. | 0.5.2 was not actually usable. Registered-release installation and development-source installation are distinguished. No version bump or release performed. |
| PS-11 | P2 | path docstrings and manual: a gap target was presented as a general coefficient-error guarantee | Objective error needs a feasible dual certificate; coefficient error needs curvature/identifiability. Historical measurements remain labeled empirical. Nonconvex theorem claims now state conditions rather than inheriting them from traits. | Documentation correction; supported operations retained. |
| PS-12 | P2 | `types.jl`: result display joined every coefficient and indexed two entries of a one-element long representation | Bounded preview uses at most two entries. BigFloat one-element result display and a 10,000-entry allocation regression cover the defect. | Human display is shorter; result arrays and fields unchanged. |
| PS-13 | P1 | active accelerated gradient: a successful inner change rule was treated as full-problem optimality | Full proximal fixed-point check now gates success. Residual is relative to `max(1,norm(initial_gradient,Inf))`, consistent with a data-scaled rule. A stalled nonstationary point returns false. | Additional full proximal call and two length-p scratch vectors. Float32 exposed the inadequacy of an absolute check; that adverse run is retained. Loose-inner regression rejects false success. |
| PS-14 | P2 | options and path validation: nonfinite stopping targets and grids | Finite tolerances and finite nonnegative path levels required; negative call limits and NaN time limits reject. Repeated levels remain supported. | Invalid settings fail early. Existing nonpositive-time behavior and minimum iteration constructor contract are preserved. |

PS-15 (P1): the Float32 active-set diagnostic exposed objective-cancellation
slack in accelerated least squares. A residual around 0.006 persisted above a
0.00017 target. For a quadratic least-squares loss, the Taylor remainder is
`scale*norm(A*(trial-origin))^2/2`. Accelerated and monotone methods now compare
that remainder using existing image buffers, instead of subtracting nearly
equal objective values. No extra matrix product is needed. The original
Float32 assertions pass unchanged; a new regression checks the independent full
residual. Before/after timings include the additional image reduction. This
specialization is retained for its mathematical and numerical purpose.

## Implementation ledger

R = source reviewed; F = repaired; V = exercised by full package suite or named
regression. V is runtime evidence for supported test cases, not proof of all
branches. Baseline and repaired editions are distinguished in validation.

| Implementation | Status | Review focus / retained purpose |
|---|---|---|
| `src/ProximalSolvers.jl` | R,V | Include order, exports, version-gated public declarations; no weak dependencies/extensions |
| `src/types.jl` | R,F,V | Options, trace/result ownership, counters, deprecated print keyword; PS-12/14 |
| `src/solve.jl` | R,F,V | Entry dispatch, initialization, accepted trials, selected stopping, final gap; PS-07 |
| `src/blocks.jl` | R,V | Shared array/tuple vector-space operations; single-block equivalence and product-space norms |
| `src/line_searches.jl` | R,F,V | TFOCS value/gradient estimates, off-domain rejection, curvature progress; PS-07 |
| `src/utils.jl` | R,V | FASTA diagnostics, trace cadence, zero normalizers, metric residuals; change flags remain diagnostics |
| `src/workspaces.jl` | R,V | Reset state, penalty type/partition checks, shapes and aliases; fixed-data reuse contract |
| `src/precompile.jl` | R,V | Workload has production callers and loads independently of bootstrap; optional precompilation remains |
| `src/solvers/image_models.jl` | R,F,V | Cached affine images, extrapolation, scale and zero-weight parity; PS-09 |
| `src/solvers/diagonal_metric.jl` | R,V | Positive diagonal metric, scalar backtracking, full group metric prox; no diagonal-Hessian substitution claim |
| `src/solvers/proximal_gradient_descent.jl` | R,F,V | Step normalization, normalized IHT, debias, current gradient; conditional nonconvex claims |
| `src/solvers/accelerated_proximal_gradient_descent.jl` | R,F,V | Extrapolation, restart, finite acceptance, accepted iterate; PS-07 |
| `src/solvers/monotone_accelerated_proximal_gradient_descent.jl` | R,F,V | Two candidates, retained origin/gradient, candidate images, failed search; PS-07 |
| `src/solvers/active_accelerated_proximal_gradient_descent.jl` | R,F,V | Restricted mappings, grouped activation, full checks and stalled inner solves; PS-13 |
| `src/solvers/admm.jl` | R,F,V | Scaled splitting, over-relaxation, residuals, rho rescaling, warm-start storage; PS-04 |
| `src/solvers/primal_dual.jl` | R,F,V | Adjoint dimensions, norm upper bound, smoothness precondition, KKT residuals, warm dual, raw certificate; PS-05 |
| `src/solvers/slope.jl` | R,V | Leading restricted weights, working-set repair, total inner budget, independent path copies |
| `src/solvers/slope_hybrid.jl` | R,V | Cluster ordering/merges, signed columns, cache invalidation, safeguarded objective and APG budget reserve |
| `src/cd/models.jl` | R,F,V | Public scalar protocol, iterate multiplicity, penalty levels, validation; PS-01/06 |
| `src/cd/solver.jl` | R,F,V | Full/active/candidate visits, finite changes, momentum cache movement, Anderson acceptance, limits; PS-03/14 |
| `src/cd/leastsquares.jl` | R,V | Dense/CSC weighted centered residuals, stored zeros, scalar/group curvature, cache refresh |
| `src/cd/multiresponse.jl` | R,V | Row groups, scalar-times-identity block Hessian, intercept vector and matrix residuals |
| `src/cd/quadratic.jl` | R,F,V | Dense/CSC/diagonal storage, shared versus copied matrices, flat slopes, block curvature; PS-01 |
| `src/cd/kron.jl` | R,F,V | Rank-one/two updates, symmetric derivatives and multiplicity, no full Kronecker allocation; PS-01 |
| `src/cd/kronu.jl` | R,F,V | QUIC's distinct O(p) row cache instead of O(p²) update; PS-01 |
| `src/cd/groupcurvature.jl` | R,V | Reusable Float32/64 LAPACK workspace sized by largest group; generic precision limitations retained |
| `src/cd/groups.jl` | R,F,V | Non-L2 group/separable block proximal steps; PS-01 |
| `src/cd/sqrtlasso.jl` | R,F,V | Exact coordinate formula, zero curvature, zero residual nondifferentiability; PS-03 |
| `src/cd/sqrtquadratic.jl` | R,F,V | Sufficient-statistic normalization, q cache, momentum refresh, caller nonnegative-q precondition; PS-03 |
| `src/cd/glm.jl` | R,F,V | Curvature bounds, intercepts, IRLS, damping, rejected steps, full scores; PS-02/09/14 |
| `src/cd/gap.jl` | R,F,V | Conjugate scaling, zero weights, restricted/full gaps, screening radii, KKT diagnostics; PS-01/05/09 |
| `src/cd/sparsegroup.jl` | R,V | Dual root, strong rule, sparse-group gap-safe ball; not an ordinary group norm shortcut |
| `src/cd/quic.jl` | R,F,V | Symmetry, SPD Cholesky/inverse updates, components, pair weights and gap; PS-05/06 |
| `src/cd/generic_newton.jl` | R,F,V | New-point quadratic oracle, model refresh, original-gradient residual, inexact budget and Armijo; PS-06 |
| `src/cd/path.jl` | R,F,V | Level validation, zero/repeated levels, strong reactivation, full-gap retries, owned snapshots; PS-11/14 |
| `src/cd/refit_cache.jl` | R,V | Owner identity, support updates/downdates, pivot criterion and QR fallback; fixed-data precondition |
| `src/cd/drivers.jl` | R,F,V | Weight changes versus inner status, support restriction and rank-deficient QR; PS-08 |
| `src/cd/lla.jl` | R,F,V | Tangent weights, alternating buffers, lasso/previous starts, stage snapshots; PS-14 |

## Documentation coverage

| Maintained area | Review / repair / validation |
|---|---|
| README, CONTRIBUTING, installation and example index | Identity, registry/development distinction, standard Pkg route, branch preservation, count/accuracy claims repaired |
| `index`, `getting_started`, `choosing_solver`, `solve` | Solver interfaces, normalization, defaults, ownership, callbacks and returned status checked against source |
| `coordinate_descent`, `losses`, `paths`, `drivers`, `prox_newton`, `extending` | Mathematical steps, storage, scalar/group distinction, cache preconditions, nonconvex scope and failure behavior reviewed; defects above repaired |
| `proximal_gradient`, `active_set`, `admm`, `primal_dual`, `slope` | Full runtime paths and assumptions reviewed; full active check and qualified convergence claims documented |
| API pages and docstrings | Export families and qualified coordinate extension operations covered; existing documented constructors/names retained |
| Sixteen examples and support algorithms | Baseline suite executed all; final suite/build status in validation. Generated pages are build outputs, not a second source of truth |
| Composite lecture/results, related packages, references | Kept empirical workload and accuracy context, independent QP distinction, CPU-only evidence, historical pins and adverse results |
| Benchmark READMEs and environments | Maintained instructions distinguished from frozen worker/evidence environments; historical manifests and results not rewritten. Large historical campaigns not rerun |
| Architecture manual and six diagrams | New normal navigation page with authoritative DOT sources, SVG renders, ownership/dispatch/type legend and representative source links |

## Remaining scope and verdict

The release verdict and exact validation editions are in [validation](validation.md).
The package needs an available compatible ProximalBase release before a registry
release of this development candidate. A general joint certificate for nonzero-
penalty exact square-root fits is outside the repaired CD contract. Broad logging
and result-status redesigns remain proposals, not hidden parts of this PR.
Physical GPUs, distributed execution, exhaustive alias/race/extreme-value tests,
all custom scalar losses, and all optional numerical backends are unverified.
