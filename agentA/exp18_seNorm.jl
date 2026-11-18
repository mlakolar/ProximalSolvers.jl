using ProximalSolvers, ProximalBase, Test
const PS = ProximalSolvers
# overlay: _scaled_norm replaced by PS's existing _se_norm (src/solvers/image_models.jl:74): (s, e) with norm = s 2^e
Core.eval(PS, :(function _scaled_norm(v::AbstractVector, n::Int)
  M = 0.0
  @inbounds for i in 1:n; M = max(M, abs(Float64(v[i]))); end
  (iszero(M) || !isfinite(M)) && return (M, 0)
  se = _se_norm(Float64, view(v, 1:n))
  (se.s, se.e)
end))
@testset "ALL" begin include("<WORK>/ps-353/test/sqrt_lasso.jl") end
