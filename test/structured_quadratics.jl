module StructuredQuadraticTests

using Test, LinearAlgebra, Random, SparseArrays
using ProximalBase, ProximalSolvers
const PS = ProximalSolvers

function matrices(::Type{T}, p = 12) where {T}
  d = collect(range(T(1.5), T(2.5); length = p))
  A = spdiagm(-1 => fill(T(-0.2), p - 1), 0 => d, 1 => fill(T(-0.2), p - 1))
  (A, Diagonal(copy(d)), Symmetric(tril(A), :L), Symmetric(triu(A), :U))
end

@testset "structured Hessian storage and cached derivatives" begin
  for T in (Float32, Float64), A in matrices(T)
    p = size(A, 1)
    b = T.(sin.(1:p))
    f = T(0.3) * QuadraticFunction(A, b, T(0.7))
    x = SparseIterate(T, p)
    x[1], x[4] = T(0.2), T(-0.3)
    m = cdmodel(f, x)
    if A isa Symmetric
      @test m.A isa SparseMatrixCSC
      @test m.A !== parent(A)
    else
      @test m.A === A
    end
    @test Matrix(m.A) == Matrix(A)
    atol = T === Float32 ? 2e-6 : 1e-13
    PS.initialize!(m, x)
    @test m.u ≈ A * Vector(x) atol = atol
    @test PS.loss_value(m, x) ≈ f(Vector(x)) atol = atol
    grad = zeros(T, p)
    PS.gradient!(grad, m, x)
    @test grad ≈ T(0.3) .* (A * Vector(x) .+ b) atol = atol
    for k in (2, 4, 1, p)
      PS.coordinate_step!(m, NormL1(T(0.05)), x, k)
      @test m.u ≈ m.A * Vector(x) atol = atol
      G, a = PS.coordinate_derivatives(m, x, k)
      @test G ≈ T(0.3) * (m.u[k] + b[k]) atol = atol
      @test a == T(0.3) * m.A[k, k]
    end
  end
  # Integer structures are promoted without materializing their implicit zeros.
  for A in (spdiagm(0 => [2, 3]), Diagonal([2, 3]))
    m = cdmodel(QuadraticFunction(A), SparseIterate(2))
    @test m.A isa (A isa Diagonal ? Diagonal{Float64} : SparseMatrixCSC{Float64})
    @test Matrix(m.A) == Float64.(Matrix(A))
  end
  Ai = SparseMatrixCSC{Float64, Int32}(matrices(Float64)[1])
  @test cdmodel(QuadraticFunction(Ai), SparseIterate(12)).A === Ai
end

@testset "structured coordinate and group solves match dense" begin
  p = 12
  groups = [1:3, 4:6, 7:9, 10:12]
  for T in (Float32, Float64), A in matrices(T)
    b = T.(sin.(1:p))
    f = T(0.6) * QuadraticFunction(A, b)
    fd = T(0.6) * QuadraticFunction(Matrix(A), copy(b))
    tol, atol = T === Float32 ? (1e-6, 3e-5) : (1e-12, 1e-9)
    s = CDSolver(; order = :cyclic, tol, maxpasses = 5000)
    penalties = (NormL1(T(0.1)), ElasticNet(T(0.1), T(0.2)), ZeroFunction(),
                 GroupNormL2(T(0.1), groups), GroupNormLinf(T(0.1), groups))
    for g in penalties
      x = g isa ProximalBase.AbstractGroupNorm ? AtomIterate(T, p, groups) : SparseIterate(T, p)
      xd = copy(x)
      r, rd = solve!(x, f, g, s), solve!(xd, fd, g, s)
      @test r.converged && rd.converged
      @test Vector(x) ≈ Vector(xd) atol = atol
      @test r.minimum ≈ rd.minimum atol = atol
    end
    path = solve_path(f, NormL1(T(1)), T[0.5, 0.2, 0.05], s)
    densepath = solve_path(fd, NormL1(T(1)), T[0.5, 0.2, 0.05], s)
    @test all(path.converged)
    @test all(isapprox(a, b; atol) for (a, b) in zip(path.solutions, densepath.solutions))
  end
end

@testset "native matrix changes are seen after initialization" begin
  for T in (Float32, Float64), A in matrices(T)[1:2]
    p = size(A, 1)
    groups = [1:3, 4:6, 7:9, 10:12]
    b = fill(T(-0.5), p)
    x = AtomIterate(fill(T(0.1), p), groups)
    m = cdmodel(QuadraticFunction(A, b), x)
    PS.initialize!(m, x)
    L = PS._groupcurvature!(m, x, 1)
    A[1, 1] += T(5)
    if A isa SparseMatrixCSC
      A[1, p] = A[p, 1] = T(0.01)  # a structural CSC insertion, not just values
    end
    PS.initialize!(m, x)
    @test m.u ≈ A * Vector(x)
    @test PS._groupcurvature!(m, x, 1) > L
    @test PS._groupcurvature!(m, x, 1) ≈ eigmax(Symmetric(Matrix(A[1:3, 1:3])))
    for g in (GroupNormL2(T(0.1), groups), GroupNormLinf(T(0.1), groups)), k in eachindex(groups)
      PS._groupstep!(m, g, x, k, false)
      @test m.u ≈ A * Vector(x) atol = (T === Float32 ? 3e-6 : 1e-13)
    end
  end
end

@testset "structured refits densify only the support" begin
  for T in (Float32, Float64), A in matrices(T)
    p = size(A, 1)
    b = T.(cos.(1:p))
    f = T(0.4) * QuadraticFunction(A, b)
    S = [8, 1, 4]
    reference = -(Matrix(A[S, S]) \ b[S])
    for cache in (nothing, RefitCache(T))
      x = SparseIterate(T, p)
      refit!(x, f; support = S, cache)
      @test Vector(x)[S] ≈ reference atol = (T === Float32 ? 3e-6 : 1e-12)
      @test all(iszero, Vector(x)[setdiff(1:p, S)])
    end
    H = PS._hessian(cdmodel(f, SparseIterate(T, p)), SparseIterate(T, p), S)
    @test H isa Matrix{T}
    @test H == T(0.4) .* Matrix(A[S, S])
  end
  # A zero pivot exercises RefitCache's fallback to rank-deficient pivoted QR.
  for A in (Diagonal([2., 0., 3.]), spdiagm(0 => [2., 0., 3.]))
    f = QuadraticFunction(A, [-1., 0., 1.])
    x = SparseIterate(3)
    refit!(x, f; support = [3, 1, 2], cache = RefitCache())
    @test A * Vector(x) + f.b ≈ zeros(3) atol = 1e-12
  end
end

function passes_bytes(f, x, g, s)
  m = cdmodel(f, x)
  st = PS._CDState(eltype(x), x, s)
  PS.initialize!(m, x)
  PS._cd!(x, m, g, st, s)
  fill!(x, zero(eltype(x)))
  PS.initialize!(m, x)
  @allocated PS._cd!(x, m, g, st, s)
end

model_bytes(f, x) = @allocated cdmodel(f, x)

@testset "structured models avoid dense storage and warmed pass allocations" begin
  groups = [1:3, 4:6, 7:9, 10:12]
  for T in (Float32, Float64), A in matrices(T)[1:2]
    f = QuadraticFunction(A, fill(T(-0.4), 12))
    for s in (CDSolver(; order = :cyclic), CDSolver(; order = :random, rng = Xoshiro(1)),
              CDSolver(; order = :random, momentum = true, rng = Xoshiro(2)))
      @test passes_bytes(f, SparseIterate(T, 12), NormL1(T(0.1)), s) == 0
      for g in (GroupNormL2(T(0.1), groups), GroupNormLinf(T(0.1), groups))
        @test passes_bytes(f, AtomIterate(T, 12, groups), g, s) == 0
      end
    end
  end
  for A in (spdiagm(-1 => fill(-0.1, 2999), 0 => ones(3000), 1 => fill(-0.1, 2999)),
            Diagonal(ones(3000)))
    f, x = QuadraticFunction(A), SparseIterate(3000)
    model_bytes(f, x)
    @test model_bytes(f, x) < 1_000_000
  end
  for A in (spdiagm(0 => [1., Inf]), Diagonal([1., NaN]))
    @test_throws ArgumentError cdmodel(QuadraticFunction(A), SparseIterate(2))
  end
end

end
