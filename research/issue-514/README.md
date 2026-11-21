# PGD/APG numerical feasibility study for ProximalSolvers #514

The experiment compares three ways to consume the same PB projected coefficient vector. A runs PS's published strict engine. B uses a numerical feasibility cap and checks stationarity at the returned point. C changes just the ℓ₁ feasibility decision to use PB #1138's signed enclosure. The research code calls unmodified PB projection methods in each arm.

## Run

Use Julia 1.10.13 and 1.13.4. `bash bootstrap.sh /path/to/julia-installs` expects Julia to be installed at `julia-<version>/bin/julia` under that directory. It fetches the three pinned source checkouts into this directory and instantiates `env/<version>` with the locks in `locks/`. The two package paths in each lock point to the sibling checkouts. The pins in PS's own `Project.toml` are independent of this environment.

Run the commands from this directory. The environment variables select one Julia thread, one BLAS thread and the locked project.

```bash
version=1.10.13
julia_bin=/path/to/julia-installs/julia-$version/bin/julia
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
export JULIA_LOAD_PATH='@:@stdlib'
"$julia_bin" --startup-file=no --threads=1 --project="env/$version" preflight.jl
"$julia_bin" --startup-file=no --threads=1 --check-bounds=auto --project="env/$version" correctness.jl results/$version-auto full
"$julia_bin" --startup-file=no --threads=1 --check-bounds=yes --project="env/$version" correctness.jl results/$version-yes full
```

Repeat the correctness commands with `version=1.13.4`. `correctness.sbatch` runs the four combinations under Slurm. The official timings use `benchmark.sbatch` with a whole exclusive node. Its Julia processes run sequentially on one bound physical core. Each process starts with a separate warmup order. The timed runs use the ordinary profile, default bounds mode, optimization level 2 and native CPU target.

```bash
sbatch $CORRECTNESS_OPTIONS correctness.sbatch "$PWD" full
sbatch $EXCLUSIVE_TIMING_OPTIONS benchmark.sbatch "$PWD" full
```

Supply a four-core allocation for correctness and an exclusive single-process allocation for timing. Run the timing job after correctness. Set the Julia installation root in each job script for your system. `preflight.jl` prints the actual loaded source paths relative to the research directory and verifies the Git revisions, trees, and shared imports. The main entry points are `correctness.jl` and `benchmark.jl`. The code under `ps/`, `pb/` and `enclosure/` comes from the pinned upstream checkouts during bootstrap.

## Policies and declared accuracy

See the preregistration comment on [#514](https://github.com/mlakolar/ProximalSolvers.jl/issues/514#issuecomment-7060428945) for the tolerance table. The ordinary requests give examples of absolute accuracy on standardized coefficients and relative accuracy when coefficients are rescaled. The mixed profile puts half the coefficient allowance on each. The independent checker uses the actual budget scalars given to the experimental arm.

Let `s` be the stored loss scale, `C = √s max_j ||X[:,j]||₂`, and `Y = √s ||y||₂`. The example objective scale is `max(Y,Cr)^2/2`. Half the relative request at that scale is allotted to objective error of the feasible witness by its support gap. Half is allotted to loss change between the stored coefficient vector and the witness. For a radial move with `v=||x||ₚ-r ≤ r`, let `M` bound the operator norm of `√s X` from the coefficient norm to ℓ₂. The displacement has coefficient norm `v`, and
`|f(x)-f(w)| ≤ v·(MY + M²(||x||ₚ+||w||ₚ)/2) ≤ v·(MY+1.5M²r)`.
Use `C` for ℓ₁ and a Frobenius bound for ℓ₂. The trial cap is the minimum of the user-specified coefficient allowance, the radius, and the allowed objective perturbation divided by this slope. Projection rounding and tolerance for optimization are separate quantities.

For B, the Float64 norm and a normal-range rounding-resolution estimate decide cap comparisons. Ambiguous comparisons with the cap are withheld. ℓ₂ uses a max-scaled norm. C calls the exact #1138 archived `wide_screen` and `compensated` functions, checking the cap at each trial and refining unresolved comparisons. It can also refine a proposed return's sign at zero to classify the extended-real objective. B and C use the same magnitude estimate in their stationarity scratch space. Neither arm uses its witness to change the caller's coefficients.

A's public entry point is exercised separately, including the four-entry ℓ₂ control. The audited internal adapter checks data and strict starting membership before passing the actual ball through PS's existing iteration engine. Its observation wrapper calls PB's fused method and forwards the resulting value. PGD's line search already tests smooth values and gradients. The result engine requires a finite composite after an iteration. APG applies the same smooth image bound in all arms, with its normal extrapolation and restart policy. A compares the composite on restart. B/C compare the smooth loss and prefer an explicit feasibility rejection to entering PS's composite return logic. On B/C trial rejection the search raises curvature. It stops with a numerical limitation after 64 trials from one base point. Fault probes check last accepted point rollback.

The stopping decision uses a feasible scratch radial witness estimated in Float64 and a fresh residual and gradient evaluated at it. Float32 solve iterations retain their native coefficient and gradient type. The stopping refresh accumulates in Float64 for both types. A magnitude estimate uses dot-product depths and the Frobenius norm to account for residual and gradient resolution, with no interval arithmetic in the stop. The stop uses both a cancellation-resistant support gap and a projected-gradient mapping at the witness rounded to the original type. The mapping uses `C²` as its fixed inverse step when the design is nonzero, plus an allowance for the working-type step resolution. The reference recomputes both quantities in MPFR from the represented data, and also measures normal-cone residual and complementarity. Its mathematical projection uses an independent sorted threshold or radial formula. The reference fits use closed form for equal-curvature diagonal designs, small active-set enumeration for dense ℓ₁, or an independent ridge multiplier root for ℓ₂. The repeated correlated ℓ₁ block example has an independently checked analytic solution. The enclosure substantiates feasibility under its assumptions. The stationarity estimation and this finite matrix do not establish a certified solver.

B and C expose the smooth monitor even for exterior points. The returned composite is infinite for classified exterior points, the smooth value for classified inside points, and missing for ambiguous membership. A's value is the rounded PB composite under its contract. `exact_composite` in the evidence is a separate independent classification. A normal `converged` result and an `approximate_solution` result both count as claims against the declared numerical budgets. Only the former also states the solver's inside classification. Progress alone can propose a check and can drive a numerical-stagnation exit. It cannot produce a success.

## Read the tables

- `solves.tsv` records input, public refusal, policy status, evaluation and projection counts, work and independent residuals, and exact-output diagnostics. `rejected` counts uncommitted projected trials, including discarded extrapolated steps. `backtracks` preserves the engine's own convention. Recomputed stationarity gradients and mapping projections are included in B/C counts. A retains the pinned counters, which omit the lazily computed reference score at zero. A/B/C trial and mapping digests hash input bits, step bits and output bits in call order. The verifier runs the complementary PB entry point at each call during correctness only. The control and all candidates use the same PB kernel.
- `vectors.tsv` records the native bytes of each question's stored return on the little-endian campaign host. `traces.tsv` contains selected callback/result traces. `projections-*.tsv` measures the same represented input under separate and aliased outputs and cap/sign probes, including zero and near-zero cutoff diagnostics. `historical.tsv` replays two #508-era checks with the frozen production projection. The old four-epsilon route is a separate positive control for false exact membership. The old working-gradient route demonstrates the tight support-gap failures.
- `controls-*.tsv` checks exact clipping and the public gates. `rollback-*.tsv` records the callback and induced-failure assertions.
- Timing `solves.tsv` gives time and allocation samples alongside a separate matching-policy accuracy run for each workload. `fixed.tsv` times eight fixed orthogonal gradient/projection steps with matching bits for every route and with one proposed stop per batch. It compares the strict fused value, B's numerical check, the C cheap screen alone, C with refinement at ambiguous cap comparisons or a proposed stop, and the refine-every-trial ablation. The rows give nanoseconds, bytes and allocation counts per operation. `clipping.tsv` uses identical-source replicas as existing supported-path controls. The left/right A/A observations use separately created baseline replicas. `warm_order` is the first invocation order in fresh Julia processes. `order` and `aa_order` state the paired invocation order.
- `summarize.py` rebuilds the JSON summaries from the configuration directories. It checks coverage, pair counts, parity, and counts the repeatable slowdowns. A slowdown flag requires every median stratified by warmup and execution order to exceed 1.05 and the empirical paired A/A 90th percentile. Raw timings include slower observations and indicate whether each policy reached acceptable accuracy. Comparing solve times is meaningful only where both outputs attain it.

```bash
python3 summarize.py numerical data/correctness
python3 summarize.py timing data/timing
sha256sum --check SHA256SUMS
```
