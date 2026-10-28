# CoordinateDescent comparison suite

[coordinatedescent/](coordinatedescent/) is a regression monitor comparing
CoordinateDescent 0.6.1 (`legacy`) with HighDimensionalModels on ProximalSolvers
(`current`) through their public APIs, at matched certified accuracy. It reuses
the input generators, certificates and record format of the
[#116 harness](../README.md).

The primary measurement is compiled public-API latency, including model
construction, initialization and result conversion inside the call. It measures
the whole package stack. It does not isolate ProximalSolvers or its coordinate
kernel, include compilation or input generation, or measure statistical quality.
Julia heap bytes accompany timings; native allocations are not measured per
case. Peak RSS describes the whole Julia process. For the quadratic cases,
preparing `A = X'X/n` and `b = -X'y/n` is outside timing; there is no separate
Gram-construction timing record in this suite.

## Locked environments

Both lockfiles require Julia 1.13.3. Python tools require Python 3.11 or later
and use only the standard library.

| Arm | Locked packages and source |
|---|---|
| `legacy` | CoordinateDescent 0.6.1, ProximalBase 0.4.1. |
| `current` | HighDimensionalModels 0.1.0 at `047c4193764b4171c659f4c649bbee8bf1df65fb`, ProximalBase 0.5.4, ProximalSolvers 0.2.0 from this checkout. |
| `current-AA` | A separate environment with byte-identical copies of current's project and manifest, using the same checkout. |

The two package stacks require different versions of ProximalBase (0.4 and 0.5),
so they cannot share a Julia process. Every arm uses a fresh process.

These lockfiles are those of the 2026-10-28 campaign, at ProximalSolvers 0.2.0.
The pinned HighDimensionalModels revision requires ProximalSolvers 0.2, so the
current environment does not instantiate against ProximalSolvers 0.3 or later.
A new campaign against a later ProximalSolvers first resolves a new `current`
manifest with a HighDimensionalModels revision that admits it, checks the
adapters against that revision with the fixtures, and commits the new lock;
`setup.jl` only reproduces a committed lock.

`setup.jl SIDE HDM_REV OUTDIR` creates an environment by copying the checked-in
project and manifest, then instantiating without a new resolution. It checks
package versions and refuses a manifest changed by instantiation. For current,
`HDM_REV` must equal the full commit in the locked manifest; it does not select
an arbitrary revision. The manifest also pins the repository tree hash. The
runner verifies the loaded repository tree and records the revision, tree hash,
package source hashes and manifest SHA-256 in its metadata.

Current's source path is `../../../..`. A current environment elsewhere can
rebase that path without changing dependency versions. The A/A setup requires
the original relative depth, so the commands below place all environment copies
at that depth. Keep the checkout and lockfiles fixed throughout a campaign.

## Input artifact

`inputs.jl` writes package-neutral, little-endian, column-major Float64 arrays
and Int64 group arrays, with a TOML manifest. Every raw file has its shape, type
and SHA-256 recorded. Readers verify all checksums. Process metadata records the
manifest SHA-256. The artifact also records generator and catalog hashes,
explicit penalty levels, zero starting points, data seeds and solver seeds.
It uses `benchmark/problems.jl:lasso_design`, repetition 1, for every block.

| Design | n × p | Nonzero coefficients | Design correlation | Suite |
|---|---:|---:|---|---|
| A | 500 × 2500 | 50 | Independent | quick |
| B | 500 × 2500 | 50 | AR(1), 0.8 | quick |
| C | 5000 × 500 | 50 | AR(1), 0.5 | quick |
| E | 500 × 2500 | 50 | Equicorrelated, 0.5 | quick |
| D | 1000 × 20000 | 20 | Independent | extended only |

The generator scales each column to squared norm `n`; adapters disable further
standardization and intercepts. Define `λmax = ‖X'y‖∞/n`. Every single-penalty
case uses `0.1 λmax` or `0.02 λmax`, including the square-root and iterative
estimators. Each design has an explicit 50-level logarithmic path from `λmax`
to `0.01 λmax`. Paths use warm starts, screening and `max_hat_s = Inf`.

Groups are contiguous blocks of five columns with unit group weights. Fixed
weighted-lasso loadings are `Γⱼ = sqrt(Σᵢ Xᵢⱼ² yᵢ²/n)`. Other fixed coordinate
weights, including scaled-lasso weights, are one. Feasible lasso recomputes
loadings from residuals. Solver seeds are separate from data seeds and reset
outside each timed call. Random coordinate orders remain comparable workloads;
identical coordinate sequences are not guaranteed after stopping or active sets
diverge.

## Cases and views

[catalog.toml](coordinatedescent/catalog.toml) defines every case and all options
passed to each API. IDs have the form `estimator/design/λspec/order`. All cases
have cyclic and random variants.

| Estimators | Quick designs | Extended additions |
|---|---|---|
| `lasso`, `weighted_lasso`, `path` | A, B, C, E | D |
| `quadratic` | A, B, C, E | None |
| `group_lasso`, `sqrt_lasso`, `scaled_lasso`, `feasible_lasso` | A, C | None |

| Runner view | Settings and use |
|---|---|
| `defaults` | Public default stopping options for the fixed objective and coordinate order; setting index 0. Completed timings remain visible even when accuracy is insufficient. |
| `ladder` | Calibration evaluates every coordinate/inner rung and any current gap rungs. |
| `frozen` | Confirmation evaluates the union of indices in `selection.toml`; current-AA uses current's selections. |

The coordinate and inner grid has nine rungs:
`1e-4, 3e-5, 1e-5, 3e-6, 1e-6, 3e-7, 1e-7, 3e-8, 1e-8`.
Legacy uses scaled coordinate change (`optTol`); current's coordinate ladder uses
`opt_tol` with `gaptol = 0`. Square-root and scaled lasso sweep the inner
coordinate tolerance; current's gap check is a final check, not their inner
stopping rule. Feasible lasso sweeps both loading-change and inner tolerances.
The catalog records iteration caps and initialization for nested estimators.

Current additionally has five gap rungs, `1e-4, 3e-5, 1e-5, 3e-6, 1e-6`, for
lasso, weighted lasso, group lasso and residual-based paths. Gap rungs follow the
nine coordinate rungs in the setting indices. Quadratic models have no gap
stopping. Current's public automatic Gram policy remains enabled: dense paths
use Gram storage when `n ≥ p` and `p ≤ 2000`, including design C, whose path
therefore uses coordinate stopping and has no gap ladder. Residual paths keep
the public default gap tolerance `1e-4` in the defaults view.

`--gram-off` labels a separate current-only control. It accepts selected lasso,
weighted-lasso, path or square-root-lasso cases with a public Gram keyword.
Keep controls separate from the primary campaign. Automatic Gram formation
inside a public call is included in that call's timing.

## Objectives and API mapping

Write `r = y - Xβ`, `L(β) = ‖r‖²/(2n)` and
`Sω(β) = Σⱼ ωⱼ|βⱼ|`. All coefficients are on the original column scale.

| Estimator | Objective or measure | Public API mapping |
|---|---|---|
| Lasso | `L(β) + λ‖β‖₁` | `lasso` on both sides, coefficients from `.x`. |
| Fixed weighted lasso | `L(β) + λSΓ(β)` | Explicit-loading `lasso` overload on both sides. |
| Path | Lasso at every artifact level | `LassoPath` on both sides; all returned levels are archived. |
| Quadratic L1 | `β'Aβ/2 + b'β + λ‖β‖₁` | `CDQuadraticLoss` and `coordinateDescent!` / `coordinate_descent!`; the certificate restores the omitted constant `y'y/(2n)`. |
| Group lasso | `L(β) + λΣg ‖βg‖₂` | Legacy uses `AtomIterate`, `ProxGroupL2` and `coordinateDescent!`; current uses `group_lasso` with `standardize=:none` and explicit unit `groupweights`. |
| Square-root lasso | `‖r‖/√n + λ‖β‖₁` | `sqrtLasso` / `sqrt_lasso` use unnormalized `‖r‖`, so both receive `λ_api = √n λ`. |
| Scaled lasso | `‖r‖²/(2nσ) + σ/2 + λSω(β)`, profiled over `σ > 0` | `scaledLasso` / `scaled_lasso` handle the square-root scaling internally. Certification uses the profiled objective `‖r‖/√n + λSω(β)`; residual scale is `σ = ‖r‖/√n`, penalty level `λσ`. |
| Feasible lasso | Residual-loading self-consistency | `feasibleLasso!` / `feasible_lasso!`; the returned penalty is ignored because the APIs return loadings from different stages. |

## Certificates and statuses

The sole matched target is a certified value at most `1e-4`. For convex
objectives the value is the relative duality gap
`max(P-D, 0)/max(abs(P), floatmin(Float64))`, with a feasible dual point and
domain, finiteness and weak-duality checks. Paths require exactly the requested
grid and use the largest gap over all 50 levels. Stopping diagnostics do not
substitute for certificates.

Feasible lasso uses `Γⱼ(β) = sqrt(Σᵢ Xᵢⱼ² rᵢ²/n)` and reports the weighted-lasso
gap at those residual loadings as its primary `self_consistency` value. This
is not a convex optimality certificate for the entire iterative estimator.
A bounded independent fixed-loading refit, tolerance `1e-10` and at most 32
passes, supplies only the secondary relative loadings change. If it fails to
certify, that secondary diagnostic is unavailable; the primary gap remains
usable. Both Julia and the Python cross-check reject an interpolating feasible
fit when `‖r‖ ≤ 1e-8‖y‖`, before computing residual loadings.

Square-root and scaled-lasso certificates reject residual norms at or below
`1e-12`. Near-interpolation cases can reach no rung or remain uncertifiable.
They remain in the reports, with unavailable matched ratios and explicit
exclusion counts in groups. Bitwise-identical returned coefficients reuse one
certificate per rung, including validation and timed samples. Certification and
the bounded refit are outside sample timing.

| Record status | Meaning |
|---|---|
| `ok` | Valid certificate and any finite record target met. |
| `target_missed` | Valid certificate exceeds a finite record target. |
| `incomplete` | Returned path differs from the complete requested grid. |
| `uncertifiable` | Invalid domain, nonfinite value or invalid certificate. |
| `error` | Input preparation, solve or certification raises an exception. |
| `timeout` | A compiled recheck or timed call exceeds the wall-time cap, assessed after it returns. |

Production records have target `NaN`: they record achieved accuracy, so `ok`
alone does not mean the matched target is reached. Analysis applies `1e-4`
separately. Fixture targets are `1e-10` for convex gaps and `1e-8` for feasible
self-consistency; fixtures also check the secondary loading change when
available. The first validation call includes compilation and is exempt from
the time cap. A compiled recheck follows if that call exceeds the cap.

Support uses `|βⱼ| > 1e-4 max|β|` at each level. Differences count the symmetric
difference against current's tightest calibration rung, only when that rung
certifies to at most `1e-6` in every calibration process. Support agreement is a
diagnostic. Without a loaded calibration reference, including separate defaults
or confirmation roots, reference differences are unavailable.

## Calibration and confirmation

Calibration uses one block of legacy and current. A/A is optional in calibration
and never affects selection. For each case, selection chooses the cheapest rung
that meets `1e-4` in every process and timed sample. Cost is the mean of process
medians; exact ties favor the smaller setting index. Every rung's time, achieved
accuracy, overshoot (`target/worst_value`) and status remain in `rungs.csv`.
No qualifying rung produces a `not reached` entry in `selection.toml`.

The primary matched view compares the coordinate-family selections on both
sides. The secondary matched view compares legacy's same selection with
current's best qualifying rung across coordinate and gap families. Freeze the
selection before confirmation; confirmation timing does not select settings.
Shared selected rungs run once per process.

Confirmation uses 12 blocks of legacy, current and current-AA. Each of the six
arm orders appears twice. Each block has a fresh ladder or frozen-view process
per arm under `arms/<side>/bNN/`, plus a fresh defaults-view process per arm
under `defaults/<side>/bNN/`. Use sequential execution, one core, one Julia
thread and one BLAS thread, with fixed hardware conditions. Long runs belong
on dedicated hardware. Defaults and matched results use separate roots.

For each case and block, analysis takes the median timed latency in each process
and forms `log(current/legacy)`. The estimate and 95% Student-t interval use the
mean over blocks, then exponentiate to the ratio scale. Groups use equal-weight
case log ratios and a whole-block bootstrap with 10,000 resamples and seed 117.
Groups list ineligible cases rather than silently dropping them.

The A/A arm has current's source, settings and seeds. Its same-rung observations
set `δ = max(log(1.05), q)`, where `q` is an upper 95% confidence bound for the
95th percentile of `|log(current/current-AA)|`. This pooled order-statistic
bound assumes independent, identically distributed observations; dependence
between cases within blocks limits its nominal coverage. Fewer than 59 A/A
observations gives an infinite bound and prevents flags. Primary, secondary
and defaults views have separate noise floors and inference families.

An interval wholly above `δ` identifies a candidate regression. One-sided
tests against `δ` undergo Benjamini–Hochberg screening at 10% across all
estimable cases within each view. A screened candidate becomes a confirmed
regression only when an independent rerun on fresh processes and a fresh
allocation reproduces it, before filing an issue. Analysis does not perform
that rerun or label a result confirmed. An interval overlapping the noise band
`[-δ, δ]` is inconclusive, not a tie. One calibration block provides no
between-block interval.

## Setup and fixtures

Run commands from the package root. Here `python3` denotes Python 3.11 or later
and `julia` denotes Julia 1.13.3. Output directories are fresh. The environment
copies below have the relative depth required by the A/A lockfiles.

```sh
suite=benchmark/external/coordinatedescent
envs="$PWD/benchmark/external/results"
artifact=/absolute/path/to/artifacts/quick
tiny=/absolute/path/to/artifacts/tiny
calibration=/absolute/path/to/results/calibration
confirmation=/absolute/path/to/results/confirmation
hdm_rev=$(python3 -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1],"rb"))["deps"]["HighDimensionalModels"][0]["repo-rev"])' "$suite/current/Manifest.toml")

julia "$suite/setup.jl" legacy "$hdm_rev" "$envs/env-legacy"
julia "$suite/setup.jl" current "$hdm_rev" "$envs/env-current"
julia "$suite/setup.jl" current-AA "$hdm_rev" "$envs/env-current-AA"
cmp "$envs/env-current/Project.toml" "$envs/env-current-AA/Project.toml"
cmp "$envs/env-current/Manifest.toml" "$envs/env-current-AA/Manifest.toml"

julia "$suite/inputs.jl" "$artifact" --suite quick
julia "$suite/inputs.jl" "$tiny" --suite quick --tiny

for side in legacy current; do
  JULIA_NUM_THREADS=1 julia --project="$envs/env-$side" "$suite/run.jl" \
    "$side" "$tiny" "/absolute/path/to/fixtures/$side" 1 --fixtures
done
```

Fixture mode writes `fixtures.tsv`, `fixtures.toml` and coefficient archives;
it does not sample timings. Its exit code is 2 for numerical failures. Check
fixture outcomes before using production results. For the extended suite,
generate a separate artifact with `--suite extended` and pass `--suite extended`
to every corresponding runner call.

## Run the blocks

Listing needs no package load or artifact read. The runner accepts `--list`,
not `--help`; the Python analysis and cross-check accept `--help`.

```sh
julia "$suite/run.jl" current "$artifact" /absolute/path/to/unused 1 \
  --view ladder --cases lasso/A/0.1lmax/cyclic --list
```

This helper runs one arm and view in a fresh process. It preserves complete
non-`ok` records (exit 2); startup or record-writing failure (exit 3) stops it.
The runner sets one BLAS thread. Set CPU affinity to one core using the
execution environment's controls.

```sh
run_process() {
  process_root=$1
  process_side=$2
  process_block=$3
  process_view=$4
  shift 4
  process_folder=$(printf '%s/%s/b%02d' "$process_root" "$process_side" "$process_block")
  if JULIA_NUM_THREADS=1 julia --project="$envs/env-$process_side" "$suite/run.jl" \
      "$process_side" "$artifact" "$process_folder" "$process_block" \
      --view "$process_view" "$@"; then
    return 0
  else
    process_code=$?
    [ "$process_code" -eq 2 ] || return "$process_code"
  fi
}

for side in legacy current; do
  run_process "$calibration/arms" "$side" 1 ladder || exit $?
  run_process "$calibration/defaults" "$side" 1 defaults || exit $?
done

python3 "$suite/analysis.py" "$calibration/arms" "$calibration/selection" \
  --blocks 1 --select
python3 "$suite/analysis.py" "$calibration/defaults" "$calibration/defaults-report" \
  --blocks 1 --select
selection="$calibration/selection/selection.toml"

for block in $(seq 1 12); do
  case "$(((block - 1) % 6))" in
    0) set -- legacy current current-AA ;;
    1) set -- legacy current-AA current ;;
    2) set -- current legacy current-AA ;;
    3) set -- current current-AA legacy ;;
    4) set -- current-AA legacy current ;;
    5) set -- current-AA current legacy ;;
  esac
  for side do
    run_process "$confirmation/arms" "$side" "$block" frozen --frozen "$selection" || exit $?
    run_process "$confirmation/defaults" "$side" "$block" defaults || exit $?
  done
done
```

`PS_SAMPLES` defaults to 50 for quick and 100 for extended; `PS_SECONDS` defaults
to 1 and 3 accumulated timed seconds respectively. Sampling uses at least five
calls unless an error or timeout stops the case. `PS_CASE_SECONDS` defaults to
120 per call; it is checked after return, not a preemptive interruption.
`--cases ID,...` (or `PS_CASES`) restricts the catalog. `--target` accepts only
`1e-4`. Keep selections, suites, sample limits and time caps consistent across
all corresponding processes.

## Validate and analyze

The shared validator directly checks a first-block folder:

```sh
python3 benchmark/validate.py "$calibration/arms/legacy/b01" \
  "$calibration/legacy-b01-validation.json" --expected-runs 1
```

It expects contiguous repetitions from 1 and supports at most 10, so it cannot
directly check an isolated later block. For any single `bNN` folder, use the
suite's metadata and table checks below. Repeat for every arm, block and root;
fixture folders use their own fixture outputs instead.

```sh
python3 - "$suite" "$confirmation/arms/current/b12" <<'PY'
from pathlib import Path
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
import analysis
folder = Path(sys.argv[2])
finals = list(folder.glob("*-metadata.toml"))
assert len(finals) == 1, "expected one finished process"
final = finals[0]
prefix = final.name.removesuffix("-metadata.toml")
match = analysis.base_validate.PREFIX.fullmatch(prefix)
assert match is not None, "invalid process prefix"
meta = analysis.base_validate.metadata(final)
start = analysis.base_validate.metadata(folder / (prefix + "-metadata-start.toml"))
analysis.base_validate.check_metadata(meta, match[1], int(match[2]))
analysis.base_validate.check_metadata(start, match[1], int(match[2]), final=False)
assert all(start.get(k) == v for k, v in meta.items()
           if k not in analysis.base_validate.FINAL_KEYS), "start/final mismatch"
tables = {kind: analysis.read_table(folder / (prefix + f"-{kind}.tsv"), kind, meta)
          for kind in analysis.base_validate.HEADERS}
analysis.check_tables(tables, meta)
print("VALID", folder)
PY

python3 "$suite/analysis.py" "$confirmation/arms" "$confirmation/matched-report" \
  --blocks 12 --selection "$selection"
python3 "$suite/analysis.py" "$confirmation/defaults" "$confirmation/defaults-report" \
  --blocks 12

python3 -I "$suite/crosscheck.py" "$artifact" "$calibration/arms" --arms legacy,current
python3 -I "$suite/crosscheck.py" "$artifact" "$calibration/defaults" --arms legacy,current
python3 -I "$suite/crosscheck.py" "$artifact" "$confirmation/arms" --arms legacy,current,current-AA
python3 -I "$suite/crosscheck.py" "$artifact" "$confirmation/defaults" --arms legacy,current,current-AA
python3 "$suite/check_analysis.py"
```

Analysis recursively reads each root's arm folders and checks complete block
coverage, matched inputs, fixed settings, package identities and current/A/A
identity. Confirmation requires all three arms and the exact frozen selection
for matched records. Calibration allows two arms via `--select`, also for its
defaults root; that defaults-only invocation has no ladder selection to make.

The independent Python cross-check verifies input and coefficient checksums and
recomputes every archived primary certificate. `--arms` selects a comma-separated
subset; without it all three arms are required. It uses relative agreement
tolerance `1e-6` or absolute tolerance `1e-12`. The archive contains the final
sample only: a comparison with recorded `worst_value` can disagree if another
sample attains the worst value. Such discrepancies are reported. The cross-check
does not recompute the secondary feasible-lasso loading change.
`check_analysis.py` checks inference and integrity rules with analytic controls
and synthetic records, without Julia.

## Output files

Every production process writes a `julia-<VERSION>-rep<NN>` prefix in its block
folder. Existing process prefixes and coefficient files are not overwritten.

| File | Contents |
|---|---|
| `*-catalog.tsv` | Shared #116 case schema. |
| `external/*-catalog.tsv` | Case ID, estimator, design, λ, order, rung, stopping family and Gram policy in addition to the shared columns. |
| `*-metrics.tsv`, `*-samples.tsv` | Process summaries and every timed attempt: nanoseconds, GC time, Julia heap bytes, accuracy and status. |
| `*-errors.tsv` | Non-`ok` cases and error details. |
| `*-settings.toml` | Exact options for every executed rung. |
| `*-diagnostics.tsv`, `*-diagnostics.toml` | Observation certificates, secondary loading changes, and returned API diagnostics such as passes, path checks and residual scales. |
| `*-metadata-start.toml`, `*-metadata.toml` | Provenance, hashes, Julia/BLAS/CPU identity and limits; final metadata includes completion, status counts, elapsed time and peak RSS. Start without final marks an interrupted process. |
| `coef/*.f64`, `coef/manifest.tsv` | Final returned coefficients, every path level, shapes, levels, primary values, secondary loading changes and SHA-256 hashes. |

Each analysis output directory is fresh and contains:

| File | Contents |
|---|---|
| `REPORT.md` | Generated case, group, noise, support, failure and limitation tables. |
| `cases.csv` | Ratios, intervals, statuses, achieved accuracy, support diagnostics and screening decisions. |
| `groups.csv` | Equal-weight aggregates, block-bootstrap intervals and exclusion counts. |
| `rungs.csv` | Calibration only: every rung, its cost, accuracy, overshoot and eligibility. |
| `selection.toml` | Select mode only: frozen coordinate/best choices and explicit `not reached` entries. |
| `noise.json` | A/A bounds and assumptions, analysis settings and process provenance; null bounds denote positive infinity. |

Preserve the artifact, raw records, coefficient archives, lockfiles, exact
source revision and commands with the reports. Numerical failures remain valid
records when their integrity checks pass.

## Results and historical material

[`docs/src/performance.md`](../../docs/src/performance.md) is the designated results page. Historical benchmarks
remain in the [pre-cleanup tree](https://github.com/mlakolar/ProximalSolvers.jl/tree/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark).
Their mixed-workload aggregates cover different estimators and objectives and
do not serve as this suite's comparison aggregate.
