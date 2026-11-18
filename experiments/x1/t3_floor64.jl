# floor64 = 16 eps(T) ‖y‖ : BASE (_scaled_norm) vs X1A/X1B (_se_norm(Float64, y)); fraction of bitwise differences.
include("x1lib.jl")
function floor_of(P, T, y)
  X = ones(T, length(y), 1); f = SqrtLeastSquaresLoss(y, X); x = SparseIterate(zeros(T, 1))
  m = P.cdmodel(f, x); P.initialize!(m, x); P._prepare!(m, NormL1(T(1)), x); m.floor64
end
println("# Julia ", VERSION)
for T in (Float32, Float64)
  rng = Xoshiro(1); nd = 0; N = 0; worst = 0.0; nz = 0
  lo, hi = T === Float32 ? (-120, 100) : (-1000, 1000)
  for i in 1:4000
    n = rand(rng, (1, 2, 5, 30, 200)); y = T.(ldexp.(randn(rng, n), rand(rng, lo:hi)))
    (all(isfinite, y)) || continue
    fb, fa, fbb = floor_of(TREES.base, T, y), floor_of(TREES.x1a, T, y), floor_of(TREES.x1b, T, y)
    fa == fbb || error("x1a != x1b")
    N += 1; fb == fa || (nd += 1; worst = max(worst, abs(fb - fa)/max(abs(fb), floatmin()))); nz += iszero(fb)
  end
  # y = 0
  y0 = zeros(T, 5)
  println(T, ": ", N, " vectors, floor64 differs in ", nd, " (", round(100nd/N, digits = 1), "%), worst relative difference ", worst, "; zeros: ", floor_of(TREES.base, T, y0), " vs ", floor_of(TREES.x1a, T, y0))
end
