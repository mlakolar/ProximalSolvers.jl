# Option C2 prototype overlay: ONE formula (the verbatim fast path of _sqrt_minimizer, src/cd/sqrtlasso.jl:178-199, factored into a function of
# (X, r, penalty, ...)). Exceptional exits:
#   Float32 -> the same formula re-run in Float64 on Float64 copies of column k and of r (cannot leave the Float64 range), result rounded once;
#   Float64 -> r = 0 handled, otherwise a refusal.
function install_C2!()
  Core.eval(PS, quote
    @inline _sqrt_minimizer(m::SqrtLSModel{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T =
      _sqrt_step(m.ls.X, m.ls.r, m.gt, old, a, b, ρ2, k)
    @inline function _sqrt_step(X, r, g, old::T, a::T, b::T, ρ2::T, k::Int) where T
      n = length(r)
      (_clean_sum(a, n) & _clean_sum(ρ2, n)) || return _sqrt_cold(X, r, g, old, k)
      λ = g.λ0
      ra = sqrt(a)
      λ >= ra && return zero(T)
      q = b/a
      c = old + q
      d2 = ρ2 - b*q
      if d2 < ρ2/16
        d2 = _distance_sqr(X, r, k, q)
      end
      d = sqrt(d2)
      p = ra*(sqrt(ra - λ)*sqrt(ra + λ))
      γ = d/p
      τ = γ*λ
      ((floatmin(T) <= p) & (iszero(d) | ((floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T))))) ?
        prox_block(g, c, k, γ) : _sqrt_cold(X, r, g, old, k)
    end
    @noinline function _sqrt_cold(X::AbstractMatrix{Float32}, r, g, old::Float32, k::Int)
      Xw = reshape(Float64.(view(X, :, k)), :, 1)
      rw = Float64.(r)
      a, b, ρ2 = _column_dot_rsqr(Xw, rw, 1, NaN)
      Float32(_sqrt_step(Xw, rw, NormL1(Float64(g.λ0)), Float64(old), a, b, ρ2, 1))
    end
    @noinline function _sqrt_cold(X, r, g, old::Float64, k::Int)
      a = sum(abs2, view(X, :, k))
      _clean_sum(a, length(r)) && all(iszero, r) && return g.λ0 >= sqrt(a) ? 0.0 : old
      throw(ArgumentError("the coordinate step of coordinate $k is outside the supported range of Float64 (the column or the residual squares leave the normal range); rescale the data"))
    end
  end)
end
