#!/bin/bash
# Paired timing of PR A at the commit of the worktree: base0, base1 (A/A), head; 15 rounds; one pinned core.
set -u
WT=<WORK>/ProximalSolvers.jl-issue353
RUN=$WT/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf
T=$RUN/evidence/timing; cd $WT
git rev-parse HEAD > $T/pra.sha; git status --porcelain > $T/pra.dirty
for spec in "lts:" "release:" "lts-alderlake:-C alderlake"; do
  tag=${spec%%:*}; flag=${spec#*:}; ch=${tag%%-*}
  uptime > $T/pra-$tag.load
  systemd-run --user --scope -q -p MemoryMax=10G -p MemorySwapMax=0 env JULIA_DEPOT_PATH=$WT/.codex-orchestrator/depot-probe-$ch-$ch:$HOME/.julia: \
    taskset -c 4 julia +$ch --startup-file=no $flag --project=. .codex-orchestrator/probes/pra_paired.jl $T/pra-$tag.tsv 15 > $T/pra-$tag.log 2>&1
  echo "rc=$?" >> $T/pra-$tag.load; uptime >> $T/pra-$tag.load
  python3 .codex-orchestrator/probes/summarize.py $T/pra-$tag.tsv > $T/pra-$tag.summary.txt 2>&1
done
echo done > $T/pra.done
