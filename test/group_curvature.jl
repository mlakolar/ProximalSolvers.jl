module GroupCurvatureTests

using Test, LinearAlgebra, SparseArrays
using Random
using ProximalBase
using ProximalSolvers
const PS = ProximalSolvers

function _curvature_case(::Type{T}, q, kind) where {T}
  s = T(0.5)
  if kind in (:dense_quadratic, :sparse_quadratic)
    C = Matrix(Diagonal(T.(1:q))) + fill(T(0.125), q, q)
    A = kind == :sparse_quadratic ? sparse(C) : C
    return s * QuadraticFunction(A, zeros(T, q)), C, false
  end
  X = vcat(Matrix(Diagonal(T.(1:q))), reshape(T.(1:q), 1, q) ./ T(8), ones(T, 1, q))
  y = T.(1:size(X, 1)) ./ T(8)
  weighted = kind in (:weighted_least_squares, :sparse_weighted_least_squares)
  sparse_design = kind in (:sparse_least_squares, :sparse_weighted_least_squares)
  design = sparse_design ? sparse(X) : X
  if weighted
    w = T[isodd(i) ? 1 : 4 for i in axes(X, 1)]
    means = [sum(w .* X[:, j]) / sum(w) for j in axes(X, 2)]
    centered = X .- transpose(means)
    C = transpose(centered) * (w .* centered)
    f = GLMLoss(ProximalBase.Squared(), y, design; weights = w)
  else
    C = transpose(X) * X
    f = LeastSquaresLoss(y, design)
  end
  s * f, C, weighted
end

function _curvature(f, ::Type{T}, q; intercept = false, failures = 0) where {T}
  x = AtomIterate(T, q, [1:q])
  m = intercept ? cdmodel(f, x; intercept) : cdmodel(f, x)
  PS.initialize!(m, x)
  try
    PS._group_eig_failure[] = (failures, 1)
    L = PS._groupcurvature!(m, x, 1)
    @test PS._group_eig_failure[][1] == 0
    @test PS._groupcurvature!(m, x, 1) === L
    return L, m
  finally
    PS._group_eig_failure[] = (0, 0)
  end
end

const _canary_pad = 8
_canary(::Type{T}) where {T} = T <: Integer ? typemin(T) + 7 : T(-7250.5)

function _guard_array(a::Vector{T}) where {T}
  backing = fill(_canary(T), length(a) + 2 * _canary_pad)
  wrapped = GC.@preserve backing begin
    b = unsafe_wrap(Array, pointer(backing, _canary_pad + 1), length(a); own = false)
    copyto!(b, a)
  end
  wrapped, backing
end

# root the backings while using the workspace; reserve before wrapping its arrays
function _guard!(ws)
  ws.iwork, ibacking = _guard_array(ws.iwork)
  ws.w, wbacking = _guard_array(ws.w)
  ibacking, wbacking
end

function _check_canaries(backings)
  for b in backings
    @test all(==(_canary(eltype(b))), view(b, 1:_canary_pad))
    @test all(==(_canary(eltype(b))), view(b, length(b)-_canary_pad+1:length(b)))
  end
end

function _near_identity_case(::Type{T}, k, kind) where {T}
  q = 5
  E = randn(Xoshiro(k), q, q)
  s = T(0.5)
  if kind in (:dense_quadratic, :sparse_quadratic)
    scale = T === Float64 ? 1e-15 : 3e-7
    C = Matrix{T}(I, q, q) + T.(scale * (E + E') / 2)
    A = kind == :sparse_quadratic ? sparse(C) : C
    return s * QuadraticFunction(A, zeros(T, q)), C, false
  elseif kind == :least_squares
    scale = T === Float64 ? 0.5e-15 : 1.5e-7
    X = vcat(Matrix{T}(I, q, q) + T.(scale * E), zeros(T, 45, q))
    return s * LeastSquaresLoss(zeros(T, 50), X), X' * X, false
  end
  w = T[isodd(i) ? 1 : 4 for i in 1:50]
  Q = Matrix(qr(hcat(sqrt.(w), T.(randn(Xoshiro(k), 50, q)))).Q)[:, 2:q+1]
  X = Q ./ sqrt.(w)
  means = [sum(w .* X[:, j]) / sum(w) for j in 1:q]
  B = (X .- transpose(means)) .* sqrt.(w)
  f = GLMLoss(ProximalBase.Squared(), zeros(T, 50), sparse(X); weights = w)
  s * f, B' * B, true
end

function _check_stray_writes(::Type{T}, kind) where {T}
  failures = spare_writes = 0
  models = []
  for k in 1:2000
    f, C, centered = _near_identity_case(T, k, kind)
    x = AtomIterate(T, 5, [1:5])
    m = centered ? cdmodel(f, x; intercept = true) : cdmodel(f, x)
    PS.initialize!(m, x)
    PS._reserve!(m.eig, 5, kind in (:dense_quadratic, :sparse_quadratic) ? 0 : 50)
    backings = _guard!(m.eig)
    GC.@preserve backings begin
      m.eig.iwork[1] = -12345
      L = PS._groupcurvature!(m, x, 1)
      failures += m.eig.info[] > 0
      spare_writes += m.eig.iwork[1] != -12345
      _check_canaries(backings)
      @test L ≈ T(0.5) * maximum(eigvals(Symmetric(C))) rtol = 10 * eps(T)
      m.eig.info[] > 0 && push!(models, (m, backings))
    end
  end
  GC.@preserve models GC.gc(true)
  println("group curvature, Julia $VERSION, $T, $kind: info > 0 = $failures, spare writes = $spare_writes")
end

function _eigmax_allocations(ws, C)
  n = size(C, 1)
  @allocated for _ in 1:10
    copyto!(ws.C, 1, C, 1, length(C))
    PS._eigmax!(ws, n)
  end
end

@testset "group curvature fallback" begin
  @testset "workspace query keeps the spare slot" begin
    for T in (Float32, Float64)
      ws = PS._reserve!(PS._GroupEig{T}(), 5, 0)
      backings = _guard!(ws)
      GC.@preserve backings begin
        ws.iwork[1] = -12345
        ws.iwork[2] = 0
        @test PS._syevr_max!(ws, 5, -1, -1) == 0
        @test ws.iwork[1] == -12345
        @test ws.iwork[2] > 0
        @test length(ws.iwork) == 1 + ws.iwork[2]
        _check_canaries(backings)
      end
    end
  end

  @testset "stray writes stay inside" begin
    for T in (Float32, Float64),
        kind in (:dense_quadratic, :sparse_quadratic, :least_squares, :sparse_weighted_least_squares)
      @testset "$T $kind" begin
        _check_stray_writes(T, kind)
      end
    end
  end

  @testset "non-finite groups keep the rescale inside" begin
    for T in (Float32, Float64)
      ws = PS._reserve!(PS._GroupEig{T}(), 2, 0)
      backings = _guard!(ws)
      GC.@preserve backings begin
        copyto!(ws.C, T[Inf, 0, 0, 1])
        L = PS._eigmax!(ws, 2)
        # some LAPACK builds report success with NaN for a non-finite matrix
        if ws.info[] > 0
          @test L === nothing
        else
          @test L isa T && isnan(L)
        end
        _check_canaries(backings)
      end
      X = T[floatmax(T) / 4 0; 0 1]
      x = AtomIterate(T, 2, [1:2])
      m = cdmodel(LeastSquaresLoss(zeros(T, 2), X), x)
      PS.initialize!(m, x)
      PS._reserve!(m.eig, 2, 2)
      backings = _guard!(m.eig)
      GC.@preserve backings begin
        try
          if ws.info[] == 0
            @test isnan(PS._groupcurvature!(m, x, 1))
            PS._group_eig_failure[] = (1, 1)
          end
          @test_throws ArgumentError PS._groupcurvature!(m, x, 1)
          @test PS._group_eig_failure[][1] == 0
        finally
          PS._group_eig_failure[] = (0, 0)
        end
        _check_canaries(backings)
      end
    end
  end

  @testset "workspace growth and small groups" begin
    for T in (Float32, Float64)
      ws = PS._GroupEig{T}()
      for n in (2, 5, 8, 3, 1)
        PS._reserve!(ws, n, 0)
        backings = _guard!(ws)
        GC.@preserve backings begin
          C = Matrix(Diagonal(T.(1:n))) + fill(T(0.125), n, n)
          copyto!(ws.C, 1, C, 1, length(C))
          @test PS._eigmax!(ws, n) ≈ eigmax(Symmetric(C)) rtol = 10 * eps(T)
          _check_canaries(backings)
          # the next reservation must own the arrays it may resize
          ws.iwork = copy(ws.iwork)
          ws.w = copy(ws.w)
        end
      end
    end
  end

  @testset "Float16 selected eigenvalues agree bitwise" begin
    for q in 2:5, k in 1:20
      E = randn(Xoshiro(k), q, q)
      Cs = [Float16.(E' * E + I)]
      for scale in (6e-8, 1.2e-7, 2.4e-7)
        push!(Cs, Float16.(Matrix{Float64}(I, q, q) + scale * (E + E') / 2))
      end
      for C in Cs
        expected = try
          eigmax(Symmetric(C))
        catch err
          err isa LinearAlgebra.LAPACKException || rethrow()
          PS._eigmax_all(C)
        end
        @test PS._eigmax_generic(C) === expected
      end
    end
  end

  @testset "reserved eigenvalue calls allocate nothing" begin
    for T in (Float32, Float64)
      C = Matrix(Diagonal(T.(1:5))) + fill(T(0.125), 5, 5)
      ws = PS._reserve!(PS._GroupEig{T}(), 5, 0)
      _eigmax_allocations(ws, C)
      @test _eigmax_allocations(ws, C) == 0
    end
  end

  @testset "BLAS retries rebuild the destroyed matrix" begin
    for T in (Float32, Float64), q in 2:5,
        kind in (:dense_quadratic, :sparse_quadratic, :least_squares, :weighted_least_squares)
      case_name = replace(string(kind), "_" => " ")
      @testset "$T with $q coordinates and $case_name" begin
        f, C, centered = _curvature_case(T, q, kind)
        expected = T(0.5) * maximum(eigvals(Symmetric(C)))
        selected, _ = _curvature(f, T, q; intercept = centered)
        fallback, m = _curvature(f, T, q; intercept = centered, failures = 1)
        @test fallback ≈ expected rtol = 10 * eps(T)
        @test fallback ≈ selected rtol = 10 * eps(T)
        @test all(isnan, view(m.eig.C, 1:q^2))
      end
    end
  end

  @testset "Float16 curvatures are dense and agree with the cache" begin
    T = Float16
    for q in 2:5,
        kind in (:dense_quadratic, :sparse_quadratic, :least_squares, :sparse_least_squares,
                 :weighted_least_squares, :sparse_weighted_least_squares)
      case_name = replace(string(kind), "_" => " ")
      @testset "$q coordinates and $case_name" begin
        f, C, centered = _curvature_case(T, q, kind)
        expected = T(max(T(0.5) * maximum(eigvals(Symmetric(Float32.(C)))), 0))
        for failures in (0, 1)
          L, _ = _curvature(f, T, q; intercept = centered, failures)
          @test L isa T
          @test abs(L - expected) <= eps(expected)
        end
      end
    end
  end

  @testset "Float16 scaling precedes conversion" begin
    f = Float16(0.5) * QuadraticFunction(fill(Float16(40000), 2, 2), zeros(Float16, 2))
    for failures in (0, 1)
      L, _ = _curvature(f, Float16, 2; failures)
      @test L === Float16(4.0e4)
    end
  end

  @testset "other errors propagate" begin
    for (T, info) in ((Float16, -1), (Float16, 0), (Float32, -1), (Float64, -1)),
        kind in (:dense_quadratic, :least_squares)
      f, _, centered = _curvature_case(T, 2, kind)
      x = AtomIterate(T, 2, [1:2])
      m = centered ? cdmodel(f, x; intercept = true) : cdmodel(f, x)
      PS.initialize!(m, x)
      try
        PS._group_eig_failure[] = (1, info)
        err = try
          PS._groupcurvature!(m, x, 1)
        catch err
          err
        end
        @test err isa LinearAlgebra.LAPACKException
        @test err.info == info
        @test PS._group_eig_failure[][1] == 0
      finally
        PS._group_eig_failure[] = (0, 0)
      end
    end
    for kind in (:dense_quadratic, :least_squares)
      f, _, _ = _curvature_case(BigFloat, 2, kind)
      x = AtomIterate(BigFloat, 2, [1:2])
      m = cdmodel(f, x)
      PS.initialize!(m, x)
      @test_throws MethodError PS._groupcurvature!(m, x, 1)
    end
  end

  @testset "group lasso agrees after every selected call fails" begin
    groups = [1:2, 3:5]
    A = Matrix(Diagonal([1.0, 2.0, 3.0, 4.0, 5.0])) + fill(0.125, 5, 5)
    f = 0.5 * QuadraticFunction(A, [-2.0, 1.0, -1.0, 2.0, -1.0])
    g = GroupNormL2(0.05, groups)
    solver = CDSolver(; order = :cyclic, tol = 1e-12)
    start = [0.2, -0.1, 0.3, -0.2, 0.1]
    x = AtomIterate(copy(start), groups)
    selected = solve!(x, f, g, solver)
    @test selected.converged
    try
      PS._group_eig_failure[] = (length(groups), 1)
      x = AtomIterate(copy(start), groups)
      fallback = solve!(x, f, g, solver)
      @test PS._group_eig_failure[][1] == 0
      @test fallback.converged
      @test norm(Vector(fallback.minimizer) - Vector(selected.minimizer), Inf) <=
            1e-8 * max(1, norm(Vector(selected.minimizer), Inf))
    finally
      PS._group_eig_failure[] = (0, 0)
    end
  end

  @testset "Float16 group lasso returns" begin
    groups = [1:2, 3:4]
    X = Matrix(Diagonal(Float16[1, 2, 3, 4]))
    y = Float16[1, -1, 1, -1]
    f = Float16(0.5) * LeastSquaresLoss(y, X)
    g = GroupNormL2(Float16(0.125), groups)
    result = solve!(AtomIterate(Float16, 4, groups), f, g,
                    CDSolver(; order = :cyclic, tol = 1e-3, maxpasses = 100))
    @test result.minimizer isa AtomIterate{Float16}
    @test all(isfinite, result.minimizer)
    @test result.converged
  end
  @test PS._group_eig_failure[][1] == 0
end

end
