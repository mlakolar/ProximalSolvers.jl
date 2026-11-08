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
        # the result of a non-finite input depends on LAPACK
        if ws.info[] > 0
          @test L === nothing
        else
          @test L isa T
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
        L = try
          PS._groupcurvature!(m, x, 1)
        catch err
          err
        end
        @test L isa T || L isa ArgumentError
        _check_canaries(backings)
        try
          m.L[1] = T(NaN)
          PS._group_eig_failure[] = (1, 1)
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
    Cs = Matrix{Float16}[]
    for q in 2:5, k in 1:20
      E = randn(Xoshiro(k), q, q)
      push!(Cs, Float16.(E' * E + I))
      for scale in (6e-8, 1.2e-7, 2.4e-7)
        push!(Cs, Float16.(Matrix{Float64}(I, q, q) + scale * (E + E') / 2))
      end
    end
    q = 5
    E = randn(Xoshiro(538), q, q)
    push!(Cs, Float16.(Matrix{Float64}(I, q, q) + 2.4e-7 * (E + E') / 2))
    for C in Cs
      n = size(C, 1)
      ws = PS._reserve!(PS._GroupEig{Float32}(), n, 0)
      for j in 1:n, i in 1:j
        ws.C[(j - 1) * n + i] = Float32(C[i, j])
      end
      selected = PS._eigmax!(ws, n)
      # call Base only when the protected selected call succeeds
      expected = selected === nothing ? PS._eigmax_all(C) : eigmax(Symmetric(C))
      @test PS._eigmax_generic(C) === expected
    end
  end

  @testset "Float16 non-finite Gram matrices are rejected" begin
    for X in (Float16[300 0; 0 1], sparse(Float16[300 0; 0 1]), Float16[300 300; 0 1])
      x = AtomIterate(Float16, 2, [1:2])
      m = cdmodel(LeastSquaresLoss(zeros(Float16, 2), X), x)
      PS.initialize!(m, x)
      @test_throws ArgumentError("matrix contains Infs or NaNs") PS._groupcurvature!(m, x, 1)
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

# the groups of 1:12 in layouts that are equal as group arrays but separately allocated (range-backed,
# vector-backed, Int32 indices), and layouts that are not equal to them
_layouts() = (
  ranges = [1:3, 4:6, 7:9, 10:12],
  vectors = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]],
  int32 = [Int32.(1:3), Int32.(4:6), Int32.(7:9), Int32.(10:12)],
  strided = [1:4:12, 2:4:12, 3:4:12, 4:4:12],
)
_other_layouts() = (
  group_order = [4:6, 1:3, 7:9, 10:12],
  within_group = [[2, 1, 3], 4:6, 7:9, 10:12],
  fewer_groups = [1:6, 7:9, 10:12],
  more_groups = [1:3, 4:6, 7:9, 10:11, 12:12],
)

accepts(f, args...) = (f(args...); true)

@testset "layout checks of the solvers and _maxgroup, _zero_like" begin
  L, O = _layouts(), _other_layouts()
  for name in (:ranges, :vectors, :int32, :strided)
    x = AtomIterate(Float64, 12, L[name])
    # a penalty with the same groups, built apart from the iterate, goes with it; one with other groups does not
    for other in (name == :strided ? (:strided,) : (:ranges, :vectors, :int32))
      g = GroupNormL2(0.1, L[other])
      @test PS._check_iterate(g, x) === nothing
      @test accepts(PS._check_groups, x, g)
      @test PS._check_iterate(GroupNormLinf(0.1, L[other]), x) === nothing
    end
    for bad in keys(O)
      @test_throws ArgumentError PS._check_iterate(GroupNormL2(0.1, O[bad]), x)
      @test_throws ArgumentError PS._check_groups(x, GroupNormL2(0.1, O[bad]))
      @test_throws ArgumentError PS._check_iterate(GroupNormLinf(0.1, O[bad]), x)
    end
    @test_throws ArgumentError PS._check_iterate(GroupNormL2(0.1, L[name]), SparseIterate(Float64, 12))
  end
  err = try; PS._check_iterate(GroupNormL2(0.1, [4:6, 1:3, 7:9, 10:12]), AtomIterate(Float64, 12, L.ranges)); catch e; e; end
  @test err isa ArgumentError && err.msg == "The groups of x must be the groups of g, as in AtomIterate(p, g.groups)."
  err = try; PS._check_groups(AtomIterate(Float64, 12, L.ranges), GroupNormL2(0.1, [4:6, 1:3, 7:9, 10:12])); catch e; e; end
  @test err isa ArgumentError && err.msg == "The groups of x must be the groups of g, as in AtomIterate(x, g.groups)."

  # the size of the largest group: contiguous, strided, vector-backed, uneven, one group, and none
  @test PS._maxgroup(AtomIterate(Float64, 12, L.ranges)) == 3
  @test PS._maxgroup(AtomIterate(Float64, 12, L.strided)) == 3
  @test PS._maxgroup(AtomIterate(Float64, 12, L.vectors)) == 3
  @test PS._maxgroup(AtomIterate(Float64, 12, L.int32)) == 3
  @test PS._maxgroup(AtomIterate(Float64, 12, [[5, 1], [2, 3, 4, 6, 7, 8, 9, 10], [11, 12]])) == 8
  @test PS._maxgroup(AtomIterate(Float64, 12, [1:12])) == 12
  @test PS._maxgroup(AtomIterate(Float32, 12, [[k] for k in 12:-1:1])) == 1
  @test PS._maxgroup(AtomIterate(Float64, 0, UnitRange{Int}[])) == 0
  x = AtomIterate(Float64, 12, L.vectors)
  PS._maxgroup(x)
  @test (@allocated PS._maxgroup(x)) == 0

  # a zero iterate with the type, size and layout of x, no active group, and zero values
  for T in (Float64, Float32), name in (:ranges, :vectors, :int32, :strided)
    x = AtomIterate(T, 12, L[name])
    x[L[name][2]] .= T[1, -2, 3]
    z = PS._zero_like(x)
    @test typeof(z) === typeof(x) && size(z) == size(x) && z !== x
    @test ProximalBase.samegroups(x, z) && ncoordinates(z) == ncoordinates(x)
    @test all(k -> atomindices(z, k) == atomindices(x, k), 1:ncoordinates(x))
    @test nactive(z) == 0 && isempty(activecoordinates(z))
    @test all(iszero, Vector(z))
    @test nactive(x) == 1 && x[L[name][2]] == T[1, -2, 3]      # x is as it was
    z[L[name][4]] .= T[1, 1, 1]
    @test nactive(z) == 1 && nactive(x) == 1 && all(iszero, x[L[name][4]])
  end
  @test PS._zero_like(SparseIterate(Float32, 5)) isa SparseIterate{Float32}
end

end
