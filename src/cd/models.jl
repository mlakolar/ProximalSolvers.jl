# Private scalar model/cache seam, including the C0 observer hooks.
abstract type CDModel{T} end
function initialize! end
_initialize!(m::CDModel, x, fresh::Bool) = initialize!(m, x)
function coordinate_step! end
coordinate_scale(m::CDModel{T}, x, k::Int) where T = one(T)
response_scale(m::CDModel{T}, x) where T = zero(T)
loss_value(m::CDModel{T}, f, x) where T = T(NaN)
function cdmodel end
# Per-solve preparation after `initialize!` and before the first pass (and its RNG draws), run
# only when `maxpasses > 0`: a model caches and validates what depends only on the data here.
_prepare!(m::CDModel, g, x) = m
# The stop check at a full pass whose largest change `maxh` is below the threshold (`_cd_plain!`,
# `_cd_momentum!`). It returns `:converged` (stop with `converged = true`), `:uncertified` (stop with
# `converged = false`) or `:retry` (the check lowered `st.tolerance`; the loop continues with it), and
# may set `st.gap` and `st.uncertified`. This method, for the models without a certificate (least
# squares, group lasso), returns the constant `:converged` and changes nothing: their stop is the
# change test. `SqrtLSModel` has its own method.
_stop_check!(m::CDModel, g, x, st, maxh) = :converged
cdmodel(f,x)=throw(ArgumentError("unsupported private coordinate-descent model"))
# The coordinate along a flat LS column (zero slope and curvature), which does not enter the loss: the
# prox of the penalty at the step floatmax(T) from 0. For an unweighted NormL1 or ElasticNet with finite
# nonnegative levels that is 0, which minimizes the penalty along the coordinate (at λ1 = λ2 = 0 the
# penalty is 0 there for every value).
function _coordinate_minimizer(g::Union{NormL1, ElasticNet}, old::T, i) where T
  new = T(prox_block(g, zero(T), i, floatmax(T)))
  isfinite(new) && isfinite(new-old) || throw(ArgumentError("coordinate $i has no finite minimizer and displacement"))
  new
end
@inline function _visit!(m::CDModel, g, x, k::Int, scaled::Bool)
  h = abs(coordinate_step!(m, g, x, k))
  change = scaled && !iszero(h) ? h * coordinate_scale(m, x, k) : h
  isfinite(change) || throw(ArgumentError("a coordinate step or its stopping scale is not finite"))
  change
end
