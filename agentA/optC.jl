# Option C prototype overlay: fast path of _sqrt_minimizer verbatim (src/cd/sqrtlasso.jl:178-199) except that every exceptional
# exit (a or ρ² not clean, or p/γ/τ not normal with d ≠ 0) goes to _sqrt_cold:
#   Float32 -> one plain Float64 re-evaluation (a, b, ρ², d recomputed in Float64 from the Float32 entries: no overflow/underflow is
#              possible there; ~14 lines), shrink formed in Float64 and rounded once to Float32;
#   Float64 -> r = 0 handled, otherwise a refusal ("rescale the data").
function install_C!()
  Core.eval(PS, quote
    @inline function _sqrt_minimizer(m::SqrtLSModel{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T
      ls = m.ls
      n = length(ls.r)
      (_clean_sum(a, n) & _clean_sum(ρ2, n)) || return _sqrt_cold(m, old, k)
      λ = m.gt.λ0
      ra = sqrt(a)
      λ >= ra && return zero(T)
      q = b/a
      c = old + q
      d2 = ρ2 - b*q
      if d2 < ρ2/16
        d2 = _distance_sqr(ls.X, ls.r, k, q)
      end
      d = sqrt(d2)
      p = ra*(sqrt(ra - λ)*sqrt(ra + λ))
      γ = d/p
      τ = γ*λ
      ((floatmin(T) <= p) & (iszero(d) | ((floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T))))) ?
        prox_block(m.gt, c, k, γ) : _sqrt_cold(m, old, k)
    end
    @noinline function _sqrt_cold(m::SqrtLSModel{Float32}, old::Float32, k::Int)
      ls = m.ls
      X, r = ls.X, ls.r
      a = b = ρ2 = 0.0
      @inbounds for i in eachindex(r)
        v, ri = Float64(X[i, k]), Float64(r[i])
        a += v*v; b += ri*v; ρ2 += ri*ri
      end
      λ = Float64(m.gt.λ0)
      ra = sqrt(a)
      λ >= ra && return 0.0f0
      iszero(ρ2) && return old
      q = b/a
      d2 = 0.0
      @inbounds for i in eachindex(r)
        t = Float64(r[i]) - q*Float64(X[i, k])
        d2 += t*t
      end
      τ = (λ/ra)*(sqrt(d2)/(sqrt(ra - λ)*sqrt(ra + λ)))
      c = Float64(old) + q
      Float32(sign(c)*max(abs(c) - τ, 0.0))
    end
    @noinline function _sqrt_cold(m::SqrtLSModel{Float64}, old::Float64, k::Int)
      ls = m.ls
      a = sum(abs2, view(ls.X, :, k))                     # clean a is needed even for r = 0
      if _clean_sum(a, length(ls.r)) && all(iszero, ls.r)
        return m.gt.λ0 >= sqrt(a) ? 0.0 : old
      end
      throw(ArgumentError("the coordinate step of coordinate $k is outside the supported range of Float64 (the column or the residual squares leave the normal range); rescale the data"))
    end
  end)
end
