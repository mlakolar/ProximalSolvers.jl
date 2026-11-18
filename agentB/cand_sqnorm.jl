# Candidate C4/C5: `_sqnorm!` (in-order Σx², no @simd) and `_flat_column`. (a) the singleton margin ℓ = nextfloat(a(1+2n eps)) ≥ exact Σx²
# (BigFloat 600) when `a` comes from other summation orders (@simd `_column_dot` a, `sum(abs2, view)`); (b) `_flat_column` vs all(iszero, view).
using ProximalSolvers, Random, Printf
const PS = ProximalSolvers
setprecision(BigFloat, 600)
rng = Xoshiro(5)
function margin_ok(a::T, n, exact) where T
  ℓ = nextfloat(a*(one(T) + 2n*eps(T)))
  BigFloat(ℓ) >= exact
end
tot = Dict{String,Int}(); bad = Dict{String,Int}(); maxrel = Dict{String,Float64}()
for T in (Float32, Float64), trial in 1:3000
  n = rand(rng, (3, 10, 100, 1000, 20000))
  kind = rand(rng, 1:5)
  x = kind == 1 ? randn(rng, T, n) :
      kind == 2 ? T.(randn(rng, n) .* exp2.(rand(rng, -20:20, n))) :
      kind == 3 ? randn(rng, T, n) .* (T === Float32 ? T(1e-19) : T(1e-154)) :       # squares near/below floatmin
      kind == 4 ? randn(rng, T, n) .* (T === Float32 ? T(1e-21) : T(1e-160)) :       # squares subnormal/zero
                  fill(T(1), n) .+ randn(rng, T, n) .* T(1e-3)
  exact = sum(abs2, BigFloat.(x))
  X = reshape(x, n, 1); r = zeros(T, n); m = PS.LSModel(r, X, one(T))
  av = Dict("sqnorm_inorder" => PS._sqnorm!(m, 1),
            "column_dot_simd" => PS._column_dot(X, r, 1, T(NaN))[1],
            "sum_abs2_view" => sum(abs2, view(X, :, 1)))
  for (k, a) in av
    key = "$T $k"
    a < floatmin(T) && continue          # the production code refuses a < floatmin (group path)
    isfinite(a) || continue
    tot[key] = get(tot, key, 0) + 1
    margin_ok(a, n, exact) || (bad[key] = get(bad, key, 0) + 1)
    rel = Float64(abs(BigFloat(a) - exact) / exact); maxrel[key] = max(get(maxrel, key, 0.0), rel / eps(T))
  end
end
for k in sort(collect(keys(tot))); @printf("%-28s cases %5d  margin violated %d  max |a-exact|/exact = %.1f eps\n", k, tot[k], get(bad, k, 0), maxrel[k]); end
# _flat_column vs all(iszero, view)
flat(m, k) = PS._flat_column(m, k)
for T in (Float32, Float64)
  X = zeros(T, 5, 4); X[2, 2] = T(-0.0); X[3, 3] = T(1e-45); X[1, 4] = T(NaN)
  m = PS.LSModel(zeros(T, 5), X, one(T))
  @printf("%s flat? %s vs %s\n", T, [flat(m, k) for k in 1:4], [all(iszero, view(X, :, k)) for k in 1:4])
  f2(m, k) = all(iszero, view(m.X, :, k))
  flat(m, 1); f2(m, 1)
  @printf("   @allocated _flat_column %d, all(iszero, view) %d\n", @allocated(flat(m, 1)), @allocated(f2(m, 1)))
end
