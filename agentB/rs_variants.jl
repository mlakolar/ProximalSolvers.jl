# candidate response_scale variants (copied from cand_rs.jl)
using ProximalSolvers
const PS = ProximalSolvers
function rs_new(m::PS.LSModel{T}) where T
  iszero(m.s) && return zero(T)
  s = zero(T)
  @inbounds for i in eachindex(m.y); s += m.y[i]*m.y[i]; end
  ny = PS._se_norm_onepass(T, s, m.y)
  ny === nothing && PS._refuse_response_scale(T, false)
  PS._se_scale(T, PS._se_mul(PS._root_scale(T, m.s), ny))
end
# same, with the sum formed in Float64 for Float32 data (what the exceptional tier does today)
function rs_new64(m::PS.LSModel{T}) where T
  iszero(m.s) && return zero(T)
  W = T === Float32 ? Float64 : T
  s = zero(W)
  @inbounds for i in eachindex(m.y); v = W(m.y[i]); s += v*v; end
  ny = PS._se_norm_onepass(W, s, m.y)
  ny === nothing && PS._refuse_response_scale(T, false)
  PS._se_scale(T, PS._se_mul(PS._root_scale(W, m.s), ny))
end
