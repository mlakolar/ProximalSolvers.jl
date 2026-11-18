# ProximalSolvers.jl #353 Stage 0 evidence (numerical helper ownership and duplication, PS and PB)

Archive of the research behind the Stage 0 report on issue #353
(https://github.com/mlakolar/ProximalSolvers.jl/issues/353). Not part of the package; nothing here is built or tested.

- Base: ProximalSolvers.jl `dac9f4b6819d9321117ee3cf3549e9e46a043f01` (master after #348). ProximalBase pinned at
  `a19c59aa723d085d5d7cf5242895bda16eb77214` (git-tree-sha1 `138929aa27c6221284ee1763e66b1110dd6ec418`; the loaded
  package source was compared file by file with an export of that commit). ProximalBase master at the time:
  `13891ccfd5c33a042c5df82d670abf1f2d786a0f`.
- Machine: Intel Core i5-13600K, Linux x86-64, Julia 1.10.13 and 1.13.4, OpenBLAS with one thread in the timings,
  timings pinned to one performance core. Julia 1.10 selects the code target `goldmont` on this CPU; the Julia 1.10
  timings exist with the default target and with `-C alderlake`. The machine was shared during the runs; every timing
  is paired in one process with an A/A control. `env/` has the recorded environment.
- Local paths are replaced by placeholders: `<WORK>` (the directory holding the worktrees `ps-353`, `ps-353-x1a`, …),
  `<RUN>` (this directory), `<DEPOT>`, `<TMP>`, `<HOME>`. Scripts need these set back before they run. Copies of GitHub
  issue text that the audits read are not archived.

## Layout

- `report/REPORT.md`: the report. Branch `archive/issue-353-evidence` is revision r1; branch `archive/issue-353-evidence-r2` adds revision r2 on top of it (archive branches of the repository cannot be updated). `report/ledger.py` + `ledger-subs.txt` generate the ledger tables
  (`ledger-*.md`); `part-*.md` are the sections.
- `agentA/` (square-root lasso CD), `agentB/` (least-squares and group CD), `agentC/` (PGD/APG and the APG
  certificate), `agentD/` (ProximalBase inventory and the interface question): each has `report.md`, its scripts and
  raw outputs (`*_lts*` = Julia 1.10.13, `*_rel*`/`*_release*` = 1.13.4).
- `experiments/make_x1.py`: generator of the two square-root prototypes from the `dac9f4b` source.
- `experiments/x1/`: experiment X1 (square-root lasso range handling). `report.md`; patches `x1a-final.patch`
  (fast path of master kept bit for bit), `x1b-final.patch` (threshold formed in range; the recommended form),
  `x1d-final.patch` (x1b with a lazy column view and a four-argument cold call: the timed variant, bit-identical to
  x1b, `x1d_equiv*`), `x1c.patch`, `x1e.patch` (timing diagnostics); step-accuracy families against BigFloat
  (`exp2_*`), whole solves (`exp3_*`, `exp3_pass_totals.txt`), outcome scans (`exp4_*`), transactionality, allocation
  and IR counts.
- `experiments/x2/`: experiments X2 (bit-identical bundle, `x2.patch`), X3 (`x3.patch`: X2 plus `_scaled_norm` and
  `_sqnorm!` deleted) and the folded norm kernels (`sc_on_x2.patch`). `report.md`; fingerprints (`fp_*`), unit sweeps,
  the margin check, test runs and the edited test copies (`test_edits/`).
- `experiments/review-r1/`: the independent review of report revision r1 (`codex-review-r1.md`), its probe scripts and outputs, and the reproduction of its two counterexamples (`verify_findings*`). `experiments/x2/x2b.patch`, `fp_x2b_*`, `tests_x2b_*`: the five-item bundle of revision r2 (X2 with `response_scale` as on master).
- `experiments/timing/`: paired timing harnesses (`x1_paired.jl`, `x1_visit.jl`, `x2_paired.jl`), the runs
  (`x1-final-*`, `x2-final-*`: `.tsv` raw, `.summary.txt` per case, `.load` load average before and after),
  `x2-final-by-workload.txt`, `shrink_probe.jl`, `summarize.py`.
- `tools/count_loc.py` (executable line counts per top-level definition), `tools/loc-ps-dac9f4b.txt`,
  `tools/save_handback.py`.
- `SHA256SUMS`: checksums of every other file.

The prototypes are disposable: they exist only as these patches against `dac9f4b` and were not pushed as branches.
