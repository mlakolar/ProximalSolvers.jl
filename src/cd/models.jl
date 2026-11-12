# Private scalar model/cache seam, including the C0 observer hooks.
abstract type CDModel{T} end
function initialize! end
_initialize!(m::CDModel, x, fresh::Bool) = initialize!(m, x)
function coordinate_step! end
coordinate_scale(m::CDModel{T}, x, k::Int) where T = one(T)
response_scale(m::CDModel{T}, x) where T = zero(T)
loss_value(m::CDModel{T}, x) where T = T(NaN)
function cdmodel end
cdmodel(f,x)=throw(ArgumentError("unsupported private coordinate-descent model"))
# Only zero slope/curvature is reachable for a genuine flat LS column.
function _coordinate_minimizer(g::NormL1, old::T, G, a, i, μ = one(T)) where T
  iszero(a) && iszero(G) || throw(ArgumentError("unsupported flat coordinate"))
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
