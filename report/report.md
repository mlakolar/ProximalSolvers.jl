## #400 validation report: PGD/APG stopping with weighted `NormL1` and `NormLinf`

Plan: [comment above](https://github.com/mlakolar/ProximalSolvers.jl/issues/400#issuecomment-7050862159). Research only; no package code changed.

### Verdict

| Item | Result |
|---|---|
| Weighted `NormL1`, PGD/APG (STOP-03/04) | **Pass.** 0 of the 31,340 converged solves (four weight sets, both types, both Julia versions) has an independent `‖G‖∞/S` at or above the bound; the largest ratio is 0.999997. Unit weights give the unweighted outcomes up to rounding-level path differences. No new defect. |
| `NormLinf`, PGD/APG, existing rule (STOP-07) | **Pass.** At 6,085 of 6,087 converged points, the independent ∞-norm KKT residual over S is below the bound. The exception is one Float32 APG case at 1.0018× the bound (relative objective excess at most 2.2e-5), the same on both versions. The independent Euclidean score (PB's definition) is at most 3.6× the bound. No new defect. |
| Reproducible exception | **Zero weight on a coordinate with a large ∇f(0) entry.** An example is an unpenalized intercept with an offset response. The global scale S lets `converged = true` stand at a point whose objective is far from the minimum: the `offset` fixture at λ0 = 0.5·λ0max, PGD, default options, is 22% above the minimum with ‖G‖∞/S = 7.2e-7. This is inside the contract (STOP-12: "a coordinate on a much smaller gradient scale than λmax can remain inaccurate"). It is the mechanism of **#464**, reached here at ordinary scales; the evidence is added there, and no new issue is filed. |
| PB's full-point `kkt_violation(NormLinf)` as a criterion | Over the same scale S, at τ = 1e-5 it never fires earlier than the existing check (0 of 1,524 trajectory pairs); it fires at the same iteration or later, median ratio 1.04–1.06. It fired earlier in 5 Float32 pairs at τ = 1e-8, below the solver's 64 eps floor. It reaches 1e-4 per coordinate at τ = 1e-5 on every well-conditioned trajectory (both types). Its cost is about that of the prox. Details below. |

### Setup

- **Revisions.** PS `083c2f705b37a285dc433a89676ce4e6a4356dea` (master). PB pin `e03c6d9659365d54f4e0fba1a9cd54490631eea6` with git-tree-sha1 `8de7a696d89a10022bb40f0941745939e4087fd4`, read from the loaded manifest in every output; the pin contains PB #981.
- **Runs.** Julia 1.13.4 on AMD Zen 3 and 1.10.13 on Intel Skylake-SP, cluster (Slurm), single-threaded BLAS. Each version is one allocation with six processes, one per (script, type).
- **Scope.** All 47,616 weighted, 9,984 `NormLinf` sweep and 1,664 trajectory solves completed without an error.
- **Matrix, references and classification.** As in the plan. References are certified (BigFloat relative gap ≤ 1e-12 weighted, ≤ 1e-20 ℓ∞) except where the minimum is not unique or F\* = 0: `rankdef` and `yzero` (weighted), `rankdef` and `zerocol` (ℓ∞).
- **Targets.** The objective target is the #352 one: 1e-8 for Float64, 1e-5 for Float32. It is stricter than what the default `gradtol = 1e-5` promises, so "objective above target" at default options is expected on hard fixtures. Use the columns to compare weight sets and options, not as defect counts. The coefficient error is reported only for a full-column-rank design with a certified reference.
- **Independent check.** A fresh reviewer checked the independent measures (`lib400.jl`) before this report; its findings are summarized at the end.

### 1. Weighted `NormL1`

Each row aggregates 2 solvers × 4 option sets × 3 starts × 6 levels × 11 fixtures × 2 losses (y = 0 has two levels).

#### Weighted `NormL1`, Float64: all options, starts, levels, fixtures, both solvers (1.13.4; 1.10.13 in parentheses where it differs)

| Weights | Solves | Converged | Converged with independent ‖G‖∞/S ≥ bound | Max ‖G‖∞/S / bound | Converged, objective above target | Converged, coef. error > 1e-4 (orth, gauss, tall_exact, corr95) | Not converged, within target |
|---|---|---|---|---|---|---|---|
| unweighted (control) | 2976 | 2231 (2234) | 0 | 1.0000 | 215 (218) | 1 | 605 (601) |
| unit | 2976 | 2235 (2238) | 0 | 1.0000 | 215 (218) | 1 | 601 (597) |
| spread 2^[−2,2] | 2976 | 2249 (2248) | 0 | 1.0000 | 216 | 1 | 582 |
| spread + two zeros | 2976 | 2598 (2586) | 0 | 1.0000 | 405 | 34 (36) | 140 (151) |

#### Weighted `NormL1`, Float32: all options, starts, levels, fixtures, both solvers (1.13.4; 1.10.13 in parentheses where it differs)

| Weights | Solves | Converged | Converged with independent ‖G‖∞/S ≥ bound | Max ‖G‖∞/S / bound | Converged, objective above target | Converged, coef. error > 1e-4 (orth, gauss, tall_exact, corr95) | Not converged, within target |
|---|---|---|---|---|---|---|---|
| unweighted (control) | 2976 | 1568 (1532) | 0 | 0.9992 (0.9957) | 101 (99) | 0 | 1150 (1190) |
| unit | 2976 | 1563 (1537) | 0 | 0.9992 | 101 (99) | 0 | 1155 (1185) |
| spread 2^[−2,2] | 2976 | 1598 (1595) | 0 | 0.9990 (0.9907) | 101 (99) | 0 | 1103 (1101) |
| spread + two zeros | 2976 | 1684 (1644) | 0 | 0.9989 (0.9996) | 321 (316) | 30 | 845 (886) |

- **Contract.** It holds in every cell. The ratio is close to 1 because a proposal can pass just below the threshold.
- **Unit weights against unweighted.** Over 2,976 pairs per type and version, 23 to 74 pairs differ in iterations or in `converged` (`converged` differs in 4 F64 and 15 to 25 F32 pairs). In every differing pair, both sides fall on the same side of the objective target. The differences are rounding-level path differences, an objective-increase exit against a converged exit a few iterations apart. STOP-03 promises equal coefficients and scale, not equal iterates.
- **Spread weights.** Their counts are those of the control within a few solves.
- **Coefficient column.** It counts only orth, gauss, tall_exact and corr95, where the 1e-12 reference certificate bounds the reference's own coefficient error by 7.3e-6. On `colscale` and `offset` it does not certify 1e-4. The zero-weight count there (30 to 36) is the same free-coordinate mechanism, on the correlated designs.
- **Zero weights.**
  - *Fewer solves end unconverged inside the target* (140 to 151 against about 600 for the control in F64). With unpenalized coordinates, zero is no longer a solution at λ0 ≥ λ0max, so the `ftol = 0` exact-stall cases of #352 F4 disappear.
  - *More solves are converged above the objective target* (F64: 209 against 35 with λ0 > 0, excluding y = 0). Of these, 118 are in `offset` and 50 in `colscale`. In `offset` the zero weight falls on the intercept column under a response offset of 1e6. In `colscale` it falls on the column of norm 1e-3. In both, the free coordinate's gradient is on a scale far below S = max(maxⱼ cⱼ, ‖∇f(0)‖∞), which the large ∇f(0) entry sets. Example (F64, raw loss, PGD, cold start, λ0 = 0.5·λ0max):
    - default options: `converged = true` after 12 iterations, ‖G‖∞/S = 7.2e-7, relative objective excess 0.22;
    - `gradtol = 1e-8`: 17 iterations, excess 1.7e-7;
    - unweighted, same data: exact after 2 iterations.
- **y = 0 with zero weights.** It has F\* = 0, so the relative objective target is undefined. Those rows count as above target whenever F > 0 and are excluded from the figures above.

### 2. `NormLinf`, existing rule

Each row aggregates PGD + APG × 3 starts × 5 levels λ/‖∇f(0)‖₁ ∈ {0, 1e-3, 0.1, 0.5, 1.01} × 11 fixtures × 2 losses.

#### `NormLinf` sweep, Float64: PGD + APG, all levels, fixtures and starts (1.13.4; 1.10.13 in parentheses where it differs)

| Options | Solves | Converged | Converged with independent ∞-norm KKT/S ≥ bound | Max Euclidean KKT/S / bound | Converged, objective above target | Converged, coef. error > 1e-4 (unique ref.) | Not converged, within target |
|---|---|---|---|---|---|---|---|
| default | 624 | 527 | 0 | 3.03 | 109 (110) | 36 | 20 |
| ftol0 | 624 | 465 | 0 | 2.34 | 100 (101) | 59 (58) | 137 |
| gradtol1e-8 | 624 | 541 (538) | 0 | 3.63 (3.13) | 52 | 32 | 43 (46) |
| strict | 624 | 382 | 0 | 3.29 (3.31) | 26 (25) | 0 | 184 (183) |

#### `NormLinf` sweep, Float32: PGD + APG, all levels, fixtures and starts (1.13.4; 1.10.13 in parentheses where it differs)

| Options | Solves | Converged | Converged with independent ∞-norm KKT/S ≥ bound | Max Euclidean KKT/S / bound | Converged, objective above target | Converged, coef. error > 1e-4 (unique ref.) | Not converged, within target |
|---|---|---|---|---|---|---|---|
| default | 624 | 431 (416) | 1 | 2.57 | 45 (42) | 48 (41) | 113 (124) |
| ftol0 | 624 | 234 (223) | 0 | 2.19 | 42 | 39 (36) | 322 (334) |
| gradtol1e-8 | 624 | 393 (385) | 0 | 2.78 | 20 (21) | 38 (34) | 138 (148) |
| strict | 624 | 89 | 0 | 0.40 (0.37) | 5 | 2 (5) | 458 |

- **The existing check bounds the KKT residual in the ∞-norm.** The ∞-norm column is 0 in every cell except the one F32 case above (APG, `wide`, λ/‖∇f(0)‖₁ = 1e-3, default options, perturbed start). The STOP-07 contract promises only a working-precision indication, so this is not a violation. That figure is the ∞-norm of PB's Euclidean minimizer, an upper bound on the least ∞-norm residual.
- **The objective and coefficient misses follow the ℓ1 control.** They sit in the same fixtures as for `NormL1`: exact fits (`tall_exact`, `wide`, `wide_exact`), non-unique minima (`rankdef`, `zerocol`) and the scale-limited `colscale`/`offset`.
  - Apart from the `colscale` case below, the largest coefficient errors at converged points are in `offset`, with coefficients near 1e6 (an error of 18 to 20, relative about 2e-5).
  - One `colscale` λ = 0 solve stops with the coefficient of the 1e-3-norm column at about 0 against 874 in the reference: the STOP-12 limitation.
- **Strict options in F32** rarely converge (PGD 1 of 312, APG 88 of 312), with 126 PGD stagnation exits. This is #352 F4 and STOP-11, unchanged, and tracked by #320.

### 3. `NormLinf` stopping criteria compared (the maintainer's comment)

Trajectories run with no stopping proposal (`ftol = 0, gradtol = 0, xtol = 1e-300`, increases allowed, 20,000 iterations). At every iterate each criterion is evaluated in `T`:

| Criterion | Definition |
|---|---|
| `gen` | the existing STOP-07 mapping residual `‖x − prox_{tg}(x − t∇f)‖∞/t` over S = max(‖∇f(0)‖∞, ‖∇f(x)‖∞) |
| `kkt` | PB's `kkt_violation(NormLinf(λ), ∇f(x), x)` over the same S |
| `kktl` | the same score over max(λ, ‖∇f(0)‖₁) |
| `gap` | the relative duality gap with θ = κr |
| `dx`, `df` | the `xtol` and `ftol` quantities |

The "oracle" is the first iterate with coefficient error ≤ 1e-4.

#### `NormLinf` criteria along trajectories, Float64 (1.13.4; 1.10.13 in parentheses where it differs)

Each cell: at the first iterate where the criterion is below τ, coefficient error ≤ 1e-4 / fired / trajectories with a unique certified reference. Well-conditioned: orth, gauss, tall_exact, corr95 (160 trajectories); ill-conditioned: colscale, offset (80). Last column: fired with the proved objective lower bound within target / fired, over all 416 trajectories (gap: 328 with λ > 0).

| Criterion | τ | Well-conditioned | Ill-conditioned | Objective within target |
|---|---|---|---|---|
| `gen` | 1e-05 | 151/160/160 | 16/72/80 | 255/390 (254/390) |
| `gen` | 1e-08 | 160/160/160 | 28/60/80 | 328/370 |
| `kkt` | 1e-05 | 160/160/160 | 16/72/80 | 283/386 |
| `kkt` | 1e-08 | 160/160/160 | 28/60/80 | 328/368 |
| `kktl` | 1e-05 | 130/160/160 (131/160/160) | 16/72/80 | 213/396 |
| `kktl` | 1e-08 | 160/160/160 | 28/60/80 | 336/376 |
| `gap` | 1e-05 | 122/128/128 | 16/60/64 | 268/312 |
| `gap` | 1e-08 | 128/128/128 | 36/52/64 | 296/296 |
| `dx` | 1e-05 | 136/160/160 | 16/80/80 | 270/416 (268/416) |
| `dx` | 1e-08 | 160/160/160 | 18/74/80 | 330/400 |
| `df` | 1e-05 | 60/160/160 | 16/80/80 | 106/416 (107/416) |
| `df` | 1e-08 | 120/160/160 | 24/78/80 | 253/413 (255/413) |

#### `NormLinf` criteria along trajectories, Float32 (1.13.4; 1.10.13 in parentheses where it differs)

Each cell: at the first iterate where the criterion is below τ, coefficient error ≤ 1e-4 / fired / trajectories with a unique certified reference. Well-conditioned: orth, gauss, tall_exact, corr95 (160 trajectories); ill-conditioned: colscale, offset (80). Last column: fired with the proved objective lower bound within target / fired, over all 416 trajectories (gap: 328 with λ > 0).

| Criterion | τ | Well-conditioned | Ill-conditioned | Objective within target |
|---|---|---|---|---|
| `gen` | 1e-05 | 144/160/160 (146/160/160) | 16/62/80 | 328/380 |
| `gen` | 1e-08 | 137/137/160 | 16/48/80 | 287/325 (288/326) |
| `kkt` | 1e-05 | 160/160/160 | 16/62/80 | 332/376 |
| `kkt` | 1e-08 | 43/43/160 (46/46/160) | 16/36/80 (16/38/80) | 122/150 (132/160) |
| `kktl` | 1e-05 | 131/160/160 (128/160/160) | 16/62/80 | 334/386 |
| `kktl` | 1e-08 | 95/95/160 (99/99/160) | 16/48/80 | 253/289 (258/294) |
| `gap` | 1e-05 | 117/124/128 (118/124/128) | 16/58/64 | 301/303 (302/304) |
| `gap` | 1e-08 | 62/62/128 (63/63/128) | 16/44/64 | 180/180 (188/188) |
| `dx` | 1e-05 | 134/160/160 | 16/80/80 | 318/416 (320/416) |
| `dx` | 1e-08 | 160/160/160 | 16/69/80 (16/68/80) | 342/392 (341/391) |
| `df` | 1e-05 | 60/160/160 | 16/80/80 | 261/416 |
| `df` | 1e-08 | 99/160/160 (100/160/160) | 16/80/80 | 314/416 (316/416) |

**The maintainer's questions:**

- **Tolerance and scaling.** `gen`, `kkt` and `kktl` are relative to the scales above. `gap` is relative to F. The solver's own check uses τ = max(`gradtol`, 64 eps(T)).
- **`kkt` against the existing check.**
  - At the same τ and S, over all trajectories with both criteria firing, `kkt` fired earlier than `gen` in 0 of the 1,524 pairs at τ = 1e-5 (both types and versions) and in 0 of the F64 pairs at τ = 1e-8. Its median fire ratio to `gen` is 1.02–1.06.
  - The exception is Float32 at τ = 1e-8, below the 64 eps(Float32) ≈ 7.6e-6 floor that the solver applies: 5 of 310 pairs fired earlier.
  - So at the tolerances the solver uses, it is a slightly stricter certificate than `gen` and makes no premature stop that `gen` would avoid.
  - Part of the delay is the norm: the PB score is a Euclidean distance compared with an ∞-norm scale, so it can exceed the ∞-norm residual by up to √p.
  - It certifies the returned point x itself, whereas `gen` measures the step to the prox point.
  - In Float32 below about τ = 1e-7 it rarely fires (43 of 160 well-conditioned trajectories at 1e-8). `gen` does fire there, because the prox returns x exactly at a floating-point fixed point. The solver's 64 eps floor keeps that regime out of the actual check.
- **`kktl` (λ-based scale)** fires earlier than `gen` in 212 to 225 of the 378 to 388 pairs at τ = 1e-5. At τ = 1e-5 it misses 1e-4 per coordinate in 29 to 32 of 160 well-conditioned trajectories, mostly in `corr95` (24 of 30 in F64).
- **`gap`.**
  - In F64 at τ = 1e-8 it is the only criterion with every fire inside the objective target (296/296).
  - Computed in Float32, it fires on rounding below about τ = 1e-7: at τ = 1e-8, 90 to 95 of the 180 to 188 fires have an independent gap above 10τ. At τ ≥ 1e-6 at most one fire does.
  - It is not available at λ = 0 with this dual point.
  - At τ = 1e-5 it misses 1e-4 per coordinate in 6 of 128 well-conditioned trajectories.
  - Its cost includes the residual (O(n) from the cached image).
- **`dx` and `df` alone stop prematurely.** At τ = 1e-5, `df` is within 1e-4 per coordinate in only 60 of 160 well-conditioned trajectories. This matches STOP-01: they propose, and the stationarity check decides.
- **About 1e-4 per coordinate.**
  - At τ = 1e-5, `gen` and `kkt` reach it reliably on the well-conditioned fixtures: `kkt` 160/160 in both types; `gen` 151/160 in F64 and 144–146/160 in F32, the misses in `corr95`.
  - On `colscale` (column norms 1e-3 to 1e3) and `offset` (coefficients near 1e6, where 1e-4 absolute is 1e-10 relative), no criterion reaches it reliably at τ = 1e-5. On those fixtures it is reached in 16 of 72 fires at 1e-5 and 28 of 60 at 1e-8, F64.
  - Within 20,000 iterations the oracle itself is reached in 20 of 40 `colscale` trajectories in F64 and 8 of 40 in F32.
  - For `offset` at λ > 0, the references are certified only to about 1e-4 in coefficients (√(2·gap·F/(sσ_min²)) with F up to 2.5e13). Its 1e-4 judgments there are therefore indicative. λ = 0 and λ ≥ ‖∇f(0)‖₁ have exact references.
- **Time to comparable accuracy.** On the well-conditioned fixtures at τ = 1e-5, the per-fixture median fire/oracle iteration ratio is 1.0–1.2 for `gen` and `kkt` and 1.2–1.4 for `gap`. `kkt` takes a median 2–6% more iterations than `gen`.
- **Per-check cost** beyond the gradient (median µs, single thread, 1.13.4; a shared node, so indicative only):

  | Type, n × p | `gen` (prox and max) | `kkt` | gap (incl. X x) | ∇f |
  |---|---|---|---|---|
  | F64, 40 × 12 | 0.09 | 0.08 | 0.17 | 0.25 |
  | F64, 200 × 1000 | 3.76 | 2.19 | 27.82 | 53.27 |
  | F64, 2000 × 5000 | 10.74 | 13.07 | 2654.15 | 5198.33 |
  | F32, 2000 × 5000 | 6.55 | 10.97 | 1077.56 | 2293.99 |

  The gap's cost is dominated by X x, which the solvers hold as a cached image; with it, the gap adds O(n + p).
- **For the stopping-options design** (separate scope): `kkt` over S is a drop-in replacement for `gen` for `NormLinf`. It has the same normalization, stops only where `gen` would or later, and costs about the same. `gap` is the only criterion here that bounds the objective. It needs λ > 0 (or a projected dual point) and the residual. `dx` and `df` should stay proposals. None of the criteria remove the scale limitation of STOP-12 or #464.

### Cross-links

- **#464:** the zero-weight evidence above is added there in a separate comment. Same mechanism; ordinary scales, least squares, PGD and APG, both types.
- **#320:** the F32 strict and `ftol = 0` outcomes are those of #352 F4, unchanged.
- **#392** (CD only), **#155/#156** (square-root CD): not exercised here, no change.

### Reproduce

The evidence branch is `archive/issue-400-evidence` (scripts, raw tables, analyses, checksums). From a PS checkout at the revision above:

```
julia --project=. <evidence>/study/driver.jl <outdir> wl1:Float64 wl1:Float32 linf-sweep:Float64 linf-sweep:Float32 linf-traj:Float64 linf-traj:Float32
python3 <evidence>/study/an400.py <outdir>              # summaries
python3 <evidence>/study/report_tables.py <dir 1.13> <dir 1.10>   # the tables above
```

`study/lib400.jl` includes `study/lib.jl` from `archive/issue-352-evidence` unchanged (copied into the same layout).

### Not covered

- Weighted `NormL1` with `LogisticLoss` (PGD only) and extreme weights belong to #464.
- `SparseIterate` and CD are not part of this issue.
- Coefficient errors are reported only for full-column-rank designs.
- The `gap` criterion is evaluated only for λ > 0.
- The two Julia versions ran on different CPU kinds, so their small differences are not attributed to either.
- Timings come from a shared node.
- No Codex review or CI, as the handoff specified for a change without code.

### Independent check of the measures

A fresh reviewer checked `lib400.jl`, `wl1.jl` and `linf.jl` without the results, using exact rational arithmetic in Python. It verified:
- the two duals and weak duality (0 violations over 2,400 rational points);
- the simplex and ℓ1-ball projections;
- that K2 equals PB's formula exactly (500 rational cases), and that Kinf equals the least ∞-norm residual;
- the support and face polish (the unique passing face is the minimizer in every enumerated case);
- uniqueness under full column rank.

Its findings that bear on classification are handled above:
- no gap certificate at λ = 0 (excluded);
- the reference tolerance does not certify 1e-4 coefficients on `colscale`/`offset` (column restricted, caveat added);
- the Euclidean score against an ∞-norm bound (classification uses the ∞-norm residual);
- the working-precision gap firing on rounding in Float32 (counted above).

The remaining notes do not change a classification. One is that the face polish cannot resolve `zerocol` and `rankdef`, which are therefore uncertified and carry no coefficient error.
