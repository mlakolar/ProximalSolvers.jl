module WeightedLassoTests
# The weighted lasso ½α‖Xb - y‖² + λ0 Σⱼ wⱼ|bⱼ| with CDSolver (dense Vector and SparseIterate, cyclic and random
# order, with and without momentum), ProximalGradientDescent and AccProxGradDescent, on Float32 and Float64 data:
# `NormL1(λ0, w)` with w a Vector{T}, finite and nonnegative, the level T(λ0) zero or normal, and the coefficient
# cⱼ = T(λ0) wⱼ finite and, where both factors are positive, normal (a zero or subnormal coefficient of positive
# factors, and a subnormal level, are refused; a zero weight leaves its entry unpenalized).
#
# The references and the independent residual of a solution are computed in 256-bit BigFloat from the stored X, y, x
# and the penalty, with the exact coefficient λ0 wⱼ, and do not use ProximalBase's `kkt_violation`, the solvers'
# gradients or their caches. G is the minimal-norm element of ∇f(x) + ∂h(x) in the infinity norm:
# max(|αXⱼᵀ(Xx - y)| - cⱼ, 0) at xⱼ = 0 and |αXⱼᵀ(Xx - y) + cⱼ sign xⱼ| elsewhere. The references are the closed form
# of an orthogonal design, a signed-support solve of the support equations whose `ok` flag is true only if the signs
# and the off-support optimality condition hold in BigFloat (the support comes from a tight Float64 solve, which that
# verification does not trust; a case with `ok` false fails the test), the least-squares solution for all weights 0,
# and the zero vector above λ0 = maxⱼ |αXⱼᵀy|/wⱼ. `converged` is a stopping flag, not an accuracy certificate: each solve of the
# matrix below is checked against G, against the reference and against the reported objective, and a
# converged = true is checked against the independent G with an allowance for the rounding of the computed
# gradient (`eG`, from the standard dot-product bounds; it is an estimate under that error model, not a
# guarantee for the BLAS kernel in use).
#
# Tolerances are stated relative to each solver's own tolerance. For PGD and APG a stop counts only where the
# computed residual is below τ S, with τ = max(gradtol, 64 eps(T)) and S = max(maxⱼ cⱼ, α‖Xᵀy‖∞); the check is
# G - eG <= τ (1 + 4 eps) (S + eS). For CD with the default `relative = true` and y ≠ 0, `converged` means that
# every coordinate change of the last full pass, scaled, is below tol times the response scale:
# |Δxₖ| ‖Xₖ‖ < tol ‖y‖. In exact arithmetic each coordinate of that pass was the minimizer in its coordinate when it was
# updated, so G is at most (p - 1) α maxⱼ ‖Xⱼ‖ ‖y‖ tol, the effect of the later coordinates of the pass on the gradient
# of an earlier one; the term 64 eps(T) S allows for the rounding of the residual cache over the passes, and the
# largest measured G over this bound is printed at the end. For a design of full column rank, a distance to the reference follows from the strong convexity of the loss,
# μ = α σmin(X)²: ‖x - β‖₂ <= √p Gtol/μ, and F(x) - F(β) <= p Gtol²/(2μ), with Gtol the tolerance above plus eG.
# Refusals of penalties and of iterates for the other receivers are also in test/core_contracts.jl.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

# Solves of the file through `solve_spec` and those that reported converged = true; the number of bit-identical
# pairs of a weighted and an unweighted run with the same coefficients (recorded, not required).
const NRUN = Ref(0)
const NCONV = Ref(0)
const BITEQ = Ref(0)
const NPAIR = Ref(0)
# the largest ratio of each measured quantity to its tolerance, by (type, solver kind, quantity): printed at the end,
# so that the headroom of each tolerance is on record
const WORST = Dict{Tuple{DataType, Symbol, Symbol}, Float64}()
note!(T, s, quantity, ratio) = (key = (T, s.kind, quantity); WORST[key] = max(get(WORST, key, 0.0), Float64(ratio)); nothing)

big256(f) = setprecision(f, BigFloat, 256)

lossof(α, y, X) = isone(α) ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)

# ---------------------------------------------------------------------------------------------------------
# Oracle and references (BigFloat, from the stored data)
# ---------------------------------------------------------------------------------------------------------

# the largest |α Xⱼᵀy|, as a Float64 (the final rounding can be below it)
lambdamax(X, y, α) = big256() do
  Float64(maximum(abs, big(α) .* (big.(X)' * big.(y))))
end

# (G, S, eG, eS) in BigFloat for the point x of the problem with the penalty NormL1(λ0, w): G as in the header,
# S = max(maxⱼ λ0 wⱼ, α‖Xᵀy‖∞), and the first-order rounding allowances of the computed gradient and of the
# computed λmax, for the unit roundoff u = eps(T)/2 doubled as slack: with d = X x - y exact,
#   eG = maxᵢ α Σⱼ |Xⱼᵢ| (e_j + (n+1) u (|d_j| + e_j)) + u (|gᵢ| + cᵢ) + tiny(T) /2,
#   e_j = (p+1) u (Σₖ |Xⱼₖ||xₖ| + |y_j|),    eS = α (n+1) u maxᵢ Σⱼ |Xⱼᵢ||y_j|.
# The term u cᵢ is an allowance for the rounding of the coefficient to T. For an accepted coefficient (0, or normal)
# |cᵢ - λ0 wᵢ| <= |T(λ0) - λ0| wᵢ + (eps(T)/2) cᵢ, also where the exact product is just below floatmin(T) and rounds up to
# it. For a level of type T the first term is 0; for the other levels used here (a Float64, or an integer, converted
# by round-to-nearest) it is at most (eps(T)/2) T(λ0) wᵢ, so the sum is at most about eps(T) cᵢ = u cᵢ (to second order).
# That estimate does not hold for a Rational level, whose conversion error can be larger (testset "the conversion
# of a level"). The term tiny(T)/2 is slack.
function kktparts(X, y, α, λ0, w, x, ::Type{T}) where T
  big256() do
    Xb, yb, xb, a, l0, wb = big.(X), big.(y), big.(x), big(α), big(λ0), big.(w)
    n, p = size(Xb)
    u = big(eps(T))
    c = l0 .* wb
    d = Xb * xb - yb
    g = a .* (Xb' * d)
    G = maximum(j -> iszero(xb[j]) ? max(abs(g[j]) - c[j], zero(l0)) : abs(g[j] + c[j] * sign(xb[j])), eachindex(xb))
    S = max(maximum(c), maximum(abs, a .* (Xb' * yb)))
    absX = abs.(Xb)
    e = (p + 1) * u .* (absX * abs.(xb) + abs.(yb))
    eG = maximum(a .* (absX' * (e .+ (n + 1) * u .* (abs.(d) .+ e))) .+ u .* (abs.(g) .+ c)) + big(nextfloat(zero(T))) / 2
    eS = a * (n + 1) * u * maximum(absX' * abs.(yb))
    (G, S, eG, eS)
  end
end

# F(x) = α/2 ‖y - X x‖² + λ0 Σ wⱼ|xⱼ| in BigFloat
objective_big(X, y, α, λ0, w, x) = big256() do
  Xb, yb, xb = big.(X), big.(y), big.(x)
  big(α) * sum(abs2, yb - Xb * xb) / 2 + big(λ0) * sum(big.(w) .* abs.(xb))
end

σmin2(X) = minimum(svdvals(Float64.(X)))^2

# The minimizer β in BigFloat of the problem with a full-column-rank X, and whether it is verified. The support
# and the signs come from a tight Float64 solve; every column with a zero weight is in the support. β solves
# α X_AᵀX_A β_A = α X_Aᵀy - (λ0 w ∘ s)_A, and it is accepted only if the signs of the penalized support entries
# agree with s and |α Xⱼᵀ(Xβ - y)| <= λ0 wⱼ off the support (the optimality condition, in BigFloat).
const TIGHT = ProximalOptions(maxiter = 50_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-11)
function reference(X, y, α, λ0, w)
  p = size(X, 2)
  b0 = zeros(p)
  solve!(b0, lossof(Float64(α), Float64.(y), Float64.(X)), NormL1(Float64(λ0), Float64.(w)),
         AccProxGradDescent(), TIGHT)
  big256() do
    Xb, yb, a, l0, wb = big.(X), big.(y), big(α), big(λ0), big.(w)
    c = l0 .* wb
    A = [j for j in 1:p if !iszero(b0[j]) || iszero(wb[j])]
    s = [sign(b0[j]) for j in A]
    β = zeros(BigFloat, p)
    if !isempty(A)
      XA = Xb[:, A]
      β[A] = (a * XA' * XA) \ (a * XA' * yb - c[A] .* s)
    end
    g = a .* (Xb' * (Xb * β - yb))
    ok = all(k -> iszero(wb[A[k]]) || sign(β[A[k]]) == s[k], eachindex(A)) &&
         all(j -> abs(g[j]) <= c[j], setdiff(1:p, A))
    β, ok
  end
end

# the closed-form minimizer for a design with diagonal XᵀX: βⱼ = shrink(α Xⱼᵀy, λ0 wⱼ) / (α ‖Xⱼ‖²)
function analytic(X, y, α, λ0, w)
  big256() do
    Xb, yb, a, l0, wb = big.(X), big.(y), big(α), big(λ0), big.(w)
    [begin
       z = a * dot(Xb[:, j], yb)
       sign(z) * max(abs(z) - l0 * wb[j], 0) / (a * dot(Xb[:, j], Xb[:, j]))
     end for j in 1:size(X, 2)]
  end
end

# the least-squares solution of an X of full column rank, in BigFloat
ols(X, y) = big256() do
  Xb, yb = big.(X), big.(y)
  (Xb' * Xb) \ (Xb' * yb)
end

# ---------------------------------------------------------------------------------------------------------
# Problems
# ---------------------------------------------------------------------------------------------------------

# n × p Gaussian design (the same Float64 draw for both types), optionally with ρ > 0: column j is
# ρ times column j - 1 plus √(1 - ρ²) times a fresh column, so that the population correlation of columns i and j is
# ρ^|i-j|, whose matrix has its eigenvalues in [(1 - ρ)/(1 + ρ), (1 + ρ)/(1 - ρ)]. The design is therefore worse
# conditioned than an independent one in the population; the sample Gram matrix of a finite design only approximates
# it, and the quality bounds below use σmin of the X as drawn. The response has four active coefficients.
function design(::Type{T}, n, p, seed; ρ = 0.0) where T
  rng = Xoshiro(seed)
  Z = randn(rng, n, p)
  if ρ > 0
    for j in 2:p
      @views Z[:, j] .= ρ .* Z[:, j - 1] .+ sqrt(1 - ρ^2) .* Z[:, j]
    end
  end
  β = zeros(p)
  m = min(p, 4)
  β[1:m] .= [2.0, -1.5, 1.0, 0.5][1:m]
  y = Z * β .+ 0.3 .* randn(rng, n)
  Matrix{T}(Z), Vector{T}(y)
end

# a design whose columns have disjoint supports, so that XᵀX is diagonal in floating point
function orthogonal(::Type{T}, seed; n = 12, p = 6) where T
  rng = Xoshiro(seed)
  X = zeros(T, n, p)
  for j in 1:p, i in (2j - 1, 2j)
    X[i, j] = T(1 + rand(rng)) * (rand(rng) < 0.5 ? -1 : 1)
  end
  X, randn(rng, T, n)
end

const BASE_WEIGHTS = [0.5, 1, 2, 3, 0.25, 1.5, 0.75, 2.5, 1.25, 0.6, 1.8, 0.9]
function weights(::Type{T}, kind, p) where T
  w = T[BASE_WEIGHTS[mod1(j, length(BASE_WEIGHTS))] for j in 1:p]
  kind === :positive && return w
  kind === :somezero && (w[[2, 5]] .= 0; return w)
  kind === :allzero && return zeros(T, p)
  kind === :unit && return ones(T, p)
  kind === :spread && return T[10.0^(-3 + 6 * (j - 1) / (p - 1)) for j in 1:p]    # 1e-3 … 1e3
  error("unknown weights $kind")
end
const WEIGHT_KINDS = (:positive, :somezero, :allzero, :unit, :spread)

# the loss scales: raw, a floating scale 1/n and an integer scale
scales(::Type{T}, n) where T = ((:raw, one(T)), (:float, T(1) / T(n)), (:int, 3))

# ---------------------------------------------------------------------------------------------------------
# The solvers of the matrix
# ---------------------------------------------------------------------------------------------------------

struct Spec
  label::String
  kind::Symbol            # :cd, :pgd or :apg
  order::Symbol
  momentum::Union{Nothing, Bool}
  owner::Bool
end
const SPECS = (
  Spec("cd cyclic", :cd, :cyclic, nothing, false),
  Spec("cd random", :cd, :random, nothing, false),
  Spec("cd random, momentum = false", :cd, :random, false, false),
  Spec("cd owner cyclic", :cd, :cyclic, nothing, true),
  Spec("cd owner random (default momentum)", :cd, :random, nothing, true),
  Spec("cd owner random, momentum = false", :cd, :random, false, true),
  Spec("cd owner random, momentum = true", :cd, :random, true, true),
  Spec("pgd", :pgd, :cyclic, nothing, false),
  Spec("apg", :apg, :cyclic, nothing, false),
)
const CD_SPECS = filter(s -> s.kind === :cd, collect(SPECS))

const CD_TOL = Dict(Float64 => 1e-9, Float32 => 1e-5)
# Float32: gradtol above its floor 64 eps = 7.6e-6. ftol and xtol only propose stops (the stationarity check
# decides), and increases of the objective by rounding are allowed, so that the run is not ended by one before
# the residual reaches τ S.
gradient_options(::Type{T}) where T = ProximalOptions(maxiter = 50_000, ftol = 1e-15, xtol = 1e-14,
                                                      gradtol = T === Float32 ? 1e-4 : 1e-10, allow_f_increases = true)

method_of(s::Spec, ::Type{T}; seed = 1, tol = CD_TOL[T]) where T =
  s.kind === :cd ? CDSolver(order = s.order, momentum = s.momentum, tol = tol, rng = Xoshiro(seed)) :
  s.kind === :pgd ? ProximalGradientDescent() : AccProxGradDescent()

# One solve from x0; returns the final point as a dense Vector and the result. The result's minimizer is the
# caller's vector or owner.
function solve_spec(s::Spec, ::Type{T}, f, g, x0; seed = 1, options = gradient_options(T), tol = CD_TOL[T]) where T
  NRUN[] += 1
  x = s.owner ? SparseIterate(copy(x0)) : copy(x0)
  r = s.kind === :cd ? solve!(x, f, g, method_of(s, T; seed, tol)) : solve!(x, f, g, method_of(s, T), options)
  @test r.minimizer === x
  r.converged && (NCONV[] += 1)
  Vector(x), r
end

# The independent checks of one solve of the problem (X, y, α, λ0, w): the reference β (or nothing), the
# truthful flag (a converged = true is within the solver's tolerance, in G), `require_converged` for the
# problems of the matrix that are well posed, the distance to β, the objective gap and the reported objective.
function check_solution(label, s::Spec, ::Type{T}, X, y, α, λ0, w, x, r, β; require_converged = true,
                        tol = CD_TOL[T], options = gradient_options(T)) where T
  n, p = size(X)
  G, S, eG, eS = kktparts(X, y, α, λ0, w, x, T)
  u = big(eps(T))
  Gtol = if s.kind === :cd
    # in BigFloat: α and ‖y‖ can be large
    (p - 1) * big(α) * maximum(j -> norm(big.(X[:, j])), 1:p) * norm(big.(y)) * big(tol) + 64 * u * S
  else
    max(big(options.gradtol), 64 * u) * (1 + 4 * u) * (S + eS)
  end
  require_converged && @test (label, r.converged) == (label, true)
  r.converged && @test (label, G - eG <= Gtol) == (label, true)
  r.converged && note!(T, s, :G, max(G - eG, 0) / Gtol)
  F = objective_big(X, y, α, λ0, w, x)
  # the reported objective is formed from the iterate (PGD, APG) or from a cached residual (CD): within
  # 4 (n + p) eps(T) of the scale α/2 ‖y‖² + λ0 Σ wⱼ|xⱼ| (the cd_numerics fixture bound, widened by 4), plus
  # floatmin(T) for a loss part that underflows
  scale = big256() do
    big(α) * sum(abs2, big.(y)) / 2 + big(λ0) * sum(big.(w) .* abs.(big.(x)))
  end
  @test (label, abs(big(r.minimum) - F) <= 4 * (n + p) * u * scale + big(floatmin(T))) == (label, true)
  note!(T, s, :objective, abs(big(r.minimum) - F) / (4 * (n + p) * u * scale + big(floatmin(T))))
  if β !== nothing
    μ = big(α) * σmin2(X)
    Gt = Gtol + eG
    dx = big256(() -> norm(big.(x) .- β))
    @test (label, dx <= 1.01 * sqrt(big(p)) * Gt / μ) == (label, true)
    note!(T, s, :distance, dx / (sqrt(big(p)) * Gt / μ))
    gap = F - objective_big(X, y, α, λ0, w, β)
    note!(T, s, :gap, max(gap, 0) / (p * Gt^2 / (2μ)))
    @test (label, gap >= -big(1e-30) * max(F, floatmin(Float64)) && gap <= 1.01 * p * Gt^2 / (2μ)) == (label, true)
  end
  G, S
end

# ---------------------------------------------------------------------------------------------------------
# 1. Orthogonal designs: the closed-form minimizer
# ---------------------------------------------------------------------------------------------------------

@testset "orthogonal designs: closed-form minimizer, every solver, cold and warm starts" begin
  for T in (Float32, Float64), (sname, α) in scales(T, 12), kind in WEIGHT_KINDS, s in SPECS, seed in (1, 2)
    X, y = orthogonal(T, seed)
    p = size(X, 2)
    w = weights(T, kind, p)
    λ0 = T(0.2 * lambdamax(X, y, α))
    β = analytic(X, y, α, λ0, w)
    f = lossof(α, y, X)
    for warm in (false, true)
      x0 = warm ? T.(0.4 .* randn(Xoshiro(seed + 10), p)) : zeros(T, p)
      x, r = solve_spec(s, T, f, NormL1(λ0, w), x0; seed)
      check_solution((T, sname, kind, s.label, seed, warm), s, T, X, y, α, λ0, w, x, r, β)
    end
  end
end

# ---------------------------------------------------------------------------------------------------------
# 2. Random designs: signed-support references
# ---------------------------------------------------------------------------------------------------------

@testset "random designs, independent and correlated: every solver, loss scale and weights" begin
  n, p = 40, 8
  for T in (Float32, Float64), ρ in (0.0, 0.9), (sname, α) in scales(T, n), kind in WEIGHT_KINDS
    X, y = design(T, n, p, 11; ρ)
    w = weights(T, kind, p)
    λ0 = T(0.1 * lambdamax(X, y, α))
    β, ok = reference(X, y, α, λ0, w)
    @test (T, ρ, sname, kind, ok) == (T, ρ, sname, kind, true)
    ok || continue
    # the nonzero pattern of the problems that have a penalty: some entries 0 and some not
    if kind === :allzero
      @test all(!iszero, β)
      @test maximum(abs, big256(() -> β .- ols(X, y))) <= big(1e-60)
    else
      @test any(iszero, β) && any(!iszero, β)
    end
    f = lossof(α, y, X)
    for s in SPECS, warm in ((false, true))
      # warm starts for two kinds only, to keep the number of solves down
      warm && !(kind in (:positive, :somezero)) && continue
      x0 = warm ? T.(0.3 .* randn(Xoshiro(7), p)) : zeros(T, p)
      x, r = solve_spec(s, T, f, NormL1(λ0, w), x0; seed = 3)
      check_solution((T, ρ, sname, kind, s.label, warm), s, T, X, y, α, λ0, w, x, r, β)
    end
  end
end

@testset "a level of another type than the data: Float64 level with Float32 data" begin
  n, p = 40, 8
  X, y = design(Float32, n, p, 12)
  w = weights(Float32, :somezero, p)
  λ0 = 0.1 * lambdamax(X, y, 1f0)       # a Float64 that is not a Float32
  @test λ0 != Float64(Float32(λ0))
  β, ok = reference(X, y, 1f0, λ0, w)
  @test ok
  for s in SPECS
    x, r = solve_spec(s, Float32, lossof(1f0, y, X), NormL1(λ0, w), zeros(Float32, p))
    check_solution((:float64level, s.label), s, Float32, X, y, 1f0, λ0, w, x, r, β)
  end
end

# ---------------------------------------------------------------------------------------------------------
# 3. A level above maxⱼ |α Xⱼᵀy| / wⱼ gives the zero vector
# ---------------------------------------------------------------------------------------------------------

@testset "a level above the largest |α Xⱼᵀy| / wⱼ gives 0, from a cold and a warm start" begin
  n, p = 40, 8
  for T in (Float32, Float64), (sname, α) in scales(T, n), kind in (:positive, :unit, :spread), s in SPECS
    X, y = design(T, n, p, 13)
    w = weights(T, kind, p)
    bound = big256() do
      maximum(abs.(big(α) .* (big.(X)' * big.(y))) ./ big.(w))
    end
    λ0 = T(1.5 * bound)
    isfinite(λ0) && all(j -> big(λ0) * big(w[j]) > bound * big(w[j]), 1:p) || continue
    for x0 in (zeros(T, p), T.(0.4 .* randn(Xoshiro(5), p)))
      x, r = solve_spec(s, T, lossof(α, y, X), NormL1(λ0, w), x0)
      label = (T, sname, kind, s.label, iszero(x0))
      @test (label, all(iszero, x)) == (label, true)
      check_solution(label, s, T, X, y, α, λ0, w, x, r, zeros(BigFloat, p))
    end
  end
end

# ---------------------------------------------------------------------------------------------------------
# 4. Uniform weights, against the unweighted penalty with the same coefficient
# ---------------------------------------------------------------------------------------------------------

# w ≡ 1, w ≡ 2 and w ≡ 1/2 (scalings by a power of two, exact) with the levels λ0, λ0 and 2 λ0 have the coefficients
# λ0, 2 λ0 and λ0 of the unweighted runs with NormL1(λ0), NormL1(2 λ0) and NormL1(λ0).
#
# Two kinds of assertion. (1) Each run is checked on its own against the reference of the same problem, against the
# independent residual and for `converged = true` (`check_solution`). The weighted and the unweighted kernels, in
# particular those of the penalty value, round differently, so the two runs can follow different trajectories and, even
# at the same final point after the same number of iterations, can set different auxiliary flags (the objective test
# and the gradient test depend on the computed objective and on the iterates): no equality of flags, iteration counts
# or objective-derived quantities between the two runs is asserted. Those comparisons, and the bit equality of the final
# points, are recorded in the counters printed at the end. (2) The stop rule is checked at fixed points,
# independently of any trajectory (D4): at the zero vector, at the final points of both runs and at one fixed perturbed
# point, the stop scale S = max(level, λmax), ProximalBase's `kkt_violation` of the converted penalty at the same
# gradient and the verdict of `_stationary!` are equal for the weighted and the unweighted penalty. They are equal bit
# for bit because the coefficients are the same numbers (T(λw) c = T(λu) for a power of two c) and the data, the point
# and the gradient are the same; none of them uses the computed objective.

# The quantities of the stop rule of `s` (PGD or APG) for the penalty g at the point x, formed as `_stationary!` forms
# them: the level of the converted penalty, λmax, S, ProximalBase's residual at the gradient at x, and the verdict.
function stop_quantities(s::Spec, ::Type{T}, f, g, x, options) where T
  state = PS.initial_state(method_of(s, T), options, f, g, copy(x))
  λmax = PS._lambda_max!(state)
  grad = copy(PS._gradient_at_x!(state, f))
  gT = PS._converted_penalty(g, T)
  λ = PS._l1_level(gT)
  (; λ, λmax, S = max(λ, λmax), grad, residual = kkt_violation(gT, grad, state.x), verdict = PS._stationary!(state, f, g, options))
end

@testset "uniform weights reach the quality of the unweighted penalty and have its stop rule" begin
  n, p = 40, 8
  counts = Dict(:pairs => 0, :same_iterations => 0, :identical => 0, :identical_flags => 0, :stop_points => 0,
                :verdict_true => 0, :verdict_false => 0)
  for T in (Float32, Float64), (sname, α) in scales(T, n), s in SPECS, (c, λfactor) in ((1, 1), (2, 1), (1 // 2, 2))
    X, y = design(T, n, p, 14)
    λ0 = T(0.1 * lambdamax(X, y, α))
    f = lossof(α, y, X)
    λw, λu = λ0 * T(λfactor), λ0 * T(λfactor) * T(c)      # weighted level; the unweighted level (c λfactor λ0)
    wu = ones(T, p)
    wc = fill(T(c), p)
    gw, gu = NormL1(λw, wc), NormL1(λu)
    β, ok = reference(X, y, α, λu, wu)
    @test ok
    xw, rw = solve_spec(s, T, f, gw, zeros(T, p); seed = 4)
    xu, ru = solve_spec(s, T, f, gu, zeros(T, p); seed = 4)
    label = (T, sname, s.label, c)
    check_solution((label, :weighted), s, T, X, y, α, λw, wc, xw, rw, β)
    check_solution((label, :unweighted), s, T, X, y, α, λu, wu, xu, ru, β)
    NPAIR[] += 1
    BITEQ[] += xw == xu
    if s.kind !== :cd
      flags(r) = (r.converged, r.x_converged, r.f_converged, r.grad_converged, r.iteration_converged)
      # recorded, not asserted
      counts[:pairs] += 1
      counts[:same_iterations] += rw.iterations == ru.iterations
      if xw == xu && rw.iterations == ru.iterations
        counts[:identical] += 1
        counts[:identical_flags] += flags(rw) == flags(ru)
      end
      options = gradient_options(T)
      for x in (zeros(T, p), xu, xw, T.(0.1 .* sin.(1:p)))
        qw, qu = stop_quantities(s, T, f, gw, x, options), stop_quantities(s, T, f, gu, x, options)
        @test (label, qw.λ, qw.λmax, qw.S, qw.grad, qw.residual, qw.verdict) ==
              (label, qu.λ, qu.λmax, qu.S, qu.grad, qu.residual, qu.verdict)
        counts[:stop_points] += 1
        counts[qw.verdict ? :verdict_true : :verdict_false] += 1
      end
    end
  end
  # the check of the stop rule is not vacuous: stationary and non-stationary points occur
  @test counts[:verdict_true] > 0 && counts[:verdict_false] > 0
  println("weighted (uniform) and unweighted runs: bit-identical points in $(BITEQ[]) of $(NPAIR[]) pairs; PGD and APG: ",
          "equal iteration counts in $(counts[:same_iterations]) of $(counts[:pairs]), identical points and counts in ",
          "$(counts[:identical]) with equal flags in $(counts[:identical_flags]); stop rule compared at ",
          "$(counts[:stop_points]) points ($(counts[:verdict_true]) stationary, $(counts[:verdict_false]) not)")
end

# ---------------------------------------------------------------------------------------------------------
# 5. Factors far from 1 with a normal product, and the smallest accepted coefficient
# ---------------------------------------------------------------------------------------------------------

# λ0 = 2^k and w = w₀ 2^-k (and the reverse): the coefficients are those of the problem with λ0 = 1, w = w₀, since
# the scalings are exact, and each factor is far outside [1e-10, 1e10]. Everything is checked against the
# independent oracle, and the bits against the unscaled run are recorded.
@testset "weights and a level that are far from 1 with a normal coefficient" begin
  n, p = 40, 8
  for T in (Float32, Float64), s in SPECS, k in (T === Float32 ? (100, -100) : (500, -500))
    X, y = design(T, n, p, 15)
    w0 = weights(T, :somezero, p)
    λ = T(0.1 * lambdamax(X, y, 1.0))
    β, ok = reference(X, y, 1.0, λ, w0)
    @test ok
    λ0, w = ldexp(λ, k), ldexp.(w0, -k)
    @test λ0 * w == λ * w0 && !any(iszero, filter(!iszero, w) .* λ0)
    f = LeastSquaresLoss(y, X)
    x, r = solve_spec(s, T, f, NormL1(λ0, w), zeros(T, p); seed = 6)
    check_solution((T, s.label, k), s, T, X, y, one(T), λ0, w, x, r, β)
    x1, _ = solve_spec(s, T, f, NormL1(λ, w0), zeros(T, p); seed = 6)
    NPAIR[] += 1
    BITEQ[] += x == x1
  end
end

# The smallest accepted coefficient is floatmin(T): entry 1 has λ0 w₁ = floatmin(T) exactly (λ0 = 2^-k and
# w₁ = floatmin(T)/λ0, both normal), so its penalty is negligible and the entry is fitted. The other coefficients are
# of the order of the level λ.
@testset "the smallest accepted coefficient, floatmin(T), on entry 1 ($T)" for T in (Float32, Float64)
  n, p = 40, 8
  emin = T === Float32 ? -126 : -1022
  k = T === Float32 ? 100 : 900
  for s in SPECS
    X, y = design(T, n, p, 16)
    λ = T(0.1 * lambdamax(X, y, 1.0))
    λ0 = ldexp(T(1), -k)
    w = ldexp.(weights(T, :positive, p), k) .* λ
    w[1] = ldexp(T(1), emin + k)
    @test λ0 * w[1] == floatmin(T) && all(c -> c == 0 || c >= floatmin(T), λ0 .* w)
    x, r = solve_spec(s, T, LeastSquaresLoss(y, X), NormL1(λ0, w), zeros(T, p); seed = 8)
    # the oracle with the exact coefficients decides; entry 1 is not 0 (the loss pulls it away)
    check_solution((T, s.label), s, T, X, y, one(T), λ0, w, x, r, nothing)
    @test !iszero(x[1])
  end
end

# ---------------------------------------------------------------------------------------------------------
# 6. The range rule of the level and of the coefficient (D3) at its boundaries
# ---------------------------------------------------------------------------------------------------------

# The rule is on the rounded values in T: λ = T(λ0) must be zero or at least floatmin(T) (not subnormal), and each
# coefficient cⱼ = λ wⱼ must be finite and, where λ and wⱼ are both positive, at least floatmin(T) (so not zero and not
# subnormal). An exact product slightly below floatmin(T) that rounds up to floatmin(T) is accepted. The classification
# here is from the exact product of the two T values in BigFloat, not from T arithmetic: the product rounds to Inf at
# floatmax(T) + ulp/2, and below floatmin(T) - tiny/2 it rounds to a subnormal or to 0 (the tie rounds to floatmin(T),
# which is even).
function expected_accept(::Type{T}, λ0, w) where T
  λ = T(λ0)
  (iszero(λ) || λ >= floatmin(T)) || return false
  ulp = big(floatmax(T)) - big(prevfloat(floatmax(T)))
  for wj in w
    (iszero(λ) | iszero(wj)) && continue
    exact = big(λ) * big(wj)
    exact >= big(floatmax(T)) + ulp / 2 && return false
    exact < big(floatmin(T)) - big(nextfloat(zero(T))) / 2 && return false
  end
  true
end

# (label, level λ0, weights, message of the refusal or "" if accepted). `huge` makes a subnormal level times a weight
# normal, so that only the rule on the level refuses; its Float32 value is the weight 2^126 of the analytical regression
# for a Float64 level that converts to a subnormal Float32.
function range_cases(::Type{T}) where T
  fm, tiny, half = floatmin(T), nextfloat(zero(T)), floatmax(T) / 2
  huge = ldexp(T(1), T === Float32 ? 126 : 1000)
  wide(v) = T === Float32 ? Float64(v) : big(v)          # a number of a type wider than T
  below = T === Float32 ? Float64(fm) * (1 - 2.0^-30) : big(fm) * (1 - big(2)^-60)
  [("coefficient floatmax", T(2), T[half, 1], ""),
   ("coefficient just above floatmax overflows", T(2), T[nextfloat(half), 1], "overflows"),
   ("coefficient floatmin", T(1), T[fm, 1], ""),
   ("coefficient prevfloat(floatmin) is subnormal", T(1), T[prevfloat(fm), 1], "is subnormal (below floatmin"),
   ("smallest subnormal coefficient", T(0.5), T[2tiny, 1], "is subnormal (below floatmin"),
   ("0.75 of the smallest subnormal rounds to it: subnormal (analytical regression)", T(0.75), T[tiny], "is subnormal (below floatmin"),
   ("half of the smallest subnormal rounds to 0", T(0.5), T[tiny, 1], "underflows to zero"),
   ("a quarter of the smallest subnormal rounds to 0", T(0.25), T[tiny, 1], "underflows to zero"),
   ("level floatmin, weight tiny: the product underflows to 0", fm, T[tiny, 1], "underflows to zero"),
   ("exact product just below floatmin rounds up to floatmin, accepted", prevfloat(one(T)), T[fm, 1], ""),
   ("zero weight", T(2), T[0, 1], ""),
   ("positive level, some zero weights", T(1), T[0, 1, 0], ""),
   ("zero level, any finite nonnegative weights", zero(T), T[5, 0, floatmax(T)], ""),
   ("level floatmin", fm, T[1, 2], ""),
   ("level prevfloat(floatmin), the coefficients are normal", prevfloat(fm), T[huge, huge], "is subnormal in"),
   ("level nextfloat(0), the coefficients are normal", tiny, T[huge, huge], "is subnormal in"),
   ("a wider level that converts to a subnormal (analytical regression)", 0.75 * wide(tiny), T[huge, huge], "is subnormal in"),
   ("a wider level just below floatmin(T) that rounds up to it, accepted", below, T[1, 2], "")]
end

@testset "the rule on the level and on the coefficient at its boundaries ($T)" for T in (Float32, Float64)
  fm = floatmin(T)
  cases = range_cases(T)
  @test T(cases[end][2]) == fm && cases[end][2] < fm         # the wider level is below floatmin(T) and rounds up to it
  @test prevfloat(one(T)) * fm == fm                         # the exact product is below floatmin(T): it rounds up
  @test T(cases[end - 1][2]) == nextfloat(zero(T)) && issubnormal(T(cases[end - 1][2]))
  # unweighted levels are not changed: a level that is subnormal in T is accepted without weights
  let X = T[1 0.2; 0.1 2; 0.3 0.4], y = T[1, -1, 0.5]
    r = solve!(zeros(T, 2), LeastSquaresLoss(y, X), NormL1(prevfloat(fm)), CDSolver(order = :cyclic))
    @test r.converged
  end
  for (label, λ0, w, msg) in cases
    accepted = isempty(msg)
    @test (label, accepted) == (label, expected_accept(T, λ0, w))
    p = length(w)
    X, y = design(T, 12, p, 17)
    f = LeastSquaresLoss(y, X)
    for s in SPECS
      x0 = T[0.3, -0.2, 0.1][1:p]
      x = s.owner ? SparseIterate(copy(x0)) : copy(x0)
      snapshot() = s.owner ? (collect(ProximalBase.activecoordinates(x)), collect(ProximalBase.activevalues(x))) : copy(x)
      before = snapshot()
      rng = Xoshiro(3)
      rng_before = copy(rng)
      method = s.kind === :cd ? CDSolver(order = s.order, momentum = s.momentum, rng = rng) : method_of(s, T)
      call() = s.kind === :cd ? solve!(x, f, NormL1(λ0, w), method) :
                                solve!(x, f, NormL1(λ0, w), method, gradient_options(T))
      if accepted
        r = call()
        @test (label, s.label, r.minimizer === x, all(isfinite, Vector(x))) == (label, s.label, true, true)
        # no claim of accuracy at these scales, but a converged = true must be within the solver's tolerance
        if r.converged && s.kind !== :cd
          G, S, eG, eS = kktparts(X, y, 1, λ0, w, Vector(x), T)
          @test (label, s.label, G - eG <= max(big(gradient_options(T).gradtol), 64 * big(eps(T))) * (1 + 4 * big(eps(T))) * (S + eS)) ==
                (label, s.label, true)
        end
      else
        # refused before any write or draw from the generator: x or the owner and the generator are as they were
        err = try call(); nothing catch e e end
        @test (label, s.label, err isa ArgumentError && occursin(msg, err.msg)) == (label, s.label, true)
        @test (label, s.label, isequal(snapshot(), before), rng == rng_before) == (label, s.label, true, true)
      end
    end
  end
  # the rounding of the accepted coefficients: |cⱼ - λ0 wⱼ| <= (eps(T)/2) cⱼ, also where the exact product is just below floatmin(T)
  big256() do
    for (λ0, w1) in ((prevfloat(one(T)), fm), (T(1), fm), (T(0.3), T(1e-30)), (T(7), nextfloat(fm)))
      c = λ0 * w1
      c >= fm && @test abs(big(c) - big(λ0) * big(w1)) <= big(eps(T)) / 2 * big(c)
    end
  end
end

# The conversion of a level to T. For a level converted by round-to-nearest (a Float16, Float32, Float64 or BigFloat, or
# an integer) the error is at most (eps(T)/2) T(λ0). Julia's conversion of a Rational can round the numerator and the
# denominator before dividing, so a Rational level can have a larger error: with the numerator and the denominator
# 2^p + 1 and 2^p + 3 (p = 24 for Float32, 53 for Float64) both round and the ratio is off by about twice that bound.
# Only the actual-error form |cⱼ - λ0 wⱼ| <= |T(λ0) - λ0| wⱼ + (eps(T)/2) cⱼ holds for the levels with a normal cⱼ; the exact value of the
# Rational is computed in BigFloat at 256 bits from its numerator and denominator.
@testset "the conversion of a level to T: the half-eps bound and the Rational counterexample ($T)" for T in (Float32, Float64)
  rational = T === Float32 ? Rational{Int}(2^24 + 1, 2^24 + 3) : Rational{Int}(2^53 + 1, 2^53 + 3)
  exact(λ0::Rational) = big256(() -> big(numerator(λ0)) / big(denominator(λ0)))
  exact(λ0) = big(λ0)
  half(λ0) = big(eps(T)) / 2 * big(T(λ0))                  # the half-eps bound on the conversion
  nearest = [("Float16", Float16(0.1)), ("Float32", 0.1f0), ("Float64", 0.1), ("BigFloat", big"0.1"),
             ("Int", 3), ("Int64 above 2^53", 2^53 + 1), ("Int128", (Int128(1) << 100) + (Int128(1) << 76) + 1),
             ("Float64 just below floatmin(Float32)", Float64(floatmin(Float32)) * (1 - 2.0^-30)),
             ("Float64 level", 0.3), ("Float64 level 2", 1e-3)]
  for (name, λ0) in nearest
    T(λ0) >= floatmin(T) || continue               # a level that rounds to a subnormal is refused with weights
    @test (name, abs(big(T(λ0)) - exact(λ0)) <= half(λ0)) == (name, true)
  end
  # the Rational: the half-eps bound is exceeded, by a factor of about 2
  err = abs(big(T(rational)) - exact(rational))
  @test err > half(rational) && err < 3 * half(rational)
  # the actual-error form holds for the coefficients, with the exact Rational: |c - λ0 w| <= |T(λ0) - λ0| w + (eps/2) c
  big256() do
    for wj in T[1, 3, 7, 0.3, 1e-3]
      c = T(rational) * wj
      @test abs(big(c) - exact(rational) * big(wj)) <= abs(big(T(rational)) - exact(rational)) * big(wj) + big(eps(T)) / 2 * big(c)
    end
  end
  # solve! accepts the Rational level (it converts to a normal T(λ0)); the coefficient that it checks is T(λ0) w, which
  # ProximalBase's ordinary prox steps do not use (they form their thresholds from λ0 and w in their working type)
  X, y = T[1 0.2; 0.1 2; 0.3 0.4], T[1, -1, 0.5]
  @test solve!(zeros(T, 2), LeastSquaresLoss(y, X), NormL1(rational, T[1, 3]), CDSolver(order = :cyclic)).converged
end

# ---------------------------------------------------------------------------------------------------------
# 7. Flat columns
# ---------------------------------------------------------------------------------------------------------

@testset "a flat column: zero and positive weight, levels below and above 1, start ≠ 0 ($T)" for T in (Float32, Float64)
  levels = T === Float32 ? T[1e-3, 0.5, 3, 1e10, 1e30] : T[1e-3, 0.5, 3, 1e10, 1e100]
  for wk in (zero(T), T(2)), λ in vcat(zero(T), floatmin(T), levels), start in (T(2), -T(0.5))
    # the minimizer along a flat column is the penalty's: 0, finite, from the proximal map at 0 and the step floatmax
    g = NormL1(λ, T[wk, 1])
    isfinite(λ * wk) || continue
    for old in (start, zero(T))
      new = PS._coordinate_minimizer(g, old, 1)
      @test (T, wk, λ, old, new) == (T, wk, λ, old, zero(T))
    end
  end
  # solves with a flat first column: CD sets it to 0, and the others satisfy the oracle; PGD and APG shrink a
  # penalized flat entry to 0 (the gradient has no component there) and leave the check to the oracle
  n = 12
  X0, y = design(T, n, 3, 18)
  X = hcat(zeros(T, n), X0[:, 2:3])
  for wk in (zero(T), T(2)), λ in (T(0.01), T(0.5), T(5)), s in SPECS
    w = T[wk, 1, 1.5]
    x0 = T[2, 0.3, -0.2]
    f = LeastSquaresLoss(y, X)
    x, r = solve_spec(s, T, f, NormL1(λ, w), x0)
    label = (T, wk, λ, s.label)
    s.kind === :cd && @test (label, x[1]) == (label, zero(T))
    wk > 0 && @test (label, x[1]) == (label, zero(T))
    # the oracle on the problem as given (a flat column has gradient 0, so any x₁ satisfies it at weight 0);
    # the zeros of the data make σmin of X zero, so the quality bound is not used here
    check_solution(label, s, T, X, y, one(T), λ, w, x, r, nothing)
  end
end

@testset "a nonflat column whose squares underflow is refused, with the caller unchanged ($T)" for T in (Float32, Float64)
  n = 8
  X0, y = design(T, n, 3, 19)
  tiny_entries = T === Float32 ? T(1e-30) : T(1e-170)
  X = copy(X0)
  X[:, 2] .= tiny_entries .* T[1, 2, 3, 4, 5, 6, 7, 8]
  @test iszero(sum(abs2, X[:, 2])) && any(!iszero, X[:, 2])
  w = T[1, 2, 3]
  for s in CD_SPECS
    x0 = T[0.3, -0.2, 0.1]
    x = s.owner ? SparseIterate(copy(x0)) : copy(x0)
    snapshot() = s.owner ? (collect(ProximalBase.activecoordinates(x)), collect(ProximalBase.activevalues(x))) : copy(x)
    before = snapshot()
    err = try
      solve!(x, LeastSquaresLoss(y, X), NormL1(T(0.01), w), method_of(s, T))
      nothing
    catch e
      e
    end
    @test err isa ArgumentError && occursin("curvature underflows", err.msg)
    @test isequal(snapshot(), before)
  end
end

# ---------------------------------------------------------------------------------------------------------
# 8. The stopping check of PGD and APG
# ---------------------------------------------------------------------------------------------------------

# Zero weights leave their coordinates unpenalized, so the stop check must score them with their full gradient. Part (1)
# uses options that do not end a run on a computed objective increase (`allow_f_increases = true`, and
# `gradient_options`, which has it too): the run must be accepted (converged), the unpenalized coordinates are nonzero
# and the independent residual is within the bound. Part (2) uses the default `ProximalOptions()`, under which a
# Float32 run can end on an increase of the computed objective (the documented exit: `f_increased = true` and
# `converged = false`; the increase is rounding in the Float32 objective, whose last decreases here are a few ulps). For
# Float64 the run must converge, and for any run that converges the independent residual is within the bound (no false
# stop); a Float32 run that does not converge must have ended on the objective increase or on numerical stagnation, so
# that a run cut off by `maxiter` or by an error is not accepted as an outcome. The labels carry the exit
# (converged, f_increased, stagnated, iterations), so a failure shows how the run ended.
@testset "zero weights on nonzero coordinates: a stop is accepted at the weighted stationary point" begin
  n, p = 40, 8
  for T in (Float32, Float64), method in (ProximalGradientDescent(), AccProxGradDescent())
    X, y = design(T, n, p, 20)
    w = T[0, 0, 0, 1, 1, 1, 1, 1]
    λ0 = T(0.2 * lambdamax(X, y, 1.0))
    s = Spec("stop", method isa ProximalGradientDescent ? :pgd : :apg, :cyclic, nothing, false)
    within_bound(x, options) = begin
      G, S, eG, eS = kktparts(X, y, 1, λ0, w, x, T)
      τ = max(big(options.gradtol), 64 * big(eps(T)))
      G - eG <= τ * (1 + 4 * big(eps(T))) * (S + eS)
    end
    for options in (ProximalOptions(allow_f_increases = true), gradient_options(T))
      x, r = solve_spec(s, T, LeastSquaresLoss(y, X), NormL1(λ0, w), zeros(T, p); options)
      label = (T, s.kind, options.gradtol, :allow_f_increases, r.converged, r.f_increased, r.stagnated, r.iterations)
      @test (label, r.converged) == (label, true)
      @test (label, all(!iszero, x[1:3])) == (label, true)
      @test (label, within_bound(x, options)) == (label, true)
    end
    options = ProximalOptions()
    x, r = solve_spec(s, T, LeastSquaresLoss(y, X), NormL1(λ0, w), zeros(T, p); options)
    label = (T, s.kind, options.gradtol, :default, r.converged, r.f_increased, r.stagnated, r.iterations)
    if r.converged
      @test (label, all(!iszero, x[1:3])) == (label, true)
      @test (label, within_bound(x, options)) == (label, true)
    else
      @test (label, T === Float32 && (r.f_increased || r.stagnated)) == (label, true)
    end
  end
end

@testset "a run with too small a maxiter does not report convergence" begin
  n, p = 40, 8
  for T in (Float32, Float64), s in filter(s -> s.kind !== :cd, collect(SPECS))
    X, y = design(T, n, p, 21; ρ = 0.9)
    w = weights(T, :somezero, p)
    λ0 = T(0.1 * lambdamax(X, y, 1.0))
    x, r = solve_spec(s, T, LeastSquaresLoss(y, X), NormL1(λ0, w), zeros(T, p); options = ProximalOptions(maxiter = 3))
    # the run stops at maxiter, or earlier for another reason; `iteration_converged` says which
    @test !r.converged && r.iterations <= 3 && r.iteration_converged == (r.iterations == 3)
  end
end

# A stop is proposed at the first iteration (xtol is huge), at a point that is not stationary for the weighted
# problem: the unpenalized entries have a gradient. The stationarity check refuses it and the solve continues; a stop
# is accepted where the computed residual is below τ S, which the independent check confirms up to the allowance
# eG. An unweighted check with the level λ0
# alone (λ0 above λmax: stationary at 0) would accept the first proposal.
@testset "zero weights do not produce a false stop" begin
  n, p = 30, 6
  for T in (Float32, Float64), s in filter(s -> s.kind !== :cd, collect(SPECS)), seed in 1:5
    X, y = design(T, n, p, 30 + seed)
    w = T[0, 0, 1, 1, 0, 1]
    λ0 = T(4 * lambdamax(X, y, 1.0))
    options = ProximalOptions(maxiter = 50_000, xtol = 1e6, ftol = 0, gradtol = T === Float32 ? 1e-4 : 1e-8,
                              allow_f_increases = true)
    x, r = solve_spec(s, T, LeastSquaresLoss(y, X), NormL1(λ0, w), zeros(T, p); options)
    label = (T, s.kind, seed)
    @test (label, r.iterations > 1) == (label, true)
    if r.converged
      G, S, eG, eS = kktparts(X, y, 1, λ0, w, x, T)
      @test (label, G - eG <= max(big(options.gradtol), 64 * big(eps(T))) * (1 + 4 * big(eps(T))) * (S + eS)) == (label, true)
      @test (label, any(!iszero, x[[1, 2, 5]])) == (label, true)
    end
  end
end

# the check of a stop allocates nothing, with weights or without
alloc_check(state, f, g, options) = @allocated PS._stationary!(state, f, g, options)
@testset "the stationarity check allocates nothing with weights" begin
  o = ProximalOptions(gradtol = 1e-5)
  for T in (Float64, Float32), method in (ProximalGradientDescent(), AccProxGradDescent())
    raw = LeastSquaresLoss(T[.6, 1, 0.3], T[1 0; 0 1; 0.5 0.5])
    for f in (raw, T(.25) * raw, 3 * raw), g in (NormL1(T(.1), T[1, 3]), NormL1(T(.1), T[0, 0]), NormL1(T(.1)))
      state = PS.initial_state(method, o, f, g, T[.5, 0])
      PS._stationary!(state, f, g, o)
      @test alloc_check(state, f, g, o) == 0
    end
  end
end

# ---------------------------------------------------------------------------------------------------------
# 9. The exceptional step of a coordinate outside the band
# ---------------------------------------------------------------------------------------------------------

# τ = cₖ/(α a): the bounds of the existing tests of `_threshold` (Float32: one Float32 ulp, and at least floatmax
# where the quotient is; Float64: 3 eps relative where normal, nextfloat(0.0) more where subnormal, and a few ulp of
# floatmax where the quotient is near it), applied to the coefficient cₖ = T(λ0) wₖ. Returns the allowed
# absolute error of the computed τ̂ and whether the quotient is at or above floatmax(T).
function tau_allowance(::Type{Float32}, τ̂::Float32, ref)
  ref >= big(floatmax(Float32)) && return big(0), true
  max(big(eps(τ̂)), big(eps(min(nextfloat(τ̂), floatmax(Float32))))), false
end
function tau_allowance(::Type{Float64}, τ̂::Float64, ref)
  ref > big(floatmax(Float64)) * (1 - 3 * eps()) && return big(0), true
  ref >= big(floatmin(Float64)) && return 3 * big(eps()) * ref, false
  big(nextfloat(0.0)) + 3 * big(eps()) * ref, false
end

shrink_big(c, τ) = sign(c) * max(abs(c) - τ, 0)

# a (λ0, wₖ) pair is accepted by the validation of `solve!`: the level is zero or normal, and the coefficient is finite
# and, where both factors are positive, normal
accepted_pair(λ0::T, wk::T) where T =
  (c = λ0 * wk; (iszero(λ0) || !issubnormal(λ0)) && isfinite(c) && (iszero(c) ? (iszero(λ0) | iszero(wk)) : floatmin(T) <= c))

@testset "the exceptional step of a weighted coordinate: E1 against BigFloat ($T)" for T in (Float32, Float64)
  ks = T === Float32 ? (-140, -100, -60, -20, 0, 20, 60, 100, 120) : (-1070, -1000, -600, -300, -100, 0, 100, 300, 600, 1000, 1020)
  tiny = nextfloat(zero(T))
  mid = T === Float32 ? T(1e-30) : T(1e-300)
  # the pairs outside the accepted domain (a subnormal level or coefficient) are skipped; floatmin(T) and
  # prevfloat(1) give a coefficient that is floatmin(T) after rounding an exact product just below it
  λs = T[0, tiny, 3tiny, mid, 0.3, prevfloat(one(T)), 1e10, floatmax(T) / 4, floatmin(T)]
  wks = T[0, tiny, 3tiny, mid, 0.3, 1, 7, 1e10, floatmax(T) / 4, floatmin(T)]
  centres = T[0.3, -2, 1e5, 1e-30, -floatmax(T) / 2]
  counts = Dict(:cases => 0, :outside => 0, :zeroweight => 0, :unit => 0)
  worst = [0.0, 0.0]
  bad = String[]
  check(ok, info...) = ok || (length(bad) < 10 && push!(bad, join(string.(info), ", ")); false)
  big256() do
    for λ0 in λs, wk in wks
      accepted_pair(λ0, wk) || continue
      ck = λ0 * wk
      for jα in ks, ja in ks
        α, a = ldexp(T(1.3), jα), ldexp(T(1.7), ja)
        (iszero(α) || iszero(a)) && continue
        p = α * a
        outside = !(floatmin(T) <= p <= floatmax(T) && floatmin(T) <= inv(p))
        for c in centres
          info = (λ0, wk, α, a, c)
          g = NormL1(λ0, T[wk, 1])
          res = PS._exceptional_step(g, c, α, a, 1)
          τ̂ = min(PS._threshold(T, ck, α, a), floatmax(T))
          ref_τ = big(ck) / (big(α) * big(a))
          Δτ, atmax = tau_allowance(T, τ̂, ref_τ)
          # the threshold is within the stated bound of cₖ/(α a), and the step is shrink(c, τ̂)
          check(atmax ? τ̂ >= prevfloat(floatmax(T), 4) : abs(big(τ̂) - ref_τ) <= Δτ, "threshold", info...)
          check(res === ProximalBase.shrink(c, τ̂), "not shrink(c, τ̂)", info...)
          # the step is within that bound plus the rounding of the final subtraction of the BigFloat shrink
          ref = shrink_big(big(c), ref_τ)
          allowed = Δτ + big(eps(T)) * abs(ref) + big(tiny)
          check(abs(big(res) - ref) <= allowed, "step against cₖ/(α a)", info...)
          worst[1] = max(worst[1], Float64(abs(big(res) - ref) / allowed))
          # against the exact λ0 wₖ: the bound plus the rounding of the coefficient, |cₖ - λ0 wₖ| / (α a)
          exact_τ = big(λ0) * big(wk) / (big(α) * big(a))
          exact = shrink_big(big(c), exact_τ)
          extra = abs(big(ck) - big(λ0) * big(wk)) / (big(α) * big(a))
          check(abs(big(res) - exact) <= allowed + extra, "step against λ0 wₖ/(α a)", info...)
          worst[2] = max(worst[2], Float64(abs(big(res) - exact) / (allowed + extra)))
          counts[:cases] += 1
          counts[:outside] += outside
          # a zero weight or level is the unpenalized step
          if iszero(ck)
            check(res === c, "zero coefficient", info...)
            counts[:zeroweight] += 1
          end
        end
      end
    end
  end
  # w ≡ 1 out of band is the unweighted method bit for bit (the same coefficient T(λ0), a level of type T)
  for λ0 in λs, jα in ks, ja in ks
    accepted_pair(λ0, one(T)) || continue
    α, a = ldexp(T(1.3), jα), ldexp(T(1.7), ja)
    (iszero(α) || iszero(a)) && continue
    for c in centres
      check(PS._exceptional_step(NormL1(λ0, ones(T, 2)), c, α, a, 2) === PS._exceptional_step(NormL1(λ0), c, α, a, 2),
            "w ≡ 1", λ0, α, a, c)
      counts[:unit] += 1
    end
  end
  @test isempty(bad)
  isempty(bad) || foreach(println, bad)
  @test counts[:outside] > 1000 && counts[:zeroweight] > 100 && counts[:unit] > 1000
  println("exceptional step, $T: $(counts[:cases]) cases ($(counts[:outside]) outside the band); worst error / allowance: ",
          "against cₖ/(α a) $(round(worst[1]; sigdigits = 3)), against λ0 wₖ/(α a) $(round(worst[2]; sigdigits = 3))")
end

# Where p = α a and 1/p are both at least floatmin(T) (inside the band), the step is PB's weighted prox at the
# coefficient 1/p, and `_exceptional_step` is defined too: the two agree within 8 eps(T) τ (the bound of `_threshold`
# on cₖ/(α a), 3 eps(T) τ in Float64 and one ulp, at most eps(T) τ, in Float32, and 4 eps(T) τ for the rounding of p, 1/p,
# γλ0 and the product by wₖ of PB's threshold), eps(T) of the result, 2 tiny (a subnormal threshold), and
# |cₖ - λ0 wₖ| / (α a), the rounding of the coefficient. The grid of products p is at both edges of the band and in
# the middle.
@testset "inside the band, PB's weighted prox step and the exceptional step agree ($T)" for T in (Float32, Float64)
  emin, emax = T === Float32 ? (-126, 127) : (-1022, 1023)
  tiny = nextfloat(zero(T))
  mid = T === Float32 ? T(1e-30) : T(1e-300)
  λs = T[0, tiny, 3tiny, mid, 0.3, prevfloat(one(T)), 1e10, floatmax(T) / 4, floatmin(T)]
  wks = T[0, tiny, mid, 0.3, 1, 7, 1e10, floatmin(T)]
  centres = T[0.3, -2, 1e5, 1e-30, -floatmax(T) / 2]
  edges = vcat(collect(emin + 1:emin + 8), collect(-6:3:6), collect(-emin - 9:-emin - 1))
  bad = String[]
  checked = 0
  big256() do
    for λ0 in λs, wk in wks
      accepted_pair(λ0, wk) || continue
      ck = λ0 * wk
      g = NormL1(λ0, T[wk, 1])
      for e in edges, d in (-20, 0, 20)
        α, a = ldexp(T(1.3), (e ÷ 2) + d), ldexp(T(1.7), e - (e ÷ 2) - d)
        (iszero(α) || iszero(a) || !isfinite(α) || !isfinite(a)) && continue
        p = α * a
        (floatmin(T) <= p && floatmin(T) <= inv(p)) || continue
        for c in centres
          inband = ProximalBase.prox_block(g, c, 1, inv(p))
          exceptional = PS._exceptional_step(g, c, α, a, 1)
          τ = big(λ0) * big(wk) / (big(α) * big(a))
          allowed = 8 * big(eps(T)) * τ + big(eps(T)) * max(abs(big(inband)), abs(big(exceptional))) + 2 * big(tiny) +
                    abs(big(ck) - big(λ0) * big(wk)) / (big(α) * big(a))
          if !(abs(big(inband) - big(exceptional)) <= allowed)
            length(bad) < 10 && push!(bad, "λ0=$λ0 wk=$wk α=$α a=$a c=$c inband=$inband exceptional=$exceptional")
          end
          checked += 1
        end
      end
    end
  end
  @test isempty(bad)
  isempty(bad) || foreach(println, bad)
  @test checked > 1000
end

# the coordinate step itself, just inside and just outside both edges of the band. The step (PB's weighted prox
# inside, the exceptional step outside) is compared with the BigFloat shrink of the same centre at the exact threshold
# λ0 wₖ / (α a), the allowance being 6 eps(T) τ (the rounded p, γ = 1/p, γλ0 and the product by wₖ of the inside; the
# bound of `_threshold` and the coefficient rounding of the outside), 2 tiny, eps(T) of the result, and
# |cₖ - λ0 wₖ| / (α a). High edge: the unit-norm columns give α a ≈ α, and α = t / floatmin(T) with t = 0.5 and 2 puts
# the reciprocal of the product on either side of floatmin(T); the level is a fraction of λmax, and cases whose level or
# coefficient is subnormal, which `solve!` refuses, are skipped. Low edge: the levels of that design are subnormal for
# α near floatmin(T), so a fixture with an accepted level is used: X = [1], y = [2], λ0 = floatmin(T), w = [1] and the
# loss scales prevfloat(floatmin(T)) (the product α a is subnormal: outside) and floatmin(T) (inside), where the
# threshold is about 1 and the step is about 1. A counter per edge and side asserts that all four are exercised.
@testset "inside and outside the band, the weighted step agrees with BigFloat ($T)" for T in (Float32, Float64)
  tiny = nextfloat(zero(T))
  seen = Dict{Tuple{Symbol, Bool}, Int}()
  # one step from the state of the model m, against BigFloat
  function check_step(form, label, m, g, x, k, λ0, wk, α)
    a, b = PS._column_dot(m, k)
    c = x[k] + b / a
    p = m.s * a
    inside = floatmin(T) <= p && floatmin(T) <= inv(p)
    seen[(form, inside)] = get(seen, (form, inside), 0) + 1
    PS.coordinate_step!(m, g, x, k)
    big256() do
      ck = λ0 * wk
      τ = big(λ0) * big(wk) / (big(α) * big(a))
      ref = shrink_big(big(c), τ)
      allowed = 6 * big(eps(T)) * τ + 2 * big(tiny) + big(eps(T)) * abs(ref) + abs(big(ck) - big(λ0) * big(wk)) / (big(α) * big(a))
      @test (T, label, inside, abs(big(x[k]) - ref) <= allowed) == (T, label, inside, true)
    end
  end
  rng = Xoshiro(41)
  X0 = randn(rng, 30, 3)
  X0 ./= sqrt.(sum(abs2, X0; dims = 1))
  y0 = X0 * [1.0, -2.0, 0.5] .+ 0.02 .* randn(rng, 30)
  X, y = Matrix{T}(X0), Vector{T}(y0 .* (0.5 / norm(y0)))
  w = T[0.5, 1, 2]
  for t in (0.5, 2.0)
    α = T(t) / floatmin(T)
    for fraction in (0.1, 0.5), warm in (false, true)
      λ0 = big256(() -> T(big(fraction) * maximum(abs, big(α) .* (big.(X)' * big.(y)))))
      (isfinite(λ0) && !iszero(λ0)) || continue
      all(k -> accepted_pair(λ0, w[k]), 1:3) || continue       # a subnormal level or coefficient is refused by solve!
      g = NormL1(λ0, w)
      for k in 1:3
        m = PS.LSModel(y, X, α)
        x = SparseIterate(warm ? T[0.1, -0.2, 0.05] : zeros(T, 3))
        PS.initialize!(m, x)
        check_step(:high, (:high, t, fraction, warm, k), m, g, x, k, λ0, w[k], α)
      end
    end
  end
  fm = floatmin(T)
  @test accepted_pair(fm, one(T))
  for α in (prevfloat(fm), fm)
    m = PS.LSModel(T[2], ones(T, 1, 1), α)
    x = SparseIterate(zeros(T, 1))
    PS.initialize!(m, x)
    check_step(:low, (:low, α), m, NormL1(fm, T[1]), x, 1, fm, one(T), α)
    @test x[1] > T(0.5)                  # the step is about 1, not 0 or 2: the threshold is about 1
  end
  @test all(key -> get(seen, key, 0) > 0, ((:high, true), (:high, false), (:low, true), (:low, false)))
end

# ---------------------------------------------------------------------------------------------------------
# 10. A full weighted CD solve whose steps leave the band
# ---------------------------------------------------------------------------------------------------------

# the data of cd_numerics' scaled_problem: 30 × 3 with the response of norm `target`
function band_problem(::Type{T}, target, xscale) where T
  rng = Xoshiro(99)
  X = randn(rng, 30, 3) * [1 0.5 0.3; 0 1 0.5; 0 0 1]
  y = X * [1.0, -2.0, 0.5] .+ 0.01 .* randn(rng, 30)
  Matrix{T}(xscale .* X), Vector{T}((target / norm(y)) .* y)
end

@testset "weighted CD where α a_k or its reciprocal leaves the range of T: $label" for (label, T, target, α, xscale) in (
    ("Float32, α a_k overflows", Float32, 1e3, 1f30, 1e4),
    ("Float32, 1/(α a_k) overflows", Float32, 100.0, 1f-30, 3e-6),
    ("Float64, α a_k overflows", Float64, 1e2, 1e300, 1e5),
    ("Float64, 1/(α a_k) overflows", Float64, 100.0, 1e-300, 1e-5))
  X, y = band_problem(T, target, xscale)
  m = PS.LSModel(y, X, α)
  @test all(k -> (p = m.s * PS._sqnorm!(m, k); !(floatmin(T) <= p && floatmin(T) <= inv(p))), 1:3)
  f = α * LeastSquaresLoss(y, X)
  w = T[0.5, 1, 2]
  for fraction in (0.05, 0.3)
    λ0 = big256(() -> T(big(fraction) * maximum(abs, big(α) .* (big.(X)' * big.(y)))))
    for s in CD_SPECS, x0 in (zeros(T, 3), T.(0.3 .* [1, -1, 1] .* (target / norm(y)) / xscale))
      x, r = solve_spec(s, T, f, NormL1(λ0, w), x0; tol = T === Float64 ? 1e-9 : 1e-7)
      check_solution((label, fraction, s.label, iszero(x0)), s, T, X, y, α, λ0, w, x, r, nothing; tol = T === Float64 ? 1e-9 : 1e-7)
    end
  end
end

# ---------------------------------------------------------------------------------------------------------
# 11. Refusals, before any write or draw
# ---------------------------------------------------------------------------------------------------------

# each refusal leaves x (or the owner), X, y and a borrowed generator as they were; the message names the cause
function refusals(::Type{T}) where T
  other = T === Float32 ? Float64 : Float32
  λ = T(0.1)
  bad_weights = T[1, 1]
  mutated = NormL1(λ, copy(bad_weights))
  mutated.w[2] = -1
  nan_weights = NormL1(λ, copy(bad_weights))
  nan_weights.w[1] = T(NaN)
  huge, small = T(2), nextfloat(zero(T))
  level = T === Float32 ? 1e40 : big"1e400"
  [(DimensionMismatch, "has 3 weights", NormL1(λ, T[1, 1, 1])),
   (ArgumentError, "penalty weight 2 must be finite and nonnegative", NormL1(λ, T[1, Inf])),
   (ArgumentError, "penalty weight 2 must be finite and nonnegative", mutated),
   (ArgumentError, "penalty weight 1 must be finite and nonnegative", nan_weights),
   (ArgumentError, "must be a Vector{$T}", NormL1(λ, other.([1, 1]))),
   (ArgumentError, "must be a Vector{$T}", NormL1(λ, view(T[1, 1, 1], 1:2))),
   (ArgumentError, "must be a Vector{$T}", NormL1(λ, T(1):T(2))),
   (ArgumentError, "must be a Vector{$T}", NormL1(λ, reshape(T[1, 1], 2, 1))),
   (ArgumentError, "overflows", NormL1(huge, T[floatmax(T), 1])),
   (ArgumentError, "underflows to zero", NormL1(floatmin(T), T[small, 1])),
   (ArgumentError, "is subnormal (below floatmin", NormL1(T(1), T[prevfloat(floatmin(T)), 1])),
   (ArgumentError, "is subnormal in", NormL1(prevfloat(floatmin(T)), T[1, 1])),
   (ArgumentError, "penalty lambda must be finite and nonnegative", NormL1(T(Inf), T[1, 1])),
   (ArgumentError, "penalty lambda is not representable", NormL1(level, T[1, 1])),
   (ArgumentError, "", ElasticNet(λ, λ, T[1, 1])),
   (ArgumentError, "", Scaled(NormL1(λ, T[1, 1]), 2))]
end

@testset "refusals leave the caller unchanged, with no draw from a borrowed generator ($T)" for T in (Float32, Float64)
  X, y = T[1 0.2; 0.1 2; 0.3 0.4], T[1, -1, 0.5]
  f = LeastSquaresLoss(y, X)
  X0, y0 = copy(X), copy(y)
  for (E, msg, g) in refusals(T), s in (SPECS[1], SPECS[4], SPECS[8], SPECS[9])
    x0 = T[0.3, -0.2]
    x = s.owner ? SparseIterate(copy(x0)) : copy(x0)
    snapshot() = s.owner ? (collect(ProximalBase.activecoordinates(x)), collect(ProximalBase.activevalues(x))) : copy(x)
    rng = Xoshiro(2)
    method = s.kind === :cd ? CDSolver(order = s.order, momentum = s.momentum, rng = rng) : method_of(s, T)
    before, rng_before = snapshot(), copy(rng)
    err = try
      s.kind === :cd ? solve!(x, f, g, method) : solve!(x, f, g, method, gradient_options(T))
      nothing
    catch e
      e
    end
    label = (T, s.label, typeof(g), E)
    @test (label, err isa E) == (label, true)
    err isa E || continue
    text = err.msg
    # A weighted ElasticNet and a scaled penalty get each solver's supported-penalty list.
    generic = s.kind === :cd ? "only NormL1 or unweighted ElasticNet is supported" :
              method isa ProximalGradientDescent ?
                "only NormL1, unweighted ElasticNet, NormLinf, GroupNormL2 or unweighted NormL1Nonneg is supported" :
                "only NormL1, unweighted ElasticNet, NormLinf or GroupNormL2 is supported"
    expected = g isa Union{ElasticNet, Scaled} ? generic : msg
    @test (label, occursin(expected, text)) == (label, true)
    @test isequal(snapshot(), before) && rng == rng_before
    @test X == X0 && y == y0
  end
end

# the advice of the message works: collect(T, vec(w)) turns each refused container into a Vector{T} that is accepted
@testset "collect(T, vec(w)) converts refused weight containers ($T)" for T in (Float32, Float64)
  X, y = T[1 0.2; 0.1 2; 0.3 0.4], T[1, -1, 0.5]
  f = LeastSquaresLoss(y, X)
  other = T === Float32 ? Float64 : Float32
  for w in (other.([1, 2]), view(T[1, 2, 3], 1:2), T(1):T(2), reshape(T[1, 2], 2, 1), reshape(T[1, 2], 1, 2))
    g = NormL1(T(0.1), w)
    err = try solve!(zeros(T, 2), f, g, CDSolver(order = :cyclic)); nothing catch e e end
    @test err isa ArgumentError && occursin("collect($T, vec(w))", err.msg)
    converted = collect(T, vec(w))
    @test converted isa Vector{T} && converted == T[1, 2]
    @test solve!(zeros(T, 2), f, NormL1(T(0.1), converted), CDSolver(order = :cyclic)).converged
  end
end

@testset "x must not alias the weights: a dense vector and an owner ($T)" for T in (Float32, Float64)
  X, y = T[1 0.2; 0.1 2; 0.3 0.4], T[1, -1, 0.5]
  f = LeastSquaresLoss(y, X)
  for s in SPECS
    w = T[1, 2]
    x = s.owner ? SparseIterate(w) : w
    # an owner is made of its own storage, and the weights alias it through its value buffer
    if s.owner
      backing = parent(ProximalBase.activevalues(x))
      g = NormL1(T(0.1), backing)
    else
      g = NormL1(T(0.1), w)
    end
    @test Base.mightalias(x, g.w)
    before = s.owner ? (collect(ProximalBase.activecoordinates(x)), collect(ProximalBase.activevalues(x))) : copy(x)
    rng = Xoshiro(4)
    rng_before = copy(rng)
    method = s.kind === :cd ? CDSolver(order = s.order, momentum = s.momentum, rng = rng) : method_of(s, T)
    err = try
      s.kind === :cd ? solve!(x, f, g, method) : solve!(x, f, g, method, gradient_options(T))
      nothing
    catch e
      e
    end
    @test err isa ArgumentError && occursin("must not alias the penalty weights", err.msg)
    @test isequal(s.owner ? (collect(ProximalBase.activecoordinates(x)), collect(ProximalBase.activevalues(x))) : copy(x), before)
    @test rng == rng_before
  end
  # a copy of the weights is not an alias
  x = copy(T[0.3, -0.2])
  @test solve!(x, f, NormL1(T(0.1), copy(T[1, 2])), CDSolver(order = :cyclic)).minimizer === x
end

# ---------------------------------------------------------------------------------------------------------
# 12. Failure rollback
# ---------------------------------------------------------------------------------------------------------

@testset "a failure during the run leaves the caller's x and owner unchanged ($T)" for T in (Float32, Float64)
  w = T[0.5, 2, 1]
  # CD: the second column has an infinite curvature, refused at its first visit after the first coordinate moved
  X, y = design(T, 8, 3, 22)
  X[:, 2] .*= T === Float32 ? T(1e19) : T(1e160)
  @test isinf(sum(abs2, X[:, 2])) && all(isfinite, X)
  f = LeastSquaresLoss(y, X)
  for s in CD_SPECS
    x0 = T[0.3, -0.2, 0.1]
    x = s.owner ? SparseIterate(copy(x0)) : copy(x0)
    snapshot() = s.owner ? (collect(ProximalBase.activecoordinates(x)), collect(ProximalBase.activevalues(x))) : copy(x)
    before = snapshot()
    @test_throws ArgumentError solve!(x, f, NormL1(T(0.01), w), method_of(s, T))
    @test isequal(snapshot(), before)
  end
  # PGD and APG: the start has a finite loss and an infinite penalty (c₂ |x₂| above floatmax(T)), so the first
  # step fails; solve! restores the start. The loss scale is 1 and ‖X‖_F² = 4 ≥ 1, so the curvature estimate
  # starts at 1 (min(1, α‖X‖_F²)) and the first trial keeps x₂ - c₂/L at about x₂. With an estimate that starts
  # far below 1 the soft threshold c₂/L would overflow and the step would land at x₂ = 0, a point with a finite
  # penalty, and the solve would succeed. The residual at the start is 0.
  Xs, ys = T[2 0], T[2]
  x0 = T[1, T === Float32 ? 1e20 : 1e200]
  wk = T[1, T === Float32 ? 1e19 : 1e109]
  @test isfinite(LeastSquaresLoss(ys, Xs)(x0)) && !isfinite(NormL1(T(1), wk)(x0))
  for method in (ProximalGradientDescent(), AccProxGradDescent())
    x = copy(x0)
    @test_throws ErrorException solve!(x, LeastSquaresLoss(ys, Xs), NormL1(T(1), wk), method)
    @test isequal(x, x0)
  end
  # on success the result is the caller's vector
  x = zeros(T, 3)
  Xg, yg = design(T, 8, 3, 23)
  r = solve!(x, LeastSquaresLoss(yg, Xg), NormL1(T(0.05), w), CDSolver(order = :cyclic, tol = T === Float32 ? 1e-5 : 1e-9))
  @test r.minimizer === x
end

# ---------------------------------------------------------------------------------------------------------
# 13. Allocations
# ---------------------------------------------------------------------------------------------------------

# the bytes of a warmed solve, measured inside a function so that no argument is boxed; the minimum of three
function solve_allocations(s::Spec, ::Type{T}, f, g, x0) where T
  run() = begin
    x = s.owner ? SparseIterate(copy(x0)) : copy(x0)
    s.kind === :cd ? (@allocated solve!(x, f, g, method_of(s, T))) :
                     (@allocated solve!(x, f, g, method_of(s, T), ProximalOptions(maxiter = 30, ftol = 0, xtol = 1e-300, gradtol = 0,
                                                                                allow_f_increases = true)))
  end
  run()
  minimum(run() for _ in 1:3)
end

@testset "a warmed weighted solve allocates no more than the unweighted solve with the same coefficients ($T)" for T in (Float32, Float64)
  n, p = 40, 8
  X, y = design(T, n, p, 24)
  λ0 = T(0.1 * lambdamax(X, y, 1.0))
  f = LeastSquaresLoss(y, X)
  x0 = zeros(T, p)
  for s in SPECS
    weighted = solve_allocations(s, T, f, NormL1(λ0, ones(T, p)), x0)
    unweighted = solve_allocations(s, T, f, NormL1(λ0), x0)
    @test (T, s.label, weighted <= unweighted) == (T, s.label, true)
    weighted == unweighted || println("allocations, $T, $(s.label): weighted $weighted bytes, unweighted $unweighted bytes")
  end
end

# the file's own check that the matrix was not vacuous: many solves, many of which reported converged = true
@testset "the solves of this file were exercised" begin
  @test NRUN[] > 1500
  @test NCONV[] > 1000
  println("weighted lasso: $(NRUN[]) solves through solve_spec, $(NCONV[]) with converged = true")
  for key in sort!(collect(keys(WORST)); by = string)
    println("  largest measured / tolerance, $(key[1]) $(key[2]) $(key[3]): $(round(WORST[key]; sigdigits = 3))")
  end
end

end
