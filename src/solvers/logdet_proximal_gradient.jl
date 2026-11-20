using ProximalBase: gradient!, value_and_gradient!

function _logdet_pgd_preflight(Θ::Matrix{T}, f, g, ls, options) where T
  isone(f.w) || throw(ArgumentError("matrix PGD requires a LogDetLoss weight of one"))
  g.w isa Matrix{T} || throw(ArgumentError("matrix PGD requires dense $T NormL1 weights"))
  S, Λ = f.S, g.w
  !isempty(Θ) && size(Θ, 1) == size(Θ, 2) ||
    throw(DimensionMismatch("Θ must be a nonempty square matrix"))
  size(Θ) == size(S) == size(Λ) ||
    throw(DimensionMismatch("Θ, S and the NormL1 weights must have the same size"))
  λ0 = _admm_level(g.λ0, T, "the NormL1 level")
  _allfinite(Θ) && _allfinite(S) && _allfinite(Λ) ||
    throw(ArgumentError("Θ, S and the NormL1 weights must be finite"))
  _admm_issymmetric(Θ) && _admm_issymmetric(S) && _admm_issymmetric(Λ) ||
    throw(ArgumentError("Θ, S and the NormL1 weights must be exactly symmetric"))
  all(>=(zero(T)), Λ) && all(i -> iszero(Λ[i, i]), axes(Λ, 1)) ||
    throw(ArgumentError("the NormL1 weights must be nonnegative with zero diagonal"))
  (_admm_mightalias(Θ, S) || _admm_mightalias(Θ, Λ) || _admm_mightalias(S, Λ)) &&
    throw(ArgumentError("Θ, S and the NormL1 weights must be independent buffers"))
  (options.allow_f_increases || options.store_trace || options.show_trace ||
   options.extended_trace || options.callback !== nothing || options.print_every != 1) &&
    throw(ArgumentError("matrix PGD requires default objective-increase, trace, callback and print settings"))
  ls.Lexact == Inf || throw(ArgumentError("matrix PGD requires Lexact = Inf"))
  α, β = T(ls.α), T(ls.β)
  zero(T) < α <= one(T) && isfinite(inv(α)) && zero(T) < β < one(T) ||
    throw(ArgumentError("matrix PGD requires 0 < α ≤ 1 with finite 1/α and 0 < β < 1 in $T"))
  C = λ0 .* Λ
  _allfinite(C) || throw(ArgumentError("matrix PGD requires finite effective NormL1 weights"))
  scratch = similar(Θ)
  _admm_passes_cholesky!(scratch, Θ) ||
    throw(ArgumentError("Θ must have a successful Cholesky factorization in $T"))
  C, max(one(T), maximum(abs, S), maximum(C)), α, β, scratch
end

function _logdet_pgd_symmetrize!(G::Matrix{T}, S) where T
  _allfinite(G) || error("matrix PGD produced a nonfinite logdet gradient")
  @inbounds for j in axes(G, 2), i in 1:j-1
    a, b = G[i, j], G[j, i]
    # Include the scale of S in case of cancellation in S - inv(Θ).
    abs(a - b) / max(one(T), abs(a), abs(b), abs(S[i, j])) <= 8eps(T) ||
      error("matrix PGD received a logdet gradient with excessive asymmetry")
    G[i, j] = G[j, i] = a + (b - a) / 2
  end
  nothing
end

function _logdet_pgd_kkt(Θ, G, C, scale)
  worst = zero(eltype(Θ))
  @inbounds for i in eachindex(Θ, G, C)
    violation = iszero(Θ[i]) ? max(abs(G[i]) - C[i], zero(worst)) :
                               abs(G[i] + C[i] * sign(Θ[i]))
    worst = max(worst, violation)
  end
  isfinite(worst) || error("matrix PGD produced a nonfinite KKT violation")
  Float64(worst / scale)
end

function _logdet_pgd_trial_argument!(V, Θ, G, t)
  @inbounds for j in axes(Θ, 2), i in 1:j
    V[i, j] = V[j, i] = Θ[i, j] - t * G[i, j]
  end
  _allfinite(V)
end

function _logdet_pgd_majorizes(G, D, t::T, loss, next_loss) where T
  linear = dot(G, D)
  quadratic = (dot(D, D) / 2) / t
  model = loss + linear + quadratic
  isfinite(model) || return false
  # Scale the comparison slack by its terms so loss/model cancellation does
  # not shrink the allowance. This is a working-precision comparison.
  slack = 16eps(T) * max(one(T), abs(loss), abs(next_loss), abs(linear), quadratic)
  next_loss - model <= slack
end

_logdet_pgd_call_limit(o, f_calls, grad_calls, prox_calls) =
  (0 < o.f_calls_limit <= f_calls || 0 < o.grad_calls_limit <= grad_calls ||
   0 < o.prox_calls_limit <= prox_calls)

_logdet_pgd_time_limit(o, start) = (time_ns() - start) * 1e-9 >= o.time_limit

function solve!(Θ::Matrix{T}, f::LogDetLoss{T}, g::NormL1, method::ProximalGradientDescent,
                options::ProximalOptions = ProximalOptions(); kwargs...) where T
  _check_keywords(kwargs)
  start = time_ns()
  C, scale, α, β, scratch = _logdet_pgd_preflight(Θ, f, g, method.ls, options)
  G, V, Z, D = similar(Θ), similar(Θ), similar(Θ), similar(Θ)
  loss = value_and_gradient!(G, f, Θ)
  objective = loss + g(Θ)
  isfinite(objective) || throw(ArgumentError("matrix PGD requires a finite starting objective"))
  _logdet_pgd_symmetrize!(G, f.S)
  score = _logdet_pgd_kkt(Θ, G, C, scale)
  gtol = max(options.gradtol, Float64(64eps(T)))

  t = one(T)
  steps = trials = prox_calls = 0
  f_calls = grad_calls = 1
  x_change = f_change = NaN
  increased = converged = stagnated = false
  call_limit = _logdet_pgd_call_limit(options, f_calls, grad_calls, prox_calls)
  while steps < options.maxiter && !call_limit && !_logdet_pgd_time_limit(options, start)
    steps > 0 && (t = min(one(T), t / α))
    accepted = false
    next_loss, next_objective = loss, objective
    for attempt in 1:64
      isfinite(t) && t > zero(T) && isfinite(inv(t)) && inv(t) > zero(T) ||
        error("matrix PGD line search requires a finite positive step and reciprocal")
      trials += 1
      if _logdet_pgd_trial_argument!(V, Θ, G, t)
        prox_calls += 1
        prox!(Z, g, V, t)
        if _admm_passes_cholesky!(scratch, Z)
          f_calls += 1
          next_loss = f(Z)
          next_objective = next_loss + g(Z)
          if isfinite(next_objective)
            D .= Z .- Θ
            slack = 16eps(T) * max(one(T), abs(next_objective), abs(objective))
            if next_objective - objective <= slack && _logdet_pgd_majorizes(G, D, t, loss, next_loss)
              accepted = true
              break
            end
          end
        end
      end
      attempt == 64 && error("matrix PGD line search failed after 64 trials")
      call_limit = _logdet_pgd_call_limit(options, f_calls, grad_calls, prox_calls)
      (call_limit || _logdet_pgd_time_limit(options, start)) && break
      next_t = t * β
      next_t < t || error("matrix PGD line search could not reduce the step")
      t = next_t
    end
    accepted || break

    grad_calls += 1
    gradient!(G, f, Z)
    _logdet_pgd_symmetrize!(G, f.S)
    score = _logdet_pgd_kkt(Z, G, C, scale)
    x_change = Float64(norm(D))
    f_change = f_residual(next_objective, objective, options.ftol)
    increased = next_objective > objective
    unchanged = Z == Θ
    copyto!(Θ, Z)
    loss, objective = next_loss, next_objective
    steps += 1

    stationary = score <= gtol
    stagnated = unchanged && !stationary
    call_limit = _logdet_pgd_call_limit(options, f_calls, grad_calls, prox_calls)
    limited = call_limit || steps == options.maxiter || _logdet_pgd_time_limit(options, start)
    converged = stationary && !limited
    (converged || stagnated || limited) && break
  end

  trace = OptimizationTrace{typeof(method)}()
  x_converged = converged && x_change < options.xtol
  f_converged = converged && options.ftol > 0 && f_change < options.ftol
  OptimizationResults{typeof(method), T, 2, typeof(method), typeof(Θ)}(
    method, Θ, objective, steps, steps == options.maxiter, converged,
    x_converged, options.xtol, x_change, f_converged, options.ftol, f_change,
    converged, gtol, score, increased, trace, trials, f_calls, grad_calls, prox_calls,
    call_limit, stagnated, NaN)
end
