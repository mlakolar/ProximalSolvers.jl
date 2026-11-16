# Evidence for ProximalSolvers.jl #307 / PR #319

The migration of the least-squares value and gradient calculations of CD, PGD and APG to the ProximalBase oracles merged in mlakolar/ProximalBase.jl#918.

Arms: A = PS `637f06a2713f1b6727869f84c22aa21e69f81d55` + PB `c123d56ba1948e36a8fdbf183a9eea396a16e0d5`; B = PS `45da3de8200da6e19f243f6c080540d5154d6b7f` + PB `50db4b1ef376cbe01831c3dd019b6be0027db0b6`; C = PS `fd4f5523207336a3fb90d129044b44348f17234d` + PB `50db4b1e…` (the final head differs from C only in documentation and one test comment).

- `plan-final.md`, `baseline-receipt.md`, `measurement-report.md`: the texts posted on the PR.
- `probes/`: the scripts that produced every record (`setup_arms.sh`, `formal_series.sh`, `latency_series.sh`, `latency_driver.jl`, `latency_child.jl`, `products.jl`, `sweep.jl`, `run_probe.jl`, `testcounts.jl`, and the analysis scripts `analyze_latency.py`, `compare_crossdep.py`, `compare_sweep.py`). One line of `latency_driver.jl` reads the scheduler's job-ID environment variable; its name is replaced by `JOB_ID_VARIABLE` in this copy.
- `baseline/<julia>/`: the arm-A baseline (two separately built copies, A1 and A2): first-call latency CSVs, product counts, the formal benchmark records of the #318 harness, validation, manifests. `baseline/aa-compare-*`: A1 against A2 with the harness's `compare.py`.
- `abc/<julia>/`: the three-arm job (latency, formal records, product counts, sweep). `abc/cmp-BC-*`: `compare.py`; `abc/cmp-AB-*`, `abc/cmp-AC-*`: `compare_crossdep.py` (cross-dependency, labelled in each report). `latency-abc.md`, `timing-table.md`: summaries.
- `sweep-unpinned/`: sweep rows from runs not pinned to one CPU kind (A and B on 1.10.13 ran on different CPU kinds; used only for the B→C check before the first migration push).

Paths of the cluster project directory are replaced by `<PROJECT>`. Every process ran with one Julia thread and one BLAS thread on exclusive nodes of one CPU kind (Intel Xeon E5-2640 v4) for the timing records.
