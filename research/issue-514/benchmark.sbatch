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
tenants() {
  squeue -h -w "$SLURMD_NODENAME" -o "%i" | awk -v job="$SLURM_JOB_ID" '$0 != job {n++} END {print 0+n}'
}
printf 'other_jobs_start\t%s\n' "$(tenants)" >> "$out/cpu.tsv"
if [[ "$mode" = short ]]; then
  versions=(1.10.13)
  orders=(forward)
else
  versions=(1.10.13 1.13.4)
  orders=(forward reverse)
fi
for version in "${versions[@]}"; do
  julia="$HOME/julia/julia-$version/bin/julia"
  flags=(--threads=1 --startup-file=no --check-bounds=auto -O2 -C native "--project=$root/env/$version")
  for order in "${orders[@]}"; do
    target="$out/$version-$order"
    [[ ! -e "$target/done" ]] || continue
    tmp=$(mktemp -d "$out/work.$version-$order.XXXXXX")
    srun --exact -N1 -n1 -c1 --mem=6G --cpu-bind=cores \
      bash -c 'taskset -pc $$ > "$2/affinity.tsv"; "$1" "${@:5}" preflight.jl > "$2/source.tsv" &&
               "$1" "${@:5}" benchmark.jl "$2" "$3" "$4" > "$2/work.log"' \
      runner "$julia" "$tmp" "$order" "$mode" "${flags[@]}"
    touch "$tmp/done"
    mv -T "$tmp" "$target"
  done
done
printf 'other_jobs_end\t%s\n' "$(tenants)" >> "$out/cpu.tsv"
