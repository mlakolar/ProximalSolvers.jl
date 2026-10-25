# Broader adaPGM evaluation: prospective decision protocol

The evaluation asks whether the benchmark-only adaPGM implementation in #88
merits an opt-in solver option. It does not change the package API. All numerical
work and package setup run under Slurm on Discovery.

## Fixed design

- Five everywhere-finite convex smooth losses: least squares, logistic, Huber,
  Poisson with log link, and **coupled** squared-plus-quartic residual loss.
  Every problem uses an l1 penalty and starts at zero. Poisson and quartic are
  only locally Lipschitz smooth; floating-point overflow is recorded as a
  numerical failure, not a domain violation or a theoretical counterexample.
- Dense n=2p design, p=100 and 500; exact singular-value construction with
  condition number of X'X equal to 1, 100 or 10,000. The logistic design is
  multiplied by two, preserving its condition number and setting the global
  gradient Lipschitz bound to one. **This is design conditioning**, not the
  Hessian condition number of a nonlinear loss or its active subproblem.
- Seeds 1--10, penalty levels 0.05 and 0.005 times the zero-solution lambda_max,
  three randomized complete timing blocks per instance. Loss data and designs
  are identical across methods. No post hoc choice of the fastest initialization.
- adaPGM initial gamma = 0.01/L0, 1/L0, 100/L0 and 10,000/L0, plus absolute
  gamma=1 when it differs from 1/L0. L0 is a generation-time Hessian bound at
  zero (a global bound for least squares/logistic/Huber only). It is used only
  to index the initialization sweep, not supplied to later adaptive steps.
  PG/APG use their existing default initialization and backtracking.
- At most 50,000 iterations and one second per fit (soft limit after an
  iteration). Failures, overflows and timeouts remain in the raw tables.

The coupled quartic is a custom scalar loss inside GLMLoss. PG and APG therefore
use the same optimized image-caching interface as the other GLMs; an extra
matrix product from a generic custom loss cannot manufacture an adaptive gain.

## Common stopping and validation

Every method checks the same external certificate every ten iterations. A fit
must satisfy **both** the l1 KKT infinity residual divided by
max(||gradient f(0)||_inf,lambda,eps) <= 1e-6 and an objective error certificate
<= 1e-6 relative to max(1,|F(x)|). Existing Fenchel dual gaps certify the four
standard losses. For coupled quartic the lower Hessian bound mu=1/kappa gives
F(x)-F* <= dist(0,subdiff F(x))²/(2mu). The certificate's objective and gradient
calls are included in time but excluded from algorithmic evaluation counts.
The expensive gap check is skipped until the KKT check is met.

A separate final calculation reconstructs the predictor, loss and gradient via
direct matrix products and scalar derivatives outside the timer. It verifies
both targets; no solver-stored residual is trusted. The public duality-gap
interface supplies the final Fenchel gap. Known orthogonal-lasso optima and
finite differences check the new harness and quartic gradient; the optimized
GLM image path is checked against direct values and gradients.

Compile every loss/method/certificate path before recorded timings. Timings
include solver workspace allocation, initialization, and scheduled certificates;
they exclude data generation, GC, compilation warmup and final validation.
Four independent single-core workers run via GNU Parallel and srun, with one
BLAS thread and non-overlapping CPU/memory requests. Each worker owns its CSV.
Report raw total allocations separately from steady-state allocation slopes
already measured in the initial experiment.

## Decision gate fixed before results

An opt-in recommendation requires at least **99% valid unit-step adaPGM fits**
within the common budget, plus at least **20% median runtime reduction against
APG in two substantive loss families**, confirmed on fresh seeds 11--15 without
retuning. Use gamma=1 (reference initialization for the four standard losses;
unit initialization for quartic) for this primary decision. Other steps expose
sensitivity and can qualify the scope, not replace a failing primary result.
PG is an additional comparator. MM is omitted from this larger campaign because
the decision concerns adaPGM versus the package's existing methods.

Keep failed fits in reliability tables and failure-aware paired comparisons;
do not base a decision only on converged pairs. When both methods hit the cap,
classify the pair as unresolved, not a speed win. If common timeouts obscure the
decision, increase only affected unit-step/APG pairs' cap in a separately
recorded confirmation, retaining the original outcomes. Confirmed gains support
an **opt-in, convex-only** method with explicit initialization and failure
semantics, not a new default, acceleration guarantee, or applicability to logdet.

## Recreate

Use the checkout's environment with the recorded ProximalBase snapshot. Run
these within a Discovery allocation (Julia 1.13.2, one Julia/BLAS thread):

```sh
julia --startup-file=no --project=. benchmark/adaptive/broad/checks.jl
julia --startup-file=no --project=. benchmark/adaptive/broad/run.jl \
  --shard 1 --shards 4 --out broad-1.csv
# Repeat shard 2,3,4 via GNU Parallel/srun in the same allocation.
```

Project run: `20261025T0800Z-ps-adapgm-broad`. Final raw data, source reference,
Slurm job records, launch commands and summaries will be retained with the
resulting decision. This protocol precedes those results.
