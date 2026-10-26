####################################
#
#  Block steps on an AtomIterate with any penalty
#
####################################

# Group k of x ← the proximal operator of g with step 1/L at x[G] - ∇_G f(x) / L,
# where L is the curvature of f over G, so that the quadratic with curvature L
# majorizes f over the group (groupwise majorization descent, as for
# GroupNormL2, which has its own method with a closed form). The gradient step is
# written into the entries of x, and the penalty's own step on the group,
# prox_coordinate!, takes its proximal operator in place: a group penalty of
# ProximalBase on the groups of x (GroupNormLinf, a sparse group lasso, ...) or a
# separable one, entry by entry. With L = 0, f does not depend on the group, which
# goes to the minimizer of the penalty: zero, unless the penalty is zero there.
# Returns the largest change of an entry, scaled with `scaled`. The buffer holds
# the gradient in 1:|G| and the previous entries in |G|+1:2|G|.

function _groupstep!(m::LSModel{T}, g::AbstractFunction, x::AtomIterate{T}, k::Int, scaled::Bool) where {T}
  G = x.groups[k]
  n = length(G)
  buf = _groupbuffer!(m, 2n)

  # buf = -∇_G f(x) / s, where ∇ⱼf(x) = -s (X[:, j] - x̄ⱼ)' W r
  for (i, j) in enumerate(G)
    a, b = _column_dot(m, j)
    m.a[j] = a
    buf[i] = b
  end

  L = _groupcurvature!(m, x, k)
  storage = x.storage
  for (i, j) in enumerate(G)
    old = storage[j]
    buf[n + i] = old
    iszero(L) || (storage[j] = old + m.s * buf[i] / L)
  end
  prox_coordinate!(x, g, k, iszero(L) ? floatmax(T) : inv(L))

  maxh = zero(T)
  for (i, j) in enumerate(G)
    h = storage[j] - buf[n + i]
    iszero(h) && continue
    _residual_axpy!(m, j, h)
    maxh = max(maxh, _scaledchange(m, x, j, h, scaled))
  end
  maxh
end

function _groupstep!(m::QuadModel{T}, g::AbstractFunction, x::AtomIterate{T}, k::Int, scaled::Bool) where {T}
  A, u = m.A, m.u
  G = x.groups[k]
  n = length(G)
  buf = _groupbuffer!(m, 2n)

  # buf = ∇_G f(x) = s (Ax + b)[G]
  for (i, j) in enumerate(G)
    buf[i] = m.s * (u[j] + _linear(m.b, j, T))
  end

  L = _groupcurvature!(m, x, k)
  iszero(L) && any(i -> !iszero(buf[i]), eachindex(G)) &&
    throw(ArgumentError("group $k has zero curvature and a nonzero linear term; coordinate descent supports this only for GroupNormL2"))
  storage = x.storage
  for (i, j) in enumerate(G)
    old = storage[j]
    buf[n + i] = old
    iszero(L) || (storage[j] = old - buf[i] / L)
  end
  prox_coordinate!(x, g, k, iszero(L) ? floatmax(T) : inv(L))

  maxh = zero(T)
  for (i, j) in enumerate(G)
    h = storage[j] - buf[n + i]
    iszero(h) && continue
    _quad_axpy!(u, A, j, h)
    maxh = max(maxh, _scaledchange(m, x, j, h, scaled))
  end
  maxh
end
