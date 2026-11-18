include("lib.jl")
# E5: random stress of the real coordinate step (one column), wide independent scales, near-parallel residuals,
# lambda near sqrt(a). Reports max excess/bound by branch and every violation (ratio > 1) or non-finite result.
function onecol(T, rng)
  n = rand(rng, 2:12)
  lo, hi = T === Float32 ? (-75, 60) : (-520, 500)
  sx = rand(rng, lo:hi); sr = rand(rng, lo:hi)
  xk = T.(ldexp.(randn(rng, n), sx))
  mode = rand(rng, 0:3)
  u = randn(rng, n)
  if mode == 0; ρ = u
  elseif mode == 1; ρ = randn(rng) .* (xk ./ maximum(abs, xk)) .+ 10.0^(-rand(rng)*12) .* u
  elseif mode == 2; ρ = randn(rng) .* (xk ./ maximum(abs, xk))
  else ρ = u .* 10.0 .^ (rand(rng, n) .* 8 .- 4); end
  ρ = T.(ldexp.(ρ, sr))
  (all(isfinite, xk) && all(isfinite, ρ) && any(!iszero, xk)) || return nothing
  ra = sqrt(sum(abs2, Float64.(xk)))
  fk = rand(rng, 1:3)
  f = fk == 1 ? 10.0^(-8*rand(rng)) : fk == 2 ? 1 - 2.0^(-rand(rng, 1:50)) : rand(rng)
  λ = T(f*ra)
  (isfinite(λ) && λ > 0) || return nothing
  old = rand(rng) < 0.5 ? zero(T) : T(ldexp(randn(rng), rand(rng, -20:20) + (sr - sx)))
  isfinite(old) || return nothing
  # model: y chosen so that r = y - x*old equals roughly rho: use y = rho + x*old (rounded) -> r is whatever the model holds
  y = ρ .+ xk .* old
  all(isfinite, y) || return nothing
  (xk, y, λ, old, mode, f)
end
