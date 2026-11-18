include("lib.jl"); include("optB.jl"); include("optC.jl"); include("optC2.jl")
# rough probe: ns per visit of the Float32 tiny-y (cold path every visit) under A, C (plain Float64 loops) and C2 (copies)
function pass_time(m, g, x, p, reps)
  best = Inf
  for _ in 1:reps
    t0 = time_ns()
    for k in 1:p
      PS.coordinate_step!(m, g, x, k)
    end
    best = min(best, (time_ns() - t0) / p)
  end
  best
end
function setup(X, y, λ)
  T = eltype(X); f = SqrtLeastSquaresLoss(y, X); x = SparseIterate(zeros(T, size(X, 2)))
  m = PS.cdmodel(f, x); PS.initialize!(m, x); g = NormL1(λ); PS._prepare!(m, g, x); m, g, x
end
function run(tag)
  println(tag)
  for T in (Float32,), n in (50, 500, 5000)
    p = 40; rng = Xoshiro(3)
    X = randn(rng, T, n, p); y = randn(rng, T, n) .* T(2)^-70
    λ = T(0.5*norm(X[:,1]))
    m, g, x = setup(X, y, λ); for _ in 1:10; Base.invokelatest(pass_time, m, g, x, p, 1); end
    t = Base.invokelatest(pass_time, m, g, x, p, 50)
    alloc = Base.invokelatest(() -> @allocated(for k in 1:p; PS.coordinate_step!(m, g, x, k); end))
    @printf("  %s n=%5d tiny-y (cold every visit): %9.0f ns/visit, %d bytes per pass of %d visits\n", T, n, t, alloc, p)
  end
end
tag = ARGS[1]
tag == "C" && install_C!(); tag == "C2" && install_C2!()
run(tag)
