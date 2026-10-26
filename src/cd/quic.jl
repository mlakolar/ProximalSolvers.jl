####################################
#
#  proximal Newton for the graphical lasso (QUIC)
#
####################################

# ProxNewton on f = LogDetLoss(S, w) and g = NormL1(λ0, Λ):
#
#     minimize  w (tr(SX) - log det X) + Σᵢⱼ λᵢⱼ |Xᵢⱼ|   over X ≻ 0,
#
# by QUIC (Hsieh, Sustik, Dhillon and Ravikumar, *QUIC: quadratic approximation
# for sparse inverse covariance estimation*, JMLR 2014). With W = X⁻¹ the second
# order model of f at X in the step Δ is w (tr(WΔWΔ)/2 + tr((S - W)Δ)), a
# KronQuadratic in Δ, which coordinate descent minimizes plus g(X + Δ) over the
# free set: the coordinates with Xᵢⱼ ≠ 0 or a gradient above the penalty. An
# Armijo line search along Δ keeps X positive definite (a Cholesky factorization
# that fails rejects the step), and its factor gives log det and W for the next
# step, so every point is factorized once. The solver stops on the duality gap
# of the graphical lasso (see duality_gap). The solution is block diagonal along
# the connected components of the graph of the entries with w |Sᵢⱼ| > λᵢⱼ
# (Witten, Friedman and Simon, 2011; Mazumder and Hastie, 2012), so each
# component is solved on its own, and a component of one variable in closed
# form.

const _quic_σ = 1e-3          # the fraction of the predicted decrease that a step must achieve

# the connected components of the graph with an edge (r, c) where w |Sᵣ꜀| exceeds
# the penalty, by union-find
function _glasso_components(S::AbstractMatrix{T}, g::NormL1, w::T) where {T}
  p = size(S, 1)
  parent = collect(1:p)
  root(i) = (while parent[i] != i; parent[i] = parent[parent[i]]; i = parent[i]; end; i)
  for c in 1:p, r in c+1:p
    abs(S[r, c]) > _glasso_bound(g, p, r, c, w) || continue
    a, b = root(r), root(c)
    a == b || (parent[max(a, b)] = min(a, b))
  end
  comps = Dict{Int, Vector{Int}}()
  for i in 1:p
    push!(get!(comps, root(i), Int[]), i)
  end
  sort!(collect(values(comps)); by = first)
end

# the dense symmetric matrix of x
function _dense!(D::Matrix{T}, x::SymmetricSparseIterate{T}) where {T}
  fill!(D, zero(T))
  cx = coordinates(x)
  for k in activecoordinates(x)
    v = cx[k]
    r, c = tril_cartesian(x.p, k)
    D[r, c] = v
    D[c, r] = v
  end
  D
end

# QUIC on one problem (a component with more than one variable); X holds a
# positive definite start and the solution on return. Returns (F, D, passes,
# converged): the objective and the dual value at the solution.
function _quic!(X::SymmetricSparseIterate{T}, S::Matrix{T}, w::T, g::NormL1, method::ProxNewton, tol::Float64) where {T}
  p = X.p
  Xd, Wd, Xt, M = _dense!(zeros(T, p, p), X), zeros(T, p, p), zeros(T, p, p), zeros(T, p, p)
  copyto!(M, Xd)
  ld = _logdet_chol!(M)
  ld === nothing && throw(ArgumentError("the starting point must be positive definite."))
  _inverse_from_chol!(Wd, M)
  trSX, l1X = dot(S, Xd), g(Xd)
  F = w * (trSX - ld) + l1X
  Dual = _glasso_dual!(M, S, Wd, g, w)
  converged = _relative_gap(F, Dual) <= tol

  Cm = zeros(T, p, p)                     # S - W, the linear term of the model
  model = KronUModel(Wd, Wd, Cm, w)       # A = B = W, updated in place
  b = zeros(T, p, p)                      # -X: the model's penalty is g(X + Δ) = g(Δ - b)
  gt = Translate(g, b)
  D = SymmetricSparseIterate(T, p)
  st = _CDState(T, D, method.inner)
  free = sizehint!(Int[], p)
  passes = 0
  for it in 1:method.maxiter
    converged && break
    Cm .= S .- Wd
    b .= .-Xd
    # the free set: Xᵣ꜀ ≠ 0, or the gradient w (S - W) above the bound
    empty!(free)
    for c in 1:p, r in c:p
      (!iszero(Xd[r, c]) || abs(Cm[r, c]) > _glasso_bound(g, p, r, c, w)) && push!(free, tril_index(p, r, c))
    end
    # the Newton direction, from Δ = 0, with more passes as the steps get closer
    fill!(D, zero(T))
    initialize!(model, D)
    st.candidates = free
    inner = CDSolver(; maxpasses = min(method.inner.maxpasses, 2 * (1 + it ÷ 3)), tol = method.inner.tol,
                     order = method.inner.random ? :random : :cyclic, relative = method.inner.relative,
                     anderson = method.inner.anderson, rng = method.inner.rng)
    _cd!(D, model, gt, st, inner)
    st.candidates = nothing
    passes += st.passes
    nactive(D) == 0 && break             # no step: the model is minimized at X
    # the decrease the model predicts, ⟨∇f, Δ⟩ + g(X + Δ) - g(X), and tr(SΔ)
    trGD, trSD = zero(T), zero(T)
    cD = coordinates(D)
    for k in activecoordinates(D)
      r, c = tril_cartesian(p, k)
      μ = r == c ? one(T) : T(2)
      trGD += μ * Cm[r, c] * cD[k]
      trSD += μ * S[r, c] * cD[k]
    end
    _dense!(Xt, D)
    Xt .+= Xd
    δ = w * trGD + g(Xt) - l1X
    # Armijo line search; a point off the cone has no factor and is rejected
    α, accepted = one(T), false
    for _ in 1:50
      if α != 1
        _dense!(Xt, D)
        Xt .= Xd .+ α .* Xt
      end
      copyto!(M, Xt)
      ldt = _logdet_chol!(M)
      if ldt !== nothing
        trSXt, l1t = trSX + α * trSD, g(Xt)
        Ft = w * (trSXt - ldt) + l1t
        if Ft <= F + T(_quic_σ) * α * δ
          Xd, Xt = Xt, Xd
          _inverse_from_chol!(Wd, M)
          F, trSX, l1X, accepted = Ft, trSXt, l1t, true
          break
        end
      end
      α *= T(method.β)
    end
    accepted || break                    # no decrease along the step
    Dual = _glasso_dual!(M, S, Wd, g, w)
    converged = _relative_gap(F, Dual) <= tol
  end
  fill!(X, zero(T))
  for c in 1:p, r in c:p
    v = Xd[r, c]
    iszero(v) || (X[r, c] = v)
  end
  F, Dual, passes, converged
end

# the objective of one variable at its closed-form solution x = 1/(Sᵢᵢ + λᵢᵢ/w)
function _glasso_scalar(s::T, λ::T, w::T) where {T}
  a = s + λ / w
  isfinite(a) && a > 0 || throw(ArgumentError("the graphical-lasso diagonal needs a finite positive S[i,i] + penalty[i,i]/weight"))
  x = inv(a)
  isfinite(x) || throw(ArgumentError("the graphical-lasso diagonal solution overflows"))
  (x, w * (s * x - log(x)) + λ * x)
end

function solve!(X::SymmetricSparseIterate{T}, f::LogDetLoss{T}, g::NormL1, method::ProxNewton) where {T}
  S, w, p = f.S, f.w, X.p
  size(S, 1) == p || throw(DimensionMismatch("X is $p × $p and S is $(size(S, 1)) × $(size(S, 1))"))
  ProximalBase._checkparams(g, X)
  g = _newton_penalty(g, X)
  w > 0 || throw(ArgumentError("the weight of the LogDetLoss must be positive."))
  comps = _glasso_components(S, g, w)
  Xs = [_block_start(X, S, g, w, C) for C in comps]
  F, Dual, passes, converged = zero(T), zero(T), 0, true
  # each component to the relative gap tol; when the objectives of the
  # components have mixed signs, their gaps can add up to more than tol ⋅ |F|,
  # and a second round with a tighter tolerance makes up for it
  tol = method.tol
  for round in 1:2
    F, Dual, passes_round, Fabs, converged = zero(T), zero(T), 0, zero(T), true
    for (C, Xc) in zip(comps, Xs)
      if length(C) == 1
        i = C[1]
        _, Fi = _glasso_scalar(S[i, i], T(g.λ0) * T(_entryweight(g.w, (i - 1) * p + i, T)), w)
        F += Fi; Dual += Fi; Fabs += abs(Fi)
      else
        gc = g.w === nothing ? g : NormL1(g.λ0, g.w[C, C])
        Fc, Dc, pc, cc = _quic!(Xc, S[C, C], w, gc, method, tol)
        F += Fc; Dual += Dc; Fabs += abs(Fc); passes_round += pc
        converged &= cc
      end
    end
    passes += passes_round
    (F - Dual <= method.tol * abs(F) || !converged || length(comps) == 1) && break
    tol = method.tol * abs(F) / Fabs
  end
  _assemble!(X, comps, Xs, S, g, w)
  relgap = _relative_gap(F, Dual)
  CDResults(X, F, passes, converged && relgap <= method.tol, T(NaN), T(method.tol), 0, relgap)
end

# the start on component C: the values of X there when positive definite,
# otherwise the diagonal solution 1/(Sᵢᵢ + λᵢᵢ/w)
function _block_start(X::SymmetricSparseIterate{T}, S, g::NormL1, w::T, C::Vector{Int}) where {T}
  p, q = X.p, length(C)
  Xc = SymmetricSparseIterate(T, q)
  for (b, j) in enumerate(C), (a, i) in enumerate(C)
    a >= b || continue
    v = X[i, j]
    iszero(v) || (Xc[a, b] = v)
  end
  ok = nactive(Xc) > 0 && isposdef(Symmetric(Matrix(Xc)))
  if !ok
    fill!(Xc, zero(T))
    for (a, i) in enumerate(C)
      Xc[a, a] = first(_glasso_scalar(S[i, i], T(g.λ0) * T(_entryweight(g.w, (i - 1) * p + i, T)), w))
    end
  end
  Xc
end

# X ← the block-diagonal matrix of the solutions on the components
function _assemble!(X::SymmetricSparseIterate{T}, comps, Xs, S, g::NormL1, w::T) where {T}
  p = X.p
  fill!(X, zero(T))
  for (C, Xc) in zip(comps, Xs)
    if length(C) == 1
      i = C[1]
      X[i, i] = first(_glasso_scalar(S[i, i], T(g.λ0) * T(_entryweight(g.w, (i - 1) * p + i, T)), w))
    else
      cx = coordinates(Xc)
      for k in activecoordinates(Xc)
        a, b = tril_cartesian(length(C), k)
        v = cx[k]
        iszero(v) || (X[C[a], C[b]] = v)
      end
    end
  end
  X
end

function solve!(X::Matrix{T}, f::LogDetLoss{T}, g::NormL1, method::ProxNewton) where {T}
  Xs = SymmetricSparseIterate(Symmetric(X))
  r = solve!(Xs, f, g, method)
  copyto!(X, Matrix(Xs))
  CDResults(X, r.minimum, r.passes, r.converged, r.maxchange, r.tolerance, r.kkt_checks, r.gap)
end

solve!(X::Matrix, f::Scaled{<:LogDetLoss}, g::NormL1, method::ProxNewton) =
  solve!(X, LogDetLoss(f.f.S, f.α * f.f.w), g, method)
solve!(X::SymmetricSparseIterate, f::Scaled{<:LogDetLoss}, g::NormL1, method::ProxNewton) =
  solve!(X, LogDetLoss(f.f.S, f.α * f.f.w), g, method)
