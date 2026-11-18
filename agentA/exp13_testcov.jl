using ProximalSolvers, ProximalBase, Test
const PS = ProximalSolvers
const CNT = Dict{Symbol,Int}()
bump(k) = (CNT[k] = get(CNT, k, 0) + 1)
for T in (Float32, Float64)
  M = PS.SqrtLSModel{T, PS.LSModel{T, T, Matrix{T}, Vector{T}}}
  @eval function PS._sqrt_offrange_step(m::$M, old::$T, k::Int)
    $bump(Symbol(:offrange_, $(QuoteNode(Symbol(T)))))
    invoke(PS._sqrt_offrange_step, Tuple{PS.SqrtLSModel{$T}, $T, Int}, m, old, k)
  end
  @eval function PS._sqrt_band_step(c::$T, ra, λ, d̃::Float64, e::Int)
    $bump(Symbol(:band_, $(QuoteNode(Symbol(T)))))
    invoke(PS._sqrt_band_step, Tuple{Any, Any, Any, Float64, Int}, c, ra, λ, d̃, e)
  end
end
@eval function PS._sqrt_threshold64(ra::Union{Float32,Float64}, λ::Union{Float32,Float64}, d̃::Float64, e::Int)
  $bump(:threshold64)
  invoke(PS._sqrt_threshold64, Tuple{Any, Any, Float64, Int}, ra, λ, d̃, e)
end
@eval function PS._check_residual(r::Vector{T}, k::Int) where T<:Union{Float32,Float64}
  $bump(:check_residual)
  invoke(PS._check_residual, Tuple{AbstractVector, Int}, r, k)
end
@eval function PS._scaled_norm(v::Vector{T}, n::Int) where T<:Union{Float32,Float64}
  $bump(:scaled_norm)
  invoke(PS._scaled_norm, Tuple{AbstractVector, Int}, v, n)
end
@eval function PS._distance_sqr(X::Matrix{T}, r::Vector{T}, k::Int, q::T) where T<:Union{Float32,Float64}
  $bump(:distance_sqr_guard)
  invoke(PS._distance_sqr, Tuple{AbstractMatrix{T}, AbstractVector{T}, Int, T} where T, X, r, k, q)
end
t = @elapsed include("<WORK>/ps-353/test/sqrt_lasso.jl")
println("test file ran in ", round(t, digits = 1), " s")
for (k, v) in sort(collect(CNT); by = string); println("  ", k, " = ", v); end
