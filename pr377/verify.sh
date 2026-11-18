#!/bin/bash
# Orchestrator verification for PR #377, run sequentially, local, memory-capped, one BLAS thread.
set -u
cap() { systemd-run --user --scope -q -p MemoryMax=10G -p MemorySwapMax=0 env OPENBLAS_NUM_THREADS=1 JULIA_DEPOT_PATH=<issue worktree>/.codex-orchestrator/depot-verify-release:$HOME/.julia: julia +release --startup-file=no "$@"; }
E=<run>/evidence
for w in <base worktree> <head worktree>; do git -C $w rev-parse HEAD; git -C $w status --porcelain; done > $E/verify-worktrees-before.txt
cap --project=<head worktree> -e 'using Pkg; Pkg.instantiate()' > /dev/null 2>&1
VARIANT=M cap --project=<head worktree> <issue worktree>/.codex-orchestrator/probes317/scan2.jl > $E/scan2-head.tsv 2>&1; echo "scan2 head rc=$?"
VARIANT=M cap --project=<base worktree> <issue worktree>/.codex-orchestrator/probes317/scan2.jl > $E/scan2-base8cc.tsv 2>&1; echo "scan2 base rc=$?"
VARIANT=M F32=true cap --project=<head worktree> <issue worktree>/.codex-orchestrator/probes317/scan.jl > $E/scanf32-head.tsv 2>&1; echo "f32 head rc=$?"
VARIANT=M F32=true cap --project=<base worktree> <issue worktree>/.codex-orchestrator/probes317/scan.jl > $E/scanf32-base8cc.tsv 2>&1; echo "f32 base rc=$?"
git -C <pr361 copy> rev-parse HEAD > $E/pr361-verify.txt
git -C <pr361 copy> apply <run>/evidence/r2g-src.diff && git -C <pr361 copy> diff --stat >> $E/pr361-verify.txt
cap --project=<pr361 copy> <issue worktree>/.codex-orchestrator/probes317/newtests.jl <issue worktree> >> $E/pr361-verify.txt 2>&1; echo "pr361 newtests rc=$?"
cap --project=<pr361 copy> <issue worktree>/.codex-orchestrator/probes317/entry317.jl >> $E/pr361-verify.txt 2>&1; echo "pr361 entry rc=$?"
git -C <pr361 copy> checkout -q -- src/line_searches.jl; git -C <pr361 copy> status --porcelain >> $E/pr361-verify.txt
for w in <base worktree> <head worktree>; do git -C $w rev-parse HEAD; git -C $w status --porcelain; done > $E/verify-worktrees-after.txt
echo VERIFY DONE
