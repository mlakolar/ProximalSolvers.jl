# Extraction performance evidence — exact PB A

This is the executed 2026-11-10 Linux comparison of preserved PS
`9be1773e911a44ec21d49df28cb01fea37c4316e` and extracted source
`a457a0942338a936eb3b09cebed88d4743f365bc`, using PB A
`e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291` in both modules.
See [the reduction report](../minimal-core-reduction.md) for results and limits.

[evidence.json](evidence.json) records source/environment/harness hashes, all
eight cases, old/old noise, allocations and numerical comparisons. The four
`.tsv.gz` files preserve the complete measured timing and trajectory records;
their uncompressed hashes are also recorded. `controlled.jl` and `summarize.py`
are unchanged copies of the executed tools. The environment files preserve the
actual resolved packages and original local source path; substitute a fresh PB
checkout when reproducing. `SHA256SUMS` covers this directory's files.

To inspect the recorded results without running any solvers:

```sh
sha256sum -c SHA256SUMS
gzip -dc verified-old-candidate-a457.tsv.gz > /tmp/ps-extraction-timing.tsv
gzip -dc verified-old-candidate-a457-trajectories.tsv.gz > /tmp/ps-extraction-trajectory.tsv
python3 summarize.py /tmp/ps-extraction-timing.tsv /tmp/ps-extraction-trajectory.tsv
```

For a fresh comparison, extract the two PS commits with `git archive` into
separate immutable directories. Check out PB A separately and create an
isolated environment with that PB path and direct PrecompileTools `1.4.0`
(Preferences `1.6.1`). The supplied manifest identifies the remaining versions.
Use Julia `1.13.3`, `--startup-file=no --compiled-modules=no`, one Julia thread,
one OpenBLAS thread, and that environment via `--project`. The harness checks
the actual loaded PB source digest before loading either PS module.

```sh
julia --startup-file=no --compiled-modules=no --project=/path/to/environment controlled.jl control /path/to/old/src /path/to/old/src /tmp/control.tsv /tmp/control-trajectory.tsv
julia --startup-file=no --compiled-modules=no --project=/path/to/environment controlled.jl paired /path/to/old/src /path/to/candidate/src /tmp/paired.tsv /tmp/paired-trajectory.tsv
python3 summarize.py /tmp/control.tsv /tmp/control-trajectory.tsv
python3 summarize.py /tmp/paired.tsv /tmp/paired-trajectory.tsv
```

Set `JULIA_NUM_THREADS=1` and `OPENBLAS_NUM_THREADS=1` for both commands. Stop
other test/benchmark workloads first. Use fresh output paths. Setup, input
copies and RNG creation are excluded from timing; solver validation remains
included. Warm specialized calls and balanced randomized ABA/BAB triplets
compare the same work. The summarizer refuses incomplete/unbalanced samples or
numerical differences. There is no CPU affinity or claim of universal speed.

Moderate Float32 PGD retains about **2.6% bracketed timing overhead** above the
tight control noise, consistent with required once-per-solve finite-data
validation. This is not a zero-regression claim. An earlier pre-SIMD estimate
lost its raw artifacts in a host reset and is not used as current acceptance
evidence or for an absolute cross-host timing comparison.
