include("lib.jl")
for T in (Float32, Float64)
  rng = Xoshiro(3); n, p = 500, 40
  X = randn(rng, T, n, p); y = randn(rng, T, n); λ = T(0.5*norm(X[:,1]))
  m, g, x = make_model(X, y, λ)
  f(m, g, x, p) = (for k in 1:p; PS.coordinate_step!(m, g, x, k); end; nothing)
  for _ in 1:20; f(m, g, x, p); end
  println(T, " ordinary pass of $p visits: ", @allocated(f(m, g, x, p)), " bytes (", VERSION, ")")
  # full solve allocations vs LS solve for the same data/level class
  xs = zeros(T, p); solve!(xs, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(order=:cyclic))
  a1 = @allocated solve!(zeros(T, p), SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(order=:cyclic))
  println(T, " sqrt solve! total allocation: ", a1, " bytes (n=$n, p=$p; certificate work vectors 2 x 8n = ", 16n, " bytes)")
end
