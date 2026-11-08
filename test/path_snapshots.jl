module PathSnapshotTests

using Test, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

# coordinate k of an iterate: the lower-triangle coordinate k of a SymmetricSparseIterate,
# through coordinates(x) on both owner implementations, and the linear entry k of the
# other iterates
coord(x) = x
coord(x::SymmetricSparseIterate) = coordinates(x)

@testset "compact independent path snapshots" begin
  for T in (Float32, Float64)
    vector = SparseIterate(T, 12)
    matrix = SparseIterate(T, 3, 4)
    symmetric = SymmetricSparseIterate(T, 4)
    groups = [[3, 1], [6, 2, 5], [4], 7:12]
    atoms = AtomIterate(T, 12, groups)
    # Insert out of order, leave explicit zeros stored, and include an active
    # group that becomes all zero. Snapshots must keep only nonzero entries.
    for x in (vector, matrix, symmetric, atoms)
      c = coord(x)
      c[10] = T(2)
      c[2] = T(-3)
      c[4] = T(1)
      c[4] = zero(T)
      expected = Array(x)
      snapshot = PS._snapshot(x)
      @test snapshot isa (length(size(x)) == 1 ? SparseVector{T, Int} : SparseMatrixCSC{T, Int})
      @test size(snapshot) == size(x)
      @test Array(snapshot) == expected
      @test all(!iszero, nonzeros(snapshot))
      c[2] = T(7)
      @test Array(snapshot) == expected
      snapshot[2] = T(5)
      @test c[2] == T(7)
    end
    for x in (SparseIterate(T, 0), SparseIterate(T, 0, 3),
              SparseIterate(T, 3, 0), SymmetricSparseIterate(T, 0),
              AtomIterate(T, 0, UnitRange{Int}[]))
      snapshot = PS._snapshot(x)
      @test size(snapshot) == size(x)
      @test nnz(snapshot) == 0
      @test eltype(snapshot) == T
    end
  end
end

@testset "sparse and dense snapshot routes" begin
  # The first groups have arbitrary index order and unequal lengths. Only
  # these small groups become active on the sparse route.
  special = (101, 3, 1, 95, 2, 4)
  groups = vcat([[101, 3, 1], [95, 2], [4]], [[i] for i in 1:1024 if !(i in special)])
  for T in (Float32, Float64)
    for x in (SparseIterate(T, 32, 32), SymmetricSparseIterate(T, 32), AtomIterate(T, 1024, groups))
      c = coord(x)
      c[101] = T(2)
      c[1] = T(-3)
      c[2] = T(4)
      c[4] = one(T)
      c[4] = zero(T)
      @test !PS._snapshot_dense(x)
      @test Array(PS._snapshot(x)) == Array(x)
      @test all(!iszero, nonzeros(PS._snapshot(x)))
      fill!(c, one(T))
      @test PS._snapshot_dense(x)
      @test Array(PS._snapshot(x)) == Array(x)
    end
    # One active group can contain nearly all entries, even when most groups
    # are inactive. Count their lengths rather than their number.
    unequal = AtomIterate(T, 1024, vcat([1:900], [i:i for i in 901:1024]))
    unequal[1] = one(T)
    @test PS._snapshot_dense(unequal)
    @test Array(PS._snapshot(unequal)) == Array(unequal)
  end
end

snapshot_bytes(x) = @allocated PS._snapshot(x)
copyback_bytes(dest, src) = @allocated PS._copy_dense!(dest, src)

@testset "dense copy-back clears implicit and stored zeros" begin
  for T in (Float32, Float64)
    for src in (SparseIterate(T, 12), SparseIterate(T, 3, 4),
                SymmetricSparseIterate(T, 4), AtomIterate(T, 12, [[3, 1], [6, 2, 5], [4], 7:12]))
      c = coord(src)
      c[10] = T(2)
      c[2] = T(-3)
      c[4] = one(T)
      c[4] = zero(T)
      expected = Array(src)
      dest = fill(T(9), size(src))
      @test PS._copy_dense!(dest, src) === dest
      @test dest == expected
      @test Array(src) == expected
      copyback_bytes(dest, src)
      @test copyback_bytes(dest, src) == 0
      @test_throws DimensionMismatch PS._copy_dense!(zeros(T, 1, 1), src)
    end
  end
end

@testset "snapshots avoid dense temporary arrays" begin
  # The output itself allocates, including the column pointers of a sparse
  # matrix. These loose bounds exclude a dense copy without fixing allocator
  # details or the number of stored entries in SparseArrays' work buffers.
  xs = (SparseIterate(600, 800), SymmetricSparseIterate(600),
        AtomIterate(100_000, [k:k+9 for k in 1:10:100_000]))
  for x in xs
    coord(x)[10] = 1.0
    coord(x)[2] = -2.0
    snapshot_bytes(x)
    @test snapshot_bytes(x) < 100_000
  end
end

# The paths of coordinate descent and of LLA on a SymmetricSparseIterate: one snapshot per level,
# in the order of the levels, each equal to the matrix of the iterate when its level ends (both
# triangles, without stored zeros), through the sparse and the dense routes, and independent of
# the later levels; the last is the final iterate, which a cold solve at the last level reaches.
@testset "path snapshots of a SymmetricSparseIterate" begin
  q = 20
  Sx = [i == j ? 2.0 : 0.3^abs(i - j) for i in 1:q, j in 1:q]
  C = [sin(i + 2j) + sin(j + 2i) for i in 1:q, j in 1:q]
  f = KronQuadratic(Sx, Sx, C)
  λmax = lambda_max(f, NormL1(1.0), SymmetricSparseIterate(q))
  λs = λmax .* 10 .^ range(0, -1.5; length = 10)
  method = CDSolver(; order = :cyclic, tol = 1e-12)
  matrices, dense = Matrix{Float64}[], Bool[]
  record(x) = (push!(matrices, Matrix(x)); push!(dense, PS._snapshot_dense(x)); false)
  runs = ((true, (x, cb) -> solve_path(f, NormL1(1.0), λs, method; x, screening = true, gaptol = 0, callback = cb)),
          (true, (x, cb) -> solve_path(f, NormL1(1.0), λs, method; x, screening = false, gaptol = 0, callback = cb)),
          (false, (x, cb) -> solve_path(f, MCP(1.0, 3.0), λs, LLA(method); x, callback = cb)))
  for (lasso, run) in runs
    empty!(matrices); empty!(dense)
    x = SymmetricSparseIterate(q)
    path = run(x, (k, λ, x, m) -> record(x))
    @test path.λ == λs
    @test length(path.solutions) == length(matrices) == length(λs)
    @test any(dense) && !all(dense)                       # both routes of _snapshot
    for k in eachindex(λs)
      snapshot = path.solutions[k]
      @test snapshot isa SparseMatrixCSC{Float64, Int} && size(snapshot) == (q, q)
      @test Matrix(snapshot) == matrices[k]
      @test snapshot == permutedims(snapshot)
      @test all(!iszero, nonzeros(snapshot))
    end
    @test Matrix(path.solutions[end]) == Matrix(x)
    @test count(!iszero, Matrix(path.solutions[end])) > count(!iszero, Matrix(path.solutions[2]))
    lasso || continue
    @test path.values ≈ [f(X) + λ * sum(abs, X) for (λ, X) in zip(λs, matrices)] rtol = 1e-10
    xc = SymmetricSparseIterate(q)
    solve!(xc, f, NormL1(λs[end]), method)
    @test Matrix(xc) ≈ Matrix(x) atol = 1e-8
  end
end

end
