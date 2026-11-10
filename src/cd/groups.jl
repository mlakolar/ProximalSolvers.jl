####################################
#
#  Block steps on an AtomIterate with any penalty
#
####################################

# The solver constructs the trial block, calls the mathematical oracle, writes
# the result through the public group view, and updates its own residual cache.
# The second half of buf retains the old block for the cache difference.
_check_group_step_layout(g::Scaled, x) = _check_group_step_layout(g.f, x)
function _check_group_step_layout(g, x)
  isseparable(g) && return ProximalBase._checkparams(g, x)
  ProximalBase.samegroups(x, g) || throw(DimensionMismatch("f and x must have the same groups."))
  nothing
end

function _prox_group_trial!(u, g, G, k, γ)
  if isseparable(g)
    for (i, j) in enumerate(G)
      u[i] = prox_block(g, u[i], j, γ)
    end
  else
    prox_block!(u, g, u, k, γ)
  end
  u
end

function _groupstep!(m::LSModel{T}, g::AbstractFunction, x::AtomIterate{T}, k::Int, scaled::Bool) where {T}
  _check_group_step_layout(g, x)
  G = atomindices(x, k)
  n = length(G)
  buf = _groupbuffer!(m, 2n)

  # buf = -∇_G f(x) / s, where ∇ⱼf(x) = -s (X[:, j] - x̄ⱼ)' W r
  for (i, j) in enumerate(G)
    a, b = _column_dot(m, j)
    m.a[j] = a
    buf[i] = b
  end

  L = _groupcurvature!(m, x, k)
  for (i, j) in enumerate(G)
    old = x[j]
    buf[n + i] = old
    buf[i] = iszero(L) ? old : old + m.s * buf[i] / L
  end
  trial = view(buf, 1:n)
  _prox_group_trial!(trial, g, G, k, iszero(L) ? floatmax(T) : inv(L))
  copyto!(atom(x, k), trial)

  maxh = zero(T)
  for (i, j) in enumerate(G)
    h = x[j] - buf[n + i]
    iszero(h) && continue
    _residual_axpy!(m, j, h)
    maxh = max(maxh, _scaledchange(m, x, j, h, scaled))
  end
  maxh
end

function _groupstep!(m::QuadModel{T}, g::AbstractFunction, x::AtomIterate{T}, k::Int, scaled::Bool) where {T}
  _check_group_step_layout(g, x)
  A, u = m.A, m.u
  G = atomindices(x, k)
  n = length(G)
  buf = _groupbuffer!(m, 2n)

  # buf = ∇_G f(x) = s (Ax + b)[G]
  for (i, j) in enumerate(G)
    buf[i] = m.s * (u[j] + _linear(m.b, j, T))
  end

  L = _groupcurvature!(m, x, k)
  iszero(L) && any(i -> !iszero(buf[i]), eachindex(G)) &&
    throw(ArgumentError("group $k has zero curvature and a nonzero linear term; coordinate descent supports this only for GroupNormL2"))
  for (i, j) in enumerate(G)
    old = x[j]
    buf[n + i] = old
    buf[i] = iszero(L) ? old : old - buf[i] / L
  end
  trial = view(buf, 1:n)
  _prox_group_trial!(trial, g, G, k, iszero(L) ? floatmax(T) : inv(L))
  copyto!(atom(x, k), trial)

  maxh = zero(T)
  for (i, j) in enumerate(G)
    h = x[j] - buf[n + i]
    iszero(h) && continue
    _quad_axpy!(u, A, j, h)
    maxh = max(maxh, _scaledchange(m, x, j, h, scaled))
  end
  maxh
end
