# #311 reproducer: the §18 Float32 reciprocal-overflow fixture of test/cd_numerics.jl, solved in
# every start/order/storage combination, with an independent BigFloat-256 KKT and objective oracle.
# Usage: julia --project=<worktree> repro311.jl [K ...]   (K = forced-full-pass intervals; needs the
# experimental _FULL_PASS_INTERVAL Ref; "master" or no argument = the unmodified schedule)
using LinearAlgebra, Random, ProximalBase, ProximalSolvers, Printf
using Logging
const PS = ProximalSolvers

# --- pass counters (override of _pass! with the same body plus counting) ---
const NFULL = Ref(0); const NACTIVE = Ref(0)
@eval PS function _pass!(x, m, g, st::_CDState{T}, full::Bool, scaled::Bool) where {T}
  full ? ($NFULL[] += 1) : ($NACTIVE[] += 1)
  maxh = if full
    _sweep!(x, m, g, st, scaled, Base.OneTo(ncoordinates(x)))
  else
    _sweep!(x, m, g, st, scaled, activecoordinates(x))
  end
  dropzeros!(x)
  maxh
end

# --- fixture, copied from test/cd_numerics.jl (scaled_problem, penalty_fraction) ---
function scaled_problem(::Type{T}, target; xscale = 1.0, zero_column = false) where T
  rng = Xoshiro(99)
  X = randn(rng, 30, 3) * [1 0.5 0.3; 0 1 0.5; 0 0 1]
  y = X * [1.0, -2.0, 0.5] .+ 0.01 .* randn(rng, 30)
  c = target / norm(y)
  zero_column && (X = hcat(X, zeros(30)))
  Matrix{T}(xscale .* X), Vector{T}(c .* y), c / xscale
end
penalty_fraction(T, X, y, α, fraction) = iszero(fraction) ? zero(T) :
  setprecision(BigFloat, 256) do
    T(big(fraction) * maximum(abs, big(α) .* (big.(X)' * big.(y))))
  end
# independent oracle: KKT violation relative to max(λ, ‖α Xᵀy‖∞) (kkt_relative of the tests) and
# the objective in BigFloat-256
kkt_relative(X, y, α, λ, x) = setprecision(BigFloat, 256) do
  Xb, yb, xb, ab, lb = big.(X), big.(y), big.(x), big(α), big(λ)
  d = ab .* (Xb' * (Xb * xb .- yb))
  v = maximum(j -> iszero(xb[j]) ? max(abs(d[j]) - lb, 0) : abs(d[j] + lb * sign(xb[j])), eachindex(xb))
  Float64(v / max(lb, maximum(abs, ab .* (Xb' * yb))))
end
objective_big(X, y, α, λ, x) = setprecision(BigFloat, 256) do
  Xb, yb, xb = big.(X), big.(y), big.(x)
  big(α) * sum(abs2, yb .- Xb * xb) / 2 + big(λ) * sum(abs, xb)
end
# BigFloat-256 reference minimizer by cyclic CD (as reference_lasso in the tests)
function reference_lasso(X, y, α, λ; passes = 400)
  setprecision(BigFloat, 256) do
    Xb, ab, lb = big.(X), big(α), big(λ)
    b, r = zeros(BigFloat, size(X, 2)), big.(y)
    a = [sum(abs2, Xb[:, k]) for k in axes(X, 2)]
    for _ in 1:passes, k in axes(X, 2)
      iszero(a[k]) && continue
      z = b[k] + sum(Xb[i, k] * r[i] for i in eachindex(r)) / a[k]
      t = lb / (ab * a[k]); new = sign(z) * max(abs(z) - t, 0)
      r .-= Xb[:, k] .* (new - b[k]); b[k] = new
    end
    b
  end
end

const ORDERS = ((:cyclic, nothing), (:random, nothing), (:random, false))

function run1(f, λ, x0; order, momentum, owner, tol = 1e-7, maxpasses = 2000, seed = 5)
  solver = CDSolver(; order, momentum, maxpasses, tol, relative = true, rng = Xoshiro(seed))
  x = owner ? SparseIterate(copy(x0)) : copy(x0)
  NFULL[] = 0; NACTIVE[] = 0
  r = with_logger(NullLogger()) do
    solve!(x, f, NormL1(λ), solver)
  end
  (; x = Vector(x), r.passes, r.converged, r.maxchange, r.tolerance, nfull = NFULL[], nactive = NACTIVE[])
end

function main(Ks)
  T = Float32
  X, y, c = scaled_problem(T, 100.0; xscale = 3e-6)
  α = 1f-30
  f = α * LeastSquaresLoss(y, X)
  λ = penalty_fraction(T, X, y, α, 0.5)
  p = size(X, 2)
  b = reference_lasso(X, y, α, λ)
  Fstar = objective_big(X, y, α, λ, b)
  @printf "Julia %s  coverage=%d  λ=%.6g  ref x*=%s  KKT(ref)=%.2e\n" VERSION Base.JLOptions().code_coverage λ string(Float64.(b)) kkt_relative(X, y, α, λ, Float32.(b))
  hasK = isdefined(PS, :_FULL_PASS_INTERVAL) && PS._FULL_PASS_INTERVAL isa Ref
  for K in Ks
    if K == "master"
      hasK && (PS._FULL_PASS_INTERVAL[] = typemax(Int))
    else
      hasK || error("K given but _FULL_PASS_INTERVAL not defined (master build)")
      PS._FULL_PASS_MODE[] = startswith(K, "w") ? :work : :passes
      PS._FULL_PASS_INTERVAL[] = parse(Int, lstrip(K, 'w'))
    end
    println("== schedule: K = $K")
    @printf "%-5s %-7s %-6s %-5s | %-5s %6s %5s %6s %10s %10s %10s | restart: %-5s %5s %10s\n" "start" "order" "mom" "owner" "conv" "passes" "full" "active" "KKT" "relgapF" "maxch/tol" "conv" "pass" "KKT"
    for (sname, x0) in (("cold", zeros(T, p)), ("warm", T.(c .* (0.3 .* sin.(1:p))))),
        (order, momentum) in ORDERS, owner in (false, true)
      r = run1(f, λ, x0; order, momentum, owner)
      kkt = kkt_relative(X, y, α, λ, r.x)
      gap = Float64((objective_big(X, y, α, λ, r.x) - Fstar) / abs(Fstar))
      rr = run1(f, λ, T.(r.x); order, momentum, owner)
      @printf "%-5s %-7s %-6s %-5s | %-5s %6d %5d %6d %10.2e %10.2e %10.2e | restart: %-5s %5d %10.2e\n" sname order string(momentum) owner r.converged r.passes r.nfull r.nactive kkt gap r.maxchange / r.tolerance rr.converged rr.passes kkt_relative(X, y, α, λ, rr.x)
    end
  end
  # tol = 1e-6 control, warm/random/momentum=false/dense (the issue's configuration)
  hasK && (PS._FULL_PASS_INTERVAL[] = typemax(Int))
  r = run1(f, λ, T.(c .* (0.3 .* sin.(1:p))); order = :random, momentum = false, owner = false, tol = 1e-6)
  @printf "control tol=1e-6 (warm,random,false,dense, master schedule): conv=%s passes=%d KKT=%.2e\n" r.converged r.passes kkt_relative(X, y, α, λ, r.x)
end

main(isempty(ARGS) ? ["master"] : ARGS)
