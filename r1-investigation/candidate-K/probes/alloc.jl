# X1 experiment 6: allocations. All @allocated measured inside functions after warmup. julia --project=ps-353 exp6_alloc.jl
include("r1lib.jl")
function mk(P, X::Matrix{T}, y::Vector{T}, λ) where T
  f = SqrtLeastSquaresLoss(y, X); x = SparseIterate(zeros(T, size(X, 2)))
  m = P.cdmodel(f, x); P.initialize!(m, x); g = NormL1(λ); P._prepare!(m, g, x); m, g, x
end
function passes!(cs::F, m, g, x, p, reps) where F
  for _ in 1:reps, k in 1:p; cs(m, g, x, k); end
  nothing
end
dosolve(solve::F, mk::C, T, X, y, λ, p; order) where {F,C} = (xs = zeros(T, p); solve(xs, SqrtLeastSquaresLoss(y, X), NormL1(λ), mk(; order, rng = Xoshiro(5))); nothing)
dosolve_sp(solve::F, mk::C, T, X, y, λ, p; order) where {F,C} = (xs = SparseIterate(zeros(T, p)); solve(xs, SqrtLeastSquaresLoss(y, X), NormL1(λ), mk(; order, rng = Xoshiro(5))); nothing)
println("# Julia ", VERSION)
for T in (Float32, Float64)
  rng = Xoshiro(3); n, p = 500, 40
  X = randn(rng, T, n, p); y = randn(rng, T, n); λ = T(0.3 * norm(Float64.(X)' * Float64.(y), Inf) / norm(Float64.(y)))
  for t in TNAMES
    P = getproperty(TREES, t); cs = P.coordinate_step!
    m, g, x = mk(P, X, y, λ); for _ in 1:30; passes!(cs, m, g, x, p, 1); end
    b1 = @allocated passes!(cs, m, g, x, p, 1)
    b2 = @allocated passes!(cs, m, g, x, p, 20)
    sv, cd = P.solve!, P.CDSolver
    dosolve(sv, cd, T, X, y, λ, p; order = :cyclic); sd = @allocated dosolve(sv, cd, T, X, y, λ, p; order = :cyclic)
    dosolve_sp(sv, cd, T, X, y, λ, p; order = :random); ss = @allocated dosolve_sp(sv, cd, T, X, y, λ, p; order = :random)
    @printf("%-8s %-5s ordinary: 1 pass of %d visits = %d B, 20 passes = %d B; warmed solve! dense cyclic = %d B; sparse random(momentum) = %d B\n", T, t, p, b1, b2, sd, ss)
  end
  # cold path per visit
  for (label, Xc, yc) in (("tiny residual (rho^2 unclean)", X, T.(ldexp.(y, T === Float32 ? -70 : -520))),
                          ("tiny column (a unclean)", T.(ldexp.(X, T === Float32 ? -70 : -520)), y),
                          ("huge residual (rho^2 overflow, F32 only)", X, T.(ldexp.(y, T === Float32 ? 100 : 505))))
    T === Float64 && occursin("huge", label) && continue
    λc = T(0.3 * norm(Float64.(Xc)' * Float64.(yc), Inf) / norm(Float64.(yc)))
    for t in TNAMES
      P = getproperty(TREES, t); cs = P.coordinate_step!
      m, g, x = try mk(P, Xc, yc, λc) catch e; println("   ", T, " ", t, " ", label, ": setup throws"); continue end
      ok = try passes!(cs, m, g, x, p, 3); true catch e; false end
      ok || (println(@sprintf("   %-8s %-5s cold [%s]: refused (throws)", T, t, label)); continue)
      passes!(cs, m, g, x, p, 3)
      bytes = @allocated passes!(cs, m, g, x, p, 50)
      @printf("   %-8s %-5s cold [%s]: %d visits, %d B total = %.1f B/visit\n", T, t, label, 50p, bytes, bytes/(50p))
    end
  end
  # r = 0 exactly (Float64 cold r=0 path; Float32 widening path with r = 0)
  yz = zeros(T, n)
  for t in TNAMES
    P = getproperty(TREES, t); cs = P.coordinate_step!; m, g, x = mk(P, X, yz, T(0.3)); passes!(cs, m, g, x, p, 3)
    bytes = @allocated passes!(cs, m, g, x, p, 50)
    @printf("   %-8s %-5s r = 0: %d visits, %d B\n", T, t, 50p, bytes)
  end
end
# the band exit (cold) per visit: a, ρ² clean, γ beyond the range of T
for T in (Float32, Float64)
  rng = Xoshiro(9); n, p = 200, 20
  sx, sr = T === Float32 ? (-48, 50) : (-482, 500)
  Xb = T.(ldexp.(randn(rng, n, p), sx)); yb = T.(ldexp.(randn(rng, n), sr)); λb = T(0.3 * norm(Float64.(Xb)' * Float64.(yb), Inf) / norm(Float64.(yb)))
  for t in TNAMES
    P = getproperty(TREES, t); cs = P.coordinate_step!
    m, g, x = try mk(P, Xb, yb, λb) catch e; println("   ", T, " ", t, " band: setup throws"); continue end
    ok = try passes!(cs, m, g, x, p, 3); true catch e; false end
    ok || (println(@sprintf("   %-8s %-5s band: refused (throws)", T, t)); continue)
    passes!(cs, m, g, x, p, 3)
    bytes = @allocated passes!(cs, m, g, x, p, 50)
    @printf("   %-8s %-5s band: %d visits, %d B total\n", T, t, 50p, bytes)
  end
end
