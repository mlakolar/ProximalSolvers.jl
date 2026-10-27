####################################
#
#  Proximal Newton through the second-order oracle of ProximalBase
#
####################################

# quadratic_model(f, x) is a function of the new point z, up to an additive
# constant: its gradient at x is the gradient of f. Minimize q(z) + g(z), then
# search along z - x on the original objective. In particular there is no
# translation of g here, unlike QUIC's model in the direction Δ. The specialized
# GLM/intercept and QUIC implementations keep their cheaper caches.

const _GenericNewtonIterate{T} = Union{SparseIterate{T}, SymmetricSparseIterate{T}}

_newton_penalty(g, ::SparseIterate) = g
_newton_penalty(g::ZeroFunction, ::SymmetricSparseIterate) = g
_newton_penalty(g::NormL1, x::SymmetricSparseIterate) = _symmetric_penalty(g, x)
_newton_penalty(g, ::SymmetricSparseIterate) =
  throw(ArgumentError("generic ProxNewton on a symmetric matrix supports NormL1 or ZeroFunction; use a vector iterate for other separable penalties."))

# The proximal fixed-point residual uses the ORIGINAL gradient, not the change
# in the objective or the progress of the inner solve. A failed search, a loose
# inner solve and an inaccurate user model cannot certify stationarity merely
# because they did not move. No normalization from q is used: its arbitrary
# additive constant must not change the stopping rule.
function _newton_residual(x::SparseIterate{T}, g, grad::AbstractArray{T}) where {T}
  res = zero(T)
  @inbounds for i in eachindex(x)
    v = prox_entry(g, x[i] - grad[i], i, one(T))
    isfinite(v) || return T(Inf)
    res = max(res, abs(v - x[i]))
  end
  res
end

function _newton_residual(x::SymmetricSparseIterate{T}, g, grad::AbstractMatrix{T}) where {T}
  res = zero(T)
  cx = coordinates(x)
  for k in 1:ncoordinates(x)
    r, c = tril_cartesian(x.p, k)
    d = r == c ? grad[r, r] : grad[r, c] + grad[c, r]
    μ = r == c ? one(T) : T(2)
    v = prox_entry(g, cx[k] - d, _entry(x.p, r, c), μ)
    isfinite(v) || return T(Inf)
    res = max(res, abs(v - cx[k]))
  end
  res
end

function _newton_interpolate!(x::SymmetricSparseIterate{T}, x0::SymmetricSparseIterate{T},
                              x1::SymmetricSparseIterate{T}, t::T) where {T}
  cx, c0, c1 = coordinates(x), coordinates(x0), coordinates(x1)
  for k in eachindex(cx)
    cx[k] = c0[k] + t * (c1[k] - c0[k])
  end
  x
end
_newton_interpolate!(x::SparseIterate, x0::SparseIterate, x1::SparseIterate, t) =
  _interpolate!(x, x0, x1, t)

function _newton_cdmodel(q, x, g)
  m = cdmodel(q, x)
  hasmethod(initialize!, Tuple{typeof(m), typeof(x)}) &&
    hasmethod(coordinate_derivatives, Tuple{typeof(m), typeof(x), Int}) ||
    throw(ArgumentError("ProxNewton cannot minimize a quadratic model $(typeof(q)) on a $(typeof(x)) by coordinate descent."))
  eltype(m) === eltype(x) ||
    throw(ArgumentError("x has element type $(eltype(x)) and the quadratic model $(eltype(m))."))
  check_penalty(m, g)
  initialize!(m, x)
  # Coordinate descent needs nonnegative coordinate curvatures. This does not
  # claim to check positive semidefiniteness of an arbitrary user Hessian.
  for k in 1:ncoordinates(x)
    _, a = coordinate_derivatives(m, x, k)
    isfinite(a) && a >= 0 ||
      throw(ArgumentError("ProxNewton needs a quadratic model with finite, nonnegative coordinate curvatures."))
  end
  m
end

function _solve_generic_newton!(x::_GenericNewtonIterate{T}, f::AbstractFunction,
                                g::AbstractFunction, method::ProxNewton) where {T<:AbstractFloat}
  issmooth(f) || throw(ArgumentError("ProxNewton needs a smooth loss, but f is a $(typeof(f))."))
  ProximalBase.hashessian(f) ||
    throw(ArgumentError("ProxNewton needs quadratic_model and quadratic_model! for $(typeof(f)); see ProximalBase.hashessian."))
  isseparable(g) || throw(ArgumentError("ProxNewton needs a separable penalty, but g is a $(typeof(g))."))
  g = _newton_penalty(g, x)
  _check_iterate(g, x)
  F = T(f(x) + g(x))
  isfinite(F) || throw(ArgumentError("ProxNewton needs a starting point with a finite objective."))

  q = ProximalBase.quadratic_model(f, x)
  grad = _gradient_buffer(x)
  modelgrad = similar(grad)
  x0, trial = copy(x), copy(x)
  st = _CDState(T, trial, method.inner)
  # A user can ask for a tighter outer tolerance than the default inner one.
  # Keep the resource limits and orders of inner, tightening its change rule.
  inner = _with(method.inner; tol = min(method.inner.tol, max(method.tol / 10, eps(T))))
  passes, converged = 0, false
  residual, tolerance = T(Inf), T(method.tol)

  # The final visit checks stationarity after the last permitted Newton step;
  # it does not perform another inner solve.
  for it in 0:method.maxiter
    it == 0 || (q = ProximalBase.quadratic_model!(q, f, x))
    # Reuse q's buffers, but rebuild its CD cache: cdmodel may copy a Diagonal
    # or Symmetric Hessian to a dense matrix, and keeps scalar scale/constants.
    # Reinitializing such a cache alone would retain stale model parameters.
    m = _newton_cdmodel(q, x, g)
    fx = value_and_gradient!(grad, f, x)
    isfinite(fx) || throw(ArgumentError("the loss at the current ProxNewton iterate is not finite."))
    F = T(fx + g(x))
    all(isfinite, grad) || throw(ArgumentError("the gradient at the current ProxNewton iterate is not finite."))
    residual = _newton_residual(x, g, grad)
    tolerance = T(method.tol) * max(one(T), norm(x, Inf))
    if residual <= tolerance
      converged = true
      break
    end
    it == method.maxiter && break

    copyto!(x0, x)
    copyto!(trial, x)
    remaining = method.inner.maxpasses
    while true
      _cd!(trial, m, g, st, _with(inner; maxpasses = remaining))
      passes += st.passes
      remaining -= st.passes
      # The inner relative-change rule has units that depend on the model's
      # scale. Check its actual proximal residual before using a nearly
      # stationary direction; all refinements share the requested pass limit.
      initialize!(m, trial)
      value_and_gradient!(modelgrad, q, trial)
      all(isfinite, modelgrad) ||
        throw(ArgumentError("the quadratic model gradient is not finite."))
      modelres = _newton_residual(trial, g, modelgrad)
      modeltol = T(method.tol / 10) * max(one(T), norm(trial, Inf))
      (modelres <= modeltol || !st.converged || st.passes == 0 ||
       remaining <= 0 || inner.tol <= eps(T)) && break
      inner = _with(inner; tol = max(inner.tol / 10, eps(T)))
    end
    dropzeros!(trial)
    # The first-order decrease of the composite objective, evaluated with the
    # actual gradient. An insufficient inner solve can produce no direction,
    # or an inaccurate oracle an ascent direction; neither is convergence.
    δ = T(g(trial) - g(x0))
    for i in eachindex(x0, trial, grad)
      δ += grad[i] * (trial[i] - x0[i])
    end
    isfinite(δ) && δ < 0 || break

    t, accepted = one(T), false
    for _ in 1:60
      _newton_interpolate!(x, x0, trial, t)
      Ft = T(f(x) + g(x))
      # Infeasible trials return Inf. Their gradient and quadratic model are
      # never evaluated; only a finite Armijo-accepted point becomes current.
      if isfinite(Ft) && Ft <= F + T(1e-3) * t * δ
        F, accepted = Ft, true
        break
      end
      t *= T(method.β)
    end
    if !accepted
      copyto!(x, x0)
      break
    end
    dropzeros!(x)
  end
  CDResults(x, F, passes, converged, residual, tolerance, 0)
end

solve!(x::SparseIterate, f::AbstractFunction, g::AbstractFunction, method::ProxNewton) =
  _solve_generic_newton!(x, f, g, method)
solve!(x::SymmetricSparseIterate, f::AbstractFunction, g::AbstractFunction, method::ProxNewton) =
  _solve_generic_newton!(x, f, g, method)

function solve!(x::Vector{T}, f::AbstractFunction, g::AbstractFunction, method::ProxNewton) where {T<:AbstractFloat}
  xs = SparseIterate(x)
  r = solve!(xs, f, g, method)
  _copy_dense!(x, xs)
  CDResults(x, r.minimum, r.passes, r.converged, r.maxchange, r.tolerance, r.kkt_checks, r.gap)
end

function solve!(x::Matrix{T}, f::AbstractFunction, g::AbstractFunction, method::ProxNewton) where {T}
  T <: AbstractFloat || throw(ArgumentError("ProxNewton needs a floating-point iterate."))
  issymmetric(x) || throw(ArgumentError("the matrix iterate of ProxNewton must be symmetric."))
  xs = SymmetricSparseIterate(x)
  r = solve!(xs, f, g, method)
  _copy_dense!(x, xs)
  CDResults(x, r.minimum, r.passes, r.converged, r.maxchange, r.tolerance, r.kkt_checks, r.gap)
end
