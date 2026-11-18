# Evidence of the #352 Stage 0 audit (stopping and convergence contracts of CD, PGD and APG)

Audited revision: ProximalSolvers master `b8a2c04205f6dc8aadeecc42f4971602ab1b5b89`, ProximalBase rev
`a19c59aa723d085d5d7cf5242895bda16eb77214` (tree `138929aa27c6221284ee1763e66b1110dd6ec418`), Julia 1.13.4
(`release`) and 1.10.13 (`lts`). Research only: nothing here is package code. Local paths are replaced by
placeholders (`<WT>` the audit worktree, `<X1>` the prototype worktree, `<RUN>` the run directory).

## report/
`part1.md`, `part2.md`: the report as posted on the issue.

## review/
The independent reviews of the report drafts (`review-r1.md` to `review-r4.md`) and the reviewer's own probes and recounts (`r1-evidence/` to `r3-evidence/`).

## ruling/
The maintainer's ruling of 2026-11-18, as recorded on the issue.

## study/
| file | what it is |
|---|---|
| `lib.jl` | deterministic fixtures (splitmix64), BigFloat measures (KKT residual, objective, dual value), references |
| `lib_fixtures.jl` | the fixture generators alone, for the timing script |
| `cd_ls.jl` | sweep: least-squares CD, scalar (lasso, elastic net) and group lasso |
| `grad.jl` | sweep: PGD and APG |
| `sqrt.jl` | sweep: square-root lasso CD |
| `run_cd.sh`, `run_other.sh` | the launchers that produced `evidence/sweep-*` |
| `probe_underflow.jl` | F1: the product-underflow input on CD, PGD and APG |
| `probe_rounding.jl` | F2, F3 and the trade-offs of X1: cancellation, a large null-space warm start, strict options on the F1 input, a call limit (run on the master tree and on the X1 tree) |
| `probe_cd_gate.jl` | F2: what a working-precision check at the stop of CD would refuse |
| `probe_scales.jl`, `probe_scales_pgd_up.jl` | exact power-of-two rescalings; group lasso with unpenalized groups |
| `probe_cd_bound.jl` | F8: the first-order bound implied by the CD change test |
| `probe_group_colscale.jl` | group CD on the column-scaled design |
| `probe_edges.jl` | result status at the edges |
| `x1_stall_proposes.diff` | prototype X1 (F4), against the audited revision |
| `x1_timing.jl` | paired in-process timing of X1 on the ordinary path |
| `report_numbers.py` | every count and extreme quoted in the report |
| `summ.py`, `drill.py`, `tables.py`, `grad_an.py`, `sqrt_an.py`, `x1_compare.py`, `x1_compare_lts.py` | analysis of the tables (standard library only) |

## evidence/
| path | what it is |
|---|---|
| `sweep-release/`, `sweep-lts/` | one row per solve: `cd_scalar_*.tsv`, `cd_group_*.tsv`, `grad_*.tsv`, `sqrt_*.tsv` (gzip), and `*.meta` (load, commit, Julia version, exit) |
| `sweep-x1/`, `sweep-x1-lts/` | the PGD/APG sweep on prototype X1 |
| `tables-release.txt`, `tables-lts.txt` | output of `study/tables.py` |
| `report_numbers.txt` | output of `study/report_numbers.py` |
| `x1_compare.txt`, `x1_compare_lts.txt` | F4: master outcomes under `ftol = 0`; master against X1 |
| `x1_timing_release.txt` | paired timing, taken under load |
| `probe_*.txt`, `probe_*.tsv` | probe outputs |

Columns of the sweep tables: the problem and settings; the solver's result fields; `kkt_rel` (exact
`‖G‖∞ / max(λ, λmax)`); `gap_at_x` (relative duality gap at the returned point); `subopt_lo`, `subopt_hi`
(proved lower and upper bounds of the relative suboptimality, against the reference); `ref_tight` (the
reference's own gap is at most `1e-12`); `min_err` (reported `minimum` against the exact objective at the
returned point). For the square-root lasso: `gap` (reported), `gap_exact_at_x` (the exact gap of the same
dual direction), `ref_gap`.

To analyse: `gunzip evidence/sweep-*/*.gz`, then `python3 study/tables.py evidence/sweep-release`.
`SHA256SUMS` covers every file.
