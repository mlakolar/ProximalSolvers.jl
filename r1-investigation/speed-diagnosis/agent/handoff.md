## Summary
Julia 1.10's `max`/`min` make the exported `shrink` slow, and x1d's slowdown is that and nothing else. x1a's slowdown comes from `iszero(d) |` in the range test. K's shape is at parity with the base. A band-free fast path with a local 3-line soft-threshold passes the gate on every cell of both harnesses, on 1.10 (both targets) and 1.13. Its patch is `.codex-orchestrator/out/r1d-bandfree-fastpath.patch`.

All paths below are under `W=<WORK>/ProximalSolvers.jl-issue353-r1-perf/.codex-orchestrator`. Nothing tracked was edited or committed, no Pkg operation other than `instantiate` on 1.13 (it created the untracked, gitignored `Manifest.toml`), and GitHub was not touched. `git status` is clean in the scratch worktree and in the base worktree.

Setup facts that matter for reading the tables:
- **Default target on 1.10.** `Sys.CPU_NAME` says `goldmont`, but the feature set is the host's. Default-target code uses `ymm` and `vfmadd` just like `-C alderlake`. Only an explicit `-C goldmont` removes AVX (`probes/feat.jl`: ymm=95 at default and at alderlake, 0 at `-C goldmont`). So the brief's "goldmont, without AVX" is not accurate; default and alderlake differ in CPU tuning and scheduling, not in vector ISA.
- **A/A controls swing ±3–5 % from code placement, not noise.** Two compiled copies of identical code differ by a stable amount per cell. With 3 base copies (`base0/1/2`) and 2 copies of K (`k`, `k2`), `k` matches whichever base copy sits at the same placement (`q1b-visit-lts.tsv`: e.g. F32 20x10 converged gives 0.964, 0.966, 0.966 for base2, k, k2 against 1.000 for base1). That is why I used 3 base copies and 2 copies of each candidate.

## Answer to question 1: K's shape costs nothing on the ordinary path
The variant `k` replaces only the band branch with `_sqrt_offrange_step(m, old, k)`. Tables are 15 rounds, median of per-round ratios against `base0`, in `W/out/q1-{lts-default,lts-alderlake,release}-{solve,visit}.table.txt`. The solve harness has 40 cells (W1 = solve to convergence, W3 = 3 fixed passes) and the visit harness 20 cells (W5 = per-visit read-only probe).

| harness | Julia, target | k range | k2 range | A/A (base1, base2) | verdict |
|---|---|---|---|---|---|
| solve | 1.10 default | 0.951–1.002 | 0.928–1.033 | 0.938–1.053 | parity |
| visit | 1.10 default | 0.972–1.689 (one cell) | 0.967–1.038 | 0.964–1.037 | parity; one outlier, not reproduced |
| solve | 1.10 alderlake | 0.987–1.007 | 0.992–1.032 | 0.991–1.011 | parity |
| visit | 1.10 alderlake | 0.973–1.026 | 0.975–1.021 | 0.966–1.033 | parity |
| solve | 1.13 | 0.975–1.008 | 0.970–1.011 | 0.993–1.014 | parity |
| visit | 1.13 | 0.961–1.033 | 0.988–1.030 | 0.955–1.030 | parity |

- **The outlier.** In one run, visit F64 20x10 zero showed k at 1.689, steady across all 15 rounds. It did not recur in three repeats of that cell (k 0.999–1.003, k2 1.000–1.002) or in a full re-run of the visit harness (k 0.971–1.028, k2 0.981–1.006, A/A 0.965–1.036; `q1-lts-default-visit-rerun.tsv`, `q1r-{1,2,3}.tsv`). I treat it as a one-off placement or data-layout effect.
- **Other small deviations.** The few other k or k2 cells at +3 to +4 % (for example solve W3 F64 20x10 at 1 µs, alderlake, k2 1.032) are matched by the A/A copies at the same placement, or lie within the A/A swing of that file.
- **Native code.** The `_sweep!` native for base and k differs by 4 instructions (1393 against 1397 for F64, spec1). Counts of `sqrt` (8), `div` (4), calls (45) and conditional jumps (196) are equal. The visible differences are register renaming and stack-slot order (`probes/ir_q1.jl`, `probes/norm.py`, `out/q1-*.s`).

## Answer to question 2: why x1d and x1a were slower on 1.10
I reproduced both worst cells on 1.10 with both targets (`q2a-lts*-{solve,visit}.tsv`):
- **x1d solve:** F32 30x120 λ=0.1 at 1.105 (default) and 1.063 (alderlake); F64 same shape at 1.086 and 1.039.
- **x1d visit:** F64 400x40 at 1.12–1.15 (default) and 1.04–1.06 (alderlake).
- **x1a visit:** F64 20x10 at 1.22 and 1.23; F64 30x120 at 1.28 and 1.26.
- **A/A in the same runs:** within 0.3 % (1.8–2.6 % for 30x120).

### Cause 1, x1d: the exported `shrink`, which is the whole gap
Evidence from the IR and assembly:
- **1.10 IR.** `max(v-c,0)+min(v+c,0)` lowers to `bitcast→icmp sgt −1→select` and `fcmp ord→select`, once for each of max and min (`probes/shrink_ir.jl`).
- **1.10 native.** Standalone it is 22 instructions. Inlined in the visit loop it is `vmovq rax,xmm; test rax,rax; jns` twice (a data-dependent branch on the sign of `c−τ` and of `c+τ`), plus 2×`vcmpordsd` and 2×`vblendvpd`.
- **1.13.** `shrink` is `llvm.maximum`/`llvm.minimum`, 13 instructions with no GPR transfer or branch. The select form (ProximalBase's `_shrink_nonneg`, reproduced locally as `_pnn`) is 12 instructions on both versions.

Single-factor timing, visit harness, 1.10 default target (alderlake in brackets), F64 400x40 converged:

| variant (band test kept unless noted) | ratio |
|---|---|
| `shrink(c,τ)` instead of `prox_block` (`bshrink`) | 1.118 [1.079] |
| local `_pnn` (`bpnn`) | 1.002 [1.003] |
| `shrink`, band test removed (`bnoband_shrink`) | 1.096 [1.066] |
| `prox_block`, band test removed (`bnoband`) | 0.983 [0.994] |
| x1d | 1.107 [1.077] |

- **Other cells.** `bshrink` is +13 % to +16 % at F64 20x10, 100x60 and 30x120, and +11 % to +24 % at F32 400x40 and F32 30x120. `bpnn` is 0.98–1.03 everywhere. x1d is about equal to `bnoband_shrink` (1.04–1.11).
- **Solve level.** The control `cand_shrink` (my candidate with `shrink` put back) reproduces the slowdown: F64 30x120 λ=0.1 1.080, F32 30x120 λ=0.1 1.104, W3 1.042 (`q3-lts-default-solve`). On 1.13 the same control is within 0.95–1.02 on both harnesses.
- **The extra division is not a factor.** `d_2div` (shrink, 2 divisions) 1.103 against x1d (shrink, 3 divisions) 1.104 at F64 400x40; `d_sel_2div` against `d_sel` is 1.016 against 1.015, and at the smallest cells the 2-division form is 1–3 % faster (`q2c-*`).
- **The range test itself costs almost nothing:** `bpnn` against `bnoband` is 1–9 %, in the direction of the band test being slightly slower, not faster.

### Cause 2, x1a: `iszero(d) | (...)` in the range condition, about two thirds of it explained
- **Isolation.** Starting from base, adding only `iszero(d) |` to the band condition (`c1_iszero_d`) gives F64 20x10 1.211 (x1a: 1.217), 30x120 1.192 (1.258), 100x60 1.107 (1.130) and F32 30x120 1.207 (1.234) (`q2e-lts-visit.tsv`).
- **Mechanism.** LLVM 15 SLP-vectorizes the compare chain: 4×`vcmplepd` with `vandpd`, `vmovd ecx,xmm` GPR transfers and `and/or/test` in x1a and c1, against 0 in base (`out/c1-*.s`).
- **Partial confirmation.** With `||` instead of `|` (`c1b_oror`) `vcmplepd` disappears and the cost drops to +5 % to +9 %.
- **On 1.13** the same `iszero(d)|` form is also slow (+11 % to +16 % per visit, `q2f-release-visit.tsv`). So it is not 1.10-specific; the Stage 0 solve ratios simply hid it.
- **Not factors** (each within A/A, 0–3 %): `view(X,:,k)` built at the top and passed through (`a1_view`), a 7-argument cold call (`a2_cold7`), the same with a view (`a3_cold7v`), both together (`a4`), no `_clean_sum(d2)` recheck (`c2`), and the generic `_sqrt_step(m,X,r,g,…)` with `g::NormL1{T}` (`c3`: 0.999–1.002).

### Not explained
- The remaining +5 % to +9 % of c1b after the SLP effect is gone.
- Why the 1.10 sign-branch form hurts the solve loop only 4–10 % when it hurts the visit probe 10–15 %. The visit probe has a predictable sign pattern, the solve does not.

## Answer to question 3: a band-free fast path within the gate
**Recommended form** (`W/out/r1d-bandfree-fastpath.patch`; `git apply --check -p1` succeeds in the base worktree; only `src/cd/sqrtlasso.jl`, +20/−16 lines):

```julia
@inline function _soft(v::T, τ::T) where T
  lo = -τ; m = ifelse(v > lo, v, lo); (v - ifelse(m < τ, m, τ)) + zero(T)
end
@inline function _sqrt_minimizer(m::SqrtLSModel{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T
  ... (a, ρ², λ ≥ ra, q, d2 and its recompute exactly as in base, exits `_sqrt_offrange_step(m, old, k)`)
  _soft(old + q, (λ/ra)*(sqrt(d2)/(sqrt(ra - λ)*sqrt(ra + λ))))
end
```

- **Fewer exits.** It has no band branch, so only the two exits that already have the `(m, old, k)` signature remain. The `d2` recheck is kept, since it costs nothing (`c2`).
- **`shrink` vs `_soft`.** `_soft` replaces the exported `shrink`. It equals `shrink` bit for bit for every τ ≥ 0, NaN, Inf and ±0 included (`probes/soft_check.jl`: about 1.17M pairs each for Float16, Float32 and Float64, 0 differences, on 1.10 and 1.13).
- **τ ≥ 0 always holds.** λ is validated positive and finite before any step: λ<0, NaN, 0 and Inf throw identically in base and candidate (`probes/lam_edge.jl`).
- **ProximalBase API.** It uses no private ProximalBase name. It duplicates the 3-line `_shrink_nonneg`, which is private to PB.
- **Comments.** The patch also rewrites the `_sqrt_minimizer` comment with the τ no-overflow bound, taken from Stage 0 and not re-derived here. The compiled code is identical to the measured variant `cand` (non-comment lines diff empty).

**Timing** (15 rounds, `cand` and `cand2` are two compiled copies; full tables in `W/out/q3-*-{solve,visit}.table.txt`, columns base1 base2 cand cand2 cand_shrink). The candidate and the K shape are both measured against the same `base`, with the same harnesses. No cell exceeds the gate. The recommended form is also faster per visit.

| harness, target | cells | cand range | cand2 range | A/A base1 / base2 | cells outside gate |
|---|---|---|---|---|---|
| solve, 1.10 default | 40 | 0.967–1.035 | 0.964–1.035 | 0.984–1.036 / 0.991–1.052 | 0 |
| visit, 1.10 default | 20 | 0.864–1.000 | 0.864–0.998 | 0.970–1.025 / 0.993–1.003 | 0 |
| solve, 1.10 alderlake | 40 | 0.948–1.016 | 0.947–1.016 | 0.990–1.014 / 0.992–1.010 | 0 |
| visit, 1.10 alderlake | 20 | 0.876–0.999 | 0.877–0.998 | 0.977–1.035 / 0.970–1.004 | 0 |
| solve, 1.13 | 40 | 0.927–1.014 | 0.929–1.014 | 0.992–1.010 / 0.991–1.011 | 0 |
| visit, 1.13 | 20 | 0.874–1.021 | 0.873–1.033 | 0.985–1.026 / 0.992–1.014 | 0 |

- **Gate.** "Outside gate" means above 1.05, or above 1 + max A/A deviation + 0.02.
- **Worst cells.** The worst candidate cells are the same ones the A/A copies swing on: W3 F64 100x60 λ=0.5 at 1.035 (A/A 1.036 and 1.052) and 1.13 visit F64 400x40 at 1.033 (A/A 1.023–1.026).
- **Per-visit speed.** Geo-mean per-visit ratio is 0.94–0.95 on all three configurations, and 0.99 on solves.
- **The regression cell** (F32 30x120 λ=0.1, W1, 1.10) is 0.995.
- **Pass counts.** `passes` differ by ±1 or ±2 from base in 5 of the 120 solve cells, all Float32 W1 at λ=0.5, so those cells are not strictly equal work; W3 cells (3 fixed passes) are the equal-work ones. The count of 5 is stated as measured in the TSVs.

**Correctness and non-refusal** (the candidate against the base, and against x1d where noted):
- **Repository test.** `test/sqrt_lasso.jl` on a scratch copy of the tree (`variants/cand_tree`) passes 1411/1411 on 1.10 and 1.13 (`out/q3-test-sqrt_lasso-*.log`). The three errors Stage 0 reported for x1 do not appear, because the cold exits are unchanged. Only that test file was run.
- **Accuracy against BigFloat-512.** I used the Stage 0 families, adapted (`probes/acc.jl`): 480,000 cases per Julia version, 12 families, both types, seeds 2 and 3. Zero cases above the step bound, worst ratio 0.1197 on 1.10 and 0.1185 on 1.13, identical to base. Throw and non-finite counts per family and type are identical to base (`q3-acc-lts-big.txt`, `q3-acc-release-big.txt`).
- **Last bits differ from base.** On ordinary data the candidate differs from base in the last bits in about 1–4 % of steps, a quarter of all families not at all (`probes/bitdiff.jl`, 1.10, N=5000).
  - Maximum relative difference is 3.2e-14 for Float64.
  - It is 6.4e-5 for Float32, in cases near cancellation (|z| small).
  - Whole-solve objectives differ by at most 1.5e-7, and `converged` never differs.

## Load averages during the reported runs
1-minute averages at start and end, from the `.load` files. Other agents were running throughout, so every table has its A/A control.

| run | start → end |
|---|---|
| q1 default | 2.16 → 2.60 |
| q1 alderlake | 2.60 → 3.02 |
| q1 release | 3.02 → 2.32 |
| q3 default | 3.30 → 3.27 |
| q3 alderlake | 2.99 → 2.52 |
| q3 release | 2.52 → 3.49 |

The q2 diagnostic runs had load 1.6–4.3. Every timing run was pinned with `taskset -c 2` and `MemoryMax=10G`.

## Files
- **Patch:** `W/out/r1d-bandfree-fastpath.patch`. Code of the measured variant `W/variants/cand/src/cd/sqrtlasso.jl`; the patched file is `W/variants/cand_final/src/cd/sqrtlasso.jl`.
- **Variants:** `W/variants/{base,k,x1d,x1a,x1c,x1e,bshrink,bsel,bpnn,bnoband,bnoband_sel,bnoband_shrink,d_sel,d_pnn,d_2div,d_sel_2div,d_pb,a1_view,a2_cold7,a3_cold7v,a4_view_cold7,c1_iszero_d,c2_no_d2_check,c3_generic_step,c1b_oror,cand,cand_shrink,cand_final,cand_tree}`.
- **Generator:** `W/probes/mkvariants.py`.
- **Harnesses:** `W/probes/paired.jl` (solve), `W/probes/visit.jl`, `W/probes/run_paired.sh`.
- **Summaries:** `W/probes/compact.py`, `W/probes/verdict.py`, `W/probes/summarize.py`.
- **IR and native:** `W/probes/irlib.jl`, `ir_q1.jl`, `ir_pass.jl`, `norm.py`, `shrink_ir.jl`, `feat.jl`.
- **Correctness:** `W/probes/soft_check.jl`, `acc.jl`, `accfam.jl`, `acc_lib.jl`, `acc_trees.jl`, `bitdiff.jl`, `lam_edge.jl`.
- **Outputs, all under `W/out/`:**
  - Q1 timing: `q1-*`, `q1b-*`, `q1r-*`.
  - Q2 diagnostics: `q2a-*` (x1d, x1a repro), `q2b-*` (shrink and band ladder), `q2c-*` (d-series), `q2d-*` and `q2e-*` (x1a bisect), `q2f-*` (1.13), `q2g-*` (`||`).
  - Q3 timing: `q3-*.tsv` with `.table.txt`, `.summary.txt`, `.load`.
  - Correctness: `q3-acc-*.txt` and `q3-test-sqrt_lasso-*.log`.
  - IR and native listings: `*.s` and `*.ll`.

## Not run
- Float16 timing.
- AVX-512, macOS aarch64, or `-C goldmont` (no AVX) timing.
- Julia 1.11 and 1.12.
- The full repository test suite, and the group, ElasticNet and PGD/APG solvers (only `test/sqrt_lasso.jl`).
- Timing with `SparseIterate`, the random order, or warm starts; the harnesses use dense cyclic solves.
- Candidate K itself (it is in another agent's worktree). I measured its shape as the variant `k`.
- An isolated LLVM experiment (SLP off) for the x1a mechanism; it rests on the asm correlation plus the `||` variant.

## Open questions
1. `shrink` is exported by ProximalBase and costs 10–15 % per visit on 1.10 in hot scalar loops. Other solver code that calls `shrink` per coordinate (for example the cold `_sqrt_band_step` and any PB scalar use) is exposed to the same cost; only the sqrt-lasso fast path was changed here. A PB-side change would need a decision outside this brief.
2. The patch adds a 3-line local copy of PB's private `_shrink_nonneg`. Is a duplicated helper acceptable, or should PB expose a public non-negative soft threshold?
3. `test/sqrt_lasso.jl:297` still names `_sqrt_band_step` as a path for the Float64 threshold; it is now reached only from the cold `_sqrt_offrange_step`. I did not edit it.
4. Band-free changes last bits relative to base (see above). The bar was "clear pass of the gate", which the candidate meets, but bit-identity with master is lost, unlike K.

Status: COMPLETE