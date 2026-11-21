# Performance pass on numerical policy B for ProximalSolvers #515

Research code for [#515](https://github.com/mlakolar/ProximalSolvers.jl/issues/515): one bounded
performance-engineering pass on the dense `IndBallL1` least-squares policy B approved in #514.
B0 is the unmodified #514 code in `../issue-514` (arm B of `projected_policy`). No production
source, test, documentation, dependency pin or ProximalBase code changes.

| Revision | File | Change |
| --- | --- | --- |
| B0 | `../issue-514/{feasibility,stationarity,policies}.jl` | #514 prototype, baseline |
| B1 | `b1.jl` | Mechanical, bit-identical: concrete `norm2_64` maximum (Julia 1.10 inference), concrete result struct (no boxed `Union{Missing,Float64}` tuple), reuse of the accepted trial's cap decision and widened norm at the stop, `‖y‖` computed once |
| B2 | `b2.jl` | B1 plus (a) a stop-proposal pre-screen with the working-precision gradient at the stored iterate and a rounding/displacement allowance under B0's own dot-product model, and (b) one-pass Float64 design norms with B0's scaled formula as fallback |

B2 changes no feasibility test, stopping threshold, witness, fresh Float64 refresh, fixed-step
mapping, projection or status rule. A pre-screened proposal is never a success; every success
passes the unchanged B0/B1 check.

## Run

Bootstrap the pinned environment once with `bash ../issue-514/bootstrap.sh <julia root>`, then from
this directory (one Julia and one BLAS thread):

```bash
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_LOAD_PATH='@:@stdlib'
export JULIA_DEPOT_PATH="$PWD/../issue-514/depot:$HOME/.julia:"
julia --project=../issue-514/env/1.13.4 stage0.jl results/stage0 [quick]          # profile of B0
julia --project=../issue-514/env/1.13.4 [--check-bounds=yes] parity.jl results/par  # B0/B1/B2 correctness
julia --project=../issue-514/env/1.13.4 -O2 -C native bench.jl results/bench forward # paired timing
python3 summarize.py stage0|numerical|timing <results directory>
```

The Slurm scripts `stage0.sbatch`, `correctness.sbatch` and `bench.sbatch` take the absolute path of
this directory and run both Julia versions (and both bounds settings, or both warm-up orders).

- `stage0.jl`: B0 versus strict A, B0 without setup, and B0 with the full stop check only at its
  accepting iteration (ablation), plus a stage-instrumented copy of B0 (`stage0_probe.jl`) that is
  checked to reproduce B0 bit for bit. `stops.tsv` lists every full stop check.
- `parity.jl`: every #514 ℓ1 fixture and profile (ordinary, mixed, tight; PGD/APG; Float32/64) plus
  the `profile_fixtures.jl` workloads, under B0, B1 and B2 with the #514 projection audit (exact
  input/step/output digest, `prox!`/`value_and_prox!` byte parity at each call, MPFR violation of
  every accepted iterate) and the independent MPFR reference of `../issue-514/reference.jl`;
  field-by-field parity with B0; the #514 callback/injected-failure rollback probe.
- `bench.jl`: paired timing as in #514 (8 pairs per execution order per process, two processes with
  opposite warm-up orders, independent A/A on baseline replicas). End-to-end B0/B1, B0/B2 and A/B2;
  fixed work for proposals (rejected and accepted), trial decisions and setup. The statistic is
  stated in the header of `bench.jl`.

## Evidence

`data/` holds the cluster outputs with `SHA256SUMS`: `stage0-14449339` (profile, exclusive Intel
Xeon E5-2640 v4 node), `stage0-14442522` (canary), `correctness-14448857` (four Julia/bounds
configurations), `bench-14449339` (paired timing, same exclusive node as the profile), and the
`sacct` records.
