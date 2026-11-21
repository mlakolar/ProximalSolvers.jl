## Stage 2 research report: widened gap evaluator (C), stop-reason design (A), recommendation

This is Stage 2 under the [maintainer ruling](https://github.com/mlakolar/ProximalSolvers.jl/issues/320) after #510: research prototypes only, with no production change and no PR. Candidate B was dropped by that ruling.

**Recommendation: retain the existing behaviour and close #320 with the limitation accepted.** Float32 `converged = true` remains a computed-KKT result (STOP-19).
- **Do not implement C in the package.** Its measured stopping benefit depends on overriding two existing exits. The evaluator is exploratory: it has no error bound, and it can report a zero gap on adversarial inputs (§2). The same check already runs through a user callback.
- **Do not implement A.** A stored `stop_reason` would add a public result field. Almost all of its information is already available to callers, and this study shows no use case for the rest (§8).
- **Optional documentation:** a callback example (§6) for users who want an exploratory Float32 lasso gap check, with its caveats. Whether to add it is the maintainer's call.

### Summary
1. **On the sample checked, the widened evaluator agreed closely with a 256-bit reference.** Over 13,100 sampled Float32 iterates, the largest relative difference was `4.6e-9`. A comparator that reuses rounded Float32 products was off by up to 163%. The sample was selected partly by the evaluator itself (§3). The evaluator has no error bound, and two constructed inputs make it report 0 where the exact gap is 0.77 and 0.25 (§2).
2. **No hypothetical gap stop was a false success, in any tested cell.** All 4,983 successes across 108 rule × population × arm × version cells had a finite 256-bit gap at or below `gaptol`; the smallest margin was a relative `7e-6` below it.
   - On Float32 PGD at `1e-5`, stopping on the widened gap succeeded in 50/50 harness solves on each Julia version. The current harness options (H) gave 11/50 within target, with 25/15 false successes on 1.10.13/1.13.4.
   - On the adverse set it succeeded in 56/70 and 59/70. The remaining solves did not reach the target within the 10,000-iteration recorded budget, all on the two ill-conditioned low-λ designs. Some draws of those designs did succeed, Float64 included.
3. **The benefit requires that computed objective increases do not end the solve.** With the current increase exit kept, and an increase given priority over a gap pass at the same iteration, the rule succeeds in 24/12 of 50 harness solves and 1/0 of 70 adverse solves.
4. **Cost.**
   - One evaluation measured about 1.0 to 1.5 Float32 product pairs (`X*x` and `Xᵀr`), roughly one gradient, and 2.7% of a current full solve. It allocated nothing on 1.13.4.
   - Projected evaluation cost, using a constant per-iteration time: about 5 to 12% of the run's own iterations when evaluating every 10 iterations or only where the KKT check passes; 49 to 78% when evaluating every iteration.
5. **The tested callback reproduced the trajectory rule.** With the options listed in §6, the callback stopped at the same iteration as the trajectory rule in all 70 tested Float32 PGD solves, with no false success. With other options, ordinary stops can end the solve first, above target (§6).

### 1. Provenance and reproducibility
- **Code and environments:**
  - ProximalSolvers master `49d0242e`; the PS src fingerprint is `627d855f…`.
  - ProximalBase `0.6.0-DEV` at `bc9e888d` (git-tree `e3aa6977…`). Julia 1.10.13 used `Manifest-v1.10.toml`. Julia 1.13.4 used a freshly resolved `Manifest.toml` at the same PB revision.
  - One Julia thread and one BLAS thread in the runs. The local callback provenance file samples the BLAS setting before the script sets it, and so prints 10.
- **Where it ran:** a cluster (Slurm). Trajectory and degenerate runs used AMD EPYC 7513, EPYC 7542 and Xeon Silver 4116 nodes. The timing ran on Xeon Silver 4116 (§5). The callback check ran on a local i5-13600K.
- **Archive:** scripts, the preregistration (sha256 recorded before the runs), raw TSVs, logs, the full analysis output and this report are on this branch (`archive/issue-320-stage2-evidence`, the commit that contains this file), with a `SHA256SUMS` manifest. Paths and host names are scrubbed.
- **Reproduction:**
  1. `julia --project=. scripts/s2traj.jl <out> 1:10 <design>`
  2. `s2degen.jl <out>`
  3. `s2time.jl <out> 1:5`
  4. `s2callback.jl <out>`
  5. `python3 -I scripts/analyze.py results/cluster <phase0 archive>`

  `report/analysis.txt` holds the full output, including the percentiles and per-cell counts not repeated here.
- **Problems:** the Phase 0 builders, unchanged: five harness designs and seven adverse designs, 10 draws each. In 709 of 720 solver-arm rows, the data hash equals the Phase 0 summary's. Each Float32 problem appears twice, for PGD and APG. Phase 0 already reported that some warm and `lasso` inputs depend on the CPU kind; the 11 differences have not been attributed individually.

### 2. Prototype C (`scripts/gapeval.jl`, outside `src/`)
- **Scope:** unweighted `NormL1` with `s * LeastSquaresLoss`, taking the stored `X`, `y`, `s` and `λ` and a coefficient vector `x`.
- **Products:** `r = y - Xx` and `z = Xᵀr` are recomputed in Float64 from the stored values; no solver product is reused. The main kernel W1 widens on the fly and allocates nothing. The alternative W2 keeps a Float64 copy of `X` and uses BLAS.
- **Dual point and gap:** the dual point is that of STOP-13, `θ = κ s r` with `κ = min(1, λ/(s‖z‖∞))`. A computed `z = 0` gives `κ = 1`.
  - The gap uses the form `(1-κ)² f + (1-κ) λ‖x‖₁ + κ(λ‖x‖₁ + ⟨∇f, x⟩)`, which avoids subtracting `D` from `P` but still subtracts inside the last term. The direct `P - D` form is also reported.
  - The relative gap is `max(gap, 0)/P`. It is set to 0 when the computed `P` and gap are both 0 (`:zero_objective`). A nonfinite `P`, `D` or gap returns `:nonfinite`. The contract proposed in §7, question 6, is stricter, because a computed zero can come from underflow.
- **Rounding sources.** Products of Float32 entries are exact in Float64. The summations in `r` and `z`, the products with the widened residual, and the final arithmetic all round.
- **Limitations.** No error bound is derived and no certification is claimed. The computed `z` can make `θ` slightly infeasible. Summation can also cancel completely:
  - For one Float32 column `[2^60, 1, -2^60]` with `y = ones(3)`, `x = 0`, `s = 1` and `λ = 0.125`, W1 computes `z = 0` and reports relative gap 0. The 256-bit value at the same dual-point definition is 0.765625.
  - On Float64 data, `X = [1]`, `y = [1e-170]`, `x = 0`, `s = 1` and `λ = 5e-171` underflow to `P = 0` (`:zero_objective`, gap 0), where the 256-bit value is 0.25.

  Both cases were reproduced locally.

### 3. Agreement with a 256-bit reference on a selected sample
The reference recomputes the same dual-point definition in BigFloat(256) from the stored inputs, widened exactly. Its arithmetic is finite-precision; it is a numerical reference, not an exact value.

**Selection.** BigFloat was evaluated at:
- every rule stop and the H stop;
- iterates whose **W1** gap was within a factor 3 of the target, up to 60 per trajectory;
- every 50th iterate, up to 40, until the trajectory ended.

The sample is therefore enriched by the evaluator under test. The "near target" columns below group iterates by their BigFloat value after that selection. Every success was checked, so the selection does not affect the false-success count. It does limit any claim about the evaluator's error elsewhere, and about crossings it might have missed.

| Arm, Julia | Iterates (near target) | W1 max / p99 | W1 max near target | P−D form max | W2 max | Rounded-product comparator: max / near-target max / >2× underestimate |
|---|---|---|---|---|---|---|
| F32 PGD 1.10.13 | 3263 (1858) | 2.7e-9 / 1.3e-9 | 2.3e-9 | 3.6e-8 | 8.0e-9 | 1.40 / 0.79 / 67 of 1858 |
| F32 PGD 1.13.4 | 3209 (1943) | 3.4e-9 / 9.4e-10 | 1.7e-9 | 2.8e-8 | 3.2e-9 | 1.01 / 0.77 / 16 of 1943 |
| F32 APG 1.10.13 | 3376 (2321) | 3.2e-9 / 8.2e-10 | 1.6e-9 | 2.4e-8 | 4.2e-9 | 1.63 / 0.67 / 25 of 2321 |
| F32 APG 1.13.4 | 3252 (2267) | 4.6e-9 / 9.3e-10 | 1.2e-9 | 1.6e-8 | 3.5e-9 | 1.32 / 0.63 / 5 of 2267 |
| F64 PGD 1.10.13 | 2816 (1362) | 1.1e-3 / 7.8e-6 | 8.7e-7 | 2.7e-3 | 1.1e-3 | — (no wider type) |
| F64 PGD 1.13.4 | 3012 (1571) | 8.8e-5 / 5.8e-6 | 9.7e-7 | 3.8e-3 | 8.8e-5 | — |

All entries are relative differences of the relative gap from the reference. "Near target" means within a factor 3 of `1e-5` (Float32) or `1e-8` (Float64).

- The source of the remaining W1 difference was not decomposed.
- For Float64 data the evaluation is in working precision; the largest differences occur at gaps near `1e-12`.
- The comparator recomputes `X*x` and `Xᵀr` in Float32 BLAS. Phase 0 reported a 17% underestimation rate from the solver's cached image ([Phase 0 report](https://github.com/mlakolar/ProximalSolvers.jl/issues/320#issuecomment-6967100343), §6). That is a historical figure from a different quantity and was not rechecked here.

**Degenerate and finite cases** (`s2degen.jl`, both versions): 13 cases per version, 24 case-version results with a finite reference plus 2 nonfinite-status checks.

| Case | W1 against the reference |
|---|---|
| `y = 0`, `x = 0` | `P = 0`, gap 0 (`:zero_objective`) |
| `x = 0` with `λ ≥ λmax` | 0, exact |
| Exact fit `r = 0`, `x ≠ 0` | relative gap 1, exact |
| `s = 1e-30` (`P ≈ 2e-29`); data scaled by `1e-18` (`P ≈ 3.4–4.8e-37`); `y ≈ 1e18` (`P ≈ 3.4–4.8e35`) | ≤ 1.4e-16 |
| Zero column; tiny `λ`; random point | ≤ 1.1e-16 |
| Nonfinite coefficient | `:nonfinite` (both versions) |
| Near-interpolating, rounded solution | W1 ≤ 5.6e-11; the rounded-product comparator is off by up to 1.37e-2 |
| Near-optimal point (reference gap 6.37e-8 to 7.80e-8), unscaled and with `s` and `λ` times `1e-30` | 2.9e-11 to 1.5e-10 |

23 of the 24 finite results meet the preregistered criterion: relative difference ≤ 1e-10, or exact 0. Both nonfinite checks pass, 25 of 26 overall.

The miss is the near-optimal point on 1.10.13, at `1.5e-10`. Its absolute difference is `3.1e-18`, at `P ≈ 0.318`.

The constructed cancellation and underflow cases of §2 were found in review and are not in `s2degen.jl`.

### 4. Hypothetical stopping along recorded trajectories
**Simulation.**
- Each trajectory is stepped with the solver's own `update_state!` and no stop. At the H stop iteration, the trajectory iterate equals the library's returned iterate in all 720 records.
- A trajectory ends when every rule has stopped (and the margin below holds), or at 10,000 iterations, or after 200 unchanged iterates. Of the 720 trajectories, 645 ended because the rules finished and 75 at the cap; none ended on unchanged iterates.
- The simulation omits the solver's stagnation exit, callbacks, and limits other than the cap.

**Rules.** None changes the iterates.
- **R1:** stop at the first iterate with W1 relative gap ≤ `gaptol`.
- **R10:** the same, evaluated every 10 iterations.
- **RK:** evaluated only at iterates where the computed KKT check of the H options passes. The check is run at every step, independently of whether H made a proposal.
- **R1i, RKi:** R1 and RK with an objective-increase exit. As simulated, a gap pass at an iteration with a computed increase counts as a success. The "increase first" row gives the counts with the increase taking priority.

"False" means success with a reference gap above `gaptol` at the stop.

**Float32 PGD at `gaptol = 1e-5`, Julia 1.10.13 / 1.13.4:**

| | Harness (50): success | False | Adverse (70): success | False | Adverse non-success |
|---|---|---|---|---|---|
| H, current (`converged`) | 36 / 25 | **25 / 15** | 6 / 9 | **5 / 8** | increase 62/57, maxiter 2/4 |
| H within target (any exit) | 11 / 11 | — | 1 / 1 | — | |
| R1 | 50 / 50 | 0 / 0 | 56 / 59 | 0 / 0 | not reached within budget 14 / 11 |
| R10 | 50 / 50 | 0 / 0 | 56 / 59 | 0 / 0 | 14 / 11 |
| RK | 50 / 50 | 0 / 0 | 56 / 59 | 0 / 0 | 14 / 11 |
| R1i and RKi (equal counts), gap first | 29 / 18 | 0 / 0 | 1 / 1 | 0 / 0 | increase 67/65, maxiter 2/4 |
| R1i and RKi (equal counts), increase first | 24 / 12 | 0 / 0 | 1 / 0 | 0 / 0 | |
| R1, `gaptol = 1e-4` | 50 / 50 | 0 / 0 | 60 / 60 | 0 / 0 | 10 / 10 |
| R1, `gaptol = 1e-6` | 50 / 50 | 0 / 0 | 52 / 57 | 0 / 0 | 18 / 13 |

- **Where the misses are:** every non-success of R1, R10 and RK is on `adv-ill-low-cold` or `adv-ill-low-warm` at the cap, where Float64 PGD and Float32 APG also miss some draws.
- **When rules stop,** measured against `k*`, the first iterate meeting the target by the harness Float64 certificate:
  - R1 stops at `k*` in every success.
  - RK stops at a median of 0 iterations after `k*` (maximum 23).
  - R10 stops at a median of 4 to 6 iterations after `k*` (maximum 17).
- **Solve length,** successes relative to H's iterations:
  - R1 and RK: a median of 1.08 to 1.10 on the harness designs and 1.38 to 1.47 on the adverse set (maximum 4.9).
  - R10: maximum 5.7.
- **Number of evaluations:** RK a median of 2 (harness) and 15 to 16 (adverse); R1 about 16 and 166 to 214.

**Controls** (`gaptol = 1e-5` for Float32 APG, `1e-8` for Float64 PGD; 1.10.13 / 1.13.4):

| | Harness | Adverse |
|---|---|---|
| Float32 APG, H | 35/33 converged, 26/27 false success | 19/19 converged, all false |
| Float32 APG, R1 and RK | 50/50 success, 0 false | 65/67, 0 false |
| Float32 APG, R1i | 28/28 (gap first) | 4/6 |
| Float64 PGD, H | 0 false success; 46/45 within target | 13/9 within target |
| Float64 PGD, R1 | 50/50, 0 false | 54/58, 0 false |
| Float64 PGD, RK | 50/50 | 54/58 |

- For APG, R1 and RK have equal success counts but stop at different iterations in 10 solves.
- In Float64, RK stops a median of 4 to 23.5 iterations after `k*`. The reason is that the harness `gradtol = 1e-11` makes the computed KKT check stricter there than a `1e-8` gap.

These results support an empirical tradeoff on the tested designs. They do not demonstrate how a package mode that keeps the solver's actual exits would behave; that would need a replay with those exits.

### 5. Cost (`s2time.jl`): timed kernels and projections
- **Setup:** Float32 PGD, 7 designs × 5 draws. The arms ran in seeded shuffled order over 11 rounds, and the per-problem minimum was taken. Hardware was Xeon Silver 4116. Exclusive-node requests did not start within 90 minutes, so the timing ran on shared nodes with 8 reserved CPUs and one worker.
- **A/A controls:** the preregistered criterion was a median within 0.98–1.02.
  - 1.10.13: `Haa/H` 1.000 [0.996, 1.002]; `W1aa/W1` 1.000 [0.995, 1.004].
  - 1.13.4: `Haa/H` 0.997 [0.971, 1.047]; `W1aa/W1` 1.005 [0.908, 1.106].

  The medians pass on both versions. The ranges show the spread between repeated arms; they are not error bounds for the cross-kernel ratios.

**Timed kernels** (median [range] over problems):

| Ratio | 1.10.13 | 1.13.4 |
|---|---|---|
| One W1 evaluation / one Float32 product pair `X*x`, `Xᵀr` | 1.02 [0.99, 1.42] | 1.55 [1.08, 2.03] |
| One W2 evaluation (Float64 copy, BLAS) / product pair | 2.06 [1.95, 2.34] | 3.39 [2.15, 4.34] |
| Building the Float64 copy / full H solve | 0.10 [0.00, 0.29], plus `8np` bytes | 0.15 [0.00, 0.49] |
| One W1 evaluation / full H solve | 0.028 [0.000, 0.048] | 0.027 [0.000, 0.089] |

- Design medians of W1 run from 1.1 µs (`lasso`) to 33 µs (`adv-wide-low-cold`) across the two versions.
- Allocation per W1 call is 0 bytes on 1.13.4 and 16 bytes on 1.10.13. The 1.10.13 allocation was not investigated; the timing closure is a plausible source.
- W2 is slower than W1 and needs an `n × p` Float64 copy, so it is rejected.

**Projections.** These combine each rule's evaluation count on a trajectory with W1's time at the H endpoint and a constant per-iteration time taken from the H solve (normalized by the timing table's own H iteration count). They exclude the cost of running the KKT gate at RK's cadence. They cover the 25 harness and 10 adverse timed problems per version, and 45 of the 70 joins pair a trajectory and a timing run on different CPUs.

| Projection (median) | 1.10.13 | 1.13.4 |
|---|---|---|
| R10: evaluations × W1 / full H solve time (preregistered) | 0.069 | 0.096 |
| R1: evaluations × W1 / full H solve time | 0.53 | 0.77 |
| R1 / own iteration time (harness; adverse) | 0.49; 0.62 | 0.64; 0.78 |
| R10 / own iteration time | 0.049; 0.062 | 0.064; 0.078 |
| RK / own iteration time (excluding the KKT gate) | 0.043; 0.094 | 0.051; 0.122 |

No production code changed, so there is no hot-path regression to gate.

### 6. The tested callback, with today's API
`s2callback.jl` ran 70 Float32 PGD solves: the harness designs plus `adv-cor-low-cold` and `adv-wide-low-cold`, 10 draws each, on Julia 1.13.4. It used exactly these options:

```julia
work = GapWork(n, p)                      # the gapeval.jl prototype
seen = Ref(NaN)
cb = os -> (seen[] = gap_widened!(work, X, y, s, λ, os.metadata["x"]).rel; seen[] <= 1e-5)
opts = ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-300, gradtol = 1e-11,
                       allow_f_increases = true, extended_trace = true, callback = cb)
```

- **Outcome:** every solve ended on a callback hit (`seen[] ≤ 1e-5`), and the reference gap at the returned point was at or below `1e-5` in all 70.
- **Flags:** `converged`, `stagnated` and `iteration_converged` were false in all 70. `f_increased` was true in 17, which STOP-18 allows in its last class when increases are allowed.
- **Agreement with R1:** each stop was at R1's iteration. The 10 `lasso` draws were compared on the same machine; the other 60 matched the cluster trajectories.
- **Allocation:** the whole solve allocated about 1.15 to 6.7 KB per iteration (total bytes divided by iterations). This includes setup, the trace metadata and the iterate and gradient copies; a paired incremental measurement was not made.
- **Caveats:**
  - The equivalence holds only for these options and designs.
  - On `adv-cor-low-cold` draw 1, dropping `xtol` and `gradtol` returned `converged = true` at iteration 133 without a callback hit, at reference gap `1.35e-4`.
  - Ordinary proposals, the Float32 stagnation exit, or a limit can end a solve before the callback passes.
  - A documented recipe should therefore record whether the callback fired and check the gap at the returned point. It should present the result as an exploratory Float64 check, not a certificate (§2).

### 7. Design decisions a package `gaptol` would require (only if C were implemented)
1. **Storage and validation.**
   - Store `gaptol::Float64` and `gapevery::Int` in `ProximalOptions`, validated as `ftol` is today (STOP-10, IN-02):
     - the sign is checked as given, and a negative value is refused;
     - the value must be finite after conversion to Float64;
     - a positive value that rounds to zero is refused;
     - `-0.0` is stored as `0.0`, which means off.
   - `gaptol` is compared in Float64 and never converted to `T`.
   - `gapevery` must be an integer with `1 ≤ gapevery ≤ typemax(Int)`.
   - A positive `gaptol` is refused in `solve!`, before any mutation, unless:
     - the solver is `ProximalGradientDescent` or `AccProxGradDescent` on a dense `Vector{T}`, with `T` Float32 or Float64;
     - the loss is a raw `LeastSquaresLoss` (scale 1) or one `Scaled` wrapper of it with a finite positive scale (no nested or other `Scaled` forms);
     - the penalty is unweighted `NormL1` with working level `T(λ₀) > 0`; `λ₀ = 0` is refused;
     - `allow_f_increases = true` (question 4).
   - The gap uses the working `T(λ₀)` and the loss scale as supplied.
2. **Success requires the gap.** With `gaptol > 0`, `converged = true` only at a scheduled evaluation with a finite gap `≤ gaptol`. The computed KKT check is not required.
   - The `x`, objective and gradient proposals and the KKT check are not used for stopping. Their flags `x_converged`, `f_converged` and `grad_converged` are false. Their residual fields are still computed and reported.
   - This replaces the OR rule of STOP-09 in gap mode, and RES-01/RES-02 would need corresponding clauses.
3. **KKT passes but the gap fails:** the solve continues; nothing is reported as convergence.
4. **Other exits and their order.** Increases cannot end the solve, because `allow_f_increases = true` is required. After a completed iteration the order is:
   1. the scheduled gap evaluation (success ends the solve);
   2. the callback;
   3. the time limit;
   4. the call limit;
   5. Float32 stagnation;
   6. `maxiter`.

   This order only chooses which exit is reported; it does not skip any diagnostic. As in PGD-04, an iteration whose gap passes still gets its trace entry and any due callback. The limit and stagnation predicates are still evaluated and reported as independent flags. A gap success is the reported exit even when a callback, a limit or stagnation also holds at that iteration.
5. **Frequency and cost.**
   - Evaluate every `gapevery` iterations (default 10, the reserved value).
   - At any non-success exit, evaluate once more at the returned point, even after the time limit. This exit-only evaluation is diagnostic: it fills `gap` but never grants success.
   - A nonfinite evaluation does not pass and stores `gap = NaN`.
   - Evaluations are not oracle calls: they are not counted in `f_calls`, `grad_calls` or `prox_calls` and not subject to call limits. Their cost is documented (about 1 to 1.5 product pairs each; §5).
6. **Meaning of `gap`.** The relative gap `(P - D)/P` at `θ = κ s r`, evaluated in Float64 from the stored inputs. An evaluation is usable only when the computed `P` is finite and positive and the computed gap is finite and ≥ 0. Its value is then `gap/P`, and it passes when that is `≤ gaptol`.
   - A computed `P = 0` can come from underflow (§2), so it is usable only when it is exact: `x == 0` and `y == 0` entrywise, since `λ > 0` makes `P = 0` exactly then. That case has gap 0 and passes.
   - Any other evaluation (zero `P` otherwise, negative or nonfinite gap) is unusable. It does not pass, and it stores `gap = NaN`.
   - It is an exploratory floating-point value with no error bound.
   - It can be wrong under complete cancellation or underflow (§2).
   - It refers to the stored rounded problem, not to the user's unrounded data.
   - For Float64 data it is a working-precision value.
7. **Unsupported cases:** refuse everything outside question 1, including weighted, elastic-net, group, nonnegative, `NormLinf` and constraint penalties, logistic loss, matrix iterates, and other solvers. CD already refuses `gaptol`. There is no fallback, and #487 stays separate.

### 7A. Candidate A: a minimal stop-reason API (design only; nothing changed)
- **Do the existing fields suffice?** Mostly.
  - The cause of a callback-or-time-limit return cannot be read from the result (STOP-18). When a finite time limit and a callback that returns `true` coincide, whether the internal time check also passed is not observable at all. The proposed precedence would report `:time_limit` in one case and `:callback` in the other.
  - An objective-increase exit can be recognized only together with `allow_f_increases`, which the result does not store.
  - The caller knows its own options and can record whether its callback fired.
  - The relative size of an objective change is already `f_residual`, so no ulp-count or "precision-limited" class is proposed.
- **If adopted: one stored field** `stop_reason::Symbol` in `OptimizationResults`, recorded from the predicates on the actual exit path. The existing flags are unchanged and keep their meanings (STOP-09). The accessor `stop_reason(r)` would also cover `ProxNewton`, which already has the field. `:gap` is not included unless a gap mode exists.
- **Regression PGD/APG,** following STOP-18's published order and splitting its last class:
  1. `:converged` (a proposal passed the stationarity check)
  2. `:stagnated`
  3. `:f_increased` (only when the increase ended the solve)
  4. `:maxiter`
  5. `:call_limit`
  6. `:time_limit`
  7. `:callback`

  When several hold at the final iteration, the first applies.
- **Graphical-lasso PGD (PGD-08; strict limits, no callback),** by exit path:
  - **Precheck** before the first step: `:call_limit` if the call limit holds, otherwise `:time_limit`; zero iterations.
  - **Interruption inside a step:** `:call_limit` if the call limit holds, otherwise `:time_limit`.
  - **After a completed step:** `:converged` if its KKT check passed and no strict limit cleared it; otherwise `:call_limit`, `:time_limit`, `:maxiter`, `:stagnated`, in that order.
- **Cost:** one field and one assignment at return, plus `show`, an update to STOP-18 and PGD-08, and tests of each value, including the simultaneous cases.

### 8. Assessment and recommendation
- **C in the package.**
  - *Benefit:* on the tested designs, stopping at a widened gap for the unweighted least-squares lasso gave 50/50 Float32 harness solves within `1e-5`, against 11/50 now, with no false success.
  - *Requirements:*
    - It would override the increase exit and the ordinary proposals (§7, questions 2 and 4).
    - It would add two stored options, a refusal matrix, and new STOP and RES clauses.
    - It would make a success depend on an evaluator with no error bound, which can report 0 under cancellation (§2).
  - *Overlap:* the same rule runs today as the callback of §6.
  - *Verdict:* the evidence supports deferring it.
- **A (stored `stop_reason`).**
  - *What it adds:* it separates a callback stop from a time-limit stop, including the one case a caller cannot reconstruct: whether the time check also passed when the callback stopped. It also records an increase exit without the options.
  - *Why that is weak here:* the use case this study examined, stopping on a verified gap, needs only the callback's own record of its hit and gap, which it can keep today. No tested case needed the time-limit decision, and the caller already knows its options.
  - *Cost:* a public result change across two engines and `ProxNewton`, for information that is available elsewhere.
  - *Verdict:* no concrete use case shown here justifies it.
- **Closing with the limitation accepted.**
  - STOP-18/19/20 (#510) already document what `converged = true` means in Float32, why it cannot imply a `1e-5` gap, and how to classify a return.
  - Users who need a gap can evaluate one at the returned point. They can also stop on one with the callback of §6, subject to its caveats.

**Review.** One independent Codex review, two rounds.
- Round 1 blocked on nine points, including the callback options, accuracy attribution, tie handling, cost projections, the contract details and the A-versus-close comparison. All were addressed, and the recommendation changed from "implement A" to "close".
- Round 2 found five points still open: the timing normalization, `gaptol` validation, the zero-objective rule, the A rationale, and the archive reference. It also raised trace sequencing and wording nits. All of these were fixed afterwards without a third round, following the project's two-round policy. The round-2 reviewer agreed that the evidence supports closing.

**Recommendation: retain the existing behaviour and close #320 with the limitation accepted.** Optionally, the maintainer may add the §6 callback as a documented example, with its caveats, in a separate documentation change. The A and C designs above stay on record if a concrete need appears later.

---
_Generated by [Claude Code](https://claude.ai/code)_
