#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"
root=$PWD
clone_pin() {
  local name=$1 repo=$2 rev=$3
  if [[ ! -d $name/.git ]]; then
    git init -q "$name"
    git -C "$name" remote add origin "https://github.com/mlakolar/$repo.git"
  fi
  if ! git -C "$name" cat-file -e "$rev^{commit}" 2>/dev/null; then
    git -C "$name" fetch -q --depth=1 origin "$rev"
  fi
  git -C "$name" checkout -q --detach "$rev"
  test -z "$(git -C "$name" status --porcelain --untracked-files=no)"
}
clone_pin ps ProximalSolvers.jl 4988a16161dfb4e95b7a9fadc148104f3f023686
clone_pin pb ProximalBase.jl 050aca8bdd12a7f6174ad6acfeab29be3d76ffdb
clone_pin enclosure ProximalBase.jl 77bd8d9b4750c5fe389adc01612f5b0ce0947664
export JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
for version in 1.10.13 1.13.4; do
  julia="${1:-$HOME/julia}/julia-$version/bin/julia"
  export JULIA_DEPOT_PATH="${ISSUE514_DEPOT:-$root/depot}:${ISSUE514_CACHE:-$HOME/.julia}:"
  directory="$root/env/$version"
  mkdir -p "$directory"
  # Frozen campaign manifests take precedence when supplied with the artifact.
  if [[ -f "locks/$version/Manifest.toml" && ! -f "$directory/Manifest.toml" ]]; then
    cp "locks/$version/"{Project,Manifest}.toml "$directory/"
  fi
  (
    cd "$directory"
    "$julia" --startup-file=no --project=. -e '
      using Pkg
      if !isfile("Manifest.toml")
        # Both packages enter the separate resolver transaction as local checkouts.
        Pkg.develop([Pkg.PackageSpec(path="../../pb"), Pkg.PackageSpec(path="../../ps")])
      end
      Pkg.instantiate()
      Pkg.status(;mode=Pkg.PKGMODE_MANIFEST)
    '
  )
done
