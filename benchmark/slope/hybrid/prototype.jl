using ProximalBase, ProximalSolvers, LinearAlgebra, SparseArrays
import ProximalSolvers: _slope_inner!, _slope_loss, _slope_kkt, solve!, solve_path

struct HybridPrototype{T} <: ProximalSolver
  maxiter::Int
  tol::T
end
function HybridPrototype(;maxiter::Integer=10_000,tol::Real=1e-7)
  checked = SLOPEAPG(;maxiter,tol)
  HybridPrototype(checked.maxiter,checked.tol)
end

function solve!(x::Vector{<:AbstractFloat},f::ProximalBase.AbstractFunction,g::SLOPE,method::HybridPrototype;
                candidates=eachindex(x))
  X,y,scale = ProximalSolvers._check_slope_data(x,f,g)
  ProximalSolvers._slope_fit!(x,X,y,g.λ,scale,candidates,method,ProximalSolvers._slope_workspace(X,y))
end
function solve_path(f::ProximalBase.AbstractFunction,g::SLOPE,factors::AbstractVector{<:Real},method::HybridPrototype;
                    x=ProximalSolvers._slope_default_x(f),screening::Bool=true)
  ProximalSolvers._slope_path(f,g,factors,method;x,screening)
end

# Exact minimizer of .5*curvature*z^2 - gamma*z + J(beta(z)).
# `others` is descending and excludes the updated cluster. Walk upwards from
# zero, checking both one-sided derivatives at each positive breakpoint.
function cluster_value(gamma,curvature,others,m,prefix)
  a = abs(gamma)
  r = count(>(0),others)
  slope = prefix[r+m+1]-prefix[r+1]
  a <= slope && return zero(gamma)
  while r > 0
    c = others[r]
    a < curvature*c+slope && return copysign((a-slope)/curvature,gamma)
    while r > 0 && others[r] == c
      r -= 1
    end
    slope = prefix[r+m+1]-prefix[r+1]
    a <= curvature*c+slope && return copysign(c,gamma)
  end
  copysign((a-slope)/curvature,gamma)
end

function cluster_column!(column,X,indices,signs)
  mul!(column,X[:,indices],signs)
end
function cluster_column!(column,X::StridedMatrix,indices,signs)
  fill!(column,0)
  for (j,s) in zip(indices,signs), i in axes(X,1)
    column[i] += s*X[i,j]
  end
  column
end
function cluster_column!(column,X::SparseMatrixCSC,indices,signs)
  fill!(column,0)
  for (j,s) in zip(indices,signs), k in nzrange(X,j)
    column[rowvals(X)[k]] += s*nonzeros(X)[k]
  end
  column
end

function cluster_sweep!(x,X,residual,scale,lambda)
  column = similar(residual)
  prefix = [zero(eltype(x)); cumsum(lambda)]
  # Rebuild after each update, so merged clusters are never split by a stale
  # sweep. Visit a moving cluster once; PG rediscovers any missed clusters.
  visited = falses(length(x))
  for _ in eachindex(x)
    remaining = findall(j -> !visited[j] && !iszero(x[j]),eachindex(x))
    isempty(remaining) && break
    j = remaining[argmax(abs.(x[remaining]))]
    c = abs(x[j])
    indices = findall(t -> abs(t) == c,x)
    signs = sign.(x[indices])
    others = sort!(abs.(x[setdiff(eachindex(x),indices)]);rev=true)
    cluster_column!(column,X,indices,signs)
    curvature = scale*sum(abs2,column)
    gamma = curvature*c+scale*dot(column,residual)
    isfinite(curvature) && isfinite(gamma) || return false
    z = iszero(curvature) ? zero(c) : cluster_value(gamma,curvature,others,length(indices),prefix)
    isfinite(z) || return false
    for (index,s) in zip(indices,signs)
      x[index] = s*z
    end
    residual .-= (z-c).*column
    visited[indices] .= true
    # A merge inherits the visited state of the updated cluster.
    for k in eachindex(x)
      abs(x[k]) == abs(z) && (visited[k] = true)
    end
  end
  true
end

function _slope_inner!(x,f,g,method::HybridPrototype,budget,target)
  X,y,scale = _slope_loss(f)
  apg = AccProxGradDescent()
  options = ProximalOptions()
  state = ProximalSolvers.initial_state(apg,options,f,g,x)
  cluster_enabled = true
  total = 0
  while total < budget
    ProximalSolvers.update_state!(f,g,state,apg)
    total += 1
    residual,_,_ = _slope_kkt(X,y,x,g.λ,scale,nothing)
    residual <= target/2 && return total
    if cluster_enabled
      old = copy(x)
      before = state.f_x+state.g_x
      r = y-X*x
      valid = true
      for _ in 1:min(4,budget-total)
        valid = cluster_sweep!(x,X,r,scale,g.λ)
        total += 1
        valid || break
      end
      # Check the actual design product, not just the incrementally updated
      # residual. Do not call the APG start validator until a rejected point
      # has been restored: an overflowing cluster move must fall back safely.
      state.f_x = ProximalSolvers._value!(f,x,state.model,state.z_x)
      state.g_x = g(x)
      after = state.f_x+state.g_x
      if !valid || !isfinite(after) || after > before+10eps(eltype(x))*max(1,abs(before))
        copyto!(x,old)
        cluster_enabled = false
        old_L = state.L
        ProximalSolvers.reinitialize_state!(state,f,g,apg)
        state.L = old_L
      else
        copyto!(state.x_previous,x)
        state.model === nothing || copyto!(state.z_previous,state.z_x)
        state.k = 0
      end
    end
  end
  total
end
