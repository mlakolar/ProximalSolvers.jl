#!/usr/bin/env bash
# #515 correctness replay (parity.jl) in the four Julia/bounds configurations, one core each.
# Usage: sbatch [options] correctness.sbatch <absolute path of research/issue-515> [short]
#SBATCH --open-mode=append
set -euo pipefail
here=$1
mode=${2:-full}
r514="$here/../issue-514"
cd "$here"
export JULIA_DEPOT_PATH="$r514/depot:$HOME/.julia:" JULIA_LOAD_PATH='@:@stdlib' JULIA_PKG_OFFLINE=true
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
out="$here/results/correctness-$SLURM_JOB_ID"
mkdir -p "$out"
echo "job $SLURM_JOB_ID attempt ${SLURM_RESTART_COUNT:-0} node $SLURMD_NODENAME"
lscpu | awk -F: '/^Model name:/{sub(/^[ \t]+/,"",$2); print "cpu\t"$2}' > "$out/cpu.tsv"
git -C "$here" rev-parse HEAD > "$out/research_sha.txt" 2>/dev/null || true
sha256sum "$here"/*.jl "$r514"/*.jl > "$out/script_sha256.txt"
sarg=""
if [[ $mode = short ]]; then sarg=short; fi
work() {
  local version=$1 bounds=$2 target tmp
  target="$out/$version-$bounds"
  [[ ! -e "$target/done" ]] || return 0
  tmp=$(mktemp -d "$out/work.$version-$bounds.XXXXXX")
  local julia="$HOME/julia/julia-$version/bin/julia"
  local -a flags=(--threads=1 --startup-file=no "--check-bounds=$bounds" "--project=$r514/env/$version")
  srun --exact -N1 -n1 -c1 --mem=6G --cpu-bind=cores \
    bash -c 'cd "$3/../issue-514" && "$1" "${@:5}" preflight.jl > "$2/source.tsv" &&
             cd "$3" && "$1" "${@:5}" parity.jl "$2" $4 > "$2/work.log" 2>&1' \
    runner "$julia" "$tmp" "$here" "$sarg" "${flags[@]}"
  touch "$tmp/done"
  mv -T "$tmp" "$target"
}
pids=()
for version in 1.10.13 1.13.4; do
  for bounds in auto yes; do
    work "$version" "$bounds" &
    pids+=("$!")
  done
done
code=0
for pid in "${pids[@]}"; do wait "$pid" || code=1; done
exit "$code"
