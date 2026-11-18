#!/bin/bash
set -u
E=<run>/evidence
python3 -I <home>/.codex/skills/github-issue-workflow/scripts/battery.py tests --worktree <issue worktree> --run-dir <run> --where local --versions lts,release --tag impl2 --tier none --jobs 2 -- core_regressions stopping_scale minimal_core_characterization core_contracts initial_curvature > $E/battery-merge-summary.txt 2>&1; echo "battery rc=$?"
cap() { systemd-run --user --scope -q -p MemoryMax=10G -p MemorySwapMax=0 env OPENBLAS_NUM_THREADS=1 JULIA_DEPOT_PATH=<issue worktree>/.codex-orchestrator/depot-verify-release:<home>/.julia: julia +release --startup-file=no "$@"; }
for w in <base worktree> <head worktree>; do git -C $w rev-parse HEAD; git -C $w status --porcelain; done > $E/verify2-worktrees-before.txt
cap --project=<head worktree> -e 'using Pkg; Pkg.instantiate()' > /dev/null 2>&1
cap --project=<base worktree> -e 'using Pkg; Pkg.instantiate()' > /dev/null 2>&1
cap --project=<head worktree> <issue worktree>/.codex-orchestrator/probes317/entry317.jl > $E/entry-counts-merged.txt 2>&1; echo "entry rc=$?"
VARIANT=M cap --project=<head worktree> <issue worktree>/.codex-orchestrator/probes317/scan2.jl > $E/scan2-merged.tsv 2>&1; echo "scan merged rc=$?"
VARIANT=M cap --project=<base worktree> <issue worktree>/.codex-orchestrator/probes317/scan2.jl > $E/scan2-master1baab.tsv 2>&1; echo "scan master rc=$?"
for w in <base worktree> <head worktree>; do git -C $w rev-parse HEAD; git -C $w status --porcelain; done > $E/verify2-worktrees-after.txt
echo VERIFY2 DONE
