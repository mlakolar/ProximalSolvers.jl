# C4 prototype in-process: overwrite `_sqnorm!` with a pairwise/SIMD sum (method redefinition in the live module; no file edited) and time the
# real `_prepare!` (production code path: singleton groups) before/after, A/B/A in one process, plus the curvature bits that change.
using ProximalSolvers, ProximalBase, Random, Printf, Logging
const PS = ProximalSolvers
function setup(T, n, p)
  rng = Xoshiro(1); X = randn(rng, T, n, p); y = randn(rng, T, n)
  f = LeastSquaresLoss(y, X)
  groups = [[i] for i in 1:p]
  g = GroupNormL2(T(0.3*maximum(abs.(X'*y))), groups)
  x = BlockIterate(T, p, g)
  m = PS.cdmodel(f, x); PS.initialize!(m, x); PS._prepare!(m, g, x)
  m, g, x, f
end
function prep_min(m, g, x; reps=30)
  t = Inf
  for _ in 1:reps; PS.initialize!(m, x); t = min(t, @elapsed PS._prepare!(m, g, x)); end
  t
end
old_ell(m) = copy(m.ℓ)
const OLD = Dict{Any,Any}()
for T in (Float32, Float64), (n, p) in ((100, 200), (1000, 1000), (10000, 200))
  m, g, x, f = setup(T, n, p)
  t_old1 = prep_min(m, g, x); ℓold = old_ell(m)
  # new method
  @eval PS function _sqnorm!(m::LSModel{T}, k::Int) where T
    a = m.a[k]
    if isnan(a)
      a = sum(abs2, view(m.X, :, k))
      m.a[k] = a
    end
    a
  end
  t_new = prep_min(m, g, x); ℓnew = old_ell(m)
  Base.invokelatest(() -> nothing)
  # restore the production definition
  @eval PS function _sqnorm!(m::LSModel{T}, k::Int) where T
    a = m.a[k]
    if isnan(a)
      a = zero(T)
      @inbounds for i in axes(m.X, 1)
        a += m.X[i, k]*m.X[i, k]
      end
      m.a[k] = a
    end
    a
  end
  t_old2 = prep_min(m, g, x)
  nd = count(ℓold .!= ℓnew); maxrel = maximum(abs.(ℓold .- ℓnew) ./ ℓold)
  @printf("%s n=%d p=%d singletons: _prepare! old %.3f ms, new %.3f ms, old again %.3f ms (new/old %.3f);  ℓ differs in %d/%d groups, max relative change %.2e\n", T, n, p, 1e3t_old1, 1e3t_new, 1e3t_old2, t_new/min(t_old1, t_old2), nd, p, maxrel)
end
