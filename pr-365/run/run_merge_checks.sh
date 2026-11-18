#!/bin/bash
# All checks of PR B at the merge commit, against the base worktree at master 6e583f7. Sequential.
set -u
W2=<WORK>/ProximalSolvers.jl-issue353-2
RB=$W2/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf-b
BAT="python3 -I <SKILLS>/github-issue-workflow/scripts/battery.py"
LOCK=<WORK>/ProximalSolvers.jl-issue353/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf/evidence/.heavy.lock
cd $W2
probe() { name=$1; shift; for v in lts release; do $BAT julia --worktree $W2 --run-dir $RB --where local --versions $v --tag probe --name m-$name -- --project=. "$@" 2>&1 | tail -2 | head -1; done; }
probe b1 .codex-orchestrator/probes/exp_b1.jl 20000 1
probe e2cN .codex-orchestrator/probes/exp2c.jl 4000 7
probe dall .codex-orchestrator/probes/d_all.jl
probe parN .codex-orchestrator/probes/par_targeted.jl 40 3
probe b2 .codex-orchestrator/probes/exp_b2.jl
probe tiny .codex-orchestrator/probes/tiny_solves.jl
probe fp .codex-orchestrator/probes/fp_sqrt.jl
probe fl .codex-orchestrator/probes/floor64.jl
probe al .codex-orchestrator/probes/alloc.jl
probe alr .codex-orchestrator/probes/alloc_recomp.jl
flock -w 900 $LOCK $BAT tests --worktree $W2 --run-dir $RB --where local --versions lts,release --tag impl --tier full --jobs 3 --name m-full 2>&1 | tail -5
flock -w 900 $LOCK $BAT tests --worktree ${W2}-base --run-dir $RB --where local --versions lts,release --tag base --tier full --jobs 3 --name m-full-base 2>&1 | tail -5
mkdir -p $RB/evidence/timing
for spec in "lts:" "release:" "lts-alderlake:-C alderlake"; do
  tag=${spec%%:*}; flag=${spec#*:}; ch=${tag%%-*}
  uptime > $RB/evidence/timing/tb-$tag.load
  systemd-run --user --scope -q -p MemoryMax=10G -p MemorySwapMax=0 env JULIA_DEPOT_PATH=$W2/.codex-orchestrator/depot-probe-$ch-$ch:$HOME/.julia: \
    taskset -c 4 julia +$ch --startup-file=no $flag --project=. .codex-orchestrator/probes/timing_b.jl 15 7 > $RB/evidence/timing/tb-$tag.out 2>&1
  echo "rc=$?" >> $RB/evidence/timing/tb-$tag.load; uptime >> $RB/evidence/timing/tb-$tag.load
done
git -C $W2 rev-parse HEAD > $RB/evidence/m-checks.sha; git -C $W2 status --porcelain > $RB/evidence/m-checks.dirty
echo ALLDONE
