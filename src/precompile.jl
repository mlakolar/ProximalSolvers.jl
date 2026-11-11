using PrecompileTools: @setup_workload, @compile_workload
@setup_workload begin
  @compile_workload begin
    for T in (Float64,Float32)
      X=T[1 0;0 2;1 1]
      y=T[1,-1,.5]
      f=(one(T)/T(3))*LeastSquaresLoss(y,X)
      g=NormL1(T(.1))
      solve!(zeros(T,2),f,g,CDSolver())
      solve!(zeros(T,2),f,g,ProximalGradientDescent())
    end
  end
end
