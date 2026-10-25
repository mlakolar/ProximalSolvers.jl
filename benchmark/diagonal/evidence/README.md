# Discovery results, 26 October 2026 (Dubai)

The default `:none` shows no runtime regression in these workloads: its paired
median runtime is 0.965–0.987 times the baseline. Every paired run has exactly
the same coefficients, objective, gap, iterations, and backtracking counts.
There are ten repetitions per case/solver/mode, 180 timing rows total.

On scaled least-squares and logistic designs, diagonal PGD reaches the
relative-gap target in 560–590 iterations; diagonal APG takes 90–100. All
scalar runs stop at 6000 iterations with gaps between 0.471 and 0.976, compared
with at most 1e-5 for the diagonal solves. The diagonal runs use 1.6–9.9% of
the capped scalar runtime. This establishes a gain on these scaled cases,
but does not measure scalar time to the target.

The well-scaled APG case is adverse evidence: diagonal preconditioning costs
about 13% more (1.230 ms versus 1.090 ms), with 100 versus 90 iterations.
Preconditioning is optional and is not uniformly faster. Well-scaled PGD
is about 9% faster (5.786 ms versus 6.339 ms).

| Case | Solver | none / baseline median [Q1, Q3] | Diagonal / scalar median | Diagonal iterations | Scalar iterations | Scalar gap |
|---|---|---:|---:|---:|---:|---:|
| ls-well | pgd | 0.979 [0.955, 1.003] | 0.9123 | 540 | 600 | 9.77e-06 |
| ls-well | apg | 0.979 [0.960, 0.987] | 1.1297 | 100 | 90 | 5.64e-06 |
| ls-scaled | pgd | 0.965 [0.958, 0.976] | 0.0947 | 560 | 6000 | 0.976 |
| ls-scaled | apg | 0.970 [0.958, 0.980] | 0.0190 | 100 | 6000 | 0.719 |
| logistic-scaled | pgd | 0.984 [0.978, 0.986] | 0.0986 | 590 | 6000 | 0.94 |
| logistic-scaled | apg | 0.987 [0.982, 0.993] | 0.0162 | 90 | 6000 | 0.471 |

Scaled scalar runs at the iteration cap are lower bounds on time to the requested gap, not equal-accuracy speedups.

## Provenance and checks

- Solver source: `d2ef6d79e50d040402340654dd0dca0afdfa23c9`.
- Baseline: `531ff55fcf8a5ce2c6997c144d4f57e85cf79f3e`.
- ProximalBase: `b6c949f3dd26cad09252e1c2c9e49810eb69403e`, shared by both versions.
- Corrected harness: `343315e1b3eb4586ecb2cdbc43a1ed582f585de5`; solver sources unchanged.
- Julia 1.13.2, one Julia/BLAS thread per worker, EPYC 7513 node `a01-04`.
- Account `mkolar_1314`, partition `main`, allocation 3 CPUs / 12 GB.
- Job 13446683 completed in 67 seconds; all 180 measurements passed.
- Job 13446442 ran all 37 test files successfully, including 227 diagonal
  regression assertions and 11 Aqua checks. Its batch exit was 1 because the
  first benchmark harness tried to serialize the function returned by `include`.
  It produced no timings. The corrected benchmark reused the completed tests.
- Full test log, both batch logs, raw timings, and accounting are kept beside
  this report. The harness failure is retained in `failed-harness-13446442.log`.

Timings include metric construction and ordinary solve initialization, excluding
compilation and explicit pre-call GC. Both worker processes remain loaded, with
measurements run sequentially in alternating order. Designs and penalties are
described in the parent README. The fixed seed is 92026.

To reproduce, stage the pinned sources and run `discovery.sbatch` from the run
root; the recorded recovery command was:

```sh
sbatch --parsable --export=ALL,PS92_SKIP_TESTS=1,PS92_HARNESS=harness-v2 harness-v2/discovery.sbatch
python3 benchmark/diagonal/summarize.py benchmark/diagonal/evidence/discovery-20261026.csv
```
