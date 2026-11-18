# Paired in-process timing for PR B (#353): base, a second copy of base (control) and head in one process; ordinary square-root solves
# to convergence and solves whose visits go through `_sqrt_offrange_step` (tiny-scale data), without and with a nearly parallel residual
# (the recomputed-distance branch). Each round visits the three trees in a rotated order and takes the minimum over BATCHES solves.
# A fourth, untimed copy of base with counters reports the visits that reach `_sqrt_offrange_step` and the recompute branch.
# args: rounds batches      (reported run: 9 or more rounds)
using LinearAlgebra, Random, Logging, Printf
BLAS.set_num_threads(1)
module B0; include("<WORK>/ProximalSolvers.jl-issue353-2-base/src/ProximalSolvers.jl"); end
module B1; include("<WORK>/ProximalSolvers.jl-issue353-2-base/src/ProximalSolvers.jl"); end
module K;  include("<WORK>/ProximalSolvers.jl-issue353-2/src/ProximalSolvers.jl"); end
module Instr; include(joinpath(@__DIR__, "base_instr", "src", "ProximalSolvers.jl")); end
using ProximalBase: SqrtLeastSquaresLoss, NormL1, SparseIterate
const SIDES = (("base0", B0.ProximalSolvers), ("base1", B1.ProximalSolvers), ("head", K.ProximalSolvers))
const OFFR = getfield(Instr.ProximalSolvers, :OFFR); const RECOMP = getfield(Instr.ProximalSolvers, :RECOMP)
const ROUNDS = parse(Int, get(ARGS, 1, "9")); const BATCHES = parse(Int, get(ARGS, 2, "7"))
# ordinary / tiny-scale data; `par` = response close to one column (β has one nonzero entry, noise relative 1e-8)
function data(::Type{T}, n, p, sc, par) where T
  rng = Xoshiro(17 + n + p)
  Z = randn(rng, n, p); β = zeros(p)
  if par === :col                  # nearly collinear columns, y along them: r stays near-parallel to the visited column
    z = randn(rng, n); Z = z .+ 1e-6 .* Z; y = 3 .* z .+ 1e-8 .* randn(rng, n)
  elseif par; β[1] = 3.0; y = Z*β .+ 1e-8 .* randn(rng, n)
  else; β[1:min(p, 3)] .= (1.0, -2.0, 1.5)[1:min(p, 3)]; y = Z*β .+ randn(rng, n); end
  T.(ldexp.(Z, sc)), T.(ldexp.(y, sc))
end
function one(PS, X::Matrix{T}, y, λ) where T
  x = zeros(T, size(X, 2))
  t0 = time_ns()
  r = PS.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), PS.CDSolver(order = :cyclic))
  (time_ns() - t0, r.passes, r.converged, x)
end
function main()
  println("Julia ", VERSION, " rounds=", ROUNDS, " batches=", BATCHES)
  cells = Any[]
  for T in (Float32, Float64), (n, p) in ((30, 10), (200, 40), (40, 120), (1000, 100))
    push!(cells, (T, n, p, 0, false, "ordinary"))
  end
  for T in (Float32, Float64), (n, p) in ((30, 10), (200, 40), (1000, 100))
    sc = T === Float32 ? -70 : -520
    push!(cells, (T, n, p, sc, false, "tiny, general residual"))
  end
  for T in (Float32, Float64), (n, p) in ((30, 1), (200, 1), (200, 40), (1000, 100))
    sc = T === Float32 ? -70 : -520
    push!(cells, (T, n, p, sc, true, "tiny, near-parallel residual"))
  end
  for T in (Float32, Float64), (n, p) in ((30, 10), (200, 40), (1000, 100))
    sc = T === Float32 ? -70 : -520
    push!(cells, (T, n, p, sc, :col, "tiny, collinear columns"))
  end
  for (T, n, p, sc, par, lab) in cells
    X, y = data(T, n, p, sc, par)
    λ = T(0.3*maximum(abs, Float64.(X)'*Float64.(y))/norm(Float64.(y)))
    (isfinite(λ) && λ > 0) || (println("skip ", T, " ", lab, " n=", n, " p=", p); continue)
    res = [one(PS, X, y, λ) for (_, PS) in SIDES]; res = [one(PS, X, y, λ) for (_, PS) in SIDES]       # warm
    OFFR[] = 0; RECOMP[] = 0; one(Instr.ProximalSolvers, X, y, λ); offr, rec = OFFR[], RECOMP[]
    samebits = all(r -> Float64.(r[4]) == Float64.(res[1][4]), res)
    t = zeros(3, ROUNDS)
    for r in 1:ROUNDS, i in circshift(1:3, r)
      best = typemax(UInt64)
      for _ in 1:BATCHES; best = min(best, one(SIDES[i][2], X, y, λ)[1]); end
      t[i, r] = best
    end
    med(v) = sort(v)[(length(v) + 1) ÷ 2]
    @printf("%s %-28s n=%4d p=%3d offrange visits %6d (recompute %6d) passes %s conv %s  base0 %9.1f µs  head/base0 %.3f [%.3f, %.3f]  base1/base0 %.3f [%.3f, %.3f]  x bits equal: %s\n",
            T, lab, n, p, offr, rec, join((r[2] for r in res), "|"), join((r[3] for r in res), "|"), med(t[1, :])/1e3,
            med(t[3, :] ./ t[1, :]), minimum(t[3, :] ./ t[1, :]), maximum(t[3, :] ./ t[1, :]),
            med(t[2, :] ./ t[1, :]), minimum(t[2, :] ./ t[1, :]), maximum(t[2, :] ./ t[1, :]), samebits)
    flush(stdout)
  end
end
# Step-level cells: every visit goes through `_sqrt_offrange_step`; with the residual reset before each visit to y (near-parallel to
# every column of the collinear design: the recompute branch runs in every visit) or to a general residual (it does not).
# Inlined caller-shaped loop over the p columns of one model, the same loop for the three trees.
function setupm(PS, X::Matrix{T}, y, λ) where T
  x = SparseIterate(zeros(T, size(X, 2)))
  m = PS.cdmodel(SqrtLeastSquaresLoss(y, X), x); PS.initialize!(m, x); g = NormL1(λ); PS._prepare!(m, g, x); m, g, x
end
function visits!(cs::F, m, g, x, r0, p, reps) where F
  T = eltype(r0)
  for _ in 1:reps, k in 1:p
    copyto!(m.ls.r, r0); x[k] = zero(T)
    cs(m, g, x, k)
  end
  nothing
end
function steps_main()
  println("# step-level loops (reset + one visit per column; the reset is in all three loops)")
  for T in (Float32, Float64), (n, p, par) in ((30, 10, :col), (200, 40, :col), (1000, 100, :col), (200, 40, false), (1000, 100, false))
    sc = T === Float32 ? -70 : -520
    X, y = data(T, n, p, sc, par)
    λ = T(0.3*sqrt(maximum(sum(abs2, Float64.(X); dims = 1))))
    ms = [setupm(PS, X, copy(y), λ) for (_, PS) in SIDES]
    for (i, (_, PS)) in enumerate(SIDES); visits!(PS.coordinate_step!, ms[i]..., y, p, 3); end
    insm = setupm(Instr.ProximalSolvers, X, copy(y), λ); OFFR[] = 0; RECOMP[] = 0; visits!(Instr.ProximalSolvers.coordinate_step!, insm..., y, p, 1); offr, rec = OFFR[], RECOMP[]
    reps = max(1, 20000 ÷ (n*p ÷ 10 + 1))
    t = zeros(3, ROUNDS)
    for r in 1:ROUNDS, i in circshift(1:3, r)
      best = typemax(UInt64); cs = SIDES[i][2].coordinate_step!
      for _ in 1:BATCHES; t0 = time_ns(); visits!(cs, ms[i]..., y, p, reps); best = min(best, time_ns() - t0); end
      t[i, r] = best
    end
    med(v) = sort(v)[(length(v) + 1) ÷ 2]
    @printf("%s %-26s n=%4d p=%3d visits/loop %5d: offrange %5d recompute %5d  base0 %8.2f µs/visit  head/base0 %.3f [%.3f, %.3f]  base1/base0 %.3f [%.3f, %.3f]\n",
            T, par === :col ? "collinear (recompute)" : "general (no recompute)", n, p, p*reps, offr, rec, med(t[1, :])/1e3/(p*reps),
            med(t[3, :] ./ t[1, :]), minimum(t[3, :] ./ t[1, :]), maximum(t[3, :] ./ t[1, :]),
            med(t[2, :] ./ t[1, :]), minimum(t[2, :] ./ t[1, :]), maximum(t[2, :] ./ t[1, :]))
    flush(stdout)
  end
end
with_logger(NullLogger()) do; main(); steps_main(); end
