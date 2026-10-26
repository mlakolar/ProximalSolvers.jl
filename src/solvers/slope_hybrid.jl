"""
    SLOPEHybrid(; maxiter=10_000, tol=1e-7, cd_sweeps=10, stall_cycles=2)

Opt-in cluster-coordinate / proximal-gradient solver for single-response least
squares with a `SLOPE` penalty. Uses the same paths, screening, full optimality
checks and working-set repairs as [`SLOPEAPG`](@ref). APG remains the default
choice. Call `solve!(x,f,g,SLOPEHybrid())` or
`solve_path(f,g,factors,SLOPEHybrid())` explicitly.

One PG step is followed by up to `cd_sweeps` exact nonzero-cluster sweeps.
Cluster ordering, membership and scratch are reused; at most 32 signed cluster
columns are cached, so the solver never builds an entire dense collapsed design
for a sparse input. PG steps can split clusters and activate zeros.

If the reduced fixed-point residual fails to decrease by 20% for `stall_cycles`
successive cycles, or a cluster block is nonfinite or increases the objective,
that reduced solve switches permanently to APG. A bounded hybrid trial also
reserves at least half the remaining iteration budget for APG. The full residual
determines convergence, including after fallback. `maxiter` counts PG/APG steps
and complete CD sweeps, summed over working-set repairs at each level.

This numerical option performs no preprocessing or statistical calibration.
Dense and CSC designs have specialized allocation-free column accumulation;
other matrices must provide efficient multiplication and column restriction.
"""
struct SLOPEHybrid{T<:AbstractFloat} <: ProximalSolver
  maxiter::Int
  tol::T
  cd_sweeps::Int
  stall_cycles::Int
  function SLOPEHybrid(;maxiter::Integer=10_000,tol::Real=1e-7,
                        cd_sweeps::Integer=10,stall_cycles::Integer=2)
    checked = SLOPEAPG(;maxiter,tol)
    cd_sweeps >= 1 || throw(ArgumentError("cd_sweeps must be positive"))
    stall_cycles >= 1 || throw(ArgumentError("stall_cycles must be positive"))
    new{typeof(checked.tol)}(checked.maxiter,checked.tol,Int(cd_sweeps),Int(stall_cycles))
  end
end
Base.summary(::SLOPEHybrid) = "Opt-in SLOPE cluster hybrid with APG fallback"

mutable struct _SLOPEClusters{T}
  permutation::Vector{Int}
  order::Vector{Int}
  traversal::Vector{Int}
  heads::Vector{Int}
  tails::Vector{Int}
  next::Vector{Int}
  sizes::Vector{Int}
  positions::Vector{Int}
  ranks::Vector{Int}
  values::Vector{T}
  curvatures::Vector{T}
  signs::Vector{T}
  prefix::Vector{T}
  column::Vector{T}
  columns::Matrix{T}
  valid::BitVector
  direction::Vector{T}
  indices::Vector{Int}
  member_signs::Vector{T}
  residual::Vector{T}
  gradient::Vector{T}
  point::Vector{T}
  trial::Vector{T}
  saved::Vector{T}
  groups::Int
  pg_steps::Int
  sweeps::Int
  fallbacks::Int
end
function _SLOPEClusters(::Type{T},n,p) where {T}
  _SLOPEClusters(zeros(Int,p),zeros(Int,p),zeros(Int,p),zeros(Int,p),zeros(Int,p),
    zeros(Int,p),zeros(Int,p),zeros(Int,p),zeros(Int,p),zeros(T,p),zeros(T,p),zeros(T,p),zeros(T,p+1),zeros(T,n),
    zeros(T,n,min(p,32)),falses(min(p,32)),zeros(T,p),zeros(Int,p),zeros(T,p),
    zeros(T,n),zeros(T,p),zeros(T,p),zeros(T,p),zeros(T,p),0,0,0,0)
end

mutable struct _SLOPEHybridWorkspace{B,C}
  base::B
  clusters::C
end
_slope_workspace(X,y,::SLOPEHybrid) =
  _SLOPEHybridWorkspace(_slope_workspace(X,y),_SLOPEClusters(eltype(y),length(y),size(X,2)))
_slope_restricted_loss(X,y,E,w::_SLOPEHybridWorkspace) = _slope_restricted_loss(X,y,E,w.base)
_slope_nullgradient(X,y,s,w::_SLOPEHybridWorkspace) = _slope_nullgradient(X,y,s,w.base)
_slope_kkt(X,y,x,lambda,s,w::_SLOPEHybridWorkspace) = _slope_kkt(X,y,x,lambda,s,w.base)

function solve!(x::Vector{<:AbstractFloat},f::AbstractFunction,g::SLOPE,method::SLOPEHybrid;
                candidates=eachindex(x))
  X,y,scale = _check_slope_data(x,f,g)
  _slope_fit!(x,X,y,g.λ,scale,candidates,method,_slope_workspace(X,y,method))
end
function solve_path(f::AbstractFunction,g::SLOPE,factors::AbstractVector{<:Real},method::SLOPEHybrid;
                    x=_slope_default_x(f),screening::Bool=true)
  _slope_path(f,g,factors,method;x,screening)
end

function _slope_clusters!(w,x,lambda)
  p = length(x)
  for j in 1:p
    w.permutation[j] = j
    w.sizes[j] = 0
    w.signs[j] = sign(x[j])
  end
  order = view(w.permutation,1:p)
  sort!(order;alg=QuickSort,lt=(i,j)->abs(x[i])>abs(x[j]))
  fill!(w.valid,false)
  w.prefix[1] = zero(eltype(x))
  for j in 1:p
    w.prefix[j+1] = w.prefix[j]+lambda[j]
  end
  m = 0
  last = 0
  rank = 0
  for j in order
    value = abs(x[j])
    iszero(value) && break
    if m == 0 || value != w.values[m]
      m += 1
      w.order[m] = m
      w.positions[m] = m
      w.ranks[m] = rank
      w.values[m] = value
      w.heads[m] = j
    else
      w.next[last] = j
    end
    w.next[j] = 0
    w.sizes[m] += 1
    w.tails[m] = j
    last = j
    rank += 1
  end
  w.groups = m
  w
end

_slope_rank_weight(w,start,count) = w.prefix[start+count+1]-w.prefix[start+1]

# Search from the current rank, crossing only neighboring groups. The moving
# cluster occupies `count` consecutive ranks; weights belong to ranks, not ids.
function _slope_cluster_value(w,pos,gamma,curvature)
  g = w.order[pos]
  count = w.sizes[g]
  start = w.ranks[g]
  a = abs(gamma)
  weight = _slope_rank_weight(w,start,count)
  if a > curvature*w.values[g]+weight
    for k in pos-1:-1:1
      neighbor = w.order[k]
      c = w.values[neighbor]
      a < curvature*c+weight && return copysign((a-weight)/curvature,gamma)
      start -= w.sizes[neighbor]
      weight = _slope_rank_weight(w,start,count)
      a <= curvature*c+weight && return copysign(c,gamma)
    end
  else
    for k in pos+1:w.groups
      neighbor = w.order[k]
      c = w.values[neighbor]
      a > curvature*c+weight && return copysign((a-weight)/curvature,gamma)
      start += w.sizes[neighbor]
      weight = _slope_rank_weight(w,start,count)
      a >= curvature*c+weight && return copysign(c,gamma)
    end
  end
  copysign(max(zero(a),a-weight)/curvature,gamma)
end

function _slope_cluster_column!(out,X::StridedMatrix,w,g)
  fill!(out,zero(eltype(out)))
  j = w.heads[g]
  while j != 0
    s = w.signs[j]
    @inbounds @simd for i in axes(X,1)
      out[i] += s*X[i,j]
    end
    j = w.next[j]
  end
  out
end
function _slope_cluster_column!(out,X::SparseMatrixCSC,w,g)
  fill!(out,zero(eltype(out)))
  j = w.heads[g]
  while j != 0
    s = w.signs[j]
    @inbounds for k in nzrange(X,j)
      out[rowvals(X)[k]] += s*nonzeros(X)[k]
    end
    j = w.next[j]
  end
  out
end
function _slope_cluster_column!(out,X,w,g)
  j = w.heads[g]
  k = 0
  while j != 0
    k += 1
    w.indices[k] = j
    w.member_signs[k] = w.signs[j]
    j = w.next[j]
  end
  mul!(out,X[:,view(w.indices,1:k)],view(w.member_signs,1:k))
end
function _slope_cached_column!(X,w,g)
  if g <= size(w.columns,2)
    column = view(w.columns,:,g)
    if !w.valid[g]
      _slope_cluster_column!(column,X,w,g)
      w.curvatures[g] = sum(abs2,column)
    end
    w.valid[g] = true
    column
  else
    _slope_cluster_column!(w.column,X,w,g)
    w.curvatures[g] = sum(abs2,w.column)
    w.column
  end
end

# Remove/reinsert a group id. Linked membership permits allocation-free merging;
# only the short ordered group list moves, never a new coefficient index set.
function _slope_relocate!(w,g,pos,value)
  upper = pos == 1 ? oftype(value,Inf) : w.values[w.order[pos-1]]
  lower = pos == w.groups ? zero(value) : w.values[w.order[pos+1]]
  if lower < value < upper
    w.values[g] = value
    return
  end
  for k in pos:w.groups-1
    w.order[k] = w.order[k+1]
  end
  w.groups -= 1
  if iszero(value)
    w.sizes[g] = 0
    w.positions[g] = 0
    _slope_cluster_ranks!(w)
    return
  end
  k = 1
  while k <= w.groups && w.values[w.order[k]] > value
    k += 1
  end
  if k <= w.groups && w.values[w.order[k]] == value
    other = w.order[k]
    w.next[w.tails[g]] = w.heads[other]
    w.tails[g] = w.tails[other]
    w.sizes[g] += w.sizes[other]
    w.sizes[other] = 0
    w.positions[other] = 0
    w.order[k] = g
    g <= length(w.valid) && (w.valid[g] = false)
    other <= length(w.valid) && (w.valid[other] = false)
  else
    for j in w.groups:-1:k
      w.order[j+1] = w.order[j]
    end
    w.groups += 1
    w.order[k] = g
  end
  w.values[g] = value
  _slope_cluster_ranks!(w)
end
function _slope_cluster_ranks!(w)
  rank = 0
  for k in 1:w.groups
    g = w.order[k]
    w.positions[g] = k
    w.ranks[g] = rank
    rank += w.sizes[g]
  end
end

function _slope_cluster_sweep!(x,X,scale,w)
  m = w.groups
  copyto!(w.traversal,1,w.order,1,m)
  for k in 1:m
    g = w.traversal[k]
    w.sizes[g] == 0 && continue
    pos = w.positions[g]
    column = _slope_cached_column!(X,w,g)
    curvature = scale*w.curvatures[g]
    gamma = curvature*w.values[g]+scale*dot(column,w.residual)
    isfinite(curvature) && isfinite(gamma) || return false
    z = iszero(curvature) ? zero(gamma) : _slope_cluster_value(w,pos,gamma,curvature)
    isfinite(z) || return false
    delta = z-w.values[g]
    if !iszero(delta)
      j = w.heads[g]
      while j != 0
        x[j] = w.signs[j]*z
        z < 0 && (w.signs[j] = -w.signs[j])
        j = w.next[j]
      end
      @. w.residual -= delta*column
      if z < 0 && g <= length(w.valid)
        w.valid[g] = false
      end
      _slope_relocate!(w,g,pos,abs(z))
    end
  end
  true
end

function _slope_hybrid_residual!(x,X,y,scale,g,w)
  p = length(x)
  mul!(w.residual,X,x)
  @. w.residual = y-w.residual
  grad = view(w.gradient,1:p)
  mul!(grad,transpose(X),w.residual)
  point = view(w.point,1:p)
  trial = view(w.trial,1:p)
  @. point = x+scale*grad
  prox!(trial,g,point,one(eltype(x)))
  result = zero(eltype(x))
  for j in 1:p
    result = max(result,abs(x[j]-trial[j]))
  end
  result
end

_slope_hybrid_trial_budget(method,budget) = min(budget÷2,10*(method.cd_sweeps+1))

function _slope_inner!(x,f,g,method::SLOPEHybrid,budget,target,workspace::_SLOPEHybridWorkspace)
  X,y,scale = _slope_loss(f)
  w = workspace.clusters
  apg = AccProxGradDescent()
  state = initial_state(apg,ProximalOptions(),f,g,x)
  total = 0
  previous = _slope_hybrid_residual!(x,X,y,scale,g,w)
  previous <= target/2 && return total
  stalls = 0
  hybrid = true
  # At least half the budget remains available to accelerated PG after a bounded
  # trial, even when tiny decreases evade the slow-progress window.
  trial_budget = _slope_hybrid_trial_budget(method,budget)
  while total < budget
    if !hybrid
      if budget-total == 1
        update_state!(f,g,state,apg)
        w.pg_steps += 1
        return total+1
      end
      # Reuse APG state and its established stopping rules. Returning a reduced
      # fit lets the outer driver repair excluded coordinates before the whole
      # budget is consumed on an unnecessarily accurate restricted solution.
      options = ProximalOptions(;maxiter=budget-total,ftol=eps(Float64),
        xtol=eps(Float64),gradtol=method.tol/10,allow_f_increases=true)
      used = _solve_gradient!(state,f,g,apg,options,nothing).iterations
      w.pg_steps += used
      return total+used
    end
    update_state!(f,g,state,apg)
    total += 1
    w.pg_steps += 1
    if hybrid && total < trial_budget
      copyto!(w.saved,1,x,1,length(x))
      before = state.f_x+state.g_x
      _slope_clusters!(w,x,g.λ)
      if state.model === nothing
        mul!(w.residual,X,x)
        @. w.residual = y-w.residual
      else
        @. w.residual = y-state.z_x
      end
      valid = true
      for _ in 1:min(method.cd_sweeps,trial_budget-total)
        w.groups == 0 && break
        valid = _slope_cluster_sweep!(x,X,scale,w)
        total += 1
        w.sweeps += 1
        valid || break
      end
      state.f_x = _value!(f,x,state.model,state.z_x)
      state.g_x = g(x)
      after = state.f_x+state.g_x
      if !valid || !isfinite(after) || after > before+10eps(eltype(x))*max(one(eltype(x)),abs(before))
        copyto!(x,1,w.saved,1,length(x))
        old_L = state.L
        reinitialize_state!(state,f,g,apg)
        state.L = old_L
        hybrid = false
        w.fallbacks += 1
      else
        copyto!(state.x_previous,x)
        state.model === nothing || copyto!(state.z_previous,state.z_x)
        state.k = 0
      end
    end
    # Hybrid cycles use fresh products to prevent residual drift. After APG
    # fallback returns, the outer driver checks the full problem and repairs it.
    if hybrid || total == budget
      residual = _slope_hybrid_residual!(x,X,y,scale,g,w)
      residual <= target/2 && return total
      if hybrid
        stalls = residual > .8previous ? stalls+1 : 0
        if stalls >= method.stall_cycles || total >= trial_budget
          hybrid = false
          w.fallbacks += 1
        end
        previous = residual
      end
    end
  end
  total
end
