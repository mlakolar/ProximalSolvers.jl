# Warmed @allocated (min of 7 after 2 warm calls) of the main PB private kernels and PS helpers, evaluated in a
# function whose type parameter T is static (a Type passed through varargs would be dispatched dynamically and allocate).
using ProximalBase, ProximalSolvers, Random, LinearAlgebra
const PB = ProximalBase; const PS = ProximalSolvers
println("Julia ", VERSION)
macro al(ex)
  quote
    $(esc(ex)); $(esc(ex))
    m = typemax(Int)
    for _ in 1:7
      a = @allocated $(esc(ex))
      m = min(m, a)
    end
    m
  end
end
function measure(::Type{T}) where {T}
  rng = MersenneTwister(3)
  rows = Tuple{String,String,Int}[]
  n = 1000
  x = randn(rng, T, n); y = randn(rng, T, n); G = collect(1:n); z0 = zeros(T, n)
  xbig = x .* T(2)^(exponent(floatmax(T)) - 10)
  tiny = x .* T(2)^(T === Float64 ? -540 : -70)
  X = randn(rng, T, n, 8); Y = randn(rng, T, n); Z = X * randn(rng, T, 8); r = randn(rng, T, n)
  c = T(0.3); sT = T(Inf)
  fls = PB.LeastSquaresLoss(Y, X); sls = PB.SqrtLeastSquaresLoss(Y, X)
  g = zeros(T, 8); d = zeros(T, n)
  add(p, nm, a) = push!(rows, (p, "$nm [$T]", a))
  add("PB", "shrink(v,c)", @al(PB.shrink(c, c)))
  add("PB", "norm_diff(x,y) ordinary", @al(PB.norm_diff(x, y)))
  add("PB", "norm_diff(xbig,0) exceptional", @al(PB.norm_diff(xbig, z0)))
  add("PB", "norm_diff(tiny,0) exceptional", @al(PB.norm_diff(tiny, z0)))
  add("PB", "value_from_residual(LS, r)", @al(PB.value_from_residual(fls, r)))
  add("PB", "value_from_residual(SqrtLS, r)", @al(PB.value_from_residual(sls, r)))
  add("PB", "value_from_residual(SqrtLS, xbig)", @al(PB.value_from_residual(sls, xbig)))
  add("PB", "value_from_residual(SqrtLS, tiny)", @al(PB.value_from_residual(sls, tiny)))
  add("PB", "value_from_predictor(LS, z)", @al(PB.value_from_predictor(fls, Z)))
  add("PB", "value_and_gradient_from_predictor!", @al(PB.value_and_gradient_from_predictor!(g, d, fls, Z)))
  add("PB", "opnorm2(X) (Lanczos; documented to allocate)", @al(PB.opnorm2(X)))
  add("PB", "_shrink_nonneg", @al(PB._shrink_nonneg(c, c)))
  add("PB", "_positive_product", @al(PB._positive_product(c, c, c)))
  add("PB", "_threshold_product", @al(PB._threshold_product(T, c, c, c)))
  add("PB", "_scaled_product(a,b,c,k) ordinary", @al(PB._scaled_product(c, c, c, 3)))
  add("PB", "_scaled_product(a,b,c,k) k=3000", @al(PB._scaled_product(c, c, c, 3000)))
  add("PB", "_compensated_add", @al(PB._compensated_add(c, c, c)))
  add("PB", "_power_factors(T,5)", @al(PB._power_factors(T, 5)))
  add("PB", "_squares_normal", @al(PB._squares_normal(c, 1000, T)))
  add("PB", "_sumabs2(x)", @al(PB._sumabs2(x)))
  add("PB", "_sumabs2_diff(x,y)", @al(PB._sumabs2_diff(x, y)))
  add("PB", "_maximum_abs(x)", @al(PB._maximum_abs(x)))
  add("PB", "_all_zero(x)", @al(PB._all_zero(x)))
  add("PB", "_square_exponent(x,nothing,T)", @al(PB._square_exponent(x, nothing, T)))
  add("PB", "_residual_squares(x,nothing,T)", @al(PB._residual_squares(x, nothing, T)))
  add("PB", "_residual_squares(x,nothing,Float64)", @al(PB._residual_squares(x, nothing, Float64)))
  add("PB", "_residual_squares(x,y,T)", @al(PB._residual_squares(x, y, T)))
  add("PB", "_scaled_norm(xbig,nothing,s)", @al(PB._scaled_norm(xbig, nothing, sT)))
  add("PB", "_indexed_sumabs2(x,G,T)", @al(PB._indexed_sumabs2(x, G, T)))
  add("PB", "_l2_classified_norm(x,G,Float64)", @al(PB._l2_classified_norm(x, G, Float64)))
  add("PB", "_pow2_sum(T,(m,e),(m,e))", @al(PB._pow2_sum(T, (c, 3), (c, -2))))
  ea = PB._expsum_start(T)
  add("PB", "_expsum_add", @al(PB._expsum_add(ea, c, 5)))
  add("PS", "_se_norm(T,x)", @al(PS._se_norm(T, x)))
  add("PS", "_se_norm(T,xbig)", @al(PS._se_norm(T, xbig)))
  add("PS", "_se_norm_diff(T,a,b)", @al(PS._se_norm_diff(T, x, y)))
  se1 = PS._SE{T}(c); se2 = PS._SE{T}(T(0.7))
  add("PS", "_se_mul(a,b)", @al(PS._se_mul(se1, se2)))
  add("PS", "_se_mul(a,b,c,d)", @al(PS._se_mul(se1, se2, se1, se2)))
  add("PS", "_se_add", @al(PS._se_add(se1, se2)))
  add("PS", "_se_sub", @al(PS._se_sub(se2, se1)))
  add("PS", "_se_le", @al(PS._se_le(se1, se2)))
  add("PS", "_sumsq_scaled(v,m)", @al(PS._sumsq_scaled(x, T(4))))
  add("PS", "_sumsq2(d,x)", @al(PS._sumsq2(x, y)))
  add("PS", "_sumsq_diff(a,b)", @al(PS._sumsq_diff(x, y)))
  s1 = sum(abs2, x)
  add("PS", "_se_norm_onepass(T,s,v)", @al(PS._se_norm_onepass(T, s1, x)))
  add("PS", "_maxabs_diff", @al(PS._maxabs_diff(x, y)))
  add("PS", "_scaled_norm(v,n) (sqrtlasso)", @al(PS._scaled_norm(x, n)))
  add("PS", "_column_dot_rsqr", @al(PS._column_dot_rsqr(X, r, 3, T(NaN))))
  add("PS", "_distance_sqr", @al(PS._distance_sqr(X, r, 3, c)))
  add("PS", "_clean_sum", @al(PS._clean_sum(c, n)))
  add("PS", "_frobenius_upper(T,X)", @al(PS._frobenius_upper(T, X)))
  add("PS", "_root_scale(T,α)", @al(PS._root_scale(T, c)))
  add("PS", "_root_scale(T,α=BigFloat) (once per solve)", @al(PS._root_scale(T, big(0.3))))
  rows
end
function measure2()
  rows = Tuple{String,String,Int}[]
  push!(rows, ("PS", "_level_brackets(0.3)", @al(PS._level_brackets(0.3))))
  push!(rows, ("PS", "_round_up(Float32, v)", @al(PS._round_up(Float32, 0.1))))
  push!(rows, ("PS", "_up(z)", @al(PS._up(0.1))))
  rows
end
rows = vcat(measure(Float32), measure(Float64), measure2())
for (p, nm, a) in rows
  println(rpad(p, 3), rpad(nm, 56), a, " B")
end
