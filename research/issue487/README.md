# #487 research material (not part of the package)

Probes for ProximalSolvers.jl issue #487 (stopping scale with free coordinates), run at
`1a9f196bb8622180a52fc4e3d25279f1d65cb223` with ProximalBase `bc9e888d09e5fc3c3feb35905dd7a14e70657fa5`
on Julia 1.13.4 and 1.10.13. They override the private `_stationary!` (and, in round 1, `_lambda_max!`)
inside the running session; the package source is unchanged.

| file | what |
|---|---|
| `probe487.jl` | round 1: current rule vs the profiled reference (A) |
| `probe487b.jl` | round 2: rules cur, A, B, Bh, C, E on the fixture grid with BigFloat references |
| `probe487-bench.jl` | round 2: initialization, per-check and total solve cost of cur, A, B, E |
| `aggregate487b.py` | the summary tables posted on the issue (`python3 -I aggregate487b.py data/round2-grid-julia1.13.4.tsv`) |
| `summarize_bench.py` | the cost summary (`python3 -I summarize_bench.py data/round2-bench-julia1.13.4.tsv [per-iteration]`) |
| `extract_tsv.py` | copies the result rows out of a run log |
| `data/` | all result rows (tab-separated) |

Run from the repository root:

    julia --project=. -e 'using Pkg; Pkg.instantiate(); include("research/issue487/probe487b.jl")'
    julia --project=. -e 'using Pkg; Pkg.instantiate(); include("research/issue487/probe487-bench.jl")'

`PROBE_ONLY=<regex>` restricts probe487b.jl to matching fixtures; `PROBE_OUT=<path>` sets its TSV output.
The generated random fixtures differ between the two Julia versions, so the
1.13.4 and 1.10.13 grids are two independent draws.
