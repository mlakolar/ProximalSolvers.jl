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
Slurm job records, launch commands and summaries are retained with the
resulting decision. The protocol was committed as `4653b2e` before the main
results were inspected; the fixed confirmation/summary code was `3461d93`.

Fresh-seed confirmation uses the same full loss/dimension/conditioning/penalty
grid at seeds 11--15, two timing repetitions, and unit-step adaPGM plus default
PG/APG only (1,800 fits). It uses `--primary-only --seeds 11,12,13,14,15 --rounds 2`.
This avoids selecting an initialization from the main sweep for confirmation.
`check_summary.py` checks solved/failed pairing, unresolved pairs, and duplicate
row rejection with a small fixture before the scientific summaries are used.

## Result and recommendation (2026-10-25)

**Do not add a public opt-in adaPGM solver option from these measurements.**
Neither the main grid nor the fresh-seed confirmation met the prospective gate.
Keep the benchmark implementation and evidence; prefer existing APG for the
composite problems studied here. This is an empirical decision about this rule
and these workloads, not a claim that adaptive methods cannot be useful.

All **11,160 main fits** and **1,800 fresh-seed fits** were recorded, with exact
expected identity-set coverage and no duplicates. Respectively 10,172 and 1,722
met both accuracy targets; all other outcomes are retained. These are not
all-pass numerical campaigns. The focused harness checks passed 51 assertions;
summary failure-accounting and duplicate-row checks passed separately.

At absolute initial gamma=1, median paired adaPGM/APG times **among pairs where
both methods met the targets** were:

| loss | main adaPGM valid / 360 | main APG valid / 360 | main time ratio | fresh-seed time ratio |
|---|---:|---:|---:|---:|
| least squares | 360 | 360 | 1.317 | 1.169 |
| logistic | 321 | 360 | 2.708 | 2.373 |
| Huber | 330 | 354 | 1.642 | 1.190 |
| Poisson | 330 | 360 | 2.117 | 2.027 |
| coupled quartic | 360 | 360 | 1.216 | 1.212 |

Each fresh-seed family has 120 pairs. Ratios above one favor APG. Failed fits are
not erased: `primary.json` additionally reports failure-aware comparisons,
coverage and seed-cluster bootstrap intervals. In that convention an adaptive-only
success ranks as zero, a baseline-only success as infinity, and two failures
remain unresolved. These markers are rankings, not measured speed ratios. Every
loss-family failure-aware median also favors APG in both stages.

Across stages, unit-step adaPGM met the common budget/targets in **2,267/2,400**
fits (94.46%), compared with **2,388/2,400** (99.50%) for default APG. The unit-step
misses were time/iteration caps, concentrated in the small-penalty, poorly
conditioned settings. They do not prove mathematical nonconvergence. Extending
these caps was unnecessary for the decision: even fully converged pairs favored
APG, and the complete least-squares/quartic families also failed the speed gate.
No loss family supplied the required 20% broad median advantage over APG.

### Conditioning and initialization

The direction of the result changes with conditioning. At design-Gram condition
one, main-grid unit-step adaPGM/APG medians were 0.268 (least squares) and 0.773
(Huber). At condition 10,000 they were 3.800 and 3.406 among converged pairs.
The other families also became less favorable as conditioning worsened. The
orthogonal least-squares case is especially favorable to gamma=1 because that
single proximal step is its exact solution; this is not a general speed result.

Against **plain PG**, unit-step adaPGM was often useful: main both-valid medians
ranged from 0.476 to 0.718, and fresh-seed medians from 0.510 to 0.735. APG already
provides the stronger general comparison. An additional option needs a concrete
workload that benefits beyond the existing methods, not only a faster comparison
to unaccelerated PG.

Other initializations did not rescue the broad APG comparison. All 360 Poisson
runs at gamma0=10,000/L0 produced nonfinite gradients. At gamma0=100/L0, 36 Poisson
runs stopped with `invalid_step` and 30 hit the time cap. These are floating-point
failures on a mathematically globally finite loss; no line search or retry was
inserted. Initial gamma=1 did not produce those numerical failures on this grid.

The initial pilot's separable quartic, its stopping criteria and scaling differ
from this coupled, jointly certified experiment. Do not pool their time ratios
or attribute the change solely to conditioning. The broader results supersede
the pilot's suggestion to pursue an opt-in integration.

### Retained evidence and reproduction

[Evidence directory](evidence/20261025) contains all eight raw worker CSVs,
main and confirmation summaries, checked counts, and run provenance. The
analysis can be regenerated with:

```sh
python3 benchmark/adaptive/broad/check_summary.py
python3 benchmark/adaptive/broad/summarize.py \
  benchmark/adaptive/broad/evidence/20261025/main-*.csv \
  --expected 11160 --phase main --out /tmp/adapgm-main-summary
python3 benchmark/adaptive/broad/summarize.py \
  benchmark/adaptive/broad/evidence/20261025/confirmation-*.csv \
  --expected 1800 --phase confirmation --out /tmp/adapgm-confirmation-summary
```

Discovery jobs 13422390 (canary, 1m13s), 13422402 (main, 7m28s) and 13422420
(confirmation, 2m13s) all completed. Peak allocation was four CPUs and 16GB;
Julia 1.13.2 and BLAS each used one thread per worker. Total allocated running
time was 10m54s. Main source was `4653b2e`; confirmation source was `3461d93`.
The adaPGM rule engine and existing PG/APG implementations were unchanged from
the initial benchmark. Source archives, launchers and the referenced exact
package environment are in the project run registry.
