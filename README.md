# Evidence for ProximalSolvers.jl #296 (PR #315)

Scale-aware PGD/APG stopping with a stationarity check (F+R+E).
- Master: `fad90d93eb0abca3025ac5a07468b7ebe4c7e323`, with ProximalBase pinned at `c123d56ba1948e36a8fdbf183a9eea396a16e0d5`.
- PR measured at `6d90f25283380e1fd76b7d4107f91260bde602a5`. The final head `af507e6bc5853872cf7ae3e685d0b1e571782c8c` differs from it only in docstrings, docs and tests.
- F+G+R is `patches/fgr-on-base.diff` applied to master. It is a disposable comparison, not merged.

Runs used a cluster (Slurm) and Julia 1.10.13 and 1.13.3. The matrix ran on AMD Zen 3 (EPYC 7513) nodes. The paired benchmark ran on one whole Intel Xeon E5-2640 v4 node per Julia version, with one Julia thread and one BLAS thread.

## Files

- **`probes/`:** the harness.
  - `repro.jl`: the matrix. Arguments: `<out> <variant> <sweep> <datasets>`. The variant `impl` measures the checked-out source.
  - `ref.jl`: the 256-bit BigFloat lasso reference: Float64 support, an exact active-set polish, and a KKT check.
  - `datasets.jl`: the designs, including the adversarial `diag` and `orth`.
  - `variants.jl`: the disposable prototypes as method overrides (F, G, R, I1/I2, V, W, E, Q).
  - `runvariants.jl`: a driver that runs one process per variant.
  - `paired296.jl` and `bench296.jl`: the paired in-process benchmark. It runs master, F+G+R and the PR, plus master-against-master and PR-against-PR controls, alternating, in one process.
  - `benchagg.py`, `summary.py` and `cmp3.py`: the aggregation scripts. They use the standard library only.
  - `lserr.jl`: the probe of the Float64 PGD line-search underflow.
- **`matrix/`:** one row per solve (gzip-compressed TSV). Columns: data, T, α, method, λ fraction, start, options, flags, iterations, counters, final L, relative gap, relative KKT, reference KKT. Files:
  - master on both versions;
  - the PR at `6d90f25` on both versions;
  - F+G+R on 1.13.3.
- **`prototypes/`:**
  - prototype screening TSVs (Julia 1.13.3), including the adversarial designs;
  - the base reproduction of the diagnosis (`repro-base-*.tsv`: 6 α values per type, base design only).
- **`benchmark/`:** the raw `INFO`, `TIME` and `ALLOC` lines and summaries.
  - `bench1-*`: 5 rounds; the ordinary, harness, tiny and allocs groups.
  - `bench2-*`: 15 rounds; the ordinary group.
  - `TIME` rows are per round and side (`base`, `fgr`, `head`, `base2`, `head2`), in microseconds, the minimum over the batches of the round. `base2` and `head2` are the A/A controls.
  - `ALLOC` rows compare bytes at `maxiter` = 50 and 100.
- **`patches/fgr-on-base.diff`:** the F+G+R comparison patch.

## Limitations

- Timings come from one CPU model.
- The matrix's FSscale classification compares each tiny-α solve with its α = 1 counterpart.
- The independent references are exact for the lasso on the rounded data. They do not bound the error of any BLAS kernel.
TSV files are gzip-compressed (`gzip -n`, reproducible); decompress with `gunzip -k`.
