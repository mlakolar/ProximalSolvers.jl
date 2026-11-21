#!/usr/bin/env bash
#SBATCH --open-mode=append
set -euo pipefail
root=$1
mode=$2
cd "$root"
export JULIA_DEPOT_PATH="$root/depot:$HOME/.julia:" JULIA_LOAD_PATH='@:@stdlib' JULIA_PKG_OFFLINE=true
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
out="$root/results/$SLURM_JOB_ID"
mkdir -p "$out"
echo "job $SLURM_JOB_ID attempt ${SLURM_RESTART_COUNT:-0}"
lscpu | awk -F: '/^Model name:/{sub(/^[ \t]+/,"",$2); print "cpu\t"$2}' > "$out/cpu.tsv"

work() {
  local version=$1 bounds=$2 target tmp
  target="$out/$version-$bounds"
  [[ ! -e "$target/done" ]] || return 0
  tmp=$(mktemp -d "$out/work.$version-$bounds.XXXXXX")
  local julia="$HOME/julia/julia-$version/bin/julia"
  local -a flags=(--threads=1 --startup-file=no "--check-bounds=$bounds" "--project=$root/env/$version")
  srun --exclusive --exact -N1 -n1 -c1 --mem=3G --cpu-bind=cores \
    bash -c '"$1" "${@:4}" preflight.jl > "$2/source.tsv" && "$1" "${@:4}" correctness.jl "$2" "$3" > "$2/work.log"' \
    runner "$julia" "$tmp" "$mode" "${flags[@]}"
  touch "$tmp/done"
  mv -T "$tmp" "$target"
}

if [[ "$mode" = short ]]; then
  work 1.10.13 auto
  work 1.13.4 yes
else
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
fi
