module CoreContracts
using Test, LinearAlgebra, SparseArrays, Random, ProximalBase, ProximalSolvers
import Logging

# A real callable composition, independent of PB's deferred Translate wrapper.
struct ShiftedLoss{F, V} <: ProximalBase.AbstractFunction
  loss::F
  shift::V
end
(f::ShiftedLoss)(x) = f.loss(x .+ f.shift)

@testset "CD reports the objective where Σr² overflows and the value is representable; it refuses a nonfinite one before scatter" begin
  # Σr² = fl(1e20)² overflows Float32, and the value α Σr²/2 is representable: ProximalBase's residual
  # oracle recomputes it, within (n + 8) eps(T) |v| (n = 1).
  y, X = Float32[1e20], zeros(Float32, 1, 1)
  r = solve!(Float32[.5], 1e-10 * LeastSquaresLoss(y, X), NormL1(0f0), CDSolver())
  v = setprecision(BigFloat, 256) do
    big(1e-10) * big(y[1])^2 / 2
  end
  @test isfinite(r.minimum) && abs(big(r.minimum) - v) <= 9 * eps(Float32) * v
  # the value itself is above floatmax(Float32)
  x = Float32[.5]
  @test_throws r"nonfinite objective" solve!(x, 1e10 * LeastSquaresLoss(y, X), NormL1(0f0), CDSolver())
  @test x == Float32[.5]
  x = [1e308, -1e308]
  @test_logs (:warn, r"maxpasses = 0") begin
    @test_throws r"nonfinite objective" solve!(x,
      LeastSquaresLoss([0.], fill(1e308, 1, 2)), NormL1(0.), CDSolver(maxpasses = 0))
  end
  @test x == [1e308, -1e308]
end

function refused(x, f, g, method; options = nothing, kwargs...)
  original = copy(x)
  @test_throws ArgumentError options === nothing ? solve!(x, f, g, method; kwargs...) :
    solve!(x, f, g, method, options; kwargs...)
  @test isequal(x, original)
end

@testset "narrow public boundary refuses before mutation" begin
  for T in (Float64, Float32), method in (CDSolver(), ProximalGradientDescent())
    X, y, x = T[1 0; 0 2], T[1, -1], T[.3, -.2]
    f, g = LeastSquaresLoss(y, X), NormL1(T(.1))
    for bad in (sparse(x), reshape(copy(x), 1, 2), view(x, :))
      refused(bad, f, g, method)
    end
    # a vector SparseIterate is an owner for CD (test/sparse_cd.jl) but not for PGD
    method isa ProximalGradientDescent && refused(SparseIterate(x), f, g, method)
    refused(Int[0, 0], f, g, method)
    refused(Float16[0, 0], f, g, method)
    refused(zeros(T === Float32 ? Float64 : Float32, 2), f, g, method)
    refused(x, LeastSquaresLoss(y, sparse(X)), g, method)
    refused(x, LeastSquaresLoss(y, view(X, :, :)), g, method)
    refused(x, LeastSquaresLoss(reshape(y, 2, 1), X), g, method)
    refused(x, QuadraticFunction(Matrix{T}(I, 2, 2), zeros(T, 2)), g, method)
    refused(x, ShiftedLoss(f, ones(T, 2)), g, method)
    refused(x, Scaled(Scaled(f, 1e-200), 1e-200), g, method)
    refused(x, Scaled(f, 0.), g, method) # PB produces ZeroFunction, PS refuses it.
    opposite = T === Float32 ? Float64 : Float32
    refused(x, LeastSquaresLoss(opposite.(y), X), g, method)
    for badscale in (-1., NaN)
      @test_throws ArgumentError Scaled(f, badscale)
    end
    # weights are accepted (test/weighted_lasso.jl); these are not: an infinite weight, and weights of the other
    # precision
    refused(x, f, NormL1(T(.1), T[1, Inf]), method)
    refused(x, f, NormL1(T(.1), ones(opposite, 2)), method)
    refused(x, f, SqrNormL2(T(.1)), method)
    for keyword in (:intercept, :offset, :continuation, :screening)
      refused(x, f, g, method; keyword => true)
    end
    for data in (T[NaN, 0], T[Inf, 0])
      refused(data, f, g, method)
      refused(x, LeastSquaresLoss(data, X), g, method)
      badX = copy(X)
      badX[1, 1] = data[1]
      refused(x, LeastSquaresLoss(y, badX), g, method)
    end
    refused(y, LeastSquaresLoss(y, X), g, method)
    alias_x = copy(x)
    refused(alias_x, LeastSquaresLoss(T[1], reshape(alias_x, 1, 2)), g, method)
    for n in (0, 1, 3)
      z = zeros(T, n)
      before = copy(z)
      @test_throws DimensionMismatch solve!(z, f, g, method)
      @test z == before
    end
    @test_throws DimensionMismatch solve!(T[],
      LeastSquaresLoss(T[], zeros(T, 0, 0)), NormL1(zero(T)), method)
    if T === Float32
      for a in (1e-50, 1e40)
        refused(x, Scaled(f, a), g, method)
        refused(x, f, NormL1(a), method)
      end
    end
    refused(x, Scaled(f, Inf), g, method)
    refused(x, f, NormL1(Inf), method)
    @test x == T[.3, -.2] && X == T[1 0; 0 2] && y == T[1, -1]
  end
end

# ElasticNet (#324): ProximalGradientDescent and AccProxGradDescent accept an unweighted one, and
# CDSolver refuses an ElasticNet of any weights and levels. The refusals tested here leave x unchanged. The APG counterpart is in
# test/accelerated_pgd.jl.
const EN_GRADIENT_REFUSAL = "only NormL1 or unweighted ElasticNet is supported"
const EN_CD_REFUSAL = "CDSolver does not support ElasticNet yet; use ProximalGradientDescent or AccProxGradDescent"

function refused_with(x, f, g, method, msg)
  original = copy(x)
  @test_throws ArgumentError(msg) solve!(x, f, g, method)
  @test isequal(x, original)
end

@testset "PGD refuses the penalties it does not support, with the ElasticNet message (#324)" begin
  for T in (Float64, Float32)
    X, y, x = T[1 0; 0 2], T[1, -1], T[.3, -.2]
    f = LeastSquaresLoss(y, X)
    method = ProximalGradientDescent()
    en = ElasticNet(T(.1), T(.2))
    for g in (ElasticNet(T(.1), T(.2), ones(T, 2)), Scaled(en, 2), Scaled(NormL1(T(.1), ones(T, 2)), 2), SqrNormL2(T(.1)))
      refused_with(x, f, g, method, EN_GRADIENT_REFUSAL)
    end
    # a NormL1 with weights is accepted (#331); its solves are in test/weighted_lasso.jl
    r = solve!(copy(x), f, NormL1(T(.1), T[1, 2]), method)
    @test r.converged && all(isfinite, r.minimizer)
    refused_with(x, f, ElasticNet(T(Inf), zero(T)), method, "penalty lambda1 must be finite and nonnegative")
    refused_with(x, f, ElasticNet(zero(T), T(Inf)), method, "penalty lambda2 must be finite and nonnegative")
    if T === Float32
      for a in (1e40, 1e-60)
        refused_with(x, f, ElasticNet(a, 0.1), method, "penalty lambda1 is not representable without overflow or underflow in Float32")
        refused_with(x, f, ElasticNet(0.1, a), method, "penalty lambda2 is not representable without overflow or underflow in Float32")
      end
    end
    # a SparseIterate is not an iterate of PGD, and the iterate is checked before the penalty
    refused_with(SparseIterate(x), f, en, method, "x must be a dense Vector{Float32} or Vector{Float64}")
    refused_with(SparseIterate(x), f, ElasticNet(T(.1), T(.2), ones(T, 2)), method,
                 "x must be a dense Vector{Float32} or Vector{Float64}")
    refused_with(Int[0, 0], f, en, method, "x must be a dense Vector{Float32} or Vector{Float64}")
    # the loss and shape checks come before the penalty check, as for NormL1
    @test_throws DimensionMismatch solve!(zeros(T, 3), f, en, method)
    @test x == T[.3, -.2]
  end
end

@testset "CD refuses every ElasticNet before any copy, write or RNG use, and keeps its other message (#324)" begin
  for T in (Float64, Float32)
    X, y, x = T[1 0; 0 2], T[1, -1], T[.3, -.2]
    f = LeastSquaresLoss(y, X)
    en = ElasticNet(T(.1), T(.2))
    for g in (en, ElasticNet(T(.1), T(.2), ones(T, 2)), ElasticNet(T(Inf), zero(T)), ElasticNet(zero(T), T(Inf)))
      for start in (copy(x), SparseIterate(copy(x)))
        rng = Xoshiro(1)
        before = copy(rng)
        refused_with(start, f, g, CDSolver(rng = rng), EN_CD_REFUSAL)
        @test rng == before && rand(rng) == rand(before)
      end
    end
    # the iterate is checked before the penalty, and the penalties below get the message of NormL1
    refused_with(Int[0, 0], f, en, CDSolver(), "x must be a dense Vector{Float32} or Vector{Float64}")
    for g in (Scaled(en, 2), Scaled(NormL1(T(.1), ones(T, 2)), 2), SqrNormL2(T(.1)))
      refused_with(copy(x), f, g, CDSolver(), "only NormL1 is supported")
      refused_with(SparseIterate(copy(x)), f, g, CDSolver(), "only NormL1 is supported")
    end
    # a NormL1 with weights is accepted, on a dense vector and on an owner (#331)
    for start in (copy(x), SparseIterate(copy(x)))
      r = solve!(start, f, NormL1(T(.1), T[1, 2]), CDSolver(order = :cyclic))
      @test r.converged && r.minimizer === start
    end
    @test x == T[.3, -.2]
  end
end

@testset "retained constructor validation" begin
  # ftol = 0 is accepted (see "ftol = 0 is a valid option" below)
  for v in (-1., Inf, NaN)
    @test_throws ArgumentError ProximalOptions(; ftol = v)
  end
  for v in (0., -1., Inf, NaN)
    @test_throws ArgumentError ProximalOptions(; xtol = v)
  end
  for kw in (:gradtol, :gaptol), v in (-1., Inf, NaN)
    @test_throws ArgumentError ProximalOptions(; kw => v)
  end
  @test_throws ArgumentError ProximalOptions(maxiter = 1)
  @test_throws ArgumentError CDSolver(tol = NaN)
  @test_throws ArgumentError CDSolver(order = :unknown)
end

@testset "deferred options cannot hide in positional constructors" begin
  for (keyword, value) in ((:anderson, 1), (:gaptol, .1), (:gapsafe, true))
    @test_throws ArgumentError CDSolver(; keyword => value)
  end
  @test_throws ArgumentError ProximalGradientDescent(normalized = true)
  @test_throws ArgumentError ProximalGradientDescent(debias = 1)
  @test_throws ArgumentError ProximalGradientDescent(preconditioner = :diagonal)
  @test_throws ArgumentError ProximalGradientDescent(ls = nothing)
  # the explicit 3-argument method still routes through the keyword checks
  @test_throws ArgumentError("normalized IHT is deferred") ProximalGradientDescent(
    ProximalSolvers.LineSearches.BackTracking(), true, 0)
  @test_throws ArgumentError("debiasing is deferred") ProximalGradientDescent(
    ProximalSolvers.LineSearches.BackTracking(), false, 1)
end
@testset "PGD and its options have one validated constructor each (#268)" begin
  LS = ProximalSolvers.LineSearches
  # the deferred settings are accepted at their defaults but not stored
  @test fieldnames(ProximalGradientDescent) == (:ls,)
  @test ProximalGradientDescent(normalized = false, debias = 0, preconditioner = :none) ==
        ProximalGradientDescent() == ProximalGradientDescent(LS.BackTracking()) ==
        ProximalGradientDescent(LS.BackTracking(), false, 0)
  @test ProximalGradientDescent() isa ProximalGradientDescent{LS.BackTracking{Float64}}
  @test_throws ArgumentError("debias must be nonnegative, but it is -1.") ProximalGradientDescent(debias = -1)
  @test_throws ArgumentError("normalized IHT is deferred") ProximalGradientDescent(normalized = true)
  @test_throws ArgumentError("debiasing is deferred") ProximalGradientDescent(debias = 1)
  @test_throws ArgumentError("preconditioning is deferred") ProximalGradientDescent(preconditioner = :diagonal)
  for ls in (nothing, :backtracking, 0.5)
    @test_throws ArgumentError("only BackTracking is supported") ProximalGradientDescent(ls)
    @test_throws ArgumentError("only BackTracking is supported") ProximalGradientDescent(; ls)
  end
  # the former default constructors with the deferred fields are gone
  @test_throws MethodError ProximalGradientDescent(LS.BackTracking(), false, 0, nothing)
  @test_throws MethodError ProximalGradientDescent{LS.BackTracking{Float64}}(LS.BackTracking())
  # BackTracking validates every route, before and after conversion to floating point
  message = "backtracking needs 0 < α <= 1, 0 < β < 1, and Lexact > 0"
  for (α, β, Lexact) in ((0., .5, Inf), (1.5, .5, Inf), (.9, 1., Inf), (.9, 0., Inf),
                         (.9, .5, 0.), (NaN, .5, Inf), (.9, NaN, Inf), (.9, .5, NaN))
    @test_throws ArgumentError(message) LS.BackTracking(α, β, Lexact)
    @test_throws ArgumentError(message) LS.BackTracking(; α, β, Lexact)
  end
  @test_throws ArgumentError(message) LS.BackTracking(α = 1 + big(1) // big(10)^20)
  # a setting valid as given but not after promotion (2-bit BigFloat: 0.99 rounds to 1)
  setprecision(BigFloat, 2) do
    @test_throws ArgumentError(message) LS.BackTracking(β = 0.99, Lexact = big(Inf))
  end
  @test_throws MethodError LS.BackTracking{Float64}(.9, .5, Inf)
  @test LS.BackTracking(α = 1, β = 1 // 4, Lexact = 10) === LS.BackTracking(1.0, 0.25, 10.0)
  @test LS.BackTracking(α = .9f0, β = .5f0, Lexact = Inf32) isa LS.BackTracking{Float32}
  # ProximalOptions: gaptol and gapevery are accepted for compatibility and not stored;
  # a nondefault gaptol is refused at construction
  @test fieldnames(ProximalOptions) == (:maxiter, :ftol, :xtol, :gradtol, :f_calls_limit,
    :grad_calls_limit, :prox_calls_limit, :allow_f_increases, :store_trace, :show_trace,
    :extended_trace, :print_every, :callback, :time_limit)
  plain = ProximalOptions()
  @test all(n -> isequal(getfield(plain, n), getfield(ProximalOptions(gaptol = 0, gapevery = 17), n)),
            fieldnames(ProximalOptions))
  @test_throws ArgumentError("gap certificates are deferred") ProximalOptions(gaptol = .1)
  @test_throws ArgumentError("gap certificates are deferred") ProximalOptions(gaptol = 1e-300)
  for v in (-1., Inf, NaN)
    @test_throws ArgumentError("gaptol must be finite and nonnegative.") ProximalOptions(gaptol = v)
  end
  @test_throws ArgumentError("gapevery must be positive.") ProximalOptions(gapevery = 0)
  for (kw, v, message) in ((:maxiter, 1, "maxiter must be an integer greater than 1."),
                           (:ftol, -1., "ftol must be finite and nonnegative."),
                           (:xtol, NaN, "xtol must be finite and positive."),
                           (:gradtol, -1., "gradtol must be finite and nonnegative."),
                           (:f_calls_limit, -1, "call limits must be nonnegative."),
                           (:grad_calls_limit, -1, "call limits must be nonnegative."),
                           (:prox_calls_limit, -1, "call limits must be nonnegative."),
                           (:time_limit, NaN, "time_limit must not be NaN."),
                           (:print_every, 0, "print_every must be positive."))
    @test_throws ArgumentError(message) ProximalOptions(; kw => v)
  end
  # tolerances are checked as given and after conversion to Float64
  tiny = big(1) // big(10)^400
  @test_throws ArgumentError("ftol is positive but rounds to 0 in Float64; pass 0 to disable the objective test.") ProximalOptions(ftol = tiny)
  @test_throws ArgumentError("xtol must be finite and positive.") ProximalOptions(xtol = tiny)
  @test_throws ArgumentError("gradtol must be finite and nonnegative.") ProximalOptions(gradtol = -tiny)
  @test_throws ArgumentError("ftol is positive but rounds to 0 in Float64; pass 0 to disable the objective test.") ProximalOptions(1000, tiny, 1e-8, 1e-5,
    0, 0, 0, false, false, false, false, 1, nothing, Inf)
  @test ProximalOptions(gradtol = tiny).gradtol === 0.0
  # time_limit keeps its untyped keyword: anything convertible to Float64 is accepted
  @test ProximalOptions(time_limit = 5 + 0im).time_limit === 5.0
  @test_throws ArgumentError("time_limit must not be NaN.") ProximalOptions(time_limit = complex(NaN, 0))
  @test_throws MethodError ProximalOptions{Nothing}((getfield(plain, n) for n in fieldnames(ProximalOptions))...)
  # the former 16-field positional form with gaptol and gapevery is gone
  @test_throws MethodError ProximalOptions((getfield(plain, n) for n in fieldnames(ProximalOptions))..., 0., 10)
  callback = state -> false
  o = ProximalOptions(maxiter = big(50), ftol = 1 // 10^6, print_every = Int32(3), time_limit = 5, callback = callback)
  @test o.maxiter === 50 && o.ftol === 1e-6 && o.print_every === 3 && o.time_limit === 5.0
  @test o isa ProximalOptions{typeof(callback)} && o.callback === callback
end
@testset "CDSolver has one validated constructor (#268)" begin
  # anderson, gaptol and gapsafe are accepted at their defaults but not stored
  @test fieldnames(CDSolver) == (:maxpasses, :tol, :random, :relative, :momentum, :rng)
  plain = CDSolver(rng = Xoshiro(1))
  noop = CDSolver(anderson = 0, gaptol = 0, gapsafe = false, rng = Xoshiro(1))
  @test all(n -> isequal(getfield(plain, n), getfield(noop, n)), fieldnames(CDSolver))
  for (keyword, value) in ((:anderson, -1), (:gaptol, -1.), (:gaptol, NaN), (:gaptol, Inf))
    @test_throws ArgumentError CDSolver(; keyword => value)
  end
  # the refusal messages of single invalid keywords are unchanged
  @test_throws ArgumentError("Anderson acceleration is deferred") CDSolver(anderson = 1)
  @test_throws ArgumentError("gap certificates are deferred") CDSolver(gaptol = .1)
  @test_throws ArgumentError("gap screening is deferred") CDSolver(gapsafe = true)
  @test_throws ArgumentError("maxpasses must be nonnegative, but it is -1.") CDSolver(maxpasses = -1)
  @test_throws ArgumentError("tol must be nonnegative, but it is NaN.") CDSolver(tol = NaN)
  @test_throws ArgumentError("order must be :random or :cyclic, but it is :x.") CDSolver(order = :x)
  @test_throws r"momentum needs order = :random" CDSolver(order = :cyclic, momentum = true)
  # wider argument types convert as before; unrepresentable ones are refused
  wide = CDSolver(Int32(7), big"1e-9", true, true, nothing, Xoshiro(1))
  @test wide.maxpasses === 7 && wide.tol === 1e-9
  @test CDSolver(maxpasses = big(7), tol = 1//10).tol === 0.1
  @test_throws InexactError CDSolver(maxpasses = big(2)^70)
  @test_throws InexactError CDSolver(big(2)^70, 1e-7, true, true, nothing, Xoshiro(1))
  # the positional route is validated at construction, so an invalid solver cannot exist
  @test_throws ArgumentError CDSolver(-1, 1e-7, true, true, nothing, Xoshiro(1))
  for tol in (-1., NaN, Inf, big"1e400")
    @test_throws ArgumentError CDSolver(100, tol, true, true, nothing, Xoshiro(1))
  end
  @test_throws ArgumentError CDSolver(100, 1e-7, false, true, true, Xoshiro(1))
  @test_throws MethodError CDSolver{Xoshiro}(100, 1e-7, true, true, nothing, Xoshiro(1))
  # the former 9-argument default constructor, with the deferred fields, is gone
  @test_throws MethodError CDSolver(100, 1e-7, true, true, 1, nothing, Xoshiro(1), 0., false)
  @test_throws MethodError CDSolver(100, 1e-7, true, true, 0, nothing, Xoshiro(1), 0., false)
  # a valid positional solver is the keyword solver, and solves identically
  X = [1. 0 2; 0 2 1; 1 1 0; 2 0 1]
  f, g = (1 / 4) * LeastSquaresLoss([1., -1, .5, 2], X), NormL1(.05)
  for (order, random, momentum) in ((:random, true, nothing), (:random, true, true),
                                    (:random, true, false), (:cyclic, false, false))
    kw = CDSolver(; maxpasses = 50, tol = 1e-9, order, relative = false, momentum, rng = Xoshiro(3))
    pos = CDSolver(50, 1e-9, random, false, momentum, Xoshiro(3))
    @test typeof(kw) === typeof(pos)
    @test all(n -> isequal(getfield(kw, n), getfield(pos, n)), fieldnames(CDSolver))
    for start in (zeros(3), SparseIterate(zeros(3)))
      a, b = copy(start), copy(start)
      ra, rb = solve!(a, f, g, kw), solve!(b, f, g, pos)
      @test isequal(Vector(a), Vector(b)) && ra.passes == rb.passes && ra.converged == rb.converged
      @test isequal(ra.minimum, rb.minimum) && isequal(ra.maxchange, rb.maxchange)
      @test rand(kw.rng, UInt64) == rand(pos.rng, UInt64)
    end
  end
end
@testset "positional options are validated at construction" begin
  f, g = LeastSquaresLoss([1.], ones(1, 1)), NormL1(.1)
  valid = ProximalOptions()
  for (field, bad) in ((:maxiter, 1), (:ftol, NaN), (:xtol, 0.), (:gradtol, -1.),
       (:f_calls_limit, -1), (:grad_calls_limit, -1), (:prox_calls_limit, -1),
       (:print_every, 0), (:time_limit, NaN))
    values = Any[getfield(valid, n) for n in fieldnames(typeof(valid))]
    values[findfirst(n -> n == field, fieldnames(typeof(valid)))] = bad
    @test_throws ArgumentError ProximalOptions(values...)
  end
  values = Any[getfield(valid, n) for n in fieldnames(typeof(valid))]
  @test isequal(ProximalOptions(values...), valid)
  r = solve!([0.], f, g, ProximalGradientDescent(), ProximalOptions(time_limit = -1.))
  @test r.iterations == 1
  x, z = [0.], [0.]
  a = solve!(x, f, g, ProximalGradientDescent())
  b = solve!(z, f, g, ProximalGradientDescent(), ProximalOptions(gapevery = 17))
  @test x == z && a.iterations == b.iterations && isnan(b.gap)
end
@testset "ftol = 0 is a valid option and a tiny positive ftol is refused (#270)" begin
  rounds = "ftol is positive but rounds to 0 in Float64; pass 0 to disable the objective test."
  nonneg = "ftol must be finite and nonnegative."
  positional(ftol) = ProximalOptions(1000, ftol, 1e-8, 1e-5, 0, 0, 0, false, false, false, false, 1, nothing, Inf)
  # accepted: these spellings of zero are stored as +0.0, other values as their Float64
  for z in (0, 0.0, -0.0, 0f0, -0f0, big(0), big"0.0", big"-0.0", 0 // 1)
    @test ProximalOptions(ftol = z).ftol === 0.0
    @test positional(z).ftol === 0.0
  end
  # the other fields of such options are those of the default options
  zero_ftol = ProximalOptions(ftol = 0)
  default = ProximalOptions()
  @test all(n -> n === :ftol || isequal(getfield(zero_ftol, n), getfield(default, n)), fieldnames(ProximalOptions))
  @test ProximalOptions(ftol = nextfloat(0.0)).ftol === nextfloat(0.0)
  @test positional(nextfloat(0.0)).ftol === nextfloat(0.0)
  @test ProximalOptions(ftol = floatmin(Float64)).ftol === floatmin(Float64)
  @test ProximalOptions(ftol = 1e-300).ftol === 1e-300
  # a positive value that is 0.0 as a Float64 is refused, with its own message
  for tiny in (big"1e-400", 1 // big(10)^400, big"1e-1000", nextfloat(big"0.0"))
    @test_throws ArgumentError(rounds) ProximalOptions(ftol = tiny)
    @test_throws ArgumentError(rounds) positional(tiny)
  end
  # negative, NaN and infinite values are refused as before, with the nonnegative message
  for bad in (-1., -1e-300, -nextfloat(0.0), -1, NaN, Inf, -Inf, NaN32, Inf32, big"-1e-400",
              -1 // big(10)^400, big"1e400")
    @test_throws ArgumentError(nonneg) ProximalOptions(ftol = bad)
    @test_throws ArgumentError(nonneg) positional(bad)
  end
  # xtol keeps refusing 0 and gradtol keeps accepting it
  @test_throws ArgumentError("xtol must be finite and positive.") ProximalOptions(xtol = 0)
  @test_throws ArgumentError("xtol must be finite and positive.") ProximalOptions(ftol = 0, xtol = 0.0)
  @test ProximalOptions(ftol = 0, gradtol = 0).gradtol === 0.0
end

# ---- The loss scale of a Scaled loss: supported types, and refusals before any write (#307) ---------
# A Float32 or Float64 scale, or a fixed-width integer or Bool that T represents exactly, is supported. A scale
# of another type (BigInt, BigFloat, Rational, Float16, Irrational) and an integer that T rounds are refused
# before any write: this narrows the scales that were accepted before ProximalBase's oracles were used.
const LOSS_SCALE_REFUSAL = r"only Float32 and Float64 scales and fixed-width integer scales that \w+ represents exactly are supported"

function scale_problem(::Type{T}) where T
  X = T[1 0 .2; 0 1 -.1; .3 .1 1; .5 -.4 .2; -.2 .3 .6; .1 .1 -.7]
  y = T[1, -.5, .7, .2, -.6, .4]
  X, y
end
# the owner of a SparseIterate: its active coordinates and values
owner_state(x::SparseIterate) = (collect(ProximalBase.activecoordinates(x)), collect(ProximalBase.activevalues(x)))
owner_state(x) = copy(x)

const SCALE_SOLVERS = (("CD dense", () -> CDSolver(rng = Xoshiro(3)), false),
                       ("CD owner", () -> CDSolver(rng = Xoshiro(3)), true),
                       ("PGD", () -> ProximalGradientDescent(), false),
                       ("APG", () -> AccProxGradDescent(), false))
scale_accepted(::Type{Float32}) = Any[0.25, 0.25f0, 3, true, UInt8(3), 2^24]
scale_accepted(::Type{Float64}) = Any[0.25, 0.25f0, 3, true, UInt8(3), 2^24, 2^53]
scale_refused(::Type{Float32}) = Any[2^24 + 1, big(2), big(2.0), 1 // 4, Float16(0.5), π]
scale_refused(::Type{Float64}) = Any[2^53 + 1, big(2), big(2.0), 1 // 4, Float16(0.5), π]

@testset "the supported loss scales are accepted by every solver and ProximalBase's value oracle" begin
  for T in (Float32, Float64), (name, method, owner) in SCALE_SOLVERS, α in scale_accepted(T)
    X, y = scale_problem(T)
    f = Scaled(LeastSquaresLoss(y, X), α)
    g = NormL1(T(0.1 * Float64(α) * maximum(abs, X' * y)))
    x = owner ? SparseIterate(zeros(T, 3)) : zeros(T, 3)
    r = Logging.with_logger(Logging.NullLogger()) do
      solve!(x, f, g, method())
    end
    @test isfinite(r.minimum)
    # the rule of PS is a subset of the domain of the residual oracle of ProximalBase
    @test ProximalBase.value_from_residual(f, T[.1, -.2, .3, 0, .1, -.1]) isa T
  end
end

@testset "an unsupported loss scale is refused before any write: dense iterate and owner unchanged" begin
  for T in (Float32, Float64), (name, method, owner) in SCALE_SOLVERS, α in scale_refused(T)
    X, y = scale_problem(T)
    f = Scaled(LeastSquaresLoss(y, X), α)
    x = owner ? SparseIterate(T[.3, 0, -.2]) : T[.3, 0, -.2]
    before = owner_state(x)
    err = try
      solve!(x, f, NormL1(T(0.01)), method())
      nothing
    catch e
      e
    end
    @test err isa ArgumentError && occursin(LOSS_SCALE_REFUSAL, err.msg)
    @test isequal(owner_state(x), before)
  end
end

@testset "the refusal of a loss scale suggests Float64(α) only where that conversion is supported" begin
  function message(α, T = Float32)
    X, y = scale_problem(T)
    try
      solve!(zeros(T, 3), Scaled(LeastSquaresLoss(y, X), α), NormL1(T(0.01)), CDSolver())
      ""
    catch e
      e.msg
    end
  end
  for α in (Float16(0.5), 1 // 4, 2^24 + 1, big(2), big(2.0), π)
    @test occursin("Float64(α) * LeastSquaresLoss(y, X)", message(α))
  end
  @test occursin("Float64(α) * LeastSquaresLoss(y, X)", message(2^53 + 1, Float64))
  # Float64(α) is Inf, 0, or a scale that Float32 does not hold
  for α in (big(2.0)^2000, big(2)^2000, big(2.0)^-2000, big(10.0)^-300)
    @test occursin(LOSS_SCALE_REFUSAL, message(α))
    @test !occursin("Float64(α)", message(α))
  end
  # the message names the type and the value
  @test occursin("Float16", message(Float16(0.5))) && occursin("0.5", message(Float16(0.5)))
end

@testset "a Float32 or Float64 scale keeps the rule of the loss scale: nonzero in T, subnormal allowed" begin
  X, y = scale_problem(Float32)
  # subnormal in Float32: accepted; rounds to 0 in Float32: refused
  @test isfinite(solve!(zeros(Float32, 3), Scaled(LeastSquaresLoss(y, X), 1e-44), NormL1(0f0), CDSolver()).minimum)
  x = zeros(Float32, 3)
  @test_throws ArgumentError solve!(x, Scaled(LeastSquaresLoss(y, X), 1e-300), NormL1(0.01f0), CDSolver())
  @test x == zeros(Float32, 3)
end

end
