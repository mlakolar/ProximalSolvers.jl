Revision-3 independent review evidence. The supplied inputs and earlier reviews/evidence were not edited.

check_revision.py independently classifies the preserved round-2 per-solve gate replay under the revised policy and checks every displayed count and worst-residual column in the new gate output. It also checks that only four captured files changed from revision 2. numeric-delta-check.txt reruns the independent round-2 checks against unchanged sweep data. Regenerated report_numbers.txt and tables-*.txt match the supplied versions exactly.

nearfit.jl runs six targeted tall near-fit solves and evaluates production certification afresh at the returned vectors. It records the residual-error allowance and an independent 600-bit residual-direction dual gap; it does not instrument the original solve's certificate locals. It also records the scale probe references' dual gaps. The script was run sequentially under timeout 600 with Julia 1.13.4 and BLAS set to one thread.

Julia invocation from the review checkout:

```sh
JULIA_DEPOT_PATH=$PWD/.codex-orchestrator/depot-codex-release:<WT>/.codex-orchestrator/depot-release:$HOME/.julia: timeout 600 <DEPOT>/juliaup/julia-1.13.4+0.x64.linux.gnu/bin/julia --startup-file=no --heap-size-hint=4G --project=. .codex-orchestrator/audit/review-r3-evidence/nearfit.jl
```

part*.md.diff records the delta inspected. issue327.json and pr365.json are read-only GitHub metadata checks, not a validation of the placeholder maintainer ruling. snapshot-verification.txt records successful revision-3 and unchanged PB/X1 snapshot verification. Snapshots and adjacent source bundles are retained in their /tmp locations stated in the review.
