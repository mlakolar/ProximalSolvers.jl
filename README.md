# ProximalSolvers.jl #320 Phase 0 evidence (default Float32 PGD stopping and the `1e-5` benchmark target)

This is a lightweight archive of the research behind the
[Phase 0 report on #320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320#issuecomment-6967100343).
The report as posted is `report/report-post.md`. Under the maintainer's decision, option A (documentation only) is implemented by
[PR #383](https://github.com/mlakolar/ProximalSolvers.jl/pull/383). This archive is not part of the package; nothing here is built or tested.

- **Revisions.** ProximalSolvers.jl was measured at three revisions:
  - `637f06a2713f1b6727869f84c22aa21e69f81d55`, before #319, with ProximalBase `c123d56ba1948e36a8fdbf183a9eea396a16e0d5`;
  - `9f86a808bfac968f5421b9efeb6d0aecd7c1c775`, #319, with ProximalBase `50db4b1ef376cbe01831c3dd019b6be0027db0b6`;
  - master `dac9f4b6819d9321117ee3cf3549e9e46a043f01`, with ProximalBase `a19c59aa723d085d5d7cf5242895bda16eb77214`.

  Each run's `run-provenance.txt` records the loaded revision, the fingerprint of `Project.toml` plus `src/`, and the ProximalBase tree.
- **Machine.** Cluster (Slurm). The result directories ending in `-2640` ran on the Intel Xeon E5-2640 v4, and those ending in `-4116` on the Intel Xeon Silver 4116 (AVX-512). Timings (`time-4116`) had exclusive use of a node. Every run used 1 Julia thread, 1 BLAS thread and offline packages.
- **Julia.** 1.10.13 and 1.13.3.
- **Scrubbing.** Paths and host names are replaced by placeholders (`<cluster-dir>`, `<local>`, `<julia-root>`, `<node>`). The scheduler submission wrapper is omitted. In the job bodies the scheduler's job-ID variable reads `JOB_ID`.

## Contents

- `report/`:
  - `report-post.md`: the report as posted;
  - `preregistration.md`, with its checksum `preregistration.sha256`. The designs, draws, profiles and criteria were fixed there before the matrix ran.
- `scripts/`:
  - `probe320.jl`: the probe. It follows one PGD trajectory on the loaded revision's own state and stopping functions, evaluates every stopping profile, and computes the independent gap and KKT residual at every iterate. Its header gives the usage.
    - **This is the final version, the one used for the `mxd*`, `advd*` and timing runs.**
    - The earlier `repro`, `mx1`, `mx2` and `adv` runs finished before its last edit and used a predecessor. Section 1 of the report records that the two submissions agree in every discrete column except `mode_switch_iter`, which the later version computes over a longer trajectory.
  - `time320.jl`: the timing probe.
  - `mkenv.jl`: builds one environment per revision with that revision's pinned ProximalBase.
  - `runjob.sh`, `runtime.sh`: the batch-job bodies. They hold the environment variables and command lines of every run.
    - The placeholders (`<cluster-dir>`, `<julia-root>`) must be replaced before running, because the unquoted placeholders do not parse as shell.
  - Analysis scripts, Python standard library only:
    - `make_tables.py`: regenerates `tables/tables.md`, the counts of sections 3 and 4.
    - `an_repro.py <run> <profiles> <solver>`: the section 2 table. For example, `an_repro.py repro-2640 H pgd`.
    - `sim.py`, `simval.py`, `simvar.py`: the replays of stopping-rule variants in section 6, and the offline check of the stop in section 1. They read per-iteration data (below).
    - `gen_more.py`: the variants table, then the timing table.
      - The variants part imports `simvar.py`, so it needs the per-iteration data.
      - The timing part (lines 28 onward) needs only `results/time-4116/`.
      - Its heading line says "exclusive node". The archived `tables/timing-table.md`, generated earlier, says "idle node". Both describe the same exclusive jobs.
    - `build_report.py`: assembled the report from an unarchived template and is kept for reference; it cannot run from this archive.
    - `an.py`, `an_matrix.py`: helper modules imported by the other scripts. They print nothing on their own.
- `tables/`: the summary tables the report was built from:
  - `tables.md`;
  - `sim-harness-Float32.md`, `sim-harness-Float64.md`, `sim-adverse-Float32.md`;
  - `variants-table.md`;
  - `timing-table.md`;
  - `raw-per-draw.txt`, the per-draw status of each case and arm;
  - `dev-t1-summary.tsv`, a development check.
- `results/<run>/<revision>-<julia>/`: one directory per run and revision. Each has:
  - `run-summary.tsv.gz`: one row per solve and profile, with flags, iterations, independent gap and KKT residual (Float64 and BigFloat), status, the first stop proposal, `kstar`, the curvature fields, and the `gradtol` sweep columns;
  - `run-events.tsv.gz`: per solve, the stop proposals and the stationarity-check decisions;
  - `run-provenance.txt`;
  - `exit.txt`.

  The runs:
  - `repro-*`: the three changed records. These directories also hold `run-iters/*.tsv.gz`, the complete per-iteration TSVs of those solves; section 4 row (4) uses them.
  - `mx1`, `mx2`: the harness designs.
  - `mxd1`, `mxd2`: the same with per-iteration detail.
  - `adv`, `advd`: the adverse set, without and with detail.
  - `time-4116`: the timing runs, `run-timing.tsv`.
- `SHA256SUMS`: checksums of every other file.

## What the archived files reproduce

**From this archive alone:**
- **Section 1:** the provenance, the bit-for-bit `xcheck` of the probe against the library (field `xcheck`), the BigFloat agreement (`gap` against `gap_big`), and the CPU-kind comparison.
- **Section 2:** the table, via `an_repro.py`.
- **Section 3:** the tables. The summary's counts of first proposals (237 objective, 3 none), of objective-increase stops (156) and of false successes (119) also come from here.
- **Section 4:** the counts.
- **Section 5:** the `gradtol` sweep columns, and the timing table from `time-4116`.
- **Section 7:** its percentages, which come from the section 3 tables.

**Only with the local per-iteration data:**
- the offline replay of the stop in section 1 (`simval.py`);
- the spacings of the objective increases (1 to 3 Float32 spacings, 142 of exactly 1);
- the gradient-error bound (2.5e-7 of S over about 957,000 iterations);
- section 4 table rows (2) and (3);
- section 6, the replays of rule variants.

## Not archived: the per-iteration trajectories (about 577 MB)

The per-iteration data of the `mxd*` and `advd*` runs are kept only in the maintainer's local run archive, `run-archives/issue-320-phase0-run-20261118T0124-31d8/`, on the maintainer's workstation. Its `runs/run-20261118T0124-issue320-31d8/evidence/` mirrors `results/` here, with `SHA256SUMS` over the evidence files (the job registry excluded). The layout:
- `mxd*/<revision>-<julia>/run-iters/*.tsv`: one TSV per solve;
- `advd*/<revision>-<julia>/run-iters.tar.gz`: unpack it in place to `run-iters/`.

The `sim*.py` scripts and the variants part of `gen_more.py` read `<run>/<revision>-<julia>/run-iters/*.tsv`.

## Reproducing

1. **Counts from the archived summaries.**
   - Unpack: `gunzip -k results/*/*/*.gz results/repro-*/*/run-iters/*.gz`.
   - The analysis scripts read the evidence directory from a constant `E` (or `E_`) at their top, written as `<local>/…/evidence/`. Set it to this archive's `results/`, plus `tables/` where a script reads a table.
   - Run `python3 make_tables.py` (it regenerates `tables/tables.md`) and `python3 an_repro.py repro-2640 H pgd`.
2. **Rerunning a probe:**
   - Build an environment per revision: `julia mkenv.jl <checkout at the revision> <env dir>`.
   - Run, for every revision: `A320_HARNESS=<checkout of dac9f4b>/benchmark A320_BIG=1 julia --project=<env dir> probe320.jl <mode> <outprefix> 1:10`, with mode `repro`, `matrix`, `adverse` or `both`.
     - The study used master `dac9f4b`'s harness (`problems.jl`, `certificates.jl`, `cases.jl`) for all three revisions; each `run-provenance.txt` records their SHA-1s.
     - Per-iteration detail is written unless `A320_DETAIL=0` (default `1`). `A320_KEXTRA` (default 20) sets how many iterations past the stop are followed.
     - `runjob.sh` shows the full command.
   - The Float32 inputs are the harness's Float64 draws rounded once. Within one CPU kind, the data hashes in `run-summary` are identical across revisions. Iteration counts and a few statuses can differ between CPU kinds, as section 1 of the report records.
3. **Timing:** `A320_HARNESS=<checkout of dac9f4b>/benchmark julia --project=<env dir> time320.jl <outprefix> <draws> <rounds>`, on an exclusive node, as `runtime.sh` shows.
