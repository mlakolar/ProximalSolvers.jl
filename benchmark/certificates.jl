using LinearAlgebra, SparseArrays

struct Certificate
  value::Float64
  measure::Symbol
  status::Symbol
  primal::Float64
  dual::Float64
  detail::String
end

uncertifiable(detail; measure = :relative_gap, primal = NaN, dual = NaN) =
  Certificate(NaN, measure, :uncertifiable, primal, dual, detail)

cert_finite(x::Real) = isfinite(x)
cert_finite(x::AbstractArray) = all(cert_finite, x)
cert_finite(xs...) = all(cert_finite, xs)
cert_soft(x, λ) = sign(x) * max(abs(x) - λ, 0.0)
cert_maxabs(x) = maximum(abs, x; init = 0.0)

function relative_certificate(primal, dual; scale = 0.0, terms::Integer = 1)
  P, D = Float64(primal), Float64(dual)
  cert_finite(P, D) || return uncertifiable("nonfinite objective"; primal = P, dual = D)
  cert_finite(scale) && scale >= 0 && terms >= 1 && terms * eps(Float64) < 1 ||
    return uncertifiable("invalid roundoff scale"; primal = P, dual = D)
  # γ_m = m*eps/(1-m*eps) bounds reduction error relative to the sum of term magnitudes.
  # The scale covers cancellation; factor 16 allows several reductions in P and D.
  γ = terms * eps(Float64) / (1 - terms * eps(Float64))
  tol = 16γ * (abs(P) + abs(D) + scale)
  isfinite(tol) || return uncertifiable("nonfinite roundoff bound"; primal = P, dual = D)
  raw = P - D
  raw < -tol &&
    return uncertifiable("weak duality violation"; primal = P, dual = D)
  value = max(raw, 0.0) / max(abs(P), floatmin(Float64))
  isfinite(value) || return uncertifiable("nonfinite relative gap"; primal = P, dual = D)
  Certificate(value, :relative_gap, :ok, P, D, "")
end

function residual_certificate(value, primal; measure = :kkt_residual, dual = NaN)
  cert_finite(value, primal) && value >= 0 ||
    return uncertifiable("nonfinite residual or objective"; measure, primal, dual)
  Certificate(Float64(value), measure, :ok, Float64(primal), Float64(dual), "")
end

function cert_regression_valid(X, y, s, β)
  size(X, 1) == length(y) && size(X, 2) == length(β) &&
    cert_finite(X, y, s, β) && s > 0
end

function cert_l1_scale(z, bounds)
  t = 1.0
  for j in eachindex(z, bounds)
    abs(z[j]) > 0 && (t = min(t, bounds[j] / abs(z[j])))
  end
  t
end

function lasso_dual_point(X, y, s, λ, w, β)
  θ = s .* (y - X * β)
  θ .*= cert_l1_scale(X' * θ, λ .* w)
  θ
end

function lasso_certificate(X, y, s, λ, w, β)
  cert_regression_valid(X, y, s, β) && length(w) == length(β) &&
    cert_finite(λ, w) && λ >= 0 && all(>=(0), w) ||
    return uncertifiable("invalid least-squares inputs")
  r = y - X * β
  # NormL1(λ, w) = λ Σ w[j]|β[j]|; s*LeastSquaresLoss = s||r||²/2.
  penalty = λ * dot(w, abs.(β))
  P = s * sum(abs2, r) / 2 + penalty
  if λ == 0 || any(iszero, w)
    # Free coordinates require |X[j]'s*r|, not division by a zero weight.
    grad = -s .* (X' * r)
    residual = maximum((β[j] == 0 ? max(abs(grad[j]) - λ * w[j], 0.0) :
                        abs(grad[j] + λ * w[j] * sign(β[j]))
                        for j in eachindex(β)); init = 0.0)
    return residual_certificate(residual, P)
  end
  θ = lasso_dual_point(X, y, s, λ, w, β)
  scale = s * sum(abs2, y) / 2 + penalty
  relative_certificate(P, dot(y, θ) - sum(abs2, θ) / (2s); scale, terms = max(size(X)..., 1))
end

function cert_groups_valid(groups, w, p)
  length(groups) == length(w) && cert_finite(w) && all(>=(0), w) || return false
  indices = Int[]
  for group in groups
    append!(indices, group)
  end
  all(i -> 1 <= i <= p, indices) && length(unique(indices)) == length(indices)
end

function group_dual_point(X, y, s, λ, groups, w, β)
  θ = s .* (y - X * β)
  z = X' * θ
  t = 1.0
  for (g, weight) in zip(groups, w)
    a = norm(z[g])
    a > 0 && (t = min(t, λ * weight / a))
  end
  covered = falses(length(β))
  for g in groups
    covered[g] .= true
  end
  any(!covered[j] && z[j] != 0 for j in eachindex(β)) && (t = 0.0)
  t .* θ
end

function group_certificate(X, y, s, λ, groups, w, β)
  cert_regression_valid(X, y, s, β) && cert_finite(λ) && λ >= 0 &&
    cert_groups_valid(groups, w, length(β)) || return uncertifiable("invalid group inputs")
  # GroupNormL2(λ, groups, w) = λ Σ w[g]||β[g]||₂; defaults w[g]=sqrt(length(g)).
  penalty = λ * sum((w[k] * norm(β[g]) for (k, g) in enumerate(groups)); init = 0.0)
  P = s * sum(abs2, y - X * β) / 2 + penalty
  θ = group_dual_point(X, y, s, λ, groups, w, β)
  scale = s * sum(abs2, y) / 2 + penalty
  relative_certificate(P, dot(y, θ) - sum(abs2, θ) / (2s); scale, terms = max(size(X)..., 1))
end

function sparse_group_dual_point(X, y, s, λ, α, groups, w, β)
  θ = s .* (y - X * β)
  z = X' * θ
  feasible(t) = all(norm(cert_soft.(t .* z[g], λ * α)) <= λ * (1 - α) * w[k]
                    for (k, g) in enumerate(groups))
  covered = falses(length(β))
  for g in groups
    covered[g] .= true
  end
  any(!covered[j] && z[j] != 0 for j in eachindex(β)) && return zero.(θ)
  feasible(1.0) && return θ
  lo, hi = 0.0, 1.0
  for _ in 1:64
    mid = (lo + hi) / 2
    if feasible(mid)
      lo = mid
    else
      hi = mid
    end
  end
  lo .* θ
end

function sparse_group_certificate(X, y, s, λ, α, groups, w, β)
  cert_regression_valid(X, y, s, β) && cert_finite(λ, α) && λ >= 0 && 0 <= α <= 1 &&
    cert_groups_valid(groups, w, length(β)) || return uncertifiable("invalid sparse-group inputs")
  # λ*SparseGroupNormL2(α, 1-α, groups, w) has L1 level λα and group level λ(1-α).
  # ProximalBase leaves indices outside all groups entirely unpenalized.
  penalty = sum((α * sum(abs, β[g]) + (1 - α) * w[k] * norm(β[g])
                 for (k, g) in enumerate(groups)); init = 0.0)
  P = s * sum(abs2, y - X * β) / 2 + λ * penalty
  θ = sparse_group_dual_point(X, y, s, λ, α, groups, w, β)
  scale = s * sum(abs2, y) / 2 + λ * penalty
  relative_certificate(P, dot(y, θ) - sum(abs2, θ) / (2s); scale, terms = max(size(X)..., 1))
end

function slope_dual_point(X, y, s, λ, β)
  θ = s .* (y - X * β)
  z = cumsum(sort!(abs.(X' * θ); rev = true))
  bounds = cumsum(λ)
  θ .*= cert_l1_scale(z, bounds)
  θ
end

function slope_certificate(X, y, s, λ, β)
  cert_regression_valid(X, y, s, β) && length(λ) == length(β) && cert_finite(λ) &&
    all(>=(0), λ) && issorted(λ; rev = true) || return uncertifiable("invalid SLOPE inputs")
  # SLOPE(λ) = Σ λ[j]*sort(abs.(β), rev=true)[j], with no additional scalar level.
  penalty = dot(λ, sort!(abs.(β); rev = true))
  P = s * sum(abs2, y - X * β) / 2 + penalty
  θ = slope_dual_point(X, y, s, λ, β)
  scale = s * sum(abs2, y) / 2 + penalty
  relative_certificate(P, dot(y, θ) - sum(abs2, θ) / (2s); scale, terms = max(size(X)..., 1))
end

cert_sigmoid(x) = x >= 0 ? inv(1 + exp(-x)) : exp(x) / (1 + exp(x))
cert_entropy(u) = (u == 0 ? 0.0 : u * log(u)) + (u == 1 ? 0.0 : (1 - u) * log1p(-u))
cert_log1pexp(x) = max(x, 0.0) + log1p(exp(-abs(x)))

function logistic_dual_point(X, y, s, λ, w_obs, offset, β)
  probability = cert_sigmoid.(X * β + offset)
  θ = s .* w_obs .* (y - probability)
  t = cert_l1_scale(X' * θ, fill(λ, length(β)))
  (; θ = t .* θ, u = (1 - t) .* y + t .* probability, t)
end

function logistic_certificate(X, y, s, λ, w_obs, offset, β)
  cert_regression_valid(X, y, s, β) && length(w_obs) == length(y) == length(offset) &&
    cert_finite(λ, w_obs, offset) && λ >= 0 && all(>=(0), w_obs) &&
    all(u -> 0 <= u <= 1, y) || return uncertifiable("invalid logistic inputs")
  # LogisticLoss sums observation weights; its scale is s, not s/n.
  # θ includes s*w_obs; translating η=Xβ+offset subtracts dot(offset,θ) from the dual.
  η = X * β + offset
  all(isfinite, η) || return uncertifiable("nonfinite linear predictor")
  log_terms = cert_log1pexp.(η)
  penalty = λ * sum(abs, β)
  P = s * sum(w_obs .* (log_terms - y .* η)) + penalty
  point = logistic_dual_point(X, y, s, λ, w_obs, offset, β)
  all(u -> 0 <= u <= 1, point.u) || return uncertifiable("entropy outside its domain"; primal = P)
  entropy = cert_entropy.(point.u)
  D = -s * sum(w_obs .* entropy) - dot(offset, point.θ)
  scale = s * sum(w_obs .* (abs.(log_terms) + abs.(y .* η) + abs.(entropy))) +
    penalty + dot(abs.(offset), abs.(point.θ))
  relative_certificate(P, D; scale, terms = max(size(X)..., 1))
end

function sqrt_dual_point(X, y, λ, β)
  θ = (y - X * β) / norm(y - X * β)
  z = cert_maxabs(X' * θ)
  θ .*= z == 0 ? 1.0 : min(1.0, λ / z)
  θ
end

function sqrt_lasso_certificate(X, y, λ, β; fit_floor = 1e-12)
  cert_regression_valid(X, y, 1.0, β) && cert_finite(λ, fit_floor) && λ >= 0 && fit_floor >= 0 ||
    return uncertifiable("invalid square-root inputs")
  # SqrtLeastSquaresLoss = ||y-Xβ||₂, without a sqrt(n) factor.
  rnorm = norm(y - X * β)
  penalty = λ * sum(abs, β)
  P = rnorm + penalty
  rnorm > fit_floor || return uncertifiable("residual norm at or below fit_floor"; primal = P)
  θ = sqrt_dual_point(X, y, λ, β)
  relative_certificate(P, dot(y, θ); scale = norm(y) + penalty, terms = max(size(X)..., 1))
end

function quadratic_certificate(A, b, c, λ, β)
  size(A) == (length(β), length(β)) && length(b) == length(β) &&
    cert_finite(A, b, c, λ, β) && λ >= 0 ||
    return uncertifiable("invalid quadratic inputs"; measure = :kkt_residual)
  # The plain-data sign is -b'β; QuadraticFunction(A, -b, c) uses the same objective.
  grad = A * β - b
  P = dot(β, A * β) / 2 - dot(b, β) + c + λ * sum(abs, β)
  residual_certificate(cert_maxabs(β - cert_soft.(β - grad, λ)), P)
end

function glasso_dual_matrix(S, Λ, Θ)
  bounds = (Λ + Λ') / 2
  covariance = (S + S') / 2
  inverse = inv(Symmetric((Θ + Θ') / 2))
  U = clamp.(inverse - covariance, -bounds, bounds)
  covariance + (U + U') / 2
end

function glasso_certificate(S, Λ, Θ)
  size(S) == size(Λ) == size(Θ) && size(S, 1) == size(S, 2) &&
    cert_finite(S, Λ, Θ) && all(>=(0), Λ) || return uncertifiable("invalid graphical-lasso inputs")
  issymmetric(Θ) || return uncertifiable("precision matrix is not symmetric")
  covariance, bounds = (S + S') / 2, (Λ + Λ') / 2
  # NormL1(1, Λ) sums all matrix entries. On symmetric Θ the effective bounds
  # are (Λ+Λ')/2, including the diagonal; LogDetLoss(S) has unit logdet weight.
  factor = cholesky(Symmetric(Θ); check = false)
  issuccess(factor) || return uncertifiable("precision matrix is not positive definite")
  P = -logdet(factor) + dot(covariance, Θ) + sum(bounds .* abs.(Θ))
  W = glasso_dual_matrix(S, Λ, Θ)
  all(isfinite, W) || return uncertifiable("nonfinite dual matrix"; primal = P)
  dual_factor = cholesky(Symmetric(W); check = false)
  issuccess(dual_factor) || return uncertifiable("dual matrix is not positive definite"; primal = P)
  scale = 2sum(x -> abs(log(x)), diag(factor.L)) + dot(abs.(covariance), abs.(Θ)) +
    sum(bounds .* abs.(Θ)) + 2sum(x -> abs(log(x)), diag(dual_factor.L)) + size(Θ, 1)
  relative_certificate(P, logdet(dual_factor) + size(Θ, 1); scale, terms = max(length(Θ), 1))
end

function generalized_lasso_bound(X, y, s, μ, D, λ1, λ2, β, v)
  # examples/support/primal_dual_lessons.jl:58-72: μ-strongly convex lower model.
  vf = clamp.(v, -λ2, λ2)
  r = X * β - y
  fx = s * sum(abs2, r) / 2 + μ * sum(abs2, β) / 2
  grad, d = s .* (X' * r) + μ .* β, D' * vf
  z = cert_soft.(β - (grad + d) / μ, λ1 / μ)
  lower = fx + dot(grad, z - β) + μ * sum(abs2, z - β) / 2 +
    λ1 * sum(abs, z) + dot(d, z)
  primal = fx + λ1 * sum(abs, β) + λ2 * sum(abs, D * β)
  scale = s * sum(abs2, y) / 2 + primal + fx + dot(abs.(grad), abs.(z - β)) +
    μ * sum(abs2, z - β) / 2 + λ1 * sum(abs, z) + dot(abs.(d), abs.(z))
  (; primal, lower, dual = vf, z, scale)
end

function generalized_lasso_certificate(X, y, s, μ, D, λ1, λ2, β, v)
  cert_regression_valid(X, y, s, β) && size(D) == (length(v), length(β)) &&
    cert_finite(μ, D, λ1, λ2, v) && μ > 0 && λ1 >= 0 && λ2 >= 0 ||
    return uncertifiable("invalid generalized-lasso inputs")
  a = generalized_lasso_bound(X, y, s, μ, D, λ1, λ2, β, v)
  relative_certificate(a.primal, a.lower; scale = a.scale, terms = max(size(X)..., size(D)..., 1))
end

function cert_mcp_value(x, λ, a)
  t = abs(x)
  t <= a * λ ? λ * t - t^2 / (2a) : a * λ^2 / 2
end

function cert_mcp_prox(x, λ, a, γ)
  t = abs(x)
  t <= γ * λ && return 0.0
  t > a * λ && return x
  sign(x) * (t - γ * λ) / (1 - γ / a)
end

function cert_scad_value(x, λ, a)
  t = abs(x)
  t <= λ && return λ * t
  t <= a * λ && return (2a * λ * t - t^2 - λ^2) / (2(a - 1))
  λ^2 * (a + 1) / 2
end

function cert_scad_prox(x, λ, a, γ)
  t = abs(x)
  t <= (1 + γ) * λ && return cert_soft(x, γ * λ)
  t > a * λ && return x
  sign(x) * ((a - 1) * t - γ * a * λ) / (a - 1 - γ)
end

function cert_nonconvex(X, y, s, λ, a, L, β, kind)
  measure = :fixed_point_residual
  cert_regression_valid(X, y, s, β) && cert_finite(λ, a, L) && λ >= 0 && L > 0 ||
    return uncertifiable("invalid nonconvex inputs"; measure)
  γ = 1 / L
  single_valued = kind == :mcp ? a > γ : a > 2 && a - 1 > γ
  single_valued || return uncertifiable("step outside the single-valued proximal range"; measure)
  value, prox = kind == :mcp ? (cert_mcp_value, cert_mcp_prox) : (cert_scad_value, cert_scad_prox)
  grad = s .* (X' * (X * β - y))
  z = prox.(β - γ .* grad, λ, a, γ)
  P = s * sum(abs2, y - X * β) / 2 + sum(value.(β, λ, a))
  residual_certificate(cert_maxabs(β - z) / γ, P; measure)
end

# MCP(λ,a) and SCAD(λ,a) use the scalar penalties above, without a loss scale.
mcp_certificate(X, y, s, λ, a, L, β) = cert_nonconvex(X, y, s, λ, a, L, β, :mcp)
scad_certificate(X, y, s, λ, a, L, β) = cert_nonconvex(X, y, s, λ, a, L, β, :scad)

function cert_hard_threshold(x, k)
  order = sortperm(collect(eachindex(x)); by = i -> (-abs(x[i]), i))
  z = zero.(x)
  for j in order[1:k]
    z[j] = x[j]
  end
  z
end

function iht_certificate(X, y, s, k, L, β)
  measure = :fixed_point_residual
  cert_regression_valid(X, y, s, β) && cert_finite(L) && L > 0 &&
    k isa Integer && 0 <= k <= length(β) || return uncertifiable("invalid IHT inputs"; measure)
  count(!iszero, β) <= k || return uncertifiable("L0 constraint violated"; measure)
  γ = 1 / L
  grad = s .* (X' * (X * β - y))
  z = cert_hard_threshold(β - γ .* grad, k)
  residual_certificate(cert_maxabs(β - z) / γ, s * sum(abs2, y - X * β) / 2; measure)
end

function path_certificate(certs::Vector{Certificate})
  isempty(certs) && return uncertifiable("empty path")
  bad = findfirst(c -> c.status != :ok, certs)
  bad === nothing || return certs[bad]
  all(c -> c.measure == certs[1].measure, certs) || return uncertifiable("mixed path measures")
  certs[argmax([c.value for c in certs])]
end

function certify(problem::NamedTuple, β)
  a = problem
  a.kind == :lasso && return lasso_certificate(a.X, a.y, a.s, a.λ, a.w, β)
  a.kind == :group && return group_certificate(a.X, a.y, a.s, a.λ, a.groups, a.w_group, β)
  a.kind == :sparse_group &&
    return sparse_group_certificate(a.X, a.y, a.s, a.λ, a.α, a.groups, a.w_group, β)
  a.kind == :slope && return slope_certificate(a.X, a.y, a.s, a.λ, β)
  a.kind == :logistic && return logistic_certificate(a.X, a.y, a.s, a.λ, a.w_obs, a.offset, β)
  a.kind == :sqrt_lasso && return sqrt_lasso_certificate(a.X, a.y, a.λ, β; fit_floor = a.fit_floor)
  a.kind == :glasso && return glasso_certificate(a.S, a.Λ, β)
  a.kind == :mcp && return mcp_certificate(a.X, a.y, a.s, a.λ, a.a, a.L, β)
  a.kind == :scad && return scad_certificate(a.X, a.y, a.s, a.λ, a.a, a.L, β)
  a.kind == :iht && return iht_certificate(a.X, a.y, a.s, a.k, a.L, β)
  if a.kind == :generalized_lasso
    return generalized_lasso_certificate(a.X, a.y, a.s, a.μ, a.D, a.λ1, a.λ2, β.x, β.y)
  elseif a.kind == :quadratic
    residual = quadratic_certificate(a.A, a.b, a.c, a.λ, β)
    gap = lasso_certificate(a.X, a.y, a.s, a.λ, a.w, β)
    residual.status == :ok || return residual
    gap.status == :ok || return uncertifiable(gap.detail; measure = :kkt_residual)
    # The least-squares gap remains available as (primal-dual)/abs(primal).
    return residual_certificate(residual.value, gap.primal; dual = gap.dual)
  end
  uncertifiable("unsupported problem kind $(a.kind)")
end
