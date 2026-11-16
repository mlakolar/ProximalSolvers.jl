module GroupCDPreflight
using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

# ---------------------------------------------------------------------------
# Helpers. A refusal names its category (a fragment of the message), and it leaves the values
# of the caller, its active groups in slot order, the signs of its entries and a borrowed RNG as
# they were.
# ---------------------------------------------------------------------------
const GROUPS = [1:2, 3:3, 4:5]

# A BlockIterate of 5 entries in the given groups, with the groups of entries 3 and 5 holding values
function iterate(::Type{T}, groups = GROUPS) where T
  x = BlockIterate(T, 5, groups)
  x[3] = T(0.5)
  x[5] = T(-0.25)
  x
end

# An 8 × 5 design and response with finite entries
function data(::Type{T}) where T
  rng = Xoshiro(7)
  T.(randn(rng, 8, 5)), T.(randn(rng, 8))
end

state(x) = (Vector(x), collect(activecoordinates(x)), signbit.(Vector(x)))
same_state(a, b) = isequal(a[1], b[1]) && a[2] == b[2] && a[3] == b[3]

message(e) = sprint(showerror, e)

# solve! throws an exception of type E whose message contains the fragment, and the caller and
# the RNG stay as they were.
function refused(E, fragment, x, f, g; momentum = nothing, maxpasses = 100, kwargs...)
  before = state(x)
  rng = Xoshiro(11)
  rng_before = copy(rng)
  method = CDSolver(; order = :random, momentum, maxpasses, rng)
  err = try
    solve!(x, f, g, method; kwargs...)
    nothing
  catch e
    e
  end
  @test err isa E
  @test err !== nothing && occursin(fragment, message(err))
  @test same_state(before, state(x))
  @test rng == rng_before
end

accepted(x, f, g; method = CDSolver(order = :random)) = PS._check_block_problem(x, f, g, method) === nothing

@testset "group_cd_preflight" begin
  for T in (Float32, Float64)
    X, y = data(T)
    f = LeastSquaresLoss(y, X)
    g = GroupNormL2(T(0.1), GROUPS)
    opposite = T === Float32 ? Float64 : Float32

    @testset "receiver and solver ($T)" begin
      @test accepted(iterate(T), f, g)
      @test accepted(iterate(T), f, g; method = CDSolver(momentum = false))
      @test accepted(iterate(T), f, g; method = CDSolver(order = :cyclic, momentum = false))
      @test accepted(iterate(T), f, g; method = CDSolver(maxpasses = 0))
      for S in (Float16, BigFloat)
        x = iterate(S)
        refused(ArgumentError, "BlockIterate of Float32 or Float64", x, f, g)
        @test_throws ArgumentError PS._check_block_problem(x, f, g, CDSolver())
      end
      for maxpasses in (100, 0)
        refused(ArgumentError, "momentum", iterate(T), f, g; momentum = true, maxpasses)
      end
      err = try CDSolver(order = :cyclic, momentum = true) catch e e end
      @test err isa ArgumentError && occursin("momentum needs order = :random", message(err))
    end

    @testset "penalty ($T)" begin
      refused(ArgumentError, "GroupNormL2", iterate(T), f, NormL1(T(0.1)))
      refused(ArgumentError, "GroupNormL2", iterate(T), f, GroupNormL2(Float16(0.1), GROUPS))
      setprecision(BigFloat, 128) do
        refused(ArgumentError, "GroupNormL2", iterate(T), f, GroupNormL2(BigFloat(0.1), GROUPS))
      end
      @test accepted(iterate(T), f, GroupNormL2(0.1, GROUPS))   # a Float64 penalty, on either precision
      @test accepted(iterate(T), 0.5 * f, g)
      @test accepted(iterate(T), f, GroupNormL2(T(0.1), GROUPS, T[0, 1, 2]))   # a zero weight is accepted
      @test accepted(iterate(T), f, GroupNormL2(zero(T), GROUPS))
    end

    @testset "level and weights ($T)" begin
      # PB refuses a negative or NaN level or weight itself
      @test_throws ArgumentError GroupNormL2(-0.1, GROUPS)
      @test_throws ArgumentError GroupNormL2(NaN, GROUPS)
      @test_throws ArgumentError GroupNormL2(0.1, GROUPS, [1.0, -1.0, 1.0])
      refused(ArgumentError, "penalty lambda", iterate(T), f, GroupNormL2(Inf, GROUPS))
      refused(ArgumentError, "group weight 2", iterate(T), f, GroupNormL2(0.1, GROUPS, [1.0, Inf, 1.0]))
      refused(ArgumentError, "group weight 3", iterate(T), f, GroupNormL2(T(0.1), GROUPS, T[1, 1, Inf]))
      if T === Float32
        refused(ArgumentError, "penalty lambda", iterate(T), f, GroupNormL2(1e-50, GROUPS))
        refused(ArgumentError, "penalty lambda", iterate(T), f, GroupNormL2(1e40, GROUPS))
        refused(ArgumentError, "group weight 1", iterate(T), f, GroupNormL2(0.1, GROUPS, [1e40, 1.0, 1.0]))
        refused(ArgumentError, "group weight 3", iterate(T), f, GroupNormL2(0.1, GROUPS, [1.0, 1.0, 1e-50]))
        @test accepted(iterate(T), f, GroupNormL2(0.1, GROUPS, [0.0, 1.0, 1.0]))
      end
    end

    @testset "layout ($T)" begin
      mismatch(groups) = refused(DimensionMismatch, "groups", iterate(T), f, GroupNormL2(T(0.1), groups))
      mismatch([1:2, 3:5])                        # a different count
      mismatch([3:3, 1:2, 4:5])                   # the same groups in another order
      mismatch([1:1, 2:3, 4:5])                   # another partition
      mismatch([1:2, 3:3, [5, 4]])                # one group with its members permuted
      mismatch([1:2, 3:3, 4:4, 5:5])              # more groups than x
      vector_groups = [[1, 4], [2], [3, 5]]
      xv = iterate(T, vector_groups)
      refused(DimensionMismatch, "groups", xv, f, GroupNormL2(T(0.1), [[4, 1], [2], [3, 5]]))
      @test accepted(xv, f, GroupNormL2(T(0.1), vector_groups))
      @test accepted(iterate(T), f, GroupNormL2(T(0.1), [[1, 2], [3], [4, 5]]))   # ranges in x, vectors in g
      @test accepted(iterate(T, [[1, 2], [3], [4, 5]]), f, g)                     # vectors in x, ranges in g
      @test accepted(iterate(T, [1:5]), f, GroupNormL2(T(0.1), [collect(1:5)]))
      @test accepted(iterate(T, [[i] for i in 1:5]), f, GroupNormL2(T(0.1), [i:i for i in 1:5]))
    end

    @testset "loss and data ($T)" begin
      refused(ArgumentError, "X must be Matrix", iterate(T), LeastSquaresLoss(opposite.(y), opposite.(X)), g)
      refused(ArgumentError, "X must be Matrix", iterate(T), LeastSquaresLoss(y, sparse(X)), g)
      refused(ArgumentError, "X must be Matrix", iterate(T), LeastSquaresLoss(opposite.(y), X), g)
      # PB refuses a response whose length differs from the rows of X when it builds the loss
      refused(DimensionMismatch, "dimensions do not match", iterate(T), LeastSquaresLoss(y, X[:, 1:4]), g)
      refused(DimensionMismatch, "dimensions do not match", iterate(T), LeastSquaresLoss(y, hcat(X, X)), g)
      refused(ArgumentError, "only LeastSquaresLoss", iterate(T), QuadraticFunction(Matrix{T}(I, 5, 5), zeros(T, 5)), g)
      refused(ArgumentError, "only LeastSquaresLoss", iterate(T), Scaled(f, 0.0), g)
      refused(ArgumentError, "loss scale", iterate(T), Scaled(f, Float16(2)), g)
      refused(ArgumentError, "loss scale", iterate(T), Scaled(f, Inf), g)
      T === Float32 && refused(ArgumentError, "loss scale", iterate(T), Scaled(f, 1e-50), g)
    end

    @testset "nonfinite values ($T)" begin
      for v in (T(NaN), T(Inf), -T(Inf))
        x = iterate(T)
        x[3] = v
        refused(ArgumentError, "finite values", x, f, g)
        badX = copy(X)
        badX[2, 4] = v
        refused(ArgumentError, "finite values", iterate(T), LeastSquaresLoss(y, badX), g)
        bady = copy(y)
        bady[8] = v
        refused(ArgumentError, "finite values", iterate(T), LeastSquaresLoss(bady, X), g)
      end
    end

    @testset "keywords ($T)" begin
      for keyword in (:intercept, :offset, :screening)
        refused(ArgumentError, "unsupported solve! keywords", iterate(T), f, g; keyword => true)
      end
    end

    @testset "other receivers keep their messages ($T)" begin
      for x in (zeros(T, 5), SparseIterate(T, 5))
        before = Vector(x)
        err = try solve!(x, f, g, CDSolver()) catch e e end
        @test err isa ArgumentError && occursin("only unweighted NormL1 is supported", message(err))
        @test Vector(x) == before
      end
      for method in (ProximalGradientDescent(), AccProxGradDescent())
        x = iterate(T)
        before = state(x)
        err = try solve!(x, f, g, method) catch e e end
        @test err isa ArgumentError && occursin("x must be a dense Vector{Float32} or Vector{Float64}", message(err))
        @test same_state(before, state(x))
      end
    end
  end
end

end
