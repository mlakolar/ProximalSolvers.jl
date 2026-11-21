# Shared setup for the #320 Stage 2 probes (research only). Loads the formal harness's problem
# builders (the Phase 0 designs, same keys and data hashes), the gap prototype and a BigFloat
# reference. Nothing in src/ is changed.
using Pkg, TOML, SHA, Printf, Statistics, LinearAlgebra, InteractiveUtils
import ProximalSolvers, ProximalBase
const PS = ProximalSolvers
const PB = ProximalBase
include(joinpath(@__DIR__, "gapeval.jl"))
using .GapEval320

const HARNESS = get(ENV, "S2_HARNESS", joinpath(@__DIR__, "..", "..", "..", "..", "benchmark"))
const H = Module(:Harness320s2)
Core.eval(H, :(import ProximalBase, ProximalSolvers; using LinearAlgebra, SparseArrays, Random, SHA, Printf, Statistics))
Core.eval(H, :(include(p) = Base.include($H, p)))
for f in ("problems.jl", "certificates.jl", "cases.jl")
  Base.include(H, joinpath(HARNESS, f))
end

function provenance(io)
  println(io, "julia ", VERSION, "  cpu_name ", Sys.CPU_NAME, "  model ", Sys.cpu_info()[1].model, "  host_cpus ", Sys.CPU_THREADS)
  println(io, "threads ", Threads.nthreads(), "  blas_threads ", BLAS.get_num_threads(), "  ", BLAS.get_config())
  println(io, "PS path ", pkgdir(PS), "  version ", pkgversion(PS))
  gitrev = try
    readchomp(`git -C $(pkgdir(PS)) rev-parse HEAD`)
  catch
    "unavailable"
  end
  println(io, "PS git HEAD ", gitrev)
  io2 = IOBuffer()
  for fn in sort(vcat(joinpath(pkgdir(PS), "Project.toml"), [joinpath(d, n) for (d, _, ns) in walkdir(joinpath(pkgdir(PS), "src")) for n in ns if endswith(n, ".jl")]))
    write(io2, relpath(fn, pkgdir(PS)), '\0', read(fn), '\0')
  end
  println(io, "PS src fingerprint sha1 ", bytes2hex(sha1(take!(io2))))
  println(io, "PB path ", pkgdir(PB), "  version ", pkgversion(PB))
  project = Base.active_project(); manifest = Base.project_file_manifest_path(project)
  m = TOML.parsefile(manifest); e = only(get(m, "deps", m)["ProximalBase"])
  println(io, "PB manifest ", basename(manifest), "  repo-rev ", get(e, "repo-rev", ""), "  git-tree-sha1 ", get(e, "git-tree-sha1", ""))
  for f in ("problems.jl", "certificates.jl", "cases.jl")
    println(io, "harness ", f, " sha1 ", bytes2hex(sha1(read(joinpath(HARNESS, f)))))
  end
  println(io, "gapeval.jl sha1 ", bytes2hex(sha1(read(joinpath(@__DIR__, "gapeval.jl")))))
end

# BigFloat(256) reference: the same STOP-13 dual point formed from the exact residual of the
# stored (rounded) data and the given coefficients.
function gap_big(X::AbstractMatrix, y, s, λ, x; prec = 256)
  setprecision(BigFloat, prec) do
    Xb = big.(Float64.(X)); yb = big.(Float64.(y)); xb = big.(Float64.(x))
    sb, λb = big(Float64(s)), big(Float64(λ))
    gap_big_prepared(Xb, yb, sb, λb, xb)
  end
end
function gap_big_prepared(Xb, yb, sb, λb, xb)
  r = yb - Xb * xb
  z = transpose(Xb) * r
  rr = sum(abs2, r); l1 = sum(abs, xb)
  f = sb * rr / 2; P = f + λb * l1
  zmax = maximum(abs, z; init = big(0.0))
  κ = sb * zmax <= λb ? big(1.0) : λb / (sb * zmax)
  D = κ * sb * sum(r .* yb) - κ^2 * sb * rr / 2
  gap = P - D
  rel = iszero(P) ? (iszero(gap) ? 0.0 : Inf) : Float64(gap / P)
  (; P = Float64(P), gap = Float64(gap), rel)
end

illcond(a, fraction) = begin
  p = size(a.X, 2)
  X = a.X .* (10.0 .^ (-2 .* (0:p-1) ./ (p - 1)))'
  merge(a, (; X, λ = fraction * H.lambda_max(X, a.y; s = a.s)))
end
# Phase 0 designs, unchanged (archive/issue-320-evidence scripts/probe320.jl).
const HARNESS_DESIGNS = [
  ("lasso", r -> H.regression_problem(r, "core/lasso"), false),
  ("lasso-B", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), false),
  ("lasso-B-warm", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), true),
  ("lasso-C", r -> H.regression_problem(r, "extended/design-C"; n = 800, p = 120, design = :C), false),
  ("lasso-D", r -> H.regression_problem(r, "extended/design-D"; n = 180, p = 600, design = :D), false)]
const ADVERSE_DESIGNS = [
  ("adv-cor-low-cold", r -> H.regression_problem(r, "issue320/adv/cor"; n = 240, p = 160, design = :B, fraction = 0.02), false),
  ("adv-cor-low-warm", r -> H.regression_problem(r, "issue320/adv/cor"; n = 240, p = 160, design = :B, fraction = 0.02), true),
  ("adv-equi-low-cold", r -> H.regression_problem(r, "issue320/adv/equi"; n = 240, p = 160, design = :E, fraction = 0.02), false),
  ("adv-ill-mid-cold", r -> illcond(H.regression_problem(r, "issue320/adv/ill"; n = 240, p = 160, design = :A), 0.15), false),
  ("adv-ill-low-cold", r -> illcond(H.regression_problem(r, "issue320/adv/ill"; n = 240, p = 160, design = :A), 0.02), false),
  ("adv-ill-low-warm", r -> illcond(H.regression_problem(r, "issue320/adv/ill"; n = 240, p = 160, design = :A), 0.02), true),
  ("adv-wide-low-cold", r -> H.regression_problem(r, "issue320/adv/wide"; n = 180, p = 600, design = :A, fraction = 0.02), false)]
const ALL_DESIGNS = vcat(HARNESS_DESIGNS, ADVERSE_DESIGNS)

tsv(io, vals...) = println(io, join((v isa AbstractFloat ? repr(v) : replace(string(v), '\t' => ' ', '\n' => ' ') for v in vals), '\t'))
