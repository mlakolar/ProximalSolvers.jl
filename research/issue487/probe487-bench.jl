# #487 round 2: cost of candidate stopping diagnostics (research only; production code untouched).
# Production-shaped, allocation-free check kernels for: cur (the merged check), A (merged check with a
# profiled λ̂: QR of X_F at the first check), B (angle rule: column norms at the first check, O(n + p) per check
# from the cached image), E (duality gap: QR of X_F and the Gram X'X_F at the first check, O(n|F| + p|F|) per check).
# Sections: (1) one-time initialization cost, (2) per-check cost at a fixed accepted point, (3) total solve time,
# rules interleaved in a random order per repetition, with an A/A control (cur twice).
using ProximalSolvers, ProximalBase, LinearAlgebra, Random, Printf, Statistics
const PS = ProximalSolvers
BLAS.set_num_threads(1)

const RULE = Ref(:cur)
mutable struct BCtx{T}
  F::Vector{Int}; P::Vector{Int}
  lhat::T; colsq::Vector{T}
  QF::Any; G::Matrix{T}; w::Vector{T}; qp::Vector{T}; gt::Vector{T}
  init::Bool
end
const CTXB = Ref{Any}(nothing)
const DED = Union{NormL1, NormL1Nonneg, IndNonnegative, ElasticNet, GroupNormL2, NormL2}

function cur_check(state, f, g, options, λmax)
  T = eltype(state.x)
  grad = PS._gradient_at_x!(state, f)
  gT = PS._converted_penalty(g, T)
  λ = PS._l1_level(gT)
  residual = kkt_violation(gT, grad, state.x)
  S = max(λ, λmax)
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  threshold = τ * S
  isfinite(S) && threshold >= floatmin(T) && isfinite(residual) && residual < threshold &&
    (λ <= λmax || PS._entry_thresholds_hold(gT, grad, state.x, τ, λmax))
end

function init_ctx!(C::BCtx{T}, state, g, rule) where T
  C.init && return C
  X, y = state.model.X, state.model.Y
  if rule === :A && !isempty(C.F)
    XF = X[:, C.F]; b = zeros(T, size(X, 2)); b[C.F] .= XF \ y
    gF = T(state.model.α) .* (X' * (X * b .- y))
    C.lhat = PS._scale_norm(g)(gF)
  elseif rule === :B
    colsq!(C.colsq, X)
  elseif rule === :E && !isempty(C.F)
    C.QF = qr(X[:, C.F], ColumnNorm()); C.G = X' * X[:, C.F]
  end
  C.init = true
  C
end

# B: score_i < τ sqrt(α‖X_i‖²) sqrt(α‖z − y‖²) with z = A x cached by the solver (λ2 = 0 here)
function B_check(state, f, g::NormL1, options, C::BCtx{T}) where T
  grad = PS._gradient_at_x!(state, f)
  z, y, x = state.z_x, state.model.Y, state.x
  α = T(state.model.α)
  r2 = zero(T); @inbounds @simd for i in eachindex(z, y); r2 += (z[i] - y[i])^2; end
  sr = sqrt(α * r2)
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  λ0 = T(g.λ0); w = g.w
  @inbounds for i in eachindex(x)
    c = λ0 * w[i]
    sc = iszero(x[i]) ? abs(grad[i]) - c : abs(grad[i] + c * sign(x[i]))
    t = τ * sqrt(α * C.colsq[i]) * sr
    (isfinite(sc) && t >= floatmin(T) && sc < t) || return false
  end
  true
end

# E: relative gap ≤ ftol, θ projected onto null(X_Fᵀ) (λ2 = 0), then scaled
function E_check(state, f, g::NormL1, options, C::BCtx{T}) where T
  grad = PS._gradient_at_x!(state, f)
  z, y, x, X = state.z_x, state.model.Y, state.x, state.model.X
  α = T(state.model.α); λ0 = T(g.λ0); w = g.w
  qp = C.qp
  @inbounds @simd for i in eachindex(z, y); qp[i] = z[i] - y[i]; end
  q2 = zero(T); @inbounds @simd for i in eachindex(qp); q2 += qp[i]^2; end
  P = α * q2 / 2
  @inbounds for i in eachindex(x); P += λ0 * w[i] * abs(x[i]); end
  copyto!(C.gt, grad)
  if !isempty(C.F)
    C.w .= C.QF \ qp                              # w = X_F \ q (allocates the solve's work arrays)
    @inbounds for (t, j) in enumerate(C.F), i in eachindex(qp); qp[i] -= X[i, j] * C.w[t]; end
    mul!(C.gt, C.G, C.w, -α, one(T))               # gt = ∇f − α XᵀX_F w
    @inbounds for j in C.F; C.gt[j] = 0; end
  end
  κ = one(T)
  @inbounds for i in eachindex(x)
    c = λ0 * w[i]; a = abs(C.gt[i])
    c > 0 && a > c && (κ = min(κ, c / a))
  end
  qy = zero(T); qq = zero(T); fl = zero(T)
  @inbounds @simd for i in eachindex(qp); qy += qp[i] * y[i]; qq += qp[i]^2; fl += abs(qp[i] * y[i]); end
  D = -κ * α * qy - κ^2 * α * qq / 2
  gap = P - D
  ftol = T(options.ftol)
  floor = eps(T) / 2 * (α * fl + α * qq + 2P)
  isfinite(gap) && P > 0 && ftol * P >= floor && gap <= ftol * P
end

function PS._stationary!(state, f, g::DED, options::ProximalOptions)
  r = RULE[]
  T = eltype(state.x)
  if r === :cur || r === :cur2
    return cur_check(state, f, g, options, PS._lambda_max!(state, PS._scale_norm(g)))
  end
  C = init_ctx!(CTXB[], state, g, r)
  if r === :A
    λm = isempty(C.F) ? PS._lambda_max!(state, PS._scale_norm(g)) : (state.λmax = C.lhat)
    return cur_check(state, f, g, options, λm)
  end
  PS._lambda_max!(state, PS._scale_norm(g))
  r === :B ? B_check(state, f, g, options, C) : E_check(state, f, g, options, C)
end

newctx(::Type{T}, n, p, F) where T = BCtx{T}(F, setdiff(1:p, F), zero(T), zeros(T, p), nothing, zeros(T, p, length(F)),
  zeros(T, length(F)), zeros(T, n), zeros(T, p), false)

function problem(::Type{T}, n, p, nF, seed) where T
  rng = MersenneTwister(seed)
  X = randn(rng, n, p)
  F = collect(1:nF)
  if nF > 0
    X[:, 1] .= 1
    for j in 2:nF; X[:, j] .+= 5; end
  end
  β = zeros(p); k = min(10, p - nF); β[nF .+ (1:k)] .= range(2, 0.5, length = k)
  nF > 1 && (β[2:nF] .= 1.0)
  y = X * β .+ 0.5 .* randn(rng, n) .+ (nF > 0 ? 1e4 : 0.0)
  w = ones(p); w[F] .= 0
  # λ0 = half the level at which every penalized coefficient is zero
  b = zeros(p); nF > 0 && (b[F] .= X[:, F] \ y)
  gr = X' * (X * b .- y)
  λ0 = 0.5 * maximum(abs(gr[j]) for j in 1:p if w[j] > 0)
  T.(X), T.(y), T(λ0), T.(w), F
end

function colsq!(cs, X)
  @inbounds for j in axes(X, 2)
    s = zero(eltype(X))
    @simd for i in axes(X, 1); s += X[i, j]^2; end
    cs[j] = s
  end
  cs
end

function timeit(f; reps = 200, mintime = 0.05)
  f(); t = Float64[]
  for _ in 1:reps
    t0 = time_ns(); k = 0
    while true
      f(); k += 1
      (time_ns() - t0) > mintime * 1e9 / 10 && break
    end
    push!(t, (time_ns() - t0) / k)
    sum(t) > mintime * 1e9 * 20 && break
  end
  minimum(t), median(t)
end

function main()
  println("julia ", VERSION, " cpu ", Sys.cpu_info()[1].model, " threads ", Threads.nthreads(), " BLAS ", BLAS.get_num_threads())
  sizes = haskey(ENV, "BENCH_SMALL") ? [(200, 50, 2)] : [(200, 50, 21), (2000, 500, 9), (5000, 1000, 5)]
  T = Float64
  println(join(["section", "n", "p", "nF", "method", "rule", "rep", "time_ns", "median_ns", "alloc_bytes", "iters", "converged", "grad_calls", "f_calls"], '\t'))
  for (n, p, R) in sizes, nF in (0, 1, 10)
    X, y, λ0, w, F = problem(T, n, p, nF, 1000 + n + nF)
    f = LeastSquaresLoss(y, X); g = NormL1(λ0, w)
    opts = ProximalOptions()
    # (1) initialization costs
    t_lmax = timeit(() -> norm(X' * y, Inf))
    t_A = nF > 0 ? timeit(() -> (b = zeros(T, p); b[F] .= X[:, F] \ y; norm(X' * (X * b .- y), Inf))) : (0.0, 0.0)
    cs = zeros(T, p)
    t_B = timeit(() -> colsq!(cs, X))
    t_E = nF > 0 ? timeit(() -> (qr(X[:, F], ColumnNorm()); X' * X[:, F])) : (0.0, 0.0)
    for (nm, t) in (("cur", t_lmax), ("A", t_A), ("B", t_B), ("E", t_E))
      println(join(["init", n, p, nF, "-", nm, 0, @sprintf("%.0f", t[1]), @sprintf("%.0f", t[2]), "-", "-", "-", "-", "-"], '\t'))
    end
    # (2) per-check cost at the accepted point of a PGD and an APG solve (rule cur)
    for method in (ProximalGradientDescent(), AccProxGradDescent())
      mname = method isa ProximalGradientDescent ? "PGD" : "APG"
      x = zeros(T, p); RULE[] = :cur
      st = nothing
      # run a solve, then rebuild a state at the returned point for the check kernels
      solve!(x, f, g, method, opts)
      st = PS.initial_state(method, opts, f, g, copy(x))
      for rule in (:cur, :A, :B, :E)
        (rule === :A || rule === :E) && nF == 0 && continue
        C = init_ctx!(newctx(T, n, p, F), st, g, rule)
        st.λmax = -one(T); λm = PS._lambda_max!(st, PS._scale_norm(g))
        λA = rule === :A ? C.lhat : λm
        k = if rule === :cur
          () -> cur_check(st, f, g, opts, λm)
        elseif rule === :A
          () -> cur_check(st, f, g, opts, λA)
        elseif rule === :B
          () -> B_check(st, f, g, opts, C)
        else
          () -> E_check(st, f, g, opts, C)
        end
        tt = timeit(k)
        k(); al = @allocated k()
        println(join(["check", n, p, nF, mname, rule, 0, @sprintf("%.0f", tt[1]), @sprintf("%.0f", tt[2]), al, "-", "-", "-", "-"], '\t'))
      end
      # one iteration's cost for reference: a gradient (two products)
      tg = timeit(() -> X' * (X * x .- y))
      println(join(["gradient", n, p, nF, mname, "-", 0, @sprintf("%.0f", tg[1]), @sprintf("%.0f", tg[2]), "-", "-", "-", "-", "-"], '\t'))
    end
    # (3) total solve time, rules interleaved
    rules = nF == 0 ? [:cur, :cur2, :B, :E] : [:cur, :cur2, :A, :B, :E]
    rng = MersenneTwister(77)
    for method in (ProximalGradientDescent(), AccProxGradDescent())
      mname = method isa ProximalGradientDescent ? "PGD" : "APG"
      for rule in rules      # warm-up
        RULE[] = rule; CTXB[] = newctx(T, n, p, F); x = zeros(T, p); solve!(x, f, g, method, opts)
      end
      for rep in 1:R, rule in shuffle(rng, rules)
        RULE[] = rule; CTXB[] = newctx(T, n, p, F); x = zeros(T, p)
        GC.gc(false)
        t0 = time_ns(); r = solve!(x, f, g, method, opts); t1 = time_ns()
        println(join(["solve", n, p, nF, mname, rule, rep, t1 - t0, "-", "-", r.iterations, r.converged, r.grad_calls, r.f_calls], '\t'))
      end
    end
    flush(stdout)
  end
end
main()
