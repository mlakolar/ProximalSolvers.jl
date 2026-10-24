# Sparse and sparse-plus-low-rank IHT comparisons

This bounded benchmark addresses the remaining comparisons of
[issue #24](https://github.com/mlakolar/ProximalSolvers.jl/issues/24).
It does not rerun the already measured ProximalAlgorithms comparison:
[PR #53](https://github.com/mlakolar/ProximalSolvers.jl/pull/53) and
[PR #50](https://github.com/mlakolar/ProximalSolvers.jl/pull/50) record those
Discovery measurements and their adverse findings, including LiLin's failed
fallback and different nonconvex local minima.

`legacy.jl` calls the original CovarianceSelection routines at the issue's
frozen revision `edba5de`. It measures all three routines: plain D-trace IHT,
latent D-trace IHT and latent log-det IHT. A recorded fixed-step grid
`0.05, 0.2, 0.5`, scaled by the relevant curvature, provides a bounded tuning
comparison. Every grid result remains visible, including exceptions and
nonfinite objectives. The legacy routines are not rewritten in this harness.

The legacy preparation process saves its exact initializers as plain arrays.
The native process receives those same points and minimizes the same smooth
objectives, using a symmetric sparse block and, for a latent model, a second
factor block `U`. It compares plain proximal gradient, normalized proximal
gradient and monotone APG. A separate centered sparse-regression case also
compares normalized steps with support debiasing. The native coupled losses
are self-contained benchmark fixtures, with a Cholesky check before every
log-det inverse. They are not new estimator APIs.

Both runners compile each method/problem shape before timing. Native method
order reverses between repetitions. Legacy and native runners are separate
processes; their timing blocks are not interleaved across packages. These
small timings alone must not be presented as an exhaustive speed comparison.
The default dimensions are `10,20`, rank `2`, two repetitions and at most
1,000 iterations. Native solves additionally have a 30-second soft limit.

`native_vs_legacy.tsv` compares every returned native solution with the best
finite, feasible legacy objective over the recorded fixed-step grid. Reference
selection checks symmetry, the sparse support budget, factor dimensions and
positive definiteness where the log-det objective requires it. Ineligible
legacy solutions remain in `legacy_reference_rejections.tsv`; a missing valid
reference produces an explicit unavailable row. It records both objective and
support agreement; failures and support differences are not repaired or
discarded. Raw solver and warmup failures remain in the runners' TSV files.
The new exact symmetric projection can select a different support
from the legacy magnitude threshold when diagonal entries are constrained.
These are nonconvex local solutions, so neither objective ordering nor matching
supports is a universal guarantee. `legacy.tsv` and `native.tsv` also retain
the maximum objective increase, finite-trace status and final positive
definiteness. Inspect these fields before making a monotonicity claim.

## Measured legacy comparisons

Discovery job `13377697` ran the primary comparisons with source
`bcc109d1b3a214430da3f992c89eda001db9cab9`, CovarianceSelection
`edba5de674855c53fb58f55566028447974c5b1a`, and the recorded ProximalBase
snapshot. Job `13378012` used source
`e424ac5fc8e422b50d38ef9cdf238db322d4ba0f` to validate saved legacy
references and summarize the saved solutions without refitting these models.
The run record is `20261024T1358Z-ps-issue24`; its raw files include
`legacy.tsv`, `native.tsv`, `native_vs_legacy.tsv` and
`legacy_reference_rejections.tsv`.

All 72 legacy/native measurements returned finite, feasible final solutions
and finite, nonincreasing objective traces (maximum recorded increase `0.0`).
The 36 native comparisons all achieved a lower objective than the best
feasible legacy result on the recorded step grid. The table copies final
objectives from the Discovery summary; the two repetitions produced the same
objective for each native method.

| Problem | p | Best tuned legacy | PG | Normalized PG | Monotone APG |
| --- | ---: | ---: | ---: | ---: | ---: |
| D-trace | 10 | -0.9769461998454068 | -1.0099250833695956 | -1.009925083391762 | -1.0099250833883955 |
| D-trace | 20 | -1.46524567699919 | -1.5982989041839852 | -1.59829890417034 | -1.5984986705725626 |
| Latent D-trace | 10 | -1.2063557551119475 | -1.2559737266012712 | -1.25597373269155 | -1.2459877471448395 |
| Latent D-trace | 20 | -1.8415077319766637 | -1.9164684815954574 | -1.9815588001290876 | -1.9157594810973309 |
| Latent log-det | 10 | 4.667618611571708 | 4.616098919342116 | 4.602665475664798 | 4.626229795120744 |
| Latent log-det | 20 | 10.899170264366758 | 10.757315328034064 | 10.757315311128721 | 10.763074604842943 |

The same-support criterion failed: none of the 36 native comparisons matched
the best legacy reference's sparse support. Exact symmetric projection and
different nonconvex local minima preclude claiming universal equivalence to
the legacy routines. Lower final objectives in these cases do not establish
global optimality. For latent D-trace at `p=20`, all three native methods hit
the 1,000-iteration limit with `converged=false`. For latent log-det at `p=10`,
PG and monotone APG also hit that limit. Their entries are truncated feasible
iterates, not converged solutions. The other native entries report
`converged=true` in `native.tsv`.

These measurements support the stated feasibility and objective-trace checks.
They do not establish an overall timing advantage for latent models. The
bounded runs use separate process timing blocks, and iteration limits and
different attained local solutions prevent an equal-accuracy speed claim.

### Sparse least squares against MendelIHT

The centered `n=200, p=400, s=5` case recovered the planted support in every
returned run. All six method/configuration pairs agreed in residual objective
to within `2e-13`. Median seconds over two repetitions were:

| method | seconds |
|---|---:|
| PG | 0.0003747335 |
| Normalized PG | 0.000658416 |
| Monotone APG | 0.000721920 |
| Normalized PG with debiasing | 0.0003177265 |
| MendelIHT, default memory mode, no debiasing | 0.0014670335 |
| MendelIHT, dense memory mode, debiasing | 0.000700104 |

MendelIHT 1.4.11 was run on the same saved arrays and sparsity. Its two
configurations passed after the debiasing branch received its required
`memory_efficient=false` setting. Job **13378106**, source `a131cd1`, warmed
both configurations before timing and recomputed the summary. Native timings
come from job **13377697**, source `bcc109d`, and the feasibility-aware
comparison was rerun in job **13378012**, source `e424ac5`. The final tables
retain the earlier configuration and warmup failures separately. This is one
small regression problem with separate process timing blocks, rather than a
general speed claim. In particular, monotone APG was slightly slower than the
debiased MendelIHT configuration here.

## Discovery recipe

All setup, data generation, execution and summarization run under Slurm.
Bind the legacy environment to CovarianceSelection `edba5de`, the native
environment to the new ProximalSolvers checkout, and both to the recorded
ProximalBase snapshot. The benchmark environment requires ProximalBase 0.5.3
or later. Separate processes exchange only plain arrays serialized by the same
Julia version.

```sh
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/depot:"
JULIA=/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia
SOURCE=/absolute/path/to/new/source
OUT=/absolute/path/to/run/results
# Each command below runs in the Slurm allocation.
srun --exclusive --exact -N1 -n1 -c1 "$JULIA" --startup-file=no \
  --project=/absolute/path/to/legacy-env \
  "$SOURCE/benchmark/nonconvex/legacy.jl" --root "$OUT" --prepare --sizes 10,20
srun --exclusive --exact -N1 -n1 -c1 "$JULIA" --startup-file=no \
  --project=/absolute/path/to/legacy-env \
  "$SOURCE/benchmark/nonconvex/legacy.jl" --root "$OUT" --rounds 2
srun --exclusive --exact -N1 -n1 -c1 "$JULIA" --startup-file=no \
  --project=/absolute/path/to/native-env \
  "$SOURCE/benchmark/nonconvex/native.jl" --root "$OUT" --rounds 2
srun --exclusive --exact -N1 -n1 -c1 "$JULIA" --startup-file=no \
  "$SOURCE/benchmark/nonconvex/compare.jl" --root "$OUT"
```

`mendel.jl` is an optional reference runner in the separate `mendel/`
environment. Its API follows the
[official MendelIHT source](https://github.com/OpenMendel/MendelIHT.jl/blob/master/src/fit.jl).
It uses the same centered regression arrays, sparsity and initial-zero option,
with and without MendelIHT debiasing. Both branches warm before timing, and a
failed warmup is recorded explicitly. MendelIHT 1.4.11 requires
`memory_efficient=false` for debiasing; the adapter uses this setting for the
debiased branch and retains the default `true` for the other branch. Earlier
Discovery runs with both branches using the default recorded the debiasing
error, "Currently debiasing only works with memory_efficient=false". Those
failed rows remain part of the run record. The implicit intercept has its optimum
at zero on these centered inputs. Returned coefficients are checked through
their residual objective and support, rather than comparing likelihood
normalizations. A missing package or adapter failure remains an explicit
unavailable/error row; it is not a successful comparison. Dependency setup
belongs inside Slurm and may be omitted when it exceeds the run's budget.

```sh
srun --exclusive --exact -N1 -n1 -c1 "$JULIA" --startup-file=no \
  --project="$SOURCE/benchmark/nonconvex/mendel" \
  "$SOURCE/benchmark/nonconvex/mendel.jl" --root "$OUT" --rounds 2
```

Retain the raw TSVs, support/solution records, source revisions and Slurm
output. The primary legacy and corrected-memory-mode MendelIHT comparisons above
have been inspected. `nonconvex-summary*.csv` and the raw TSVs retain the
per-configuration outcomes and earlier failed rows.
