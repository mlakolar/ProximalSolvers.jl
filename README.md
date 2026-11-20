# Evidence of the #400 validation (PGD/APG stopping with weighted NormL1 and NormLinf)

Validated revision: ProximalSolvers master `083c2f705b37a285dc433a89676ce4e6a4356dea`, ProximalBase pin
`e03c6d9659365d54f4e0fba1a9cd54490631eea6` (git-tree-sha1 `8de7a696d89a10022bb40f0941745939e4087fd4`), Julia 1.13.4
(`release`, AMD Zen 3) and 1.10.13 (`lts`, Intel Skylake-SP), single-threaded BLAS. Research only: nothing here is
package code. Local paths in the outputs are replaced by `<PS checkout>` and `<depot>`.

## study/
| file | what it is |
|---|---|
| `lib400.jl` | independent BigFloat measures: weighted lasso (KKT ‖G‖∞, dual value with θ = κPr off the span of the zero-weight columns, polish, reference) and ℓ∞ penalty (Euclidean distance to λ∂‖x‖∞, its ∞-norm, dual value with θ = κr, face polish, reference); includes `../archive352/study/lib.jl` |
| `wl1.jl` | sweep: PGD/APG with `NormL1(λ0, w)` (adapted from the #352 `grad.jl`) |
| `linf.jl` | `sweep`: PGD/APG with `NormLinf(λ)`; `traj`: criteria along long trajectories |
| `driver.jl` | runs the six processes of one Julia version |
| `timing.jl` | per-check cost of the ℓ∞ criteria |
| `an400.py`, `an400_tables.py`, `an400_crit.py`, `report_tables.py` | analysis (standard library only) |

## archive352/study/lib.jl
Unchanged copy of `study/lib.jl` of `archive/issue-352-evidence` (`e2a5178`): fixtures, BigFloat helpers, references.

## evidence/
| path | what it is |
|---|---|
| `release/`, `lts/` | one row per solve (`wl1_*.tsv`, `linf_sweep_*.tsv`) or per (trajectory, criterion, τ) (`linf_traj_*.tsv`), gzip; `driver.meta` (start, Julia, CPU kind, exit codes). Each table starts with `#` lines recording the Julia version, BLAS threads, CPU kind and the loaded ProximalBase manifest entry |
| `analysis-*.txt`, `tables-*.txt`, `crit-*.txt` | output of `an400.py`, `an400_tables.py`, `an400_crit.py` |
| `report_tables.md` | output of `report_tables.py` (the tables of the report) |
| `timing-release.txt` | output of `timing.jl` (shared node, indicative) |

## report/
`plan.md` and `report.md`, as posted on the issue.

To reproduce, from the package root of a checkout at the revision above:
`julia --project=. study/driver.jl OUT wl1:Float64 wl1:Float32 linf-sweep:Float64 linf-sweep:Float32 linf-traj:Float64 linf-traj:Float32`
(with this archive's `study/` and `archive352/` copied into the checkout), then `python3 study/an400.py OUT`.
To analyse the archived tables: `gunzip evidence/*/*.gz`, then `python3 study/report_tables.py evidence/release evidence/lts`.
`SHA256SUMS` covers every file.
