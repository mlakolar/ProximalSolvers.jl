using Pkg
Pkg.offline(true)
for version in ("baseline", "candidate")
  Pkg.activate("env-" * version)
  Pkg.develop([PackageSpec(; path=abspath(version)), PackageSpec(; path=abspath("ProximalBase.jl"))])
  version == "candidate" && Pkg.add(["Aqua", "Statistics"])
end
