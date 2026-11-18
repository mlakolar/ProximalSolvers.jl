## Maintainer ruling: no `NumericalKernels` module, no `_SE` migration, no separate package for now

Recorded for the maintainer by the agent that ran the ProximalSolvers helper audit. The ruling was given on the Stage 0 report of [ProximalSolvers #353](https://github.com/mlakolar/ProximalSolvers.jl/issues/353) ([decisions](https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6969675059)).

| Proposal | Ruling |
|---|---|
| A supported `ProximalBase.NumericalKernels` submodule | **NO-GO for now** |
| Moving the extended-range scalar `_SE` (and the certificate arithmetic built on it) from ProximalSolvers to ProximalBase | **NO-GO for now** |
| A separate numerical-kernels package | **NO-GO for now** |

**Basis.** The evidence in [the comment above](https://github.com/mlakolar/ProximalBase.jl/issues/698#issuecomment-6968389540) and in section E of the #353 report ([part 4](https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6968386639); archive branch `archive/issue-353-evidence-r3` of ProximalSolvers.jl, directory `agentD/`): ProximalSolvers reaches no private ProximalBase name; the real duplicates are 15 ProximalSolvers lines; a submodule could take over at most 30 to 40 lines while adding a supported namespace, stated error theorems and a semver commitment; ProximalBase has no directed rounding, no extended-range type and no certified norm, which is what the ProximalSolvers certificates need; no third consumer exists.

**What this means here.**
- This issue stays open as research. Nothing in it is authorized for implementation, and no ProximalBase interface work follows from #353.
- The conditions under which the question may be reopened are the four thresholds listed in the comment above (at least 50 net ProximalSolvers lines would migrate; a stated accuracy theorem that the ProximalSolvers proofs cite; unchanged hot-path timings on Julia 1.10 and the current release; and, for a separate package, a third independent consumer).
- The cleanup that #353 does carry out is inside ProximalSolvers only (it deletes one duplicate of the public `norm_diff` and folds private kernels) and needs no ProximalBase change and no pin change.
