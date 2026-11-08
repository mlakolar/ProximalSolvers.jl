module PathSnapshotTests

using Test, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

# coordinate k of an iterate: a lower-triangle coordinate of a SymmetricSparseIterate,
# which has no one-index access, and the linear entry k of the other iterates
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

end
