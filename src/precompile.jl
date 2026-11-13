using PrecompileTools: @setup_workload, @compile_workload
@setup_workload begin
  @compile_workload begin
    for T in (Float64, Float32)
      X = T[1 0; 0 2; 1 1]
      y = T[1, -1, .5]
      f = (one(T)/T(3))*LeastSquaresLoss(y, X)
      g = NormL1(T(.1))
      solve!(zeros(T, 2), f, g, CDSolver())
      solve!(zeros(T, 2), f, g, ProximalGradientDescent())
      solve!(zeros(T, 2), f, g, AccProxGradDescent())
    end
    # Float32 data with the Float64 scale of the `(1/n) * LeastSquaresLoss(y, X)` shorthand
    X = Float32[1 0; 0 2; 1 1]
    y = Float32[1, -1, .5]
    solve!(zeros(Float32, 2), (1/3)*LeastSquaresLoss(y, X), NormL1(0.1f0), CDSolver())
  end
end
