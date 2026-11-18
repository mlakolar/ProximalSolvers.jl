## Verdict

**K meets A–H, with one small change to the brief's design (called K+ below).**

Plain K (all three exits call the cold step) failed A in 4 of 3.38M boundary inputs. K+ adds one conditional on the band exit and removes all four. Details are under A.

Nothing in the evidence calls for the fallback.

## What changed

Branch `fix/issue-353-r1`, worktree `<WORK>/ProximalSolvers.jl-issue353-r1`, base `bb20b6a`. Edits are in `src/cd/sqrtlasso.jl` and comments only in `test/sqrt_lasso.jl`. Executable lines go from 310 to 286 (−24). The fallback alone would be about 297.

- **`_scaled_norm`**: deleted.
- **`_sqrt_band_step`, `_sqrt_threshold64`, `_sqrt_offrange_step`**: replaced by one `@noinline _sqrt_cold_step(m, old, k)` for both element types. The cold step uses `m.rowmag64` for x̃ and `m.res64` for s.
  - Only `_certify!` touches `rowmag64` otherwise, and it refills the vector at the start of each call.
- **`_sqrt_minimizer`**:
  - All code lines are unchanged except the three exits. Exit 1 (`a` or ρ² not clean) and exit 2 (recomputed d² not clean) call `_sqrt_cold_step(m, old, k)`.
  - Exit 3 (the band) is now `... : isfinite(c) ? _sqrt_cold_step(m, old, k) : c`. This `isfinite(c)` guard is the one deviation from the brief; see A.
  - The `prox_block(m.gt, c, k, γ)` call is untouched.
- **`_prepare!`**:
  - `ny = _se_norm(Float64, m.ls.y)` and `floor64 = ny === nothing ? 16eps(T)*Float64(maximum(abs, m.ls.y)) : 16eps(T)*ldexp(ny.s, ny.e)`.
  - For a non-finite y this gives master's value (Inf or NaN). I checked `[1,Inf,2]`, `[1,NaN,2]`, `[1,-Inf,2]` and `[NaN,Inf]` in both types on both Julia versions; all are `isequal` to master.
  - `solve!` never passes a non-finite y here.
- **Comments**: the struct comment, the `_sqrt_minimizer` comment and the cold-step comment are rewritten. In `test/sqrt_lasso.jl`, the helper names are updated (lines 297–298, 354, 361). I also added one clause to the `step_bound` comment (lines 302–305): d̃ can carry an extra absolute error of √(nη₆₄/2)‖r‖ from the plain sum.

Final cold step:

```julia
@noinline function _sqrt_cold_step(m::SqrtLSModel{T}, old::T, k::Int) where T
  ls = m.ls
  X, r, s, xs = ls.X, ls.r, m.res64, m.rowmag64
  n = length(r)
  Mx, M = 0.0, 0.0
  @inbounds for i in 1:n
    Mx = max(Mx, abs(Float64(X[i, k])))
    M = max(M, abs(Float64(r[i])))
  end
  ex = exponent(Mx)
  as = 0.0
  @inbounds for i in 1:n
    v = ldexp(Float64(X[i, k]), -ex)
    xs[i] = v
    as += v*v
  end
  ras = sqrt(as)
  λs = ldexp(Float64(m.gt.λ0), -ex)
  λs >= ras && return zero(T)
  iszero(M) && return old
  er = exponent(M)
  bs, ss = 0.0, 0.0
  @inbounds for i in 1:n
    v = ldexp(Float64(r[i]), -er)
    s[i] = v
    bs += v*xs[i]
    ss += v*v
  end
  qs = bs/as
  ds2 = ss - bs*qs
  if ds2 < ss/16
    ds2 = 0.0
    @inbounds for i in 1:n
      v = s[i] - qs*xs[i]
      ds2 += v*v
    end
  end
  τs = (λs/ras)*(sqrt(ds2)/(sqrt(ras - λs)*sqrt(ras + λs)))
  e = er - ex
  shrink(old + T(ldexp(qs, e)), T(min(ldexp(τs, e), Float64(floatmax(T)))))
end
```

## Commit and status

- Commit `966004ec527c9fdbc45c950d08abae6c129d53e0`, one commit on `bb20b6a`, not pushed.
- `git status --porcelain` is empty.
- The evidence runs below were made at `1048834`. The later amends changed comments only (`ceb59c7`, then the `_prepare!` comment).
  - The only code change after the evidence runs: none; `git diff 1048834 HEAD` shows only comment lines.
  - I re-ran `sqrt_lasso` on both Julia versions at the final SHA: 1411/1411 each.
- `comment_scan.py` lists one line, `test/sqrt_lasso.jl:362` ("subnormal in every nonzero entry"). That is master's own comment about the test data, kept with the name updated. The data does have only subnormal nonzero entries.

## Evidence per criterion

Probe scripts are in `.codex-orchestrator/probes/`. Outputs are in `.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf/evidence/<name>-{lts,release}.out`. Julia 1.10 is `lts`, 1.13 is `release`.

**A. No domain change** (`d_all.jl`, `verify_a.jl`, `exp2c.jl`)
- **Boundary search**, 3,376,180 steps per Julia version: 0 outcome-class changes with K+.
  - This covers throws (same text), non-finite results and finite values.
- **Plain K failed 4 inputs** (identical on 1.10 and 1.13):
  - Float64, n=30, `x = fill(1.0010415475915507e-146, 30)`, `r = fill(2.4479196166420686e153, 30)` (also a variant with r[2] = 4e-323), `λ = 5.482930366157735e-146` (within an ulp of √a), `old = floatmax`.
  - Master returns Inf, which `_visit!` refuses. K returned 0.0, the true minimizer.
  - Cause: master's fast path has c = old + q = Inf, and the band step keeps c. The cold step re-tests λ ≥ √a in scaled Float64, which flips at the last bit of λ/√a.
  - This was a case where K accepts more than master. I found none where K refuses and master returns.
- **K+ fix**: the `isfinite(c) ? cold : c` guard on the band exit returns c unchanged, which is what master's `shrink(c, τ)` gave for a non-finite c.
  - Cost: one extra test on the band branch only. The fast path is untouched.
  - With it the boundary search shows 0 mismatches.
- **The five-case probe** (`verify_a.jl`): the two Stage 0 counterexamples (`X = fill(1e-150, 2, 1)`, y = 0, λ = 1e-151, zero start, and the exact fit with start 1) and the Stage 0 Float64 rescaling families give 52 of 52 outcomes with full-string equality (x, converged, gap, passes, minimum, error text), 0 different, on both versions.
  - Master's outcomes there: tiny-column certified, `gap = 0`, exact fit returned with `converged = false`, extreme-y `gap = NaN`, `ArgumentError` for curvature underflow.
- **`exp2c`** (about 360k steps per Julia version, 12 families × 2 types): 0 outcome-class mismatches.

**B. Ordinary path bit-identical**
- `exp_b1.jl` (30,000 random states per type, 3 visits each):
  - Float32: 202,826 fast or λ ≥ √a steps by master's classification, 0 not bitwise equal.
  - Float64: 202,134 fast or λ ≥ √a steps by master's classification, 0 not bitwise equal.
  - The comparison covers the new value, the residual cache and the curvature cache. Equal on both versions.
  - The non-fast steps in these runs (22,276 Float32, 22,737 Float64) were bitwise equal as well.
- `exp_b2.jl` (Stage 0 corpus, 748 whole solves):
  - 748 of 748 identical in x, passes, converged, gap, minimum and error text, on both versions.
  - Outcomes were 489 converged, 259 uncertified, 0 throws. Pass totals were 272,662 for master and 272,662 for K+.
- `fp_sqrt.jl` (cd-sqrt family of the fingerprint matrix, 158 comparisons including the 2^-500 and 2^480 scale cases): 0 mismatches on both versions.
- `tiny_solves.jl` (454 tiny or huge scale solves):
  - 432 bitwise identical, 22 throw the same text in both trees, 0 differ.
  - 162 of these solves ran master's recomputed-d branch.

**C. Cold path within the step bound** (`exp2c.jl`, 15,000 cases per family and type, seed 1; same table on 1.10 and 1.13)
- Excess over bound is at most 0.123 for both master and K+ on 1.10 (family `wide_full`) and at most 0.121 on 1.13.
- Every family has 0 cases above 1 for both master and K+, and 0 outcome-class mismatches.
- Families whose cases never differ from master: ordinary, near_parallel, tiny_d, lam_near, thresh, corner, huge_edge.
- Differing cases (cold or band steps) per family, with the largest difference, 1.10 / 1.13:

| family | type | differ of 15000 | largest ulp diff (1.10 / 1.13) | largest relative diff (1.10 / 1.13) |
|---|---|---|---|---|
| wide_mod | F32 | 153 / 109 | 7.98e3 / 3.2e4 | 7.2e-4 / 2.5e-3 |
| wide_mod | F64 | 203 / 230 | 4.1e3 / 3.47e3 | 5.3e-13 / 5.6e-13 |
| wide_full | F32 | 34 / 33 | 22 / 29 | 1.7e-6 / 2.1e-6 |
| wide_full | F64 | 59 / 55 | 169 / 26 | 2.5e-14 / 4.4e-15 |
| far | F32 | 35 / 24 | 1.02e3 / 128 | 8.6e-5 / 1.1e-5 |
| far | F64 | 1 / 0 | 3 / 0 | 3.6e-16 / 0 |
| band | F32 | 2920 / 2789 | 1.0e6 / 3.07e3 | 0.075 / 3.1e-4 |
| band | F64 | 2507 / 2531 | 4.1e3 / 2.05e3 | 5.7e-13 / 3.3e-13 |
| sub_lam | F32 | 6430 / 6307 | 1.98e3 / 1.02e3 | 1.5e-4 / 8.5e-5 |
| sub_lam | F64 | 5900 / 5771 | 1.22e4 / 4.29e3 | 1.6e-12 / 7.0e-13 |

  - The larger ulp or relative figures occur where the step is near 0 after c − τ, so the ulp reference is tiny.
  - Worst excess/bound for K+ against master per family: band F32 is 2.3e-8 against 2.6e-6 on 1.10, 8.2e-8 against 1.5e-7 on 1.13. sub_lam F32 is 1.7e-2 against 2.6e-2 on 1.10. The other families are equal.
- **Finite-versus-non-finite or throw-versus-value cases**: none (outcome-class mismatches = 0 in every family and type, both versions). Throw counts and non-finite counts are equal between master and K+ in every family and type.

**D. Boundary-targeted search** (`d_all.jl`, `exp_d.jl`, both versions, both types, n ∈ {1, 2, 3, 5, 30})
- **Part 1** (old = 0, all λ) and **part 2** (old ∈ {nextfloat(0), ±floatmax, 2^100 (F32) or 2^900 (F64), ldexp(nextfloat(0), 30)}, a subset of λ): 3,376,180 steps per Julia version across the three parts.
- **Ladder** (14 values per type and n; "at, one ulp below and one ulp above" is measured on the computed T sum of squares):
  - subnormal entries, floatmin, last failing and first passing entry value for the clean threshold, and the values just below and above it;
  - 1, ~√floatmax scale, the last finite and first overflowing sum, floatmax.
- **Each (x, r) pair** crosses the x ladder with the r ladder, in uniform and mixed shape (one big entry plus tiny ones) and alternating signs. Also included are r = 0, r parallel by powers of two, and r targeted so that γ is near floatmin or floatmax.
- **λ list**: ra, prevfloat(ra), nextfloat(ra), ra/2, subnormal λ and the γλ targets at floatmin and floatmax (with neighbours).
- **Part 3** (q-edge): c = old + q at the T overflow boundary with old = ±floatmax and perpendicular parts. It found no mismatch and no difference at all (0 of 325,248 to 327,600 per type and n).
- **Results**: both versions have 0 cases above the bound for master and for K+, and 0 outcome-class mismatches with K+.
  - Worst excess/bound, 1.10 (`lts`): 6.06e-2 (Float64, n=30, part 2), equal for master and K+.
  - Worst excess/bound, 1.13 (`release`): about 2.5e-2 (Float32, n=3, part 2).
  - On 1.13 Float64 n=30 part 2, K+ is 6.4e-3 against 5.9e-3 for master.
  - Zero-flips (one result 0 and the other not) occur in 17 to 25 cases per type in the n=2 and n=30 runs. Their excess/bound is still below the bound.

**E. Test files** (both versions, at `1048834`; `sqrt_lasso` repeated at the final SHA)
- `sqrt_lasso`: 1411/1411 on 1.10 and on 1.13, with no assertion changed.
- All five (`sqrt_lasso cd_numerics core_regressions core_contracts stopping_scale`) pass: 27956/27956 on 1.10, 27955/27955 on 1.13.
  - The one-test difference between versions exists in the same files regardless of this change (I did not re-run master to confirm).

**F. Allocations** (`alloc.jl`): equal to master in both versions.
- Warmed passes: 0 B. Cold steps (tiny residual, tiny column, huge residual, r = 0, band): 0 B.
- Warmed `solve!`: identical to master (Float32 15,536 B dense and 21,536 B sparse; Float64 20,208 B and 30,992 B).

**G. floor64** (`floor64.jl`)
- On 4000 vectors per type, bits differ in 42.6% (Float32) and 39.9% (Float64). The largest relative change is 1.06e-15 (Float32) and 7.8e-16 (Float64).
- At n = 1e5 randn: relative changes of 4.1e-14 (Float32) and 4.5e-15 (Float64).
- Outcome class or pass count changed in 0 solves across the 748-solve corpus, the 454 targeted solves and the 158 fingerprint comparisons.
- All of this is identical on both versions.

**H. Size** (`count_loc.py`, executable lines)

| function | before | after |
|---|---|---|
| `_scaled_norm` | 14 | deleted |
| `_sqrt_band_step` | 4 | deleted |
| `_sqrt_threshold64` | 8 | deleted |
| `_sqrt_offrange_step` | 39 | deleted |
| `_sqrt_cold_step` | – | 41 |
| `_sqrt_minimizer` | 21 | 21 |
| `_prepare!` | 15 | 15 |
| file | 310 | 286 |

The physical file goes from 526 to 497 lines.

## Differences from master on cold inputs
- The same four counts (3.38M boundary steps, 24 family-type cells of about 15000) show that fast-path and λ ≥ √a-class steps are bitwise equal.
- The differences are all in steps that leave the fast path: band exits and cold steps.
  - They come from the cold step reading X and r in Float64 where master used T sums for c, plus the plain-sum d̃.
  - They are round-off scale, as the table in C shows; the ratios are all within the step bound.
- In whole solves no difference was observable: 748 + 454 + 158 comparisons, bitwise identical.

## The choice for the cancelled d̃
I used the plain sum of squares of s − q̃x̃ in the cold step. `_se_norm` is not used there, and `_scaled_norm` is gone.

- The error is at most √(nη/2) < 2^-537 √n absolute in d̃. The bound of `test/sqrt_lasso.jl` holds with it in every sweep above.
- Master's recompute fires only where d̃² < ‖s‖²/16, so |q̃| is large against d̃ and τ̃ is far below c. The plain sum can then change z only if it flips the last rounding of c − τ, and it never did.
- Direct checks:
  - `dtilde.jl` (d̃ below 2^-537 against x = e1, 15,360 cases per version): 0 steps differ.
  - In the 454 targeted solves 162 ran master's recompute branch, and K+ was bitwise equal.

## Deviations from this brief
1. **The `isfinite(c) ? cold : c` guard on the band exit**, discussed under A. Without it the three exits call the cold step as written.
2. **Extra clause in `test/sqrt_lasso.jl`** (the `step_bound` comment) for the extra absolute error of the plain-sum d̃.
3. **`maximum(abs, y)` fallback in `_prepare!`** for a non-finite y, as the brief asked for handling that case.
4. Commit amended three times to keep one clean commit; no push.

## Not run
- Performance (speed) probes: the brief assigns the fast path's speed to another agent. The fast path is byte for byte except the three exit calls.
- The full test tier beyond the five named files: not requested.
- A master-side re-run of the 27955-versus-27956 test count difference: not needed for the criteria.
- Nothing else.

## Open questions
- Whether the maintainer wants the `isfinite(c)` guard (K+) or plain K. Plain K changes 4 boundary inputs from a refusal to the correct value 0.0, and the guard costs one extra comparison on the band branch.
- Whether the two-line `_prepare!` handling of a non-finite y should stay, given `solve!` never reaches it.

Status: COMPLETE