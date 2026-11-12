module MinimalCoreCharacterization

using Test, LinearAlgebra, Random
using ProximalBase, ProximalSolvers
const PS = ProximalSolvers

# Independent arithmetic on the supplied (rounded) data, never PB proximal,
# PS gradient/cache, or convergence helpers. Wider checks matter for Float32.
function objective(X, y, x, λ, scale)
  A, b, z = Float64.(X), Float64.(y), Float64.(x)
  Float64(scale) * sum(abs2, b - A * z) / 2 + Float64(λ) * sum(abs, z)
end
function kkt(X, y, x, λ, scale)
  A, b, z = Float64.(X), Float64.(y), Float64.(x)
  d = Float64(scale) * (A' * (A * z - b))
  maximum((iszero(z[j]) ? max(abs(d[j]) - Float64(λ), 0.0) :
           abs(d[j] + Float64(λ) * sign(z[j])) for j in eachindex(z)); init = 0.0)
end

# Finite active-face enumeration for tiny FULL COLUMN RANK fixtures only.
# All restricted systems are nonsingular in that domain. Wider arithmetic is
# independent of native-type solver accumulation and avoids solving the lasso
# by a second copy of either iterative algorithm.
function reference(X, y, λ, scale)
  size(X, 2) <= 7 || error("reference is restricted to tiny problems")
  rank(Float64.(X)) == size(X, 2) || error("reference requires full column rank")
  setprecision(BigFloat, 128) do
    A, b, a, l = BigFloat.(X), BigFloat.(y), BigFloat(scale), BigFloat(λ)
    p = size(A, 2)
    best, answer = BigFloat(Inf), nothing
    slack = big"1e-25"
    for signs in Iterators.product(ntuple(_ -> (-1, 0, 1), p)...)
      S = findall(!iszero, collect(signs))
      z = zeros(BigFloat, p)
      if !isempty(S)
        B = A[:, S]
        z[S] = (a * (B' * B)) \ (a * (B' * b) - l * collect(signs)[S])
        all(j -> sign(z[j]) == signs[j], S) || continue
      end
      d = a * (A' * (A * z - b))
      all(j -> iszero(signs[j]) ? abs(d[j]) <= l + slack :
          abs(d[j] + l * signs[j]) <= slack, 1:p) || continue
      value = a * sum(abs2, b - A * z) / 2 + l * sum(abs, z)
      if value < best
        best, answer = value, z
      end
    end
    answer === nothing && error("independent reference found no KKT-feasible face")
    Float64.(answer), Float64(best)
  end
end

function correlated(::Type{T}) where T
  T[1 1 .2; 2 1 .3; -1 0 .5; .1 1 1; .4 .3 -.8; -.2 .8 .1; .6 -.1 .2],
  T[2, 1, -1, .4, -.5, .7, .9]
end
quiet(f) = (@test_logs (:warn, r"coordinate descent did not converge") f())
strict_options(::Type{T}; kwargs...) where T = ProximalOptions(;
  maxiter = 10_000, ftol = 1e-20, xtol = T === Float64 ? 1e-12 : 1e-7,
  gradtol = T === Float64 ? 1e-10 : 1e-5, kwargs...)

# Fixture-specific test bound for this file's correlated fixture; it is not a
# solver tolerance or a general guarantee. With allow_f_increases = false, PGD
# stops at the first iteration whose native-precision objective increases, and
# reports converged = false unless the x, f or gradient test held at that
# iteration. 64 eps(T) is approximately twice the first-order a-priori bound
# (32.19 eps(T) at lambda = 0) on the relative difference between two
# native-precision evaluations of this fixture's objective at its solution
# with no true change; see #260.
warm_pgd_accepted(r::PS.OptimizationResults, options::ProximalOptions, ::Type{T}) where T =
  r.converged || (r.f_increased && !r.iteration_converged && r.iterations < options.maxiter &&
                  !r.call_limit_reached && isfinite(r.f_residual) && 0 <= r.f_residual <= 64 * eps(T))

# Diagnostic text for the warm-start check in "independent dense lasso
# correctness". It reads its arguments and calls no solver.
hexbits(v) = string(reinterpret(Unsigned, v), base = 16, pad = 2sizeof(v))
coefficient_lines(label, z) = string(label, ": ", join(string.(z), ", "), "\n",
  label, " (hex bits): ", join(hexbits.(z), " "), "\n")

function result_lines(label, r::PS.OptimizationResults)
  string(label, " result (ProximalGradientDescent): converged = ", r.converged,
    ", iterations = ", r.iterations, ", iteration_converged = ", r.iteration_converged, "\n",
    "  x_converged = ", r.x_converged, ", x_residual = ", r.x_residual, ", x_tol = ", r.x_tol, "\n",
    "  f_converged = ", r.f_converged, ", f_residual = ", r.f_residual, ", f_tol = ", r.f_tol, "\n",
    "  grad_converged = ", r.grad_converged, ", g_residual = ", r.g_residual, ", g_tol = ", r.g_tol, "\n",
    "  f_increased = ", r.f_increased, ", backtrack_steps = ", r.backtrack_steps,
    ", call_limit_reached = ", r.call_limit_reached, "\n",
    "  f_calls = ", r.f_calls, ", grad_calls = ", r.grad_calls, ", prox_calls = ", r.prox_calls, "\n",
    "  minimum = ", r.minimum, "\n")
end
function result_lines(label, r::CDResults)
  string(label, " result (CDSolver): converged = ", r.converged, ", passes = ", r.passes, "\n",
    "  maxchange = ", r.maxchange, ", tolerance = ", r.tolerance,
    ", kkt_checks = ", r.kkt_checks, " (compatibility field; this solver path leaves it at 0)\n",
    "  minimum = ", r.minimum, "\n")
end

# CPU, Julia and BLAS settings of the running process.
function environment_lines()
  function unavailable(f)
    try
      f()
    catch
      "unavailable"
    end
  end
  lines = String[
    "Julia version: $VERSION",
    "CPU model: " * unavailable(() -> string(Sys.cpu_info()[1].model)),
    "Sys.CPU_NAME: " * string(Sys.CPU_NAME),
    "CPU features (jl_get_cpu_features): " *
      unavailable(() -> ccall(:jl_get_cpu_features, Ref{String}, ()))]
  if isfile("/proc/cpuinfo")
    flags = unavailable() do
      row = open("/proc/cpuinfo") do io
        first(l for l in eachline(io) if startswith(l, "flags"))
      end
      join(filter(w -> any(p -> startswith(w, p), ("avx", "fma", "sse4", "f16c", "amx")),
                  split(last(split(row, ':'; limit = 2)))), " ")
    end
    push!(lines, "/proc/cpuinfo vector flags: " * flags)
  end
  opts = Base.JLOptions()
  push!(lines,
    "code_coverage: $(opts.code_coverage)",
    "check_bounds: $(opts.check_bounds)",
    "cpu_target: " * (opts.cpu_target == C_NULL ? "default" : unavailable(() -> unsafe_string(opts.cpu_target))),
    "Threads.nthreads(): $(Threads.nthreads())",
    "BLAS.get_num_threads(): " * unavailable(() -> string(BLAS.get_num_threads())),
    "BLAS.get_config(): " * unavailable(() -> string(BLAS.get_config())))
  join(lines, "\n") * "\n"
end

function warm_report(::Type{T}, λ, scale, initial, method, opts, X, y, r, first_x, warm, x,
                     oracle, optimum)::String where T
  solver = method isa CDSolver ?
    string("CDSolver (the loop constructs CDSolver(rng = Xoshiro(713))): maxpasses = ", method.maxpasses,
           ", tol = ", method.tol, ", random = ", method.random, ", relative = ", method.relative,
           ", anderson = ", method.anderson, ", momentum = ", method.momentum,
           ", rng type = ", typeof(method.rng)) :
    string("ProximalGradientDescent() with strict_options(", T, "): maxiter = ", opts.maxiter,
           ", ftol = ", opts.ftol, ", xtol = ", opts.xtol, ", gradtol = ", opts.gradtol,
           ", allow_f_increases = ", opts.allow_f_increases)
  obj_first, obj_warm = objective(X, y, first_x, λ, scale), objective(X, y, x, λ, scale)
  string("warm-start stopping check failed\n",
    "case: element type = ", T, ", lambda = ", λ, ", scaled loss (scale = ", scale, ")",
    ", initial point = ", initial, "\n",
    "solver: ", solver, "\n",
    result_lines("first", r), result_lines("warm", warm),
    coefficient_lines("first coefficients", first_x),
    coefficient_lines("warm coefficients", x),
    "objective(first) = ", obj_first, ", kkt(first) = ", kkt(X, y, first_x, λ, scale), "\n",
    "objective(warm) = ", obj_warm, ", kkt(warm) = ", kkt(X, y, x, λ, scale), "\n",
    "objective(warm) - objective(first) = ", obj_warm - obj_first, "\n",
    "objective(warm) - optimum = ", obj_warm - optimum, "\n",
    "max |warm - first| = ", maximum(abs, Float64.(x) - Float64.(first_x)), "\n",
    "max |first - oracle| = ", maximum(abs, Float64.(first_x) - oracle),
    ", max |warm - oracle| = ", maximum(abs, Float64.(x) - oracle), "\n",
    environment_lines())
end

@testset "independent dense lasso correctness" begin
  for T in (Float64, Float32), normalized in (false, true)
    X = T[1 0 0; 0 2 0; 0 0 3; 0 0 0; 0 0 0]
    y = T[3, -2, .5, 1, -1]
    scale = normalized ? one(T) / T(length(y)) : one(T)
    f = normalized ? scale * LeastSquaresLoss(y, X) : LeastSquaresLoss(y, X)
    for λ in (zero(T), T(.1), T(10))
      # Hand-derived threshold for orthogonal columns with unequal norms and n!=p.
      expected = [sign(dot(Float64.(X[:, j]), Float64.(y))) *
        max(abs(dot(Float64.(X[:, j]), Float64.(y))) - Float64(λ) / scale, 0.0) /
        sum(abs2, Float64.(X[:, j])) for j in 1:3]
      oracle, optimum = reference(X, y, λ, scale)
      @test oracle ≈ expected atol = 2e-14
      @test kkt(X, y, oracle, λ, scale) < 2e-14
      iszero(λ) && @test oracle ≈ Float64.(X) \ Float64.(y) atol = 2e-14
      for initial in (zeros(T, 3), T[.3, -.7, .2]),
          method in (CDSolver(rng = Xoshiro(713)), ProximalGradientDescent())
        x = copy(initial)
        r = method isa CDSolver ? solve!(x, f, NormL1(λ), method) :
            solve!(x, f, NormL1(λ), method, strict_options(T))
        @test r.minimizer === x
        @test eltype(x) === T && typeof(r.minimum) === T
        @test r.converged
        @test x ≈ expected atol = T === Float64 ? 2e-7 : 2e-3
        @test objective(X, y, x, λ, scale) ≈ optimum atol = T === Float64 ? 1e-12 : 2e-5
        @test kkt(X, y, x, λ, scale) < (T === Float64 ? 2e-7 : 2e-3)
        @test Float64(r.minimum) ≈ objective(X, y, x, λ, scale) atol = T === Float64 ? 1e-12 : 2e-5
        @test isnan(r.gap)
      end
    end
  end
  for T in (Float64, Float32)
    X, y = correlated(T)
    scale = one(T) / T(length(y))
    f = scale * LeastSquaresLoss(y, X)
    for λ in (zero(T), T(.1), T(10)), initial in (zeros(T, 3), T[.3, -.7, .2])
      oracle, optimum = reference(X, y, λ, scale)
      @test kkt(X, y, oracle, λ, scale) < 2e-14
      iszero(λ) && @test oracle ≈ Float64.(X) \ Float64.(y) atol = 2e-14
      solutions = Vector{T}[]
      for method in (CDSolver(rng = Xoshiro(713)), ProximalGradientDescent())
        x = copy(initial)
        r = method isa CDSolver ? solve!(x, f, NormL1(λ), method) :
            solve!(x, f, NormL1(λ), method, strict_options(T))
        push!(solutions, copy(x))
        @test r.converged
        @test x ≈ oracle atol = T === Float64 ? 2e-6 : 4e-3
        @test objective(X, y, x, λ, scale) ≈ optimum atol = T === Float64 ? 1e-11 : 1e-5
        @test kkt(X, y, x, λ, scale) < (T === Float64 ? 3e-7 : 2e-3)
        options = method isa CDSolver ? nothing : strict_options(T)
        warm = method isa CDSolver ? solve!(x, f, NormL1(λ), method) :
               solve!(x, f, NormL1(λ), method, options)
        @test warm.minimizer === x
        stopped_ok = method isa CDSolver ? warm.converged : warm_pgd_accepted(warm, options, T)
        @test stopped_ok
        @test kkt(X, y, x, λ, scale) < (T === Float64 ? 3e-7 : 2e-3)
        stopped_ok || println(warm_report(T, λ, scale, initial, method, options, X, y, r,
                                          solutions[end], warm, x, oracle, optimum))
        if T === Float64 && iszero(λ) && iszero(initial)
          # Builds the report for this case, so report construction is
          # exercised when the warm stopping check passes too.
          report = warm_report(T, λ, scale, initial, method, options, X, y, r,
                               solutions[end], warm, x, oracle, optimum)
          markers = ("Float64", method isa CDSolver ? "CDSolver" : "ProximalGradientDescent",
                     "converged", "first coefficients", "warm coefficients (hex bits)",
                     "objective(warm) - optimum", "Julia version", "BLAS.get_config()")
          @test all(m -> occursin(m, report), markers)
        end
        @test objective(X, y, x, λ, scale) ≈ optimum atol = T === Float64 ? 1e-11 : 1e-5
      end
      @test solutions[1] ≈ solutions[2] atol = T === Float64 ? 2e-6 : 4e-3
    end
  end
end

@testset "warm PGD acceptance predicate rejects non-converged material increases and exhausted budgets" begin
  for T in (Float64, Float32)
    X, y = correlated(T)
    f = (one(T) / T(length(y))) * LeastSquaresLoss(y, X)
    g = NormL1(zero(T))
    initial = T[.3, -.7, .2]
    options = strict_options(T)
    base = solve!(copy(initial), f, g, ProximalGradientDescent(), options)
    # Result of an objective-increase stop with a rounding-size residual; the
    # keywords overwrite fields of a copy.
    function variant(; kwargs...)
      r = deepcopy(base)
      r.converged, r.f_increased, r.iteration_converged = false, true, false
      r.iterations, r.call_limit_reached, r.f_residual = 1, false, Float64(1.31 * eps(T))
      for (name, value) in kwargs
        setfield!(r, name, value)
      end
      r
    end
    accepted(r) = warm_pgd_accepted(r, options, T)
    @test accepted(variant(converged = true))
    @test accepted(variant(converged = true, f_increased = false, call_limit_reached = true,
                           f_residual = NaN, iterations = options.maxiter))
    @test accepted(variant())
    @test accepted(variant(f_residual = 0.0))
    @test accepted(variant(f_residual = Float64(64 * eps(T))))
    @test !accepted(variant(f_residual = Float64(65 * eps(T))))
    @test !accepted(variant(f_residual = NaN))
    @test !accepted(variant(f_residual = Inf))
    @test !accepted(variant(f_residual = -1.0))
    @test !accepted(variant(iteration_converged = true))
    @test !accepted(variant(iteration_converged = true, iterations = options.maxiter))
    @test !accepted(variant(iterations = options.maxiter))
    @test !accepted(variant(call_limit_reached = true))
    @test !accepted(variant(f_increased = false))
    # Real solves that stop on the iteration limit and on the call limit.
    limited = strict_options(T; maxiter = 2)
    r = solve!(copy(initial), f, g, ProximalGradientDescent(), limited)
    @test !r.converged && r.iteration_converged
    @test !warm_pgd_accepted(r, limited, T)
    limited = strict_options(T; f_calls_limit = 1)
    r = solve!(copy(initial), f, g, ProximalGradientDescent(), limited)
    @test r.call_limit_reached && !r.converged
    @test !warm_pgd_accepted(r, limited, T)
  end
end

@testset "nonunique solutions require objective and KKT, not coefficient equality" begin
  for T in (Float64, Float32), λ in (zero(T), T(.1))
    # Duplicate columns: many coefficients represent the same fitted value.
    a, y = T[1, 2, -1, .5], T[2, 1, -1, .4]
    X = hcat(a, a, zeros(T, 4))
    scale = one(T) / T(4)
    _, optimum = reference(reshape(a, :, 1), y, λ, scale)
    solutions = Vector{T}[]
    for method in (CDSolver(order = :cyclic), ProximalGradientDescent())
      x = T[.3, .2, .9]
      f = scale * LeastSquaresLoss(y, X)
      r = method isa CDSolver ? solve!(x, f, NormL1(λ), method) :
          solve!(x, f, NormL1(λ), method, strict_options(T))
      @test r.converged
      @test objective(X, y, x, λ, scale) ≈ optimum atol = T === Float64 ? 1e-12 : 2e-6
      @test kkt(X, y, x, λ, scale) < (T === Float64 ? 1e-7 : 2e-4)
      push!(solutions, x)
    end
    @test X * solutions[1] ≈ X * solutions[2] atol = T === Float64 ? 1e-7 : 2e-4
    if iszero(λ)
      @test solutions[1][3] == zero(T)        # CD's nearest-zero flat minimizer
      @test solutions[2][3] == T(.9)         # PGD leaves the null coordinate alone
      @test solutions[1] != solutions[2]
    end
  end
end

# Observes calls at the actual private pass boundary, delegating arithmetic to
# the historical LS model. No second copy of the scheduling algorithm.
mutable struct PassRecorder{T, M} <: PS.CDModel{T}
  inner::M
  full::Vector{Bool}
  points::Vector{Vector{T}}
end
PS.response_scale(m::PassRecorder, x) = PS.response_scale(m.inner, x)
PS._cache(m::PassRecorder) = PS._cache(m.inner)
PS._initialize!(m::PassRecorder, x, fresh::Bool) = (PS._initialize!(m.inner, x, fresh); m)
function PS._pass!(x, m::PassRecorder, g, st::PS._CDState{T}, full::Bool, scaled::Bool) where T
  h = PS._pass!(x, m.inner, g, st, full, scaled)
  push!(m.full, full)
  push!(m.points, Vector(x))
  h
end

@testset "CD seeded finite trajectories and full/active passes" begin
  # Recorded on unchanged PS 9be1773 / PB e8a45a8, seed 713. The early points
  # distinguish the default momentum route from plain random and cyclic CD.
  snapshots = (
    (:cyclic, nothing, [1.0051750380517506 0 .17829395804380904;
                        .6861350209363949 0 .20603656822775301;
                        .685374949424506 0 .2061026614026999;
                        .6853731386525896 0 .2061028188611274]),
    (:random, nothing, [.9918602342664286 0 .6859903381642511;
                        .6722255310700813 0 .20724608908569325;
                        .6851514397981441 0 .21419466958996164;
                        .6853726061698586 0 .20612209702238343]),
    (:random, false, [.9918602342664286 0 .6859903381642511;
                      .6722255310700813 0 .20724608908569325;
                      .6853418118667541 0 .20724608908569325;
                      .685373059706651 0 .20610554292946087]))
  for T in (Float64, Float32), (order, momentum, expected) in snapshots
    X, y = correlated(T)
    f, g = (one(T) / T(length(y))) * LeastSquaresLoss(y, X), NormL1(T(.1))
    for passes in 1:4
      x = T[.3, -.7, .2]
      rng = Xoshiro(713)
      r = quiet(() -> solve!(x, f, g, CDSolver(; order, momentum, maxpasses = passes, rng)))
      if order === :random && momentum === nothing && passes == 3
        # Golden next word detects extra/missing Fisher–Yates draws, even if
        # two solves repeat the same erroneous new implementation.
        @test rand(rng, UInt64) == 0x9ff92f2552f8e694
      end
      @test x ≈ expected[passes, :] atol = T === Float64 ? 2e-13 : 2e-6
      @test r.passes == passes && !r.converged
      @test r.maxchange >= r.tolerance && r.kkt_checks == 0 && isnan(r.gap)
    end
    xs = SparseIterate(T[.3, -.7, .2])
    inner = PS.cdmodel(f, xs)
    PS.initialize!(inner, xs)
    recorder = PassRecorder{T, typeof(inner)}(inner, Bool[], Vector{T}[])
    solver = CDSolver(; order, momentum, maxpasses = 6, rng = Xoshiro(713))
    state = PS._CDState(T, xs, solver)
    PS._cd!(xs, recorder, g, state, solver)
    @test recorder.full[1] && !any(recorder.full[2:4])
    @test recorder.points[1:4] ≈ [T.(expected[i, :]) for i in 1:4] atol = T === Float64 ? 2e-13 : 2e-6
    # The cyclic fixture needs a full pass to admit its previously zero second
    # coordinate. Active-only stagnation must not be reported as convergence.
    if order === :cyclic
      @test recorder.full == [true, false, false, false, false, true]
      @test iszero(recorder.points[5][2]) && recorder.points[6][2] > 0
    end
  end
  X, y = correlated(Float64)
  f, g = LeastSquaresLoss(y, X), NormL1(.1)
  rng1, rng2 = Xoshiro(713), Xoshiro(713)
  solver = CDSolver(rng = rng1, maxpasses = 3)
  for _ in 1:2
    x1, x2 = zeros(3), zeros(3)
    a = quiet(() -> solve!(x1, f, g, solver))
    b = quiet(() -> solve!(x2, f, g, CDSolver(rng = rng2, maxpasses = 3)))
    @test x1 == x2 && a.passes == b.passes && a.maxchange == b.maxchange
    @test rand(copy(rng1), UInt64) == rand(copy(rng2), UInt64)
  end
end

@testset "CD residual, lazy curvature, flat columns and limits" begin
  for T in (Float64, Float32)
    X, y = correlated(T)
    scale = one(T) / T(length(y))
    f, g = scale * LeastSquaresLoss(y, X), NormL1(T(.1))
    xs = SparseIterate(T[.3, -.7, .2])
    m = PS.cdmodel(f, xs)
    PS.initialize!(m, xs)
    @test all(isnan, m.a)
    @test m.r ≈ y - X * Vector(xs) atol = 8eps(T)
    old = Vector(xs)
    h = PS.coordinate_step!(m, g, xs, 1)
    @test h == xs[1] - old[1]
    @test m.a[1] ≈ sum(abs2, X[:, 1]) rtol = 4eps(T)
    @test all(isnan, m.a[2:3])
    @test m.r ≈ y - X * Vector(xs) atol = 8eps(T)
    @test PS.coordinate_scale(m, xs, 1) ≈ sqrt(scale * sum(abs2, X[:, 1]))
    # Every new solve rebuilds state; modifying data before a new initialize
    # must not leave a previous curvature in the cache.
    PS.initialize!(m, xs)
    @test all(isnan, m.a)
    Xzero = hcat(X, zeros(T, size(X, 1)))
    for λ in (zero(T), T(.1))
      x = T[.3, -.7, .2, .9]
      r = solve!(x, scale * LeastSquaresLoss(y, Xzero), NormL1(λ), CDSolver(order = :cyclic))
      @test r.converged && iszero(x[4])
    end
    x = ones(T, 3)
    r = @test_logs (:warn, r"did not converge in maxpasses = 0") solve!(x, f, g, CDSolver(maxpasses = 0))
    @test x == ones(T, 3) && r.passes == 0 && !r.converged && isnan(r.maxchange)
    x = zeros(T, 1)
    r = @test_logs (:warn, r"did not converge") solve!(x, LeastSquaresLoss(zeros(T, 1), ones(T, 1, 1)),
                                                      NormL1(zero(T)), CDSolver(tol = 0, maxpasses = 3))
    @test x == zeros(T, 1) && !r.converged && r.maxchange == r.tolerance == 0
  end
  x = Float32[.5]
  @test_throws r"curvature underflows" solve!(x, LeastSquaresLoss(Float32[1e15], fill(1f-23, 1, 1)),
                                            NormL1(.1f0), CDSolver())
  @test x == Float32[.5]  # private owner fails before public dense scatter
end

@testset "PGD LS image, initial counts, native storage and scalar conversion" begin
  for T in (Float64, Float32), scale in (one(T), one(T) / T(7), 1 / 7)
    X, y = correlated(T)
    f, g = scale * LeastSquaresLoss(y, X), NormL1(T(.1))
    for x in (zeros(T, 3), T[.3, -.7, .2])
      state = PS.initial_state(ProximalGradientDescent(), ProximalOptions(), f, g, copy(x))
      @test (state.f_calls, state.grad_calls, state.prox_calls, state.backtrack_steps) == (1, 1, 0, 0)
      @test state.L === one(T) && state.max_residual == T(-Inf) && state.backtrack_simple
      @test eltype(state.grad_f_x) === T && eltype(state.z_x) === T
      @test state.z_x == X * x
      @test state.grad_f_x ≈ scale .* (X' * (X * x - y)) rtol = 8eps(T) atol = 8eps(T)
      @test state.f_x ≈ objective(X, y, x, zero(T), scale) rtol = 8eps(T) atol = 8eps(T)
    end
  end
end

@testset "PGD recorded trials, both backtracking modes and zero-step refresh" begin
  expected = [.6676984126984127 -.23380952380952388 .2798412698412698;
              .7386224489795918 0 .29387755102040813;
              .7027957344019325 .04078133310937543 .2751357744743988;
              .6756617594248804 .08388358109628198 .2533767171596679]
  for T in (Float64, Float32)
    X, y = correlated(T)
    f, g = (one(T) / T(7)) * LeastSquaresLoss(y, X), NormL1(T(.1))
    method = ProximalGradientDescent()
    state = PS.initial_state(method, ProximalOptions(), f, g, T[.3, -.7, .2])
    for i in 1:4
      PS.update_state!(f, g, state, method)
      @test state.x ≈ expected[i, :] atol = T === Float64 ? 2e-13 : 2e-6
      # First trial is rejected, its retry accepted; later early steps accept once.
      @test (state.backtrack_steps, state.f_calls, state.grad_calls, state.prox_calls) == (i + 1, 2i + 2, i + 1, i + 1)
      @test state.backtrack_simple
    end
    # Exercise gradient-based checking explicitly in each native precision.
    state.backtrack_simple = false
    PS.update_state!(f, g, state, method)
    @test !state.backtrack_simple
    @test state.grad_f_x ≈ (one(T) / T(7)) .* (X' * (X * state.x - y)) atol = 8eps(T)
  end
  X, y = correlated(Float64)
  f, g = (1 / 7) * LeastSquaresLoss(y, X), NormL1(.1)
  state = PS.initial_state(ProximalGradientDescent(), ProximalOptions(), f, g, zeros(3))
  modes = Bool[]
  for _ in 1:100
    PS.update_state!(f, g, state, ProximalGradientDescent())
    push!(modes, state.backtrack_simple)
  end
  @test any(modes) && !all(modes)
  first_gradient = findfirst(!, modes)
  @test all(.!modes[first_gradient:end])
  # LS differs from the equivalent old quadratic fixture only by a constant.
  state = PS.initial_state(ProximalGradientDescent(), ProximalOptions(), LeastSquaresLoss([1.], ones(1, 1)),
                           NormL1(0.), [1. + eps()])
  state.backtrack_simple = false
  state.L = 2.
  PS.update_state!(LeastSquaresLoss([1.], ones(1, 1)), NormL1(0.), state, ProximalGradientDescent())
  @test state.x == [1. + eps()] && state.grad_f_x == [eps()]
  @test (state.backtrack_steps, state.f_calls, state.grad_calls, state.prox_calls) == (1, 5, 3, 2)
end

@testset "PGD numerical failure restores the accepted point" begin
  @test_throws r"curvature estimate cannot increase finitely" PS.LineSearches.next_curvature(floatmax(Float64), .5)
  # Valid finite LS data/start and a valid but extreme line-search beta cause
  # a nonfinite trial, followed by unrepresentable curvature growth.
  x = [0.]
  f = LeastSquaresLoss([1.], fill(1e154, 1, 1))
  method = ProximalGradientDescent(ls = PS.LineSearches.BackTracking(β = nextfloat(0.)))
  @test_throws r"curvature estimate cannot increase finitely" solve!(x, f, NormL1(0.), method)
  @test x == [0.]
  # Fault injection into private state after an accepted ordinary LS step
  # checks that rollback targets that accepted point, not the original x0.
  X, y = correlated(Float64)
  f, g = (1 / 7) * LeastSquaresLoss(y, X), NormL1(.1)
  method = ProximalGradientDescent()
  state = PS.initial_state(method, ProximalOptions(), f, g, zeros(3))
  PS.update_state!(f, g, state, method)
  accepted = copy(state.x)
  @test accepted != zeros(3)
  state.L = 0.
  @test_throws r"curvature estimate cannot increase finitely" PS._solve_gradient!(state, f, g, method, ProximalOptions())
  @test state.x == accepted
end

@testset "PGD limits, stopping flags, trace and callback ownership" begin
  X, y = correlated(Float64)
  f, g = (1 / 7) * LeastSquaresLoss(y, X), NormL1(.1)
  for store in (false, true)
    called = Int[]
    callback = record -> begin
      state = store ? last(record) : record
      @test (record isa AbstractVector) == store
      push!(called, state.iteration)
      length(called) == 2
    end
    opts = ProximalOptions(; maxiter = 100, ftol = 1e-30, xtol = 1e-30, gradtol = 0.,
                          store_trace = store, extended_trace = true, print_every = 2, callback)
    x = zeros(3)
    r = solve!(x, f, g, ProximalGradientDescent(), opts)
    @test called == [2, 4] && r.iterations == 4 && !r.converged
    @test !r.iteration_converged && !r.call_limit_reached
    @test length(r.trace) == (store ? 4 : 0)
    @test r.minimizer === x
    if store
      first_point = copy(r.trace[1].metadata["x"])
      x .= 99.
      @test r.trace[1].metadata["x"] == first_point
      @test r.trace[1].metadata["x"] !== x
    end
  end
  for (keyword, field) in ((:f_calls_limit, :f_calls), (:grad_calls_limit, :grad_calls), (:prox_calls_limit, :prox_calls))
    opts = ProximalOptions(; maxiter = 100, ftol = 1e-30, xtol = 1e-30, gradtol = 0., keyword => 5,
                          callback = _ -> false, store_trace = true)
    r = solve!(zeros(3), f, g, ProximalGradientDescent(), opts)
    @test r.call_limit_reached && !r.converged && getfield(r, field) >= 5
    @test !r.iteration_converged && !r.f_increased
  end
  r = solve!(zeros(3), f, g, ProximalGradientDescent(),
             ProximalOptions(maxiter = 2, ftol = 1e-30, xtol = 1e-30, gradtol = 0.))
  @test r.iterations == 2 && r.iteration_converged && !r.converged
  @test (r.f_calls, r.grad_calls, r.prox_calls, r.backtrack_steps) == (6, 3, 3, 3)
  # Characterize historical default objective stopping separately from KKT.
  for T in (Float64, Float32)
    A, b = correlated(T)
    scale = one(T) / T(7)
    r = solve!(zeros(T, 3), scale * LeastSquaresLoss(b, A), NormL1(T(.1)), ProximalGradientDescent())
    @test r.converged && r.f_converged && !r.x_converged && !r.grad_converged && !r.f_increased
    @test r.iterations == 14
    @test (r.f_calls, r.grad_calls, r.prox_calls, r.backtrack_steps) == (30, 15, 15, 15)
    @test r.g_tol < kkt(A, b, r.minimizer, T(.1), scale) < 2e-3
    @test isnan(r.gap)
  end
  # Printing samples rows without changing the retained trace or numerical work.
  function run_trace(show)
    solve!(zeros(3), f, g, ProximalGradientDescent(), ProximalOptions(;
      maxiter = 4, ftol = 1e-30, xtol = 1e-30, gradtol = 0.,
      store_trace = true, extended_trace = true, show_trace = show, print_every = 2))
  end
  quiet_result = run_trace(false)
  printed_result, output = mktemp() do _, io
    result = redirect_stdout(() -> run_trace(true), io)
    flush(io); seekstart(io)
    result, read(io, String)
  end
  @test [parse(Int, m[1]) for m in eachmatch(r"(?m)^\s*(\d+)\s", output)] == [2, 4]
  @test occursin("Function value", output)
  @test quiet_result.minimizer == printed_result.minimizer
  @test (quiet_result.minimum, quiet_result.iterations, quiet_result.f_calls,
         quiet_result.grad_calls, quiet_result.prox_calls, quiet_result.backtrack_steps) ==
        (printed_result.minimum, printed_result.iterations, printed_result.f_calls,
         printed_result.grad_calls, printed_result.prox_calls, printed_result.backtrack_steps)
  @test length(quiet_result.trace) == length(printed_result.trace) == 4
  @test [s.metadata["x"] for s in quiet_result.trace] == [s.metadata["x"] for s in printed_result.trace]
end

end
