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
cdmodel(f,x)=throw(ArgumentError("unsupported private coordinate-descent model"))
# The minimizer along a flat LS column (zero slope and curvature): the penalty's.
function _coordinate_minimizer(g::NormL1, old::T, i) where T
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
