module CenteredSqNorm
# The centered squared norm (α/2)‖b - s‖² + λ‖b‖₁ through `solve!(x, SqrNormL2(α, s), NormL1(λ), method)` with
# CDSolver (a dense Vector and a one-dimensional SparseIterate, cyclic and random order), ProximalGradientDescent
# and AccProxGradDescent, on Float32 and Float64 data. The minimizer is b*ⱼ = sign(sⱼ) max(|sⱼ| - λ/α, 0).
#
# The references are computed in 256-bit BigFloat from the stored centre, the level α and the penalty level λ as they
# were passed, and do not use ProximalBase's prox or oracles, the solvers' gradients or their caches: the closed
# form, the objective F(x) = α/2 ‖x - s‖² + λ‖x‖₁, and the residual G(x) of the minimal-norm element of ∂F(x), which is
# max(α|sⱼ| - λ, 0) at xⱼ = 0 and |α(xⱼ - sⱼ) + λ sign xⱼ| elsewhere. F is α-strongly convex, so ‖x - b*‖₂ ≤ ‖G(x)‖₂/α.
#
# Tolerances, with u = eps(T)/2 the unit roundoff of the data type T:
#   CD. Each coordinate is its own minimizer: a visit forms the soft threshold of sⱼ at the threshold λ/α by a prox step with
#   the step 1/α, so a full pass reaches the point and the next pass changes nothing. The threshold carries at most
#   three roundings (the step 1/α, the level λ in T, their product) and the difference one, so
#   |xⱼ - b*ⱼ| <= 4u (|sⱼ| + λ/α).
#   PGD and APG. A stop counts only where the computed residual is below τ S, τ = max(gradtol, 64 eps(T)) and
#   S = max(λ, α‖s‖∞); the independent residual of entry j is allowed the rounding of the computed gradient entry and
#   of S, Gtolⱼ = τ S (1 + 8u) + 4u (α(|xⱼ| + |sⱼ|) + λ), and the point is judged by ‖x - b*‖₂ <= ‖Gtol‖₂/α with the
#   x that the solver returned and the τ of its options, whether or not it reports `converged`. In Float64 the solves
#   also assert `converged`; in Float32 they do not, as `converged` is a stopping flag of a solver whose residual
#   threshold is a few eps(Float32).
#   The reported objective is the sum of two nonnegative sums of p terms in T, so |minimum - F(x)| <= 2 (p + 4) u
#   (α/2 ‖x - s‖² + λ‖x‖₁).
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
using Logging: with_logger
const PS = ProximalSolvers

big256(f) = setprecision(f, BigFloat, 256)
unit(::Type{T}) where T = Float64(eps(T)) / 2

# ---------------------------------------------------------------------------------------------------------
# References and independent checks (BigFloat, from the stored data)
# ---------------------------------------------------------------------------------------------------------

# b*ⱼ = sign(sⱼ) max(|sⱼ| - λ/α, 0), as Float64 (the rounding of the Float64 result is far below the tolerances)
minimizer_ref(s, α, λ) = big256() do
  τ = big(λ) / big(α)
  [Float64(sign(big(sj)) * max(abs(big(sj)) - τ, 0)) for sj in s]
end

# F(x) = α/2 ‖x - s‖² + λ‖x‖₁ and its two terms
function objective_parts(s, α, λ, x)
  big256() do
    q = sum(abs2(big(x[i]) - big(s[i])) for i in eachindex(s)) * big(α) / 2
    l = big(λ) * sum(abs(big(xi)) for xi in x)
    Float64(q), Float64(l)
  end
end
objective_ref(s, α, λ, x) = sum(objective_parts(s, α, λ, x))

# the residual G(x), entrywise, as Float64
residual_ref(s, α, λ, x) = big256() do
  αb, λb = big(α), big(λ)
  [iszero(x[i]) ? Float64(max(αb * abs(big(s[i])) - λb, 0)) :
                  Float64(abs(αb * (big(x[i]) - big(s[i])) + λb * sign(big(x[i])))) for i in eachindex(s)]
end

cd_tol(::Type{T}, s, α, λ) where T = [4unit(T) * (abs(Float64(sj)) + Float64(λ) / Float64(α)) for sj in s]
function pg_tol(::Type{T}, s, α, λ, x, gradtol) where T
  u = unit(T)
  τ = max(Float64(gradtol), 64 * Float64(eps(T)))
  S = max(Float64(λ), Float64(α) * maximum(abs, Float64.(s)))
  [τ * S * (1 + 8u) + 4u * (Float64(α) * (abs(Float64(x[i])) + abs(Float64(s[i]))) + Float64(λ)) for i in eachindex(s)]
end

# the worst ratio of each measured quantity to its tolerance, by (type, method kind, quantity), printed at the end
const WORST = Dict{Tuple{DataType, Symbol, Symbol}, Float64}()
note!(T, kind, q, ratio) = (k = (T, kind, q); WORST[k] = max(get(WORST, k, 0.0), Float64(ratio)); nothing)
const NSOLVE = Ref(0)
const NCONV = Ref(0)

# ---------------------------------------------------------------------------------------------------------
# The methods of the matrix
# ---------------------------------------------------------------------------------------------------------

# kind: :cd or :pg; `start` builds the iterate the method takes from a dense vector
const METHODS = (
  (name = "CD dense cyclic",    kind = :cd, make = () -> CDSolver(order = :cyclic),                   start = x -> copy(x)),
  (name = "CD dense random",    kind = :cd, make = () -> CDSolver(order = :random, rng = Xoshiro(11)), start = x -> copy(x)),
  (name = "CD sparse cyclic",   kind = :cd, make = () -> CDSolver(order = :cyclic),                   start = x -> SparseIterate(x)),
  (name = "CD sparse random",   kind = :cd, make = () -> CDSolver(order = :random, rng = Xoshiro(12)), start = x -> SparseIterate(x)),
  (name = "PGD",                kind = :pg, make = () -> ProximalGradientDescent(),                   start = x -> copy(x)),
  (name = "APG",                kind = :pg, make = () -> AccProxGradDescent(),                        start = x -> copy(x)),
)
gradtol(::Type{Float64}) = 1e-10
gradtol(::Type{Float32}) = 0.0
# `allow_f_increases = true`: with gradtol near the rounding level of the objective, a solve can otherwise end on a
# computed objective increase with converged = false (see docs/src/support.md, notes (a) and (f))
pg_options(::Type{T}) where T = ProximalOptions(maxiter = 1000, gradtol = gradtol(T), allow_f_increases = true)

solve_with(m, x, f, g, ::Type{T}) where T = m.kind === :cd ? solve!(x, f, g, m.make()) : solve!(x, f, g, m.make(), pg_options(T))

# a centre of p entries across a few binades, with an exact zero and repeated magnitudes
function centre(::Type{T}, p; seed) where T
  rng = Xoshiro(seed)
  s = randn(rng, p) .* 2.0 .^ rand(rng, -2:2, p)
  s[1] = 0.0
  s[2] = 1.5
  s[3] = -1.5
  s[4] = s[5]
  T.(s)
end

# One solve of a method on one problem, checked against the references; returns (x, the L2 tolerance).
function check_solve(m, ::Type{T}, s, α, λ, x0) where T
  p = length(s)
  f, g = SqrNormL2(α, s), NormL1(λ)
  start = m.start(x0)
  r = solve_with(m, start, f, g, T)
  x = Vector{T}(Vector(start))
  NSOLVE[] += 1
  @test r.minimizer === start
  b = minimizer_ref(s, α, λ)
  tol = m.kind === :cd ? cd_tol(T, s, α, λ) : pg_tol(T, s, α, λ, x, gradtol(T))
  err = abs.(Float64.(x) .- b)
  if m.kind === :cd
    @test r.converged
    NCONV[] += r.converged
    @test all(err .<= tol)
    note!(T, :cd, :point, maximum(err ./ max.(tol, floatmin(Float64))))
    L2tol = norm(tol)
    iszero(λ) && @test x == s
  else
    r.converged && (NCONV[] += 1)
    T === Float64 && @test r.converged
    G = residual_ref(s, α, λ, x)
    @test norm(err) <= norm(tol) / Float64(α) * (1 + 1e-12)
    note!(T, :pg, :point, norm(err) / (norm(tol) / Float64(α)))
    if r.converged
      @test all(G .<= tol)
      note!(T, :pg, :residual, maximum(G ./ tol))
    end
    L2tol = norm(tol) / Float64(α)
  end
  F = objective_ref(s, α, λ, x)
  q, l = objective_parts(s, α, λ, x)
  @test abs(Float64(r.minimum) - F) <= 2 * (p + 4) * unit(T) * (q + l)
  note!(T, m.kind, :objective, abs(Float64(r.minimum) - F) / max(2 * (p + 4) * unit(T) * (q + l), floatmin(Float64)))
  # b is a minimizer, and convexity bounds the gap by ‖G(x)‖ ‖x - b*‖; for the gradient methods the tolerance of
  # the stop gives F(x) - F* <= ‖Gtol‖²/(2α)
  Fstar = objective_ref(s, α, λ, b)
  rounding = 8 * eps(Float64) * (F + Fstar)
  @test F - Fstar >= -rounding
  @test F - Fstar <= norm(residual_ref(s, α, λ, x)) * norm(err) * (1 + 1e-9) + rounding
  m.kind === :pg && @test F - Fstar <= L2tol^2 * Float64(α) / 2 * (1 + 1e-9) + rounding
  x, L2tol
end

# ---------------------------------------------------------------------------------------------------------
# The main matrix: type × level × penalty × start × method
# ---------------------------------------------------------------------------------------------------------

@testset "closed form, independent objective and residual, $T" for T in (Float32, Float64)
  p = 12
  s = centre(T, p; seed = 3)
  smax = maximum(abs, Float64.(s))
  for α in (2.0, 0.3, 7, 0.3f0)             # Float64, Float64, an Integer, a Float32 level
    λmax = Float64(α) * smax
    for frac in (0.0, 0.02, 0.4, 1.0, 1.7)   # λ = 0, small, moderate, the level of the zero solution and above it
      λ = T(frac * λmax)
      warm = T.(minimizer_ref(s, α, 0.9 * Float64(λ)))
      starts = (zeros(T, p), T.(smax .* cos.(1:p) ./ 2), warm)
      @testset "α = $α, λ = $(Float64(λ))" begin
        sols = Any[]
        for x0 in starts, m in METHODS
          x, L2tol = check_solve(m, T, s, α, λ, x0)
          push!(sols, (m.name, x, L2tol))
        end
        # the solutions agree across solvers, each within its own tolerance of the minimizer
        for i in eachindex(sols), j in (i + 1):length(sols)
          @test norm(Float64.(sols[i][2]) .- Float64.(sols[j][2])) <= sols[i][3] + sols[j][3] + 1e-300
        end
      end
    end
  end
end

# At |sⱼ| = λ/α exactly (α = 2, λ = 1/2, so the threshold 1/4 and the entries are dyadic) a coordinate of CD is
# exactly 0, the example of the contract returns its values exactly, and the gradient methods reach them within
# their tolerance.
@testset "exact-threshold coordinates and the example of the contract, $T" for T in (Float32, Float64)
  s = T[1, -3, 0.5]
  for (name, m) in (("cyclic", () -> CDSolver(order = :cyclic)), ("random", () -> CDSolver(order = :random, rng = Xoshiro(2))))
    x = zeros(T, 3)
    r = solve!(x, SqrNormL2(T(2), s), NormL1(T(0.5)), m())
    @test x == T[0.75, -2.75, 0.25] && r.converged && r.minimizer === x
  end
  s = T[0.25, -0.25, 0.5, -0.5, 0.0, 0.2500001, -0.75]
  for x0 in (zeros(T, 7), T[5, -5, 5, -5, 5, -5, 5])
    for x in (copy(x0), SparseIterate(copy(x0)))
      solve!(x, SqrNormL2(2.0, s), NormL1(0.5), CDSolver(order = :cyclic))
      xv = Vector(x)
      @test xv[1] === zero(T) && xv[2] === zero(T) && xv[5] === zero(T) && xv[4] == T(-0.25) && xv[3] == T(0.25)
      @test xv[7] == T(-0.5) && xv[6] == s[6] - T(0.25)
    end
    for method in (ProximalGradientDescent(), AccProxGradDescent())
      x = copy(x0)
      solve!(x, SqrNormL2(2.0, s), NormL1(0.5), method, pg_options(T))
      b = minimizer_ref(s, 2.0, 0.5)
      @test norm(Float64.(x) .- b) <= norm(pg_tol(T, s, 2.0, 0.5, x, gradtol(T))) / 2 * (1 + 1e-12)
    end
  end
end

# ---------------------------------------------------------------------------------------------------------
# Options: momentum, the stopping scale, no pass, no coordinate
# ---------------------------------------------------------------------------------------------------------

@testset "CD options: momentum, relative, maxpasses = 0, s = 0 ($T)" for T in (Float32, Float64)
  p = 9
  s = centre(T, p; seed = 8)
  α, λ = T(1.25), T(0.4)
  b = minimizer_ref(s, α, λ)
  tol = cd_tol(T, s, α, λ)
  for momentum in (nothing, false, true), relative in (true, false), order in (:random, :cyclic)
    order === :cyclic && momentum === true && continue        # cyclic order does not support momentum = true
    x = SparseIterate(zeros(T, p))
    r = solve!(x, SqrNormL2(α, s), NormL1(λ), CDSolver(; order, momentum, relative, rng = Xoshiro(5)))
    @test r.converged && all(abs.(Float64.(Vector(x)) .- b) .<= tol)
    @test r.minimizer === x
    xd = fill(T(3), p)
    r = solve!(xd, SqrNormL2(α, s), NormL1(λ), CDSolver(; order, momentum, relative, rng = Xoshiro(5)))
    @test r.converged && all(abs.(Float64.(xd) .- b) .<= tol)
  end
  # under relative = true the threshold is tol √α ‖s‖ (the sum of squares is in T, so the relative allowance is
  # that of a sum of p terms and a root), and under relative = false it is tol
  r = solve!(zeros(T, p), SqrNormL2(α, s), NormL1(λ), CDSolver(order = :cyclic))
  @test r.tolerance ≈ T(1e-7) * T(sqrt(Float64(α) * sum(abs2, Float64.(s)))) rtol = 2 * (p + 4) * unit(T)
  r = solve!(zeros(T, p), SqrNormL2(α, s), NormL1(λ), CDSolver(order = :cyclic, relative = false))
  @test r.tolerance == T(1e-7)
  # maxpasses = 0 leaves the entry state: values, active zeros and the order of the active coordinates
  entry = T[0.5, 0, -1, 0, 0, 2, 0, 0, 0]
  xd = copy(entry)
  r = @test_logs (:warn, r"maxpasses = 0") solve!(xd, SqrNormL2(α, s), NormL1(λ), CDSolver(maxpasses = 0))
  @test xd == entry && r.passes == 0 && !r.converged
  xs = SparseIterate(T, p)
  xs[7] = T(2); xs[2] = T(0); xs[4] = T(-1)
  before = (Vector(xs), collect(ProximalBase.activecoordinates(xs)), collect(ProximalBase.activevalues(xs)))
  r = @test_logs (:warn, r"maxpasses = 0") solve!(xs, SqrNormL2(α, s), NormL1(λ), CDSolver(maxpasses = 0, order = :random, rng = Xoshiro(1)))
  @test (Vector(xs), collect(ProximalBase.activecoordinates(xs)), collect(ProximalBase.activevalues(xs))) == before && r.passes == 0
  # s = 0: the response scale is 0, so the absolute tolerance is used, and the minimizer is 0 for λ >= 0
  for λ0 in (zero(T), T(0.5)), x0 in (T[1, -2, 3], zeros(T, 3))
    for x in (copy(x0), SparseIterate(copy(x0)))
      r = solve!(x, SqrNormL2(1.0, zeros(T, 3)), NormL1(λ0), CDSolver(order = :cyclic))
      @test r.converged && all(iszero, Vector(x)) && r.tolerance == T(1e-7)
    end
  end
end

@testset "PGD and APG with s = 0 ($T)" for T in (Float32, Float64)
  # λ > 0: the minimizer is 0 and the stop counts (S = λ > 0)
  for method in (ProximalGradientDescent(), AccProxGradDescent())
    x = T[1, -2, 3]
    r = solve!(x, SqrNormL2(1.0, zeros(T, 3)), NormL1(T(0.5)), method, pg_options(T))
    @test all(iszero, x) || maximum(abs, x) <= 64 * eps(T)
    T === Float64 && @test r.converged
  end
  # s = 0 and λ = 0: S = max(λ, α‖s‖∞) = 0, so no stop is proposed by any test and counts (the stationarity check
  # needs S > 0): the run goes to maxiter with converged = false, and the iterates shrink toward 0 (the minimizer)
  for method in (ProximalGradientDescent(), AccProxGradDescent()), x0 in (T[1, -2, 3], zeros(T, 3))
    x = copy(x0)
    r = solve!(x, SqrNormL2(1.0, zeros(T, 3)), NormL1(zero(T)), method, ProximalOptions(maxiter = 60))
    @test !r.converged && r.iterations == 60 && !r.x_converged && !r.f_converged && !r.grad_converged
    @test maximum(abs, x) <= 1e-30
  end
end

# ---------------------------------------------------------------------------------------------------------
# Refusals: before any change of x, the centre or the RNG
# ---------------------------------------------------------------------------------------------------------

state(x::Vector) = (copy(x), signbit.(x))
state(x) = (Vector(x), collect(ProximalBase.activecoordinates(x)), signbit.(Vector(x)))
message(e) = sprint(showerror, e)

# solve! throws an exception of type E whose message contains the fragment, with the caller's iterate, the
# centre and a borrowed RNG as they were.
function refused(E, fragment, x, f, g, method)
  before = state(x)
  centre_before = f isa SqrNormL2 && f.y !== nothing ? copy(f.y) : nothing
  rng_before = method isa CDSolver ? copy(method.rng) : nothing
  err = try
    method isa CDSolver ? solve!(x, f, g, method) : solve!(x, f, g, method, pg_options(eltype(x)))
    nothing
  catch e
    e
  end
  ok = err isa E && occursin(fragment, message(err)) && isequal(state(x), before)
  centre_before === nothing || (ok &= isequal(f.y, centre_before))
  method isa CDSolver && (ok &= method.rng == rng_before)
  ok || @info "unexpected refusal" fragment err
  ok
end

# the receivers of a refusal: a name, the iterate of the start, and the method
receivers(T) = (
  ("CD dense",           () -> T[0.5, 0, -0.25, 1],               () -> CDSolver(order = :cyclic, rng = Xoshiro(4))),
  ("CD dense random",    () -> T[0.5, 0, -0.25, 1],               () -> CDSolver(order = :random, rng = Xoshiro(4))),
  ("CD sparse random",   () -> SparseIterate(T[0.5, 0, -0.25, 1]), () -> CDSolver(order = :random, rng = Xoshiro(4))),
  ("CD sparse cyclic",   () -> SparseIterate(T[0.5, 0, -0.25, 1]), () -> CDSolver(order = :cyclic, rng = Xoshiro(4))),
  ("PGD",                () -> T[0.5, 0, -0.25, 1],               () -> ProximalGradientDescent()),
  ("APG",                () -> T[0.5, 0, -0.25, 1],               () -> AccProxGradDescent()),
)

@testset "refusals before any change of x, the centre or the RNG ($T)" for T in (Float64, Float32)
  s = T[1, -3, 0.5, 2]
  g = NormL1(T(0.25))
  other = T === Float32 ? Float64 : Float32
  for (name, mkx, mkm) in receivers(T)
    @testset "$name" begin
      R(E, frag, f, gg = g) = refused(E, frag, mkx(), f, gg, mkm())
      # the centre
      @test R(ArgumentError, "needs a centre", SqrNormL2(1.0))
      @test R(ArgumentError, "must be a Vector{$T}", SqrNormL2(1.0, other.(s)))
      @test R(ArgumentError, "must be a Vector{$T}", SqrNormL2(1.0, reshape(s, :, 1)))
      @test R(ArgumentError, "must be a Vector{$T}", SqrNormL2(1.0, view(s, :)))
      @test R(ArgumentError, "must be a Vector{$T}", SqrNormL2(1.0, Int.(round.(s))))
      @test R(DimensionMismatch, "entries", SqrNormL2(1.0, s[1:3]))
      @test R(DimensionMismatch, "entries", SqrNormL2(1.0, vcat(s, one(T))))
      @test R(ArgumentError, "finite", SqrNormL2(1.0, T[1, NaN, 0.5, 2]))
      @test R(ArgumentError, "finite", SqrNormL2(1.0, T[1, -3, Inf, 2]))
      # a start that is not finite
      for bad in (T[NaN, 0, 0, 0], T[0, 0, -Inf, 0])
        xb = name == "CD sparse random" || name == "CD sparse cyclic" ? SparseIterate(bad) : copy(bad)
        @test refused(ArgumentError, "finite", xb, SqrNormL2(1.0, s), g, mkm())
      end
      # the level α: the rule of a loss scale, with the hint naming SqrNormL2
      @test R(ArgumentError, "finite and positive", SqrNormL2(0.0, s))
      @test R(ArgumentError, "finite and positive", SqrNormL2(0, s))
      @test R(ArgumentError, "finite and positive", SqrNormL2(Inf, s))
      @test R(ArgumentError, "unsupported type", SqrNormL2(Float16(2), s))
      @test R(ArgumentError, "unsupported type", SqrNormL2(1 // 2, s))
      @test R(ArgumentError, "unsupported type", SqrNormL2(big(2), s))
      @test R(ArgumentError, "SqrNormL2(Float64(α), s), where Float64(α) = 2.0", SqrNormL2(Float16(2), s))
      @test R(ArgumentError, "SqrNormL2(Float64(α), s), where Float64(α) = 0.5", SqrNormL2(1 // 2, s))
      @test R(ArgumentError, "SqrNormL2(Float64(α), s), where Float64(α) = 2.0", SqrNormL2(big(2), s))
      T === Float32 && @test R(ArgumentError, "not exactly representable", SqrNormL2(2^24 + 1, s))
      T === Float32 && @test R(ArgumentError, "not representable", SqrNormL2(1e-50, s))
      T === Float32 && @test R(ArgumentError, "not representable", SqrNormL2(1e300, s))
      # Scaled is refused with the way to the same function
      @test R(ArgumentError, "SqrNormL2(c α, s)", Scaled(SqrNormL2(1.0, s), 2.0))
      # the penalty
      f = SqrNormL2(1.0, s)
      @test R(ArgumentError, "weighted NormL1", f, NormL1(T(0.25), ones(T, 4)))
      @test R(ArgumentError, "only an unweighted NormL1", f, ElasticNet(T(0.25), T(0.5)))
      @test R(ArgumentError, "only an unweighted NormL1", f, ProximalBase.NormL2(T(0.25)))
      @test R(ArgumentError, "only an unweighted NormL1", f, ProximalBase.NormLinf(T(0.25)))
      @test R(ArgumentError, "only an unweighted NormL1", f, ProximalBase.ZeroFunction())
      @test R(ArgumentError, "penalty lambda must be finite", f, NormL1(T(Inf)))
      T === Float32 && @test R(ArgumentError, "not representable", f, NormL1(1e-50))
      T === Float32 && @test R(ArgumentError, "not representable", f, NormL1(1e300))
      # an unsupported loss lists SqrNormL2 (and keeps the least-squares wording)
      @test R(ArgumentError, "SqrNormL2(α, s)", QuadraticFunction(Matrix{T}(I, 4, 4), zeros(T, 4)))
      @test R(ArgumentError, "only LeastSquaresLoss", QuadraticFunction(Matrix{T}(I, 4, 4), zeros(T, 4)))
    end
  end
  # a dense iterate that is the centre, and an empty problem
  for (mk) in (() -> CDSolver(order = :cyclic), () -> ProximalGradientDescent(), () -> AccProxGradDescent())
    xa = copy(s)
    @test refused(ArgumentError, "alias", xa, SqrNormL2(1.0, xa), g, mk())
    @test refused(DimensionMismatch, "positive", T[], SqrNormL2(1.0, T[]), g, mk())
  end
  # a BlockIterate
  xb = BlockIterate(T, 4, [1:2, 3:4])
  @test refused(ArgumentError, "does not support a BlockIterate", xb, SqrNormL2(1.0, s), GroupNormL2(T(0.25), [1:2, 3:4]),
                CDSolver(order = :cyclic, rng = Xoshiro(4)))
  # the constructor of ProximalBase refuses a negative or NaN level before solve! is reached
  @test_throws ArgumentError SqrNormL2(-1.0, s)
  @test_throws ArgumentError SqrNormL2(NaN, s)
end

# A Float32 level on Float64 data, a Float64 level on Float32 data, an Integer level, and penalty levels of types other
# than T (Float64, Float32, Integer, Rational) are accepted by the six methods of the matrix, within the tolerances of the matrix
# for the level and the penalty as passed (the threshold λ/α is formed from them as they are).
@testset "levels and penalty levels of other types" begin
  s32 = centre(Float32, 10; seed = 21)
  s64 = Float64.(s32)
  for (T, s) in ((Float32, s32), (Float64, s64)), α in (0.3, 0.3f0, 3), λ in (0.2, 0.2f0, 1, 1 // 5)
    for m in METHODS
      start = m.start(zeros(T, 10))
      g = NormL1(λ)
      r = solve_with(m, start, SqrNormL2(α, s), g, T)
      b = minimizer_ref(s, α, λ)
      x = Float64.(Vector(start))
      if m.kind === :cd
        @test r.converged && all(abs.(x .- b) .<= cd_tol(T, s, α, λ))
      else
        @test norm(x .- b) <= norm(pg_tol(T, s, α, λ, x, gradtol(T))) / Float64(α) * (1 + 1e-12)
      end
    end
  end
end

# ---------------------------------------------------------------------------------------------------------
# After the gate: the start, and an overflow during the run
# ---------------------------------------------------------------------------------------------------------

@testset "a start where f is not finite is refused before x changes; CD is not affected ($T)" for T in (Float32, Float64)
  α = T === Float32 ? 1f30 : 1e300       # α/2 (1e5)² overflows T
  s = T[1e5]
  for method in (ProximalGradientDescent(), AccProxGradDescent())
    @test refused(ArgumentError, "start from a point where f is finite", T[0], SqrNormL2(α, copy(s)), NormL1(zero(T)), method)
  end
  # CD does not form f at the start: the first pass puts the coordinate at s and the objective there is finite
  x = T[0]
  r = solve!(x, SqrNormL2(α, copy(s)), NormL1(zero(T)), CDSolver(order = :cyclic))
  @test x == s && r.converged && r.minimum == 0
end

@testset "a failed step restores the last accepted iterate ($T)" for T in (Float32, Float64)
  # (1) the curvature that the certified line search of APG needs exceeds floatmax(T): L / β overflows before L reaches
  # α and the search raises; the same holds for PGD in Float32. PGD in Float64 replaces its estimate by the computed
  # curvature of the rejected step, which is representable, and is not part of this test.
  α = T === Float32 ? 3f38 : 1.7e308
  for method in (T === Float32 ? (ProximalGradientDescent(), AccProxGradDescent()) : (AccProxGradDescent(),))
    accepted = Vector{T}[]
    options = ProximalOptions(maxiter = 100, extended_trace = true,
      callback = os -> (push!(accepted, copy(os.metadata["x"])); false))
    x = T[0]
    @test_throws r"cannot increase finitely" solve!(x, SqrNormL2(α, T[1]), NormL1(zero(T)), method, options)
    @test x == (isempty(accepted) ? T[0] : accepted[end])
    @test all(isfinite, x)
  end
  # (2) the penalty overflows after a step: f(x0) = 0 at x0 = s, g(x0) is not finite (accepted at the start),
  # and a step with a finite f has g(x) = Inf, which the iteration refuses
  big = T === Float32 ? T(1e19) : T(1e154)
  p = 100
  s = fill(big, p)
  for method in (ProximalGradientDescent(), AccProxGradDescent())
    x = copy(s)
    @test_throws r"did not produce a finite objective" solve!(x, SqrNormL2(1.0, copy(s)), NormL1(T(0.8 * big)), method, pg_options(T))
    @test x == s
  end
  # CD has no step that throws after the gate (an unweighted NormL1 has no throwing exceptional step); the failure that
  # remains is the nonfinite final objective, which leaves a dense iterate and an owner as they were
  xs = T === Float32 ? T[3e38, 1] : T[1.7e308, 1]
  for mk in (() -> zeros(T, 2), () -> SparseIterate(zeros(T, 2)))
    @test refused(ArgumentError, "nonfinite objective", mk(), SqrNormL2(1.0, copy(xs)), NormL1(T(10)),
                  CDSolver(order = :cyclic, rng = Xoshiro(1)))
  end
end

# ---------------------------------------------------------------------------------------------------------
# Subnormal and range cases of the level
# ---------------------------------------------------------------------------------------------------------

# The level α passes the loss-scale rule where T(α) is nonzero, also where it is subnormal in T. CD solves these problems
# to the tolerance of the matrix. For PGD and APG in Float32 the computed objective (α/2 ‖x - s‖², about 1e-40) is in
# the subnormal range, where the computed values did not separate the steps of the line search in this fixture: the runs
# of this fixture end at the start, with converged = false. The point is judged by the objective (no worse than the
# start's, within rounding), not by `converged`; this is a limit of the gradient methods, stated in docs/src/support.md.
@testset "a level that is subnormal in Float32 is accepted; the point is judged, not `converged`" begin
  s = Float32[1, -3, 0.5]
  for (α, λ) in ((1e-40, 1f-41), (1f-40, 1f-41), (1f-44, 1f-45))
    b = minimizer_ref(s, α, λ)
    for m in METHODS[[1, 4]]
      x = m.start(zeros(Float32, 3))
      r = solve!(x, SqrNormL2(α, s), NormL1(λ), m.make())
      @test r.converged && all(abs.(Float64.(Vector(x)) .- b) .<= cd_tol(Float32, s, α, λ))
    end
    for method in (ProximalGradientDescent(), AccProxGradDescent())
      x0 = zeros(Float32, 3)
      x = copy(x0)
      r = solve!(x, SqrNormL2(α, s), NormL1(λ), method, ProximalOptions(maxiter = 200, xtol = 1e-300, gradtol = 0))
      q0, l0 = objective_parts(s, α, λ, x0)
      q, l = objective_parts(s, α, λ, x)
      @test all(isfinite, x)
      @test q + l <= (q0 + l0) * (1 + 1e-6)
    end
  end
end

@testset "the Diagonal methods of the identity equal the dense p×1 column; the size bound" begin
  for T in (Float32, Float64), p in (1, 2, 7, 100)
    X = Diagonal(ones(T, p))
    col = ones(T, p, 1)
    @test PS._frobenius_upper(T, X) == PS._frobenius_upper(T, col)
    ub = PS._frobenius_upper(T, X)
    @test ldexp(Float64(ub.s), ub.e) >= sqrt(p)                       # an upper bound of ‖X‖_F = √p
    @test ldexp(Float64(ub.s), ub.e) <= sqrt(p) * (1 + 64 * unit(T))
    # a dense identity matrix of order p has the same bound up to the larger term count of its sum
    ud = PS._frobenius_upper(T, Matrix{T}(I, p, p))
    @test ldexp(Float64(ub.s), ub.e) <= ldexp(Float64(ud.s), ud.e)
    for α in (1e-300, 1e-12, 0.5 / p, 1.0 / p, 1.5 / p, 1.0, 1e12, 1e300)
      αT = α
      T === Float32 && !(1e-30 < α < 1e30) && continue
      @test PS._scanned_initial_curvature(T, X, αT) === PS._scanned_initial_curvature(T, col, αT)
      L = PS._scanned_initial_curvature(T, X, αT)
      ok = L >= T(min(1.0, α * p) * (1 - 64 * unit(T))) && L <= T(min(1.0, α * p) * (1 + 64 * unit(T)))
      ok || @info "initial curvature outside its band" T p α L expected = min(1.0, α * p)
      @test ok
    end
    # the model of the loss: the identity, the centre as the response, the level as passed
    s = T.(1:p)
    f = SqrNormL2(0.25, s)
    m = PS._image_model(f)
    @test m.X == Diagonal(ones(T, p)) && m.Y === s && m.α === 0.25 && length(PS._image_buffer(m)) == p
  end
  # the arithmetic of the bound: p + 4 terms in T and p + 3 in Float64, at the largest p that each type admits
  @test PS._bound_size_ok(Float32, 2^21 - 5) && !PS._bound_size_ok(Float32, 2^21 - 4)
  @test PS._bound_size_ok(Float64, 2^50 - 5) && !PS._bound_size_ok(Float64, 2^50 - 4)
  # and the check itself, at the Float32 boundary (a centre of 2,097,147 entries is 8 MB)
  @test PS._check_bound_size(SqrNormL2(1f0, zeros(Float32, 2^21 - 5)), Float32) === nothing
  @test_throws ArgumentError PS._check_bound_size(SqrNormL2(1f0, zeros(Float32, 2^21 - 4)), Float32)
end

# the least-squares check of the bound is unchanged by the method of SqrNormL2
@testset "the size bound of least squares is unchanged" begin
  f = LeastSquaresLoss(zeros(Float32, 3), zeros(Float32, 3, 2))
  @test PS._check_bound_size(f, Float32) === nothing
end

let
  println("centered_sqnorm: ", NSOLVE[], " solves of the main matrix, ", NCONV[], " reported converged = true")
  for k in sort(collect(keys(WORST)); by = string)
    println("  worst ratio to the tolerance, ", k[1], " ", k[2], " ", k[3], ": ", round(WORST[k]; sigdigits = 3))
  end
end
end
