# Issue #464 study: the PGD/APG stopping scale with weighted NormL1 (and GroupNormL2, record only).
#
# Four stopping rules for a proposed stop with NormL1(λ0, w), c_i = T(λ0) w_i, s_i the point-aware KKT score of entry i
# (ProximalBase's kkt_violation(g, ∇f, x, i)), λmax = ‖∇f(0)‖∞, τ = T(max(gradtol, 64 eps(T))):
#   v0  current master:   max_i s_i < τ max(max_i c_i, λmax)                      (invoke of the shipped method)
#   v1  coordinate-aware: s_i < τ max(c_i, λmax) for every i (each threshold ≥ floatmin(T))
#   v2  two-part:         v0, and |∇f_i| < τ λmax for every i with c_i = 0
#   v3  global minimum:   max_i s_i < τ max(min_i c_i, λmax)
# The rules are installed as a more specific method of ProximalSolvers._stationary! for a weighted NormL1 and
# selected with RULE[]; the package source is not modified. Every accuracy figure below is computed in 256-bit
# BigFloat from the stored inputs and the returned coefficients, against a BigFloat coordinate-descent reference,
# and does not use the solver's oracles or its stopping decision.
#
# Run from a ProximalSolvers checkout: julia --project=. study464.jl [out.tsv]
using LinearAlgebra, Printf, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers
setprecision(BigFloat, 256)

const RULE = Ref(:v0)
const GRULE = Ref(:v0)
const NCHECK = Ref(0)
const NPASS = Ref(0)
const SHIPPED = Tuple{Any, Any, Union{NormL1, NormL1Nonneg, IndNonnegative, ElasticNet, GroupNormL2}, ProximalOptions}

_pass(ok) = (NCHECK[] += 1; ok && (NPASS[] += 1); ok)

function PS._stationary!(state, f, g::NormL1{<:Real, <:Vector}, options::ProximalOptions)
  rule = RULE[]
  rule === :v0 && return _pass(invoke(PS._stationary!, SHIPPED, state, f, g, options))
  T = eltype(state.x)
  λmax = PS._lambda_max!(state, PS._scale_norm(g))
  grad = PS._gradient_at_x!(state, f)
  gT = PS._converted_penalty(g, T)
  x = state.x
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  isfinite(λmax) || return _pass(false)
  if rule === :v1
    # the proposed implementation: the shipped comparison, which every coordinate threshold implies; when the
    # largest coefficient does not exceed λmax every coordinate threshold equals it, and otherwise each entry
    # is compared with its own threshold
    cmax = PS._l1_level(gT)
    S = max(cmax, λmax)
    threshold = τ * S
    residual = kkt_violation(gT, grad, x)
    (isfinite(S) && threshold >= floatmin(T) && isfinite(residual) && residual < threshold) || return _pass(false)
    cmax <= λmax && return _pass(true)
    @inbounds for i in eachindex(x, grad, gT.w)
      t = τ * max(gT.λ0 * gT.w[i], λmax)
      (t >= floatmin(T) && kkt_violation(gT, grad, x, i) < t) || return _pass(false)
    end
    return _pass(true)
  elseif rule === :v2
    S = max(PS._l1_level(gT), λmax)
    threshold = τ * S
    residual = kkt_violation(gT, grad, x)
    (isfinite(S) && threshold >= floatmin(T) && isfinite(residual) && residual < threshold) || return _pass(false)
    t0 = τ * λmax
    for i in eachindex(x)
      iszero(gT.λ0 * gT.w[i]) || continue
      (t0 >= floatmin(T) && abs(grad[i]) < t0) || return _pass(false)
    end
    return _pass(true)
  elseif rule === :v3
    S = max(gT.λ0 * minimum(gT.w), λmax)
    threshold = τ * S
    residual = kkt_violation(gT, grad, x)
    return _pass(isfinite(S) && threshold >= floatmin(T) && isfinite(residual) && residual < threshold)
  end
  error("rule $rule")
end

# GroupNormL2: v0 shipped; gv1 the group analogue of v1 (record only, for the report)
function PS._stationary!(state, f, g::GroupNormL2, options::ProximalOptions)
  GRULE[] === :v0 && return _pass(invoke(PS._stationary!, SHIPPED, state, f, g, options))
  T = eltype(state.x)
  λmax = PS._lambda_max!(state, PS._scale_norm(g))
  grad = PS._gradient_at_x!(state, f)
  x = state.x
  τ = T(max(options.gradtol, 64 * Float64(eps(T))))
  isfinite(λmax) || return _pass(false)
  for k in eachindex(g.groups)
    t = τ * max(g.λ0 * g.w[k], λmax)
    s = kkt_violation(g, grad, x, k)
    (t >= floatmin(T) && isfinite(s) && s < t) || return _pass(false)
  end
  _pass(true)
end

# ---------------------------------------------------------------------------------------------------------------
# BigFloat problem, objective, KKT and reference
# ---------------------------------------------------------------------------------------------------------------
sigmoid(t) = t >= 0 ? inv(1 + exp(-t)) : (e = exp(t); e / (1 + e))
softplus(t) = t > 0 ? t + log1p(exp(-t)) : log1p(exp(t))

struct BigProblem
  loss::Symbol                 # :ls (α/2 ‖y - Xb‖²) or :logistic (Σ log(1 + exp(η)) - y η)
  α::BigFloat
  X::Matrix{BigFloat}
  y::Vector{BigFloat}
  c::Vector{BigFloat}          # exact coefficients λ0 w_j of the stored (rounded) level and weights
  groups::Union{Nothing, Vector{UnitRange{Int}}}
end

smooth(P::BigProblem, b) = P.loss === :ls ? P.α * sum(abs2, P.y - P.X * b) / 2 :
  sum(softplus.(P.X * b) .- P.y .* (P.X * b))
gradient(P::BigProblem, b) = P.loss === :ls ? P.α * (P.X' * (P.X * b - P.y)) : P.X' * (sigmoid.(P.X * b) .- P.y)
penalty(P::BigProblem, b) = P.groups === nothing ? sum(P.c .* abs.(b)) :
  sum(P.c[k] * norm(b[G]) for (k, G) in enumerate(P.groups))
objective(P::BigProblem, b) = smooth(P, b) + penalty(P, b)

# per-entry (per-group) minimal-norm KKT scores, clipped at 0
function scores(P::BigProblem, b)
  g = gradient(P, b)
  if P.groups === nothing
    [iszero(b[j]) ? max(abs(g[j]) - P.c[j], big(0)) : abs(g[j] + P.c[j] * sign(b[j])) for j in eachindex(b)]
  else
    [iszero(norm(b[G])) ? max(norm(g[G]) - P.c[k], big(0)) : norm(g[G] + P.c[k] * b[G] / norm(b[G]))
     for (k, G) in enumerate(P.groups)]
  end
end
# a column-local scale, independent of every stopping rule: the Cauchy-Schwarz bound of |∇f_j(0)| plus c_j
function localscale(P::BigProblem)
  r0 = P.loss === :ls ? P.α * norm(P.y) : norm(P.y .- big(1) / 2)
  P.groups === nothing ? [norm(P.X[:, j]) * r0 + P.c[j] for j in axes(P.X, 2)] :
    [norm(P.X[:, G]) * r0 + P.c[k] for (k, G) in enumerate(P.groups)]
end

soft(z, c) = sign(z) * max(abs(z) - c, big(0))

# Coordinate descent in BigFloat (groups: block CD with an exact 1D search on the block radius for LS only —
# group references use singleton or separable fixtures, see the cases), to a column-local KKT below 1e-60.
function reference(P::BigProblem; sweeps = 200_000)
  p = size(P.X, 2)
  b = zeros(BigFloat, p)
  sc = localscale(P)
  for sweep in 1:sweeps
    if P.groups === nothing
      for j in 1:p
        xj = P.X[:, j]
        nj = sum(abs2, xj)
        iszero(nj) && (b[j] = 0; continue)
        if P.loss === :ls
          r = P.y - P.X * b
          z = xj' * r + nj * b[j]
          b[j] = soft(z, P.c[j] / P.α) / nj
        else
          b[j] = logistic_coordinate(P, b, j)
        end
      end
    else
      for (k, G) in enumerate(P.groups)
        b[G] .= block_update(P, b, k, G)
      end
    end
    s = scores(P, b)
    maximum(s ./ max.(sc, big(1e-300))) < big(1e-60) && return b, sweep
  end
  error("reference did not converge")
end

# exact block update for LS with a group whose columns are orthogonal with equal norms (the fixtures below)
function block_update(P, b, k, G)
  @assert P.loss === :ls
  XG = P.X[:, G]
  nG = sum(abs2, XG[:, 1])
  iszero(nG) && return zeros(BigFloat, length(G))
  r = P.y - P.X * b + XG * b[G]
  z = XG' * r
  nz = norm(z)
  nz <= P.c[k] / P.α && return zeros(BigFloat, length(G))
  z * (1 - P.c[k] / (P.α * nz)) / nG
end

# exact coordinate minimization of the logistic objective: d(β) = X_jᵀ(σ(η(β)) - y) is increasing in β
function logistic_coordinate(P, b, j)
  xj = P.X[:, j]
  base = P.X * b - xj * b[j]
  d(β) = xj' * (sigmoid.(base + xj * β) .- P.y)
  h(β) = xj' * ((s = sigmoid.(base + xj * β)); s .* (1 .- s))
  c = P.c[j]
  d0 = d(big(0))
  abs(d0) <= c && return big(0)
  target = d0 < -c ? -c : c          # solve d(β) = -c on β > 0, or d(β) = c on β < 0
  sgn = d0 < -c ? 1 : -1
  lo, hi = big(0), sgn * (abs(b[j]) + big(1) / max(norm(xj), big(1e-300)))
  while sgn * (d(hi) - target) < 0
    lo, hi = hi, 2hi
  end
  β = (lo + hi) / 2
  for _ in 1:400
    v = d(β) - target
    iszero(v) && break
    sgn * v < 0 ? (lo = β) : (hi = β)
    βn = β - v / h(β)
    βnew = min(lo, hi) < βn < max(lo, hi) ? βn : (lo + hi) / 2
    abs(βnew - β) <= abs(βnew) * big(1e-72) && (β = βnew; break)
    β = βnew
  end
  β
end

# ---------------------------------------------------------------------------------------------------------------
# Running one case
# ---------------------------------------------------------------------------------------------------------------
const ROWS = Vector{String}()
const HEADER = join(["case", "loss", "T", "method", "start", "rule", "converged", "iter", "iter_conv", "stagnated", "f_increased", "call_limit", "x_conv", "f_conv", "g_conv", "f_calls",
  "grad_calls", "checks", "passes", "relgap", "kkt_local", "kkt_free_rel0", "free_err", "S_v0", "lmax", "cmax", "decision_vs_v0"], '\t')

methodname(m) = m isa ProximalGradientDescent ? "PGD" : "APG"

function bigproblem(loss, α, X, y, λ0, w; groups = nothing)
  c = big(λ0) .* big.(w)            # exact products of the stored level and weights (T(λ0) w_j rounds them)
  BigProblem(loss, big(α), big.(X), big.(y), c, groups)
end

function makeloss(loss, α, X, y)
  loss === :logistic && return LogisticLoss(y, X)
  isone(α) ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
end

# rules: weighted NormL1 => v0..v3; groups => v0, gv1
function runcase(case, loss, X, y, λ0, w, methods; α = one(eltype(X)), starts = (:zero,), options = ProximalOptions(),
                 groups = nothing, rules = groups === nothing ? (:v0, :v1, :v2, :v3) : (:v0, :gv1), Pref = nothing)
  T = eltype(X)
  P = bigproblem(loss, α, X, y, T(λ0), w; groups)
  bstar = Pref === nothing ? first(reference(P)) : Pref
  Fstar = objective(P, bstar)
  sc = localscale(P)
  free = groups === nothing ? findall(iszero, P.c) : Int[]
  g0 = gradient(P, zeros(BigFloat, size(X, 2)))
  lmax = Float64(maximum(abs, g0))
  cmax = Float64(maximum(P.c))
  for method in methods, start in starts
    v0dec = nothing
    for rule in rules
      groups === nothing ? (RULE[] = rule) : (GRULE[] = rule === :gv1 ? :gv1 : :v0)
      b = start === :zero ? zeros(T, size(X, 2)) :
          start === :random ? T.(randn(MersenneTwister(11), size(X, 2)) .* Float64.(max.(abs.(bstar), 1 ./ max.(norm.(eachcol(Float64.(X))), 1e-300)))) :
          start === :reference ? T.(bstar) : error()
      g = groups === nothing ? NormL1(T(λ0), w) : GroupNormL2(T(λ0), groups, w)
      NCHECK[] = 0; NPASS[] = 0
      r = solve!(b, makeloss(loss, α, X, y), g, method, options)
      bb = big.(b)
      F = objective(P, bb)
      relgap = iszero(Fstar) ? Float64(F) : Float64((F - Fstar) / abs(Fstar))
      s = scores(P, bb)
      kloc = Float64(maximum(s ./ max.(sc, big(1e-300))))
      gb = gradient(P, bb)
      kfree = isempty(free) ? NaN : Float64(maximum(abs.(gb[free])) / max(maximum(abs.(g0[free])), big(1e-300)))
      ferr = Float64(maximum(abs, bb - bstar) / max(maximum(abs, bstar), big(1e-300)))
      dec = (r.converged, r.iterations)
      rule === :v0 && (v0dec = dec)
      same = dec == v0dec ? "same" : "differs"
      row = join([case, String(loss), string(T), methodname(method), String(start), String(rule), r.converged,
        r.iterations, r.iteration_converged, r.stagnated, r.f_increased, r.call_limit_reached, r.x_converged,
        r.f_converged, r.grad_converged, r.f_calls, r.grad_calls, NCHECK[], NPASS[],
        @sprintf("%.3e", relgap), @sprintf("%.3e", kloc), @sprintf("%.3e", kfree), @sprintf("%.3e", ferr),
        @sprintf("%.3e", max(cmax, lmax)), @sprintf("%.3e", lmax), @sprintf("%.3e", cmax), same], '\t')
      push!(ROWS, row)
      println(row); flush(stdout)
    end
  end
  RULE[] = :v0; GRULE[] = :v0
  nothing
end

const LS2 = (ProximalGradientDescent(), AccProxGradDescent())
const PGD = (ProximalGradientDescent(),)

function design(T, n, p; ρ = 0.5, seed = 1)
  rng = MersenneTwister(seed)
  Z = randn(rng, n, p)
  C = [ρ^abs(i - j) for i in 1:p, j in 1:p]
  X = Z * cholesky(C).U
  β = zeros(p); β[1:min(4, p)] .= [2.0, -1.5, 1.0, 0.5][1:min(4, p)]
  y = X * β + 0.5 * randn(rng, n)
  T.(X), T.(y)
end
lmaxof(X, y, α = 1) = α * norm(X' * y, Inf)

function main(out)
  println(HEADER)
  # --- A. the original #439/#464 fixtures (zero column with weight 1, λ = 1e300) ---------------------------------
  y5 = [0.0, 1.0, 1.0, 1.0, 1.0]
  runcase("A1 logistic B4", :logistic, [fill(1e150, 5) zeros(5)], y5, 1e300, [0.0, 1.0], PGD,
          Pref = [log(big(4)) / big(1e150), big(0)])
  runcase("A2 LS one free", :ls, [fill(1e150, 5) zeros(5)], y5, 1e300, [0.0, 1.0], LS2)
  runcase("A3 LS two free", :ls, [fill(1e150, 5) 1e150 .* collect(1.0:5.0) zeros(5)], y5, 1e300, [0.0, 0.0, 1.0], LS2)

  for T in (Float64, Float32)
    X, y = design(T, 50, 10)
    lm = lmaxof(Float64.(X), Float64.(y))
    λ = T(0.1 * lm)
    ws = T == Float64 ? (1.0, 1e3, 1e6, 1e12, 1e100) : (1.0, 1e3, 1e6, 1e12, 1e30)
    Xz = hcat(X, zeros(T, 50))
    # --- B. ordinary weights plus one zero column with weight W (the reduced problem is W-independent) --------
    for W in ws
      w = vcat(ones(T, 10), T(W))
      runcase("B zero column W=$(W)", :ls, Xz, y, λ, w, LS2)
    end
    runcase("B reduced (no zero column)", :ls, X, y, λ, ones(T, 10), LS2)
    # --- C. a relevant column excluded by a huge penalty factor (no zero column) -------------------------------
    for W in ws
      w = vcat(ones(T, 9), T(W))
      runcase("C excluded column W=$(W)", :ls, X, y, λ, w, LS2)
    end
    # --- D. a free (zero-weight) coordinate with ordinary and extreme other weights -----------------------------
    for W in ws
      w = vcat(zero(T), ones(T, 8), T(W))
      runcase("D free first, W=$(W)", :ls, X, y, λ, w, LS2)
    end
    # --- E. nearly-free coordinate (tiny weight) with an extreme weight elsewhere ------------------------------
    runcase("E tiny+huge weights", :ls, X, y, λ, vcat(T(1e-6), ones(T, 8), T(T == Float64 ? 1e12 : 1e12)), LS2)
    # --- F. ordinary positive weights in [0.5, 2] (control) and λ variations -----------------------------------
    wo = T.(0.5 .+ 1.5 .* rand(MersenneTwister(3), 10))
    for f in (0.01, 0.1, 0.5, 2.0)
      runcase("F ordinary weights λ=$(f)λmax", :ls, X, y, T(f * lm), wo, LS2)
    end
    runcase("F all-zero weights", :ls, X, y, λ, zeros(T, 10), LS2)
    runcase("F λ0 = 0", :ls, X, y, zero(T), wo, LS2)
    # --- G. correlated predictors (ρ = 0.95) and rank deficiency (duplicate column) ---------------------------
    Xc, yc = design(T, 50, 10; ρ = 0.95, seed = 2)
    lmc = lmaxof(Float64.(Xc), Float64.(yc))
    runcase("G corr ρ=.95 ordinary", :ls, Xc, yc, T(0.1lmc), ones(T, 10), LS2)
    runcase("G corr ρ=.95 huge W", :ls, Xc, yc, T(0.1lmc), vcat(zero(T), ones(T, 8), T(1e6)), LS2)
    Xd = hcat(X[:, 1:9], X[:, 9])
    runcase("G duplicate column, huge W on copy", :ls, Xd, y, λ, vcat(zero(T), ones(T, 8), T(1e6)), LS2)
    # --- H. starts: random and the (rounded) reference --------------------------------------------------------
    runcase("H starts ordinary", :ls, X, y, λ, wo, LS2; starts = (:random, :reference))
    runcase("H starts huge W", :ls, X, y, λ, vcat(zero(T), ones(T, 8), T(1e6)), LS2; starts = (:random, :reference))
    # --- I. positive rescaling of the objective (loss scale α, penalty level α λ) ------------------------------
    for α in (T == Float64 ? (1e-100, 1e-20, 1e20, 1e100) : (1e-12, 1e12))
      runcase("I rescale α=$(α) huge W", :ls, X, y, T(α * λ), vcat(zero(T), ones(T, 8), T(1e6)), LS2; α = T(α))
      runcase("I rescale α=$(α) ordinary", :ls, X, y, T(α * λ), wo, LS2; α = T(α))
    end
    # --- J. zero response with mixed weights (zero scale for free coordinates); zero gradient at 0 on a free one
    runcase("J y=0 mixed weights", :ls, X, zeros(T, 50), λ, vcat(zero(T), ones(T, 9)), LS2; starts = (:zero, :random))
    yo = y .- X[:, 1] * (dot(X[:, 1], y) / dot(X[:, 1], X[:, 1]))     # ∇f_1(0) ≈ 0 on the free coordinate 1
    runcase("J free coord with ∇f_1(0)≈0, huge W", :ls, X, T.(yo), λ, vcat(zero(T), ones(T, 8), T(1e6)), LS2)
    # --- K. options: strict gradtol and ftol = 0 -----------------------------------------------------------------
    strict = ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)
    runcase("K strict, huge W", :ls, X, y, λ, vcat(zero(T), ones(T, 8), T(1e6)), LS2; options = strict)
    runcase("K maxiter 5000, huge W", :ls, X, y, λ, vcat(zero(T), ones(T, 8), T(1e6)), LS2;
            options = ProximalOptions(maxiter = 5000))
  end

  # --- N. an active coordinate whose coefficient is far above λmax (a false-negative probe for v3) -------------
  # X = [1 M; 0 1], y = [1, -M]: ∇f(0) = -(1, 0), λmax = 1; with x₁ free the fitted residual is (0, -M), so
  # |∇f₂| reaches M and x₂ is active for 1 < c₂ < M.
  for (T, Ms) in ((Float32, (1f3, 1f5)), (Float64, (1e6, 1e13)))
    for M in Ms
      # closed form: x₂ = c₂ - M, x₁ = 1 - M x₂ (residual (0, -c₂)), with c₂ = T(M/10) as stored
      c2, Mb = big(T(M / 10)), big(M)
      runcase("N active c₂=M/10 ≫ λmax, M=$(M)", :ls, T[1 M; 0 1], T[1, -M], M / 10, T[0, 1], LS2;
              starts = (:zero, :reference), Pref = [1 - Mb * (c2 - Mb), c2 - Mb])
    end
  end

  # --- O. the #400 `offset` mechanism: a free intercept with an offset response (the λmax term of S) ------------
  for T in (Float64, Float32)
    rng = MersenneTwister(400)
    Xo = hcat(ones(50), randn(rng, 50, 9))
    yo = 1e6 .+ Xo[:, 2:5] * [2.0, -1.5, 1.0, 0.5] .+ 0.5 .* randn(rng, 50)
    wo = vcat(0.0, 0.0, 2.0 .^ (4 .* rand(MersenneTwister(401), 8) .- 2))
    free = findall(iszero, wo)
    rf = yo - Xo[:, free] * (Xo[:, free] \ yo)
    λ0max = maximum(abs(dot(Xo[:, j], rf)) / wo[j] for j in eachindex(wo) if wo[j] > 0)
    runcase("O offset response, free intercept (#400)", :ls, T.(Xo), T.(yo), T(0.5λ0max), T.(wo), LS2)
    runcase("O centered control", :ls, T.(Xo), T.(yo .- 1e6), T(0.5λ0max), T.(wo), LS2)
  end

  # --- L. logistic PGD (Float64 only): ordinary, intercept, excluded column, zero column ------------------------
  rng = MersenneTwister(7)
  Xl = randn(rng, 200, 8)
  yl = Float64.(rand(rng, 200) .< sigmoid.(Xl * [1.0, -1.0, 0.5, 0, 0, 0, 0, 0] .+ 0.3))
  Xi = hcat(ones(200), Xl)
  lml = norm(Xi' * (0.5 .- yl), Inf)
  for W in (1.0, 1e3, 1e6, 1e12, 1e100)
    runcase("L logistic intercept free, zero column W=$(W)", :logistic, hcat(Xi, zeros(200)), yl, 0.05lml,
            vcat(0.0, ones(8), W), PGD)
    runcase("L logistic intercept free, excluded column W=$(W)", :logistic, Xi, yl, 0.05lml, vcat(0.0, ones(7), W), PGD)
  end
  runcase("L logistic ordinary weights", :logistic, Xl, yl, 0.05lml, collect(0.5:0.2:1.9), PGD)

  # --- M. GroupNormL2 (record only): the B4 mechanism with singleton and paired groups ------------------------
  runcase("M group LS one free (B4 analogue)", :ls, [fill(1e150, 5) zeros(5)], y5, 1e300, [0.0, 1.0], LS2;
          groups = [1:1, 2:2])
  Xg, yg = design(Float64, 50, 10; seed = 4)
  Q = Matrix(qr(Xg).Q)[:, 1:10] .* sqrt(50)      # orthogonal equal-norm columns: exact block reference
  yq = Q * vcat(2.0, -1.0, 1.0, 0.5, zeros(6)) + 0.5 * randn(MersenneTwister(5), 50)
  gr = [1:2, 3:4, 5:6, 7:8, 9:10]
  Λ = maximum(norm((Q' * yq)[G]) for G in gr)
  for W in (1.0, 1e6, 1e12)
    runcase("M group excluded group W=$(W)", :ls, Q, yq, 0.1Λ, [0.0, 1.0, 1.0, 1.0, W], LS2; groups = gr)
  end

  open(out, "w") do io
    println(io, HEADER)
    foreach(r -> println(io, r), ROWS)
  end
end

get(ENV, "STUDY_NO_MAIN", "") == "" && main(isempty(ARGS) ? "study464.tsv" : ARGS[1])
