# PANOCplus benchmark prototype (issue #25)

This directory contains a benchmark-only, dense real-array implementation of
PANOCplus. It adds no runtime dependency or public solver. The independent
adaptive-rule experiment is in `../adaptive`.

The method follows [De Marchi and Themelis (2022), Algorithm 2](https://aldma.github.io/bib/demarchi2022proximal_arxiv.pdf):
the forward--backward envelope uses the current proximal step, the smoothness
check uses alpha=0.95, and the merit-decrease threshold uses the previous
accepted step. A failed smoothness check halves gamma and restarts the direction
search. L-BFGS uses five pairs in preallocated circular buffers, resets after
gamma changes, and caps the direction norm at 10,000 times the residual norm.
The two-loop recursion has no history-sized allocations inside the iterations.
Curvature pairs with insufficient positive curvature are skipped. The default
initial step is 1; each path level starts fresh memory and step state.

For `LogDetLoss`, both the quasi-Newton trial and its proximal point must have
finite loss and gradient. Infeasible trials reduce the direction step; infeasible
proximal points reduce gamma. After 31 unsuccessful direction backtracks the
trial is the proximal-gradient fallback. A failed merit test is never accepted
just because a retry cap is reached. Retry caps return failure. This is an
experimental extension to a domain-restricted loss: the paper assumes a finite
smooth loss on all of Euclidean space. Passing these tests is no general proof
of convergence for an extended-real smooth term.

## Comparison

The common objective is `tr(S*X)-logdet(X)+lambda*sum(abs,X_offdiag)`.
The sample covariance uses `n=2p` Gaussian observations and a banded precision,
with seeds 25 and 71. We compare cold starts at each lambda and primal warm
starts along lambda = 0.2, 0.12, 0.08. Every solver has its own path. A failed
level stops that solver's warm path; it is never used as a successful warm start.
Three repetitions reverse solver order on the second round.

APG and PANOCplus check the same cached package duality-gap certificate every
10 iterations; the returned point is independently checked using direct
Cholesky factors, an explicit inverse, and the clipped dual point. QUIC uses its
native gap check and the same independent final validator. All must attain
relative gap <= 1e-6. Times include solver setup and scheduled certificates,
but exclude data construction, GC, compilation warmup and independent final
validation. QUIC reports coordinate passes in the iterations column; these
are not comparable to first-order iteration counts. QUIC has a 200-Newton-step
cap; the 10-second limit is a soft per-fit cap on the first-order methods.
Failures and attained accuracies stay in the raw CSV. These are common-target
comparisons, not identical attained accuracies or evidence for all graph classes.

`f_calls`, `grad_calls` and `prox_calls` count algorithmic calls only and exclude
the external certificate. -1 means unavailable. `domain_rejections` counts
nonfinite loss/gradient trials in PANOCplus. The baseline's `step_shrinks` field
contains its existing backtracking counter (trial evaluations), so it should not
be compared directly with PANOCplus's number of halvings.

`total_bytes` includes setup and certificate allocations. `allocations.jl`
separately estimates incremental bytes per iteration by differencing fixed
20- and 120-iteration runs, without certificates, on convex least squares.
The script retains actual counts and returns NaN if either count is truncated.
This slope is not total memory, and the L-BFGS workspace scales as O(p²*m) for
matrix iterates. The experiment measures dense Float64 performance; the focused
checks also cover a small Float32 problem.

## Recreate

Run all Julia commands in a Slurm allocation, with one Julia and BLAS thread.
Bind ProximalBase to the recorded snapshot in the checkout's environment before
running; no benchmark-only external package is needed.

```sh
julia --startup-file=no --project=. benchmark/panocplus/checks.jl
julia --startup-file=no --project=. benchmark/panocplus/run.jl \
  --sizes 50,200,600 --rounds 3 --limit 10 --out panocplus.csv
julia --startup-file=no --project=. benchmark/adaptive/run.jl \
  --sizes 50,200,600 --rounds 3 --limit 10 --out adaptive.csv
julia --startup-file=no --project=. benchmark/panocplus/allocations.jl --out allocations.csv
python3 benchmark/panocplus/summarize.py panocplus.csv adaptive.csv --out summary
```

Run identity: `20261025T0730Z-ps-issue25`, Discovery EPYC 7513, Julia 1.13.2,
ProximalSolvers base `1c29626`, ProximalBase `3857c3d`. The lightweight project
registry preserves exact source snapshots, launcher, scheduler IDs and outcomes.
