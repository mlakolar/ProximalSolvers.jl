Reviewer evidence for review-r1.md. Paths are relative to the audit directory unless absolute in a script. Original report, study, evidence and production files were not edited. Reviewer Julia runs used Julia 1.13.4 and one BLAS thread.

Recounts:

```sh
python3 .codex-orchestrator/audit/review-r1-evidence/recount.py
python3 .codex-orchestrator/audit/review-r1-evidence/corrections.py
```

Run one Julia probe at a time from the review checkout, after the requested Pkg.instantiate setup:

```sh
JULIA_DEPOT_PATH=$PWD/.codex-orchestrator/depot-codex-release:<WT>/.codex-orchestrator/depot-release:$HOME/.julia: timeout 600 <DEPOT>/juliaup/julia-1.13.4+0.x64.linux.gnu/bin/julia --startup-file=no --heap-size-hint=4G --project=. .codex-orchestrator/audit/review-r1-evidence/ordinary.jl
```

The same command prefix was used for probe.jl, cancellation.jl, edges.jl, and corrected_bound.jl; their outputs are alongside them. The explicit binary bypasses juliaup needing a writable global lockfile. ordinary.jl, probe.jl and edges.jl include the read-only X1 source in a separate module. corrected_bound.jl changes only the reviewer's denominator for the elastic-net measurement; it does not alter solver code.

The regenerated tables match both archived tables byte for byte. snapshots are preserved in <TMP>, including adjacent source bundles; snapshot-verification.txt records their final verification. issue352.json preserves the requested gh issue view result.
