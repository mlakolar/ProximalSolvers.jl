include("lib.jl"); include("optB.jl"); include("optC.jl"); include("optC2.jl")
using Logging
install_C2!()
for T in (Float32, Float64), owner in (false, true)
  rng = Xoshiro(1); n, p = 50, 8
  X = randn(rng, T, n, p); y = randn(rng, T, n) .* (T === Float32 ? T(1e-19) : T(1e200)) 
  λ = T(0.2*lam_max(X, y)); x0 = zeros(T, p); x = owner ? SparseIterate(copy(x0)) : copy(x0)
  before = Vector(x)
  try
    with_logger(NullLogger()) do
      solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(order = :cyclic))
    end
    println(T, " owner=", owner, ": solved, converged path (F32 tiny y accepted by widening)")
  catch e
    println(T, " owner=", owner, ": ", first(sprint(showerror, e), 70), " | caller unchanged: ", Vector(x) == before)
  end
end
