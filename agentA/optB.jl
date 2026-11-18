# Option B prototype (B1) as an overlay on ProximalSolvers (evaluated at run time, nothing on disk is changed):
# the fast path of _sqrt_minimizer is kept VERBATIM (src/cd/sqrtlasso.jl:178-199) except
#   - the three calls of _sqrt_offrange_step are replaced by the refusal _B_unclean/_B_refuse (r == 0 handled),
#   - the band (_sqrt_band_step) is replaced by the refusal, except d == 0 (prox_block at step γ = 0 returns c).
const B_ACTIVE = Ref(false)
function install_B1!()
  Core.eval(PS, quote
    @inline function _sqrt_minimizer(m::SqrtLSModel{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T
      ls = m.ls
      n = length(ls.r)
      (_clean_sum(a, n) & _clean_sum(ρ2, n)) || return _B_unclean(m, old, a, k)
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
        prox_block(m.gt, c, k, γ) : _B_refuse(T, k)
    end
    @noinline function _B_unclean(m, old::T, a, k) where T
      ls = m.ls
      n = length(ls.r)
      if _clean_sum(a, n) && all(iszero, ls.r)      # r = 0: the minimizer is 0 for λ ≥ √a, else old
        return m.gt.λ0 >= sqrt(a) ? zero(T) : old
      end
      _B_refuse(T, k)
    end
    @noinline _B_refuse(::Type{T}, k) where T =
      throw(ArgumentError("the coordinate step of coordinate $k is outside the supported range of $T (the column or the residual squares leave the normal range); rescale the data"))
  end)
  B_ACTIVE[] = true
end
