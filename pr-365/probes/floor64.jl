# G: floor64 = 16 eps(T) ‖y‖ at _prepare!, master (_scaled_norm) vs candidate (_se_norm(Float64, y)); Stage 0 corpus t3_floor64.jl
include("r1lib.jl")
function floor_of(P, T, y)
  X = ones(T, length(y), 1); f = SqrtLeastSquaresLoss(y, X); x = SparseIterate(zeros(T, 1))
  m = P.cdmodel(f, x); P.initialize!(m, x)
  try P._prepare!(m, NormL1(T(1)), x); m.floor64 catch e; "throws " * first(sprint(showerror, e), 70) end   # head: a direct call with a non-finite y fails on `nothing`
end
println("# Julia ", VERSION)
for T in (Float32, Float64)
  rng = Xoshiro(1); nd = 0; N = 0; worst = 0.0; nz = 0
  lo, hi = T === Float32 ? (-120, 100) : (-1000, 1000)
  for i in 1:4000
    n = rand(rng, (1, 2, 5, 30, 200)); y = T.(ldexp.(randn(rng, n), rand(rng, lo:hi)))
    (all(isfinite, y)) || continue
    fb, fc = floor_of(TREES.base, T, y), floor_of(TREES.cand, T, y)
    N += 1; fb == fc || (nd += 1; worst = max(worst, abs(fb - fc)/max(abs(fb), floatmin()))); nz += iszero(fb)
  end
  y0 = zeros(T, 5)
  println(T, ": ", N, " vectors, floor64 differs in ", nd, " (", round(100nd/N, digits = 1), "%), worst relative difference ", worst, "; zeros: ", floor_of(TREES.base, T, y0), " vs ", floor_of(TREES.cand, T, y0))
  # large n (the Stage 0 note: sequential sum less accurate at n = 1e5)
  yl = T.(randn(rng, 100000)); fb, fc = floor_of(TREES.base, T, yl), floor_of(TREES.cand, T, yl)
  println("   n = 1e5, randn: master ", fb, " cand ", fc, " relative difference ", abs(fb - fc)/fb)
  # a non-finite y reaches _prepare! only by a direct call (solve! checks y): the same floor64 as master?
  for bad in (T(Inf), T(NaN), -T(Inf))
    yb = T[1, bad, 2]; fb, fc = floor_of(TREES.base, T, yb), floor_of(TREES.cand, T, yb)
    println("   y = [1, $bad, 2]: master ", fb, " cand ", fc, " same: ", isequal(fb, fc))
  end
  yb = T[T(NaN), T(Inf)]; fb, fc = floor_of(TREES.base, T, yb), floor_of(TREES.cand, T, yb)
  println("   y = [NaN, Inf]: master ", fb, " cand ", fc, " same: ", isequal(fb, fc))
end
