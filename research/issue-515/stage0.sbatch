#!/usr/bin/env bash
# Stage 0 profile of the #514 B0 prototype on one bound physical core of an exclusive node.
# Usage: sbatch [options] stage0.sbatch <absolute path of research/issue-515> [quick]
#SBATCH --open-mode=append
set -euo pipefail
here=$1
mode=${2:-full}
r514="$here/../issue-514"
cd "$here"
export JULIA_DEPOT_PATH="$r514/depot:$HOME/.julia:" JULIA_LOAD_PATH='@:@stdlib' JULIA_PKG_OFFLINE=true
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
out="$here/results/stage0-$SLURM_JOB_ID"
mkdir -p "$out"
echo "job $SLURM_JOB_ID attempt ${SLURM_RESTART_COUNT:-0} node $SLURMD_NODENAME"
lscpu | awk -F: '/^Model name:/{sub(/^[ \t]+/,"",$2); print "cpu\t"$2}' > "$out/cpu.tsv"
tenants() {
  squeue -h -w "$SLURMD_NODENAME" -o "%i" | awk -v job="$SLURM_JOB_ID" '$0 != job {n++} END {print 0+n}'
}
printf 'node\t%s\nother_jobs_start\t%s\n' "$SLURMD_NODENAME" "$(tenants)" >> "$out/cpu.tsv"
git -C "$here" rev-parse HEAD > "$out/research_sha.txt" 2>/dev/null || true
sha256sum "$here"/*.jl "$r514"/*.jl > "$out/script_sha256.txt"
qarg=""
if [[ $mode = quick ]]; then qarg=quick; fi
for version in 1.10.13 1.13.4; do
  target="$out/$version"
  [[ ! -e "$target/done" ]] || continue
  tmp=$(mktemp -d "$out/work.$version.XXXXXX")
  julia="$HOME/julia/julia-$version/bin/julia"
  flags=(--threads=1 --startup-file=no --check-bounds=auto -O2 -C native "--project=$r514/env/$version")
  srun --exact -N1 -n1 -c1 --mem=12G --cpu-bind=cores \
    bash -c 'taskset -pc $$ > "$2/affinity.tsv"; cd "$3/../issue-514" && "$1" "${@:5}" preflight.jl > "$2/source.tsv" &&
             cd "$3" && "$1" "${@:5}" stage0.jl "$2" $4 > "$2/work.log" 2>&1' \
    runner "$julia" "$tmp" "$here" "$qarg" "${flags[@]}"
  touch "$tmp/done"
  mv -T "$tmp" "$target"
done
printf 'other_jobs_end\t%s\n' "$(tenants)" >> "$out/cpu.tsv"
