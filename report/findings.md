# Research report: stopping least-squares CD when the cached residual may be stale (#352 F2)

Audited revision `8cc022222d3c90ef86a24ca0c957b02faaf4fc1f` (ProximalBase pin `a19c59aa723d085d5d7cf5242895bda16eb77214`). No production code was changed and no implementation PR is proposed. All Julia runs were on a cluster (Slurm), under Julia 1.13.4 and 1.10.13, on two CPU kinds (AMD Zen 3; Intel Skylake-SP with AVX-512). Every table, the scripts and the prototype patches are on the branch `archive/issue-378-evidence` (section 9). The plan is in the [earlier comment](https://github.com/mlakolar/ProximalSolvers.jl/issues/378#issuecomment-6972272974); section 8 says where the work left it.

Notation, for `relative = true`: `thr = tol·√s‖y‖` is the threshold of the change test, `a_k = ‖X_k‖²`, and the scaled change of a visit is `√(s a_k)|h|`. `ρ(x) = eps(T)·√s·Σ_k ‖X_k‖|x_k|` estimates, in the unit of `thr`, the rounding error of a residual `y − Xx` computed at `x`; it is a first-order estimate, not a bound (section 7). `L(c) = max(tol, c·eps(T))·√s‖y‖` is the threshold with a floor.

## 1. Summary

**What happens.** A *false stop* below means: `converged = true`, the returned point is above the accuracy target of #352 (relative suboptimality above 1e-8 in Float64, 1e-5 in Float32, by a lower bound computed in 600-bit arithmetic), and an exact first visit at that point would change a coefficient by more than `p·thr` (in exact arithmetic a converged full pass leaves at most `(p−1)·thr`, #352 F8).

- One sweep of 1,667,350 solves has 264,795 false stops under `relative = true`. In every one the cached residual differed from `y − Xx` at the returned point by at least `thr`. The sweep has no false stop from an absorbed step with an accurate residual; such a case exists (section 3).
- A pass that changed nothing is not the marker. Between 9% and 13% of the false stops ended with a full pass in which no coefficient changed; in the others the last pass moved coefficients by less than `thr`. In the other direction, 6.6% of the Float32 solves with a vector penalty that converged from ordinary starts ended with such a pass, and all but 27 of those 7,603 are not above target.
- The false stops follow the size of the start. With starts `x_ref + 2^j z` (z scaled so that its largest column image equals `‖y‖`) most of them appear from `j = 8` to `12` in Float32 and from `j = 36` in Float64; section 3 has the exceptions at smaller j. From zero, the solution, a perturbed solution and the next point of a λ path there are none on a problem with a positive penalty. One ordinary start does give them: on the rank-deficient fixture, the unpenalized least-squares point used as a warm start for a penalized problem gives 158 (Float32) and 196 (Float64) false stops; that point has cancelling coefficients whose column images are millions of times larger than `y`.
- The default configuration for a vector iterate (random order with momentum) recomputes the residual before a full pass whenever momentum has moved it. On the designs where both ran it had 434 false stops from the large starts where cyclic order without momentum had 27,116 (Float32, dense input). The group lasso runs without momentum and had 38,936 with random order.

**Recommendation: documentation only (the first option).** No diagnostic and no stop rule met the conditions fixed in the plan, and the plan's rule for that case is documentation only:

- the statistic of the visit (A), with its floor, catches 6% of the false stops;
- the report-only rule (R) and the first stop rule (F), with floors calibrated on the fixtures of #352, lose 64 and 17 Float32 solves that must be kept on the generated designs, and cost more than 5% on small warm solves;
- a second stop rule (S), built after those results, loses none of the solves that must be kept in the sweep, removes all but 18 of the 114,053 false stops of the outcome sweep, and leaves every must-keep Float64 solve unchanged. It is still not a candidate: it is exploratory, its constant was chosen on the same data, and it reports `converged = false` at some exact solutions (section 5, "What S gets wrong"); one timing case also repeats above 5%.

What the documentation should say is in section 7. If the maintainer wants the solver itself to act, S is the rule to start from; section 7 lists what an implementation would have to settle first.

| on the same 912,116 inputs (Julia 1.13.4) | master | A | R | F | S |
|---|---|---|---|---|---|
| false stops left, Float32 / Float64 (vector penalties) | 60,871 / 53,182 | 57,445 / 49,808 | 22 / 0 | 0 / 0 | 18 / 0 |
| must-keep solves no longer converged, Float32 / Float64 | – | 0 / 0 | 64 / 0 | 17 / 0 | 0 / 0 |
| must-keep solves with a different flag, pass count, last change or KKT residual, Float32 / Float64 | – | 0 / 0 | 64 / 0 | 969 / 18 | 240 / 0 |
| large starts that end within target, Float32 / Float64 (vector penalties) | 152,066 / 131,563 | same | 109,595 / 115,154 | 213,887 / 180,984 | 213,546 / 178,660 |
| timing cases above 5% (of 260; Skylake-SP, Julia 1.13.4, exclusive) | – | 0 | 23 | 51 | 0 |

## 2. What was run

- **Sweep.** 49 designs: the ten fixtures of #352 and 39 generated ones (n×p of 40×12, 100×30 and 50×200 with equicorrelation 0, 0.5, 0.95 and 0.999, three seeds each; 5000×20; 2000×50; a 100×30 design with column norms over six decades). Lasso at λ/λmax of 0, 1e-3, 0.1 and 0.5, elastic nets, ridge, and the group lasso with two layouts; raw and mean-scaled loss; Float32 and Float64. Starts: zero, the reference solution, a perturbation of it, the unpenalized least-squares point, the next point of a λ path, and `x_ref + 2^j z` for five directions z (null space, smallest singular vector, the most correlated pair, one coordinate, dense) over a ladder of j. Cyclic and random order, with and without momentum, dense input and `SparseIterate`; `tol` from 1e-4 down to 1e-16; `relative` true and false. 1,667,350 solves per run; four runs (two Julia versions × two CPU kinds), all complete.
- **Instrumentation.** Each solve goes through a wrapper model that forwards every call to the package's model and records the visits of the last pass. All rows are from wrapper solves that were bit-identical to a plain `solve!` of the same input (none had to be dropped).
- **Reference values.** For every returned point, in 600-bit `BigFloat`: the objective against a reference (upper and lower bound of the relative suboptimality), the KKT residual over `max(λ1, λmax)`, the largest scaled change `E` of an exact first visit, and the distance between the cached residual and `y − Xx`. These are high-precision evaluations, not interval certificates.
- **Prototypes.** Four patches against the audited revision, each compiled from source as its own module beside an unchanged copy (master) in the same process: A (statistic in the visit), R (report only), F (stop rule with a path statistic), S (stop rule, section 5). Each solved 912,116 inputs next to master (three configurations, `tol` 1e-7 and 1e-4). Of these, 896,500 are inputs of the sweep, and on them master's rows equal the sweep's rows (flag, passes, last change, KKT); the others are the same problems in a configuration that the sweep skips on its large designs.
- **Timing.** Master, a second copy of master (the control) and the prototypes in one process; per case the minimum over batches, per round one ratio, alternating order; the median and the largest ratio over nine rounds. 260 cases: designs from 40×12 to 2000×200, cold and warm starts, lasso, elastic net and group lasso, Float32 and Float64. One process per run on a machine used exclusively by it, except where noted.

## 3. Task 1: when a rounding-dominated full pass occurs at a non-stationary point

Counts are from the Julia 1.13.4 run on Zen 3, `relative = true`, all configurations. The four runs differ in the third or fourth digit of these counts (Float32 false stops for vector penalties: 88,226, 88,387, 88,235 and 88,112).

**By size of the start** (lasso, elastic net and ridge; "false" = false stop as defined above):

| start | Float32 converged | Float32 false | Float64 converged | Float64 false |
|---|---|---|---|---|
| zero, λ-path point | 36,383 | 0 | 44,840 | 0 |
| reference solution or its perturbation | 54,850 | 128 | 67,933 | 64 |
| unpenalized least-squares point | 24,080 | 158 | 29,955 | 196 |
| `x_ref + 2^j z`, j = 0 | 28,881 | 80 | 28,930 | 80 |
| j = 8 | 27,086 | 122 | 27,244 | 80 |
| j = 12 | 24,922 | 653 | – | – |
| j = 16 | 23,601 | 7,785 | 23,848 | 80 |
| j = 20 | 23,526 | 15,319 | – | – |
| j = 28 | 21,978 | 15,294 | 22,904 | 64 |
| j = 36 | – | – | 22,454 | 480 |
| j = 40 | – | – | 22,256 | 4,154 |
| j = 48 | – | – | 22,197 | 13,920 |
| j = 60 | – | – | 23,265 | 16,563 |

Every false stop in the first three rows and at j ≤ 4 (and the 80 or fewer per row in Float64 up to j = 32) is on the rank-deficient fixture, except two at j = 4 in Float32: with λ = 0 its reference solution is itself a least-squares point with huge cancelling coefficients, and the rows with a positive penalty are the warm start from the least-squares point (for which `ρ(x0)/(eps·√s‖y‖)` is 7e6 in Float32 and 2e15 in Float64). The group lasso has its first false stops at j = 4 to 8 in Float32 and at j = 36 in Float64 (58,110 and 42,784 in all) and none from ordinary starts.

**The residual.** For each false stop the tables record the distance between the cached residual and the true one at the returned point. It is at least `thr` in all 264,795. That distance does not say when the error entered (at the initialization or during the updates); the dependence on the size of the start above is the evidence for the initialization. Three situations were reproduced by hand (`cases/repro-release.txt`):

- the reproducer of #352 (`X = [1 1]`, `x0 = [M, −M]`): the initial residual loses `y` altogether, every step is absorbed by the large coefficients, the first pass changes nothing;
- the same with λ = 0: the correlation computed from the cached residual is exactly 0, so a statistic computed from the visit's own `b` is 0;
- a start `2^j e_1` on a well-conditioned design: the iterate returns to ordinary size and the solve converges in the ordinary number of passes with a cached residual that is wrong (Float64, j = 50: KKT residual 5.9e-3 of λmax; Float32, j = 22: 1.1e-2).

Between 87% and 91% of the false stops have a last pass that moved coefficients, as in the third situation.

**An absorbed step with an exact residual** can also stop falsely, although the sweep has no such stop. With `X = [1 1; 0 0]`, `y = [0, 1]`, `x0 = [M, −M]` and `λ = 1/1024` (M as in the reproducer) the initial residual `[0, 1]` is exact, both correlations are 0, and the shrinkage by λ is absorbed by the large coefficients; the pass changes nothing at a point whose objective exceeds the minimum by `2Mλ`. This case was pointed out in review and follows by exact binary arithmetic; it was not run.

**By configuration** (Float32, starts `x_ref + 2^j z`; Float64 is alike). The configuration with default momentum did not run on the large designs, so the third row has fewer inputs than the first; restricted to the designs of the third row, the first row has 69,244 converged solves and 27,116 false stops.

| configuration | converged | false stops |
|---|---|---|
| dense input, cyclic, no momentum | 72,167 | 28,123 |
| `SparseIterate`, random, no momentum | 75,612 | 30,924 |
| dense input, random, default momentum | 74,694 | 434 |
| groups, cyclic | 44,594 | 19,174 |
| groups, random | 90,625 | 38,936 |

**`relative = false`.** The same stops occur (for example 3,606 Float32 solves that converged above target with an empty last pass from the large starts). The prototypes act only under relative scaling.

## 4. Task 2: diagnostics at a converged full pass

Evaluated offline on the recorded stops of the sweep. Populations for vector penalties: *must keep* = ordinary start, positive penalty, `tol` of 1e-7 or 1e-4, converged on master and not above target (49,974 Float32 and 42,891 Float64 solves); *false* = the false stops (88,226 and 75,675). For groups the populations are 8,248 and 6,678, and 58,110 and 42,784. A floor c means that the statistic is compared with `max(tol, c·eps(T))` in its unit instead of `tol`. The Float64 figures are the same at every floor because `c·eps(Float64)` is below `tol` there. The table is for vector penalties.

| diagnostic | extra work | must keep refused, Float32 (c = 0 / 64 / 1024 / 4096) | false stops caught, Float32 (c = 64 / 1024 / 4096) | Float64: refused, caught |
|---|---|---|---|---|
| A: unrounded step of a visit that changed nothing, from the visit's own `b` | a test in each zero-change visit | 674 / 0 / 0 / 0 | 5.77% / 5.76% / 5.76% | 0, 6.6% |
| C352: final-point statistic of #352 (fresh residual, every coordinate) | a residual and p products | 8,929 / 1,643 / 1,024 / – | 99.97% / 99.87% / – | 2,396, 100% |
| K: KKT residual in working precision (the form of #296) | a residual and p products | 20,287 / 5,344 / 4,089 / – | 99.98% / 99.88% / – | 7,166, 100% |
| R: distance between the cached and a recomputed residual | a residual | 14,751 / 550 / 114 / 0 | 99.998% / 99.91% / 99.84% | 0, 100% |
| ρ(x) ≥ L at the stop | one sum over the nonzeros | 13,468 / 248 / 0 / 0 | 8.1% / 6.1% / 5.8% | 0, 6.6% |
| ρ(x) ≥ L at the stop or ρ(x0) ≥ L at the start | two sums | selects (c = 64 / 1024 / 4096) 1,472 / 528 / 80 | 99.998% / 99.97% / 99.92% | selects 72, 100% |

The last two rows use the sums `ρ` themselves, at the start of the solve and at the stop. Prototype S tests related but different quantities (section 5), so these rows are not an evaluation of S; its decisions are measured in section 5.

- **A, with or without a floor, catches the reproducer and little else**: 11% of the false stops without a floor and 6% from c = 64. Without a floor it also refuses 674 must-keep Float32 solves; from c = 16 it refuses none (for groups, two at c = 16 and none from c = 64).
- **Statistics of the final point from a recomputed residual (C352, K) catch nearly everything and refuse too much**, with any floor. In Float64, where the floor plays no part, they refuse 2,396 and 7,166 must-keep solves: after a converged pass an exact first visit may still move a coordinate by up to `(p−1)·thr` (#352 F8), and these statistics test every coordinate against `thr`. In Float32 they refuse more. The count of #352 for this check is reproduced exactly on #352's population (91 of 480 in Float32, 14 of 480 in Float64).
- **R separates the two populations in Float64 at any floor. In Float32 it needs a floor of 4096 for vector penalties and of 16384 for groups** (at 4096 it still refuses 31 of the 8,248 must-keep group solves). The must-keep solves it refuses below that are long Float32 solves on ill-conditioned designs. Over the must-keep solves the largest distance between the cached and the recomputed residual is 3,146 `eps·√s‖y‖` for vector penalties (34,475 passes at `tol = 1e-7`, suboptimality 4.7e-8, KKT residual 2.4e-4 of λmax) and 13,190 for groups (99,079 passes, suboptimality at most 1.3e-6, KKT residual 3.7e-3).
- **`ρ(x) ≥ L` at the stop** holds where the iterate is still huge (the reproducer). No must-keep solve reaches it from c = 256: the largest `ρ(x)/(eps·√s‖y‖)` over the must-keep solves is 114 for vector penalties, in all four runs. Adding the same test at the start selects all but a few of the false stops (the largest KKT residual among those it misses at c = 1024 is 1.6e-5 of λmax) and 528 of the 49,974 must-keep solves.
- **Empty passes only.** The plan also asked for each diagnostic restricted to stops whose last pass changed nothing. No table was made for that restriction: it cannot catch more than the 9% to 13% of the false stops that end with such a pass.

## 5. Prototypes and their outcomes

- **A** (floor 64): the statistic above; a stop with a refusable absorbed step ends with `converged = false`.
- **R** (floor 256, report only): where `ρ(x) + 2·eps(T)·path ≥ L` (path = the sum of the scaled changes of all visits of the solve, accumulated in the sweep), compare the cached with a recomputed residual; a distance of `L` or more ends the solve with `converged = false`.
- **F** (floor 64, stop rule): where the same gate fires, recompute the residual, set the path to zero and continue with a full pass; accept a stop from a pass that started from the recomputed residual; with A's refusal.
- **S** (floors 256 and 1024, stop rule), at a full pass whose largest change is below the threshold:
  1. if `ρ(x) ≥ L`: stop with `converged = false`;
  2. otherwise, if `eps(T)·√s·max_k‖X_k‖·Σ_k|x0_k| ≥ L` for the point `x0` from which the residual in use was last computed from scratch (the start, or a refresh of the momentum loop): recompute the residual, clear that mark, and continue with a full pass;
  3. otherwise stop with `converged = true`, as on master.

  For groups the patch uses `Σ_g √ℓ_g‖x_g‖` with the curvature bound `ℓ_g` of the group in place of `Σ_k‖X_k‖|x_k|`, and `max_g √ℓ_g · Σ_g‖x0_g‖` in rule 2. The coordinate step and the sweep are those of master; the additions are one sum in the loop that computes the residual from scratch and a few sums at a converged full pass.

Floors for A, R and F were fixed from the ten fixtures with a factor of 4 to spare, as pre-registered, before the generated designs were analysed. S and its floors came after (section 8).

**Must-keep inputs** (ordinary start, positive penalty, converged on master and not above target; vector penalties + groups: 19,186 + 5,496 in Float32, 16,387 + 4,448 in Float64):

| | A | R | F | S, c = 256 | S, c = 1024 |
|---|---|---|---|---|---|
| Float32: no longer converged | 0 | 62 + 2 | 6 + 11 | 0 | 0 |
| Float32: more passes than master | 0 | 0 | 918 + 51 | 328 + 0 | 240 + 0 |
| Float32: total passes, vector penalties | same | same | +6.3% | +0.04% | +0.015% |
| Float64: no longer converged | 0 | 0 | 0 | 0 | 0 |
| Float64: more passes than master | 0 | 0 | 18 + 0 | 0 | 0 |

All the solves that R and F lose are Float32 solves on generated designs with equicorrelation 0.95 or 0.999, at `tol = 1e-7` but for two of R's at `tol = 1e-4`. R stops them with `converged = false`; F runs each of them to the pass cap, and the largest increase in passes with F is 95,951. Neither lost a solve on the ten fixtures.

**False stops** (vector penalties: converged, above target, `E > p·thr`; all starts):

| | master | A | R | F | S, c = 256 | S, c = 1024 |
|---|---|---|---|---|---|---|
| Float32 | 60,871 | 57,445 | 22 | 0 | 2 | 18 |
| Float64 | 53,182 | 49,808 | 0 | 0 | 0 | 0 |

The 18 that S leaves at c = 1024 are Float32 solves with λ = 0 on two small fixtures from starts with j = 4 and 8; their KKT residual is at most 1.6e-5 of λmax. For groups the outcome sweep recorded no `E`; with the proxy "converged above target with a KKT residual more than 10 times the largest one master reaches on the same problem from ordinary starts", master has 40,180 (Float32) and 29,954 (Float64) such stops, A 36,292 and 26,320, R 186 and 106, F 304 and 226, S at c = 1024 368 and 194.

**The large starts** (`x_ref + 2^j z`, vector penalties; 273,456 Float32 and 296,244 Float64 inputs):

| Float32 / Float64 | master | A | R | F | S, c = 1024 |
|---|---|---|---|---|---|
| converged within target | 152,066 / 131,563 | 152,066 / 131,563 | 109,595 / 115,154 | 213,887 / 180,984 | 213,546 / 178,660 |
| stopped with `converged = false` before the pass cap | 0 / 0 | 6,422 / 5,906 | 114,832 / 83,736 | 242 / 230 | 8,903 / 7,484 |
| of those, the returned point was within target | – | 0 / 0 | 42,471 / 16,409 | 0 / 0 | 0 / 0 |
| reached the pass cap (5,000) | 44,088 / 58,470 | same | 44,089 / 58,470 | 52,172 / 65,117 | 44,555 / 58,945 |
| passes, relative to master | 1 | 1 | 1 | 1.147 / 1.088 | 1.017 / 1.008 |

**Ordinary starts under S** (c = 1024). Rule 1 stops 68 Float32 and 24 Float64 solves that master reports converged: 48 are the λ = 0 problem on the rank-deficient fixture started at its huge least-squares point (all above target on master), and 44 are Float32 solves of the λ = 0 problem on two wide designs with equicorrelation 0.999, started at or near a reference solution with `ρ(x) ≥ L` (none of them is shown within or above target). None has a positive penalty. Master's other false stops from ordinary starts are not false stops under S. S takes more passes than master in three situations: the warm start from the least-squares point on the rank-deficient fixture (up to 394 more in Float32 and 504 in Float64); the same start on the wide designs with equicorrelation 0.999 (Float32, up to 135 more); and, in Float32, the two designs with column norms over six decades, where the bound of rule 2, which uses the largest column norm, reaches `L` at points of ordinary size. There S recomputes the residual after a computation from scratch, also from a zero start in the momentum loop: one more pass in most of these solves, up to 28 in a few, and about 1,100 (of 4,600) in four group solves with λ = 0 from the perturbed start.

**What S gets wrong.** Found in review with probes on the archived patch (`review/`), not by the sweep:

- *It refuses exact solutions with heavy cancellation.* For `X = [1 1; 0 δ]`, `y = [−λ, 1 + 1/512]`, `x0 = [−M, M]`, `M = 2^20` (Float32) or `2^40` (Float64), `δ = 1/M`, `λ = δ/1024`, the start is the exact lasso minimizer (KKT residual 0). Master returns `converged = true` after one empty pass; S returns `converged = false` after the same pass, because `ρ(x0) ≥ L`. Rule 1 does not tell this point from the reproducer, and no finite constant removes the class: any stop at a point with `Σ_k‖X_k‖|x_k| ≥ max(tol/eps(T), c)·‖y‖` is refused.
- *For groups the test is looser than `ρ`.* With `X = diag(1, δ)`, `y = [0, 1 + 1/1024]`, `x0 = [0, M]` and the penalty `GroupNormL2(λ, [[1, 2]], [1])` (one group with unit weight, λ as above), the start is again an exact minimizer, with no cancellation at all (`ρ(x0)` is about `eps(T)·√s‖y‖`), and S refuses it: `√ℓ_g‖x_g‖` charges the large coefficient of the small column with the norm of the large column. With `NormL1(λ)` the same input makes rule 2 recompute a residual that was exact: two passes where master takes one, and `converged = false` with `maxpasses = 1`.
- *The group sums of squares are not range-safe.* With columns of size `2^300`, coefficients `±2^-600` and `y = 2^-360` (Float64, one group, λ = 0), the squares of the coefficients underflow to 0 in the patch's sums, both tests pass, and S returns `converged = true` at the same non-stationary point as master, with `ρ(x)/L = 5e9`. The correlations and the loss of this input are normal numbers; this is a defect of the patch, apart from F1 and F3 of #352.

The counts of this section are therefore counts on the sweep's inputs: "no must-keep solve lost" does not extend to solutions with cancellation of three decimal digits or more in Float32.

## 6. Task 3: cost on the ordinary path

Ratio to master of the time of one solve, 260 cases per run. A case counts as above 5% only where the control copy of master is within 2% of master in the same case. Each cell: median over the cases, median over the warm cases, largest case, number of cases above 5%. S was timed in two builds that differ in one constant (c = 256 and c = 1024).

| run | A | R | F | S, c = 256 and c = 1024 |
|---|---|---|---|---|
| 1.13.4, Skylake-SP | 1.008, 1.015, 1.042, 0 | 1.013, 1.037, 1.099, 23 | 1.020, 1.045, 1.076, 51 | 1.009, 1.016, 1.048, 0 and 1.010, 1.020, 1.049, 0 |
| 1.10.13, Skylake-SP | 1.005, 1.010, 1.068, 3 | 1.010, 1.020, 1.060, 2 | 1.013, 1.026, 1.056, 3 | 1.007, 1.018, 1.069, 2 and 1.008, 1.022, 1.112, 25 |
| 1.13.4, Zen 3 | 1.007, 1.012, 1.051, 1 * | 1.014, 1.031, 1.120, 21 * | 1.024, 1.049, 1.108, 50 * | 1.006, 1.011, 1.071, 1 and 1.004, 1.013, 1.059, 3 |
| 1.10.13, Zen 3 | 1.004, 1.006, 1.032, 0 * | 1.010, 1.020, 1.060, 6 * | 1.012, 1.031, 1.077, 11 * | 1.007, 1.015, 1.041, 0 and 1.007, 1.014, 1.057, 2 |

\* on a machine shared with other jobs; the control was within 2% in 235 and 253 of the 260 cases.

- **R and F exceed 5% on small warm solves in every run.** Both add one accumulation per visit to the sweep (the path) and work at the stop. On the exclusive Skylake-SP run under Julia 1.13.4 all 14 solves under 1 µs are above 5% with F (median 6.6%).
- **A stays under 5% except for three cases in one run and one in another.**
- **S: one case repeats above 5%.** The plan's rule is that a case above 1.05 with its control within 1.02 is repeated in a separate run and escalated if it repeats. All four S runs were repeated. For the build with c = 1024, one case is above 5% in a run and in its repetition: a warm lasso solve on a 40×12 design with a `SparseIterate`, Float32, 0.5 µs, under Julia 1.13.4 on Zen 3, at 5.5% and 6.0% (control 1.3% and 0.4%). The build with c = 256, which is the same code but for the constant, shows 2.0% and 4.8% for this case in the same two runs, and no case of that build repeats. In the other three environments no case of either build repeats.
- The cases above 5% change from one process to the next: per build, the first runs have 0 to 25 of them and the repetitions 0 to 9 (under Julia 1.13.4 on Skylake-SP: none in the first run, eight and nine in the repetition). The medians are steadier: over the warm cases 1.1% to 2.2% in the first runs and 1.0% to 1.7% in the repetitions; over the cold cases at most 0.4%.
- In absolute terms, the median over the warm solves of a vector penalty under 10 µs of (ratio − 1) × master's time is 15, 34, 31 and 52 ns for the build with c = 256 and 18, 38, 28 and 89 ns for c = 1024 (Zen 3 and Skylake-SP under 1.13.4, then under 1.10.13; first runs). The work S adds depends on the number of coefficients and of nonzeros, and on whether rule 2 fires.
- **Allocation.** The model struct grows. A warmed solve allocates 32 (Float32) or 64 (Float64) bytes more than on master with A, R and F, and 16 or 32 with S: in every case under Julia 1.10.13, and under 1.13.4 in all but a few cases, in which the control copy of master also differs from master.
- An earlier build of S that searched the largest column norm with an unvectorized loop is in the archive (`time2-*`, `prototypes/S-first-build`); the build reported here tries a bound from a vectorized sum first. The rows of the two builds are identical in the outcome sweep (2,736,348 rows under each Julia version).

## 7. Task 4: recommendation and the contract of `converged = true`

**Recommendation: documentation only.** The plan fixed what a rule had to show to be a candidate (the reproducer and its λ = 0 variant refused; no must-keep solve refused on the fixtures and on the generated designs, with a factor of 4 to spare in the floor), and documentation only as the outcome if none did; a repeated timing case above 5% was to be escalated. None is a candidate: A does not refuse the λ = 0 variant, R and F lose must-keep solves, and S is exploratory, has no held-out validation and has the defects of section 5. Its repeated timing case is a decision for the maintainer if S is taken up. The contract of `converged = true` stays the one #352 recorded: the last pass was a full pass in which no coefficient or group changed by `thr` or more, measured with the solver's cached residual; it says nothing about the accuracy of that residual.

**What to document** (the page on stopping limits already has the reproducer):

- the observed risk factor: a start whose column images are far larger than the response. On most designs of the sweep the false stops begin where the largest column image of the start is 2^8 to 2^12 (Float32) or 2^36 (Float64) times `‖y‖`, but the sweep also has them from smaller starts (the rank-deficient fixture at every j, and two Float32 solves at j = 4 whose start has column images that sum to 29 `‖y‖`), so no size of the start can be documented as safe;
- the ordinary start that meets it: an unpenalized fit on a rank-deficient design, used as a warm start;
- which configurations the sweep shows exposed: cyclic order, random order without momentum, and the group lasso; the default for a vector iterate much less (434 false stops against 27,116);
- something to try: call `solve!` again from the returned point. This recomputes the residual; it is not guaranteed to improve the result and was not measured. What was measured is prototype S, which recomputes the residual inside the solve (in another order of summation than the initialization): in the outcome sweep it ended 61,533 of master's 70,460 Float32 stops above target from large starts within target (in Float64 47,119 of 97,635, of which 53,120 were false stops). A second solve still fails on the reproducer, where the large cancelling coefficients remain.

**If the solver should act: S, after these are settled.**

1. *The refusal of exact solutions with heavy cancellation* (section 5). It is a property of rule 1, not of the constant. The maintainer would have to accept `converged = false` at every stop with `Σ_k‖X_k‖|x_k| ≥ max(tol/eps(T), c)·‖y‖`, or the rule needs a second test at such points, which this study did not design.
2. *The bounds.* Rule 2 uses the largest column norm and the group tests use the curvature bound of the group. Both are loose where column norms differ by orders of magnitude, and cost passes or refuse solves there. The sums of squares need range-safe forms.
3. *The constant.* c = 1024 was chosen on the whole sweep: over the must-keep solves the largest `ρ(x)/(eps·√s‖y‖)` is 114 for vector penalties, and the group test of the patch refused no must-keep solve at c = 256. There is no held-out validation.
4. *The cost* (section 6): the repeated case at 5.5% and 6.0%.
5. *What the tests are.* Under the measured patch (with `relative = true`, `y ≠ 0`, and apart from the range defect of section 5), `converged = true` means that the change test passed, that the computed `ρ(x)` is below `L`, and one of two things: the bound of rule 2 for the point of the last computation of the residual by the initialization or by the momentum loop is below `L`, or S itself recomputed the residual at a point where the computed `ρ` was below `L`. In the second case S clears its mark and does not form the bound of rule 2 at that point, which can exceed `L` there (the diagonal example of section 5). For groups the group forms of section 5 take the place of `ρ`. It would not mean that the residual is accurate: `ρ` has no term for the number of terms or for `‖y‖`, and is not a bound. With `y = [1]`, 8,192 unit columns and coefficients `eps(Float32)/4`, the package's initialization returns the residual 1 where the exact one is `1 − 2^-12`: an error above `L(1024)` at a point with `ρ` of `2^-35` (by exact binary arithmetic, pointed out in review; not run). Nor does a refusal mean that the residual is inaccurate (item 1).

**What neither the documentation nor S covers.**

- The rounding that the updates themselves accumulate. On long Float32 solves the cached residual is thousands of `eps·√s‖y‖` away from the true one at solves that are within target (section 4). R and F carry a statistic in the sweep for it; they cost more than 5% and lose must-keep solves.
- `relative = false` and `y = 0`: S is inactive there, and section 3 shows the same stops under `relative = false`.
- F1 and F3 of #352 (underflow and cancellation of the products).

**Delete, consolidate, keep.**

- Delete: nothing in the package. Not to pursue: the statistic in the visit (A), final-point statistics from a recomputed residual (C352, K), the path statistic in the sweep (R, F).
- Consolidate: the new paragraph into the existing page on stopping limits. If S is taken up, its refusal belongs in the outcome `_stop_check!` already has for the square-root lasso (`:uncertified`) and its warning.
- Keep: the change test, `tol` and its default, both loops, the coordinate step and the sweep, the Float32 and Float64 paths, momentum, and the owner, RNG and rollback behaviour.

**Decisions for the maintainer.** (1) Documentation only, as recommended, or an implementation issue for S with the five items above as its scope. (2) If documentation: whether the paragraph above goes into the stopping-limits page now.

## 8. Against the plan

- **Calibration did not transfer.** The plan fixed floors on the #352 fixtures with a factor of 4 to spare and validated them on the generated designs. For R (256) and F (64) the validation failed: 64 and 17 must-keep Float32 solves lost, all on generated designs.
- **S was not in the plan.** The plan listed the estimate `ρ` at the start and at the stop as a statistic; the rule built on it was added when the planned finalists failed, and its floors were chosen after the whole sweep had been seen. It is exploratory, and the recommendation follows the plan's rule for the case that no pre-registered candidate survives.
- **Must refuse.** The reproducer and its λ = 0 variant, both precisions: refused by R, F and S (by S at the pass at which master stops); A refuses only the variant with λ > 0.
- **Timing rule.** Applied as written in section 6: one case of S (c = 1024) repeats. A first draft of this report counted a case only where both builds exceeded 5%, a filter the plan does not have; under it no case repeated. For R and F, cases above 5% appear in all four runs; those runs were not repeated.
- **Efficacy measure for groups.** The outcome sweep recorded no `E` for groups, so the group figures of section 5 use a KKT proxy in place of the plan's measure.
- **Not reported.** The diagnostics restricted to empty passes (section 4). The must-keep solves with `tol` below `eps(T)`, which the tables list in a column of their own (Float32 at `tol = 1e-7`), are not discussed apart, and the outcome sweep of the prototypes did not include the tolerances below 1e-7 of the sweep.
- **Coverage.** The outcome sweep of A, R and F ran under Julia 1.13.4 only; that of S under both versions (under 1.10.13, at c = 1024: no must-keep solve lost, 239 Float32 ones with more passes and at most 147 more, every Float64 one unchanged, 16 Float32 false stops left and none in Float64, no refused solve within target). The timing of A, R and F on Zen 3 was on a shared machine.
- **Review.** A first draft recommended S. An independent review (Codex) requested changes: the three defects of S in section 5, the repeated timing case, a contract that claimed more than the tests establish, offline rows of section 4 presented as an evaluation of S, and several wrong group figures. The recommendation and those passages were rewritten. A second round found two further errors in the rewritten text (the statement of what S's tests establish after its own recomputation, and a first-failure scale that the sweep contradicts) and four smaller ones. The third round passed with no findings; it accepts the report, not an implementation of S. The three reviews and the reviewer's probes are in `review/`.

## 9. Evidence

Branch `archive/issue-378-evidence` (an orphan branch, not for merge), with a `README.md` and `SHA256SUMS`:

- `plan/`, `report/`, `review/` (the reviews, the reviewer's probes and their output);
- `study/`: the sweep, the wrapper model and the 600-bit measures, the prototype builders, the timing harness and the analysis scripts (Python, standard library);
- `prototypes/`: the patches of A, R, F and S against the audited `src`;
- `tables/`: every table this report quotes (`sweep-*-tables.txt` for sections 3 and 4, `*-rules3.txt` for the last rows of the table of section 4, `proto*-tables.txt` for section 5);
- `timing/`: the raw output of the timing runs and their summaries;
- `cases/`: the hand-built cases on master and on the prototypes;
- `checksums/`: SHA-256 of every raw result file and of the code that produced it.

The raw rows (one per solve, about 0.6 GB compressed) are too large for a branch of this repository. They are kept with the local records of the run, and their checksums are on the branch.
