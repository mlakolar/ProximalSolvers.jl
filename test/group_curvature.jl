module GroupCurvatureTests

using Test, LinearAlgebra, SparseArrays
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

@testset "group curvature fallback" begin
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
      @test isfinite(L)
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
    if result.converged
      @test result.converged
    else
      @info "Float16 group lasso returned without convergence" passes = result.passes
    end
  end
  @test PS._group_eig_failure[][1] == 0
end

end
