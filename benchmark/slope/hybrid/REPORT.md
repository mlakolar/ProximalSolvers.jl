# Hybrid SLOPE pilot: no production promotion

The bounded pilot for [issue #95](https://github.com/mlakolar/ProximalSolvers.jl/issues/95)
does **not** justify adding this hybrid to the public solvers. Keep screened
`SLOPEAPG` as the supported path engine. This is a result about the prototype
and workloads below, not a rejection of the published algorithm or a claim
about an optimized specialist implementation.

## Accuracy and decision

Both methods use the existing screening, reduced losses, working-set repairs,
full fixed-point check and retained-failure path driver. The only package
refactor extracts private reduced-solve and path helpers, so the benchmark
prototype can reuse that driver without duplicating it. No public solver,
dependency, default or tolerance is added or changed.

The declared benefit was fewer matrix products on difficult clustered,
ill-conditioned least-squares paths, without losing robustness. The protocol
was fixed in [README.md](README.md) before the first run. An initial diagnostic
at `tol=1e-7` passed all fixed-point checks but missed the independent `1e-6`
gap target at three hybrid levels. Both methods were then calibrated to
`tol=1e-8`, without increasing the per-level budget of 10,000 iterations.

| Cohort | Method | Requested levels | Full residual passed | Independent gap passed | Largest relative gap |
|:--|:--|--:|--:|--:|--:|
| Main, seeds 1–3 | APG | 864 | 864 | 864 | 2.43e-7 |
| Main, seeds 1–3 | Hybrid | 864 | 855 | 859 | 4.22e-4 |
| Confirmation, unused seeds 11–12 | APG | 576 | 576 | 576 | 2.31e-7 |
| Confirmation, unused seeds 11–12 | Hybrid | 576 | 572 | 572 | 6.92e-4 |

All 13 hybrid nonconverged levels exhausted the budget and occurred on dense
latent-AR(1) designs with rho=.99. Nine also missed the independent gap target;
four passed the gap but still failed the solver's residual criterion. These
flags remain false. Later levels were independently checked even after a failed
warm start. No failure was removed from the requested-level denominators.

The accuracy gate fails in both cohorts. The twofold full-design-product gate
also fails on sparse controls. Reducing the count of full-width products alone
would be misleading: on the correlated dense pairs that **did** pass both
checks, the hybrid used many more restricted products and more total entry work.

## Conditional work and warm measurements

The following are medians of **hybrid/APG** within paired paths where both
methods passed every full residual and every independent gap. They exclude
failed paths from timing comparisons; the counts make that conditioning explicit.
Each cell has one warm observation per fixture, not replicated timing blocks.

| Cohort | Latent rho / storage | Certified pairs / requested | All design products | Entry work including cluster columns | Warm time | Julia allocation bytes |
|:--|:--|--:|--:|--:|--:|--:|
| Main | 0 / dense | 24 / 24 | 0.590 | 0.767 | 15.0 | 68.8 |
| Main | 0 / sparse | 24 / 24 | 0.455 | 0.577 | 15.3 | 85.3 |
| Main | .99 / dense | 15 / 24 | 5.63 | 5.92 | 51.1 | 641 |
| Main | .99 / sparse | 24 / 24 | 0.429 | 0.530 | 12.8 | 99.8 |
| Confirmation | 0 / dense | 16 / 16 | 0.580 | 0.746 | 9.68 | 43.8 |
| Confirmation | 0 / sparse | 16 / 16 | 0.473 | 0.618 | 16.1 | 92.3 |
| Confirmation | .99 / dense | 12 / 16 | 6.37 | 6.91 | 76.6 | 1,030 |
| Confirmation | .99 / sparse | 16 / 16 | 0.430 | 0.537 | 11.6 | 93.6 |

Products count both directions and include full-problem checks. Full-width
products are also recorded separately. Entry work counts matrix entries touched
by products and signed cluster-column construction: `n*p` for dense matrices and
stored nonzeros for CSC matrices. It is a work proxy, not a complete flop count;
sorting, vector work, memory traffic and allocations also cost time. Instrumented
and plain fits agreed within `1e-8` in every coefficient vector. Counters and
independent certificates run separately from the timed plain solve.

The prototype rebuilds cluster membership, ranks and signed columns during
sweeps and allocates heavily. Caching these structures could reduce its time
and memory cost, but would not by itself resolve the demonstrated convergence
failures or excess restricted matrix work. This pilot does not establish a
timing lower bound or predict behavior at larger dimensions. No process-RSS
study was run: the numerical/work gate already rejected production promotion.
Allocation bytes are **not** process RSS, and no memory superiority is claimed.

## Workloads and algorithm

Each seed has 32 fixtures: `n=80`, `p=120`, latent rho in `{0,.99}`, dense or
15%-masked CSC storage, 8 or 32 signals, linear or stepped positive rank weights,
and 6 or 12 log-spaced levels from `lambda_max` to `.05lambda_max`. Nonzero
signals repeat magnitudes 2 and 1 with alternating signs; Gaussian noise has
scale .3. This gives 160 paired paths and 1,440 levels per method across cohorts.
The sparse masking weakens the latent correlations substantially; those are
storage controls, not evidence of equally ill-conditioned sparse problems.

The prototype implements the scalar cluster minimizer from Larsson,
Klopfenstein, Massias and Wallin (2023),
[Sections 2.1–2.3](https://proceedings.mlr.press/v206/larsson23a.html), by searching
the piecewise-affine penalty's exact magnitude breakpoints and rank weights.
It can merge clusters, cross ranks and reverse a cluster's signs. It updates
only nonzero clusters. A proximal-gradient step can split them and activate
zero coefficients. Four cluster sweeps intervene between gradient steps;
momentum restarts after cluster moves. A nonfinite or increasing cluster block
restores the last PG iterate, disables cluster updates for that reduced solve,
and continues with APG. Finite slow progress is not treated as convergence.

An APG iteration and a hybrid iteration have different costs: the latter counts
one PG step or one complete cluster sweep. Both methods have 10,000 such
iterations per level including repairs; raw iteration counts must not be read
as equal gradient counts. APG retains its original internal stopping rules;
the hybrid checks the reduced fixed-point residual after each PG step.
Acceptance requires the same full residual and external dual-gap targets.
The independent certificate rebuilds predictions and scales the least-squares
residual into the SLOPE dual ball. It does not reuse solver residuals, rank
buffers or the cluster threshold code.

The benchmark checks cover scalar minimizers against exhaustive kink/stationary
candidate enumeration, rank crossings, signs and merges, PG splitting/zero
activation, cancelling columns, Float32, excluded predictors, rank deficiency,
dense/CSC/product-only implicit designs, retained budget failures, and injected
bad cluster directions followed by a successful APG fallback.

## Evidence, provenance and recreation

- [summary.json](summary.json) is regenerated from complete path and level TSVs
  by [summarize.py](summarize.py). CI verifies coverage, counts, budgets, failures
  and exact summary regeneration; an empirical no-go is an expected result.
- `evidence/main.tsv` and `evidence/confirmation.tsv`, with their `.levels.tsv`
  companions, are the final decision data. `calibration-v1.*` retain the earlier
  calibrated run; the final main run exactly replayed its numerical metrics,
  iterations and matrix-work counts after hardening the rejected-sweep guard.
- `initial-diagnostic.tsv` retains the preliminary `1e-7` run. It used a local
  ProximalBase master checkout at `0111d1b` with pending naming changes; its
  ordered-penalty and least-squares source files match the clean final dependency.
  Only dense kernels were prewarmed in that diagnostic, so its timing is not
  used in the decision table.
- Final runs use clean ProximalBase master `b6c949f`, solver base `531ff55`
  plus this PR, Julia 1.13.2 on Apple M3, one Julia thread and one OpenBLAS
  thread. [environment.toml](evidence/environment.toml) records full revisions,
  flags and SHA256 hashes of the measured sources. The saved manifest records
  resolved dependencies; its local source paths must be resolved in the new
  workspace. There were no cluster jobs in this pilot.

From a checkout of this PR with a clean sibling ProximalBase master checkout
(use `b6c949f` to reproduce the recorded dependency), run:

```sh
julia scripts/test_master.jl --setup-only
julia --startup-file=no --compiled-modules=existing --project=.master-test-env/v1.13 benchmark/slope/hybrid/checks.jl
julia --startup-file=no --compiled-modules=existing --project=.master-test-env/v1.13 benchmark/slope/hybrid/pilot.jl benchmark/slope/hybrid/evidence/main.tsv 1,2,3 1e-8
julia --startup-file=no --compiled-modules=existing --project=.master-test-env/v1.13 benchmark/slope/hybrid/pilot.jl benchmark/slope/hybrid/evidence/confirmation.tsv 11,12 1e-8
python3 benchmark/slope/hybrid/summarize.py --write
```

The runner prewarms both storage types and methods, and alternates paired order
by fixture. Timings will change by machine; inspect convergence and the decision
before comparing timings. To verify the committed evidence without rerunning
numerical work, run `python3 benchmark/slope/hybrid/summarize.py`.

Prior specialist comparisons, all 36 unscreened correlated FISTA failures, and
the corrected process-memory cohort remain intact in their original reports.
This numerical pilot supplies no statistical FDR guarantee.

## Validation

The complete Julia 1.13.2 package suite passed **17,410 assertions**, including
426 benchmark-specific checks and the original 53 engine checks. Julia 1.10.12
passed the 53 engine and 426 hybrid assertions. Both used bounds checking and
the clean pinned ProximalBase master checkout. Logs are retained in `evidence/`.
The naming check, whitespace check and Python summary/coverage integrity check
also passed. CI runs the benchmark correctness checks as part of the package
suite and verifies the recorded decision without rerunning the timing study.
