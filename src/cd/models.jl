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
# `_cd_momentum!`; `scaled` is that of `_tolerances`). It returns `:converged` (stop with
# `converged = true`), `:uncertified` (stop with `converged = false`) or `:retry` (the check lowered
# `st.tolerance`; the loop continues with it); a model with a certificate records its outcome itself, for
# `_result_gap` and `_uncertified`. This method, for the models without a certificate (least squares,
# group lasso), returns the constant `:converged` and changes nothing: their stop is the change test,
# and their result has `gap = NaN` and no uncertified stop. `SqrtLSModel` has its own methods.
_stop_check!(m::CDModel, g, x, st, maxh, scaled::Bool) = :converged
_result_gap(m::CDModel{T}) where T = T(NaN)
_uncertified(m::CDModel) = false
# The fallback after an uncertified stop (`_run_cd!`): none for the models without a certificate.
_fallback!(m::CDModel, g, x, st, s) = nothing
cdmodel(f,x)=throw(ArgumentError("unsupported private coordinate-descent model"))
# The coordinate along a flat LS column (zero slope and curvature), which does not enter the loss: the
# prox of the penalty at the step floatmax(T) from 0. For an unweighted NormL1 or ElasticNet with finite
# nonnegative levels that is 0, which minimizes the penalty along the coordinate (at λ1 = λ2 = 0 the
# penalty is 0 there for every value). For a NormL1 with weights that `solve!` accepts it is 0 too, also at a
# zero weight (test/weighted_lasso.jl checks weights 0 and 2 at levels from 0 to 1e30 in Float32 and to 1e100
# in Float64).
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
