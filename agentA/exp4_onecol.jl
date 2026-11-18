include("lib.jl")
if get(ENV, "OVERLAY", "") != ""
  include("optB.jl"); include("optC.jl"); include("optC2.jl")
  ENV["OVERLAY"] == "C" ? install_C!() : ENV["OVERLAY"] == "C2" ? install_C2!() : install_B1!()
end
# E4: one-column coordinate problems on a (column scale, residual scale) grid.
# Compares, per trial, excess/bound (BigFloat 512 reference, test-suite bound) of
#   real   : PS.coordinate_step! (the production code)
#   fast   : the fast-path of _sqrt_minimizer VERBATIM minus the _clean_sum tests (band kept)   [Option B-lite]
#   naive  : fast path with the band replaced by shrink(c, γ*λ) formed in T (no _sqrt_band_step)  [Option B-min]
# fast/naive are copies of the lines of _sqrt_minimizer (src/cd/sqrtlasso.jl:178-199) as noted.
function fast_only(m, old::T, a::T, b::T, ρ2::T, k, naive) where T
  ls = m.ls
  λ = m.gt.λ0
  ra = sqrt(a)
  λ >= ra && return zero(T)
  q = b/a
  c = old + q
  d2 = ρ2 - b*q
  if d2 < ρ2/16
    d2 = PS._distance_sqr(ls.X, ls.r, k, q)
  end
  d = sqrt(d2)
  p = ra*(sqrt(ra - λ)*sqrt(ra + λ))
  γ = d/p
  τ = γ*λ
  if naive
    return PS.shrink(c, τ)
  end
  ((floatmin(T) <= p) & (floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T))) ?
    prox_block(m.gt, c, k, γ) : PS._sqrt_band_step(c, ra, λ, Float64(d), 0)
end

function trial(T, n, sx, sr, mode, f, rng)
  xk = T.(ldexp.(randn(rng, n), sx))
  ρ = randn(rng, n)
  if mode == 1       # nearly parallel
    ρ = (randn(rng) .* (xk ./ maximum(abs, xk))) .+ 1e-3 .* ρ
  elseif mode == 2   # exactly parallel (up to rounding)
    ρ = randn(rng) .* (xk ./ maximum(abs, xk))
  end
  ρ = T.(ldexp.(ρ, sr))
  (all(isfinite, xk) && all(isfinite, ρ) && any(!iszero, xk)) || return nothing
  a64 = sum(abs2, Float64.(xk))   # to choose λ
  ra = sqrt(a64)
  λ = T(f * ra)
  (isfinite(λ) && λ > 0) || return nothing
  X = reshape(copy(xk), n, 1); y = copy(ρ)
  old = zero(T)
  m, g, x = make_model(X, y, λ)
  r = copy(m.ls.r)     # residual as the model holds it (old = 0: r = y)
  # real
  mr, gr, xr = make_model(X, y, λ)
  br = classify(mr, gr, xr, 1)
  err = nothing
  zreal = try; PS.coordinate_step!(mr, gr, xr, 1); xr[1]; catch e; err = e; T(NaN); end
  a, b, ρ2 = PS._column_dot_rsqr(m.ls.X, m.ls.r, 1, m.ls.a[1])
  zfast = (isfinite(a) && !iszero(a)) ? try; fast_only(m, old, a, b, ρ2, 1, false); catch; T(NaN); end : T(NaN)
  znaive = (isfinite(a) && !iszero(a)) ? try; fast_only(m, old, a, b, ρ2, 1, true); catch; T(NaN); end : T(NaN)
  ref = bigref(xk, r, old, m.gt.λ0)
  function ratio(z)
    isfinite(z) || return Inf
    setprecision(BigFloat, 512) do
      exc = ref.φ(big(z)) - ref.φmin
      bd = step_bound(T, n, ref.ρn, ref.rn, ref.a, m.gt.λ0)
      Float64(exc)/bd
    end
  end
  (br = br, err = err, real = err === nothing ? ratio(zreal) : NaN, fast = ratio(zfast), naive = ratio(znaive))
end

function main()
  println("# E4 one-column grid: cell = column scale 2^sx, residual scale 2^sr; entries: worst excess/bound over 3 modes x 3 lambda fractions")
  println("# columns: T sx sr | branches seen | real | fast(B-lite) | naive(B-min) | errors")
  steps = Dict(Float32 => (-100:10:70), Float64 => (-600:50:560))
  for T in (Float32, Float64)
    for sx in steps[T], sr in steps[T]
      rng = Xoshiro(hash((sx, sr)))
      cnt = Dict{Symbol,Int}(); wr = 0.0; wf = 0.0; wn = 0.0; errs = Set{String}(); nt = 0
      for n in (6,), mode in (0, 1, 2), f in (0.3, 0.9, 0.999)
        t = Base.invokelatest(trial, T, n, sx, sr, mode, f, rng)
        t === nothing && continue
        nt += 1
        cnt[t.br] = get(cnt, t.br, 0) + 1
        t.err === nothing ? (wr = max(wr, t.real)) : push!(errs, first(split(sprint(showerror, t.err), '\n'))[1:min(end,50)])
        wf = max(wf, t.fast); wn = max(wn, t.naive)
      end
      nt == 0 && continue
      @printf("%s sx=%d sr=%d | %s | real=%.2e | fast=%.2e | naive=%.2e | %s\n", T, sx, sr, fmtcnt(cnt), wr, wf, wn, join(errs, ";"))
    end
  end
end
main()
