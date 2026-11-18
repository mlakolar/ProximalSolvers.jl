using ProximalBase
const PB = ProximalBase
names_used = [:LeastSquaresLoss, :SqrtLeastSquaresLoss, :Scaled, :NormL1, :ElasticNet, :SparseIterate, :ncoordinates, :nactive,
  :activecoordinates, :activevalues, :prox_block, :value_and_prox!, :BlockIterate, :GroupNormL2, :blockindices, :blockview, :prox_block!,
  :kkt_violation, :norm_diff, :shrink, :leastsquares_data, :value_from_residual, :value_from_predictor, :value_and_gradient_from_predictor!]
println("Julia ", VERSION)
for n in names_used
  ex = Base.isexported(PB, n); pu = @static VERSION >= v"1.11" ? Base.ispublic(PB, n) : missing
  println(rpad(n, 40), "exported=", ex, "  public(1.11+)=", pu)
end
println("fields documented? NormL1 fieldnames: ", fieldnames(PB.NormL1), " ; docstring mentions λ0: ", occursin("λ0", string(Base.Docs.doc(PB.NormL1))))
