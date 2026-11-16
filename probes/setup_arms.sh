#!/usr/bin/env bash
# #307: build one environment and one private depot per arm, with the fixed harness's setup.jl.
#   SHARED_DEPOT=<depot with registries/packages> setup_arms.sh JULIA HARNESS_ROOT OUT ARM_SPEC...
# ARM_SPEC is label=checkout_dir (a clean detached worktree). Writes OUT/arms.tsv
# (label, checkout, PS SHA, PB pin, env, depot) and OUT/manifest-<label>.toml.
set -euo pipefail
JULIA=$1; HARNESS=$2; OUT=$3; shift 3
: "${SHARED_DEPOT:?set SHARED_DEPOT}"
[ -e "$OUT" ] && { echo "refusing existing $OUT" >&2; exit 3; }
mkdir -p "$OUT"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
for spec in "$@"; do
  l=${spec%%=*}; d=${spec#*=}
  if git -C "$d" status --porcelain | grep -q .; then echo "dirty checkout $d" >&2; exit 3; fi
  rev=$(git -C "$d" rev-parse HEAD)
  pbrev=$(sed -n 's/^ProximalBase = {rev = "\([0-9a-f]\{40\}\)".*/\1/p' "$d/Project.toml")
  [ -n "$pbrev" ] || { echo "no PB pin in $d/Project.toml" >&2; exit 3; }
  mkdir -p "$OUT/depot-$l"
  JULIA_DEPOT_PATH="$OUT/depot-$l:$SHARED_DEPOT" \
    "$JULIA" --startup-file=no "$HARNESS/benchmark/setup.jl" "$d" "$OUT/env-$l" pinned > "$OUT/setup-$l.log" 2>&1
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$l" "$d" "$rev" "$pbrev" "$OUT/env-$l" "$OUT/depot-$l" >> "$OUT/arms.tsv"
  cp "$OUT/env-$l/Manifest.toml" "$OUT/manifest-$l.toml"
done
"$JULIA" --version > "$OUT/julia-version.txt"
